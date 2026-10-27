import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patient_portal_flutter/core/network/api_client.dart';
import 'package:patient_portal_flutter/features/auth/application/patient_auth_controller.dart';
import 'package:patient_portal_flutter/features/auth/application/patient_auth_scope.dart';
import 'package:patient_portal_flutter/features/auth/data/patient_auth_api_repository.dart';
import 'package:patient_portal_flutter/features/auth/domain/patient_session_store.dart';
import 'package:patient_portal_flutter/features/auth/login_page.dart';
import 'package:patient_portal_flutter/features/auth/registration_page.dart';
import 'package:patient_portal_flutter/features/auth/verify_email_page.dart';

Widget _testApp() => const MaterialApp(home: RegistrationPage());

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
}

Future<void> _enter(WidgetTester tester, String id, String value) async {
  final field = find.byKey(ValueKey('registration-$id'));
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
}

Future<DateTime> _pickDateOfBirth(
  WidgetTester tester, {
  bool openPicker = true,
}) async {
  if (openPicker) {
    final pickerButton = find.byKey(const ValueKey('registration-date-picker'));
    await tester.ensureVisible(pickerButton);
    await tester.tap(pickerButton);
    await tester.pumpAndSettle();
  }

  final calendar = tester.widget<CalendarDatePicker>(
    find.byType(CalendarDatePicker),
  );
  final referenceDate = calendar.initialDate ?? calendar.lastDate;

  final day = find.descendant(
    of: find.byType(CalendarDatePicker),
    matching: find.text('${referenceDate.day}'),
  );
  await tester.tap(day.last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  return DateTime.parse(
    tester
        .widget<TextField>(
          find.byKey(const ValueKey('registration-dateOfBirth')),
        )
        .controller!
        .text,
  );
}

int _ageFor(DateTime date, DateTime today) {
  var age = today.year - date.year;
  if (today.month < date.month ||
      (today.month == date.month && today.day < date.day)) {
    age--;
  }
  return age;
}

Future<void> _select(WidgetTester tester, String id, String option) async {
  final field = find.byKey(ValueKey('registration-$id'));
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _fillValidForm(WidgetTester tester) async {
  for (final entry in const {
    'firstName': 'Jordan',
    'middleName': '',
    'lastName': 'Santos',
    'contact': '09171234567',
    'addressUnit': 'Block 5 Lot 10',
    'addressStreet': 'Sample Street',
    'addressZipCode': '3020',
    'email': 'preview@example.test',
    'password': 'Password1',
    'confirmPassword': 'Password1',
  }.entries) {
    await _enter(tester, entry.key, entry.value);
  }
  await _pickDateOfBirth(tester);
  await _select(tester, 'gender', 'Female');
  await _select(tester, 'addressProvince', 'Bulacan');
  await _select(tester, 'addressCityMunicipality', 'Meycauayan');
  await _select(tester, 'addressBarangay', 'Banga');

  final terms = find.byKey(const ValueKey('registration-terms-checkbox'));
  await tester.ensureVisible(terms);
  await tester.tap(terms);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows registration form and keeps middle name optional', (
    tester,
  ) async {
    _setViewport(tester, const Size(1440, 1000));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('First Name *'), findsOneWidget);
    expect(find.text('Middle Name'), findsOneWidget);
    expect(find.text('Last Name *'), findsOneWidget);
    expect(find.text('Date of Birth *'), findsOneWidget);
    expect(find.text('Age'), findsOneWidget);
    expect(find.text('Gender *'), findsOneWidget);
    expect(find.text('Terms and Conditions'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final submit = find.byKey(const ValueKey('registration-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Please enter your first name.'),
      findsOneWidget,
    );
    expect(find.textContaining('Please enter your last name.'), findsOneWidget);
    expect(find.textContaining('middle name'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'validates name lengths and updates age from selected birth date',
    (tester) async {
      _setViewport(tester, const Size(390, 844));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_testApp());
      await _enter(tester, 'firstName', 'J');
      await _enter(tester, 'middleName', 'M');
      await _enter(tester, 'lastName', 'S');
      final selectedDate = await _pickDateOfBirth(tester);

      final submit = find.byKey(const ValueKey('registration-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(
        find.text('Please enter a valid your first name.'),
        findsOneWidget,
      );
      expect(
        find.text('Please enter a valid middle name or leave it blank.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('registration-age')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('registration-age')))
            .controller!
            .text,
        _ageFor(selectedDate, DateTime.now()).toString(),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'date of birth opens date picker, blocks typing, and updates age',
    (tester) async {
      _setViewport(tester, const Size(1440, 1000));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_testApp());

      final dateField = tester.widget<TextField>(
        find.byKey(const ValueKey('registration-dateOfBirth')),
      );
      expect(dateField.readOnly, isTrue);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('registration-age')))
            .readOnly,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('registration-date-picker')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('registration-dateOfBirth')));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarDatePicker), findsOneWidget);
      final selectedDate = await _pickDateOfBirth(tester, openPicker: false);
      expect(find.byType(CalendarDatePicker), findsNothing);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('registration-dateOfBirth')),
            )
            .controller!
            .text,
        '${selectedDate.year.toString().padLeft(4, '0')}-'
        '${selectedDate.month.toString().padLeft(2, '0')}-'
        '${selectedDate.day.toString().padLeft(2, '0')}',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('registration-age')))
            .controller!
            .text,
        _ageFor(selectedDate, DateTime.now()).toString(),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('date picker restricts birth dates to 1926 through 2016', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    await tester.ensureVisible(
      find.byKey(const ValueKey('registration-date-picker')),
    );
    await tester.tap(find.byKey(const ValueKey('registration-date-picker')));
    await tester.pumpAndSettle();
    final picker = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(DateUtils.dateOnly(picker.firstDate), DateTime(1926, 1, 1));
    expect(DateUtils.dateOnly(picker.lastDate), DateTime(2016, 12, 31));

    final selectedDates = <DateTime>[];
    picker.onDateChanged(DateTime(1926, 1, 1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    selectedDates.add(
      DateTime.parse(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('registration-dateOfBirth')),
            )
            .controller!
            .text,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('registration-date-picker')));
    await tester.pumpAndSettle();
    final latestPicker = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    latestPicker.onDateChanged(DateTime(2016, 12, 31));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    selectedDates.add(
      DateTime.parse(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('registration-dateOfBirth')),
            )
            .controller!
            .text,
      ),
    );

    expect(selectedDates, [DateTime(1926, 1, 1), DateTime(2016, 12, 31)]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('date picker initial date stays within allowed year range', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());
    final pickerButton = find.byKey(const ValueKey('registration-date-picker'));
    await tester.ensureVisible(pickerButton);
    await tester.tap(pickerButton);
    await tester.pumpAndSettle();

    final picker = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(picker.initialDate, isNotNull);
    expect(
      !picker.initialDate!.isBefore(DateTime(1926, 1, 1)) &&
          !picker.initialDate!.isAfter(DateTime(2016, 12, 31)),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('registration rejects birth dates outside the allowed years', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    final dateField = tester.widget<TextField>(
      find.byKey(const ValueKey('registration-dateOfBirth')),
    );
    dateField.controller!.text = '1925-12-31';
    final submit = find.byKey(const ValueKey('registration-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(
      find.text('Date of birth must be between 1926 and 2016.'),
      findsOneWidget,
    );

    dateField.controller!.text = '2017-01-01';
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(
      find.text('Date of birth must be between 1926 and 2016.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('gender and address selectors cascade and validate', (
    tester,
  ) async {
    _setViewport(tester, const Size(850, 900));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    final city = find.byKey(
      const ValueKey('registration-addressCityMunicipality'),
    );
    expect(
      tester.widget<DropdownButtonFormField<String>>(city).onChanged,
      isNull,
    );
    await _select(tester, 'addressProvince', 'Bulacan');
    expect(
      tester.widget<DropdownButtonFormField<String>>(city).onChanged,
      isNotNull,
    );
    await _select(tester, 'addressCityMunicipality', 'Meycauayan');
    await _select(tester, 'addressBarangay', 'Banga');
    await _select(tester, 'gender', 'Female');
    expect(tester.takeException(), isNull);
  });

  testWidgets('validates contact, email, ZIP, password, and confirmation', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());
    await _enter(tester, 'firstName', 'Jordan');
    await _enter(tester, 'lastName', 'Santos');
    await _enter(tester, 'contact', '123');
    await _enter(tester, 'addressUnit', 'Unit 1');
    await _enter(tester, 'addressStreet', 'Sample Street');
    await _enter(tester, 'addressZipCode', '123');
    await _enter(tester, 'email', 'not-an-email');
    await _enter(tester, 'password', 'short');
    await _enter(tester, 'confirmPassword', 'different');

    final submit = find.byKey(const ValueKey('registration-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(
      find.text('Please enter a valid Philippine mobile number.'),
      findsOneWidget,
    );
    expect(find.text('ZIP code must be exactly 4 digits.'), findsOneWidget);
    expect(find.text('Please enter a valid email address.'), findsOneWidget);
    expect(
      find.text('Password must contain at least 8 characters.'),
      findsOneWidget,
    );
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(
      find.text('You must agree to the Terms and Conditions.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('terms dialog scrolls and password controls update the meter', (
    tester,
  ) async {
    _setViewport(tester, const Size(320, 720));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    final password = find.byKey(const ValueKey('registration-password-toggle'));
    expect(password, findsOneWidget);
    await tester.ensureVisible(password);
    await tester.tap(password);
    await tester.pumpAndSettle();
    await _enter(tester, 'password', 'Password1!');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('registration-password')), findsOneWidget);
    expect(find.byKey(const ValueKey('password-strength')), findsOneWidget);
    expect(find.byKey(const ValueKey('strength-bar-3')), findsOneWidget);

    final termsLink = find.byKey(const ValueKey('registration-terms-link'));
    await tester.ensureVisible(termsLink);
    await tester.tap(termsLink);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('terms-scroll')), findsOneWidget);
    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('terms-scroll')),
      matching: find.byType(Scrollable),
    );
    expect(
      tester.state<ScrollableState>(scrollable.first).position.maxScrollExtent,
      greaterThan(0),
    );
    expect(find.text('Terms and Conditions'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('valid submission opens verification with the entered email', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());
    await _fillValidForm(tester);

    final submit = find.byKey(const ValueKey('registration-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(VerifyEmailPage), findsOneWidget);
    final description = tester.widget<Text>(
      find.byKey(const ValueKey('verify-email-description')),
    );
    expect(
      (description.textSpan! as TextSpan).toPlainText(),
      contains('preview@example.test'),
    );
    expect(
      find.text(
        'LOCAL PREVIEW ONLY: Enter any six-digit code. No account is created and no verification email is sent.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('API registration is blocked and never sends the form', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var requests = 0;
    final client = ApiClient(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
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
        child: MaterialApp(home: const RegistrationPage()),
      ),
    );
    await _fillValidForm(tester);

    final submit = find.byKey(const ValueKey('registration-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(requests, 0);
    expect(find.byType(RegistrationPage), findsOneWidget);
    expect(
      find.textContaining('No registration request was sent.'),
      findsOneWidget,
    );
    expect(find.byType(VerifyEmailPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'verification returns to Registration, then Sign in returns to Login',
    (tester) async {
      _setViewport(tester, const Size(600, 900));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_testApp());
      await _fillValidForm(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('registration-submit')),
      );
      await tester.tap(find.byKey(const ValueKey('registration-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('verify-back-registration')));
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);
      expect(find.byType(RegistrationPage), findsOneWidget);

      final login = find.byKey(const ValueKey('registration-login-link'));
      await tester.ensureVisible(login);
      await tester.tap(login);
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in const [
    Size(1440, 1000),
    Size(850, 900),
    Size(600, 900),
    Size(480, 844),
    Size(390, 844),
    Size(320, 720),
  ]) {
    testWidgets('has no layout overflow at ${size.width}x${size.height}', (
      tester,
    ) async {
      _setViewport(tester, size);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_testApp());
      expect(tester.takeException(), isNull);
    });
  }
}
