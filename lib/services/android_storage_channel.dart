import 'dart:io';
import 'package:flutter/services.dart';

class AndroidStorageChannel {
  AndroidStorageChannel._();
  static const _channel = MethodChannel('cn.mingao.fileshare/storage');

  static Future<String?> pickDirectory() async {
    if (!Platform.isAndroid) return null;
    return _channel.invokeMethod<String>('pickDirectory');
  }

  static Future<String?> saveFile({
    required String treeUri,
    required String fileName,
    required String sourcePath,
  }) async {
    if (!Platform.isAndroid) return null;
    return _channel.invokeMethod<String>('saveFile', {
      'treeUri': treeUri,
      'fileName': fileName,
      'sourcePath': sourcePath,
    });
  }
}