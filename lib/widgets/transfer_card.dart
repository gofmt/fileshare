import 'package:flutter/material.dart';

import '../core/utils.dart';
import '../models/transfer_task.dart';

class TransferCard extends StatelessWidget {
  const TransferCard({super.key, required this.task});

  final TransferTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSend = task.direction == TransferDirection.send;
    final statusText = switch (task.status) {
      TransferStatus.waiting => '等待中',
      TransferStatus.transferring => isSend ? '发送中' : '接收中',
      TransferStatus.completed => '已完成',
      TransferStatus.failed => '失败',
      TransferStatus.canceled => '已取消',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSend ? Icons.upload : Icons.download,
                  color: isSend
                      ? theme.colorScheme.primary
                      : theme.colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(statusText, style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value:
                  task.status == TransferStatus.completed ? 1.0 : task.progress,
              minHeight: 4,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${FileUtils.formatBytes(task.transferredBytes)} / ${FileUtils.formatBytes(task.fileSize)}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  isSend ? '→ ${task.peerName}' : '← ${task.peerName}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            //
            // 在原来的进度条下面添加这段：
            if (task.status == TransferStatus.completed &&
                task.direction == TransferDirection.receive)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  task.savedLocation ?? '已保存到应用私有目录',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: task.savedLocation != null
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).disabledColor,
                      ),
                ),
              ),

            //
            if (task.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  task.errorMessage!,
                  style:
                      TextStyle(color: theme.colorScheme.error, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
