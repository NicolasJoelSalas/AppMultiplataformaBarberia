import 'package:domain/domain.dart';

({String title, String body, String channel}) appointmentNoticeText(
  AppointmentNotice notice,
  bool english,
  DateTime? start,
) {
  final (title, body) = switch (notice) {
    AppointmentNotice.reminder => (
      english ? 'Appointment reminder' : 'Recordatorio de turno',
      _reminderBody(start!, english),
    ),
    AppointmentNotice.booked =>
      english
          ? ('New appointment', 'A customer booked an appointment.')
          : ('Nuevo turno', 'Un cliente reservó un turno.'),
    AppointmentNotice.updated =>
      english
          ? (
              'Appointment changed',
              'Open Appointments to see the updated details.',
            )
          : (
              'Turno modificado',
              'Abrí Turnos para ver los datos actualizados.',
            ),
    AppointmentNotice.canceled =>
      english
          ? ('Appointment canceled', 'An upcoming appointment was canceled.')
          : ('Turno cancelado', 'Se canceló un turno próximo.'),
  };
  final channel = notice == AppointmentNotice.reminder
      ? (english ? 'Appointment reminders' : 'Recordatorios de turnos')
      : (english ? 'Appointment updates' : 'Novedades de turnos');
  return (title: title, body: body, channel: channel);
}

String appointmentNoticeSummary(AppointmentNotice notice, bool english) =>
    switch (notice) {
      AppointmentNotice.reminder =>
        english ? 'Your appointment is coming up.' : 'Se acerca tu turno.',
      AppointmentNotice.booked =>
        english ? 'There is a new appointment.' : 'Hay un nuevo turno.',
      AppointmentNotice.updated =>
        english ? 'An appointment changed.' : 'Un turno cambió.',
      AppointmentNotice.canceled =>
        english ? 'An appointment was canceled.' : 'Se canceló un turno.',
    };

String _reminderBody(DateTime start, bool english) {
  final local = start.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return english
      ? 'Your appointment is at $hour:$minute.'
      : 'Tu turno es a las $hour:$minute.';
}
