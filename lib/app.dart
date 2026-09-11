import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

class SinerehApp extends StatelessWidget {
  const SinerehApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sinereh VPN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      locale: const Locale('fa'),
      builder: (_, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const HomeScreen(),
    );
  }
}
