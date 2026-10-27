import 'package:flutter/material.dart';

import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/network/api_failure.dart';
import '../appointment_history/appointment_history_page.dart';
import '../appointment_history/appointment_history_mock_data.dart';
import '../appointment_history/appointment_history_repository.dart';
import '../appointments/booking_page.dart';
import '../frames_catalog/frames_catalog_page.dart';
import '../frames_catalog/try_on_page.dart';
import '../profile/profile_page.dart';
import '../transaction_history/transaction_history_page.dart';
import '../auth/application/patient_auth_controller.dart';
import '../auth/application/patient_auth_scope.dart';
import '../auth/domain/patient_session.dart';
import '../shell/portal_navigation.dart';
import '../shell/portal_shell.dart';
import '../support_center/support_center_page.dart';
import 'dashboard_appointment_summary.dart';
import 'dashboard_mock_data.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    required this.isDark,
    required this.onToggleTheme,
    this.onLogout,
    this.logoutEnabled = false,
    this.dashboardAppointments,
    this.dashboardAppointmentsAsOf,
    super.key,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback? onLogout;
  final bool logoutEnabled;
  final List<AppointmentHistoryRecord>? dashboardAppointments;
  final DateTime? dashboardAppointmentsAsOf;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DemoDataBadge extends StatelessWidget {
  const _DemoDataBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light
            ? const Color(0xFFEFF6FF)
            : const Color(0xFF122C58),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'DEMO DATA',
        style: theme.textTheme.labelSmall?.copyWith(
          color: primary,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _DashboardPageState extends State<DashboardPage> {
  PortalDestination _selectedDestination = PortalDestination.dashboard;
  bool _focusAppointmentsSection = false;

  void _selectDestination(PortalDestination destination) {
    setState(() {
      _selectedDestination = destination;
      _focusAppointmentsSection = false;
    });
  }

  void _openMyAppointments() {
    setState(() {
      _selectedDestination = PortalDestination.appointments;
      _focusAppointmentsSection = true;
    });
  }

  void _openTryOn(Uri uri) {
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => TryOnPage(uri: uri)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = PatientAuthScope.maybeOf(context);
    final isDemoMode = controller?.isDemoMode ?? true;
    final session = controller?.currentSession;

    return PortalShell(
      selectedDestination: _selectedDestination,
      onSelectDestination: _selectDestination,
      isDark: widget.isDark,
      onToggleTheme: widget.onToggleTheme,
      onLogout: widget.onLogout,
      logoutEnabled: widget.logoutEnabled,
      child: switch (_selectedDestination) {
        PortalDestination.dashboard => _DashboardContent(
          onNavigate: _selectDestination,
          onOpenMyAppointments: _openMyAppointments,
          isDemoMode: isDemoMode,
          session: session,
          dashboardAppointments: widget.dashboardAppointments,
          dashboardAppointmentsAsOf: widget.dashboardAppointmentsAsOf,
        ),
        PortalDestination.appointments => BookingPage(
          focusMyAppointments: _focusAppointmentsSection,
        ),
        PortalDestination.appointmentHistory => const AppointmentHistoryPage(),
        PortalDestination.transactionHistory => const TransactionHistoryPage(),
        PortalDestination.framesCatalog => FramesCatalogPage(
          onOpenTryOn: _openTryOn,
        ),
        PortalDestination.supportCenter => const SupportCenterPage(),
        PortalDestination.profile => const ProfilePage(),
      },
    );
  }
}

class _DashboardContent extends StatefulWidget {
  const _DashboardContent({
    required this.onNavigate,
    required this.onOpenMyAppointments,
    required this.isDemoMode,
    required this.session,
    required this.dashboardAppointments,
    required this.dashboardAppointmentsAsOf,
  });

  final ValueChanged<PortalDestination> onNavigate;
  final VoidCallback onOpenMyAppointments;
  final bool isDemoMode;
  final PatientSession? session;
  final List<AppointmentHistoryRecord>? dashboardAppointments;
  final DateTime? dashboardAppointmentsAsOf;

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  PatientAuthController? _controller;
  AppointmentHistoryRepository? _repository;
  List<AppointmentHistoryRecord>? _records;
  bool _isLoading = false;
  String? _errorMessage;
  String? _requestedSessionKey;
  int _loadGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = PatientAuthScope.maybeOf(context);
    final repository = PatientAuthScope.appointmentsHistoryOf(context);
    if (controller != _controller) {
      _controller?.removeListener(_handleSessionChange);
      _controller = controller;
      _controller?.addListener(_handleSessionChange);
      _requestedSessionKey = null;
    }
    if (repository != _repository) {
      _repository = repository;
      _requestedSessionKey = null;
    }
    _loadForCurrentSession();
  }

  @override
  void didUpdateWidget(covariant _DashboardContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dashboardAppointments != oldWidget.dashboardAppointments) {
      _records = widget.dashboardAppointments;
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _controller?.removeListener(_handleSessionChange);
    super.dispose();
  }

  void _handleSessionChange() {
    _requestedSessionKey = null;
    _loadForCurrentSession();
  }

  void _loadForCurrentSession({bool force = false}) {
    // The patient appointment endpoint is not verified to authorize the JWT identity.
    if (!widget.isDemoMode || widget.dashboardAppointments != null) return;

    final repository = _repository;
    if (repository?.isDemo == false) return;
    final session = _controller?.currentSession;
    if (repository == null || repository.isDemo || session == null) {
      if (_isLoading || _errorMessage != null || _records != null) {
        setState(() {
          _loadGeneration++;
          _requestedSessionKey = null;
          _isLoading = false;
          _records = null;
          _errorMessage = null;
        });
      }
      return;
    }

    final sessionKey = '${session.patientId}\u0000${session.token}';
    if (!force && _requestedSessionKey == sessionKey) return;
    _requestedSessionKey = sessionKey;
    _fetchAppointments(repository, session, ++_loadGeneration);
  }

  Future<void> _fetchAppointments(
    AppointmentHistoryRepository repository,
    PatientSession session,
    int generation,
  ) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final records = await repository.getAppointments(
        patientId: session.patientId,
        token: session.token,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _records = records;
        _isLoading = false;
        _errorMessage = null;
      });
    } on ApiFailure catch (failure) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _isLoading = false;
        _errorMessage = failure.message;
      });
    } on Exception catch (error, stackTrace) {
      if (!mounted || generation != _loadGeneration) return;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: StateError(
            'Unexpected dashboard appointment failure (${error.runtimeType}).',
          ),
          stack: stackTrace,
          library: 'patient dashboard appointments',
        ),
      );
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Your appointments could not be loaded. Please try again.';
      });
    }
  }

  Future<void> _refreshAppointments() async {
    _loadForCurrentSession(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final records = widget.dashboardAppointments ?? _records;
    final appointmentSummary = widget.isDemoMode || records == null
        ? null
        : DashboardAppointmentSummary.fromRecords(
            records,
            now: widget.dashboardAppointmentsAsOf ?? DateTime.now(),
          );
    final secondary = Theme.of(context)
        .extension<PatientPortalTextColors>()!
        .secondary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = MediaQuery.sizeOf(context).width;
        final compact = viewportWidth <= PatientPortalBreakpoints.tablet;
        final narrow =
            viewportWidth <= PatientPortalBreakpoints.mobileNavigation;
        final singleColumnActions = viewportWidth <= 550;
        final pagePadding = narrow
            ? viewportWidth <= PatientPortalBreakpoints.mobile
                  ? 17.0
                  : 22.0
            : compact
            ? 25.0
            : 32.0;

        return RefreshIndicator(
          onRefresh: _refreshAppointments,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(pagePadding),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: PatientPortalBreakpoints.contentMaxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Welcome back, ${widget.isDemoMode ? DashboardMockData.patientName : _available(widget.session?.name)}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontSize: narrow ? 26 : 30,
                            height: 1.2,
                            letterSpacing: -1.05,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Manage your appointments and view your clinic '
                            'information from one place.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontSize: 14,
                                  color: secondary,
                                  height: 1.6,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (widget.isDemoMode) const _DemoDataBadge(),
                      ],
                    ),
                    SizedBox(height: narrow ? 20 : 28),
                    _SummaryCards(
                      narrow: narrow,
                      isDemoMode: widget.isDemoMode,
                      session: widget.session,
                      appointmentSummary: appointmentSummary,
                      isLoadingAppointments: _isLoading,
                      hasAppointmentError: _errorMessage != null,
                    ),
                    const SizedBox(height: 20),
                    _MainDashboardCards(
                      compact: compact,
                      onNavigate: widget.onNavigate,
                      isDemoMode: widget.isDemoMode,
                      session: widget.session,
                      appointmentSummary: appointmentSummary,
                      isLoadingAppointments: _isLoading,
                      appointmentError: _errorMessage,
                      onRetryAppointments: _refreshAppointments,
                    ),
                    const SizedBox(height: 22),
                    _QuickActions(
                      narrow: singleColumnActions,
                      compact: compact,
                      onNavigate: widget.onNavigate,
                      onOpenMyAppointments: widget.onOpenMyAppointments,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({
    required this.narrow,
    required this.isDemoMode,
    required this.session,
    required this.appointmentSummary,
    required this.isLoadingAppointments,
    required this.hasAppointmentError,
  });

  final bool narrow;
  final bool isDemoMode;
  final PatientSession? session;
  final DashboardAppointmentSummary? appointmentSummary;
  final bool isLoadingAppointments;
  final bool hasAppointmentError;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useSingleColumn = narrow || constraints.maxWidth < 560;
        final cardWidth = useSingleColumn
            ? constraints.maxWidth
            : (constraints.maxWidth - 32) / 3;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _SummaryCard(
              width: cardWidth,
              icon: Icons.calendar_month_outlined,
              title: 'Upcoming Appointments',
              value: isDemoMode
                  ? DashboardMockData.upcomingAppointmentCount
                  : appointmentSummary?.upcomingCount.toString() ??
                        (isLoadingAppointments
                            ? 'Loading…'
                            : hasAppointmentError
                            ? '—'
                            : 'Unavailable'),
              detail: 'Scheduled visits',
            ),
            _SummaryCard(
              width: cardWidth,
              icon: Icons.event_available_outlined,
              title: 'Last Visit',
              value: isDemoMode ? DashboardMockData.lastVisit : 'Unavailable',
              detail: 'Most recent clinic visit',
            ),
            _SummaryCard(
              width: cardWidth,
              icon: Icons.badge_outlined,
              title: 'Patient ID',
              value: isDemoMode
                  ? DashboardMockData.patientId
                  : _available(session?.patientId),
              detail: 'Your clinic identification number',
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });

  final double width;
  final IconData icon;
  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.extension<PatientPortalTextColors>()!.secondary;

    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _IconTile(icon: icon),
                ],
              ),
              const SizedBox(height: 17),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.44,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MainDashboardCards extends StatelessWidget {
  const _MainDashboardCards({
    required this.compact,
    required this.onNavigate,
    required this.isDemoMode,
    required this.session,
    required this.appointmentSummary,
    required this.isLoadingAppointments,
    required this.appointmentError,
    required this.onRetryAppointments,
  });

  final bool compact;
  final ValueChanged<PortalDestination> onNavigate;
  final bool isDemoMode;
  final PatientSession? session;
  final DashboardAppointmentSummary? appointmentSummary;
  final bool isLoadingAppointments;
  final String? appointmentError;
  final Future<void> Function() onRetryAppointments;

  @override
  Widget build(BuildContext context) {
    const gap = 18.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (compact || constraints.maxWidth < 700) {
          return Column(
            children: [
              _UpcomingAppointmentCard(
                onNavigate: onNavigate,
                isDemoMode: isDemoMode,
                appointmentSummary: appointmentSummary,
                isLoading: isLoadingAppointments,
                errorMessage: appointmentError,
                onRetry: onRetryAppointments,
              ),
              SizedBox(height: gap),
              _PatientInformationCard(isDemoMode: isDemoMode, session: session),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 13,
              child: _UpcomingAppointmentCard(
                onNavigate: onNavigate,
                isDemoMode: isDemoMode,
                appointmentSummary: appointmentSummary,
                isLoading: isLoadingAppointments,
                errorMessage: appointmentError,
                onRetry: onRetryAppointments,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              flex: 7,
              child: _PatientInformationCard(
                isDemoMode: isDemoMode,
                session: session,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _UpcomingAppointmentCard extends StatelessWidget {
  const _UpcomingAppointmentCard({
    required this.onNavigate,
    required this.isDemoMode,
    required this.appointmentSummary,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
  });

  final ValueChanged<PortalDestination> onNavigate;
  final bool isDemoMode;
  final DashboardAppointmentSummary? appointmentSummary;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        final secondary = theme.extension<PatientPortalTextColors>()!.secondary;

        return _SectionCard(
          title: 'Upcoming Appointment',
          subtitle: 'Your next scheduled visit',
          actionLabel: constraints.maxWidth > 400 ? 'View appointments' : null,
          onAction: () => onNavigate(PortalDestination.appointments),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (appointmentSummary?.earliestAppointment
                      case final appointment?) ...[
                    _EmptyAppointmentIcon(color: secondary),
                    const SizedBox(height: 12),
                    Text(
                      formatDashboardAppointmentDate(appointment.scheduledAt!),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (formatDashboardAppointmentTime(appointment.time)
                        case final time?) ...[
                      const SizedBox(height: 5),
                      Text(
                        time,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondary,
                        ),
                      ),
                    ],
                    if (appointment.purpose case final purpose?) ...[
                      const SizedBox(height: 5),
                      Text(
                        purpose,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondary,
                        ),
                      ),
                    ],
                    if (appointment.status case final status?) ...[
                      const SizedBox(height: 5),
                      Text(
                        status,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondary,
                        ),
                      ),
                    ],
                  ] else ...[
                    _EmptyAppointmentIcon(color: secondary),
                    const SizedBox(height: 12),
                    Text(
                      isLoading
                          ? 'Loading appointments…'
                          : errorMessage != null
                          ? 'Appointments could not be loaded'
                          : isDemoMode || appointmentSummary != null
                          ? 'No upcoming appointment'
                          : 'Appointment data unavailable',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isLoading
                          ? 'Retrieving your latest appointment details.'
                          : errorMessage ??
                                (isDemoMode || appointmentSummary != null
                                    ? 'Choose a date and time to schedule your next visit.'
                                    : 'Patient-level appointment access has not been verified.'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: secondary,
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => onRetry(),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                      ),
                    ],
                  ],
                  const SizedBox(height: 15),
                  FilledButton.icon(
                    onPressed: () => onNavigate(PortalDestination.appointments),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Book an appointment'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      textStyle: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyAppointmentIcon extends StatelessWidget {
  const _EmptyAppointmentIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light
            ? const Color(0xFFF8FAFC)
            : const Color(0xFF162238),
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.event_busy_outlined, size: 22, color: color),
    );
  }
}

class _PatientInformationCard extends StatelessWidget {
  const _PatientInformationCard({
    required this.isDemoMode,
    required this.session,
  });

  final bool isDemoMode;
  final PatientSession? session;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Patient Information',
      subtitle: 'Your clinic account details',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          children: [
            _InformationRow(
              label: 'Full name',
              value: isDemoMode
                  ? DashboardMockData.fullName
                  : _available(session?.name),
              isFirst: true,
            ),
            _InformationRow(
              label: 'Patient ID',
              value: isDemoMode
                  ? DashboardMockData.patientId
                  : _available(session?.patientId),
            ),
            _InformationRow(
              label: 'Contact number',
              value: isDemoMode
                  ? DashboardMockData.contactNumber
                  : 'Unavailable',
            ),
            _InformationRow(
              label: 'Email',
              value: isDemoMode
                  ? DashboardMockData.email
                  : _available(session?.email),
            ),
            _InformationRow(
              label: 'Address',
              value: isDemoMode ? DashboardMockData.address : 'Unavailable',
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

String _available(String? value) =>
    value == null || value.trim().isEmpty ? 'Unavailable' : value;

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.label,
    required this.value,
    this.isFirst = false,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context)
        .extension<PatientPortalTextColors>()!
        .secondary;
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(
            top: isFirst ? 0 : 13,
            bottom: isLast ? 0 : 13,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 112,
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  softWrap: true,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: theme.colorScheme.outline),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.narrow,
    required this.compact,
    required this.onNavigate,
    required this.onOpenMyAppointments,
  });

  final bool narrow;
  final bool compact;
  final ValueChanged<PortalDestination> onNavigate;
  final VoidCallback onOpenMyAppointments;

  static const _actions = <_QuickActionData>[
    _QuickActionData(
      title: 'Book an Appointment',
      description: 'Choose a convenient date and time.',
      icon: Icons.add_circle_outline,
      destination: PortalDestination.appointments,
    ),
    _QuickActionData(
      title: 'My Appointments',
      description: 'View your appointment history.',
      icon: Icons.calendar_month_outlined,
      destination: PortalDestination.appointments,
      focusMyAppointments: true,
    ),
    _QuickActionData(
      title: 'Appointment History',
      description: 'View your previous and completed appointments.',
      icon: Icons.history,
      destination: PortalDestination.appointmentHistory,
    ),
    _QuickActionData(
      title: 'Transaction History',
      description: 'View your clinic payments and purchase records.',
      icon: Icons.receipt_long_outlined,
      destination: PortalDestination.transactionHistory,
    ),
    _QuickActionData(
      title: 'Frames Catalog',
      description: 'Browse available frames.',
      icon: Icons.visibility_outlined,
      destination: PortalDestination.framesCatalog,
    ),
    _QuickActionData(
      title: 'My Profile',
      description: 'View your patient information.',
      icon: Icons.person_outline,
      destination: PortalDestination.profile,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Quick Actions',
      subtitle: 'Access the most commonly used patient portal features.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = (constraints.maxWidth - 40)
              .clamp(0.0, constraints.maxWidth)
              .toDouble();
          const spacing = 16.0;
          final columns = narrow || availableWidth < 480
              ? 1
              : compact || availableWidth < 760
              ? 2
              : 4;
          final width = ((availableWidth - spacing * (columns - 1)) / columns)
              .clamp(0.0, availableWidth)
              .toDouble();

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: _actions
                  .map(
                    (action) => SizedBox(
                      width: width,
                      child: _QuickActionCard(
                        action: action,
                        onTap: action.focusMyAppointments
                            ? onOpenMyAppointments
                            : () => onNavigate(action.destination),
                      ),
                    ),
                  )
                  .toList(),
            ),
          );
        },
      ),
    );
  }
}

class _QuickActionData {
  const _QuickActionData({
    required this.title,
    required this.description,
    required this.icon,
    required this.destination,
    this.focusMyAppointments = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final PortalDestination destination;
  final bool focusMyAppointments;
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action, required this.onTap});

  final _QuickActionData action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.extension<PatientPortalTextColors>()!.secondary;

    return Semantics(
      button: true,
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 106),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IconTile(icon: action.icon, size: 36),
                const SizedBox(height: 13),
                Text(
                  action.title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  action.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: secondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.extension<PatientPortalTextColors>()!.secondary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 68,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.24,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: onAction,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        side: BorderSide(color: theme.colorScheme.outline),
                        foregroundColor: secondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                        textStyle: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outline),
          child,
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, this.size = 38});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final background = theme.brightness == Brightness.light
        ? const Color(0xFFEFF6FF)
        : const Color(0xFF122C58);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size == 36 ? 9 : 10),
      ),
      child: Icon(icon, color: primary, size: 20),
    );
  }
}
