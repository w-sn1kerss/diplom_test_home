import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

class BlogRepository {
  final SupabaseClient _client;
  static const int _pageSize = 15;

  BlogRepository(this._client);

  String? get _userId => _client.auth.currentUser?.id;

  // ---- Ð›ÐµÐ½Ñ‚Ð° Ð±Ð»Ð¾Ð³Ð¾Ð² (Ñ JOIN Ð¿Ñ€Ð¾Ñ„Ð¸Ð»Ñ Ð°Ð²Ñ‚Ð¾Ñ€Ð° â€” 1 Ð·Ð°Ð¿Ñ€Ð¾Ñ) ----
  Future<List<Blog>> getBlogs({
    int page = 0,
    String? authorId, // Ñ„Ð¸Ð»ÑŒÑ‚Ñ€ Ð¿Ð¾ Ð°Ð²Ñ‚Ð¾Ñ€Ñƒ
  }) async {
    var query = _client.from('blogs').select('''
          id, user_id, title, content, likes, comments,
          image_url, created_at,
          profiles!blogs_user_id_fkey (
            id, username, avatar_url, full_name
          )
        ''');

    if (authorId != null) {
      query = query.eq('user_id', authorId);
    }

    final data = await query
        .order('created_at', ascending: false)
        .range(page * _pageSize, (page + 1) * _pageSize - 1);

    final blogs = (data as List).map((e) => Blog.fromJson(e)).toList();

    // ÐŸÐ¾Ð¼ÐµÑ‡Ð°ÐµÐ¼ Ð»Ð°Ð¹ÐºÐ½ÑƒÑ‚Ñ‹Ðµ Ñ‚ÐµÐºÑƒÑ‰Ð¸Ð¼ Ð¿Ð¾Ð»ÑŒÐ·Ð¾Ð²Ð°Ñ‚ÐµÐ»ÐµÐ¼
    if (_userId != null && blogs.isNotEmpty) {
      final blogIds = blogs.map((b) => b.id).toList();
      final liked = await _client
          .from('blog_likes')
          .select('blog_id')
          .eq('user_id', _userId!)
          .inFilter('blog_id', blogIds);

      final likedIds =
      (liked as List).map((e) => e['blog_id'] as String).toSet();

      return blogs
          .map((b) => b.copyWith(isLikedByMe: likedIds.contains(b.id)))
          .toList();
    }

    return blogs;
  }

  // ---- Ð”ÐµÑ‚Ð°Ð»ÑŒÐ½Ñ‹Ð¹ Ð±Ð»Ð¾Ð³ ----
  Future<Blog> getBlog(String id) async {
    final data = await _client.from('blogs').select('''
          id, user_id, title, content, likes, comments,
          image_url, created_at,
          profiles!blogs_user_id_fkey (
            id, username, avatar_url, full_name
          )
        ''').eq('id', id).single();

    Blog blog = Blog.fromJson(data);

    // ÐŸÑ€Ð¾Ð²ÐµÑ€ÑÐµÐ¼ Ð»Ð°Ð¹Ðº
    if (_userId != null) {
      final liked = await _client
          .from('blog_likes')
          .select('id')
          .eq('blog_id', id)
          .eq('user_id', _userId!)
          .maybeSingle();
      blog = blog.copyWith(isLikedByMe: liked != null);
    }

    return blog;
  }

  // ---- Ð¡Ð¾Ð·Ð´Ð°Ñ‚ÑŒ Ð±Ð»Ð¾Ð³ ----
  Future<Blog> createBlog({
    required String title,
    required String content,
    String? imageUrl,
  }) async {
    if (_userId == null) throw const AppException('ÐÐµ Ð°Ð²Ñ‚Ð¾Ñ€Ð¸Ð·Ð¾Ð²Ð°Ð½');
    if (title.trim().isEmpty) throw const AppException('Ð’Ð²ÐµÐ´Ð¸Ñ‚Ðµ Ð·Ð°Ð³Ð¾Ð»Ð¾Ð²Ð¾Ðº');
    if (content.trim().isEmpty) throw const AppException('Ð’Ð²ÐµÐ´Ð¸Ñ‚Ðµ ÑÐ¾Ð´ÐµÑ€Ð¶Ð°Ð½Ð¸Ðµ');

    final data = await _client.from('blogs').insert({
      'user_id': _userId,
      'title': title.trim(),
      'content': content.trim(),
      if (imageUrl != null) 'image_url': imageUrl,
    }).select('''
          id, user_id, title, content, likes, comments,
          image_url, created_at,
          profiles!blogs_user_id_fkey (
            id, username, avatar_url, full_name
          )
        ''').single();

    // ÐžÐ±Ð½Ð¾Ð²Ð»ÑÐµÐ¼ ÑÑ‡Ñ‘Ñ‚Ñ‡Ð¸Ðº Ð±Ð»Ð¾Ð³Ð¾Ð² Ð¿Ð¾Ð»ÑŒÐ·Ð¾Ð²Ð°Ñ‚ÐµÐ»Ñ
    try {
      await _client.rpc('increment_blogs_count', params: {'p_user_id': _userId});
    } catch (_) {}

    return Blog.fromJson(data);
  }

