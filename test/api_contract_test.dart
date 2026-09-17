// Contract tests: the app's models parsed against *real* backend responses.
//
// models_test.dart uses hand-written JSON, which proves the parsing logic but
// not that it matches the API. These fixtures were captured from a running
// BeDocToPdf (`test/fixtures/api/README.md` says how to regenerate them), so a
// renamed or dropped field on the server fails here instead of at the operator's
// first tap.
//
// The data is synthetic throughout -- the backend's own committed
// tests/fixtures/payslips.docx and a made-up staff sheet.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fe_doc_to_pdf/models/capabilities.dart';
import 'package:fe_doc_to_pdf/models/job.dart';
import 'package:fe_doc_to_pdf/ui/widgets/warning_banner.dart';

Map<String, dynamic> fixture(String name) {
  final file = File('test/fixtures/api/$name.json');
  expect(file.existsSync(), isTrue, reason: 'missing fixture ${file.path}');
  return (jsonDecode(file.readAsStringSync()) as Map).cast<String, dynamic>();
}

void main() {
  group('GET /api/capabilities', () {
    test('drives the setup form', () {
      final capabilities = Capabilities.fromJson(fixture('capabilities'));

      expect(capabilities.splitModes, containsAll(['section', 'page', 'chunk', 'whole']));
      expect(capabilities.matchStrategies, containsAll(['order', 'key']));
      expect(capabilities.defaultSplitMode, 'section');
      expect(capabilities.defaultMatchBy, 'order');
      expect(capabilities.defaultFilenamePattern, isNotEmpty);
      expect(capabilities.defaultMessageTemplate, isNotEmpty);
      expect(capabilities.maxPages, greaterThan(0));

      // The home screen shows the two-tap notice off this flag, and the whole
      // delivery UX is built around it being false.
      expect(capabilities.attachesFileAutomatically, isFalse);

      // The form renders these as "Tokens: {{x}} {{y}}" helper text.
      expect(capabilities.filenameTokens, contains('index'));
      expect(capabilities.messageTokens, contains('name'));
    });
  });

  group('POST /api/analyse', () {
    test('yields a marker suggestion the form can prefill', () {
      final analysis = DocumentAnalysis.fromJson(fixture('analyse'));

      expect(analysis.pageCount, 6);
      expect(analysis.markerSuggestions, isNotEmpty);

      final best = analysis.bestMarker!;
      expect(best.marker, contains('RECIPIENT:'));
      expect(best.occurrences, 3);
      expect(best.pagesPerSection, 2);
      expect(best.regular, isTrue);
      expect(best.summary, '3 sections, every 2 pages');
    });

    test('an absent key label is absent, not a crash', () {
      final analysis = DocumentAnalysis.fromJson(fixture('analyse'));
      // This document has no "Serial No:"-style label; the chip row must just
      // not render rather than blowing up.
      expect(analysis.keyLabelSuggestions, isEmpty);
      expect(analysis.bestKeyLabel, isNull);
    });
  });

  group('POST /api/jobs', () {
    test('the 202 body parses before any part exists', () {
      final job = Job.fromJson(fixture('create')['job'] as Map<String, dynamic>);

      expect(job.id, isNotEmpty);
      expect(job.status.isTerminal, isFalse, reason: 'work has not started yet');
      expect(job.parts, isEmpty);
      // JobScreen shows a spinner off this, so it must not throw on nulls.
      expect(job.status.label, isNotEmpty);
    });
  });

  group('GET /api/jobs/:id', () {
    test('a ready job carries everything the delivery list renders', () {
      final job = Job.fromJson(fixture('job')['job'] as Map<String, dynamic>);

      expect(job.status, JobStatus.ready);
      expect(job.status.isTerminal, isTrue);
      expect(job.pageCount, 6);
      expect(job.documentName, 'Payslips.docx');
      expect(job.splitMode, 'section');
      expect(job.matchStrategy, 'key', reason: 'shown in the progress header');
      expect(job.partCount, 3);
      expect(job.deliverableCount, 3);
      expect(job.warnings, isEmpty);
      expect(job.parts, hasLength(3));
      expect(job.sentCount, 0);
    });

    test('every part is renderable and sendable', () {
      final job = Job.fromJson(fixture('job')['job'] as Map<String, dynamic>);

      for (final part in job.parts) {
        expect(part.index, greaterThan(0));
        expect(part.filename, endsWith('.pdf'));
        expect(part.pageLabel, isNotEmpty);
        expect(part.pageCount, 2, reason: 'each payslip is 2 pages');
        expect(part.sizeBytes, greaterThan(0));
        expect(part.sizeLabel, isNotEmpty);
        expect(part.downloadUrl, startsWith('http'),
            reason: 'must be absolute; a phone cannot resolve a relative path');
        expect(part.deliverable, isTrue);
        expect(part.blockedReason, isNull);
        expect(part.sent, isFalse);
        expect(part.message, isNotEmpty);
        expect(part.recipient, isNotNull);
        expect(part.recipient!.phone, startsWith('+'), reason: 'E.164');
        expect(part.recipient!.displayName, isNotEmpty);

        // The link the "Open chat" button launches.
        expect(part.whatsappLink, isNotNull);
        expect(part.whatsappLink!, startsWith('https://wa.me/'));
        // Spaces must be percent-encoded: WhatsApp renders "+" literally in
        // the message box.
        expect(part.whatsappLink!, contains('%20'));
        expect(part.whatsappLink!.split('?text=').last, isNot(contains('+')));
      }
    });

    test('the filename pattern was applied server-side', () {
      final job = Job.fromJson(fixture('job')['job'] as Map<String, dynamic>);
      expect(job.parts.map((p) => p.filename), [
        'Payslip-EMP-1001.pdf',
        'Payslip-EMP-1002.pdf',
        'Payslip-EMP-1003.pdf',
      ]);
    });

    test('a phone pulled from a messy cell survives the API', () {
      final job = Job.fromJson(fixture('job')['job'] as Map<String, dynamic>);
      final grace = job.parts.firstWhere((p) => p.key == 'EMP-1003').recipient!;

      // Sheet cell was: "Mob: 8086006942, 8086006941, email: grace@example.com"
      expect(grace.phone, '+918086006942');
      expect(grace.phoneAlternatives, ['+918086006941']);
      expect(grace.phoneRaw, contains('Mob:'),
          reason: 'the row shows the original so the operator can sanity-check it');
    });

    test('nextUnsent picks the first deliverable part', () {
      final job = Job.fromJson(fixture('job')['job'] as Map<String, dynamic>);
      expect(job.nextUnsent?.index, 1);
    });
  });

  group('warning severity', () {
    // The banner orders warnings by matching the backend's own phrasing, so a
    // reworded server warning would quietly demote the most important one.
    // These are the exact sentences pipeline.service.js emits.
    test('an undelivered-notice warning outranks housekeeping', () {
      const undelivered =
          '176 of 181 notices have no recipient. The sheet has 5 rows and the '
          'document produced 181 notices, so those are still created but cannot '
          'be sent. Check you uploaded the full list.';
      const peopleMissed =
          '2 of 4 people on the sheet have no notice in this document. It '
          'produced 2 notices, so those people receive nothing. Check the '
          'document covers the whole list.';
      const housekeeping =
          'Header found on row 4; the 3 row(s) above it were treated as title '
          'banners and skipped.';

      final ordered = WarningBanner.orderBySeverity(
        [housekeeping, undelivered, peopleMissed],
      );
      expect(ordered.first, undelivered, reason: 'most severe leads the banner');
      expect(ordered.last, housekeeping);
    });
  });

  group('POST /api/jobs/:id/parts/:index/sent', () {
    test('returns the updated part', () {
      final part = JobPart.fromJson(fixture('sent')['part'] as Map<String, dynamic>);
      expect(part.index, 1);
      expect(part.sent, isTrue);
      expect(part.deliverable, isTrue);
    });
  });
}
