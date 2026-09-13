/// An error the backend reported, or a transport failure reaching it.
class ApiException implements Exception {
  ApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  /// True when the server could not be reached at all -- almost always a wrong
  /// base URL rather than a real fault, so the UI says so.
  bool get isNetworkIssue => statusCode == null;

  @override
  String toString() => message;
}
