class TransactionLineItem {
  const TransactionLineItem({
    required this.name,
    this.quantity,
    this.unitPrice,
  });

  final String name;
  final int? quantity;
  final double? unitPrice;

  double? get total =>
      quantity == null || unitPrice == null ? null : quantity! * unitPrice!;

  factory TransactionLineItem.fromJson(Map<String, dynamic> json) {
    final quantity = _optionalInt(json['quantity']);
    final unitPrice = _optionalDouble(json['unit_price']);
    final name = json['item_name'];
    return TransactionLineItem(
      name: name is String && name.trim().isNotEmpty
          ? name.trim()
          : 'Unknown Item',
      quantity: quantity,
      unitPrice: unitPrice,
    );
  }
}

class TransactionRecord {
  const TransactionRecord({
    required this.reference,
    required this.description,
    required this.items,
    required this.status,
    this.dateValue,
    this.subtotal,
    this.vat,
    this.total,
    this.discountName,
    this.discountPercent,
    this.discountAmount,
  });

  factory TransactionRecord.fromJson(Map<String, dynamic> json) {
    final itemsValue = json['items'];
    if (itemsValue != null && itemsValue is! List) {
      throw const FormatException('Invalid transaction items.');
    }
    final items = <TransactionLineItem>[];
    for (final item in (itemsValue as List? ?? const [])) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid transaction item.');
      }
      items.add(TransactionLineItem.fromJson(item));
    }

    final rawDate = json['created_at'] ??
        json['transaction_date'] ??
        json['date'] ??
        json['paid_at'];
    final dateValue = rawDate is String &&
            DateTime.tryParse(rawDate) != null
        ? rawDate
        : null;
    final rawDescription = json['purpose_of_visit'] ??
        json['description'] ??
        json['purpose'] ??
        json['category'];
    final rawStatus =
        json['payment_status'] ?? json['transaction_status'] ?? json['status'];

    return TransactionRecord(
      reference: _firstNonEmptyString([
        json['invoice_number'],
        json['id'],
        json['transaction_id'],
        json['reference_number'],
      ]) ??
          'Not available',
      dateValue: dateValue,
      description: rawDescription is String && rawDescription.trim().isNotEmpty
          ? rawDescription.trim()
          : 'Description unavailable',
      items: items,
      subtotal: _optionalDouble(json['subtotal'] ?? json['sub_total']),
      discountName: _optionalString(json['discount_name']),
      discountPercent: _optionalDouble(
        json['discount_percent'] ?? json['discount_percentage'],
      ),
      discountAmount: _optionalDouble(
        json['discount_amount'] ?? json['discount'],
      ),
      vat: _optionalDouble(json['vat_amount'] ?? json['vat']),
      total: _optionalDouble(
        json['total_amount'] ?? json['amount'] ?? json['total'],
      ),
      status: rawStatus is String && rawStatus.trim().isNotEmpty
          ? rawStatus.trim()
          : 'Unknown',
    );
  }

  final String reference;
  final String? dateValue;
  final String description;
  final List<TransactionLineItem> items;
  final double? subtotal;
  final double? discountAmount;
  final double? discountPercent;
  final String? discountName;
  final double? vat;
  final double? total;
  final String status;

  DateTime? get date => dateValue == null ? null : DateTime.parse(dateValue!);
}

String? _firstNonEmptyString(List<Object?> values) {
  for (final value in values) {
    if (value is! String && value is! num) continue;
    final result = '$value'.trim();
    if (result.isNotEmpty) return result;
  }
  return null;
}

String? _optionalString(Object? value) {
  if (value is! String) return null;
  return value.trim().isEmpty ? null : value.trim();
}

double? _optionalDouble(Object? value) {
  if (value == null) return null;
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  if (number == null || !number.isFinite) {
    return null;
  }
  return number;
}

int? _optionalInt(Object? value) {
  if (value == null) return null;
  final number = value is int ? value : int.tryParse('$value');
  if (number == null) return null;
  return number;
}

class TransactionHistoryMockData {
  const TransactionHistoryMockData._();

