import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patient_portal_flutter/app/theme.dart';
import 'package:patient_portal_flutter/core/network/api_client.dart';
import 'package:patient_portal_flutter/core/network/api_failure.dart';
import 'package:patient_portal_flutter/features/auth/application/patient_auth_controller.dart';
import 'package:patient_portal_flutter/features/auth/application/patient_auth_setup.dart';
import 'package:patient_portal_flutter/features/auth/application/patient_auth_scope.dart';
import 'package:patient_portal_flutter/features/auth/data/patient_auth_api_repository.dart';
import 'package:patient_portal_flutter/features/auth/data/patient_auth_repository.dart';
import 'package:patient_portal_flutter/features/auth/domain/patient_registration.dart';
import 'package:patient_portal_flutter/features/auth/domain/patient_session.dart';
import 'package:patient_portal_flutter/features/auth/domain/patient_session_store.dart';
import 'package:patient_portal_flutter/features/auth/login_page.dart';
import 'package:patient_portal_flutter/app/app.dart';

void main() {
  testWidgets('API setup keeps all portal repositories in API mode', (
    tester,
  ) async {
    final setup = createPatientAuthSetup(mode: 'api');
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
    });

    await tester.pumpWidget(PatientPortalApp(setup: setup, startAtLogin: true));

    final scopeContext = tester.element(find.byType(MaterialApp));
    expect(PatientAuthScope.framesCatalogOf(scopeContext)?.isDemo, isFalse);
    expect(PatientAuthScope.notificationsOf(scopeContext)?.isDemo, isFalse);
    expect(PatientAuthScope.transactionsOf(scopeContext)?.isDemo, isFalse);
    expect(
      PatientAuthScope.appointmentsHistoryOf(scopeContext)?.isDemo,
      isFalse,
    );
    expect(find.byType(LoginPage), findsOneWidget);
  });

  test(
    'maps patient login response and sends the confirmed body shape',
    () async {
      http.Request? captured;
      final client = ApiClient(
        baseUri: Uri.parse('https://example.test'),
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'success': true,
              'patient_id': 'GVC-1234',
              'name': 'Demo Patient',
              'email': 'patient@example.test',
              'email_verified': true,
              'token': 'test-token',
              'rememberMe': true,
            }),
            200,
          );
        }),
      );
      addTearDown(client.close);
      final repository = PatientAuthApiRepository(client);

      final result = await repository.login(
        email: ' patient@example.test ',
        password: 'a-test-password',
        rememberMe: true,
      );

      expect(captured!.url.path, '/api/patients/login');
      expect(jsonDecode(captured!.body), {
        'email': 'patient@example.test',
        'password': 'a-test-password',
        'rememberMe': true,
      });
      expect(result.isDemo, isFalse);
      expect(result.session, isA<PatientSession>());
      expect(result.session!.patientId, 'GVC-1234');
      expect(result.session!.token, 'test-token');
      expect(result.session!.rememberMe, isTrue);
    },
  );

  test('requires a complete successful login response', () async {
    final client = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'success': true, 'patient_id': 'GVC-1234'}),
          200,
        ),
      ),
    );
    addTearDown(client.close);

    await expectLater(
      PatientAuthApiRepository(client).login(
        email: 'patient@example.test',
        password: 'password',
        rememberMe: false,
      ),
      throwsA(isA<ApiFailure>()),
    );
  });

  test(
    'validates a session with the Bearer token and maps auth/me fields',
    () async {
      http.Request? captured;
      final client = ApiClient(
        baseUri: Uri.parse('https://example.test'),
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'success': true,
              'patient_id': 'GVC-1234',
              'name': 'Demo Patient',
              'email': 'patient@example.test',
              'email_verified': true,
              'status': 'Active',
            }),
            200,
          );
        }),
      );
      addTearDown(client.close);

      final session = await PatientAuthApiRepository(client)
          .validateSession('test-token');

      expect(captured!.url.path, '/api/patients/auth/me');
      expect(captured!.headers['authorization'], 'Bearer test-token');
      expect(session.patientId, 'GVC-1234');
      expect(session.name, 'Demo Patient');
      expect(session.email, 'patient@example.test');
      expect(session.status, 'Active');
      expect(session.emailVerified, isTrue);
    },
  );

  test('rejects auth/me responses without confirmed status', () async {
    final client = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'success': true,
            'patient_id': 'GVC-1234',
            'name': 'Demo Patient',
            'email': 'patient@example.test',
            'email_verified': true,
          }),
          200,
        ),
      ),
    );
    addTearDown(client.close);

    await expectLater(
      PatientAuthApiRepository(client).validateSession('test-token'),
      throwsA(
        isA<ApiFailure>().having(
          (failure) => failure.kind,
          'kind',
          ApiFailureKind.invalidResponse,
        ),
      ),
    );
  });

  testWidgets('keeps Login in explicit demo mode without a network request', (
    tester,
  ) async {
    var requests = 0;
    final client = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(theme: PatientPortalTheme.light, home: const LoginPage()),
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-Email Address')),
      'patient@example.test',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-Password')),
      'demo-password',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('login-submit')));
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'LOCAL DEMO PREVIEW: No real sign-in was performed and no information was sent.',
      ),
      findsOneWidget,
    );
    expect(requests, 0);
  });

  testWidgets('API login displays invalid credentials and network failures', (
    tester,
  ) async {
    final responses = <http.Response>[
      http.Response(jsonEncode({'error': 'Invalid email or password.'}), 401),
      http.Response(jsonEncode({'error': 'database message'}), 503),
    ];
    var failNetwork = false;
    final client = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient((_) async {
        if (failNetwork) throw http.ClientException('private network detail');
        return responses.removeAt(0);
      }),
    );
    final controller = PatientAuthController(
      repository: PatientAuthApiRepository(client),
      sessionStore: InMemoryPatientSessionStore(),
    );
    addTearDown(controller.dispose);
    addTearDown(client.close);

    await tester.pumpWidget(
      PatientAuthScope(
        controller: controller,
        child: MaterialApp(
          theme: PatientPortalTheme.light,
          home: const LoginPage(),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-Email Address')),
      'patient@example.test',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-Password')),
      'wrong-password',
    );
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Invalid email or password.'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('login-submit')));
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();
    expect(
      find.text('The clinic service is temporarily unavailable.'),
      findsOneWidget,
    );

    failNetwork = true;
    await tester.ensureVisible(find.byKey(const ValueKey('login-submit')));
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();
    expect(
      find.text('Unable to reach the clinic service. Check your connection.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows loading and prevents duplicate API submissions', (
    tester,
  ) async {
    final repository = _PendingLoginRepository();
    final controller = PatientAuthController(
      repository: repository,
      sessionStore: InMemoryPatientSessionStore(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      PatientAuthScope(
        controller: controller,
        child: MaterialApp(
          theme: PatientPortalTheme.light,
          home: const LoginPage(),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-Email Address')),
      'patient@example.test',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-Password')),
      'valid-password',
    );
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pump();

    expect(find.text('Signing in...'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('login-submit')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    expect(repository.calls, 1);

    repository.completer.complete(
      const PatientAuthResult.api(
        PatientSession(
          patientId: 'GVC-1234',
          name: 'Demo Patient',
          email: 'patient@example.test',
          token: 'test-token',
          rememberMe: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.calls, 1);
    expect(
      find.text(
        'Sign-in successful. Your session is held in memory only and will end when this page closes or reloads.',
      ),
      findsOneWidget,
    );
    expect(controller.currentSession!.patientId, 'GVC-1234');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'API-mode app gates Dashboard until login succeeds, then logs out',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = PatientAuthController(
        repository: _ImmediateLoginRepository(
          result: const PatientAuthResult.api(
            PatientSession(
              patientId: 'GVC-1234',
              name: 'Demo Patient',
              email: 'patient@example.test',
              token: 'test-token',
              rememberMe: false,
            ),
          ),
        ),
        sessionStore: InMemoryPatientSessionStore(),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(PatientPortalApp(controller: controller));
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('Welcome back, James'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('login-Email Address')),
        'patient@example.test',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-Password')),
        'valid-password',
      );
      await tester.tap(find.byKey(const ValueKey('login-submit')));
      await tester.pumpAndSettle();

      expect(controller.currentSession!.patientId, 'GVC-1234');
      expect(find.byType(LoginPage), findsNothing);
      expect(find.text('Welcome back, Demo Patient'), findsOneWidget);
      expect(find.text('DEMO DATA'), findsNothing);
      expect(find.text('Dashboard'), findsWidgets);

      await tester.ensureVisible(find.text('Logout'));
      await tester.tap(find.text('Logout').first);
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsOneWidget);
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();

      expect(controller.currentSession, isNull);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('Welcome back, James'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('API-mode failed login remains gated on Login', (tester) async {
    final controller = PatientAuthController(
      repository: _ImmediateLoginRepository(
        error: const ApiFailure(
          kind: ApiFailureKind.http,
          statusCode: 401,
          message: 'Invalid email or password.',
        ),
      ),
      sessionStore: InMemoryPatientSessionStore(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(PatientPortalApp(controller: controller));
    await tester.enterText(
      find.byKey(const ValueKey('login-Email Address')),
      'patient@example.test',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-Password')),
      'wrong-password',
    );
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Welcome back, James'), findsNothing);
    expect(find.text('Invalid email or password.'), findsOneWidget);
    expect(controller.currentSession, isNull);
    expect(tester.takeException(), isNull);
  });

  test('expired session validation clears only the rejected session', () async {
    final session = const PatientSession(
      patientId: 'GVC-1234',
      name: 'Demo Patient',
      email: 'patient@example.test',
      token: 'expired-token',
      rememberMe: false,
    );
    final store = InMemoryPatientSessionStore()..save(session);
    final controller = PatientAuthController(
      repository: _ImmediateLoginRepository(
        error: const ApiFailure(
          kind: ApiFailureKind.http,
          statusCode: 401,
          message: 'Your login session has expired.',
        ),
      ),
      sessionStore: store,
    );
    addTearDown(controller.dispose);

    expect(await controller.validateCurrentSession(), isFalse);
    expect(controller.currentSession, isNull);
  });

  test(
    'session validation network errors do not falsely sign the user out',
    () async {
      final session = const PatientSession(
        patientId: 'GVC-1234',
        name: 'Demo Patient',
        email: 'patient@example.test',
        token: 'test-token',
        rememberMe: false,
      );
      final store = InMemoryPatientSessionStore()..save(session);
      final controller = PatientAuthController(
        repository: _ImmediateLoginRepository(
          error: const ApiFailure(
            kind: ApiFailureKind.network,
            message: 'Network unavailable.',
          ),
        ),
        sessionStore: store,
      );
      addTearDown(controller.dispose);

      await expectLater(
        controller.validateCurrentSession(),
        throwsA(isA<ApiFailure>()),
      );
      expect(controller.currentSession, same(session));
    },
  );

  testWidgets('demo PatientPortalApp still starts at Dashboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const PatientPortalApp());

    expect(find.byType(LoginPage), findsNothing);
    expect(find.text('Welcome back, James'), findsOneWidget);
  });
}

class _ImmediateLoginRepository implements PatientAuthRepository {
  _ImmediateLoginRepository({this.result, this.error});

  final PatientAuthResult? result;
  final ApiFailure? error;

  @override
  Future<PatientAuthResult> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    if (error != null) throw error!;
    return result!;
  }

  @override
  Future<PatientSession> validateSession(String token) async {
    if (error != null) throw error!;
    return result!.session!;
  }

  @override
  Future<PatientRegistrationResult> register(
    PatientRegistrationRequest request,
  ) => throw UnimplementedError();

  @override
  Future<EmailVerificationResult> verifyEmail({
    required String email,
    required String otp,
  }) => throw UnimplementedError();

  @override
  Future<ResendVerificationResult> resendVerification({
    required String email,
  }) => throw UnimplementedError();
}

class _PendingLoginRepository implements PatientAuthRepository {
  final completer = Completer<PatientAuthResult>();
  int calls = 0;

  @override
  Future<PatientAuthResult> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) {
    calls++;
    return completer.future;
  }

  @override
  Future<PatientSession> validateSession(String token) {
    throw UnimplementedError();
  }

  @override
  Future<PatientRegistrationResult> register(
    PatientRegistrationRequest request,
  ) => throw UnimplementedError();

  @override
  Future<EmailVerificationResult> verifyEmail({
    required String email,
    required String otp,
  }) => throw UnimplementedError();

  @override
  Future<ResendVerificationResult> resendVerification({
    required String email,
  }) => throw UnimplementedError();
}
