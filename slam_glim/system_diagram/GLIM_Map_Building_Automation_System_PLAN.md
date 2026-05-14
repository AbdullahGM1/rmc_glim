# GLIM Map Building Automation System — Implementation Plan

## 1. What This System Is

The full project has **3 phases**:

| Phase | Name | Description |
|---|---|---|
| **Phase 1** | Environment Setup | Docker image — CUDA 13.2, ROS2 Jazzy, GLIM, all dependencies |
| **Phase 2** | CLI Wizard | Interactive terminal pipeline — bag → SLAM → map → POI (this document) |
| **Phase 3** | Web Dashboard | Replaces CLI with a web page — same pipeline + live robot tracking + OEM map sharing |

This plan covers **Phase 2**: an **interactive CLI wizard** for the `slam_glim` ROS2 package.
The user runs one command, types in a bag file path, and the terminal guides them through
every step of the GLIM 3D SLAM pipeline — from raw bag to final 3D/2D map with POI registration.

Every decision point in the system diagram becomes a terminal prompt.
Every tool (validator, map_editor, RViz2, GLIM) is launched as a subprocess from the same terminal.
The script waits for each tool to finish, then moves to the next step automatically.

**Phase 3 constraint:** keep all step modules free of `input()` calls — accept all user decisions
as function parameters so they work identically from both the CLI wizard and the web dashboard backend.

---

## 2. The Full Pipeline (Step by Step)

This matches the system diagram (`GLIM_System.drawio.png`) with the agreed improvements applied.

```
START
  │
  ▼
[User types bag file path]
  │
  ▼
[1] Is this a ROS1 bag?
  ├── Yes → Convert ROS1 → ROS2 (automated script) → continue
  └── No  → continue
  │
  ▼
[1.5] Sensor config setup — user edits user_config.yaml:
       imu_topic:    /imu/gravity
       lidar_topic:  /velodyne_points
       T_lidar_imu:  [tx, ty, tz, qx, qy, qz, qw]
       System reads this file and auto-fills the GLIM JSON config files
       (config_ros.json → imu_topic + points_topic)
       (config_sensors.json → T_lidar_imu)
       Wizard prints the file path and waits for user to confirm done
  │
  ▼
[2] Run validator? (recommended before SLAM)
  ├── Yes → Launch validator_node against the bag
  │         Print report to terminal
  │         HUMAN REVIEWS REPORT — fix config_ros.json / config_sensors.json if needed
  │         Press Enter when ready to continue
  └── No  → continue
  │
  ▼
[3] Do you want to generate a new map?
  ├── No (already have a dump) → ask user for dump directory path → skip to [5]
  └── Yes → continue
  │
  ▼
[3a] Select SLAM pipeline:
  ├── [1] GPU        → Full SLAM with CUDA acceleration (recommended for RMC robot)
  ├── [2] CPU        → Full SLAM without GPU (use when no CUDA available)
  └── [3] LiDAR-only → CT-ICP, no IMU required (use when bag has no IMU data)
       sets config_path = slam_glim/config/gpu|cpu|lidar_only/
  │
  ▼
[3b] Config review — always shown before SLAM runs:
       Displays current settings and asks user to confirm:
         Pipeline:      GPU / CPU / LiDAR-only
         IMU topic:     /imu/gravity        (from config_ros.json)
         LiDAR topic:   /velodyne_points    (from config_ros.json)
         T_lidar_imu:   [0,0,0,0.035,0.008,0,0.999]  (from config_sensors.json)
         Dump path:     maps/<bag_name>_<YYYYMMDD_HHMMSS>/
       Confirm? [y/n]
         → n: prints config file paths, waits for Enter, re-displays and asks again
         → y: continue
  │
  ▼
[4] SLAM mode:
  ├── [1] Live viewer  → ros2 bag play + glim_rosnode (Iridescence 3D viewer opens)
  └── [2] Fast offline → glim_rosbag (no viewer, faster than real-time)
       │
       ▼
       GLIM runs → auto-saves dump to maps/<bag_name>_<YYYYMMDD_HHMMSS>/
  │
  ▼
[5] Do you want to Edit/Modify the map?
  ├── Yes → launch map_editor with dump path → user edits → closes tool → saves dump
  │         Ask again: edit more? → loop until No
  └── No  → continue
  │
  ▼
[6] Do you want to Merge with another map?
  ├── Yes → ask user for second dump path
  │         launch map_editor with both paths → user merges → saves new dump
  │         ask user for the merged dump path (output of merge)
  └── No  → continue
  │
  ▼
[7] Export map — AUTOMATED (no GUI needed)
      Read dump directory → transform all submaps to world frame → write .pcd
      (see Section 6 for the binary format details)
  │
  ▼
[8] Do you want a 2D map?
  ├── Yes → run convert_map on the .pcd → saves .pgm + .yaml alongside the .pcd
  └── No  → continue
  │
  ▼
[9] Open 3D map viewer with POI registration
      Launch RViz2 with pcd_publisher + poi_selector
      User clicks points → POIs saved to YAML
END
```

