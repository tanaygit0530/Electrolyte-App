import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:electro_app/main.dart';
import 'package:electro_app/providers/theme_provider.dart';
import 'package:electro_app/providers/auth_provider.dart';

void main() {
  testWidgets('App startup flow displays IntroFlashScreen on initial launch', (tester) async {
    final apiService = SharedApiService();
    final authProvider = AuthProvider(apiService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: const MaterialApp(
          home: AppStartupFlow(),
        ),
      ),
    );

    // Initial frame must show the intro flash screen with logo & tagline
    expect(find.byType(IntroFlashScreen), findsOneWidget);
    expect(find.text('POWERING RELIABLE SERVICE'), findsOneWidget);
  });
}
