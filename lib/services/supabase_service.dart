  import 'package:supabase_flutter/supabase_flutter.dart';
  import '../models/book.dart';

  class SupabaseService {
    final SupabaseClient _supabase = Supabase.instance.client;

    Future<List<Map<String, dynamic>>> getBlogs({
      int from = 0,
      int to = 4,
      String sortBy = 'newest'
    }) async {
      try {
        PostgrestTransformBuilder<PostgrestList> query = _supabase
            .from('blogs')
            .select('*, profiles(username, avatar_url)');

        if (sortBy == 'newest') {
          query = query.order('created_at', ascending: false);
        } else {
          query = query.order('likes', ascending: false);
        }

        final response = await query.range(from, to);
        return List<Map<String, dynamic>>.from(response);
      } catch (e) {
        print('Ошибка SupabaseService (getBlogs): $e');
        return [];
      }
    }

    // Если ты используешь автоматическое получение из Storage:
    Future<List<Book>> getBooksFromStorage() async {
      try {
        final response = await _supabase.storage.from('books').list();

        return response.map((file) {
          final url = _supabase.storage.from('books').getPublicUrl(file.name);
          final extension = file.name.split('.').last.toLowerCase();

          return Book(
            id: file.name,
            title: _extractTitle(file.name),
            author: 'Неизвестный автор',
            coverUrl: 'https://via.placeholder.com/150x200?text=$extension',
            fileUrl: url,
            description: 'Загружено из хранилища',
            categories: [extension.toUpperCase()],

            // ИСПРАВЛЕНИЕ: передаем обязательные поля, которых не хватало:
            rating: 0.0, // Рейтинг по умолчанию
            createdAt: DateTime.now(), // Дата создания по умолчанию

            // ВНИМАНИЕ: Если в модели Book нет поля 'pages', удалите эту строку.
            // Если вы планируете добавить 'pages', убедитесь, что оно есть в модели.
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