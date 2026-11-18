import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B6BCB)),
    useMaterial3: true,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
  );
}