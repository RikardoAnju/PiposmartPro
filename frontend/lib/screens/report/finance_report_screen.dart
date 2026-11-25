import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/providers/laporan_provider.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/screens/report/laba&rugi/laporan_laba_rugi_screen.dart';
import 'package:ayocucinew/screens/report/omset/laporan_omset_screen.dart';
import 'package:ayocucinew/screens/report/pendapatan/laporan_pendapatan_screen.dart';
import 'package:ayocucinew/screens/report/pengeluaran/laporan_pengeluaran_screen.dart';
import 'package:ayocucinew/screens/report/piutang/laporan_piutang_screen.dart';
import 'package:ayocucinew/screens/report/deposit/deposit_report_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'widgets/menu_report_tile.dart';

class FinanceReportScreen extends StatefulWidget {
  const FinanceReportScreen({super.key});

  @override
  State<FinanceReportScreen> createState() => _FinanceReportScreenState();
}

class _FinanceReportScreenState extends State<FinanceReportScreen> {
  Future<void> _navigateTo(Widget Function(String token) builder) async {
    final token =
        await const FlutterSecureStorage().read(key: 'access_token') ?? '';
    if (!mounted) return;

    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesi habis, silakan login ulang')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider(
          create: (_) => LaporanProvider(),
          child: builder(token),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Laporan Keuangan",
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: AppFont.w800,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih Laporan',
              style: TextStyle(fontSize: 16, fontWeight: AppFont.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Buka laporan keuangan sesuai kebutuhan.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            _buildMenuFinance(context),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuFinance(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Column(
      children: [
        MenuReportTile(
          title: "Laporan Penjualan",
          subtitle: "Rincian penjualan per periode",
          image: Image.asset(
            'assets/laporan/ic_omset.webp',
            width: 32,
            height: 32,
          ),
          isLocked: !auth.canReadReportAction('read_omset'),
          onTap: () => _navigateTo((token) => LaporanOmsetScreen(token: token)),
        ),
        MenuReportTile(
          title: "Laporan Pengeluaran",
          subtitle: "Rincian pengeluaran operasional per periode",
          image: Image.asset(
            'assets/laporan/ic_pengeluaran.webp',
            width: 32,
            height: 32,
          ),
          isLocked: !auth.canReadReportAction('read_pengeluaran'),
          onTap: () =>
              _navigateTo((token) => AnalisaLaporanScreen(token: token)),
        ),
        MenuReportTile(
          title: "Laporan Pendapatan",
          subtitle: "Rincian uang masuk per metode pembayaran",
          image: Image.asset(
            'assets/laporan/ic_pendapatan.webp',
            width: 32,
            height: 32,
          ),
          isLocked: !auth.canReadReportAction('read_pendapatan'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LaporanPendapatanScreen(),
              ),
            );
          },
        ),
        MenuReportTile(
          title: "Laporan Deposit",
          subtitle: "Pergerakan saldo deposit pelanggan",
          image: Image.asset(
            'assets/laporan/ic_deposit.webp',
            width: 32,
            height: 32,
          ),
          isLocked: !auth.canReadReportAction('read_pendapatan'),
          onTap: () => _navigateTo((token) => const DepositReportScreen()),
        ),
        MenuReportTile(
          title: "Laporan Piutang Pelanggan",
          subtitle: "Rincian sisa tagihan pelanggan",
          image: Image.asset(
            'assets/laporan/ic_piutang.webp',
            width: 32,
            height: 32,
          ),
          isLocked: !auth.canReadReportAction('read_debt'),
          onTap: () =>
              _navigateTo((token) => LaporanPiutangScreen(token: token)),
        ),
        MenuReportTile(
          title: "Laporan Laba & Rugi",
          subtitle: "Ringkasan laba rugi per periode",
          image: Image.asset(
            'assets/laporan/ic_laba_rugi.webp',
            width: 32,
            height: 32,
          ),
          isLocked: !auth.canReadReportAction('read_profit_loss'),
          onTap: () =>
              _navigateTo((token) => LaporanLabaRugiScreen(token: token)),
        ),
      ],
    );
  }
}
