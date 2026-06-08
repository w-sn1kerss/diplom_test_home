class UserNote {
  final String id;
  final String userId;
  final String bookId;
  final int pageIndex;
  final String content;
  final String colorHex;
  final DateTime createdAt;

  const UserNote({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.pageIndex,
    required this.content,
    required this.colorHex,
    required this.createdAt,
  });

  factory UserNote.fromJson(Map<String, dynamic> json) => UserNote(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    bookId: json['book_id'] as String,
    pageIndex: json['page_index'] as int,
    content: json['content'] as String,
    colorHex: (json['color_hex'] as String?) ?? '#FFFF00',
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}