// lib/repositories/blog_repository.dart
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../utils/utils.dart';

class BlogRepository {
  final SupabaseClient _client;
  static const int _pageSize = 15;

  BlogRepository(this._client);

  String? get _userId => _client.auth.currentUser?.id;

  static const _blogSelect = '''
    id, user_id, title, content, likes, comments,
    image_url, created_at,
    profiles!blogs_user_id_fkey1 (
      id, username, avatar_url, full_name
    )
  ''';

  Future<List<Blog>> getBlogs({
    int page = 0,
    String? authorId,
  }) async {
    var query = _client.from('blogs').select(_blogSelect);

    if (authorId != null) {
      query = query.eq('user_id', authorId);
    }

    final data = await query
        .order('created_at', ascending: false)
        .range(page * _pageSize, (page + 1) * _pageSize - 1);
    print("Данные из Supabase: $data"); // <--- ДОБАВЬТЕ ЭТО
    final blogs = (data as List).map((e) => Blog.fromJson(e)).toList();

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

  Future<Blog> getBlog(String id) async {
    final data = await _client
        .from('blogs')
        .select(_blogSelect)
        .eq('id', id)
        .single();

    Blog blog = Blog.fromJson(data);

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

  Future<Blog> createBlog({
    required String title,
    required String content,
    String? imageUrl,
  }) async {
    if (_userId == null) throw const AppException('Не авторизован');
    if (title.trim().isEmpty) throw const AppException('Введите заголовок');
    if (content.trim().isEmpty) throw const AppException('Введите содержание');

    final data = await _client.from('blogs').insert({
      'user_id': _userId,
      'title': title.trim(),
      'content': content.trim(),
      if (imageUrl != null) 'image_url': imageUrl,
    }).select(_blogSelect).single();

    try {
      await _client
          .rpc('increment_blogs_count', params: {'p_user_id': _userId});
    } catch (_) {}

    return Blog.fromJson(data);
  }

  Future<Blog> updateBlog({
    required String id,
    required String title,
    required String content,
    String? imageUrl,
  }) async {
    if (_userId == null) throw const AppException('Не авторизован');

    final data = await _client
        .from('blogs')
        .update({
      'title': title.trim(),
      'content': content.trim(),
      'image_url': imageUrl,
      'updated_at': DateTime.now().toIso8601String(),
    })
        .eq('id', id)
        .eq('user_id', _userId!)
        .select(_blogSelect)
        .single();

    return Blog.fromJson(data);
  }

  Future<void> deleteBlog(String id) async {
    if (_userId == null) throw const AppException('Не авторизован');
    await _client
        .from('blogs')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId!);
  }

  Future<Blog> toggleLike(Blog blog) async {
    if (_userId == null) throw const AppException('Не авторизован');

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
    if (_userId == null) throw const AppException('Не авторизован');
    if (content.trim().isEmpty) throw const AppException('Комментарий пуст');

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

    // Обновляем счётчик комментариев
    try {
      await _client.rpc('increment_blog_comments',
          params: {'p_blog_id': blogId});
    } catch (_) {
      // Fallback: ручной инкремент
      try {
        await _client.rpc('increment_blog_comments_manual',
            params: {'p_blog_id': blogId});
      } catch (_) {}
    }

    return data;
  }

  Future<String?> uploadBlogImage(List<int> bytes, String ext) async {
    if (_userId == null) return null;

    final fileName = '$_userId/blog_${DateTime.now().millisecondsSinceEpoch}.$ext';

    // Преобразуем List<int> в Uint8List
    final uint8Bytes = Uint8List.fromList(bytes);

    await _client.storage.from('blog-images').uploadBinary(
      fileName,
      uint8Bytes, // Передаем уже преобразованные данные
      fileOptions: FileOptions(contentType: 'image/$ext', upsert: false),
    );

    return _client.storage.from('blog-images').getPublicUrl(fileName);
  }

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
}