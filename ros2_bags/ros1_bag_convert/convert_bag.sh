#!/bin/bash
# Convert a ROS1 .bag file to a ROS2 .db3 bag.
#
# Usage:
#   ./convert_bag.sh /path/to/your_file.bag [output_name]
#
# Output:
#   ros2_bags/<output_name>/   (defaults to the .bag filename if not specified)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"
OUTPUT_DIR="$(dirname "$SCRIPT_DIR")"   # ros2_bags/

# --- Validate input ---
if [ -z "$1" ]; then
    echo "Error: no bag file provided."
    echo "Usage: $0 /path/to/your_file.bag"
    exit 1
fi

INPUT_BAG="$(realpath "$1")"

if [ ! -f "$INPUT_BAG" ]; then
    echo "Error: file not found: $INPUT_BAG"
    exit 1
fi

if [[ "$INPUT_BAG" != *.bag ]]; then
    echo "Error: expected a .bag file, got: $INPUT_BAG"
    exit 1
fi

# --- Validate venv ---
if [ ! -f "$VENV_DIR/bin/rosbags-convert" ]; then
    echo "Error: venv not set up. Run ./setup.sh first."
    exit 1
fi

# --- Convert ---
if [ -n "$2" ]; then
    BAG_NAME="$2"
else
    BAG_NAME="$(basename "$INPUT_BAG" .bag)"
fi
DEST="$OUTPUT_DIR/$BAG_NAME"

if [ -d "$DEST" ]; then
    echo "Warning: output directory already exists: $DEST"
    read -rp "Overwrite? [y/N] " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborted."
        exit 0
    fi
    rm -rf "$DEST"
fi

echo "Converting: $INPUT_BAG"
echo "       To:  $DEST"
echo ""

"$VENV_DIR/bin/rosbags-convert" --src "$INPUT_BAG" --dst "$DEST"

echo ""
echo "Done. ROS2 bag saved to: $DEST"
