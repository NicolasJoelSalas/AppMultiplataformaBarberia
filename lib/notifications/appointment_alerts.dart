import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

abstract class AppointmentAlerts extends ChangeNotifier {
  void start(AccountRole role, {required bool english});
  void refresh();
  Future<void> stop();

  bool get supportsSystemPermissions => false;
  Set<String>? get disabledReminders => null;
  Future<void> setReminderEnabled(String appointmentId, bool enabled) async {}
  bool takeTap() => false;
  List<AppointmentNotice> takeNotices() => const [];
  Future<bool> requestPermissions({required bool exact}) async => false;
}
