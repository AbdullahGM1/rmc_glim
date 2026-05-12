#!/usr/bin/env bash
# CUDA Toolkit installation script — Ubuntu 24.04 only
# Installs CUDA 13.2 from NVIDIA's official repository.
#
# Run this BEFORE glim_setup.sh so that libcudart.so.13 is available
# in a standard system path — no symlink workarounds needed.
#
# Usage:
#   ./cuda_setup.sh
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

if ! command -v nvidia-smi &>/dev/null; then
    error "nvidia-smi not found. Install the NVIDIA driver first before running this script."
fi
info "NVIDIA driver: OK"
nvidia-smi --query-gpu=name,driver_version --format=csv,noheader | while IFS=',' read -r name drv; do
    info "  GPU: $name | Driver: $drv"
done

# ── Step 2: Check if CUDA toolkit already installed ───────────────────────────
banner "Step 2 — Check existing CUDA toolkit"

if [[ -d /usr/local/cuda-13.2 ]]; then
    info "CUDA 13.2 toolkit already installed at /usr/local/cuda-13.2 — skipping."
    info "libcudart.so.13 location:"
    find /usr/local/cuda-13.2/lib64 -name "libcudart.so.13*" | while read -r f; do info "  $f"; done
    echo ""
    info "Next step: run ./glim_setup.sh to install GLIM"
    exit 0
fi

info "CUDA 13.2 toolkit not found — proceeding with installation."

# ── Step 3: Add NVIDIA CUDA repository ───────────────────────────────────────
banner "Step 3 — NVIDIA CUDA repository"

if dpkg -l cuda-keyring &>/dev/null 2>&1; then
    info "cuda-keyring already installed — skipping."
else
    info "Downloading NVIDIA CUDA keyring..."
    KEYRING_TMP=$(mktemp /tmp/cuda-keyring-XXXXXX.deb)
    wget -q \
        https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb \
        -O "$KEYRING_TMP"
    sudo dpkg -i "$KEYRING_TMP"
    rm -f "$KEYRING_TMP"
    info "NVIDIA CUDA repository added."
fi

sudo apt update

# ── Step 4: Install CUDA 13.2 toolkit ────────────────────────────────────────
banner "Step 4 — Install CUDA 13.2 toolkit"

# cuda-toolkit-13-2 installs the compiler, libraries, and headers for CUDA 13.2.
# This places libcudart.so.13 in /usr/local/cuda-13.2/lib64/ — a standard path
# that the dynamic linker finds without any symlink workarounds.
sudo apt install -y cuda-toolkit-13-2
info "CUDA 13.2 toolkit installed."

# ── Step 5: ldconfig ─────────────────────────────────────────────────────────
# The cuda-toolkit apt package registers its own ldconfig entry during install.
# Running ldconfig here ensures the cache is up to date.
banner "Step 5 — ldconfig"

sudo ldconfig
info "Library cache updated."

# ── Step 6: Verify CUDA is accessible for GLIM ───────────────────────────────
banner "Step 6 — Verify CUDA for GLIM"

PASS=0
FAIL=0

check_pass() { info  "  [PASS] $*"; ((PASS++)) || true; }
check_fail() { warn  "  [FAIL] $*"; ((FAIL++)) || true; }

# 1. nvcc — confirms toolkit is installed
NVCC="/usr/local/cuda-13.2/bin/nvcc"
if [[ -f "$NVCC" ]]; then
    NVCC_VER=$("$NVCC" --version | grep -oP "release \K[0-9.]+")
    check_pass "nvcc $NVCC_VER found at $NVCC"
else
    check_fail "nvcc not found at $NVCC"
fi

# 2. libcudart.so.13 exists on disk
LIBCUDART=$(find /usr/local/cuda-13.2 -name "libcudart.so.13" 2>/dev/null | head -1)
if [[ -n "$LIBCUDART" ]]; then
    check_pass "libcudart.so.13 found at $LIBCUDART"
else
    check_fail "libcudart.so.13 not found under /usr/local/cuda-13.2"
fi

# 3. Dynamic linker can resolve libcudart.so.13 — what GLIM checks at launch
LINKER_PATH=$(ldconfig -p | grep "libcudart.so.13 " | awk '{print $NF}' | head -1)
if [[ -n "$LINKER_PATH" ]]; then
    check_pass "Linker resolves libcudart.so.13 → $LINKER_PATH"
else
    check_fail "Linker cannot resolve libcudart.so.13 — GLIM will fail at launch"
fi

# 4. /usr/local/cuda symlink points to cuda-13.2
CUDA_LINK=$(readlink /usr/local/cuda 2>/dev/null || true)
if [[ "$CUDA_LINK" == *"cuda-13.2"* ]] || [[ -d /usr/local/cuda-13.2 && "$(readlink -f /usr/local/cuda)" == "$(readlink -f /usr/local/cuda-13.2)" ]]; then
    check_pass "/usr/local/cuda → $(readlink -f /usr/local/cuda)"
else
    check_fail "/usr/local/cuda symlink missing or does not point to cuda-13.2 (points to: ${CUDA_LINK:-none})"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
if [[ "$FAIL" -eq 0 ]]; then
    info "All $PASS checks passed — GLIM can access CUDA 13.2 correctly."
else
    warn "$FAIL check(s) failed — GLIM may not work. Fix the issues above before running glim_setup.sh."
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           CUDA 13.2 installation complete!                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
info "Next step: run ./glim_setup.sh to install GLIM"
echo ""
