import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../repositories/book_repository.dart';

class BookProvider extends ChangeNotifier {
  final BookRepository _repo;

  // Ð¡Ð¿Ð¸ÑÐ¾Ðº ÐºÐ½Ð¸Ð³
  List<Book> _books = [];
  bool _loadingBooks = false;
  bool _hasMore = true;
  int _page = 0;
  String? _search;
  String? _category;

  // Ð”ÐµÑ‚Ð°Ð»ÑŒÐ½Ð°Ñ ÑÑ‚Ñ€Ð°Ð½Ð¸Ñ†Ð° ÐºÐ½Ð¸Ð³Ð¸
  Book? _selectedBook;
  bool _loadingBook = false;

  // ÐšÐ¾Ð¼Ð¼ÐµÐ½Ñ‚Ð°Ñ€Ð¸Ð¸
  List<BookComment> _comments = [];
  bool _loadingComments = false;

  // Ð—Ð°Ð¼ÐµÑ‚ÐºÐ¸
  List<UserNote> _notes = [];

  // ÐÐµÐ´Ð°Ð²Ð½Ð¾ Ñ‡Ð¸Ñ‚Ð°ÐµÐ¼Ñ‹Ðµ
  List<Map<String, dynamic>> _recentBooks = [];

  String? _error;

  // ---- Ð“ÐµÑ‚Ñ‚ÐµÑ€Ñ‹ ----
  List<Book> get books => _books;
  bool get loadingBooks => _loadingBooks;
  bool get hasMore => _hasMore;
  Book? get selectedBook => _selectedBook;
  bool get loadingBook => _loadingBook;
  List<BookComment> get comments => _comments;
  bool get loadingComments => _loadingComments;
  List<UserNote> get notes => _notes;
  List<Map<String, dynamic>> get recentBooks => _recentBooks;
  String? get error => _error;

  BookProvider(this._repo);

