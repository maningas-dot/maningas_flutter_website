import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../domain/patient_registration.dart';
import '../domain/patient_session.dart';
import 'patient_auth_repository.dart';

class PatientAuthApiRepository implements PatientAuthRepository {
  const PatientAuthApiRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<PatientAuthResult> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final response = await _apiClient.postJson(
      '/api/patients/login',
      body: {
        'email': email.trim(),
        'password': password,
        'rememberMe': rememberMe,
      },
    );

    final token = response['token'];
    final patientId = response['patient_id'];
    final name = response['name'];
    final responseEmail = response['email'];
    if (response['success'] != true ||
        token is! String ||
        token.isEmpty ||
        patientId == null ||
        patientId.toString().isEmpty ||
        name is! String ||
        responseEmail is! String ||
        response['email_verified'] != true) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidResponse,
        message: 'The clinic service returned incomplete sign-in details.',
      );
    }

    return PatientAuthResult.api(
      PatientSession(
        patientId: patientId.toString(),
        name: name,
        email: responseEmail,
        token: token,
        rememberMe: response['rememberMe'] == true,
      ),
    );
  }

  @override
  Future<PatientSession> validateSession(String token) async {
    final response = await _apiClient.getJson(
      '/api/patients/auth/me',
      headers: {'Authorization': 'Bearer $token'},
    );
    final patientId = response['patient_id'];
    final name = response['name'];
    final email = response['email'];
    final status = response['status'];
    if (response['success'] != true ||
        patientId == null ||
        patientId.toString().isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        email is! String ||
        email.trim().isEmpty ||
        status is! String ||
        status.trim().isEmpty ||
        response['email_verified'] != true) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidResponse,
        message: 'The clinic service returned incomplete session details.',
      );
    }

    return PatientSession(
      patientId: patientId.toString(),
      name: name,
      email: email,
      token: token,
      rememberMe: false,
      status: status,
      emailVerified: true,
    );
  }

  @override
  Future<PatientRegistrationResult> register(
    PatientRegistrationRequest request,
  ) async {
    throw const ApiFailure(
      kind: ApiFailureKind.securityBlocked,
      message: 'Online registration is temporarily unavailable while the clinic secures its registration password handling. No registration request was sent.',
    );
  }

  @override
  Future<EmailVerificationResult> verifyEmail({
    required String email,
    required String otp,
  }) async {
    final response = await _apiClient.postJson(
      '/api/patients/verify-email',
      body: {'email': email.trim(), 'otp': otp},
    );
    final patientId = response['patient_id'];
    final verifiedEmail = response['email'];
    if (response['success'] != true ||
        response['email_verified'] != true ||
        patientId == null ||
        patientId.toString().isEmpty ||
        verifiedEmail is! String ||
        verifiedEmail.trim().toLowerCase() != email.trim().toLowerCase()) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidResponse,
        message: 'The clinic service returned an invalid verification result.',
      );
    }
    final message = response['message'];
    return EmailVerificationResult(
      message: message is String && message.trim().isNotEmpty
          ? message.trim()
          : 'Email verified. Please sign in.',
      isDemo: false,
    );
  }

  @override
  Future<ResendVerificationResult> resendVerification({
    required String email,
  }) async {
    final response = await _apiClient.postJson(
      '/api/patients/resend-verification',
      body: {'email': email.trim()},
    );
    if (response['success'] != true || response['email_verified'] is! bool) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidResponse,
        message: 'The clinic service returned an invalid resend result.',
      );
    }
    final message = response['message'];
    return ResendVerificationResult(
      message: message is String && message.trim().isNotEmpty
          ? message.trim()
          : 'The verification request was accepted.',
      emailVerified: response['email_verified'] == true,
      isDemo: false,
    );
  }
}
