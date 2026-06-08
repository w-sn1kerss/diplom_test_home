import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../utils/utils.dart';

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository(this._client);

  String? get _userId => _client.auth.currentUser?.id;

  // ---- ÐŸÐ¾Ð»ÑƒÑ‡Ð¸Ñ‚ÑŒ Ð¿Ñ€Ð¾Ñ„Ð¸Ð»ÑŒ ----
  Future<Profile?> getProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return data != null ? Profile.fromJson(data) : null;
  }

  // ---- Ð¡Ñ‚Ð°Ñ‚Ð¸ÑÑ‚Ð¸ÐºÐ° Ð¿Ð¾Ð»ÑŒÐ·Ð¾Ð²Ð°Ñ‚ÐµÐ»Ñ ----
  Future<UserStats?> getUserStats(String userId) async {
    final data = await _client
        .from('user_stats')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return data != null ? UserStats.fromJson(data) : null;
  }

  // ---- Ð”Ð¾ÑÑ‚Ð¸Ð¶ÐµÐ½Ð¸Ñ ----
  Future<List<Achievement>> getUserAchievements(String userId) async {
    final data = await _client.from('user_achievements').select('''
          earned_at,
          achievements (
            id, title, description, icon_url, requirement_code
          )
        ''').eq('user_id', userId).order('earned_at', ascending: false);

    return (data as List).map((e) {
      final ach = Map<String, dynamic>.from(
          e['achievements'] as Map<String, dynamic>);
      ach['earned_at'] = e['earned_at'];
      return Achievement.fromJson(ach);
    }).toList();
  }

  // ---- ÐŸÐ¾Ð´Ð¿Ð¸ÑÐºÐ¸ ----
  Future<void> follow(String targetId) async {
    if (_userId == null) throw const AppException('ÐÐµ Ð°Ð²Ñ‚Ð¾Ñ€Ð¸Ð·Ð¾Ð²Ð°Ð½');
    if (_userId == targetId) throw const AppException('ÐÐµÐ»ÑŒÐ·Ñ Ð¿Ð¾Ð´Ð¿Ð¸ÑÐ°Ñ‚ÑŒÑÑ Ð½Ð° ÑÐµÐ±Ñ');

    await _client.from('user_follows').upsert({
      'follower_id': _userId,
      'following_id': targetId,
    });
  }

  Future<void> unfollow(String targetId) async {
    if (_userId == null) throw const AppException('ÐÐµ Ð°Ð²Ñ‚Ð¾Ñ€Ð¸Ð·Ð¾Ð²Ð°Ð½');
    await _client
        .from('user_follows')
        .delete()
        .eq('follower_id', _userId!)
        .eq('following_id', targetId);
  }

  Future<bool> isFollowing(String targetId) async {
    if (_userId == null) return false;
    final data = await _client
        .from('user_follows')
        .select('follower_id')
        .eq('follower_id', _userId!)
        .eq('following_id', targetId)
        .maybeSingle();
    return data != null;
  }

  Future<int> getFollowersCount(String userId) async {
    final data = await _client
        .from('user_follows')
        .select('follower_id')
        .eq('following_id', userId);
    return (data as List).length;
  }

  Future<int> getFollowingCount(String userId) async {
    final data = await _client
        .from('user_follows')
        .select('following_id')
        .eq('follower_id', userId);
    return (data as List).length;
  }

  // ---- ÐŸÐ¾Ð¸ÑÐº Ð¿Ð¾Ð»ÑŒÐ·Ð¾Ð²Ð°Ñ‚ÐµÐ»ÐµÐ¹ ----
  Future<List<Profile>> searchProfiles(String query) async {
    if (query.trim().isEmpty) return [];
    final data = await _client
        .from('profiles')
        .select('id, username, full_name, avatar_url, created_at')
        .or('username.ilike.%${query.trim()}%,full_name.ilike.%${query.trim()}%')
        .limit(20);
    return (data as List).map((e) => Profile.fromJson(e)).toList();
  }
}