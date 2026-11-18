import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'android_storage_channel.dart'; 

class FileService {
  Future<List<File>> pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
      withReadStream: true,
    );
    if (result == null) return const [];

    final files = <File>[];
    for (final picked in result.files) {
      if (picked.path != null) {
        files.add(File(picked.path!));
        continue;
      }
      final stream = picked.readStream;
      if (stream == null) continue;
      final tmp = await getTemporaryDirectory();
      final file = File('${tmp.path}/${picked.name}');
      final sink = file.openWrite();
      await stream.pipe(sink);
      files.add(file);
    }
    return files;
  }

  Future<Directory> saveDirectory() async {
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external != null) {
        final dir = Directory('${external.path}/Download');
        if (!await dir.exists()) await dir.create(recursive: true);
        return dir;
      }
    }
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads;
    return getApplicationDocumentsDirectory();
  }

  Future<String> uniquePath(String dir, String name) async {
    var candidate = '$dir/$name';
    if (!await File(candidate).exists()) return candidate;
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';
    var i = 1;
    while (await File('$dir/$base ($i)$ext').exists()) {
      i++;
    }
    return '$dir/$base ($i)$ext';
  }


String? _cachedTreeUri;

// 获取保存的目录 URI
Future<String?> getReceiveTreeUri() async {
  if (!Platform.isAndroid) return null;
  if (_cachedTreeUri != null) return _cachedTreeUri;
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/fileshare_config.json');
    if (await file.exists()) {
      final json = jsonDecode(await file.readAsString());
      _cachedTreeUri = json['receiveTreeUri'] as String?;
      return _cachedTreeUri;
    }
  } catch (_) {}
  return null;
}

// 保存目录 URI
Future<void> setReceiveTreeUri(String? uri) async {
  _cachedTreeUri = uri;
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/fileshare_config.json');
    await file.writeAsString(jsonEncode({'receiveTreeUri': uri}));
  } catch (_) {}
}

// 将临时文件移动到用户选定的公共目录
Future<String?> moveToReceiveDirectory({
  required String tempPath,
  required String fileName,
}) async {
  if (!Platform.isAndroid) return null;
  final treeUri = await getReceiveTreeUri();
  if (treeUri == null) return null;
  try {
    final savedUri = await AndroidStorageChannel.saveFile(
      treeUri: treeUri,
      fileName: fileName,
      sourcePath: tempPath,
    );
    if (savedUri != null) {
      await File(tempPath).delete(); // 移完就删掉临时文件
      return '已保存到所选文件夹';
    }
  } catch (_) {}
  return null;
}
}