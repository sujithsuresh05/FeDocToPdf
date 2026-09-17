import 'package:flutter/material.dart';

import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';

class DocToPdfApp extends StatelessWidget {
  const DocToPdfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notice Splitter',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      // Light only, by decision. Pinning themeMode means a phone set to dark
      // still renders the palette the app was designed and reviewed in, rather
      // than a Material-generated dark scheme nobody has looked at.
      themeMode: ThemeMode.light,
      home: const HomeScreen(),
    );
  }
}