  static const transactions = <TransactionRecord>[
    TransactionRecord(
      reference: 'DEMO-TXN-2026-014',
      dateValue: '2026-10-24',
      description: 'Prescription Eyeglasses',
      items: [
        TransactionLineItem(
          name: 'Optical frame',
          quantity: 1,
          unitPrice: 2450,
        ),
        TransactionLineItem(
          name: 'Single-vision lenses',
          quantity: 2,
          unitPrice: 850,
        ),
      ],
      subtotal: 4150,
      discountName: 'Senior Citizen Discount',
      discountPercent: 20,
      discountAmount: 830,
      vat: 398.40,
      total: 3718.40,
      status: 'Paid',
    ),
    TransactionRecord(
      reference: 'DEMO-TXN-2026-013',
      dateValue: '2026-10-18',
      description: 'Comprehensive Eye Examination',
      items: [
        TransactionLineItem(
          name: 'Comprehensive eye examination',
          quantity: 1,
          unitPrice: 1200,
        ),
      ],
      subtotal: 1200,
      vat: 144,
      total: 1344,
      status: 'Paid',
    ),
    TransactionRecord(
      reference: 'DEMO-TXN-2026-012',
      dateValue: '2026-10-12',
      description: 'Contact Lens Purchase',
      items: [
        TransactionLineItem(
          name: 'Daily contact lenses (30-pack)',
          quantity: 2,
          unitPrice: 1350,
        ),
        TransactionLineItem(
          name: 'Multipurpose solution',
          quantity: 1,
          unitPrice: 280,
        ),
      ],
      subtotal: 2980,
      vat: 357.60,
      total: 3337.60,
      status: 'Pending',
    ),
    TransactionRecord(
      reference: 'DEMO-TXN-2026-011',
      dateValue: '2026-10-05',
      description: 'Follow-up Consultation',
      items: [
        TransactionLineItem(
          name: 'Follow-up consultation',
          quantity: 1,
          unitPrice: 500,
        ),
      ],
      subtotal: 500,
      vat: 60,
      total: 560,
      status: 'Paid',
    ),
    TransactionRecord(
      reference: 'DEMO-TXN-2026-010',
      dateValue: '2026-09-28',
      description: 'Prescription Eyeglasses',
      items: [
        TransactionLineItem(
          name: 'Optical frame',
          quantity: 1,
          unitPrice: 1800,
        ),
        TransactionLineItem(
          name: 'Progressive lenses',
          quantity: 2,
          unitPrice: 2200,
        ),
      ],
      subtotal: 6200,
      vat: 744,
      total: 6944,
      status: 'Paid',
    ),
    TransactionRecord(
      reference: 'DEMO-TXN-2026-009',
      dateValue: '2026-09-20',
      description: 'Vision Screening',
      items: [
        TransactionLineItem(
          name: 'Vision screening',
          quantity: 1,
          unitPrice: 650,
        ),
      ],
      subtotal: 650,
      vat: 78,
      total: 728,
      status: 'Voided',
    ),
    TransactionRecord(
      reference: 'DEMO-TXN-2026-008',
      dateValue: '2026-09-12',
      description: 'Contact Lens Consultation',
      items: [
        TransactionLineItem(
          name: 'Contact lens consultation',
          quantity: 1,
          unitPrice: 750,
        ),
      ],
      subtotal: 750,
      vat: 90,
      total: 840,
      status: 'Paid',
    ),
    TransactionRecord(
      reference: 'DEMO-TXN-2026-007',
      dateValue: '2026-09-01',
      description: 'Optical Accessories',
      items: [
        TransactionLineItem(name: 'Eyeglass case', quantity: 1, unitPrice: 180),
        TransactionLineItem(
          name: 'Lens cleaning cloth',
          quantity: 2,
          unitPrice: 50,
        ),
      ],
      subtotal: 280,
      vat: 33.60,
      total: 313.60,
      status: 'Paid',
    ),
    TransactionRecord(
      reference: 'DEMO-TXN-2026-006',
      dateValue: '2026-08-26',
      description: 'Prescription Eyeglasses',
      items: [
        TransactionLineItem(
          name: 'Optical frame',
          quantity: 1,
          unitPrice: 3200,
        ),
        TransactionLineItem(
          name: 'Blue-light lenses',
          quantity: 2,
          unitPrice: 1100,
        ),
      ],
      subtotal: 5400,
      discountName: 'Promotional Discount',
      discountPercent: 10,
      discountAmount: 540,
      vat: 583.20,
      total: 5443.20,
      status: 'Paid',
    ),
    TransactionRecord(
      reference: 'DEMO-TXN-2026-005',
      dateValue: '2026-08-14',
      description: 'Comprehensive Eye Examination',
      items: [
        TransactionLineItem(
          name: 'Comprehensive eye examination',
          quantity: 1,
          unitPrice: 1200,
        ),
      ],
      subtotal: 1200,
      vat: 144,
      total: 1344,
      status: 'Paid',
    ),
    TransactionRecord(
      reference: 'DEMO-TXN-2026-004',
      dateValue: '2026-08-03',
      description: 'Contact Lens Purchase',
      items: [
        TransactionLineItem(
          name: 'Monthly contact lenses',
          quantity: 2,
          unitPrice: 980,
        ),
      ],
      subtotal: 1960,
      vat: 235.20,
      total: 2195.20,
      status: 'Paid',
    ),
    TransactionRecord(
      reference: 'DEMO-TXN-2026-003',
      dateValue: '2026-07-22',
      description: 'Frame Adjustment',
      items: [
        TransactionLineItem(
          name: 'Frame adjustment service',
          quantity: 1,
          unitPrice: 250,
        ),
      ],
      subtotal: 250,
      vat: 30,
      total: 280,
      status: 'Paid',
    ),
  ];
}
