import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patient_portal_flutter/core/network/api_client.dart';
import 'package:patient_portal_flutter/core/network/api_failure.dart';
import 'package:patient_portal_flutter/features/appointment_history/appointment_history_mock_data.dart';
import 'package:patient_portal_flutter/features/appointment_history/appointment_history_repository.dart';
import 'package:patient_portal_flutter/features/auth/application/patient_auth_setup.dart';

void main() {
  final baseUri = Uri.parse('https://api.example.test');

  test(
    'parses backend appointment fields without fabricating missing data',
    () {
      final appointment = PatientAppointment.fromJson({
        'appointment_id': 123,
        'patient_id': 'GVC-1601',
        'patient_name': 'Jordan Patient',
        'appointment_date': '2026-10-28',
        'appointment_time': '09:30:00',
        'purpose_of_visit': 'Eye examination',
        'appointment_status': 'Confirmed',
        'appointment_source': 'Patient Portal',
      });

      expect(appointment.id, '123');
      expect(appointment.patientName, 'Jordan Patient');
      expect(appointment.date, DateTime(2026, 10, 28));
      expect(appointment.time, '09:30');
      expect(appointment.purpose, 'Eye examination');
      expect(appointment.status, 'Confirmed');
      expect(appointment.source, 'Patient Portal');
      expect(appointment.scheduledAt, DateTime(2026, 10, 28, 9, 30));

      final incomplete = PatientAppointment.fromJson({
        'appointment_id': 'appt-public-id',
        'appointment_date': 'invalid',
        'appointment_time': 'not-time',
        'appointment_status': null,
      });
      expect(incomplete.id, 'appt-public-id');
      expect(incomplete.date, isNull);
      expect(incomplete.scheduledAt, isNull);
      expect(incomplete.purpose, isNull);
      expect(incomplete.status, isNull);
      expect(incomplete.patientName, isNull);
    },
  );

  test(
    'requests the existing GET route with string patient ID and session token',
    () async {
      final requests = <http.Request>[];
      final client = ApiClient(
        baseUri: baseUri,
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode([
              {
                'appointment_id': 123,
                'patient_id': 'GVC-1601',
                'appointment_date': '2026-10-28',
                'appointment_time': '09:30:00',
                'purpose_of_visit': 'Eye examination',
                'appointment_status': 'Confirmed',
                'appointment_source': 'Patient Portal',
              },
            ]),
            200,
          );
        }),
      );
      addTearDown(client.close);

      final appointments = await ApiAppointmentHistoryRepository(client)
          .getAppointments(patientId: 'GVC-1601', token: 'test-token');

      expect(appointments.single.id, '123');
      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/api/appointments/patient/GVC-1601');
      expect(requests.single.headers['authorization'], 'Bearer test-token');
      expect(requests.single.headers['accept'], 'application/json');
    },
  );

  test('accepts empty array and rejects invalid response shapes', () async {
    final emptyClient = ApiClient(
      baseUri: baseUri,
      client: MockClient((_) async => http.Response('[]', 200)),
    );
    addTearDown(emptyClient.close);
    expect(
      await ApiAppointmentHistoryRepository(emptyClient)
          .getAppointments(patientId: 'GVC-1601', token: 'test-token'),
      isEmpty,
    );

    final invalidClient = ApiClient(
      baseUri: baseUri,
      client: MockClient(
        (_) async => http.Response(jsonEncode({'appointments': []}), 200),
      ),
    );
    addTearDown(invalidClient.close);
    await expectLater(
      ApiAppointmentHistoryRepository(invalidClient)
          .getAppointments(patientId: 'GVC-1601', token: 'test-token'),
      throwsA(
        isA<ApiFailure>().having(
          (failure) => failure.kind,
          'kind',
          ApiFailureKind.invalidResponse,
        ),
      ),
    );
  });

  test('maps authentication failures from the API contract', () async {
    final client = ApiClient(
      baseUri: baseUri,
      client: MockClient(
        (_) async => http.Response(jsonEncode({'error': 'Unauthorized'}), 401),
      ),
    );
    addTearDown(client.close);

    await expectLater(
      ApiAppointmentHistoryRepository(client)
          .getAppointments(patientId: 'GVC-1601', token: 'expired-token'),
      throwsA(
        isA<ApiFailure>().having(
          (failure) => failure.message,
          'message',
          'Your patient session is invalid or expired. Please sign in again.',
        ),
      ),
    );
  });

  test(
    'Demo Mode stays local and API Mode selects the API repository',
    () async {
      final demoSetup = createPatientAuthSetup(mode: 'demo');
      addTearDown(demoSetup.controller.dispose);
      expect(demoSetup.appointmentHistoryRepository.isDemo, isTrue);
      expect(
        await demoSetup.appointmentHistoryRepository.getAppointments(
          patientId: 'GVC-1601',
          token: '',
        ),
        same(AppointmentHistoryMockData.appointments),
      );

      final apiSetup = createPatientAuthSetup(mode: 'api');
      addTearDown(apiSetup.controller.dispose);
      expect(apiSetup.appointmentHistoryRepository.isDemo, isFalse);
      expect(
        apiSetup.appointmentHistoryRepository,
        isA<ApiAppointmentHistoryRepository>(),
      );
    },
  );
}
