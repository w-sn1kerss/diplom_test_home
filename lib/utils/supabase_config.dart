// lib/config/supabase_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  SupabaseConfig._();

  static String get url =>
      dotenv.env['SUPABASE_URL'] ?? (throw Exception('SUPABASE_URL not set'));

  static String get anonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ??
          (throw Exception('SUPABASE_ANON_KEY not set'));
}