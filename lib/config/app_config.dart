/// Defaults used before the operator has configured anything.
class AppConfig {
  /// Android emulator reaches the host machine on 10.0.2.2; a real device needs
  /// the host's LAN address, which the operator sets on the home screen.
  static const String defaultBaseUrl = 'http://10.0.2.2:4000';

  static const List<String> documentExtensions = ['docx', 'doc', 'rtf', 'odt'];
  static const List<String> recipientExtensions = ['csv', 'xlsx', 'xlsm'];

  /// Shown next to the split-mode picker.
  static const Map<String, String> splitModeDescriptions = {
    'section': 'One PDF per recipient, found by a marker on each section\'s first page',
    'page': 'One PDF per page',
    'chunk': 'One PDF per fixed number of pages',
    'whole': 'Convert only, do not split',
  };
}
