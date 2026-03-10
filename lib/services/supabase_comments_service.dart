import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/comment_model.dart';

class SupabaseCommentsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Получить комментарии
  Future<List<Comment>> getComments(String bookId) async {
    try {
      print('Загрузка комментариев для книги: $bookId');

      final response = await _supabase
          .from('book_comments')
          .select('*')
          .eq('book_id', bookId)
          .order('created_at', ascending: false);

      final currentUserId = _supabase.auth.currentUser?.id;

      return (response as List).map((json) {
        return Comment(
          id: json['id'].toString(),
          userId: json['user_id'].toString(),
          userName: _generateUserName(json['user_id'].toString(), currentUserId),
          userAvatar: '👤',
          content: json['content']?.toString() ?? '',
          rating: (json['rating'] as num?)?.toInt(),
          likes: 0,
          timeAgo: _formatTimeAgo(DateTime.parse(json['created_at'].toString())),
          isLiked: false,
        );
      }).toList();
    } catch (e) {
      print('Ошибка загрузки комментариев: $e');
      return [];
    }
  }

  String _generateUserName(String userId, String? currentUserId) {
    if (currentUserId != null && userId == currentUserId) {
      return 'Вы';
    }
    return 'Пользователь ${userId.substring(0, 8)}';
  }

  // Добавить комментарий
  Future<void> addComment({
    required String bookId,
    required String content,
    int? rating,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Не авторизован');

      await _supabase.from('book_comments').insert({
        'book_id': bookId,
        'user_id': user.id,
        'content': content,
        'rating': rating,
      });
    } catch (e) {
      print('Ошибка добавления комментария: $e');
      rethrow;
    }
  }

  // Удалить комментарий - ДОБАВИТЬ ЭТОТ МЕТОД
  Future<void> deleteComment(String commentId) async {
    try {
      await _supabase
          .from('book_comments')
          .delete()
          .eq('id', commentId);

      print('Комментарий $commentId удален');
    } catch (e) {
      print('Ошибка удаления комментария: $e');
      rethrow;
    }
  }

  // Получить статистику
  Future<Map<String, dynamic>> getStatistics(String bookId) async {
    try {
      final comments = await _supabase
          .from('book_comments')
          .select('*')
          .eq('book_id', bookId);

      final commentsCount = comments.length;

      // Средний рейтинг
      double averageRating = 0;
      int ratingCount = 0;
      double ratingSum = 0;

      for (var comment in comments) {
        final rating = comment['rating'] as num?;
        if (rating != null) {
          ratingSum += rating.toDouble();
          ratingCount++;
        }
      }

      if (ratingCount > 0) {
        averageRating = ratingSum / ratingCount;
      }

      return {
        'commentsCount': commentsCount,
        'averageRating': averageRating,
        'totalLikes': 0, // Пока нет лайков
      };
    } catch (e) {
      print('Ошибка получения статистики: $e');
      return {
        'commentsCount': 0,
        'averageRating': 0,
        'totalLikes': 0,
      };
    }
  }

  // Проверить, текущий ли пользователь
  bool isCurrentUser(String userId) {
    return _supabase.auth.currentUser?.id == userId;
  }

  // Вспомогательные методы
  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) return 'Только что';
    if (difference.inMinutes < 60) return '${difference.inMinutes} мин назад';
    if (difference.inHours < 24) return '${difference.inHours} ч назад';
    if (difference.inDays < 7) return '${difference.inDays} д назад';
    return '${difference.inDays ~/ 7} нед назад';
  }
}