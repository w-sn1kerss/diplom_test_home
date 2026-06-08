// lib/models/blog.dart
import 'profile.dart';

class Blog {
  final String id;
  final String userId;
  final String title;
  final String content;
  final int likes;
  final int comments;
  final String? imageUrl;
  final DateTime createdAt;
  final Profile? author;
  final bool isLikedByMe;

  const Blog({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.likes,
    required this.comments,
    this.imageUrl,
    required this.createdAt,
    this.author,
    this.isLikedByMe = false,
  });

  factory Blog.fromJson(Map<String, dynamic> json) => Blog(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    title: json['title'] as String,
    content: json['content'] as String,
    likes: (json['likes'] as int?) ?? 0,
    comments: (json['comments'] as int?) ?? 0,
    imageUrl: json['image_url'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    author: json['profiles'] != null
        ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
        : null,
  );

  Blog copyWith({
    int? likes,
    int? comments,
    bool? isLikedByMe,
    String? imageUrl,
  }) =>
      Blog(
        id: id,
        userId: userId,
        title: title,
        content: content,
        likes: likes ?? this.likes,
        comments: comments ?? this.comments,
        imageUrl: imageUrl ?? this.imageUrl,
        createdAt: createdAt,
        author: author,
        isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      );
}