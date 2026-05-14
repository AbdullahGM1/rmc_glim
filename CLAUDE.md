# CLAUDE.md — rmc_glim

> **This is the one and only CLAUDE.md for this project.** Do not copy or back it up elsewhere.

## Project Overview

Standalone ROS2 Jazzy workspace for **GLIM 3D SLAM** on the RMC 2.0 robot.
GitHub: `AbdullahGM1/rmc_glim`

Goal: run GLIM against recorded bag data to produce a 3D map of the environment.

---

## Active Focus

**`glim_test` package — fully working (verification sandbox, do not modify).**
**`slam_glim` package — active development: GLIM Map Building Automation System.**

### glim_test status — complete
1. **SLAM** — GLIM builds the 3D map from the OS1-128 bag, auto-saves dump on shutdown
2. **2D map conversion** — `convert_map` reads the exported PCD → `.pgm` + `.yaml`
3. **POI selector** — integrated into `view_map.launch.py`; click points in RViz2, saved as YAML

### slam_glim status — design complete, implementation pending
The full design is documented in the plan file:
`slam_glim/system_diagram/GLIM_Map_Building_Automation_System_PLAN.md`

System diagram (PNG + SVG):
`slam_glim/system_diagram/GLIM_Map_Building_Automation_System.png`

**Phases:**
- **Phase 1** — Docker environment (CUDA 13.2 + ROS2 Jazzy + GLIM). See `DOCKER_PLAN.md`.
- **Phase 2** — Interactive CLI wizard (`ros2 run slam_glim main`). **Active implementation target.**
- **Phase 3** — Web Dashboard (replaces CLI with browser UI). After Phase 2 is complete.

### Approach
Discuss every detail before making any changes. Understand what each config file does,
what each parameter means for our specific sensor setup, and why — then implement.
No guessing. No copy-pasting without understanding.

---

## Workspace Layout

