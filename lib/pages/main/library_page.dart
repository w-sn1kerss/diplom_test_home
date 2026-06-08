import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/book.dart';
import '../../providers/book_provider.dart';
import '../reader/book_reader_screen.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  static const _accent = Color(0xFFFF5722);
  static const _bg = Color(0xFFF8F9FB);

  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String? _selectedCategory;

  static const _categories = [
    'Все',
    'Фантастика',
    'Роман',
    'Детектив',
    'Наука',
    'История',
    'Психология',
    'Бизнес',
    'Саморазвитие',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookProvider>().loadBooks();
    });

    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 300) {
      context.read<BookProvider>().loadMore();
    }
  }

  void _applyFilter(String? category) {
    setState(() => _selectedCategory = (category == 'Все') ? null : category);
    context.read<BookProvider>().loadBooks(
      category: _selectedCategory,
      search: _searchCtrl.text.trim().isEmpty
          ? null
          : _searchCtrl.text.trim(),
    );
  }

  void _onSearchSubmit(String query) {
    context.read<BookProvider>().loadBooks(
      search: query.trim().isEmpty ? null : query.trim(),
      category: _selectedCategory,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text('Библиотека',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Поиск
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: _onSearchSubmit,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Поиск...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchCtrl.clear();
                    _onSearchSubmit('');
                  },
                )
                    : null,
                filled: true,
                fillColor: const Color(0xFFEDF0F4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Категории
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final isSelected = (cat == 'Все' && _selectedCategory == null) ||
                    cat == _selectedCategory;
                return GestureDetector(
                  onTap: () => _applyFilter(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? _accent : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isSelected
                              ? _accent
                              : Colors.black.withOpacity(0.08)),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Список книг
          Expanded(
            child: Consumer<BookProvider>(
              builder: (_, prov, __) {
                if (prov.loadingBooks && prov.books.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (prov.books.isEmpty) {
                  return const Center(child: Text('Книги не найдены'));
                }

                return GridView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.6,
                  ),
                  itemCount:
                  prov.books.length + (prov.hasMore ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i >= prov.books.length) {
                      return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ));
                    }
                    return _BookCard(
                      book: prov.books[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              BookReaderScreen(book: prov.books[i]),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;

  const _BookCard({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Обложка
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: (book.coverUrl?.isNotEmpty == true)
                  ? Image.network(
                book.coverUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
                  : _placeholder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          Text(
            book.author ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black45, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.star_rounded,
                  color: Color(0xFFFF5722), size: 14),
              const SizedBox(width: 2),
              Text(book.rating.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFE5E9EF),
    child: const Center(child: Icon(Icons.book, color: Colors.black26)),
  );
}