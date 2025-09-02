import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// import 'dart:io';

// Platform-specific UI imports (disabilitato per web)
// import 'package:macos_ui/macos_ui.dart' as macos;

import 'core/theme/app_theme.dart';
import 'core/theme/colors.dart';
import 'presentation/screens/main_screen.dart';
import 'presentation/screens/chat_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/onboarding_screen.dart';

class AIAssistantApp extends ConsumerWidget {
  const AIAssistantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = _createRouter();

    // Per ora usiamo solo Material Design (funziona su web)
    return _buildMaterialApp(router);
  }

  GoRouter _createRouter() {
    return GoRouter(
      initialLocation: '/onboarding',
      debugLogDiagnostics: true,
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const MainScreen(),
          routes: [
            GoRoute(
              path: 'chat',
              builder: (context, state) => const ChatScreen(),
            ),
            GoRoute(
              path: 'settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMaterialApp(GoRouter router) {
    return MaterialApp.router(
      title: 'AI Assistant MVP',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}