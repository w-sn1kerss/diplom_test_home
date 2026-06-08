// lib/providers/blog_provider.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../repositories/blog_repository.dart';
import '../utils/utils.dart';

class BlogProvider extends ChangeNotifier {
  final BlogRepository _repo;

  List<Blog> _blogs = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 0;

  Blog? _selectedBlog;
  List<Map<String, dynamic>> _blogComments = [];

  RealtimeChannel? _realtimeChannel;
  String? _error;

  List<Blog> get blogs => _blogs;
  bool get loading => _loading;
  bool get hasMore => _hasMore;
  Blog? get selectedBlog => _selectedBlog;
  List<Map<String, dynamic>> get blogComments => _blogComments;
  String? get error => _error;

  BlogProvider(this._repo);

  // Внутри BlogProvider
  Future<List<Blog>> fetchBlogsByAuthor(String userId) async {
    return await _repo.getBlogs(page: 0, authorId: userId);
  }

  Future<void> loadBlogs({String? authorId}) async {
    _page = 0;
    _hasMore = true;
    _blogs = [];
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _repo.getBlogs(page: 0, authorId: authorId);
      _blogs = result;
      _hasMore = result.length == 15;
      _page = 1;
    } catch (e) {
      _error = handleError(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore({String? authorId}) async {
    if (!_hasMore || _loading) return;

    _loading = true;
    notifyListeners();

    try {
      final result =
      await _repo.getBlogs(page: _page, authorId: authorId);
      _blogs = [..._blogs, ...result];
      _hasMore = result.length == 15;
      _page++;
    } catch (e) {
      _error = handleError(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> selectBlog(String id) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repo.getBlog(id),
        _repo.getBlogComments(id),
      ]);
      _selectedBlog = results[0] as Blog;
      _blogComments = (results[1] as List).cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      _error = handleError(e);
      notifyListeners();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> createBlog({
    required String title,
    required String content,
    String? imageUrl,
  }) async {
    _error = null;
    try {
      final blog = await _repo.createBlog(
        title: title,
        content: content,
        imageUrl: imageUrl,
      );
      _blogs = [blog, ..._blogs];
      notifyListeners();
      return true;
    } catch (e) {
      _error = handleError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteBlog(String id) async {
    try {
      await _repo.deleteBlog(id);
      _blogs = _blogs.where((b) => b.id != id).toList();
      if (_selectedBlog?.id == id) _selectedBlog = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = handleError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleLike(Blog blog) async {
    final idx = _blogs.indexWhere((b) => b.id == blog.id);

    // Оптимистичное обновление
    final optimistic = blog.isLikedByMe
        ? blog.copyWith(likes: blog.likes - 1, isLikedByMe: false)
        : blog.copyWith(likes: blog.likes + 1, isLikedByMe: true);

    if (idx != -1) _blogs[idx] = optimistic;
    if (_selectedBlog?.id == blog.id) _selectedBlog = optimistic;
    notifyListeners();

    try {
      final fromServer = await _repo.toggleLike(blog);
      if (idx != -1) _blogs[idx] = fromServer;
      if (_selectedBlog?.id == blog.id) _selectedBlog = fromServer;
      notifyListeners();
    } catch (e) {
      // Откат
      if (idx != -1) _blogs[idx] = blog;
      if (_selectedBlog?.id == blog.id) _selectedBlog = blog;
      _error = handleError(e);
      notifyListeners();
    }
  }

  Future<bool> addBlogComment({
    required String blogId,
    required String content,
  }) async {
    try {
      final comment = await _repo.addBlogComment(
        blogId: blogId,
        content: content,
      );
      _blogComments = [comment, ..._blogComments];

      // Обновляем счётчик
      final idx = _blogs.indexWhere((b) => b.id == blogId);
      if (idx != -1) {
        _blogs[idx] =
            _blogs[idx].copyWith(comments: _blogs[idx].comments + 1);
      }
      if (_selectedBlog?.id == blogId) {
        _selectedBlog = _selectedBlog!
            .copyWith(comments: _selectedBlog!.comments + 1);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = handleError(e);
      notifyListeners();
      return false;
    }
  }

  void startRealtimeFeed() {
    _realtimeChannel = _repo.subscribeToBlogFeed((_) => loadBlogs());
  }

  void stopRealtimeFeed() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
  }

  @override
  void dispose() {
    stopRealtimeFeed();
    super.dispose();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}