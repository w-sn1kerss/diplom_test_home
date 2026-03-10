import 'dart:io';
import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/book_model.dart';

enum ReadingMode {
  horizontal,
  vertical,
}

class EpubReaderScreen extends StatefulWidget {
  final Book book;
  final String filePath;

  const EpubReaderScreen({
    super.key,
    required this.book,
    required this.filePath,
  });

  @override
  State<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends State<EpubReaderScreen> with WidgetsBindingObserver {
  late PageController _pageController;
  final ScrollController _scrollController = ScrollController();

  List<String> _pages = [];
  int _currentPage = 0;
  double _currentScrollOffset = 0.0;
  double _maxScrollExtent = 0.0; // Для расчёта прогресса в вертикальном режиме
  bool _isLoading = true;
  bool _showUI = true;

  // Настройки
  double _fontSize = 18.0;
  double _lineHeight = 1.6;
  bool _isNightMode = false;
  String _fontFamily = 'Georgia';
  ReadingMode _readingMode = ReadingMode.horizontal;

  final TextEditingController _jumpToPageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    _loadEpub();
    _loadSettings();

    _scrollController.addListener(_saveScrollOffset);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _saveAllData();
    }
  }

  Future<void> _saveAllData() async {
    await _saveCurrentPosition();
    await _saveSettings();
  }

  void _saveScrollOffset() {
    if (_scrollController.hasClients && _readingMode == ReadingMode.vertical) {
      _currentScrollOffset = _scrollController.offset;
      _maxScrollExtent = _scrollController.position.maxScrollExtent;
    }
  }

  /// Рассчитывает прогресс чтения от 0.0 до 1.0 (универсально для обоих режимов)
  double _getReadingProgress() {
    if (_pages.isEmpty) return 0.0;

    if (_readingMode == ReadingMode.horizontal) {
      return _currentPage / (_pages.length - 1);
    } else {
      if (_maxScrollExtent <= 0) return 0.0;
      return _currentScrollOffset / _maxScrollExtent;
    }
  }

  /// Переход к позиции на основе прогресса (0.0 - 1.0)
  void _jumpToProgress(double progress) {
    progress = progress.clamp(0.0, 1.0);

    if (_readingMode == ReadingMode.horizontal) {
      final targetPage = (progress * (_pages.length - 1)).round();
      if (_currentPage != targetPage) {
        _currentPage = targetPage;
        _pageController.jumpToPage(targetPage);
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && _maxScrollExtent > 0) {
          final targetOffset = progress * _maxScrollExtent;
          if ((_currentScrollOffset - targetOffset).abs() > 10) {
            _currentScrollOffset = targetOffset;
            _scrollController.jumpTo(targetOffset);
          }
        }
      });
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontSize = prefs.getDouble('fontSize') ?? 18.0;
      _lineHeight = prefs.getDouble('lineHeight') ?? 1.6;
      _isNightMode = prefs.getBool('isNightMode') ?? false;
      _fontFamily = prefs.getString('fontFamily') ?? 'Georgia';

      final modeIndex = prefs.getInt('readingMode') ?? 0;
      _readingMode = ReadingMode.values[modeIndex];
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', _fontSize);
    await prefs.setDouble('lineHeight', _lineHeight);
    await prefs.setBool('isNightMode', _isNightMode);
    await prefs.setString('fontFamily', _fontFamily);
    await prefs.setInt('readingMode', _readingMode.index);
    setState(() {});
  }

  Future<void> _loadEpub() async {
    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();
      final book = await EpubReader.readBook(bytes);

      String fullContent = '';
      for (var chapter in book.Chapters ?? []) {
        if (chapter.HtmlContent != null) {
          fullContent += chapter.HtmlContent!;
        }
      }

      List<String> pages = [];
      const int charsPerPage = 2000;

      for (int i = 0; i < fullContent.length; i += charsPerPage) {
        int end = (i + charsPerPage < fullContent.length)
            ? i + charsPerPage
            : fullContent.length;

        String pageContent = fullContent.substring(i, end);

        if (pageContent.contains('<') && !pageContent.contains('>')) {
          int nextTagEnd = fullContent.indexOf('>', end);
          if (nextTagEnd != -1) {
            pageContent = fullContent.substring(i, nextTagEnd + 1);
            i = nextTagEnd;
          }
        }

        pages.add(pageContent);
      }

      setState(() {
        _pages = pages;
        _isLoading = false;
      });

      await _loadSavedPosition();
      print('Создано страниц: ${_pages.length}');
    } catch (e) {
      print('Ошибка загрузки EPUB: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSavedPosition() async {
    final prefs = await SharedPreferences.getInstance();

    // Загружаем универсальный прогресс (если есть)
    final savedProgress = prefs.getDouble('book_${widget.book.id}_progress');

    // Загружаем старые значения для обратной совместимости
    final savedPage = prefs.getInt('book_${widget.book.id}_page') ?? 0;
    final savedOffset = prefs.getDouble('book_${widget.book.id}_offset') ?? 0.0;
    final savedMode = prefs.getInt('book_${widget.book.id}_mode') ?? 0;

    setState(() {
      // Восстанавливаем режим чтения для этой книги
      if (savedMode == 1) {
        _readingMode = ReadingMode.vertical;
      }
    });

    // Применяем позицию
    if (savedProgress != null) {
      // Используем универсальный прогресс
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpToProgress(savedProgress);
      });
    } else {
      // Обратная совместимость со старыми сохранениями
      setState(() {
        _currentPage = savedPage.clamp(0, _pages.length - 1);
        _currentScrollOffset = savedOffset;
      });

      if (_readingMode == ReadingMode.horizontal) {
        _pageController.jumpToPage(_currentPage);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_currentScrollOffset);
          }
        });
      }
    }
  }

  Future<void> _saveCurrentPosition() async {
    final prefs = await SharedPreferences.getInstance();

    // Сохраняем универсальный прогресс
    final progress = _getReadingProgress();
    await prefs.setDouble('book_${widget.book.id}_progress', progress);

    // Сохраняем старые значения для обратной совместимости
    await prefs.setInt('book_${widget.book.id}_page', _currentPage);
    await prefs.setDouble('book_${widget.book.id}_offset', _currentScrollOffset);
    await prefs.setInt('book_${widget.book.id}_mode', _readingMode.index);
  }

  /// Переключение режима с синхронизацией позиции
  void _toggleReadingMode() async {
    // Сохраняем текущую позицию перед переключением
    await _saveCurrentPosition();

    // Получаем прогресс в текущем режиме
    final progress = _getReadingProgress();

    setState(() {
      _readingMode = _readingMode == ReadingMode.horizontal
          ? ReadingMode.vertical
          : ReadingMode.horizontal;
    });

    // После перестройки виджета переходим к той же позиции
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToProgress(progress);
    });

    await _saveSettings();
  }

  String _processHtmlContent(String html) {
    if (html.isEmpty) return '<p></p>';

    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
            
            body {
                font-family: '$_fontFamily', Georgia, serif;
                font-size: ${_fontSize}px;
                line-height: $_lineHeight;
                color: ${_isNightMode ? '#E0E0E0' : '#2C3E50'};
                background-color: ${_isNightMode ? '#1A1A1A' : '#FFFFFF'};
                padding: 30px 25px;
                min-height: 100vh;
                word-wrap: break-word;
                max-width: 800px;
                margin: 0 auto;
            }
            
            h1 {
                font-size: ${_fontSize * 2.2}px;
                font-weight: 700;
                margin: 1.5em 0 1em;
                color: ${_isNightMode ? '#BB86FC' : '#6C63FF'};
                text-align: center;
            }
            
            h2 {
                font-size: ${_fontSize * 1.8}px;
                font-weight: 600;
                margin: 1.3em 0 0.8em;
                color: ${_isNightMode ? '#BB86FC' : '#6C63FF'};
            }
            
            h3 {
                font-size: ${_fontSize * 1.5}px;
                font-weight: 500;
                margin: 1.2em 0 0.6em;
                color: ${_isNightMode ? '#BB86FC' : '#6C63FF'};
            }
            
            p {
                margin: 1.2em 0;
                text-align: left;
                font-size: ${_fontSize}px;
                line-height: $_lineHeight;
                color: ${_isNightMode ? '#E0E0E0' : '#2C3E50'};
            }
            
            strong, b {
                font-weight: 700;
                color: ${_isNightMode ? '#FFFFFF' : '#000000'};
            }
            
            em, i {
                font-style: italic;
            }
            
            blockquote {
                margin: 1.5em 0;
                padding: 1em 1.5em;
                border-left: 4px solid ${_isNightMode ? '#BB86FC' : '#6C63FF'};
                background-color: ${_isNightMode ? '#2D2D2D' : '#F8F9FA'};
                font-style: italic;
            }
            
            ul, ol {
                margin: 1.2em 0;
                padding-left: 2em;
            }
            
            li {
                margin: 0.5em 0;
                line-height: $_lineHeight;
            }
            
            img {
                max-width: 100%;
                height: auto;
                display: block;
                margin: 1.5em auto;
                border-radius: 8px;
            }
        </style>
    </head>
    <body>
        $html
    </body>
    </html>
    ''';
  }

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isNightMode ? Colors.grey[900] : Colors.grey[50],
      body: Stack(
        children: [
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6C63FF),
              ),
            )
          else if (_pages.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Не удалось загрузить книгу',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          else
            GestureDetector(
              onTap: _toggleUI,
              child: _readingMode == ReadingMode.horizontal
                  ? PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                  _saveCurrentPosition();
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return Container(
                    color: _isNightMode ? Colors.grey[900] : Colors.white,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        child: HtmlWidget(
                          _processHtmlContent(_pages[index]),
                        ),
                      ),
                    ),
                  );
                },
              )
                  : Container(
                color: _isNightMode ? Colors.grey[900] : Colors.white,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Column(
                      children: _pages.asMap().entries.map((entry) {
                        int idx = entry.key;
                        String page = entry.value;
                        return Column(
                          children: [
                            if (idx > 0)
                              const Divider(height: 30, color: Colors.transparent),
                            HtmlWidget(
                              _processHtmlContent(page),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),

          // Верхняя панель
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _showUI ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !_showUI,
              child: Container(
                decoration: BoxDecoration(
                  color: (_isNightMode ? Colors.grey[900] : Colors.white)?.withOpacity(0.95),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            color: _isNightMode ? Colors.white70 : Colors.black87,
                          ),
                          onPressed: () {
                            _saveCurrentPosition();
                            Navigator.pop(context);
                          },
                        ),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.book.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _isNightMode ? Colors.white70 : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _readingMode == ReadingMode.horizontal
                                    ? 'Стр. ${_currentPage + 1} / ${_pages.length}'
                                    : 'Режим: непрерывный',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _isNightMode ? Colors.white54 : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _readingMode == ReadingMode.horizontal
                                ? Icons.swap_vert
                                : Icons.swap_horiz,
                            color: _isNightMode ? Colors.white70 : Colors.black87,
                          ),
                          onPressed: _toggleReadingMode,
                          tooltip: _readingMode == ReadingMode.horizontal
                              ? 'Переключить на непрерывный режим'
                              : 'Переключить на постраничный режим',
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.settings,
                            color: _isNightMode ? Colors.white70 : Colors.black87,
                          ),
                          onPressed: _showSettings,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Нижняя панель (только для горизонтального режима)
          if (_readingMode == ReadingMode.horizontal)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _showUI ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_showUI,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: (_isNightMode ? Colors.grey[900] : Colors.white)?.withOpacity(0.95),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${_currentPage + 1}/${_pages.length}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _isNightMode ? Colors.white70 : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: (_currentPage + 1) / _pages.length,
                            backgroundColor: Colors.grey[300],
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: Icon(
                            Icons.grid_view,
                            color: _isNightMode ? Colors.white70 : Colors.grey[600],
                            size: 22,
                          ),
                          onPressed: _showPageNavigator,
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: BoxDecoration(
                color: _isNightMode ? Colors.grey[900] : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Настройки',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        ListTile(
                          title: const Text('Текущий режим'),
                          subtitle: Text(
                            _readingMode == ReadingMode.horizontal
                                ? 'Постраничный (свайпы)'
                                : 'Непрерывный (скролл)',
                          ),
                          trailing: Icon(
                            _readingMode == ReadingMode.horizontal
                                ? Icons.swap_horiz
                                : Icons.swap_vert,
                            color: const Color(0xFF6C63FF),
                          ),
                        ),
                        const Divider(),

                        _buildSettingSlider(
                          title: 'Размер шрифта',
                          value: _fontSize,
                          min: 12,
                          max: 28,
                          onChanged: (value) {
                            setSheetState(() => _fontSize = value);
                            _saveSettings();
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildSettingSlider(
                          title: 'Межстрочный интервал',
                          value: _lineHeight,
                          min: 1.2,
                          max: 2.5,
                          onChanged: (value) {
                            setSheetState(() => _lineHeight = value);
                            _saveSettings();
                          },
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          title: const Text('Шрифт'),
                          trailing: DropdownButton<String>(
                            value: _fontFamily,
                            items: const [
                              DropdownMenuItem(value: 'Georgia', child: Text('Georgia')),
                              DropdownMenuItem(value: 'Arial', child: Text('Arial')),
                              DropdownMenuItem(value: 'Times New Roman', child: Text('Times New Roman')),
                            ],
                            onChanged: (value) {
                              setSheetState(() => _fontFamily = value!);
                              _saveSettings();
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          title: const Text('Ночной режим'),
                          trailing: Switch(
                            value: _isNightMode,
                            onChanged: (value) {
                              setSheetState(() => _isNightMode = value);
                              _saveSettings();
                            },
                            activeColor: const Color(0xFF6C63FF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingSlider({
    required String title,
    required double value,
    required double min,
    required double max,
    required Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(title),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: () => onChanged((value - 1).clamp(min, max)),
            ),
            Expanded(
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: ((max - min) * 10).toInt(),
                activeColor: const Color(0xFF6C63FF),
                onChanged: onChanged,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => onChanged((value + 1).clamp(min, max)),
            ),
          ],
        ),
        Center(
          child: Text(
            value is int ? value.toString() : value.toStringAsFixed(1),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  void _showPageNavigator() {
    _jumpToPageController.clear();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isNightMode ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Перейти к странице',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _jumpToPageController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Введите номер (1-${_pages.length})',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (value) {
                final page = int.tryParse(value);
                if (page != null && page > 0 && page <= _pages.length) {
                  final progress = (page - 1) / (_pages.length - 1);
                  setState(() {
                    _currentPage = page - 1;
                  });

                  if (_readingMode == ReadingMode.horizontal) {
                    _pageController.jumpToPage(_currentPage);
                  } else {
                    _jumpToProgress(progress);
                  }

                  _saveCurrentPosition();
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveCurrentPosition();
    _pageController.dispose();
    _scrollController.removeListener(_saveScrollOffset);
    _scrollController.dispose();
    _jumpToPageController.dispose();
    super.dispose();
  }
}