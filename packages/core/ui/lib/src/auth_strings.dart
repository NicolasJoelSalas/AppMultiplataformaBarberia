import 'package:flutter/widgets.dart';

class AuthStrings {
  AuthStrings(BuildContext context)
    : english = Localizations.localeOf(context).languageCode == 'en';
  final bool english;
  String text(String key) => (english ? _en : _es)[key] ?? key;
  static const _es = {
    'barber_app': 'BARBER APP',
    'crea_tu_cuenta': 'Creá tu cuenta',
    'bienvenido': 'Bienvenido',
    'registrate_para_reservar_tu_proximo_corte':
        'Registrate para reservar tu próximo corte.',
    'tu_barberia_en_un_solo_lugar_reserva_tu_turno_o_gestiona_tu_agenda_como_barbero': 'Tu barbería en un solo lugar. Reservá tu turno o gestioná tu agenda como barbero.',
    'datos_de_tu_cuenta': 'Datos de tu cuenta',
    'iniciar_sesion': 'Iniciar sesión',
    'falta_completar_tu_perfil_tu_cuenta_ya_esta_creada':
        'Falta completar tu perfil. Tu cuenta ya está creada.',
    'procesando': 'Procesando…',
    'reintentar': 'Reintentar',
    'correo_electronico': 'Correo electrónico',
    'contrasena': 'Contraseña',
    'ocultar_contrasena': 'Ocultar contraseña',
    'mostrar_contrasena': 'Mostrar contraseña',
    'confirmar_contrasena': 'Confirmar contraseña',
    'usa_una_contrasena_de_al_menos_6_caracteres':
        'Usá una contraseña de al menos 6 caracteres.',
    'crear_cuenta': 'Crear cuenta',
    'ingresar': 'Ingresar',
    'o_continua_con': 'o continuá con',
    'continuar_con_google': 'Continuar con Google',
    'ya_tengo_cuenta_iniciar_sesion': 'Ya tengo cuenta · Iniciar sesión',
    'no_tengo_cuenta_registrarme': 'No tengo cuenta · Registrarme',
  };
  static const _en = {
    'barber_app': 'BARBER APP',
    'crea_tu_cuenta': 'Create your account',
    'bienvenido': 'Welcome',
    'registrate_para_reservar_tu_proximo_corte':
        'Sign up to book your next haircut.',
    'tu_barberia_en_un_solo_lugar_reserva_tu_turno_o_gestiona_tu_agenda_como_barbero': 'Your barbershop in one place. Book an appointment or manage your schedule as a barber.',
    'datos_de_tu_cuenta': 'Account details',
    'iniciar_sesion': 'Sign in',
    'falta_completar_tu_perfil_tu_cuenta_ya_esta_creada':
        'Your account has been created. Complete your profile to continue.',
    'procesando': 'Processing…',
    'reintentar': 'Try again',
    'correo_electronico': 'Email address',
    'contrasena': 'Password',
    'ocultar_contrasena': 'Hide password',
    'mostrar_contrasena': 'Show password',
    'confirmar_contrasena': 'Confirm password',
    'usa_una_contrasena_de_al_menos_6_caracteres':
        'Use a password with at least 6 characters.',
    'crear_cuenta': 'Create account',
    'ingresar': 'Sign in',
    'o_continua_con': 'or continue with',
    'continuar_con_google': 'Continue with Google',
    'ya_tengo_cuenta_iniciar_sesion': 'I already have an account · Sign in',
    'no_tengo_cuenta_registrarme': 'I need an account · Sign up',
  };
}
