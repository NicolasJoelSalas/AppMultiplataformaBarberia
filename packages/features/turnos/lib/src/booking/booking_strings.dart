import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

class BookingStrings {
  BookingStrings(BuildContext context)
    : _english = Localizations.localeOf(context).languageCode == 'en',
      _material = MaterialLocalizations.of(context);

  final bool _english;
  final MaterialLocalizations _material;
  String _text(String es, String en) => _english ? en : es;

  String get reserve => _text('Reservar turno', 'Book appointment');
  String get confirm => _text('Confirmar reserva', 'Confirm booking');
  String get confirming => _text('Reservando…', 'Booking…');
  String get booked => _text('Turno reservado.', 'Appointment booked.');
  String get instructions => _text(
    'Seleccioná barbero, servicio y un horario disponible de lunes a sábado.',
    'Choose a barber, a service and an available time from Monday to Saturday.',
  );
  String get barber => _text('Barbero', 'Barber');
  String get client => _text('Cliente', 'Client');
  String get service => _text('Servicio', 'Service');
  String get name => _text('Tu nombre', 'Your name');
  String get current => _text('Esta semana', 'This week');
  String get next => _text('Próxima semana', 'Next week');
  String get retry => _text('Reintentar', 'Try again');
  String get refresh =>
      _text('Actualizar disponibilidad', 'Refresh availability');
  String get cancel => _text('Volver', 'Back');
  String get appointments => _text('Turnos', 'Appointments');
  String get myAppointments => _text('Mis turnos', 'My appointments');
  String get noBarbers =>
      _text('No hay barberos habilitados.', 'No barbers are available.');
  String get noServices => _text(
    'No hay servicios habilitados para este barbero.',
    'This barber has no active services.',
  );
  String get noTimes => _text('Sin horarios disponibles', 'No available times');
  String get noAppointments => _text(
    'No hay turnos para la semana seleccionada.',
    'There are no appointments for the selected week.',
  );
  String get unknownService =>
      _text('Servicio sin asignar', 'Service unavailable');
  String get unknownName => _text('Sin nombre', 'Name unavailable');

  String date(DateTime date) => _material.formatFullDate(date);

  String serviceOption(BookingService item) {
    final name = item.name.isEmpty ? unknownService : item.name;
    final price = item.priceCents;
    if (price == null) return '$name · ${item.minutes} min';
    final pesos = _material.formatDecimal(price ~/ 100);
    final cents = (price % 100).toString().padLeft(2, '0');
    return '$name · ARS $pesos${_english ? '.' : ','}$cents · ${item.minutes} min';
  }

  String interval(AgendaCalendar calendar, DateTime start, DateTime end) =>
      '${_clock(calendar.minuteOfDay(start))} – ${_clock(calendar.minuteOfDay(end))}';

  String _clock(int minute) {
    final hours = (minute ~/ 60).toString().padLeft(2, '0');
    final minutes = (minute % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  String status(AppointmentStatus status) => switch (status) {
    AppointmentStatus.pending => _text('Pendiente', 'Pending'),
    AppointmentStatus.canceled => _text('Cancelado', 'Canceled'),
    AppointmentStatus.completed => _text('Realizado', 'Completed'),
    AppointmentStatus.other => _text('Otro estado', 'Other status'),
  };

  String error(BookingFailure failure) => switch (failure) {
    BookingFailure.permission => _text(
      'Tu cuenta no tiene permiso para completar esta operación.',
      'Your account cannot complete this operation.',
    ),
    BookingFailure.network => _text(
      'Revisá tu conexión a Internet y reintentá.',
      'Check your internet connection and try again.',
    ),
    BookingFailure.unpublished => _text(
      'El barbero debe publicar esta semana antes de que puedas reservar.',
      'The barber needs to publish this week before you can book.',
    ),
    BookingFailure.unavailable => _text(
      'El horario ya no está disponible. Actualizá la disponibilidad y elegí otro.',
      'That time is no longer available. Refresh availability and choose another time.',
    ),
    BookingFailure.serviceChanged => _text(
      'El servicio cambió. Actualizá y volvé a elegirlo.',
      'The service has changed. Refresh and select it again.',
    ),
    BookingFailure.fields => _text(
      'Ingresá un nombre de entre 1 y 120 caracteres.',
      'Enter a name between 1 and 120 characters.',
    ),
    BookingFailure.operation => _text(
      'No se pudo completar la operación. Reintentá.',
      'Could not complete the operation. Try again.',
    ),
  };
}
