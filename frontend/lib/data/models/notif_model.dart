import 'dart:convert';

class NotifModel {
  final int id; // ID dari nr_id (receiver)
  final String masterId;
  final String judul;
  final String pesan;
  final String kategori;
  final String? imageUrl;
  final int status; // 0: Unread, 1: Read
  final DateTime createdAt;
  final String notificationType;
  final String? ctaLabel;
  final int schemaVersion;
  final Map<String, dynamic> payload;

  NotifModel({
    required this.id,
    required this.masterId,
    required this.judul,
    required this.pesan,
    required this.kategori,
    this.imageUrl,
    required this.status,
    required this.createdAt,
    this.notificationType = 'announcement',
    this.ctaLabel,
    this.schemaVersion = 0,
    this.payload = const {},
  });

  factory NotifModel.fromJson(Map<String, dynamic> json) {
    // Karena kita pake Preload("Master"), konten ada di dalam field 'content' atau diratakan
    final master = json['content'] ?? {};
    final payload = _parsePayload(master['payload'] ?? json['payload']);
    return NotifModel(
      id: json['id'] ?? 0,
      masterId: json['master_id'] ?? '',
      judul: master['judul'] ?? json['nt_judul'] ?? '',
      pesan: master['pesan'] ?? json['nt_pesan'] ?? '',
      kategori: master['kategori'] ?? json['nt_kategori'] ?? 'INFO',
      imageUrl: master['image_url'] ?? json['image_url'],
      status: json['status'] ?? 0,
      createdAt: DateTime.parse(
        master['created_at'] ?? json['created_at'] ?? DateTime.now().toString(),
      ).toLocal(),
      notificationType:
          master['type']?.toString() ??
          json['notification_type']?.toString() ??
          'announcement',
      ctaLabel:
          master['cta_label']?.toString() ?? json['cta_label']?.toString(),
      schemaVersion:
          int.tryParse(
            (master['schema_version'] ?? json['schema_version'] ?? 0)
                .toString(),
          ) ??
          0,
      payload: payload,
    );
  }

  static Map<String, dynamic> _parsePayload(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return const {};
  }
}
