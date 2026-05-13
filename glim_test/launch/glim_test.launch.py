import os
from launch import LaunchDescription
from launch.actions import ExecuteProcess, TimerAction

def generate_launch_description():
    launch_dir = os.path.dirname(os.path.realpath(__file__))
    config_path = os.path.realpath(os.path.join(launch_dir, '..', 'config', 'gpu'))
    bag_path    = os.path.realpath(os.path.join(launch_dir, '..', '..', 'bag_test'))
    rviz_config = os.path.realpath(os.path.join(launch_dir, '..', 'rviz_config', 'glim_ros.rviz'))

    glim_env = os.environ.copy()
    glim_env['LD_LIBRARY_PATH'] = '/usr/local/lib:' + glim_env.get('LD_LIBRARY_PATH', '')

    # Step 1 — GLIM starts immediately
    glim_node = ExecuteProcess(
        cmd=[
            'ros2', 'run', 'glim_ros', 'glim_rosnode',
            '--ros-args', '-p', f'config_path:={config_path}'
        ],
        env=glim_env,
        output='screen'
    )

    # Step 2 — bag plays after 2s (gives GLIM time to initialize)
    bag_play = TimerAction(
        period=2.0,
        actions=[
            ExecuteProcess(
                cmd=['ros2', 'bag', 'play', bag_path, '--clock'],
                output='screen'
            )
        ]
    )

    # Step 3 — RViz opens alongside the bag
    rviz = TimerAction(
        period=2.0,
        actions=[
            ExecuteProcess(
                cmd=['rviz2', '-d', rviz_config],
                output='screen'
            )
        ]
    )

    return LaunchDescription([glim_node, bag_play, rviz])
