import 'package:auth_ui_demo/utils/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'providers/auth_provider.dart';
import 'providers/book_provider.dart';
import 'providers/blog_provider.dart';
import 'providers/profile_provider.dart';
import 'repositories/auth_repository.dart';
import 'repositories/book_repository.dart';
import 'repositories/blog_repository.dart';
import 'repositories/profile_repository.dart';
import 'widgets/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    debug: false,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;

    return MultiProvider(
      providers: [
        Provider(create: (_) => AuthRepository(client)),
        Provider(create: (_) => BookRepository(client)),
        Provider(create: (_) => BlogRepository(client)),
        Provider(create: (_) => ProfileRepository(client)),

        ChangeNotifierProxyProvider<AuthRepository, AuthProvider>(
          create: (ctx) => AuthProvider(ctx.read<AuthRepository>()),
          update: (_, repo, prev) => prev ?? AuthProvider(repo),
        ),
        ChangeNotifierProxyProvider<BookRepository, BookProvider>(
          create: (ctx) => BookProvider(ctx.read<BookRepository>()),
          update: (_, repo, prev) => prev ?? BookProvider(repo),
        ),
        ChangeNotifierProxyProvider<BlogRepository, BlogProvider>(
          create: (ctx) => BlogProvider(ctx.read<BlogRepository>()),
          update: (_, repo, prev) => prev ?? BlogProvider(repo),
        ),
        ChangeNotifierProxyProvider<ProfileRepository, ProfileProvider>(
          create: (ctx) => ProfileProvider(ctx.read<ProfileRepository>()),
          update: (_, repo, prev) => prev ?? ProfileProvider(repo),
        ),
      ],
      child: MaterialApp(
        title: 'BookHub',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const AuthGate(),
      ),
    );
  }

  ThemeData _buildTheme() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6C63FF),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );
    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1A1A2E),
      ),
      // Внутри _buildTheme() -> base.copyWith(...)
      cardTheme: const CardThemeData( // Измените CardTheme на CardThemeData
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}