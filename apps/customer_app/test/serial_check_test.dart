import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_core/shared_core.dart';
import 'package:electro_app/providers/serial_check_provider.dart';
import 'package:electro_app/models/serial_check_result.dart';
import 'package:electro_app/screens/serial_check_screen.dart';

/// Mock SharedApiService for deterministic testing
class MockSharedApiService implements SharedApiService {
  Future<Map<String, dynamic>> Function(String serialNumber)? onCheckSerial;

  @override
  Future<Map<String, dynamic>> checkSerialNumber(String serialNumber, {Duration? timeout}) async {
    if (onCheckSerial != null) {
      return onCheckSerial!(serialNumber);
    }
    return {
      'success': true,
      'status': 'SAFE TO CLOSE',
      'isWithin60Days': false,
      'repeatRisk': false,
      'canCloseCall': true,
      'daysAgo': null,
      'serialNumber': serialNumber,
      'message': 'No previous service history found for this serial number. Safe to close.',
      'record': null
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SerialCheckProvider Unit Tests', () {
    test('extractCleanSerial strips prefixes and normalizes text', () {
      expect(SerialCheckProvider.extractCleanSerial('SrNo. LA24AECHA2P13535'), 'LA24AECHA2P13535');
      expect(SerialCheckProvider.extractCleanSerial('  sl. no:  ab1234cd  '), 'AB1234CD');
      expect(SerialCheckProvider.extractCleanSerial('SERIAL: 0012399'), '0012399');
      expect(SerialCheckProvider.extractCleanSerial('S/N-998877'), '998877');
      expect(
        SerialCheckProvider.extractCleanSerial('Some text\nSerial No: LA24XYZ\nOther text'),
        'LA24XYZ',
      );
      expect(SerialCheckProvider.extractCleanSerial(''), '');
    });

    test('Test 5: A serial number found in DB returns REPEAT RISK', () async {
      final mockApi = MockSharedApiService();
      mockApi.onCheckSerial = (serial) async => {
        'success': true,
        'status': 'REPEAT RISK',
        'isWithin60Days': true,
        'repeatRisk': true,
        'canCloseCall': false,
        'daysAgo': 12,
        'lastServiceDate': '17/10/2026',
        'serialNumber': serial,
        'message': 'Repeat service risk: Last service was completed 12 days ago.',
        'record': {
          'caseNumber': 'CAS-1001',
          'workOrder': 'WO-501',
          'customerName': 'Test Customer',
          'productName': 'Smart Motor Fan',
        }
      };

      final provider = SerialCheckProvider(mockApi);
      await provider.checkSerial('LA24AECHA2P13535');

      expect(provider.isLoading, false);
      expect(provider.errorMessage, isNull);
      expect(provider.result, isNotNull);
      expect(provider.result!.isRepeatRisk, true);
      expect(provider.result!.isWithin60Days, true);
      expect(provider.result!.canCloseCall, false);
      expect(provider.result!.daysAgo, 12);
      expect(provider.result!.status, 'REPEAT RISK');
    });

    test('Test 6: A serial number with no eligible service history returns SAFE TO CLOSE', () async {
      final mockApi = MockSharedApiService();
      mockApi.onCheckSerial = (serial) async => {
        'success': true,
        'status': 'SAFE TO CLOSE',
        'isWithin60Days': false,
        'repeatRisk': false,
        'canCloseCall': true,
        'daysAgo': null,
        'lastServiceDate': null,
        'serialNumber': serial,
        'message': 'No previous service history found for this serial number. Safe to close.',
        'record': null
      };

      final provider = SerialCheckProvider(mockApi);
      await provider.checkSerial('BRAND-NEW-001');

      expect(provider.isLoading, false);
      expect(provider.errorMessage, isNull);
      expect(provider.result, isNotNull);
      expect(provider.result!.isSafeToClose, true);
      expect(provider.result!.isRepeatRisk, false);
      expect(provider.result!.isWithin60Days, false);
      expect(provider.result!.canCloseCall, true);
    });

    test('Test 4: When API times out, provider catches TimeoutException gracefully', () async {
      final mockApi = MockSharedApiService();
      mockApi.onCheckSerial = (serial) async {
        throw TimeoutException('Future not completed');
      };

      final provider = SerialCheckProvider(mockApi);
      await provider.checkSerial('TIMEOUT-TEST-SERIAL');

      expect(provider.isLoading, false);
      expect(provider.result, isNull);
      expect(provider.errorMessage, isNotNull);
      // Must NOT display raw unhandled "TimeoutException after 0:00:15.000000"
      expect(provider.errorMessage, isNot(contains('TimeoutException after')));
      expect(provider.errorMessage, contains('Verification timed out'));
    });

    test('Test 7: Retrying after timeout triggers API verification again', () async {
      final mockApi = MockSharedApiService();
      int callCount = 0;
      mockApi.onCheckSerial = (serial) async {
        callCount++;
        if (callCount == 1) {
          throw TimeoutException('Future not completed');
        }
        return {
          'success': true,
          'status': 'SAFE TO CLOSE',
          'isWithin60Days': false,
          'canCloseCall': true,
          'serialNumber': serial,
        };
      };

      final provider = SerialCheckProvider(mockApi);
      await provider.checkSerial('RETRY-TEST-SERIAL');
      expect(callCount, 1);
      expect(provider.errorMessage, contains('Verification timed out'));
      expect(provider.result, isNull);

      // Retry without restart
      await provider.retry();
      expect(callCount, 2);
      expect(provider.errorMessage, isNull);
      expect(provider.result, isNotNull);
      expect(provider.result!.isSafeToClose, true);
    });

    test('Prevents overlapping duplicate API requests', () async {
      final mockApi = MockSharedApiService();
      int callCount = 0;
      final completer = Completer<Map<String, dynamic>>();

      mockApi.onCheckSerial = (serial) async {
        callCount++;
        return completer.future;
      };

      final provider = SerialCheckProvider(mockApi);

      // First call starts
      final f1 = provider.checkSerial('OVERLAP-SERIAL');
      // Second call while first is in flight
      final f2 = provider.checkSerial('OVERLAP-SERIAL');

      completer.complete({
        'success': true,
        'status': 'SAFE TO CLOSE',
        'isWithin60Days': false,
        'serialNumber': 'OVERLAP-SERIAL',
      });

      await Future.wait([f1, f2]);
      // Duplicate call was prevented
      expect(callCount, 1);
    });
  });

