import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/blog.dart';
import '../../providers/auth_provider.dart';
import '../../providers/blog_provider.dart';
import 'profile_screen.dart';

class BlogDetailPage extends StatefulWidget {
  final Blog blog;

  const BlogDetailPage({super.key, required this.blog});

  @override
  State<BlogDetailPage> createState() => _BlogDetailPageState();
}

class _BlogDetailPageState extends State<BlogDetailPage> {
  final _commentCtrl = TextEditingController();
  bool _posting = false;

  late Blog _blog;

  @override
  void initState() {
    super.initState();
    _blog = widget.blog;
    // Загрузим детальные данные и комментарии
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BlogProvider>().selectBlog(widget.blog.id);
    });
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    final ok = await context.read<BlogProvider>().addBlogComment(
      blogId: _blog.id,
      content: text,
    );
    setState(() => _posting = false);
    if (ok) _commentCtrl.clear();
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays >= 30) return '${(d.inDays / 30).floor()} мес. назад';
    if (d.inDays > 0) return '${d.inDays} дн. назад';
    if (d.inHours > 0) return '${d.inHours} ч. назад';
    if (d.inMinutes > 0) return '${d.inMinutes} мин. назад';
    return 'только что';
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.read<AuthProvider>().currentUser?.id;
    final isOwn = myId == _blog.userId;

    final imageUrl = widget.blog.imageUrl; // Тут теперь лежит путь, например 'userId/123.jpg'
    final publicUrl = imageUrl != null
        ? Supabase.instance.client.storage.from('blog-images').getPublicUrl(imageUrl)
        : null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Шапка с картинкой
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: Colors.black,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: publicUrl != null // Используем вычисленную переменную publicUrl
                      ? Image.network(
                    publicUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(color: Colors.grey[200], child: const Icon(Icons.broken_image));
                    },
                  )
                      : Container(color: Colors.grey[200]), // Если пути нет, показываем серый фон
                ),
                actions: [
                  if (isOwn)
                    PopupMenuButton<String>(
                      icon:
                      const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (val) async {
                        if (val == 'delete') {
                          await context
                              .read<BlogProvider>()
                              .deleteBlog(_blog.id);
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Удалить',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                ],
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Заголовок
                      Text(
                        _blog.title,
                        style: GoogleFonts.manrope(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 1.2),
                      ),
                      const SizedBox(height: 16),

                      // Автор
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProfileScreen(userId: _blog.userId),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundImage:
                              (_blog.author?.avatarUrl?.isNotEmpty ==
                                  true)
                                  ? NetworkImage(
                                  _blog.author!.avatarUrl!)
                                  : null,
                              child: (_blog.author?.avatarUrl?.isNotEmpty !=
                                  true)
                                  ? const Icon(Icons.person, size: 18)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _blog.author?.username ?? 'Автор',
                                  style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14),
                                ),
                                Text(
                                  _timeAgo(_blog.createdAt),
                                  style: GoogleFonts.manrope(
                                      color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // Лайк
                            Consumer<BlogProvider>(
                              builder: (_, prov, __) {
                                final current = prov.selectedBlog?.id ==
                                    _blog.id
                                    ? prov.selectedBlog!
                                    : _blog;
                                return GestureDetector(
                                  onTap: () =>
                                      prov.toggleLike(current),
                                  child: Row(
                                    children: [
                                      Icon(
                                        current.isLikedByMe
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        color: current.isLikedByMe
                                            ? Colors.red
                                            : Colors.black45,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 4),
                                      Text('${current.likes}',
                                          style: const TextStyle(
                                              fontSize: 13)),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Контент
                      Text(
                        _blog.content,
                        style: GoogleFonts.manrope(
                            fontSize: 16,
                            height: 1.8,
                            color: const Color(0xFF2D3436)),
                      ),

                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 16),

                      Text('Комментарии',
                          style: GoogleFonts.manrope(
                              fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),

                      // Комментарии
                      Consumer<BlogProvider>(
                        builder: (_, prov, __) {
                          final comments = prov.blogComments;
                          if (comments.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text('Пока нет комментариев',
                                  style: GoogleFonts.manrope(
                                      color: Colors.grey)),
                            );
                          }
                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: comments.length,
                            separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                thickness: 1,
                                color: Color(0xFFF1F1F1)),
                            itemBuilder: (_, i) =>
                                _CommentTile(comment: comments[i]),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Поле ввода внизу
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      style: GoogleFonts.manrope(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Написать комментарий...',
                        filled: true,
                        fillColor: const Color(0xFFF1F1F1),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _posting ? null : _sendComment,
                    child: CircleAvatar(
                      backgroundColor: _posting
                          ? Colors.grey
                          : Colors.black,
                      radius: 22,
                      child: _posting
                          ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
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
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFF1F1F1),
            child: const Icon(Icons.person, size: 16, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comment['username'] ?? 'Пользователь',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                Text(comment['content'] ?? '',
                    style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF2D3436),
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}