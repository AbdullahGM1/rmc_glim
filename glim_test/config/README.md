# GLIM Config Files

## Source

All config files here are derived from **GLIM's official default configs**, installed at:

```
/opt/ros/jazzy/share/glim/config/
```

The only modification applied to all three pipelines is in `config_sensors.json`:

```json
"T_lidar_imu": [-0.006, 0.012, -0.008, 0.0, 0.0, 0.0, 1.0]
```

This is the correct LiDAR-IMU extrinsic for the **Ouster OS1-128** used in this test bag.
The default value shipped by GLIM is for the OS0 (`[0.006, -0.012, 0.008, ...]`).

---

## Pipeline Types

GLIM supports three pipeline configurations. Each lives in its own subdirectory so you can
switch pipelines by pointing `config_path` at the appropriate folder.

### `gpu/` — GPU-Accelerated Full SLAM (active)

Uses CUDA for both odometry and map optimization. Requires an NVIDIA GPU.

| Stage | Module |
|---|---|
| Odometry | `libodometry_estimation_gpu.so` — keyframe VGICP on GPU |
| Sub-mapping | `libsub_mapping.so` — VGICP_GPU registration between keyframes |
| Global mapping | `libglobal_mapping.so` — VGICP_GPU loop closure + ISAM2 optimizer |

**Use when:** you have a GPU and want the fastest, most accurate full SLAM.

**To run:**
```bash
ros2 launch glim_test glim_test.launch.py
# launch file already points config_path at this folder
```

---

### `cpu/` — CPU-Only Full SLAM

Same full SLAM pipeline as GPU but runs entirely on CPU. Slower but works without a GPU.

| Stage | Module |
|---|---|
| Odometry | `libodometry_estimation_cpu.so` — keyframe VGICP on CPU |
| Sub-mapping | `libsub_mapping.so` — VGICP (CPU) registration |
| Global mapping | `libglobal_mapping.so` — VGICP (CPU) loop closure + ISAM2 optimizer |

**Use when:** no GPU is available or for debugging on a development machine.

**To run:**
```bash
LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH \
  ros2 run glim_ros glim_rosnode --ros-args \
  -p config_path:=$(pwd)/cpu
```

---

### `lidar_only/` — LiDAR-Only Odometry

No IMU preintegration. Runs CT-ICP (Continuous-Time ICP) purely from LiDAR geometry.
Sub-mapping is a lightweight passthrough with no internal optimization.
Loop closure uses a pose-graph approach rather than dense point cloud registration.

| Stage | Module |
|---|---|
| Odometry | `libodometry_estimation_ct.so` — CT-GICP, no IMU |
| Sub-mapping | `libsub_mapping_passthrough.so` — no internal optimization |
| Global mapping | `libglobal_mapping_pose_graph.so` — explicit loop detection + pose graph |

**Use when:** IMU data is unavailable, unreliable, or not calibrated.
Note: accuracy is generally lower than IMU-aided pipelines on aggressive motion.

**To run:**
```bash
LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH \
  ros2 run glim_ros glim_rosnode --ros-args \
  -p config_path:=$(pwd)/lidar_only
```

---

## Config File Reference

Every pipeline folder contains the same set of files. Here is what each one controls:

### `config.json` — Top-level router

Tells GLIM which file to load for each subsystem. The only meaningful choice is which
variant (gpu / cpu / ct) to use for odometry, sub_mapping, and global_mapping.

```json
"config_odometry":      "config_odometry_gpu.json"
"config_sub_mapping":   "config_sub_mapping_gpu.json"
"config_global_mapping":"config_global_mapping_gpu.json"
```

---

### `config_sensors.json` — Sensor calibration

The most critical file for map correctness.

| Parameter | Value | Description |
|---|---|---|
| `T_lidar_imu` | `[-0.006, 0.012, -0.008, 0,0,0,1]` | LiDAR-IMU extrinsic in TUM pose format — see details below. |
| `imu_acc_noise` | `0.05` | Accelerometer white noise (m/s²/√Hz) |
| `imu_gyro_noise` | `0.02` | Gyroscope white noise (rad/s/√Hz) |
| `imu_bias_noise` | `1e-5` | How fast IMU bias drifts over time |
#### T_lidar_imu — Format Details

The value has **7 numbers** in TUM pose format: `[tx, ty, tz, qx, qy, qz, qw]`

**Translation** (first 3) — physical offset of the LiDAR origin from the IMU origin in meters:

| Field | Value | Meaning |
|---|---|---|
| `tx` | `-0.006` | 6 mm in X |
| `ty` |  `0.012` | 12 mm in Y |
| `tz` | `-0.008` | 8 mm in Z |

