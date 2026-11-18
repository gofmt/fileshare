import 'dart:io';

class NetworkInterfaceInfo {
  final String name;
  final String address;
  final String type; // wifi / ethernet / other

  NetworkInterfaceInfo({
    required this.name,
    required this.address,
    required this.type,
  });

  String get displayLabel => '$name ($address)';
}

class NetworkUtils {
  NetworkUtils._();

  static const _virtualKeywords = [
    'vmware', 'virtualbox', 'vbox', 'hyper-v', 'vethernet', 'virtual',
    'tap', 'tun', 'zerotier', 'tailscale', 'wireguard', 'vpn',
    'bluetooth', 'docker', 'wsl', 'rmnet', 'loopback',
  ];

  static const _wifiKeywords = ['wi-fi', 'wifi', 'wlan', 'wireless', '无线'];

  static const _ethernetKeywords = ['ethernet', '以太网', '本地连接'];
static bool isPrivateIp(String ip) {
  if (ip.startsWith('192.168.') || ip.startsWith('10.')) return true;
  if (ip.startsWith('172.')) {
    final parts = ip.split('.');
    if (parts.length >= 2) {
      final second = int.tryParse(parts[1]) ?? 0;
      return second >= 16 && second <= 31;
    }
  }
  return false;
}
  /// 列出所有可用的私有 IPv4 网卡，WiFi 优先
  static Future<List<NetworkInterfaceInfo>> allIPv4() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    final result = <NetworkInterfaceInfo>[];
    for (final iface in interfaces) {
      final lower = iface.name.toLowerCase();
      if (_virtualKeywords.any(lower.contains)) continue;
      for (final addr in iface.addresses) {
        if (addr.isLoopback) continue;
        if (!_isPrivate(addr.address)) continue;
        result.add(NetworkInterfaceInfo(
          name: iface.name,
          address: addr.address,
          type: _classify(lower),
        ));
      }
    }
    result.sort((a, b) {
      const order = {'wifi': 0, 'ethernet': 1, 'other': 2};
      return (order[a.type] ?? 9).compareTo(order[b.type] ?? 9);
    });
    return result;
  }

  /// 自动挑选：WiFi > 以太网 > 其它
  static Future<String?> localIpv4() async {
    final all = await allIPv4();
    return all.isEmpty ? null : all.first.address;
  }

  static String _classify(String lowerName) {
    if (_wifiKeywords.any(lowerName.contains)) return 'wifi';
    if (_ethernetKeywords.any(lowerName.contains)) return 'ethernet';
    return 'other';
  }

  static bool _isPrivate(String ip) {
    if (ip.startsWith('192.168.') || ip.startsWith('10.')) return true;
    if (ip.startsWith('172.')) {
      final parts = ip.split('.');
      if (parts.length >= 2) {
        final second = int.tryParse(parts[1]) ?? 0;
        return second >= 16 && second <= 31;
      }
    }
    return false;
  }
}

class FileUtils {
  FileUtils._();

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}

