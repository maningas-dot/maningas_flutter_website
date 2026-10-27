import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_portal_flutter/app/theme.dart';
import 'package:patient_portal_flutter/features/auth/application/patient_auth_scope.dart';
import 'package:patient_portal_flutter/features/auth/application/patient_auth_setup.dart';
import 'package:patient_portal_flutter/features/auth/domain/patient_session.dart';
import 'package:patient_portal_flutter/features/appointment_history/appointment_history_mock_data.dart';
import 'package:patient_portal_flutter/features/appointment_history/appointment_history_repository.dart';
import 'package:patient_portal_flutter/features/dashboard/dashboard_appointment_summary.dart';
import 'package:patient_portal_flutter/features/dashboard/dashboard_page.dart';

void main() {
  testWidgets('API mode displays session identity and marks unavailable data', (
    tester,
  ) async {
    _setViewport(tester);
    final setup = createPatientAuthSetup(mode: 'api');
    setup.controller.sessionStore.save(_testSession());
    addTearDown(setup.controller.dispose);

    await tester.pumpWidget(_dashboardApp(setup));

    expect(find.text('Welcome back, Taylor Patient'), findsOneWidget);
    expect(find.text('GVC-8421'), findsNWidgets(2));
    expect(find.text('taylor@example.test'), findsOneWidget);
    expect(find.text('DEMO DATA'), findsNothing);
    expect(find.text('Unavailable'), findsNWidgets(4));
    expect(find.text('Appointment data unavailable'), findsOneWidget);
    expect(
      find.text('Patient-level appointment access has not been verified.'),
      findsOneWidget,
    );
    expect(find.text('No upcoming appointment'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Demo Mode retains mock data and the Demo badge', (tester) async {
    _setViewport(tester);
    final setup = createPatientAuthSetup(mode: 'demo');
    addTearDown(setup.controller.dispose);

    await tester.pumpWidget(_dashboardApp(setup));

    expect(find.text('Welcome back, James'), findsOneWidget);
    expect(find.text('DEMO DATA'), findsOneWidget);
    expect(find.text('James Maningas'), findsNWidgets(2));
    expect(find.text('GVC-1601'), findsWidgets);
    expect(find.text('james@example.com'), findsOneWidget);
    expect(find.text('Oct 23, 2026'), findsOneWidget);
    expect(find.text('No upcoming appointment'), findsOneWidget);
    expect(find.text('Unavailable'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('API mode without a session does not show mock identity', (
    tester,
  ) async {
    _setViewport(tester);
    final setup = createPatientAuthSetup(mode: 'api');
    addTearDown(setup.controller.dispose);

    await tester.pumpWidget(_dashboardApp(setup));

    expect(find.text('Welcome back, Unavailable'), findsOneWidget);
    expect(find.text('DEMO DATA'), findsNothing);
    expect(find.text('GVC-1601'), findsNothing);
    expect(find.text('james@example.com'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'API Dashboard does not request unverified patient appointments',
    (tester) async {
      _setViewport(tester);
      final setup = createPatientAuthSetup(mode: 'api');
      final repository = _RecordingAppointmentRepository();
      setup.controller.sessionStore.save(_testSession());
      addTearDown(setup.controller.dispose);

      await tester.pumpWidget(
        _dashboardApp(setup, appointmentHistoryRepository: repository),
      );

      expect(repository.requestCount, 0);
      expect(find.text('Appointment data unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('Dashboard summary matches HTML date and cancellation rules', () {
    final summary = DashboardAppointmentSummary.fromRecords([
      _appointment(
        id: 'later',
        date: '2026-10-28',
        time: '14:30',
        status: 'Rejected',
      ),
      _appointment(
        id: 'earliest',
        date: '2026-10-28',
        time: '09:30',
        status: 'Confirmed',
      ),
      _appointment(
        id: 'cancelled',
        date: '2026-10-29',
        time: '09:00',
        status: 'Cancelled',
      ),
      _appointment(
        id: 'canceled',
        date: '2026-10-30',
        time: '09:00',
        status: 'canceled',
      ),
      _appointment(
        id: 'past',
        date: '2026-10-27',
        time: '09:00',
        status: 'Confirmed',
      ),
      _appointment(id: 'invalid', date: 'invalid', time: '10:00'),
    ], now: DateTime(2026, 10, 27, 12));

    expect(summary.upcomingCount, 2);
    expect(summary.earliestAppointment?.id, 'earliest');
    expect(
      formatDashboardAppointmentDate(DateTime(2026, 10, 28)),
      'Oct 28, 2026',
    );
    expect(formatDashboardAppointmentTime('09:30'), '9:30 AM');
    expect(formatDashboardAppointmentTime('14:30:00'), '2:30 PM');
  });

  testWidgets(
    'API Dashboard shows supplied upcoming records and true empty state',
    (tester) async {
      _setViewport(tester);
      final setup = createPatientAuthSetup(mode: 'api');
      setup.controller.sessionStore.save(_testSession());
      addTearDown(setup.controller.dispose);
      final asOf = DateTime(2026, 10, 27, 12);

      await tester.pumpWidget(
        _dashboardApp(
          setup,
          dashboardAppointments: [
            _appointment(
              id: 'later',
              date: '2026-10-28',
              time: '14:30',
              purpose: 'Later visit',
              status: 'Confirmed',
            ),
            _appointment(
              id: 'earliest',
              date: '2026-10-28',
              time: '09:30',
              purpose: 'Eye examination',
              status: 'Confirmed',
            ),
            _appointment(
              id: 'cancelled',
              date: '2026-10-29',
              time: '09:00',
              status: 'Cancelled',
            ),
          ],
          dashboardAppointmentsAsOf: asOf,
        ),
      );

      expect(find.text('2'), findsNWidgets(2));
      expect(find.text('Oct 28, 2026'), findsOneWidget);
      expect(find.text('9:30 AM'), findsOneWidget);
      expect(find.text('Eye examination'), findsOneWidget);
      expect(find.text('Later visit'), findsNothing);
      expect(find.text('Appointment data unavailable'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _dashboardApp(
          setup,
          dashboardAppointments: const [],
          dashboardAppointmentsAsOf: asOf,
        ),
      );
      expect(find.text('0'), findsOneWidget);
      expect(find.text('No upcoming appointment'), findsOneWidget);
      expect(find.text('Appointment data unavailable'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Dashboard remains within narrow browser widths', (tester) async {
    final setup = createPatientAuthSetup(mode: 'demo');
    addTearDown(setup.controller.dispose);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in [280.0, 320.0, 360.0, 480.0]) {
      tester.view.physicalSize = Size(width, 640);
      await tester.pumpWidget(_dashboardApp(setup));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Viewport width $width');
    }
  });
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _dashboardApp(
  PatientAuthSetup setup, {
  AppointmentHistoryRepository? appointmentHistoryRepository,
  List<AppointmentHistoryRecord>? dashboardAppointments,
  DateTime? dashboardAppointmentsAsOf,
}) => PatientAuthScope(
  controller: setup.controller,
  appointmentHistoryRepository:
      appointmentHistoryRepository ?? setup.appointmentHistoryRepository,
  child: MaterialApp(
    theme: PatientPortalTheme.light,
    home: DashboardPage(
      isDark: false,
      onToggleTheme: () {},
      dashboardAppointments: dashboardAppointments,
      dashboardAppointmentsAsOf: dashboardAppointmentsAsOf,
    ),
  ),
);

PatientAppointment _appointment({
  required String id,
  required String date,
  required String time,
  String? purpose,
  String? status,
}) => PatientAppointment(
  id: id,
  dateValue: date,
  time: time,
  purpose: purpose,
  status: status,
);

class _RecordingAppointmentRepository implements AppointmentHistoryRepository {
  int requestCount = 0;

  @override
  bool get isDemo => false;

  @override
  Future<List<AppointmentHistoryRecord>> getAppointments({
    required String patientId,
    required String token,
  }) async {
    requestCount++;
    throw StateError('Unverified appointment endpoint must not be requested.');
  }
}

PatientSession _testSession() => const PatientSession(
  patientId: 'GVC-8421',
  name: 'Taylor Patient',
  email: 'taylor@example.test',
  token: 'test-token',
  rememberMe: false,
);
