import 'package:domain/domain.dart';

String authErrorMessage(AuthError error, {bool english = false}) {
  final messages = english ? _en : _es;
  return messages[error] ?? messages[AuthError.unknown]!;
}

const _es = {
  AuthError.requiredFields: 'Completá el correo y la contraseña.',
  AuthError.invalidEmail: 'Ingresá un correo válido.',
  AuthError.passwordLength: 'La contraseña debe tener al menos 6 caracteres.',
  AuthError.passwordConfirmation: 'Las contraseñas no coinciden.',
  AuthError.emailExists: 'Ese correo ya está registrado.',
  AuthError.weakPassword: 'La contraseña es demasiado débil.',
  AuthError.loginFailed: 'No se pudo iniciar sesión. Revisá tus datos.',
  AuthError.registerFailed: 'No se pudo crear la cuenta.',
  AuthError.network: 'Revisá tu conexión a Internet.',
  AuthError.googleAccount: 'No se pudo iniciar sesión con Google.',
  AuthError.googleOpen: 'No se pudo abrir Google. Revisá la configuración.',
  AuthError.googleUnavailable: 'Google no está configurado.',
  AuthError.profileSignin: 'Iniciá sesión para completar tu perfil.',
  AuthError.missingEmail: 'La cuenta no tiene un correo asociado.',
  AuthError.profileLoad: 'No se pudo cargar tu perfil. Reintentá con conexión.',
  AuthError.unknown: 'No se pudo completar la operación.',
};
const _en = {
  AuthError.requiredFields: 'Enter your email and password.',
  AuthError.invalidEmail: 'Enter a valid email address.',
  AuthError.passwordLength: 'Use at least 6 characters.',
  AuthError.passwordConfirmation: 'Passwords do not match.',
  AuthError.emailExists: 'That email is already registered.',
  AuthError.weakPassword: 'The password is too weak.',
  AuthError.loginFailed: 'Unable to sign in. Check your credentials.',
  AuthError.registerFailed: 'Unable to create your account.',
  AuthError.network: 'Check your Internet connection.',
  AuthError.googleAccount: 'Unable to sign in with Google.',
  AuthError.googleOpen: 'Unable to open Google. Check the configuration.',
  AuthError.googleUnavailable: 'Google is not configured.',
  AuthError.profileSignin: 'Sign in to complete your profile.',
  AuthError.missingEmail: 'Your account has no email address.',
  AuthError.profileLoad: 'Unable to load your profile. Try again online.',
  AuthError.unknown: 'Unable to complete this operation.',
};
