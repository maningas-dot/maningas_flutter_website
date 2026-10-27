import 'patient_notification.dart';

class NotificationMockData {
  const NotificationMockData._();

  static const notifications = <PatientNotification>[
    PatientNotification(
      id: 1,
      title: 'Appointment Confirmed',
      body: 'Your eye examination appointment has been confirmed.',
      demoTimestamp: 'Oct 24, 2026 · 2:35 PM',
      isRead: false,
    ),
    PatientNotification(
      id: 2,
      title: 'Appointment Reminder',
      body: 'Reminder: your clinic appointment is coming up soon.',
      demoTimestamp: 'Oct 23, 2026 · 9:00 AM',
      isRead: false,
    ),
    PatientNotification(
      id: 3,
      title: 'Appointment Cancelled',
      body: 'A previous appointment request was cancelled.',
      demoTimestamp: 'Oct 20, 2026 · 11:15 AM',
      isRead: true,
    ),
  ];
}
