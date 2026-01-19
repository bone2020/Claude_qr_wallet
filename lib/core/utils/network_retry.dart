import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Configuration for retry behavior
class RetryConfig {
  /// Maximum number of retry attempts
  final int maxRetries;

  /// Initial delay before first retry (in milliseconds)
  final int initialDelayMs;

  /// Maximum delay between retries (in milliseconds)
  final int maxDelayMs;

  /// Multiplier for exponential backoff
  final double backoffMultiplier;

  const RetryConfig({
    this.maxRetries = 3,
    this.initialDelayMs = 1000,
    this.maxDelayMs = 10000,
    this.backoffMultiplier = 2.0,
  });

  /// Default configuration for network operations
  static const network = RetryConfig(
    maxRetries: 3,
    initialDelayMs: 1000,
    maxDelayMs: 8000,
    backoffMultiplier: 2.0,
  );

  /// Quick retry for lightweight operations
  static const quick = RetryConfig(
    maxRetries: 2,
    initialDelayMs: 500,
    maxDelayMs: 2000,
    backoffMultiplier: 2.0,
  );

  /// Extended retry for critical operations like payments
  static const extended = RetryConfig(
    maxRetries: 5,
    initialDelayMs: 1000,
    maxDelayMs: 16000,
    backoffMultiplier: 2.0,
  );
}

/// Utility class for handling network retries with exponential backoff
class NetworkRetry {
  NetworkRetry._();

  /// Execute an async operation with retry logic
  ///
  /// [operation] - The async operation to execute
  /// [config] - Retry configuration (defaults to network config)
  /// [shouldRetry] - Optional callback to determine if error is retryable
  /// [onRetry] - Optional callback called before each retry attempt
  static Future<T> execute<T>(
    Future<T> Function() operation, {
    RetryConfig config = RetryConfig.network,
    bool Function(Object error)? shouldRetry,
    void Function(int attempt, Duration delay, Object error)? onRetry,
  }) async {
    int attempt = 0;
    int delayMs = config.initialDelayMs;

    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempt++;

        // Check if we've exhausted retries
        if (attempt >= config.maxRetries) {
          debugPrint('NetworkRetry: Max retries ($attempt) reached, throwing error');
          rethrow;
        }

        // Check if error is retryable
        final isRetryable = shouldRetry?.call(e) ?? _isRetryableError(e);
        if (!isRetryable) {
          debugPrint('NetworkRetry: Non-retryable error, throwing immediately');
          rethrow;
        }

        // Calculate delay with exponential backoff
        final delay = Duration(milliseconds: delayMs);
        debugPrint('NetworkRetry: Attempt $attempt failed, retrying in ${delay.inMilliseconds}ms');

        // Notify listener if provided
        onRetry?.call(attempt, delay, e);

        // Wait before retrying
        await Future.delayed(delay);

        // Calculate next delay with exponential backoff, capped at maxDelay
        delayMs = (delayMs * config.backoffMultiplier).round();
        if (delayMs > config.maxDelayMs) {
          delayMs = config.maxDelayMs;
        }
      }
    }
  }

  /// Execute an operation with retry, returning a result instead of throwing
  ///
  /// Returns a [RetryResult] with either success value or final error
  static Future<RetryResult<T>> executeWithResult<T>(
    Future<T> Function() operation, {
    RetryConfig config = RetryConfig.network,
    bool Function(Object error)? shouldRetry,
    void Function(int attempt, Duration delay, Object error)? onRetry,
  }) async {
    try {
      final result = await execute(
        operation,
        config: config,
        shouldRetry: shouldRetry,
        onRetry: onRetry,
      );
      return RetryResult.success(result);
    } catch (e) {
      return RetryResult.failure(e);
    }
  }

  /// Check if an error is retryable (network-related)
  static bool _isRetryableError(Object error) {
    final errorString = error.toString().toLowerCase();

    // Socket/network exceptions
    if (error is SocketException) return true;
    if (error is TimeoutException) return true;

    // Common network error patterns
    if (errorString.contains('socketexception')) return true;
    if (errorString.contains('connection reset')) return true;
    if (errorString.contains('connection refused')) return true;
    if (errorString.contains('connection closed')) return true;
    if (errorString.contains('connection timed out')) return true;
    if (errorString.contains('network unreachable')) return true;
    if (errorString.contains('host lookup failed')) return true;
    if (errorString.contains('failed host lookup')) return true;
    if (errorString.contains('no internet')) return true;
    if (errorString.contains('network is unreachable')) return true;

    // Server errors that might be transient
    if (errorString.contains('503')) return true; // Service unavailable
    if (errorString.contains('502')) return true; // Bad gateway
    if (errorString.contains('504')) return true; // Gateway timeout
    if (errorString.contains('429')) return true; // Too many requests

    // Firebase-specific retryable errors
    if (errorString.contains('unavailable')) return true;
    if (errorString.contains('deadline-exceeded')) return true;
    if (errorString.contains('resource-exhausted')) return true;

    return false;
  }

  /// Helper to check if error looks like a network error (for UI purposes)
  static bool isNetworkError(Object error) {
    return _isRetryableError(error);
  }
}

/// Result wrapper for retry operations
class RetryResult<T> {
  final bool success;
  final T? value;
  final Object? error;

  RetryResult._({
    required this.success,
    this.value,
    this.error,
  });

  factory RetryResult.success(T value) {
    return RetryResult._(success: true, value: value);
  }

  factory RetryResult.failure(Object error) {
    return RetryResult._(success: false, error: error);
  }

  /// Execute callback if success
  void ifSuccess(void Function(T value) callback) {
    if (success && value != null) {
      callback(value as T);
    }
  }

  /// Execute callback if failure
  void ifFailure(void Function(Object error) callback) {
    if (!success && error != null) {
      callback(error!);
    }
  }

  /// Map the result value
  RetryResult<R> map<R>(R Function(T value) mapper) {
    if (success && value != null) {
      return RetryResult.success(mapper(value as T));
    }
    return RetryResult.failure(error!);
  }
}

/// Extension methods for Future to add retry capability
extension RetryExtension<T> on Future<T> Function() {
  /// Execute this operation with retry logic
  Future<T> withRetry({
    RetryConfig config = RetryConfig.network,
    bool Function(Object error)? shouldRetry,
    void Function(int attempt, Duration delay, Object error)? onRetry,
  }) {
    return NetworkRetry.execute(
      this,
      config: config,
      shouldRetry: shouldRetry,
      onRetry: onRetry,
    );
  }

  /// Execute this operation with retry, returning a result
  Future<RetryResult<T>> withRetryResult({
    RetryConfig config = RetryConfig.network,
    bool Function(Object error)? shouldRetry,
    void Function(int attempt, Duration delay, Object error)? onRetry,
  }) {
    return NetworkRetry.executeWithResult(
      this,
      config: config,
      shouldRetry: shouldRetry,
      onRetry: onRetry,
    );
  }
}
