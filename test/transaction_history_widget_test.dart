import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_portal_flutter/app/theme.dart';
import 'package:patient_portal_flutter/core/network/api_failure.dart';
import 'package:patient_portal_flutter/features/auth/application/patient_auth_controller.dart';
import 'package:patient_portal_flutter/features/auth/application/patient_auth_scope.dart';
import 'package:patient_portal_flutter/features/auth/data/demo_patient_auth_repository.dart';
import 'package:patient_portal_flutter/features/auth/domain/patient_session.dart';
import 'package:patient_portal_flutter/features/auth/domain/patient_session_store.dart';
import 'package:patient_portal_flutter/features/transaction_history/transaction_history_mock_data.dart';
import 'package:patient_portal_flutter/features/transaction_history/transaction_history_page.dart';
import 'package:patient_portal_flutter/features/transaction_history/transaction_history_repository.dart';

void main() {
  testWidgets(
    'loads authenticated transactions newest-first with 10 per page',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _FakeTransactionRepository(
        List.generate(
          12,
          (index) => TransactionRecord.fromJson({
            'transaction_id': index + 1,
            'invoice_number': 'INV-${index + 1}',
            'created_at': DateTime(2026, 1, index + 1).toIso8601String(),
            'items': [],
          }),
        ),
      );
      final controller = _authenticatedController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: PatientPortalTheme.light,
          home: PatientAuthScope(
            controller: controller,
            transactionHistoryRepository: repository,
            child: const Scaffold(body: TransactionHistoryPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.calls, 1);
      expect(repository.patientId, 'GVC-1601');
      expect(repository.token, 'session-token');
      expect(find.text('Showing 1-10 of 12'), findsOneWidget);
      expect(find.textContaining('Ref: INV-12'), findsOneWidget);
      expect(find.textContaining('Ref: INV-2'), findsNothing);
      expect(find.text('DEMO DATA'), findsNothing);

      await tester.tap(find.text('2').first);
      await tester.pumpAndSettle();
      expect(find.text('Showing 11-12 of 12'), findsOneWidget);
      expect(find.textContaining('Ref: INV-2'), findsOneWidget);
      expect(find.textContaining('Ref: INV-12'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows an API error and retries without claiming success', (
    tester,
  ) async {
    final repository = _FakeTransactionRepository(
      const [],
      failures: [
        const ApiFailure(
          kind: ApiFailureKind.network,
          message: 'Network unavailable.',
        ),
      ],
    );
    final controller = _authenticatedController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: PatientAuthScope(
          controller: controller,
          transactionHistoryRepository: repository,
          child: const Scaffold(body: TransactionHistoryPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to load transaction history'), findsOneWidget);
    expect(find.text('Network unavailable.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No transaction records available'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    expect(find.text('No transaction records available'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('requires an authenticated patient session in API mode', (
    tester,
  ) async {
    final repository = _FakeTransactionRepository(const []);
    final store = InMemoryPatientSessionStore();
    final controller = PatientAuthController(
      repository: const DemoPatientAuthRepository(),
      sessionStore: store,
      isDemoMode: false,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: PatientPortalTheme.light,
        home: PatientAuthScope(
          controller: controller,
          transactionHistoryRepository: repository,
          child: const Scaffold(body: TransactionHistoryPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in required'), findsOneWidget);
    expect(repository.calls, 0);
  });
}

PatientAuthController _authenticatedController() {
  final store = InMemoryPatientSessionStore()
    ..save(
      const PatientSession(
        patientId: 'GVC-1601',
        name: 'Test Patient',
        email: 'patient@example.test',
        token: 'session-token',
        rememberMe: false,
      ),
    );
  return PatientAuthController(
    repository: const DemoPatientAuthRepository(),
    sessionStore: store,
    isDemoMode: false,
  );
}

class _FakeTransactionRepository implements TransactionHistoryRepository {
  _FakeTransactionRepository(this.records, {this.failures = const []});

  final List<TransactionRecord> records;
  final List<ApiFailure> failures;
  var calls = 0;
  String? patientId;
  String? token;

  @override
  bool get isDemo => false;

  @override
  Future<List<TransactionRecord>> getTransactions({
    required String patientId,
    required String token,
  }) async {
    calls++;
    this.patientId = patientId;
    this.token = token;
    if (failures.isNotEmpty) throw failures.removeAt(0);
    return records;
  }
}
