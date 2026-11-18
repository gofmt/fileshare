import 'dart:async';
import 'dart:io';

import 'package:fileshare/services/android_storage_channel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../models/device.dart';
import '../providers/device_provider.dart';
import '../providers/transfer_provider.dart';
import '../services/file_service.dart';
import '../services/http_client_service.dart';
import '../widgets/device_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/transfer_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.watch<DeviceProvider>();
    final transferProvider = context.watch<TransferProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: '清除已完成记录',
            icon: const Icon(Icons.cleaning_services_outlined),
            onPressed: transferProvider.clearCompleted,
          ),
        ],
      ),
      body: Column(
        children: [
_LocalInfoCard(
  name: deviceProvider.localDeviceName,
  ip: deviceProvider.localIp,
  onTap: () => _pickInterface(context),
),
//
// 在 body 的 Column 中，_LocalInfoCard 下方插入：
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Text('接收文件夹设置：'),
      TextButton.icon(
        icon: const Icon(Icons.folder_open),
        label: const Text('选择公共目录'),
        onPressed: () => _pickReceiveFolder(context),
      ),
    ],
  ),
),
          Expanded(
            child: ListView(
              children: [
                _SectionTitle(
                  title: '附近设备',
                  count: deviceProvider.devices.length,
                ),
                if (deviceProvider.devices.isEmpty)
                  const EmptyState(
                    icon: Icons.devices_other,
                    message: '正在搜索局域网内的设备…\n请确保双方在同一 Wi-Fi / 局域网',
                  )
                else
                  ...deviceProvider.devices.map(
                    (d) => DeviceCard(
                      device: d,
                      onTap: () => _sendToDevice(context, d),
                    ),
                  ),
                _SectionTitle(
                  title: '传输记录',
                  count: transferProvider.tasks.length,
                ),
                if (transferProvider.tasks.isEmpty)
                  const EmptyState(
                    icon: Icons.swap_vert,
                    message: '暂无传输任务\n点击上方设备卡片即可发送文件',
                  )
                else
                  ...transferProvider.tasks.map(
                    (t) => TransferCard(task: t),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
Future<void> _pickReceiveFolder(BuildContext context) async {
  if (!Platform.isAndroid) return;
  final fileService = context.read<FileService>();
  final uri = await AndroidStorageChannel.pickDirectory();
  if (!context.mounted) return;
  if (uri != null) {
    await fileService.setReceiveTreeUri(uri);
   if (!context.mounted) return; // 👈 加上这一句，第二个检查
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('接收文件夹已更新，接收的文件将直接保存到这里')),
    );
  }
}
  Future<void> _sendToDevice(BuildContext context, Device device) async {
    final fileService = context.read<FileService>();
    final transferProvider = context.read<TransferProvider>();
    final deviceProvider = context.read<DeviceProvider>();

    final files = await fileService.pickFiles();
    if (files.isEmpty) return;

    for (final file in files) {
      final size = await file.length();
      final taskId = transferProvider.createSendTask(
        file.uri.pathSegments.last,
        size,
        device.name,
      );
      unawaited(
        HttpTransferClient()
            .sendFile(
              device: device,
              file: file,
              localDeviceName: deviceProvider.localDeviceName,
              onProgress: (sent, _) =>
                  transferProvider.updateProgress(taskId, sent),
            )
            .then((_) => transferProvider.completeTask(taskId))
            .catchError((Object e) => transferProvider.failTask(taskId, '$e')),
      );
    }
  }
}

class _LocalInfoCard extends StatelessWidget {
  const _LocalInfoCard({
    required this.name,
    required this.ip,
    required this.onTap,
  });

  final String name;
  final String? ip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        child: Row(
          children: [
            Icon(Icons.computer, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('本机：$name', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text('IP：${ip ?? '获取中…'}（点击切换网卡）',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.swap_horiz, color: theme.disabledColor),
          ],
        ),
      ),
    );
  }
}
Future<void> _pickInterface(BuildContext context) async {
  final discovery = context.read<DeviceProvider>().discovery;
  final interfaces = await discovery.listAvailableInterfaces();
  if (!context.mounted) return;
  if (interfaces.length <= 1) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('只有一个可用网卡，无需切换')),
    );
    return;
  }
  final current = discovery.localIp;
  final selected = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('选择用于传输的网卡'),
          ),
          ...interfaces.map((i) {
            final active = i.address == current;
            final icon = switch (i.type) {
              'wifi' => Icons.wifi,
              'ethernet' => Icons.settings_ethernet,
              _ => Icons.devices_other,
            };
            return ListTile(
              leading: Icon(icon,
                  color: active
                      ? Theme.of(ctx).colorScheme.primary
                      : null),
              title: Text(i.name),
              subtitle: Text(i.address),
              trailing: active ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, i.address),
            );
          }),
        ],
      ),
    ),
  );
  if (selected != null && selected != current) {
    await discovery.switchInterface(selected);
  }
}
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(width: 6),
          Text('($count)', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}