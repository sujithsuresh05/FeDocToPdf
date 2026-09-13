import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/job.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';
import '../services/settings_service.dart';

/// Owns one job and keeps it in sync with the server while it is running.
class JobController extends ChangeNotifier {
  JobController({required ApiClient api, SettingsService? settings})
      : _api = api,
        _settings = settings ?? SettingsService();

  final ApiClient _api;
  final SettingsService _settings;

  Job? _job;
  Timer? _poll;
  String? _error;
  bool _disposed = false;

  /// Part indices with a download or share in flight, so each row can show its
  /// own spinner instead of blocking the whole list.
  final Set<int> _busyParts = <int>{};

  Job? get job => _job;
  String? get error => _error;
  bool isPartBusy(int index) => _busyParts.contains(index);

  /// Poll while the server is still working. Two seconds keeps the UI honest
  /// without hammering a box that is running LibreOffice.
  static const Duration _pollInterval = Duration(seconds: 2);

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void attach(Job job) {
    _job = job;
    _error = null;
    unawaited(_settings.writeLastJobId(job.id));
    _notify();
    if (!job.status.isTerminal) _startPolling();
  }

  Future<void> load(String jobId) async {
    try {
      attach(await _api.fetchJob(jobId));
    } on ApiException catch (error) {
      _error = error.message;
      _notify();
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(_pollInterval, (_) => unawaited(refresh()));
  }

  Future<void> refresh() async {
    final current = _job;
    if (current == null) return;
    try {
      final next = await _api.fetchJob(current.id);
      _job = next;
      _error = null;
      if (next.status.isTerminal) {
        _poll?.cancel();
        _poll = null;
      }
      _notify();
    } on ApiException catch (error) {
      // A dropped poll is not worth tearing the screen down; surface it and
      // let the next tick try again.
      _error = error.message;
      _notify();
    }
  }

  /// Download a part, returning null (and setting [error]) on failure.
  Future<File?> download(JobPart part) async {
    final current = _job;
    if (current == null) return null;
    _busyParts.add(part.index);
    _notify();
    try {
      return await _api.downloadPart(current, part);
    } on ApiException catch (error) {
      _error = error.message;
      return null;
    } finally {
      _busyParts.remove(part.index);
      _notify();
    }
  }

  Future<void> setSent(JobPart part, {required bool sent}) async {
    final current = _job;
    if (current == null) return;

    // Update locally first: the operator is mid-flow and should not wait for a
    // round trip to see the row tick over.
    final updated = current.parts
        .map((candidate) => candidate.index == part.index ? candidate.copyWith(sent: sent) : candidate)
        .toList(growable: false);
    _job = current.copyWithParts(updated);
    _notify();

    try {
      await _api.markSent(current.id, part.index, sent: sent);
    } on ApiException catch (error) {
      // Put it back the way it was so the UI never claims a state the server
      // does not have.
      final reverted = current.parts
          .map((candidate) =>
              candidate.index == part.index ? candidate.copyWith(sent: !sent) : candidate)
          .toList(growable: false);
      _job = current.copyWithParts(reverted);
      _error = 'Could not record that as sent: ${error.message}';
      _notify();
    }
  }

  void clearError() {
    _error = null;
    _notify();
  }
}
