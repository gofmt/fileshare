enum TransferDirection { send, receive }

enum TransferStatus { waiting, transferring, completed, failed, canceled }

class TransferTask {
  final String id;
  final String fileName;
  final int fileSize;
  final TransferDirection direction;
  final String peerName;
  TransferStatus status;
  int transferredBytes;
  String? errorMessage;
   String? savedLocation; // 新增

  TransferTask({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.direction,
    required this.peerName,
    this.status = TransferStatus.waiting,
    this.transferredBytes = 0,
    this.errorMessage,
    this.savedLocation,
  });

  double get progress {
    if (fileSize <= 0) return 0;
    return (transferredBytes / fileSize).clamp(0.0, 1.0);
  }

  bool get isActive =>
      status == TransferStatus.waiting ||
      status == TransferStatus.transferring;
}