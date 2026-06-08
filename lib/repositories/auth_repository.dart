// lib/repositories/auth_repository.dart
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../utils/utils.dart';

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  User? get currentUser => _client.auth.currentUser;
  String? get currentUserId => _client.auth.currentUser?.id;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signUp({
    required String email,
    required String password,
    required String username,
    String? fullName,
  }) async {
    // 1. Пытаемся создать пользователя
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'username': username.trim(),
        'full_name': fullName?.trim(),
      },
    );

    if (response.user == null) {
      throw const AppException('Не удалось создать аккаунт');
    }

    // 2. ВАЖНО: Мы не делаем upsert в profiles здесь,
    // если у вас настроен триггер (Database Trigger), который делает это автоматически.
    // Если триггера нет, тогда оставьте upsert, но проверьте RLS политики (INSERT).
  }

  Future<String> uploadAvatar(XFile file) async {
    final userId = currentUserId;
    if (userId == null) throw const AppException('Не авторизован');

    final ext = file.name.split('.').last.toLowerCase();
    final bytes = await file.readAsBytes();

    // ВАЖНО: Используем путь, а не URL для хранения в БД
    final fileName = '$userId/avatar.$ext';

    await _client.storage.from('avatars').uploadBinary(
      fileName,
      bytes,
      fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
    );

    // В БД сохраняем только ПУТЬ к файлу, а не полный URL
    await _client.from('profiles').update({
      'avatar_url': fileName,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);

    return fileName;
  }

  Future<Profile?> getProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;

    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    return data != null ? Profile.fromJson(data) : null;
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }



  Future<Profile> updateProfile({
    String? username,
    String? fullName,
    String? bio,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw const AppException('Не авторизован');

    if (username != null && username.trim().isNotEmpty) {
      final existing = await _client
          .from('profiles')
          .select('id')
          .eq('username', username.trim())
          .neq('id', userId)
          .maybeSingle();
      if (existing != null) {
        throw const AppException('Имя пользователя уже занято');
      }
    }

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (username != null && username.trim().isNotEmpty) {
      updates['username'] = username.trim();
    }
    if (fullName != null) updates['full_name'] = fullName.trim();
    if (bio != null) updates['bio'] = bio.trim();

    final data = await _client
        .from('profiles')
        .update(updates)
        .eq('id', userId)
        .select()
        .single();

    return Profile.fromJson(data);
  }
}