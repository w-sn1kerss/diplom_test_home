// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import '../repositories/auth_repository.dart';
import '../utils/utils.dart';

enum AuthStatus { idle, loading, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repo;

  AuthStatus _status = AuthStatus.idle;
  Profile? _profile;
  String? _error;

  AuthStatus get status => _status;
  Profile? get profile => _profile;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  dynamic get currentUser => _repo.currentUser;

  AuthProvider(this._repo) {
    _repo.authStateChanges.listen((state) async {
      if (state.session != null) {
        _status = AuthStatus.authenticated;
        await _loadProfile();
      } else {
        _status = AuthStatus.unauthenticated;
        _profile = null;
        notifyListeners();
      }
    });

    // Инициализация при запуске
    if (_repo.currentUser != null) {
      _status = AuthStatus.authenticated;
      _loadProfile();
    } else {
      _status = AuthStatus.unauthenticated;
    }
  }

  Future<void> _loadProfile() async {
    try {
      debugPrint("Попытка загрузки профиля...");
      _profile = await _repo.getProfile();
      debugPrint("Профиль загружен: ${_profile?.username ?? 'NULL'}"); // <-- ВАЖНО
    } catch (e) {
      debugPrint("ОШИБКА загрузки профиля: $e");
      _profile = null;
    }
    notifyListeners();
  }

  Future<bool> signIn({required String email, required String password}) async {
    _status = AuthStatus.loading;
    notifyListeners(); // <-- Важно!

    try {
      await _repo.signIn(email: email, password: password);
      _status = AuthStatus.authenticated; // <-- СТАВИМ СТАТУС
      await _loadProfile(); // <-- ЗАГРУЖАЕМ
      notifyListeners(); // <-- ОБЯЗАТЕЛЬНО ДЛЯ UI
      return true;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      notifyListeners(); // <-- И здесь для UI
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String username,
    String? fullName,
  }) async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();

    try {
      await _repo.signUp(
        email: email,
        password: password,
        username: username,
        fullName: fullName,
      );
      _status = AuthStatus.unauthenticated; // Ждём подтверждения email
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _error = handleError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    _profile = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _repo.resetPassword(email);
      return true;
    } catch (e) {
      _error = handleError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> uploadAvatar(XFile file) async {
    try {
      final url = await _repo.uploadAvatar(file);
      _profile = _profile?.copyWith(avatarUrl: url);
      notifyListeners();
    } catch (e) {
      _error = handleError(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateProfile({
    String? username,
    String? fullName,
    String? bio,
  }) async {
    try {
      _profile = await _repo.updateProfile(
        username: username,
        fullName: fullName,
        bio: bio,
      );
      notifyListeners();
    } catch (e) {
      _error = handleError(e);
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}