"""Convert GLIM exported PCD map to a 2D occupancy grid (.pgm + .yaml)."""

import os
import numpy as np
from PIL import Image
import yaml

# Point this at the PCD file you want to convert
MAP_PCD = os.path.join(
    os.path.dirname(os.path.realpath(__file__)),
    '..', 'maps', 'bag_test_20260513_131336', 'map_test.pcd'
)


def _read_pcd_xyz(path: str) -> np.ndarray:
    """Read x, y, z columns from an ASCII PCD file. Returns (N, 3) float64 array."""
    fields = []
    with open(path, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('FIELDS'):
                fields = line.split()[1:]
            if line.startswith('DATA'):
                break
        data = np.loadtxt(f, dtype=np.float32)
    if data.ndim == 1:
        data = data.reshape(1, -1)
    xi = fields.index('x')
    yi = fields.index('y')
    zi = fields.index('z')
    return data[:, [xi, yi, zi]].astype(np.float64)


def _detect_ground_top(points_xyz: np.ndarray, search_range: float = 1.5, bin_size: float = 0.05):
    """Find the peak and top edge of the ground cluster in the z-histogram."""
    z_vals = points_xyz[:, 2]
    # Use 1st percentile instead of min to ignore sparse outlier points below the actual floor
    z_min = float(np.percentile(z_vals, 1))
    z_search_max = z_min + search_range

    low_z = z_vals[(z_vals >= z_min) & (z_vals <= z_search_max)]
    if len(low_z) == 0:
        return z_min, z_min

    bins = np.arange(z_min, z_search_max + bin_size, bin_size)
    counts, edges = np.histogram(low_z, bins=bins)

    ground_bin = int(np.argmax(counts))
    threshold = counts[ground_bin] * 0.20

    top_bin = ground_bin
    for i in range(ground_bin + 1, len(counts)):
        if counts[i] < threshold:
            top_bin = i
            break
    else:
        top_bin = ground_bin + 1

    ground_peak_z = float(edges[ground_bin] + bin_size / 2.0)
    ground_top_z = float(edges[top_bin])
    return ground_peak_z, ground_top_z


def xyz_to_occupancy_grid(
    points_xyz: np.ndarray,
    output_stem: str,
    resolution: float = 0.05,
    z_ceil_offset: float = 3.0,
    margin: float = 1.0,
):
    """Project (N, 3) world-frame points to a 2D occupancy grid and save .pgm + .yaml."""
    print(f'  Input: {len(points_xyz):,} points')

    # Voxel downsample
    voxel_idx = np.floor(points_xyz / resolution).astype(np.int64)
    _, keep = np.unique(voxel_idx, axis=0, return_index=True)
    points_xyz = points_xyz[keep]
    print(f'  After voxel downsample: {len(points_xyz):,} points')

    # Ground detection
    ground_peak_z, ground_top_z = _detect_ground_top(points_xyz)
    z_floor = max(ground_top_z, ground_peak_z + 0.30)
    z_ceil = ground_peak_z + z_ceil_offset
    print(f'  Ground peak: {ground_peak_z:.2f} m  |  cluster top: {ground_top_z:.2f} m  |  z_floor: {z_floor:.2f} m')

    # Height filter
    mask = (points_xyz[:, 2] >= z_floor) & (points_xyz[:, 2] <= z_ceil)
    pts2d = points_xyz[mask, :2]
    print(f'  Height filter [{z_floor:.2f} m, {z_ceil:.2f} m]: {len(pts2d):,} points kept')

    if len(pts2d) == 0:
        raise ValueError('No points remain after height filter — try increasing z_ceil_offset')

    # Grid allocation
    x_orig = pts2d[:, 0].min() - margin
    y_orig = pts2d[:, 1].min() - margin
    x_max = pts2d[:, 0].max() + margin
    y_max = pts2d[:, 1].max() + margin
    width = int(np.ceil((x_max - x_orig) / resolution))
    height = int(np.ceil((y_max - y_orig) / resolution))

    # 205 = unknown gray (ROS2 trinary: 0=occupied, 254=free, 205=unknown)
    grid = np.full((height, width), 205, dtype=np.uint8)

    # Mark occupied cells
    xi = np.floor((pts2d[:, 0] - x_orig) / resolution).astype(int)
    yi = np.floor((pts2d[:, 1] - y_orig) / resolution).astype(int)
    valid = (xi >= 0) & (xi < width) & (yi >= 0) & (yi < height)
    grid[yi[valid], xi[valid]] = 0  # occupied = black

    os.makedirs(os.path.dirname(output_stem) if os.path.dirname(output_stem) else '.', exist_ok=True)

    # Save .pgm (row 0 = world y_max — ROS2 map_server convention)
    pgm_path = output_stem + '.pgm'
    Image.fromarray(np.flipud(grid), mode='L').save(pgm_path)

    # Save .yaml
    yaml_data = {
        'image': os.path.basename(pgm_path),
        'mode': 'trinary',
        'resolution': float(resolution),
        'origin': [round(float(x_orig), 6), round(float(y_orig), 6), 0.0],
        'negate': 0,
        'occupied_thresh': 0.65,
        'free_thresh': 0.196,
    }
    yaml_path = output_stem + '.yaml'
    with open(yaml_path, 'w') as f:
        yaml.dump(yaml_data, f, default_flow_style=False)

    print(f'  Saved: {pgm_path}')
    print(f'  Saved: {yaml_path}')
    print(f'  Map size: {width} x {height} px  ({width * resolution:.1f} x {height * resolution:.1f} m)')


def main():
    pcd_path = os.path.realpath(MAP_PCD)
    if not os.path.exists(pcd_path):
        raise FileNotFoundError(f'PCD file not found: {pcd_path}')

    run_dir = os.path.dirname(pcd_path)
    output_stem = os.path.join(run_dir, 'glim_2d_map')

    print(f'[convert_map] Input:  {pcd_path}')
    print(f'[convert_map] Output: {output_stem}.pgm / .yaml')

    points = _read_pcd_xyz(pcd_path)
    xyz_to_occupancy_grid(points, output_stem)
    print('[convert_map] Done.')


if __name__ == '__main__':
    main()
