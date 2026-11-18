import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/transfer_task.dart';

class TransferProvider extends ChangeNotifier {
  final List<TransferTask> _tasks = [];
  List<TransferTask> get tasks => List.unmodifiable(_tasks);

  String createSendTask(String fileName, int fileSize, String peerName) {
    final task = TransferTask(
      id: const Uuid().v4(),
      fileName: fileName,
      fileSize: fileSize,
      direction: TransferDirection.send,
      peerName: peerName,
      status: TransferStatus.transferring,
    );
    _tasks.insert(0, task);
    notifyListeners();
    return task.id;
  }

  void createReceiveTask(
      String taskId, String fileName, int fileSize, String peerName) {
    final task = TransferTask(
      id: taskId,
      fileName: fileName,
      fileSize: fileSize,
      direction: TransferDirection.receive,
      peerName: peerName,
      status: TransferStatus.transferring,
    );
    _tasks.insert(0, task);
    notifyListeners();
  }

  // 新增：记录上次刷新时间的字典
  final Map<String, DateTime> _lastUpdateTimes = {};
  void updateProgress(String taskId, int transferredBytes) {
    final task = _find(taskId);
    if (task == null) return;
    
    // 确保永远记录最新的字节数（为了准确性）
    task.transferredBytes = transferredBytes;

    final now = DateTime.now();
    final lastUpdate = _lastUpdateTimes[taskId];

    // 只有距离上次刷新超过 200ms，才通知 UI 重绘
    if (lastUpdate == null || now.difference(lastUpdate).inMilliseconds > 200) {
      _lastUpdateTimes[taskId] = now;
      notifyListeners();
    }
  }

  // void updateProgress(String taskId, int transferredBytes) {
  //   final task = _find(taskId);
  //   if (task == null) return;
  //   task.transferredBytes = transferredBytes;
  //   notifyListeners();
  // }
  // 在任务完成或失败时，强制刷新一次，保证 UI 最终状态正确
  void completeTask(String taskId, {String? savedLocation}) {
    final task = _find(taskId);
    if (task == null) return;
    task.status = TransferStatus.completed;
    if (task.fileSize > 0) task.transferredBytes = task.fileSize;
    task.savedLocation = savedLocation;
    _lastUpdateTimes.remove(taskId); // 清理记录
    notifyListeners(); // 强制刷新
  }
  // void completeTask(String taskId, {String? savedLocation}) {
  //   final task = _find(taskId);
  //   if (task == null) return;
  //   task.status = TransferStatus.completed;
  //   if (task.fileSize > 0) task.transferredBytes = task.fileSize;
  //   task.savedLocation = savedLocation; // 新增
  //   notifyListeners();
  // }
  // // void completeTask(String taskId) {
  // //   final task = _find(taskId);
  // //   if (task == null) return;
  // //   task.status = TransferStatus.completed;
  // //   if (task.fileSize > 0) task.transferredBytes = task.fileSize;
  // //   notifyListeners();
  // // }

  void failTask(String taskId, String error) {
    final task = _find(taskId);
    if (task == null) return;
    task.status = TransferStatus.failed;
    task.errorMessage = error;
    _lastUpdateTimes.remove(taskId); // 清理记录
    notifyListeners(); // 强制刷新
  }
 
  // void failTask(String taskId, String error) {
  //   final task = _find(taskId);
  //   if (task == null) return;
  //   task.status = TransferStatus.failed;
  //   task.errorMessage = error;
  //   notifyListeners();
  // }

  TransferTask? _find(String id) {
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  void clearCompleted() {
    _tasks.removeWhere((t) => !t.isActive);
    notifyListeners();
  }
}
