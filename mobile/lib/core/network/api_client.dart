import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thin REST client for the MedTrack backend (`/v1` API described in
/// docs/architecture.md §7). Callers own JSON encoding/decoding of bodies.
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;
  String? _accessToken;

  /// Called when the server rejects the token we're holding (HTTP 401) —
  /// the app wires this to a sign-out so an expired session drops the user
  /// back to the login screen instead of leaving every screen failing.
  void Function()? onUnauthorized;

  void setAccessToken(String? token) => _accessToken = token;

  String? get accessToken => _accessToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Future<dynamic> get(String path) => _send('GET', path);

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) =>
      _send('POST', path, body: body);

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// Multipart upload — used for avatar photos. `fileBytes` is sent as the
  /// `file` field with `fileName` as its filename.
  Future<dynamic> uploadFile(
    String path, {
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({if (_accessToken != null) 'Authorization': 'Bearer $_accessToken'})
      ..files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));

    final streamed = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    // Only a rejected *existing* token means the session died. A 401 with no
    // token is just a failed sign-in attempt (wrong PIN/OTP), which the
    // login screens report themselves.
    if (response.statusCode == 401 && _accessToken != null) {
      _accessToken = null;
      onUnauthorized?.call();
    }
    throw ApiException(response.statusCode, response.body);
  }

  Future<dynamic> _send(String method, String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.Request(method, uri)..headers.addAll(_headers);
    if (body != null) request.body = jsonEncode(body);

    final streamed = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    // Only a rejected *existing* token means the session died. A 401 with no
    // token is just a failed sign-in attempt (wrong PIN/OTP), which the
    // login screens report themselves.
    if (response.statusCode == 401 && _accessToken != null) {
      _accessToken = null;
      onUnauthorized?.call();
    }
    throw ApiException(response.statusCode, response.body);
  }
}
