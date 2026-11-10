import 'dart:async';

import 'package:core_data/core_data.dart';
import 'package:flutter/foundation.dart';

class AndroidPushRegistration {
  AndroidPushRegistration(this._devices);

  final FirebasePushDevices _devices;
  StreamSubscription<void>? _tokenChanges;
  String? _uid;
  String? _token;
  Future<void>? _pending;
  bool _dirty = false;

  void start(String uid) {
    if (_uid == uid) return;
    _uid = uid;
    _token = null;
    try {
      _tokenChanges = _devices.tokenChanges.listen(
        (_) => refresh(),
        onError: (Object _) =>
            debugPrint('Could not observe FCM token changes.'),
      );
    } catch (_) {
      debugPrint('Could not initialize the FCM token listener.');
    }
    refresh();
  }

  void refresh() {
    final uid = _uid;
    if (uid == null) return;
    _dirty = true;
    _pending ??= _register(uid).whenComplete(() {
      _pending = null;
      if (_dirty) refresh();
    });
  }

  Future<void> _register(String uid) async {
    while (_uid == uid && _dirty) {
      _dirty = false;
      try {
        final token = await _devices.register(
          uid,
          _token,
          isActive: () => _uid == uid,
        );
        if (_uid == uid) _token = token;
      } catch (_) {
        // A later resume or token change can retry registration.
        debugPrint('Could not register the FCM installation.');
      }
    }
  }

  Future<void> stop() async {
    final uid = _uid;
    dispose();
    await _pending;
    if (uid == null) return;
    try {
      await _devices.unregister(uid);
    } catch (_) {
      debugPrint('Could not finish unlinking the FCM installation.');
    }
  }

  void dispose() {
    _uid = null;
    _token = null;
    _dirty = false;
    unawaited(_tokenChanges?.cancel());
    _tokenChanges = null;
  }
}
