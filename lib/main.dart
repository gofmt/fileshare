import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/device_provider.dart';
import 'providers/transfer_provider.dart';
import 'services/discovery_service.dart';
import 'services/file_service.dart';
import 'services/http_server_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final discovery = DiscoveryService();
  final fileService = FileService();
  final httpServer = HttpServerService(fileService: fileService);

  final deviceProvider = DeviceProvider(discovery: discovery);
  final transferProvider = TransferProvider();

  httpServer.onUploadStarted = transferProvider.createReceiveTask;
  httpServer.onUploadProgress = transferProvider.updateProgress;
  httpServer.onUploadCompleted = (id, loc) =>
    transferProvider.completeTask(id, savedLocation: loc);
  // httpServer.onUploadCompleted = transferProvider.completeTask;
  httpServer.onUploadFailed = transferProvider.failTask;

  await httpServer.start();
  await discovery.start(port: httpServer.port);

  runApp(
    MultiProvider(
      providers: [
        Provider<FileService>.value(value: fileService),
        Provider<HttpServerService>.value(value: httpServer),
        ChangeNotifierProvider.value(value: deviceProvider),
        ChangeNotifierProvider.value(value: transferProvider),
      ],
      child: const FileshareApp(),
    ),
  );
}