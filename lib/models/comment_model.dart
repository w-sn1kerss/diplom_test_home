class Comment {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String content;
  final int? rating;
  final int likes;
  final String timeAgo;
  final bool isLiked;

  Comment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.content,
    this.rating,
    required this.likes,
    required this.timeAgo,
    required this.isLiked,
  });

  Comment copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatar,
    String? content,
    int? rating,
    int? likes,
    String? timeAgo,
    bool? isLiked,
  }) {
    return Comment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      content: content ?? this.content,
      rating: rating ?? this.rating,
      likes: likes ?? this.likes,
      timeAgo: timeAgo ?? this.timeAgo,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}