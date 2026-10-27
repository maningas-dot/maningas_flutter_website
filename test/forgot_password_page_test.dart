import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_portal_flutter/app/theme.dart';
import 'package:patient_portal_flutter/features/auth/forgot_password_page.dart';
import 'package:patient_portal_flutter/features/auth/login_page.dart';

Widget _testApp() => MaterialApp(
  theme: PatientPortalTheme.light,
  home: const ForgotPasswordPage(),
);

void _setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
}

Future<void> _advanceToResetStep(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('forgot-email')),
    'preview@example.test',
  );
  await tester.ensureVisible(find.byKey(const ValueKey('forgot-continue')));
  await tester.tap(find.byKey(const ValueKey('forgot-continue')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows initial email reset preview content', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());

    expect(find.text('Get back to\nyour account.'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(
      find.text(
        "Enter the email address associated with your patient account and "
        "we'll help you reset your password.",
      ),
      findsOneWidget,
    );
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Remember your password?'), findsOneWidget);
    expect(find.text('Back to login'), findsNWidgets(2));
    expect(
      find.text('© 2026 Gonzales Vision Clinic.\nYour vision, our priority.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('all email and reset fields use 14px entered text', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    final email = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('forgot-email')),
        matching: find.byType(EditableText),
      ),
    );
    expect(email.style.fontSize, 14);

    await _advanceToResetStep(tester);
    for (final key in const [
      ValueKey('reset-code'),
      ValueKey('new-password'),
      ValueKey('confirm-password'),
    ]) {
      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.style.fontSize, 14, reason: '$key');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('validates empty and malformed email addresses', (tester) async {
    _setPhoneViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());
    await tester.ensureVisible(find.byKey(const ValueKey('forgot-continue')));
    await tester.tap(find.byKey(const ValueKey('forgot-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Please enter your email address.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('forgot-email')),
      'not-an-email',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('forgot-continue')));
    await tester.tap(find.byKey(const ValueKey('forgot-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a valid email address.'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('valid email advances to local demo reset step', (tester) async {
    _setPhoneViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());
    await _advanceToResetStep(tester);

    expect(find.text('Reset your password'), findsOneWidget);
    expect(find.text('Verification Code'), findsOneWidget);
    expect(find.text('New Password'), findsOneWidget);
    expect(find.text('Confirm New Password'), findsOneWidget);
    expect(find.text('Change Password'), findsOneWidget);
    expect(
      find.text(
        'LOCAL DEMO PREVIEW: No email was sent. Enter any six digits to '
        'preview the next step.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('requires a six-digit verification code', (tester) async {
    _setPhoneViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());
    await _advanceToResetStep(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('reset-submit')));
    await tester.tap(find.byKey(const ValueKey('reset-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('Please enter the 6-digit verification code.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('validates password rules and confirmation', (tester) async {
    _setPhoneViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());
    await _advanceToResetStep(tester);

    await tester.ensureVisible(find.byKey(const ValueKey('reset-code')));
    await tester.enterText(find.byKey(const ValueKey('reset-code')), '12345');
    await tester.ensureVisible(find.byKey(const ValueKey('new-password')));
    await tester.enterText(find.byKey(const ValueKey('new-password')), 'abc');
    await tester.ensureVisible(find.byKey(const ValueKey('confirm-password')));
    await tester.enterText(
      find.byKey(const ValueKey('confirm-password')),
      'different',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('reset-submit')));
    await tester.tap(find.byKey(const ValueKey('reset-submit')));
    await tester.pumpAndSettle();
    expect(
      find.text('Please enter the 6-digit verification code.'),
      findsOneWidget,
    );
    expect(
      find.text('Password must be at least 8 characters long.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byKey(const ValueKey('reset-code')));
    await tester.enterText(find.byKey(const ValueKey('reset-code')), '123456');
    await tester.ensureVisible(find.byKey(const ValueKey('new-password')));
    await tester.enterText(
      find.byKey(const ValueKey('new-password')),
      'password1',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('confirm-password')));
    await tester.enterText(
      find.byKey(const ValueKey('confirm-password')),
      'password1',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('reset-submit')));
    await tester.tap(find.byKey(const ValueKey('reset-submit')));
    await tester.pumpAndSettle();
    expect(
      find.text('Password must contain at least one uppercase letter.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byKey(const ValueKey('new-password')));
    await tester.enterText(
      find.byKey(const ValueKey('new-password')),
      'PASSWORD1',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('reset-submit')));
    await tester.tap(find.byKey(const ValueKey('reset-submit')));
    await tester.pumpAndSettle();
    expect(
      find.text('Password must contain at least one lowercase letter.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byKey(const ValueKey('new-password')));
    await tester.enterText(
      find.byKey(const ValueKey('new-password')),
      'Password',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('reset-submit')));
    await tester.tap(find.byKey(const ValueKey('reset-submit')));
    await tester.pumpAndSettle();
    expect(
      find.text('Password must contain at least one number.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byKey(const ValueKey('new-password')));
    await tester.enterText(
      find.byKey(const ValueKey('new-password')),
      'Pass word1',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('reset-submit')));
    await tester.tap(find.byKey(const ValueKey('reset-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Password must not contain spaces.'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('new-password')));
    await tester.enterText(
      find.byKey(const ValueKey('new-password')),
      'Password1${List.filled(120, 'x').join()}',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('reset-submit')));
    await tester.tap(find.byKey(const ValueKey('reset-submit')));
    await tester.pumpAndSettle();
    expect(
      find.text('Password must not exceed 128 characters.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byKey(const ValueKey('new-password')));
    await tester.enterText(
      find.byKey(const ValueKey('new-password')),
      'Password1',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('confirm-password')));
    await tester.enterText(
      find.byKey(const ValueKey('confirm-password')),
      'Password2',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('reset-submit')));
    await tester.tap(find.byKey(const ValueKey('reset-submit')));
    await tester.pumpAndSettle();
    expect(find.text('The passwords do not match.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('valid demo reset shows no-account-operation confirmation', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());
    await _advanceToResetStep(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('reset-code')));
    await tester.enterText(find.byKey(const ValueKey('reset-code')), '123456');
    await tester.ensureVisible(find.byKey(const ValueKey('new-password')));
    await tester.enterText(
      find.byKey(const ValueKey('new-password')),
      'Password1',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('confirm-password')));
    await tester.enterText(
      find.byKey(const ValueKey('confirm-password')),
      'Password1',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('reset-submit')));
    await tester.tap(find.byKey(const ValueKey('reset-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'LOCAL DEMO PREVIEW: No password was changed. This reset flow is for display only.',
      ),
      findsOneWidget,
    );
    expect(find.byType(ForgotPasswordPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back-to-login opens Login from the standalone preview', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());
    await tester.ensureVisible(find.text('Back to login').first);
    await tester.tap(find.text('Back to login').first);
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('layout remains within desktop and mobile widths', (
    tester,
  ) async {
    for (final size in [
      const Size(1440, 1000),
      const Size(900, 900),
      const Size(480, 800),
      const Size(390, 844),
      const Size(320, 720),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      expect(find.text('Forgot password?'), findsOneWidget, reason: '$size');
      expect(tester.takeException(), isNull, reason: '$size');
      final email = tester.getRect(find.byKey(const ValueKey('forgot-email')));
      expect(email.left, greaterThanOrEqualTo(0), reason: '$size');
      expect(email.right, lessThanOrEqualTo(size.width), reason: '$size');
      if (size.width <= 900) {
        expect(find.text('Gonzales Vision Clinic'), findsOneWidget);
        expect(find.text('Get back to\nyour account.'), findsNothing);
      } else {
        expect(find.text('Get back to\nyour account.'), findsOneWidget);
      }
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('reset form scrolls without overflow on desktop and mobile', (
    tester,
  ) async {
    for (final size in [
      const Size(1440, 1000),
      const Size(1440, 600),
      const Size(390, 844),
      const Size(320, 720),
      const Size(320, 500),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('forgot-email')),
        findsOneWidget,
        reason: 'initial email field at $size',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('forgot-email')));
      await tester.enterText(
        find.byKey(const ValueKey('forgot-email')),
        'preview@example.test',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('forgot-continue')));
      await tester.tap(find.byKey(const ValueKey('forgot-continue')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Reset your password'), findsOneWidget, reason: '$size');
      expect(
        find.byKey(const ValueKey('reset-submit')),
        findsOneWidget,
        reason: '$size',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('reset-submit')));
      await tester.pumpAndSettle();

      final buttonRect = tester.getRect(
        find.byKey(const ValueKey('reset-submit')),
      );
      expect(buttonRect.top, greaterThanOrEqualTo(0), reason: '$size');
      expect(
        buttonRect.bottom,
        lessThanOrEqualTo(size.height),
        reason: '$size',
      );
      expect(tester.takeException(), isNull, reason: '$size');
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('back to email returns from local reset step', (tester) async {
    _setPhoneViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());
    await _advanceToResetStep(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('back-to-email')));
    await tester.tap(find.byKey(const ValueKey('back-to-email')));
    await tester.pumpAndSettle();

    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.byKey(const ValueKey('forgot-email')), findsOneWidget);
    expect(find.text('Reset your password'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
