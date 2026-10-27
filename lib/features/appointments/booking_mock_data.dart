class DemoAppointmentBooking {
  const DemoAppointmentBooking({
    required this.appointmentDate,
    required this.appointmentTime,
    this.status = 'Requested',
  });

  final DateTime appointmentDate;
  final String appointmentTime;
  final String status;
}

class DemoClinicClosure {
  const DemoClinicClosure({
    required this.startDate,
    required this.endDate,
    required this.reason,
  });

  final DateTime startDate;
  final DateTime endDate;
  final String reason;

  bool includes(DateTime date) {
    final value = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !value.isBefore(start) && !value.isAfter(end);
  }
}

class DemoBookingSchedule {
  const DemoBookingSchedule({required this.bookings, required this.closures});

  final List<DemoAppointmentBooking> bookings;
  final List<DemoClinicClosure> closures;

  factory DemoBookingSchedule.forDate(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    var firstOpenDay = today.add(const Duration(days: 1));
    while (firstOpenDay.weekday == DateTime.sunday) {
      firstOpenDay = firstOpenDay.add(const Duration(days: 1));
    }

    var closureDay = today.add(const Duration(days: 10));
    while (closureDay.weekday == DateTime.sunday) {
      closureDay = closureDay.add(const Duration(days: 1));
    }

    return DemoBookingSchedule(
      bookings: [
        DemoAppointmentBooking(
          appointmentDate: firstOpenDay,
          appointmentTime: '09:00:00',
        ),
        DemoAppointmentBooking(
          appointmentDate: firstOpenDay,
          appointmentTime: '09:30:00',
        ),
      ],
      closures: [
        DemoClinicClosure(
          startDate: closureDay,
          endDate: closureDay,
          reason: 'Demo clinic closure',
        ),
      ],
    );
  }
}
