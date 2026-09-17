import 'package:flutter/material.dart';

import '../theme.dart';

/// Which slice of the run the list is showing.
enum PartFilter { toSend, sent, blocked }

/// A scrollable row of counts that doubles as the filter.
///
/// The counts are the useful part -- "144 to send, 37 sent, 5 blocked" answers
/// the operator's question before they tap anything. Horizontally scrollable so
/// three labels with figures never overflow a narrow phone.
class FilterPills extends StatelessWidget {
  const FilterPills({
    required this.selected,
    required this.toSend,
    required this.sent,
    required this.blocked,
    required this.onChanged,
    super.key,
  });

  final PartFilter selected;
  final int toSend;
  final int sent;
  final int blocked;
  final ValueChanged<PartFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(right: 14),
      child: Row(
        children: [
          _pill(context, PartFilter.toSend, 'To send', toSend),
          const SizedBox(width: 6),
          _pill(context, PartFilter.sent, 'Sent', sent),
          if (blocked > 0) ...[
            const SizedBox(width: 6),
            _pill(context, PartFilter.blocked, 'Blocked', blocked, danger: true),
          ],
        ],
      ),
    );
  }

  Widget _pill(
    BuildContext context,
    PartFilter value,
    String label,
    int count, {
    bool danger = false,
  }) {
    final on = selected == value;
    final accent = danger ? AppColors.blocked : AppColors.accentInk;

    return Material(
      color: on
          ? (danger ? AppColors.blockedSoft : AppColors.accentSoft)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: on ? Colors.transparent : AppColors.line),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$label '),
                TextSpan(
                  text: '$count',
                  style: mono(
                    const TextStyle(),
                    color: on ? accent : AppColors.muted,
                    size: 12,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: on ? FontWeight.w600 : FontWeight.w400,
              color: on ? accent : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
