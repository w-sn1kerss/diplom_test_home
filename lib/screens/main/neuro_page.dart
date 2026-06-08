import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/gigachat_service.dart';

class NeuroPage extends StatefulWidget {
  const NeuroPage({super.key});

  @override
  State<NeuroPage> createState() => _NeuroPageState();
}

class _NeuroPageState extends State<NeuroPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  late GigaChatService _gigaChatService;

  @override
  void initState() {
    super.initState();
    _setupService();
    _loadChatHistory();
  }

  void _setupService() {
    _gigaChatService = GigaChatService(
      clientId: dotenv.env['GIGACHAT_CLIENT_ID']!,
      clientSecret: dotenv.env['GIGACHAT_CLIENT_SECRET']!,
    );
    setState(() => _isInitialized = true);
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedChat = prefs.getString('chat_history');
    if (savedChat != null) {
      setState(() {
        _messages = List<Map<String, dynamic>>.from(json.decode(savedChat));
      });
      _scrollToBottom();
    } else {
      setState(() {
        _messages.add({
          'text': 'Рад твоему визиту в мою обитель. О какой книге ты хочешь поговорить сегодня?',
          'isUser': false,
        });
      });
    }
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_history', json.encode(_messages));
  }

  Future<void> _clearChat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_history');
    setState(() {
      _messages = [
        {'text': 'Полки снова чисты. Начнем новый рассказ?', 'isUser': false}
      ];
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    String messageText = _messageController.text;
    if (messageText.trim().isEmpty || !_isInitialized) return;

    setState(() {
      _messageController.clear();
      _messages.add({'text': messageText, 'isUser': true});
      _isLoading = true;
    });
    _scrollToBottom();
    await _saveChatHistory();

    try {
      final response = await _gigaChatService.sendBookQuery(messageText);
      setState(() {
        _messages.add({'text': response, 'isUser': false});
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'text': 'Тишина библиотечных залов прервана ошибкой... Попробуй еще раз.',
          'isUser': false
        });
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
      await _saveChatHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Важно для прозрачной навигации
      body: Stack(
        children: [
          // 1. ФОН
          Positioned.fill(
            child: Image.network(
              'https://i.pinimg.com/originals/60/d8/44/60d844679e07db517c19fdc5dd7af089.gif',
              fit: BoxFit.cover,
            ),
          ),

          // 2. ЗАТЕМНЕНИЕ
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),

          // 3. КОНТЕНТ
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white38),
                    onPressed: _clearChat,
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildGlassBubble(msg['text'], msg['isUser'] ?? false);
                    },
                  ),
                ),

                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text('Хранитель ищет ответ на полках...',
                        style: TextStyle(color: Colors.white60, fontSize: 12, fontStyle: FontStyle.italic)),
                  ),

                // ВЕРНУЛ КРУТУЮ НИЖНЮЮ ЧАСТЬ
                _buildBlurInput(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Тот самый стеклянный баббл
  Widget _buildGlassBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: isUser ? const Radius.circular(2) : const Radius.circular(20),
            bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(2),
          ),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
        ),
      ),
    );
  }

  // ТА САМАЯ КРУТАЯ НИЖНЯЯ ПАНЕЛЬ
  Widget _buildBlurInput() {
    return Container(
      // Тот самый свободный отступ из первой версии
      padding: EdgeInsets.fromLTRB(20, 0, 10, MediaQuery.of(context).padding.bottom + 20),
      child: Row(
        children: [
          // Поле ввода без границ и плашек, как в самом начале
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              maxLines: null,
              decoration: const InputDecoration(
                hintText: 'Напиши...',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none, // Полное отсутствие рамок
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),

          // Кнопка-иконка без лишних подложек (максимальный минимализм)
          _isLoading
              ? const Padding(
            padding: EdgeInsets.all(12.0),
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)
            ),
          )
              : IconButton(
            icon: const Icon(
                Icons.auto_awesome, // Твой новый «магический» значок
                color: Colors.white,
                size: 26
            ),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}