import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../repositories/auth_repository.dart';
import '../repositories/profile_repository.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepo;
  ProfileRepository? _profileRepo;

  AuthStatus _status = AuthStatus.initial;
  String? _error;
  Profile? _profile;
  UserStats? _stats;

  AuthStatus get status => _status;
  String? get error => _error;
  Profile? get profile => _profile;
  UserStats? get stats => _stats;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get userId => _authRepo.currentUserId;

  AuthProvider(this._authRepo) {
    _authRepo.authStateChanges.listen(_handleAuthStateChange);
  }

  void setProfileRepository(ProfileRepository repo) {
    _profileRepo = repo;
  }

  void _handleAuthStateChange(AuthState state) async {
    switch (state.event) {
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.tokenRefreshed:
        _status = AuthStatus.authenticated;
        notifyListeners();
        await _loadCurrentProfile();
        break;
      case AuthChangeEvent.signedOut:
      case AuthChangeEvent.userDeleted:
        _status = AuthStatus.unauthenticated;
        _profile = null;
        _stats = null;
        notifyListeners();
        break;
      case AuthChangeEvent.passwordRecovery:
        break;
      default:
        break;
    }
  }

  Future<void> _loadCurrentProfile() async {
    final userId = _authRepo.currentUserId;
    if (userId == null || _profileRepo == null) return;
    try {
      final result = await Future.wait([
        _profileRepo!.getProfile(userId),
        _profileRepo!.getUserStats(userId),
      ]);
      _profile = result[0] as Profile?;
      _stats = result[1] as UserStats?;
      notifyListeners();
    } catch (_) {}
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
      await _authRepo.signUp(
        email: email,
        password: password,
        username: username,
        fullName: fullName,
      );
      return true;
    } catch (e) {
      _error = handleError(e);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _error = null;
    notifyListeners();
    try {
      await _authRepo.signIn(email: email, password: password);
      return true;
    } catch (e) {
      _error = handleError(e);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _authRepo.signOut();
    } catch (e) {
      _error = handleError(e);
      notifyListeners();
    }
  }

  Future<bool> resetPassword(String email) async {
    _error = null;
    try {
      await _authRepo.resetPassword(email);
      return true;
    } catch (e) {
      _error = handleError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({
    String? username,
    String? fullName,
    String? bio,
  }) async {
    _error = null;
    try {
      _profile = await _authRepo.updateProfile(
        username: username,
        fullName: fullName,
        bio: bio,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = handleError(e);
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}