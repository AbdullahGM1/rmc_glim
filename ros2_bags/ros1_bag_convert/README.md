# ROS1 → ROS2 Bag Conversion

Converts ROS1 `.bag` files to ROS2 `.db3` bags using the `rosbags-convert` tool inside a local Python venv.

---

## Setup (once)

```bash
cd ros2_bags/ros1_bag_convert
./setup.sh
```

This creates a `venv/` directory and installs `rosbags` into it. The venv is gitignored — run setup once per machine.

---

## Convert a Bag

```bash
./convert_bag.sh /path/to/your_file.bag [output_name]
```

- The first argument is the path to the ROS1 `.bag` file (required).
- The second argument is the output directory name (optional). Defaults to the `.bag` filename if not provided.

The converted bag is saved to `ros2_bags/<output_name>/`.

**Example — keep original name:**

```bash
./convert_bag.sh ~/recordings/my_recording.bag
# Output: ros2_bags/my_recording/
#           ├── my_recording.db3
#           └── metadata.yaml
```

**Example — custom name:**

```bash
./convert_bag.sh ~/recordings/record_2025-03-19-09-30-13_2.bag lower_fused
# Output: ros2_bags/lower_fused/
#           ├── lower_fused.db3
#           └── metadata.yaml
```

If the output directory already exists, the script will ask before overwriting.

---

## Notes

- The `venv/` directory is gitignored — do not commit it.
- Only `.bag` files are accepted. Passing any other extension will error out.
- Do not loop converted bags during GLIM playback (`-l` flag) — GLIM crashes when sim time jumps backwards on loop restart.
