import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../repositories/blog_repository.dart';


class BlogProvider extends ChangeNotifier {
  final BlogRepository _repo;

  List<Blog> _blogs = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 0;
  String? _error;

  // Ð”Ð»Ñ Ð´ÐµÑ‚Ð°Ð»ÑŒÐ½Ð¾Ð¹ ÑÑ‚Ñ€Ð°Ð½Ð¸Ñ†Ñ‹
  Blog? _selectedBlog;
  List<Map<String, dynamic>> _blogComments = [];

  RealtimeChannel? _realtimeChannel;

  // ---- Ð“ÐµÑ‚Ñ‚ÐµÑ€Ñ‹ ----
  List<Blog> get blogs => _blogs;
  bool get loading => _loading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  Blog? get selectedBlog => _selectedBlog;
  List<Map<String, dynamic>> get blogComments => _blogComments;

  BlogProvider(this._repo);

  // ---- Ð—Ð°Ð³Ñ€ÑƒÐ·ÐºÐ° Ð»ÐµÐ½Ñ‚Ñ‹ ----
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
      final result = await _repo.getBlogs(page: _page, authorId: authorId);
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

  // ---- Ð’Ñ‹Ð±Ð¾Ñ€ Ð±Ð»Ð¾Ð³Ð° ----
  Future<void> selectBlog(String id) async {
    // ÐŸÐ¾ÐºÐ°Ð·Ñ‹Ð²Ð°ÐµÐ¼ Ð¸Ð· ÑÐ¿Ð¸ÑÐºÐ° Ð¼Ð³Ð½Ð¾Ð²ÐµÐ½Ð½Ð¾ Ð¿Ð¾ÐºÐ° Ð³Ñ€ÑƒÐ·Ð¸Ð¼ Ð¿Ð¾Ð»Ð½ÑƒÑŽ Ð²ÐµÑ€ÑÐ¸ÑŽ
    _selectedBlog = _blogs.where((b) => b.id == id).firstOrNull;
    _blogComments = [];
    notifyListeners();

    try {
      final results = await Future.wait([
        _repo.getBlog(id),
        _repo.getBlogComments(id),
      ]);
      _selectedBlog = results[0] as Blog;
      _blogComments =
          (results[1] as List).cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      _error = handleError(e);
      notifyListeners();
    }
  }

  // ---- Ð¡Ð¾Ð·Ð´Ð°Ñ‚ÑŒ Ð±Ð»Ð¾Ð³ ----
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

  // ---- Ð£Ð´Ð°Ð»Ð¸Ñ‚ÑŒ Ð±Ð»Ð¾Ð³ ----
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

  // ---- Ð›Ð°Ð¹Ðº (Ð¾Ð¿Ñ‚Ð¸Ð¼Ð¸ÑÑ‚Ð¸Ñ‡Ð½Ð¾Ðµ Ð¾Ð±Ð½Ð¾Ð²Ð»ÐµÐ½Ð¸Ðµ) ----
  Future<void> toggleLike(Blog blog) async {
    // ÐœÐ³Ð½Ð¾Ð²ÐµÐ½Ð½Ð¾ Ð¾Ð±Ð½Ð¾Ð²Ð»ÑÐµÐ¼ UI
    final idx = _blogs.indexWhere((b) => b.id == blog.id);
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
      // ÐžÑ‚ÐºÐ°Ñ‚
      if (idx != -1) _blogs[idx] = blog;
      if (_selectedBlog?.id == blog.id) _selectedBlog = blog;
      _error = handleError(e);
      notifyListeners();
    }
  }

  // ---- ÐšÐ¾Ð¼Ð¼ÐµÐ½Ñ‚Ð°Ñ€Ð¸Ð¹ Ðº Ð±Ð»Ð¾Ð³Ñƒ ----
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

      // ÐžÐ±Ð½Ð¾Ð²Ð»ÑÐµÐ¼ ÑÑ‡Ñ‘Ñ‚Ñ‡Ð¸Ðº
      final idx = _blogs.indexWhere((b) => b.id == blogId);
      if (idx != -1) {
        _blogs[idx] = _blogs[idx].copyWith(
          comments: _blogs[idx].comments + 1,
        );
      }
      if (_selectedBlog?.id == blogId) {
        _selectedBlog = _selectedBlog!.copyWith(
          comments: _selectedBlog!.comments + 1,
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = handleError(e);
      notifyListeners();
      return false;
    }
  }

  // ---- Realtime Ð¿Ð¾Ð´Ð¿Ð¸ÑÐºÐ° ----
  void startRealtimeFeed() {
    _realtimeChannel = _repo.subscribeToBlogFeed((newBlogData) {
      // ÐŸÐµÑ€ÐµÐ·Ð°Ð³Ñ€ÑƒÐ¶Ð°ÐµÐ¼ ÐºÐ¾Ð³Ð´Ð° Ð¿Ð¾ÑÐ²Ð¸Ð»ÑÑ Ð½Ð¾Ð²Ñ‹Ð¹ Ð±Ð»Ð¾Ð³
      loadBlogs();
    });
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