  // ---- Ð—Ð°Ð³Ñ€ÑƒÐ·ÐºÐ° Ð¿ÐµÑ€Ð²Ð¾Ð¹ ÑÑ‚Ñ€Ð°Ð½Ð¸Ñ†Ñ‹ ----
  Future<void> loadBooks({String? category, String? search}) async {
    _page = 0;
    _hasMore = true;
    _books = [];
    _category = category;
    _search = search;
    _loadingBooks = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _repo.getBooks(
        page: 0,
        category: category,
        search: search,
      );
      _books = result;
      _hasMore = result.length == 20;
      _page = 1;
    } catch (e) {
      _error = handleError(e);
    } finally {
      _loadingBooks = false;
      notifyListeners();
    }
  }

  // ---- Ð—Ð°Ð³Ñ€ÑƒÐ·ÐºÐ° ÑÐ»ÐµÐ´ÑƒÑŽÑ‰ÐµÐ¹ ÑÑ‚Ñ€Ð°Ð½Ð¸Ñ†Ñ‹ ----
  Future<void> loadMore() async {
    if (!_hasMore || _loadingBooks) return;

    _loadingBooks = true;
    notifyListeners();

    try {
      final result = await _repo.getBooks(
        page: _page,
        category: _category,
        search: _search,
      );
      _books = [..._books, ...result];
      _hasMore = result.length == 20;
      _page++;
    } catch (e) {
      _error = handleError(e);
    } finally {
      _loadingBooks = false;
      notifyListeners();
    }
  }

  // ---- ÐŸÐ¾Ð¸ÑÐº ----
  Future<void> search(String query) => loadBooks(search: query);

  // ---- Ð’Ñ‹Ð±Ð¾Ñ€ ÐºÐ½Ð¸Ð³Ð¸ ----
  Future<void> selectBook(String id) async {
    // ÐŸÐ¾ÐºÐ°Ð·Ñ‹Ð²Ð°ÐµÐ¼ ÐºÑÑˆÐ¸Ñ€Ð¾Ð²Ð°Ð½Ð½ÑƒÑŽ Ð²ÐµÑ€ÑÐ¸ÑŽ Ð¼Ð³Ð½Ð¾Ð²ÐµÐ½Ð½Ð¾
    _selectedBook = _repo.getCached(id) ??
        _books.where((b) => b.id == id).firstOrNull;
    _loadingBook = true;
    _error = null;
    notifyListeners();

    try {
      _selectedBook = await _repo.getBook(id);
    } catch (e) {
      _error = handleError(e);
    } finally {
      _loadingBook = false;
      notifyListeners();
    }
  }

  // ---- ÐšÐ¾Ð¼Ð¼ÐµÐ½Ñ‚Ð°Ñ€Ð¸Ð¸ ----
  Future<void> loadComments(String bookId) async {
    _loadingComments = true;
    _error = null;
    notifyListeners();

    try {
      _comments = await _repo.getComments(bookId);
    } catch (e) {
      _error = handleError(e);
    } finally {
      _loadingComments = false;
      notifyListeners();
    }
  }

  Future<bool> addComment({
    required String bookId,
    required String content,
    int? rating,
  }) async {
    try {
      final comment = await _repo.addComment(
        bookId: bookId,
        content: content,
        rating: rating,
      );
      _comments = [comment, ..._comments];
      notifyListeners();
      return true;
    } catch (e) {
      _error = handleError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleCommentLike(BookComment comment) async {
    // ÐžÐ¿Ñ‚Ð¸Ð¼Ð¸ÑÑ‚Ð¸Ñ‡Ð½Ð¾Ðµ Ð¾Ð±Ð½Ð¾Ð²Ð»ÐµÐ½Ð¸Ðµ
    final idx = _comments.indexWhere((c) => c.id == comment.id);
    if (idx == -1) return;

    final updated = comment.isLikedByMe
        ? comment.copyWith(
        likesCount: comment.likesCount - 1, isLikedByMe: false)
        : comment.copyWith(
        likesCount: comment.likesCount + 1, isLikedByMe: true);

    _comments[idx] = updated;
    notifyListeners();

    try {
      final fromServer = await _repo.toggleCommentLike(comment);
      _comments[idx] = fromServer;
      notifyListeners();
    } catch (e) {
      // ÐžÑ‚ÐºÐ°Ñ‚ Ð¿Ñ€Ð¸ Ð¾ÑˆÐ¸Ð±ÐºÐµ
      _comments[idx] = comment;
      _error = handleError(e);
      notifyListeners();
    }
  }

  // ---- Ð—Ð°Ð¼ÐµÑ‚ÐºÐ¸ ----
  Future<void> loadNotes(String bookId) async {
    try {
      _notes = await _repo.getNotes(bookId);
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> addNote({
    required String bookId,
    required int pageIndex,
    required String content,
    String colorHex = '#FFFF00',
  }) async {
    try {
      final note = await _repo.addNote(
        bookId: bookId,
        pageIndex: pageIndex,
        content: content,
        colorHex: colorHex,
      );
      _notes = [..._notes, note];
      notifyListeners();
      return true;
    } catch (e) {
      _error = handleError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteNote(String noteId) async {
    try {
      await _repo.deleteNote(noteId);
      _notes = _notes.where((n) => n.id != noteId).toList();
      notifyListeners();
    } catch (e) {
      _error = handleError(e);
      notifyListeners();
    }
  }

  // ---- ÐŸÑ€Ð¾Ð³Ñ€ÐµÑÑ Ñ‡Ñ‚ÐµÐ½Ð¸Ñ ----
  Future<void> saveProgress(String bookId, int percent) async {
    try {
      await _repo.saveProgress(bookId: bookId, progressPercent: percent);
    } catch (_) {}
  }

  // ---- ÐÐµÐ´Ð°Ð²Ð½Ð¸Ðµ ÐºÐ½Ð¸Ð³Ð¸ ----
  Future<void> loadRecentBooks() async {
    try {
      _recentBooks = await _repo.getRecentBooks();
      notifyListeners();
    } catch (_) {}
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}