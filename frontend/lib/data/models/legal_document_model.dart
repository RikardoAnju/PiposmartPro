class LegalDocumentModel {
  final int id;
  final String type;
  final String title;
  final String effectiveLabel;
  final String body;
  final DateTime? updatedAt;

  const LegalDocumentModel({
    required this.id,
    required this.type,
    required this.title,
    required this.effectiveLabel,
    required this.body,
    this.updatedAt,
  });

  factory LegalDocumentModel.fromJson(Map<String, dynamic> json) {
    return LegalDocumentModel(
      id: json['id'] ?? 0,
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      effectiveLabel: json['effective_label'] ?? '',
      body: json['body'] ?? '',
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }
}
