import 'package:flutter/material.dart';

import 'services/settings_service.dart';
import 'state/theme_controller.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';

class DocToPdfApp extends StatefulWidget {
  const DocToPdfApp({super.key});

  @override
  State<DocToPdfApp> createState() => _DocToPdfAppState();
}

class _DocToPdfAppState extends State<DocToPdfApp> {
  late final ThemeController _theme;

  @override
  void initState() {
    super.initState();
    _theme = ThemeController(SettingsService());
  }

  @override
  void dispose() {
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _theme,
      builder: (context, mode, _) => MaterialApp(
        title: 'Notice Splitter',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        // Follows the phone unless the operator pins one.
        themeMode: mode,
        home: HomeScreen(theme: _theme),
      ),
    );
  }
}
