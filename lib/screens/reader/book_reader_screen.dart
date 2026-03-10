import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/book_model.dart';
import 'pdf_reader_screen.dart';
import 'web_reader_screen.dart';
import '../../services/book_download_service.dart';
import 'epub_reader_screen.dart';

class BookReaderScreen extends StatefulWidget {
  final Book book;

  const BookReaderScreen({super.key, required this.book});

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  bool _isDownloading = false;

  Future<void> _openBook() async {
    final format = BookDownloadService.getBookFormat(widget.book.fileUrl);

    // Скачиваем книгу локально для любого формата
    await _downloadAndOpenBook(format);
  }

  Future<void> _downloadAndOpenBook(BookFormat format) async {
    setState(() => _isDownloading = true);

    try {
      // Проверяем, существует ли уже файл
      final directory = await getApplicationDocumentsDirectory();
      String extension = 'pdf';
      if (widget.book.fileUrl.toLowerCase().contains('.epub')) {
        extension = 'epub';
      } else if (widget.book.fileUrl.toLowerCase().contains('.fb2')) {
        extension = 'fb2';
      }
      final filePath = '${directory.path}/book_${widget.book.id}.$extension';
      final file = File(filePath);

      String? finalPath;

      if (await file.exists()) {
        // Файл уже скачан
        print('Файл уже существует: $filePath');
        finalPath = filePath;
      } else {
        // Скачиваем новый файл
        finalPath = await BookDownloadService.downloadBook(
          widget.book.fileUrl,
          widget.book.id,
        );
      }

      if (finalPath == null) {
        throw Exception('Не удалось получить книгу');
      }

      if (!mounted) return;

      // Открываем в зависимости от формата
      if (format == BookFormat.pdf) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfReaderScreen(
              book: widget.book,
              filePath: filePath,
            ),
          ),
        );
      } else {
        // Для EPUB и FB2 используем WebView с локальным файлом
        if (format == BookFormat.pdf) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PdfReaderScreen(
                book: widget.book,
                filePath: filePath,
              ),
            ),
          );
        } else if (format == BookFormat.epub) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EpubReaderScreen(
                book: widget.book,
                filePath: filePath,
              ),
            ),
          );
        } else {
          // Для FB2 и других форматов
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WebReaderScreen(
                book: widget.book,
                filePath: filePath,
                format: 'FB2',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }


  String _getFormatIcon() {
    final format = BookDownloadService.getBookFormat(widget.book.fileUrl);
    switch (format) {
      case BookFormat.pdf:
        return '📄 PDF';
      case BookFormat.epub:
        return '📱 EPUB';
      case BookFormat.fb2:
        return '📚 FB2';
      default:
        return '📖 Книга';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.book.title,
              style: const TextStyle(fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.book.author,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Обложка
              Container(
                width: 200,
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: NetworkImage(widget.book.coverUrl),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Название
              Text(
                widget.book.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Автор
              Text(
                'Автор: ${widget.book.author}',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 10),

              // Формат
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getFormatIcon(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6C63FF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Описание
              if (widget.book.description.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.book.description,
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 40),

              // Индикатор загрузки
              if (_isDownloading) ...[
                const CircularProgressIndicator(
                  color: Color(0xFF6C63FF),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Загрузка книги...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Кнопка чтения
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isDownloading ? null : _openBook,
                  icon: _isDownloading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(Icons.menu_book),
                  label: Text(
                    _isDownloading ? 'Загрузка...' : 'Читать книгу',
                    style: const TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}