import 'package:flutter/material.dart';

/// Shows the server's warnings.
///
/// These matter more than they look: a count mismatch between the document and
/// the sheet means some notices have no recipient, and that must not be
/// mistaken for a normal run.
class WarningBanner extends StatelessWidget {
  const WarningBanner({required this.warnings, super.key});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: scheme.tertiaryContainer,
      child: ExpansionTile(
        leading: Icon(Icons.warning_amber_rounded, color: scheme.onTertiaryContainer),
        title: Text(
          '${warnings.length} thing${warnings.length == 1 ? '' : 's'} to check',
          style: TextStyle(color: scheme.onTertiaryContainer, fontWeight: FontWeight.w600),
        ),
        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
        children: warnings
            .map(
              (warning) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(
                      child: Text(warning, style: TextStyle(color: scheme.onTertiaryContainer)),
                    ),
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
