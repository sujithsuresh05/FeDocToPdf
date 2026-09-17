import 'package:flutter/material.dart';

import '../../models/job.dart';
import '../../services/api_client.dart';
import '../../services/delivery_service.dart';
import '../../state/job_controller.dart';
import '../theme.dart';
import '../widgets/filter_pills.dart';
import '../widgets/next_notice_card.dart';
import '../widgets/part_row.dart';
import '../widgets/warning_banner.dart';

/// Progress while the server works, then the delivery worklist.
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

  PartFilter _filter = PartFilter.toSend;

  /// Set when the operator taps a row to work on a notice out of order;
  /// otherwise the focus follows the first unsent notice.
  int? _pinnedIndex;

  /// Which steps have been taken for the notice in focus, this sitting.
  /// Not persisted: it is a hint about where the operator is in the hand-off,
  /// not a claim about what WhatsApp did.
  final Set<int> _chatOpened = <int>{};
  final Set<int> _pdfShared = <int>{};

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
    super.dispose();
  }

  void _toast(String message, {bool bad = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: bad ? AppColors.blocked : AppColors.ink,
        behavior: SnackBarBehavior.floating,
      ));
  }

  JobPart? _focused(Job job) {
    final pinned = _pinnedIndex;
    if (pinned != null) {
      for (final part in job.parts) {
        if (part.index == pinned) return part;
      }
    }
    return job.nextUnsent ?? (job.parts.isEmpty ? null : job.parts.first);
  }

  Future<void> _openChat(JobPart part) async {
    final link = part.whatsappLink;
    if (link == null) {
      _toast(part.blockedReason ?? 'No WhatsApp link for this notice.', bad: true);
      return;
    }
    final opened = await _delivery.openChat(link);
    if (!opened) {
      _toast('Could not open WhatsApp. Is it installed on this device?', bad: true);
      return;
    }
    if (mounted) setState(() => _chatOpened.add(part.index));
  }

  Future<void> _sharePdf(JobPart part) async {
    final file = await _controller.download(part);
    if (file == null) {
      _toast(_controller.error ?? 'Could not download that PDF.', bad: true);
      _controller.clearError();
      return;
    }
    final shared = await _delivery.sharePdf(file, message: part.message);
    if (!shared) {
      _toast('Could not open the share sheet.', bad: true);
      return;
    }
    if (mounted) setState(() => _pdfShared.add(part.index));
  }

  Future<void> _markSent(Job job, JobPart part) async {
    await _controller.setSent(part, sent: true);
    if (!mounted) return;
    setState(() {
      _chatOpened.remove(part.index);
      _pdfShared.remove(part.index);
      // Release the pin so focus falls through to the next unsent notice.
      _pinnedIndex = null;
    });
  }

  List<JobPart> _visible(Job job) => switch (_filter) {
        PartFilter.toSend => job.parts.where((p) => p.deliverable && !p.sent).toList(),
        PartFilter.sent => job.parts.where((p) => p.sent).toList(),
        PartFilter.blocked => job.parts.where((p) => !p.deliverable).toList(),
      };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final job = _controller.job;
        return Scaffold(
          appBar: AppBar(
            title: Text(job?.documentName ?? 'Run'),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: _controller.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: job == null ? _waiting('Loading the run…') : _body(job),
        );
      },
    );
  }

  Widget _waiting(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 18),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  Widget _body(Job job) {
    if (job.status == JobStatus.failed) return _failed(job);
    if (job.status != JobStatus.ready) {
      return _waiting(
        '${job.status.label}…'
        '${job.pageCount == null ? '' : '\n${job.pageCount} pages'}',
      );
    }

    final focused = _focused(job);
    final visible = _visible(job);
    final toSend = job.parts.where((p) => p.deliverable && !p.sent).length;
    final sent = job.sentCount;
    final blocked = job.parts.where((p) => !p.deliverable).length;

    return Column(
      children: [
        _header(job, toSend: toSend, sent: sent, blocked: blocked),
        WarningBanner(warnings: job.warnings),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 28),
            // One focused card, then the rows of whichever slice is selected.
            itemCount: visible.length + (focused == null ? 0 : 1),
            itemBuilder: (context, position) {
              if (focused != null && position == 0) {
                return NextNoticeCard(
                  part: focused,
                  position: focused.index,
                  total: job.partCount,
                  chatOpened: _chatOpened.contains(focused.index),
                  pdfShared: _pdfShared.contains(focused.index),
                  busy: _controller.isPartBusy(focused.index),
                  onOpenChat: () => _openChat(focused),
                  onSharePdf: () => _sharePdf(focused),
                  onMarkSent: () => _markSent(job, focused),
                );
              }
              final part = visible[position - (focused == null ? 0 : 1)];
              if (focused != null && part.index == focused.index) {
                return const SizedBox.shrink();
              }
              return PartRow(
                part: part,
                onTap: () => setState(() => _pinnedIndex = part.index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _header(Job job, {required int toSend, required int sent, required int blocked}) {
    final text = Theme.of(context).textTheme;
    final total = job.deliverableCount;
    final fraction = total == 0 ? 0.0 : sent / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 0, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$sent of $total sent',
            style: mono(text.titleMedium!, size: 17, weight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            [
              '$toSend to go',
              '${job.partCount} PDFs from ${job.pageCount ?? '?'} pages',
              if (job.matchStrategy != null) 'matched by ${job.matchStrategy}',
            ].join('  ·  '),
            style: text.labelSmall?.copyWith(fontSize: 11.5),
          ),
          const SizedBox(height: 9),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 5,
                backgroundColor: AppColors.line,
              ),
            ),
          ),
          const SizedBox(height: 11),
          FilterPills(
            selected: _filter,
            toSend: toSend,
            sent: sent,
            blocked: blocked,
            onChanged: (value) => setState(() => _filter = value),
          ),
        ],
      ),
    );
  }

  Widget _failed(Job job) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 46, color: AppColors.blocked),
              const SizedBox(height: 16),
              Text('The run failed', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                job.errorMessage ?? 'No reason was reported.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to setup'),
              ),
            ],
          ),
        ),
      );
}
