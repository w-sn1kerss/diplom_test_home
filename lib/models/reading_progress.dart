class ReadingProgress {
  final String userId;
  final String bookId;
  final int progressPercent;
  final DateTime lastViewedAt;

  const ReadingProgress({
    required this.userId,
    required this.bookId,
    required this.progressPercent,
    required this.lastViewedAt,
  });

  factory ReadingProgress.fromJson(Map<String, dynamic> json) =>
      ReadingProgress(
        userId: json['user_id'] as String,
        bookId: json['book_id'] as String,
        progressPercent: (json['progress_percent'] as int?) ?? 0,
        lastViewedAt: DateTime.parse(json['last_viewed_at'] as String),
      );
}