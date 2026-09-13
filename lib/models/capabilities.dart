/// Server-declared options, so the UI does not hard-code defaults that the
/// backend owns.
class Capabilities {
  const Capabilities({
    required this.splitModes,
    required this.matchStrategies,
    required this.defaultSplitMode,
    required this.defaultMatchBy,
    required this.defaultFilenamePattern,
    required this.defaultMessageTemplate,
    required this.filenameTokens,
    required this.messageTokens,
    required this.maxPages,
    required this.attachesFileAutomatically,
  });

  final List<String> splitModes;
  final List<String> matchStrategies;
  final String defaultSplitMode;
  final String defaultMatchBy;
  final String defaultFilenamePattern;
  final String defaultMessageTemplate;
  final List<String> filenameTokens;
  final List<String> messageTokens;
  final int maxPages;

  /// False for click-to-chat: the operator attaches the PDF by hand. The UI
  /// uses this to decide whether to show the share step at all.
  final bool attachesFileAutomatically;

  static List<String> _strings(Object? value, List<String> fallback) {
    if (value is List) {
      return value.map((item) => item.toString()).toList(growable: false);
    }
    return fallback;
  }

  factory Capabilities.fromJson(Map<String, dynamic> json) {
    final defaults = (json['defaults'] as Map?)?.cast<String, dynamic>() ?? const {};
    final limits = (json['limits'] as Map?)?.cast<String, dynamic>() ?? const {};
    final delivery = (json['delivery'] as Map?)?.cast<String, dynamic>() ?? const {};

    return Capabilities(
      splitModes: _strings(json['splitModes'], const ['section', 'page', 'chunk', 'whole']),
      matchStrategies: _strings(json['matchStrategies'], const ['order', 'key']),
      defaultSplitMode: (defaults['splitMode'] ?? 'section').toString(),
      defaultMatchBy: (defaults['matchBy'] ?? 'order').toString(),
      defaultFilenamePattern: (defaults['filenamePattern'] ?? '{{docBase}}-{{index}}').toString(),
      defaultMessageTemplate: (defaults['messageTemplate'] ?? '').toString(),
      filenameTokens: _strings(json['filenameTokens'], const []),
      messageTokens: _strings(json['messageTokens'], const []),
      maxPages: (limits['maxPages'] as num?)?.toInt() ?? 500,
      attachesFileAutomatically: delivery['attachesFileAutomatically'] == true,
    );
  }
}

/// A marker the server found repeating through the document.
class MarkerSuggestion {
  const MarkerSuggestion({
    required this.marker,
    required this.occurrences,
    required this.pagesPerSection,
    required this.regular,
  });

  final String marker;
  final int occurrences;

  /// Null when the marker does not repeat on a fixed cadence.
  final int? pagesPerSection;
  final bool regular;

  factory MarkerSuggestion.fromJson(Map<String, dynamic> json) => MarkerSuggestion(
        marker: (json['marker'] ?? '').toString(),
        occurrences: (json['occurrences'] as num?)?.toInt() ?? 0,
        pagesPerSection: (json['pagesPerSection'] as num?)?.toInt(),
        regular: json['regular'] == true,
      );

  String get summary {
    final cadence = pagesPerSection == null
        ? 'irregular spacing'
        : 'every $pagesPerSection page${pagesPerSection == 1 ? '' : 's'}';
    return '$occurrences sections, $cadence';
  }
}

class KeyLabelSuggestion {
  const KeyLabelSuggestion({
    required this.keyLabel,
    required this.occurrences,
    required this.sample,
  });

  final String keyLabel;
  final int occurrences;
  final String? sample;

  factory KeyLabelSuggestion.fromJson(Map<String, dynamic> json) => KeyLabelSuggestion(
        keyLabel: (json['keyLabel'] ?? '').toString(),
        occurrences: (json['occurrences'] as num?)?.toInt() ?? 0,
        sample: json['sample']?.toString(),
      );
}

/// Result of `POST /api/analyse`: what the document looks like before we commit
/// to splitting it.
class DocumentAnalysis {
  const DocumentAnalysis({
    required this.pageCount,
    required this.markerSuggestions,
    required this.keyLabelSuggestions,
  });

  final int pageCount;
  final List<MarkerSuggestion> markerSuggestions;
  final List<KeyLabelSuggestion> keyLabelSuggestions;

  factory DocumentAnalysis.fromJson(Map<String, dynamic> json) => DocumentAnalysis(
        pageCount: (json['pageCount'] as num?)?.toInt() ?? 0,
        markerSuggestions: ((json['markerSuggestions'] as List?) ?? const [])
            .map((item) => MarkerSuggestion.fromJson((item as Map).cast<String, dynamic>()))
            .toList(growable: false),
        keyLabelSuggestions: ((json['keyLabelSuggestions'] as List?) ?? const [])
            .map((item) => KeyLabelSuggestion.fromJson((item as Map).cast<String, dynamic>()))
            .toList(growable: false),
      );

  MarkerSuggestion? get bestMarker =>
      markerSuggestions.isEmpty ? null : markerSuggestions.first;

  KeyLabelSuggestion? get bestKeyLabel =>
      keyLabelSuggestions.isEmpty ? null : keyLabelSuggestions.first;
}
