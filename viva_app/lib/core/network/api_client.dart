import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/constants/app_constants.dart';

/// Dio HTTP client that attaches the current Supabase access token.
/// Token refresh is handled automatically by supabase_flutter — when the
/// SDK refreshes a token it fires onAuthStateChange which updates the session
/// object we read here. No custom refresh interceptor needed.
class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout:
            const Duration(milliseconds: AppConstants.connectTimeoutMs),
        receiveTimeout:
            const Duration(milliseconds: AppConstants.receiveTimeoutMs),
        headers: {
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.addAll([
      _SupabaseAuthInterceptor(),
      LogInterceptor(requestBody: false, responseBody: false, error: true),
    ]);
  }

  Dio get dio => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _dio.get<T>(path,
          queryParameters: queryParameters, options: options);

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _dio.post<T>(path,
          data: data, queryParameters: queryParameters, options: options);

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Options? options,
  }) =>
      _dio.put<T>(path, data: data, options: options);

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Options? options,
  }) =>
      _dio.delete<T>(path, data: data, options: options);

  Future<Response<T>> postForm<T>(
    String path,
    FormData formData, {
    Options? options,
    ProgressCallback? onSendProgress,
  }) =>
      _dio.post<T>(
        path,
        data: formData,
        options: options,
        onSendProgress: onSendProgress,
      );
}

/// Injects the current Supabase access token into every request.
/// If the session is null (logged out) the request proceeds without a token
/// and the backend will return 401 — the router will catch it via auth state.
class _SupabaseAuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      options.headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    handler.next(options);
  }
}

/// Parses API errors into user-friendly messages.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException({required this.message, this.statusCode});

  factory ApiException.fromDioError(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;

    String message;
    if (data is Map<String, dynamic> && data.containsKey('detail')) {
      final detail = data['detail'];
      message = detail is String ? detail : detail.toString();
    } else {
      message = switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'Server is taking too long to respond. Please try again.',
        DioExceptionType.connectionError =>
          'No internet connection. Please check your network.',
        _ => switch (statusCode) {
          400 => 'Invalid request. Please check your input.',
          401 => 'Session expired. Please log in again.',
          403 => 'You do not have permission to do this.',
          404 => 'Not found.',
          429 => 'Too many requests. Please slow down.',
          500 || 502 || 503 =>
            'Server error. Please try again shortly.',
          _ => 'Something went wrong. Please try again.',
        },
      };
    }
    return ApiException(message: message, statusCode: statusCode);
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}

final apiClientProvider = Provider<ApiClient>((_) => ApiClient());
