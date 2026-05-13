from setuptools import find_packages, setup
import os
from glob import glob

package_name = 'glim_test'

setup(
    name=package_name,
    version='0.0.1',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages', ['resource/glim_test']),
        ('share/' + package_name, ['package.xml']),
        (os.path.join('share', package_name, 'launch'), glob('launch/*.py')),
        (os.path.join('share', package_name, 'config', 'gpu'), glob('config/gpu/*.json')),
        (os.path.join('share', package_name, 'config', 'cpu'), glob('config/cpu/*.json')),
        (os.path.join('share', package_name, 'config', 'lidar_only'), glob('config/lidar_only/*.json')),
        (os.path.join('share', package_name, 'rviz_config'), glob('rviz_config/*.rviz')),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='Abdullah',
    maintainer_email='agm.musalami@gmail.com',
    description='GLIM quickstart test — OS1-128 bag playback with GLIM SLAM',
    license='MIT',
    entry_points={
        'console_scripts': [],
    },
)
