class DemoSupportMessage {
  const DemoSupportMessage({
    required this.body,
    required this.senderName,
    required this.sentAt,
    required this.isMine,
  });

  final String body;
  final String senderName;
  final DateTime sentAt;
  final bool isMine;
}

class DemoSupportTicket {
  const DemoSupportTicket({
    required this.id,
    required this.subject,
    required this.category,
    required this.status,
    required this.priority,
    required this.updatedAt,
    required this.messages,
  });

  final String id;
  final String subject;
  final String category;
  final String status;
  final String priority;
  final DateTime updatedAt;
  final List<DemoSupportMessage> messages;
}

class SupportCenterMockData {
  const SupportCenterMockData._();

  static final List<DemoSupportTicket> tickets = [
    DemoSupportTicket(
      id: 'DEMO-102',
      subject: 'Question about my appointment',
      category: 'Appointment',
      status: 'In Progress',
      priority: 'Medium',
      updatedAt: DateTime(2026, 10, 24, 14, 35),
      messages: [
        DemoSupportMessage(
          body: 'Can you confirm the time of my upcoming visit?',
          senderName: 'You',
          sentAt: DateTime(2026, 10, 23, 10, 15),
          isMine: true,
        ),
        DemoSupportMessage(
          body: 'We are checking the appointment details for you.',
          senderName: 'Clinic Support',
          sentAt: DateTime(2026, 10, 24, 14, 35),
          isMine: false,
        ),
      ],
    ),
    DemoSupportTicket(
      id: 'DEMO-101',
      subject: 'Frames catalog question',
      category: 'Eyewear / Frames',
      status: 'Open',
      priority: 'Low',
      updatedAt: DateTime(2026, 10, 20, 9, 5),
      messages: [
        DemoSupportMessage(
          body: 'I would like to ask about the frame options in the catalog.',
          senderName: 'You',
          sentAt: DateTime(2026, 10, 20, 9, 5),
          isMine: true,
        ),
      ],
    ),
    DemoSupportTicket(
      id: 'DEMO-100',
      subject: 'Patient account details',
      category: 'Patient Account',
      status: 'Resolved',
      priority: 'Medium',
      updatedAt: DateTime(2026, 10, 12, 16, 20),
      messages: [
        DemoSupportMessage(
          body: 'I needed help reviewing my account details.',
          senderName: 'You',
          sentAt: DateTime(2026, 10, 11, 11, 40),
          isMine: true,
        ),
        DemoSupportMessage(
          body:
              'Your question has been addressed. Please let us know if you '
              'need anything else.',
          senderName: 'Clinic Support',
          sentAt: DateTime(2026, 10, 12, 16, 20),
          isMine: false,
        ),
      ],
    ),
  ];

  static const List<String> categories = [
    'Appointment',
    'Billing / Payment',
    'Patient Account',
    'Eyewear / Frames',
    'Website / Technical Issue',
    'General Inquiry',
    'Other',
  ];

  static const List<String> priorities = ['Low', 'Medium', 'High', 'Urgent'];
}
