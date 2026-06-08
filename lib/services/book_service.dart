import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/book_model.dart';

class BookService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Book>> getBooks() async {
    try {
      // Запрашиваем все данные, сортируем по дате добавления (новые сверху)
      final response = await _supabase
          .from('books')
          .select('*')
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;

      return data.map((json) {
        // 1. Обработка обложки (если пусто — ставим заглушку)
        final String rawCoverUrl = json['cover_url'] ?? '';
        final String coverUrl = rawCoverUrl.isNotEmpty
            ? rawCoverUrl
            : 'https://images.unsplash.com/photo-1543005139-85e92111bb46?q=80&w=500&auto=format&fit=crop';

        // 2. Безопасное приведение рейтинга (важно для работы со звездами)
        // Если в БД NULL или int, принудительно делаем double
        final double rating = (json['rating'] ?? 0.0).toDouble();

        // 3. Безопасное приведение страниц
        final int pages = json['pages'] != null ? (json['pages'] as num).toInt() : 0;

        // 4. Обработка категорий (массив строк)
        final List<String> categories = json['categories'] != null
            ? List<String>.from(json['categories'])
            : ['Без категории'];

        return Book(
          id: json['id'].toString(),
          title: json['title'] ?? 'Без названия',
          author: json['author'] ?? 'Неизвестный автор',
          coverUrl: coverUrl,
          fileUrl: json['file_url'] ?? '',
          description: json['description'] ?? '',
          rating: rating,
          pages: pages,
          categories: categories,
        );
      }).toList();

    } catch (e) {
      // Логируем ошибку, чтобы понимать, что пошло не так
      print('--- Ошибка загрузки книг в BookService ---');
      print(e);
      // Возвращаем пустой список, чтобы приложение не "крашнулось"
      return [];
    }
  }

  /// Дополнительный метод, если нужно получить только одну книгу по ID
  Future<Book?> getBookById(String id) async {
    try {
      final data = await _supabase.from('books').select().eq('id', id).single();

      return Book(
        id: data['id'].toString(),
        title: data['title'] ?? '',
        author: data['author'] ?? '',
        coverUrl: data['cover_url'] ?? '',
        fileUrl: data['file_url'] ?? '',
        description: data['description'] ?? '',
        rating: (data['rating'] ?? 0.0).toDouble(),
        pages: (data['pages'] as num?)?.toInt() ?? 0,
        categories: List<String>.from(data['categories'] ?? []),
      );
    } catch (e) {
      print('Ошибка получения книги $id: $e');
      return null;
    }
  }
}