// lib/repositories/profile_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../utils/utils.dart';

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository(this._client);

  String? get _userId => _client.auth.currentUser?.id;

  Future<Profile?> getProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return data != null ? Profile.fromJson(data) : null;
  }

  Future<UserStats?> getUserStats(String userId) async {
    final data = await _client
        .from('user_stats')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return data != null ? UserStats.fromJson(data) : null;
  }

  Future<List<Achievement>> getUserAchievements(String userId) async {
    final data = await _client
        .from('user_achievements')
        .select('''
          earned_at,
          achievements (
            id, title, description, icon_url, requirement_code
          )
        ''')
        .eq('user_id', userId)
        .order('earned_at', ascending: false);

    return (data as List).map((e) {
      final ach = e['achievements'] as Map<String, dynamic>;
      return Achievement.fromJson({
        ...ach,
        'earned_at': e['earned_at'],
      });
    }).toList();
  }

  Future<bool> isFollowing(String targetId) async {
    if (_userId == null || _userId == targetId) return false;
    final data = await _client
        .from('user_follows')
        .select('id')
        .eq('follower_id', _userId!)
        .eq('following_id', targetId)
        .maybeSingle();
    return data != null;
  }

  Future<int> getFollowersCount(String userId) async {
    final data = await _client
        .from('user_follows')
        .select('id')
        .eq('following_id', userId);
    return (data as List).length;
  }

  Future<int> getFollowingCount(String userId) async {
    final data = await _client
        .from('user_follows')
        .select('id')
        .eq('follower_id', userId);
    return (data as List).length;
  }

  Future<void> follow(String targetId) async {
    if (_userId == null) throw const AppException('Не авторизован');
    await _client.from('user_follows').upsert({
      'follower_id': _userId,
      'following_id': targetId,
    });
  }

  Future<void> unfollow(String targetId) async {
    if (_userId == null) throw const AppException('Не авторизован');
    await _client
        .from('user_follows')
        .delete()
        .eq('follower_id', _userId!)
        .eq('following_id', targetId);
  }
}