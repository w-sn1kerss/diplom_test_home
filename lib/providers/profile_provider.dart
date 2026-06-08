// lib/providers/profile_provider.dart
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../repositories/profile_repository.dart';
import '../utils/utils.dart';

class ProfileProvider extends ChangeNotifier {
  final ProfileRepository _repo;

  Profile? _viewedProfile;
  UserStats? _viewedStats;
  List<Achievement> _achievements = [];
  bool _loading = false;
  bool _isFollowing = false;
  int _followersCount = 0;
  int _followingCount = 0;
  String? _error;

  Profile? get viewedProfile => _viewedProfile;
  UserStats? get viewedStats => _viewedStats;
  List<Achievement> get achievements => _achievements;
  bool get loading => _loading;
  bool get isFollowing => _isFollowing;
  int get followersCount => _followersCount;
  int get followingCount => _followingCount;
  String? get error => _error;

  ProfileProvider(this._repo);

  Future<void> loadProfile(String userId) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repo.getProfile(userId),
        _repo.getUserStats(userId),
        _repo.getUserAchievements(userId),
        _repo.isFollowing(userId),
        _repo.getFollowersCount(userId),
        _repo.getFollowingCount(userId),
      ]);

      _viewedProfile = results[0] as Profile?;
      _viewedStats = results[1] as UserStats?;
      _achievements = results[2] as List<Achievement>;
      _isFollowing = results[3] as bool;
      _followersCount = results[4] as int;
      _followingCount = results[5] as int;
    } catch (e) {
      _error = handleError(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFollow(String targetId) async {
    final wasFollowing = _isFollowing;
    // Оптимистичное обновление
    _isFollowing = !wasFollowing;
    _followersCount += wasFollowing ? -1 : 1;
    notifyListeners();

    try {
      if (wasFollowing) {
        await _repo.unfollow(targetId);
      } else {
        await _repo.follow(targetId);
      }
    } catch (e) {
      // Откат
      _isFollowing = wasFollowing;
      _followersCount += wasFollowing ? 1 : -1;
      _error = handleError(e);
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}