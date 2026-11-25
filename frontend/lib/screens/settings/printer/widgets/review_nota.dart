import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/data/models/setting_nota_model.dart';
import 'package:ayocucinew/providers/setting_nota_provider.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:ayocucinew/shared/widgets/nota_preview_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NotaPreviewPage extends StatelessWidget {
  final NotaSettings? previewSettings;

  const NotaPreviewPage({super.key, this.previewSettings});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text(
          'Preview Struk',
          style: TextStyle(color: Colors.black87, fontSize: 17),
        ),
        backgroundColor: Colors.grey[200],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Consumer<NotaSettingsProvider>(
          builder: (context, provider, _) {
            final nota = previewSettings ?? provider.notaSettings;

            if (nota == null && provider.isLoading) {
              return const NotaPreviewSkeleton();
            }

            if (nota == null && provider.errorMessage != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(provider.errorMessage!),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => provider.fetchNotaSettings(force: true),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              );
            }

            if (nota == null) {
              return const Center(child: Text('Pengaturan nota belum diatur'));
            }

            return _NotaPreviewBody(nota: nota);
          },
        ),
      ),
    );
  }
}

/// Preview struk di setting. WYSIWYG sesungguhnya: dirender dari
/// [NotaPreviewWidget] — widget yang sama persis dipakai saat nota dikirim ke
/// pelanggan — memakai data contoh, jadi bentuknya identik dengan hasil nota
/// asli dan selalu mengikuti pengaturan (nama outlet, alamat, logo, QR, dll).
class _NotaPreviewBody extends StatelessWidget {
  final NotaSettings nota;

  const _NotaPreviewBody({required this.nota});

  static final _now = DateTime.now();
  static final _estSelesai = _now.add(const Duration(days: 2));

  static final List<_DemoItem> _items = [
    _DemoItem(name: 'Cuci Kiloan Reguler (2 Hari)', durasi: '2', durasiSatuan: 'Hari', qty: 2, satuan: 'Kg', hargaSatuan: 6000),
    _DemoItem(name: 'Cuci Kiloan Ekspres (24 Jam)', durasi: '1', durasiSatuan: 'Hari', qty: 2, satuan: 'Kg', hargaSatuan: 12000),
  ];

  static const List<Map<String, dynamic>> _optionalItems = [
    {'service_name': 'Cuci Kiloan Reguler (2 Hari)', 'name': 'Kemeja', 'qty': 2},
    {'service_name': 'Cuci Kiloan Reguler (2 Hari)', 'name': 'Celana Panjang', 'qty': 1, 'keterangan': 'sobek kecil'},
  ];

  static const double _jemputBiaya = 5000;
  static const double _antarBiaya = 5000;
  static const double _discount = 2000;
  static const double _cashAmount = 50000;

  Map<String, dynamic> _demoSnapshot() {
    final subtotal = _items.fold<double>(0, (s, i) => s + i.subtotal);
    final grand = subtotal + _jemputBiaya + _antarBiaya - _discount;
    return {
      'tr_code': 'TRX/25127006',
      'customer_name': 'Grace',
      'tr_userupdate': 'Admin',
      'tr_created': _now.toIso8601String(),
      'catatan': 'Lipat rapi',
      'parfum_nama': 'Bunga Sakura',
      'jemput_alamat': 'Jl. Merdeka No. 12, Jakarta',
      'jemput_biaya': _jemputBiaya,
      'antar_alamat': 'Jl. Sudirman No. 5, Jakarta',
      'antar_biaya': _antarBiaya,
      'details': _items
          .map((i) => {
                'dtr_nama_layanan': i.name,
                'dtr_qty': i.qty,
                'dtr_satuan': i.satuan,
                'dtr_subtotal': i.subtotal,
                'duration': i.durasi,
                'duration_unit': i.durasiSatuan,
                'dtr_ready_at': _estSelesai.toIso8601String(),
              })
          .toList(),
      'optional_items': _optionalItems,
      'tr_subtotal': subtotal,
      'tr_diskon': _discount,
      'tr_rounding': 0,
      'tr_total': grand,
      'tr_dp': 0,
      'tr_sisa': 0,
      'tr_cash': _cashAmount,
      'tr_status_pembayaran': 'Lunas',
      'tr_status_order': 'Antrian',
    };
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _demoSnapshot();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildIllustrationBadge(),
          const SizedBox(height: 16),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: NotaPreviewWidget(
                  snapshot: snapshot,
                  customer: null,
                  nota: nota,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIllustrationBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE6E9ED)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF7C8896)),
          SizedBox(width: 6),
          Text(
            'Data hanya contoh — bentuk mengikuti nota asli',
            style: TextStyle(
              fontSize: 11.5,
              color: Color(0xFF6E7B8B),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoItem {
  final String name;
  final String durasi;
  final String durasiSatuan;
  final int qty;
  final String satuan;
  final double hargaSatuan;

  const _DemoItem({
    required this.name,
    required this.durasi,
    required this.durasiSatuan,
    required this.qty,
    required this.satuan,
    required this.hargaSatuan,
  });

  double get subtotal => qty * hargaSatuan;
}
