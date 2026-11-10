import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class WorkImageCache {
  const WorkImageCache();

  Future<Directory> _directory(String account) async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/work/$account');
  }

  Future<Uint8List?> read(String account, String name) async {
    final directory = await _directory(account);
    final file = File('${directory.path}/$name');
    return await file.exists() ? file.readAsBytes() : null;
  }

  Future<void> write(String account, String name, Uint8List bytes) async {
    final directory = await _directory(account);
    final file = File('${directory.path}/$name');
    await directory.create(recursive: true);
    final temporary = await File('${file.path}.tmp').writeAsBytes(bytes);
    await temporary.rename(file.path);
  }

  Future<void> clear(String account) async {
    final directory = await _directory(account);
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<void> retain(String account, Set<String> names) async {
    final directory = await _directory(account);
    if (!await directory.exists()) return;
    await for (final entry in directory.list()) {
      final name = entry.uri.pathSegments.last;
      if (entry is File && name.endsWith('.jpg') && !names.contains(name)) {
        await entry.delete();
      }
    }
  }
}
