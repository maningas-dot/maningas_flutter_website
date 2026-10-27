import 'package:flutter/material.dart';

import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../appointment_history/appointment_history_mock_data.dart';
import 'booking_mock_data.dart';
import 'my_appointments_section.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({
    this.now,
    this.schedule,
    this.appointments = AppointmentHistoryMockData.appointments,
    this.focusMyAppointments = false,
    super.key,
  });

  final DateTime? now;
  final DemoBookingSchedule? schedule;
  final List<DemoAppointment> appointments;
  final bool focusMyAppointments;

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _myAppointmentsKey = GlobalKey();

  static const _openMinute = 8 * 60;
  static const _closeMinute = 17 * 60 + 30;
  static const _slotInterval = 30;
  static const _bookingCutoff = Duration(minutes: 20);

  late final DateTime _now = widget.now ?? DateTime.now();
  late final DateTime _today = DateTime(_now.year, _now.month, _now.day);
  late final DateTime _maxDate = _today.add(const Duration(days: 365));
  late final DemoBookingSchedule _schedule =
      widget.schedule ?? DemoBookingSchedule.forDate(_now);
  late DateTime _visibleMonth = DateTime(_today.year, _today.month);
  DateTime? _selectedDate;
  String? _selectedTime;
  String? _purpose;

  @override
  void initState() {
    super.initState();
    if (widget.focusMyAppointments) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final sectionContext = _myAppointmentsKey.currentContext;
        if (!mounted || sectionContext == null) return;
        Scrollable.ensureVisible(
          sectionContext,
          alignment: 0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  List<String> get _slots => [
    for (
      var minute = _openMinute;
      minute <= _closeMinute;
      minute += _slotInterval
    )
      '${_twoDigits(minute ~/ 60)}:${_twoDigits(minute % 60)}:00',
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width <= PatientPortalBreakpoints.mobileNavigation;
    final horizontalPadding = width <= 360
        ? 8.0
        : width <= PatientPortalBreakpoints.mobile
        ? 12.0
        : compact
        ? 22.0
        : 18.0;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        compact ? 22 : 32,
        horizontalPadding,
        compact ? 28 : 40,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: PatientPortalBreakpoints.contentMaxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PageHeader(compact: compact),
              const SizedBox(height: 20),
              const _DemoNotice(),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final calendar = _CalendarCard(
                    visibleMonth: _visibleMonth,
                    selectedDate: _selectedDate,
                    today: _today,
                    maxDate: _maxDate,
                    schedule: _schedule,
                    previousEnabled: !_isAtMinimumMonth,
                    nextEnabled: !_isAtMaximumMonth,
                    onMonthChanged: _changeMonth,
                    onDateSelected: _selectDate,
                    isDateUnavailable: _isDateUnavailable,
                  );
                  final details = _DetailsCard(
                    selectedDate: _selectedDate,
                    slots: _slots,
                    selectedTime: _selectedTime,
                    purpose: _purpose,
                    now: _now,
                    schedule: _schedule,
                    onTimeSelected: (time) {
                      setState(() => _selectedTime = time);
                    },
                    onPurposeChanged: (purpose) {
                      setState(() => _purpose = purpose);
                    },
                    onBook: _showConfirmation,
                  );

                  if (constraints.maxWidth <= 1050) {
                    return Column(
                      children: [calendar, const SizedBox(height: 16), details],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: calendar),
                      const SizedBox(width: 18),
                      Expanded(flex: 3, child: details),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              MyAppointmentsSection(
                key: _myAppointmentsKey,
                appointments: widget.appointments,
                now: _now,
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isAtMinimumMonth =>
      _visibleMonth.year == _today.year && _visibleMonth.month == _today.month;

  bool get _isAtMaximumMonth =>
      _visibleMonth.year == _maxDate.year &&
      _visibleMonth.month == _maxDate.month;

  void _changeMonth(int offset) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + offset,
      );
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedTime = null;
    });
  }

  bool _isDateUnavailable(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    if (day.isBefore(_today) ||
        day.isAfter(_maxDate) ||
        day.weekday == DateTime.sunday ||
        _closureForDate(day) != null) {
      return true;
    }
    return _slots.every(
      (time) => _isSlotPast(day, time) || _isSlotBooked(day, time),
    );
  }

  DemoClinicClosure? _closureForDate(DateTime date) {
    for (final closure in _schedule.closures) {
      if (closure.includes(date)) return closure;
    }
    return null;
  }

  bool _isSlotBooked(DateTime date, String time) {
    const releasedStatuses = {'cancelled', 'canceled', 'rejected', 'declined'};
    return _schedule.bookings.any((booking) {
      final bookingDate = DateTime(
        booking.appointmentDate.year,
        booking.appointmentDate.month,
        booking.appointmentDate.day,
      );
      return bookingDate == date &&
          booking.appointmentTime.substring(0, 5) == time.substring(0, 5) &&
          !releasedStatuses.contains(booking.status.trim().toLowerCase());
    });
  }

  bool _isSlotPast(DateTime date, String time) {
    final parts = time.split(':').map(int.parse).toList();
    final slotDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      parts[0],
      parts[1],
    );
    return slotDateTime.difference(_now) <= _bookingCutoff;
  }

  void _showConfirmation() {
    final date = _selectedDate;
    final time = _selectedTime;
    final purpose = _purpose;
    if (date == null || time == null || purpose == null) return;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.event_available_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('Review appointment request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DEMO DATA · This is a local preview, not a live booking.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Text('Date: ${_formatLongDate(date)}'),
            Text('Time: ${_formatTime(time)}'),
            Text('Purpose: $purpose'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Review details'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showPreviewNotice();
            },
            child: const Text('Preview only'),
          ),
        ],
      ),
    );
  }

  void _showPreviewNotice() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.info_outline,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('Demo confirmation preview'),
        content: const Text(
          'No appointment was submitted, created, or reserved. '
          'Availability shown here is local demo data only.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.extension<PatientPortalTextColors>()!.secondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.visibility_outlined,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'GONZALES VISION CLINIC',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Schedule a visit',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: compact ? 28 : 36,
            height: 1.2,
            letterSpacing: -1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose a convenient date and time for your next clinic visit.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: secondary,
            fontSize: compact ? 13 : 14,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: .07),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: .2),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'DEMO DATA · Sample dates, closures, and reserved slots are '
              'illustrative only and do not reflect live clinic availability.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.visibleMonth,
    required this.selectedDate,
    required this.today,
    required this.maxDate,
    required this.schedule,
    required this.previousEnabled,
    required this.nextEnabled,
    required this.onMonthChanged,
    required this.onDateSelected,
    required this.isDateUnavailable,
  });

  final DateTime visibleMonth;
  final DateTime? selectedDate;
  final DateTime today;
  final DateTime maxDate;
  final DemoBookingSchedule schedule;
  final bool previousEnabled;
  final bool nextEnabled;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;
  final bool Function(DateTime) isDateUnavailable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.extension<PatientPortalTextColors>()!.secondary;
    final daysInMonth = DateTime(
      visibleMonth.year,
      visibleMonth.month + 1,
      0,
    ).day;
    final leadingDays =
        DateTime(visibleMonth.year, visibleMonth.month, 1).weekday % 7;
    final cells = <Widget>[
      for (var day = 1; day <= leadingDays; day++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        _CalendarDay(
          date: DateTime(visibleMonth.year, visibleMonth.month, day),
          today: today,
          selected: _sameDate(
            selectedDate,
            DateTime(visibleMonth.year, visibleMonth.month, day),
          ),
          unavailable: isDateUnavailable(
            DateTime(visibleMonth.year, visibleMonth.month, day),
          ),
          closure: _closureFor(
            schedule,
            DateTime(visibleMonth.year, visibleMonth.month, day),
          ),
          maxDate: maxDate,
          onTap: onDateSelected,
        ),
    ];

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardHeader(
            icon: Icons.calendar_month_outlined,
            title: 'Select a date',
            subtitle: 'Available dates are highlighted on the calendar.',
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatMonth(visibleMonth),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Previous month',
                      onPressed: previousEnabled
                          ? () => onMonthChanged(-1)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Next month',
                      onPressed: nextEnabled ? () => onMonthChanged(1) : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final day in [
                      'Sun',
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                    ])
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 7),
                            child: Text(
                              day,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .3,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cells.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    mainAxisExtent: 55,
                  ),
                  itemBuilder: (context, index) => cells[index],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: theme.colorScheme.outline),
                const SizedBox(height: 13),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    _LegendItem(
                      color: const Color(0xFF16A34A),
                      label: 'Available',
                    ),
                    _LegendItem(
                      color: theme.colorScheme.primary,
                      label: 'Selected',
                    ),
                    _LegendItem(
                      color: theme.colorScheme.error,
                      label: 'Unavailable',
                    ),
                    Text(
                      'Book up to 1 year ahead',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.date,
    required this.today,
    required this.selected,
    required this.unavailable,
    required this.closure,
    required this.maxDate,
    required this.onTap,
  });

  final DateTime date;
  final DateTime today;
  final bool selected;
  final bool unavailable;
  final DemoClinicClosure? closure;
  final DateTime maxDate;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = _sameDate(date, today);
    final inRange = !date.isBefore(today) && !date.isAfter(maxDate);
    final isSunday = date.weekday == DateTime.sunday;
    final closedBySource = closure != null || isSunday;
    final label = closure != null
        ? 'CLOSED'
        : isSunday
        ? 'CLOSED'
        : unavailable && inRange
        ? 'FULL'
        : '';
    final foreground = selected
        ? Colors.white
        : unavailable
        ? theme.disabledColor
        : theme.colorScheme.onSurface;

    return Tooltip(
      message:
          closure?.reason ??
          (isSunday
              ? 'The clinic is closed on Sundays.'
              : unavailable && inRange
              ? 'No appointments available.'
              : _formatLongDate(date)),
      child: OutlinedButton(
        key: ValueKey('booking-date-${_dateKey(date)}'),
        onPressed: unavailable ? null : () => onTap(date),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          backgroundColor: selected
              ? theme.colorScheme.primary
              : isToday
              ? theme.colorScheme.primary.withValues(alpha: .04)
              : theme.colorScheme.surface,
          foregroundColor: foreground,
          side: BorderSide(
            color: selected
                ? theme.colorScheme.primary
                : isToday
                ? theme.colorScheme.primary.withValues(alpha: .35)
                : unavailable
                ? theme.colorScheme.outline.withValues(alpha: .55)
                : theme.colorScheme.outline,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          disabledBackgroundColor: theme.colorScheme.surface.withValues(
            alpha: .65,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  color: foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isToday && constraints.maxHeight > 42)
                Text(
                  'TODAY',
                  style: TextStyle(
                    color: selected ? Colors.white : theme.colorScheme.primary,
                    fontSize: 6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (label.isNotEmpty)
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : closedBySource
                        ? theme.colorScheme.error
                        : theme.extension<PatientPortalTextColors>()!.secondary,
                    fontSize: 6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.selectedDate,
    required this.slots,
    required this.selectedTime,
    required this.purpose,
    required this.now,
    required this.schedule,
    required this.onTimeSelected,
    required this.onPurposeChanged,
    required this.onBook,
  });

  final DateTime? selectedDate;
  final List<String> slots;
  final String? selectedTime;
  final String? purpose;
  final DateTime now;
  final DemoBookingSchedule schedule;
  final ValueChanged<String> onTimeSelected;
  final ValueChanged<String?> onPurposeChanged;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.extension<PatientPortalTextColors>()!.secondary;
    final selected = selectedDate;
    final closure = selected == null ? null : _closureFor(schedule, selected);
    final availableSlots = selected == null
        ? <String>[]
        : slots.where((time) {
            return !_slotPast(selected, time, now) &&
                !_slotBooked(schedule, selected, time);
          }).toList();

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardHeader(
            icon: Icons.person_outline,
            title: 'Appointment details',
            subtitle: 'Choose your preferred time and visit purpose.',
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: .07),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: .25),
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SELECTED DATE',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .7,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        selected == null
                            ? 'Select a date'
                            : _formatLongDate(selected),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Available time',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '30-minute intervals',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (selected == null)
                  const _EmptySlots(
                    message: 'Select a date to see available times.',
                  )
                else if (closure != null)
                  _EmptySlots(
                    message:
                        'The clinic is closed on this date: ${closure.reason}.',
                  )
                else if (selected.weekday == DateTime.sunday)
                  const _EmptySlots(message: 'The clinic is closed on Sundays.')
                else if (availableSlots.isEmpty)
                  const _EmptySlots(
                    message:
                        'No appointment times are available for this date.',
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth < 390 ? 2 : 3;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: slots.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          mainAxisExtent: 43,
                        ),
                        itemBuilder: (context, index) {
                          final time = slots[index];
                          final past = _slotPast(selected, time, now);
                          final booked = _slotBooked(schedule, selected, time);
                          final unavailable = past || booked;
                          final isSelected = selectedTime == time;
                          return OutlinedButton(
                            key: ValueKey('booking-time-$time'),
                            onPressed: unavailable
                                ? null
                                : () => onTimeSelected(time),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              foregroundColor: isSelected
                                  ? Colors.white
                                  : secondary,
                              backgroundColor: isSelected
                                  ? theme.colorScheme.primary
                                  : null,
                              side: BorderSide(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                            child: Text(
                              _formatTime(time),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                const SizedBox(height: 20),
                Text(
                  'Purpose of visit',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: const ValueKey('booking-purpose'),
                  initialValue: purpose,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Select purpose',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 14,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Eye Examination',
                      child: Text('Eye Examination'),
                    ),
                    DropdownMenuItem(
                      value: 'Follow-up',
                      child: Text('Follow-up'),
                    ),
                    DropdownMenuItem(
                      value: 'Frame / Eyewear',
                      child: Text('Frame / Eyewear'),
                    ),
                    DropdownMenuItem(
                      value: 'Contact Lens',
                      child: Text('Contact Lens'),
                    ),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: onPurposeChanged,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? const Color(0xFF162238)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 17,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your appointment request would be submitted for '
                          'clinic confirmation. This screen is demo-only.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: secondary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 44,
                  child: FilledButton(
                    key: const ValueKey('booking-submit'),
                    onPressed:
                        selected != null &&
                            selectedTime != null &&
                            purpose != null
                        ? onBook
                        : null,
                    child: const Text('Book Appointment'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.extension<PatientPortalTextColors>()!.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: secondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySlots extends StatelessWidget {
  const _EmptySlots({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: .8),
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.extension<PatientPortalTextColors>()!.secondary,
          height: 1.5,
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

DemoClinicClosure? _closureFor(DemoBookingSchedule schedule, DateTime date) {
  for (final closure in schedule.closures) {
    if (closure.includes(date)) return closure;
  }
  return null;
}

bool _slotBooked(DemoBookingSchedule schedule, DateTime date, String time) {
  const releasedStatuses = {'cancelled', 'canceled', 'rejected', 'declined'};
  return schedule.bookings.any((booking) {
    final bookingDate = DateTime(
      booking.appointmentDate.year,
      booking.appointmentDate.month,
      booking.appointmentDate.day,
    );
    return bookingDate == date &&
        booking.appointmentTime.substring(0, 5) == time.substring(0, 5) &&
        !releasedStatuses.contains(booking.status.trim().toLowerCase());
  });
}

bool _slotPast(DateTime date, String time, DateTime now) {
  final parts = time.split(':').map(int.parse).toList();
  final slotDateTime = DateTime(
    date.year,
    date.month,
    date.day,
    parts[0],
    parts[1],
  );
  return slotDateTime.difference(now) <= const Duration(minutes: 20);
}

bool _sameDate(DateTime? first, DateTime second) =>
    first != null &&
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _dateKey(DateTime date) =>
    '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';

String _formatMonth(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

String _formatLongDate(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _formatTime(String time) {
  final parts = time.split(':').map(int.parse).toList();
  final hour = parts[0];
  final minute = parts[1];
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  final period = hour >= 12 ? 'PM' : 'AM';
  return '$displayHour:${_twoDigits(minute)} $period';
}
