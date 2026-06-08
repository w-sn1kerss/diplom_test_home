import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../models/profile.dart';
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
    final existing = await _client
        .from('profiles')
        .select('id')
        .eq('username', username.trim())
        .maybeSingle();

    if (existing != null) {
      throw const AppException('Имя пользователя уже занято');
    }

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

    try {
      await _client.from('profiles').upsert({
        'id': response.user!.id,
        'username': username.trim(),
        'full_name': fullName?.trim(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }

    try {
      await _client.from('user_stats').upsert({
        'user_id': response.user!.id,
        'books_read_count': 0,
        'blogs_count': 0,
        'reviews_count': 0,
        'achievements_count': 0,
        'activity_score': 0,
      });
    } catch (_) {}
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

  Future<String> uploadAvatar(XFile file) async {
    final userId = currentUserId;
    if (userId == null) throw const AppException('Не авторизован');

    final ext = file.name.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      throw const AppException('Разрешены только JPG, PNG, WebP');
    }

    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      throw const AppException('Файл слишком большой (максимум 5MB)');
    }

    final fileName = '$userId/avatar.$ext';

    await _client.storage.from('avatars').uploadBinary(
      fileName,
      bytes,
      fileOptions: FileOptions(
        contentType: 'image/$ext',
        upsert: true,
      ),
    );

    final url = _client.storage.from('avatars').getPublicUrl(fileName);

    await _client.from('profiles').update({
      'avatar_url': url,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);

    return url;
  }


  Future<Profile> updateProfile({
    String? username,
    String? fullName,
    String? bio,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw const AppException('Не авторизован');

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (username != null) updates['username'] = username.trim();
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