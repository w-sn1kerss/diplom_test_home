import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
class BookRepository {
  final SupabaseClient _client;
  static const int _pageSize = 20;

  final Map<String, Book> _cache = {};

  BookRepository(this._client);

  String? get _userId => _client.auth.currentUser?.id;

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
      query = query.or(
          'title.ilike.%${search.trim()}%,author.ilike.%${search.trim()}%');
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
    final data = await _client
        .from('books')
        .select()
        .eq('id', id)
        .single();

    final book = Book.fromJson(data);
    _cache[id] = book;
    return book;
  }

  Future<List<Map<String, dynamic>>> getRecentBooks() async {
    if (_userId == null) return [];

    // JOIN Ñ‡ÐµÑ€ÐµÐ· PostgREST â€” Ð¾Ð´Ð¸Ð½ Ð·Ð°Ð¿Ñ€Ð¾Ñ Ð²Ð¼ÐµÑÑ‚Ð¾ N+1
    final data = await _client.from('user_recent_activity').select('''
          user_id, book_id, progress_percent, last_viewed_at,
          books!user_recent_activity_book_id_fkey (
            id, title, author, cover_url, rating
          )
        ''').eq('user_id', _userId!).order('last_viewed_at', ascending: false).limit(10);

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

    // Ð•ÑÐ»Ð¸ Ð°Ð²Ñ‚Ð¾Ñ€Ð¸Ð·Ð¾Ð²Ð°Ð½ â€” Ð¿Ð¾Ð¼ÐµÑ‡Ð°ÐµÐ¼ Ð»Ð°Ð¹ÐºÐ½ÑƒÑ‚Ñ‹Ðµ
    if (_userId != null && comments.isNotEmpty) {
      final commentIds = comments.map((c) => c.id).toList();
      final liked = await _client
          .from('comment_likes')
          .select('comment_id')
          .eq('user_id', _userId!)
          .inFilter('comment_id', commentIds);

      final likedIds = (liked as List)
          .map((e) => e['comment_id'] as String)
          .toSet();

      return comments
          .map((c) => c.copyWith(isLikedByMe: likedIds.contains(c.id)))
          .toList();
    }

    return comments;
  }

  // ---- Ð”Ð¾Ð±Ð°Ð²Ð¸Ñ‚ÑŒ ÐºÐ¾Ð¼Ð¼ÐµÐ½Ñ‚Ð°Ñ€Ð¸Ð¹ ----
  Future<BookComment> addComment({
    required String bookId,
    required String content,
    int? rating,
  }) async {
    if (_userId == null) throw const AppException('ÐÐµ Ð°Ð²Ñ‚Ð¾Ñ€Ð¸Ð·Ð¾Ð²Ð°Ð½');
    if (content.trim().isEmpty) throw const AppException('ÐšÐ¾Ð¼Ð¼ÐµÐ½Ñ‚Ð°Ñ€Ð¸Ð¹ Ð½Ðµ Ð¼Ð¾Ð¶ÐµÑ‚ Ð±Ñ‹Ñ‚ÑŒ Ð¿ÑƒÑÑ‚Ñ‹Ð¼');
    if (rating != null && (rating < 1 || rating > 5)) {
      throw const AppException('ÐžÑ†ÐµÐ½ÐºÐ° Ð´Ð¾Ð»Ð¶Ð½Ð° Ð±Ñ‹Ñ‚ÑŒ Ð¾Ñ‚ 1 Ð´Ð¾ 5');
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

    // ÐžÐ±Ð½Ð¾Ð²Ð»ÑÐµÐ¼ ÑÑ‡Ñ‘Ñ‚Ñ‡Ð¸Ðº Ñ€ÐµÑ†ÐµÐ½Ð·Ð¸Ð¹ Ð¿Ð¾Ð»ÑŒÐ·Ð¾Ð²Ð°Ñ‚ÐµÐ»Ñ
    try {
      await _client.rpc('increment_reviews_count', params: {'p_user_id': _userId});
    } catch (_) {}

    // ÐžÐ±Ð½Ð¾Ð²Ð»ÑÐµÐ¼ ÑÑ€ÐµÐ´Ð½Ð¸Ð¹ Ñ€ÐµÐ¹Ñ‚Ð¸Ð½Ð³ ÐºÐ½Ð¸Ð³Ð¸
    if (rating != null) {
      await _updateBookRating(bookId);
    }

    return BookComment.fromJson(data);
  }

  // ---- Ð£Ð´Ð°Ð»Ð¸Ñ‚ÑŒ ÐºÐ¾Ð¼Ð¼ÐµÐ½Ñ‚Ð°Ñ€Ð¸Ð¹ ----
  Future<void> deleteComment(String commentId) async {
    if (_userId == null) throw const AppException('ÐÐµ Ð°Ð²Ñ‚Ð¾Ñ€Ð¸Ð·Ð¾Ð²Ð°Ð½');
    await _client
        .from('book_comments')
        .delete()
        .eq('id', commentId)
        .eq('user_id', _userId!);
  }

  // ---- Ð›Ð°Ð¹Ðº ÐºÐ¾Ð¼Ð¼ÐµÐ½Ñ‚Ð°Ñ€Ð¸Ñ ----
  Future<BookComment> toggleCommentLike(BookComment comment) async {
    if (_userId == null) throw const AppException('ÐÐµ Ð°Ð²Ñ‚Ð¾Ñ€Ð¸Ð·Ð¾Ð²Ð°Ð½');

    if (comment.isLikedByMe) {
      await _client
          .from('comment_likes')
          .delete()
          .eq('comment_id', comment.id)
          .eq('user_id', _userId!);
      return comment.copyWith(
        likesCount: comment.likesCount - 1,
        isLikedByMe: false,
      );
    } else {
      await _client.from('comment_likes').upsert({
        'comment_id': comment.id,
        'user_id': _userId,
      });
      return comment.copyWith(
        likesCount: comment.likesCount + 1,
        isLikedByMe: true,
      );
    }
  }

  // ---- Ð—Ð°Ð¼ÐµÑ‚ÐºÐ¸ Ñ‡Ð¸Ñ‚Ð°Ñ‚ÐµÐ»Ñ ----
  Future<List<UserNote>> getNotes(String bookId) async {
    if (_userId == null) return [];

    final data = await _client
        .from('user_notes')
        .select()
        .eq('user_id', _userId!)
        .eq('book_id', bookId)
        .order('page_index');

    return (data as List).map((e) => UserNote.fromJson(e)).toList();
  }

  Future<UserNote> addNote({
    required String bookId,
    required int pageIndex,
    required String content,
    String colorHex = '#FFFF00',
  }) async {
    if (_userId == null) throw const AppException('ÐÐµ Ð°Ð²Ñ‚Ð¾Ñ€Ð¸Ð·Ð¾Ð²Ð°Ð½');
    if (content.trim().isEmpty) throw const AppException('Ð—Ð°Ð¼ÐµÑ‚ÐºÐ° Ð½Ðµ Ð¼Ð¾Ð¶ÐµÑ‚ Ð±Ñ‹Ñ‚ÑŒ Ð¿ÑƒÑÑ‚Ð¾Ð¹');

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
    if (_userId == null) throw const AppException('ÐÐµ Ð°Ð²Ñ‚Ð¾Ñ€Ð¸Ð·Ð¾Ð²Ð°Ð½');
    await _client
        .from('user_notes')
        .delete()
        .eq('id', noteId)
        .eq('user_id', _userId!);
  }

  // ---- Ð¡Ð¾Ñ…Ñ€Ð°Ð½ÐµÐ½Ð¸Ðµ Ð¿Ñ€Ð¾Ð³Ñ€ÐµÑÑÐ° ----
  Future<void> saveProgress({
    required String bookId,
    required int progressPercent,
  }) async {
    if (_userId == null) return;

    await _client.from('user_recent_activity').upsert(
      {
        'user_id': _userId,
        'book_id': bookId,
        'progress_percent': progressPercent.clamp(0, 100),
        'last_viewed_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,book_id',
    );

    // Ð•ÑÐ»Ð¸ ÐºÐ½Ð¸Ð³Ð° Ð´Ð¾Ñ‡Ð¸Ñ‚Ð°Ð½Ð° â€” Ð¾Ð±Ð½Ð¾Ð²Ð»ÑÐµÐ¼ ÑÑ‚Ð°Ñ‚Ð¸ÑÑ‚Ð¸ÐºÑƒ
    if (progressPercent >= 95) {
      try {
        await _client.rpc('increment_books_read', params: {'p_user_id': _userId});
      } catch (_) {}
    }
  }

  // ---- Ð˜Ð·Ð±Ñ€Ð°Ð½Ð½Ð¾Ðµ ----
  Future<bool> isInFavorites(String bookId) async {
    if (_userId == null) return false;
    final data = await _client
        .from('user_favorites')
        .select('id')
        .eq('user_id', _userId!)
        .eq('item_id', bookId)
        .eq('item_type', 'book')
        .maybeSingle();
    return data != null;
  }

  Future<void> toggleFavorite(String bookId, bool isFavorite) async {
    if (_userId == null) throw const AppException('ÐÐµ Ð°Ð²Ñ‚Ð¾Ñ€Ð¸Ð·Ð¾Ð²Ð°Ð½');

    if (isFavorite) {
      await _client.from('user_favorites').delete().eq('user_id', _userId!).eq('item_id', bookId);
    } else {
      await _client.from('user_favorites').insert({
        'user_id': _userId,
        'item_id': bookId,
        'item_type': 'book',
      });
    }
  }

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

  Book? getCached(String id) => _cache[id];

  void clearCache() => _cache.clear();
}
