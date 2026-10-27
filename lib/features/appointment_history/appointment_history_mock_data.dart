abstract interface class AppointmentHistoryRecord {
  String? get id;
  String? get dateValue;
  String? get time;
  String? get purpose;
  String? get status;
  String? get source;
  String? get patientName;
  DateTime? get date;
  DateTime? get scheduledAt;
}

class DemoAppointment implements AppointmentHistoryRecord {
  const DemoAppointment({
    required this.id,
    required this.dateValue,
    required this.time,
    required this.purpose,
    required this.status,
    required this.source,
    required this.patientName,
  });

  @override
  final String id;
  @override
  final String dateValue;
  @override
  final String time;
  @override
  final String purpose;
  @override
  final String status;
  @override
  final String source;
  @override
  final String patientName;

  @override
  DateTime get date => DateTime.parse(dateValue);

  @override
  DateTime get scheduledAt {
    final parts = time.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }
}

class PatientAppointment implements AppointmentHistoryRecord {
  const PatientAppointment({
    this.id,
    this.dateValue,
    this.time,
    this.purpose,
    this.status,
    this.source,
    this.patientName,
  });

  factory PatientAppointment.fromJson(Map<String, dynamic> json) {
    return PatientAppointment(
      id: _stringOrNumber(json['appointment_id'] ?? json['id']),
      dateValue: _dateOnly(json['appointment_date'] ?? json['date']),
      time: _timeOnly(json['appointment_time'] ?? json['time']),
      purpose: _optionalString(
        json['purpose_of_visit'] ?? json['purposeOfVisit'] ?? json['service'],
      ),
      status: _optionalString(
        json['appointment_status'] ??
            json['appointmentStatus'] ??
            json['status'],
      ),
      source: _optionalString(
        json['appointment_source'] ?? json['source'],
      ),
      patientName: _optionalString(
        json['patient_name'] ??
            json['patientName'] ??
            json['full_name'] ??
            json['name'],
      ),
    );
  }

  @override
  final String? id;
  @override
  final String? dateValue;
  @override
  final String? time;
  @override
  final String? purpose;
  @override
  final String? status;
  @override
  final String? source;
  @override
  final String? patientName;

  @override
  DateTime? get date => dateValue == null ? null : DateTime.tryParse(dateValue!);

  @override
  DateTime? get scheduledAt {
    final appointmentDate = date;
    if (appointmentDate == null) return null;
    final appointmentTime = time;
    if (appointmentTime == null) return appointmentDate;
    final parts = appointmentTime.split(':');
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(
      appointmentDate.year,
      appointmentDate.month,
      appointmentDate.day,
      hour,
      minute,
    );
  }
}

String? _stringOrNumber(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  if (value is num) return value.toString();
  return null;
}

String? _optionalString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

String? _dateOnly(Object? value) {
  if (value is! String || DateTime.tryParse(value) == null) return null;
  return value.length >= 10 ? value.substring(0, 10) : value;
}

String? _timeOnly(Object? value) {
  if (value is! String) return null;
  final normalized = value.trim();
  if (!RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$').hasMatch(normalized)) {
    return null;
  }
  final pieces = normalized.split(':');
  final hour = int.tryParse(pieces[0]);
  final minute = int.tryParse(pieces[1]);
  if (hour == null || hour > 23 || minute == null || minute > 59) return null;
  return '${hour.toString().padLeft(2, '0')}:${pieces[1]}';
}

class AppointmentHistoryMockData {
  const AppointmentHistoryMockData._();

  static const patientName = 'James Maningas';
  static const appointments = <DemoAppointment>[
    DemoAppointment(
      id: 'DEMO-2026-014',
      dateValue: '2026-12-03',
      time: '10:30',
      purpose: 'Comprehensive Eye Examination',
      status: 'Confirmed',
      source: 'Patient Portal',
      patientName: AppointmentHistoryMockData.patientName,
    ),
    DemoAppointment(
      id: 'DEMO-2026-013',
      dateValue: '2026-11-19',
      time: '14:00',
      purpose: 'Contact Lens Consultation',
      status: 'Requested',
      source: 'Patient Portal',
      patientName: AppointmentHistoryMockData.patientName,
    ),
    DemoAppointment(
      id: 'DEMO-2026-012',
      dateValue: '2026-10-23',
      time: '09:00',
      purpose: 'Follow-up Consultation',
      status: 'Completed',
      source: 'Clinic Staff',
      patientName: AppointmentHistoryMockData.patientName,
    ),
    DemoAppointment(
      id: 'DEMO-2026-011',
      dateValue: '2026-09-08',
      time: '11:15',
      purpose: 'Vision Screening',
      status: 'Completed',
      source: 'Patient Portal',
      patientName: AppointmentHistoryMockData.patientName,
    ),
    DemoAppointment(
      id: 'DEMO-2026-010',
      dateValue: '2026-08-21',
      time: '15:30',
      purpose: 'Frame Adjustment',
      status: 'Completed',
      source: 'Clinic Staff',
      patientName: AppointmentHistoryMockData.patientName,
    ),
    DemoAppointment(
      id: 'DEMO-2026-009',
      dateValue: '2026-07-10',
      time: '13:00',
      purpose: 'Comprehensive Eye Examination',
      status: 'Completed',
      source: 'Patient Portal',
      patientName: AppointmentHistoryMockData.patientName,
    ),
    DemoAppointment(
      id: 'DEMO-2026-008',
      dateValue: '2026-06-16',
      time: '10:00',
      purpose: 'Prescription Review',
      status: 'Completed',
      source: 'Clinic Staff',
      patientName: AppointmentHistoryMockData.patientName,
    ),
    DemoAppointment(
      id: 'DEMO-2026-007',
      dateValue: '2026-05-04',
      time: '09:30',
      purpose: 'Contact Lens Consultation',
      status: 'Cancelled',
      source: 'Patient Portal',
      patientName: AppointmentHistoryMockData.patientName,
    ),
    DemoAppointment(
      id: 'DEMO-2026-006',
      dateValue: '2026-04-12',
      time: '16:00',
      purpose: 'Follow-up Consultation',
      status: 'Completed',
      source: 'Patient Portal',
      patientName: AppointmentHistoryMockData.patientName,
    ),
    DemoAppointment(
      id: 'DEMO-2026-005',
      dateValue: '2026-03-02',
      time: '11:00',
      purpose: 'Vision Screening',
      status: 'Completed',
      source: 'Clinic Staff',
      patientName: AppointmentHistoryMockData.patientName,
    ),
    DemoAppointment(
      id: 'DEMO-2026-004',
      dateValue: '2026-02-14',
      time: '14:30',
      purpose: 'Frame Adjustment',
      status: 'Completed',
      source: 'Patient Portal',
      patientName: AppointmentHistoryMockData.patientName,
    ),
    DemoAppointment(
      id: 'DEMO-2026-003',
      dateValue: '2026-01-08',
      time: '08:45',
      purpose: 'Comprehensive Eye Examination',
      status: 'Completed',
      source: 'Clinic Staff',
      patientName: AppointmentHistoryMockData.patientName,
    ),
  ];
}
