// lib/providers/book_provider.dart
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../repositories/book_repository.dart';
import '../utils/utils.dart';

class BookProvider extends ChangeNotifier {
  final BookRepository _repo;

  List<Book> _books = [];
  bool _loadingBooks = false;
  bool _hasMore = true;
  int _page = 0;
  String? _search;
  String? _category;

  Book? _selectedBook;
  bool _loadingBook = false;

  List<BookComment> _comments = [];
  bool _loadingComments = false;

  List<UserNote> _notes = [];
  List<Map<String, dynamic>> _recentBooks = [];

  String? _error;

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

  Future<void> search(String query) => loadBooks(search: query);

  Future<void> selectBook(String id) async {
    _selectedBook =
        _repo.getCached(id) ?? _books.where((b) => b.id == id).firstOrNull;
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
    final idx = _comments.indexWhere((c) => c.id == comment.id);
    if (idx == -1) return;

    // Оптимистичное обновление
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
      _comments[idx] = comment; // Откат
      _error = handleError(e);
      notifyListeners();
    }
  }

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

  Future<void> saveProgress(String bookId, int percent) async {
    try {
      await _repo.saveProgress(bookId: bookId, progressPercent: percent);
    } catch (_) {}
  }

  Future<void> loadRecentBooks() async {
    try {
      _recentBooks = await _repo.getRecentBooks();
      notifyListeners();
    } catch (_) {}
  }

  void sortBooks(String criteria) {
    if (criteria == 'rating') {
      _books.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (criteria == 'title') {
      _books.sort((a, b) => a.title.compareTo(b.title));
    }
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}