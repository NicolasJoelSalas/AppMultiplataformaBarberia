import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart';
import 'package:domain/domain.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'appointment_alerts.dart';

const _alertTask = 'appointment-alerts';

@pragma('vm:entry-point')
void appointmentAlertsDispatcher() {
  Workmanager().executeTask((task, input) async {
    final uid = input?['uid'];
    if (task != _alertTask || uid is! String) return true;
    try {
      await Firebase.initializeApp();
      final auth = FirebaseAuth.instance;
      if (auth.currentUser?.uid != uid) return true;
      await AndroidAppointmentAlerts(
        FirestoreBookingRepository(FirebaseFirestore.instance, auth),
        appointmentNoticeText,
      ).sync(uid);
      return true;
    } on FirebaseException catch (error) {
      return error.code == 'permission-denied' ||
          error.code == 'unauthenticated';
    } catch (_) {
      return false;
    }
  });
}

class AppointmentAlertController extends AppointmentAlerts {
  AppointmentAlertController(this._session, this._bookings, this._storage)
    : _alerts = AndroidAppointmentAlerts(_bookings, appointmentNoticeText);

  final SesionActual _session;
  final AppointmentAlertRepository _bookings;
  final SharedPreferences _storage;
  final AndroidAppointmentAlerts _alerts;
  StreamSubscription<void>? _subscription;
  Future<void> _lifecycle = Future.value();
  Future<void>? _sync;
  Timer? _retry;
  String? _uid;
  AccountRole? _role;
  bool? _english;
  bool _dirty = false;
  bool _disposed = false;
  String? _tappedUid;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize() async {
    await _alerts.initialize((uid) {
      if (_disposed) return;
      _tappedUid = uid;
      notifyListeners();
    });
    try {
      await Workmanager().initialize(appointmentAlertsDispatcher);
    } catch (_) {
      debugPrint('Could not initialize background appointment alerts.');
    }
    if (_session.usuarioId == null) await stop();
  }

  @override
  bool get supportsSystemPermissions => true;

  @override
  bool takeTap() {
    final tapped = _tappedUid;
    if (tapped == null) return false;
    _tappedUid = null;
    return tapped == _session.usuarioId;
  }

  @override
  void start(AccountRole role, {required bool english}) {
    final uid = _session.usuarioId;
    if (uid == null) return;
    _enqueue(() async {
      if (_disposed ||
          _session.usuarioId != uid ||
          (_uid == uid && _role == role && _english == english)) {
        return;
      }
      await _subscription?.cancel();
      _retry?.cancel();
      await _alerts.activate(uid, role, english: english);
      if (_disposed) return;
      _uid = uid;
      _role = role;
      _english = english;
      _listen(uid, role);
      refresh();
      try {
        await Workmanager().registerPeriodicTask(
          _alertTask,
          _alertTask,
          frequency: const Duration(minutes: 15),
          constraints: Constraints(networkType: NetworkType.connected),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
          inputData: {'uid': uid},
        );
      } catch (_) {
        debugPrint('Could not register background appointment alerts.');
      }

      final key = 'askedForAppointmentNotifications.$uid';
      if (_storage.getBool(key) != true) {
        await _storage.setBool(key, true);
        unawaited(requestPermissions(exact: false));
      }
    });
  }

  void _listen(String uid, AccountRole role) {
    unawaited(_subscription?.cancel());
    _subscription = _bookings
        .watchAppointmentAlertChanges(role, uid)
        .listen(
          (_) => refresh(),
          onError: (Object _) {
            _retry?.cancel();
            _retry = Timer(const Duration(seconds: 30), () {
              if (_uid == uid && _role == role) _listen(uid, role);
            });
          },
        );
  }

  @override
  Future<bool> requestPermissions({required bool exact}) async {
    try {
      if (_uid == null || _uid != _session.usuarioId) return false;
      return await _alerts.requestPermissions(exact: exact);
    } catch (_) {
      return false;
    } finally {
      refresh();
    }
  }

  @override
  void refresh() {
    final uid = _uid;
    if (uid == null || _session.usuarioId != uid) return;
    _dirty = true;
    _sync ??= _drain(uid).whenComplete(() {
      _sync = null;
      if (_dirty) refresh();
    });
  }

  Future<void> _drain(String uid) async {
    while (_dirty && _uid == uid) {
      _dirty = false;
      try {
        await _alerts.sync(uid);
      } catch (_) {
        // The next confirmed snapshot, resume or background job retries.
      }
    }
  }

  @override
  Future<void> stop() => _enqueue(() async {
    _uid = null;
    _role = null;
    _english = null;
    _dirty = false;
    _tappedUid = null;
    _retry?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _alerts.deactivate();
    } finally {
      await Workmanager().cancelByUniqueName(_alertTask);
    }
  });

  @override
  void dispose() {
    _disposed = true;
    _uid = null;
    _dirty = false;
    _retry?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _enqueue(Future<void> Function() action) {
    _lifecycle = _lifecycle.then((_) => action()).catchError((Object _) {
      debugPrint('Could not update the appointment alerts session.');
    });
    return _lifecycle;
  }
}
