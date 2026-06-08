import 'dart:ui'; // Обязательно для ImageFilter
import 'package:flutter/material.dart';
import 'home_page.dart';
import 'library_page.dart';
import 'neuro_page.dart';
import '../users/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const LibraryPage(),
    const NeuroPage(), // Здесь твоя гифка
    const ProfileScreen(),
  ];

  void changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Проверяем, открыт ли сейчас раздел Нейро
    bool isNeuro = _currentIndex == 2;

    return Scaffold(
      // КРИТИЧНО: extendBody позволяет контенту (гифке) заходить под BottomNavigationBar
      extendBody: true,
      body: _pages[_currentIndex],

      bottomNavigationBar: _buildGlassNavigationBar(isNeuro),
    );
  }

  Widget _buildGlassNavigationBar(bool isNeuro) {
    return Container(
      // Если это Нейро — убираем белый фон, если другие страницы — оставляем или делаем чуть прозрачным
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          top: BorderSide(
            color: isNeuro ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
            width: 0.5,
          ),
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          // Эффект размытия фона под кнопками
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: changeTab,
            type: BottomNavigationBarType.fixed,
            // Прозрачный фон самого бара, чтобы BackdropFilter работал
            backgroundColor: isNeuro
                ? Colors.black.withOpacity(0.2)
                : Colors.white.withOpacity(0.8),

            selectedItemColor: const Color(0xFF6C63FF),
            unselectedItemColor: isNeuro ? Colors.white54 : Colors.grey,

            elevation: 0,
            selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),

            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Главная',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.menu_book_outlined),
                activeIcon: Icon(Icons.menu_book),
                label: 'Библиотека',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.psychology_outlined),
                activeIcon: Icon(Icons.psychology),
                label: 'Нейро',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Профиль',
              ),
            ],
          ),
        ),
      ),
    );
  }
}