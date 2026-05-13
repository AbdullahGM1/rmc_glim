import os
import subprocess
from launch import LaunchDescription
from launch.actions import ExecuteProcess, TimerAction
from launch_ros.actions import Node

# Point this at the PLY file you want to view
MAP_PLY = os.path.join(
    os.path.dirname(os.path.realpath(__file__)),
    '..', 'maps', 'bag_test_20260513_131336', 'map_test.ply'
)

def generate_launch_description():
    launch_dir = os.path.dirname(os.path.realpath(__file__))
    rviz_config = os.path.realpath(os.path.join(launch_dir, '..', 'rviz_config', 'view_map.rviz'))

    ply_path = os.path.realpath(MAP_PLY)
    pcd_path = os.path.splitext(ply_path)[0] + '.pcd'

    # Convert PLY → ASCII PCD only if not already done
    if not os.path.exists(pcd_path):
        subprocess.run(['pcl_ply2pcd', '-format', '0', ply_path, pcd_path], check=True)

    pcd_publisher = Node(
        package='glim_test',
        executable='pcd_publisher',
        parameters=[{'pcd_path': pcd_path}],
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

    return LaunchDescription([pcd_publisher, rviz])
