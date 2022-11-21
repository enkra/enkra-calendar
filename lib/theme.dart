import 'package:flutter/material.dart';

class CalendarTheme {
  Color background;
  Color primary;
  Color onPrimary;
  Color secondary;
  Color miscColor;
  Color danger;

  CalendarTheme({
    required this.background,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.miscColor,
    required this.danger,
  });
}

var theme = CalendarTheme(
  background: const Color(0xfffefefe),
  primary: const Color(0xff22C55E),
  onPrimary: Colors.white,
  secondary: const Color(0xffF0FDF4),
  miscColor: const Color(0xffF59E0B),
  danger: const Color(0xffff8181),
);
