import 'package:flutter/widgets.dart';

enum AppLanguage {
  system(null),
  spanish(Locale('es')),
  english(Locale('en'));

  const AppLanguage(this.locale);
  final Locale? locale;
}
