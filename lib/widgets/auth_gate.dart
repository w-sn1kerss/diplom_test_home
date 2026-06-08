// lib/widgets/auth_gate.dart
import 'package:auth_ui_demo/pages/onboard/onboarding_first.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/auth/login_page.dart';
import '../providers/auth_provider.dart';
import 'main_shell.dart';

/// Слушает поток авторизации Supabase и показывает либо оболочку приложения,
/// либо экран входа. Дополнительно синхронизирует AuthProvider.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;
        final hasSession = session != null ||
            Supabase.instance.client.auth.currentSession != null;

        return hasSession ? const MainShell() : const OnboardingFirst();
      },
    );
  }
}