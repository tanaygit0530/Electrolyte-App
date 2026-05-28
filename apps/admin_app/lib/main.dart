import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/upload_provider.dart';
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

  @override
  void initState() {
    super.initState();
    // Initialize singleton core services
    _apiService = ApiService();
    _authProvider = AuthProvider(_apiService);
    _dashboardProvider = DashboardProvider(_apiService);
    _uploadProvider = UploadProvider(_apiService);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<DashboardProvider>.value(value: _dashboardProvider),
        ChangeNotifierProvider<UploadProvider>.value(value: _uploadProvider),
      ],
      child: MaterialApp(
        title: 'Electrolyte Admin Portal',
        debugShowCheckedModeBanner: false,
        theme: AdminTheme.darkTheme,
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            // Render loading screen if verifying persisted credentials
            if (auth.isLoading && !auth.isAuthenticated) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: AdminTheme.accentTeal),
                ),
              );
            }

            // Route dynamically based on session status
            return auth.isAuthenticated ? const MainWorkspace() : const LoginScreen();
          },
        ),
      ),
    );
  }
}
