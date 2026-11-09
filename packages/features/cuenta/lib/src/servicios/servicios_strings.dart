import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

class ServiciosStrings {
  ServiciosStrings(BuildContext context)
    : _english = Localizations.localeOf(context).languageCode == 'en';

  final bool _english;

  String _text(String es, String en) => _english ? en : es;

  String get title => _text('Mis servicios', 'My services');
  String get notice => _text(
    'Administrá el nombre, el precio y la duración de tus servicios. Los servicios desactivados se conservan para mantener el historial.',
    'Manage the name, price and duration of your services. Deactivated services are kept for your appointment history.',
  );
  String get empty => _text(
    'Todavía no creaste servicios propios. Agregá tu primer servicio para comenzar.',
    'You have no services yet. Add your first service to get started.',
  );
  String get add => _text('Agregar servicio', 'Add service');
  String get edit => _text('Editar', 'Edit');
  String get editTitle => _text('Editar servicio', 'Edit service');
  String get active => _text('Activo', 'Active');
  String get inactive => _text('Desactivado', 'Inactive');
  String get deactivate => _text('Dar de baja', 'Deactivate');
  String get reactivate => _text('Reactivar', 'Reactivate');
  String get deactivateTitle =>
      _text('¿Dar de baja este servicio?', 'Deactivate this service?');
  String deactivateBody(String name) => _text(
    '$name dejará de estar disponible para nuevas reservas. Los turnos anteriores se conservarán. Podés reactivarlo cuando quieras.',
    '$name will no longer be available for new bookings. Existing appointments will be kept. You can reactivate it at any time.',
  );
  String get retry => _text('Reintentar', 'Try again');
  String get save => _text('Guardar servicio', 'Save service');
  String get saving => _text('Guardando…', 'Saving…');
  String get cancel => _text('Cancelar', 'Cancel');
  String get name => _text('Nombre del servicio', 'Service name');
  String get price => _text('Precio (ARS)', 'Price (ARS)');
  String get duration => _text('Duración (minutos)', 'Duration (minutes)');
  String get durationRange =>
      _text('Entre 5 y 240 minutos.', 'Between 5 and 240 minutes.');

  String details(BuildContext context, ServiceDetails details) {
    final whole = MaterialLocalizations.of(context)
        .formatDecimal(details.priceCents ~/ 100);
    final cents = (details.priceCents % 100).toString().padLeft(2, '0');
    return 'ARS $whole${_english ? '.' : ','}$cents · ${details.durationMinutes} min';
  }

  String error(ServiceFailure error) => switch (error) {
    ServiceFailure.format => _text(
      'Ingresá un precio válido con hasta dos decimales y una duración en minutos.',
      'Enter a valid price with up to two decimal places and a duration in minutes.',
    ),
    ServiceFailure.fields => _text(
      'Revisá el nombre (hasta 120 caracteres), el precio y la duración (5 a 240 minutos).',
      'Check the name (up to 120 characters), price and duration (5 to 240 minutes).',
    ),
    ServiceFailure.permission => _text(
      'Solo un barbero habilitado puede gestionar sus propios servicios.',
      'Only an enabled barber can manage their own services.',
    ),
    ServiceFailure.network => _text(
      'Revisá tu conexión a Internet.',
      'Check your Internet connection.',
    ),
    ServiceFailure.operation => _text(
      'No se pudo completar la operación. Revisá tu conexión y reintentá.',
      'Could not complete the operation. Check your connection and try again.',
    ),
  };
}
