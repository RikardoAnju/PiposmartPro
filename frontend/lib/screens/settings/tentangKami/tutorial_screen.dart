import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'dart:convert';

import 'package:ayocucinew/core/utils/api_client.dart';
import 'package:ayocucinew/shared/widgets/app_cached_network_image.dart';
import 'package:ayocucinew/shared/widgets/app_search_field.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen>
    with SingleTickerProviderStateMixin {
  static const _primary = AppPalette.primary;
  static const _ink = Color(0xFF243246);
  static const _muted = Color(0xFF98A1AE);
  static const _surface = Color(0xFFF7F7F8);

  late final TabController _tabController;
  final _searchController = TextEditingController();
  String _selectedCategory = 'Semua';
  String _query = '';

  final List<String> _categories = const [
    'Semua',
    'Transaksi',
    'Laporan',
    'Pelanggan',
    'Outlet',
    'Printer',
    'Koin',
    'Referral',
  ];

  List<TutorialVideo> _videos = const [
    TutorialVideo(
      title: 'Membuat transaksi laundry baru',
      category: 'Transaksi',
      duration: '4 menit',
      summary:
          'Alur membuat pesanan, memilih layanan, mengisi quantity, memilih parfum, dan lanjut pembayaran.',
      lessons: [
        'Pilih pelanggan atau buat pelanggan baru',
        'Tambahkan layanan dan item cucian',
        'Atur parfum, catatan, antar jemput, dan pembayaran',
      ],
      youtubeId: null,
      accentColor: AppPalette.primary,
      videoUrl: null,
    ),
    TutorialVideo(
      title: 'Membaca semua data transaksi',
      category: 'Laporan',
      duration: '3 menit',
      summary:
          'Panduan memakai filter status pesanan, status pembayaran, metode pembayaran, dan periode laporan.',
      lessons: [
        'Pahami total penjualan dan jumlah transaksi',
        'Gunakan filter periode, status, dan metode bayar',
        'Buka detail transaksi dari daftar laporan',
      ],
      youtubeId: null,
      accentColor: AppPalette.primaryWarm,
      videoUrl: null,
    ),
    TutorialVideo(
      title: 'Melihat ringkasan pelanggan',
      category: 'Pelanggan',
      duration: '3 menit',
      summary:
          'Cara membaca pelanggan bertransaksi, pertumbuhan pelanggan baru, dan daftar pelanggan terbaik.',
      lessons: [
        'Lihat total pelanggan yang bertransaksi',
        'Pantau pertumbuhan pelanggan baru per periode',
        'Buka riwayat transaksi tiap pelanggan',
      ],
      youtubeId: null,
      accentColor: Color(0xFF4E9FFF),
      videoUrl: null,
    ),
    TutorialVideo(
      title: 'Mengatur outlet dan layanan',
      category: 'Outlet',
      duration: '5 menit',
      summary:
          'Panduan mengubah profil outlet, layanan, harga, role pegawai, dan konfigurasi dasar operasional.',
      lessons: [
        'Update profil dan lokasi outlet',
        'Kelola layanan, item cucian, parfum, dan diskon',
        'Atur role pegawai sesuai tugas outlet',
      ],
      youtubeId: null,
      accentColor: Color(0xFF23B26D),
      videoUrl: null,
    ),
    TutorialVideo(
      title: 'Menyiapkan printer dan nota',
      category: 'Printer',
      duration: '4 menit',
      summary:
          'Cara menghubungkan printer thermal, preview nota, dan mengatur informasi yang tampil pada struk.',
      lessons: [
        'Hubungkan printer Bluetooth',
        'Atur logo, alamat, dan catatan nota',
        'Tes cetak dan kirim nota digital',
      ],
      youtubeId: null,
      accentColor: Color(0xFF7C6CFF),
      videoUrl: null,
    ),
    TutorialVideo(
      title: 'Top up koin dan aktivasi fitur',
      category: 'Koin',
      duration: '3 menit',
      summary:
          'Cara top up koin, melihat mutasi, membeli addon, dan memahami pemakaian koin operasional.',
      lessons: [
        'Pilih paket koin dan metode pembayaran',
        'Pantau status top up dan mutasi koin',
        'Aktifkan addon sesuai kebutuhan outlet',
      ],
      youtubeId: null,
      accentColor: AppPalette.warning,
      videoUrl: null,
    ),
    TutorialVideo(
      title: 'Menggunakan referral owner',
      category: 'Referral',
      duration: '3 menit',
      summary:
          'Panduan membagikan kode referral, melihat bonus, menukar saldo ke koin, dan mengajukan pencairan.',
      lessons: [
        'Bagikan kode referral ke owner laundry lain',
        'Pantau bonus top up yang tersedia',
        'Pilih bonus untuk ditukar ke koin atau dicairkan',
      ],
      youtubeId: null,
      accentColor: Color(0xFF00A889),
      videoUrl: null,
    ),
  ];

  List<GuideBook> _guides = const [
    GuideBook(
      title: 'Panduan Mulai Operasional',
      category: 'Transaksi',
      description:
          'Checklist awal untuk menyiapkan outlet, layanan, pelanggan, dan transaksi pertama.',
      pageCount: 12,
      updatedLabel: 'Perlu file PDF',
      pdfUrl: null,
      icon: Icons.route_rounded,
    ),
    GuideBook(
      title: 'Panduan Laporan Usaha',
      category: 'Laporan',
      description:
          'Penjelasan istilah laporan transaksi, penjualan, pendapatan, piutang, laba rugi, dan pelanggan.',
      pageCount: 18,
      updatedLabel: 'Perlu file PDF',
      pdfUrl: null,
      icon: Icons.analytics_rounded,
    ),
    GuideBook(
      title: 'Panduan Printer dan Nota',
      category: 'Printer',
      description:
          'Rangkuman pengaturan printer thermal, desain nota, QR nota digital, dan troubleshooting cetak.',
      pageCount: 10,
      updatedLabel: 'Perlu file PDF',
      pdfUrl: null,
      icon: Icons.print_rounded,
    ),
    GuideBook(
      title: 'Panduan Koin dan Referral',
      category: 'Referral',
      description:
          'Alur top up koin, bonus referral, penukaran saldo, pencairan, dan status pengajuan.',
      pageCount: 14,
      updatedLabel: 'Perlu file PDF',
      pdfUrl: null,
      icon: Icons.card_giftcard_rounded,
    ),
  ];

  List<TutorialFaq> _faqs = const [
    TutorialFaq(
      category: 'Transaksi',
      question: 'Kenapa transaksi bisa berstatus DP?',
      answer:
          'Status DP berarti pelanggan sudah membayar sebagian tagihan. Sisa tagihan tetap tercatat sebagai piutang sampai dilunasi.',
    ),
    TutorialFaq(
      category: 'Laporan',
      question:
          'Apa beda penjualan, tagihan setelah diskon, dan uang diterima?',
      answer:
          'Penjualan menunjukkan nilai transaksi yang tercatat pada laporan. Tagihan setelah diskon adalah jumlah yang perlu dibayar pelanggan. Uang diterima adalah pembayaran yang benar-benar masuk, termasuk DP dan pelunasan.',
    ),
    TutorialFaq(
      category: 'Pelanggan',
      question: 'Kenapa pelanggan bertransaksi beda dengan pelanggan baru?',
      answer:
          'Pelanggan bertransaksi menghitung pelanggan yang melakukan pencucian pada periode aktif. Pelanggan baru menghitung pelanggan yang pertama kali dibuat pada periode tersebut.',
    ),
    TutorialFaq(
      category: 'Printer',
      question: 'Apa yang perlu dicek kalau printer tidak cetak?',
      answer:
          'Pastikan printer menyala, sudah pairing Bluetooth, permission aktif, ukuran kertas benar, dan printer dipilih dari pengaturan printer AyoCuci.',
    ),
    TutorialFaq(
      category: 'Koin',
      question: 'Kenapa saldo koin berkurang?',
      answer:
          'Koin dipakai untuk transaksi laundry, addon, atau fitur premium sesuai konfigurasi outlet dan paket aktif.',
    ),
    TutorialFaq(
      category: 'Referral',
      question: 'Kapan bonus referral bisa ditukar atau dicairkan?',
      answer:
          'Bonus bisa dipakai ketika statusnya tersedia. Bonus yang sudah masuk pengajuan akan berubah menjadi menunggu sampai proses selesai.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      final value = _searchController.text.trim().toLowerCase();
      if (value != _query) setState(() => _query = value);
    });
    _loadTutorials();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<TutorialVideo> get _filteredVideos => _videos.where((item) {
    return _matchesFilter(
      category: item.category,
      values: [item.title, item.summary, ...item.lessons],
    );
  }).toList();

  List<GuideBook> get _filteredGuides => _guides.where((item) {
    return _matchesFilter(
      category: item.category,
      values: [item.title, item.description],
    );
  }).toList();

  List<TutorialFaq> get _filteredFaqs => _faqs.where((item) {
    return _matchesFilter(
      category: item.category,
      values: [item.question, item.answer],
    );
  }).toList();

  bool _matchesFilter({
    required String category,
    required List<String> values,
  }) {
    final categoryMatch =
        _selectedCategory == 'Semua' || category == _selectedCategory;
    final queryMatch =
        _query.isEmpty ||
        values.any((value) => value.toLowerCase().contains(_query));
    return categoryMatch && queryMatch;
  }

  Future<void> _loadTutorials() async {
    try {
      final response = await ApiClient.get('/tutorials');
      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final rawItems = decoded['data'];
      if (rawItems is! List || rawItems.isEmpty) return;

      final videos = <TutorialVideo>[];
      final guides = <GuideBook>[];
      final faqs = <TutorialFaq>[];

      for (final raw in rawItems) {
        if (raw is! Map<String, dynamic>) continue;

        final type = _stringValue(raw['type']).toUpperCase();
        final category = _categoryLabel(_stringValue(raw['category']));
        final title = _stringValue(raw['title']);
        final summary = _stringValue(raw['summary']);
        final body = _stringValue(raw['body']);
        final duration = _stringValue(raw['duration']);
        final youtubeId = _stringValue(raw['youtube_id']);
        final videoUrl = _stringValue(raw['video_url']);
        final pdfUrl = _stringValue(raw['pdf_url']);

        if (title.isEmpty) continue;

        if (type == 'VIDEO') {
          videos.add(
            TutorialVideo(
              title: title,
              category: category,
              duration: _formatVideoDuration(duration),
              summary: summary.isEmpty ? body : summary,
              lessons: _buildLessons(body, summary),
              youtubeId: youtubeId.isEmpty ? null : youtubeId,
              accentColor: _categoryColor(category),
              videoUrl: videoUrl.isEmpty ? null : videoUrl,
            ),
          );
        } else if (type == 'GUIDE') {
          guides.add(
            GuideBook(
              title: title,
              category: category,
              description: summary.isEmpty ? body : summary,
              pageCount: 0,
              updatedLabel: pdfUrl.isEmpty ? 'Belum ada PDF' : 'PDF tersedia',
              pdfUrl: pdfUrl.isEmpty ? null : pdfUrl,
              icon: _categoryIcon(category),
            ),
          );
        } else if (type == 'FAQ') {
          faqs.add(
            TutorialFaq(
              category: category,
              question: title,
              answer: body.isEmpty ? summary : body,
            ),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _videos = videos;
        _guides = guides;
        _faqs = faqs;
      });
    } catch (_) {
      // Keep curated fallback content if tutorial API is not ready yet.
    }
  }

  String _stringValue(dynamic value) => value?.toString().trim() ?? '';

  String _formatVideoDuration(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Video';
    if (RegExp(r'^\d+$').hasMatch(trimmed)) return '$trimmed menit';
    return trimmed;
  }

  List<String> _buildLessons(String body, String summary) {
    final lessons = body
        .split(RegExp(r'\r?\n'))
        .map((line) => line.replaceFirst(RegExp(r'^[-•\d.)\s]+'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lessons.isNotEmpty) return lessons.take(5).toList();
    if (summary.trim().isNotEmpty) return [summary.trim()];
    return ['Ikuti panduan sesuai materi tutorial ini.'];
  }

  String _categoryLabel(String value) {
    switch (value.toUpperCase()) {
      case 'TRANSAKSI':
        return 'Transaksi';
      case 'LAPORAN':
        return 'Laporan';
      case 'PELANGGAN':
        return 'Pelanggan';
      case 'OUTLET':
        return 'Outlet';
      case 'PRINTER':
        return 'Printer';
      case 'KOIN':
        return 'Koin';
      case 'REFERRAL':
        return 'Referral';
      default:
        return value.isEmpty ? 'Transaksi' : value;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Laporan':
        return AppPalette.primaryWarm;
      case 'Pelanggan':
        return const Color(0xFF4E9FFF);
      case 'Outlet':
        return const Color(0xFF23B26D);
      case 'Printer':
        return const Color(0xFF7C6CFF);
      case 'Koin':
        return AppPalette.warning;
      case 'Referral':
        return const Color(0xFF00A889);
      default:
        return AppPalette.primary;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Laporan':
        return Icons.analytics_rounded;
      case 'Pelanggan':
        return Icons.group_rounded;
      case 'Outlet':
        return Icons.storefront_rounded;
      case 'Printer':
        return Icons.print_rounded;
      case 'Koin':
        return Icons.paid_rounded;
      case 'Referral':
        return Icons.card_giftcard_rounded;
      default:
        return Icons.route_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tutorial',
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: AppFont.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildTopSection(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildVideoTab(), _buildGuideTab(), _buildFaqTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppPalette.primary, AppPalette.primaryWarm],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pusat Panduan AyoCuci',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: AppFont.w900,
                          height: 1.15,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Cari tutorial operasional, laporan, printer, koin, dan referral.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: AppFont.w600,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppSearchField(
            controller: _searchController,
            onChanged: (_) {},
            onClear: _searchController.clear,
            showClear: _query.isNotEmpty,
            hintText: 'Cari panduan atau pertanyaan',
            height: 48,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = _categories[index];
                final selected = item == _selectedCategory;
                return ChoiceChip(
                  label: Text(item),
                  selected: selected,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _selectedCategory = item),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF6D7480),
                    fontSize: 12,
                    fontWeight: AppFont.w800,
                  ),
                  selectedColor: _primary,
                  backgroundColor: _surface,
                  side: BorderSide(
                    color: selected ? _primary : const Color(0xFFE8EAED),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          labelColor: _primary,
          unselectedLabelColor: _muted,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: AppFont.w900),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: AppFont.w800,
          ),
          tabs: const [
            Tab(text: 'Video'),
            Tab(text: 'Panduan'),
            Tab(text: 'FAQ'),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoTab() {
    final videos = _filteredVideos;
    if (videos.isEmpty) return _buildEmptyState('Video tidak ditemukan');

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      itemCount: videos.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildVideoCard(videos[index]),
    );
  }

  Widget _buildVideoCard(TutorialVideo video) {
    final hasVideo = video.hasVideo;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showVideoDetail(video),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVideoThumb(video, hasVideo),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildMiniChip(video.category, video.accentColor),
                        _buildMiniChip(video.duration, const Color(0xFF6D7480)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      video.title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: AppFont.w900,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      video.summary,
                      style: const TextStyle(
                        color: Color(0xFF8F96A3),
                        fontSize: 12,
                        fontWeight: AppFont.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          hasVideo
                              ? Icons.play_circle_outline_rounded
                              : Icons.schedule_rounded,
                          size: 16,
                          color: hasVideo ? _primary : _muted,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          hasVideo ? 'Tonton video' : 'Video segera hadir',
                          style: TextStyle(
                            color: hasVideo ? _primary : _muted,
                            fontSize: 12,
                            fontWeight: AppFont.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoThumb(TutorialVideo video, bool hasVideo) {
    return Container(
      width: 96,
      height: 76,
      decoration: BoxDecoration(
        color: video.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasVideo)
            AppCachedNetworkImage(
              imageUrl:
                  'https://img.youtube.com/vi/${video.youtubeId}/mqdefault.jpg',
              fit: BoxFit.cover,
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  video.accentColor.withValues(alpha: hasVideo ? 0.1 : 0.95),
                  video.accentColor.withValues(alpha: hasVideo ? 0.35 : 0.72),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasVideo
                    ? Icons.play_arrow_rounded
                    : Icons.video_library_rounded,
                color: video.accentColor,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideTab() {
    final guides = _filteredGuides;
    if (guides.isEmpty) return _buildEmptyState('Panduan tidak ditemukan');

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      itemCount: guides.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildGuideCard(guides[index]),
    );
  }

  Widget _buildGuideCard(GuideBook guide) {
    final hasPdf = guide.pdfUrl != null && guide.pdfUrl!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(guide.icon, color: _primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildMiniChip(guide.category, _primary),
                    _buildMiniChip(
                      guide.pageCount > 0
                          ? '${guide.pageCount} halaman'
                          : (hasPdf ? 'PDF' : 'Panduan'),
                      _muted,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  guide.title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: AppFont.w900,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  guide.description,
                  style: const TextStyle(
                    color: Color(0xFF8F96A3),
                    fontSize: 12,
                    fontWeight: AppFont.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        guide.updatedLabel,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: AppFont.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: hasPdf ? () => _openPdf(guide.pdfUrl!) : null,
                      style: TextButton.styleFrom(
                        foregroundColor: _primary,
                        disabledForegroundColor: _muted,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      icon: Icon(
                        hasPdf
                            ? Icons.open_in_new_rounded
                            : Icons.lock_clock_rounded,
                        size: 16,
                      ),
                      label: Text(
                        hasPdf ? 'Buka PDF' : 'Belum tersedia',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: AppFont.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqTab() {
    final faqs = _filteredFaqs;
    if (faqs.isEmpty) return _buildEmptyState('FAQ tidak ditemukan');

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      itemCount: faqs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _buildFaqCard(faqs[index]),
    );
  }

  Widget _buildFaqCard(TutorialFaq faq) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.hardEdge,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: _primary,
          collapsedIconColor: _muted,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMiniChip(faq.category, _primary),
              const SizedBox(height: 8),
              Text(
                faq.question,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: AppFont.w900,
                  height: 1.25,
                ),
              ),
            ],
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                faq.answer,
                style: const TextStyle(
                  color: Color(0xFF727A86),
                  fontSize: 13,
                  fontWeight: AppFont.w600,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color == _muted ? const Color(0xFF7C8490) : color,
          fontSize: 10,
          fontWeight: AppFont.w900,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: _primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontSize: 16,
                fontWeight: AppFont.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Coba ubah kata pencarian atau pilih kategori lain.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: AppFont.w600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoDetail(TutorialVideo video) {
    final hasVideo = video.hasVideo;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: video.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.play_lesson_rounded,
                        color: video.accentColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildMiniChip(video.category, video.accentColor),
                              _buildMiniChip(video.duration, _muted),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            video.title,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 18,
                              fontWeight: AppFont.w900,
                              height: 1.22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  video.summary,
                  style: const TextStyle(
                    color: Color(0xFF727A86),
                    fontSize: 13,
                    fontWeight: AppFont.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Yang dipelajari',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: AppFont.w900,
                  ),
                ),
                const SizedBox(height: 10),
                ...video.lessons.map(
                  (lesson) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(top: 1),
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: _primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            lesson,
                            style: const TextStyle(
                              color: Color(0xFF606873),
                              fontSize: 13,
                              fontWeight: AppFont.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: hasVideo ? () => _openVideo(video) : null,
                    icon: Icon(
                      hasVideo
                          ? Icons.play_arrow_rounded
                          : Icons.lock_clock_rounded,
                      size: 20,
                    ),
                    label: Text(
                      hasVideo ? 'Tonton Video' : 'Video Segera Hadir',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      disabledBackgroundColor: const Color(0xFFE8EAED),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: _muted,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: AppFont.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openYoutube(String videoId) async {
    final appUrl = Uri.parse('youtube://www.youtube.com/watch?v=$videoId');
    final webUrl = Uri.parse('https://www.youtube.com/watch?v=$videoId');

    if (await canLaunchUrl(appUrl)) {
      await launchUrl(appUrl);
      return;
    }

    if (await canLaunchUrl(webUrl)) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka video')),
      );
    }
  }

  Future<void> _openVideo(TutorialVideo video) async {
    if (video.youtubeId != null && video.youtubeId!.isNotEmpty) {
      await _openYoutube(video.youtubeId!);
      return;
    }

    final url = video.videoUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka video')),
      );
    }
  }

  Future<void> _openPdf(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tidak dapat membuka PDF')));
    }
  }
}

class TutorialVideo {
  final String title;
  final String category;
  final String duration;
  final String summary;
  final List<String> lessons;
  final String? youtubeId;
  final Color accentColor;
  final String? videoUrl;

  bool get hasVideo =>
      (youtubeId != null && youtubeId!.isNotEmpty) ||
      (videoUrl != null && videoUrl!.isNotEmpty);

  const TutorialVideo({
    required this.title,
    required this.category,
    required this.duration,
    required this.summary,
    required this.lessons,
    required this.youtubeId,
    required this.accentColor,
    required this.videoUrl,
  });
}

class GuideBook {
  final String title;
  final String category;
  final String description;
  final int pageCount;
  final String updatedLabel;
  final String? pdfUrl;
  final IconData icon;

  const GuideBook({
    required this.title,
    required this.category,
    required this.description,
    required this.pageCount,
    required this.updatedLabel,
    required this.pdfUrl,
    required this.icon,
  });
}

class TutorialFaq {
  final String category;
  final String question;
  final String answer;

  const TutorialFaq({
    required this.category,
    required this.question,
    required this.answer,
  });
}
