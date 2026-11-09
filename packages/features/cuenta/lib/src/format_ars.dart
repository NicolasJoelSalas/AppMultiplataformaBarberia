import 'package:flutter/material.dart';

String formatArs(BuildContext context, int cents) {
  final whole = MaterialLocalizations.of(context).formatDecimal(cents ~/ 100);
  final fraction = (cents % 100).toString().padLeft(2, '0');
  final separator = Localizations.localeOf(context).languageCode == 'es'
      ? ','
      : '.';
  return 'ARS $whole$separator$fraction';
}
