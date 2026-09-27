import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/turso_service.dart';

import 'providers/auth_provider.dart';
import 'providers/menu_provider.dart';
import 'providers/pos_provider.dart';
import 'providers/printer_provider.dart';
import 'providers/sales_provider.dart';
import 'theme/app_theme.dart';
import 'views/login_screen.dart';

import 'dart:ui';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global uncaught Flutter error handler
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Uncaught Flutter Error: ${details.exception}');
  };

  // Global asynchronous platform error handler to prevent crashing
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Uncaught Platform Async Error: $error\n$stack');
    return true; // Handled, prevents app crash
  };

  // Initialize Turso database schema in background without blocking app startup
  TursoService().initDatabase().catchError((e) {
    debugPrint('Background Turso init warning: $e');
  });

  runApp(const AromaaCafeApp());
}

class AromaaCafeApp extends StatelessWidget {
  const AromaaCafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MenuProvider()),
        ChangeNotifierProvider(create: (_) => POSProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
        ChangeNotifierProvider(create: (_) => PrinterProvider()),
      ],
      child: MaterialApp(
        title: 'AROMAA Cafe POS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const LoginScreen(),
      ),
    );
  }
}
