import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/capabilities.dart';
import '../models/job.dart';
import 'api_exception.dart';

/// Talks to the BeDocToPdf API.
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  /// e.g. http://192.168.1.20:4000 -- never "localhost" from a real device.
  final String baseUrl;
  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 30);

  /// Conversion of a long document runs in the background on the server, but
  /// analysis is synchronous and can take a while on a 362-page file.
  static const Duration _analyseTimeout = Duration(minutes: 5);

  Uri _uri(String path) => Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');

  void close() => _client.close();

  Never _fail(http.Response response) {
    String message = 'Request failed (HTTP ${response.statusCode}).';
    String? code;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] is Map) {
        final error = (decoded['error'] as Map).cast<String, dynamic>();
        message = (error['message'] ?? message).toString();
        code = error['code']?.toString();
      }
    } catch (_) {
      // Not JSON -- keep the generic message rather than showing raw HTML.
    }
    throw ApiException(message, code: code, statusCode: response.statusCode);
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) _fail(response);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw ApiException('The server returned an unexpected response.');
    }
    return decoded.cast<String, dynamic>();
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException {
      rethrow;
    } on SocketException catch (error) {
      throw ApiException(
        'Could not reach the server at $baseUrl. Check the address and that '
        'the device is on the same network.\n(${error.message})',
      );
    } on HttpException catch (error) {
      throw ApiException('HTTP error talking to $baseUrl: ${error.message}');
    } on FormatException {
      throw ApiException('The server response could not be read as JSON.');
    }
  }

  Future<bool> ping() => _guard(() async {
        final response = await _client.get(_uri('/health')).timeout(_timeout);
        return response.statusCode == 200;
      });

  Future<Capabilities> fetchCapabilities() => _guard(() async {
        final response = await _client.get(_uri('/api/capabilities')).timeout(_timeout);
        return Capabilities.fromJson(_decode(response));
      });

  /// Inspect a document so the marker and key label can be pre-filled.
  Future<DocumentAnalysis> analyse(String documentPath) => _guard(() async {
        final request = http.MultipartRequest('POST', _uri('/api/analyse'))
          ..files.add(await http.MultipartFile.fromPath('document', documentPath));
        final streamed = await _client.send(request).timeout(_analyseTimeout);
        final response = await http.Response.fromStream(streamed);
        return DocumentAnalysis.fromJson(_decode(response));
      });

  Future<Job> createJob({
    required String documentPath,
    String? recipientsPath,
    required String splitMode,
    int chunkSize = 1,
    String? marker,
    String? keyLabel,
    String matchBy = 'order',
    String? filenamePattern,
    String? messageTemplate,
  }) =>
      _guard(() async {
        final request = http.MultipartRequest('POST', _uri('/api/jobs'))
          ..fields['splitMode'] = splitMode
          ..fields['chunkSize'] = chunkSize.toString()
          ..fields['matchBy'] = matchBy;

        if (marker != null && marker.isNotEmpty) request.fields['marker'] = marker;
        if (keyLabel != null && keyLabel.isNotEmpty) request.fields['keyLabel'] = keyLabel;
        if (filenamePattern != null && filenamePattern.isNotEmpty) {
          request.fields['filenamePattern'] = filenamePattern;
        }
        if (messageTemplate != null && messageTemplate.isNotEmpty) {
          request.fields['messageTemplate'] = messageTemplate;
        }

        request.files.add(await http.MultipartFile.fromPath('document', documentPath));
        if (recipientsPath != null) {
          request.files.add(await http.MultipartFile.fromPath('recipients', recipientsPath));
        }

        // Uploading a large .docx can take a while on a phone connection.
        final streamed = await _client.send(request).timeout(const Duration(minutes: 10));
        final response = await http.Response.fromStream(streamed);
        final body = _decode(response);
        return Job.fromJson((body['job'] as Map).cast<String, dynamic>());
      });

  Future<Job> fetchJob(String jobId) => _guard(() async {
        final response = await _client.get(_uri('/api/jobs/$jobId')).timeout(_timeout);
        final body = _decode(response);
        return Job.fromJson((body['job'] as Map).cast<String, dynamic>());
      });

  Future<void> markSent(String jobId, int partIndex, {required bool sent}) =>
      _guard(() async {
        final response = await _client
            .post(
              _uri('/api/jobs/$jobId/parts/$partIndex/sent'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({'sent': sent}),
            )
            .timeout(_timeout);
        if (response.statusCode < 200 || response.statusCode >= 300) _fail(response);
      });

  /// Download a part into the app's documents directory and return the file.
  ///
  /// The file has to exist locally before it can go into the share sheet, so
  /// this is what makes WhatsApp delivery possible at all.
  Future<File> downloadPart(Job job, JobPart part) => _guard(() async {
        final directory = await getApplicationDocumentsDirectory();
        final jobDirectory = Directory('${directory.path}/jobs/${job.id}');
        await jobDirectory.create(recursive: true);
        final file = File('${jobDirectory.path}/${part.filename}');

        // Re-use an earlier download; parts are immutable once a job is ready.
        if (await file.exists() && await file.length() == part.sizeBytes) {
          return file;
        }

        final url = part.downloadUrl.isNotEmpty
            ? Uri.parse(part.downloadUrl)
            : _uri('/api/jobs/${job.id}/parts/${part.index}/download');

        final response = await _client.get(url).timeout(const Duration(minutes: 2));
        if (response.statusCode != 200) _fail(response);
        await file.writeAsBytes(response.bodyBytes, flush: true);
        return file;
      });
}
