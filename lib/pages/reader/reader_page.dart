import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:epubx/epubx.dart';

import '../../models/models.dart';
import '../../providers/book_provider.dart';
import '../../utils/utils.dart';

class ReaderPage extends StatefulWidget {
  final Book book;

  const ReaderPage({super.key, required this.book});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage>
    with SingleTickerProviderStateMixin {
  // ---- Ð¡Ð¾ÑÑ‚Ð¾ÑÐ½Ð¸Ðµ ----
  _ReaderState _state = _ReaderState.loading;
  String? _errorMessage;

  // PDF
  String? _pdfPath;
  PDFViewController? _pdfController;
  int _currentPage = 0;
  int _totalPages = 1;

  // EPUB
  EpubBook? _epubBook;
  final PageController _epubPageController = PageController();
  List<String> _epubChapterHtmls = [];
  int _epubChapter = 0;

  // Ð¢Ð°Ð¹Ð¼ÐµÑ€ debounce Ð´Ð»Ñ ÑÐ¾Ñ…Ñ€Ð°Ð½ÐµÐ½Ð¸Ñ Ð¿Ñ€Ð¾Ð³Ñ€ÐµÑÑÐ°
  Timer? _saveTimer;

  // ÐŸÐ°Ð½ÐµÐ»ÑŒ Ð·Ð°Ð¼ÐµÑ‚Ð¾Ðº
  bool _showNotes = false;

  // Ð¡ÐºÑ€Ñ‹Ñ‚Ð¸Ðµ UI Ð¿Ñ€Ð¸ Ñ‡Ñ‚ÐµÐ½Ð¸Ð¸
  bool _uiVisible = true;

  bool get _isPdf => widget.book.fileUrl?.toLowerCase().endsWith('.pdf') == true;
  bool get _isEpub => widget.book.fileUrl?.toLowerCase().endsWith('.epub') == true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _loadFile();
    _loadNotesAndProgress();
  }

  @override
  void dispose() {
    // ÐšÐ Ð˜Ð¢Ð˜Ð§ÐÐž: Ð¾Ñ‚Ð¼ÐµÐ½ÑÐµÐ¼ Ñ‚Ð°Ð¹Ð¼ÐµÑ€ Ñ‡Ñ‚Ð¾Ð±Ñ‹ Ð¸Ð·Ð±ÐµÐ¶Ð°Ñ‚ÑŒ ÑƒÑ‚ÐµÑ‡ÐºÐ¸
    _saveTimer?.cancel();
    // Ð¡Ð¾Ñ…Ñ€Ð°Ð½ÑÐµÐ¼ Ð¿Ñ€Ð¾Ð³Ñ€ÐµÑÑ Ð¿Ñ€Ð¸ Ð·Ð°ÐºÑ€Ñ‹Ñ‚Ð¸Ð¸
    _forceSaveProgress();

    _epubPageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  void _forceSaveProgress() {
    final percent = _isPdf
        ? (_totalPages > 0
        ? ((_currentPage + 1) / _totalPages * 100).round()
        : 0)
        : (_epubBook != null && _epubChapterHtmls.isNotEmpty
        ? ((_epubChapter + 1) / _epubChapterHtmls.length * 100).round()
        : 0);

    if (percent > 0) {
      // Ð¡Ð¸Ð½Ñ…Ñ€Ð¾Ð½Ð½Ñ‹Ð¹ Ð²Ñ‹Ð·Ð¾Ð² â€” Ð¸ÑÐ¿Ð¾Ð»ÑŒÐ·ÑƒÐµÐ¼ Ñ€ÐµÐ¿Ð¾Ð·Ð¸Ñ‚Ð¾Ñ€Ð¸Ð¹ Ð½Ð°Ð¿Ñ€ÑÐ¼ÑƒÑŽ
      context.read<BookProvider>().saveProgress(widget.book.id, percent);
    }
  }

  Future<void> _loadFile() async {
    final url = widget.book.fileUrl;
    if (url == null || url.isEmpty) {
      setState(() {
        _state = _ReaderState.error;
        _errorMessage = 'URL Ñ„Ð°Ð¹Ð»Ð° Ð½Ðµ ÑƒÐºÐ°Ð·Ð°Ð½';
      });
      return;
    }

    try {
      setState(() => _state = _ReaderState.loading);

      if (_isPdf) {
        await _loadPdf(url);
      } else if (_isEpub) {
        await _loadEpub(url);
      } else {
        setState(() {
          _state = _ReaderState.error;
          _errorMessage = 'ÐÐµÐ¿Ð¾Ð´Ð´ÐµÑ€Ð¶Ð¸Ð²Ð°ÐµÐ¼Ñ‹Ð¹ Ñ„Ð¾Ñ€Ð¼Ð°Ñ‚ Ñ„Ð°Ð¹Ð»Ð°';
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _ReaderState.error;
        _errorMessage = switch (e.type) {
          DioExceptionType.connectionTimeout => 'ÐŸÑ€ÐµÐ²Ñ‹ÑˆÐµÐ½Ð¾ Ð²Ñ€ÐµÐ¼Ñ Ð¾Ð¶Ð¸Ð´Ð°Ð½Ð¸Ñ',
          DioExceptionType.connectionError => 'ÐÐµÑ‚ ÑÐ¾ÐµÐ´Ð¸Ð½ÐµÐ½Ð¸Ñ Ñ Ð¸Ð½Ñ‚ÐµÑ€Ð½ÐµÑ‚Ð¾Ð¼',
          _ => 'ÐžÑˆÐ¸Ð±ÐºÐ° Ð·Ð°Ð³Ñ€ÑƒÐ·ÐºÐ¸ Ñ„Ð°Ð¹Ð»Ð°',
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _ReaderState.error;
        _errorMessage = 'ÐÐµ ÑƒÐ´Ð°Ð»Ð¾ÑÑŒ Ð¾Ñ‚ÐºÑ€Ñ‹Ñ‚ÑŒ Ñ„Ð°Ð¹Ð»: $e';
      });
    }
  }

  Future<void> _loadPdf(String url) async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'book_${widget.book.id}.pdf';
    final filePath = '${dir.path}/$fileName';
    final file = File(filePath);

    // ÐšÑÑˆ â€” Ð½Ðµ Ð·Ð°Ð³Ñ€ÑƒÐ¶Ð°ÐµÐ¼ Ð¿Ð¾Ð²Ñ‚Ð¾Ñ€Ð½Ð¾
    if (!await file.exists()) {
      await Dio().download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            // ÐœÐ¾Ð¶Ð½Ð¾ Ð´Ð¾Ð±Ð°Ð²Ð¸Ñ‚ÑŒ Ð¿Ñ€Ð¾Ð³Ñ€ÐµÑÑ-Ð±Ð°Ñ€ Ð·Ð°Ð³Ñ€ÑƒÐ·ÐºÐ¸
          }
        },
      );
    }

