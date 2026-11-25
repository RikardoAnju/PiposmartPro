import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:provider/provider.dart';
import '../../../providers/koin_provider.dart';
import 'transfer_instruction_screen.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class BankSelectionScreen extends StatefulWidget {
  final int jumlahKoin;
  final double totalBayar;
  final String? kodeVoucher;

  const BankSelectionScreen({
    super.key,
    required this.jumlahKoin,
    required this.totalBayar,
    this.kodeVoucher,
  });

  @override
  State<BankSelectionScreen> createState() => _BankSelectionScreenState();
}

class _BankSelectionScreenState extends State<BankSelectionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<KoinProvider>().fetchBankAccounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final koinProv = context.watch<KoinProvider>();

    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "PILIH BANK TRANSFER",
          style: TextStyle(
            color: Colors.black,
            fontWeight: AppFont.w800,
            fontSize: 14,
          ),
        ),
      ),
      body: koinProv.isLoading
          ? const BankListSkeleton()
          : koinProv.bankAccounts.isEmpty
          ? const Center(
              child: Text(
                "Tidak ada bank tersedia",
                style: TextStyle(fontWeight: AppFont.w700),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: koinProv.bankAccounts.length,
              itemBuilder: (context, index) {
                final bank = koinProv.bankAccounts[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFF1F3F5),
                      width: 2,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppPalette.primaryDeep.withValues(
                        alpha: 0.1,
                      ),
                      child: const Icon(
                        Icons.account_balance_rounded,
                        color: AppPalette.primaryDeep,
                      ),
                    ),
                    title: Text(
                      bank['bank_name'],
                      style: const TextStyle(
                        fontWeight: AppFont.w900,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: const Text(
                      "Konfirmasi Manual",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: AppFont.w700,
                        color: Colors.grey,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      koinProv.selectBank(bank);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TransferInstructionScreen(
                            jumlahKoin: widget.jumlahKoin,
                            totalBayar: widget.totalBayar,
                            kodeVoucher: widget.kodeVoucher,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
