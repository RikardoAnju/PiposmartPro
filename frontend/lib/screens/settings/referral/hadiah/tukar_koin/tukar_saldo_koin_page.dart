import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/data/models/referral_model.dart';
import 'package:ayocucinew/providers/koin_provider.dart';
import 'package:ayocucinew/screens/settings/referral/widgets/referral_empty_state.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'widgets/tukar_header_card.dart';
import 'widgets/tukar_saldo_info_card.dart';
import 'widgets/outlet_selector_dropdown.dart';
import 'widgets/total_koin_display.dart';
import 'widgets/ketentuan_penukaran.dart';
import 'widgets/konfirmasi_penukaran_sheet.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class OutletOption {
  final String id;
  final String name;
  final int currentKoin;

  const OutletOption({
    required this.id,
    required this.name,
    required this.currentKoin,
  });
}

class TukarSaldoKoinPage extends StatefulWidget {
  final int availableBalance;
  final int minNominal;
  final List<OutletOption> outlets;
  final List<ReferralRewardModel> rewards;
  final Future<bool> Function({
    required String outletId,
    required List<int> rewardIds,
    required int jumlahKoin,
  })?
  onConfirm;

  const TukarSaldoKoinPage({
    super.key,
    required this.availableBalance,
    this.minNominal = 25000,
    required this.outlets,
    required this.rewards,
    this.onConfirm,
  });

  @override
  State<TukarSaldoKoinPage> createState() => _TukarSaldoKoinPageState();
}

class _TukarSaldoKoinPageState extends State<TukarSaldoKoinPage> {
  static const Color kPrimary = AppPalette.primary;
  static const Color kBg = Color(0xFFF6F7F9);

  OutletOption? _selectedOutlet;
  final Set<int> _selectedRewardIds = {};
  bool _isSubmitting = false;

