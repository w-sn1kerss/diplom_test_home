import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../reader/book_reader_screen.dart'; // Путь к экрану чтения/обзора книги
import '../../models/book_model.dart'; // Твоя модель книги

class UserItemsListScreen extends StatefulWidget {
  final String title;
  final String userId;
  final String tableName;

  const UserItemsListScreen({
    super.key,
    required this.title,
    required this.userId,
    required this.tableName,
  });

  @override
  State<UserItemsListScreen> createState() => _UserItemsListScreenState();
}

class _UserItemsListScreenState extends State<UserItemsListScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _items = [];

  // Цвета из BookReaderScreen для единообразия
  final Color _textSecondary = const Color(0xFF666666);
  final Color _accentColor = const Color(0xFFFF5722);
  final Color _chipBg = const Color(0xFFE1E5EB);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // Безопасная загрузка картинок
  ImageProvider? _getSafeImage(String? url) {
    if (url == null || url.isEmpty || !url.startsWith('http') || url.contains('%F0%9F%91%A4')) {
      return null;
    }
    return NetworkImage(url);
  }

  Future<void> _fetchData() async {
    try {
      dynamic query;
      if (widget.tableName == 'user_recent_activity') {
        query = _supabase.from('user_recent_activity').select('*, books(*)').eq('user_id', widget.userId);
      } else if (widget.tableName == 'user_achievements') {
        query = _supabase.from('user_achievements').select('*, achievements(*)').eq('user_id', widget.userId);
      } else if (widget.tableName == 'book_comments') {
        // Загружаем полные данные книги для перехода
        query = _supabase.from('book_comments').select('*, books(*)').eq('user_id', widget.userId);
      }

      final data = await query;
      if (mounted) setState(() { _items = data; _isLoading = false; });
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB), // Светлый фон как в обзоре
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.title, style: GoogleFonts.manrope(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _items.isEmpty ? _buildEmptyState() : _buildList(),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      itemCount: _items.length,
      separatorBuilder: (context, index) => widget.tableName == 'book_comments'
          ? const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE))
          : const SizedBox(height: 15),
      itemBuilder: (context, index) {
        final item = _items[index];
        if (widget.tableName == 'user_recent_activity') return _buildBookCard(item);
        if (widget.tableName == 'user_achievements') return _buildAchievementCard(item);
        if (widget.tableName == 'book_comments') return _buildReviewCard(item);
        return const SizedBox();
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.blueGrey.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text("Пока здесь пусто",
              style: GoogleFonts.manrope(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // --- КАРТОЧКИ ---

  // 1. Карточка книги (для раздела Read)
  Widget _buildBookCard(Map<String, dynamic> item) {
    final book = item['books'];
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(
              book['cover_url'] ?? '',
              width: 70,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(width: 70, height: 100, color: Colors.grey[200]),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book['title'] ?? 'Без названия',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(book['author'] ?? 'Автор неизвестен',
                    style: GoogleFonts.manrope(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: (item['progress_percent'] ?? 0) / 100,
                  backgroundColor: Colors.grey[100],
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. Карточка достижения (для раздела Badges)
  Widget _buildAchievementCard(Map<String, dynamic> item) {
    final achievement = item['achievements'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emoji_events, color: Colors.orange, size: 30),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(achievement['title'] ?? 'Награда',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(achievement['description'] ?? '',
                    style: GoogleFonts.manrope(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3. Карточка отзыва (для раздела Reviews)
  Widget _buildReviewCard(Map<String, dynamic> item) {
    final bookData = item['books'];
    final double rating = (item['rating'] ?? 0).toDouble();

    return GestureDetector(
      onTap: () {
        if (bookData != null) {
          final book = Book(
            id: bookData['id'].toString(),
            title: bookData['title'] ?? '',
            author: bookData['author'] ?? '',
            // ИСПРАВЛЕНО: используем правильные ключи cover_url и file_url
            coverUrl: bookData['cover_url'] ?? '',
            fileUrl: bookData['file_url'] ?? '',
            description: bookData['description'] ?? '',
            pages: (bookData['pages'] as num?)?.toInt() ?? 0,
            categories: List<String>.from(bookData['categories'] ?? []),
          );
          Navigator.push(context, MaterialPageRoute(builder: (_) => BookReaderScreen(book: book)));
        }
      },
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    // ИСПРАВЛЕНО: ключ должен быть cover_url, а не book_url
                    bookData?['cover_url'] ?? '',
                    width: 40, height: 55, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        width: 40,
                        height: 55,
                        color: _chipBg,
                        child: const Icon(Icons.book, size: 20, color: Colors.grey)
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bookData?['title'] ?? 'Книга',
                          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 15),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: List.generate(5, (i) => Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: i < rating ? Colors.amber : _chipBg,
                        )),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _textSecondary.withOpacity(0.5)),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              item['content'] ?? '',
              style: GoogleFonts.manrope(color: Colors.black87, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 12),
            Text(
              "Отзыв от ${_formatDate(item['created_at'])}",
              style: GoogleFonts.manrope(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return "";
    final date = DateTime.parse(dateStr);
    return "${date.day}.${date.month}.${date.year}";
  }
}