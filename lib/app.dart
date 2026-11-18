import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'screens/home_screen.dart';

class FileshareApp extends StatelessWidget {
  const FileshareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}