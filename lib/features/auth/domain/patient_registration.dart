class PatientRegistrationRequest {
  const PatientRegistrationRequest({
    required this.name,
    required this.age,
    required this.dateOfBirth,
    required this.gender,
    required this.contact,
    required this.email,
    required this.password,
  });

  final String name;
  final int? age;
  final String dateOfBirth;
  final String gender;
  final String contact;
  final String email;
  final String password;

  Map<String, Object?> toJson() => {
    'name': name,
    'age': age,
    'date_of_birth': dateOfBirth,
    'gender': gender,
    'contact': contact,
    'email': email,
    'password': password,
  };
}

class PatientRegistrationResult {
  const PatientRegistrationResult({
    required this.email,
    required this.name,
    required this.requiresEmailVerification,
    required this.isDemo,
  });

  final String email;
  final String name;
  final bool requiresEmailVerification;
  final bool isDemo;
}

class EmailVerificationResult {
  const EmailVerificationResult({required this.message, required this.isDemo});

  final String message;
  final bool isDemo;
}

class ResendVerificationResult {
  const ResendVerificationResult({
    required this.message,
    required this.emailVerified,
    required this.isDemo,
  });

  final String message;
  final bool emailVerified;
  final bool isDemo;
}
