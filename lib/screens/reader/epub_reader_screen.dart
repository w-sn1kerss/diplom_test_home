import 'dart:io';
import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/book_model.dart';

enum ReadingMode { horizontal, vertical }

class EpubReaderScreen extends StatefulWidget {
  final Book book;
  final String filePath;

  const EpubReaderScreen({super.key, required this.book, required this.filePath});

  @override
  State<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends State<EpubReaderScreen> {
  late PageController _pageController;
  late ScrollController _scrollController;

  String _fullCleanHtml = "";
  List<String> _pages = [];
  int _currentPage = 0;
  double _currentProgress = 0.0;
  bool _isLoading = true;
  bool _showUI = true;

  // --- ХРАНЕНИЕ ЗАМЕТОК ДЛЯ ДИПЛОМА ---
  List<Map<String, dynamic>> _bookNotes = []; // Заметки текущей книги

  double _fontSize = 18.0;
  double _horizontalPadding = 25.0;
  int _themeIndex = 0;
  ReadingMode _readingMode = ReadingMode.horizontal;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _scrollController = ScrollController()..addListener(_updateVerticalProgress);
    _initReader();
  }

  Future<void> _initReader() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSize = prefs.getDouble('fontSize') ?? 18.0;
    _themeIndex = prefs.getInt('themeIndex') ?? 0;
    _readingMode = ReadingMode.values[prefs.getInt('readingMode') ?? 0];
    _currentProgress = prefs.getDouble('book_${widget.book.id}_progress') ?? 0.0;
    _horizontalPadding = prefs.getDouble('hPadding') ?? 25.0;

    await _loadAndCleanEpub();
    _repaginate();
    await _loadNotesFromSupabase(); // Загружаем аннотации

