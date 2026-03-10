import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/book_model.dart';

class BookService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Book>> getBooks() async {
    try {
      print('Загрузка книг из Supabase...');

      final response = await _supabase
          .from('books')
          .select('*')
          .order('created_at', ascending: false);

      print('Получено книг: ${response.length}');

      final books = (response as List).map((json) {
        print('Книга: ${json['title']}, ID: ${json['id']}');

        // ВАЖНО: В вашем JSON файл хранится в cover_url, а не в file_url
        String fileUrl = json['cover_url'] ?? '';  // Используем cover_url как fileUrl

        // Если нужно, можно добавить логику для определения формата
        String fileExtension = '';
        if (fileUrl.isNotEmpty) {
          fileExtension = fileUrl.split('.').last.toLowerCase();
        }

        return Book(
          id: json['id'].toString(),
          title: json['title'] ?? 'Без названия',
          author: json['author'] ?? 'Неизвестный автор',
          coverUrl: json['cover_url'] ?? 'https://via.placeholder.com/150',  // Для обложки
          fileUrl: fileUrl,  // Используем ту же ссылку для файла
          description: json['description'] ?? '',
          pages: (json['pages'] as num?)?.toInt() ?? 0,
          category: json['category'] ?? 'Без категории',
        );
      }).toList();

      print('Успешно загружено книг: ${books.length}');
      return books;
    } catch (e) {
      print('Ошибка загрузки книг: $e');
      print('Стек трейс: ${e.toString()}');

      // Возвращаем тестовые книги для демонстрации
      return [
        Book(
          id: '7e69c3fd-73c9-4282-9b3d-308c35fe0c9f',
          title: 'Маленький принц',
          author: 'Антуан де Сент-Экзюпери',
          coverUrl: 'https://covers.openlibrary.org/b/id/10410081-L.jpg',
          fileUrl: 'https://fiyfttuzxnokdgiqtpua.supabase.co/storage/v1/object/public/books/malenkiy%20prince.pdf',
          description: 'Философская сказка о дружбе, любви и ответственности',
          pages: 96,
          category: 'Детская литература',
        ),
        Book(
          id: '9b896e7f-baa4-4ff2-8546-8e07b8b28745',
          title: 'Посторонний',
          author: 'Альбер Камю',
          coverUrl: 'https://fiyfttuzxnokdgiqtpua.supabase.co/storage/v1/object/public/books/postoronniy.epub',
          fileUrl: 'https://fiyfttuzxnokdgiqtpua.supabase.co/storage/v1/object/public/books/postoronniy.epub',
          description: 'lallalalaal',
          pages: 0,
          category: 'Без категории',
        ),
      ];
    }
  }
}