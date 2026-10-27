import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patient_portal_flutter/core/network/api_client.dart';
import 'package:patient_portal_flutter/core/network/api_failure.dart';
import 'package:patient_portal_flutter/features/auth/application/patient_auth_setup.dart';
import 'package:patient_portal_flutter/features/transaction_history/transaction_history_mock_data.dart';
import 'package:patient_portal_flutter/features/transaction_history/transaction_history_repository.dart';

void main() {
  final baseUri = Uri.parse('https://api.example.test');

  test('parses transaction data and nested line items', () {
    final transaction = TransactionRecord.fromJson({
      'transaction_id': 9,
      'invoice_number': 'INV-9',
      'created_at': '2026-10-24T11:30:00Z',
      'purpose_of_visit': 'Eye examination',
      'subtotal': '1200.00',
      'discount_percent': 10,
      'discount_amount': '120',
      'vat_amount': 129.6,
      'total_amount': 1209.6,
      'payment_status': 'Paid',
      'items': [
        {'item_name': 'Exam', 'quantity': '2', 'unit_price': '600'},
      ],
    });

    expect(transaction.reference, 'INV-9');
    expect(transaction.date, DateTime.parse('2026-10-24T11:30:00Z'));
    expect(transaction.description, 'Eye examination');
    expect(transaction.subtotal, 1200);
    expect(transaction.discountPercent, 10);
    expect(transaction.discountAmount, 120);
    expect(transaction.vat, 129.6);
    expect(transaction.total, 1209.6);
    expect(transaction.status, 'Paid');
    expect(transaction.items.single.name, 'Exam');
    expect(transaction.items.single.quantity, 2);
    expect(transaction.items.single.unitPrice, 600);
    expect(transaction.items.single.total, 1200);
  });

  test('preserves missing optional data without fabricated amounts', () {
    final transaction = TransactionRecord.fromJson({
      'transaction_id': 12,
      'created_at': 'not-a-date',
      'items': [
        {'item_name': 'Frame', 'quantity': 'invalid', 'unit_price': null},
      ],
    });

    expect(transaction.date, isNull);
    expect(transaction.subtotal, isNull);
    expect(transaction.vat, isNull);
    expect(transaction.total, isNull);
    expect(transaction.items.single.quantity, isNull);
    expect(transaction.items.single.total, isNull);
  });

  test('requests transactions using the configured URL and string patient ID', () async {
    final requests = <http.Request>[];
    final client = ApiClient(
      baseUri: baseUri,
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'success': true,
            'transactions': [
              {
                'transaction_id': 14,
                'invoice_number': 'INV-14',
                'items': [],
              },
            ],
          }),
          200,
        );
      }),
    );
    addTearDown(client.close);
    final repository = ApiTransactionHistoryRepository(client);

    final records = await repository.getTransactions(
      patientId: 'GVC-1601',
      token: 'test-token',
    );

    expect(records.single.reference, 'INV-14');
    expect(repository.isDemo, isFalse);
    expect(requests.single.method, 'GET');
    expect(
      requests.single.url.path,
      '/api/patients/GVC-1601/transactions',
    );
    expect(requests.single.headers['authorization'], 'Bearer test-token');
  });

  test('accepts empty transactions and rejects malformed envelopes', () async {
    final emptyClient = ApiClient(
      baseUri: baseUri,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'success': true, 'transactions': []}),
          200,
        ),
      ),
    );
    addTearDown(emptyClient.close);
    expect(
      await ApiTransactionHistoryRepository(emptyClient).getTransactions(
        patientId: 'GVC-1601',
        token: 'test-token',
      ),
      isEmpty,
    );

    final invalidClient = ApiClient(
      baseUri: baseUri,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'success': true, 'transactions': {'id': 1}}),
          200,
        ),
      ),
    );
    addTearDown(invalidClient.close);
    await expectLater(
      ApiTransactionHistoryRepository(invalidClient).getTransactions(
        patientId: 'GVC-1601',
        token: 'test-token',
      ),
      throwsA(
        isA<ApiFailure>().having(
          (failure) => failure.kind,
          'kind',
          ApiFailureKind.invalidResponse,
        ),
      ),
    );
  });

  test('maps authentication failures and preserves other request errors', () async {
    final client = ApiClient(
      baseUri: baseUri,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'error': 'Unauthorized'}),
          401,
        ),
      ),
    );
    addTearDown(client.close);
    await expectLater(
      ApiTransactionHistoryRepository(client).getTransactions(
        patientId: 'GVC-1601',
        token: 'expired-token',
      ),
      throwsA(
        isA<ApiFailure>().having(
          (failure) => failure.message,
          'message',
          'Your patient session is invalid or expired. Please sign in again.',
        ),
      ),
    );
  });

  test('demo repository uses local records without creating a client', () async {
    final setup = createPatientAuthSetup(mode: 'demo');
    addTearDown(setup.controller.dispose);
    final records = await setup.transactionHistoryRepository.getTransactions(
      patientId: 'GVC-1601',
      token: '',
    );

    expect(setup.transactionHistoryRepository.isDemo, isTrue);
    expect(records, same(TransactionHistoryMockData.transactions));
  });
}