**Rotation** (last 4) — quaternion describing the rotational difference between the two sensors:

| Field | Value | Meaning |
|---|---|---|
| `qx` | `0.0` | — |
| `qy` | `0.0` | — |
| `qz` | `0.0` | — |
| `qw` | `1.0` | Identity rotation — LiDAR and IMU axes are perfectly aligned in orientation |

For the OS1-128, the IMU and LiDAR axes point in the same direction — they are only offset
in position. That is why only the translation values are non-zero and the quaternion is
identity `[0, 0, 0, 1]`.

A wrong `T_lidar_imu` will produce a tilted or continuously drifting map.

| `autoconf_perpoint_times` | `true` | Auto-detect per-point timestamps from the Ouster — enables motion deskewing |
| `global_shutter_lidar` | `false` | Ouster is a rolling-shutter LiDAR — per-point timestamps are valid |

---

### `config_ros.json` — ROS interface

Controls how GLIM subscribes to topics and publishes TF.

| Parameter | Value | Description |
|---|---|---|
| `imu_topic` | `/os_cloud_node/imu` | IMU input topic |
| `points_topic` | `/os_cloud_node/points` | LiDAR input topic |
| `imu_frame_id` | `""` | Auto-detected from incoming IMU messages |
| `lidar_frame_id` | `""` | Auto-detected from incoming point cloud messages |
| `base_frame_id` | `""` | Defaults to IMU frame — GLIM tracks the IMU pose |
| `odom_frame_id` | `"odom"` | TF output: `map → odom → base_frame` |
| `map_frame_id` | `"map"` | TF output root frame |
| `enable_local_mapping` | `true` | Enable submap creation |
| `enable_global_mapping` | `true` | Enable loop closure |
| `extension_modules` | see below | Viewer and RViz publisher |

**Extension modules loaded:**
- `libmemory_monitor.so` — logs RAM/VRAM usage
- `libstandard_viewer.so` — opens the Iridescence 3D viewer
- `librviz_viewer.so` — publishes `/glim_ros/map` PointCloud2 for RViz

---

### `config_preprocess.json` — Point cloud filtering

Applied to every incoming scan before it enters the SLAM pipeline.

| Parameter | Value | Description |
|---|---|---|
| `distance_near_thresh` | `0.5 m` | Drop points closer than 0.5 m — removes the robot body from scans |
| `distance_far_thresh` | `100.0 m` | Drop points beyond 100 m — OS1-128 max range is ~120 m |
| `downsample_resolution` | `1.0 m` | Voxel size for downsampling |
| `random_downsample_target` | `10000` | Keep ~10,000 points per scan. OS1-128 produces ~130,000 raw points per scan — this reduces compute load significantly |
| `enable_outlier_removal` | `false` | Statistical outlier removal — off by default |
| `k_correspondences` | `10` | Neighbors used for covariance estimation during GICP |

---

### `config_odometry_gpu.json` — Frame-to-frame tracking (GPU)

Runs at LiDAR frequency (~10 Hz). Matches each new scan against a rolling set of keyframes
using GPU-accelerated Voxelized GICP (VGICP).

| Parameter | Value | Description |
|---|---|---|
| `initialization_mode` | `LOOSE` | Uses IMU + a short LiDAR window to initialize gravity and velocity before tracking. `NAIVE` is faster but just uses gravity direction from the first IMU reading. |
| `smoother_lag` | `5.0 s` | Fixed-lag smoother window — GLIM jointly optimizes the last 5 seconds of poses |
| `voxel_resolution` | `0.25 m` | VGICP voxel size for scan matching — smaller = more precise but slower |
| `voxel_resolution_max` | `0.5 m` | Voxel resolution scales up adaptively at long range |
| `voxelmap_levels` | `2` | Multi-resolution voxel maps — matching at coarse + fine resolution simultaneously |
| `max_num_keyframes` | `15` | Number of keyframes kept active for scan matching |
| `keyframe_max_overlap` | `0.7` | New keyframe inserted when overlap with existing ones drops below 70% |
| `full_connection_window_size` | `2` | Latest pose connected to the last 2 keyframe poses in the factor graph |

---

### `config_odometry_cpu.json` — Frame-to-frame tracking (CPU)

Same concept as GPU odometry but uses CPU VGICP. Key differences:

| Parameter | CPU value | GPU value | Note |
|---|---|---|---|
| `initialization_window_size` | `3.0 s` | `1.0 s` | Longer window needed — CPU initialization is less stable |
| `registration_type` | `GICP` | _(VGICP implicit)_ | CPU version can switch between GICP and VGICP |
| `ivox_resolution` | `1.0 m` | — | iVox spatial hash used instead of GPU voxel maps |

