import os
import datetime
import subprocess
from launch import LaunchDescription
from launch.actions import ExecuteProcess, TimerAction
from launch_ros.actions import Node

# Point this at the PLY file you want to view
MAP_PLY = os.path.join(
    os.path.dirname(os.path.realpath(__file__)),
    '..', 'maps', 'bag_test_20260513_131336', 'map_test.ply'
)

# POI files are saved to glim_test/POI_Poses/
# Filename: glim_<map_name>_<YYYYMMDD_HHMMSS>.yaml
_PACKAGE_DIR  = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
_POI_POSES_DIR = os.path.join(_PACKAGE_DIR, 'POI_Poses')
_MAP_NAME     = os.path.basename(os.path.dirname(os.path.realpath(MAP_PLY)))
_TIMESTAMP    = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
POIS_PATH     = os.path.join(_POI_POSES_DIR, f'glim_{_MAP_NAME}_{_TIMESTAMP}.yaml')


def generate_launch_description():
    os.makedirs(_POI_POSES_DIR, exist_ok=True)

    launch_dir  = os.path.dirname(os.path.realpath(__file__))
    rviz_config = os.path.realpath(os.path.join(launch_dir, '..', 'rviz_config', 'view_map.rviz'))

    ply_path = os.path.realpath(MAP_PLY)
    pcd_path = os.path.splitext(ply_path)[0] + '.pcd'

    # Convert PLY → ASCII PCD only if not already done
    if not os.path.exists(pcd_path):
        subprocess.run(['pcl_ply2pcd', '-format', '0', ply_path, pcd_path], check=True)

    # Static identity map → odom so RViz fixed frame "map" resolves without a live SLAM node
    static_tf = Node(
        package='tf2_ros',
        executable='static_transform_publisher',
        name='map_to_odom',
        arguments=['0', '0', '0', '0', '0', '0', 'map', 'odom'],
        output='screen'
    )

    pcd_publisher = Node(
        package='glim_test',
        executable='pcd_publisher',
        parameters=[{'pcd_path': pcd_path}],
        output='screen'
    )

    poi_selector = Node(
        package='glim_test',
        executable='poi_selector',
        parameters=[{
            'pois_path': POIS_PATH,
            'load_existing': True,
        }],
        output='screen'
    )

    rviz = TimerAction(
        period=2.0,
        actions=[
            ExecuteProcess(
                cmd=['rviz2', '-d', rviz_config],
                output='screen'
            )
        ]
    )

    return LaunchDescription([static_tf, pcd_publisher, poi_selector, rviz])
