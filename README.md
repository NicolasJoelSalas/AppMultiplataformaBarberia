# Barber App

Aplicación multiplataforma para conectar clientes y barberos. Permite iniciar sesión, consultar y publicar trabajos, gestionar servicios y agenda, solicitar o administrar turnos y compartir la ubicación de la barbería. El repositorio contiene una app Flutter organizada en paquetes Dart por responsabilidades.

## Estado y plataformas

- **Android:** plataforma móvil configurada. Incluye autenticación Firebase, notificaciones locales y remotas, ubicación, selección de fotos y persistencia local complementaria.
- **Web:** aplicación ejecutable en Chrome y Edge. Comparte las cuentas y los datos de Firebase con Android cuando apunta al mismo proyecto. Las notificaciones de turnos funcionan mientras la página está abierta.
- **iOS y escritorio nativo:** el código Flutter puede servir de base, pero este repositorio no incluye actualmente el proyecto/configuración necesarios para ofrecerlos como plataformas listas para ejecutar.

## Arquitectura

La app sigue una arquitectura por capas y módulos. La dirección principal de dependencias es:

```text
lib (arranque, composición y navegación)
  ├── compone features/* con implementaciones de core/*
  ├── features/* ──────────────┐
  ├── core/auth ────────────────┼──> core/domain (modelos, contratos y casos de uso)
  ├── core/data ────────────────┘
  │      ├── Firebase / Firestore / almacenamiento local / APIs del dispositivo
  │      └── core/network ──> Cloudinary y OSRM (HTTP)
  └── core/ui (tema y elementos compartidos)
```

| Capa o paquete | Responsabilidad |
| --- | --- |
| `lib/` | Punto de entrada (`main.dart`), configuración de Firebase Web, composición de dependencias, shell de navegación, preferencias y coordinación de avisos. Aquí se conectan las implementaciones concretas con las features. |
| `packages/core/domain` (`domain`) | Modelos de negocio, contratos de repositorio y casos de uso independientes de Firebase y de la interfaz. Incluye autenticación, perfiles, servicios, agenda, turnos, trabajos, ubicación y recordatorios. |
| `packages/core/data` (`core_data`) | Adaptadores de persistencia e integración: Firestore, Cloudinary, OSRM, ubicación del dispositivo, cachés locales, borradores y registro de dispositivos para FCM. Implementa los contratos del dominio. |
| `packages/core/auth` (`core_auth`) | Adaptación de Firebase Authentication y obtención de credenciales de Google. |
| `packages/core/network` (`network`) | Cliente HTTP compartido para controlar solicitudes, tiempos de espera y descargas. Lo usan los adaptadores de datos para servicios externos. |
| `packages/core/ui` (`core_ui`) | Tema, idioma, textos compartidos, presentación de errores y recursos visuales reutilizables. |
| `packages/features/auth` (`feature_auth`) | Inicio, registro, acceso con Google y estado/presentación del flujo de autenticación. |
| `packages/features/turnos` (`feature_turnos`) | Reserva y consulta de turnos, además de la agenda del barbero. |
| `packages/features/trabajos` (`feature_trabajos`) | Feed y administración de publicaciones de trabajos. |
| `packages/features/cuenta` (`feature_cuenta`) | Perfil, servicios, ubicación de la barbería y resumen de ingresos. |

Las features reciben contratos y modelos del dominio; no crean por sí solas los clientes de Firebase. `lib/di/auth_dependencies.dart` crea adaptadores, casos de uso y modelos de presentación y los entrega a `BarberApp` y `AppShell`. Esto permite mantener las reglas de negocio separadas de la interfaz y de los proveedores externos.

### Inicio de la aplicación

1. `lib/main.dart` inicializa Flutter y Firebase. En Web verifica primero que exista la configuración requerida y muestra un error legible si falta.
2. Carga `SharedPreferences` y llama a `AuthDependencies.create`, que ensambla los repositorios y casos de uso.
3. Se restaura la sesión de Firebase. Si no hay sesión autenticada se muestra acceso; si hay sesión, se carga el perfil y el rol para habilitar el área correspondiente.
4. `AppShell` organiza Inicio, Trabajos, Turnos, Agenda y Mi cuenta. Las pantallas delegan las operaciones a sus ViewModels, casos de uso y repositorios.
5. Los repositorios traducen las operaciones de negocio a Firestore, almacenamiento local o APIs externas. Firebase Rules debe validar permisos en el servidor; el rol usado por la interfaz no reemplaza esa seguridad.

