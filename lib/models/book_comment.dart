// lib/models/book_comment.dart
import 'profile.dart';

class BookComment {
  final String id;
  final String bookId;
  final String userId;
  final String content;
  final int? rating;
  final int likesCount;
  final DateTime createdAt;
  final Profile? author;
  final bool isLikedByMe;


  const BookComment({
    required this.id,
    required this.bookId,
    required this.userId,
    required this.content,
    this.rating,
    required this.likesCount,
    required this.createdAt,
    this.author,
    this.isLikedByMe = false,
  });

  factory BookComment.fromJson(Map<String, dynamic> json) => BookComment(
    id: json['id'] as String,
    bookId: json['book_id'] as String,
    userId: json['user_id'] as String,
    content: json['content'] as String,
    rating: json['rating'] as int?,
    likesCount: (json['likes_count'] as int?) ?? 0,
    createdAt: DateTime.parse(json['created_at'] as String),
    author: json['profiles'] != null
        ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
        : null,
  );

  BookComment copyWith({
    int? likesCount,
    bool? isLikedByMe,
    int? rating, // Добавьте этот параметр
    String? content, // И этот, если захотите менять текст отзыва
  }) => BookComment(
    id: id,
    bookId: bookId,
    userId: userId,
    content: content ?? this.content,
    rating: rating ?? this.rating, // Используйте его здесь
    likesCount: likesCount ?? this.likesCount,
    createdAt: createdAt,
    author: author,
    isLikedByMe: isLikedByMe ?? this.isLikedByMe,
  );
}