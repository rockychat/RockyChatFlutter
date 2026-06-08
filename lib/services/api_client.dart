import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config.dart';

class ApiClient {
  String? _token;

  static const int maxRetries = 2;
  static const Duration retryBaseDelay = Duration(milliseconds: 500);
  static const Duration defaultTimeout = Duration(seconds: 30);

  void setToken(String? token) => _token = token;
  String? get token => _token;

  Map<String, String> _headers({bool json = true}) {
    final h = <String, String>{};
    if (json) h['Content-Type'] = 'application/json';
    if (_token != null) h['Authorization'] = 'Bearer $_token';
    return h;
  }

  Future<ApiResult> request(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? data,
    Duration timeout = defaultTimeout,
    CancelToken? cancelToken,
  }) async {
    final url = Uri.parse('${AppConfig.apiBase}$endpoint');

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await _sendRequest(
          url, method, data, timeout, cancelToken,
        );
        if (response.statusCode >= 500 && attempt < maxRetries) {
          await Future.delayed(retryBaseDelay * (1 << attempt));
          continue;
        }
        if (response.statusCode == 204) {
          return ApiResult(success: true, data: {});
        }
        final body = response.body;
        Map<String, dynamic> result;
        try {
          result = jsonDecode(body) as Map<String, dynamic>;
        } catch (_) {
          return ApiResult(
            success: false,
            message: 'Invalid JSON response: ${response.statusCode}',
          );
        }
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return ApiResult(success: true, data: result['data'] ?? result);
        } else {
          return ApiResult(
            success: false,
            message: result['message'] as String? ?? 'Request failed',
          );
        }
      } on TimeoutException {
        if (attempt < maxRetries) {
          await Future.delayed(retryBaseDelay * (1 << attempt));
          continue;
        }
        return ApiResult(success: false, message: 'Request timed out');
      } on http.ClientException {
        if (attempt < maxRetries) {
          await Future.delayed(retryBaseDelay * (1 << attempt));
          continue;
        }
        return ApiResult(success: false, message: 'Network error');
      } catch (_) {
        if (attempt < maxRetries) {
          await Future.delayed(retryBaseDelay * (1 << attempt));
          continue;
        }
        return ApiResult(success: false, message: 'Network error');
      }
    }
    return ApiResult(success: false, message: 'Max retries exceeded');
  }

  Future<http.Response> _sendRequest(
    Uri url,
    String method,
    Map<String, dynamic>? data,
    Duration timeout,
    CancelToken? cancelToken,
  ) async {
    final headers = _headers();
    final body = data != null ? jsonEncode(data) : null;
    late Future<http.Response> future;

    switch (method) {
      case 'POST':
        future = http.post(url, headers: headers, body: body);
        break;
      case 'PUT':
        future = http.put(url, headers: headers, body: body);
        break;
      case 'DELETE':
        future = http.delete(url, headers: headers, body: body);
        break;
      default:
        future = http.get(url, headers: headers);
    }
    return future.timeout(timeout);
  }

  Future<ApiResult> uploadFile(
    String endpoint, {
    required File file,
    String fileField = 'file',
    Map<String, String>? fields,
    Duration timeout = defaultTimeout,
  }) async {
    final url = Uri.parse('${AppConfig.apiBase}$endpoint');
    try {
      final req = http.MultipartRequest('POST', url);
      req.headers.addAll(_headers(json: false));
      final ext = file.path.split('.').last.toLowerCase();
      final mimeType = _mimeType(ext);
      req.files.add(await http.MultipartFile.fromPath(
        fileField,
        file.path,
        contentType: mimeType,
      ));
      if (fields != null) {
        req.fields.addAll(fields);
      }
      final streamed = await req.send().timeout(timeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 204) {
        return ApiResult(success: true, data: {});
      }
      final result = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResult(success: true, data: result['data'] ?? result);
      } else {
        return ApiResult(
          success: false,
          message: result['message'] as String? ?? 'Upload failed',
        );
      }
    } on TimeoutException {
      return ApiResult(success: false, message: 'Upload timed out');
    } catch (_) {
      return ApiResult(success: false, message: 'Network error');
    }
  }

  MediaType _mimeType(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'webp':
        return MediaType('image', 'webp');
      case 'mp4':
        return MediaType('video', 'mp4');
      case 'mov':
        return MediaType('video', 'quicktime');
      case 'avi':
        return MediaType('video', 'x-msvideo');
      case 'mkv':
        return MediaType('video', 'x-matroska');
      case 'webm':
        return MediaType('video', 'webm');
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'doc':
        return MediaType('application', 'msword');
      case 'docx':
        return MediaType('application',
            'vnd.openxmlformats-officedocument.wordprocessingml.document');
      case 'xls':
        return MediaType('application', 'vnd.ms-excel');
      case 'xlsx':
        return MediaType('application',
            'vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      case 'zip':
        return MediaType('application', 'zip');
      case 'txt':
        return MediaType('text', 'plain');
      default:
        return MediaType('application', 'octet-stream');
    }
  }
}

class CancelToken {
  bool isCancelled = false;
  void cancel() => isCancelled = true;
}

class ApiResult {
  final bool success;
  final dynamic data;
  final String? message;
  ApiResult({required this.success, this.data, this.message});
}
