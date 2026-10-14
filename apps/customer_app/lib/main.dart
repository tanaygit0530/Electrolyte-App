import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:shared_core/shared_core.dart';
import 'providers/theme_provider.dart';
import 'providers/order_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/serial_check_provider.dart';
import 'screens/main_screen.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  final apiService = SharedApiService();
  final authProvider = AuthProvider(apiService);

  runApp(
    MultiProvider(
      providers: [
        Provider<SharedApiService>.value(value: apiService),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider(apiService)),
        ChangeNotifierProvider(create: (_) => OrderProvider(apiService)),
        ChangeNotifierProvider(create: (_) => ChatHistoryProvider()),
        ChangeNotifierProvider(create: (_) => InvoiceProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => SerialCheckProvider(apiService)),
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
      title: 'Electrolyte Technician',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'IN'),
        Locale('en', 'US'),
        Locale('en', 'GB'),
        Locale('en'),
      ],
      home: const AppStartupFlow(),
    );
  }
}

class AppStartupFlow extends StatefulWidget {
  const AppStartupFlow({super.key});

  @override
  State<AppStartupFlow> createState() => _AppStartupFlowState();
}

class _AppStartupFlowState extends State<AppStartupFlow> {
  bool _hasIntroFinished = false;

  void _onIntroFinished() {
    if (mounted) {
      setState(() {
        _hasIntroFinished = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    final Widget currentScreen;
    if (!_hasIntroFinished || (auth.isLoading && !auth.isAuthenticated)) {
      currentScreen = IntroFlashScreen(
        key: const ValueKey('intro_flash_screen'),
        minDisplayDuration: const Duration(milliseconds: 2300),
        subtitle: 'POWERING RELIABLE SERVICE',
        onFinished: _onIntroFinished,
      );
    } else if (auth.isAuthenticated) {
      currentScreen = const MainScreen(key: ValueKey('main_screen'));
    } else {
      currentScreen = const LoginScreen(key: ValueKey('login_screen'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      child: currentScreen,
    );
  }
}
