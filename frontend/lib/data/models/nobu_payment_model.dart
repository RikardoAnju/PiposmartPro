class NobuPaymentModel {
  final String paymentId;
  final String orderId;
  final String qrContent;
  final String qrUrl;
  final String internalStatus;
  final String providerStatus;
  final String? qrExpiredAt;
  final String amountValue;
  final String nmid;
  final String merchantName;
  final String acquirerCode;
  final String paymentReferenceNo;
  final String? paidAt;

  const NobuPaymentModel({
    required this.paymentId,
    required this.orderId,
    required this.qrContent,
    required this.qrUrl,
    required this.internalStatus,
    required this.providerStatus,
    required this.qrExpiredAt,
    required this.amountValue,
    required this.nmid,
    required this.merchantName,
    required this.acquirerCode,
    required this.paymentReferenceNo,
    required this.paidAt,
  });

  factory NobuPaymentModel.fromJson(Map<String, dynamic> json) {
    final payment = (json['payment'] as Map?)?.cast<String, dynamic>() ?? json;
    return NobuPaymentModel(
      paymentId: '${payment['id'] ?? ''}',
      orderId: '${payment['order_id'] ?? ''}',
      qrContent: '${json['qr_content'] ?? payment['qr_content'] ?? ''}',
      qrUrl: '${json['qr_url'] ?? payment['qr_url'] ?? ''}',
      internalStatus: '${payment['internal_status'] ?? ''}',
      providerStatus: '${payment['provider_status'] ?? ''}',
      qrExpiredAt: payment['qr_expired_at']?.toString(),
      amountValue: '${payment['amount_value'] ?? ''}',
      nmid: '${json['nmid'] ?? payment['nmid'] ?? payment['store_id'] ?? ''}',
      merchantName: '${json['merchant_name'] ?? ''}',
      acquirerCode: '${json['acquirer_code'] ?? ''}',
      paymentReferenceNo: '${payment['payment_reference_no'] ?? ''}',
      paidAt: payment['paid_at']?.toString(),
    );
  }

  double get amount => double.tryParse(amountValue) ?? 0;

  DateTime? get paidAtLocal =>
      paidAt == null ? null : DateTime.tryParse(paidAt!)?.toLocal();

  DateTime? get expiredAt => qrExpiredAt == null
      ? null
      : DateTime.tryParse(qrExpiredAt!)?.toLocal();

  bool get isPaid => internalStatus.toUpperCase() == 'PAID';
  bool get isExpired => internalStatus.toUpperCase() == 'EXPIRED';
  bool get isFailed => internalStatus.toUpperCase() == 'FAILED';
  bool get isCancelled => internalStatus.toUpperCase() == 'CANCELLED';
  bool get isWaiting => !isPaid && !isExpired && !isFailed && !isCancelled;
}
