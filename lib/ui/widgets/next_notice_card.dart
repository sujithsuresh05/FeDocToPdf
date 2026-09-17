import 'package:flutter/material.dart';

import '../../models/job.dart';
import '../theme.dart';

/// The one notice currently being worked on.
///
/// This is the only lifted surface on the delivery screen. With 181 notices in
/// a run, a list of equal-weight cards gives no answer to "where was I", so
/// exactly one is in focus and everything else is a quiet index.
///
/// The hand-off is drawn as three numbered steps because it *is* ordered: a
/// wa.me link cannot carry an attachment, so the PDF can only be shared after
/// the chat is open. The step that comes next is filled; the others are
/// outlined but still tappable, since the operator may have done one already.
class NextNoticeCard extends StatelessWidget {
  const NextNoticeCard({
    required this.part,
    required this.position,
    required this.total,
    required this.chatOpened,
    required this.pdfShared,
    required this.busy,
    required this.onOpenChat,
    required this.onSharePdf,
    required this.onMarkSent,
    super.key,
  });

  final JobPart part;

  /// 1-based position of this notice in the run, for "notice 38 of 181".
  final int position;
  final int total;

  final bool chatOpened;
  final bool pdfShared;
  final bool busy;

  final VoidCallback onOpenChat;
  final VoidCallback onSharePdf;
  final VoidCallback onMarkSent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final blocked = part.blockedReason;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: blocked == null ? AppColors.accent : AppColors.blocked,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  blocked == null
                      ? 'NEXT · NOTICE $position OF $total'
                      : 'NOTICE $position OF $total',
                  style: kicker(
                    context,
                    color: blocked == null ? AppColors.accentInk : AppColors.blocked,
                  ),
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            part.recipient?.displayName ?? 'No recipient',
            style: text.titleLarge?.copyWith(fontSize: 19),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            _meta(part),
            style: mono(text.bodySmall!, color: AppColors.muted, size: 12),
            maxLines: 2,
          ),
          if (blocked != null) ...[
            const SizedBox(height: 12),
            _BlockedNote(reason: blocked),
          ] else ...[
            const SizedBox(height: 14),
            _Step(
              number: 1,
              label: 'Open WhatsApp chat',
              trailing: Icons.open_in_new,
              active: !chatOpened,
              done: chatOpened,
              onTap: busy ? null : onOpenChat,
            ),
            const SizedBox(height: 6),
            _Step(
              number: 2,
              label: 'Attach the PDF',
              trailing: Icons.ios_share,
              active: chatOpened && !pdfShared,
              done: pdfShared,
              onTap: busy ? null : onSharePdf,
            ),
            const SizedBox(height: 6),
            _Step(
              number: 3,
              label: 'Mark sent & go to next',
              active: chatOpened && pdfShared,
              done: false,
              onTap: busy ? null : onMarkSent,
            ),
          ],
        ],
      ),
    );
  }

  /// "+919442302726 · Serial No: 38 · pages 75-76"
  static String _meta(JobPart part) {
    final bits = <String>[
      if (part.recipient?.phone != null) part.recipient!.phone!,
      if (part.key != null && part.key!.isNotEmpty) 'no. ${part.key}',
      'pages ${part.pageLabel}',
      part.sizeLabel,
    ];
    return bits.join('  ·  ');
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.label,
    required this.active,
    required this.done,
    required this.onTap,
    this.trailing,
  });

  final int number;
  final String label;

  /// The step that should happen next: filled, so the eye lands on it.
  final bool active;

  /// Already done in this sitting.
  final bool done;
  /// Drawn as an icon rather than an arrow character: "↗" is absent from the
  /// bundled text font and renders as a missing-glyph box.
  final IconData? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final background = active ? AppColors.accent : Colors.transparent;
    final foreground = active
        ? Colors.white
        : done
            ? AppColors.muted
            : AppColors.inkSoft;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: active ? Colors.transparent : AppColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 19,
                height: 19,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? Colors.white.withValues(alpha: 0.24)
                      : done
                          ? AppColors.accent
                          : AppColors.accentSoft,
                ),
                child: done && !active
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : Text(
                        '$number',
                        style: mono(
                          const TextStyle(),
                          color: active ? Colors.white : AppColors.accentInk,
                          size: 10.5,
                          weight: FontWeight.w500,
                        ),
                      ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ),
              if (trailing != null)
                Icon(trailing, size: 15, color: foreground.withValues(alpha: 0.75)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockedNote extends StatelessWidget {
  const _BlockedNote({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.blockedSoft,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.block, size: 15, color: AppColors.blocked),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$reason. Fix the sheet and run the split again.',
              style: const TextStyle(fontSize: 12.5, color: AppColors.blocked),
            ),
          ),
        ],
      ),
    );
  }
}
