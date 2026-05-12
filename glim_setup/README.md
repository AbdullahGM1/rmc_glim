# GLIM Setup

Automated installation scripts for GLIM 3D SLAM on **Ubuntu 24.04 / ROS2 Jazzy**.
Run the four scripts in order on a fresh machine to get a fully working GLIM setup.

---

## Requirements

| | |
|---|---|
| OS | Ubuntu 24.04 |
| GPU | NVIDIA GPU with CUDA 12.6 or 13.1+ (optional — a no-CUDA build is available) |

---

## Usage

### Option A — Single command (recommended)

```bash
cd glim_setup
chmod +x install.sh
./install.sh        # auto-detect CUDA
./install.sh 13.1   # or specify variant manually
```

`install.sh` detects what is already installed and runs only the missing steps.
The only interruption is a mandatory reboot after the NVIDIA driver install — it will
tell you when to reboot and resume from where it left off when you re-run it.

Also installs `git-lfs` and pulls the bag files (~3.3 GB) automatically.

---

### Option B — Run each script manually

### Step 1 — Install NVIDIA driver

```bash
cd glim_setup
chmod +x driver_setup.sh
./driver_setup.sh
```

Installs the recommended NVIDIA driver for your GPU using Ubuntu's `ubuntu-drivers` tool.

**Reboot required after this step before continuing.**

Skip if `nvidia-smi` already returns output.

### Step 2 — Install ROS2 Jazzy Desktop

```bash
chmod +x ros2_setup.sh
./ros2_setup.sh
```

Installs the full ROS2 Jazzy Desktop from the official ROS2 apt source. Includes RViz2, rqt,
ros2cli, and all GUI tools. Adds `source /opt/ros/jazzy/setup.bash` to `~/.bashrc`.

Restart your terminal after this step before continuing.

Skip if ROS2 Jazzy is already installed at `/opt/ros/jazzy`.

### Step 3 — Install CUDA toolkit

```bash
chmod +x cuda_setup.sh
./cuda_setup.sh
```

Installs CUDA 13.2 from NVIDIA's official repository. Places `libcudart.so.13` in a standard
path the dynamic linker finds automatically. Verifies GLIM can access it before finishing.

Skip if the CUDA toolkit is already installed via the official NVIDIA repo.

### Step 4 — Install GLIM

```bash
chmod +x glim_setup.sh

# Auto-detect CUDA version from nvidia-smi
./glim_setup.sh

# Or choose a variant manually:
./glim_setup.sh none    # Without CUDA
./glim_setup.sh 12.6    # With CUDA 12.6
./glim_setup.sh 13.1    # With CUDA 13.1
```

### Step 5 — Download bag files (Git LFS)

The bag files (`.db3`) are stored in Git LFS. Without this step they exist as 130-byte
pointer files and `ros2 bag play` will fail.

```bash
sudo apt install -y git-lfs
git lfs install
cd ..
git lfs pull
```

Total download: ~3.3 GB (`lower_fused` 1.6 GB, `merged_bag` 1.1 GB, `fused_upper` 623 MB).

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

## What each script does

### driver_setup.sh

| Step | Action |
|---|---|
| 1 | Verifies Ubuntu 24.04 — exits early if not |
| 2 | Checks if NVIDIA driver is already working (`nvidia-smi`) — exits early if so |
| 3 | Runs `apt update && apt upgrade` |
| 4 | Installs `ubuntu-drivers-common` |
| 5 | Lists available NVIDIA drivers for your GPU |
| 6 | Installs the recommended driver via `ubuntu-drivers install` (pre-built, signed, Secure Boot compatible) |
| 7 | Verifies the driver package is present in dpkg |

**A reboot is required after this script before running `cuda_setup.sh`.**

### ros2_setup.sh

| Step | Action |
|---|---|
| 1 | Verifies Ubuntu 24.04 — exits early if not |
| 2 | Checks if ROS2 Jazzy is already installed — exits early if so |
| 3 | Sets locale to `en_US.UTF-8` |
| 4 | Enables the `universe` apt repository |
| 5 | Adds the official ROS2 apt source |
| 6 | Installs `ros-dev-tools` |
| 7 | Installs `ros-jazzy-desktop` (full desktop — RViz2, rqt, all GUI tools) |
| 8 | Adds `source /opt/ros/jazzy/setup.bash` to `~/.bashrc` |
| 9 | Verifies the installation: `/opt/ros/jazzy`, `ros2` CLI, `rviz2`, and `~/.bashrc` entry |

### cuda_setup.sh

| Step | Action |
|---|---|
| 1 | Verifies Ubuntu 24.04 and NVIDIA driver are present |
| 2 | Checks if CUDA 13.2 is already installed — exits early if so |
| 3 | Adds NVIDIA's official CUDA repository via `cuda-keyring` |
| 4 | Installs `cuda-toolkit-13-2` — places `libcudart.so.13` in `/usr/local/cuda-13.2/lib64/` |
| 5 | Runs `ldconfig` to update the linker cache (the apt package registers its own entry during install) |
| 6 | Verifies `nvcc` and `libcudart.so.13` are found by the linker |

### glim_setup.sh

| Step | Action |
|---|---|
| 1 | Verifies Ubuntu 24.04 and ROS2 Jazzy are present — exits early if not |
| 2 | Detects CUDA version from `nvidia-smi` (or uses the argument you pass) |
| 3 | Adds koide3's PPA — skips if already present |
| 4 | Installs dependencies: `libiridescence-dev`, `libboost-all-dev`, `libglfw3-dev`, `libmetis-dev` |
| 5 | Installs `gtsam_points` (koide3's point cloud extension for GTSAM 4.3a0) from PPA into `/usr/local/lib/` |
| 6 | Installs the GLIM ROS package matching the selected variant |
| 7 | Runs `sudo ldconfig` |

Both scripts are **idempotent** — safe to re-run; already-completed steps are skipped.

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
[glim] [info] config_path: /opt/ros/jazzy/share/glim/config
[glim] [info] load libodometry_estimation_gpu.so
[glim] [info] load libsub_mapping.so
[glim] [info] load libglobal_mapping.so
[glim] [info] load libmemory_monitor.so
[glim] [info] load libstandard_viewer.so
[glim] [info] load librviz_viewer.so
```
Then exit cleanly. If you see those lines — GLIM is working correctly.