## Funcionalidad y datos

- **Autenticación y perfiles:** Firebase Authentication con correo/contraseña y Google. El perfil se consulta en Firestore; si la cuenta no es un barbero existente, el flujo de autenticación puede crear el perfil de cliente. El cierre de sesión limpia las cachés de la cuenta.
- **Turnos y agenda:** Firestore es la fuente compartida para barberos, servicios, agenda, disponibilidad y turnos. Las reservas y sus cambios se validan mediante transacciones y comprobaciones de disponibilidad en los repositorios.
- **Trabajos y fotos:** los metadatos de publicaciones viven en Firestore. Las imágenes se suben a Cloudinary. Al borrar una publicación se quita del feed, pero el archivo alojado en Cloudinary no se elimina automáticamente.
- **Ubicación y rutas:** la ubicación guardada de la barbería vive en Firestore; la ubicación actual se obtiene con el permiso del dispositivo. El cálculo de rutas usa OSRM y puede apuntar a otro servidor compatible.
- **Preferencias y caché:** `SharedPreferences` conserva preferencias de idioma/tema y datos auxiliares por cuenta. Android mantiene recordatorios y caché local complementaria; Web guarda preferencias y ejecuta sus recordatorios solo con la página abierta.
- **Avisos:** Android programa recordatorios locales de turnos y registra el token FCM de barberos habilitados. El envío de avisos remotos requiere un emisor seguro externo (Firebase Admin SDK o FCM HTTP v1); no se envían desde la app cliente. Web no recibe avisos con la página cerrada.

Los adaptadores consultan colecciones Firestore como `clientes`, `barberos`, `servicios`, `turnos` y `publicaciones`, además de subcolecciones de agenda y disponibilidad. La app espera el esquema y las reglas compatibles con el proyecto Firebase existente; este repositorio no contiene reglas ni funciones de servidor para desplegar.

## Requisitos

- Flutter instalado con Dart **3.13.7 o superior**, compatible con la restricción declarada en `pubspec.yaml`.
- Para Android: Android Studio/SDK y Java 17. El wrapper de Gradle está en `android/gradlew.bat`.
- Un proyecto Firebase con Authentication y Cloud Firestore configurados. Para Google, habilitá el proveedor y registrá las huellas SHA del certificado Android que uses.
- Una configuración de Firebase para Android y otra para Web. Ambas pueden usar el mismo proyecto.
- Cloudinary es opcional para ejecutar sin adjuntar fotos; se necesita su cloud name y un upload preset unsigned para subirlas.

## Preparar la configuración

### Android

Colocá el archivo `google-services.json` correspondiente a tu app Android en `android/app/google-services.json`. En Firebase, la app Android debe usar el `applicationId` `ar.edu.unaj.am.myapplication` definido en `android/app/build.gradle.kts`.

Para habilitar la subida de fotos, agregá estos valores a `android/local.properties` (no los subas al repositorio):

```properties
cloudinary.cloudName=TU_CLOUD_NAME
cloudinary.uploadPreset=TU_UPLOAD_PRESET
```

También se pueden pasar al ejecutar o compilar mediante `--dart-define`; esos valores tienen prioridad sobre los locales de Android:

```powershell
flutter run --dart-define=CLOUDINARY_CLOUD_NAME=TU_CLOUD_NAME --dart-define=CLOUDINARY_UPLOAD_PRESET=TU_UPLOAD_PRESET
```

Si no configurás Cloudinary, se pueden usar los flujos que no adjuntan fotos.

### Web

1. Registrá o seleccioná una app Web en **Firebase Console → Configuración del proyecto → Tus apps**.
2. En este entorno, `web_config.local.json` ya está configurado con los valores de Firebase y Cloudinary. Está ignorado por Git. Para preparar otra copia del proyecto, usá `web_config.example.json` como base.
3. Para iniciar con Google, habilitá el proveedor en Firebase Authentication y agregá `localhost` o el dominio publicado a los dominios autorizados.

