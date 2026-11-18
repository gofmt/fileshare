import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fileshare/app.dart';
import 'package:fileshare/providers/device_provider.dart';
import 'package:fileshare/providers/transfer_provider.dart';
import 'package:fileshare/services/discovery_service.dart';
import 'package:fileshare/services/file_service.dart';

void main() {
  testWidgets('应用可以正常渲染首页', (tester) async {
    final discovery = DiscoveryService();
    final deviceProvider = DeviceProvider(discovery: discovery);
    final transferProvider = TransferProvider();
    final fileService = FileService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<FileService>.value(value: fileService),
          ChangeNotifierProvider.value(value: deviceProvider),
          ChangeNotifierProvider.value(value: transferProvider),
        ],
        child: const FileshareApp(),
      ),
    );

    // 首页 AppBar 标题应出现
    expect(find.text('明奥文件快传'), findsOneWidget);
  });
}