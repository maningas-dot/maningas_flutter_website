import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_portal_flutter/app/theme.dart';
import 'package:patient_portal_flutter/features/auth/login_page.dart';
import 'package:patient_portal_flutter/features/auth/registration_page.dart';
import 'package:patient_portal_flutter/features/auth/verify_email_page.dart';

Widget _testApp({String? email}) => MaterialApp(
  theme: PatientPortalTheme.light,
  home: VerifyEmailPage(email: email),
);

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
}

void main() {
  testWidgets('shows verification page content and transient email', (
    tester,
  ) async {
    _setViewport(tester, const Size(1440, 1000));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp(email: 'person@example.test'));

    expect(find.text('Verify your\nemail address.'), findsOneWidget);
    expect(find.text('Verify your email'), findsOneWidget);
    expect(
      find.text(
        'LOCAL PREVIEW ONLY: Enter any six-digit code. No account is created and no verification email is sent.',
      ),
      findsOneWidget,
    );
    final description = tester.widget<Text>(
      find.byKey(const ValueKey('verify-email-description')),
    );
    expect(
      (description.textSpan! as TextSpan).toPlainText(),
      contains('person@example.test'),
    );
    expect(find.text('Verification code'), findsOneWidget);
    expect(find.text('Verify Email'), findsOneWidget);
    expect(find.text("Didn't receive the code?"), findsOneWidget);
    expect(find.text('Resend code'), findsOneWidget);
    expect(find.text('Back to registration'), findsOneWidget);
    expect(
      find.text('© 2026 Gonzales Vision Clinic.\nYour vision, our priority.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('verify-brand-panel')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('verify-mobile-brand-mark')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('verify-digit-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('verify-digit-5')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses neutral email fallback when no email was provided', (
    tester,
  ) async {
    _setViewport(tester, const Size(600, 900));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());
    final description = tester.widget<Text>(
      find.byKey(const ValueKey('verify-email-description')),
    );
    expect(
      (description.textSpan! as TextSpan).toPlainText(),
      contains('your email address'),
    );
    expect(find.byKey(const ValueKey('verify-brand-panel')), findsNothing);
    expect(
      find.byKey(const ValueKey('verify-mobile-brand-mark')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('switches from desktop branding panel at the 900px breakpoint', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    _setViewport(tester, const Size(901, 900));
    await tester.pumpWidget(_testApp());
    expect(find.byKey(const ValueKey('verify-brand-panel')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('verify-mobile-brand-mark')),
      findsNothing,
    );

    _setViewport(tester, const Size(900, 900));
    await tester.pump();
    expect(find.byKey(const ValueKey('verify-brand-panel')), findsNothing);
    expect(
      find.byKey(const ValueKey('verify-mobile-brand-mark')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters digits and advances focus between boxes', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    final first = find.byKey(const ValueKey('verify-digit-0'));
    final second = find.byKey(const ValueKey('verify-digit-1'));
    await tester.tap(first);
    await tester.enterText(first, 'a1');
    await tester.pump();
    expect(tester.widget<TextField>(first).controller!.text, '1');
    expect(tester.widget<TextField>(second).focusNode!.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports backspace and arrow navigation', (tester) async {
    _setViewport(tester, const Size(390, 844));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    final first = find.byKey(const ValueKey('verify-digit-0'));
    final second = find.byKey(const ValueKey('verify-digit-1'));
    final third = find.byKey(const ValueKey('verify-digit-2'));
    await tester.tap(first);
    await tester.enterText(first, '1');
    await tester.enterText(second, '2');
    expect(tester.widget<TextField>(third).focusNode!.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(tester.widget<TextField>(second).focusNode!.hasFocus, isTrue);
    await tester.enterText(second, '');
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(tester.widget<TextField>(first).focusNode!.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pasting digits fills boxes and strips non-digits', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    final first = find.byKey(const ValueKey('verify-digit-0'));
    await tester.tap(first);
    await tester.enterText(first, '12a34-56');
    await tester.pump();
    final values = List.generate(
      6,
      (index) => tester
          .widget<TextField>(find.byKey(ValueKey('verify-digit-$index')))
          .controller!
          .text,
    );
    expect(values.join(), '123456');
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty and incomplete verification show local errors', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    final submit = find.byKey(const ValueKey('verify-email-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(
      find.text('Please enter the complete 6-digit verification code.'),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const ValueKey('verify-digit-0')), '123');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(
      find.text('Please enter the complete 6-digit verification code.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('six digits produce only a preview confirmation', (tester) async {
    _setViewport(tester, const Size(390, 844));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

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
    expect(
      find.text(
        'LOCAL PREVIEW ONLY: This code was not verified and no account was activated.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'resend simulation starts on demand and expires after 30 seconds',
    (tester) async {
      _setViewport(tester, const Size(390, 844));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_testApp());

      expect(find.byKey(const ValueKey('verify-countdown')), findsNothing);
      final first = find.byKey(const ValueKey('verify-digit-0'));
      await tester.enterText(first, '1');
      await tester.tap(find.byKey(const ValueKey('verify-resend')));
      await tester.pump();
      expect(
        find.text('LOCAL SIMULATION: You can resend in 30s'),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(first).controller!.text, isEmpty);
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('verify-resend')))
            .onPressed,
        isNull,
      );
      await tester.pump(const Duration(seconds: 29));
      expect(
        find.text('LOCAL SIMULATION: You can resend in 1s'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('verify-countdown')), findsNothing);
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('verify-resend')))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('standalone verification can navigate to Registration', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    await tester.tap(find.byKey(const ValueKey('verify-back-registration')));
    await tester.pumpAndSettle();
    expect(find.byType(RegistrationPage), findsOneWidget);
    expect(find.text('Create your account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back to Login clears the verification navigation stack', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());
    final login = find.byKey(const ValueKey('verify-back-login'));
    await tester.ensureVisible(login);
    await tester.tap(login);
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('short mobile viewport scrolls through the complete form', (
    tester,
  ) async {
    _setViewport(tester, const Size(320, 600));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    final scrollable = find.byType(Scrollable).first;
    final scrollState = tester.state<ScrollableState>(scrollable);
    expect(scrollState.position.maxScrollExtent, greaterThan(0));
    await tester.ensureVisible(find.byKey(const ValueKey('verify-back-login')));
    expect(find.byKey(const ValueKey('verify-back-login')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [
    Size(1440, 1000),
    Size(900, 900),
    Size(600, 900),
    Size(480, 844),
    Size(390, 844),
    Size(350, 844),
    Size(320, 600),
  ]) {
    testWidgets('has no overflow at ${size.width}x${size.height}', (
      tester,
    ) async {
      _setViewport(tester, size);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_testApp(email: 'preview@example.test'));
      expect(tester.takeException(), isNull);
    });
  }
}
