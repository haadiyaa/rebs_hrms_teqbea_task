import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../errors/app_error.dart';

/// HTTP Client wrapper handling base URLs, timeouts, headers, and typed errors.
class ApiClient {
  final http.Client _httpClient;
  final AppConfig appConfig;

  ApiClient({
    http.Client? httpClient,
    required this.appConfig,
  })  : _httpClient = httpClient ?? http.Client();

  /// Default headers sent with every request (including ngrok warning bypass).
  Map<String, String> get _defaultHeaders => {
        AppConstants.headerContentType: AppConstants.contentTypeJson,
        'Accept': AppConstants.contentTypeJson,
        AppConstants.ngrokWarningHeader: AppConstants.ngrokWarningValue,
      };

  Uri _buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    final cleanBase = appConfig.apiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$cleanBase$cleanPath';

    final uri = Uri.parse(fullUrl);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      return uri.replace(
        queryParameters: queryParameters.map(
          (key, value) => MapEntry(key, value?.toString() ?? ''),
        ),
      );
    }
    return uri;
  }

  /// Performs a GET request and decodes the JSON response.
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, queryParameters);
    try {
      final response = await _httpClient
          .get(
            uri,
            headers: {..._defaultHeaders, ...?headers},
          )
          .timeout(appConfig.requestTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      throw const TimeoutError('Request timed out. Please check your network connection.');
    } on SocketException {
      throw const NetworkError('Unable to reach server. Please check your internet connection.');
    } on http.ClientException catch (e) {
      throw NetworkError('Network connection failed: ${e.message}');
    }
  }

  /// Performs a POST request with a JSON payload and decodes the JSON response.
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path);
    try {
      final response = await _httpClient
          .post(
            uri,
            headers: {..._defaultHeaders, ...?headers},
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(appConfig.requestTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      throw const TimeoutError('Request timed out. Please check your network connection.');
    } on SocketException {
      throw const NetworkError('Unable to reach server. Please check your internet connection.');
    } on http.ClientException catch (e) {
      throw NetworkError('Network connection failed: ${e.message}');
    }
  }

  /// Parses the HTTP response and maps status codes into typed AppErrors.
  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    dynamic decodedBody;

    try {
      if (response.body.isNotEmpty) {
        decodedBody = jsonDecode(response.body);
      }
    } catch (_) {
      decodedBody = response.body;
    }

    if (statusCode >= 200 && statusCode < 300) {
      return decodedBody;
    }

    if (statusCode == 409) {
      final message = (decodedBody is Map && decodedBody['message'] != null)
          ? decodedBody['message'].toString()
          : 'Attendance conflict: Record already exists.';
      throw ConflictError(message: message);
    }

    if (statusCode == 422) {
      final message = (decodedBody is Map && decodedBody['message'] != null)
          ? decodedBody['message'].toString()
          : (decodedBody is Map && decodedBody['error'] != null)
              ? decodedBody['error'].toString()
              : 'Validation failed';

      final fieldErrors = <String, String>{};
      if (decodedBody is Map && decodedBody['fieldErrors'] is Map) {
        (decodedBody['fieldErrors'] as Map).forEach((key, value) {
          fieldErrors[key.toString()] = value.toString();
        });
      }

      // Geofence violation payload from mock server
      if (decodedBody is Map && decodedBody['distanceMeters'] != null) {
        throw LocationError(
          message: message,
          kind: LocationErrorKind.outsideGeofence,
          distanceMeters: (decodedBody['distanceMeters'] as num).toDouble(),
          allowedRadiusMeters: (decodedBody['allowedRadiusMeters'] as num?)?.toDouble() ?? 200.0,
        );
      }

      throw ValidationError(message, fieldErrors: fieldErrors);
    }

    if (statusCode >= 500) {
      final message = (decodedBody is Map && decodedBody['message'] != null)
          ? decodedBody['message'].toString()
          : 'Server error ($statusCode). Please try again later.';
      throw ServerError(statusCode: statusCode, message: message, responseBody: decodedBody);
    }

    final message = (decodedBody is Map && decodedBody['message'] != null)
        ? decodedBody['message'].toString()
        : 'Request failed with status $statusCode.';
    throw ServerError(statusCode: statusCode, message: message, responseBody: decodedBody);
  }
}
