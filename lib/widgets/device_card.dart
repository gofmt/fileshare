import 'package:flutter/material.dart';

import '../models/device.dart';

class DeviceCard extends StatelessWidget {
  const DeviceCard({super.key, required this.device, required this.onTap});

  final Device device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = device.platform == 'android'
        ? Icons.phone_android
        : device.platform == 'windows'
            ? Icons.desktop_windows
            : Icons.devices_other;
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(device.name),
        subtitle: Text('${device.ip}:${device.port}'),
        trailing: const Icon(Icons.send),
        onTap: onTap,
      ),
    );
  }
}
