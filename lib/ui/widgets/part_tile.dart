import 'package:flutter/material.dart';

import '../../models/job.dart';

/// One output PDF with its delivery actions.
class PartTile extends StatelessWidget {
  const PartTile({
    required this.part,
    required this.busy,
    required this.onOpenChat,
    required this.onSharePdf,
    required this.onToggleSent,
    this.highlight = false,
    super.key,
  });

  final JobPart part;
  final bool busy;
  final VoidCallback? onOpenChat;
  final VoidCallback? onSharePdf;
  final ValueChanged<bool> onToggleSent;

  /// Marks the part the operator should handle next.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blocked = part.blockedReason;
    final recipient = part.recipient;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      color: highlight ? scheme.primaryContainer.withOpacity(0.45) : null,
      shape: highlight
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.primary, width: 1.5),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: part.sent
                      ? scheme.primary
                      : blocked != null
                          ? scheme.errorContainer
                          : scheme.surfaceContainerHighest,
                  child: part.sent
                      ? Icon(Icons.check, size: 18, color: scheme.onPrimary)
                      : Text('${part.index}', style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipient?.displayName ?? 'No recipient',
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        recipient?.phone ?? '—',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'pages ${part.pageLabel} · ${part.sizeLabel} · ${part.filename}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 4, right: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
            if (blocked != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.block, size: 15, color: scheme.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        blocked,
                        style: TextStyle(color: scheme.error, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            if (recipient != null && recipient.phoneAlternatives.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Other numbers in that cell: ${recipient.phoneAlternatives.join(", ")}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                TextButton.icon(
                  onPressed: busy ? null : onOpenChat,
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: const Text('Open chat'),
                ),
                TextButton.icon(
                  onPressed: busy ? null : onSharePdf,
                  icon: const Icon(Icons.attach_file, size: 18),
                  label: const Text('Share PDF'),
                ),
                const Spacer(),
                Tooltip(
                  message: part.sent ? 'Mark as not sent' : 'Mark as sent',
                  child: Checkbox(
                    value: part.sent,
                    onChanged: busy ? null : (value) => onToggleSent(value ?? false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
