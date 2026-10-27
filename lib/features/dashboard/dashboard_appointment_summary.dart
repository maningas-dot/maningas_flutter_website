import '../appointment_history/appointment_history_mock_data.dart';

class DashboardAppointmentSummary {
  DashboardAppointmentSummary._(this.upcomingAppointments);

  factory DashboardAppointmentSummary.fromRecords(
    Iterable<AppointmentHistoryRecord> records, {
    required DateTime now,
  }) {
    final upcoming = records.where((record) {
      final scheduledAt = record.scheduledAt;
      return scheduledAt != null &&
          !scheduledAt.isBefore(now) &&
          !_isCancelled(record.status);
    }).toList()..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));

    return DashboardAppointmentSummary._(
      List<AppointmentHistoryRecord>.unmodifiable(upcoming),
    );
  }

  final List<AppointmentHistoryRecord> upcomingAppointments;

  int get upcomingCount => upcomingAppointments.length;

  AppointmentHistoryRecord? get earliestAppointment =>
      upcomingAppointments.isEmpty ? null : upcomingAppointments.first;
}

bool _isCancelled(String? status) {
  final normalized = status?.trim().toLowerCase();
  return normalized == 'cancelled' || normalized == 'canceled';
}

String formatDashboardAppointmentDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String? formatDashboardAppointmentTime(String? value) {
  if (value == null || value.isEmpty) return null;
  final parts = value.split(':');
  if (parts.length < 2) return value;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return value;

  final suffix = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
}
