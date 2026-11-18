class Device {
  final String id;
  final String name;
  final String ip;
  final int port;
  final String platform;
  DateTime lastSeen;

  Device({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.platform,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  String get endpoint => 'http://$ip:$port';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'port': port,
        'platform': platform,
      };

  /// 注意：必须接受 2 个位置参数 (json, ip)
  factory Device.fromJson(Map<String, dynamic> json, String ip) => Device(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? 'Unknown',
        ip: ip,
        port: (json['port'] as num?)?.toInt() ?? 0,
        platform: (json['platform'] as String?) ?? 'unknown',
      );
}