  group('SerialCheckScreen Widget Tests', () {
    testWidgets('Test 1: Screen opens successfully and shows camera live scan tab', (tester) async {
      final mockApi = MockSharedApiService();
      final provider = SerialCheckProvider(mockApi);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SerialCheckProvider>.value(
            value: provider,
            child: const SerialCheckScreen(),
          ),
        ),
      );

      // Verify app bar title
      expect(find.text('Verify Serial Number'), findsOneWidget);
      // Verify tabs exist
      expect(find.text('Live Scan'), findsOneWidget);
      expect(find.text('Upload Image'), findsOneWidget);
      expect(find.text('Manual Entry'), findsOneWidget);
      // Instruction text
      expect(find.text('Point camera at the QR code or Barcode sticker on the product'), findsOneWidget);
    });

    testWidgets('Test 2: No barcode detected for 15 seconds shows friendly prompt', (tester) async {
      final mockApi = MockSharedApiService();
      final provider = SerialCheckProvider(mockApi);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SerialCheckProvider>.value(
            value: provider,
            child: const SerialCheckScreen(),
          ),
        ),
      );

      // Trigger post-frame callback
      await tester.pump();
      expect(find.text('No Barcode Detected'), findsNothing);

      // Advance time by 15 seconds
      await tester.pump(const Duration(seconds: 15));

