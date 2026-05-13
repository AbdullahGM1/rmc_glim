import numpy as np
import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, DurabilityPolicy
from sensor_msgs.msg import PointCloud2, PointField


def _read_pcd_ascii(path):
    """Parse an ASCII PCD file and return an (N, 3) float32 XYZ array."""
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
    return data[:, [xi, yi, zi]]


class PcdPublisher(Node):
    def __init__(self):
        super().__init__('pcd_publisher')
        self.declare_parameter('pcd_path', '')
        pcd_path = self.get_parameter('pcd_path').get_parameter_value().string_value

        qos = QoSProfile(depth=1, durability=DurabilityPolicy.TRANSIENT_LOCAL)
        self.pub = self.create_publisher(PointCloud2, '/map_cloud', qos)

        self._publish(pcd_path)

    def _publish(self, path):
        points = _read_pcd_ascii(path)

        msg = PointCloud2()
        msg.header.stamp = self.get_clock().now().to_msg()
        msg.header.frame_id = 'map'
        msg.height = 1
        msg.width = len(points)
        msg.is_dense = True
        msg.is_bigendian = False
        msg.point_step = 12  # 3 × float32
        msg.row_step = msg.point_step * msg.width
        msg.fields = [
            PointField(name='x', offset=0,  datatype=PointField.FLOAT32, count=1),
            PointField(name='y', offset=4,  datatype=PointField.FLOAT32, count=1),
            PointField(name='z', offset=8,  datatype=PointField.FLOAT32, count=1),
        ]
        msg.data = points.tobytes()

        self.pub.publish(msg)
        self.get_logger().info(f'Published {len(points):,} points from {path}')


def main():
    rclpy.init()
    node = PcdPublisher()
    rclpy.spin(node)
    rclpy.shutdown()
