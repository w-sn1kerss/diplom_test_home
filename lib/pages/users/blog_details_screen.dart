import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_screen.dart';

class BlogDetailScreen extends StatelessWidget {
  final Map<String, dynamic> blog;
  final Map<String, dynamic>? userData;
  final bool isOwnProfile;
  final Function onUpdate;

  const BlogDetailScreen({
    super.key,
    required this.blog,
    this.userData,
    required this.isOwnProfile,
    required this.onUpdate
  });

  // Функция-помощник для безопасной загрузки аватарки
  ImageProvider? _getSafeAvatar(String? url) {
    if (url == null || url.isEmpty || !url.startsWith('http') || url.contains('%F0%9F%91%A4')) {
      return null;
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final commentController = TextEditingController();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 350,
                pinned: true,
                backgroundColor: Colors.black,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: blog['image_url'] != null
                      ? Image.network(blog['image_url'], fit: BoxFit.cover)
                      : Container(color: Colors.grey[200]),
                ),
                actions: [
                  if (isOwnProfile)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (value) async {
                        if (value == 'delete') {
                          await supabase.from('blogs').delete().eq('id', blog['id']);
                          Navigator.pop(context);
                          onUpdate();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'delete', child: Text("Удалить", style: TextStyle(color: Colors.red))),
                      ],
                    ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        blog['title'] ?? '',
                        style: GoogleFonts.manrope(fontSize: 28, fontWeight: FontWeight.w900, height: 1.2),
                      ),
                      const SizedBox(height: 20),

                      // АВТОР БЛОГА
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: blog['user_id']))),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundImage: _getSafeAvatar(userData?['avatar_url']),
                              child: _getSafeAvatar(userData?['avatar_url']) == null ? const Icon(Icons.person, size: 18) : null,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(userData?['username'] ?? "Автор", style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 14)),
                                Text(_getTimeAgo(blog['created_at']), style: GoogleFonts.manrope(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),
                      Text(blog['content'] ?? '', style: GoogleFonts.manrope(fontSize: 16, height: 1.8, color: const Color(0xFF2D3436))),
                      const SizedBox(height: 40),
                      const Divider(thickness: 1, height: 1),
                      const SizedBox(height: 25),
                      Text("Комментарии", style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),

                      // СПИСОК КОММЕНТАРИЕВ В СТИЛЕ ОТЗЫВОВ
                      StreamBuilder(
                        stream: supabase.from('blog_comments')
                            .stream(primaryKey: ['id'])
                            .eq('blog_id', blog['id'])
                            .order('created_at', ascending: false),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          final comments = snapshot.data as List;
                          if (comments.isEmpty) return Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Text("Пока нет комментариев", style: GoogleFonts.manrope(color: Colors.grey)),
                          );

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: comments.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F1F1)),
                            itemBuilder: (context, i) {
                              final comment = comments[i];
                              return _buildCommentItem(context, comment);
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ПОЛЕ ВВОДА
          _buildInputArea(supabase, commentController, blog['id']),
        ],
      ),
    );
  }

  // ВИДЖЕТ ОДНОГО КОММЕНТАРИЯ (КАК ОТЗЫВ)
  Widget _buildCommentItem(BuildContext context, Map<String, dynamic> comment) {
    final supabase = Supabase.instance.client;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: FutureBuilder(
        // Загружаем профиль того, кто оставил коммент
        future: supabase.from('profiles').select('username, avatar_url').eq('id', comment['user_id']).maybeSingle(),
        builder: (context, AsyncSnapshot snapshot) {
          final profile = snapshot.data;
          final String name = profile?['username'] ?? "Пользователь";
          final String? avatar = profile?['avatar_url'];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: comment['user_id']))),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFFF1F1F1),
                      backgroundImage: _getSafeAvatar(avatar),
                      child: _getSafeAvatar(avatar) == null ? const Icon(Icons.person, size: 16, color: Colors.grey) : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: comment['user_id']))),
                          child: Text(name, style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 14)),
                        ),
                        Text(_getTimeAgo(comment['created_at']), style: GoogleFonts.manrope(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                comment['content'] ?? '',
                style: GoogleFonts.manrope(fontSize: 14, color: const Color(0xFF2D3436), height: 1.5),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInputArea(SupabaseClient supabase, TextEditingController controller, dynamic blogId) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: GoogleFonts.manrope(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Написать комментарий...",
                    filled: true,
                    fillColor: const Color(0xFFF1F1F1),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () async {
                  if (controller.text.trim().isEmpty) return;
                  await supabase.from('blog_comments').insert({
                    'blog_id': blogId,
                    'user_id': supabase.auth.currentUser!.id,
                    'content': controller.text.trim(),
                  });
                  controller.clear();
                },
                child: const CircleAvatar(
                  backgroundColor: Colors.black,
                  radius: 22,
                  child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
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
    if (diff.inDays >= 30) return "${(diff.inDays / 30).floor()} мес. назад";
    if (diff.inDays > 0) return "${diff.inDays} дн. назад";
    if (diff.inHours > 0) return "${diff.inHours} ч. назад";
    if (diff.inMinutes > 0) return "${diff.inMinutes} мин. назад";
    return "только что";
  }
}