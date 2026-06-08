import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/blog.dart';
import '../../providers/auth_provider.dart';
import '../../providers/blog_provider.dart';
import 'blog_detail_page.dart';
import 'create_blog_page.dart';

class BlogListPage extends StatefulWidget {
  const BlogListPage({super.key});

  @override
  State<BlogListPage> createState() => _BlogListPageState();
}

class _BlogListPageState extends State<BlogListPage> {
  static const _accent = Color(0xFF6C63FF);
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BlogProvider>().loadBlogs();
    });
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      context.read<BlogProvider>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Блоги',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: _accent),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateBlogPage()),
            ).then((_) => context.read<BlogProvider>().loadBlogs()),
          ),
        ],
      ),
      body: Consumer<BlogProvider>(
        builder: (_, prov, __) {
          if (prov.loading && prov.blogs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (prov.blogs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.article_outlined,
                      size: 64, color: Colors.black26),
                  const SizedBox(height: 16),
                  const Text('Блогов пока нет',
                      style: TextStyle(color: Colors.black45)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CreateBlogPage()),
                    ).then((_) => context.read<BlogProvider>().loadBlogs()),
                    icon: const Icon(Icons.add),
                    label: const Text('Написать первым'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<BlogProvider>().loadBlogs(),
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount:
              prov.blogs.length + (prov.hasMore ? 1 : 0),
              itemBuilder: (_, i) {
                if (i >= prov.blogs.length) {
                  return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ));
                }
                return _BlogCard(blog: prov.blogs[i]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _BlogCard extends StatelessWidget {
  final Blog blog;
  const _BlogCard({required this.blog});


  @override
  Widget build(BuildContext context) {
    final myId =
        context.read<AuthProvider>().currentUser?.id;
    final isOwn = myId == blog.userId;
    final supabase = Supabase.instance.client;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BlogDetailPage(blog: blog),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04), blurRadius: 12)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Картинка
            if (blog.imageUrl != null && blog.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.network(
                  // ВСТАВЛЯЕМ СЮДА: динамическое создание ссылки
                  supabase.storage.from('blogs').getPublicUrl(blog.imageUrl!),

                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(height: 180, color: const Color(0xFFEDF0F4), child: const Icon(Icons.broken_image)),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Автор
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: (blog.author?.avatarUrl?.isNotEmpty ==
                            true)
                            ? NetworkImage(blog.author!.avatarUrl!)
                            : null,
                        child: (blog.author?.avatarUrl?.isNotEmpty != true)
                            ? const Icon(Icons.person, size: 16)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(blog.author?.username ?? 'Автор',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const Spacer(),
                      Text(_timeAgo(blog.createdAt),
                          style: const TextStyle(
                              color: Colors.black45, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Заголовок
                  Text(blog.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 17)),
                  const SizedBox(height: 6),
                  Text(blog.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 14, height: 1.4)),
                  const SizedBox(height: 14),
                  // Лайки / комментарии
                  Row(
                    children: [
                      _IconCount(
                        icon: blog.isLikedByMe
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        count: blog.likes,
                        color: blog.isLikedByMe
                            ? Colors.red
                            : Colors.black45,
                        onTap: () => context
                            .read<BlogProvider>()
                            .toggleLike(blog),
                      ),
                      const SizedBox(width: 16),
                      _IconCount(
                        icon: Icons.chat_bubble_outline_rounded,
                        count: blog.comments,
                        color: Colors.black45,
                      ),
                      if (isOwn) ...[
                        const Spacer(),
                        GestureDetector(
                          onTap: () async {
                            final ok = await context
                                .read<BlogProvider>()
                                .deleteBlog(blog.id);
                            if (!ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Ошибка удаления')),
                              );
                            }
                          },
                          child: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays >= 30) return '${(d.inDays / 30).floor()} мес.';
    if (d.inDays > 0) return '${d.inDays} дн.';
    if (d.inHours > 0) return '${d.inHours} ч.';
    if (d.inMinutes > 0) return '${d.inMinutes} мин.';
    return 'только что';
  }
}

class _IconCount extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  const _IconCount(
      {required this.icon,
        required this.count,
        required this.color,
        this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 4),
          Text('$count',
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}