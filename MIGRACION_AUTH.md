# Autenticación migrada desde Kotlin

## Capas
- packages/core/domain/lib/src/auth: resultados, errores, contratos y casos de uso sin Flutter.
- packages/core/auth/lib/src: Firebase Authentication y selector de cuenta Google.
- packages/core/data/lib/src/repository: transacción del perfil y marca local por UID de perfil validado.
- packages/core/ui/lib/src: tema original, textos español/inglés, errores y marca Google.
- packages/features/auth/lib/src/detail: LoginScreen, LoginUiState, LoginViewModel y LoginRoute.
- lib/di/auth_dependencies.dart: composición mediante constructores, equivalente al grafo Hilt.
- lib/main.dart: inicio de Firebase, restauración y navegación de autenticación.

## Configuración Android
Se reutilizan google-services.json y el applicationId ar.edu.unaj.am.myapplication del proyecto Kotlin para acceder al mismo proyecto Firebase. La namespace de Flutter se conserva. El dispositivo puede considerar ambas implementaciones como la misma aplicación; firmas distintas impiden actualizar una sobre otra.
Google requiere que el certificado SHA de la compilación Flutter esté registrado en Firebase y que el proveedor Google esté habilitado. Ejecutar android/gradlew.bat signingReport para consultar las huellas y verificar la consola si Google rechaza el ingreso.
La implementación de Google utiliza google_sign_in 7: initialize y authenticate. Cerrar el selector no muestra error.

## Comportamiento
Ingreso y registro con correo y contraseña; validación antes de Firebase; Google; transacción que consulta barberos y clientes y solo crea clientes cuando no existe ninguno; campos Nombre, Correo y CreadoEn intactos; reintento de perfil sin repetir ingreso; sesión Firebase restaurada; marca local de perfil validado por UID limpiada al salir.
La marca local no asigna permisos: las reglas de Firestore siguen autorizando cada operación. No reemplaza la validación del rol para la navegación.

## Pendiente fuera de esta migración
La pantalla posterior al ingreso es un punto de integración provisional. Las features de agenda, datos Room, avisos y su limpieza al salir aún no existen en Flutter. El inicio sin conexión permite recuperar la sesión validada, pero no incorpora esos datos offline. Android es la plataforma configurada; iOS y web requieren su configuración Firebase y adaptación de Google.

## Verificación
flutter analyze
flutter build apk --debug
