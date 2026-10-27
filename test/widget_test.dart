import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_portal_flutter/app/app.dart';
import 'package:patient_portal_flutter/app/theme.dart';
import 'package:patient_portal_flutter/core/network/api_failure.dart';
import 'package:patient_portal_flutter/features/appointment_history/appointment_history_page.dart';
import 'package:patient_portal_flutter/features/appointments/booking_page.dart';
import 'package:patient_portal_flutter/features/auth/application/patient_auth_controller.dart';
import 'package:patient_portal_flutter/features/auth/application/patient_auth_scope.dart';
import 'package:patient_portal_flutter/features/auth/application/patient_auth_setup.dart';
import 'package:patient_portal_flutter/features/frames_catalog/catalog_frame.dart';
import 'package:patient_portal_flutter/features/frames_catalog/frames_catalog_page.dart';
import 'package:patient_portal_flutter/features/frames_catalog/frames_catalog_repository.dart';
import 'package:patient_portal_flutter/features/profile/profile_page.dart';
import 'package:patient_portal_flutter/features/support_center/support_center_page.dart';
import 'package:patient_portal_flutter/features/transaction_history/transaction_history_page.dart';

void main() {
  testWidgets('API catalog shows loading and then real frame data', (
    tester,
  ) async {
    final controller = createPatientAuthController(mode: 'demo');
    addTearDown(controller.dispose);
    final request = Completer<List<CatalogFrame>>();
    final repository = _FakeFramesCatalogRepository(
      onGetFrames: () => request.future,
    );

    await tester.pumpWidget(_catalogApp(controller, repository));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(repository.calls, 1);

    request.complete([_apiFrame()]);
    await tester.pumpAndSettle();

    expect(find.text('Avery API Frame'), findsOneWidget);
    expect(find.text('API Brand • Eyeglasses'), findsOneWidget);
    expect(find.text('₱2,450.00'), findsOneWidget);
    expect(find.text('DEMO DATA'), findsNothing);
    expect(find.text('Avery Classic'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('API catalog distinguishes an empty catalog', (tester) async {
    final controller = createPatientAuthController(mode: 'demo');
    addTearDown(controller.dispose);
    final repository = _FakeFramesCatalogRepository(frames: const []);

    await tester.pumpWidget(_catalogApp(controller, repository));
    await tester.pumpAndSettle();

    expect(find.text('0 frames'), findsOneWidget);
    expect(find.text('No frames currently available'), findsOneWidget);
    expect(find.text('No frames found'), findsNothing);
  });

  testWidgets('API catalog displays a generic error and supports retry', (
    tester,
  ) async {
    final controller = createPatientAuthController(mode: 'demo');
    addTearDown(controller.dispose);
    var shouldFail = true;
    final repository = _FakeFramesCatalogRepository(
      onGetFrames: () async {
        if (shouldFail) {
          shouldFail = false;
          throw const ApiFailure(
            kind: ApiFailureKind.http,
            message: 'private server response',
          );
        }
        return [_apiFrame()];
      },
    );

    await tester.pumpWidget(_catalogApp(controller, repository));
    await tester.pumpAndSettle();

    expect(find.text('Unable to load frames'), findsOneWidget);
    expect(find.text('private server response'), findsNothing);
    expect(find.text('Avery Classic'), findsNothing);

    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.text('Avery API Frame'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('API catalog shows a neutral fallback for missing images', (
    tester,
  ) async {
    final controller = createPatientAuthController(mode: 'demo');
    addTearDown(controller.dispose);
    final repository = _FakeFramesCatalogRepository(frames: [_apiFrame()]);

    await tester.pumpWidget(_catalogApp(controller, repository));
    await tester.pumpAndSettle();

    expect(find.text('IMAGE UNAVAILABLE'), findsOneWidget);
    expect(find.text('DEMO IMAGE'), findsNothing);
  });

  testWidgets('API catalog shows a fallback when a frame image fails', (
    tester,
  ) async {
    final controller = createPatientAuthController(mode: 'demo');
    addTearDown(controller.dispose);
    final repository = _FakeFramesCatalogRepository(
      frames: [
        _apiFrame(
          imageUrl: Uri.parse('https://images.example.test/broken.png'),
        ),
      ],
    );

    await tester.pumpWidget(_catalogApp(controller, repository));
    await tester.pumpAndSettle();

    expect(find.text('Image unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('profile age calculation respects the birthday date', () {
    expect(
      calculatePatientAge(
        DateTime(1996, 10, 26),
        today: DateTime(2026, 10, 25),
      ),
      29,
    );
    expect(
      calculatePatientAge(
        DateTime(1996, 10, 24),
        today: DateTime(2026, 10, 25),
      ),
      30,
    );
    expect(
      calculatePatientAge(DateTime(2027, 1, 1), today: DateTime(2026, 10, 25)),
      isNull,
    );
  });

  testWidgets('shows dashboard content and patient portal navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PatientPortalApp());

    expect(find.text('Welcome back, James'), findsOneWidget);
    expect(find.text('Upcoming Appointment'), findsOneWidget);
    expect(find.text('Patient Information'), findsOneWidget);
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Support Center'), findsOneWidget);
    expect(find.text('GVC-1601'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('My Appointments quick action focuses the appointments section', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PatientPortalApp());
    final quickAction = find.text('My Appointments');
    await tester.ensureVisible(quickAction);
    await tester.tap(quickAction);
    await tester.pumpAndSettle();

    expect(find.byType(BookingPage), findsOneWidget);
    expect(find.byType(AppointmentHistoryPage), findsNothing);
    expect(find.text('Schedule a visit'), findsOneWidget);
    expect(find.text('My appointments'), findsOneWidget);
    final bookingScrollView = find.descendant(
      of: find.byType(BookingPage),
      matching: find.byType(SingleChildScrollView),
    );
    final bookingViewport = find
        .descendant(of: bookingScrollView, matching: find.byType(Scrollable))
        .first;
    final sectionRect = tester.getRect(
      find.byKey(const ValueKey('my-appointments-card')),
    );
    final viewportRect = tester.getRect(bookingViewport);
    expect(sectionRect.top, greaterThanOrEqualTo(viewportRect.top));
    expect(sectionRect.top, lessThan(viewportRect.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('support center is reachable from portal navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PatientPortalApp());
    await tester.tap(find.text('Support Center'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Manage your support requests and communicate with our clinic team.',
      ),
      findsOneWidget,
    );
    expect(find.text('My Support Tickets'), findsOneWidget);
    expect(find.text('DEMO DATA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'support ticket opens conversation and messages preview locally',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: PatientPortalTheme.light,
          home: const Scaffold(
            body: SupportCenterPage(key: ValueKey('support-with-tickets')),
          ),
        ),
      );

      await tester.tap(find.text('Question about my appointment'));
      await tester.pumpAndSettle();
      expect(find.text('In Progress · Medium priority'), findsOneWidget);
      expect(
        find.text('We are checking the appointment details for you.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'Demo reply');
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(find.text('Demo reply'), findsOneWidget);
      expect(
        find.text('Message preview added locally. Nothing was sent.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('new support ticket validates and adds a local preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: const Scaffold(body: SupportCenterPage()),
      ),
    );

    await tester.tap(find.text('New Ticket'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Ticket'));
    await tester.pumpAndSettle();
    expect(find.text('Select a category'), findsWidgets);
    expect(find.text('Enter a subject'), findsOneWidget);
    expect(find.text('Enter a description'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appointment').last);
    await tester.enterText(find.byType(TextFormField).at(0), 'Demo subject');
    await tester.enterText(find.byType(TextFormField).at(1), 'Demo details');
    await tester.tap(find.text('Submit Ticket'));
    await tester.pumpAndSettle();

    expect(find.text('Demo subject'), findsWidgets);
    expect(
      find.text('Demo ticket preview added locally. Nothing was submitted.'),
      findsOneWidget,
    );
    expect(find.textContaining('DEMO-103'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new ticket dialog closes from X and Cancel on narrow screens', (
    tester,
  ) async {
    for (final size in [const Size(390, 844), const Size(320, 720)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: PatientPortalTheme.light,
          home: const Scaffold(body: SupportCenterPage()),
        ),
      );

      await tester.tap(find.text('New Ticket'));
      await tester.pumpAndSettle();
      expect(find.text('Create a Support Ticket'), findsOneWidget);
      expect(find.text('Select a category'), findsOneWidget);
      expect(
        tester.getRect(find.byType(Dialog)).right,
        lessThanOrEqualTo(size.width),
      );
      expect(tester.getRect(find.byType(Dialog)).left, greaterThanOrEqualTo(0));
      await tester.tap(find.byTooltip('Close form'));
      await tester.pumpAndSettle();
      expect(find.text('Create a Support Ticket'), findsNothing);

      await tester.tap(find.text('New Ticket'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(find.text('Create a Support Ticket'), findsNothing);
      expect(find.text('DEMO-103'), findsNothing);
      expect(tester.takeException(), isNull);
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('support center empty inbox and cancellation remain previews', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: Scaffold(body: SupportCenterPage(tickets: const [])),
      ),
    );
    expect(
      find.text(
        'You have no support tickets yet. Create a new ticket to get started.',
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: const Scaffold(
          body: SupportCenterPage(key: ValueKey('support-with-tickets')),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Frames catalog question'));
    await tester.tap(find.text('Cancel Ticket').first);
    await tester.pumpAndSettle();
    expect(find.text('Demo action only'), findsOneWidget);
    expect(find.textContaining('no ticket was changed.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('support conversation switches to inbox on narrow mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: const Scaffold(body: SupportCenterPage()),
      ),
    );
    await tester.ensureVisible(find.text('Frames catalog question'));
    await tester.tap(find.text('Frames catalog question'));
    await tester.pumpAndSettle();
    expect(find.text('← Back to Tickets'), findsOneWidget);
    expect(find.textContaining('Waiting for Super Admin'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('← Back to Tickets'));
    await tester.pumpAndSettle();
    expect(find.text('My Support Tickets'), findsOneWidget);
    expect(find.text('Frames catalog question'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile destination shows its read-only demo information', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PatientPortalApp());
    await tester.tap(find.text('My Profile').first);
    await tester.pumpAndSettle();

    expect(
      find.text('View your personal information and clinic account details.'),
      findsOneWidget,
    );
    expect(find.text('James Maningas'), findsWidgets);
    expect(find.text('Personal Information'), findsOneWidget);
    expect(find.text('Patient Identification'), findsOneWidget);
    expect(find.text('Address Information'), findsOneWidget);
    expect(find.text('Contact Information'), findsOneWidget);
    expect(find.text('Account Information'), findsOneWidget);
    expect(find.text('Your patient information is protected'), findsOneWidget);
    expect(find.text('DEMO DATA'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-edit-action')), findsOneWidget);

    await tester.tap(find.byTooltip('Switch to dark theme'));
    await tester.pumpAndSettle();
    expect(find.text('Account Information'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile Edit Profile action opens form and Cancel returns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PatientPortalApp());
    await tester.tap(find.text('My Profile').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-edit-action')));
    await tester.pumpAndSettle();

    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('PREVIEW ONLY'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('edit-profile-cancel')),
    );
    await tester.tap(find.byKey(const ValueKey('edit-profile-cancel')));
    await tester.pumpAndSettle();

    expect(
      find.text('View your personal information and clinic account details.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('profile-edit-action')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile screen stacks without overflow on narrow mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PatientPortalApp());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Profile').last);
    await tester.pumpAndSettle();

    expect(find.text('Personal Information'), findsOneWidget);
    expect(find.text('Patient Identification'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('appointment history shows source-based filters and records', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: Scaffold(
          body: AppointmentHistoryPage(now: DateTime(2026, 10, 25, 12)),
        ),
      ),
    );

    expect(find.text('Appointment History'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Past'), findsOneWidget);
    expect(find.text('Showing 1-5 of 12'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('DEMO DATA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('appointment filters and fixed-size pagination work locally', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: Scaffold(
          body: AppointmentHistoryPage(now: DateTime(2026, 10, 25, 12)),
        ),
      ),
    );

    await tester.tap(find.text('2').first);
    await tester.pumpAndSettle();
    expect(find.text('Showing 6-10 of 12'), findsOneWidget);

    await tester.tap(find.text('Upcoming'));
    await tester.pumpAndSettle();
    expect(find.text('Showing 1-2 of 2'), findsOneWidget);
    expect(find.text('No appointment records found'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('appointment details are presentation-only', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: Scaffold(
          body: AppointmentHistoryPage(now: DateTime(2026, 10, 25, 12)),
        ),
      ),
    );

    await tester.tap(
      find
          .ancestor(
            of: find.text('Comprehensive Eye Examination').first,
            matching: find.byType(InkWell),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('APPOINTMENT ID'), findsOneWidget);
    expect(find.text('DEMO-2026-014'), findsOneWidget);
    expect(find.text('Close details'), findsOneWidget);

    await tester.tap(find.text('Close details'));
    await tester.pumpAndSettle();
    expect(find.text('APPOINTMENT ID'), findsNothing);
  });

  testWidgets('appointment history mobile layout has no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: Scaffold(
          body: AppointmentHistoryPage(now: DateTime(2026, 10, 25, 12)),
        ),
      ),
    );

    expect(find.text('Appointment History'), findsOneWidget);
    expect(find.text('Comprehensive Eye Examination'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('appointment history shows the source empty state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: Scaffold(body: AppointmentHistoryPage(now: DateTime(2030, 1, 1))),
      ),
    );
    await tester.tap(find.text('Upcoming'));
    await tester.pumpAndSettle();

    expect(find.text('No appointment records found'), findsOneWidget);
    expect(find.text('Showing 1-5 of 12'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading and error states show patient-safe details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: const Scaffold(
          body: AppointmentHistoryPage(
            presentationState: AppointmentHistoryPresentationState.loading,
          ),
        ),
      ),
    );
    expect(find.text('Loading appointment history...'), findsOneWidget);
    expect(find.text('Loading demo appointment records...'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: const Scaffold(
          body: AppointmentHistoryPage(
            presentationState: AppointmentHistoryPresentationState.error,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Your appointment history could not be loaded right now.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Your appointment history could not be loaded. Please try again.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sidebar navigation opens Appointment History and preserves '
      'Dashboard and Profile destinations', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PatientPortalApp());
    await tester.tap(find.text('Appointment History').first);
    await tester.pumpAndSettle();
    expect(find.text('My appointment records'), findsOneWidget);

    await tester.tap(find.text('My Profile').first);
    await tester.pumpAndSettle();
    expect(find.text('Your patient information is protected'), findsOneWidget);

    await tester.tap(find.text('Dashboard').first);
    await tester.pumpAndSettle();
    expect(find.text('Welcome back, James'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transaction history shows source-based billing fields', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: const Scaffold(body: TransactionHistoryPage()),
      ),
    );

    expect(find.text('Transaction History'), findsOneWidget);
    expect(find.text('Billing records'), findsOneWidget);
    expect(
      find.text(
        'Review your billing and payment activity for clinic services.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Ref: DEMO-TXN-2026-014'), findsOneWidget);
    expect(find.text('Optical frame × 1'), findsWidgets);
    expect(find.text('Subtotal'), findsWidgets);
    expect(find.text('Senior Citizen Discount (20%)'), findsOneWidget);
    expect(find.text('VAT'), findsWidgets);
    expect(find.text('Total'), findsWidgets);
    expect(find.text('₱3,718.40'), findsWidgets);
    expect(find.text('Paid'), findsWidgets);
    expect(find.text('DEMO DATA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transaction history paginates ten newest-first records', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: const Scaffold(body: TransactionHistoryPage()),
      ),
    );
    expect(find.text('Showing 1-10 of 12'), findsOneWidget);
    expect(find.textContaining('Ref: DEMO-TXN-2026-014'), findsOneWidget);
    expect(find.textContaining('Ref: DEMO-TXN-2026-003'), findsNothing);

    await tester.tap(find.text('2').first);
    await tester.pumpAndSettle();
    expect(find.text('Showing 11-12 of 12'), findsOneWidget);
    expect(find.textContaining('Ref: DEMO-TXN-2026-003'), findsOneWidget);
    expect(find.textContaining('Ref: DEMO-TXN-2026-014'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transaction history renders empty and loading/error states', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: const Scaffold(body: TransactionHistoryPage(transactions: [])),
      ),
    );
    expect(find.text('No transaction records available'), findsOneWidget);
    expect(
      find.text(
        'There are no payment or billing records currently linked to this patient account.',
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: const Scaffold(
          body: TransactionHistoryPage(
            presentationState: TransactionHistoryPresentationState.loading,
          ),
        ),
      ),
    );
    expect(find.text('Loading transaction history...'), findsOneWidget);
    expect(find.text('Loading demo transaction records...'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: const Scaffold(
          body: TransactionHistoryPage(
            presentationState: TransactionHistoryPresentationState.error,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load transaction history'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transaction history mobile cards fit narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: const Scaffold(body: TransactionHistoryPage()),
      ),
    );

    expect(find.text('Transaction History'), findsOneWidget);
    expect(find.text('Prescription Eyeglasses'), findsWidgets);
    expect(find.text('₱3,718.40'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transaction history navigation preserves existing screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PatientPortalApp());
    await tester.tap(find.text('Transaction History').first);
    await tester.pumpAndSettle();
    expect(find.text('Billing records'), findsOneWidget);

    await tester.tap(find.text('Appointment History').first);
    await tester.pumpAndSettle();
    expect(find.text('My appointment records'), findsOneWidget);

    await tester.tap(find.text('My Profile').first);
    await tester.pumpAndSettle();
    expect(find.text('Your patient information is protected'), findsOneWidget);

    await tester.tap(find.text('Dashboard').first);
    await tester.pumpAndSettle();
    expect(find.text('Welcome back, James'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'frames catalog shows demo content and source-supported filters',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: PatientPortalTheme.light,
          home: const Scaffold(body: FramesCatalogPage()),
        ),
      );

      expect(find.text('Frames Catalog'), findsOneWidget);
      expect(find.text('Find a Frame'), findsOneWidget);
      expect(find.text('Our Collection'), findsOneWidget);
      expect(find.text('DEMO DATA'), findsOneWidget);
      expect(find.text('DEMO IMAGE'), findsWidgets);
      expect(find.text('Avery Classic'), findsOneWidget);
      expect(find.text('₱2,450.00'), findsOneWidget);
      expect(find.text('Available'), findsWidgets);
      expect(find.text('Try On 3D'), findsWidgets);

      await tester.enterText(find.byType(TextField), 'Northline');
      await tester.pumpAndSettle();
      expect(find.text('3 frames'), findsOneWidget);
      expect(find.text('Avery Classic'), findsNothing);
      expect(find.text('Harper Round'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'nothing matches');
      await tester.pumpAndSettle();
      expect(find.text('No frames found'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'frames catalog category, stock, and price controls work locally',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: PatientPortalTheme.light,
          home: const Scaffold(body: FramesCatalogPage()),
        ),
      );

      await tester.tap(find.text('Eyeglasses').first);
      await tester.pumpAndSettle();
      expect(find.text('6 frames'), findsOneWidget);

      await tester.tap(find.text('All Frames'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Low Stock').last);
      await tester.pumpAndSettle();
      expect(find.text('2 frames'), findsOneWidget);
      expect(find.text('Harper Round'), findsOneWidget);
      expect(find.text('Ridge Sport'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Price: High to Low'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('demo Try-On never opens the production website', (tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: const Scaffold(body: FramesCatalogPage()),
      ),
    );

    await tester.ensureVisible(find.text('Try On 3D').first);
    await tester.tap(find.text('Try On 3D').first);
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'Demo frames cannot be opened on the clinic website.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('frames catalog navigation preserves other portal destinations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PatientPortalApp());
    await tester.tap(find.text('Frames Catalog').first);
    await tester.pumpAndSettle();
    expect(find.text('Our Collection'), findsOneWidget);

    await tester.tap(find.text('Appointment History').first);
    await tester.pumpAndSettle();
    expect(find.text('My appointment records'), findsOneWidget);

    await tester.tap(find.text('Frames Catalog').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transaction History').first);
    await tester.pumpAndSettle();
    expect(find.text('Billing records'), findsOneWidget);

    await tester.tap(find.text('Dashboard').first);
    await tester.pumpAndSettle();
    expect(find.text('Welcome back, James'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('frames catalog fits narrow mobile layout without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.dark,
        home: const Scaffold(body: FramesCatalogPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Frames Catalog'), findsOneWidget);
    expect(find.text('Find a Frame'), findsOneWidget);
    expect(tester.getSize(find.byType(Scaffold)).width, 390);
    expect(tester.takeException(), isNull);
  });

  testWidgets('booking screen shows local demo schedule and source fields', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: Scaffold(body: BookingPage(now: DateTime(2026, 10, 26, 7))),
      ),
    );

    expect(find.text('Schedule a visit'), findsOneWidget);
    expect(find.textContaining('DEMO DATA'), findsNWidgets(2));
    expect(find.text('Select a date'), findsNWidgets(2));
    expect(find.text('Appointment details'), findsOneWidget);
    expect(find.text('Purpose of visit'), findsOneWidget);
    expect(find.text('30-minute intervals'), findsOneWidget);
    expect(find.text('Book up to 1 year ahead'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('booking-submit')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('booking date, time, purpose, and required fields work locally', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: Scaffold(body: BookingPage(now: DateTime(2026, 10, 26, 7))),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('booking-date-2026-10-27')));
    await tester.pumpAndSettle();
    expect(find.text('October 27, 2026'), findsOneWidget);

    final reservedSlot = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('booking-time-09:00:00')),
    );
    expect(reservedSlot.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('booking-time-08:00:00')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('booking-submit')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('booking-purpose')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eye Examination').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('booking-submit')))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('booking enforces Sunday, closures, cutoff, and date range', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: Scaffold(body: BookingPage(now: DateTime(2026, 10, 26, 7, 50))),
      ),
    );

    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('booking-date-2026-11-01')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('booking-date-2026-11-05')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('booking-date-2026-10-26')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('booking-time-08:00:00')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('booking-time-08:30:00')),
          )
          .onPressed,
      isNotNull,
    );

    for (var month = 0; month < 12; month++) {
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
    }
    expect(find.text('October 2027'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('booking-date-2027-10-26')),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('booking-date-2027-10-27')),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('booking confirmation is a demo preview, not a submission', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: Scaffold(body: BookingPage(now: DateTime(2026, 10, 26, 7))),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('booking-date-2026-10-27')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('booking-time-08:00:00')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('booking-purpose')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eye Examination').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('booking-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Review appointment request'), findsOneWidget);
    expect(
      find.text('DEMO DATA · This is a local preview, not a live booking.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Preview only'));
    await tester.pumpAndSettle();
    expect(find.text('Demo confirmation preview'), findsOneWidget);
    expect(
      find.text(
        'No appointment was submitted, created, or reserved. '
        'Availability shown here is local demo data only.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'booking navigation preserves appointment history and dashboard',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const PatientPortalApp());
      await tester.tap(find.text('Appointments').first);
      await tester.pumpAndSettle();
      expect(find.text('Schedule a visit'), findsOneWidget);

      await tester.tap(find.text('Appointment History').first);
      await tester.pumpAndSettle();
      expect(find.text('My appointment records'), findsOneWidget);

      await tester.tap(find.text('Appointments').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dashboard').first);
      await tester.pumpAndSettle();
      expect(find.text('Welcome back, James'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('booking layout fits narrow mobile viewports', (tester) async {
    for (final width in [390.0, 320.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(
        MaterialApp(
          theme: PatientPortalTheme.dark,
          home: Scaffold(body: BookingPage(now: DateTime(2026, 10, 26, 7))),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Schedule a visit'), findsOneWidget);
      expect(find.textContaining('DEMO DATA'), findsNWidgets(2));
      expect(tester.getSize(find.byType(Scaffold)).width, width);
      expect(tester.takeException(), isNull);
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets(
    'My appointments groups and orders upcoming before past records',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: PatientPortalTheme.light,
          home: Scaffold(body: BookingPage(now: DateTime(2026, 10, 25, 12))),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('my-appointments-card')),
      );
      expect(find.text('My appointments'), findsOneWidget);
      expect(
        find.text('Your appointment requests and previous visits'),
        findsOneWidget,
      );
      expect(find.text('Upcoming appointments'), findsOneWidget);
      expect(find.text('Past appointments'), findsOneWidget);
      expect(find.text('Comprehensive Eye Examination').first, findsOneWidget);
      expect(find.text('Contact Lens Consultation').first, findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Requested'), findsOneWidget);
      expect(find.text('Showing 1–5 of 12'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Upcoming appointments')).dy,
        lessThan(tester.getTopLeft(find.text('Past appointments')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Comprehensive Eye Examination').first).dy,
        lessThan(
          tester.getTopLeft(find.text('Contact Lens Consultation').first).dy,
        ),
      );

      final requestedBadge = tester.widget<Container>(
        find.byKey(const ValueKey('my-appointment-status-DEMO-2026-013')),
      );
      expect(
        (requestedBadge.decoration! as BoxDecoration).color,
        const Color(0xFFFFFBEB),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'My appointments paginates five combined records and styles status',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: PatientPortalTheme.light,
          home: Scaffold(body: BookingPage(now: DateTime(2026, 10, 25, 12))),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('my-appointments-card')),
      );

      expect(
        find.byKey(const ValueKey('my-appointments-next')),
        findsOneWidget,
      );
      expect(find.text('Showing 1–5 of 12'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('my-appointment-DEMO-2026-009')),
        findsNothing,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('my-appointments-next')),
      );
      await tester.tap(find.byKey(const ValueKey('my-appointments-next')));
      await tester.pumpAndSettle();
      expect(find.text('Showing 6–10 of 12'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('my-appointment-DEMO-2026-013')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('my-appointment-DEMO-2026-009')),
        findsOneWidget,
      );
      expect(find.text('Past appointments'), findsOneWidget);

      final cancelledBadge = tester.widget<Container>(
        find.byKey(const ValueKey('my-appointment-status-DEMO-2026-007')),
      );
      expect(
        (cancelledBadge.decoration! as BoxDecoration).color,
        const Color(0xFFFEF2F2),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('My appointments shows source empty state and omits pagination', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: Scaffold(
          body: BookingPage(
            now: DateTime(2026, 10, 25),
            appointments: const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('my-appointments-card')),
    );

    expect(find.text("You don't have any appointments yet."), findsOneWidget);
    expect(find.byKey(const ValueKey('my-appointments-next')), findsNothing);
    expect(find.textContaining('Showing '), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('My appointments cancellation affordance is preview-only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: Scaffold(body: BookingPage(now: DateTime(2026, 10, 25, 12))),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cancel Appointment').first);

    expect(find.text('Cancel Appointment'), findsWidgets);
    await tester.tap(find.text('Cancel Appointment').first);
    await tester.pumpAndSettle();
    expect(find.text('Demo action only'), findsOneWidget);
    expect(
      find.text('Cancellation is not connected. No appointment was changed.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('My appointments content fits narrow mobile widths', (
    tester,
  ) async {
    for (final width in [390.0, 320.0]) {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: PatientPortalTheme.dark,
          home: Scaffold(body: BookingPage(now: DateTime(2026, 10, 25, 12))),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('my-appointments-card')),
      );
      expect(find.text('My appointments'), findsOneWidget);
      expect(find.text('Cancel Appointment'), findsWidgets);
      expect(tester.getSize(find.byType(Scaffold)).width, width);
      expect(tester.takeException(), isNull);
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('Appointment History remains separately navigable from booking', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PatientPortalApp());
    await tester.tap(find.text('Appointments').first);
    await tester.pumpAndSettle();
    expect(find.text('Schedule a visit'), findsOneWidget);

    await tester.tap(find.text('Appointment History').first);
    await tester.pumpAndSettle();
    expect(find.text('My appointment records'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Past'), findsOneWidget);

    await tester.tap(find.text('Appointments').first);
    await tester.pumpAndSettle();
    expect(find.text('My appointments'), findsOneWidget);
    expect(find.text('My appointment records'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'notification dropdown shows local demo items and read controls',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const PatientPortalApp());
      await tester.tap(find.byTooltip('Switch to dark theme'));
      await tester.pumpAndSettle();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);

      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('notification-dropdown')),
        findsOneWidget,
      );
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('2 unread'), findsOneWidget);
      expect(find.text('Appointment Confirmed'), findsOneWidget);
      expect(find.text('Appointment Reminder'), findsOneWidget);
      expect(find.text('Appointment Cancelled'), findsOneWidget);
      expect(find.text('LOCAL DEMO DATA · PREVIEW ONLY'), findsOneWidget);

      await tester.tap(find.text('Appointment Confirmed'));
      await tester.pumpAndSettle();
      expect(find.text('1 unread'), findsOneWidget);

      await tester.tap(find.text('Mark all as read'));
      await tester.pumpAndSettle();
      expect(find.text('0 unread'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Mark all as read'),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('notification-dropdown')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('notification dropdown fits desktop and narrow mobile widths', (
    tester,
  ) async {
    for (final size in [
      const Size(1440, 1000),
      const Size(390, 844),
      const Size(320, 720),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const PatientPortalApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'before open $size');
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'opened viewport $size');

      final dropdownRect = tester.getRect(
        find.byKey(const ValueKey('notification-dropdown')),
      );
      expect(dropdownRect.left, greaterThanOrEqualTo(0));
      expect(dropdownRect.right, lessThanOrEqualTo(size.width));
      expect(dropdownRect.top, greaterThanOrEqualTo(0));
      expect(dropdownRect.bottom, lessThanOrEqualTo(size.height));
      expect(find.text('Appointment Confirmed'), findsOneWidget);
      final titleRect = tester.getRect(find.text('Notifications'));
      final unreadRect = tester.getRect(find.text('2 unread'));
      final markReadRect = tester.getRect(find.text('Mark all as read'));
      expect(
        (titleRect.center.dy - unreadRect.center.dy).abs(),
        lessThanOrEqualTo(2),
        reason: 'unread indicator alignment at $size',
      );
      expect(
        (titleRect.center.dy - markReadRect.center.dy).abs(),
        lessThanOrEqualTo(2),
        reason: 'header action alignment at $size',
      );
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('notification-dropdown')), findsNothing);
      expect(tester.takeException(), isNull, reason: 'closed viewport $size');
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('dashboard fits a narrow mobile viewport without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PatientPortalApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome back, James'), findsOneWidget);
    expect(find.byTooltip('Open navigation menu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile drawer opens and selects a local destination', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PatientPortalApp());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Support Center'));
    await tester.pumpAndSettle();

    expect(find.text('My Support Tickets'), findsOneWidget);
    expect(find.text('DEMO DATA'), findsOneWidget);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appointment History'));
    await tester.pumpAndSettle();
    expect(find.text('My appointment records'), findsOneWidget);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transaction History'));
    await tester.pumpAndSettle();
    expect(find.text('Billing records'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _catalogApp(
  PatientAuthController controller,
  FramesCatalogRepository repository,
) {
  return PatientAuthScope(
    controller: controller,
    framesCatalogRepository: repository,
    child: MaterialApp(
      theme: PatientPortalTheme.light,
      home: const Scaffold(body: FramesCatalogPage()),
    ),
  );
}

CatalogFrame _apiFrame({Uri? imageUrl}) => CatalogFrame(
  frameId: 14,
  name: 'Avery API Frame',
  brand: 'API Brand',
  category: 'Eyeglasses',
  price: 2450,
  stockQuantity: 8,
  description: 'API frame details.',
  imageUrl: imageUrl,
);

class _FakeFramesCatalogRepository implements FramesCatalogRepository {
  _FakeFramesCatalogRepository({this.frames = const [], this.onGetFrames});

  final List<CatalogFrame> frames;
  final Future<List<CatalogFrame>> Function()? onGetFrames;
  int calls = 0;

  @override
  bool get isDemo => false;

  @override
  List<CatalogFrame>? get localFrames => null;

  @override
  Future<List<CatalogFrame>> getFrames() {
    calls++;
    return onGetFrames?.call() ?? Future.value(frames);
  }
}
