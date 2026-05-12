# GLIM Setup

Automated installation script for GLIM 3D SLAM on **Ubuntu 24.04 / ROS2 Jazzy**.
Handles dependency installation, PPA setup, CUDA variant selection, and library fixes in one shot.

---

## Requirements

| | |
|---|---|
| OS | Ubuntu 24.04 |
| ROS | ROS2 Jazzy |
| GPU | NVIDIA GPU with CUDA 12.6 or 13.1 (optional — a no-CUDA build is available) |

---

## Usage

```bash
cd glim_setup

# Make executable (once)
chmod +x setup.sh

# Auto-detect CUDA version from nvidia-smi
./setup.sh

# Or choose a variant manually:
./setup.sh none    # Without CUDA
./setup.sh 12.6    # With CUDA 12.6
./setup.sh 13.1    # With CUDA 13.1
```

---

## GLIM package variants

| Argument | Package installed |
|---|---|
| `none` | `ros-jazzy-glim-ros` |
| `12.6` | `ros-jazzy-glim-ros-cuda12.6` |
| `13.1` | `ros-jazzy-glim-ros-cuda13.1` |

Check your CUDA version with:
```bash
nvidia-smi
```

---

## GTSAM version conflict — important

GLIM requires **GTSAM 4.3a0** (specified in the official GLIM build instructions). It also depends on **gtsam_points** — a separate point cloud extension library by koide3, built on top of GTSAM. The koide3 PPA installs both into `/usr/local/lib/`.

ROS2 Jazzy ships its own older version — **GTSAM 4.2.0** — at `/opt/ros/jazzy/lib/`. When ROS is sourced, it prepends that path to `LD_LIBRARY_PATH`, so the system finds GTSAM 4.2.0 first. GLIM was built against 4.3a0 and will crash if it loads 4.2.0.

To make GLIM load the correct version, `/usr/local/lib` must appear **before** `/opt/ros/jazzy/lib` in the library search path.

**This is handled automatically in `glim.launch.py`** — the launch file sets `LD_LIBRARY_PATH=/usr/local/lib:...` scoped only to the GLIM process. No changes to `~/.bashrc` or any global environment are needed.

---

## What the script does

| Step | Action |
|---|---|
| 1 | Verifies Ubuntu 24.04 and ROS2 Jazzy are present — exits early if not |
| 2 | Detects CUDA version from `nvidia-smi` (or uses the argument you pass) |
| 3 | Adds koide3's PPA — skips if already present |
| 4 | Installs dependencies: `libiridescence-dev`, `libboost-all-dev`, `libglfw3-dev`, `libmetis-dev` |
| 5 | Installs `gtsam_points` (koide3's point cloud extension for GTSAM 4.3a0) from PPA into `/usr/local/lib/` |
| 6 | Installs the GLIM ROS package matching the selected variant |
| 7 | Creates the `libcudart.so.<major>` symlink if missing (CUDA builds only) |
| 8 | Runs `sudo ldconfig` |

The script is **idempotent** — safe to re-run; already-completed steps are skipped.

---

## After installation

```bash
cd ros2_rmc_ws
colcon build --packages-select slam_glim --symlink-install
source install/setup.bash
```

## Verify GLIM is installed and running

```bash
# LD_LIBRARY_PATH is required to pick the correct GTSAM version over ROS Jazzy's bundled one.
# This prefix is only needed when running glim_rosnode directly for testing.
# When using ros2 launch slam_glim glim.launch.py, the launch file sets this automatically.
LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH ros2 run glim_ros glim_rosnode
```

GLIM should load all modules and print lines like:
```
[glim] [info] load libodometry_estimation_gpu.so
[glim] [info] load libsub_mapping.so
[glim] [info] load libglobal_mapping.so
[glim] [info] waiting for odometry estimation
```
Then exit cleanly. If you see those lines — GLIM is working correctly.
