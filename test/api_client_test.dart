import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patient_portal_flutter/core/network/api_client.dart';
import 'package:patient_portal_flutter/core/network/api_failure.dart';

void main() {
  test('sends JSON requests and decodes object responses', () async {
    http.Request? capturedRequest;
    final client = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'success': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.close);

    final response = await client.postJson(
      '/api/patients/login',
      body: {'email': 'patient@example.test', 'password': 'secret'},
    );

    expect(
      capturedRequest!.url.toString(),
      'https://example.test/api/patients/login',
    );
    expect(capturedRequest!.headers['accept'], 'application/json');
    expect(capturedRequest!.headers['content-type'], 'application/json');
    expect(jsonDecode(capturedRequest!.body), {
      'email': 'patient@example.test',
      'password': 'secret',
    });
    expect(response, {'success': true});
  });

  test(
    'maps HTTP failures without logging or exposing response bodies',
    () async {
      final client = ApiClient(
        baseUri: Uri.parse('https://example.test'),
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': 'Invalid email or password.',
              'code': 'BAD_LOGIN',
            }),
            401,
          ),
        ),
      );
      addTearDown(client.close);

      await expectLater(
        client.postJson('/api/patients/login', body: const {}),
        throwsA(
          isA<ApiFailure>()
              .having((failure) => failure.kind, 'kind', ApiFailureKind.http)
              .having((failure) => failure.statusCode, 'status', 401)
              .having((failure) => failure.code, 'code', 'BAD_LOGIN')
              .having(
                (failure) => failure.message,
                'message',
                'Invalid email or password.',
              ),
        ),
      );
    },
  );

  test('rejects malformed success responses', () async {
    final client = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient((_) async => http.Response('not-json', 200)),
    );
    addTearDown(client.close);

    await expectLater(
      client.getJson('/api/patients/auth/me'),
      throwsA(
        isA<ApiFailure>().having(
          (failure) => failure.kind,
          'kind',
          ApiFailureKind.invalidResponse,
        ),
      ),
    );
  });

  test('decodes JSON array responses', () async {
    final client = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient(
        (_) async => http.Response(
          jsonEncode([
            {'frame_id': 1},
            {'frame_id': 2},
          ]),
          200,
        ),
      ),
    );
    addTearDown(client.close);

    expect(await client.getJsonList('/api/frames'), [
      {'frame_id': 1},
      {'frame_id': 2},
    ]);
  });

  test('rejects malformed JSON array responses', () async {
    final client = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient((_) async => http.Response('[', 200)),
    );
    addTearDown(client.close);

    await expectLater(
      client.getJsonList('/api/frames'),
      throwsA(
        isA<ApiFailure>().having(
          (failure) => failure.kind,
          'kind',
          ApiFailureKind.invalidResponse,
        ),
      ),
    );
  });

  test('rejects non-array success responses from getJsonList', () async {
    for (final body in ['{"frames":[]}', '"frames"', '42', 'null']) {
      final client = ApiClient(
        baseUri: Uri.parse('https://example.test'),
        client: MockClient((_) async => http.Response(body, 200)),
      );
      addTearDown(client.close);

      await expectLater(
        client.getJsonList('/api/frames'),
        throwsA(
          isA<ApiFailure>().having(
            (failure) => failure.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
    }
  });

  test(
    'maps array endpoint HTTP errors without exposing server details',
    () async {
      final client = ApiClient(
        baseUri: Uri.parse('https://example.test'),
        client: MockClient(
          (_) async =>
              http.Response('{"error":"private database details"}', 500),
        ),
      );
      addTearDown(client.close);

      await expectLater(
        client.getJsonList('/api/frames'),
        throwsA(
          isA<ApiFailure>()
              .having((failure) => failure.kind, 'kind', ApiFailureKind.http)
              .having((failure) => failure.statusCode, 'status', 500)
              .having(
                (failure) => failure.message,
                'message',
                'The clinic service is temporarily unavailable.',
              ),
        ),
      );
    },
  );

  test('maps network and timeout failures', () async {
    final networkClient = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient((_) async {
        throw http.ClientException('private transport details');
      }),
    );
    addTearDown(networkClient.close);

    await expectLater(
      networkClient.getJson('/api/patients/auth/me'),
      throwsA(
        isA<ApiFailure>()
            .having((failure) => failure.kind, 'kind', ApiFailureKind.network)
            .having(
              (failure) => failure.message,
              'message',
              'Unable to reach the clinic service. Check your connection.',
            ),
      ),
    );

    final timeoutClient = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) => Completer<http.Response>().future),
    );
    addTearDown(timeoutClient.close);

    await expectLater(
      timeoutClient.getJson('/api/patients/auth/me'),
      throwsA(
        isA<ApiFailure>().having(
          (failure) => failure.kind,
          'kind',
          ApiFailureKind.timeout,
        ),
      ),
    );
  });
}
