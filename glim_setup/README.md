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

## What the script does

| Step | Action |
|---|---|
| 1 | Verifies Ubuntu 24.04 and ROS2 Jazzy are present — exits early if not |
| 2 | Detects CUDA version from `nvidia-smi` (or uses the argument you pass) |
| 3 | Adds koide3's PPA — skips if already present |
| 4 | Installs dependencies: `libiridescence-dev`, `libboost-all-dev`, `libglfw3-dev`, `libmetis-dev` |
| 5 | Installs GTSAM 4.3.0 from PPA |
| 6 | Installs the GLIM ROS package matching the selected variant |
| 7 | Creates the `libcudart.so.<major>` symlink if missing (CUDA builds only) |
| 8 | Runs `sudo ldconfig` |

The script is **idempotent** — safe to re-run; already-completed steps are skipped.

---

## Troubleshooting

**`nvidia-smi` fails with "Driver/library version mismatch"**
This happens after a kernel update before a reboot. Reboot and re-run. If still broken, pass the variant manually:
```bash
./setup.sh 13.1
```

**`libcudart.so.<major>` symlink not found**
The script searches common locations (Ollama path, `/usr/local/cuda`, system lib). If none are found it prints the exact paths it searched. Find it manually and create the symlink:
```bash
find /usr /usr/local -name 'libcudart.so.13' 2>/dev/null
sudo ln -s <found_path> /usr/local/lib/libcudart.so.13
sudo ldconfig
```

**GTSAM conflict (ROS Jazzy 4.2.0 vs PPA 4.3.0)**
No action needed — `glim.launch.py` automatically prepends `/usr/local/lib` to `LD_LIBRARY_PATH` to force the correct GTSAM version at runtime.

---

## After installation

```bash
cd ros2_rmc_ws
colcon build --packages-select slam_glim --symlink-install
source install/setup.bash
ros2 launch slam_glim glim.launch.py
```
