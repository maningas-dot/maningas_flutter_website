import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patient_portal_flutter/app/app.dart';
import 'package:patient_portal_flutter/app/theme.dart';
import 'package:patient_portal_flutter/core/network/api_client.dart';
import 'package:patient_portal_flutter/features/auth/application/patient_auth_controller.dart';
import 'package:patient_portal_flutter/features/auth/application/patient_auth_scope.dart';
import 'package:patient_portal_flutter/features/auth/data/patient_auth_api_repository.dart';
import 'package:patient_portal_flutter/features/auth/domain/patient_session.dart';
import 'package:patient_portal_flutter/features/auth/domain/patient_session_store.dart';
import 'package:patient_portal_flutter/features/auth/login_page.dart';
import 'package:patient_portal_flutter/features/profile/profile_page.dart';

void main() {
  testWidgets('shows identity loading and prevents duplicate API requests', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    var requests = 0;
    final apiClient = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient((_) {
        requests++;
        return response.future;
      }),
    );
    final controller = _controller(apiClient);
    addTearDown(controller.dispose);
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      PatientAuthScope(
        controller: controller,
        child: MaterialApp(
          theme: PatientPortalTheme.light,
          home: ProfilePage(),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('profile-identity-loading')),
      findsOneWidget,
    );
    final firstLoad = controller.loadCurrentPatientIdentity();
    final secondLoad = controller.loadCurrentPatientIdentity();
    expect(requests, 1);

    response.complete(_identityResponse());
    await Future.wait([firstLoad, secondLoad]);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('profile-identity-loading')),
      findsNothing,
    );
    expect(find.text('Confirmed Patient'), findsWidgets);
  });

  testWidgets(
    'loads authenticated identity and excludes unsupported mock data',
    (tester) async {
      http.Request? request;
      final apiClient = ApiClient(
        baseUri: Uri.parse('https://example.test'),
        client: MockClient((incoming) async {
          request = incoming;
          return _identityResponse();
        }),
      );
      final controller = _controller(apiClient);
      addTearDown(controller.dispose);
      addTearDown(apiClient.close);

      await tester.pumpWidget(
        PatientAuthScope(
          controller: controller,
          child: MaterialApp(
            theme: PatientPortalTheme.light,
            home: ProfilePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(request!.url.path, '/api/patients/auth/me');
      expect(request!.headers['authorization'], 'Bearer test-session-token');
      expect(find.text('Confirmed Patient'), findsWidgets);
      expect(find.text('GVC-9001'), findsWidgets);
      expect(find.text('confirmed@example.test'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Active'), findsWidgets);
      expect(
        find.text(
          'Unavailable — not returned by the authenticated profile service',
        ),
        findsWidgets,
      );
      expect(find.text('0917 123 4567'), findsNothing);
      expect(find.text('GVC-1601'), findsNothing);
      expect(controller.currentSession!.patientId, 'GVC-9001');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows a retry after server failure and preserves the session', (
    tester,
  ) async {
    var requests = 0;
    final apiClient = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient((_) async {
        requests++;
        if (requests == 1) {
          return http.Response('{"error":"unavailable"}', 503);
        }
        if (requests == 2) {
          throw http.ClientException('test connection failure');
        }
        return _identityResponse();
      }),
    );
    final controller = _controller(apiClient);
    addTearDown(controller.dispose);
    addTearDown(apiClient.close);

    await tester.pumpWidget(
      PatientAuthScope(
        controller: controller,
        child: MaterialApp(
          theme: PatientPortalTheme.light,
          home: ProfilePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.currentSession, isNotNull);
    expect(
      find.byKey(const ValueKey('profile-identity-error')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('profile-identity-retry')),
      findsOneWidget,
    );
    expect(find.text('confirmed@example.test'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('profile-identity-retry')));
    await tester.pumpAndSettle();

    expect(requests, 2);
    expect(controller.currentSession, isNotNull);
    expect(
      find.byKey(const ValueKey('profile-identity-error')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('profile-identity-retry')));
    await tester.pumpAndSettle();

    expect(requests, 3);
    expect(find.byKey(const ValueKey('profile-identity-error')), findsNothing);
    expect(find.text('confirmed@example.test'), findsOneWidget);
    expect(controller.currentSession, isNotNull);
  });

  testWidgets('401 clears the session and the app returns to Login', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient(
        (_) async => http.Response('{"error":"unauthorized"}', 401),
      ),
    );
    final store = _sessionStore();
    final controller = PatientAuthController(
      repository: PatientAuthApiRepository(client),
      sessionStore: store,
    );
    addTearDown(controller.dispose);
    addTearDown(client.close);

    await tester.pumpWidget(PatientPortalApp(controller: controller));
    await tester.tap(find.text('My Profile').first);
    await tester.pumpAndSettle();

    expect(controller.currentSession, isNull);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Confirmed Patient'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('403 clears the authenticated session', () async {
    final apiClient = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient(
        (_) async => http.Response('{"error":"forbidden"}', 403),
      ),
    );
    final controller = _controller(apiClient);
    addTearDown(controller.dispose);
    addTearDown(apiClient.close);

    expect(await controller.loadCurrentPatientIdentity(), isFalse);
    expect(controller.currentSession, isNull);
  });

  test(
    'logout prevents a late identity response restoring the old session',
    () async {
      final response = Completer<http.Response>();
      final apiClient = ApiClient(
        baseUri: Uri.parse('https://example.test'),
        client: MockClient((_) => response.future),
      );
      final controller = _controller(apiClient);
      addTearDown(controller.dispose);
      addTearDown(apiClient.close);

      final load = controller.loadCurrentPatientIdentity();
      controller.logout();
      response.complete(_identityResponse());
      expect(await load, isFalse);
      expect(controller.currentSession, isNull);
    },
  );

  testWidgets('demo Profile stays network-free and keeps its demo identity', (
    tester,
  ) async {
    var requests = 0;
    final client = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient((_) async {
        requests++;
        return _identityResponse();
      }),
    );
    final controller = PatientAuthController(
      repository: PatientAuthApiRepository(client),
      sessionStore: InMemoryPatientSessionStore(),
      isDemoMode: true,
    );
    addTearDown(controller.dispose);
    addTearDown(client.close);

    await tester.pumpWidget(
      PatientAuthScope(
        controller: controller,
        child: MaterialApp(
          theme: PatientPortalTheme.light,
          home: ProfilePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requests, 0);
    expect(find.text('James Maningas'), findsWidgets);
    expect(find.text('GVC-1601'), findsWidgets);
    expect(find.text('DEMO DATA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

PatientAuthController _controller(ApiClient apiClient) {
  return PatientAuthController(
    repository: PatientAuthApiRepository(apiClient),
    sessionStore: _sessionStore(),
  );
}

InMemoryPatientSessionStore _sessionStore() {
  return InMemoryPatientSessionStore()..save(
    const PatientSession(
      patientId: 'GVC-9001',
      name: 'Login Name',
      email: 'login@example.test',
      token: 'test-session-token',
      rememberMe: false,
    ),
  );
}

http.Response _identityResponse() {
  return http.Response(
    jsonEncode({
      'success': true,
      'patient_id': 'GVC-9001',
      'name': 'Confirmed Patient',
      'email': 'confirmed@example.test',
      'email_verified': true,
      'status': 'Active',
    }),
    200,
  );
}
