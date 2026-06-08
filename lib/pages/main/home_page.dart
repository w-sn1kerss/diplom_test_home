import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/book_service.dart';
import '../../models/book.dart';
import '../reader/book_reader_screen.dart';
import '../users/blog_details_screen.dart';
import 'library_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _supabase = Supabase.instance.client;
  final BookService _bookService = BookService();

  List<Book> _continueReading = [];
  List<Book> _recommendations = [];
  List<Book> _popularBooks = [];
  List<Map<String, dynamic>> _blogs = [];
  bool _isLoading = true;

  final Color _bgColor = const Color(0xFFF8F9FB);
  final Color _onBgTextColor = const Color(0xFF1A1A1A);
  final Color _inputBgColor = const Color(0xFFEDF0F4);
  final Color _cardBgColor = const Color(0xFFE5E9EF);
  final Color _accentColor = const Color(0xFFFF5722);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 1. Загружаем скачанные книги ("Мои книги")
      final downloadsRaw = await _supabase
          .from('user_downloads')
          .select('books(*)')
          .eq('user_id', userId)
          .order('downloaded_at', ascending: false)
          .limit(5);

      final List<Book> loadedDownloads = [];
      if (downloadsRaw != null) {
        for (var item in (downloadsRaw as List)) {
          final b = item['books'];
          if (b != null) {
            loadedDownloads.add(Book(
              id: b['id'].toString(),
              title: b['title'] ?? 'Без названия',
              author: b['author'] ?? 'Неизвестен',
              coverUrl: b['cover_url'] ?? '',
              fileUrl: b['file_url'] ?? '',
              description: b['description'] ?? '',
              // Теперь это поле будет приходить из БД благодаря триггеру
              rating: (b['rating'] ?? 0.0).toDouble(),
              categories: List<String>.from(b['categories'] ?? []),
              pages: (b['pages'] as num?)?.toInt() ?? 0,
            ));
          }
        }
      }

      // 2. Получаем все книги (в BookService метод getBooks тоже должен читать rating)
      final allBooks = await _bookService.getBooks();

      // 3. Загружаем блоги
      final blogsRaw = await _supabase
          .from('blogs')
          .select('*, profiles(username, avatar_url)')
          .order('created_at', ascending: false)
          .limit(5);

      if (mounted) {
        setState(() {
          _continueReading = loadedDownloads;

          // ЛОГИКА РЕКОМЕНДАЦИЙ (Сортировка по рейтингу)
          if (_continueReading.isNotEmpty) {
            final myCats = _continueReading.expand((b) => b.categories).toSet();
            _recommendations = allBooks
                .where((b) => b.categories.any((c) => myCats.contains(c)))
                .where((b) => !_continueReading.any((cr) => cr.id == b.id))
                .toList();
          } else {
            _recommendations = List.from(allBooks);
          }
          // Сортируем: сначала самые высокие оценки
          _recommendations.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
          _recommendations = _recommendations.take(6).toList();

          // --- САМОЕ ПОПУЛЯРНОЕ: ТРИ КНИГИ С ЛУЧШИМ РЕЙТИНГОМ ---
          _popularBooks = List<Book>.from(allBooks);
          _popularBooks.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
          _popularBooks = _popularBooks.take(3).toList();

          _blogs = List<Map<String, dynamic>>.from(blogsRaw as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openBook(Book book) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => BookReaderScreen(book: book)));
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _accentColor, strokeWidth: 2))
          : SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: _accentColor,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildContinueReadingList(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 35),
                      _buildSectionHeader('Рекомендации', 'Библиотека',
                          onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LibraryPage()))),
                      const SizedBox(height: 16),
                      _buildHorizontalGrid(),
                      const SizedBox(height: 35),
                      _buildSectionHeader('Самое популярное', ''),
                      const SizedBox(height: 16),
                      _buildPopularVerticalList(),
                      const SizedBox(height: 35),
                      _buildSectionHeader('Блоги сообщества', ''),
                      const SizedBox(height: 16),
                      _buildBlogsList(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text('Найди книгу', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _onBgTextColor)),
          const SizedBox(height: 20),
          _buildSearchField(),
          if (_continueReading.isNotEmpty) ...[
            const SizedBox(height: 30),
            _buildSectionHeader('Продолжить чтение', ''),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 50,
      decoration: BoxDecoration(color: _inputBgColor, borderRadius: BorderRadius.circular(14)),
      child: const Row(
        children: [
          Icon(Icons.search_rounded, color: Colors.black45, size: 22),
          SizedBox(width: 12),
          Text('Поиск книг...', style: TextStyle(color: Colors.black38, fontSize: 15, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String action, {VoidCallback? onAction}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _onBgTextColor)),
        if (action.isNotEmpty)
          GestureDetector(
            onTap: onAction,
            child: Text(action, style: TextStyle(color: _accentColor, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
      ],
    );
  }

  Widget _buildCover(String? url, {double width = 115, double height = 160}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: (url != null && url.isNotEmpty)
          ? Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        // Добавляем кэширование или лоадер, чтобы не моргало
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : Container(width: width, height: height, color: _cardBgColor, child: const Center(child: CircularProgressIndicator(strokeWidth: 1))),
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(width, height),
      )
          : _buildPlaceholder(width, height),
    );
  }

  Widget _buildPlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: _cardBgColor,
      child: const Icon(Icons.book, color: Colors.black26),
    );
  }

  Widget _buildContinueReadingList() {
    if (_continueReading.isEmpty) return const SizedBox();
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _continueReading.length,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemBuilder: (context, i) {
          final book = _continueReading[i];
          return GestureDetector(
            onTap: () => _openBook(book),
            child: Container(
              width: 260,
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _cardBgColor, borderRadius: BorderRadius.circular(18)),
              child: Row(
                children: [
                  _buildCover(book.coverUrl, width: 60, height: 86),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        Text(book.author, maxLines: 1, style: TextStyle(color: _onBgTextColor.withOpacity(0.5), fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHorizontalGrid() {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _recommendations.length,
        itemBuilder: (context, i) {
          final book = _recommendations[i];
          return GestureDetector(
            onTap: () => _openBook(book),
            child: Container(
              width: 115,
              margin: const EdgeInsets.only(right: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      _buildCover(book.coverUrl),
                      Positioned(top: 8, left: 8, child: _buildRatingBadge(book.rating)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(book.author, maxLines: 1, style: const TextStyle(color: Colors.black45, fontSize: 11)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPopularVerticalList() {
    return Column(
      children: _popularBooks.asMap().entries.map((entry) {
        return _buildListTileCard(
          index: entry.key + 1,
          title: entry.value.title,
          subtitle: entry.value.author,
          image: entry.value.coverUrl,
          rating: entry.value.rating,
          showRating: true,
          onTap: () => _openBook(entry.value),
        );
      }).toList(),
    );
  }

  Widget _buildBlogsList() {
    return Column(
      children: _blogs.map((blog) {
        final profile = blog['profiles'] as Map<String, dynamic>?;
        return _buildListTileCard(
          index: _blogs.indexOf(blog) + 1,
          title: blog['title'] ?? 'Без названия',
          subtitle: profile?['username'] ?? 'Автор',
          image: blog['image_url'],
          rating: 0,
          showRating: false, // УБРАЛИ ОЦЕНКИ
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => BlogDetailScreen(
              blog: blog,
              userData: profile,
              isOwnProfile: blog['user_id'] == _supabase.auth.currentUser?.id,
              onUpdate: _loadData,
            )));
          },
        );
      }).toList(),
    );
  }

  Widget _buildListTileCard({required int index, required String title, required String subtitle, String? image, required double rating, required bool showRating, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
            border: Border.all(color: Colors.black.withOpacity(0.03))
        ),
        child: Row(
          children: [
            Text('$index', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _onBgTextColor.withOpacity(0.15))),
            const SizedBox(width: 16),
            if (image != null) ...[
              _buildCover(image, width: 45, height: 60),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(subtitle, style: const TextStyle(color: Colors.black45, fontSize: 12)),
                ],
              ),
            ),
            if (showRating) _buildMiniRating(rating),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBadge(double rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: _accentColor, size: 12),
          const SizedBox(width: 2),
          // Если 0.0 — значит отзывов еще нет, но показываем цифру
          Text(
              rating.toStringAsFixed(1),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)
          ),
        ],
      ),
    );
  }

  Widget _buildMiniRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, color: _accentColor, size: 16),
        const SizedBox(width: 4),
        Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
        ),
      ],
    );
  }
}