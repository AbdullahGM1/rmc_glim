#!/usr/bin/env bash
# Master GLIM installation script — Ubuntu 24.04 only
# Runs all four setup scripts in the correct order.
# Re-run after each reboot as instructed.
#
# Usage:
#   ./install.sh              # auto-detect CUDA version
#   ./install.sh none         # install without CUDA
#   ./install.sh 12.6         # install with CUDA 12.6
#   ./install.sh 13.1         # install with CUDA 13.1
set -euo pipefail

CUDA_ARG="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
info()   { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
banner() { echo -e "\n${GREEN}══ $* ${NC}"; }
step()   { echo -e "${CYAN}[STEP]${NC}  $*"; }

# ── State detection ───────────────────────────────────────────────────────────
driver_active()   { command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; }
driver_installed(){ dpkg -l 2>/dev/null | grep -q "nvidia-driver"; }
ros2_installed()  { [[ -d /opt/ros/jazzy ]]; }
cuda_installed()  { [[ -d /usr/local/cuda-13.2 ]]; }
glim_installed()  { dpkg -l 2>/dev/null | grep -q "ros-jazzy-glim-ros"; }

# ── Progress header ───────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              GLIM Installation — rmc_glim                   ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

driver_active   && echo -e "  ${GREEN}[✓]${NC} NVIDIA driver" \
                || { driver_installed \
                     && echo -e "  ${YELLOW}[~]${NC} NVIDIA driver (installed — reboot pending)" \
                     || echo -e "  ${RED}[✗]${NC} NVIDIA driver"; }
ros2_installed  && echo -e "  ${GREEN}[✓]${NC} ROS2 Jazzy Desktop" \
                || echo -e "  ${RED}[✗]${NC} ROS2 Jazzy Desktop"
cuda_installed  && echo -e "  ${GREEN}[✓]${NC} CUDA 13.2 toolkit" \
                || echo -e "  ${RED}[✗]${NC} CUDA 13.2 toolkit"
glim_installed  && echo -e "  ${GREEN}[✓]${NC} GLIM" \
                || echo -e "  ${RED}[✗]${NC} GLIM"
echo ""

# ── Already complete? ─────────────────────────────────────────────────────────
if driver_active && ros2_installed && cuda_installed && glim_installed; then
    info "All steps complete — GLIM is fully installed."
    echo ""
    info "Build and run:"
    echo "  cd ros2_rmc_ws"
    echo "  colcon build --packages-select slam_glim --symlink-install"
    echo "  source install/setup.bash"
    echo "  ros2 launch slam_glim glim.launch.py"
    echo ""
    exit 0
fi

# ── Step 1: NVIDIA driver ─────────────────────────────────────────────────────
if ! driver_active; then
    if driver_installed; then
        # Package is installed but nvidia-smi doesn't work yet → needs reboot
        echo -e "${YELLOW}"
        echo "  !! REBOOT REQUIRED !!"
        echo ""
        echo "  The NVIDIA driver is installed but not yet active."
        echo "  Please reboot and then re-run:"
        echo "    ./install.sh${CUDA_ARG:+ $CUDA_ARG}"
        echo -e "${NC}"
        exit 0
    fi

    banner "Step 1/4 — NVIDIA driver"
    bash "$SCRIPT_DIR/driver_setup.sh"

    echo -e "${YELLOW}"
    echo "  !! REBOOT REQUIRED !!"
    echo ""
    echo "  The NVIDIA driver has been installed."
    echo "  Please reboot and then re-run:"
    echo "    ./install.sh${CUDA_ARG:+ $CUDA_ARG}"
    echo -e "${NC}"
    exit 0
fi

step "NVIDIA driver — already installed, skipping."

# ── Step 2: ROS2 Jazzy ────────────────────────────────────────────────────────
if ! ros2_installed; then
    banner "Step 2/4 — ROS2 Jazzy Desktop"
    bash "$SCRIPT_DIR/ros2_setup.sh"
fi

# Source ROS2 for the remainder of this script (avoids needing terminal restart)
if [[ -f /opt/ros/jazzy/setup.bash ]]; then
    # shellcheck disable=SC1091
    source /opt/ros/jazzy/setup.bash
    step "ROS2 Jazzy — installed and sourced."
fi

# ── Step 3: CUDA toolkit ──────────────────────────────────────────────────────
if ! cuda_installed; then
    banner "Step 3/4 — CUDA 13.2 toolkit"
    bash "$SCRIPT_DIR/cuda_setup.sh"
else
    step "CUDA 13.2 — already installed, skipping."
fi

# ── Step 4: GLIM ─────────────────────────────────────────────────────────────
if ! glim_installed; then
    banner "Step 4/4 — GLIM"
    if [[ -n "$CUDA_ARG" ]]; then
        bash "$SCRIPT_DIR/glim_setup.sh" "$CUDA_ARG"
    else
        bash "$SCRIPT_DIR/glim_setup.sh"
    fi
else
    step "GLIM — already installed, skipping."
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           GLIM installation complete!                       ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
info "Next steps:"
echo "  1. Build:  cd ros2_rmc_ws && colcon build --packages-select slam_glim --symlink-install"
echo "  2. Source: source install/setup.bash"
echo "  3. Run:    ros2 launch slam_glim glim.launch.py"
echo ""
