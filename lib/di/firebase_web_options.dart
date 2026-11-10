import 'package:firebase_core/firebase_core.dart';

const _apiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
const _appId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
const _senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
const _authDomain = String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN');

bool get hasFirebaseWebOptions => [
  _apiKey,
  _appId,
  _projectId,
  _senderId,
  _authDomain,
].every((value) => value.isNotEmpty);

FirebaseOptions get firebaseWebOptions => const FirebaseOptions(
  apiKey: _apiKey,
  appId: _appId,
  messagingSenderId: _senderId,
  projectId: _projectId,
  authDomain: _authDomain,
);