    setState(() => _isLoading = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToProgress(_currentProgress));
  }

  // --- РАБОТА С АННОТАЦИЯМИ (SUPABASE) ---
  Future<void> _loadNotesFromSupabase() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await _supabase
          .from('user_notes')
          .select()
          .eq('book_id', widget.book.id);
      setState(() {
        _bookNotes = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint("Ошибка загрузки заметок: $e");
    }
  }

  Future<void> _addNote(String content, String colorHex) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final newNote = {
        'user_id': userId,
        'book_id': widget.book.id,
        'page_index': _currentPage,
        'content': content,
        'color_hex': colorHex,
      };

      await _supabase.from('user_notes').insert(newNote);
      await _loadNotesFromSupabase(); // Перерисовываем список
    } catch (e) {
      debugPrint("Ошибка добавления заметки: $e");
    }
  }

  // Получить заметку для текущей страницы
  Map<String, dynamic>? _getNoteForCurrentPage() {
    try {
      return _bookNotes.firstWhere((note) => note['page_index'] == _currentPage);
    } catch (_) {
      return null;
    }
  }

  Future<void> _syncProgressToSupabase() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('user_recent_activity').upsert({
        'user_id': userId,
        'book_id': widget.book.id,
        'progress_percent': (_currentProgress * 100).toInt(),
        'last_viewed_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint("Ошибка синхронизации прогресса: $e");
    }
  }

  void _updateVerticalProgress() {
    if (_readingMode == ReadingMode.vertical && _scrollController.hasClients) {
      if (_scrollController.position.maxScrollExtent > 0) {
        _currentProgress = _scrollController.offset / _scrollController.position.maxScrollExtent;
      }
    }
  }

  Future<void> _loadAndCleanEpub() async {
    final file = File(widget.filePath);
    final bytes = await file.readAsBytes();
    final book = await EpubReader.readBook(bytes);

    StringBuffer buffer = StringBuffer();
    book.Chapters?.forEach((chapter) {
      if (chapter.HtmlContent != null) {
        String raw = chapter.HtmlContent!;
        if (raw.contains('<body')) raw = raw.substring(raw.indexOf('<body'));
        String clean = raw
            .replaceAll(RegExp(r'</?(body|html|head|link|meta|style|span|div)[^>]*>'), '')
            .replaceAll(RegExp(r'<a[^>]*>|</a>'), '')
            .replaceAll(RegExp(r'\s(style|class|id|onclick|target)="[^"]*"'), '')
            .trim();
        buffer.write(clean);
      }
    });
    _fullCleanHtml = buffer.toString();
  }

  void _repaginate() {
    int charsPerPage = (1300 / (_fontSize / 18) / (1 + (_horizontalPadding - 25) / 100)).round();
    List<String> tempPages = [];
    for (int i = 0; i < _fullCleanHtml.length; i += charsPerPage) {
      int end = (i + charsPerPage < _fullCleanHtml.length) ? i + charsPerPage : _fullCleanHtml.length;
      tempPages.add(_fullCleanHtml.substring(i, end));
    }
    _pages = tempPages;
  }

  void _jumpToProgress(double progress) {
    if (_pages.isEmpty) return;
    _currentProgress = progress.clamp(0.0, 1.0);

    if (_readingMode == ReadingMode.horizontal) {
      int targetPage = (_currentProgress * (_pages.length - 1)).round();
      if (_pageController.hasClients) {
        _pageController.jumpToPage(targetPage);
      }
      setState(() => _currentPage = targetPage);
    } else {
      if (_scrollController.hasClients) {
        double offset = _currentProgress * _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(offset);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Color> bgColors = [Colors.white, const Color(0xFF121212), const Color(0xFFF4ECD8)];
    final List<Color> textColors = [Colors.black87, Colors.white70, const Color(0xFF5B4636)];

    final bgColor = bgColors[_themeIndex];
    final textColor = textColors[_themeIndex];

    final activeNote = _getNoteForCurrentPage();

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            GestureDetector(
              onTap: () => setState(() => _showUI = !_showUI),
              child: _readingMode == ReadingMode.horizontal
                  ? _buildHorizontalView(textColor)
                  : _buildVerticalView(textColor),
            ),

          // ФИШКА ДЛЯ ДИПЛОМА: Отображение созданного стикера-заметки прямо на странице
          if (activeNote != null && _readingMode == ReadingMode.horizontal)
            Positioned(
              right: 15,
              top: 120,
              child: GestureDetector(
                onTap: () => _showNoteDetailsDialog(activeNote),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Color(int.parse(activeNote['color_hex'].replaceAll('#', '0xFF'))),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.sticky_note_2, size: 16, color: Colors.black87),
                      SizedBox(width: 4),
                      Text(
                        "Заметка",
                        style: TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          _buildTopBar(bgColor, textColor),
          _buildBottomPanel(bgColor, textColor),
        ],
      ),
    );
  }

  Widget _buildHorizontalView(Color textColor) {
    return PageView.builder(
      controller: _pageController,
      itemCount: _pages.length,
      onPageChanged: (i) => setState(() {
        _currentPage = i;
        _currentProgress = _pages.length > 1 ? i / (_pages.length - 1) : 0.0;
      }),
      itemBuilder: (context, index) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: _horizontalPadding, vertical: 40),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: HtmlWidget(
                    _pages[index],
                    textStyle: TextStyle(fontSize: _fontSize, height: 1.6, color: textColor),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalView(Color textColor) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(_horizontalPadding, 100, _horizontalPadding, 100),
      itemCount: _pages.length,
      itemBuilder: (context, index) => HtmlWidget(
        _pages[index],
        textStyle: TextStyle(fontSize: _fontSize, height: 1.6, color: textColor),
      ),
    );
  }

  Widget _buildTopBar(Color bg, Color text) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      top: _showUI ? 0 : -120,
      left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, bottom: 10),
        decoration: BoxDecoration(color: bg.withOpacity(0.95), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]),
        child: Row(
          children: [
            IconButton(icon: Icon(Icons.arrow_back, color: text), onPressed: () => Navigator.pop(context)),
            Expanded(child: Text(widget.book.title, style: TextStyle(color: text, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),

            // КНОПКА ДОБАВЛЕНИЯ ЗАМЕТКИ (АННОТИРОВАНИЯ)
            IconButton(
              icon: Icon(Icons.edit_note, color: text, size: 28),
              onPressed: _showCreateNoteDialog,
            ),

            IconButton(
              icon: Icon(_readingMode == ReadingMode.horizontal ? Icons.swap_vert : Icons.menu_book, color: text),
              onPressed: () {
                double p = _currentProgress;
                setState(() => _readingMode = _readingMode == ReadingMode.horizontal ? ReadingMode.vertical : ReadingMode.horizontal);
                Future.delayed(const Duration(milliseconds: 100), () => _jumpToProgress(p));
                _saveSettings();
              },
            ),
            IconButton(icon: Icon(Icons.settings, color: text), onPressed: _showSettings),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel(Color bg, Color text) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      bottom: _showUI ? 0 : -140,
      left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 15, 20, 35),
        decoration: BoxDecoration(color: bg, border: Border(top: BorderSide(color: text.withOpacity(0.1)))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Стр. ${_currentPage + 1} / ${_pages.length}", style: TextStyle(color: text, fontSize: 12)),
                Text("${(_currentProgress * 100).toInt()}%", style: TextStyle(color: text, fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: _currentProgress.clamp(0.0, 1.0),
              activeColor: const Color(0xFF6C63FF),
              onChanged: (v) {
                setState(() => _currentProgress = v);
                _jumpToProgress(v);
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- ДИАЛОГ СОЗДАНИЯ ЗАМЕТКИ (СТИКЕРА) ---
  void _showCreateNoteDialog() {
    final textController = TextEditingController();
    String selectedColor = "#FFFF00"; // По умолчанию желтый стикер
    final List<String> stickerColors = ["#FFFF00", "#8FF7A7", "#FFB3BA", "#BAE1FF"]; // Желтый, Зеленый, Розовый, Синий

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text("Оставить заметку на полях"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "Напишите ваши мысли или выделите цитату...",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: stickerColors.map((colorHex) => GestureDetector(
                  onTap: () => setDlgState(() => selectedColor = colorHex),
                  child: Container(
                    width: 35, height: 35,
                    decoration: BoxDecoration(
                        color: Color(int.parse(colorHex.replaceAll('#', '0xFF'))),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: selectedColor == colorHex ? Colors.black : Colors.transparent,
                            width: 2
                        )
                    ),
                  ),
                )).toList(),
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена")),
            ElevatedButton(
              onPressed: () {
                if (textController.text.trim().isNotEmpty) {
                  _addNote(textController.text.trim(), selectedColor);
                  Navigator.pop(context);
                }
              },
              child: const Text("Сохранить"),
            )
          ],
        ),
      ),
    );
  }

  // --- ДИАЛОГ ПРОСМОТРА СУЩЕСТВУЮЩЕЙ ЗАМЕТКИ ---
  void _showNoteDetailsDialog(Map<String, dynamic> note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.bookmark, color: Color(int.parse(note['color_hex'].replaceAll('#', '0xFF')))),
            const SizedBox(width: 8),
            const Text("Заметка на полях"),
          ],
        ),
        content: Text(note['content'], style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () async {
              await _supabase.from('user_notes').delete().eq('id', note['id']);
              await _loadNotesFromSupabase();
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Удалить", style: TextStyle(color: Colors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Закрыть")),
        ],
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _themeIndex == 1 ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setST) => Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Комфортное чтение", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildSettingRow("Размер шрифта", Row(children: [
                IconButton(icon: const Icon(Icons.remove), onPressed: () {
                  double p = _currentProgress;
                  setState(() { _fontSize--; _repaginate(); });
                  setST(() {});
                  _jumpToProgress(p);
                }),
                Text("${_fontSize.toInt()}"),
                IconButton(icon: const Icon(Icons.add), onPressed: () {
                  double p = _currentProgress;
                  setState(() { _fontSize++; _repaginate(); });
                  setST(() {});
                  _jumpToProgress(p);
                }),
              ])),
              _buildSettingRow("Ширина полей", Slider(
                value: _horizontalPadding,
                min: 10, max: 60,
                activeColor: const Color(0xFF6C63FF),
                onChanged: (v) {
                  double p = _currentProgress;
                  setState(() { _horizontalPadding = v; _repaginate(); });
                  setST(() {});
                  _jumpToProgress(p);
                },
              )),
              _buildSettingRow("Цветовая схема", Row(
                children: List.generate(3, (index) => GestureDetector(
                  onTap: () { setState(() => _themeIndex = index); setST(() {}); _saveSettings(); },
                  child: Container(
                    margin: const EdgeInsets.only(left: 10),
                    width: 35, height: 35,
                    decoration: BoxDecoration(
                      color: index == 0 ? Colors.white : index == 1 ? Colors.black : const Color(0xFFF4ECD8),
                      border: Border.all(color: _themeIndex == index ? const Color(0xFF6C63FF) : Colors.grey, width: 2),
                      shape: BoxShape.circle,
                    ),
                  ),
                )),
              )),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingRow(String label, Widget trailing) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Expanded(child: Align(alignment: Alignment.centerRight, child: trailing))],
      ),
    );
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', _fontSize);
    await prefs.setInt('themeIndex', _themeIndex);
    await prefs.setInt('readingMode', _readingMode.index);
    await prefs.setDouble('hPadding', _horizontalPadding);
    await prefs.setDouble('book_${widget.book.id}_progress', _currentProgress);

    _syncProgressToSupabase();
  }

  @override
  void dispose() {
    _syncProgressToSupabase();
    _saveSettings();
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}