---

## 3. Package File Structure (Target State)

```
slam_glim/
├── slam_glim/                        # Python package
│   ├── __init__.py
│   ├── main.py                       # Entry point — CLI wizard orchestrator
│   ├── steps/
│   │   ├── __init__.py
│   │   ├── bag_convert.py            # Step 1:   ROS1 → ROS2 conversion
│   │   ├── config_setup.py           # Step 1.5: guide user to edit user_config.yaml, push to GLIM JSON
│   │   ├── validator.py              # Step 2:   run validator_node, show report
│   │   ├── slam_runner.py            # Step 3+4: run GLIM (pipeline select + config review + two modes)
│   │   ├── map_editor_launcher.py    # Step 5+6: open map_editor subprocess
│   │   ├── export_map.py             # Step 7: dump → PCD (no GUI needed)
│   │   ├── convert_map.py            # Step 8: PCD → 2D occupancy grid (.pgm + .yaml)
│   │   └── poi_viewer.py             # Step 9: launch RViz2 + pcd_publisher + poi_selector
│   ├── nodes/
│   │   ├── __init__.py
│   │   ├── pcd_publisher.py          # ROS2 node: reads PCD → latched PointCloud2 on /map_cloud
│   │   └── poi_selector.py           # ROS2 node: /clicked_point → YAML + /poi_pose + /poi_markers
│   └── utils/
│       ├── __init__.py
│       └── terminal.py               # Colored terminal output helpers (print_step, ask_yes_no, etc.)
├── launch/
│   ├── view_map.launch.py            # Used by Step 9 internally (pcd_publisher + poi_selector + RViz2)
│   └── map_editor.launch.py          # Used by Steps 5+6 internally (map_editor subprocess)
├── config/
│   ├── user_config.yaml              # ← USER EDITS THIS (Step 1.5): imu_topic, lidar_topic, T_lidar_imu
│   ├── gpu/                          # GLIM GPU full SLAM config (copy from glim_test)
│   │   ├── config.json
│   │   ├── config_ros.json           # ← auto-filled by config_setup.py from user_config.yaml
│   │   ├── config_sensors.json       # ← auto-filled by config_setup.py from user_config.yaml
│   │   ├── config_preprocess.json
│   │   ├── config_odometry_gpu.json
│   │   ├── config_sub_mapping_gpu.json
│   │   ├── config_global_mapping_gpu.json
│   │   ├── config_viewer.json
│   │   └── config_logging.json
│   ├── cpu/                          # GLIM CPU full SLAM config (copy from glim_test)
│   └── lidar_only/                   # GLIM LiDAR-only config (copy from glim_test)
├── rviz_config/
│   └── view_map.rviz                 # RViz2 config: map_cloud + POI markers + PublishPoint tool
├── maps/                             # All GLIM map dumps land here
│   └── <bag_name>_<YYYYMMDD_HHMMSS>/
│       ├── 000000/, 000001/, ...     # Binary submap dirs
│       ├── graph.bin / graph.txt
│       ├── map.pcd                   # Written by export_map.py (Step 7)
│       ├── map_2d.pgm                # Written by convert_map.py (Step 8)
│       ├── map_2d.yaml               # Written by convert_map.py (Step 8)
│       └── POI_Poses/               # POI YAML files from poi_selector
├── system_diagram/                   # Design documents (not part of ROS build)
│   ├── GLIM_System.drawio.png
│   ├── GLIM_System.drawio.svg
│   ├── GLIM_Map_Building_Automation_System.txt
│   ├── aaa.pptx
│   └── GLIM_Map_Building_Automation_System_PLAN.md  ← this file
├── resource/slam_glim
├── package.xml
├── setup.py
└── setup.cfg
```

