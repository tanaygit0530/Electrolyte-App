import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';

class MockApiService implements SharedApiService {
  int callCount = 0;
  String? lastInput;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Map<String, dynamic>> getChatResponse(
    String message, {
    String? sessionId,
  }) async {
    callCount++;
    lastInput = message;
    return {
      'reply': 'Echo: $message',
      'sessionId': 'session-test-123',
      'components': [],
    };
  }
}

void main() {
  group('ChatProvider tests', () {
    test('initializes with greeting message', () {
      final mockApi = MockApiService();
      final provider = ChatProvider(mockApi);
      expect(provider.messages.length, 1);
      expect(provider.messages.first.isUser, false);
      expect(provider.isLoading, false);
    });

    test('ignores empty or whitespace input', () async {
      final mockApi = MockApiService();
      final provider = ChatProvider(mockApi);
      await provider.handleUserInput('   ');
      expect(mockApi.callCount, 0);
      expect(provider.messages.length, 1);
    });

    test('appends user message and server response successfully', () async {
      final mockApi = MockApiService();
      final provider = ChatProvider(mockApi);
      await provider.handleUserInput('Need compressor');
      expect(mockApi.callCount, 1);
      expect(provider.messages.length, 3); // greeting, user msg, bot reply
      expect(provider.messages[1].isUser, true);
      expect(provider.messages[1].text, 'Need compressor');
      expect(provider.messages[2].isUser, false);
      expect(provider.messages[2].text, 'Echo: Need compressor');
      expect(provider.currentSessionId, 'session-test-123');
      expect(provider.isLoading, false);
    });

    test('clearChat resets messages and shows initial greeting', () {
      final mockApi = MockApiService();
      final provider = ChatProvider(mockApi);
      provider.clearChat();
      expect(provider.messages.length, 1);
      expect(provider.messages.first.isUser, false);
    });
  });
}
