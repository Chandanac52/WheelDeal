import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/api_constants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _tokenKey = 'auth_token';
  static const _secureStorage = FlutterSecureStorage();

  String? _token;

  Future<void> init() async {
    _token = await _secureStorage.read(key: _tokenKey);
  }

  Future<void> setToken(String? token) async {
    _token = token;
    if (token != null) {
      await _secureStorage.write(key: _tokenKey, value: token);
    } else {
      await _secureStorage.delete(key: _tokenKey);
    }
  }

  String? get token => _token;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('${ApiConstants.apiBase}$path').replace(queryParameters: query);
    final response = await http
        .get(uri, headers: _headers)
        .timeout(ApiConstants.requestTimeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${ApiConstants.apiBase}$path');
    final response = await http
        .post(uri, headers: _headers, body: body != null ? jsonEncode(body) : null)
        .timeout(ApiConstants.requestTimeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${ApiConstants.apiBase}$path');
    final response = await http
        .put(uri, headers: _headers, body: body != null ? jsonEncode(body) : null)
        .timeout(ApiConstants.requestTimeout);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final uri = Uri.parse('${ApiConstants.apiBase}$path');
    final response = await http
        .delete(uri, headers: _headers)
        .timeout(ApiConstants.requestTimeout);
    return _handleResponse(response);
  }

  /// Uploads one or more local image files to the backend (multipart/form-data)
  /// and returns their public URLs. Used by the Sell screen.
  ///
  /// IMPORTANT: we do NOT use `http.MultipartFile.fromPath`, because it
  /// guesses the Content-Type purely from the file's extension. Files from
  /// `image_picker` (especially camera captures, or gallery picks via the
  /// Android/iOS system photo picker) are frequently copied into a cache
  /// file with a generic or missing extension, even though the image data
  /// itself is a perfectly normal JPEG/PNG/WEBP/HEIC. When that guess fails,
  /// the part gets sent as `application/octet-stream`, which the backend
  /// correctly rejects with "Only JPG, PNG, WEBP, or HEIC images are
  /// allowed" — even though the photo is genuinely one of those formats.
  ///
  /// Instead we sniff the real format from the file's magic bytes (the
  /// first few bytes of actual image data), which is reliable regardless of
  /// what the OS happened to name the temp file.
  Future<List<String>> uploadImages(List<File> files) async {
    final uri = Uri.parse('${ApiConstants.apiBase}/upload');
    final request = http.MultipartRequest('POST', uri);
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    for (final file in files) {
      final bytes = await file.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'images',
          bytes,
          filename: file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : 'photo.jpg',
          contentType: _detectImageMediaType(bytes),
        ),
      );
    }
    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed);
    final data = _handleResponse(response);
    return (data['urls'] as List<dynamic>).map((e) => e.toString()).toList();
  }

  /// Detects the real image type from its magic bytes rather than trusting
  /// the file name/extension. Covers every type the backend accepts
  /// (JPEG, PNG, WEBP, HEIC/HEIF). Falls back to JPEG only as an absolute
  /// last resort — `image_picker` only ever returns images, so it's a safe
  /// assumption, and it's still better than sending `application/octet-stream`
  /// which the server always rejects outright.
  MediaType _detectImageMediaType(List<int> bytes) {
    // JPEG: FF D8 FF
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return MediaType('image', 'jpeg');
    }
    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return MediaType('image', 'png');
    }
    // WEBP: 'RIFF'....'WEBP'
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return MediaType('image', 'webp');
    }
    // HEIC/HEIF: ISO-BMFF container with an 'ftyp' box at byte offset 4
    if (bytes.length >= 12 &&
        bytes[4] == 0x66 &&
        bytes[5] == 0x74 &&
        bytes[6] == 0x79 &&
        bytes[7] == 0x70) {
      return MediaType('image', 'heic');
    }
    return MediaType('image', 'jpeg');
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    Map<String, dynamic>? data;
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data ?? {};
    }

    // express-validator (used by the backend's POST /vehicles, /auth, etc.)
    // returns 400s shaped as { errors: [ { msg, path, ... }, ... ] } rather
    // than { error: "..." }. Without this, every validation failure fell
    // through to the generic "Request failed (400)" fallback below, with no
    // indication of which field was actually wrong (e.g. price below the
    // ₹1000 minimum, a missing required field, etc).
    String? validationMessage;
    final errorsField = data?['errors'];
    if (errorsField is List && errorsField.isNotEmpty) {
      validationMessage = errorsField
          .map((e) {
            if (e is Map) {
              final field = (e['path'] ?? e['param'] ?? '').toString();
              final msg = (e['msg'] ?? 'is invalid').toString();
              return field.isNotEmpty ? '$field $msg' : msg;
            }
            return e.toString();
          })
          .join(', ');
    }

    final message = data?['error']?.toString() ??
        data?['message']?.toString() ??
        validationMessage ??
        'Request failed (${response.statusCode})';
    throw ApiException(message, statusCode: response.statusCode);
  }
}