```
ros2_rmc_ws/
├── src/
│   └── rmc_glim/                   ← this repo
│       ├── bag_test/               # Quickstart test bag — Ouster OS1-128
│       │   ├── os1_128_01.db3
│       │   └── metadata.yaml
│       ├── ros2_bags/
│       │   ├── lower_fused/        # Active RMC bag — lower LiDAR fused (~293 s)
│       │   ├── fused_upper/        # Upper LiDAR fused (~112 s)
│       │   ├── merged_bag/         # Both LiDARs merged (~225 s, ROS1-era timestamps)
│       │   ├── ros1_bag_convert/
│       │   │   ├── setup.sh        # One-time venv setup
│       │   │   ├── convert_bag.sh  # Converts a ROS1 .bag → ROS2 .db3
│       │   │   ├── venv/           # Python venv (gitignored)
│       │   │   └── README.md
│       │   ├── qos_override.yaml
│       │   └── running_ros2bag_with_QOS.txt
│       ├── glim_test/              # ROS2 package — GLIM quickstart test (complete)
│       │   ├── config/
│       │   │   ├── gpu/            # GPU full SLAM (active)
│       │   │   ├── cpu/            # CPU full SLAM
│       │   │   ├── lidar_only/     # CT-ICP, no IMU, pose-graph loop closure
│       │   │   └── README.md       # Full config reference
│       │   ├── launch/
│       │   │   ├── glim_test.launch.py   # SLAM: GLIM + bag + RViz2
│       │   │   └── view_map.launch.py    # Map viewer + POI selector
│       │   ├── rviz_config/
│       │   │   ├── glim_ros.rviz         # Official config from koide3/glim_ros2
│       │   │   └── view_map.rviz         # Map viewer + POI markers + PublishPoint tool
│       │   ├── maps/                     # GLIM map dumps — one subdirectory per run
│       │   │   └── <bag_name>_<YYYYMMDD_HHMMSS>/
│       │   │       ├── 000000/, 000001/, ...   # Binary submap dirs
│       │   │       ├── map_test.ply             # Exported from map_editor
│       │   │       ├── map_test.pcd             # Converted by view_map.launch.py
│       │   │       ├── glim_2d_map.pgm          # 2D occupancy grid
│       │   │       └── glim_2d_map.yaml         # Map metadata for nav2_map_server
│       │   ├── POI_Poses/                # Saved POI YAML files (gitignored content)
│       │   ├── glim_test/
│       │   │   ├── __init__.py
│       │   │   ├── pcd_publisher.py      # Reads ASCII PCD, publishes latched PointCloud2
│       │   │   ├── convert_map.py        # Converts PCD → 2D occupancy grid (.pgm + .yaml)
│       │   │   ├── poi_selector.py       # /clicked_point → YAML + /poi_pose + /poi_markers
│       │   │   └── README.md             # Package usage + all GLIM tool commands
│       │   ├── resource/glim_test
│       │   ├── package.xml
│       │   ├── setup.py
│       │   └── setup.cfg
│       ├── slam_glim/              # ROS2 package — GLIM Map Building Automation System
│       │   ├── slam_glim/                        # Python package
│       │   │   ├── __init__.py
│       │   │   ├── main.py                       # CLI wizard entry point
│       │   │   ├── steps/
│       │   │   │   ├── __init__.py
│       │   │   │   ├── bag_convert.py            # Step 1:   ROS1 → ROS2 bag conversion
│       │   │   │   ├── config_setup.py           # Step 1.5: user_config.yaml → GLIM JSON
│       │   │   │   ├── validator.py              # Step 2:   validator_node + report
│       │   │   │   ├── slam_runner.py            # Step 3+4: pipeline select + run GLIM
│       │   │   │   ├── map_editor_launcher.py    # Step 5+6: edit/merge via map_editor
│       │   │   │   ├── export_map.py             # Step 7:   dump → PCD (pure Python)
│       │   │   │   ├── convert_map.py            # Step 8:   PCD → 2D occupancy grid
│       │   │   │   └── poi_viewer.py             # Step 9:   RViz2 + POI registration
│       │   │   ├── nodes/
│       │   │   │   ├── __init__.py
│       │   │   │   ├── pcd_publisher.py          # ROS2 node: PCD → latched PointCloud2
│       │   │   │   └── poi_selector.py           # ROS2 node: /clicked_point → YAML + markers
│       │   │   └── utils/
│       │   │       ├── __init__.py
│       │   │       └── terminal.py               # Colored terminal output helpers
│       │   ├── launch/
│       │   │   ├── view_map.launch.py            # Step 9: pcd_publisher + poi_selector + RViz2
│       │   │   └── map_editor.launch.py          # Steps 5+6: map_editor subprocess
│       │   ├── config/
│       │   │   ├── user_config.yaml              # ← USER EDITS THIS (Step 1.5)
│       │   │   ├── gpu/                          # GLIM GPU full SLAM config
│       │   │   │   ├── config_ros.json           # ← auto-filled by config_setup.py
│       │   │   │   ├── config_sensors.json       # ← auto-filled by config_setup.py
│       │   │   │   └── ... (other GLIM JSON files)
│       │   │   ├── cpu/                          # GLIM CPU full SLAM config
│       │   │   └── lidar_only/                   # GLIM LiDAR-only config
│       │   ├── rviz_config/
│       │   │   └── view_map.rviz
│       │   ├── maps/                             # All GLIM dumps land here
│       │   │   └── <bag_name>_<YYYYMMDD_HHMMSS>/
│       │   │       ├── 000000/, 000001/, ...     # Binary submap dirs
│       │   │       ├── map.pcd                   # Written by export_map.py
│       │   │       ├── map_2d.pgm / map_2d.yaml  # Written by convert_map.py
│       │   │       └── POI_Poses/               # POI YAML files
│       │   ├── system_diagram/                   # Design docs (not part of ROS build)
│       │   │   ├── GLIM_Map_Building_Automation_System.png
│       │   │   ├── GLIM_Map_Building_Automation_System.svg
│       │   │   └── GLIM_Map_Building_Automation_System_PLAN.md
│       │   ├── resource/
│       │   │   └── slam_glim
│       │   ├── package.xml
│       │   ├── setup.py
│       │   └── setup.cfg
│       ├── maps/                   # GLIM map dumps — tracked in repo
│       ├── glim_setup/             # Installation scripts
│       │   ├── install.sh          # Master script — 6 steps including pcl-tools
│       │   ├── driver_setup.sh     # Step 1: NVIDIA driver
│       │   ├── ros2_setup.sh       # Step 2: ROS2 Jazzy Desktop
│       │   ├── cuda_setup.sh       # Step 3: CUDA 13.2 toolkit
│       │   ├── glim_setup.sh       # Step 4: GLIM dependencies + package
│       │   └── README.md
│       ├── .gitignore
│       ├── .gitattributes          # Git LFS tracking for *.db3 / *.bag
│       ├── CLAUDE.md
│       └── README.md
└── build/                          # Generated by colcon — never inside src/
└── install/                        # Generated by colcon — never inside src/
```

