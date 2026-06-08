import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_core/shared_core.dart';
import 'providers/theme_provider.dart';
import 'providers/order_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  final apiService = SharedApiService();
  final authProvider = AuthProvider(apiService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => ChatHistoryProvider()),
        ChangeNotifierProvider(create: (_) => InvoiceProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ],
      child: const SparePartsApp(),
    ),
  );
}

class SparePartsApp extends StatelessWidget {
  const SparePartsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Spare Parts Management',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          // Render loading screen if verifying persisted credentials
          if (auth.isLoading && !auth.isAuthenticated) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryYellow),
              ),
            );
          }

          // Route dynamically based on session status
          return auth.isAuthenticated ? const MainScreen() : const LoginScreen();
        },
      ),
    );
  }
}
