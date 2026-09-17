import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../models/capabilities.dart';
import '../../services/api_client.dart';
import '../../services/api_exception.dart';
import '../../services/settings_service.dart';
import '../../state/theme_controller.dart';
import '../theme.dart';
import 'job_screen.dart';

/// Set up a run: point at the backend, pick the two files, confirm what the
/// server detected, send.
///
/// The screen is built around the common path. Marker, split mode, filename
/// pattern and matching are all still here, but behind Advanced: the backend
/// detects them and the operator's job is to confirm a sentence, not to
/// remember that sections start at "Form No.128".
class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.theme, super.key});

  /// Exposed here because setup is the screen an operator lingers on; the
  /// choice applies to the whole app.
  final ThemeController theme;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _settings = SettingsService();

  final _baseUrl = TextEditingController(text: AppConfig.defaultBaseUrl);
  final _marker = TextEditingController();
  final _keyLabel = TextEditingController();
  final _filenamePattern = TextEditingController();
  final _messageTemplate = TextEditingController();
  final _chunkSize = TextEditingController(text: '2');

  String _splitMode = 'section';
  String _matchBy = 'order';

  String? _documentPath;
  String? _documentName;
  String? _recipientsPath;
  String? _recipientsName;

  Capabilities? _capabilities;
  DocumentAnalysis? _analysis;

  bool _connected = false;
  bool _editingServer = true;
  bool _analysing = false;
  bool _busy = false;
  String? _error;
  String? _resumableJobId;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    for (final c in [_baseUrl, _marker, _keyLabel, _filenamePattern, _messageTemplate, _chunkSize]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _restore() async {
    final savedUrl = await _settings.readBaseUrl();
    final defaults = await _settings.readJobDefaults();
    final lastJob = await _settings.readLastJobId();
    if (!mounted) return;

    setState(() {
      if (savedUrl != null && savedUrl.isNotEmpty) _baseUrl.text = savedUrl;
      _marker.text = defaults['marker'] ?? '';
      _keyLabel.text = defaults['keyLabel'] ?? '';
      _filenamePattern.text = defaults['filenamePattern'] ?? '';
      _messageTemplate.text = defaults['messageTemplate'] ?? '';
      _resumableJobId = lastJob;
    });
    await _connect(quiet: true);
  }

  ApiClient _api() => ApiClient(baseUrl: _baseUrl.text.trim());

  Future<void> _connect({bool quiet = false}) async {
    final api = _api();
    try {
      final capabilities = await api.fetchCapabilities();
      if (!mounted) return;
      setState(() {
        _capabilities = capabilities;
        _connected = true;
        _editingServer = false;
        if (!capabilities.splitModes.contains(_splitMode)) {
          _splitMode = capabilities.defaultSplitMode;
        }
        if (_filenamePattern.text.isEmpty) {
          _filenamePattern.text = capabilities.defaultFilenamePattern;
        }
        if (_messageTemplate.text.isEmpty) {
          _messageTemplate.text = capabilities.defaultMessageTemplate;
        }
        _error = null;
      });
      await _settings.writeBaseUrl(_baseUrl.text.trim());
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _connected = false;
        _editingServer = true;
        // On first launch the server is usually not up yet; only complain when
        // the operator actually pressed Connect.
        if (!quiet) _error = error.message;
      });
    } finally {
      api.close();
    }
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConfig.documentExtensions,
    );
    final picked = result?.files.single;
    if (picked?.path == null || !mounted) return;
    setState(() {
      _documentPath = picked!.path;
      _documentName = picked.name;
      _analysis = null; // a new document invalidates the old detection
    });
    if (_connected) await _analyse();
  }

  Future<void> _pickRecipients() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConfig.recipientExtensions,
    );
    final picked = result?.files.single;
    if (picked?.path == null || !mounted) return;
    setState(() {
      _recipientsPath = picked!.path;
      _recipientsName = picked.name;
    });
  }

  /// Ask the server what the document looks like, and adopt what it found.
  Future<void> _analyse() async {
    final path = _documentPath;
    if (path == null) return;

    setState(() {
      _analysing = true;
      _error = null;
    });

    final api = _api();
    try {
      final analysis = await api.analyse(path);
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
        final marker = analysis.bestMarker;
        final keyLabel = analysis.bestKeyLabel;
        if (marker != null) {
          _marker.text = marker.marker;
          _splitMode = 'section';
        }
        if (keyLabel != null) _keyLabel.text = keyLabel.keyLabel;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      api.close();
      if (mounted) setState(() => _analysing = false);
    }
  }

  Future<void> _split() async {
    final path = _documentPath;
    if (path == null) {
      setState(() => _error = 'Pick a Word document first.');
      return;
    }
    final chunk = int.tryParse(_chunkSize.text.trim()) ?? 1;
    if (_splitMode == 'chunk' && chunk < 1) {
      setState(() => _error = 'Pages per PDF must be 1 or more.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    await _settings.writeBaseUrl(_baseUrl.text.trim());
    await _settings.writeJobDefaults(
      marker: _marker.text.trim(),
      keyLabel: _keyLabel.text.trim(),
      filenamePattern: _filenamePattern.text.trim(),
      messageTemplate: _messageTemplate.text.trim(),
    );

    final api = _api();
    try {
      final job = await api.createJob(
        documentPath: path,
        recipientsPath: _recipientsPath,
        splitMode: _splitMode,
        chunkSize: chunk,
        marker: _splitMode == 'section' ? _marker.text.trim() : null,
        keyLabel: _splitMode == 'section' ? _keyLabel.text.trim() : null,
        matchBy: _matchBy,
        filenamePattern: _filenamePattern.text.trim(),
        messageTemplate: _messageTemplate.text.trim(),
      );
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => JobScreen(baseUrl: _baseUrl.text.trim(), initialJob: job),
      ));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      api.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resume() async {
    final jobId = _resumableJobId;
    if (jobId == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => JobScreen(baseUrl: _baseUrl.text.trim(), resumeJobId: jobId),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New run'),
        actions: [
          IconButton(
            tooltip: widget.theme.label,
            onPressed: widget.theme.next,
            icon: Icon(widget.theme.icon),
          ),
          if (_resumableJobId != null)
            IconButton(
              tooltip: 'Back to the last run',
              onPressed: _busy ? null : _resume,
              icon: const Icon(Icons.history),
            ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 36),
          children: [
            _serverGroup(),
            _documentsGroup(),
            _messageGroup(),
            if (_error != null) _errorBox(_error!),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
              child: FilledButton(
                onPressed: _busy || _documentPath == null ? null : _split,
                child: _busy
                    ? SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: context.scheme.onPrimary))
                    : Text(_splitLabel()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Text(
                'Nothing is sent automatically. You send each notice yourself.',
                style: TextStyle(fontSize: 11.5, color: context.scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _splitLabel() {
    final count = _analysis?.bestMarker?.occurrences;
    if (_splitMode == 'section' && count != null) return 'Split into $count PDFs';
    if (_splitMode == 'page' && _analysis != null) {
      return 'Split into ${_analysis!.pageCount} PDFs';
    }
    return 'Split the document';
  }

  // ---- groups -------------------------------------------------------------

  Widget _group({required String label, required List<Widget> children}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: context.scheme.surface,
          border: Border(bottom: BorderSide(color: context.scheme.outlineVariant)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: kicker(context)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );

  Widget _serverGroup() {
    if (_connected && !_editingServer) {
      return _group(label: 'Backend', children: [
        Row(
          children: [
            Icon(Icons.check_circle, size: 16, color: context.scheme.primary),
            const SizedBox(width: 7),
            Text('Connected',
                style: TextStyle(fontWeight: FontWeight.w600, color: context.scheme.primary)),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                _baseUrl.text.replaceFirst(RegExp(r'^https?://'), ''),
                style: mono(Theme.of(context).textTheme.bodySmall!,
                    color: context.scheme.onSurfaceVariant, size: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _editingServer = true),
              child: const Text('Change'),
            ),
          ],
        ),
      ]);
    }

    return _group(label: 'Backend', children: [
      TextField(
        controller: _baseUrl,
        keyboardType: TextInputType.url,
        autocorrect: false,
        decoration: const InputDecoration(
          labelText: 'Address',
          helperText: "Your computer's network address, not localhost",
          helperMaxLines: 2,
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          FilledButton(
            onPressed: _busy ? null : () => _connect(),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
            child: const Text('Connect'),
          ),
          if (_connected) ...[
            const SizedBox(width: 10),
            TextButton(
              onPressed: () => setState(() => _editingServer = false),
              child: const Text('Cancel'),
            ),
          ],
        ],
      ),
    ]);
  }

  Widget _documentsGroup() => _group(label: 'Documents', children: [
        _fileField(
          icon: Icons.description_outlined,
          value: _documentName,
          empty: 'Choose the Word document',
          onTap: _busy ? null : _pickDocument,
        ),
        const SizedBox(height: 8),
        _fileField(
          icon: Icons.table_chart_outlined,
          value: _recipientsName,
          empty: 'Choose the recipient sheet (optional)',
          onTap: _busy ? null : _pickRecipients,
        ),
        if (_analysing) ...[
          const SizedBox(height: 10),
          Row(children: [
            const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 9),
            Expanded(
              child: Text('Inspecting the document. A long one can take a minute.',
                  style: TextStyle(fontSize: 12, color: context.scheme.onSurfaceVariant)),
            ),
          ]),
        ] else if (_analysis != null) ...[
          const SizedBox(height: 10),
          _detection(_analysis!),
        ],
      ]);

  Widget _fileField({
    required IconData icon,
    required String? value,
    required String empty,
    required VoidCallback? onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: context.scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value ?? empty,
                  style: TextStyle(
                    fontSize: 14,
                    color: value == null ? context.scheme.onSurfaceVariant : context.scheme.onSurface,
                    fontWeight: value == null ? FontWeight.w400 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: context.scheme.onSurfaceVariant),
            ],
          ),
        ),
      );

  /// What the server found, as a sentence to confirm rather than fields to fill.
  Widget _detection(DocumentAnalysis analysis) {
    final marker = analysis.bestMarker;
    final keyLabel = analysis.bestKeyLabel;

    if (marker == null) {
      return Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: context.scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          '${analysis.pageCount} pages, but no repeating heading was found. '
          'Split per page or per fixed number of pages under Advanced, or add a '
          '"pages" column to the sheet.',
          style: TextStyle(fontSize: 12, height: 1.4, color: context.scheme.tertiary),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: context.scheme.primaryContainer,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text.rich(
        TextSpan(
          style: TextStyle(fontSize: 12, height: 1.45, color: context.scheme.onPrimaryContainer),
          children: [
            const TextSpan(text: 'Found '),
            TextSpan(
              text: '${marker.occurrences} notices',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: marker.pagesPerSection == null
                  ? ' in ${analysis.pageCount} pages'
                  : ', every ${marker.pagesPerSection} pages',
            ),
            const TextSpan(text: ', each starting '),
            TextSpan(text: '"${marker.marker}"', style: _codeStyle()),
            if (keyLabel != null) ...[
              const TextSpan(text: ' and numbered by '),
              TextSpan(text: '"${keyLabel.keyLabel}"', style: _codeStyle()),
            ],
            const TextSpan(text: '.'),
          ],
        ),
      ),
    );
  }

  TextStyle _codeStyle() => mono(
        const TextStyle(),
        color: context.scheme.onPrimaryContainer,
        size: 11.5,
        weight: FontWeight.w500,
      );

  Widget _messageGroup() => _group(label: 'Message', children: [
        TextField(
          controller: _messageTemplate,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            helperText: _capabilities == null
                ? 'Use {{name}} for the recipient'
                : 'Tokens: ${_capabilities!.messageTokens.map((t) => '{{$t}}').join(' ')}',
            helperMaxLines: 2,
          ),
        ),
        const SizedBox(height: 4),
        Theme(
          // A divider-free tile so Advanced reads as part of this group.
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 4),
            title: Text(
              'Advanced',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: context.tones.inkSoft),
            ),
            subtitle: Text(
              'Split mode, matching, filenames',
              style: TextStyle(fontSize: 11.5, color: context.scheme.onSurfaceVariant),
            ),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _splitMode,
                decoration: const InputDecoration(labelText: 'Split mode'),
                items: (_capabilities?.splitModes ?? const ['section', 'page', 'chunk', 'whole'])
                    .map((mode) => DropdownMenuItem(
                          value: mode,
                          child: Text('$mode — ${AppConfig.splitModeDescriptions[mode] ?? ''}',
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(growable: false),
                onChanged: (value) => setState(() => _splitMode = value ?? 'section'),
              ),
              if (_splitMode == 'chunk') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _chunkSize,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Pages per PDF'),
                ),
              ],
              if (_splitMode == 'section') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _marker,
                  decoration: const InputDecoration(
                    labelText: 'Heading that starts each notice',
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _keyLabel,
                  decoration: const InputDecoration(
                    labelText: 'Label before each number (optional)',
                    helperMaxLines: 2,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _matchBy,
                decoration: const InputDecoration(
                  labelText: 'Match notices to sheet rows by',
                  helperText: 'Order is safest; numbers can repeat between wards',
                  helperMaxLines: 2,
                ),
                items: (_capabilities?.matchStrategies ?? const ['order', 'key'])
                    .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                    .toList(growable: false),
                onChanged: (value) => setState(() => _matchBy = value ?? 'order'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _filenamePattern,
                decoration: InputDecoration(
                  labelText: 'Filename pattern',
                  helperText: _capabilities == null
                      ? null
                      : 'Tokens: ${_capabilities!.filenameTokens.map((t) => '{{$t}}').join(' ')}',
                  helperMaxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ]);

  Widget _errorBox(String message) => Container(
        margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.scheme.errorContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 17, color: context.scheme.error),
            const SizedBox(width: 9),
            Expanded(
              child: Text(message,
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: context.scheme.error)),
            ),
          ],
        ),
      );
}