**IMPORTANT:** Always run `colcon build` from `ros2_rmc_ws/`, never from inside the package directory.

---

## glim_test Package

### Build and Run

```bash
cd ros2_rmc_ws
colcon build --packages-select glim_test --symlink-install
source install/setup.bash
```

### Executables

| Executable | Command | Purpose |
|---|---|---|
| `glim_test.launch.py` | `ros2 launch glim_test glim_test.launch.py` | Run GLIM SLAM on bag |
| `view_map.launch.py` | `ros2 launch glim_test view_map.launch.py` | View 3D map + select POIs |
| `convert_map` | `ros2 run glim_test convert_map` | Convert PCD → 2D occupancy grid |

---

## GLIM SLAM — glim_test.launch.py

```bash
ros2 launch glim_test glim_test.launch.py
```

| Time | Event |
|---|---|
| `t=0s` | GLIM starts — Iridescence 3D viewer opens, waits for data |
| `t=2s` | Bag plays with `--clock` |
| `t=2s` | RViz2 opens with official GLIM config |
| bag end | GLIM auto-saves map dump to `glim_test/maps/<bag_name>_<YYYYMMDD_HHMMSS>/` |

### Map Saving — dump_path

`glim_rosnode` is launched with `dump_path` pointing to a pre-created timestamped directory:

```python
run_dir = maps/<bag_name>_<YYYYMMDD_HHMMSS>
os.makedirs(run_dir, exist_ok=True)   # created before GLIM starts
# passed as: -p dump_path:=run_dir
```

When GLIM shuts down it auto-saves there. No copy step needed.

---

## Map Viewer + POI Selector — view_map.launch.py

```bash
ros2 launch glim_test view_map.launch.py
```

**What it does:**
1. Converts `MAP_PLY` → ASCII PCD using `pcl_ply2pcd -format 0` (skipped if PCD already exists)
2. Publishes `static_transform_publisher` for `map → odom` (so RViz fixed frame resolves without a live SLAM node)
3. `pcd_publisher` reads the PCD, publishes a latched `PointCloud2` on `/map_cloud`
4. `poi_selector` listens on `/clicked_point`, saves POIs to YAML, publishes `/poi_pose` + `/poi_markers`
5. RViz2 opens (2s delay) with `view_map.rviz`

**Switching maps:** change `MAP_PLY` at the top of the launch file.

### How to select POIs

1. Launch `view_map.launch.py`
2. In RViz2, select the **Publish Point** tool (crosshair icon in toolbar)
3. Click any point on the 3D cloud
4. A red sphere + label appears; the YAML file is updated automatically
5. Repeat for additional POIs

### POI file format

Saved to `glim_test/POI_Poses/glim_<map_name>_<YYYYMMDD_HHMMSS>.yaml`:

```yaml
# POIs — glim_bag_test_20260513_131336_20260513_143021
pois:
  - id: 1
    name: POI_1
    timestamp: '2026-05-13T14:30:21'
    frame_id: map
    position: {x: 1.234, y: 2.345, z: -1.123}
    orientation: {x: 0.0, y: 0.0, z: 0.0, w: 1.0}
```

