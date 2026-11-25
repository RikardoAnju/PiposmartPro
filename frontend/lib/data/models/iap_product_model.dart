class IapProductModel {
  final String productId;
  final String productType;
  final int coinAmount;

  const IapProductModel({
    required this.productId,
    required this.productType,
    required this.coinAmount,
  });

  factory IapProductModel.fromJson(Map<String, dynamic> json) {
    return IapProductModel(
      productId: json['product_id']?.toString() ?? '',
      productType: json['product_type']?.toString() ?? '',
      coinAmount: int.tryParse(json['coin_amount']?.toString() ?? '0') ?? 0,
    );
  }
}
