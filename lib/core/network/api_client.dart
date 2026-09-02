// =============================================================================
// FILE: lib/core/network/api_client.dart
// PURPOSE: Thin, dependency-free wrapper around package:http for talking to
// the MEPCO PHP/MySQL REST API. Every call:
//   - attaches "Authorization: Bearer <token>" when a token is provided
//   - encodes/decodes JSON automatically
//   - enforces a request timeout
//   - throws ApiException (never a raw http/SocketException) on failure,
//     so BLoCs only ever need to catch one exception type.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'api_exception.dart';

class ApiClient {
  final http.Client _httpClient;

  ApiClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  // ---------------------------------------------------------------------------
  Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> get(Uri uri, {String? token}) =>
      _send(() => _httpClient.get(uri, headers: _headers(token)));

  Future<Map<String, dynamic>> post(
    Uri uri, {
    Map<String, dynamic>? body,
    String? token,
  }) =>
      _send(() => _httpClient.post(
            uri,
            headers: _headers(token),
            body: body != null ? jsonEncode(body) : null,
          ));

  Future<Map<String, dynamic>> put(
    Uri uri, {
    Map<String, dynamic>? body,
    String? token,
  }) =>
      _send(() => _httpClient.put(
            uri,
            headers: _headers(token),
            body: body != null ? jsonEncode(body) : null,
          ));

  Future<Map<String, dynamic>> delete(Uri uri, {String? token}) =>
      _send(() => _httpClient.delete(uri, headers: _headers(token)));

  // ---------------------------------------------------------------------------
  // CORE REQUEST HANDLER
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    http.Response response;

    try {
      response = await request().timeout(ApiConfig.requestTimeout);
    } on TimeoutException {
      throw ApiException(
        message: 'The server took too long to respond (waited ${ApiConfig.requestTimeout.inSeconds}s). '
            'If this is a Railway free/hobby-tier deployment, it may be waking up from sleep — please try again.',
        errorCode: 'NETWORK_TIMEOUT',
      );
    } on SocketException catch (e) {
      throw ApiException(
        message: 'Could not reach the server (${e.osError?.message ?? e.message}). '
            'Check that ApiConfig.baseUrl is correct and the device has internet access.',
        errorCode: 'NETWORK_UNREACHABLE',
      );
    } on HandshakeException catch (e) {
      throw ApiException(
        message: 'A secure connection (HTTPS/TLS) could not be established: ${e.message}',
        errorCode: 'NETWORK_TLS_ERROR',
      );
    } on HttpException catch (e) {
      throw ApiException(
        message: 'Could not reach the server: ${e.message}',
        errorCode: 'NETWORK_HTTP_ERROR',
      );
    } on FormatException catch (e) {
      throw ApiException(
        message: 'Invalid request URL (${e.message}). Check ApiConfig.baseUrl.',
        errorCode: 'NETWORK_BAD_URL',
      );
    } catch (e) {
      // Anything else transport-level (e.g. http.ClientException) — surface
      // the real error instead of guessing, so it's actually diagnosable.
      throw ApiException(
        message: 'Network request failed: $e',
        errorCode: 'NETWORK_UNKNOWN_ERROR',
      );
    }

    Map<String, dynamic> decoded;
    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw ApiException(
        message: 'The server returned an unexpected response (HTTP ${response.statusCode}).',
        errorCode: 'MALFORMED_RESPONSE',
        statusCode: response.statusCode,
      );
    }

    final bool success = decoded['success'] == true;

    if (!success || response.statusCode >= 400) {
      throw ApiException(
        message: (decoded['message'] as String?) ?? 'Something went wrong. Please try again.',
        errorCode: decoded['error_code'] as String?,
        statusCode: response.statusCode,
        fieldErrors: decoded['errors'] is Map<String, dynamic> ? decoded['errors'] as Map<String, dynamic> : null,
      );
    }

    return decoded;
  }

  void close() => _httpClient.close();
}
