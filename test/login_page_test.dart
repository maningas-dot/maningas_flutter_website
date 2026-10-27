import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_portal_flutter/app/theme.dart';
import 'package:patient_portal_flutter/features/auth/forgot_password_page.dart';
import 'package:patient_portal_flutter/features/auth/login_page.dart';
import 'package:patient_portal_flutter/features/auth/registration_page.dart';

Widget _testApp() =>
    MaterialApp(theme: PatientPortalTheme.light, home: const LoginPage());

void main() {
  testWidgets('shows original patient login content and fields', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());

    expect(find.text('Gonzales Vision Clinic'), findsOneWidget);
    expect(find.text('PATIENT PORTAL'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(
      find.text('Sign in to access your patient account.'),
      findsOneWidget,
    );
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Create Patient Account'), findsOneWidget);
    expect(
      find.text('Your account information is protected and kept confidential.'),
      findsOneWidget,
    );
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms & Conditions'), findsOneWidget);
    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('validates required fields and email format', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your email address.'), findsOneWidget);
    expect(find.text('Please enter your password.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('login-Email Address')),
      'not-an-email',
    );
    await tester.pumpAndSettle();
    expect(find.text('Please enter a valid email address.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('login-Email Address')),
      'patient@example.com',
    );
    await tester.pumpAndSettle();
    expect(find.text('Please enter a valid email address.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('toggles password visibility and Remember Me locally', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp());

    final passwordField = find.byKey(const ValueKey('login-Password'));
    final editablePassword = find.descendant(
      of: passwordField,
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(editablePassword).obscureText, isTrue);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(editablePassword).obscureText, isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);

    expect(
      tester.widget<Checkbox>(find.byKey(const ValueKey('remember-me'))).value,
      isFalse,
    );
    await tester.tap(find.byKey(const ValueKey('remember-me')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Checkbox>(find.byKey(const ValueKey('remember-me'))).value,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('valid submission shows a local preview only', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());
    await tester.enterText(
      find.byKey(const ValueKey('login-Email Address')),
      'patient@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-Password')),
      'not-a-real-password',
    );
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'LOCAL DEMO PREVIEW: No real sign-in was performed and no information was sent.',
      ),
      findsOneWidget,
    );
    expect(find.byType(LoginPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Login navigates to Registration and Forgot Password', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    await tester.ensureVisible(find.text('Forgot password?'));
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordPage), findsOneWidget);
    await tester.tap(find.text('Back to login').first);
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);

    await tester.ensureVisible(find.text('Create Patient Account'));
    await tester.tap(find.text('Create Patient Account'));
    await tester.pumpAndSettle();
    expect(find.byType(RegistrationPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login layout fits desktop and narrow phone widths', (
    tester,
  ) async {
    for (final size in [
      const Size(1440, 1000),
      const Size(390, 844),
      const Size(320, 720),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget, reason: '$size');
      expect(tester.takeException(), isNull, reason: '$size');
      final card = tester.getRect(find.byKey(const ValueKey('login-card')));
      expect(card.left, greaterThanOrEqualTo(0), reason: '$size');
      expect(card.right, lessThanOrEqualTo(size.width), reason: '$size');
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('login heading and subtitle match original typography rules', (
    tester,
  ) async {
    final cases = [
      (size: const Size(1440, 1000), heading: 37.6, subtitle: 14.0),
      (size: const Size(1100, 900), heading: 33.0, subtitle: 14.0),
      (size: const Size(800, 900), heading: 30.4, subtitle: 14.0),
      (size: const Size(760, 844), heading: 28.8, subtitle: 13.12),
      (size: const Size(420, 844), heading: 25.6, subtitle: 12.48),
      (size: const Size(390, 844), heading: 25.6, subtitle: 12.48),
    ];

    for (final testCase in cases) {
      tester.view.physicalSize = testCase.size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      final heading = tester.widget<Text>(find.text('Welcome back')).style!;
      expect(heading.fontFamily, 'Segoe UI Black', reason: '${testCase.size}');
      expect(heading.fontFamilyFallback, [
        'Segoe UI',
        'Inter',
        'sans-serif',
      ], reason: '${testCase.size}');
      expect(heading.fontSize, testCase.heading, reason: '${testCase.size}');
      expect(heading.fontWeight, FontWeight.w800, reason: '${testCase.size}');
      expect(heading.height, 1.08, reason: '${testCase.size}');
      expect(
        heading.letterSpacing,
        closeTo(-testCase.heading * 0.045, 0.0001),
        reason: '${testCase.size}',
      );
      expect(
        heading.color,
        const Color(0xFF0F172A),
        reason: '${testCase.size}',
      );

      final subtitle = tester
          .widget<Text>(find.text('Sign in to access your patient account.'))
          .style!;
      expect(subtitle.fontFamily, 'Inter', reason: '${testCase.size}');
      expect(subtitle.fontSize, testCase.subtitle, reason: '${testCase.size}');
      expect(subtitle.fontWeight, FontWeight.w400, reason: '${testCase.size}');
      expect(
        subtitle.height,
        testCase.size.width <= 760 ? 1.7 : 1.6,
        reason: '${testCase.size}',
      );
      expect(tester.takeException(), isNull, reason: '${testCase.size}');
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('email and password input bounds match on desktop and mobile', (
    tester,
  ) async {
    for (final size in [
      const Size(1440, 1000),
      const Size(390, 844),
      const Size(320, 720),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      final emailRect = tester.getRect(
        find.byKey(const ValueKey('login-Email Address')),
      );
      final passwordRect = tester.getRect(
        find.byKey(const ValueKey('login-Password')),
      );
      expect(emailRect.width, passwordRect.width, reason: '$size');
      expect(emailRect.height, passwordRect.height, reason: '$size');
      expect(emailRect.left, passwordRect.left, reason: '$size');
      expect(tester.takeException(), isNull, reason: '$size');
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