---

### `config_odometry_ct.json` — CT-ICP odometry (LiDAR-only)

Continuous-Time ICP — no IMU. Estimates motion by solving for a smooth trajectory
through each scan using only LiDAR geometry.

| Parameter | Value | Description |
|---|---|---|
| `ivox_resolution` | `1.0 m` | Spatial hash cell size for nearest-neighbor search |
| `max_correspondence_distance` | `2.0 m` | Maximum point-to-point distance to form an ICP correspondence |
| `location_consistency_inf_scale` | `1e-3` | Regularization weight — penalizes abrupt jumps in position |
| `constant_velocity_inf_scale` | `1e3` | Regularization weight — assumes roughly constant velocity between scans |
| `smoother_lag` | `1.0 s` | Shorter than IMU-aided because there's no IMU to bridge gaps |

---

### `config_sub_mapping_gpu.json` — Submap creation (GPU)

Groups keyframes into submaps. Each submap is the atomic unit passed to global mapping.

| Parameter | Value | Description |
|---|---|---|
| `max_num_keyframes` | `15` | A submap is finalized when it accumulates 15 keyframes |
| `enable_optimization` | `false` | Submap poses come directly from odometry — no internal re-optimization |
| `registration_error_factor_type` | `VGICP_GPU` | GPU matching used to build the inter-keyframe factor graph inside the submap |
| `submap_downsample_resolution` | `0.1 m` | Final voxel size of a finished submap — 10 cm detail preserved |
| `submap_target_num_points` | `50000` | Each submap is downsampled to ~50k points before global mapping |

---

### `config_sub_mapping_passthrough.json` — Submap creation (LiDAR-only)

Lightweight submap creation with no internal optimization. Scans are accumulated
into submaps using odometry poses directly, then voxel-filtered.

| Parameter | Value | Description |
|---|---|---|
| `max_num_keyframes` | `50` | Larger submaps (50 frames) since there's no optimization cost |
| `keyframe_update_interval_trans` | `0.1 m` | New keyframe every 10 cm of motion |
| `submap_voxel_resolution` | `0.5 m` | Submap voxel size — coarser than GPU pipeline |
| `submap_target_num_points` | `50000` | Same target point count as GPU pipeline |

---

### `config_global_mapping_gpu.json` — Loop closure (GPU)

Manages all submaps and detects revisited places using point cloud overlap.

| Parameter | Value | Description |
|---|---|---|
| `max_implicit_loop_distance` | `100.0 m` | Only check loop closure between submaps within 100 m of each other |
| `min_implicit_loop_overlap` | `0.2` | Submaps with ≥20% point overlap trigger a loop closure factor |
| `registration_error_factor_type` | `VGICP_GPU` | GPU matching for loop verification |
| `submap_voxel_resolution` | `0.5 m` | Coarser voxels used when matching submaps for loop closure — faster than odometry matching |
| `enable_imu` | `true` | IMU preintegration factors included in the global pose graph |

---

### `config_global_mapping_pose_graph.json` — Loop closure (LiDAR-only)

Explicit loop detection pipeline — searches for candidate loops by proximity,
then validates with ICP, and adds pose graph factors.

| Parameter | Value | Description |
|---|---|---|
| `min_travel_dist` | `50.0 m` | Only search for loops after the robot has travelled 50 m from a submap |
| `max_neighbor_dist` | `5.0 m` | Candidate submaps must be within 5 m in position space |
| `min_inliear_fraction` | `0.5` | ICP validation — at least 50% inlier matches required |
| `odom_factor_stddev` | `1e-3` | Tight odometry factor — CT-ICP is fairly accurate |
| `loop_factor_stddev` | `0.1` | Looser loop factor — loop ICP alignment is less precise |

---

### `config_viewer.json` — Iridescence 3D viewer

Visual settings only — no effect on SLAM quality.

| Parameter | Value | Description |
|---|---|---|
| `viewer_width/height` | `2560×1440` | Viewer window size |
| `default_z_range` | `[-2.0, 4.0]` | Initial vertical clip range in meters |
| `point_size` | `0.025` | Rendered point size in metric units |
| `enable_partial_rendering` | `false` | Partial rendering trades visual smoothness for GPU headroom — leave off on a capable GPU |

---

### `config_logging.json` — Log files

| Parameter | Value | Description |
|---|---|---|
| `log_dir` | `/tmp` | Where GLIM writes log files |
| `max_file_size_kb` | `8192` | Rotate log after 8 MB |
| `max_files` | `10` | Keep the last 10 log files |