    if (!mounted) return;
    setState(() {
      _pdfPath = filePath;
      _state = _ReaderState.ready;
    });
  }

  Future<void> _loadEpub(String url) async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'book_${widget.book.id}.epub';
    final filePath = '${dir.path}/$fileName';
    final file = File(filePath);

    if (!await file.exists()) {
      await Dio().download(url, filePath);
    }

    final bytes = await file.readAsBytes();
    final epub = await EpubReader.readBook(bytes);

    // Ð¡Ð¾Ð±Ð¸Ñ€Ð°ÐµÐ¼ HTML ÑÑ‚Ñ€Ð°Ð½Ð¸Ñ†Ñ‹ Ð¸Ð· Ð²ÑÐµÑ… Ð³Ð»Ð°Ð²
    final htmls = <String>[];
    for (final chapter in epub.Chapters ?? []) {
      if (chapter.HtmlContent != null) {
        htmls.add(chapter.HtmlContent!);
      }
      for (final sub in chapter.SubChapters ?? []) {
        if (sub.HtmlContent != null) htmls.add(sub.HtmlContent!);
      }
    }

    if (!mounted) return;
    setState(() {
      _epubBook = epub;
      _epubChapterHtmls = htmls;
      _state = _ReaderState.ready;
    });
  }

  void _loadNotesAndProgress() {
    final provider = context.read<BookProvider>();
    provider.loadNotes(widget.book.id);
  }

  // ---- Debounce ÑÐ¾Ñ…Ñ€Ð°Ð½ÐµÐ½Ð¸Ðµ Ð¿Ñ€Ð¾Ð³Ñ€ÐµÑÑÐ° ----
  void _onPageChanged(int page, {bool isEpub = false}) {
    if (isEpub) {
      _epubChapter = page;
    } else {
      _currentPage = page;
    }

    // ÐžÑ‚Ð¼ÐµÐ½ÑÐµÐ¼ Ð¿Ñ€ÐµÐ´Ñ‹Ð´ÑƒÑ‰Ð¸Ð¹ Ñ‚Ð°Ð¹Ð¼ÐµÑ€ Ð¸ Ð·Ð°Ð¿ÑƒÑÐºÐ°ÐµÐ¼ Ð½Ð¾Ð²Ñ‹Ð¹
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      final percent = _isPdf
          ? ((_currentPage + 1) / _totalPages * 100).round()
          : ((_epubChapter + 1) / _epubChapterHtmls.length * 100).round();

      context.read<BookProvider>().saveProgress(widget.book.id, percent);
    });
  }

  // ---- Ð”Ð¸Ð°Ð»Ð¾Ð³ Ð´Ð¾Ð±Ð°Ð²Ð»ÐµÐ½Ð¸Ñ Ð·Ð°Ð¼ÐµÑ‚ÐºÐ¸ ----
  Future<void> _showAddNoteDialog() async {
    final controller = TextEditingController();
    String selectedColor = '#FFFF00';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ð”Ð¾Ð±Ð°Ð²Ð¸Ñ‚ÑŒ Ð·Ð°Ð¼ÐµÑ‚ÐºÑƒ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ð¡Ñ‚Ñ€Ð°Ð½Ð¸Ñ†Ð° ${_currentPage + 1}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),

              // Ð¦Ð²ÐµÑ‚ Ð·Ð°Ð¼ÐµÑ‚ÐºÐ¸
              Row(
                children: [
                  const Text('Ð¦Ð²ÐµÑ‚: '),
                  const SizedBox(width: 8),
                  for (final color in [
                    '#FFFF00',
                    '#FF9800',
                    '#4CAF50',
                    '#2196F3',
                    '#E91E63'
                  ])
                    GestureDetector(
                      onTap: () =>
                          setSheetState(() => selectedColor = color),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(int.parse(
                              color.replaceAll('#', '0xFF'))),
                          shape: BoxShape.circle,
                          border: selectedColor == color
                              ? Border.all(
                              color: Colors.black, width: 2)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              TextField(
                controller: controller,
                maxLines: 4,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Ð’Ð²ÐµÐ´Ð¸Ñ‚Ðµ Ð·Ð°Ð¼ÐµÑ‚ÐºÑƒ...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (controller.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    final success =
                    await context.read<BookProvider>().addNote(
                      bookId: widget.book.id,
                      pageIndex: _currentPage,
                      content: controller.text,
                      colorHex: selectedColor,
                    );
                    if (mounted && success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ð—Ð°Ð¼ÐµÑ‚ÐºÐ° Ð´Ð¾Ð±Ð°Ð²Ð»ÐµÐ½Ð°'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text('Ð¡Ð¾Ñ…Ñ€Ð°Ð½Ð¸Ñ‚ÑŒ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- UI ----
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: GestureDetector(
        onTap: () => setState(() => _uiVisible = !_uiVisible),
        child: Stack(
          children: [
            // ÐšÐ¾Ð½Ñ‚ÐµÐ½Ñ‚
            _buildContent(),

            // Ð’ÐµÑ€Ñ…Ð½ÑÑ Ð¿Ð°Ð½ÐµÐ»ÑŒ
            AnimatedSlide(
              duration: const Duration(milliseconds: 250),
              offset: _uiVisible ? Offset.zero : const Offset(0, -1),
              child: _buildTopBar(),
            ),

            // ÐÐ¸Ð¶Ð½ÑÑ Ð¿Ð°Ð½ÐµÐ»ÑŒ
            if (_state == _ReaderState.ready)
              AnimatedSlide(
                duration: const Duration(milliseconds: 250),
                offset: _uiVisible ? Offset.zero : const Offset(0, 1),
                child: _buildBottomBar(),
              ),

            // ÐŸÐ°Ð½ÐµÐ»ÑŒ Ð·Ð°Ð¼ÐµÑ‚Ð¾Ðº
            if (_showNotes)
              _buildNotesPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case _ReaderState.loading:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Ð—Ð°Ð³Ñ€ÑƒÐ·ÐºÐ° ÐºÐ½Ð¸Ð³Ð¸...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        );

      case _ReaderState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.red, size: 64),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'ÐÐµÐ¸Ð·Ð²ÐµÑÑ‚Ð½Ð°Ñ Ð¾ÑˆÐ¸Ð±ÐºÐ°',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadFile,
                  icon: const Icon(Icons.refresh),
                  label: const Text('ÐŸÐ¾Ð²Ñ‚Ð¾Ñ€Ð¸Ñ‚ÑŒ'),
                ),
              ],
            ),
          ),
        );

      case _ReaderState.ready:
        if (_isPdf && _pdfPath != null) return _buildPdfView();
        if (_isEpub && _epubChapterHtmls.isNotEmpty) return _buildEpubView();
        return const Center(
          child: Text('Ð¤Ð¾Ñ€Ð¼Ð°Ñ‚ Ð½Ðµ Ð¿Ð¾Ð´Ð´ÐµÑ€Ð¶Ð¸Ð²Ð°ÐµÑ‚ÑÑ',
              style: TextStyle(color: Colors.white)),
        );
    }
  }

  Widget _buildPdfView() {
    return PDFView(
      filePath: _pdfPath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      onRender: (pages) {
        setState(() => _totalPages = pages ?? 1);
      },
      onViewCreated: (controller) {
        _pdfController = controller;
      },
      onPageChanged: (page, total) {
        if (page != null) {
          setState(() {
            _currentPage = page;
            _totalPages = total ?? 1;
          });
          _onPageChanged(page);
        }
      },
      onError: (error) {
        setState(() {
          _state = _ReaderState.error;
          _errorMessage = 'ÐžÑˆÐ¸Ð±ÐºÐ° Ð¾Ñ‚Ð¾Ð±Ñ€Ð°Ð¶ÐµÐ½Ð¸Ñ PDF: $error';
        });
      },
    );
  }

  Widget _buildEpubView() {
    return PageView.builder(
      controller: _epubPageController,
      itemCount: _epubChapterHtmls.length,
      onPageChanged: (page) {
        setState(() => _epubChapter = page);
        _onPageChanged(page, isEpub: true);
      },
      itemBuilder: (context, index) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 80, 20, 100),
          child: SelectableText(
            // ÐŸÑ€Ð¾ÑÑ‚Ð°Ñ Ð¾Ñ‡Ð¸ÑÑ‚ÐºÐ° HTML Ñ‚ÐµÐ³Ð¾Ð² Ð´Ð»Ñ Ð¾Ñ‚Ð¾Ð±Ñ€Ð°Ð¶ÐµÐ½Ð¸Ñ
            _epubChapterHtmls[index]
                .replaceAll(RegExp(r'<[^>]*>'), '')
                .replaceAll('&nbsp;', ' ')
                .replaceAll('&amp;', '&')
                .replaceAll('&lt;', '<')
                .replaceAll('&gt;', '>'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.6,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xCC000000), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  widget.book.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.note_add_outlined, color: Colors.white),
                onPressed: _showAddNoteDialog,
              ),
              IconButton(
                icon: Icon(
                  _showNotes ? Icons.notes : Icons.notes_outlined,
                  color: _showNotes ? Colors.amber : Colors.white,
                ),
                onPressed: () => setState(() => _showNotes = !_showNotes),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final progress = _isPdf
        ? (_totalPages > 0 ? (_currentPage + 1) / _totalPages : 0.0)
        : (_epubChapterHtmls.isNotEmpty
        ? (_epubChapter + 1) / _epubChapterHtmls.length
        : 0.0);

    final pageLabel = _isPdf
        ? 'Ð¡Ñ‚Ñ€. ${_currentPage + 1} Ð¸Ð· $_totalPages'
        : 'Ð“Ð»Ð°Ð²Ð° ${_epubChapter + 1} Ð¸Ð· ${_epubChapterHtmls.length}';

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xCC000000), Colors.transparent],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: progress.toDouble(),
                backgroundColor: Colors.white24,
                valueColor:
                const AlwaysStoppedAnimation(Color(0xFF6C63FF)),
              ),
              const SizedBox(height: 8),
              Text(
                pageLabel,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotesPanel() {
    return Positioned(
      right: 0,
      top: 80,
      bottom: 80,
      width: MediaQuery.of(context).size.width * 0.75,
      child: Material(
        elevation: 8,
        child: Consumer<BookProvider>(
          builder: (context, provider, _) {
            final notes = provider.notes;
            return Column(
              children: [
                ListTile(
                  title: Text('Ð—Ð°Ð¼ÐµÑ‚ÐºÐ¸ (${notes.length})'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _showNotes = false),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: notes.isEmpty
                      ? const Center(
                    child: Text('ÐÐµÑ‚ Ð·Ð°Ð¼ÐµÑ‚Ð¾Ðº'),
                  )
                      : ListView.builder(
                    itemCount: notes.length,
                    itemBuilder: (_, i) {
                      final note = notes[i];
                      return ListTile(
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Color(int.parse(
                                note.colorHex.replaceAll('#', '0xFF'))),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(
                          note.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle:
                        Text('Ð¡Ñ‚Ñ€. ${note.pageIndex + 1}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () =>
                              provider.deleteNote(note.id),
                        ),
                        onTap: () {
                          // ÐŸÐµÑ€ÐµÑ…Ð¾Ð´ Ðº ÑÑ‚Ñ€Ð°Ð½Ð¸Ñ†Ðµ Ð·Ð°Ð¼ÐµÑ‚ÐºÐ¸
                          if (_isPdf && _pdfController != null) {
                            _pdfController!
                                .setPage(note.pageIndex);
                          } else if (_isEpub) {
                            _epubPageController.jumpToPage(
                                note.pageIndex);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _ReaderState { loading, ready, error }