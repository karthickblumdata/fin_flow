import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_plugins/url_strategy.dart' show usePathUrlStrategy;
import 'dart:async';
import 'theme/app_theme.dart';
import 'router/app_router.dart';
import 'utils/route_observer.dart';

void main() {
   // Note: DevTools connection warnings in web mode are harmless
  // Warnings like "Failed to set DevTools server address" and "Failed to set vm service URI"
  // occur when Flutter tries to connect to DevTools but fails. These can be safely ignored
  // as they don't affect app functionality. They're framework-level console messages.
  
  // Use path-based URL strategy for web (removes hash from URLs)
  // This allows query parameters to work properly: /set-password?email=...
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  
  // Handle initial deep link if app was opened via deep link
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Blumdata Fin Flow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}