---

## 4. Entry Point — How the User Runs It

```bash
cd ros2_rmc_ws
colcon build --packages-select slam_glim --symlink-install
source install/setup.bash
ros2 run slam_glim main
```

`main.py` is registered in `setup.py` as the `main` console_scripts entry point.
It imports and calls each step module in sequence.

---

## 5. Each Step — Implementation Details

### Step 1: Bag Conversion (`bag_convert.py`)

- Ask: "Is this a ROS1 .bag file? [y/n]"
- If yes: call the existing conversion script at
  `ros2_bags/ros1_bag_convert/convert_bag.sh <input_path>`
  using `subprocess.run()`
- Output: ROS2 `.db3` bag directory alongside the original
- The converted path is passed to all subsequent steps

### Step 1.5: Sensor Config Setup (`config_setup.py`)

**Purpose:** the user fills in ONE simple YAML file with their sensor settings.
The system reads it and auto-fills all three GLIM pipeline JSON files (gpu, cpu, lidar_only).
The user never touches the JSON files directly.

**`slam_glim/config/user_config.yaml` format:**
```yaml
# GLIM Sensor Configuration — edit once per robot/sensor setup
imu_topic:    /imu/gravity        # IMU topic in the bag
lidar_topic:  /velodyne_points    # LiDAR topic in the bag
T_lidar_imu:                      # LiDAR-to-IMU extrinsic [tx, ty, tz, qx, qy, qz, qw]
  - 0.0
  - 0.0
  - 0.0
  - 0.035460
  - 0.008223
  - 0.0
  - 0.999337
```

**What the wizard does:**
- Prints: "Open the sensor config file and fill in your settings:"
- Prints: `  >>> slam_glim/config/user_config.yaml`
- Waits for user to press Enter when done
- Reads `user_config.yaml`
- Updates `imu_topic` + `points_topic` in `config/gpu/config_ros.json`,
  `config/cpu/config_ros.json`, `config/lidar_only/config_ros.json`
- Updates `T_lidar_imu` in `config/gpu/config_sensors.json`,
  `config/cpu/config_sensors.json`, `config/lidar_only/config_sensors.json`
- Prints confirmation: "Config applied to all pipelines."

**RMC 2.0 robot values** (pre-filled in the repo):
```yaml
imu_topic:    /imu/gravity
lidar_topic:  /velodyne_points
T_lidar_imu: [0.0, 0.0, 0.0, 0.035460, 0.008223, 0.0, 0.999337]
```

**T_lidar_imu note:** The gravity vector from `/imu/gravity` is `[-0.16, 0.69, 9.71]` m/s² —
not perfectly vertical (4.17° tilt). This quaternion cancels the tilt so the map is level.
Recompute if a new bag with different robot orientation is recorded.

### Step 2: Validator (`validator.py`)

