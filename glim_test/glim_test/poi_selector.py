import os
import yaml
import datetime
import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, DurabilityPolicy, HistoryPolicy
from geometry_msgs.msg import PointStamped, PoseStamped
from visualization_msgs.msg import Marker, MarkerArray


class PoiSelector(Node):
    """
    Subscribes to /clicked_point (from RViz2 Publish Point tool).
    For each click:
      - Publishes geometry_msgs/PoseStamped on /poi_pose (identity orientation)
      - Appends to a YAML file in glim_test/POI_Poses/
      - Republishes all POIs as red sphere markers on /poi_markers
    """

    def __init__(self):
        super().__init__('poi_selector')

        self.declare_parameter('pois_path', '/tmp/pois.yaml')
        self.declare_parameter('load_existing', True)

        self._pois_path = self.get_parameter('pois_path').value
        self._pois = []

        qos_reliable = QoSProfile(
            reliability=ReliabilityPolicy.RELIABLE,
            durability=DurabilityPolicy.VOLATILE,
            history=HistoryPolicy.KEEP_LAST,
            depth=10,
        )
        qos_transient = QoSProfile(
            reliability=ReliabilityPolicy.RELIABLE,
            durability=DurabilityPolicy.TRANSIENT_LOCAL,
            history=HistoryPolicy.KEEP_LAST,
            depth=1,
        )

        self.create_subscription(PointStamped, '/clicked_point', self._click_cb, qos_reliable)
        self._pub_pose    = self.create_publisher(PoseStamped,  '/poi_pose',    qos_reliable)
        self._pub_markers = self.create_publisher(MarkerArray,  '/poi_markers', qos_transient)

        if self.get_parameter('load_existing').value:
            self._load_existing()

        self.get_logger().info(
            f'poi_selector ready — saving to {self._pois_path} | {len(self._pois)} POI(s) loaded'
        )

    def _click_cb(self, msg: PointStamped):
        poi_id = len(self._pois) + 1
        name = f'POI_{poi_id}'
        now = datetime.datetime.now().strftime('%Y-%m-%dT%H:%M:%S')

        entry = {
            'id': poi_id,
            'name': name,
            'timestamp': now,
            'frame_id': msg.header.frame_id,
            'position': {
                'x': float(msg.point.x),
                'y': float(msg.point.y),
                'z': float(msg.point.z),
            },
            'orientation': {'x': 0.0, 'y': 0.0, 'z': 0.0, 'w': 1.0},
        }
        self._pois.append(entry)

        pose = PoseStamped()
        pose.header = msg.header
        pose.pose.position.x = msg.point.x
        pose.pose.position.y = msg.point.y
        pose.pose.position.z = msg.point.z
        pose.pose.orientation.w = 1.0
        self._pub_pose.publish(pose)

        self._save_yaml()
        self._publish_markers()

        self.get_logger().info(
            f'{name} — x={msg.point.x:.3f} y={msg.point.y:.3f} z={msg.point.z:.3f} '
            f'frame={msg.header.frame_id}'
        )

    def _save_yaml(self):
        os.makedirs(os.path.dirname(self._pois_path), exist_ok=True)
        session_name = os.path.splitext(os.path.basename(self._pois_path))[0]
        data = {'pois': self._pois}
        with open(self._pois_path, 'w') as f:
            f.write(f'# POIs — {session_name}\n')
            yaml.dump(data, f, default_flow_style=False, sort_keys=False)

    def _load_existing(self):
        if not os.path.exists(self._pois_path):
            return
        try:
            with open(self._pois_path, 'r') as f:
                data = yaml.safe_load(f)
            if data and 'pois' in data:
                self._pois = data['pois']
                self._publish_markers()
        except Exception as e:
            self.get_logger().warn(f'Could not load existing pois.yaml: {e}')

    def _publish_markers(self):
        array = MarkerArray()

        clear = Marker()
        clear.action = Marker.DELETEALL
        array.markers.append(clear)

        for poi in self._pois:
            poi_id = poi['id']
            x = poi['position']['x']
            y = poi['position']['y']
            z = poi['position']['z']
            frame = poi['frame_id']

            sphere = Marker()
            sphere.header.frame_id = frame
            sphere.ns = 'poi_spheres'
            sphere.id = poi_id
            sphere.type = Marker.SPHERE
            sphere.action = Marker.ADD
            sphere.pose.position.x = x
            sphere.pose.position.y = y
            sphere.pose.position.z = z
            sphere.pose.orientation.w = 1.0
            sphere.scale.x = sphere.scale.y = sphere.scale.z = 0.4
            sphere.color.r = 1.0
            sphere.color.g = 0.0
            sphere.color.b = 0.0
            sphere.color.a = 1.0
            array.markers.append(sphere)

            label = Marker()
            label.header.frame_id = frame
            label.ns = 'poi_labels'
            label.id = poi_id
            label.type = Marker.TEXT_VIEW_FACING
            label.action = Marker.ADD
            label.pose.position.x = x
            label.pose.position.y = y
            label.pose.position.z = z + 0.5
            label.pose.orientation.w = 1.0
            label.scale.z = 0.3
            label.color.r = 1.0
            label.color.g = 1.0
            label.color.b = 1.0
            label.color.a = 1.0
            label.text = poi['name']
            array.markers.append(label)

        self._pub_markers.publish(array)


def main(args=None):
    rclpy.init(args=args)
    node = PoiSelector()
    rclpy.spin(node)
    rclpy.shutdown()
