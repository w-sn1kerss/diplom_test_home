import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/book_model.dart';

class SupabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Book>> getBooks() async {
    try {
      final response = await _supabase.storage.from('books').list();

      return response.map((file) {
        final url = _supabase.storage
            .from('books')
            .getPublicUrl(file.name);

        // Определяем тип книги по расширению
        final extension = file.name.split('.').last.toLowerCase();
        final isPdf = extension == 'pdf';
        final isEpub = extension == 'epub';
        final isFb2 = extension == 'fb2' || file.name.endsWith('.fb2.zip');

        String format = 'Книга';
        if (isPdf) format = 'PDF';
        if (isEpub) format = 'EPUB';
        if (isFb2) format = 'FB2';

        return Book(
          id: file.name,
          title: _extractTitle(file.name),
          author: 'Неизвестный автор',
          coverUrl: 'https://via.placeholder.com/150x200/6C63FF/FFFFFF?text=$format',
          fileUrl: url ?? '',
          description: 'Книга в формате $format',
          pages: 0,
          category: format,
        );
      }).toList();
    } catch (e) {
      print('Ошибка загрузки книг: $e');
      return [];
    }
  }

  String _extractTitle(String fileName) {
    final name = fileName.split('.').first;
    return name.replaceAll('_', ' ');
  }
}