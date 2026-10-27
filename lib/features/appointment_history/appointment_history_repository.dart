import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import 'appointment_history_mock_data.dart';

abstract interface class AppointmentHistoryRepository {
  bool get isDemo;

  Future<List<AppointmentHistoryRecord>> getAppointments({
    required String patientId,
    required String token,
  });
}

class DemoAppointmentHistoryRepository implements AppointmentHistoryRepository {
  const DemoAppointmentHistoryRepository();

  @override
  bool get isDemo => true;

  @override
  Future<List<AppointmentHistoryRecord>> getAppointments({
    required String patientId,
    required String token,
  }) async => AppointmentHistoryMockData.appointments;
}

class ApiAppointmentHistoryRepository implements AppointmentHistoryRepository {
  const ApiAppointmentHistoryRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  bool get isDemo => false;

  @override
  Future<List<AppointmentHistoryRecord>> getAppointments({
    required String patientId,
    required String token,
  }) async {
    try {
      final rows = await _apiClient.getJsonList(
        '/api/appointments/patient/${Uri.encodeComponent(patientId)}',
        headers: {'Authorization': 'Bearer $token'},
      );
      return rows
          .map((row) {
            if (row is! Map<String, dynamic>) {
              throw const FormatException('Invalid appointment record.');
            }
            return PatientAppointment.fromJson(row);
          })
          .toList(growable: false);
    } on FormatException {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidResponse,
        message: 'The clinic service returned invalid appointment history.',
      );
    } on ApiFailure catch (failure) {
      if (failure.statusCode == 401 || failure.statusCode == 403) {
        throw ApiFailure(
          kind: failure.kind,
          statusCode: failure.statusCode,
          code: failure.code,
          message: failure.statusCode == 401
              ? 'Your patient session is invalid or expired. Please sign in again.'
              : 'Your account cannot access appointment history.',
        );
      }
      rethrow;
    }
  }
}