- Ask: "Run sensor validator before SLAM? [y/n]"
- If yes:
  - Launch: `ros2 run glim_ros validator_node --ros-args -p config_path:=<config_path>`
    with `LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH`
  - Simultaneously play the bag for ~10 seconds (enough for validator to check topics/rates)
  - Kill both processes
  - Print the validator output clearly to terminal
  - Print: ">>> Review the report above. Fix config files if needed."
  - Print: ">>> Config files are at: slam_glim/config/gpu/"
  - Wait for user to press Enter to continue
- If no: skip

### Step 3+4: SLAM Runner (`slam_runner.py`)

- Ask: "Generate a new map? [y/n]"
- If no: ask for existing dump path → store it → skip to Step 5
- If yes:
  - **Ask: "Select SLAM pipeline: [1] GPU  [2] CPU  [3] LiDAR-only"**
    - Sets `config_path` to `slam_glim/config/gpu/`, `cpu/`, or `lidar_only/`
    - Default (press Enter) = GPU (recommended for RMC robot)
  - **Config review — always shown before GLIM starts:**
    - Reads `imu_topic` and `points_topic` from `config_ros.json`
    - Reads `T_lidar_imu` from `config_sensors.json`
    - Displays all values clearly in the terminal
    - Asks: "Confirm? [y/n]"
    - If n: prints exact paths to config files, waits for Enter, re-displays, asks again
    - If y: proceed
  - Ask: "SLAM mode? [1] Live viewer  [2] Fast offline"
  - Create timestamped dump directory: `maps/<bag_name>_<YYYYMMDD_HHMMSS>/`
  - **Mode 1 (Live viewer):**
    - Launch `glim_rosnode` with dump_path + config_path + LD_LIBRARY_PATH
    - Launch `ros2 bag play <bag_path> --clock`
    - Launch RViz2 with glim_ros.rviz
    - Wait for bag to finish
    - Allow 5s grace period for GLIM to finish processing
    - Send shutdown → GLIM auto-saves to dump_path
  - **Mode 2 (Fast offline):**
    - Launch `glim_rosbag` with config_path + bag_path + dump_path + LD_LIBRARY_PATH
    - Wait for process to exit
    - GLIM auto-saves to dump_path
  - Print: "Map saved to: <dump_path>"
  - Store dump_path for subsequent steps

### Step 5: Map Editor — Edit/Modify (`map_editor_launcher.py`)

- Ask: "Do you want to edit/modify the map? [y/n]"
- If yes:
  - Print instructions: "The map editor will open. Edit the map, then close the window."
  - Launch: `ros2 run glim_ros map_editor --ros-args -p map_path:=<dump_path>`
    with `LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH`
  - Wait for process to exit (user closed the tool)
  - Ask: "Edit more? [y/n]" → loop if yes
- Note: map_editor saves back to the same dump_path automatically on close

### Step 6: Map Merging (`map_editor_launcher.py`)

- Ask: "Do you want to merge with another map? [y/n]"
- If yes:
  - Ask for second dump directory path
  - Print instructions: "The map editor will open with both maps loaded for merging."
  - Launch map_editor (the tool handles loading multiple maps via its GUI)
  - Wait for user to complete merge and close
  - Ask: "Enter the path of the merged dump (where you saved it):"
  - Update dump_path to the merged dump
- Note: map merging is done inside the GLIM map_editor GUI — the script just opens the tool
  and waits. The user does the actual merge work in the GUI.

### Step 7: Export Map — Dump → PCD (`export_map.py`)

**This step is fully automated. No GUI. No PLY intermediate.**

Key technical finding (verified): The GLIM dump format is readable directly in Python:
- Each submap directory (000000, 000001, ...) contains:
  - `points_compact.bin` — raw points as **float32 XYZ** (3 × float32 = 12 bytes/point)
  - `data.txt` — contains `T_world_origin` (4×4 transform matrix, text format)
- `covs_compact.bin` — covariances (not needed for PCD export)
- There is NO intensity data in the compact format — export is XYZ only

