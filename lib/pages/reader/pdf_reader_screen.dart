import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/book.dart';

class PdfReaderScreen extends StatefulWidget {
  final Book book;
  final String filePath;
  const PdfReaderScreen({super.key, required this.book, required this.filePath});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  PDFViewController? _pdfViewController;
  int _totalPages = 0;
  int _currentPage = 0;
  bool _isLoading = true;
  bool _showUI = true;
  bool _isVertical = false;

  // Ключ для принудительной перерисовки при смене режима
  Key _pdfKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  final _supabase = Supabase.instance.client;

  Future<void> _syncPdfProgress() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || _totalPages == 0) return;

    final progress = ((_currentPage + 1) / _totalPages * 100).toInt();

    await _supabase.from('user_recent_activity').upsert({
      'user_id': userId,
      'book_id': widget.book.id,
      'progress_percent': progress,
      'last_read_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isVertical = prefs.getBool('pdfVertical') ?? false;
      _currentPage = prefs.getInt('book_${widget.book.id}_page') ?? 0;
      _pdfKey = UniqueKey();
    });
  }

  void _savePos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('book_${widget.book.id}_page', _currentPage);
    await prefs.setBool('pdfVertical', _isVertical);
  }

  void _toggleOrientation() {
    setState(() {
      _isVertical = !_isVertical;
      _pdfKey = UniqueKey();
      _isLoading = true;
    });
    _savePos();
  }

  @override
  Widget build(BuildContext context) {
    // ВАЖНО: Убираем SafeArea вокруг Stack, чтобы комикс был на весь экран
    return Scaffold(
      backgroundColor: Colors.black, // Черный фон идеален для комиксов
      body: Stack(
        children: [
          // Основной вьювер с хаком кадрирования
          _buildCroppedPdfView(),

          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),

          // Зона управления
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => setState(() => _showUI = !_showUI),
            child: const Center(child: SizedBox(width: double.infinity, height: 300)),
          ),

          _buildTopBar(),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // --- ХАК ДЛЯ "УМНОГО КАДРИРОВАНИЯ" (ФИШКА ДЛЯ ДИПЛОМА) ---
  Widget _buildCroppedPdfView() {
    return Positioned.fill(
      // 1. ClipRect обрезает всё, что вылезло за пределы Stack
      child: ClipRect(
        // 2. FittedBox растягивает содержимое по принципу AspectFill
        child: FittedBox(
          // BoxFit.cover — это и есть Aspect Fill.
          // Он растягивает картинку, пока она не заполнит всё пространство,
          // обрезая лишнее по меньшей стороне.
          fit: BoxFit.cover,

          // 3. Указываем реальный аспект страницы (примерно для комиксов 2:3)
          // Это нужно, чтобы FittedBox понимал, как растягивать.
          child: SizedBox(
            width: 1000, // Любые большие числа, сохраняющие пропорцию страницы
            height: 1500,

            // 4. Сам нативный PDFView
            child: PDFView(
              key: _pdfKey,
              filePath: widget.filePath,
              swipeHorizontal: !_isVertical,
              autoSpacing: false, // Выключаем отступы, они мешают растягиванию
              pageFling: true,
              pageSnap: true,
              defaultPage: _currentPage,
              // КРИТИЧНО: Используем FitWIDTH, чтобы в горизонтальном режиме
              // страница растянулась по ширине, а FittedBox дотянул её.
              fitPolicy: FitPolicy.WIDTH,
              preventLinkNavigation: false,
              onRender: (p) {
                setState(() { _totalPages = p!; _isLoading = false; });
                _pdfViewController?.setPage(_currentPage);
              },
              onViewCreated: (c) => _pdfViewController = c,
              onPageChanged: (p, _) {
                setState(() => _currentPage = p ?? 0);
                _savePos();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      top: _showUI ? 0 : -120,
      left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, bottom: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
        ),
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
            Expanded(child: Text(widget.book.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            IconButton(
              icon: Icon(_isVertical ? Icons.swap_horiz : Icons.swap_vert, color: Colors.white),
              onPressed: _toggleOrientation,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      bottom: _showUI ? 0 : -140, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 15, 20, 35),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          border: const Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Стр. ${_currentPage + 1} из $_totalPages", style: const TextStyle(color: Colors.white70)),
                Text(_totalPages > 0 ? "${((_currentPage + 1) / _totalPages * 100).toInt()}%" : "0%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 5),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: _totalPages > 0 ? _currentPage.toDouble().clamp(0, (_totalPages - 1).toDouble()) : 0.0,
                max: _totalPages > 1 ? (_totalPages - 1).toDouble() : 1.0,
                activeColor: const Color(0xFF6C63FF),
                inactiveColor: Colors.white24,
                onChanged: (v) {
                  int target = v.toInt();
                  setState(() => _currentPage = target);
                  _pdfViewController?.setPage(target);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}