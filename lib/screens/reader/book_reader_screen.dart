  import 'dart:io';
  import 'package:flutter/material.dart';
  import 'package:path_provider/path_provider.dart';
  import 'package:dio/dio.dart';
  import 'package:supabase_flutter/supabase_flutter.dart';
  import '../../models/book_model.dart';
  import '../../models/comment_model.dart';
  import '../../services/supabase_comments_service.dart';
  import '../users/book_comments_screen.dart';
  import '../users/profile_screen.dart';
import 'epub_reader_screen.dart';
  import 'pdf_reader_screen.dart';

  class BookReaderScreen extends StatefulWidget {
    final Book book;
    const BookReaderScreen({super.key, required this.book});

    @override
    State<BookReaderScreen> createState() => _BookReaderScreenState();
  }

  class _BookReaderScreenState extends State<BookReaderScreen> {
    final SupabaseCommentsService _commentsService = SupabaseCommentsService();
    final _supabase = Supabase.instance.client;

    Set<String> _expandedComments = {};

    bool _isOverviewSelected = true;
    bool _isBookDownloaded = false;
    bool _isDownloading = false;
    double _downloadProgress = 0.0;

    List<Comment> _comments = [];
    List<Book> _recommendations = [];
    double _averageRating = 0.0;
    bool _isLoadingRecs = true;

    final Color _bgColor = const Color(0xFFF8F9FB);
    final Color _textPrimary = const Color(0xFF1A1A1A);
    final Color _textSecondary = const Color(0xFF666666);
    final Color _accentColor = const Color(0xFFFF5722);
    final Color _chipBg = const Color(0xFFE1E5EB);

    @override
    void initState() {
      super.initState();
      _checkIfDownloaded();
      _loadData();
      _loadRecommendations();
    }

    Future<void> _loadData() async {
      try {
        final comments = await _commentsService.getComments(widget.book.id);
        if (mounted) {
          setState(() {
            _comments = comments;
            if (_comments.isNotEmpty) {
              // Считаем только те комментарии, где есть оценка
              final ratedComments = _comments.where((c) => c.rating != null);
              if (ratedComments.isNotEmpty) {
                double sum = ratedComments.fold(0, (prev, c) => prev + c.rating!);
                _averageRating = sum / ratedComments.length;
              } else {
                _averageRating = 0.0;
              }
            }
          });
        }
      } catch (e) {
        debugPrint("Ошибка загрузки комментов: $e");
      }
    }

    Future<void> _loadRecommendations() async {
      try {
        final response = await _supabase
            .from('books')
            .select()
            .overlaps('categories', widget.book.categories)
            .neq('id', widget.book.id)
            .limit(6);

        final List<Book> recs = (response as List).map((b) {
          return Book(
            id: b['id'].toString(),
            title: b['title'] ?? 'Без названия',
            author: b['author'] ?? 'Неизвестный автор',
            // ТЕПЕРЬ ПРАВИЛЬНО:
            coverUrl: b['cover_url'] ?? '', // Картинка обложки
            fileUrl: b['file_url'] ?? '',   // Файл (PDF/EPUB)
            description: b['description'] ?? '',
            pages: (b['pages'] as num?)?.toInt() ?? 0,
            categories: b['categories'] != null ? List<String>.from(b['categories']) : [],
          );
        }).toList();

        if (mounted) {
          setState(() {
            _recommendations = recs;
            _isLoadingRecs = false;
          });
        }
      } catch (e) {
        debugPrint("Ошибка рекомендаций: $e");
        if (mounted) setState(() => _isLoadingRecs = false);
      }
    }

    Future<File> _getLocalFile() async {
      final directory = await getApplicationDocumentsDirectory();
      // Очищаем URL от параметров Supabase (если есть), чтобы корректно взять расширение
      final cleanUrl = widget.book.fileUrl.split('?').first;
      final extension = cleanUrl.split('.').last.toLowerCase();

      // Список поддерживаемых расширений
      final safeExt = ['pdf', 'epub', 'fb2', 'zip'].contains(extension) ? extension : 'pdf';
      return File('${directory.path}/book_${widget.book.id}.$safeExt');
    }

    Future<void> _checkIfDownloaded() async {
      final file = await _getLocalFile();
      final exists = await file.exists();
      if (mounted) setState(() => _isBookDownloaded = exists);
    }

    Future<void> _downloadBook() async {
      if (_isDownloading || _isBookDownloaded) return;

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final file = await _getLocalFile();
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });

      try {
        await Dio().download(
          widget.book.fileUrl,
          file.path,
          onReceiveProgress: (received, total) {
            if (total != -1 && mounted) {
              setState(() => _downloadProgress = received / total);
            }
          },
        );

        await _supabase.from('user_downloads').upsert({
          'user_id': userId,
          'book_id': widget.book.id,
          'local_path': file.path,
          'downloaded_at': DateTime.now().toIso8601String(),
        });

        if (mounted) {
          setState(() {
            _isDownloading = false;
            _isBookDownloaded = true;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ошибка загрузки: $e"), backgroundColor: Colors.red),
        );
      }
    }

    Future<void> _confirmDelete() async {
      final bool? result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Удалить книгу?"),
          content: const Text("Файл книги будет удален из памяти устройства."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Отмена")),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Удалить", style: TextStyle(color: Colors.red))
            ),
          ],
        ),
      );

      if (result == true) {
        _deleteBook();
      }
    }

    Future<void> _deleteBook() async {
      final userId = _supabase.auth.currentUser?.id;
      try {
        final file = await _getLocalFile();
        if (await file.exists()) await file.delete();

        if (userId != null) {
          await _supabase.from('user_downloads')
              .delete()
              .eq('user_id', userId)
              .eq('book_id', widget.book.id);
        }

        if (mounted) {
          setState(() => _isBookDownloaded = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Книга удалена")),
          );
        }
      } catch (e) {
        debugPrint("Ошибка при удалении: $e");
      }
    }

    void _openBook() async {
      final file = await _getLocalFile();
      if (await file.exists()) {
        if (!mounted) return;
        final isEpub = file.path.toLowerCase().endsWith('.epub');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => isEpub
                ? EpubReaderScreen(book: widget.book, filePath: file.path)
                : PdfReaderScreen(book: widget.book, filePath: file.path),
          ),
        );
      } else {
        _downloadBook();
      }
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _bgColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: _textPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text("О книге", style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w900, fontSize: 18)),
          actions: [
            if (_isBookDownloaded)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                onPressed: _confirmDelete,
              ),
          ],
        ),
        // Кнопка теперь "привязана" к экрану и не уезжает при скролле
        bottomNavigationBar: _isOverviewSelected
            ? null
            : SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: ElevatedButton(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => BookCommentsScreen(bookId: widget.book.id, bookTitle: widget.book.title)
                ));
                _loadData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                side: BorderSide(color: _accentColor, width: 1.5),
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text("Написать отзыв",
                  style: TextStyle(color: _accentColor, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 10),
              _buildBookHeader(),
              const SizedBox(height: 30),
              _buildMainActions(),
              const SizedBox(height: 30),
              _buildTabSwitcher(),
              const SizedBox(height: 25),
              _isOverviewSelected ? _buildOverviewTab() : _buildReviewsTab(),
              const SizedBox(height: 40), // Немного уменьшил отступ, так как кнопка теперь внизу
            ],
          ),
        ),
      );
    }

    Widget _buildBookHeader() {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                widget.book.coverUrl, // КАРТИНКА ОБЛОЖКИ
                width: 115, height: 170,
                fit: BoxFit.cover,
                errorBuilder: (c,e,s) => Container(width: 115, height: 170, color: _chipBg, child: const Icon(Icons.book)),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.book.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(widget.book.author, style: TextStyle(color: _accentColor, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 15),
                Text('${widget.book.pages} стр.', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: widget.book.categories.map((cat) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: _chipBg, borderRadius: BorderRadius.circular(6)),
                    child: Text(cat, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  )).toList(),
                ),
              ],
            ),
          )
        ],
      );
    }

    Widget _buildMainActions() {
      return Row(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isBookDownloaded ? _openBook : _downloadBook,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isBookDownloaded ? const Color(0xFF2E333D) : _accentColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(double.infinity, 52),
                    elevation: 0,
                  ),
                  child: _isDownloading
                      ? const SizedBox.shrink()
                      : Text(_isBookDownloaded ? "Читать книгу" : "Скачать",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                if (_isDownloading)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _downloadProgress,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              color: Colors.white,
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text("${(_downloadProgress * 100).toInt()}%",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (!_isBookDownloaded) ...[
            const SizedBox(width: 12),
            Container(
              height: 52, width: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withOpacity(0.05)),
              ),
              child: IconButton(
                icon: Icon(Icons.bookmark_border_rounded, color: _textPrimary),
                onPressed: () {},
              ),
            ),
          ],
        ],
      );
    }

    Widget _buildTabSwitcher() {
      return Row(
        children: [
          _buildTabItem("Обзор", _isOverviewSelected, () => setState(() => _isOverviewSelected = true)),
          const SizedBox(width: 30),
          _buildTabItem("Отзывы (${_comments.length})", !_isOverviewSelected, () => setState(() => _isOverviewSelected = false)),
        ],
      );
    }

    Widget _buildTabItem(String label, bool isActive, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: isActive ? _textPrimary : _textSecondary, fontWeight: FontWeight.w800, fontSize: 16)),
            if (isActive) Container(margin: const EdgeInsets.only(top: 4), width: 20, height: 3, color: _accentColor),
          ],
        ),
      );
    }

    Widget _buildOverviewTab() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.book.description,
              style: TextStyle(color: _textPrimary.withOpacity(0.7), fontSize: 14, height: 1.6)),
          const SizedBox(height: 30),
          const Text("Вам также может понравиться", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          _isLoadingRecs
              ? const Center(child: CircularProgressIndicator())
              : _recommendations.isEmpty
              ? Text("Похожих книг пока нет", style: TextStyle(color: _textSecondary))
              : SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recommendations.length,
              itemBuilder: (context, i) {
                final b = _recommendations[i];
                return GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => BookReaderScreen(book: b)),
                    );
                  },
                  child: Container(
                    width: 110,
                    margin: const EdgeInsets.only(right: 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              b.coverUrl, // КАРТИНКА ОБЛОЖКИ
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(
                                  color: _chipBg,
                                  child: const Icon(Icons.book, color: Colors.grey)
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(b.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
                        ),
                        Text(b.author,
                            maxLines: 1,
                            style: TextStyle(fontSize: 10, color: _textSecondary)
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    Widget _buildReviewsTab() {
      return Column(
        children: [
          _buildRatingSummaryCard(),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _comments.length,
            separatorBuilder: (context, index) => Divider(
              color: Colors.black.withOpacity(0.06),
              thickness: 1,
              height: 1, // Линия стала тоньше и аккуратнее
            ),
            itemBuilder: (context, index) => _buildCommentItem(_comments[index]),
          ),
        ],
      );
    }

    Widget _buildRatingSummaryCard() {
      Map<int, int> distribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
      for (var c in _comments) {
        int r = c.rating?.toInt() ?? 0;
        if (distribution.containsKey(r)) distribution[r] = distribution[r]! + 1;
      }
      int total = _comments.length;
      double divisor = total > 0 ? total.toDouble() : 1.0;

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]
        ),
        child: Row(
          children: [
            Column(
              children: [
                Text(_averageRating.toStringAsFixed(1), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900)),
                Row(children: List.generate(5, (i) => Icon(Icons.star_rounded, size: 16, color: i < _averageRating.floor() ? Colors.amber : _chipBg))),
                const SizedBox(height: 6),
                Text("$total отзывов", style: TextStyle(fontSize: 11, color: _textSecondary)),
              ],
            ),
            const SizedBox(width: 30),
            Expanded(
              child: Column(
                children: [
                  _buildStarProgress(5, (distribution[5] ?? 0) / divisor),
                  _buildStarProgress(4, (distribution[4] ?? 0) / divisor),
                  _buildStarProgress(3, (distribution[3] ?? 0) / divisor),
                  _buildStarProgress(2, (distribution[2] ?? 0) / divisor),
                  _buildStarProgress(1, (distribution[1] ?? 0) / divisor),
                ],
              ),
            )
          ],
        ),
      );
    }

    Widget _buildStarProgress(int star, double pct) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text("$star", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: _chipBg,
                    color: Colors.amber,
                    minHeight: 6
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildCommentItem(Comment comment) {
      final bool isExpanded = _expandedComments.contains(comment.id);

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ОБЕРНУЛИ АВАТАРКУ
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ProfileScreen(userId: comment.userId))
                  ),
                  child: FutureBuilder(
                    future: _supabase.from('profiles').select('avatar_url').eq('id', comment.userId).maybeSingle(),
                    builder: (context, AsyncSnapshot snapshot) {
                      String? url;
                      if (snapshot.hasData && snapshot.data != null) url = snapshot.data['avatar_url'];
                      return CircleAvatar(
                        radius: 21,
                        backgroundColor: _accentColor.withOpacity(0.1),
                        backgroundImage: (url != null && url.isNotEmpty) ? NetworkImage(url) : null,
                        child: (url == null || url.isEmpty)
                            ? Text(comment.userName.isNotEmpty ? comment.userName[0].toUpperCase() : "?",
                            style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold, fontSize: 15))
                            : null,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ОБЕРНУЛИ ИМЯ
                      GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ProfileScreen(userId: comment.userId))
                        ),
                        child: Text(comment.userName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -0.2)),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: List.generate(5, (i) => Icon(
                            Icons.star_rounded,
                            size: 13,
                            color: i < (comment.rating ?? 0) ? Colors.amber : _chipBg
                        )),
                      ),
                    ],
                  ),
                ),
                Text(comment.timeAgo,
                    style: TextStyle(color: _textSecondary.withOpacity(0.7), fontSize: 12)),
              ],
            ),

            // Отступ 54 пикселя: 21(радиус)*2 + 12(отступ) = 54.
            // Это создает ровную вертикальную линию от буквы имени до текста.
            Padding(
              padding: const EdgeInsets.only(left: 54, top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comment.content,
                    maxLines: isExpanded ? null : 3,
                    overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _textPrimary.withOpacity(0.85),
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w400, // Чистый, читаемый шрифт
                    ),
                  ),
                  if (comment.content.length > 90)
                    GestureDetector(
                      onTap: () => setState(() {
                        if (isExpanded) _expandedComments.remove(comment.id);
                        else _expandedComments.add(comment.id);
                      }),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(
                              isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              color: Colors.black,
                              size: 26,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }