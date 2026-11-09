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
  String get edit => _text('Modificar turno', 'Edit appointment');
  String get confirmEdit => _text('Confirmar modificación', 'Confirm changes');
  String get edited => _text('Turno modificado.', 'Appointment updated.');
  String get cancelAppointment => _text('Cancelar turno', 'Cancel appointment');
  String get cancelMessage => _text(
    '¿Querés cancelar este turno? Se liberará el horario.',
    'Cancel this appointment and release its time slot?',
  );
  String get canceled => _text('Turno cancelado.', 'Appointment canceled.');
  String get complete => _text('Marcar realizado', 'Mark completed');
  String get completed =>
      _text('Turno marcado como realizado.', 'Appointment marked completed.');
  String get saving => _text('Guardando…', 'Saving…');
  String get completeFromStart => _text(
    'Disponible desde la hora de inicio del turno.',
    'Available from the appointment start time.',
  );
  String get noMatchingAppointments => _text(
    'No hay turnos con el estado seleccionado para esta semana.',
    'No appointments match this status for the selected week.',
  );
  String charged(int cents) => _text(
    'Importe cobrado · ${_ars(cents)}',
    'Amount charged · ${_ars(cents)}',
  );
  String filter(AppointmentStatus? value) => switch (value) {
    null => _text('Todos', 'All'),
    AppointmentStatus.completed => _text('Completado', 'Completed'),
    final value => status(value),
  };
  String section(AppointmentStatus value) => switch (value) {
    AppointmentStatus.pending => _text('Pendientes', 'Pending'),
    AppointmentStatus.canceled => _text('Cancelados', 'Canceled'),
    AppointmentStatus.completed => _text('Completados', 'Completed'),
    AppointmentStatus.other => _text('Otros turnos', 'Other appointments'),
  };
  String get photo => _text('Foto de referencia', 'Reference photo');
  String get addPhoto => _text('Adjuntar foto', 'Attach photo');
  String get changePhoto => _text('Cambiar foto', 'Change photo');
  String get removePhoto => _text('Quitar foto', 'Remove photo');
  String get viewPhoto =>
      _text('Ver foto de referencia', 'View reference photo');
  String get photoError =>
      _text('No se pudo abrir la foto.', 'Could not open the photo.');
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
    return '$name · ${_ars(price)} · ${item.minutes} min';
  }

  String _ars(int cents) {
    final pesos = _material.formatDecimal(cents ~/ 100);
    final fraction = (cents % 100).toString().padLeft(2, '0');
    return 'ARS $pesos${_english ? '.' : ','}$fraction';
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
    BookingFailure.notEditable => _text(
      'Solo podés modificar o cancelar turnos pendientes que todavía no empezaron.',
      'You can only edit or cancel pending appointments that have not started.',
    ),
    BookingFailure.notCompletable => _text(
      'Solo podés completar turnos pendientes desde su hora de inicio.',
      'Only pending appointments that have started can be completed.',
    ),
    BookingFailure.invalidServicePrice => _text(
      'El servicio necesita un precio válido para registrar el importe cobrado.',
      'The service needs a valid price to record the amount charged.',
    ),
    BookingFailure.changed => _text(
      'El turno cambió. Volvé al listado y abrilo nuevamente.',
      'This appointment changed. Return to the list and open it again.',
    ),
    BookingFailure.photoUnavailable => _text(
      'La carga de fotos todavía no está configurada. Podés continuar sin adjuntarla.',
      'Photo uploads are not configured. You can continue without attaching it.',
    ),
    BookingFailure.photoUpload => _text(
      'No se pudo subir la foto. Reintentá o quitá la foto para continuar.',
      'The photo could not be uploaded. Try again or remove it to continue.',
    ),
  };
}
