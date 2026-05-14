# DOCKER_PLAN.md — rmc_glim

Dockerize after `slam_glim` is fully working end-to-end.
Keep `glim_setup/` scripts up to date during development — every new `apt install` or config
step added during `slam_glim` work must go into the relevant script immediately.
These scripts are the source of truth for the Dockerfile.

---

## Strategy

| What | Decision |
|---|---|
| Base image | `nvidia/cuda:13.2-devel-ubuntu24.04` (check Docker Hub at build time; if unavailable fall back to `nvidia/cuda:13.1-devel-ubuntu24.04` + run `cuda_setup.sh` on top) |
| ROS2 | Install Jazzy Desktop inside the image via `ros2_setup.sh` steps |
| GLIM | Install `ros-jazzy-glim-ros-cuda13.1` from koide3 PPA (same variant as host) |
| GPU access | NVIDIA Container Toolkit on the host — run container with `--gpus all` |
| RViz2 / GUI | X11 forwarding at runtime |
| Image size | Expected 15–25 GB — normal for this stack |

**GPU drivers are NOT in the image.** They live on the host and are accessed via
`--gpus all`. The CUDA toolkit (libraries/headers) IS in the image.

**CUDA rule:** container CUDA version ≤ host driver's max supported CUDA version.
Host already runs CUDA 13.2, so CUDA 13.2 in the container is safe.

---

## Dockerfile Structure

```dockerfile
# ── Stage: base ───────────────────────────────────────────────────────────────
# Use official NVIDIA CUDA image — CUDA toolkit already included.
# Check https://hub.docker.com/r/nvidia/cuda/tags before building.
# If cuda:13.2-devel-ubuntu24.04 is not available, use 13.1 and run cuda_setup.sh.
FROM nvidia/cuda:13.2-devel-ubuntu24.04

# Avoid interactive prompts during apt
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# ── Locale ────────────────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y locales \
    && locale-gen en_US en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# ── ROS2 Jazzy Desktop ────────────────────────────────────────────────────────
# Mirrors ros2_setup.sh steps 4–7
RUN apt-get update && apt-get install -y software-properties-common curl \
    && add-apt-repository universe \
    && rm -rf /var/lib/apt/lists/*

RUN curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest \
        | grep tag_name | awk -F'"' '{print $4}' | xargs -I{} \
        curl -L -o /tmp/ros2-apt-source.deb \
        "https://github.com/ros-infrastructure/ros-apt-source/releases/download/{}/ros2-apt-source_{}.$(. /etc/os-release && echo ${UBUNTU_CODENAME})_all.deb" \
    && dpkg -i /tmp/ros2-apt-source.deb \
    && rm -f /tmp/ros2-apt-source.deb

RUN apt-get update && apt-get install -y \
    ros-dev-tools \
    ros-jazzy-desktop \
    ros-jazzy-nav2-map-server \
    pcl-tools \
    && rm -rf /var/lib/apt/lists/*

# ── GLIM + dependencies ───────────────────────────────────────────────────────
# Mirrors glim_setup.sh steps 3–7
RUN apt-get install -y curl gpg \
    && curl -s https://koide3.github.io/ppa/setup_ppa.sh | bash

RUN apt-get update && apt-get install -y \
    libiridescence-dev \
    libboost-all-dev \
    libglfw3-dev \
    libmetis-dev \
    libgtsam-points-cuda13.1-dev \
    ros-jazzy-glim-ros-cuda13.1 \
    && ldconfig \
    && rm -rf /var/lib/apt/lists/*

# ── Workspace ─────────────────────────────────────────────────────────────────
WORKDIR /ros2_rmc_ws

# Copy the source packages (bags excluded via .dockerignore)
COPY src/ src/

# Build
RUN /bin/bash -c "source /opt/ros/jazzy/setup.bash \
    && colcon build --packages-select glim_test slam_glim --symlink-install"

# ── Environment ───────────────────────────────────────────────────────────────
# GTSAM version conflict fix — same as what the launch files do at runtime
ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

# Source ROS2 + workspace on every shell
RUN echo "source /opt/ros/jazzy/setup.bash" >> /etc/bash.bashrc \
    && echo "source /ros2_rmc_ws/install/setup.bash" >> /etc/bash.bashrc

CMD ["/bin/bash"]
```

---

## .dockerignore

Exclude bags (large binary files — mount at runtime instead):

```
# Bags — mount at runtime with -v
ros2_bags/
bag_test/

# Build artifacts
build/
install/
log/

# GLIM viewer state
imgui.ini

# Python venvs
**/venv/
ros2_bags/ros1_bag_convert/venv/

# Map dumps — mount at runtime or copy out after run
glim_test/maps/
slam_glim/maps/
maps/
```

---

## Build Command

```bash
cd /home/abdullah/projects/RMC_2.0/ros2_rmc_ws/src/rmc_glim
docker build -t rmc_glim:latest .
```

---

## Run Command

```bash
docker run --gpus all \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v /home/abdullah/projects/RMC_2.0/ros2_rmc_ws/src/rmc_glim/ros2_bags:/ros2_rmc_ws/src/rmc_glim/ros2_bags:ro \
  -v /home/abdullah/projects/RMC_2.0/ros2_rmc_ws/src/rmc_glim/bag_test:/ros2_rmc_ws/src/rmc_glim/bag_test:ro \
  -v /home/abdullah/projects/RMC_2.0/ros2_rmc_ws/src/rmc_glim/glim_test/maps:/ros2_rmc_ws/src/rmc_glim/glim_test/maps \
  -v /home/abdullah/projects/RMC_2.0/ros2_rmc_ws/src/rmc_glim/slam_glim/maps:/ros2_rmc_ws/src/rmc_glim/slam_glim/maps \
  --name rmc_glim \
  rmc_glim:latest
```

Bags are mounted **read-only** (`:ro`). Map output directories are mounted read-write
so saved maps land on the host even after the container exits.

---

## Host Prerequisites (one-time setup)

```bash
# NVIDIA Container Toolkit — required for --gpus all
sudo apt install -y nvidia-container-toolkit
sudo systemctl restart docker

# X11 access for RViz2 / Iridescence viewer
xhost +local:docker
```

---

## Dependency Tracking Rule

Every time a new dependency is added during `slam_glim` development:

| What you install | Where to record it |
|---|---|
| `sudo apt install <pkg>` | `glim_setup/glim_setup.sh` or a new `slam_glim_deps.sh` |
| `pip install <pkg>` | `requirements.txt` in the package directory |
| New `ldconfig` / symlink step | `glim_setup/glim_setup.sh` |
| New env var / `LD_LIBRARY_PATH` hack | Note in CLAUDE.md + add to Dockerfile `ENV` section |

Do this immediately — not retroactively at Docker time.
