import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/blog_provider.dart';
import 'blog_detail_page.dart';
import 'create_blog_page.dart';

class ProfileScreen extends StatefulWidget {
  /// Если null — открывается профиль текущего пользователя.
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _accent = Color(0xFF6C63FF);
  static const _accentOrange = Color(0xFFFF5722);

  late final String? _targetId;
  late bool _isOwn;

  @override
  void initState() {
    super.initState();
    final myId = context.read<AuthProvider>().currentUser?.id;
    _targetId = widget.userId ?? myId;
    _isOwn = (_targetId == myId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_targetId != null) {
        context.read<ProfileProvider>().loadProfile(_targetId!);
      }
    });
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final xfile =
    await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (xfile == null) return;

    try {
      await context.read<AuthProvider>().uploadAvatar(xfile);
      if (mounted && _targetId != null) {
        context.read<ProfileProvider>().loadProfile(_targetId!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  Future<void> _showEditBottomSheet() async {
    final auth = context.read<AuthProvider>();
    final profile = auth.profile;
    final nameCtrl = TextEditingController(text: profile?.username);
    final fullNameCtrl = TextEditingController(text: profile?.fullName);
    final bioCtrl = TextEditingController(text: profile?.bio);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Редактировать профиль',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              decoration:
              const InputDecoration(labelText: 'Имя пользователя'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: fullNameCtrl,
              decoration: const InputDecoration(labelText: 'Полное имя'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bioCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'О себе', alignLabelWithHint: true),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await context.read<AuthProvider>().updateProfile(
                  username: nameCtrl.text.trim(),
                  fullName: fullNameCtrl.text.trim(),
                  bio: bioCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted && _targetId != null) {
                  context.read<ProfileProvider>().loadProfile(_targetId!);
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ProfileProvider, AuthProvider>(
      builder: (_, profileProv, auth, __) {
        if (profileProv.loading) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final profile = profileProv.viewedProfile;
        final stats = profileProv.viewedStats;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          body: CustomScrollView(
            slivers: [
              _buildAppBar(profile, auth),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Имя
                      Text(
                        profile?.username ?? 'Пользователь',
                        style: GoogleFonts.manrope(
                            fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                      if (profile?.fullName?.isNotEmpty == true)
                        Text(profile!.fullName!,
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 14)),
                      if (profile?.bio?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Text(profile!.bio!,
                            style: const TextStyle(
                                fontSize: 14, height: 1.5)),
                      ],
                      const SizedBox(height: 20),

                      // Статистика
                      _StatsRow(stats: stats),
                      const SizedBox(height: 24),

                      // Follow / Edit кнопки
                      _buildActionButton(profileProv),
                      const SizedBox(height: 28),

                      // Достижения
                      if (profileProv.achievements.isNotEmpty) ...[
                        const Text('Достижения',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 18)),
                        const SizedBox(height: 12),
                        _AchievementsRow(
                            achievements: profileProv.achievements),
                        const SizedBox(height: 24),
                      ],

                      // Блоги
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Блоги',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 18)),
                          if (_isOwn)
                            TextButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const CreateBlogPage()),
                              ).then((_) {
                                context.read<BlogProvider>().loadBlogs();
                                if (_targetId != null) {
                                  context
                                      .read<ProfileProvider>()
                                      .loadProfile(_targetId!);
                                }
                              }),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Добавить'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _BlogsSection(userId: _targetId),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppBar(Profile? profile, AuthProvider auth) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: _accent,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6C63FF), Color(0xFF9C27B0)],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white24,
                      backgroundImage:
                      (profile?.avatarUrl?.isNotEmpty == true)
                          ? NetworkImage(profile!.avatarUrl!)
                          : null,
                      child: (profile?.avatarUrl?.isNotEmpty != true)
                          ? const Icon(Icons.person,
                          size: 50, color: Colors.white70)
                          : null,
                    ),
                    if (_isOwn)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickAndUploadAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 16, color: _accent),
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
      actions: [
        if (_isOwn) ...[
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: _showEditBottomSheet,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () async {
              await context.read<AuthProvider>().signOut();
            },
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton(ProfileProvider prov) {
    if (_isOwn) return const SizedBox.shrink();
    if (_targetId == null) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => prov.toggleFollow(_targetId!),
            style: ElevatedButton.styleFrom(
              backgroundColor:
              prov.isFollowing ? Colors.white : _accent,
              foregroundColor:
              prov.isFollowing ? _accent : Colors.white,
              side: const BorderSide(color: _accent),
            ),
            child: Text(prov.isFollowing ? 'Отписаться' : 'Подписаться'),
          ),
        ),
      ],
    );
  }
}

// ─── Widgets ─────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final UserStats? stats;
  const _StatsRow({this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)
        ],
      ),
      child: Row(
        children: [
          _StatItem(
              value: '${stats?.booksReadCount ?? 0}', label: 'Прочитано'),
          _StatItem(
              value: '${stats?.reviewsCount ?? 0}', label: 'Отзывов'),
          _StatItem(
              value: '${stats?.blogsCount ?? 0}', label: 'Блогов'),
          _StatItem(
              value: '${stats?.achievementsCount ?? 0}',
              label: 'Достиж.'),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 20)),
          Text(label,
              style: const TextStyle(color: Colors.black45, fontSize: 11)),
        ],
      ),
    );
  }
}

class _AchievementsRow extends StatelessWidget {
  final List<Achievement> achievements;
  const _AchievementsRow({required this.achievements});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: achievements.length,
        itemBuilder: (_, i) {
          final a = achievements[i];
          return Tooltip(
            message: a.description ?? a.title,
            child: Container(
              width: 70,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor:
                    const Color(0xFF6C63FF).withOpacity(0.1),
                    backgroundImage: a.iconUrl != null
                        ? NetworkImage(a.iconUrl!)
                        : null,
                    child: a.iconUrl == null
                        ? const Icon(Icons.emoji_events,
                        color: Color(0xFF6C63FF))
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Text(a.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BlogsSection extends StatefulWidget {
  final String? userId;
  const _BlogsSection({this.userId});

  @override
  State<_BlogsSection> createState() => _BlogsSectionState();
}

class _BlogsSectionState extends State<_BlogsSection> {
  List<Blog> _blogs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBlogs();
  }

  Future<void> _loadBlogs() async {
    if (widget.userId == null) return;
    // Используем провайдер для получения данных
    final blogs = await context.read<BlogProvider>().fetchBlogsByAuthor(widget.userId!);
    if (mounted) {
      setState(() {
        _blogs = blogs;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_blogs.isEmpty) return const Text('Блогов нет');

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _blogs.length,
      itemBuilder: (_, i) {
        final b = _blogs[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: (b.imageUrl?.isNotEmpty == true)
              ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(b.imageUrl!, width: 48, height: 48, fit: BoxFit.cover))
              : Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: const Color(0xFFEDF0F4), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.article_outlined, color: Colors.black38)),
          title: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(_timeAgo(b.createdAt), style: const TextStyle(fontSize: 11)),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BlogDetailPage(blog: b))),
        );
      },
    );
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays > 0) return '${d.inDays} дн. назад';
    if (d.inHours > 0) return '${d.inHours} ч. назад';
    return 'только что';
  }
}