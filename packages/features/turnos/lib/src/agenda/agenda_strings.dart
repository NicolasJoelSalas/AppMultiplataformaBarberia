import 'package:domain/domain.dart';
import 'package:flutter/widgets.dart';

class AgendaStrings {
  AgendaStrings(BuildContext context)
    : english = Localizations.localeOf(context).languageCode == 'en';

  final bool english;

  String _text(String es, String en) => english ? en : es;

  String get title => _text('Gestionar semana', 'Manage week');
  String get current => _text('Esta semana', 'This week');
  String get next => _text('Próxima semana', 'Next week');
  String get today => _text('Hoy', 'Today');
  String get selected => _text('Semana seleccionada', 'Selected week');
  String get open => _text('Abierto', 'Open');
  String get closed => _text('Cerrado', 'Closed');
  String get start => _text('Inicio', 'Start');
  String get end => _text('Fin', 'End');
  String get add => _text('Agregar franja', 'Add time range');
  String get save =>
      _text('Guardar y publicar semana', 'Save and publish week');
  String get saving =>
      _text('Guardando y publicando…', 'Saving and publishing…');
  String get retry => _text('Reintentar', 'Try again');
  String get reload => _text('Volver a cargar la semana', 'Reload week');
  String get leave => _text('Salir sin guardar', 'Leave without saving');
  String get discard => _text('Descartar cambios', 'Discard changes');
  String get keepEditing => _text('Seguir editando', 'Keep editing');
  String get unsaved => _text(
    'Tenés cambios pendientes en tu agenda.',
    'You have unsaved changes to your schedule.',
  );
  String get pending => _text(
    'La agenda se guardó, pero falta actualizar los horarios. Reintentá guardar y publicar.',
    'The schedule was saved, but availability is pending. Try saving and publishing again.',
  );

  String day(int index) => (english
      ? const [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
        ]
      : const [
          'Lunes',
          'Martes',
          'Miércoles',
          'Jueves',
          'Viernes',
          'Sábado',
        ])[index];

  String span(int number) => _text('Franja $number', 'Time range $number');
  String remove(int number) =>
      _text('Quitar franja $number', 'Remove time range $number');
  String dates(String from, String to) => _text('$from al $to', '$from to $to');
  String published(int count) =>
      _text('Franjas publicadas: $count', 'Published time ranges: $count');

  String error(AgendaProblem problem) => switch (problem.reason) {
    AgendaFailure.permission => _text(
      'Solo un barbero habilitado puede gestionar la agenda.',
      'Only an enabled barber can manage the schedule.',
    ),
    AgendaFailure.network => _text(
      'Revisá tu conexión a Internet.',
      'Check your internet connection.',
    ),
    AgendaFailure.zone => _text(
      'Configurá una zona horaria válida para el barbero.',
      'Set a valid time zone for the barber.',
    ),
    AgendaFailure.weekChanged => _text(
      'La semana cambió. Volvé a cargar la agenda.',
      'The week changed. Reload your schedule.',
    ),
    AgendaFailure.changed => _text(
      'La agenda o la zona horaria cambió. Volvé a cargar la semana.',
      'The schedule or time zone changed. Reload the week.',
    ),
    AgendaFailure.emptyDay => _text(
      'Agregá al menos una franja para el día abierto.',
      'Add at least one time range for the open day.',
    ),
    AgendaFailure.time => _text(
      'Elegí una hora válida de inicio y de fin.',
      'Choose a valid start and end time.',
    ),
    AgendaFailure.duration => _text(
      'La franja debe durar al menos 5 minutos.',
      'Each time range must last at least 5 minutes.',
    ),
    AgendaFailure.overlap => _text(
      'Este horario se superpone con otra franja.',
      'This time range overlaps another range.',
    ),
    AgendaFailure.zoneBookings => _text(
      'Hay reservas futuras asociadas a otra zona horaria. Revisá esos turnos antes de publicar.',
      'Future appointments belong to another time zone. Review them before publishing.',
    ),
    AgendaFailure.availability => _text(
      'Hay horarios u ocupaciones que no coinciden con el día publicado.',
      'Some hours or reservations do not match the published day.',
    ),
    AgendaFailure.operation => _text(
      'No se pudo completar la operación. Reintentá.',
      'Could not complete the operation. Try again.',
    ),
  };
}
