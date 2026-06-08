class UserStats {
  final String userId;
  final int booksReadCount;
  final int blogsCount;
  final int reviewsCount;
  final int achievementsCount;
  final int activityScore;

  const UserStats({
    required this.userId,
    required this.booksReadCount,
    required this.blogsCount,
    required this.reviewsCount,
    required this.achievementsCount,
    required this.activityScore,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
    userId: json['user_id'] as String,
    booksReadCount: (json['books_read_count'] as int?) ?? 0,
    blogsCount: (json['blogs_count'] as int?) ?? 0,
    reviewsCount: (json['reviews_count'] as int?) ?? 0,
    achievementsCount: (json['achievements_count'] as int?) ?? 0,
    activityScore: (json['activity_score'] as int?) ?? 0,
  );
}