  final _fmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String get _saldoDisplay => _fmt.format(widget.availableBalance);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KoinProvider>().fetchEconomyConfig();
    });

    if (widget.outlets.length == 1) {
      _selectedOutlet = widget.outlets.first;
    }
  }

  void _pickOutlet() async {
    if (widget.outlets.isEmpty) return;

    final result = await showModalBottomSheet<OutletOption>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _OutletPickerSheet(outlets: widget.outlets),
    );

    if (result != null) {
      setState(() => _selectedOutlet = result);
    }
  }

  int get _selectedAmount {
    return widget.rewards
        .where((reward) => _selectedRewardIds.contains(reward.id))
        .fold<int>(0, (sum, reward) => sum + reward.rewardAmount);
  }

  List<int> get _selectedIds {
    return widget.rewards
        .where((reward) => _selectedRewardIds.contains(reward.id))
        .map((reward) => reward.id)
        .toList();
  }

  void _toggleReward(ReferralRewardModel reward) {
    setState(() {
      if (_selectedRewardIds.contains(reward.id)) {
        _selectedRewardIds.remove(reward.id);
      } else {
        _selectedRewardIds.add(reward.id);
      }
    });
  }

  void _autoSelectRewards(int rupiahPerKoin) {
    setState(() {
      _selectedRewardIds
        ..clear()
        ..addAll(widget.rewards.map((reward) => reward.id));
    });
  }

  bool _canConfirm(int rupiahPerKoin) {
    return _selectedOutlet != null &&
        rupiahPerKoin > 0 &&
        _selectedIds.isNotEmpty &&
        _selectedAmount >= rupiahPerKoin &&
        _selectedAmount <= widget.availableBalance;
  }

  Future<void> _onKonfirmasi(int rupiahPerKoin) async {
    final totalKoin = rupiahPerKoin > 0
        ? (_selectedAmount ~/ rupiahPerKoin)
        : 0;

    if (!_canConfirm(rupiahPerKoin)) {
      String msg;

      if (_selectedOutlet == null) {
        msg = 'Pilih outlet tujuan terlebih dahulu';
      } else if (rupiahPerKoin <= 0) {
        msg = 'Konversi koin belum tersedia';
      } else if (_selectedIds.isEmpty) {
        msg = 'Pilih bonus referral yang ingin ditukar';
      } else if (_selectedAmount < rupiahPerKoin) {
        msg = 'Minimal penukaran ${_fmt.format(rupiahPerKoin)}';
      } else if (_selectedAmount > widget.availableBalance) {
        msg = 'Saldo tidak mencukupi';
      } else {
        msg = 'Pilihan bonus tidak valid';
      }

      CustomToast.show(context, message: msg, isError: true);
      return;
    }

    final confirmed = await KonfirmasiPenukaranSheet.show(
      context,
      nominalSaldo: _selectedAmount,
      totalKoin: totalKoin,
      outletName: _selectedOutlet!.name,
    );

    if (confirmed == true && mounted) {
      setState(() => _isSubmitting = true);

      final success =
          await widget.onConfirm?.call(
            outletId: _selectedOutlet!.id,
            rewardIds: _selectedIds,
            jumlahKoin: totalKoin,
          ) ??
          true;

      if (!mounted) return;

      setState(() => _isSubmitting = false);

      if (success) {
        CustomToast.show(
          context,
          message: 'Penukaran berhasil diajukan!',
          isError: false,
        );
        Navigator.of(context).maybePop();
      } else {
        CustomToast.show(
          context,
          message: 'Penukaran gagal. Coba lagi.',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final koinProv = context.watch<KoinProvider>();

    final rupiahPerKoin = koinProv.pricePerCoin.toInt();

    final totalKoin = rupiahPerKoin > 0
        ? (_selectedAmount ~/ rupiahPerKoin)
        : 0;

    final conversionInfo =
        'Setiap ${_fmt.format(rupiahPerKoin)} saldo referral = 1 koin';

    return AppScaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black87, size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Referral',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TukarHeaderCard(),

            const SizedBox(height: 16),

            TukarSaldoInfoCard(
              saldo: _saldoDisplay,
              conversionInfo: conversionInfo,
            ),

            const SizedBox(height: 16),

            const Text(
              'Outlet Tujuan*',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 8),

            OutletSelectorDropdown(
              selectedOutletName: _selectedOutlet?.name,
              selectedOutletKoin: _selectedOutlet?.currentKoin,
              onTap: _pickOutlet,
            ),

            const SizedBox(height: 16),

            const Text(
              'Pilih Bonus Referral*',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 12),

            _RewardSelectionHeader(
              count: widget.rewards.length,
              selectedCount: _selectedIds.length,
              selectedAmount: _fmt.format(_selectedAmount),
              onAutoSelect: widget.rewards.isEmpty
                  ? null
                  : () => _autoSelectRewards(rupiahPerKoin),
            ),

            const SizedBox(height: 10),

            if (widget.rewards.isEmpty)
              const _EmptyRewardCard()
            else
              ...widget.rewards.map(
                (reward) => _RewardPickCard(
                  reward: reward,
                  selected: _selectedRewardIds.contains(reward.id),
                  amount: _fmt.format(reward.rewardAmount),
                  onTap: () => _toggleReward(reward),
                ),
              ),

            const SizedBox(height: 12),

            TotalKoinDisplay(totalKoin: totalKoin),

            const SizedBox(height: 12),

            const KetentuanPenukaran(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSubmitting || !_canConfirm(rupiahPerKoin)
                  ? null
                  : () => _onKonfirmasi(rupiahPerKoin),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                disabledBackgroundColor: kPrimary.withValues(alpha: 0.5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      _selectedAmount > 0
                          ? totalKoin > 0
                              ? 'Tukar $totalKoin Koin'
                              : 'Minimal 1 Koin'
                          : 'Pilih Bonus',
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardSelectionHeader extends StatelessWidget {
  final int count;
  final int selectedCount;
  final String selectedAmount;
  final VoidCallback? onAutoSelect;

  const _RewardSelectionHeader({
    required this.count,
    required this.selectedCount,
    required this.selectedAmount,
    required this.onAutoSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$selectedCount dari $count bonus dipilih · $selectedAmount',
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ),
        TextButton(
          onPressed: onAutoSelect,
          style: TextButton.styleFrom(
            foregroundColor: AppPalette.primary,
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          child: const Text(
            'Auto Pilih',
            style: TextStyle(fontSize: 12,),
          ),
        ),
      ],
    );
  }
}

class _RewardPickCard extends StatelessWidget {
  final ReferralRewardModel reward;
  final bool selected;
  final String amount;
  final VoidCallback onTap;

  const _RewardPickCard({
    required this.reward,
    required this.selected,
    required this.amount,
    required this.onTap,
  });

  String get _bonusLabel {
    if (reward.percent > 0) return 'Bonus ${reward.percent}%';
    return reward.type.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppPalette.primary
                  : Colors.black.withValues(alpha: 0.05),
              width: selected ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: selected ? AppPalette.primary : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? AppPalette.primary
                        : Colors.black.withValues(alpha: 0.15),
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reward.outletName.isEmpty || reward.outletName == '-'
                          ? 'Outlet Referral'
                          : reward.outletName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reward.ownerName.isEmpty || reward.ownerName == '-'
                          ? 'Owner referral'
                          : reward.ownerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _RewardChip(label: _bonusLabel),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                amount,
                style: const TextStyle(
                  color: AppPalette.primary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  final String label;

  const _RewardChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppPalette.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppPalette.primary,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _EmptyRewardCard extends StatelessWidget {
  const _EmptyRewardCard();

  @override
  Widget build(BuildContext context) {
    return const ReferralEmptyState(
      icon: Icons.currency_exchange_rounded,
      title: 'Belum ada bonus yang bisa ditukar',
      message:
          'Bonus tersedia akan muncul setelah komisi referral masuk dan belum digunakan.',
      padding: EdgeInsets.fromLTRB(18, 24, 18, 24),
    );
  }
}

class _OutletPickerSheet extends StatelessWidget {
  final List<OutletOption> outlets;

  const _OutletPickerSheet({required this.outlets});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 16),

          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Pilih Outlet',
              style: TextStyle(
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: outlets.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final o = outlets[index];

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).pop(o),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppPalette.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.store_rounded,
                              color: AppPalette.primary,
                              size: 22,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  o.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),

                                const SizedBox(height: 2),

                                Text(
                                  'Koin saat ini: ${o.currentKoin}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
