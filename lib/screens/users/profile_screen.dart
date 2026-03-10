import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  final String? userName;

  const ProfileScreen({
    super.key,
    this.userId,
    this.userName,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _usernameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _blogTitleController = TextEditingController();
  final _blogContentController = TextEditingController();

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isChangingPassword = false;
  bool _isAddingBlog = false;
  bool _showSettings = false;

  String _email = '';
  String _username = '';
  String _bio = '';
  String _avatarUrl = '';
  bool _isOwnProfile = true;

  // Статистика
  int _commentsCount = 0;
  int _blogsCount = 0;
  int _likesReceived = 0;
  double _avgRating = 0.0;

  // Блоги
  List<Map<String, dynamic>> _blogs = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = _supabase.auth.currentUser;
      final targetUserId = widget.userId ?? currentUser?.id;

      if (targetUserId == null) throw Exception('Пользователь не найден');

      _isOwnProfile = currentUser?.id == targetUserId;

      // Загружаем профиль из таблицы profiles
      final profile = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', targetUserId)
          .maybeSingle();

      if (profile != null) {
        _username = profile['username'] ?? widget.userName ?? 'Пользователь';
        _bio = profile['bio'] ?? '';
        _avatarUrl = profile['avatar_url'] ?? '';
      } else {
        _username = widget.userName ?? 'Пользователь';
      }

      _usernameController.text = _username;

      // Загружаем email для своего профиля
      if (_isOwnProfile) {
        _email = currentUser?.email ?? 'Не указан';
      }

      // Загружаем статистику
      await _loadUserStats(targetUserId);

      // Загружаем блоги
      await _loadUserBlogs(targetUserId);

    } catch (e) {
      print('Ошибка загрузки профиля: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка загрузки: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserStats(String userId) async {
    try {
      // Количество комментариев
      final comments = await _supabase
          .from('book_comments')
          .select('id')
          .eq('user_id', userId);
      _commentsCount = comments.length;

      // Количество блогов
      final blogs = await _supabase
          .from('blogs')
          .select('id')
          .eq('user_id', userId);
      _blogsCount = blogs.length;

      // Полученные лайки на комментарии
      final userComments = await _supabase
          .from('book_comments')
          .select('id')
          .eq('user_id', userId);

      int likes = 0;
      for (var comment in userComments) {
        final commentLikes = await _supabase
            .from('comment_likes')
            .select('id')
            .eq('comment_id', comment['id']);
        likes += commentLikes.length;
      }
      _likesReceived = likes;

      // Средний рейтинг комментариев
      final ratings = await _supabase
          .from('book_comments')
          .select('rating')
          .eq('user_id', userId)
          .not('rating', 'is', null);

      if (ratings.isNotEmpty) {
        double sum = 0;
        int count = 0;
        for (var r in ratings) {
          final rating = r['rating'] as num?;
          if (rating != null) {
            sum += rating.toDouble();
            count++;
          }
        }
        _avgRating = count > 0 ? sum / count : 0.0;
      }
    } catch (e) {
      print('Ошибка загрузки статистики: $e');
    }
  }

  Future<void> _loadUserBlogs(String userId) async {
    try {
      print('Загрузка блогов пользователя: $userId');

      final blogs = await _supabase
          .from('blogs')
          .select('''
          *,
          profiles!user_id (
            username,
            avatar_url
          )
        ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      print('Загружено блогов пользователя: ${blogs.length}');

      setState(() {
        _blogs = List<Map<String, dynamic>>.from(blogs);
        _blogsCount = blogs.length;
      });
    } catch (e) {
      print('Ошибка загрузки блогов: $e');
      print('Стек трейс: ${e.toString()}');
      setState(() {
        _blogs = [];
        _blogsCount = 0;
      });
    }
  }

  Future<void> _updateUsername() async {
    if (_usernameController.text.isEmpty) {
      _showSnackBar('Введите имя пользователя', Colors.red);
      return;
    }

    setState(() => _isEditing = true);

    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) throw Exception('Не авторизован');

      await _supabase.from('profiles').upsert({
        'id': currentUser.id,
        'username': _usernameController.text,
        'updated_at': DateTime.now().toIso8601String(),
      });

      setState(() {
        _username = _usernameController.text;
        _showSettings = false;
      });

      _showSnackBar('Имя обновлено', Colors.green);
    } catch (e) {
      _showSnackBar('Ошибка: $e', Colors.red);
    } finally {
      setState(() => _isEditing = false);
    }
  }

  Future<void> _updatePassword() async {
    if (_newPasswordController.text.length < 6) {
      _showSnackBar('Пароль должен содержать минимум 6 символов', Colors.red);
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnackBar('Пароли не совпадают', Colors.red);
      return;
    }

    setState(() => _isChangingPassword = true);

    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      setState(() => _showSettings = false);

      _showSnackBar('Пароль изменен', Colors.green);
    } catch (e) {
      _showSnackBar('Ошибка: $e', Colors.red);
    } finally {
      setState(() => _isChangingPassword = false);
    }
  }

  Future<void> _addBlog() async {
    if (_blogTitleController.text.isEmpty || _blogContentController.text.isEmpty) {
      _showSnackBar('Заполните все поля', Colors.red);
      return;
    }

    setState(() => _isAddingBlog = true);

    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) throw Exception('Не авторизован');

      await _supabase.from('blogs').insert({
        'user_id': currentUser.id,
        'title': _blogTitleController.text,
        'content': _blogContentController.text,
        'created_at': DateTime.now().toIso8601String(),
        'likes': 0,
        'comments': 0,
      });

      _blogTitleController.clear();
      _blogContentController.clear();
      setState(() => _isAddingBlog = false);

      await _loadUserBlogs(currentUser.id);
      _showSnackBar('Блог опубликован!', Colors.green);
    } catch (e) {
      _showSnackBar('Ошибка: $e', Colors.red);
      setState(() => _isAddingBlog = false);
    }
  }

  Future<void> _deleteBlog(String blogId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить блог?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabase
            .from('blogs')
            .delete()
            .eq('id', blogId);

        final currentUser = _supabase.auth.currentUser;
        if (currentUser != null) {
          await _loadUserBlogs(currentUser.id);
          await _loadUserStats(currentUser.id);
        }

        _showSnackBar('Блог удален', Colors.green);
      } catch (e) {
        _showSnackBar('Ошибка: $e', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _isOwnProfile ? 'Мой профиль' : 'Профиль',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: _isOwnProfile
            ? [
          IconButton(
            onPressed: () {
              setState(() => _showSettings = !_showSettings);
            },
            icon: Icon(
              _showSettings ? Icons.close : Icons.settings,
              color: _showSettings ? Colors.red : null,
            ),
            tooltip: _showSettings ? 'Закрыть' : 'Настройки',
          ),
        ]
            : null,
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF6C63FF),
        ),
      )
          : RefreshIndicator(
        onRefresh: () async {
          final currentUser = _supabase.auth.currentUser;
          if (currentUser != null) {
            await _loadUserData();
          }
        },
        color: const Color(0xFF6C63FF),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Шапка профиля
              _buildProfileHeader(),

              if (_showSettings && _isOwnProfile) ...[
                const SizedBox(height: 24),
                _buildSettingsSection(),
              ],

              const SizedBox(height: 24),

              // Статистика
              _buildStatsSection(),

              const SizedBox(height: 32),

              // Секция блогов
              _buildBlogsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
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
          // Аватар
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF8B7FFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _username.isNotEmpty ? _username[0].toUpperCase() : '👤',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              if (_isOwnProfile)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF6C63FF),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: Color(0xFF6C63FF),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _username,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          if (_bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _bio,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (_isOwnProfile) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'ID: ${_supabase.auth.currentUser?.id?.substring(0, 8)}...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.settings,
                  size: 20,
                  color: Color(0xFF6C63FF),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Настройки профиля',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Имя пользователя
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Имя пользователя',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    hintText: 'Введите имя',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isEditing ? null : _updateUsername,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isEditing
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Text('Сохранить имя'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Смена пароля
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Изменить пароль',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _currentPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Текущий пароль',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Новый пароль',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Подтвердите пароль',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isChangingPassword ? null : _updatePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isChangingPassword
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Text('Изменить пароль'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Выход
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                await _supabase.auth.signOut();
                if (context.mounted) {
                  Navigator.pop(context);
                  _showSnackBar('Вы вышли из аккаунта', Colors.green);
                }
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Выйти из аккаунта',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.analytics,
                  size: 20,
                  color: Color(0xFF6C63FF),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Статистика',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(_commentsCount.toString(), 'Комментариев'),
              _buildStatItem(_blogsCount.toString(), 'Блогов'),
              _buildStatItem(_likesReceived.toString(), 'Лайков'),
              _buildStatItem(_avgRating.toStringAsFixed(1), 'Рейтинг'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlogsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.article,
                    size: 20,
                    color: Color(0xFF6C63FF),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Блоги',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            if (_isOwnProfile)
              TextButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => _buildAddBlogSheet(),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Написать'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6C63FF),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        if (_blogs.isEmpty)
          Container(
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
                  _isOwnProfile
                      ? 'У вас пока нет блогов'
                      : 'У пользователя нет блогов',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                if (_isOwnProfile) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Напишите первый блог!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _blogs.length,
            itemBuilder: (context, index) {
              final blog = _blogs[index];
              return _buildBlogCard(blog);
            },
          ),
      ],
    );
  }

  Widget _buildAddBlogSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[200]!,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                const Text(
                  'Новый блог',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: _isAddingBlog ? null : () async {
                    await _addBlog();
                    if (mounted) Navigator.pop(context);
                  },
                  child: _isAddingBlog
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Color(0xFF6C63FF),
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    'Опубликовать',
                    style: TextStyle(
                      color: Color(0xFF6C63FF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    controller: _blogTitleController,
                    decoration: const InputDecoration(
                      labelText: 'Заголовок',
                      border: OutlineInputBorder(),
                      hintText: 'Введите заголовок блога',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _blogContentController,
                    maxLines: null,
                    minLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'Содержание',
                      border: OutlineInputBorder(),
                      hintText: 'О чем хотите рассказать?',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlogCard(Map<String, dynamic> blog) {
    final profile = blog['profiles'] as Map<String, dynamic>?;
    final userName = profile?['username'] ?? _username;
    final userAvatar = profile?['avatar_url'] ?? '👤';
    final isOwnBlog = _supabase.auth.currentUser?.id == blog['user_id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Шапка блога
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
                    style: const TextStyle(fontSize: 18),
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
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTimeAgo(DateTime.parse(blog['created_at'])),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              if (isOwnBlog)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteBlog(blog['id']);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Удалить'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Заголовок блога
          Text(
            blog['title'] ?? 'Без названия',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),

          // Содержание
          Text(
            blog['content'] ?? '',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
              height: 1.5,
            ),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),

          // Статистика
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
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6C63FF),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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