---

## 2D Map Conversion — convert_map

```bash
ros2 run glim_test convert_map
```

Reads `MAP_PCD` (hardcoded at the top of `convert_map.py`), projects the 3D point cloud
to a 2D occupancy grid, and saves `.pgm` + `.yaml` alongside the PCD in the same run directory.

**Switching maps:** change `MAP_PCD` at the top of `convert_map.py`.

### Pipeline

1. **Read PCD** — parses `FIELDS` header, extracts `x`, `y`, `z` columns (ignores `intensity`)
2. **Voxel downsample** at 0.05 m — removes redundant cells
3. **Ground detection** — z-histogram on the bottom 1.5 m (from 1st percentile, not `z_min`, to ignore outlier points); finds the densest bin = floor peak; walks up until counts drop below 20% = top of ground cluster
4. **Height filter** — keeps points from `max(ground_top, ground_peak + 0.30 m)` to `ground_peak + 3.0 m`
5. **Grid allocation** — 205 (unknown gray) filled grid, 0.05 m/pixel, 1 m padding
6. **Mark occupied** — project x/y, set cells to 0 (black)
7. **Save** — `np.flipud` before writing (ROS2: row 0 = world y_max); `.yaml` origin = bottom-left corner

**Why 1st percentile instead of `z_min`:** the exported PLY/PCD map can contain sparse outlier
points below the actual floor (e.g., at -6.25 m while the real floor is at -1.65 m). Using
`z_min` puts the search window entirely in empty space and misses the real ground peak.

**Output convention** matches `nav2_map_server map_saver_cli`:
- Pixel `0` = black = occupied
- Pixel `205` = gray = unknown
- Pixel `254` = white = free (not written — no ray casting)

---

## Config Pipelines

All config files are copied from GLIM's installed defaults at
`/opt/ros/jazzy/share/glim/config/` and organized into three subdirectories.
See `glim_test/config/README.md` for the full parameter reference.

| Pipeline | Directory | Odometry | Sub-mapping | Global mapping |
|---|---|---|---|---|
| GPU full SLAM | `config/gpu/` | `libodometry_estimation_gpu.so` | VGICP_GPU | VGICP_GPU loop closure |
| CPU full SLAM | `config/cpu/` | `libodometry_estimation_cpu.so` | VGICP CPU | VGICP CPU loop closure |
| LiDAR-only | `config/lidar_only/` | `libodometry_estimation_ct.so` | Passthrough | Pose graph |

The active pipeline is `gpu/`. To switch, change the `config_path` in `glim_test.launch.py`.

---

## Sensor Config — bag_test (OS1-128)

| Parameter | Value |
|---|---|
| `imu_topic` | `/os_cloud_node/imu` |
| `points_topic` | `/os_cloud_node/points` |
| `T_lidar_imu` | `[-0.006, 0.012, -0.008, 0.0, 0.0, 0.0, 1.0]` |

**`T_lidar_imu` format** — TUM pose format: `[tx, ty, tz, qx, qy, qz, qw]`
- Translation: LiDAR origin offset from IMU origin in meters
- Rotation: quaternion — identity `[0,0,0,1]` means axes are aligned, only position differs
- Wrong value → tilted or drifting map

---

## slam_glim Package — GLIM Map Building Automation System

### Overview

`slam_glim` is the production ROS2 package for the RMC 2.0 robot. It implements a 3-phase system:

| Phase | Name | Status |
|---|---|---|
| **Phase 1** | Docker environment (CUDA 13.2 + ROS2 Jazzy + GLIM) | Planned — see `DOCKER_PLAN.md` |
| **Phase 2** | Interactive CLI wizard — full bag-to-POI pipeline in one terminal command | **Active implementation target** |
| **Phase 3** | Web dashboard — browser UI, 3D map viewer, live tracking, OEM sharing | After Phase 2 |

