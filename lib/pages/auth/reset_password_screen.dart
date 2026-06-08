import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/code_input_field.dart';
import '../../widgets/numeric_keyboard.dart';
import 'login_page.dart';
import 'change_password_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({
    super.key,
    required this.email,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _code = TextEditingController();
  bool _isLoading = false;
  bool _canResend = true;
  int _countdown = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _code.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_countdown > 0) {
            _countdown--;
          } else {
            _canResend = true;
            timer.cancel();
          }
        });
      }
    });
  }

  Future<void> _verifyCode() async {
    if (_code.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите 6-значный код'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Имитация проверки кода
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
    });

    // Переход на экран смены пароля
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChangePasswordScreen(email: widget.email),
      ),
    );
  }

  Future<void> _resendCode() async {
    if (!_canResend) return;

    setState(() {
      _canResend = false;
      _countdown = 30;
    });

    _startCountdown();

    // Имитация повторной отправки
    await Future.delayed(const Duration(seconds: 1));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Код отправлен повторно'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _onKeyPressed(String key) {
    if (_code.text.length < 6) {
      _code.text += key;
      _code.selection = TextSelection.collapsed(offset: _code.text.length);

      if (_code.text.length == 6) {
        _verifyCode();
      }
    }
  }

  void _onBackspacePressed() {
    if (_code.text.isNotEmpty) {
      _code.text = _code.text.substring(0, _code.text.length - 1);
      _code.selection = TextSelection.collapsed(offset: _code.text.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Кнопка назад
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: Colors.black,
                ),

                const SizedBox(height: 20),

                // Заголовок
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mark_email_read_outlined,
                          size: 40,
                          color: Color(0xFF6C63FF),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Verification Email',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Please enter the code we just sent to email',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Email
                Center(
                  child: Text(
                    widget.email,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Поле для ввода кода
                CodeInputField(
                  length: 6,
                  onCodeChanged: (code) {
                    if (code.length == 6) {
                      _verifyCode();
                    }
                  },
                  autoFocus: true,
                ),

                const SizedBox(height: 32),

                // Кнопка "Resend"
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "If you didn't receive a code? ",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      InkWell(
                        onTap: _canResend ? _resendCode : null,
                        child: Text(
                          _canResend ? 'Resend' : 'Resend ($_countdown)',
                          style: TextStyle(
                            color: _canResend
                                ? const Color(0xFF6C63FF)
                                : Colors.grey,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Кнопка Continue
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _code.text.length == 6 ? _verifyCode : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Разделитель
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Colors.grey[300],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Or enter with keyboard',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Colors.grey[300],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Цифровая клавиатура
                NumericKeypad(
                  onKeyPressed: _onKeyPressed,
                  onBackspacePressed: _onBackspacePressed,
                  showBackspace: true,
                ),

                const SizedBox(height: 40),

                // Скрытый TextField для хранения кода
                Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _code,
                    readOnly: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}