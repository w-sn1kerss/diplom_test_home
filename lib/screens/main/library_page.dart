import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Добавил для доступа к Auth и DB
import '../../services/book_service.dart';
import '../../models/book_model.dart';
import '../../services/supabase_comments_service.dart';
import '../reader/book_reader_screen.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> with SingleTickerProviderStateMixin {
  final BookService _bookService = BookService();
  final _supabase = Supabase.instance.client;

  late TabController _tabController;

  List<Book> _books = [];
  List<Book> _downloadedBooks = [];
  List<String> _downloadedIds = [];
  List<String> _recentIds = []; // Для сортировки "Недавние"

  // Фильтры
  String _selectedGenre = 'Все жанры';
  List<String> _availableGenres = ['Все жанры'];
  String _sortBy = 'Недавние'; // Для "Моих книг"

  bool _isLoading = true;
  String _searchQuery = '';
  bool _isGridView = true;

  final Color _bgOffWhite = const Color(0xFFF8F9FB);
  final Color _textPrimary = const Color(0xFF1A1A1A);
  final Color _accentColor = const Color(0xFFFF5722);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Выполняем запросы параллельно для скорости
      final results = await Future.wait<dynamic>([
        _supabase.from('user_downloads').select('book_id, books(*)').eq('user_id', userId),
        _bookService.getBooks(),
      ]);

      final downloadsRaw = results[0] as List;

      // ИСПРАВЛЕННЫЙ МАППИНГ ДЛЯ "МОИ КНИГИ"
      final List<Book> downloaded = downloadsRaw.where((d) => d['books'] != null).map((d) {
        final b = d['books'] as Map<String, dynamic>;
        return Book(
          id: b['id'].toString(),
          title: b['title'] ?? 'Без названия',
          author: b['author'] ?? 'Неизвестный автор',
          coverUrl: b['cover_url'] ?? '', // ТЕПЕРЬ ТУТ КАРТИНКА (из новой БД)
          fileUrl: b['file_url'] ?? '',   // ТЕПЕРЬ ТУТ ФАЙЛ (из новой БД)
          description: b['description'] ?? '',
          pages: (b['pages'] as num?)?.toInt() ?? 0,
          categories: b['categories'] != null ? List<String>.from(b['categories']) : [],
          rating: (b['rating'] ?? 0).toDouble(), // Не забудь про рейтинг, если он есть в модели
        );
      }).toList();

      final allBooks = results[1] as List<Book>;

      final Set<String> genreSet = {'Все жанры'};
      for (var book in allBooks) {
        genreSet.addAll(book.categories);
      }

      if (mounted) {
        setState(() {
          _downloadedBooks = downloaded;
          _downloadedIds = downloaded.map((b) => b.id).toList();
          _books = allBooks;
          _availableGenres = genreSet.toList()..sort();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // МЕТОД, КОТОРЫЙ ПРОПАЛ
  void _handleBookOpen(Book book) async {
    // Локально обновляем "недавние" для сортировки
    setState(() {
      _recentIds.remove(book.id);
      _recentIds.insert(0, book.id);
    });

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookReaderScreen(book: book)),
    );

    // Обязательно вызываем обновление, так как пользователь
    // мог скачать или удалить книгу внутри BookReaderScreen
    _loadData();
  }

  // ФИЛЬТРАЦИЯ ДЛЯ "МОИ КНИГИ" (Сортировка)
  List<Book> _applyMyBooksFilters(List<Book> list) {
    List<Book> filtered = list.where((b) =>
    b.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        b.author.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    if (_sortBy == 'Название') {
      filtered.sort((a, b) => a.title.compareTo(b.title));
    } else if (_sortBy == 'Недавние') {
      filtered.sort((a, b) {
        int indexA = _recentIds.indexOf(a.id);
        int indexB = _recentIds.indexOf(b.id);
        if (indexA == -1 && indexB == -1) return 0;
        if (indexA == -1) return 1;
        if (indexB == -1) return -1;
        return indexA.compareTo(indexB);
      });
    }
    return filtered;
  }

  // ФИЛЬТРАЦИЯ ДЛЯ "КАТАЛОГ" (Жанры)
  List<Book> _applyCatalogFilters(List<Book> list) {
    return list.where((b) {
      final matchesSearch = b.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          b.author.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesGenre = _selectedGenre == 'Все жанры' || b.categories.contains(_selectedGenre);
      return matchesSearch && matchesGenre;
    }).toList();
  }

  void _showSortOrGenrePicker() {
    bool isCatalog = _tabController.index == 1;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isCatalog ? "Выберите жанр" : "Сортировка",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: (isCatalog ? _availableGenres : ['Недавние', 'Название']).map((option) => ListTile(
                    title: Text(option, style: TextStyle(
                      fontWeight: (isCatalog ? _selectedGenre : _sortBy) == option ? FontWeight.w900 : FontWeight.w500,
                      color: (isCatalog ? _selectedGenre : _sortBy) == option ? _accentColor : _textPrimary,
                    )),
                    onTap: () {
                      setState(() {
                        if (isCatalog) _selectedGenre = option; else _sortBy = option;
                      });
                      Navigator.pop(context);
                    },
                  )).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final myBooks = _applyMyBooksFilters(_downloadedBooks);
    final catalogBooks = _applyCatalogFilters(
        _books.where((b) => !_downloadedIds.contains(b.id.toString())).toList()
    );

    return Scaffold(
      backgroundColor: _bgOffWhite,
      appBar: AppBar(
        backgroundColor: _bgOffWhite,
        elevation: 0,
        centerTitle: true,
        title: Text('Библиотека', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w800, fontSize: 20)),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_agenda_outlined : Icons.grid_view_rounded),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _accentColor,
          labelColor: _textPrimary,
          tabs: const [Tab(text: 'Мои книги'), Tab(text: 'Каталог')],
          onTap: (index) => setState(() {}), // Обновляем UI для кнопки фильтра/сортировки
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _accentColor))
          : Column(
        children: [
          _buildSearchRow(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBookDisplay(myBooks),
                _buildBookDisplay(catalogBooks),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchRow() {
    bool isCatalog = _tabController.index == 1;
    String currentLabel = isCatalog ? _selectedGenre : _sortBy;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(10)),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: const InputDecoration(hintText: 'Поиск...', border: InputBorder.none, icon: Icon(Icons.search, size: 18)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: _showSortOrGenrePicker,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black.withOpacity(0.05)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 70),
                    child: Text(currentLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  ),
                  const Icon(Icons.filter_list_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookDisplay(List<Book> books) {
    if (books.isEmpty) return Center(child: Text(_searchQuery.isEmpty ? 'Здесь пока ничего нет' : 'Ничего не найдено'));
    return _isGridView
        ? GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 16, mainAxisSpacing: 24, childAspectRatio: 0.58),
      itemCount: books.length,
      itemBuilder: (context, i) => _BookGridTile(book: books[i], onOpen: () => _handleBookOpen(books[i])),
    )
        : ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: books.length,
      itemBuilder: (context, i) => _BookListTile(book: books[i], onOpen: () => _handleBookOpen(books[i])),
    );
  }
}

// Виджеты плиток (без изменений, добавлены для полноты кода)
class _BookGridTile extends StatelessWidget {
  final Book book;
  final VoidCallback onOpen;
  const _BookGridTile({required this.book, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    book.coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(color: Colors.grey[300], child: const Icon(Icons.book)),
                  )
              )
          ),
          const SizedBox(height: 8),
          Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text(book.author, maxLines: 1, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }
}

class _BookListTile extends StatelessWidget {
  final Book book;
  final VoidCallback onOpen;
  const _BookListTile({required this.book, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  book.coverUrl,
                  width: 60, height: 85,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(width: 60, height: 85, color: Colors.grey[300], child: const Icon(Icons.book)),
                )
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(book.author, style: const TextStyle(color: Colors.deepOrange, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(book.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}