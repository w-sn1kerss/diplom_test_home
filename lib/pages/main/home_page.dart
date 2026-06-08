// lib/pages/main/home_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../providers/book_provider.dart';
import '../../providers/blog_provider.dart';
import '../../providers/auth_provider.dart';
import '../reader/book_reader_screen.dart';
import '../users/blog_detail_page.dart';
import 'library_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _accent = Color(0xFFFF5722);
  static const _bg = Color(0xFFF8F9FB);
  static const _cardBg = Color(0xFFE5E9EF);
  static const _inputBg = Color(0xFFEDF0F4);
  static const _textPrimary = Color(0xFF1A1A1A);

  List<Book> _continueReading = [];
  bool _isLoadingContinue = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final bookProvider = context.read<BookProvider>();
    final blogProvider = context.read<BlogProvider>();

    await Future.wait([
      if (bookProvider.books.isEmpty) bookProvider.loadBooks(),
      if (blogProvider.blogs.isEmpty) blogProvider.loadBlogs(),
      _loadContinueReading(),
    ]);
  }

  Future<void> _loadContinueReading() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoadingContinue = true);
    try {
      final raw = await Supabase.instance.client
          .from('user_recent_activity')
          .select('books(*)')
          .eq('user_id', userId)
          .order('last_viewed_at', ascending: false)
          .limit(5);

      final books = <Book>[];
      for (final item in raw as List) {
        final b = item['books'] as Map<String, dynamic>?;
        if (b != null) books.add(Book.fromJson(b));
      }
      if (mounted) setState(() => _continueReading = books);
    } catch (e) {
      debugPrint('continue reading error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingContinue = false);
    }
  }

  Future<void> _refresh() async {
    context.read<BookProvider>().loadBooks();
    context.read<BlogProvider>().loadBlogs();
    await _loadContinueReading();
  }

  void _openBook(Book book) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookReaderScreen(book: book)),
    ).then((_) => _loadContinueReading());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: _accent,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              if (_continueReading.isNotEmpty)
                SliverToBoxAdapter(child: _buildContinueReading()),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 28),
                    _buildSectionHeader(
                      'Рекомендации',
                      'Все книги',
                      onAction: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LibraryPage())),
                    ),
                    const SizedBox(height: 16),
                    _buildRecommendations(),
                    const SizedBox(height: 28),
                    _buildSectionHeader('Самое популярное', ''),
                    const SizedBox(height: 16),
                    _buildPopular(),
                    const SizedBox(height: 28),
                    _buildSectionHeader('Блоги сообщества', ''),
                    const SizedBox(height: 16),
                    _buildBlogs(),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Consumer<AuthProvider>(
            builder: (_, auth, __) {
              final name = auth.profile?.username ?? '';
              return Text(
                name.isEmpty ? 'Найди книгу' : 'Привет, $name 👋',
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: _textPrimary),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildSearchBar(),
          if (_continueReading.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionHeader('Продолжить чтение', ''),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () => showSearch(
          context: context,
          delegate: _BookSearchDelegate(context)),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            color: _inputBg,
            borderRadius: BorderRadius.circular(14)),
        child: const Row(
          children: [
            Icon(Icons.search_rounded, color: Colors.black45, size: 22),
            SizedBox(width: 12),
            Text('Поиск книг...',
                style: TextStyle(
                    color: Colors.black38,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueReading() {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _continueReading.length,
        itemBuilder: (_, i) {
          final book = _continueReading[i];
          return GestureDetector(
            onTap: () => _openBook(book),
            child: Container(
              width: 260,
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(18)),
              child: Row(
                children: [
                  _BookCover(url: book.coverUrl, width: 60, height: 86),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                        Text(book.author ?? '',
                            maxLines: 1,
                            style: TextStyle(
                                color: _textPrimary.withOpacity(0.5),
                                fontSize: 12)),
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

  Widget _buildRecommendations() {
    return Consumer<BookProvider>(
      builder: (_, prov, __) {
        if (prov.loadingBooks && prov.books.isEmpty) {
          return const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()));
        }
        final readIds = _continueReading.map((b) => b.id).toSet();
        final recs = prov.books
            .where((b) => !readIds.contains(b.id))
            .toList()
          ..sort((a, b) => b.rating.compareTo(a.rating));
        final display = recs.take(6).toList();

        if (display.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: display.length,
            itemBuilder: (_, i) {
              final book = display[i];
              return GestureDetector(
                onTap: () => _openBook(book),
                child: Container(
                  width: 115,
                  margin: const EdgeInsets.only(right: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(children: [
                        _BookCover(url: book.coverUrl),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: _RatingBadge(rating: book.rating),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Text(book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      Text(book.author ?? '',
                          maxLines: 1,
                          style: const TextStyle(
                              color: Colors.black45, fontSize: 11)),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPopular() {
    return Consumer<BookProvider>(
      builder: (_, prov, __) {
        if (prov.loadingBooks && prov.books.isEmpty) {
          return const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()));
        }
        final popular = List<Book>.from(prov.books)
          ..sort((a, b) => b.rating.compareTo(a.rating));
        final display = popular.take(3).toList();

        return Column(
          children: display.asMap().entries.map((e) {
            return _ListTileCard(
              index: e.key + 1,
              title: e.value.title,
              subtitle: e.value.author ?? '',
              imageUrl: e.value.coverUrl,
              rating: e.value.rating,
              showRating: true,
              onTap: () => _openBook(e.value),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildBlogs() {
    return Consumer<BlogProvider>(
      builder: (_, prov, __) {
        if (prov.loading && prov.blogs.isEmpty) {
          return const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()));
        }
        final display = prov.blogs.take(5).toList();
        return Column(
          children: display.asMap().entries.map((e) {
            final blog = e.value;
            return _ListTileCard(
              index: e.key + 1,
              title: blog.title,
              subtitle: blog.author?.username ?? 'Автор',
              imageUrl: blog.imageUrl,
              rating: 0,
              showRating: false,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => BlogDetailPage(blog: blog)),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, String action,
      {VoidCallback? onAction}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _textPrimary)),
        if (action.isNotEmpty)
          GestureDetector(
            onTap: onAction,
            child: Text(action,
                style: const TextStyle(
                    color: _accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
      ],
    );
  }
}

// ─── Shared Widgets ──────────────────────────────────────────────────────────

class _BookCover extends StatelessWidget {
  final String? url;
  final double width;
  final double height;

  const _BookCover({this.url, this.width = 115, this.height = 160});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: (url != null && url!.isNotEmpty)
          ? Image.network(
        url!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : Container(
            width: width,
            height: height,
            color: const Color(0xFFE5E9EF),
            child: const Center(
                child: CircularProgressIndicator(strokeWidth: 1))),
        errorBuilder: (_, __, ___) => _placeholder(),
      )
          : _placeholder(),
    );
  }

  Widget _placeholder() => Container(
    width: width,
    height: height,
    color: const Color(0xFFE5E9EF),
    child: const Icon(Icons.book, color: Colors.black26),
  );
}

class _RatingBadge extends StatelessWidget {
  final double rating;
  const _RatingBadge({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded,
              color: Color(0xFFFF5722), size: 12),
          const SizedBox(width: 2),
          Text(rating.toStringAsFixed(1),
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ListTileCard extends StatelessWidget {
  final int index;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final double rating;
  final bool showRating;
  final VoidCallback onTap;

  const _ListTileCard({
    required this.index,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    required this.rating,
    required this.showRating,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02), blurRadius: 10)
          ],
          border:
          Border.all(color: Colors.black.withOpacity(0.03)),
        ),
        child: Row(
          children: [
            Text('$index',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1A1A1A).withOpacity(0.15))),
            const SizedBox(width: 16),
            if (imageUrl != null) ...[
              _BookCover(url: imageUrl, width: 45, height: 60),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.black45, fontSize: 12)),
                ],
              ),
            ),
            if (showRating)
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.star_rounded,
                    color: Color(0xFFFF5722), size: 16),
                const SizedBox(width: 4),
                Text(rating.toStringAsFixed(1),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
          ],
        ),
      ),
    );
  }
}

// ─── Search Delegate ─────────────────────────────────────────────────────────

class _BookSearchDelegate extends SearchDelegate<Book?> {
  final BuildContext _ctx;
  _BookSearchDelegate(this._ctx);

  @override
  String get searchFieldLabel => 'Название, автор...';

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          }),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) {
    _ctx.read<BookProvider>().loadBooks(search: query.trim());
    return Consumer<BookProvider>(
      builder: (_, prov, __) {
        if (prov.loadingBooks) {
          return const Center(child: CircularProgressIndicator());
        }
        if (prov.books.isEmpty) {
          return const Center(child: Text('Ничего не найдено'));
        }
        return ListView.builder(
          itemCount: prov.books.length,
          itemBuilder: (_, i) {
            final book = prov.books[i];
            return ListTile(
              leading: _BookCover(url: book.coverUrl, width: 40, height: 56),
              title: Text(book.title),
              subtitle: Text(book.author ?? ''),
              onTap: () {
                close(context, book);
                Navigator.push(
                  _ctx,
                  MaterialPageRoute(
                      builder: (_) => BookReaderScreen(book: book)),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);
}