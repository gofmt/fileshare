import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import 'file_service.dart';

class HttpServerService {
  HttpServerService({required this.fileService});

  final FileService fileService;

  HttpServer? _server;
  int get port => _server?.port ?? 0;

  void Function(String taskId, String fileName, int fileSize, String peer)?
      onUploadStarted;
  void Function(String taskId, int transferredBytes)? onUploadProgress;
  void Function(String taskId, String? finalLocation)? onUploadCompleted;
  // void Function(String taskId)? onUploadCompleted;
  void Function(String taskId, String error)? onUploadFailed;

  Future<void> start() async {
    final router = Router()
      ..get('/info', _handleInfo)
      ..post('/upload', _handleUpload);

    _server = await shelf_io.serve(
      const Pipeline().addMiddleware(logRequests()).addHandler(router.call),
      InternetAddress.anyIPv4,
      0, // 由系统分配端口，写入 UDP 广播供对端发现
    );
  }

  Response _handleInfo(Request request) {
    return Response.ok(
      jsonEncode({
        'name': Platform.localHostname,
        'platform': Platform.operatingSystem,
      }),
      headers: {'content-type': 'application/json'},
    );
  }

  Future<Response> _handleUpload(Request request) async {
    final rawFileName = request.headers['x-file-name'];
    if (rawFileName == null || rawFileName.isEmpty) {
      return Response.badRequest(body: 'x-file-name required');
    }
    final fileName = Uri.decodeComponent(rawFileName); // ← 解码

    final fileSize = int.tryParse(request.headers['x-file-size'] ?? '') ?? 0;
    final rawPeer = request.headers['x-device-name'] ?? 'peer';
    final peer = Uri.decodeComponent(rawPeer); // ← 解码
    // final fileName = request.headers['x-file-name'];
    // if (fileName == null || fileName.isEmpty) {
    //   return Response.badRequest(body: 'x-file-name required');
    // }
    // final fileSize =
    //     int.tryParse(request.headers['x-file-size'] ?? '') ?? 0;
    // final peer = request.headers['x-device-name'] ?? 'peer';

    final taskId = const Uuid().v4();

    final dir = await fileService.saveDirectory();
    final savePath = await fileService.uniquePath(dir.path, fileName);
    final sink = File(savePath).openWrite();

    onUploadStarted?.call(taskId, fileName, fileSize, peer);
    var received = 0;
    try {
      await for (final chunk in request.read()) {
        sink.add(chunk);
        received += chunk.length;
        onUploadProgress?.call(taskId, received);
      }
      await sink.flush();
      await sink.close();
          // 【新增】尝试移动到公共目录
    final finalLoc = await fileService.moveToReceiveDirectory(
      tempPath: savePath,
      fileName: fileName,
    );
      onUploadCompleted?.call(taskId, finalLoc); // 传回结果
      // onUploadCompleted?.call(taskId);
      return Response.ok('ok');
    } catch (e) {
      await sink.close();
      onUploadFailed?.call(taskId, e.toString());
      return Response.internalServerError(body: 'upload failed: $e');
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}
