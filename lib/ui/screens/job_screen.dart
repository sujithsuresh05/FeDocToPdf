import 'package:flutter/material.dart';

import '../../models/job.dart';
import '../../services/api_client.dart';
import '../../services/delivery_service.dart';
import '../../state/job_controller.dart';
import '../widgets/part_tile.dart';
import '../widgets/warning_banner.dart';

/// Progress while the server works, then the delivery list.
class JobScreen extends StatefulWidget {
  const JobScreen({
    required this.baseUrl,
    this.initialJob,
    this.resumeJobId,
    super.key,
  }) : assert(initialJob != null || resumeJobId != null,
            'JobScreen needs either a job or an id to resume');

  final String baseUrl;
  final Job? initialJob;
  final String? resumeJobId;

  @override
  State<JobScreen> createState() => _JobScreenState();
}

class _JobScreenState extends State<JobScreen> {
  late final ApiClient _api;
  late final JobController _controller;
  final _delivery = DeliveryService();
  final _listController = ScrollController();

  bool _onlyPending = false;

  @override
  void initState() {
    super.initState();
    _api = ApiClient(baseUrl: widget.baseUrl);
    _controller = JobController(api: _api);

    final initial = widget.initialJob;
    if (initial != null) {
      _controller.attach(initial);
    } else {
      _controller.load(widget.resumeJobId!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _api.close();
    _listController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openChat(JobPart part) async {
    final link = part.whatsappLink;
    if (link == null) {
      _toast(part.blockedReason ?? 'No WhatsApp link for this part.');
      return;
    }
    final opened = await _delivery.openChat(link);
    if (!opened) {
      _toast('Could not open WhatsApp. Is it installed on this device?');
    }
  }

  /// Download the part if needed, then hand it to the share sheet.
  Future<void> _sharePdf(JobPart part) async {
    final file = await _controller.download(part);
    if (file == null) {
      _toast(_controller.error ?? 'Could not download that PDF.');
      _controller.clearError();
      return;
    }
    final shared = await _delivery.sharePdf(file, message: part.message);
    if (!shared) {
      _toast('Could not open the share sheet.');
      return;
    }
    if (!part.sent && mounted) _promptMarkSent(part);
  }

  /// After a share the app cannot know whether the operator actually pressed
  /// send in WhatsApp, so ask rather than assume.
  void _promptMarkSent(JobPart part) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Sent ${part.filename}?'),
          action: SnackBarAction(
            label: 'Mark sent',
            onPressed: () => _controller.setSent(part, sent: true),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
  }

  void _jumpToNextUnsent(Job job) {
    final next = job.nextUnsent;
    if (next == null) {
      _toast('Everything deliverable has been marked sent.');
      return;
    }
    final visible = _visibleParts(job);
    final position = visible.indexWhere((part) => part.index == next.index);
    if (position >= 0 && _listController.hasClients) {
      // Rows are roughly uniform, so an estimated offset is good enough to put
      // the next one on screen.
      _listController.animateTo(
        (position * 150).toDouble().clamp(0, _listController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  List<JobPart> _visibleParts(Job job) => _onlyPending
      ? job.parts.where((part) => !part.sent).toList(growable: false)
      : job.parts;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final job = _controller.job;

        return Scaffold(
          appBar: AppBar(
            title: Text(job?.documentName ?? 'Job'),
            actions: [
              if (job != null && job.status == JobStatus.ready)
                IconButton(
                  tooltip: _onlyPending ? 'Show all' : 'Show pending only',
                  onPressed: () => setState(() => _onlyPending = !_onlyPending),
                  icon: Icon(_onlyPending ? Icons.filter_alt_off : Icons.filter_alt),
                ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _controller.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          floatingActionButton: job != null && job.status == JobStatus.ready
              ? FloatingActionButton.extended(
                  onPressed: () => _jumpToNextUnsent(job),
                  icon: const Icon(Icons.arrow_downward),
                  label: const Text('Next unsent'),
                )
              : null,
          body: job == null ? _loading('Loading job...') : _body(job),
        );
      },
    );
  }

  Widget _loading(String message) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      );

  Widget _body(Job job) {
    if (job.status == JobStatus.failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text('The job failed', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                job.errorMessage ?? 'No reason was reported.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (job.status != JobStatus.ready) {
      return _loading('${job.status.label}...'
          '${job.pageCount == null ? '' : '\n${job.pageCount} pages'}');
    }

    final visible = _visibleParts(job);

    return Column(
      children: [
        _progressHeader(job),
        WarningBanner(warnings: job.warnings),
        if (visible.isEmpty)
          const Expanded(child: Center(child: Text('Nothing pending.')))
        else
          Expanded(
            child: ListView.builder(
              controller: _listController,
              itemCount: visible.length,
              itemBuilder: (context, position) {
                final part = visible[position];
                return PartTile(
                  part: part,
                  busy: _controller.isPartBusy(part.index),
                  highlight: job.nextUnsent?.index == part.index,
                  onOpenChat: () => _openChat(part),
                  onSharePdf: () => _sharePdf(part),
                  onToggleSent: (value) => _controller.setSent(part, sent: value),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _progressHeader(Job job) {
    final scheme = Theme.of(context).colorScheme;
    final total = job.deliverableCount;
    final sent = job.sentCount;
    final fraction = total == 0 ? 0.0 : sent / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      color: scheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$sent of $total sent · ${job.partCount} PDFs from ${job.pageCount ?? '?'} pages',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (job.partCount != total)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${job.partCount - total} PDF(s) have no recipient and cannot be sent',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
          if (job.matchStrategy != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Matched to sheet rows by ${job.matchStrategy}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: fraction, minHeight: 6),
          ),
        ],
      ),
    );
  }
}
