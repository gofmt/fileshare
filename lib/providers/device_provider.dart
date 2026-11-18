import 'package:flutter/foundation.dart';

import '../models/device.dart';
import '../services/discovery_service.dart';

class DeviceProvider extends ChangeNotifier {
  DeviceProvider({required this.discovery}) {
    discovery.addListener(_onDiscoveryChanged);
  }

  final DiscoveryService discovery;

  void _onDiscoveryChanged() => notifyListeners();

  List<Device> get devices => discovery.devices;
  String get localDeviceName => discovery.deviceName;
  String? get localIp => discovery.localIp;

  @override
  void dispose() {
    discovery.removeListener(_onDiscoveryChanged);
    super.dispose();
  }
}