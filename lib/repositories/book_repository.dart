// lib/repositories/book_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../utils/utils.dart';

class BookRepository {
  final SupabaseClient _client;
  static const int _pageSize = 20;

  final Map<String, Book> _cache = {};

  BookRepository(this._client);

  String? get _userId => _client.auth.currentUser?.id;

  Book? getCached(String id) => _cache[id];

  Future<List<Book>> getBooks({
    int page = 0,
    String? category,
    String? search,
  }) async {
    var query = _client.from('books').select(
        'id, title, author, cover_url, rating, categories, created_at');

    if (category != null && category.isNotEmpty) {
      query = query.contains('categories', [category]);
    }

    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim();
      query = query.or('title.ilike.%$s%,author.ilike.%$s%');
    }

    final data = await query
        .order('created_at', ascending: false)
        .range(page * _pageSize, (page + 1) * _pageSize - 1);

    final books = (data as List).map((e) => Book.fromListJson(e)).toList();
    for (final b in books) {
      _cache[b.id] = b;
    }
    return books;
  }

  Future<Book> getBook(String id) async {
    final data =
    await _client.from('books').select().eq('id', id).single();
    final book = Book.fromJson(data);
    _cache[id] = book;
    return book;
  }

  Future<List<Map<String, dynamic>>> getRecentBooks() async {
    if (_userId == null) return [];

    final data = await _client
        .from('user_recent_activity')
        .select('''
          user_id, book_id, progress_percent, last_viewed_at,
          books!user_recent_activity_book_id_fkey (
            id, title, author, cover_url, rating
          )
        ''')
        .eq('user_id', _userId!)
        .order('last_viewed_at', ascending: false)
        .limit(10);

    return (data as List).map((e) {
      final bookData = e['books'] as Map<String, dynamic>?;
      return {
        'progress': e['progress_percent'] as int? ?? 0,
        'last_viewed_at': e['last_viewed_at'] as String,
        'book': bookData != null ? Book.fromListJson(bookData) : null,
      };
    }).where((e) => e['book'] != null).toList();
  }

  Future<List<BookComment>> getComments(String bookId) async {
    final data = await _client.from('book_comments').select('''
          id, book_id, user_id, content, rating, likes_count, created_at,
          profiles!book_comments_user_id_fkey (
            id, username, avatar_url
          )
        ''').eq('book_id', bookId).order('created_at', ascending: false);

    final comments =
    (data as List).map((e) => BookComment.fromJson(e)).toList();

    if (_userId != null && comments.isNotEmpty) {
      final commentIds = comments.map((c) => c.id).toList();
      final liked = await _client
          .from('comment_likes')
          .select('comment_id')
          .eq('user_id', _userId!)
          .inFilter('comment_id', commentIds);

      final likedIds =
      (liked as List).map((e) => e['comment_id'] as String).toSet();

      return comments
          .map((c) => c.copyWith(isLikedByMe: likedIds.contains(c.id)))
          .toList();
    }

    return comments;
  }

  Future<BookComment> addComment({
    required String bookId,
    required String content,
    int? rating,
  }) async {
    if (_userId == null) throw const AppException('Не авторизован');
    if (content.trim().isEmpty) {
      throw const AppException('Комментарий не может быть пустым');
    }
    if (rating != null && (rating < 1 || rating > 5)) {
      throw const AppException('Оценка должна быть от 1 до 5');
    }

    final data = await _client.from('book_comments').insert({
      'book_id': bookId,
      'user_id': _userId,
      'content': content.trim(),
      if (rating != null) 'rating': rating,
    }).select('''
          id, book_id, user_id, content, rating, likes_count, created_at,
          profiles!book_comments_user_id_fkey (
            id, username, avatar_url
          )
        ''').single();

    try {
      await _client.rpc(
          'increment_reviews_count', params: {'p_user_id': _userId});
    } catch (_) {}

    if (rating != null) {
      await _updateBookRating(bookId);
    }

    return BookComment.fromJson(data);
  }

  // Внутри класса BookRepository
  Future<List<BookComment>> getBookComments(String bookId) async {
    final data = await _client
        .from('book_comments')
        .select('*, profiles(*)') // Загружаем данные профиля автора комментария
        .eq('book_id', bookId)
        .order('created_at', ascending: false);

    return (data as List).map((json) => BookComment.fromJson(json)).toList();
  }

  Future<void> deleteComment(String commentId) async {
    if (_userId == null) throw const AppException('Не авторизован');
    await _client
        .from('book_comments')
        .delete()
        .eq('id', commentId)
        .eq('user_id', _userId!);
  }

  Future<BookComment> toggleCommentLike(BookComment comment) async {
    if (_userId == null) throw const AppException('Не авторизован');

    if (comment.isLikedByMe) {
      await _client
          .from('comment_likes')
          .delete()
          .eq('comment_id', comment.id)
          .eq('user_id', _userId!);
      return comment.copyWith(
          likesCount: comment.likesCount - 1, isLikedByMe: false);
    } else {
      await _client.from('comment_likes').upsert({
        'comment_id': comment.id,
        'user_id': _userId,
      });
      return comment.copyWith(
          likesCount: comment.likesCount + 1, isLikedByMe: true);
    }
  }

  Future<List<UserNote>> getNotes(String bookId) async {
    if (_userId == null) return [];
    final data = await _client
        .from('user_notes')
        .select()
        .eq('book_id', bookId)
        .eq('user_id', _userId!);
    return (data as List).map((e) => UserNote.fromJson(e)).toList();
  }

  Future<UserNote> addNote({
    required String bookId,
    required int pageIndex,
    required String content,
    String colorHex = '#FFFF00',
  }) async {
    if (_userId == null) throw const AppException('Не авторизован');

    final data = await _client.from('user_notes').insert({
      'user_id': _userId,
      'book_id': bookId,
      'page_index': pageIndex,
      'content': content.trim(),
      'color_hex': colorHex,
    }).select().single();

    return UserNote.fromJson(data);
  }

  Future<void> deleteNote(String noteId) async {
    if (_userId == null) throw const AppException('Не авторизован');
    await _client
        .from('user_notes')
        .delete()
        .eq('id', noteId)
        .eq('user_id', _userId!);
  }

  Future<void> saveProgress({
    required String bookId,
    required int progressPercent,
  }) async {
    if (_userId == null) return;
    await _client.from('user_recent_activity').upsert({
      'user_id': _userId,
      'book_id': bookId,
      'progress_percent': progressPercent.clamp(0, 100),
      'last_viewed_at': DateTime.now().toIso8601String(),
    });
  }

  // Пересчёт среднего рейтинга книги
  Future<void> _updateBookRating(String bookId) async {
    try {
      final data = await _client
          .from('book_comments')
          .select('rating')
          .eq('book_id', bookId)
          .not('rating', 'is', null);

      final ratings = (data as List)
          .map((e) => (e['rating'] as num).toDouble())
          .toList();

      if (ratings.isEmpty) return;

      final avg = ratings.reduce((a, b) => a + b) / ratings.length;

      await _client
          .from('books')
          .update({'rating': double.parse(avg.toStringAsFixed(1))})
          .eq('id', bookId);
    } catch (_) {}
  }
}