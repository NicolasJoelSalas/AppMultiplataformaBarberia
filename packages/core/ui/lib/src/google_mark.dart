import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key});
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/google.svg',
    package: 'core_ui',
    width: 20,
    height: 20,
    excludeFromSemantics: true,
  );
}
