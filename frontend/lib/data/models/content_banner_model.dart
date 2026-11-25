class ContentBannerModel {
  final int id;
  final String category;
  final String title;
  final String summary;
  final String body;
  final String voucherCode;
  final String imageUrl;
  final DateTime publishedAt;

  ContentBannerModel({
    required this.id,
    required this.category,
    required this.title,
    required this.summary,
    required this.body,
    required this.voucherCode,
    required this.imageUrl,
    required this.publishedAt,
  });

  factory ContentBannerModel.fromJson(Map<String, dynamic> json) {
    return ContentBannerModel(
      id: json['id'] ?? 0,
      category: json['category'] ?? 'PROMO',
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      body: json['body'] ?? '',
      voucherCode: json['voucher_code'] ?? '',
      imageUrl: json['image_url'] ?? '',
      publishedAt:
          DateTime.tryParse(json['published_at'] ?? '') ?? DateTime.now(),
    );
  }
}
