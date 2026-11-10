import 'package:domain/domain.dart';

AppointmentStatus decodeAppointmentStatus(Object? value) =>
    switch (value.toString().toLowerCase()) {
      'true' || 'confirmado' || 'pendiente' => AppointmentStatus.pending,
      'false' || 'cancelado' || 'cancelada' => AppointmentStatus.canceled,
      'realizado' || 'completado' => AppointmentStatus.completed,
      _ => AppointmentStatus.other,
    };
