import 'package:flutter/material.dart';

import '../../models/job.dart';
import '../theme.dart';

/// One notice as a single compact row.
///
/// Everything that is not in focus lives here. A row is two tight lines, not a
/// card: 181 cards with borders and shadows flattens the hierarchy and makes
/// the screen exhausting to scan.
///
/// State is carried by form as well as text -- a leading dot, dimming, a rule
/// through the name -- so "done", "to send" and "cannot send" read at a glance
/// without reading the words.
class PartRow extends StatelessWidget {
  const PartRow({required this.part, required this.onTap, super.key});

  final JobPart part;

  /// Focuses this notice. Tapping a row is how the operator skips ahead or
  /// goes back to one they left.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final blocked = part.blockedReason;
    final sent = part.sent;

    final Color dot = blocked != null
        ? context.scheme.error
        : sent
            ? context.scheme.primary
            : context.scheme.primary.withValues(alpha: 0.4);

    final secondary = blocked ?? part.recipient?.phone ?? '—';

    return InkWell(
      onTap: onTap,
      child: Opacity(
        opacity: sent ? 0.55 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.scheme.outlineVariant)),
          ),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 11),
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      part.recipient?.displayName ??
                          (part.key == null ? 'Part ${part.index}' : 'no. ${part.key}'),
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        decoration: sent ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      secondary,
                      style: blocked != null
                          ? TextStyle(fontSize: 11.5, color: context.scheme.error)
                          : mono(text.labelSmall!, color: context.scheme.onSurfaceVariant, size: 11.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (sent)
                Icon(Icons.check, size: 15, color: context.scheme.primary)
              else
                Text(
                  part.pageLabel,
                  style: mono(text.labelSmall!, color: context.scheme.onSurfaceVariant, size: 11.5),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