      // Friendly message must be displayed
      expect(find.text('No Barcode Detected'), findsOneWidget);
      expect(
        find.text('No barcode detected. Adjust the camera or try manual entry.'),
        findsOneWidget,
      );
      expect(find.text('Retry Scan'), findsOneWidget);
      expect(find.text('Manual Entry'), findsWidgets);

      // Tap Retry Scan
      await tester.tap(find.text('Retry Scan'));
      await tester.pump();

      // Message is dismissed and scanning resumes
      expect(find.text('No Barcode Detected'), findsNothing);
    });

    testWidgets('Test 3 & 5: Valid barcode scanned renders REPEAT RISK view', (tester) async {
      final mockApi = MockSharedApiService();
      mockApi.onCheckSerial = (serial) async => {
        'success': true,
        'status': 'REPEAT RISK',
        'isWithin60Days': true,
        'repeatRisk': true,
        'canCloseCall': false,
        'daysAgo': 14,
        'lastServiceDate': '15/10/2026',
        'serialNumber': serial,
        'message': 'Repeat service risk: Last service was completed 14 days ago.',
        'record': {
          'caseNumber': 'CAS-7788',
          'workOrder': 'WO-9900',
          'productName': 'Ceiling Fan BLDC',
        }
      };

      final provider = SerialCheckProvider(mockApi);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SerialCheckProvider>.value(
            value: provider,
            child: const SerialCheckScreen(),
          ),
        ),
      );

      // Simulate barcode scan via provider
      await provider.checkSerial('LA24AECHA2P13535');
      await tester.pumpAndSettle();

      // Check results UI
      expect(find.text('REPEAT RISK (≤ 60 DAYS)'), findsOneWidget);
      expect(find.text('LA24AECHA2P13535'), findsOneWidget);
      expect(find.text('14 days ago'), findsOneWidget);
      expect(find.text('CAS-7788'), findsOneWidget);
      expect(find.text('Ceiling Fan BLDC'), findsOneWidget);
      expect(find.text('Verify Another Serial Number'), findsOneWidget);
    });

    testWidgets('Test 4 & 7: API timeout renders friendly error banner with retry option', (tester) async {
      final mockApi = MockSharedApiService();
      mockApi.onCheckSerial = (serial) async {
        throw TimeoutException('Future not completed');
      };

      final provider = SerialCheckProvider(mockApi);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SerialCheckProvider>.value(
            value: provider,
            child: const SerialCheckScreen(),
          ),
        ),
      );

      await provider.checkSerial('SN-TIMEOUT-TEST');
      await tester.pump();

      // Ensure raw TimeoutException is NOT displayed
      expect(find.textContaining('TimeoutException after'), findsNothing);

      // Friendly banner
      expect(find.text('Verification Issue'), findsOneWidget);
      expect(
        find.text('Verification timed out. Please check your network connection and retry.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Scan Again'), findsOneWidget);

      // Now configure API to succeed on retry
      mockApi.onCheckSerial = (serial) async => {
        'success': true,
        'status': 'SAFE TO CLOSE',
        'isWithin60Days': false,
        'canCloseCall': true,
        'serialNumber': serial,
      };

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Successful result view displayed
      expect(find.text('SAFE TO CLOSE (> 60 DAYS)'), findsOneWidget);
      expect(find.text('SN-TIMEOUT-TEST'), findsOneWidget);
    });

    testWidgets('Test 8: Screen can be closed and reopened cleanly', (tester) async {
      final mockApi = MockSharedApiService();
      final provider = SerialCheckProvider(mockApi);

      // Open screen
      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider<SerialCheckProvider>.value(
                value: provider,
                child: const SerialCheckScreen(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Verify Serial Number'), findsOneWidget);

      // Replace with another widget (simulating navigation away / closing)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Home Screen')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Home Screen'), findsOneWidget);

      // Reopen screen
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SerialCheckProvider>.value(
            value: provider,
            child: const SerialCheckScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Verify Serial Number'), findsOneWidget);
      expect(find.text('Live Scan'), findsOneWidget);
    });
  });
}