Full design plan: `slam_glim/system_diagram/GLIM_Map_Building_Automation_System_PLAN.md`
System diagram: `slam_glim/system_diagram/GLIM_Map_Building_Automation_System.png`

### Build and Run

```bash
cd ros2_rmc_ws
colcon build --packages-select slam_glim --symlink-install
source install/setup.bash
ros2 run slam_glim main
```

Always build with `--symlink-install` — `os.path.realpath(__file__)` must resolve to `src/`, not `install/`.

### The Full Pipeline

The wizard runs as a single terminal session. Each step asks the user a question, launches tools as subprocesses, and moves forward automatically.

```
[1]   Bag Conversion      — Is this a ROS1 .bag? → auto-convert if yes
[1.5] Sensor Config       — Open user_config.yaml, fill topics + T_lidar_imu
                            System auto-fills all GLIM JSON config files
[2]   Sensor Validation   — Run validator_node → human reviews report → fix if needed
[3a]  SLAM Pipeline       — Select: [1] GPU  [2] CPU  [3] LiDAR-only
[3b]  Config Review       — Show all settings, confirm before SLAM starts
[4]   SLAM Mode           — [1] Live viewer (glim_rosnode + bag play)
                            [2] Fast offline (glim_rosbag, no viewer)
                            → GLIM runs → dump auto-saved
[5]   Edit/Modify Map     — Open map_editor → loop until done
[6]   Merge Maps          — Open map_editor with two dumps → user merges
[7]   Export Map          — AUTOMATED: dump → PCD (pure Python, no GUI, no PLY)
[8]   2D Map              — PCD → .pgm + .yaml occupancy grid
[9]   POI Registration    — RViz2 + pcd_publisher + poi_selector
```

### Step 1.5 — Sensor Config (`user_config.yaml`)

The user edits **one YAML file** — never the GLIM JSON files directly.
`config_setup.py` reads it and auto-fills all six affected JSON files (gpu + cpu + lidar_only pipelines).

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

**Only these three fields go in `user_config.yaml`** — all other GLIM config parameters use correct defaults for the RMC robot and must not be changed without understanding:

| Field | Description | RMC 2.0 value |
|---|---|---|
| `imu_topic` | IMU topic in the bag | `/imu/gravity` |
| `lidar_topic` | LiDAR topic in the bag | `/velodyne_points` |
| `T_lidar_imu` | LiDAR-to-IMU extrinsic `[tx,ty,tz,qx,qy,qz,qw]` | `[0,0,0,0.035460,0.008223,0,0.999337]` |

The `T_lidar_imu` quaternion cancels the 4.17° tilt from the gravity vector — see **RMC 2.0 Map Orientation** section below.

**JSON files auto-filled by `config_setup.py`:**

```
user_config.yaml
  └─ config/gpu/config_ros.json        ← imu_topic, points_topic
  └─ config/gpu/config_sensors.json   ← T_lidar_imu
  └─ config/cpu/config_ros.json
  └─ config/cpu/config_sensors.json
  └─ config/lidar_only/config_ros.json
  └─ config/lidar_only/config_sensors.json
```

### Step 7 — Export Map (Dump → PCD, No GUI)

GLIM's offline_viewer and map_editor only expose PLY export through the GUI — there is no CLI flag (confirmed by checking `--help` and binary symbols). The dump binary format is directly parseable in Python, bypassing the GUI entirely.

**Dump format** (verified against actual GLIM output):
- Each submap dir (`000000/`, `000001/`, ...) contains:
  - `points_compact.bin` — raw points as **float32 XYZ**, 12 bytes/point (no intensity)
  - `data.txt` — contains `T_world_origin` as a 4×4 transform matrix (text format)

**Algorithm in `export_map.py`:**
```python
all_points = []
for submap_dir in sorted(glob(dump_path + "/[0-9]*/")):
    T = parse_T_world_origin(submap_dir + "/data.txt")           # 4x4 np.array
    pts = np.fromfile(submap_dir + "/points_compact.bin", dtype=np.float32).reshape(-1, 3)
    pts_h = np.hstack([pts, np.ones((len(pts), 1), dtype=np.float32)])
    pts_world = (T @ pts_h.T).T[:, :3]
    all_points.append(pts_world)
all_points = np.vstack(all_points)
# voxel downsample 0.05m → write ASCII PCD v0.7 to dump_path/map.pcd
```

