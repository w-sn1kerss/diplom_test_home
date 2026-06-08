// lib/utils/utils.dart

/// Кастомное исключение приложения с человекочитаемым сообщением.
class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

/// Валидаторы для форм.
class Validators {
  Validators._();

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Введите email';
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value.trim())) return 'Неверный формат email';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Введите пароль';
    if (value.length < 6) return 'Минимум 6 символов';
    return null;
  }

  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) return 'Введите имя пользователя';
    if (value.trim().length < 3) return 'Минимум 3 символа';
    final regex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!regex.hasMatch(value.trim())) {
      return 'Только латиница, цифры и _';
    }
    return null;
  }

  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Поле обязательно';
    return null;
  }
}

/// Превращает любое исключение в читаемую строку.
String handleError(Object e) {
  if (e is AppException) return e.message;
  final s = e.toString();

  if (s.contains('Invalid login credentials')) return 'Неверный email или пароль';
  if (s.contains('Email not confirmed')) return 'Подтвердите email';
  if (s.contains('User already registered')) return 'Email уже зарегистрирован';
  if (s.contains('network')) return 'Проблема с сетью';
  if (s.contains('JWT')) return 'Сессия устарела, войдите снова';

  // ИСПРАВЛЕНИЕ: Вместо того чтобы скрывать ошибку, возвращаем её суть
  return s.replaceAll('Exception: ', '').replaceAll('PostgrestException: ', '');
}