import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_portal_flutter/app/theme.dart';
import 'package:patient_portal_flutter/features/profile/edit_profile_page.dart';

Widget _testApp() =>
    MaterialApp(theme: PatientPortalTheme.light, home: const EditProfilePage());

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
}

int _ageOn(DateTime birthDate, DateTime today) {
  var age = today.year - birthDate.year;
  if (today.month < birthDate.month ||
      (today.month == birthDate.month && today.day < birthDate.day)) {
    age--;
  }
  return age;
}

Future<void> _fillRequiredForm(WidgetTester tester) async {
  const values = <String, String>{
    'firstName': 'Jamie',
    'lastName': 'Maningas',
    'dateOfBirth': '1996-04-18',
    'contact': '0917 123 4567',
    'addressUnit': 'Unit 2',
    'addressStreet': 'Clinic Road',
    'addressZipCode': '3019',
  };
  for (final entry in values.entries) {
    await tester.enterText(
      find.byKey(ValueKey('edit-profile-${entry.key}')),
      entry.value,
    );
  }
  await tester.tap(find.byKey(const ValueKey('edit-profile-gender')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Female').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('edit-profile-province')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Metro Manila').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('edit-profile-city')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Quezon City').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('edit-profile-barangay')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Commonwealth').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows initial demo values and profile sections', (tester) async {
    _setViewport(tester, const Size(1440, 1000));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('PREVIEW ONLY'), findsOneWidget);
    expect(find.text('Personal Information'), findsOneWidget);
    expect(find.text('Contact Information'), findsOneWidget);
    expect(find.text('Address'), findsOneWidget);
    expect(find.text('Age (calculated; read-only)'), findsOneWidget);
    expect(
      find.text(
        'Preview only — changes are not saved to the clinic or a patient record.',
      ),
      findsOneWidget,
    );
    expect(find.text('Email Address'), findsNothing);
    expect(find.byKey(const ValueKey('edit-profile-email')), findsNothing);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('edit-profile-firstName')),
          )
          .controller!
          .text,
      'James',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('edit-profile-lastName')),
          )
          .controller!
          .text,
      'Maningas',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('validates required fields and malformed formats', (
    tester,
  ) async {
    _setViewport(tester, const Size(600, 900));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    await tester.enterText(
      find.byKey(const ValueKey('edit-profile-firstName')),
      '',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-profile-middleName')),
      'M',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('edit-profile-save')));
    await tester.tap(find.byKey(const ValueKey('edit-profile-save')));
    await tester.pumpAndSettle();
    expect(find.text('Please enter your first name.'), findsOneWidget);
    expect(
      find.text('Enter at least 2 characters or leave this blank.'),
      findsOneWidget,
    );
    expect(find.text('Please select gender.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('edit-profile-firstName')),
      'A',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-profile-middleName')),
      '',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-profile-contact')),
      '123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-profile-addressZipCode')),
      '12',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('edit-profile-save')));
    await tester.tap(find.byKey(const ValueKey('edit-profile-save')));
    await tester.pumpAndSettle();
    expect(find.text('Please enter at least 2 characters.'), findsOneWidget);
    expect(
      find.text('Please enter a valid Philippine mobile number.'),
      findsOneWidget,
    );
    expect(find.text('ZIP code must be exactly 4 digits.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calculates age and rejects invalid date and age', (
    tester,
  ) async {
    _setViewport(tester, const Size(600, 900));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    final dateOfBirth = tester.widget<TextFormField>(
      find.byKey(const ValueKey('edit-profile-dateOfBirth')),
    );
    final age = tester.widget<TextFormField>(
      find.byKey(const ValueKey('edit-profile-age')),
    );
    expect(dateOfBirth.controller!.text, '1996-04-18');
    expect(age.controller!.text, isNotEmpty);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('edit-profile-age')),
              matching: find.byType(EditableText),
            ),
          )
          .readOnly,
      isTrue,
    );
    expect(find.text('Age (calculated; read-only)'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('edit-profile-dateOfBirth')),
      '2000-01-01',
    );
    expect(
      age.controller!.text,
      _ageOn(DateTime(2000, 1, 1), DateTime.now()).toString(),
    );
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('edit-profile-age')),
              matching: find.byType(EditableText),
            ),
          )
          .readOnly,
      isTrue,
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-profile-dateOfBirth')),
      '2099-01-01',
    );
    expect(age.controller!.text, isNotEmpty);
    await tester.ensureVisible(find.byKey(const ValueKey('edit-profile-save')));
    await tester.tap(find.byKey(const ValueKey('edit-profile-save')));
    await tester.pumpAndSettle();
    expect(find.text('Date of birth cannot be in the future.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('edit-profile-dateOfBirth')),
      '2020-02-31',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('edit-profile-save')));
    await tester.tap(find.byKey(const ValueKey('edit-profile-save')));
    await tester.pumpAndSettle();
    expect(
      find.text('Please enter a valid date (YYYY-MM-DD).'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('address dropdowns depend on parent selections', (tester) async {
    _setViewport(tester, const Size(600, 900));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    final cityBefore = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('edit-profile-city')),
    );
    expect(cityBefore.onChanged, isNull);
    await tester.ensureVisible(
      find.byKey(const ValueKey('edit-profile-province')),
    );
    await tester.tap(find.byKey(const ValueKey('edit-profile-province')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Metro Manila').last);
    await tester.pumpAndSettle();
    final cityEnabled = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('edit-profile-city')),
    );
    expect(cityEnabled.onChanged, isNotNull);
    await tester.ensureVisible(find.byKey(const ValueKey('edit-profile-city')));
    await tester.tap(find.byKey(const ValueKey('edit-profile-city')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quezon City').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('edit-profile-barangay')),
    );
    await tester.tap(find.byKey(const ValueKey('edit-profile-barangay')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Commonwealth').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('edit-profile-province')),
    );
    await tester.tap(find.byKey(const ValueKey('edit-profile-province')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rizal').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('edit-profile-city')),
          )
          .initialValue,
      isNull,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('edit-profile-barangay')),
          )
          .initialValue,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('valid save displays local preview confirmation only', (
    tester,
  ) async {
    _setViewport(tester, const Size(1440, 1200));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());
    await _fillRequiredForm(tester);
    await tester.tap(find.byKey(const ValueKey('edit-profile-save')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'LOCAL PREVIEW ONLY: Changes are not saved to a patient record.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Preview only — changes are not saved to the clinic or a patient record.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel restores initial demo values and shows local notice', (
    tester,
  ) async {
    _setViewport(tester, const Size(600, 900));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_testApp());

    await tester.enterText(
      find.byKey(const ValueKey('edit-profile-firstName')),
      'Changed',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('edit-profile-cancel')),
    );
    await tester.tap(find.byKey(const ValueKey('edit-profile-cancel')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('edit-profile-firstName')),
          )
          .controller!
          .text,
      'James',
    );
    expect(
      find.text('Local preview: unsaved edits were discarded.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in const [
    Size(1440, 900),
    Size(600, 900),
    Size(390, 700),
    Size(320, 480),
  ]) {
    testWidgets(
      'scrolls without overflow at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        _setViewport(tester, size);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(_testApp());

        final scrollable = find.byKey(const ValueKey('edit-profile-scroll'));
        expect(scrollable, findsOneWidget);
        expect(find.byKey(const ValueKey('edit-profile-save')), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const ValueKey('edit-profile-save')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
