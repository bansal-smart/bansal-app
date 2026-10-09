import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sealed hierarchy of all errors the app can encounter.
/// Every exception maps to exactly one [userMessage] shown in the UI.
sealed class AppException implements Exception {
  const AppException();

  String get userMessage;
  String get technicalMessage;

  /// Converts any raw exception from a repository into an [AppException].
  static AppException from(Object error) {
    if (error is AppException) return error;

    final msg = error.toString().toLowerCase();

    // Network / socket
    if (error is SocketException ||
        msg.contains('socket') ||
        msg.contains('network')) {
      return const NetworkException();
    }

    // Timeout
    if (error is TimeoutException ||
        msg.contains('timeout') ||
        msg.contains('timed out') ||
        msg.contains('deadline')) {
      return const TimeoutException();
    }

    // Supabase auth errors
    if (error is AuthException) {
      final code = error.statusCode ?? '';
      if (code == '400' && msg.contains('invalid')) {
        return AuthAppException(error.message);
      }
      if (code == '422') return AuthAppException(error.message);
      if (code == '429') return const RateLimitException();
      return AuthAppException(error.message);
    }

    // Supabase postgrest / storage errors
    if (error is PostgrestException) {
      final code = int.tryParse(error.code ?? '') ?? 0;
      if (code == 0 || msg.contains('connection'))
        return const NetworkException();
      if (code >= 500) return const ServerException();
      if (code == 404) return const NotFoundException();
      return ServerException(error.message);
    }

    // HTTP 4xx / 5xx in message
    if (msg.contains('500') || msg.contains('502') || msg.contains('503')) {
      return const ServerException();
    }
    if (msg.contains('401') ||
        msg.contains('403') ||
        msg.contains('unauthorized')) {
      return const UnauthorizedException();
    }
    if (msg.contains('404')) return const NotFoundException();

    // Generic connectivity hints
    if (msg.contains('no internet') ||
        msg.contains('connection refused') ||
        msg.contains('host lookup failed') ||
        msg.contains('failed to connect')) {
      return const NetworkException();
    }

    return UnknownException(error.toString());
  }
}

// ── Concrete types ─────────────────────────────────────────────────────────────

class NetworkException extends AppException {
  const NetworkException();
  @override
  String get userMessage =>
      'No internet connection.\nPlease check your network and try again.';
  @override
  String get technicalMessage => 'NetworkException: no connectivity';
}

class TimeoutException extends AppException {
  const TimeoutException();
  @override
  String get userMessage =>
      'Request timed out.\nYour connection may be slow — please try again.';
  @override
  String get technicalMessage => 'TimeoutException: request exceeded limit';
}

class ServerException extends AppException {
  final String? detail;
  const ServerException([this.detail]);
  @override
  String get userMessage =>
      'Something went wrong on our end.\nPlease try again later.';
  @override
  String get technicalMessage =>
      'ServerException: ${detail ?? 'unknown server error'}';
}

class UnauthorizedException extends AppException {
  const UnauthorizedException();
  @override
  String get userMessage => 'Your session has expired.\nPlease log in again.';
  @override
  String get technicalMessage => 'UnauthorizedException: 401/403';
}

class NotFoundException extends AppException {
  const NotFoundException();
  @override
  String get userMessage => 'The requested content was not found.';
  @override
  String get technicalMessage => 'NotFoundException: 404';
}

class AuthAppException extends AppException {
  final String _raw;
  const AuthAppException(this._raw);
  @override
  String get userMessage {
    final m = _raw.toLowerCase();
    if (m.contains('invalid login') || m.contains('invalid credentials')) {
      return 'Incorrect email or password.\nPlease try again.';
    }
    if (m.contains('email not confirmed')) {
      return 'Please verify your email before logging in.';
    }
    if (m.contains('user already registered') ||
        m.contains('already been registered')) {
      return 'An account with this email already exists.';
    }
    if (m.contains('password'))
      return 'Password must be at least 6 characters.';
    return 'Authentication failed. Please try again.';
  }

  @override
  String get technicalMessage => 'AuthException: $_raw';
}

class RateLimitException extends AppException {
  const RateLimitException();
  @override
  String get userMessage =>
      'Too many attempts. Please wait a moment and try again.';
  @override
  String get technicalMessage => 'RateLimitException: 429';
}

class UnknownException extends AppException {
  final String _raw;
  const UnknownException(this._raw);
  @override
  String get userMessage => 'Something went wrong.\nPlease try again.';
  @override
  String get technicalMessage => 'UnknownException: $_raw';
}
