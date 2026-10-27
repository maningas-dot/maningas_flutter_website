import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patient_portal_flutter/app/theme.dart';
import 'package:patient_portal_flutter/core/network/api_client.dart';
import 'package:patient_portal_flutter/features/appointment_history/appointment_history_page.dart';
import 'package:patient_portal_flutter/features/appointment_history/appointment_history_repository.dart';
import 'package:patient_portal_flutter/features/auth/application/patient_auth_controller.dart';
import 'package:patient_portal_flutter/features/auth/application/patient_auth_scope.dart';
import 'package:patient_portal_flutter/features/auth/data/demo_patient_auth_repository.dart';
import 'package:patient_portal_flutter/features/auth/domain/patient_session.dart';
import 'package:patient_portal_flutter/features/auth/domain/patient_session_store.dart';

void main() {
  testWidgets(
    'renders mocked API records with existing filters and pagination',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final requests = <http.Request>[];
      final apiClient = ApiClient(
        baseUri: Uri.parse('https://api.example.test'),
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode([
              _appointmentJson(1, '2026-10-28', 'Requested'),
              _appointmentJson(2, '2026-10-29', 'Confirmed'),
              _appointmentJson(3, '2026-10-30', 'Cancelled'),
              _appointmentJson(4, '2026-10-31', 'Completed'),
              _appointmentJson(5, '2026-11-01', 'Requested'),
              _appointmentJson(6, '2026-11-02', 'Requested'),
              _appointmentJson(7, '2026-10-26', 'Completed'),
            ]),
            200,
          );
        }),
      );
      addTearDown(apiClient.close);
      final controller = _apiController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: PatientPortalTheme.light,
          home: PatientAuthScope(
            controller: controller,
            appointmentHistoryRepository: ApiAppointmentHistoryRepository(
              apiClient,
            ),
            child: Scaffold(
              body: AppointmentHistoryPage(now: DateTime(2026, 10, 27)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/api/appointments/patient/GVC-1601');
      expect(requests.single.headers['authorization'], 'Bearer test-token');
      expect(find.text('Showing 1-5 of 7'), findsOneWidget);
      expect(find.textContaining('DEMO-2026'), findsNothing);
      expect(find.text('Appointment 6'), findsOneWidget);
      expect(find.text('Appointment 1'), findsNothing);

      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle();
      expect(find.text('Showing 1-5 of 5'), findsOneWidget);
      expect(find.textContaining('Ref: 3'), findsNothing);

      await tester.tap(find.text('Past'));
      await tester.pumpAndSettle();
      expect(find.text('Showing 1-1 of 1'), findsOneWidget);
      await tester.tap(find.text('Appointment 7'));
      await tester.pumpAndSettle();
      expect(find.text('APPOINTMENT ID'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows API errors and retries without losing the session', (
    tester,
  ) async {
    var requestCount = 0;
    final apiClient = ApiClient(
      baseUri: Uri.parse('https://api.example.test'),
      client: MockClient((_) async {
        requestCount++;
        if (requestCount == 1) {
          return http.Response(
            jsonEncode({'error': 'Unavailable'}),
            503,
          );
        }
        return http.Response('[]', 200);
      }),
    );
    addTearDown(apiClient.close);
    final controller = _apiController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: PatientAuthScope(
          controller: controller,
          appointmentHistoryRepository: ApiAppointmentHistoryRepository(
            apiClient,
          ),
          child: const Scaffold(body: AppointmentHistoryPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your appointment history could not be loaded right now.'),
        findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No appointment records found'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(requestCount, 2);
    expect(find.text('No appointment records found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('API mode without a patient session requests no history', (
    tester,
  ) async {
    var requestCount = 0;
    final apiClient = ApiClient(
      baseUri: Uri.parse('https://api.example.test'),
      client: MockClient((_) async {
        requestCount++;
        return http.Response('[]', 200);
      }),
    );
    addTearDown(apiClient.close);
    final controller = PatientAuthController(
      repository: const DemoPatientAuthRepository(),
      sessionStore: InMemoryPatientSessionStore(),
      isDemoMode: false,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: PatientAuthScope(
          controller: controller,
          appointmentHistoryRepository: ApiAppointmentHistoryRepository(
            apiClient,
          ),
          child: const Scaffold(body: AppointmentHistoryPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in required'), findsOneWidget);
    expect(find.text('DEMO DATA'), findsNothing);
    expect(requestCount, 0);
    expect(tester.takeException(), isNull);
  });
}

Map<String, Object?> _appointmentJson(int id, String date, String status) => {
  'appointment_id': id,
  'patient_id': 'GVC-1601',
  'patient_name': 'Test Patient',
  'appointment_date': date,
  'appointment_time': '09:30:00',
  'purpose_of_visit': 'Appointment $id',
  'appointment_status': status,
  'appointment_source': 'Patient Portal',
};

PatientAuthController _apiController() {
  final sessionStore = InMemoryPatientSessionStore()
    ..save(
      const PatientSession(
        patientId: 'GVC-1601',
        name: 'Test Patient',
        email: 'patient@example.test',
        token: 'test-token',
        rememberMe: false,
      ),
    );
  return PatientAuthController(
    repository: const DemoPatientAuthRepository(),
    sessionStore: sessionStore,
    isDemoMode: false,
  );
}
