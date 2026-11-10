# barberapp

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# AppMultiplataformaBarberia

## Fotos de referencia en Android

Copiá el nombre de nube y el preset unsigned de Cloudinary que configuraste en Kotlin a `android/local.properties` de Flutter.

```properties
cloudinary.cloudName=TU_CLOUD_NAME
cloudinary.uploadPreset=TU_UPLOAD_PRESET
```

Volvé a compilar la app de Android para aplicar los cambios. También podés indicar ambos valores al ejecutar o compilar Flutter.

```powershell
flutter run --dart-define=CLOUDINARY_CLOUD_NAME=TU_CLOUD_NAME --dart-define=CLOUDINARY_UPLOAD_PRESET=TU_UPLOAD_PRESET
```

Los valores indicados con `--dart-define` tienen prioridad. El mismo preset se usa al publicar trabajos. Si falta, podés confirmar reservas y sus cambios sin adjuntar una foto.

## Ejecutar en una computadora

La versión Web comparte las cuentas, los turnos y los trabajos con Android cuando ambas usan el mismo proyecto Firebase. En pantallas anchas, la navegación aparece a la izquierda.

1. En la consola de Firebase, abrí **Configuración del proyecto → Tus apps**. Elegí la app Web existente o registrá una con el ícono `</>`. Copiá los datos del bloque `firebaseConfig`.
2. Copiá `web_config.example.json` como `web_config.local.json` y completá los campos con `apiKey`, `appId`, `projectId`, `messagingSenderId` y `authDomain`, en ese orden. Si ya tenés un archivo local preparado, completá los campos vacíos. Para subir fotos, usá el mismo nombre de nube y preset de Cloudinary que en Android.
3. Para usar **Continuar con Google**, habilitá ese proveedor en Authentication y agregá `localhost` para pruebas o el dominio publicado en **Dominios autorizados**.
4. Abrí la app en Chrome o Edge.

```powershell
flutter run -d chrome --dart-define-from-file=web_config.local.json
flutter run -d edge --dart-define-from-file=web_config.local.json
```

Para generar la versión que se sirve desde un sitio HTTPS:

```powershell
flutter build web --dart-define-from-file=web_config.local.json
```

El navegador permite elegir fotos desde archivos. El GPS depende del permiso de ubicación y de un origen seguro como HTTPS o localhost. Con la app abierta, se pueden consultar los turnos, trabajos y fotos guardados en ese navegador. Los recordatorios y novedades aparecen dentro de la página mientras está abierta. Para recibirlos con el navegador cerrado haría falta habilitar avisos push y programarlos desde un servidor.

## Trabajos, ubicación y turnos en Android

- **Trabajos.** El barbero publica desde cámara o galería y administra sus publicaciones. El cliente ve el feed en Inicio y abre una reserva con el barbero seleccionado. Firestore usa los mismos campos y reglas del proyecto Kotlin. Al eliminar un trabajo, se retira del feed. Cloudinary conserva el archivo alojado.
- **Cómo llegar.** El barbero guarda su ubicación desde Mi cuenta. El cliente puede calcular el recorrido desde una publicación o un turno próximo, con el GPS o un punto del mapa. El recorrido usa OSRM. Para usar otro servidor compatible, compilá con `--dart-define=OSRM_BASE_URL=https://tu-servidor/`.
- **Sin conexión.** Con la sesión iniciada, la app guarda por cuenta la última lista de turnos confirmada por el servidor, junto con las publicaciones y las fotos que terminó de descargar. Abrí la app con conexión para preparar la copia local.
- **Avisos.** El cliente recibe recordatorios 24 horas y 1 hora antes de los turnos próximos. La app también detecta cambios y cancelaciones mientras está abierta y los consulta periódicamente en segundo plano cuando Android lo permite. Tocá un aviso para abrir Turnos. En Turnos podés solicitar los permisos de notificaciones y alarmas exactas. Sin el permiso de alarmas exactas, Android puede demorar la entrega.
