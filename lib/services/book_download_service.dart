import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum BookFormat { pdf, epub, fb2, unknown }

class BookDownloadService {
  static final _supabase = Supabase.instance.client;

  static Future<String?> downloadBook(String url, String bookId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authorized');

      final extension = _getExtensionFromUrl(url);
      final directory = await getApplicationDocumentsDirectory();
      // Используем корректный путь для сохранения
      final filePath = '${directory.path}/book_$bookId.$extension';
      final file = File(filePath);

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));

      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 30));

      if (streamedResponse.statusCode != 200) throw Exception('Error ${streamedResponse.statusCode}');

      final IOSink sink = file.openWrite();
      await streamedResponse.stream.pipe(sink);
      await sink.close();
      client.close();

      // ЗАПИСЬ В БД: Таблица user_downloads остается без изменений
      await _supabase.from('user_downloads').upsert({
        'user_id': userId,
        'book_id': bookId,
        'local_path': filePath,
        'downloaded_at': DateTime.now().toIso8601String(),
      });

      return filePath;
    } catch (e) {
      print('Download error: $e');
      return null;
    }
  }

  static String _getExtensionFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      if (path.contains('.')) {
        return path.split('.').last.toLowerCase();
      }
      return 'pdf';
    } catch (_) {
      return 'pdf';
    }
  }

  static BookFormat getBookFormat(String url) {
    final ext = _getExtensionFromUrl(url);
    if (ext == 'pdf') return BookFormat.pdf;
    if (ext == 'epub') return BookFormat.epub;
    if (ext == 'fb2' || ext == 'zip') return BookFormat.fb2;
    return BookFormat.pdf;
  }
}