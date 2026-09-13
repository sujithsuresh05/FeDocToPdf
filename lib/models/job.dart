/// Where a job is in the pipeline. Mirrors the backend's `status` field.
enum JobStatus { queued, converting, splitting, ready, failed, unknown }

JobStatus jobStatusFrom(String? value) {
  switch (value) {
    case 'queued':
      return JobStatus.queued;
    case 'converting':
      return JobStatus.converting;
    case 'splitting':
      return JobStatus.splitting;
    case 'ready':
      return JobStatus.ready;
    case 'failed':
      return JobStatus.failed;
    default:
      return JobStatus.unknown;
  }
}

extension JobStatusDisplay on JobStatus {
  bool get isTerminal => this == JobStatus.ready || this == JobStatus.failed;

  String get label {
    switch (this) {
      case JobStatus.queued:
        return 'Queued';
      case JobStatus.converting:
        return 'Converting document';
      case JobStatus.splitting:
        return 'Splitting into PDFs';
      case JobStatus.ready:
        return 'Ready';
      case JobStatus.failed:
        return 'Failed';
      case JobStatus.unknown:
        return 'Unknown';
    }
  }
}

/// The spreadsheet row a part was matched to.
class Recipient {
  const Recipient({
    required this.rowNumber,
    required this.name,
    required this.key,
    required this.phone,
    required this.phoneRaw,
    required this.phoneAlternatives,
    required this.phoneError,
  });

  final int? rowNumber;
  final String? name;
  final String? key;

  /// Normalised E.164 number, or null when the sheet's value was unusable.
  final String? phone;
  final String? phoneRaw;

  /// Other numbers found in the same cell, offered when the first is wrong.
  final List<String> phoneAlternatives;
  final String? phoneError;

  factory Recipient.fromJson(Map<String, dynamic> json) => Recipient(
        rowNumber: (json['rowNumber'] as num?)?.toInt(),
        name: json['name']?.toString(),
        key: json['key']?.toString(),
        phone: json['phone']?.toString(),
        phoneRaw: json['phoneRaw']?.toString(),
        phoneAlternatives: ((json['phoneAlternatives'] as List?) ?? const [])
            .map((item) => item.toString())
            .toList(growable: false),
        phoneError: json['phoneError']?.toString(),
      );

  String get displayName {
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    final k = key?.trim();
    if (k != null && k.isNotEmpty) return 'Row $rowNumber ($k)';
    return 'Row $rowNumber';
  }
}

/// One output PDF.
class JobPart {
  const JobPart({
    required this.index,
    required this.filename,
    required this.pageLabel,
    required this.pageCount,
    required this.sizeBytes,
    required this.key,
    required this.message,
    required this.whatsappLink,
    required this.downloadUrl,
    required this.deliverable,
    required this.unassigned,
    required this.sent,
    required this.recipient,
  });

  final int index;
  final String filename;

  /// Human-readable page range, e.g. "3-4".
  final String pageLabel;
  final int pageCount;
  final int sizeBytes;
  final String? key;
  final String message;

  /// Null when the recipient has no usable phone number.
  final String? whatsappLink;
  final String downloadUrl;

  /// True when this part has somewhere to go.
  final bool deliverable;

  /// True for pages that fell outside every recipient's section.
  final bool unassigned;
  final bool sent;
  final Recipient? recipient;

  factory JobPart.fromJson(Map<String, dynamic> json) => JobPart(
        index: (json['index'] as num?)?.toInt() ?? 0,
        filename: (json['filename'] ?? '').toString(),
        pageLabel: (json['pageLabel'] ?? '').toString(),
        pageCount: (json['pageCount'] as num?)?.toInt() ?? 0,
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
        key: json['key']?.toString(),
        message: (json['message'] ?? '').toString(),
        whatsappLink: json['whatsappLink']?.toString(),
        downloadUrl: (json['downloadUrl'] ?? '').toString(),
        deliverable: json['deliverable'] == true,
        unassigned: json['unassigned'] == true,
        sent: json['sent'] == true,
        recipient: json['recipient'] == null
            ? null
            : Recipient.fromJson((json['recipient'] as Map).cast<String, dynamic>()),
      );

  JobPart copyWith({bool? sent}) => JobPart(
        index: index,
        filename: filename,
        pageLabel: pageLabel,
        pageCount: pageCount,
        sizeBytes: sizeBytes,
        key: key,
        message: message,
        whatsappLink: whatsappLink,
        downloadUrl: downloadUrl,
        deliverable: deliverable,
        unassigned: unassigned,
        sent: sent ?? this.sent,
        recipient: recipient,
      );

  String get sizeLabel {
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (sizeBytes >= 1024) return '${(sizeBytes / 1024).round()} KB';
    return '$sizeBytes B';
  }

  /// Why this part cannot be sent, or null when it can.
  String? get blockedReason {
    if (unassigned) return 'These pages matched no recipient';
    if (recipient == null) return 'No spreadsheet row for this part';
    if (recipient!.phone == null) {
      final raw = recipient!.phoneRaw;
      return raw == null || raw.isEmpty
          ? 'Row has no phone number'
          : 'Unusable phone number: "$raw"';
    }
    return null;
  }
}

class Job {
  const Job({
    required this.id,
    required this.status,
    required this.splitMode,
    required this.pageCount,
    required this.documentName,
    required this.warnings,
    required this.errorMessage,
    required this.parts,
    required this.matchStrategy,
    required this.partCount,
    required this.deliverableCount,
  });

  final String id;
  final JobStatus status;
  final String splitMode;
  final int? pageCount;
  final String? documentName;
  final List<String> warnings;
  final String? errorMessage;
  final List<JobPart> parts;

  /// How parts were actually paired to rows -- may differ from the request when
  /// key matching had to degrade to document order.
  final String? matchStrategy;
  final int partCount;
  final int deliverableCount;

  factory Job.fromJson(Map<String, dynamic> json) {
    final summary = (json['summary'] as Map?)?.cast<String, dynamic>();
    final parts = ((json['parts'] as List?) ?? const [])
        .map((item) => JobPart.fromJson((item as Map).cast<String, dynamic>()))
        .toList(growable: false);

    return Job(
      id: (json['id'] ?? '').toString(),
      status: jobStatusFrom(json['status']?.toString()),
      splitMode: (json['splitMode'] ?? '').toString(),
      pageCount: (json['pageCount'] as num?)?.toInt(),
      documentName: (json['document'] as Map?)?['originalName']?.toString(),
      warnings: ((json['warnings'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      errorMessage: (json['error'] as Map?)?['message']?.toString(),
      parts: parts,
      matchStrategy: json['matchStrategy']?.toString(),
      partCount: (summary?['partCount'] as num?)?.toInt() ?? parts.length,
      deliverableCount: (summary?['deliverableCount'] as num?)?.toInt() ??
          parts.where((part) => part.deliverable).length,
    );
  }

  Job copyWithParts(List<JobPart> next) => Job(
        id: id,
        status: status,
        splitMode: splitMode,
        pageCount: pageCount,
        documentName: documentName,
        warnings: warnings,
        errorMessage: errorMessage,
        parts: next,
        matchStrategy: matchStrategy,
        partCount: partCount,
        deliverableCount: deliverableCount,
      );

  int get sentCount => parts.where((part) => part.sent).length;

  /// The next part worth acting on, so the operator is not hunting through 181
  /// rows to find where they left off.
  JobPart? get nextUnsent {
    for (final part in parts) {
      if (part.deliverable && !part.sent) return part;
    }
    return null;
  }
}