**Algorithm:**
```python
all_points = []
for submap_dir in sorted(glob(dump_path + "/[0-9]*/")):
    # 1. Parse T_world_origin from data.txt
    T = parse_T_world_origin(submap_dir + "/data.txt")   # returns 4x4 np.array
    # 2. Load points
    pts = np.fromfile(submap_dir + "/points_compact.bin", dtype=np.float32).reshape(-1, 3)
    # 3. Transform to world frame
    pts_h = np.hstack([pts, np.ones((len(pts), 1), dtype=np.float32)])
    pts_world = (T @ pts_h.T).T[:, :3]
    all_points.append(pts_world)
all_points = np.vstack(all_points)
# 4. Voxel downsample (0.05m) to reduce size
# 5. Write ASCII PCD v0.7 to dump_path/map.pcd
```

Output: `maps/<run>/map.pcd`

**Why no PLY step:** The GLIM offline_viewer and map_editor only expose PLY export through
their GUI (no CLI flag exists — confirmed by checking `--help` and binary symbols).
The dump binary format is fully parseable in Python, so we bypass the GUI entirely.
The Python implementation reproduces exactly what GLIM's `export_points()` C++ method does.

### Step 8: 2D Map Conversion (`convert_map.py`)

- Ask: "Do you want a 2D occupancy map? [y/n]"
- If yes: run convert_map pipeline on `dump_path/map.pcd`
- Output: `dump_path/map_2d.pgm` + `dump_path/map_2d.yaml`

**convert_map pipeline** (already implemented and tested in glim_test — copy and adapt):
1. Read ASCII PCD → extract XYZ
2. Voxel downsample at 0.05m
3. Ground detection: z-histogram on bottom 1.5m from 1st percentile (not z_min — avoids
   outlier points below real floor pulling the search window into empty space)
4. Find floor peak (densest z bin), walk up until counts < 20% → ground_top
5. Height filter: keep points from `max(ground_top, ground_peak + 0.30m)` to `ground_peak + 3.0m`
6. Grid: 205 (unknown gray) fill, 0.05m/pixel, 1m padding
7. Mark occupied cells as 0 (black)
8. `np.flipud` before saving (ROS2 convention: row 0 = world y_max)
9. Write .pgm + .yaml (origin = bottom-left corner)

### Step 9: POI Viewer (`poi_viewer.py`)

- Print: "Opening 3D map viewer with POI registration..."
- Launch `view_map.launch.py` with `map_pcd:=<dump_path>/map.pcd`
- view_map.launch.py starts:
  - `static_transform_publisher` (map → odom identity TF)
  - `pcd_publisher` node (reads PCD → latched PointCloud2 on /map_cloud)
  - `poi_selector` node (/clicked_point → YAML + /poi_pose + /poi_markers)
  - RViz2 with view_map.rviz (2s delay)
- POI YAML saved to `dump_path/POI_Poses/`
- User closes RViz2 when done

---

## 6. Config File Approach

**Single user-facing file:** `slam_glim/config/user_config.yaml`
The user edits only this YAML file. The system auto-fills all GLIM JSON files from it.
The user never touches any JSON file directly.

```
user_config.yaml   ──→  config_setup.py reads it
                          └──→ config/gpu/config_ros.json        (imu_topic, points_topic)
                          └──→ config/gpu/config_sensors.json    (T_lidar_imu)
                          └──→ config/cpu/config_ros.json
                          └──→ config/cpu/config_sensors.json
                          └──→ config/lidar_only/config_ros.json
                          └──→ config/lidar_only/config_sensors.json
```

**Why YAML not JSON:** YAML is human-readable, supports comments, and is simpler for users
who are not developers. The GLIM JSON files are GLIM's internal format — they are generated,
not hand-edited.

**Fields in user_config.yaml:**

| Field | Description | RMC 2.0 value |
|---|---|---|
| `imu_topic` | IMU topic name in the bag | `/imu/gravity` |
| `lidar_topic` | LiDAR point cloud topic in the bag | `/velodyne_points` |
| `T_lidar_imu` | LiDAR-to-IMU extrinsic `[tx,ty,tz,qx,qy,qz,qw]` | `[0,0,0,0.035460,0.008223,0,0.999337]` |

