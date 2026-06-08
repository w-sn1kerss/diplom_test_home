import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../screens/users/user_items_list_screen.dart';
import 'blog_details_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  final String? userName;

  const ProfileScreen({super.key, this.userId, this.userName});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();

  bool _isLoading = true;
  bool _isOwnProfile = true;
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _userBlogs = [];

  Map<String, dynamic> _stats = {
    'read': 0,
    'achievements': 0,
    'reviews': 0,
    'favorites': 0,
  };

  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final myId = _supabase.auth.currentUser?.id;
    // Если widget.userId передан — открываем его, иначе — свой
    final targetId = widget.userId ?? myId;

    if (targetId == null) return;

    // Устанавливаем флаг: мой это профиль или чужой (чтобы скрыть кнопку "Добавить блог")
    _isOwnProfile = (targetId == myId);

    try {
      final responses = await Future.wait([
        _supabase.from('profiles').select().eq('id', targetId).single(),
        _supabase.from('user_stats').select().eq('user_id', targetId).maybeSingle(),
        _supabase.from('blogs').select().eq('user_id', targetId).order('created_at', ascending: false),
        _supabase.from('user_achievements').count().eq('user_id', targetId),
      ]);

      if (mounted) {
        setState(() {
          _userData = responses[0] as Map<String, dynamic>;
          final statsData = responses[1] as Map<String, dynamic>?;
          _stats = {
            'read': statsData?['books_read_count'] ?? 0,
            'achievements': responses[3] as int,
            'reviews': statsData?['reviews_count'] ?? 0,
            'favorites': 0,
          };
          _userBlogs = (responses[2] as List<dynamic>).cast<Map<String, dynamic>>();
          _nameController.text = _userData?['username'] ?? widget.userName ?? "Пользователь";
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Ошибка загрузки данных: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ЛОГИКА РЕДАКТИРОВАНИЯ ПРОФИЛЯ ---
  Future<void> _editProfile() async {
    final nameEditController = TextEditingController(text: _userData?['username']);
    final bioEditController = TextEditingController(text: _userData?['bio']);
    File? newAvatar;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 25, right: 25, top: 25
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Редактировать профиль", style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 25),
                GestureDetector(
                  onTap: () async {
                    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
                    if (image != null) setModalState(() => newAvatar = File(image.path));
                  },
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: newAvatar != null
                            ? FileImage(newAvatar!)
                            : (_userData?['avatar_url'] != null ? NetworkImage(_userData!['avatar_url']) : null) as ImageProvider?,
                        child: newAvatar == null && _userData?['avatar_url'] == null
                            ? const Icon(Icons.person, size: 40) : null,
                      ),
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.black,
                        child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                TextField(
                  controller: nameEditController,
                  maxLength: 12,
                  decoration: InputDecoration(
                    labelText: "Ваше имя",
                    counterText: "",
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: bioEditController,
                  maxLines: 5,
                  minLines: 3,
                  decoration: InputDecoration(
                    labelText: "О себе",
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    onPressed: () async {
                      try {
                        String? avatarUrl = _userData?['avatar_url'];
                        if (newAvatar != null) {
                          final name = 'avatar_${_supabase.auth.currentUser!.id}.jpg';
                          await _supabase.storage.from('avatars').upload(name, newAvatar!, fileOptions: const FileOptions(upsert: true));
                          avatarUrl = _supabase.storage.from('avatars').getPublicUrl(name);
                        }
                        await _supabase.from('profiles').update({'username': nameEditController.text, 'bio': bioEditController.text, 'avatar_url': avatarUrl}).eq('id', _supabase.auth.currentUser!.id);
                        if (mounted) { Navigator.pop(context); _loadInitialData(); }
                      } catch (e) { debugPrint("Ошибка обновления: $e"); }
                    },
                    child: Text("Сохранить", style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- ЛОГИКА ЛАЙКОВ ---
  Future<void> _toggleLike(Map<String, dynamic> blog) async {
    final userId = _supabase.auth.currentUser!.id;
    final blogId = blog['id'];
    try {
      final existingLike = await _supabase.from('blog_likes').select().eq('blog_id', blogId).eq('user_id', userId).maybeSingle();
      if (existingLike == null) {
        await _supabase.from('blog_likes').insert({'blog_id': blogId, 'user_id': userId});
        await _supabase.from('blogs').update({'likes': (blog['likes'] ?? 0) + 1}).eq('id', blogId);
      } else {
        await _supabase.from('blog_likes').delete().eq('blog_id', blogId).eq('user_id', userId);
        await _supabase.from('blogs').update({'likes': (blog['likes'] ?? 0) - 1}).eq('id', blogId);
      }
      _loadInitialData();
    } catch (e) { debugPrint("Ошибка лайка: $e"); }
  }

  Future<void> _upsertBlog({Map<String, dynamic>? existingBlog}) async {
    final titleController = TextEditingController(text: existingBlog?['title']);
    final contentController = TextEditingController(text: existingBlog?['content']);
    File? selectedImage;
    String? currentImageUrl = existingBlog?['image_url'];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 25, right: 25, top: 25),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(existingBlog == null ? "Новая запись" : "Редактирование", style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () async {
                    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
                    if (image != null) setModalState(() => selectedImage = File(image.path));
                  },
                  child: Container(
                    height: 160, width: double.infinity,
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[300]!, width: 1)),
                    child: selectedImage != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.file(selectedImage!, fit: BoxFit.cover))
                        : (currentImageUrl != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(currentImageUrl!, fit: BoxFit.cover))
                        : Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.grey), const SizedBox(height: 8), Text("Добавить фото", style: GoogleFonts.manrope(color: Colors.grey))])),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(controller: titleController, decoration: InputDecoration(hintText: "Заголовок", filled: true, fillColor: Colors.grey[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
                const SizedBox(height: 10),
                TextField(controller: contentController, maxLines: 5, decoration: InputDecoration(hintText: "Ваша история...", filled: true, fillColor: Colors.grey[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: () async {
                  if (titleController.text.trim().isEmpty) return;
                  try {
                    String? imageUrl = currentImageUrl;
                    if (selectedImage != null) {
                      final fileName = 'blog_${DateTime.now().millisecondsSinceEpoch}.jpg';
                      await _supabase.storage.from('blog-images').upload(fileName, selectedImage!);
                      imageUrl = _supabase.storage.from('blog-images').getPublicUrl(fileName);
                    }
                    final blogData = {'user_id': _supabase.auth.currentUser!.id, 'title': titleController.text.trim(), 'content': contentController.text.trim(), 'image_url': imageUrl};
                    if (existingBlog == null) { await _supabase.from('blogs').insert(blogData); } else { await _supabase.from('blogs').update(blogData).eq('id', existingBlog['id']); }
                    if (mounted) { Navigator.pop(context); _loadInitialData(); }
                  } catch (e) { debugPrint("ОШИБКА: $e"); }
                }, child: Text("Сохранить", style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.bold)))),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.black)));

    return Scaffold(
      backgroundColor: const Color(0xFFE9EEF2),
      body: RefreshIndicator(
        onRefresh: _loadInitialData,
        color: Colors.black,
        child: Stack( // Используем Stack, чтобы кнопка была поверх всего
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 60),

                    // ЗАГОЛОВОК С УЧЕТОМ КНОПКИ НАЗАД
                    Row(
                      children: [
                        if (!_isOwnProfile) ...[
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                  )
                                ],
                              ),
                              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.black),
                            ),
                          ),
                          const SizedBox(width: 15),
                        ],
                        Text(
                            _isOwnProfile ? "Профиль" : "Автор",
                            style: GoogleFonts.manrope(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1
                            )
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    _buildMainProfileCard(),
                    const SizedBox(height: 15),
                    _buildStatsGrid(),
                    const SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Публикации", style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800)),
                        if (_isOwnProfile) IconButton(onPressed: () => _upsertBlog(), icon: const Icon(Icons.add_circle, size: 32, color: Colors.black)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildBlogsList(),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- НОВАЯ КАРТОЧКА ПРОФИЛЯ С БЛЮРОМ ---
  Widget _buildMainProfileCard() {
    final avatarUrl = _userData?['avatar_url'];
    final safeImage = _getSafeAvatar(avatarUrl);

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Container(
          height: 320,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: Stack(
              children: [
                // Фон карточки (размытое фото)
                Positioned.fill(
                  child: safeImage != null
                      ? Image(image: safeImage, fit: BoxFit.cover)
                      : Container(color: const Color(0xFFD6E2E8)),
                ),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                    child: Container(color: Colors.white.withOpacity(0.2)),
                  ),
                ),
                if (_isOwnProfile)
                  Positioned(
                    top: 20, right: 20,
                    child: IconButton(
                      onPressed: _editProfile,
                      icon: const Icon(Icons.edit_note_rounded, size: 32, color: Colors.black87),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Column(
            children: [
              // Основная круглая аватарка
              Container(
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]
                ),
                child: CircleAvatar(
                  radius: 55,
                  backgroundColor: Colors.white,
                  backgroundImage: safeImage,
                  child: safeImage == null
                      ? const Icon(Icons.person, size: 50, color: Colors.grey)
                      : null,
                ),
              ),
              const SizedBox(height: 15),
              Text(_nameController.text, style: GoogleFonts.manrope(fontSize: 26, fontWeight: FontWeight.w900)),
              Text("Участник сообщества", style: GoogleFonts.manrope(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              // ... (остальной блок с Email и "О себе" остается без изменений)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow("Email", _supabase.auth.currentUser?.email ?? "—"),
                          const Divider(color: Colors.white24, height: 15),
                          _buildInfoRow("О себе", _userData?['bio'] ?? "Нет описания"),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label: ", style: GoogleFonts.manrope(color: Colors.black54, fontWeight: FontWeight.w800, fontSize: 13)),
          Expanded(child: Text(value, style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: Colors.black87, fontSize: 13), maxLines: 5, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.1,
      children: [
        _buildStatTile("Книги", _stats['read'].toString(), Icons.auto_stories, () => _openDetailList("Прочитанные", "user_recent_activity")),
        _buildStatTile("Награды", _stats['achievements'].toString(), Icons.emoji_events, () => _openDetailList("Достижения", "user_achievements")),
        _buildStatTile("Отзывы", _stats['reviews'].toString(), Icons.rate_review, () => _openDetailList("Мои отзывы", "book_comments")),
        _buildStatTile("Избранное", "0", Icons.favorite, () {}),
      ],
    );
  }

  Widget _buildStatTile(String title, String value, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: GoogleFonts.manrope(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w600)),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(value, style: GoogleFonts.manrope(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              Padding(padding: const EdgeInsets.only(bottom: 6), child: Icon(icon, color: Colors.orange, size: 18)),
            ]),
          ],
        ),
      ),
    );
  }

  // --- НОВЫЙ СПИСОК БЛОГОВ (КАК НА ФОТО) ---
  Widget _buildBlogsList() {
    if (_userBlogs.isEmpty) return const Center(child: Text("Записей пока нет"));
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _userBlogs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final blog = _userBlogs[index];
        final blogAvatar = _getSafeAvatar(_userData?['avatar_url']); // Безопасная аватарка

        return GestureDetector(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => BlogDetailScreen(
                blog: blog,
                userData: _userData,
                isOwnProfile: _isOwnProfile,
                onUpdate: _loadInitialData,
              ))
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Картинка самого блога
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: (blog['image_url'] != null && blog['image_url'].toString().startsWith('http'))
                      ? Image.network(blog['image_url'], width: 100, height: 100, fit: BoxFit.cover)
                      : Container(width: 100, height: 100, color: Colors.grey[100], child: const Icon(Icons.image)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(blog['title'] ?? '', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 16, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundImage: blogAvatar,
                            child: blogAvatar == null ? const Icon(Icons.person, size: 8, color: Colors.white) : null,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "${_userData?['username']} • ${_getTimeAgo(blog['created_at'])}",
                              style: GoogleFonts.manrope(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- ДЕТАЛИ БЛОГА С КОММЕНТАРИЯМИ ---
  void _showBlogDetails(Map<String, dynamic> blog) {
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(35))
          ),
          child: Column(
            children: [
              // Полоска сверху для красоты
              Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),

              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Публикация", style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: Colors.grey)),
                        if (_isOwnProfile) Row(children: [
                          IconButton(onPressed: () { Navigator.pop(context); _upsertBlog(existingBlog: blog); }, icon: const Icon(Icons.edit_outlined, size: 20)),
                          IconButton(onPressed: () async {
                            await _supabase.from('blogs').delete().eq('id', blog['id']);
                            Navigator.pop(context);
                            _loadInitialData();
                          }, icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20))
                        ])
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(blog['title'] ?? '', style: GoogleFonts.manrope(fontSize: 26, fontWeight: FontWeight.w900, height: 1.2)),
                    const SizedBox(height: 20),
                    if (blog['image_url'] != null)
                      ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(blog['image_url'], fit: BoxFit.cover)),
                    const SizedBox(height: 20),
                    Text(blog['content'] ?? '', style: GoogleFonts.manrope(fontSize: 16, height: 1.7, color: Colors.black87)),

                    const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),

                    // Секция комментариев
                    Row(
                      children: [
                        const Icon(Icons.mode_comment_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text("Комментарии", style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Список комментариев (FutureBuilder остается как был)
                    FutureBuilder<List<Map<String, dynamic>>>(
                      // Делаем запрос более надежным
                      future: _supabase
                          .from('blog_comments')
                          .select('*, profiles(username, avatar_url)')
                          .eq('blog_id', blog['id'])
                          .order('created_at', ascending: false)
                          .then((data) => List<Map<String, dynamic>>.from(data)),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)),
                          );
                        }
                        if (snapshot.hasError) {
                          return const Center(child: Text("Ошибка загрузки комментариев"));
                        }

                        final comments = snapshot.data ?? [];
                        if (comments.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: Text("Комментариев пока нет", style: GoogleFonts.manrope(color: Colors.grey))),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: comments.length,
                          itemBuilder: (context, i) {
                            final c = comments[i];
                            final profile = c['profiles'];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundImage: profile['avatar_url'] != null ? NetworkImage(profile['avatar_url']) : null,
                                    child: profile['avatar_url'] == null ? const Icon(Icons.person, size: 14) : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(profile['username'] ?? "Аноним", style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 12)),
                                            const SizedBox(width: 8),
                                            Text(_getTimeAgo(c['created_at']), style: TextStyle(fontSize: 10, color: Colors.grey)),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(c['content'] ?? "", style: GoogleFonts.manrope(fontSize: 13, color: Colors.black87)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
              // Поле ввода комментария
              Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 10),
                child: Row(
                  children: [
                    Expanded(
                        child: TextField(
                            controller: commentController,
                            decoration: InputDecoration(
                                hintText: "Написать комментарий...",
                                filled: true,
                                fillColor: Color(0xFFF1F5F9),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none)
                            )
                        )
                    ),
                    const SizedBox(width: 10),
                    CircleAvatar(
                        backgroundColor: Colors.black,
                        child: IconButton(
                            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                            onPressed: () async {
                              if (commentController.text.isEmpty) return;
                              await _supabase.from('blog_comments').insert({'blog_id': blog['id'], 'user_id': _supabase.auth.currentUser!.id, 'content': commentController.text});
                              await _supabase.from('blogs').update({'comments': (blog['comments'] ?? 0) + 1}).eq('id', blog['id']);
                              commentController.clear();
                              setState(() {});
                            }
                        )
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(String? dateStr) {
    if (dateStr == null) return "";
    final date = DateTime.parse(dateStr);
    final diff = DateTime.now().difference(date);

    if (diff.inDays >= 365) {
      int years = (diff.inDays / 365).floor();
      return "$years ${years == 1 ? "год" : years < 5 ? "года" : "лет"} назад";
    } else if (diff.inDays >= 30) {
      int months = (diff.inDays / 30).floor();
      return "$months ${months == 1 ? "месяц" : months < 5 ? "месяца" : "месяцев"} назад";
    } else if (diff.inDays > 0) {
      return "${diff.inDays} ${diff.inDays == 1 ? "день" : diff.inDays < 5 ? "дня" : "дней"} назад";
    } else if (diff.inHours > 0) {
      return "${diff.inHours} ч. назад";
    } else {
      return "только что";
    }
  }

  void _openDetailList(String title, String tableName) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => UserItemsListScreen(title: title, userId: widget.userId ?? _supabase.auth.currentUser!.id, tableName: tableName)));
  }

  ImageProvider? _getSafeAvatar(String? url) {
    if (url == null || url.isEmpty || !url.startsWith('http') || url.contains('%F0%9F%91%A4')) {
      return null;
    }
    return NetworkImage(url);
  }
}