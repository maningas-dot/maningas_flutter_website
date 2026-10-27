import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patient_portal_flutter/app/theme.dart';
import 'package:patient_portal_flutter/core/network/api_client.dart';
import 'package:patient_portal_flutter/features/auth/application/patient_auth_controller.dart';
import 'package:patient_portal_flutter/features/auth/application/patient_auth_scope.dart';
import 'package:patient_portal_flutter/features/auth/data/demo_patient_auth_repository.dart';
import 'package:patient_portal_flutter/features/auth/domain/patient_session.dart';
import 'package:patient_portal_flutter/features/auth/domain/patient_session_store.dart';
import 'package:patient_portal_flutter/features/shell/notification_repository.dart';
import 'package:patient_portal_flutter/features/shell/portal_navigation.dart';
import 'package:patient_portal_flutter/features/shell/portal_shell.dart';

void main() {
  testWidgets('API notifications mark unread once and support mark all', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <http.Request>[];
    final client = ApiClient(
      baseUri: Uri.parse('https://api.example.test'),
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/notifications/patient/GVC-1601') {
          return http.Response(
            jsonEncode([
              {
                'notification_id': 40,
                'title': 'First notice',
                'body': 'First description.',
                'is_read': 0,
                'created_at': '2026-10-27T09:30:00Z',
              },
              {
                'notification_id': 41,
                'title': 'Second notice',
                'body': 'Second description.',
                'is_read': 0,
                'created_at': '2026-10-26T09:30:00Z',
              },
            ]),
            200,
          );
        }
        if (request.url.path.endsWith('/unread-count')) {
          return http.Response(jsonEncode({'unread_count': 2}), 200);
        }
        if (request.url.path == '/api/notifications/40/read') {
          return http.Response(
            jsonEncode({
              'success': true,
              'notification_id': 40,
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
    final store = InMemoryPatientSessionStore()
      ..save(
        const PatientSession(
          patientId: 'GVC-1601',
          name: 'Patient',
          email: 'patient@example.test',
          token: 'test-token',
          rememberMe: false,
        ),
      );
    final controller = PatientAuthController(
      repository: const DemoPatientAuthRepository(),
      sessionStore: store,
      isDemoMode: false,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      PatientAuthScope(
        controller: controller,
        notificationRepository: ApiNotificationRepository(client),
        child: MaterialApp(
          theme: PatientPortalTheme.light,
          home: PortalShell(
            selectedDestination: PortalDestination.dashboard,
            onSelectDestination: (_) {},
            isDark: false,
            onToggleTheme: () {},
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('2 unread'), findsOneWidget);
    expect(find.text('PATIENT NOTIFICATIONS'), findsOneWidget);
    await tester.tap(find.text('First notice'));
    await tester.pumpAndSettle();
    expect(find.text('1 unread'), findsOneWidget);
    expect(
      requests.where(
        (request) => request.url.path == '/api/notifications/40/read',
      ),
      hasLength(1),
    );

    await tester.tap(find.text('First notice'));
    await tester.pumpAndSettle();
    expect(
      requests.where(
        (request) => request.url.path == '/api/notifications/40/read',
      ),
      hasLength(1),
    );

    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();
    expect(find.text('0 unread'), findsOneWidget);
    expect(
      requests.where((request) => request.url.path.endsWith('/read-all')),
      hasLength(1),
    );
    expect(
      requests.every(
        (request) => request.headers['authorization'] == 'Bearer test-token',
      ),
      isTrue,
    );
  });

  testWidgets('failed read operation leaves the notification unread', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = ApiClient(
      baseUri: Uri.parse('https://api.example.test'),
      client: MockClient((request) async {
        if (request.url.path == '/api/notifications/patient/GVC-1601') {
          return http.Response(
            jsonEncode([
              {
                'notification_id': 40,
                'title': 'Unread notice',
                'body': 'Still unread if the update fails.',
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
        if (request.url.path == '/api/notifications/40/read') {
          return http.Response(
            jsonEncode({'success': false, 'error': 'Unavailable'}),
            500,
          );
        }
        return http.Response('Not found', 404);
      }),
    );
    addTearDown(client.close);
    final store = InMemoryPatientSessionStore()
      ..save(
        const PatientSession(
          patientId: 'GVC-1601',
          name: 'Patient',
          email: 'patient@example.test',
          token: 'test-token',
          rememberMe: false,
        ),
      );
    final controller = PatientAuthController(
      repository: const DemoPatientAuthRepository(),
      sessionStore: store,
      isDemoMode: false,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      PatientAuthScope(
        controller: controller,
        notificationRepository: ApiNotificationRepository(client),
        child: MaterialApp(
          theme: PatientPortalTheme.light,
          home: PortalShell(
            selectedDestination: PortalDestination.dashboard,
            onSelectDestination: (_) {},
            isDark: false,
            onToggleTheme: () {},
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unread notice'));
    await tester.pumpAndSettle();

    expect(find.text('1 unread'), findsOneWidget);
    expect(
      find.text('The clinic service is temporarily unavailable.'),
      findsOneWidget,
    );
  });

  testWidgets('401 notification response stops polling and prompts sign-in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <http.Request>[];
    final client = ApiClient(
      baseUri: Uri.parse('https://api.example.test'),
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({'success': false, 'error': 'Unauthorized'}),
          401,
        );
      }),
    );
    addTearDown(client.close);
    final store = InMemoryPatientSessionStore()
      ..save(
        const PatientSession(
          patientId: 'GVC-1601',
          name: 'Patient',
          email: 'patient@example.test',
          token: 'test-token',
          rememberMe: false,
        ),
      );
    final controller = PatientAuthController(
      repository: const DemoPatientAuthRepository(),
      sessionStore: store,
      isDemoMode: false,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      PatientAuthScope(
        controller: controller,
        notificationRepository: ApiNotificationRepository(client),
        child: MaterialApp(
          theme: PatientPortalTheme.light,
          home: PortalShell(
            selectedDestination: PortalDestination.dashboard,
            onSelectDestination: (_) {},
            isDark: false,
            onToggleTheme: () {},
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/api/notifications/patient/GVC-1601');
    expect(
      requests.single.headers['authorization']!.startsWith('Bearer '),
      isTrue,
    );

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Your patient session is invalid or expired. Please sign in again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);

    await tester.pump(const Duration(seconds: 45));
    expect(requests, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