### SLAM Pipeline Options

| Pipeline | Config dir | Odometry | Use when |
|---|---|---|---|
| GPU | `config/gpu/` | VGICP_GPU — CUDA | Default for RMC robot (has NVIDIA GPU) |
| CPU | `config/cpu/` | VGICP CPU | No CUDA available |
| LiDAR-only | `config/lidar_only/` | CT-ICP, no IMU | Bag has no IMU data |

Pipeline is selected interactively each time SLAM is run — not hardcoded.

### SLAM Modes

| Mode | Tool | Viewer | Speed |
|---|---|---|---|
| Live viewer | `glim_rosnode` + `ros2 bag play` | Iridescence 3D viewer opens | Real-time |
| Fast offline | `glim_rosbag` | No viewer | Faster than real-time |

### GTSAM Version Fix (Applied in All GLIM Subprocesses)

GLIM needs GTSAM 4.3.0 at `/usr/local/lib/`. ROS Jazzy ships 4.2.0 at `/opt/ros/jazzy/lib/` which takes precedence. Every subprocess that launches a GLIM tool sets:

```python
env = os.environ.copy()
env["LD_LIBRARY_PATH"] = "/usr/local/lib:" + env.get("LD_LIBRARY_PATH", "")
subprocess.run([...], env=env)
```

Applied in: `validator.py`, `slam_runner.py`, `map_editor_launcher.py`. Not needed for pure Python steps.

### Phase 3 Design Constraint

All step modules accept user decisions as **function parameters** — no `input()` calls inside them. This allows the web dashboard backend (Phase 3) to call the exact same modules:

```python
# Phase 2 CLI:     prompts user via terminal
# Phase 3 backend: passes decisions programmatically, returns report as string
run_validator(bag_path, config_path, auto_continue=True)
```

### Implementation Order

| Order | File | Why |
|---|---|---|
| 1 | `steps/export_map.py` | Core unique logic — binary format verified, no dependencies |
| 2 | `steps/convert_map.py` | Pure Python — copy + adapt from glim_test |
| 3 | `nodes/pcd_publisher.py` + `nodes/poi_selector.py` | Copy from glim_test |
| 4 | `launch/view_map.launch.py` + `rviz_config/view_map.rviz` | Wire nodes together |
| 5 | `steps/config_setup.py` | Read user_config.yaml → push to GLIM JSON files |
| 6 | `steps/slam_runner.py` | GLIM launch: pipeline select + config review + two modes |
| 7 | `steps/validator.py` | Subprocess + report printing |
| 8 | `steps/bag_convert.py` | Wrap existing shell script |
| 9 | `steps/map_editor_launcher.py` | Simple subprocess wrapper |
| 10 | `main.py` | Wire all steps into the wizard |
| 11 | `setup.py` + `package.xml` | Finalize build |

### `setup.py` Entry Points

```python
entry_points={
    'console_scripts': [
        'main          = slam_glim.main:main',
        'pcd_publisher = slam_glim.nodes.pcd_publisher:main',
        'poi_selector  = slam_glim.nodes.poi_selector:main',
        'convert_map   = slam_glim.steps.convert_map:main',
        'export_map    = slam_glim.steps.export_map:main',
    ],
},
```

### What to Reuse from `glim_test`

| Component | Source | Action |
|---|---|---|
| `pcd_publisher` | `glim_test/glim_test/pcd_publisher.py` | Copy to `slam_glim/nodes/` |
| `poi_selector` | `glim_test/glim_test/poi_selector.py` | Copy to `slam_glim/nodes/` |
| `convert_map` pipeline | `glim_test/glim_test/convert_map.py` | Copy logic to `slam_glim/steps/convert_map.py` |
| `view_map.rviz` | `glim_test/rviz_config/view_map.rviz` | Copy to `slam_glim/rviz_config/` |
| GLIM config files | `glim_test/config/gpu/`, `cpu/`, `lidar_only/` | Copy entire directories to `slam_glim/config/` |

