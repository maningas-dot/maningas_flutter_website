import '../domain/patient_session.dart';
import '../domain/patient_registration.dart';
import 'patient_auth_repository.dart';

class DemoPatientAuthRepository implements PatientAuthRepository {
  const DemoPatientAuthRepository();

  @override
  Future<PatientAuthResult> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    return const PatientAuthResult.demo();
  }

  @override
  Future<PatientSession> validateSession(String token) async {
    throw UnsupportedError('Session validation is unavailable in demo mode.');
  }

  @override
  Future<PatientRegistrationResult> register(
    PatientRegistrationRequest request,
  ) async {
    return PatientRegistrationResult(
      email: request.email.trim(),
      name: request.name.trim(),
      requiresEmailVerification: true,
      isDemo: true,
    );
  }

  @override
  Future<EmailVerificationResult> verifyEmail({
    required String email,
    required String otp,
  }) async {
    return const EmailVerificationResult(
      message: 'LOCAL PREVIEW ONLY: This code was not verified and no account was activated.',
      isDemo: true,
    );
  }

  @override
  Future<ResendVerificationResult> resendVerification({
    required String email,
  }) async {
    return const ResendVerificationResult(
      message:
          'LOCAL PREVIEW ONLY: Resend is simulated. No email or code was sent.',
      emailVerified: false,
      isDemo: true,
    );
  }
}
