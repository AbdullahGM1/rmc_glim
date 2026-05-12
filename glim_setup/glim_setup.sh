#!/usr/bin/env bash
# GLIM installation script — Ubuntu 24.04 / ROS2 Jazzy only
#
# Usage:
#   ./setup.sh              # auto-detect CUDA version from nvidia-smi
#   ./setup.sh none         # install without CUDA
#   ./setup.sh 12.6         # install with CUDA 12.6
#   ./setup.sh 13.1         # install with CUDA 13.1
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()   { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
banner() { echo -e "\n${GREEN}══ $* ${NC}"; }

# ── Step 1: Verify system ─────────────────────────────────────────────────────
banner "Step 1 — Verify system (Ubuntu 24.04 / ROS2 Jazzy)"

# Ubuntu version check
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    if [[ "$VERSION_ID" != "24.04" ]]; then
        error "This script requires Ubuntu 24.04. Detected: $PRETTY_NAME"
    fi
    info "OS: $PRETTY_NAME — OK"
else
    error "/etc/os-release not found. Cannot verify Ubuntu version."
fi

# ROS Jazzy check
if [[ ! -d /opt/ros/jazzy ]]; then
    error "ROS2 Jazzy not found at /opt/ros/jazzy. Install it first:\n       https://docs.ros.org/en/jazzy/Installation.html"
fi
info "ROS2 Jazzy: found at /opt/ros/jazzy — OK"

# ── Step 2: Select CUDA variant ───────────────────────────────────────────────
banner "Step 2 — CUDA variant"

CUDA_VARIANT=""   # none | 12.6 | 13.1

if [[ $# -ge 1 ]]; then
    ARG="$1"
    case "$ARG" in
        none)  CUDA_VARIANT="none" ;;
        12.6)  CUDA_VARIANT="12.6" ;;
        13.1)  CUDA_VARIANT="13.1" ;;
        *)     error "Unknown variant: '$ARG'. Valid options: none | 12.6 | 13.1" ;;
    esac
    info "Using user-supplied variant: $CUDA_VARIANT"
else
    # Auto-detect from nvidia-smi
    if ! command -v nvidia-smi &>/dev/null; then
        error "nvidia-smi not found.\n       Pass a variant manually: ./setup.sh none | 12.6 | 13.1"
    fi

    NVOUT=$(nvidia-smi 2>&1) || true
    CUDA_VERSION=$(echo "$NVOUT" | grep -oP "CUDA Version: \K[0-9]+\.[0-9]+" || true)

    if [[ -z "$CUDA_VERSION" ]]; then
        warn "nvidia-smi ran but could not parse CUDA version."
        warn "Output: $NVOUT"
        warn "This often means a driver/kernel mismatch — try rebooting first."
        error "Or pass a variant manually: ./setup.sh none | 12.6 | 13.1"
    fi

    info "Auto-detected CUDA version: $CUDA_VERSION"
    CUDA_MAJOR=$(echo "$CUDA_VERSION" | cut -d. -f1)
    CUDA_MINOR=$(echo "$CUDA_VERSION" | cut -d. -f2)

    if   [[ "$CUDA_MAJOR" -ge 13 ]];                             then CUDA_VARIANT="13.1"
    elif [[ "$CUDA_MAJOR" -eq 12 && "$CUDA_MINOR" -ge 6 ]];     then CUDA_VARIANT="12.6"
    else
        warn "CUDA $CUDA_VERSION is below 12.6. No matching CUDA package available."
        warn "Falling back to the non-CUDA build. Pass './setup.sh none' to confirm."
        CUDA_VARIANT="none"
    fi
fi

# Resolve package names from variant
if [[ "$CUDA_VARIANT" == "none" ]]; then
    GLIM_PKG="ros-jazzy-glim-ros"
    GTSAM_PKG="libgtsam-points-dev"
    info "Selected: no-CUDA build"
else
    GLIM_PKG="ros-jazzy-glim-ros-cuda${CUDA_VARIANT}"
    GTSAM_PKG="libgtsam-points-cuda${CUDA_VARIANT}-dev"
    info "Selected: CUDA ${CUDA_VARIANT} build"
fi

# ── Step 3: Add koide3 PPA ────────────────────────────────────────────────────
banner "Step 3 — koide3 PPA"

if apt-cache policy 2>/dev/null | grep -q "koide3"; then
    info "koide3 PPA already present — skipping."
else
    info "Adding koide3 PPA..."
    sudo apt install -y curl gpg
    curl -s https://koide3.github.io/ppa/setup_ppa.sh | sudo bash
fi

# ── Step 4: Install dependencies ─────────────────────────────────────────────
banner "Step 4 — Dependencies"

sudo apt update
sudo apt install -y \
    libiridescence-dev \
    libboost-all-dev \
    libglfw3-dev \
    libmetis-dev

# ── Step 5: Install GTSAM from PPA ───────────────────────────────────────────
banner "Step 5 — GTSAM 4.3.0 from PPA"

sudo apt install -y "$GTSAM_PKG"
info "GTSAM 4.3.0 installed."
info "The launch file handles the conflict with ROS Jazzy's GTSAM 4.2.0"
info "by prepending /usr/local/lib to LD_LIBRARY_PATH at runtime."

# ── Step 6: Install GLIM ROS package ─────────────────────────────────────────
banner "Step 6 — GLIM ROS package"

# Available options:
#   sudo apt install -y ros-jazzy-glim-ros              # Without CUDA
#   sudo apt install -y ros-jazzy-glim-ros-cuda12.6     # With CUDA 12.6
#   sudo apt install -y ros-jazzy-glim-ros-cuda13.1     # With CUDA 13.1
sudo apt install -y "$GLIM_PKG"
info "Installed: $GLIM_PKG"

# ── Step 7: ldconfig ──────────────────────────────────────────────────────────
banner "Step 7 — ldconfig"
sudo ldconfig

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           GLIM installation complete!                       ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
info "Next steps:"
echo "  1. Build:  cd ros2_rmc_ws && colcon build --packages-select slam_glim --symlink-install"
echo "  2. Run:    source install/setup.bash && ros2 launch slam_glim glim.launch.py"
echo ""
