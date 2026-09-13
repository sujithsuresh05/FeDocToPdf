import 'package:flutter_test/flutter_test.dart';
import 'package:fe_doc_to_pdf/models/job.dart';
import 'package:fe_doc_to_pdf/models/capabilities.dart';

/// Sample shaped like a real `GET /api/jobs/:id` response.
Map<String, dynamic> jobJson() => {
      'id': 'abc-123',
      'status': 'ready',
      'splitMode': 'section',
      'pageCount': 362,
      'matchStrategy': 'order',
      'document': {'originalName': 'ProfTax.docx'},
      'summary': {'partCount': 181, 'deliverableCount': 5},
      'warnings': ['Header found on row 4'],
      'parts': [
        {
          'index': 1,
          'filename': 'ProfTax_Traders_Notice-1.pdf',
          'pageLabel': '1-2',
          'pageCount': 2,
          'sizeBytes': 70168,
          'key': '1',
          'message': 'Dear A, your notice is attached.',
          'whatsappLink': 'https://wa.me/919442302726?text=Dear%20A',
          'downloadUrl': 'http://host/api/jobs/abc-123/parts/1/download',
          'deliverable': true,
          'sent': false,
          'recipient': {
            'rowNumber': 5,
            'name': 'JASMINE SUNITHA M',
            'key': '1',
            'phone': '+919442302726',
            'phoneRaw': '9442302726',
            'phoneAlternatives': [],
          },
        },
        {
          'index': 2,
          'filename': 'ProfTax_Traders_Notice-2.pdf',
          'pageLabel': '3-4',
          'pageCount': 2,
          'sizeBytes': 70000,
          'key': '2',
          'message': '',
          'whatsappLink': null,
          'downloadUrl': 'http://host/api/jobs/abc-123/parts/2/download',
          'deliverable': false,
          'sent': false,
          'recipient': null,
        },
      ],
    };

void main() {
  group('Job', () {
    test('parses a ready job with its parts', () {
      final job = Job.fromJson(jobJson());
      expect(job.id, 'abc-123');
      expect(job.status, JobStatus.ready);
      expect(job.pageCount, 362);
      expect(job.documentName, 'ProfTax.docx');
      expect(job.partCount, 181);
      expect(job.deliverableCount, 5);
      expect(job.warnings, hasLength(1));
      expect(job.parts, hasLength(2));
    });

    test('nextUnsent skips parts that cannot be delivered', () {
      final job = Job.fromJson(jobJson());
      expect(job.nextUnsent?.index, 1, reason: 'part 2 has no recipient');
    });

    test('nextUnsent is null once everything deliverable is sent', () {
      final job = Job.fromJson(jobJson());
      final updated = job.copyWithParts(
        job.parts.map((part) => part.copyWith(sent: true)).toList(),
      );
      expect(updated.nextUnsent, isNull);
      expect(updated.sentCount, 2);
    });

    test('unknown status does not throw', () {
      final job = Job.fromJson({...jobJson(), 'status': 'something-new'});
      expect(job.status, JobStatus.unknown);
      expect(job.status.isTerminal, isFalse);
    });

    test('tolerates a minimal payload', () {
      final job = Job.fromJson({'id': 'x', 'status': 'queued'});
      expect(job.parts, isEmpty);
      expect(job.pageCount, isNull);
      expect(job.partCount, 0);
    });
  });

  group('JobPart', () {
    test('explains why a part is blocked', () {
      final parts = Job.fromJson(jobJson()).parts;
      expect(parts[0].blockedReason, isNull);
      expect(parts[1].blockedReason, 'No spreadsheet row for this part');
    });

    test('reports an unusable phone number with the original value', () {
      final part = JobPart.fromJson({
        'index': 3,
        'deliverable': false,
        'recipient': {'rowNumber': 7, 'name': 'X', 'phone': null, 'phoneRaw': 'not-a-number'},
      });
      expect(part.blockedReason, contains('not-a-number'));
    });

    test('flags pages that matched no recipient', () {
      final part = JobPart.fromJson({'index': 1, 'unassigned': true});
      expect(part.blockedReason, 'These pages matched no recipient');
    });

    test('formats sizes for humans', () {
      expect(JobPart.fromJson({'sizeBytes': 512}).sizeLabel, '512 B');
      expect(JobPart.fromJson({'sizeBytes': 70168}).sizeLabel, '69 KB');
      expect(JobPart.fromJson({'sizeBytes': 2621440}).sizeLabel, '2.5 MB');
    });

    test('falls back to the row number when a name is missing', () {
      final recipient = Recipient.fromJson({'rowNumber': 9, 'name': '  ', 'key': 'EMP-9'});
      expect(recipient.displayName, 'Row 9 (EMP-9)');
    });
  });

  group('Capabilities', () {
    test('reads server defaults', () {
      final capabilities = Capabilities.fromJson({
        'splitModes': ['section', 'page'],
        'defaults': {'splitMode': 'section', 'filenamePattern': '{{docBase}}-{{index}}'},
        'limits': {'maxPages': 500},
        'delivery': {'attachesFileAutomatically': false},
        'filenameTokens': ['docBase', 'index'],
      });
      expect(capabilities.splitModes, ['section', 'page']);
      expect(capabilities.defaultFilenamePattern, '{{docBase}}-{{index}}');
      expect(capabilities.maxPages, 500);
      expect(capabilities.attachesFileAutomatically, isFalse);
    });

    test('falls back when the server sends nothing useful', () {
      final capabilities = Capabilities.fromJson({});
      expect(capabilities.splitModes, ['section', 'page', 'chunk', 'whole']);
      expect(capabilities.defaultSplitMode, 'section');
    });
  });

  group('DocumentAnalysis', () {
    test('surfaces the best marker and key label', () {
      final analysis = DocumentAnalysis.fromJson({
        'pageCount': 362,
        'markerSuggestions': [
          {'marker': 'Form No.128', 'occurrences': 181, 'pagesPerSection': 2, 'regular': true},
        ],
        'keyLabelSuggestions': [
          {'keyLabel': 'Serial No:', 'occurrences': 181, 'sample': '1'},
        ],
      });
      expect(analysis.bestMarker?.marker, 'Form No.128');
      expect(analysis.bestMarker?.summary, '181 sections, every 2 pages');
      expect(analysis.bestKeyLabel?.keyLabel, 'Serial No:');
    });

    test('handles a document with no repeating marker', () {
      final analysis = DocumentAnalysis.fromJson({'pageCount': 3});
      expect(analysis.bestMarker, isNull);
      expect(analysis.markerSuggestions, isEmpty);
    });
  });
}
