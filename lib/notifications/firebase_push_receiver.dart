import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_data/core_data.dart';
import 'package:core_ui/core_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> receiveBackgroundAppointmentPush(RemoteMessage message) async {
  // Android displays notification payloads itself. Data-only messages let
  // Flutter validate the current session before presenting anything.
  if (message.notification != null) return;
  try {
    await Firebase.initializeApp();
    final auth = FirebaseAuth.instance;
    await auth.authStateChanges().first.timeout(const Duration(seconds: 5));
    await receiveAppointmentPush(
      message,
      AndroidAppointmentAlerts(
        FirestoreBookingRepository(FirebaseFirestore.instance, auth),
        appointmentNoticeText,
      ),
      () => auth.currentUser?.uid,
    );
  } catch (_) {
    debugPrint('Could not process a background FCM message.');
  }
}

Future<void> receiveAppointmentPush(
  RemoteMessage message,
  AndroidAppointmentAlerts alerts,
  String? Function() currentUid,
) async {
  final recipient = message.data['barberoId'];
  if (recipient is! String || recipient.isEmpty || recipient != currentUid()) {
    return;
  }
  final body = message.data['texto'] ?? message.notification?.body;
  if (body is! String || body.trim().isEmpty) return;
  final title = message.data['titulo'] ?? message.notification?.title;
  final event = message.data['eventoId'] ?? message.messageId;
  try {
    await alerts.showRemote(
      recipient,
      body.trim(),
      title: title is String ? title.trim() : null,
      eventId: event is String && event.isNotEmpty ? event : null,
      isCurrent: () => currentUid() == recipient,
    );
  } catch (_) {
    debugPrint('Could not present an FCM message.');
  }
}
