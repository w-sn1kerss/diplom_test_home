import 'package:flutter/material.dart';
import '../auth/login_page.dart';


class OnboardingThird extends StatelessWidget {
  const OnboardingThird({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Убираем AppBar, чтобы фон был на весь экран
      appBar: null,

      // Делаем body без ограничений по размерам
      body: Stack(
        children: [
          // Фоновое изображение
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/onboard_screens/5.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Затемненный слой поверх фона
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.black.withOpacity(0.6),
                ],
              ),
            ),
          ),

          // Основной контент
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // Пропускаем верхнюю часть для размещения заголовка выше
                const Expanded(
                  flex: 2,
                  child: SizedBox(),
                ),

                // Заголовок (примерно в середине экрана, чуть выше)
                const Column(
                  children: [
                    Text(
                      'Начните ваше путешествие',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),

                    // Подзаголовок (маленький текст)
                    Text(
                      'Готовы отправиться в путешествие за вдохновением и знаниями? Ваше приключение начинается прямо сейчас. Вперед!',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        height: 1.4,
                        fontWeight: FontWeight.w300,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),

                // Пропускаем пространство
                const Expanded(
                  flex: 1,
                  child: SizedBox(),
                ),

                // Три точки (индикатор страницы)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Первая точка (неактивная)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 4),

                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 4),

                    Container(
                      width: 12, // Делаем шире для активной
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white, // Белый цвет для активной
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),

                  ],
                ),

                const SizedBox(height: 40),

                // Кнопка "Продолжить" (выше)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(), // Укажите верное имя класса из login_page.dart
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: const Text(
                      'Продолжить',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 200),
              ],
            ),
          ),
        ],
      ),
    );
  }
}