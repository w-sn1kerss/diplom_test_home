class Book {
  final String id;
  final String title;
  final String? author;
  final String? fileUrl;
  final String? coverUrl;
  final String? description;
  final List<String> categories;
  final double rating;
  final DateTime createdAt;

  const Book({
    required this.id,
    required this.title,
    this.author,
    this.fileUrl,
    this.coverUrl,
    this.description,
    required this.categories,
    required this.rating,
    required this.createdAt,
  });

  factory Book.fromJson(Map<String, dynamic> json) => Book(
    id: json['id'] as String,
    title: json['title'] as String,
    author: json['author'] as String?,
    fileUrl: json['file_url'] as String?,
    coverUrl: json['cover_url'] as String?,
    description: json['description'] as String?,
    categories: (json['categories'] as List<dynamic>?)?.cast<String>() ?? [],
    rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
  factory Book.fromListJson(Map<String, dynamic> json) => Book(
    id: json['id'] as String,
    title: json['title'] as String,
    author: json['author'] as String?,
    coverUrl: json['cover_url'] as String?,
    categories: (json['categories'] as List<dynamic>?)?.cast<String>() ?? [],
    rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Book copyWith({
    String? title,
    String? author,
    String? description,
    String? coverUrl,
    String? fileUrl,
    List<String>? categories,
    double? rating,
  }) =>
      Book(
        id: id,
        title: title ?? this.title,
        author: author ?? this.author,
        fileUrl: fileUrl ?? this.fileUrl,
        coverUrl: coverUrl ?? this.coverUrl,
        description: description ?? this.description,
        categories: categories ?? this.categories,
        rating: rating ?? this.rating,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Book && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
