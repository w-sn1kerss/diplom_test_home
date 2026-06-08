class UserNote {
  final String id;
  final String userId;
  final String bookId;
  final int pageIndex;
  final String content;
  final String colorHex;
  final DateTime createdAt;

  UserNote({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.pageIndex,
    required this.content,
    required this.colorHex,
    required this.createdAt,
  });

  // Фабрика для создания объекта из JSON, который возвращает Supabase
  factory UserNote.fromJson(Map<String, dynamic> json) {
    return UserNote(
      id: json['id'],
      userId: json['user_id'],
      bookId: json['book_id'],
      pageIndex: json['page_index'],
      content: json['content'],
      colorHex: json['color_hex'] ?? '#FFFF00',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}