import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:rebs_hrms/core/config/app_config.dart';
import 'package:rebs_hrms/core/constants/app_constants.dart';
import 'package:rebs_hrms/core/errors/app_error.dart';
import 'package:rebs_hrms/core/network/api_client.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost:3000'));
  });

  group('ApiClient', () {
    late MockHttpClient mockHttpClient;
    late AppConfig appConfig;
    late ApiClient apiClient;

    setUp(() {
      mockHttpClient = MockHttpClient();
      appConfig = const AppConfig(
        apiBaseUrl: 'http://localhost:3000',
        requestTimeout: Duration(milliseconds: 100),
      );
      apiClient = ApiClient(
        httpClient: mockHttpClient,
        appConfig: appConfig,
      );
    });

    test('injects ngrok bypass header and returns parsed JSON on 200 OK', () async {
      when(
        () => mockHttpClient.get(
          any(),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          '{"id": "EMP-1042", "name": "Alex Mercer"}',
          200,
        ),
      );

      final result = await apiClient.get('/employee/me');

      expect(result, isA<Map<String, dynamic>>());
      expect(result['id'], equals('EMP-1042'));

      final captured = verify(
        () => mockHttpClient.get(
          any(),
          headers: captureAny(named: 'headers'),
        ),
      ).captured.first as Map<String, String>;

      expect(
        captured[AppConstants.ngrokWarningHeader],
        equals(AppConstants.ngrokWarningValue),
      );
    });

    test('maps 409 status code to ConflictError', () async {
      when(
        () => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          '{"error": "Conflict", "message": "Already checked in today."}',
          409,
        ),
      );

      expect(
        () => apiClient.post('/attendance/events', body: {'type': 'check_in'}),
        throwsA(
          isA<ConflictError>().having(
            (e) => e.message,
            'message',
            contains('Already checked in today'),
          ),
        ),
      );
    });

    test('maps 422 status code to ValidationError with fieldErrors map', () async {
      when(
        () => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          '{"error": "Validation Failed", "fieldErrors": {"reason": "Too short", "dates": "Overlap"}}',
          422,
        ),
      );

      try {
        await apiClient.post('/leave/requests', body: {'reason': 'abc'});
        fail('Should throw ValidationError');
      } on ValidationError catch (e) {
        expect(e.fieldErrors['reason'], equals('Too short'));
        expect(e.fieldErrors['dates'], equals('Overlap'));
      }
    });

    test('maps 500 status code to ServerError', () async {
      when(
        () => mockHttpClient.get(
          any(),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          '{"error": "Internal Server Error", "message": "Fatal database crash"}',
          500,
        ),
      );

      expect(
        () => apiClient.get('/attendance'),
        throwsA(
          isA<ServerError>()
              .having((e) => e.statusCode, 'statusCode', equals(500))
              .having((e) => e.message, 'message', contains('Fatal database crash')),
        ),
      );
    });

    test('maps SocketException to NetworkError', () async {
      when(
        () => mockHttpClient.get(
          any(),
          headers: any(named: 'headers'),
        ),
      ).thenThrow(const SocketException('Failed host lookup'));

      expect(
        () => apiClient.get('/employee/me'),
        throwsA(isA<NetworkError>()),
      );
    });

    test('maps TimeoutException to TimeoutError', () async {
      when(
        () => mockHttpClient.get(
          any(),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer(
        (_) => Future.delayed(
          const Duration(milliseconds: 300),
          () => http.Response('{}', 200),
        ),
      );

      expect(
        () => apiClient.get('/employee/me'),
        throwsA(isA<TimeoutError>()),
      );
    });
  });
}
