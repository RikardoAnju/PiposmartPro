import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/koin_model.dart';

class DetailHistoryKoinScreen extends StatelessWidget {
  final HistoryKoinModel item;

  const DetailHistoryKoinScreen({super.key, required this.item});

  static const Color _ink = Color(0xFF2D3436);
  static const Color _muted = Color(0xFF9AA5B1);

  @override
  Widget build(BuildContext context) {
    final bool isMasuk = item.jenis == 'masuk';

    final List<Color> gradient = isMasuk
        ? const [Color(0xFF25CC8B), Color(0xFF10A566)]
        : const [Color(0xFFFF6B6B), Color(0xFFE63946)];
    final Color accent = isMasuk
        ? const Color(0xFF10A566)
        : const Color(0xFFE63946);

    final String amount = NumberFormat.decimalPattern('id_ID').format(item.jumlah);
    final String sign = isMasuk ? '+' : '-';

    return AppScaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7F9),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.black,
                size: 14,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text(
          "Detail Mutasi",
          style: TextStyle(
            color: Colors.black,
            fontWeight: AppFont.w800,
            fontSize: 16,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          children: [
            _buildHeroCard(gradient, accent, sign, amount, isMasuk),
            const SizedBox(height: 16),
            _buildDetailsCard(),
            const SizedBox(height: 24),
            SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _ink,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(
                        color: Color(0xFFECEFF3),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: const Text(
                    "Tutup",
                    style: TextStyle(fontWeight: AppFont.w800, fontSize: 15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(
    List<Color> gradient,
    Color accent,
    String sign,
    String amount,
    bool isMasuk,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withValues(alpha: 0.32),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // subtle decorative bubbles
          Positioned(
            top: -30,
            right: -20,
            child: _bubble(90, 0.10),
          ),
          Positioned(
            bottom: -34,
            left: -18,
            child: _bubble(70, 0.08),
          ),
          Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isMasuk
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isMasuk ? "Koin Masuk" : "Koin Keluar",
                style: TextStyle(
                  fontWeight: AppFont.w700,
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    "$sign$amount",
                    style: const TextStyle(
                      fontWeight: AppFont.w900,
                      fontSize: 46,
                      color: Colors.white,
                      letterSpacing: -1,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      "Koin",
                      style: TextStyle(
                        fontWeight: AppFont.w700,
                        fontSize: 18,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: accent,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "Sukses",
                      style: TextStyle(
                        color: accent,
                        fontSize: 11.5,
                        fontWeight: AppFont.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bubble(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildDetailsCard() {
    final parts = item.id.split('/');
    final adminId = parts.length > 1 ? "ID #${parts[1]}" : "-";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Rincian Transaksi",
                style: TextStyle(
                  fontWeight: AppFont.w900,
                  fontSize: 15,
                  color: _ink,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.info_outline_rounded, color: _muted, size: 15),
            ],
          ),
          const SizedBox(height: 8),
          _row(Icons.tag_rounded, "ID Mutasi", item.id),
          _divider(),
          _row(
            Icons.schedule_rounded,
            "Waktu",
            DateFormat('dd MMMM yyyy, HH:mm', 'id_ID')
                .format(item.createdAt.toLocal()),
          ),
          _divider(),
          _row(Icons.badge_outlined, "Admin / System", adminId),
          _divider(),
          _row(
            Icons.description_outlined,
            "Keterangan",
            item.keterangan.isEmpty ? "-" : item.keterangan,
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 14),
    child: Divider(height: 1, thickness: 1, color: Color(0xFFF2F4F7)),
  );

  Widget _row(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: _muted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: AppFont.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: AppFont.w800,
                  fontSize: 13,
                  color: _ink,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
