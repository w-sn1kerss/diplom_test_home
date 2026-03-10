import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class GigaChatService {
  static const String _authUrl = 'https://ngw.devices.sberbank.ru:9443/api/v2/oauth';
  static const String _apiUrl = 'https://gigachat.devices.sberbank.ru/api/v1/chat/completions';

  final String clientId;
  final String clientSecret;
  final String scope;

  String? _accessToken;
  DateTime? _tokenExpiry;

  GigaChatService({
    required this.clientId,
    required this.clientSecret,
    this.scope = 'GIGACHAT_API_PERS',
  });

  // Генерация RqUID
  String _generateRqUID() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return '${_bytesToHex(bytes.sublist(0, 4))}-'
        '${_bytesToHex(bytes.sublist(4, 6))}-'
        '${_bytesToHex(bytes.sublist(6, 8))}-'
        '${_bytesToHex(bytes.sublist(8, 10))}-'
        '${_bytesToHex(bytes.sublist(10, 16))}';
  }

  String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // Специальный HTTP клиент для работы с самоподписанными сертификатами
  Future<http.Client> _getHttpClient() async {
    // Для Flutter Web используем обычный клиент
    if (identical(0, 0.0)) { // Проверка на Web платформу
      return http.Client();
    }

    // Для мобильных платформ создаем клиент с отключенной проверкой сертификатов (ТОЛЬКО ДЛЯ ТЕСТА!)
    final client = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;

    return IOClient(client);
  }

  // Получение токена
  Future<String> _getAccessToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken!;
    }

    try {
      final rqUID = _generateRqUID();
      final client = await _getHttpClient();

      try {
        final response = await client.post(
          Uri.parse(_authUrl),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json',
            'RqUID': rqUID,
            'Authorization': 'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}',
          },
          body: {
            'scope': scope,
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          _accessToken = data['access_token'];
          final expiresIn = data['expires_in'] as int? ?? 3600;
          _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
          return _accessToken!;
        } else {
          throw Exception('Ошибка получения токена: ${response.statusCode} - ${response.body}');
        }
      } finally {
        client.close();
      }
    } catch (e) {
      throw Exception('Ошибка при получении токена GigaChat: $e');
    }
  }

  // Отправка запроса к GigaChat
  Future<String> sendMessage(String message, {String? systemPrompt}) async {
    try {
      final token = await _getAccessToken();
      final client = await _getHttpClient();

      try {
        final messages = [
          if (systemPrompt != null)
            {
              'role': 'system',
              'content': systemPrompt,
            },
          {
            'role': 'user',
            'content': message,
          },
        ];

        final response = await client.post(
          Uri.parse(_apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: json.encode({
            'model': 'GigaChat',
            'messages': messages,
            'temperature': 0.7,
            'max_tokens': 1000,
          }),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data['choices'][0]['message']['content'] ?? 'Нет ответа';
        } else {
          throw Exception('Ошибка API: ${response.statusCode} - ${response.body}');
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print('Ошибка GigaChat: $e');
      rethrow;
    }
  }

  // Отправка запроса с контекстом книги
  Future<String> sendBookQuery(String message, {Map<String, dynamic>? bookContext}) async {
    String systemPrompt = '''
Ты - книжный ассистент, который помогает пользователям с вопросами о книгах.
Отвечай кратко, информативно и дружелюбно.
Если спрашивают о конкретной книге, давай информацию об авторе, сюжете и интересных фактах.
''';

    if (bookContext != null) {
      systemPrompt += '''
      
Контекст текущей книги:
Название: ${bookContext['title']}
Автор: ${bookContext['author']}
Описание: ${bookContext['description']}
''';
    }

    return sendMessage(message, systemPrompt: systemPrompt);
  }
}