# glim_test Package

ROS2 package for running and validating GLIM 3D SLAM against the Ouster OS1-128 quickstart bag (`bag_test`).
All commands below assume the workspace is built and sourced:

```bash
cd ros2_rmc_ws
colcon build --packages-select glim_test --symlink-install
source install/setup.bash
```

---

## Launch Files

### Run GLIM SLAM + bag + RViz2

```bash
ros2 launch glim_test glim_test.launch.py
```

| Time | Event |
|---|---|
| `t=0s` | `glim_rosnode` starts — Iridescence 3D viewer opens |
| `t=2s` | Bag plays with `--clock` |
| `t=2s` | RViz2 opens with official GLIM config |
| bag end | GLIM auto-saves map dump to `maps/<bag_name>_<YYYYMMDD_HHMMSS>/` |

To switch pipelines (GPU / CPU / LiDAR-only), change `config_path` in the launch file.
See `config/README.md` for the full pipeline and parameter reference.

---

### View a saved map in RViz2

```bash
ros2 launch glim_test view_map.launch.py
```

Converts the PLY map file to PCD (`pcl_ply2pcd`), publishes it as a latched PointCloud2
on `/map_cloud`, and opens RViz2. Change `MAP_PLY` at the top of the launch file to
point at a different run.

---

## GLIM Map Tools

All commands require the GTSAM library path prefix:

```bash
LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
```

Replace `<dump_path>` with the path to a run directory, e.g.:
`maps/bag_test_20260513_131336`

---

### offline_viewer — inspect a saved map

Opens the Iridescence 3D viewer on a finished map dump. Use this to inspect the full
optimized map, trajectory, and submaps after a SLAM run.

```bash
LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH \
  ros2 run glim_ros offline_viewer \
  --ros-args -p dump_path:=<dump_path>
```

---

### map_editor 

Opens an interactive editor on a saved map. 

```bash
LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH \
  ros2 run glim_ros map_editor \
  --ros-args -p dump_path:=<dump_path>
```

---

### glim_rosbag — offline SLAM without bag play

Processes a bag file directly inside GLIM — no `ros2 bag play` or `--clock` needed.
Useful for batch processing or when you want faster-than-realtime processing.

```bash
LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH \
  ros2 run glim_ros glim_rosbag \
  --ros-args \
  -p config_path:=<config_path> \
  -p bag_path:=<bag_path> \
  -p dump_path:=<dump_path>
```

Example using the GPU pipeline:

```bash
LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH \
  ros2 run glim_ros glim_rosbag \
  --ros-args \
  -p config_path:=$(ros2 pkg prefix glim_test)/share/glim_test/config/gpu \
  -p bag_path:=$(pwd)/../bag_test \
  -p dump_path:=$(pwd)/maps/bag_test_offline
```

---

### validator_node — validate sensor input

Checks that LiDAR and IMU topics are formatted correctly for GLIM before running the
full SLAM. Reports any missing fields, wrong frame IDs, or timestamp issues.

```bash
LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH \
  ros2 run glim_ros validator_node \
  --ros-args -p config_path:=<config_path>
```

Then play the bag in another terminal:

```bash
ros2 bag play ../bag_test --clock
```

---

## Saved Map Contents

Each run saves into `maps/<bag_name>_<YYYYMMDD_HHMMSS>/`:

```
maps/bag_test_20260513_131336/
├── 000000/, 000001/, ...   # Individual submaps (point clouds + local poses)
├── graph.bin / graph.txt   # Pose graph with loop closure factors
├── odom_lidar.txt          # Per-frame LiDAR odometry trajectory
├── odom_imu.txt            # Per-frame IMU odometry trajectory
├── traj_lidar.txt          # Full optimized LiDAR trajectory
├── traj_imu.txt            # Full optimized IMU trajectory
├── values.bin              # Optimized pose graph values
├── map_test.ply            # Map exported from offline_viewer or map_editor
├── map_test.pcd            # Converted from PLY by view_map.launch.py
└── config/                 # Config snapshot used for this run
```