La app Web no inicia si faltan los cinco valores Firebase requeridos: `FIREBASE_WEB_API_KEY`, `FIREBASE_WEB_APP_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID` y `FIREBASE_WEB_AUTH_DOMAIN`. Cloudinary es opcional si no se suben fotos.

## Ejecutar

Desde la raíz del repositorio, instalá las dependencias.

```powershell
flutter pub get
```

### Android

Iniciá un emulador o conectá un teléfono con depuración USB habilitada. Consultá los dispositivos disponibles.

```powershell
flutter devices
```

Copiá el identificador de la fila correspondiente a Android y reemplazá `ID_ANDROID` en este comando.

```powershell
flutter run -d ID_ANDROID
```

### Web

El archivo `web_config.local.json` ya está configurado en el proyecto local. Ejecutá uno de estos comandos según el navegador que quieras usar. La opción `--dart-define-from-file` carga esa configuración al iniciar la app.

```powershell
flutter run -d chrome --dart-define-from-file=web_config.local.json
flutter run -d edge --dart-define-from-file=web_config.local.json
```

La opción `-d` selecciona dónde se ejecuta la app. Flutter establece automáticamente `kIsWeb` en `true` al ejecutar en Chrome o Edge, y en `false` al ejecutar en Android. La interfaz también se adapta al ancho disponible para mostrar el menú lateral o la navegación inferior.

### Compilar

Para generar los archivos de distribución, ejecutá el comando de la plataforma correspondiente.

```powershell
flutter build apk --release
flutter build appbundle --release
flutter build web --dart-define-from-file=web_config.local.json
```

El APK/AAB de release requiere configurar firma de producción en Gradle; el proyecto usa firma de depuración para builds locales. Para apuntar las rutas a otro servicio OSRM, agregá `--dart-define=OSRM_BASE_URL=https://tu-servidor/` a `flutter run` o `flutter build`.

## Configuración de servicios y permisos

- **Firebase:** habilitá los métodos de acceso que se usarán, crea/valida las colecciones y despliega reglas de Firestore que permitan cada operación según el usuario autenticado. Android usa `google-services.json`; Web usa `web_config.local.json`.
- **Google Sign-In en Android:** registrá en Firebase las huellas SHA del certificado de depuración o distribución. Las firmas diferentes pueden requerir registros separados.
- **Cloudinary:** el upload preset unsigned se usa desde el cliente para fotos de reservas y publicaciones. No coloques secretos de administración en la app.
- **Ubicación:** el sistema pide permiso al usar GPS. En Web, el navegador exige un origen seguro (HTTPS o `localhost`).
- **Notificaciones Android:** el usuario debe conceder permiso de notificaciones; Android puede requerir habilitar alarmas exactas en Ajustes para respetar horarios precisos. Los mensajes remotos de FCM deben ser solo de datos e incluir `barberoId` y `texto`; opcionalmente `titulo` y `eventoId`.
- **Notificaciones Web:** recordatorios, cambios y cancelaciones se consultan mientras la página está abierta. Para notificar con el navegador cerrado se requiere implementar push y programación del lado servidor.

## Estructura del repositorio

```text
lib/                         Arranque, composición, navegación y avisos
packages/core/domain/        Dominio y contratos
packages/core/data/          Adaptadores y persistencia
packages/core/auth/          Firebase Authentication y Google
packages/core/network/       Cliente HTTP
packages/core/ui/            Tema y componentes compartidos
packages/features/auth/      Acceso y registro
packages/features/turnos/    Turnos y agenda
packages/features/trabajos/  Publicaciones
packages/features/cuenta/    Perfil, servicios y ubicación
android/                     Proyecto Android y recursos nativos
web/                         Entrada, manifest e iconos de la app Web
```

Los paquetes internos están declarados como workspace Dart en el `pubspec.yaml` raíz. Sus dependencias locales se resuelven con rutas relativas bajo `packages/`.

