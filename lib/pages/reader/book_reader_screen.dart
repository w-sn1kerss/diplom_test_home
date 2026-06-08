import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../providers/book_provider.dart';
import '../../services/book_download_service.dart';
import '../users/book_comments_screen.dart';
import 'epub_reader_screen.dart';
import 'pdf_reader_screen.dart';

class BookReaderScreen extends StatefulWidget {
  final Book book;
  const BookReaderScreen({super.key, required this.book});

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  static const _accent = Color(0xFFFF5722);
  static const _bg = Color(0xFFF8F9FB);
  static const _textPrimary = Color(0xFF1A1A1A);
  static const _textSecondary = Color(0xFF666666);
  static const _chipBg = Color(0xFFE1E5EB);

  bool _isOverviewSelected = true;
  bool _isBookDownloaded = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _checkIfDownloaded();

    // ПРИНУДИТЕЛЬНОЕ ОБНОВЛЕНИЕ ДАННЫХ
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<BookProvider>();
      // Если у нас нет ссылки, пробуем дозагрузить полную инфу о книге
      if (widget.book.fileUrl == null) {
        await provider.selectBook(widget.book.id);
        // После этого можно обновить состояние, если нужно
        if (mounted) setState(() {});
      }
      provider.loadComments(widget.book.id);
    });
  }

  // ─── File helpers ─────────────────────────────────
  Future<File> _getLocalFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final format = BookDownloadService.getBookFormat(widget.book.fileUrl ?? '');

    // Приводим к расширению, которое использует твой сервис
    String ext = 'pdf';
    if (format == BookFormat.epub) ext = 'epub';
    else if (format == BookFormat.fb2) ext = 'fb2';

    return File('${dir.path}/book_${widget.book.id}.$ext');
  }

  Future<void> _checkIfDownloaded() async {
    final file = await _getLocalFile();
    if (mounted) setState(() => _isBookDownloaded = file.existsSync());
  }

  // ─── Полностью рабочий метод скачивания через Dio ────────────────
  Future<void> _downloadBook() async {
    // Получаем актуальную книгу из провайдера или виджета
    final book = context.read<BookProvider>().selectedBook ?? widget.book;
    final url = book.fileUrl;

    if (url == null || url.isEmpty) {
      _showError('Ошибка: Ссылка на книгу отсутствует');
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final dir = await getApplicationDocumentsDirectory();

      // 1. Правильно извлекаем расширение
      final ext = url.split('.').last.split('?').first.toLowerCase();

      // 2. ИСПРАВЛЕНИЕ: используем book.id вместо несуществующего bookId
      final file = File('${dir.path}/book_${book.id}.$ext');

      final dio = Dio();

      // Скачиваем
      await dio.download(
        url,
        file.path,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isBookDownloaded = true;
          _isDownloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Книга успешно скачана!')));
      }
    } catch (e) {
      print('DEBUG: Ошибка при скачивании: $e');
      if (mounted) {
        setState(() => _isDownloading = false);
        _showError('Ошибка загрузки: $e');
      }
    }
  }

  // Обновленный метод открытия, который проверяет файл перед навигацией
  Future<void> _openBook() async {
    final file = await _getLocalFile();

    if (!file.existsSync()) {
      await _downloadBook();
      return;
    }

    if (!mounted) return;

    // ВАЖНО: используем расширение файла, а не URL, чтобы быть уверенными
    final ext = file.path.split('.').last.toLowerCase();
    print('DEBUG: Открываем файл с расширением: $ext');

    if (ext == 'epub') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => EpubReaderScreen(book: widget.book, filePath: file.path)));
    } else if (ext == 'pdf') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PdfReaderScreen(book: widget.book, filePath: file.path)));
    } else {
      _showError('Формат .$ext не поддерживается этим ридером');
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить книгу?'),
        content:
        const Text('Файл будет удалён с устройства.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) _deleteBook();
  }

  Future<void> _deleteBook() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    try {
      final file = await _getLocalFile();
      if (file.existsSync()) await file.delete();
      if (userId != null) {
        await Supabase.instance.client
            .from('user_downloads')
            .delete()
            .eq('user_id', userId)
            .eq('book_id', widget.book.id);
      }
      if (mounted) {
        setState(() => _isBookDownloaded = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Книга удалена')));
      }
    } catch (e) {
      _showError('Ошибка при удалении: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  // ─── Build ────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon:
          const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: _textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('О книге',
            style: TextStyle(
                fontWeight: FontWeight.w900, fontSize: 18)),
        actions: [
          if (_isBookDownloaded)
            IconButton(
              icon:
              const Icon(Icons.delete_outline_rounded, color: Colors.red),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      bottomNavigationBar: _isOverviewSelected
          ? null
          : SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: ElevatedButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookCommentsScreen(
                    bookId: widget.book.id,
                    bookTitle: widget.book.title,
                    bookCoverUrl: widget.book.coverUrl,
                  ),
                ),
              );
              if (mounted) {
                context
                    .read<BookProvider>()
                    .loadComments(widget.book.id);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              side: BorderSide(color: _accent, width: 1.5),
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text('Написать отзыв',
                style: TextStyle(
                    color: _accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildBookHeader(),
            const SizedBox(height: 24),
            _buildMainActions(),
            const SizedBox(height: 24),
            _buildTabSwitcher(),
            const SizedBox(height: 20),
            _isOverviewSelected ? _buildOverviewTab() : _buildReviewsTab(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBookHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Обложка
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5))
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: (widget.book.coverUrl?.isNotEmpty == true)
                ? Image.network(
              widget.book.coverUrl!,
              width: 115,
              height: 170,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _coverPlaceholder(),
            )
                : _coverPlaceholder(),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.book.title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              if (widget.book.author?.isNotEmpty == true)
                Text(widget.book.author!,
                    style: const TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              const SizedBox(height: 12),
              // Рейтинг
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(widget.book.rating.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              // Категории
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.book.categories
                    .map((cat) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: _chipBg,
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(cat,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ))
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _coverPlaceholder() => Container(
    width: 115,
    height: 170,
    color: _chipBg,
    child: const Icon(Icons.book, color: Colors.black26),
  );

  Widget _buildMainActions() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Основная кнопка
                ElevatedButton(
                  onPressed: _isDownloading ? null : (_isBookDownloaded ? _openBook : _downloadBook),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isBookDownloaded ? const Color(0xFF2E333D) : _accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(double.infinity, 52),
                    elevation: 0,
                  ),
                  child: Text(
                    _isDownloading ? '' : (_isBookDownloaded ? 'Читать книгу' : 'Скачать'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
                // Полоска прогресса (появляется поверх кнопки)
                if (_isDownloading)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _downloadProgress, // <-- Вот эта переменная обновляет UI
                              backgroundColor: Colors.white.withOpacity(0.3),
                              color: Colors.white,
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${(_downloadProgress * 100).toInt()}%',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabSwitcher() {
    return Row(
      children: [
        _TabItem(
          label: 'Обзор',
          isActive: _isOverviewSelected,
          onTap: () => setState(() => _isOverviewSelected = true),
        ),
        const SizedBox(width: 30),
        Consumer<BookProvider>(
          builder: (_, prov, __) => _TabItem(
            label: 'Отзывы (${prov.comments.length})',
            isActive: !_isOverviewSelected,
            onTap: () => setState(() => _isOverviewSelected = false),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.book.description?.isNotEmpty == true)
          Text(
            widget.book.description!,
            style: TextStyle(
                color: _textPrimary.withOpacity(0.7),
                fontSize: 14,
                height: 1.6),
          ),
        const SizedBox(height: 32),
        const Text('Похожие книги',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),

        // --- КАРТОЧКИ С СОРТИРОВКОЙ/СПИСКОМ ---
        Consumer<BookProvider>(builder: (_, prov, __) {
          final recs = prov.books
              .where((b) => b.id != widget.book.id &&
              b.categories.any((c) => widget.book.categories.contains(c)))
              .take(6)
              .toList();

          if (recs.isEmpty) return const Text("Нет похожих книг");

          return SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: recs.length,
              itemBuilder: (_, i) => _buildBookCard(recs[i]),
            ),
          );
        }),
      ],
    );
  }

  // Вспомогательный метод для создания красивой карточки
  Widget _buildBookCard(Book book) {
    return GestureDetector(
      onTap: () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => BookReaderScreen(book: book)),
      ),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                image: DecorationImage(
                  image: NetworkImage(book.coverUrl ?? ''),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(book.author ?? '',
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsTab() {
    return Consumer<BookProvider>(
      builder: (_, prov, __) {
        if (prov.loadingComments) {
          return const Center(child: CircularProgressIndicator());
        }
        if (prov.comments.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: Text('Отзывов пока нет')),
          );
        }
        return Column(
          children: prov.comments.map(_CommentCard.new).toList(),
        );
      },
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabItem(
      {required this.label,
        required this.isActive,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
                color: isActive
                    ? const Color(0xFF1A1A1A)
                    : const Color(0xFF666666),
                fontWeight: FontWeight.w800,
                fontSize: 16),
          ),
          if (isActive)
            Container(
                margin: const EdgeInsets.only(top: 4),
                width: 20,
                height: 3,
                color: const Color(0xFFFF5722)),
        ],
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  final BookComment comment;
  const _CommentCard(this.comment);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage:
                (comment.author?.avatarUrl?.isNotEmpty == true)
                    ? NetworkImage(comment.author!.avatarUrl!)
                    : null,
                child: (comment.author?.avatarUrl?.isNotEmpty != true)
                    ? const Icon(Icons.person, size: 16)
                    : null,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(comment.author?.username ?? 'Пользователь',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  if (comment.rating != null)
                    Row(
                      children: List.generate(
                        5,
                            (i) => Icon(
                          i < (comment.rating ?? 0)
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(comment.content,
              style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}