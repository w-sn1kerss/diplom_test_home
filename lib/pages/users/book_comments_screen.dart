import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Добавьте provider
import '../../models/models.dart'; // Здесь лежит ваш BookComment
import '../../providers/auth_provider.dart';
import '../../repositories/book_repository.dart'; // Ваш основной репозиторий

class BookCommentsScreen extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final String? bookCoverUrl;

  const BookCommentsScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
    this.bookCoverUrl,
  });

  @override
  State<BookCommentsScreen> createState() => _BookCommentsScreenState();
}

class _BookCommentsScreenState extends State<BookCommentsScreen> {
  final _textController = TextEditingController();
  int _selectedRating = 0;
  bool _isLoading = true;
  bool _isPosting = false;

  final Color _accentColor = const Color(0xFFE55A4F);
  final Color _bgColor = const Color(0xFFF8F9FB);

  @override
  void initState() {
    super.initState();
    _loadUserReview();
  }

  Future<void> _loadUserReview() async {
    setState(() => _isLoading = true);
    try {
      // Используем репозиторий, который у вас уже есть в main.dart
      final comments = await context.read<BookRepository>().getBookComments(widget.bookId);

      // Получаем ID текущего пользователя из AuthProvider
      final myUserId = context.read<AuthProvider>().currentUser;

      final myReview = comments.cast<BookComment?>().firstWhere(
            (c) => c?.userId == context.read<AuthProvider>().currentUser?.id,
        orElse: () => null,
      );

      if (mounted && myReview != null) {
        setState(() {
          _textController.text = myReview.content;
          _selectedRating = myReview.rating ?? 0;
        });
      }
    } catch (e) {
      debugPrint("Ошибка: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitReview() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, поставьте оценку')),
      );
      return;
    }

    setState(() => _isPosting = true);
    try {
      // Используем ваш метод из BookRepository
      await context.read<BookRepository>().addComment(
        bookId: widget.bookId,
        content: _textController.text,
        rating: _selectedRating, // Убрали .toDouble()
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          "Оставить отзыв",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _accentColor))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Блок информации о книге (как на скриншоте)
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: widget.bookCoverUrl != null
                      ? Image.network(widget.bookCoverUrl!, width: 60, height: 60, fit: BoxFit.cover)
                      : Container(width: 60, height: 60, color: _bgColor, child: const Icon(Icons.book)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.bookTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text("Ваша оценка очень важна", style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),

            const Text(
              "Как бы вы оценили эту книгу?",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text("Ваш общий рейтинг", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),

            // Звезды
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _selectedRating = index + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      index < _selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: index < _selectedRating ? Colors.amber : Colors.grey[300],
                      size: 48,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 48),

            Align(
              alignment: Alignment.centerLeft,
              child: const Text(
                "Добавить подробный отзыв",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),

            // Поле ввода
            TextField(
              controller: _textController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Напишите здесь...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                fillColor: _bgColor,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(20),
              ),
            ),
          ],
        ),
      ),

      // Кнопка публикации внизу
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 16),
        decoration: const BoxDecoration(color: Colors.white),
        child: ElevatedButton(
          onPressed: _isPosting ? null : _submitReview,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentColor,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: _isPosting
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text(
            "Опубликовать отзыв",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }
}