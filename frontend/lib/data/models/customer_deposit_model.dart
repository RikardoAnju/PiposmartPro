class CustomerDeposit {
  final String id;
  final String customerId;
  final String outletId;
  final double balanceRupiah;
  final double balanceKg;
  CustomerDeposit({
    required this.id,
    required this.customerId,
    required this.outletId,
    required this.balanceRupiah,
    required this.balanceKg,
  });
  factory CustomerDeposit.fromJson(Map<String, dynamic> j) => CustomerDeposit(
    id: '${j['id'] ?? ''}',
    customerId: '${j['customer_id'] ?? ''}',
    outletId: '${j['outlet_id'] ?? ''}',
    balanceRupiah: (j['balance_rupiah'] as num?)?.toDouble() ?? 0,
    balanceKg: (j['balance_kg'] as num?)?.toDouble() ?? 0,
  );
}

class CustomerDepositLedgerEntry {
  final String entryType, depositType, referenceId, note, paymentMethod;
  final String createdBy, createdByName, createdByType;
  final double paidAmount;
  final double discountAmount;
  final double amount, balanceBefore, balanceAfter;
  final DateTime? createdAt;
  CustomerDepositLedgerEntry({
    required this.entryType,
    required this.depositType,
    required this.referenceId,
    required this.note,
    required this.paymentMethod,
    required this.createdBy,
    required this.createdByName,
    required this.createdByType,
    this.paidAmount = 0,
    this.discountAmount = 0,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    this.createdAt,
  });
  factory CustomerDepositLedgerEntry.fromJson(Map<String, dynamic> j) =>
      CustomerDepositLedgerEntry(
        entryType: '${j['entry_type'] ?? ''}',
        depositType: '${j['deposit_type'] ?? ''}',
        referenceId: '${j['reference_id'] ?? ''}',
        note: '${j['note'] ?? ''}',
        paymentMethod: '${j['payment_method'] ?? ''}',
        createdBy: '${j['created_by'] ?? ''}',
        createdByName: '${j['created_by_name'] ?? ''}',
        createdByType: '${j['created_by_type'] ?? ''}',
        paidAmount: (j['paid_amount'] as num?)?.toDouble() ?? 0,
        discountAmount: (j['discount_amount'] as num?)?.toDouble() ?? 0,
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        balanceBefore: (j['balance_before'] as num?)?.toDouble() ?? 0,
        balanceAfter: (j['balance_after'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.tryParse('${j['created_at'] ?? ''}'),
      );
}
