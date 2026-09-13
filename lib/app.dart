import 'package:flutter/material.dart';

import 'ui/screens/home_screen.dart';

class DocToPdfApp extends StatelessWidget {
  const DocToPdfApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF128C7E)); // WhatsApp green

    return MaterialApp(
      title: 'Doc to PDF Splitter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
