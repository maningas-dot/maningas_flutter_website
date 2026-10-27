import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_portal_flutter/app/theme.dart';
import 'package:patient_portal_flutter/features/profile/change_password_page.dart';
import 'package:patient_portal_flutter/features/profile/profile_page.dart';

Widget _testApp({Widget home = const ChangePasswordPage()}) =>
    MaterialApp(theme: PatientPortalTheme.light, home: home);

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
}

const _currentField = ValueKey('change-password-Current Password');
const _newField = ValueKey('change-password-New Password');
const _confirmField = ValueKey('change-password-Confirm New Password');

void main() {
  testWidgets('shows three password fields and preview-only notice', (
    tester,
  ) async {
    _setViewport(tester, const Size(1440, 1000));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    expect(
      find.byKey(const ValueKey('change-password-heading')),
      findsOneWidget,
    );
    expect(find.text('Current Password'), findsOneWidget);
    expect(find.text('New Password'), findsOneWidget);
    expect(find.text('Confirm New Password'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('change-password-submit')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('change-password-cancel')),
      findsOneWidget,
    );
    expect(find.text('PREVIEW ONLY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('requires all fields and validates preview password rules', (
    tester,
  ) async {
    _setViewport(tester, const Size(600, 900));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    await tester.tap(find.byKey(const ValueKey('change-password-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Please enter your current password.'), findsOneWidget);
    expect(find.text('Please enter your new password.'), findsOneWidget);
    expect(find.text('Please confirm your new password.'), findsOneWidget);

    await tester.enterText(find.byKey(_currentField), 'current');
    await tester.enterText(find.byKey(_newField), 'short');
    await tester.enterText(find.byKey(_confirmField), 'short');
    await tester.ensureVisible(
      find.byKey(const ValueKey('change-password-submit')),
    );
    await tester.tap(find.byKey(const ValueKey('change-password-submit')));
    await tester.pumpAndSettle();
    expect(
      find.text('Password must be at least 8 characters long.'),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(_newField), 'alllowercase1');
    await tester.enterText(find.byKey(_confirmField), 'alllowercase1');
    await tester.ensureVisible(
      find.byKey(const ValueKey('change-password-submit')),
    );
    await tester.tap(find.byKey(const ValueKey('change-password-submit')));
    await tester.pumpAndSettle();
    expect(
      find.text('Password must contain at least one uppercase letter.'),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(_newField), 'NoNumberHere');
    await tester.enterText(find.byKey(_confirmField), 'NoNumberHere');
    await tester.ensureVisible(
      find.byKey(const ValueKey('change-password-submit')),
    );
    await tester.tap(find.byKey(const ValueKey('change-password-submit')));
    await tester.pumpAndSettle();
    expect(
      find.text('Password must contain at least one number.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejects spaces, overlong passwords, and mismatched values', (
    tester,
  ) async {
    _setViewport(tester, const Size(600, 900));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    await tester.enterText(find.byKey(_currentField), 'current');
    await tester.enterText(find.byKey(_newField), 'Strong Pass1');
    await tester.enterText(find.byKey(_confirmField), 'Different1');
    await tester.tap(find.byKey(const ValueKey('change-password-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Password must not contain spaces.'), findsOneWidget);

    await tester.enterText(find.byKey(_newField), 'StrongPass1');
    await tester.enterText(find.byKey(_confirmField), 'Different1');
    await tester.ensureVisible(
      find.byKey(const ValueKey('change-password-submit')),
    );
    await tester.tap(find.byKey(const ValueKey('change-password-submit')));
    await tester.pumpAndSettle();
    expect(find.text('The passwords do not match.'), findsOneWidget);

    await tester.enterText(find.byKey(_newField), 'A1${'a' * 127}');
    await tester.enterText(find.byKey(_confirmField), 'A1${'a' * 127}');
    await tester.ensureVisible(
      find.byKey(const ValueKey('change-password-submit')),
    );
    await tester.tap(find.byKey(const ValueKey('change-password-submit')));
    await tester.pumpAndSettle();
    expect(
      find.text('Password must not exceed 128 characters.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('visibility controls independently show and hide each value', (
    tester,
  ) async {
    _setViewport(tester, const Size(600, 900));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    final fields = [
      (
        _currentField,
        const ValueKey('change-password-toggle-Current Password'),
      ),
      (_newField, const ValueKey('change-password-toggle-New Password')),
      (
        _confirmField,
        const ValueKey('change-password-toggle-Confirm New Password'),
      ),
    ];
    for (final (fieldKey, toggleKey) in fields) {
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(fieldKey),
                matching: find.byType(EditableText),
              ),
            )
            .obscureText,
        isTrue,
      );
      await tester.tap(find.byKey(toggleKey));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(fieldKey),
                matching: find.byType(EditableText),
              ),
            )
            .obscureText,
        isFalse,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rejects a new password identical to current password without success',
    (tester) async {
      _setViewport(tester, const Size(600, 900));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_testApp());

      const samePassword = 'StrongPass1';
      await tester.enterText(find.byKey(_currentField), samePassword);
      await tester.enterText(find.byKey(_newField), samePassword);
      await tester.enterText(find.byKey(_confirmField), samePassword);
      await tester.ensureVisible(
        find.byKey(const ValueKey('change-password-submit')),
      );
      await tester.tap(find.byKey(const ValueKey('change-password-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('New password must be different from your current password.'),
        findsOneWidget,
      );
      expect(
        find.text('LOCAL PREVIEW ONLY: No password was changed.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('valid form advances to OTP without showing success', (
    tester,
  ) async {
    _setViewport(tester, const Size(600, 900));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    await tester.enterText(find.byKey(_currentField), 'OldPassword2');
    await tester.enterText(find.byKey(_newField), 'StrongPass1');
    await tester.enterText(find.byKey(_confirmField), 'StrongPass1');
    await tester.ensureVisible(
      find.byKey(const ValueKey('change-password-submit')),
    );
    await tester.tap(find.byKey(const ValueKey('change-password-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('New password must be different from your current password.'),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('change-password-otp-heading')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('change-password-success-heading')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('OTP requires six digits and then shows simulated success', (
    tester,
  ) async {
    _setViewport(tester, const Size(600, 900));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    await tester.enterText(find.byKey(_currentField), 'current password');
    await tester.enterText(find.byKey(_newField), 'StrongPass1');
    await tester.enterText(find.byKey(_confirmField), 'StrongPass1');
    await tester.ensureVisible(
      find.byKey(const ValueKey('change-password-submit')),
    );
    await tester.tap(find.byKey(const ValueKey('change-password-submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('change-password-otp-verify')));
    await tester.pumpAndSettle();
    expect(
      find.text('Please enter the complete 6-digit code.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('change-password-otp-code')),
      '12345',
    );
    await tester.tap(find.byKey(const ValueKey('change-password-otp-verify')));
    await tester.pumpAndSettle();
    expect(
      find.text('Please enter the complete 6-digit code.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('change-password-otp-code')),
      '123456',
    );
    await tester.tap(find.byKey(const ValueKey('change-password-otp-verify')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('change-password-success-heading')),
      findsOneWidget,
    );
    expect(
      find.text(
        'LOCAL DEMO PREVIEW: Verification succeeded in this '
        'simulation. No password was changed.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('resend starts a 30-second cooldown and clears entered code', (
    tester,
  ) async {
    _setViewport(tester, const Size(600, 900));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());
    await tester.enterText(find.byKey(_currentField), 'OldPassword2');
    await tester.enterText(find.byKey(_newField), 'StrongPass1');
    await tester.enterText(find.byKey(_confirmField), 'StrongPass1');
    await tester.tap(find.byKey(const ValueKey('change-password-submit')));
    await tester.pumpAndSettle();

    final code = find.byKey(const ValueKey('change-password-otp-code'));
    await tester.enterText(code, '123');
    await tester.tap(find.byKey(const ValueKey('change-password-otp-resend')));
    await tester.pump();

    expect(tester.widget<TextField>(code).controller!.text, isEmpty);
    expect(
      find.text('LOCAL SIMULATION: Resend available in 30s. No code was sent.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('change-password-otp-resend')),
          )
          .onPressed,
      isNull,
    );
    await tester.pump(const Duration(seconds: 29));
    expect(
      find.text('LOCAL SIMULATION: Resend available in 1s. No code was sent.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.byKey(const ValueKey('change-password-otp-countdown')),
      findsNothing,
    );
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('change-password-otp-resend')),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling OTP clears temporary password values', (
    tester,
  ) async {
    _setViewport(tester, const Size(600, 900));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());
    await tester.enterText(find.byKey(_currentField), 'OldPassword2');
    await tester.enterText(find.byKey(_newField), 'StrongPass1');
    await tester.enterText(find.byKey(_confirmField), 'StrongPass1');
    await tester.tap(find.byKey(const ValueKey('change-password-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('change-password-otp-cancel')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('change-password-otp-heading')),
      findsNothing,
    );
    expect(
      tester.widget<TextFormField>(find.byKey(_currentField)).controller!.text,
      isEmpty,
    );
    expect(
      tester.widget<TextFormField>(find.byKey(_newField)).controller!.text,
      isEmpty,
    );
    expect(
      tester.widget<TextFormField>(find.byKey(_confirmField)).controller!.text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed OTP preview returns to My Profile', (tester) async {
    _setViewport(tester, const Size(1440, 1200));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp(home: const ProfilePage()));
    await tester.tap(
      find.byKey(const ValueKey('profile-change-password-action')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(_currentField), 'OldPassword2');
    await tester.enterText(find.byKey(_newField), 'StrongPass1');
    await tester.enterText(find.byKey(_confirmField), 'StrongPass1');
    await tester.tap(find.byKey(const ValueKey('change-password-submit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('change-password-otp-code')),
      '654321',
    );
    await tester.tap(find.byKey(const ValueKey('change-password-otp-verify')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('change-password-return-profile')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('View your personal information and clinic account details.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('change-password-heading')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('My Profile opens Change Password and Cancel returns', (
    tester,
  ) async {
    _setViewport(tester, const Size(1440, 1200));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp(home: const ProfilePage()));

    await tester.tap(
      find.byKey(const ValueKey('profile-change-password-action')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Confirm New Password'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('change-password-cancel')),
    );
    await tester.tap(find.byKey(const ValueKey('change-password-cancel')));
    await tester.pumpAndSettle();
    expect(
      find.text('View your personal information and clinic account details.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('profile-edit-action')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('profile-change-password-action')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in const [
    Size(1440, 900),
    Size(600, 800),
    Size(390, 700),
    Size(320, 480),
  ]) {
    testWidgets('Change Password form scrolls without overflow at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      _setViewport(tester, size);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_testApp());

      expect(
        find.byKey(const ValueKey('change-password-scroll')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('change-password-cancel')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