  // ---- ÐžÐ±Ð½Ð¾Ð²Ð¸Ñ‚ÑŒ Ð±Ð»Ð¾Ð³ ----
  Future<Blog> updateBlog({
    required String id,
    required String title,
    required String content,
    String? imageUrl,
  }) async {
    if (_userId == null) throw const AppException('ÐÐµ Ð°Ð²Ñ‚Ð¾Ñ€Ð¸Ð·Ð¾Ð²Ð°Ð½');

    final data = await _client.from('blogs').update({
      'title': title.trim(),
      'content': content.trim(),
      'image_url': imageUrl,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id).eq('user_id', _userId!).select('''
          id, user_id, title, content, likes, comments,
          image_url, created_at,
          profiles!blogs_user_id_fkey (
            id, username, avatar_url, full_name
          )
        ''').single();

    return Blog.fromJson(data);
  }

  // ---- Ð£Ð´Ð°Ð»Ð¸Ñ‚ÑŒ Ð±Ð»Ð¾Ð³ ----
  Future<void> deleteBlog(String id) async {
    if (_userId == null) throw const AppException('ÐÐµ Ð°Ð²Ñ‚Ð¾Ñ€Ð¸Ð·Ð¾Ð²Ð°Ð½');
    await _client
        .from('blogs')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId!);
  }

  // ---- Ð›Ð°Ð¹Ðº Ð±Ð»Ð¾Ð³Ð° (Ð¾Ð¿Ñ‚Ð¸Ð¼Ð¸ÑÑ‚Ð¸Ñ‡Ð½Ð¾, Ñ Ð·Ð°Ñ‰Ð¸Ñ‚Ð¾Ð¹ Ð¾Ñ‚ Ð´ÑƒÐ±Ð»ÐµÐ¹) ----
  Future<Blog> toggleLike(Blog blog) async {
    if (_userId == null) throw const AppException('ÐÐµ Ð°Ð²Ñ‚Ð¾Ñ€Ð¸Ð·Ð¾Ð²Ð°Ð½');

    if (blog.isLikedByMe) {
      await _client
          .from('blog_likes')
          .delete()
          .eq('blog_id', blog.id)
          .eq('user_id', _userId!);
      return blog.copyWith(likes: blog.likes - 1, isLikedByMe: false);
    } else {
      await _client.from('blog_likes').upsert({
        'blog_id': blog.id,
        'user_id': _userId,
      });
      return blog.copyWith(likes: blog.likes + 1, isLikedByMe: true);
    }
  }

  // ---- ÐšÐ¾Ð¼Ð¼ÐµÐ½Ñ‚Ð°Ñ€Ð¸Ð¸ Ðº Ð±Ð»Ð¾Ð³Ñƒ (Ñ JOIN) ----
  Future<List<Map<String, dynamic>>> getBlogComments(String blogId) async {
    final data = await _client.from('blog_comments').select('''
          id, blog_id, user_id, content, likes_count, created_at,
          profiles!blog_comments_user_id_fkey (
            id, username, avatar_url
          )
        ''').eq('blog_id', blogId).order('created_at', ascending: false);

    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> addBlogComment({
    required String blogId,
    required String content,
  }) async {
    if (_userId == null) throw const AppException('ÐÐµ Ð°Ð²Ñ‚Ð¾Ñ€Ð¸Ð·Ð¾Ð²Ð°Ð½');
    if (content.trim().isEmpty) throw const AppException('ÐšÐ¾Ð¼Ð¼ÐµÐ½Ñ‚Ð°Ñ€Ð¸Ð¹ Ð¿ÑƒÑÑ‚');

    final data = await _client.from('blog_comments').insert({
      'blog_id': blogId,
      'user_id': _userId,
      'content': content.trim(),
    }).select('''
          id, blog_id, user_id, content, likes_count, created_at,
          profiles!blog_comments_user_id_fkey (
            id, username, avatar_url
          )
        ''').single();

    // ÐžÐ±Ð½Ð¾Ð²Ð»ÑÐµÐ¼ ÑÑ‡Ñ‘Ñ‚Ñ‡Ð¸Ðº ÐºÐ¾Ð¼Ð¼ÐµÐ½Ñ‚Ð°Ñ€Ð¸ÐµÐ² Ñƒ Ð±Ð»Ð¾Ð³Ð° (ÐµÑÐ»Ð¸ Ð½ÐµÑ‚ DB Ñ‚Ñ€Ð¸Ð³Ð³ÐµÑ€Ð°)
    await _client.rpc('increment_blog_comments',
        params: {'p_blog_id': blogId}).catchError((_) async {
      await _client.from('blogs').update(
          {'comments': blog_increment_fallback}).eq('id', blogId);
    });

    return data;
  }

  // Ð—Ð°Ð³Ñ€ÑƒÐ·ÐºÐ° Ð¸Ð·Ð¾Ð±Ñ€Ð°Ð¶ÐµÐ½Ð¸Ñ Ð´Ð»Ñ Ð±Ð»Ð¾Ð³Ð°
  Future<String?> uploadBlogImage(List<int> bytes, String ext) async {
    if (_userId == null) return null;

    final fileName =
        '$_userId/blog_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.storage.from('blog-images').uploadBinary(
      fileName,
      bytes,
      fileOptions: FileOptions(contentType: 'image/$ext', upsert: false),
    );

    return _client.storage.from('blog-images').getPublicUrl(fileName);
  }

  // Realtime Ð¿Ð¾Ð´Ð¿Ð¸ÑÐºÐ° Ð½Ð° Ð½Ð¾Ð²Ñ‹Ðµ Ð±Ð»Ð¾Ð³Ð¸
  RealtimeChannel subscribeToBlogFeed(
      void Function(Map<String, dynamic>) onNew) {
    return _client
        .channel('blog_feed')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'blogs',
      callback: (payload) {
        if (payload.newRecord.isNotEmpty) {
          onNew(payload.newRecord);
        }
      },
    )
        .subscribe();
  }

  int get blog_increment_fallback => 0; // Ð·Ð°Ð³Ð»ÑƒÑˆÐºÐ°
}