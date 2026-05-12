#!/bin/bash
# One-time setup: creates a Python venv and installs rosbags-convert.
# Run this once before using convert_bag.sh.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"

if [ -d "$VENV_DIR" ]; then
    echo "Venv already exists at $VENV_DIR — skipping setup."
    echo "To reinstall, delete the venv directory and re-run this script."
    exit 0
fi

echo "Creating venv at $VENV_DIR ..."
python3 -m venv "$VENV_DIR"

echo "Installing rosbags ..."
"$VENV_DIR/bin/pip" install --quiet --upgrade pip
"$VENV_DIR/bin/pip" install rosbags

echo ""
echo "Setup complete. You can now run:"
echo "  ./convert_bag.sh /path/to/your_file.bag"