`glim_test` remains unchanged — it is the verified testing sandbox.

---

## GLIM Map Tools

All require the GTSAM prefix: `LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH`

See `glim_test/glim_test/README.md` for full usage of all tools.

| Tool | Command | Use |
|---|---|---|
| `offline_viewer` | `ros2 run glim_ros offline_viewer --ros-args -p dump_path:=<path>` | Inspect finished map in Iridescence viewer |
| `map_editor` | `ros2 run glim_ros map_editor --ros-args -p dump_path:=<path>` | Manually add/remove loop closures, re-optimize; export PLY |
| `glim_rosbag` | `ros2 run glim_ros glim_rosbag --ros-args -p config_path:=... -p bag_path:=... -p dump_path:=...` | Run SLAM offline on a bag without `ros2 bag play` |
| `validator_node` | `ros2 run glim_ros validator_node --ros-args -p config_path:=<path>` | Validate sensor topics before a SLAM run |

---

## GTSAM Version Conflict

GLIM needs GTSAM 4.3.0 (from koide3's PPA at `/usr/local/lib/`).
ROS Jazzy ships GTSAM 4.2.0 at `/opt/ros/jazzy/lib/` which takes precedence when ROS is sourced.

**Fix:** the launch file sets `LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH` scoped
to the GLIM process only. No changes to `~/.bashrc` needed.

---

## Available Bags

| Bag | Path | Duration | Topics | Notes |
|---|---|---|---|---|
| bag_test | `bag_test/` | ~115 s | `/os_cloud_node/points`, `/os_cloud_node/imu` | **Quickstart test bag — Ouster OS1-128** |
| lower_fused | `ros2_bags/lower_fused/` | ~293 s | `/velodyne_points`, `/imu/gravity` | RMC 2.0 primary bag |
| fused_upper | `ros2_bags/fused_upper/` | ~112 s | `/velodyne_points`, `/imu/gravity` | RMC 2.0 upper LiDAR |
| merged_bag | `ros2_bags/merged_bag/` | ~225 s | `/velodyne_points`, `/imu/gravity` | ROS1-era timestamps — use with caution |

**Do not loop bags** (`-l` flag) — GLIM crashes when sim time jumps backwards.

---

## RMC 2.0 Bag Topics

| Topic | Type | Count (lower_fused) | Notes |
|---|---|---|---|
| `/velodyne_points` | `sensor_msgs/PointCloud2` | 5,827 | Primary LiDAR input to GLIM |
| `/imu` | `sensor_msgs/Imu` | 29,387 | **Gravity-subtracted** — do NOT use for GLIM |
| `/imu/gravity` | `sensor_msgs/Imu` | 29,388 | **Raw gravity vector** — use this for GLIM |
| `/tf_static` | `tf2_msgs/TFMessage` | 1 | Full arm joint chain + `chassis_link → imu_link` |
| `/tf` | `tf2_msgs/TFMessage` | 7,346 | Dynamic arm/flipper joints only |
| `/odom/raw` | `nav_msgs/Odometry` | 7,348 | Wheel odometry — not used by GLIM |
| `/scan` | `sensor_msgs/LaserScan` | 5,827 | 2D scan — not used by GLIM |

### IMU Topics — Critical Detail

```
/imu         → linear_acceleration ≈ [0.06, 0.0, -0.07] m/s²  ← gravity subtracted (≈0)
/imu/gravity → linear_acceleration ≈ [-0.16, 0.69, 9.71] m/s² ← raw gravity vector
```

**Always use `/imu/gravity`** as `imu_topic` in `config_ros.json`. Using `/imu` causes a
randomly-oriented or flipped map — GLIM cannot determine the "up" direction without gravity.

---

## RMC 2.0 TF Frame Hierarchy

```
map
 └── odom              (published by glim_rosnode — updated with loop closure)
      └── base_link    (published by glim_rosnode — GPU VGICP odometry)
           └── velodyne  (from bag's /tf_static — arm joint chain)
```

`/tf_static` from the bag provides:
```
base_link → chassis_link → arm_flange_link → ... → velodyne_base_link → velodyne
chassis_link → imu_link   (translation: x=0.424, y=0.007, z=-0.032 — no rotation)
```

No static transform override is needed in the launch file — adding one causes a TF conflict.

---

## RMC 2.0 Map Orientation — T_lidar_imu

The gravity vector from `/imu/gravity` is `[-0.16, 0.69, 9.71]` — not perfectly vertical.
The 0.69 y-component causes a ~4.17° tilt. `T_lidar_imu` in `config_sensors.json` cancels this:

```json
"T_lidar_imu": [0.0, 0.0, 0.0, 0.035460, 0.008223, 0.0, 0.999337]
```

Format: `[tx, ty, tz, qx, qy, qz, qw]`.

Recompute if a new bag is recorded with a different robot orientation:

```python
import math
g = [-0.16, 0.69, 9.71]
mag = math.sqrt(sum(x**2 for x in g))
v1 = [x/mag for x in g]
v2 = [0.0, 0.0, 1.0]
axis = [v1[1]*v2[2]-v1[2]*v2[1], v1[2]*v2[0]-v1[0]*v2[2], v1[0]*v2[1]-v1[1]*v2[0]]
axis_mag = math.sqrt(sum(x**2 for x in axis))
axis_n = [x/axis_mag for x in axis]
theta = math.atan2(axis_mag, sum(a*b for a,b in zip(v1,v2)))
qw = math.cos(theta/2); s = math.sin(theta/2)
print([0,0,0, axis_n[0]*s, axis_n[1]*s, axis_n[2]*s, qw])
```

---

## Installation (Fresh Machine)

All system dependencies are handled by scripts in `glim_setup/`. Run in order:

```bash
cd glim_setup
./install.sh 13.1   # runs all 6 steps — reboots when needed, re-run after each reboot
```

Steps: NVIDIA driver → ROS2 Jazzy → CUDA 13.2 → GLIM → pcl-tools → Git LFS (bags)

Or manually:
```bash
./driver_setup.sh        # NVIDIA driver — REBOOT after
./ros2_setup.sh          # ROS2 Jazzy Desktop — restart terminal after
./cuda_setup.sh          # CUDA 13.2 toolkit
./glim_setup.sh 13.1     # GLIM + dependencies
sudo apt install -y pcl-tools                              # for view_map.launch.py
sudo apt install -y git-lfs && git lfs install && git lfs pull  # bag files (~3.3 GB)
```

See `glim_setup/README.md` for full details.

---

## ROS1 → ROS2 Bag Conversion

```bash
cd ros2_bags/ros1_bag_convert
./setup.sh                              # one-time venv setup
./convert_bag.sh /path/to/file.bag      # output lands in ros2_bags/<bag_name>/
```

---

## Git and Large Files

### .gitignore key entries

| Pattern | Reason |
|---|---|
| `ros2_bags/ros1_bag_convert/venv/` | Local Python venv |
| `*.db3` / `*.bag` | Tracked via Git LFS |
| `imgui.ini` | Auto-generated GLIM viewer window layout — machine-specific |

### Git LFS

Bag files (`.db3`) are tracked with Git LFS. On a fresh clone:

```bash
sudo apt install -y git-lfs
git lfs install
git lfs pull   # downloads ~3.3 GB of bag data
```

---

## Common Commands

```bash
# Kill all ROS2 processes
pkill -f ros2

# Check TF tree
ros2 run tf2_tools view_frames

# Echo a specific transform
ros2 run tf2_ros tf2_echo base_link velodyne

# Check topic QoS
ros2 topic info /velodyne_points --verbose

# Echo IMU gravity (for T_lidar_imu calibration)
ros2 topic echo /imu/gravity --once
```
