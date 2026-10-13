import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('IntroFlashScreen renders successfully in light mode', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        themeMode: ThemeMode.light,
        home: IntroFlashScreen(
          minDisplayDuration: Duration(milliseconds: 500),
          subtitle: 'POWERING RELIABLE SERVICE',
        ),
      ),
    );

    expect(find.byType(IntroFlashScreen), findsOneWidget);
    expect(find.text('POWERING RELIABLE SERVICE'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('IntroFlashScreen renders successfully in dark mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const IntroFlashScreen(
          minDisplayDuration: Duration(milliseconds: 500),
          subtitle: 'POWERING RELIABLE SERVICE',
        ),
      ),
    );

    expect(find.byType(IntroFlashScreen), findsOneWidget);
    expect(find.text('POWERING RELIABLE SERVICE'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('IntroFlashScreen triggers onFinished callback after duration', (tester) async {
    bool finished = false;

    await tester.pumpWidget(
      MaterialApp(
        home: IntroFlashScreen(
          minDisplayDuration: const Duration(milliseconds: 300),
          onFinished: () {
            finished = true;
          },
        ),
      ),
    );

    expect(finished, isFalse);

    // Advance time past minDisplayDuration
    await tester.pump(const Duration(milliseconds: 350));

    expect(finished, isTrue);
  });
}
