import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

enum BookFormat {
  pdf,
  epub,
  fb2,
  unknown
}

class BookDownloadService {
  static Future<String?> downloadBook(String url, String bookId) async {
    try {
      print('Скачивание книги: $url');

      final response = await http.get(Uri.parse(url));

      print('Статус ответа: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('Ошибка загрузки: ${response.statusCode}');
      }

      final extension = _getExtensionFromUrl(url);
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/book_$bookId.$extension';

      print('Сохранение в: $filePath');
      print('Размер файла: ${response.bodyBytes.length} байт');

      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      print('Файл сохранен!');
      print('Файл существует: ${await file.exists()}');

      return filePath;
    } catch (e) {
      print('Ошибка скачивания книги: $e');
      return null;
    }
  }

  static String _getExtensionFromUrl(String url) {
    try {
      if (url.contains('.')) {
        final parts = url.split('.');
        if (parts.length > 1) {
          String ext = parts.last.toLowerCase();
          if (ext.contains('?')) {
            ext = ext.split('?').first;
          }
          return ext;
        }
      }
      return 'pdf';
    } catch (e) {
      return 'pdf';
    }
  }

  static BookFormat getBookFormat(String url) {
    final extension = _getExtensionFromUrl(url);

    switch (extension) {
      case 'pdf':
        return BookFormat.pdf;
      case 'epub':
        return BookFormat.epub;
      case 'fb2':
      case 'fb2.zip':
        return BookFormat.fb2;
      default:
        return BookFormat.pdf;
    }
  }
}