import 'package:flutter/material.dart';

import '../theme.dart';

/// The server's warnings, stated rather than hidden.
///
/// These are not decoration. The worst real case is a run where the document
/// split into 181 notices but the sheet held 5 rows: 176 notices with nobody to
/// send them to. That must not look like a normal run, and the count must not
/// sit behind a disclosure triangle reading "2 things to check" -- so the first
/// warning is shown as a sentence at full size and the rest are listed under it.
class WarningBanner extends StatelessWidget {
  const WarningBanner({required this.warnings, super.key});

  final List<String> warnings;

  /// A warning naming a count mismatch outranks the housekeeping ones, because
  /// it is the one that means notices will go undelivered.
  static int _severity(String warning) {
    final w = warning.toLowerCase();
    if (w.contains('deliverable part') || w.contains('no recipient')) return 0;
    if (w.contains('unusable phone') || w.contains('not assigned')) return 1;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) return const SizedBox.shrink();

    final ordered = [...warnings]..sort((a, b) => _severity(a).compareTo(_severity(b)));
    final headline = ordered.first;
    final rest = ordered.skip(1).toList(growable: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
      decoration: const BoxDecoration(
        color: AppColors.warnSoft,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.warning_amber_rounded, size: 17, color: AppColors.warn),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.warn,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                for (final warning in rest)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      warning,
                      style: const TextStyle(fontSize: 11.5, height: 1.4, color: AppColors.warn),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
