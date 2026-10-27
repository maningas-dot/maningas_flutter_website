import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patient_portal_flutter/core/network/api_client.dart';
import 'package:patient_portal_flutter/core/network/api_failure.dart';
import 'package:patient_portal_flutter/features/auth/data/patient_auth_api_repository.dart';
import 'package:patient_portal_flutter/features/auth/application/patient_auth_controller.dart';
import 'package:patient_portal_flutter/features/auth/application/patient_auth_scope.dart';
import 'package:patient_portal_flutter/features/auth/domain/patient_registration.dart';
import 'package:patient_portal_flutter/features/auth/domain/patient_session_store.dart';
import 'package:patient_portal_flutter/features/auth/login_page.dart';
import 'package:patient_portal_flutter/features/auth/verify_email_page.dart';

void main() {
  test(
    'blocks API registration before dispatching submitted credentials',
    () async {
      var requests = 0;
      final client = ApiClient(
        baseUri: Uri.parse('https://example.test'),
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      addTearDown(client.close);

      await expectLater(
        PatientAuthApiRepository(client).register(
          const PatientRegistrationRequest(
            name: 'Patient Name',
            age: 30,
            dateOfBirth: '1995-01-01',
            gender: 'Female',
            contact: '09171234567',
            email: 'patient@example.test',
            password: 'not-transmitted',
          ),
        ),
        throwsA(
          isA<ApiFailure>()
              .having(
                (failure) => failure.kind,
                'kind',
                ApiFailureKind.securityBlocked,
              )
              .having(
                (failure) => failure.message,
                'message',
                contains('No registration request was sent.'),
              ),
        ),
      );
      expect(requests, 0);
    },
  );

  test('posts exact verification body and maps confirmed success', () async {
    http.Request? captured;
    final client = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Email verified successfully. Your account has been created. Please sign in.',
            'patient_id': 'GVC-1234',
            'email': 'patient@example.test',
            'name': 'Patient Name',
            'email_verified': true,
          }),
          201,
        );
      }),
    );
    addTearDown(client.close);

    final result = await PatientAuthApiRepository(client)
        .verifyEmail(email: ' patient@example.test ', otp: '123456');

    expect(captured!.url.path, '/api/patients/verify-email');
    expect(jsonDecode(captured!.body), {
      'email': 'patient@example.test',
      'otp': '123456',
    });
    expect(result.isDemo, isFalse);
    expect(result.message, contains('Please sign in.'));
  });

  test('posts resend email and maps verified/not-sent response', () async {
    http.Request? captured;
    final client = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Email is already verified.',
            'email_verified': true,
          }),
          200,
        );
      }),
    );
    addTearDown(client.close);

    final result = await PatientAuthApiRepository(client)
        .resendVerification(email: ' patient@example.test ');

    expect(captured!.url.path, '/api/patients/resend-verification');
    expect(jsonDecode(captured!.body), {'email': 'patient@example.test'});
    expect(result.isDemo, isFalse);
    expect(result.emailVerified, isTrue);
    expect(result.message, 'Email is already verified.');
  });

  test('maps invalid and expired code response without accepting it', () async {
    final client = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'error': 'Verification code is invalid or expired.'}),
          400,
        ),
      ),
    );
    addTearDown(client.close);

    await expectLater(
      PatientAuthApiRepository(client)
          .verifyEmail(email: 'patient@example.test', otp: '123456'),
      throwsA(
        isA<ApiFailure>()
            .having((failure) => failure.statusCode, 'status', 400)
            .having(
              (failure) => failure.message,
              'message',
              'Verification code is invalid or expired.',
            ),
      ),
    );
  });

  test(
    'does not accept a success response without verified identity fields',
    () async {
      final client = ApiClient(
        baseUri: Uri.parse('https://example.test'),
        client: MockClient(
          (_) async => http.Response(jsonEncode({'success': true}), 200),
        ),
      );
      addTearDown(client.close);

      await expectLater(
        PatientAuthApiRepository(client)
            .verifyEmail(email: 'patient@example.test', otp: '123456'),
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

  testWidgets('confirmed API verification returns to Login without a session', (
    tester,
  ) async {
    http.Request? captured;
    final client = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Email verified successfully. Your account has been created. Please sign in.',
            'patient_id': 'GVC-1234',
            'email': 'patient@example.test',
            'name': 'Patient Name',
            'email_verified': true,
          }),
          201,
        );
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
          home: const VerifyEmailPage(email: 'patient@example.test'),
        ),
      ),
    );
    for (var index = 0; index < 6; index++) {
      await tester.enterText(
        find.byKey(ValueKey('verify-digit-$index')),
        '${index + 1}',
      );
    }
    final submit = find.byKey(const ValueKey('verify-email-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(captured!.url.path, '/api/patients/verify-email');
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Email verified. You can now sign in.'), findsOneWidget);
    expect(controller.currentSession, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('API verification failure stays on OTP and shows server error', (
    tester,
  ) async {
    final client = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'error': 'Verification code is invalid or expired.'}),
          400,
        ),
      ),
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
          home: const VerifyEmailPage(email: 'patient@example.test'),
        ),
      ),
    );
    for (var index = 0; index < 6; index++) {
      await tester.enterText(
        find.byKey(ValueKey('verify-digit-$index')),
        '${index + 1}',
      );
    }
    final submit = find.byKey(const ValueKey('verify-email-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.byType(VerifyEmailPage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
    expect(
      find.text('Verification code is invalid or expired.'),
      findsOneWidget,
    );
    expect(controller.currentSession, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('API resend starts cooldown only after backend confirmation', (
    tester,
  ) async {
    http.Request? captured;
    final client = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'A new verification code has been sent to your email.',
            'email': 'patient@example.test',
            'email_verified': false,
          }),
          200,
        );
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
          home: const VerifyEmailPage(email: 'patient@example.test'),
        ),
      ),
    );
    final resend = find.byKey(const ValueKey('verify-resend'));
    await tester.ensureVisible(resend);
    await tester.tap(resend);
    await tester.pumpAndSettle();

    expect(captured!.url.path, '/api/patients/resend-verification');
    expect(
      find.text('A new verification code has been sent to your email.'),
      findsOneWidget,
    );
    expect(find.text('You can resend in 30s'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
