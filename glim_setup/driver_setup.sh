#!/usr/bin/env bash
# NVIDIA driver installation script — Ubuntu 24.04 only
# Follows the official Ubuntu NVIDIA driver installation guide:
# https://ubuntu.com/server/docs/how-to/graphics/install-nvidia-drivers/
#
# IMPORTANT: A reboot is required after this script completes.
#            Run cuda_setup.sh only after rebooting.
#
# Usage:
#   ./driver_setup.sh
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

# ── Step 2: Check if driver already installed ─────────────────────────────────
banner "Step 2 — Check existing NVIDIA driver"

if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
    info "NVIDIA driver already installed and working:"
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader | while IFS=',' read -r name drv; do
        info "  GPU: $name | Driver: $drv"
    done
    echo ""
    info "Next step: run ./cuda_setup.sh"
    exit 0
fi

info "NVIDIA driver not found — proceeding with installation."

# ── Step 3: Update system ─────────────────────────────────────────────────────
banner "Step 3 — System update"

sudo apt update
sudo apt upgrade -y
info "System updated."

# ── Step 4: Install ubuntu-drivers tool ──────────────────────────────────────
banner "Step 4 — ubuntu-drivers tool"

sudo apt install -y ubuntu-drivers-common
info "ubuntu-drivers tool installed."

# ── Step 5: Show available drivers ───────────────────────────────────────────
banner "Step 5 — Available NVIDIA drivers"

info "Detecting available drivers for your GPU..."
sudo ubuntu-drivers list || true

# ── Step 6: Install recommended driver ───────────────────────────────────────
banner "Step 6 — Install recommended NVIDIA driver"

# ubuntu-drivers install automatically selects the recommended driver
# for your GPU — pre-built, signed, and compatible with Secure Boot.
sudo ubuntu-drivers install
info "NVIDIA driver installed."

# ── Step 7: Verify (pre-reboot) ──────────────────────────────────────────────
banner "Step 7 — Verify (pre-reboot)"

if dpkg -l | grep -q "nvidia-driver"; then
    DRIVER_PKG=$(dpkg -l | grep "nvidia-driver" | awk '{print $2}' | head -1)
    info "Driver package installed: $DRIVER_PKG"
else
    warn "No nvidia-driver package found in dpkg — installation may have failed."
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           NVIDIA driver installation complete!              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}  !! REBOOT REQUIRED before continuing !!${NC}"
echo ""
info "After rebooting, verify the driver with:"
echo "    nvidia-smi"
echo ""
info "Then continue with:"
echo "  1. ./cuda_setup.sh"
echo "  2. ./glim_setup.sh"
echo ""
