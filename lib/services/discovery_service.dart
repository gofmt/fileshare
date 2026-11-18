import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../core/utils.dart';
import '../models/device.dart';

class DiscoveryService extends ChangeNotifier {
  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;
  Timer? _scanTimer;
  bool _running = false;
  bool _scanning = false;

  final Map<String, Device> _devices = {};
  String _deviceName = 'Unknown';
  String _deviceId = '';
  String _platform = AppConstants.platformUnknown;
  int _httpPort = 0;
  String? _localIp;

  List<Device> get devices =>
      _devices.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  String get deviceName => _deviceName;
  String? get localIp => _localIp;

  Future<void> start({required int port}) async {
    if (_running) return;
    _running = true;
    _httpPort = port;
    _deviceId = const Uuid().v4();
    await _loadDeviceInfo();
    await _bindSocket();
    _startBroadcast();
    _startCleanup();
    _startScan();
  }

  Future<void> _loadDeviceInfo() async {
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      _platform = AppConstants.platformAndroid;
      final android = await info.androidInfo;
      _deviceName = '${android.brand} ${android.model}';
    } else if (Platform.isWindows) {
      _platform = AppConstants.platformWindows;
      final windows = info.windowsInfo;
      _deviceName = (await windows).computerName;
    } else {
      _deviceName = Platform.localHostname;
    }
    _localIp = await NetworkUtils.localIpv4();
  }

  Future<void> _bindSocket() async {
    // 必须绑 anyIPv4，才能收到所有网卡上的广播和单播
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      AppConstants.discoveryPort,
      reusePort: !Platform.isWindows,
    );
    _socket!.broadcastEnabled = true;
    _socket!.listen(_onSocketEvent);
  }

  void _onSocketEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _socket?.receive();
    if (datagram == null) return;
    try {
      debugPrint('UDP 收到 ${datagram.address.address}:${datagram.port} → ${utf8.decode(datagram.data, allowMalformed: true)}');
      final text = utf8.decode(datagram.data);
      if (!text.startsWith('${AppConstants.discoveryPrefix}:')) return;
      final body = text.substring(AppConstants.discoveryPrefix.length + 1);

      // ① 收到探测包 → 单播回复自己
      if (body == 'PROBE') {
        final reply = jsonEncode({
          'id': _deviceId,
          'name': _deviceName,
          'port': _httpPort,
          'platform': _platform,
        });
        _socket?.send(
          utf8.encode('${AppConstants.discoveryPrefix}:$reply'),
          datagram.address,
          datagram.port,
        );
        return;
      }

      // ② 正常广播 / 单播回复
      final payload = jsonDecode(body) as Map<String, dynamic>;
      final senderId = payload['id'] as String?;
      if (senderId == null || senderId == _deviceId) return;
      final device = Device.fromJson(payload, datagram.address.address);
      _devices[device.id] = device;
      notifyListeners();
    } catch (_) {
      // 忽略格式错误的数据包
    }
  }

  void _startBroadcast() {
    _broadcastTimer =
        Timer.periodic(AppConstants.broadcastInterval, (_) => _sendBroadcast());
    _sendBroadcast();
  }

  Future<void> _sendBroadcast() async {
    final payload = jsonEncode({
      'id': _deviceId,
      'name': _deviceName,
      'port': _httpPort,
      'platform': _platform,
    });
    final bytes = utf8.encode('${AppConstants.discoveryPrefix}:$payload');

    try {
      final interfaces = await NetworkUtils.allIPv4();
      for (final info in interfaces) {
        RawDatagramSocket? s;
        try {
          // 绑源网卡 IP，强制从该网卡发出
          s = await RawDatagramSocket.bind(InternetAddress(info.address), 0);
          s.broadcastEnabled = true;

          final parts = info.address.split('.');
          if (parts.length == 4) {
            final directed = '${parts[0]}.${parts[1]}.${parts[2]}.255';
            try {
              s.send(
                  bytes, InternetAddress(directed), AppConstants.discoveryPort);
            } catch (_) {}
          }
          try {
            s.send(bytes, InternetAddress('255.255.255.255'),
                AppConstants.discoveryPort);
          } catch (_) {}
        } catch (_) {
        } finally {
          s?.close();
        }
      }
    } catch (_) {}
  }
  // Future<void> _sendBroadcast() async {
  //   final payload = jsonEncode({
  //     'id': _deviceId,
  //     'name': _deviceName,
  //     'port': _httpPort,
  //     'platform': _platform,
  //   });
  //   final bytes = utf8.encode('${AppConstants.discoveryPrefix}:$payload');

  //   if (!Platform.isWindows) {
  //     try {
  //       _socket?.send(
  //         bytes,
  //         InternetAddress('255.255.255.255'),
  //         AppConstants.discoveryPort,
  //       );
  //     } catch (_) {}
  //     return;
  //   }

  //   // Windows：对每块私有网卡单独发一次，保证 WiFi 网卡也能发出
  //   try {
  //     final interfaces = await NetworkInterface.list(
  //       type: InternetAddressType.IPv4,
  //       includeLinkLocal: false,
  //     );
  //     for (final iface in interfaces) {
  //       for (final addr in iface.addresses) {
  //         if (addr.isLoopback || !NetworkUtils.isPrivateIp(addr.address)) {
  //           continue;
  //         }
  //         RawDatagramSocket? s;
  //         try {
  //           s = await RawDatagramSocket.bind(addr, 0);
  //           s.broadcastEnabled = true;
  //           s.send(
  //             bytes,
  //             InternetAddress('255.255.255.255'),
  //             AppConstants.discoveryPort,
  //           );
  //         } catch (_) {
  //         } finally {
  //           s?.close();
  //         }
  //       }
  //     }
  //   } catch (_) {}
  // }

  void _startScan() {
    // 启动时扫一次，之后每 15 秒兜底扫一次（广播被路由屏蔽时靠这个）
    _scanSubnet();
    _scanTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _scanSubnet());
  }

  Future<void> _scanSubnet() async {
    if (_scanning) return;
    _scanning = true;
    try {
      final interfaces = await NetworkUtils.allIPv4();
      if (interfaces.isEmpty) return;
      await Future.wait(interfaces.map(_scanOnInterface));
    } finally {
      _scanning = false;
    }
  }

  Future<void> _scanOnInterface(NetworkInterfaceInfo info) async {
    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? sub;
    try {
      // 关键：绑定到该网卡的 IP，发送只会从这块网卡出去
      socket = await RawDatagramSocket.bind(InternetAddress(info.address), 0);
      sub = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = socket?.receive();
        if (dg == null) return;
        try {
          final text = utf8.decode(dg.data);
          if (!text.startsWith('${AppConstants.discoveryPrefix}:')) return;
          final body = text.substring(AppConstants.discoveryPrefix.length + 1);
          if (body == 'PROBE') return;
          final payload = jsonDecode(body) as Map<String, dynamic>;
          final senderId = payload['id'] as String?;
          if (senderId == null || senderId == _deviceId) return;
          final device = Device.fromJson(payload, dg.address.address);
          _devices[device.id] = device;
          notifyListeners();
        } catch (_) {}
      });

      final probe = utf8.encode('${AppConstants.discoveryPrefix}:PROBE');
      final parts = info.address.split('.');
      if (parts.length != 4) return;
      final prefix = '${parts[0]}.${parts[1]}.${parts[2]}.';
      for (var i = 1; i <= 254; i++) {
        final target = '$prefix$i';
        if (target == info.address) continue;
        try {
          socket.send(
              probe, InternetAddress(target), AppConstants.discoveryPort);
        } catch (_) {}
      }

      // 留 2 秒收回复
      await Future.delayed(const Duration(seconds: 2));
    } catch (_) {
    } finally {
      await sub?.cancel();
      socket?.close();
    }
  }
  // Future<void> _scanSubnet() async {
  //   if (_scanning) return;
  //   _scanning = true;
  //   RawDatagramSocket? scanSocket;
  //   StreamSubscription<RawSocketEvent>? sub;
  //   try {
  //     final localIp = _localIp ?? await NetworkUtils.localIpv4();
  //     if (localIp == null) return;
  //     final parts = localIp.split('.');
  //     if (parts.length != 4) return;
  //     final prefix = '${parts[0]}.${parts[1]}.${parts[2]}.';

  //     // 关键：用同一个 socket 发所有探测包，并保持打开收回复
  //     scanSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  //     sub = scanSocket.listen((event) {
  //       if (event != RawSocketEvent.read) return;
  //       final dg = scanSocket?.receive();
  //       if (dg == null) return;
  //       try {
  //         final text = utf8.decode(dg.data);
  //         if (!text.startsWith('${AppConstants.discoveryPrefix}:')) return;
  //         final body = text.substring(AppConstants.discoveryPrefix.length + 1);
  //         if (body == 'PROBE') return;
  //         final payload = jsonDecode(body) as Map<String, dynamic>;
  //         final senderId = payload['id'] as String?;
  //         if (senderId == null || senderId == _deviceId) return;
  //         final device = Device.fromJson(payload, dg.address.address);
  //         _devices[device.id] = device;
  //         notifyListeners();
  //       } catch (_) {}
  //     });

  //     final probe = utf8.encode('${AppConstants.discoveryPrefix}:PROBE');
  //     for (var i = 1; i <= 254; i++) {
  //       final target = '$prefix$i';
  //       if (target == localIp) continue;
  //       try {
  //         scanSocket.send(
  //           probe,
  //           InternetAddress(target),
  //           AppConstants.discoveryPort,
  //         );
  //       } catch (_) {}
  //     }
  //     // 留 2 秒收回复
  //     await Future.delayed(const Duration(seconds: 2));
  //   } catch (_) {
  //   } finally {
  //     _scanning = false;
  //     await sub?.cancel();
  //     scanSocket?.close();
  //   }
  // }

  void _startCleanup() {
    _cleanupTimer = Timer.periodic(AppConstants.cleanupInterval, (_) {
      final now = DateTime.now();
      final expired = _devices.entries
          .where((e) =>
              now.difference(e.value.lastSeen) > AppConstants.deviceTimeout)
          .map((e) => e.key)
          .toList();
      if (expired.isEmpty) return;
      for (final key in expired) {
        _devices.remove(key);
      }
      notifyListeners();
    });
  }

  /// 列出本机所有可用的私有 IPv4 网卡（给 UI 手动切换用）
  Future<List<NetworkInterfaceInfo>> listAvailableInterfaces() =>
      NetworkUtils.allIPv4();

  /// 切换"用哪块网卡参与发现"
  Future<void> switchInterface(String ip) async {
    if (ip == _localIp) return;
    _localIp = ip;
    notifyListeners();
    // 用新网段立即扫一次，不用等下一个 15 秒周期
    unawaited(_scanSubnet());
  }

  @override
  void dispose() {
    _broadcastTimer?.cancel();
    _cleanupTimer?.cancel();
    _scanTimer?.cancel();
    _socket?.close();
    super.dispose();
  }
}
