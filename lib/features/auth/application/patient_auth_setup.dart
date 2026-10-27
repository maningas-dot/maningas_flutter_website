import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../appointment_history/appointment_history_repository.dart';
import '../data/demo_patient_auth_repository.dart';
import '../data/patient_auth_api_repository.dart';
import '../domain/patient_session_store.dart';
import 'patient_auth_controller.dart';
import '../../frames_catalog/frames_catalog_repository.dart';
import '../../shell/notification_repository.dart';
import '../../transaction_history/transaction_history_repository.dart';

const patientAuthMode = String.fromEnvironment(
  'PATIENT_AUTH_MODE',
  defaultValue: 'demo',
);

class PatientAuthSetup {
  const PatientAuthSetup({
    required this.controller,
    required this.framesCatalogRepository,
    required this.notificationRepository,
    required this.transactionHistoryRepository,
    required this.appointmentHistoryRepository,
  });

  final PatientAuthController controller;
  final FramesCatalogRepository framesCatalogRepository;
  final NotificationRepository notificationRepository;
  final TransactionHistoryRepository transactionHistoryRepository;
  final AppointmentHistoryRepository appointmentHistoryRepository;
}

PatientAuthSetup createPatientAuthSetup({String? mode}) {
  final selectedMode = mode ?? patientAuthMode;
  final sessionStore = InMemoryPatientSessionStore();
  if (selectedMode == 'demo') {
    return PatientAuthSetup(
      controller: PatientAuthController(
        repository: const DemoPatientAuthRepository(),
        sessionStore: sessionStore,
        isDemoMode: true,
      ),
      framesCatalogRepository: const DemoFramesCatalogRepository(),
      notificationRepository: const DemoNotificationRepository(),
      transactionHistoryRepository: const DemoTransactionHistoryRepository(),
      appointmentHistoryRepository:
          const DemoAppointmentHistoryRepository(),
    );
  }
  if (selectedMode == 'api') {
    final apiClient = ApiClient(
      client: http.Client(),
      baseUri: ApiConfig.baseUri,
    );
    return PatientAuthSetup(
      controller: PatientAuthController(
        repository: PatientAuthApiRepository(apiClient),
        sessionStore: sessionStore,
        onDispose: apiClient.close,
      ),
      framesCatalogRepository: ApiFramesCatalogRepository(apiClient),
      notificationRepository: ApiNotificationRepository(apiClient),
      transactionHistoryRepository: ApiTransactionHistoryRepository(apiClient),
      appointmentHistoryRepository: ApiAppointmentHistoryRepository(apiClient),
    );
  }
  throw ArgumentError.value(
    selectedMode,
    'mode',
    'PATIENT_AUTH_MODE must be either "demo" or "api".',
  );
}

PatientAuthController createPatientAuthController({String? mode}) =>
    createPatientAuthSetup(mode: mode).controller;
