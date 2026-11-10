import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

abstract class AppointmentAlerts extends ChangeNotifier {
  void start(AccountRole role, {required bool english});
  void refresh();
  Future<void> stop();

  bool get supportsSystemPermissions => false;
  bool takeTap() => false;
  List<AppointmentNotice> takeNotices() => const [];
  Future<bool> requestPermissions({required bool exact}) async => false;
}
