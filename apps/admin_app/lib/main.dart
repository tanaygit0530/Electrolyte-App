import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_ui/shared_ui.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/upload_provider.dart';
import 'providers/user_provider.dart';
import 'providers/report_provider.dart';
import 'providers/service_records_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_workspace.dart';
import 'services/api_service.dart';
import 'utils/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ElectrolyteAdminApp());
}

class ElectrolyteAdminApp extends StatefulWidget {
  const ElectrolyteAdminApp({super.key});

  @override
  State<ElectrolyteAdminApp> createState() => _ElectrolyteAdminAppAppState();
}

class _ElectrolyteAdminAppAppState extends State<ElectrolyteAdminApp> {
  late final ApiService _apiService;
  late final AuthProvider _authProvider;
  late final DashboardProvider _dashboardProvider;
  late final UploadProvider _uploadProvider;
  late final UserProvider _userProvider;
  late final ReportProvider _reportProvider;
  late final ServiceRecordsProvider _serviceRecordsProvider;

  @override
  void initState() {
    super.initState();
    // Initialize singleton core services
    _apiService = ApiService();
    _authProvider = AuthProvider(_apiService);
    _dashboardProvider = DashboardProvider(_apiService);
    _uploadProvider = UploadProvider(_apiService);
    _userProvider = UserProvider(_apiService);
    _reportProvider = ReportProvider(_apiService);
    _serviceRecordsProvider = ServiceRecordsProvider(_apiService);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<DashboardProvider>.value(value: _dashboardProvider),
        ChangeNotifierProvider<UploadProvider>.value(value: _uploadProvider),
        ChangeNotifierProvider<UserProvider>.value(value: _userProvider),
        ChangeNotifierProvider<ReportProvider>.value(value: _reportProvider),
        ChangeNotifierProvider<ServiceRecordsProvider>.value(value: _serviceRecordsProvider),
        ChangeNotifierProvider<ChatProvider>(create: (_) => ChatProvider()),
        ChangeNotifierProvider<ChatHistoryProvider>(create: (_) => ChatHistoryProvider()),
      ],
      child: MaterialApp(
        title: 'Electrolyte Admin Portal',
        debugShowCheckedModeBanner: false,
        theme: AdminTheme.darkTheme,
        home: const AdminStartupFlow(),
      ),
    );
  }
}

class AdminStartupFlow extends StatefulWidget {
  const AdminStartupFlow({super.key});

  @override
  State<AdminStartupFlow> createState() => _AdminStartupFlowState();
}

class _AdminStartupFlowState extends State<AdminStartupFlow> {
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

    // Initial launch: Display animated intro flash screen with company logo
    if (!_hasIntroFinished) {
      return IntroFlashScreen(
        minDisplayDuration: const Duration(milliseconds: 2000),
        subtitle: 'ADMINISTRATION & AUDIT PORTAL',
        onFinished: _onIntroFinished,
      );
    }

    // Still checking auth credentials
    if (auth.isLoading && !auth.isAuthenticated) {
      return const IntroFlashScreen(
        minDisplayDuration: Duration(milliseconds: 300),
        subtitle: 'VERIFYING CREDENTIALS...',
        showProgress: true,
      );
    }

    // Smooth fade transition into MainWorkspace or LoginScreen
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      child: auth.isAuthenticated
          ? const MainWorkspace(key: ValueKey('main_workspace'))
          : const LoginScreen(key: ValueKey('admin_login_screen')),
    );
  }
}
