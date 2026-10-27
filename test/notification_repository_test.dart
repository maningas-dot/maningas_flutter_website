import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patient_portal_flutter/core/network/api_client.dart';
import 'package:patient_portal_flutter/core/network/api_failure.dart';
import 'package:patient_portal_flutter/features/auth/application/patient_auth_setup.dart';
import 'package:patient_portal_flutter/features/shell/notification_mock_data.dart';
import 'package:patient_portal_flutter/features/shell/notification_repository.dart';
import 'package:patient_portal_flutter/features/shell/patient_notification.dart';

void main() {
  final baseUri = Uri.parse('https://api.example.test');

  test('parses API notification fields and supported read representations', () {
    final notification = PatientNotification.fromJson({
      'notification_id': 27,
      'title': ' Appointment reminder ',
      'body': 'Your visit is tomorrow.',
      'is_read': 0,
      'created_at': '2026-10-27T09:30:00Z',
    });

    expect(notification.id, 27);
    expect(notification.title, 'Appointment reminder');
    expect(notification.body, 'Your visit is tomorrow.');
    expect(notification.isRead, isFalse);
    expect(notification.createdAt, DateTime.parse('2026-10-27T09:30:00Z'));
    expect(
      PatientNotification.fromJson({
        'notification_id': '28',
        'title': null,
        'body': null,
        'is_read': true,
        'created_at': null,
      }).title,
      'Notification',
    );
  });

  test('rejects malformed notification identifiers, flags, and timestamps', () {
    final valid = <String, Object?>{
      'notification_id': 1,
      'title': 'Update',
      'body': 'Description',
      'is_read': 0,
      'created_at': '2026-10-27T09:30:00Z',
    };
    for (final invalid in [
      {...valid, 'notification_id': 'GVC-1601'},
      {...valid, 'notification_id': 0},
      {...valid, 'is_read': 'yes'},
      {...valid, 'created_at': 'not-a-date'},
    ]) {
      expect(
        () => PatientNotification.fromJson(invalid),
        throwsFormatException,
      );
    }
  });

  test(
    'API repository uses string patient IDs and verified request contract',
    () async {
      final requests = <http.Request>[];
      final client = ApiClient(
        baseUri: baseUri,
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/api/notifications/patient/GVC-1601') {
            return http.Response(
              jsonEncode([
                {
                  'notification_id': 27,
                  'title': 'Appointment confirmed',
                  'body': 'Your appointment is confirmed.',
                  'is_read': 0,
                  'created_at': '2026-10-27T09:30:00Z',
                },
              ]),
              200,
            );
          }
          if (request.url.path.endsWith('/unread-count')) {
            return http.Response(jsonEncode({'unread_count': 1}), 200);
          }
          if (request.url.path == '/api/notifications/27/read') {
            return http.Response(
              jsonEncode({
                'success': true,
                'notification_id': 27,
                'is_read': true,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/read-all')) {
            return http.Response(
              jsonEncode({'success': true, 'updated_count': 1}),
              200,
            );
          }
          return http.Response('Not found', 404);
        }),
      );
      addTearDown(client.close);
      final repository = ApiNotificationRepository(client);

      final notifications = await repository.getNotifications(
        patientId: 'GVC-1601',
        token: 'test-token',
      );
      final count = await repository.getUnreadCount(
        patientId: 'GVC-1601',
        token: 'test-token',
      );
      await repository.markAsRead(notificationId: 27, token: 'test-token');
      await repository.markAllAsRead(
        patientId: 'GVC-1601',
        token: 'test-token',
      );

      expect(notifications.single.id, 27);
      expect(count, 1);
      expect(repository.isDemo, isFalse);
      expect(requests.map((request) => request.method), [
        'GET',
        'GET',
        'PATCH',
        'PATCH',
      ]);
      expect(requests.map((request) => request.url.path), [
        '/api/notifications/patient/GVC-1601',
        '/api/notifications/patient/GVC-1601/unread-count',
        '/api/notifications/27/read',
        '/api/notifications/patient/GVC-1601/read-all',
      ]);
      for (final request in requests) {
        expect(request.headers['authorization'], 'Bearer test-token');
      }
    },
  );

  test(
    'API repository accepts an empty list and rejects invalid responses',
    () async {
      final emptyClient = ApiClient(
        baseUri: baseUri,
        client: MockClient((_) async => http.Response('[]', 200)),
      );
      addTearDown(emptyClient.close);
      expect(
        await ApiNotificationRepository(emptyClient)
            .getNotifications(patientId: 'GVC-1601', token: 'test-token'),
        isEmpty,
      );

      final invalidClient = ApiClient(
        baseUri: baseUri,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode([
              {
                'notification_id': 'invalid',
                'title': 'Update',
                'body': '',
                'is_read': 0,
              },
            ]),
            200,
          ),
        ),
      );
      addTearDown(invalidClient.close);
      await expectLater(
        ApiNotificationRepository(invalidClient)
            .getNotifications(patientId: 'GVC-1601', token: 'test-token'),
        throwsA(
          isA<ApiFailure>().having(
            (failure) => failure.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
    },
  );

  test('API auth failures become patient-session errors', () async {
    final client = ApiClient(
      baseUri: baseUri,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'success': false, 'error': 'Unauthorized'}),
          401,
        ),
      ),
    );
    addTearDown(client.close);

    await expectLater(
      ApiNotificationRepository(client)
          .getUnreadCount(patientId: 'GVC-1601', token: 'expired-token'),
      throwsA(
        isA<ApiFailure>().having(
          (failure) => failure.message,
          'message',
          'Your patient session is invalid or expired. Please sign in again.',
        ),
      ),
    );
  });

  test(
    'demo setup preserves local mock notifications without HTTP requests',
    () async {
      final setup = createPatientAuthSetup(mode: 'demo');
      addTearDown(setup.controller.dispose);

      expect(setup.notificationRepository.isDemo, isTrue);
      expect(
        await setup.notificationRepository.getNotifications(
          patientId: 'GVC-1601',
          token: '',
        ),
        same(NotificationMockData.notifications),
      );
    },
  );
}
