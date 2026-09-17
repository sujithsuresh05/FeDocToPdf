import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../models/capabilities.dart';
import '../../services/api_client.dart';
import '../../services/api_exception.dart';
import '../../services/settings_service.dart';
import 'job_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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

  bool _busy = false;
  String? _status;
  String? _error;
  String? _resumableJobId;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _marker.dispose();
    _keyLabel.dispose();
    _filenamePattern.dispose();
    _messageTemplate.dispose();
    _chunkSize.dispose();
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

    await _loadCapabilities(quiet: true);
  }

  ApiClient _api() => ApiClient(baseUrl: _baseUrl.text.trim());

  Future<void> _loadCapabilities({bool quiet = false}) async {
    final api = _api();
    try {
      final capabilities = await api.fetchCapabilities();
      if (!mounted) return;
      setState(() {
        _capabilities = capabilities;
        _splitMode = capabilities.splitModes.contains(_splitMode)
            ? _splitMode
            : capabilities.defaultSplitMode;
        if (_filenamePattern.text.isEmpty) {
          _filenamePattern.text = capabilities.defaultFilenamePattern;
        }
        if (_messageTemplate.text.isEmpty) {
          _messageTemplate.text = capabilities.defaultMessageTemplate;
        }
        _error = null;
        if (!quiet) _status = 'Connected.';
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      // On first launch the server usually is not reachable yet; do not shout
      // about it until the operator actually asks.
      if (!quiet) setState(() => _error = error.message);
    } finally {
      api.close();
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _busy = true;
      _status = null;
      _error = null;
    });
    await _settings.writeBaseUrl(_baseUrl.text.trim());
    await _loadCapabilities();
    if (mounted) setState(() => _busy = false);
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
      _analysis = null; // a new document invalidates the old suggestions
    });
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

  /// Ask the server what the document looks like and pre-fill the marker and
  /// key label, so the operator does not have to know them by heart.
  Future<void> _analyse() async {
    final path = _documentPath;
    if (path == null) return;

    setState(() {
      _busy = true;
      _status = 'Converting and inspecting the document. This can take a minute.';
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
        if (marker != null && _marker.text.isEmpty) _marker.text = marker.marker;
        if (keyLabel != null && _keyLabel.text.isEmpty) _keyLabel.text = keyLabel.keyLabel;
        _status = '${analysis.pageCount} pages.'
            '${marker == null ? '' : ' Suggested marker: "${marker.marker}" (${marker.summary}).'}';
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      api.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createJob() async {
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
      _status = 'Uploading...';
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
      setState(() => _status = null);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => JobScreen(baseUrl: _baseUrl.text.trim(), initialJob: job),
        ),
      );
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JobScreen(baseUrl: _baseUrl.text.trim(), resumeJobId: jobId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final needsMarker = _splitMode == 'section';
    final capabilities = _capabilities;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Split & send notices'),
        actions: [
          if (_resumableJobId != null)
            IconButton(
              tooltip: 'Resume last job',
              onPressed: _busy ? null : _resume,
              icon: const Icon(Icons.history),
            ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('1. Server'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _baseUrl,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'API base URL',
                      helperText: 'Use the computer\'s LAN address, not localhost',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : _testConnection,
                  child: const Text('Test'),
                ),
              ],
            ),
            if (capabilities != null && !capabilities.attachesFileAutomatically)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: _DeliveryNotice(),
              ),

            _section('2. Files'),
            _filePickerTile(
              icon: Icons.description_outlined,
              label: 'Word document',
              value: _documentName,
              onPressed: _busy ? null : _pickDocument,
            ),
            _filePickerTile(
              icon: Icons.table_chart_outlined,
              label: 'Recipient sheet (.csv / .xlsx)',
              value: _recipientsName,
              onPressed: _busy ? null : _pickRecipients,
              optional: true,
            ),
            if (_documentPath != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _analyse,
                  icon: const Icon(Icons.search),
                  label: const Text('Inspect document & suggest marker'),
                ),
              ),
            if (_analysis != null) _analysisSummary(_analysis!),

            _section('3. How to split'),
            DropdownButtonFormField<String>(
              initialValue: _splitMode,
              decoration: const InputDecoration(labelText: 'Split mode'),
              items: (capabilities?.splitModes ?? const ['section', 'page', 'chunk', 'whole'])
                  .map(
                    (mode) => DropdownMenuItem(
                      value: mode,
                      child: Text(mode),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() => _splitMode = value ?? 'section'),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 6),
              child: Text(
                AppConfig.splitModeDescriptions[_splitMode] ?? '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (_splitMode == 'chunk')
              TextField(
                controller: _chunkSize,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Pages per PDF'),
              ),
            if (needsMarker) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _marker,
                decoration: const InputDecoration(
                  labelText: 'Section marker',
                  helperText: 'Text on the first page of each recipient\'s section',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _keyLabel,
                decoration: const InputDecoration(
                  labelText: 'Key label (optional)',
                  helperText: 'Label before each section\'s id, e.g. "Serial No:"',
                ),
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _matchBy,
              decoration: const InputDecoration(
                labelText: 'Match parts to sheet rows by',
                helperText: 'Order is safest; keys can repeat across wards',
              ),
              items: (capabilities?.matchStrategies ?? const ['order', 'key'])
                  .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                  .toList(growable: false),
              onChanged: (value) => setState(() => _matchBy = value ?? 'order'),
            ),

            _section('4. Naming & message'),
            TextField(
              controller: _filenamePattern,
              decoration: InputDecoration(
                labelText: 'Filename pattern',
                helperText: capabilities == null
                    ? null
                    : 'Tokens: ${capabilities.filenameTokens.map((t) => '{{$t}}').join(' ')}',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageTemplate,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'WhatsApp message',
                helperText: capabilities == null
                    ? null
                    : 'Tokens: ${capabilities.messageTokens.map((t) => '{{$t}}').join(' ')}',
              ),
            ),

            const SizedBox(height: 20),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_status!, style: Theme.of(context).textTheme.bodyMedium),
              ),
            if (_error != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy || _documentPath == null ? null : _createJob,
              icon: _busy
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.call_split),
              label: Text(_busy ? 'Working...' : 'Split document'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _filePickerTile({
    required IconData icon,
    required String label,
    required String? value,
    required VoidCallback? onPressed,
    bool optional = false,
  }) =>
      Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(icon),
          title: Text(label),
          subtitle: Text(
            value ?? (optional ? 'Not selected (optional)' : 'Not selected'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.folder_open),
          onTap: onPressed,
        ),
      );

  Widget _analysisSummary(DocumentAnalysis analysis) => Card(
        margin: const EdgeInsets.only(top: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${analysis.pageCount} pages',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              if (analysis.markerSuggestions.isEmpty)
                const Text('No repeating marker found. Use per-page or fixed-chunk splitting, '
                    'or add a "pages" column to the sheet.')
              else ...[
                const Text('Tap a suggestion to use it:'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: analysis.markerSuggestions
                      .map(
                        (suggestion) => ActionChip(
                          label: Text('${suggestion.marker}  (${suggestion.summary})'),
                          onPressed: () => setState(() {
                            _marker.text = suggestion.marker;
                            _splitMode = 'section';
                          }),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              if (analysis.keyLabelSuggestions.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Key labels found:'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: analysis.keyLabelSuggestions
                      .map(
                        (suggestion) => ActionChip(
                          label: Text(
                            '${suggestion.keyLabel} ${suggestion.sample ?? ''}'.trim(),
                          ),
                          onPressed: () => setState(() => _keyLabel.text = suggestion.keyLabel),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ],
          ),
        ),
      );
}

/// Sets expectations up front: the app cannot attach the PDF for you.
class _DeliveryNotice extends StatelessWidget {
  const _DeliveryNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: scheme.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sending is two taps per recipient: "Open chat" pre-fills the message, then '
                '"Share PDF" attaches the file. WhatsApp links cannot carry an attachment.',
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
