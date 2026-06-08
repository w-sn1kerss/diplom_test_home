class Book {
  final String id;
  final String title;
  final String author;
  final String coverUrl;
  final String fileUrl;
  final String description;
  final int pages;
  final List<String> categories;
  final double rating;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.fileUrl,
    required this.description,
    required this.pages,
    required this.categories,
    this.rating = 0.0,
  });

  // ДОБАВЬ ЭТОТ МЕТОД:
  Book copyWithRating(double newRating) {
    return Book(
      id: id,
      title: title,
      author: author,
      coverUrl: coverUrl,
      fileUrl: fileUrl,
      description: description,
      pages: pages,
      categories: categories,
      rating: newRating,
    );
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Без названия',
      author: map['author'] ?? 'Автор неизвестен',
      coverUrl: map['cover_url'] ?? '',
      fileUrl: map['book_url'] ?? '',
      description: map['description'] ?? '',
      pages: map['pages'] ?? 0,
      categories: map['categories'] != null
          ? List<String>.from(map['categories'])
          : [],
      rating: (map['rating'] ?? 0.0).toDouble(),
    );
  }
}