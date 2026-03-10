class Book {
  final String id;
  final String title;
  final String author;
  final String coverUrl;  // Для отображения обложки
  final String fileUrl;   // Для скачивания файла
  final String description;
  final int pages;
  final String category;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.fileUrl,
    required this.description,
    required this.pages,
    required this.category,
  });
}