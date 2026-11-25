class DepositReportHeader {
  final int totalEntries;
  final double totalTopUp;
  final double totalUsage;
  final double totalRefund;
  final double totalTopUpRupiah;
  final double totalTopUpKg;
  final double totalUsageRupiah;
  final double totalUsageKg;
  final double totalRefundRupiah;
  final double totalRefundKg;
  final double totalPaidTopUpRupiah;
  final double totalPaidTopUpKg;
  final double totalDiscountRupiah;
  final double totalDiscountKg;
  final int customersActive;
  final double currentRupiah;
  final double currentKg;

  const DepositReportHeader({
    this.totalEntries = 0,
    this.totalTopUp = 0,
    this.totalUsage = 0,
    this.totalRefund = 0,
    this.totalTopUpRupiah = 0,
    this.totalTopUpKg = 0,
    this.totalUsageRupiah = 0,
    this.totalUsageKg = 0,
    this.totalRefundRupiah = 0,
    this.totalRefundKg = 0,
    this.totalPaidTopUpRupiah = 0,
    this.totalPaidTopUpKg = 0,
    this.totalDiscountRupiah = 0,
    this.totalDiscountKg = 0,
    this.customersActive = 0,
    this.currentRupiah = 0,
    this.currentKg = 0,
  });

  factory DepositReportHeader.fromJson(
    Map<String, dynamic> json,
  ) => DepositReportHeader(
    totalEntries: (json['total_entries'] as num?)?.toInt() ?? 0,
    totalTopUp: (json['total_top_up'] as num?)?.toDouble() ?? 0,
    totalUsage: (json['total_usage'] as num?)?.toDouble() ?? 0,
    totalRefund: (json['total_refund'] as num?)?.toDouble() ?? 0,
    totalTopUpRupiah: (json['total_top_up_rupiah'] as num?)?.toDouble() ?? 0,
    totalTopUpKg: (json['total_top_up_kg'] as num?)?.toDouble() ?? 0,
    totalUsageRupiah: (json['total_usage_rupiah'] as num?)?.toDouble() ?? 0,
    totalUsageKg: (json['total_usage_kg'] as num?)?.toDouble() ?? 0,
    totalRefundRupiah: (json['total_refund_rupiah'] as num?)?.toDouble() ?? 0,
    totalRefundKg: (json['total_refund_kg'] as num?)?.toDouble() ?? 0,
    totalPaidTopUpRupiah:
        (json['total_paid_top_up_rupiah'] as num?)?.toDouble() ?? 0,
    totalPaidTopUpKg: (json['total_paid_top_up_kg'] as num?)?.toDouble() ?? 0,
    totalDiscountRupiah:
        (json['total_discount_rupiah'] as num?)?.toDouble() ?? 0,
    totalDiscountKg: (json['total_discount_kg'] as num?)?.toDouble() ?? 0,
    customersActive: (json['customers_active'] as num?)?.toInt() ?? 0,
    currentRupiah: (json['current_rupiah'] as num?)?.toDouble() ?? 0,
    currentKg: (json['current_kg'] as num?)?.toDouble() ?? 0,
  );
}

class DepositReportEntry {
  final String id;
  final String activityType;
  final String depositType;
  final double amount;
  final double paidAmount;
  final double discountAmount;
  final double balanceBefore;
  final double balanceAfter;
  final String customerId;
  final String customerName;
  final String referenceId;
  final String referenceType;
  final String paymentMethod;
  final String note;
  final String createdByName;
  final DateTime? createdAt;

  const DepositReportEntry({
    required this.id,
    required this.activityType,
    required this.depositType,
    required this.amount,
    this.paidAmount = 0,
    this.discountAmount = 0,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.customerId,
    required this.customerName,
    required this.referenceId,
    required this.referenceType,
    required this.paymentMethod,
    required this.note,
    required this.createdByName,
    required this.createdAt,
  });

  factory DepositReportEntry.fromJson(Map<String, dynamic> json) {
    final rawActivity = '${json['activity_type'] ?? json['entry_type'] ?? ''}'
        .trim()
        .toUpperCase();
    final activityType = rawActivity == 'TOPUP' ? 'TOP_UP' : rawActivity;

    return DepositReportEntry(
      id: '${json['id'] ?? ''}',
      activityType: activityType,
      depositType: '${json['deposit_type'] ?? ''}',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      balanceBefore: (json['balance_before'] as num?)?.toDouble() ?? 0,
      balanceAfter: (json['balance_after'] as num?)?.toDouble() ?? 0,
      customerId: '${json['customer_id'] ?? ''}',
      customerName: '${json['customer_name'] ?? 'Tanpa Nama'}',
      referenceId: '${json['reference_id'] ?? ''}',
      referenceType: '${json['reference_type'] ?? ''}',
      paymentMethod: '${json['payment_method'] ?? ''}',
      note: '${json['note'] ?? ''}',
      createdByName: '${json['created_by_name'] ?? 'Sistem'}',
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}')?.toLocal(),
    );
  }
}
