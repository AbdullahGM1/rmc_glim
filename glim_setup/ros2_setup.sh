#!/usr/bin/env bash
# ROS2 Jazzy Desktop installation script — Ubuntu 24.04 only
# Follows the official ROS2 Jazzy installation guide:
# https://docs.ros.org/en/jazzy/Installation/Ubuntu-Install-Debs.html
#
# Run this BEFORE cuda_setup.sh and glim_setup.sh.
#
# Usage:
#   ./ros2_setup.sh
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()   { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
banner() { echo -e "\n${GREEN}══ $* ${NC}"; }

# ── Step 1: Verify system ─────────────────────────────────────────────────────
banner "Step 1 — Verify system (Ubuntu 24.04)"

if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    if [[ "$VERSION_ID" != "24.04" ]]; then
        error "This script requires Ubuntu 24.04. Detected: $PRETTY_NAME"
    fi
    info "OS: $PRETTY_NAME — OK"
else
    error "/etc/os-release not found. Cannot verify Ubuntu version."
fi

# ── Step 2: Check if already installed ───────────────────────────────────────
banner "Step 2 — Check existing ROS2 installation"

if [[ -d /opt/ros/jazzy ]]; then
    info "ROS2 Jazzy already installed at /opt/ros/jazzy — skipping."
    echo ""
    info "Next step: run ./cuda_setup.sh"
    exit 0
fi

info "ROS2 Jazzy not found — proceeding with installation."

# ── Step 3: Set locale ────────────────────────────────────────────────────────
banner "Step 3 — Locale (UTF-8)"

sudo apt update
sudo apt install -y locales
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8
info "Locale set to en_US.UTF-8 — OK"

# ── Step 4: Enable universe repository ───────────────────────────────────────
banner "Step 4 — Universe repository"

sudo apt install -y software-properties-common
sudo add-apt-repository -y universe
info "Universe repository enabled."

# ── Step 5: Add ROS2 apt source ──────────────────────────────────────────────
banner "Step 5 — ROS2 apt source"

if apt-cache policy 2>/dev/null | grep -q "packages.ros.org"; then
    info "ROS2 apt source already present — skipping."
else
    info "Adding ROS2 apt source..."
    sudo apt update
    sudo apt install -y curl

    ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest \
        | grep -F "tag_name" | awk -F'"' '{print $4}')

    curl -L -o /tmp/ros2-apt-source.deb \
        "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo ${UBUNTU_CODENAME:-${VERSION_CODENAME}})_all.deb"

    sudo dpkg -i /tmp/ros2-apt-source.deb
    rm -f /tmp/ros2-apt-source.deb
    info "ROS2 apt source added."
fi

# ── Step 6: Install ROS2 dev tools ───────────────────────────────────────────
banner "Step 6 — ROS2 dev tools"

sudo apt update
sudo apt install -y ros-dev-tools
info "ROS2 dev tools installed."

# ── Step 7: Install ROS2 Jazzy Desktop (full) ────────────────────────────────
banner "Step 7 — ROS2 Jazzy Desktop"

# ros-jazzy-desktop installs:
#   - ROS2 core + middleware (DDS)
#   - RViz2, rqt, and all GUI tools
#   - Demo packages and tutorials
#   - ros2cli and all command-line tools
sudo apt upgrade -y
sudo apt install -y ros-jazzy-desktop
info "ROS2 Jazzy Desktop installed."

# ── Step 8: Source ROS2 in ~/.bashrc ─────────────────────────────────────────
banner "Step 8 — Shell setup"

BASHRC="$HOME/.bashrc"
SOURCE_LINE="source /opt/ros/jazzy/setup.bash"

if grep -qF "$SOURCE_LINE" "$BASHRC"; then
    info "ROS2 source line already in $BASHRC — skipping."
else
    echo "" >> "$BASHRC"
    echo "# ROS2 Jazzy" >> "$BASHRC"
    echo "$SOURCE_LINE" >> "$BASHRC"
    info "Added '$SOURCE_LINE' to $BASHRC"
fi

# ── Step 9: Verify ────────────────────────────────────────────────────────────
banner "Step 9 — Verify"

PASS=0; FAIL=0
check_pass() { info "  [PASS] $*"; ((PASS++)) || true; }
check_fail() { warn "  [FAIL] $*"; ((FAIL++)) || true; }

# ROS2 Jazzy directory exists
if [[ -d /opt/ros/jazzy ]]; then
    check_pass "/opt/ros/jazzy exists"
else
    check_fail "/opt/ros/jazzy not found"
fi

# ros2 CLI is available
if [[ -f /opt/ros/jazzy/bin/ros2 ]]; then
    check_pass "ros2 CLI found at /opt/ros/jazzy/bin/ros2"
else
    check_fail "ros2 CLI not found"
fi

# RViz2 is present (confirms full desktop install)
if [[ -f /opt/ros/jazzy/bin/rviz2 ]]; then
    check_pass "rviz2 found — full desktop confirmed"
else
    check_fail "rviz2 not found — desktop install may be incomplete"
fi

# Source line in ~/.bashrc
if grep -qF "$SOURCE_LINE" "$BASHRC"; then
    check_pass "ROS2 source line present in ~/.bashrc"
else
    check_fail "ROS2 source line missing from ~/.bashrc"
fi

echo ""
if [[ "$FAIL" -eq 0 ]]; then
    info "All $PASS checks passed — ROS2 Jazzy Desktop is ready."
else
    warn "$FAIL check(s) failed — review the output above."
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         ROS2 Jazzy Desktop installation complete!           ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
info "Next steps:"
echo "  1. Restart your terminal (or run: source ~/.bashrc)"
echo "  2. Run: ./cuda_setup.sh"
echo "  3. Run: ./glim_setup.sh"
echo ""
