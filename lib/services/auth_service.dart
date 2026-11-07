import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// Результат вызова auth-эндпоинта.
class AuthResult {
  final bool ok;
  final String? message;
  final String? token;

  const AuthResult({required this.ok, this.message, this.token});
}

class AuthService {
  /// Тот же ключ, что читает ApiService.postJson.
  static const _tokenKey = 'session_token';
  static const _emailKey = 'account_email';

  // -------------------------
  // ТОКЕН
  // -------------------------
  static Future<String?> loadToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      if (token == null || token.isEmpty) return null;
      return token;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    } catch (e) {
      debugPrint('SAVE TOKEN ERROR: $e');
    }
  }

  static Future<void> clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (e) {
      debugPrint('CLEAR TOKEN ERROR: $e');
    }
  }

  static Future<bool> isLoggedIn() async => (await loadToken()) != null;

  static Future<void> saveEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_emailKey, email.trim().toLowerCase());
    } catch (e) {
      debugPrint('SAVE EMAIL ERROR: $e');
    }
  }

  static Future<String?> loadEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_emailKey);
    } catch (_) {
      return null;
    }
  }

  // -------------------------
  // ЗАПРОСЫ
  // -------------------------
  /// Данные аккаунта: {"email": ..., "family": {...} | null}.
  /// `null` — нет токена или сервер недоступен.
  static Future<Map<String, dynamic>?> fetchMe() async {
    final res = await ApiService.getJson('/auth/me');
    if (res == null || res['status'] != 'ok') return null;
    return res;
  }

  static Future<AuthResult> register({
    required String email,
    required String password,
  }) async {
    final res = await ApiService.postJson('/auth/register', {
      'email': email.trim().toLowerCase(),
      'password': password,
    });

    if (res == null) {
      return const AuthResult(
        ok: false,
        message: 'Нет связи с сервером. Проверьте интернет.',
      );
    }

    if (res['status'] == 'ok') {
      return const AuthResult(ok: true, message: 'Код отправлен на почту');
    }

    return AuthResult(ok: false, message: _humanize(res['message']));
  }

  /// Повторная отправка кода (без смены пароля).
  static Future<AuthResult> resendCode({required String email}) async {
    final res = await ApiService.postJson('/auth/resend', {
      'email': email.trim().toLowerCase(),
    });

    if (res == null) {
      return const AuthResult(
        ok: false,
        message: 'Нет связи с сервером. Проверьте интернет.',
      );
    }

    if (res['status'] == 'ok') {
      return const AuthResult(ok: true, message: 'Код отправлен повторно');
    }

    return AuthResult(ok: false, message: _humanize(res['message']));
  }

  static Future<AuthResult> verify({
    required String email,
    required String code,
  }) async {    final res = await ApiService.postJson('/auth/verify', {
      'email': email.trim().toLowerCase(),
      'code': code.trim(),
    });

    if (res == null) {
      return const AuthResult(
        ok: false,
        message: 'Нет связи с сервером. Проверьте интернет.',
      );
    }

    if (res['status'] == 'ok') {
      final token = res['session_token']?.toString();
      if (token == null || token.isEmpty) {
        return const AuthResult(ok: false, message: 'Сервер не вернул токен');
      }
      await saveToken(token);
      await saveEmail(email);
      return AuthResult(ok: true, token: token);
    }

    return AuthResult(ok: false, message: _humanize(res['message']));
  }

  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final res = await ApiService.postJson('/auth/login', {
      'email': email.trim().toLowerCase(),
      'password': password,
    });

    if (res == null) {
      return const AuthResult(
        ok: false,
        message: 'Нет связи с сервером. Проверьте интернет.',
      );
    }

    if (res['status'] == 'ok') {
      final token = res['session_token']?.toString();
      if (token == null || token.isEmpty) {
        return const AuthResult(ok: false, message: 'Сервер не вернул токен');
      }
      await saveToken(token);
      await saveEmail(email);
      return AuthResult(ok: true, token: token);
    }

    return AuthResult(ok: false, message: _humanize(res['message']));
  }

  static Future<void> logout() async {
    final token = await loadToken();
    if (token != null && token.isNotEmpty) {
      await ApiService.postJson('/auth/logout', {'session_token': token});
    }
    await clearToken();
    await saveEmail('');
  }

  // -------------------------
  // ТЕКСТЫ ОШИБОК
  // -------------------------
  static String _humanize(Object? raw) {
    switch (raw?.toString() ?? '') {
      case 'invalid email':
        return 'Проверьте адрес почты';
      case 'password too short':
        return 'Пароль должен быть не короче 6 символов';
      case 'email already registered':
        return 'Эта почта уже зарегистрирована. Войдите в аккаунт.';
      case 'email send failed':
        return 'Не удалось отправить письмо. Попробуйте позже.';
      case 'invalid code':
        return 'Неверный код. Проверьте и попробуйте ещё раз.';
      case 'code expired':
        return 'Код истёк. Запросите новый.';
      case 'already verified':
        return 'Почта уже подтверждена. Войдите в аккаунт.';
      case 'user not found':
        return 'Аккаунт не найден. Зарегистрируйтесь.';
      case 'invalid credentials':
        return 'Неверная почта или пароль';
      case 'email not verified':
        return 'Почта не подтверждена. Завершите регистрацию.';
      default:
        return 'Что-то пошло не так. Попробуйте позже.';
    }
  }
}