**Important — always use `/imu/gravity` not `/imu`:** The `/imu` topic has gravity
subtracted (≈0 when stationary) — GLIM cannot determine map orientation from it.
`/imu/gravity` contains the raw gravity vector `[-0.16, 0.69, 9.71]` m/s² which GLIM
uses for initialization.

---

## 7. GTSAM Version Fix

GLIM needs GTSAM 4.3.0 at `/usr/local/lib/`.
ROS Jazzy ships GTSAM 4.2.0 at `/opt/ros/jazzy/lib/` which takes precedence.

**Fix:** every subprocess that launches a GLIM tool must set:
```python
env = os.environ.copy()
env["LD_LIBRARY_PATH"] = "/usr/local/lib:" + env.get("LD_LIBRARY_PATH", "")
subprocess.run([...], env=env)
```

This is applied in: `validator.py`, `slam_runner.py`, `map_editor_launcher.py`.
It is NOT needed for `export_map.py`, `convert_map.py`, `poi_viewer.py` (pure Python / ROS2 only).

---

## 8. What to Reuse from `glim_test`

| Component | Source file | Action |
|---|---|---|
| `pcd_publisher` node | `glim_test/pcd_publisher.py` | Copy to `slam_glim/nodes/pcd_publisher.py` |
| `poi_selector` node | `glim_test/poi_selector.py` | Copy to `slam_glim/nodes/poi_selector.py` |
| `convert_map` pipeline | `glim_test/convert_map.py` | Copy logic to `slam_glim/steps/convert_map.py` |
| `view_map.rviz` | `glim_test/rviz_config/view_map.rviz` | Copy to `slam_glim/rviz_config/view_map.rviz` |
| GLIM config files | `glim_test/config/gpu/` | Copy entire gpu/, cpu/, lidar_only/ to `slam_glim/config/` |

`glim_test` remains unchanged — it is the verified testing sandbox.
`slam_glim` is the production implementation.

---

## 9. `setup.py` Entry Points (Target)

```python
entry_points={
    'console_scripts': [
        'main         = slam_glim.main:main',
        'pcd_publisher = slam_glim.nodes.pcd_publisher:main',
        'poi_selector  = slam_glim.nodes.poi_selector:main',
        'convert_map   = slam_glim.steps.convert_map:main',
        'export_map    = slam_glim.steps.export_map:main',
    ],
},
```

`ros2 run slam_glim main` → starts the full CLI wizard.
Individual steps can also be called directly (useful for debugging or re-running a single step).

---

## 10. `setup.py` Data Files (Target)

```python
data_files=[
    ('share/ament_index/resource_index/packages', ['resource/slam_glim']),
    ('share/' + package_name, ['package.xml']),
    (os.path.join('share', package_name, 'launch'),      glob('launch/*.py')),
    (os.path.join('share', package_name, 'rviz_config'), glob('rviz_config/*.rviz')),
    (os.path.join('share', package_name, 'config', 'gpu'),        glob('config/gpu/*.json')),
    (os.path.join('share', package_name, 'config', 'cpu'),        glob('config/cpu/*.json')),
    (os.path.join('share', package_name, 'config', 'lidar_only'), glob('config/lidar_only/*.json')),
],
```

Always build with `--symlink-install` so `os.path.realpath(__file__)` resolves to `src/` not `install/`.

---

## 11. Terminal Output Style

The CLI wizard should be clear and readable. Use simple prefixes — no external dependencies:

