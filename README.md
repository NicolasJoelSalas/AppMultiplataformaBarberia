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

Los valores indicados con `--dart-define` tienen prioridad. Si el preset falta, podés confirmar las reservas y sus cambios sin adjuntar una foto.
