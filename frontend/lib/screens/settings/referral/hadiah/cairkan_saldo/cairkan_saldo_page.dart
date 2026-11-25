import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/data/models/referral_model.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/providers/referral_provider.dart';
import 'package:ayocucinew/screens/settings/referral/widgets/referral_empty_state.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'widgets/payout_balance_card.dart';
import 'widgets/payout_account_selector.dart';
import 'widgets/payout_terms_card.dart';
import 'widgets/payout_account_list_sheet.dart';
import 'widgets/payout_account_form_sheet.dart';
import 'widgets/payout_confirmation_sheet.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class CairkanSaldoPage extends StatefulWidget {
  const CairkanSaldoPage({super.key});

  @override
  State<CairkanSaldoPage> createState() => _CairkanSaldoPageState();
}

class _CairkanSaldoPageState extends State<CairkanSaldoPage> {
  static const Color kPrimary = AppPalette.primary;
  static const Color kBg = Color(0xFFF6F7F9);

  ReferralPayoutAccountModel? _selectedAccount;
  List<ReferralPayoutAccountModel> _accounts = [];
  final Set<int> _selectedRewardIds = {};

  bool _loadingAccounts = false;
  bool _confirming = false;

  final _rupiahFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String _fmtRp(int value) => _rupiahFmt.format(value);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAccounts();
    });
  }

  Future<void> _loadAccounts() async {
    setState(() => _loadingAccounts = true);

    try {
      final token = context.read<AuthProvider>().token;
      final list = await context.read<ReferralProvider>().fetchPayoutAccounts(
        token: token,
      );

      if (!mounted) return;

      setState(() {
        _accounts = list;
        if (_selectedAccount == null && list.isNotEmpty) {
          _selectedAccount = list.firstWhere(
            (a) => a.isDefault,
            orElse: () => list.first,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        CustomToast.show(
          context,
          message: 'Gagal memuat rekening',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingAccounts = false);
      }
    }
  }

  void _openAccountSelector() {
    PayoutAccountListSheet.show(
      context,
      accounts: _accounts,
      selected: _selectedAccount,
      onSelect: (account) {
        setState(() => _selectedAccount = account);
      },
      onAddNew: _openAddAccount,
      onEdit: _openEditAccount,
    );
  }

  void _openAddAccount() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PayoutAccountFormPage(
          onSave:
              ({
                required bankName,
                required accountNumber,
                required accountName,
              }) async {
                final token = context.read<AuthProvider>().token;

                final newAccount = await context
                    .read<ReferralProvider>()
                    .createPayoutAccount(
                      bankName: bankName,
                      accountNumber: accountNumber,
                      accountName: accountName,
                      token: token,
                    );

                await _loadAccounts();

                if (!mounted) return;

                setState(() {
                  _selectedAccount = newAccount;
                });

                CustomToast.show(
                  context,
                  message: 'Rekening berhasil ditambahkan',
                  isError: false,
                );
              },
        ),
      ),
    );
  }

  void _openEditAccount(ReferralPayoutAccountModel account) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PayoutAccountFormPage(
          existingAccount: account,
          onSave:
              ({
                required bankName,
                required accountNumber,
                required accountName,
              }) async {
                final token = context.read<AuthProvider>().token;

                final updatedAccount = await context
                    .read<ReferralProvider>()
                    .updatePayoutAccount(
                      accountId: account.id,
                      bankName: bankName,
                      accountNumber: accountNumber,
                      accountName: accountName,
                      token: token,
                    );

                await _loadAccounts();

                if (!mounted) return;

                if (_selectedAccount?.id == account.id) {
                  setState(() {
                    _selectedAccount = updatedAccount;
                  });
                }

                CustomToast.show(
                  context,
                  message: 'Rekening berhasil diperbarui',
                  isError: false,
                );
              },
          onDelete: () async {
            final token = context.read<AuthProvider>().token;

            await context.read<ReferralProvider>().deletePayoutAccount(
              account.id,
              token: token,
            );

            await _loadAccounts();

            if (!mounted) return;

            if (_selectedAccount?.id == account.id) {
              setState(() {
                _selectedAccount = null;
              });
            }

            CustomToast.show(
              context,
              message: 'Rekening berhasil dihapus',
              isError: false,
            );
          },
        ),
      ),
    );
  }

  int _selectedAmount(List<ReferralRewardModel> rewards) {
    return rewards
        .where((reward) => _selectedRewardIds.contains(reward.id))
        .fold<int>(0, (sum, reward) => sum + reward.rewardAmount);
  }

  List<int> _selectedIds(List<ReferralRewardModel> rewards) {
    return rewards
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

  void _autoSelectRewards(List<ReferralRewardModel> rewards, int minAmount) {
    final sorted = [...rewards]
      ..sort((a, b) => a.rewardAmount.compareTo(b.rewardAmount));
    final selected = <int>{};
    var total = 0;

    for (final reward in sorted) {
      selected.add(reward.id);
      total += reward.rewardAmount;
      if (total >= minAmount) break;
    }

    setState(() {
      _selectedRewardIds
        ..clear()
        ..addAll(selected);
    });
  }

  void _onKonfirmasi() {
    final summary = context.read<ReferralProvider>().summary;
    final minAmount = summary?.payoutMinAmount ?? 100000;
    final maxAmount = summary?.payoutMaxAmount ?? 200000;
    final rewards = summary?.availableRewards ?? [];
    final selectedAmount = _selectedAmount(rewards);
    final selectedIds = _selectedIds(rewards);

    if (_selectedAccount == null) {
      CustomToast.show(
        context,
        message: 'Pilih rekening tujuan terlebih dahulu',
        isError: true,
      );
      return;
    }

    if (selectedIds.isEmpty) {
      CustomToast.show(
        context,
        message: 'Pilih bonus referral yang ingin dicairkan',
        isError: true,
      );
      return;
    }

    if (selectedAmount < minAmount) {
      CustomToast.show(
        context,
        message: 'Total bonus terpilih minimal ${_fmtRp(minAmount)}',
        isError: true,
      );
      return;
    }

    if (maxAmount > 0 && selectedAmount > maxAmount) {
      CustomToast.show(
        context,
        message: 'Total bonus terpilih maksimal ${_fmtRp(maxAmount)} bulan ini',
        isError: true,
      );
      return;
    }

    PayoutConfirmationSheet.show(
      context,
      amount: selectedAmount,
      account: _selectedAccount!,
      isLoading: _confirming,
      onConfirm: () => _doConfirm(selectedIds),
    );
  }

  Future<void> _doConfirm(List<int> rewardIds) async {
    if (_confirming) return;

    setState(() => _confirming = true);

    try {
      final token = context.read<AuthProvider>().token;
      final referralProvider = context.read<ReferralProvider>();

      await referralProvider.createPayoutRequest(
        rewardIds: rewardIds,
        payoutAccountId: _selectedAccount!.id,
        token: token,
      );

      if (!mounted) return;

      Navigator.of(context).pop();
      await referralProvider.fetchSummary(token: token);
      if (!mounted) return;

      CustomToast.show(
        context,
        message: 'Pengajuan pencairan berhasil dikirim!',
        isError: false,
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        final message = e.toString();
        if (message.toLowerCase().contains('kuota pencairan mitra')) {
          _showPayoutQuotaDialog(message);
        } else {
          CustomToast.show(context, message: message, isError: true);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _confirming = false);
      }
    }
  }

  void _showPayoutQuotaDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Kuota Pencairan Terpenuhi',
          style: TextStyle(fontSize: 16, fontWeight: AppFont.w700),
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = context.watch<ReferralProvider>().summary;
    final availableBalance = summary?.availableBalance ?? 0;
    final minAmount = summary?.payoutMinAmount ?? 100000;
    final maxAmount = summary?.payoutMaxAmount ?? 200000;
    final rewards = summary?.availableRewards ?? [];
    final selectedAmount = _selectedAmount(rewards);
    final selectedCount = _selectedIds(rewards).length;

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
            fontWeight: AppFont.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PayoutBalanceCard(balance: ''),
            const SizedBox(height: 12),

            PayoutAvailableBalanceCard(balance: _fmtRp(availableBalance)),

            const SizedBox(height: 20),

            _loadingAccounts
                ? const Center(
                    child: CircularProgressIndicator(color: kPrimary),
                  )
                : PayoutAccountSelector(
                    selectedAccount: _selectedAccount,
                    onTap: _openAccountSelector,
                  ),

            const SizedBox(height: 20),

            _RewardSelectionHeader(
              count: rewards.length,
              selectedCount: selectedCount,
              selectedAmount: _fmtRp(selectedAmount),
              onAutoSelect: rewards.isEmpty
                  ? null
                  : () => _autoSelectRewards(rewards, minAmount),
            ),

            const SizedBox(height: 10),

            if (rewards.isEmpty)
              const _EmptyRewardCard()
            else
              ...rewards.map(
                (reward) => _RewardPickCard(
                  reward: reward,
                  selected: _selectedRewardIds.contains(reward.id),
                  amount: _fmtRp(reward.rewardAmount),
                  onTap: () => _toggleReward(reward),
                ),
              ),

            const SizedBox(height: 20),

            PayoutTermsCard(
              terms: [
                'Pilih bonus referral yang ingin dicairkan. Total pilihan minimal ${_fmtRp(minAmount)}.',
                if (maxAmount > 0)
                  'Maksimal pencairan referral per bulan sebesar ${_fmtRp(maxAmount)}.',
                'Bonus yang masuk pengajuan akan berstatus Pending dan tidak bisa dipilih ulang.',
                'Pastikan rekening tujuan sudah benar dan aktif untuk menerima pencairan dana.',
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _confirming || selectedAmount == 0
                  ? null
                  : _onKonfirmasi,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                disabledBackgroundColor: kPrimary.withValues(alpha: 0.5),
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _confirming
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      selectedAmount > 0
                          ? 'Cairkan ${_fmtRp(selectedAmount)}'
                          : 'Pilih Bonus',
                      style: const TextStyle(
                        fontWeight: AppFont.w700,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih Bonus Referral',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: AppFont.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$selectedCount dari $count bonus dipilih · $selectedAmount',
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ],
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
            style: TextStyle(fontSize: 12, fontWeight: AppFont.w700),
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
                        fontWeight: AppFont.w800,
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
                    Row(
                      children: [
                        _RewardChip(label: _bonusLabel),
                        const SizedBox(width: 6),
                        _RewardChip(label: _statusLabel(reward.status)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                amount,
                style: const TextStyle(
                  color: AppPalette.primary,
                  fontSize: 14,
                  fontWeight: AppFont.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _statusLabel(String value) {
    switch (value.toLowerCase().trim()) {
      case 'credited':
      case 'available':
        return 'Siap Cair';
      case 'pending':
        return 'Pending';
      case 'paid':
        return 'Paid';
      default:
        return value;
    }
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
          fontWeight: AppFont.w700,
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
      icon: Icons.account_balance_wallet_rounded,
      title: 'Belum ada bonus yang bisa dicairkan',
      message:
          'Pilih bonus referral yang masih tersedia setelah memenuhi minimum pencairan.',
      padding: EdgeInsets.fromLTRB(18, 24, 18, 24),
    );
  }
}