```
[GLIM Map Building System]
=====================================

[Step 1/9] Bag Conversion
  Is this a ROS1 .bag file? [y/n]: y
  Converting... done.
  Output: /path/to/bag_ros2/

[Step 2/9] Sensor Validation
  Run validator before SLAM? [y/n]: y
  Launching validator for 10 seconds...
  ----------------------------------------
  [validator output printed here]
  ----------------------------------------
  >>> Review the report above.
  >>> Config files: slam_glim/config/gpu/config_ros.json
  >>> Press Enter when ready to continue...

[Step 3/9] Map Generation
  Generate a new map? [y/n]: y
  SLAM mode? [1] Live viewer  [2] Fast offline: 1
  Running GLIM SLAM (live mode)...
  Map saved to: .../maps/lower_fused_20260515_143021/

[Step 7/9] Exporting Map
  Reading 43 submaps from dump...
  Transforming points to world frame...
  Total points: 1,284,032
  Voxel filtering (0.05m)...
  Writing PCD: .../maps/lower_fused_20260515_143021/map.pcd
  Done.
...
```

---

## 12. Phase 3 — Web Dashboard

After the CLI wizard (Phase 2) is fully working and tested, Phase 3 replaces the CLI
with a web dashboard. The underlying step modules are identical — only the interface changes.

### What the Dashboard Is

A web application (browser-based) that:
1. **Replaces the CLI wizard** — same pipeline steps (bag → SLAM → edit → export → POI)
   but through web forms, buttons, and progress indicators instead of terminal prompts
2. **Visualizes the 3D map** — renders the `.pcd` map in the browser
3. **POI management** — click on the map in the browser to register POIs, view/edit existing ones
4. **Live robot tracking** — overlays real-time robot pose on the global map
5. **OEM sharing** — share the final `.pcd` map with other teams/OEMs

### Architecture

```
Web Browser (frontend)
    ↕ HTTP / WebSocket
Web Backend — Flask or FastAPI (Python)
    ↕ function calls
Step modules (bag_convert, config_setup, validator, slam_runner, export_map, ...)
    ↕ subprocess / file I/O
GLIM tools, ROS2, bag files, dump directories
```

### Design Constraint (already applied in Phase 2)

All step modules accept user decisions as function parameters — no `input()` calls inside them:

```python
# Phase 2 CLI calls:
run_validator(bag_path, config_path, auto_continue=False)   # waits for Enter

# Phase 3 web backend calls:
run_validator(bag_path, config_path, auto_continue=True)    # returns report as string
```

### Dashboard Features

| Feature | Description |
|---|---|
| Pipeline wizard | Web form version of CLI steps 1–9 |
| Map viewer | 3D point cloud rendered in browser (Three.js or Potree) |
| POI editor | Click-to-place POIs on the 3D map, edit names/descriptions |
| Live tracking | WebSocket stream of robot pose overlaid on the map |
| Map library | Browse all saved map runs with metadata |
| OEM export | Download `.pcd`, `.pgm/.yaml`, POI YAML for distribution |

---

## 13. Build and Run (Final)

```bash
cd ros2_rmc_ws
colcon build --packages-select slam_glim --symlink-install
source install/setup.bash
ros2 run slam_glim main
```

---

## 14. Implementation Order

Build and test one step at a time. Suggested order:

| Order | Step | Why first |
|---|---|---|
| 1 | `export_map.py` | Core unique logic — verified binary format, no dependencies |
| 2 | `convert_map.py` | Pure Python — copy from glim_test, adapt path logic |
| 3 | `nodes/pcd_publisher.py` + `nodes/poi_selector.py` | Copy from glim_test |
| 4 | `view_map.launch.py` + RViz config | Wire together nodes 3 |
| 5 | `config_setup.py` | Read user_config.yaml → push to GLIM JSON files |
| 6 | `slam_runner.py` | SLAM launch logic — pipeline select + config review + two modes |
| 7 | `validator.py` | Subprocess + report printing |
| 8 | `bag_convert.py` | Wrap existing shell script |
| 9 | `map_editor_launcher.py` | Simple subprocess wrapper |
| 10 | `main.py` | Wire all steps together into the wizard |
| 11 | `setup.py` + `package.xml` | Finalize build |

---

*Plan created: 2026-05-15*
*Author: Abdullah AlMusalami + Claude*
