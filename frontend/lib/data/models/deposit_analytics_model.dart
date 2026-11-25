class DepositAnalytics {
  final double totalTopUpRupiah;
  final double totalTopUpKg;
  final double totalUsageRupiah;
  final double totalUsageKg;
  final double totalRefundRupiah;
  final double totalRefundKg;
  final double totalPaidRupiah;
  final double totalPaidTopUpRupiah;
  final double totalPaidTopUpKg;
  final double totalDiscountRupiah;
  final double totalDiscountKg;
  final double currentRupiah;
  final double currentKg;

  const DepositAnalytics({
    this.totalTopUpRupiah = 0,
    this.totalTopUpKg = 0,
    this.totalUsageRupiah = 0,
    this.totalUsageKg = 0,
    this.totalRefundRupiah = 0,
    this.totalRefundKg = 0,
    this.totalPaidRupiah = 0,
    this.totalPaidTopUpRupiah = 0,
    this.totalPaidTopUpKg = 0,
    this.totalDiscountRupiah = 0,
    this.totalDiscountKg = 0,
    this.currentRupiah = 0,
    this.currentKg = 0,
  });

  factory DepositAnalytics.fromJson(
    Map<String, dynamic> json,
  ) => DepositAnalytics(
    totalTopUpRupiah: (json['total_top_up_rupiah'] as num?)?.toDouble() ?? 0,
    totalTopUpKg: (json['total_top_up_kg'] as num?)?.toDouble() ?? 0,
    totalUsageRupiah: (json['total_usage_rupiah'] as num?)?.toDouble() ?? 0,
    totalUsageKg: (json['total_usage_kg'] as num?)?.toDouble() ?? 0,
    totalRefundRupiah: (json['total_refund_rupiah'] as num?)?.toDouble() ?? 0,
    totalRefundKg: (json['total_refund_kg'] as num?)?.toDouble() ?? 0,
    totalPaidRupiah: (json['total_paid_rupiah'] as num?)?.toDouble() ?? 0,
    totalPaidTopUpRupiah:
        (json['total_paid_top_up_rupiah'] as num?)?.toDouble() ??
        (json['total_paid_rupiah'] as num?)?.toDouble() ??
        0,
    totalPaidTopUpKg: (json['total_paid_top_up_kg'] as num?)?.toDouble() ?? 0,
    totalDiscountRupiah:
        (json['total_discount_rupiah'] as num?)?.toDouble() ?? 0,
    totalDiscountKg: (json['total_discount_kg'] as num?)?.toDouble() ?? 0,
    currentRupiah: (json['current_rupiah'] as num?)?.toDouble() ?? 0,
    currentKg: (json['current_kg'] as num?)?.toDouble() ?? 0,
  );
}
