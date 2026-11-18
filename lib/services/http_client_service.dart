import 'dart:async';
import 'dart:io';

import '../models/device.dart';

class HttpTransferClient {
  Future<void> sendFile({
    required Device device,
    required File file,
    required String localDeviceName,
    required void Function(int sentBytes, int totalBytes) onProgress,
  }) async {
    final total = await file.length();
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('${device.endpoint}/upload'),
      );
      request.headers
          .set('x-file-name', Uri.encodeComponent(file.uri.pathSegments.last));
      request.headers.set('x-file-size', total.toString());
      request.headers
          .set('x-device-name', Uri.encodeComponent(localDeviceName));
      // request.headers.set('x-file-name', file.uri.pathSegments.last);
      // request.headers.set('x-file-size', total.toString());
      // request.headers.set('x-device-name', localDeviceName);
      request.contentLength = total;

      var sent = 0;
      await for (final chunk in file.openRead()) {
        request.add(chunk);
        sent += chunk.length;
        onProgress(sent, total);
      }
      final response = await request.close();
      await response.drain<void>();
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
    } finally {
      client.close(force: true);
    }
  }
}
