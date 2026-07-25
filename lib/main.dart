import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'providers/auth_provider.dart';
import 'providers/menu_provider.dart';
import 'providers/pos_provider.dart';
import 'providers/printer_provider.dart';
import 'providers/sales_provider.dart';
import 'theme/app_theme.dart';
import 'views/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AromaCafeApp());
}

class AromaCafeApp extends StatelessWidget {
  const AromaCafeApp({super.key});

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
        title: 'Aroma Tea Cafe POS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const LoginScreen(),
      ),
    );
  }
}
