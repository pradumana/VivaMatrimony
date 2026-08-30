import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../shared/constants/app_constants.dart';

/// Dio HTTP client with JWT interceptor and error handling.
class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage;
  late final _AuthInterceptor _authInterceptor;

  ApiClient({FlutterSecureStorage? storage, void Function()? onForceLogout})
      : _storage = storage ?? const FlutterSecureStorage() {
    _authInterceptor = _AuthInterceptor(_storage, onForceLogout: onForceLogout);
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(milliseconds: AppConstants.connectTimeoutMs),
        receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeoutMs),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.addAll([
      _authInterceptor,
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        error: true,
      ),
    ]);
    // Wire the Dio instance into the interceptor after construction.
    _authInterceptor._dio = _dio;
  }

  // Allows wiring a force-logout callback after construction (used by authProvider).
  set onForceLogout(void Function() cb) => _authInterceptor._onForceLogout = cb;

  Dio get dio => _dio;

  // ── Convenience methods ──────────────────────────────────────────────────

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _dio.get<T>(path, queryParameters: queryParameters, options: options);

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _dio.post<T>(path, data: data, queryParameters: queryParameters, options: options);

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

class _AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  late Dio _dio;
  void Function()? _onForceLogout;
  bool _isRefreshing = false;
  // Pending completers waiting for the in-flight refresh to finish.
  final List<({RequestOptions options, ErrorInterceptorHandler handler})>
      _pendingRequests = [];

  _AuthInterceptor(this._storage, {void Function()? onForceLogout})
      : _onForceLogout = onForceLogout;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: AppConstants.accessTokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    // If already refreshing, queue this request and wait.
    if (_isRefreshing) {
      _pendingRequests.add((options: err.requestOptions, handler: handler));
      return;
    }

    _isRefreshing = true;
    try {
      final refreshToken = await _storage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken == null) {
        _isRefreshing = false;
        _failPending(err);
        return handler.next(err);
      }

      final refreshResponse = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final newAccessToken = refreshResponse.data['access_token'] as String;
      final newRefreshToken = refreshResponse.data['refresh_token'] as String;

      await _storage.write(key: AppConstants.accessTokenKey, value: newAccessToken);
      await _storage.write(key: AppConstants.refreshTokenKey, value: newRefreshToken);

      // Retry the original request.
      err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
      final retryResponse = await _dio.fetch(err.requestOptions);
      _isRefreshing = false;
      // Resolve all queued requests with the new token.
      await _retryPending(newAccessToken);
      return handler.resolve(retryResponse);
    } catch (_) {
      _isRefreshing = false;
      // Refresh failed — clear only tokens (not onboarding flag) and force logout.
      await Future.wait([
        _storage.delete(key: AppConstants.accessTokenKey),
        _storage.delete(key: AppConstants.refreshTokenKey),
        _storage.delete(key: AppConstants.userIdKey),
      ]);
      _failPending(err);
      _onForceLogout?.call();
      return handler.next(err);
    }
  }

  Future<void> _retryPending(String newToken) async {
    final pending = List.of(_pendingRequests);
    _pendingRequests.clear();
    for (final p in pending) {
      try {
        p.options.headers['Authorization'] = 'Bearer $newToken';
        final response = await _dio.fetch(p.options);
        p.handler.resolve(response);
      } catch (e) {
        p.handler.next(e is DioException ? e : DioException(requestOptions: p.options));
      }
    }
  }

  void _failPending(DioException err) {
    final pending = List.of(_pendingRequests);
    _pendingRequests.clear();
    for (final p in pending) {
      p.handler.next(DioException(
        requestOptions: p.options,
        response: err.response,
        type: err.type,
        error: err.error,
      ));
    }
  }
}

/// Parses API errors into user-friendly messages.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  const ApiException({
    required this.message,
    this.statusCode,
    this.code,
  });

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
          500 || 502 || 503 => 'Server error. Please try again shortly.',
          _ => 'Something went wrong. Please try again.',
        }
      };
    }

    return ApiException(message: message, statusCode: statusCode);
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}

// ── Riverpod providers ──────────────────────────────────────────────────────

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
