import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class WorkImageCache {
  const WorkImageCache();

  Future<web.Cache> _open(String account) =>
      web.window.caches.open('barberapp-work-v1-$account').toDart;

  JSString _key(String name) =>
      Uri.base.resolve('__barberapp_work__/$name').toString().toJS;

  Future<Uint8List?> read(String account, String name) async {
    final cache = await _open(account);
    final response = await cache.match(_key(name)).toDart;
    if (response == null) return null;
    final bytes = await response.arrayBuffer().toDart;
    return bytes.toDart.asUint8List();
  }

  Future<void> write(String account, String name, Uint8List bytes) async {
    final cache = await _open(account);
    await cache.put(_key(name), web.Response(bytes.toJS)).toDart;
  }

  Future<void> retain(String account, Set<String> names) async {
    final cache = await _open(account);
    final requests = await cache.keys().toDart;
    for (final request in requests.toDart) {
      if (!names.contains(Uri.parse(request.url).pathSegments.last)) {
        await cache.delete(request).toDart;
      }
    }
  }
}
