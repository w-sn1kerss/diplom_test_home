import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/book_service.dart';
import '../../models/book_model.dart';
import '../reader/book_reader_screen.dart';
import '../users/book_comments_screen.dart';
import '../users/blog_details_screen.dart';
import 'main_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final BookService _bookService = BookService();
  final _supabase = Supabase.instance.client;

  List<Book> _allBooks = [];
  List<Book> _recommendedBooks = [];
  List<Book> _recentlyReadBooks = [];
  List<Map<String, dynamic>> _blogs = [];
  bool _isLoading = true;

  // Сортировка блогов
  String _currentSort = 'newest';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadBooks(),
      _loadBlogs(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBooks() async {
    try {
      final books = await _bookService.getBooks();
      if (mounted) {
        setState(() {
          _allBooks = books;
          _recommendedBooks = books.length > 3
              ? books.sublist(0, 3)
              : books;
          _recentlyReadBooks = books.length > 2
              ? books.sublist(0, books.length > 3 ? 3 : books.length)
              : books;
        });
      }
    } catch (e) {
      print('Ошибка загрузки книг: $e');
      if (mounted) {
        _setFallbackBooks();
      }
    }
  }

  Future<void> _loadBlogs() async {
    try {
      print('Загрузка блогов из Supabase...');

      PostgrestTransformBuilder<PostgrestList> query = _supabase
          .from('blogs')
          .select('''
      *,
      profiles (
        username,
        avatar_url
      )
      ''');

      // Применяем сортировку
      switch (_currentSort) {
        case 'newest':
          query = query.order('created_at', ascending: false);
          break;
        case 'oldest':
          query = query.order('created_at', ascending: true);
          break;
        case 'popular':
          query = query.order('likes', ascending: false);
          break;
      }

      final blogs = await query;

      print('Загружено блогов: ${blogs.length}');
      for (var blog in blogs) {
        print('Блог: ${blog['title']}, автор: ${blog['profiles']?['username']}');
      }

      if (mounted) {
        setState(() {
          _blogs = List<Map<String, dynamic>>.from(blogs);
        });
      }
    } catch (e) {
      print('Ошибка загрузки блогов: $e');
      print('Стек трейс: ${e.toString()}');
      if (mounted) {
        _setFallbackBlogs();
      }
    }
  }

  void _setFallbackBooks() {
    setState(() {
      _allBooks = [
        Book(
          id: '7e69c3fd-73c9-4282-9b3d-308c35fe0c9f',
          title: 'Маленький принц',
          author: 'Антуан де Сент-Экзюпери',
          coverUrl: 'https://covers.openlibrary.org/b/id/10410081-L.jpg',
          fileUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
          description: 'Философская сказка о дружбе и ответственности',
          pages: 96,
          category: 'Детская литература',
        ),
        Book(
          id: '550e8400-e29b-41d4-a716-446655440000',
          title: 'Война и мир',
          author: 'Лев Толстой',
          coverUrl: 'https://covers.openlibrary.org/b/id/7974501-L.jpg',
          fileUrl: '',
          description: 'Роман-эпопея',
          pages: 1225,
          category: 'Классика',
        ),
        Book(
          id: '3f2504e0-4f89-11d3-9a0c-0305e82c3301',
          title: 'Преступление и наказание',
          author: 'Фёдор Достоевский',
          coverUrl: 'https://covers.openlibrary.org/b/id/10410081-L.jpg',
          fileUrl: '',
          description: 'Психологический роман',
          pages: 430,
          category: 'Классика',
        ),
      ];
      _recommendedBooks = _allBooks.length > 3
          ? _allBooks.sublist(0, 3)
          : _allBooks;
      _recentlyReadBooks = _allBooks.length > 2
          ? _allBooks.sublist(0, _allBooks.length > 3 ? 3 : _allBooks.length)
          : _allBooks;
    });
  }

  void _setFallbackBlogs() {
    setState(() {
      _blogs = [
        {
          'id': '1',
          'title': 'Как читать больше книг?',
          'content': '5 простых привычек, которые помогут вам читать по книге в неделю...',
          'likes': 124,
          'comments': 34,
          'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
          'profiles': {
            'username': 'Анна Иванова',
            'avatar_url': '👩'
          }
        },
        {
          'id': '2',
          'title': 'Лучшие книги 2024 года',
          'content': 'Подборка самых интересных новинок в жанре фантастики...',
          'likes': 89,
          'comments': 23,
          'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          'profiles': {
            'username': 'Дмитрий Петров',
            'avatar_url': '👨'
          }
        },
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Главная'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFF6C63FF),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Рекомендуемые книги
              _buildSectionHeader(
                title: 'Рекомендуем для вас',
                icon: Icons.star,
                onSeeAll: () {
                  final mainScreen = context.findAncestorStateOfType<MainScreenState>();
                  mainScreen?.changeTab(1);
                },
              ),
              const SizedBox(height: 16),
              _buildRecommendedBooks(),
              const SizedBox(height: 32),

              // Недавно прочитанные
              _buildSectionHeader(
                title: 'Недавно прочитанные',
                icon: Icons.history,
                onSeeAll: () {
                  final mainScreen = context.findAncestorStateOfType<MainScreenState>();
                  mainScreen?.changeTab(1);
                },
              ),
              const SizedBox(height: 16),
              _buildRecentBooks(),
              const SizedBox(height: 32),

              // Блоги читателей с сортировкой
              _buildBlogsHeader(),
              const SizedBox(height: 16),
              _buildBlogsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendedBooks() {
    if (_recommendedBooks.isEmpty) {
      return _buildEmptyState('Нет рекомендаций');
    }

    return SizedBox(
      height: 260,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _recommendedBooks.length > 5 ? 5 : _recommendedBooks.length,
        itemBuilder: (context, index) {
          final book = _recommendedBooks[index];
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 16),
            child: RecommendedBookCard(book: book),
          );
        },
      ),
    );
  }

  Widget _buildRecentBooks() {
    if (_recentlyReadBooks.isEmpty) {
      return _buildEmptyState('Нет недавно прочитанных');
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _recentlyReadBooks.length > 5 ? 5 : _recentlyReadBooks.length,
        itemBuilder: (context, index) {
          final book = _recentlyReadBooks[index];
          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: 16),
            child: RecentBookCard(book: book),
          );
        },
      ),
    );
  }

  Widget _buildBlogsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.article,
                size: 16,
                color: Color(0xFF6C63FF),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Блоги читателей',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        PopupMenuButton<String>(
          icon: Row(
            children: [
              Text(
                _getSortLabel(),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.sort,
                size: 18,
                color: Colors.grey[600],
              ),
            ],
          ),
          onSelected: (String value) {
            setState(() {
              _currentSort = value;
            });
            _loadBlogs();
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem<String>(
              value: 'newest',
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 18, color: Color(0xFF6C63FF)),
                  SizedBox(width: 8),
                  Text('Сначала новые'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'oldest',
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 18, color: Color(0xFF6C63FF)),
                  SizedBox(width: 8),
                  Text('Сначала старые'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'popular',
              child: Row(
                children: [
                  Icon(Icons.favorite, size: 18, color: Color(0xFF6C63FF)),
                  SizedBox(width: 8),
                  Text('По популярности'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getSortLabel() {
    switch (_currentSort) {
      case 'newest':
        return 'Сначала новые';
      case 'oldest':
        return 'Сначала старые';
      case 'popular':
        return 'По популярности';
      default:
        return 'Сортировка';
    }
  }

  Widget _buildBlogsList() {
    if (_blogs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.article_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'Пока нет блогов',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Станьте первым, кто напишет блог!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 260,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _blogs.length > 5 ? 5 : _blogs.length,
        itemBuilder: (context, index) {
          final blog = _blogs[index];
          return Container(
            width: 300,
            margin: const EdgeInsets.only(right: 16),
            child: BlogCard(blog: blog),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required VoidCallback onSeeAll,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: const Color(0xFF6C63FF),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: onSeeAll,
          child: const Text(
            'Все →',
            style: TextStyle(
              color: Color(0xFF6C63FF),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 40,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

// Карточка для рекомендуемых книг
class RecommendedBookCard extends StatelessWidget {
  final Book book;

  const RecommendedBookCard({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookReaderScreen(book: book),
          ),
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      book.coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.book, size: 40, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.star,
                              size: 12,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '4.8',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      book.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      book.author,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BookCommentsScreen(
                              bookId: book.id,
                              bookTitle: book.title,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 12,
                              color: Color(0xFF6C63FF),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Обсудить',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6C63FF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Карточка для недавно прочитанных книг
class RecentBookCard extends StatelessWidget {
  final Book book;

  const RecentBookCard({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookReaderScreen(book: book),
          ),
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(12),
              ),
              child: Image.network(
                book.coverUrl,
                width: 80,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 80,
                    height: 120,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.book, size: 30, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      book.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Продолжить →',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Карточка блога из Supabase
class BlogCard extends StatelessWidget {
  final Map<String, dynamic> blog;

  const BlogCard({super.key, required this.blog});

  @override
  Widget build(BuildContext context) {
    final profile = blog['profiles'] as Map<String, dynamic>?;
    final userName = profile?['username'] ?? 'Пользователь';
    final userAvatar = profile?['avatar_url'] ?? '👤';
    final createdAt = DateTime.parse(blog['created_at']);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: // В классе BlogCard, в InkWell:
      InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BlogDetailScreen(
                  blog: blog,
                  profile: profile,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        userAvatar,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatTimeAgo(createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Блог',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                blog['title'] ?? 'Без названия',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                blog['content'] ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${blog['likes'] ?? 0}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${blog['comments'] ?? 0}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) return 'Только что';
    if (difference.inMinutes < 60) return '${difference.inMinutes} мин назад';
    if (difference.inHours < 24) return '${difference.inHours} ч назад';
    if (difference.inDays < 7) return '${difference.inDays} д назад';
    if (difference.inDays < 30) return '${difference.inDays ~/ 7} нед назад';
    if (difference.inDays < 365) return '${difference.inDays ~/ 30} мес назад';
    return '${difference.inDays ~/ 365} г назад';
  }
}