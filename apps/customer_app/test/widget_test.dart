import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:electro_app/main.dart';
import 'package:electro_app/providers/theme_provider.dart';
import 'package:electro_app/providers/chat_provider.dart';
import 'package:electro_app/providers/order_provider.dart';
import 'package:electro_app/providers/chat_history_provider.dart';
import 'package:electro_app/providers/navigation_provider.dart';

void main() {
  testWidgets('App startup smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => ChatProvider()),
          ChangeNotifierProvider(create: (_) => OrderProvider()),
          ChangeNotifierProvider(create: (_) => ChatHistoryProvider()),
          ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ],
        child: const SparePartsApp(),
      ),
    );

    // Verify that the app compiles and launches successfully.
    expect(find.byType(SparePartsApp), findsOneWidget);
  });
}
