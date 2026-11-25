import 'package:flutter/material.dart';
import 'package:ayocucinew/core/utils/quantity_formatter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_font.dart';
import '../../../core/theme/app_palette.dart';
import '../../../data/models/customer_deposit_model.dart';
import '../../../data/models/customer_model.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/customer_deposit_provider.dart';
import '../../../shared/widgets/app_shimmer.dart';
import '../../../shared/widgets/app_page_bar.dart';
import '../../../shared/widgets/custom_toast.dart';
import '../../report/widgets/report_error_view.dart';
import '../../report/deposit/deposit_analytics_screen.dart';
import 'customer_deposit_history_screen.dart';
import 'customer_deposit_topup_screen.dart';

class CustomerDepositScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDepositScreen({super.key, required this.customer});

  @override
  State<CustomerDepositScreen> createState() => _CustomerDepositScreenState();
}

class _CustomerDepositScreenState extends State<CustomerDepositScreen> {
  String get displayId {
    final raw = widget.customer.id.trim();
    final value = raw.isEmpty ? widget.customer.kode : raw;
    return value.length <= 5 ? value : value.substring(value.length - 5);
  }

  Future<void> _sendBalanceToWhatsApp(CustomerDeposit? balance) async {
    final rupiah = balance?.balanceRupiah ?? 0;
    final kg = balance?.balanceKg ?? 0;
    final outletName = context.read<AppProvider>().outlet?.nama.trim() ?? '';
    final now = DateTime.now();
    final checkedAt =
        '${_twoDigits(now.day)}/${_twoDigits(now.month)}/${now.year}, '
        '${_twoDigits(now.hour)}:${_twoDigits(now.minute)}';
    final message = <String>[
      if (outletName.isNotEmpty) '*$outletName*',
      '*INFORMASI SALDO DEPOSIT*',
      '',
      'Pelanggan: ${widget.customer.name}',
      'Saldo Rupiah: ${_formatRupiah(rupiah)}',
      'Saldo Kiloan: ${formatCompactQuantity(kg)} Kg',
      'Dicek pada: $checkedAt',
      '',
      'Informasi ini menunjukkan saldo saat pesan dibuat.',
    ].join('\n');
    final phone = _normalizeWhatsAppNumber(widget.customer.phone);
    final uri = Uri.https('wa.me', phone.isEmpty ? '/' : '/$phone', {
      'text': message,
    });

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
      await SharePlus.instance.share(ShareParams(text: message));
    } catch (_) {
      if (!mounted) return;
      CustomToast.show(
        context,
        message: 'WhatsApp tidak dapat dibuka.',
        isError: true,
      );
    }
  }

  String _normalizeWhatsAppNumber(String raw) {
    var phone = raw.replaceAll(RegExp(r'\D'), '');
    if (phone.startsWith('0')) phone = '62${phone.substring(1)}';
    if (phone.isNotEmpty && !phone.startsWith('62')) phone = '62$phone';
    return phone;
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<CustomerDepositProvider>().fetch(widget.customer.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: const AppPageBar(title: 'Deposit Pelanggan'),
      body: Consumer<CustomerDepositProvider>(
        builder: (context, provider, _) {
          if (provider.loading && !provider.hasLoaded) {
            return const _CustomerDepositSkeleton();
          }
          if (provider.errorMessage != null && !provider.hasLoaded) {
            return ReportErrorView(
              message: provider.errorMessage!,
              onRetry: () => provider.fetch(widget.customer.id),
              color: AppPalette.primary,
            );
          }
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              14,
              16,
              MediaQuery.viewPaddingOf(context).bottom + 32,
            ),
            children: [
              if (provider.loading) ...[
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: AppPalette.primary,
                  backgroundColor: AppPalette.primaryPale,
                ),
                const SizedBox(height: 12),
              ],
              _buildCustomerCard(provider.balance),
              const SizedBox(height: 16),
              _buildDepositCard(provider.balance),
              const SizedBox(height: 24),
              _buildRecentHeader(),
              const SizedBox(height: 10),
              _buildRecentTransactions(provider.ledger),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DepositAnalyticsScreen(customer: widget.customer),
          ),
        ),
        backgroundColor: AppPalette.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.insights_outlined),
        label: const Text(
          'Analitik',
          style: TextStyle(fontWeight: AppFont.w700),
        ),
      ),
    );
  }

  Widget _buildCustomerCard(CustomerDeposit? balance) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFFFE5DD),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 25,
              color: AppPalette.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.ink,
                    fontSize: 18,
                    height: 1.2,
                    fontWeight: AppFont.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'ID #$displayId',
                  style: const TextStyle(
                    color: AppPalette.muted,
                    fontSize: 13,
                    fontWeight: AppFont.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.customer.phone.trim().isEmpty
                      ? 'No. WA belum diisi'
                      : widget.customer.phone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppPalette.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: widget.customer.phone.trim().isEmpty
                ? 'Pilih kontak dan kirim saldo'
                : 'Kirim saldo via WhatsApp',
            child: InkWell(
              onTap: () => _sendBalanceToWhatsApp(balance),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const FaIcon(
                  FontAwesomeIcons.whatsapp,
                  color: Color(0xFF25D366),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepositCard(dynamic balance) {
    final rupiah = balance?.balanceRupiah ?? 0.0;
    final kg = balance?.balanceKg ?? 0.0;
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppPalette.brandGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                  size: 19,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Saldo Deposit Pelanggan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: AppFont.w700,
                ),
              ),
              const SizedBox(width: 5),
              InkWell(
                onTap: () => _showDepositInfo(context),
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildHeroBalance('Rupiah', _formatRupiah(rupiah)),
              ),
              Container(
                width: 1,
                height: 42,
                color: Colors.white.withValues(alpha: .32),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _buildHeroBalance(
                  'Kiloan',
                  '${formatCompactQuantity(kg)} Kg',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CustomerDepositTopupScreen(customer: widget.customer),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppPalette.primary,
                elevation: 0,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Top Up Deposit',
                style: TextStyle(fontSize: 15, fontWeight: AppFont.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBalance(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: .82),
          fontSize: 12,
          fontWeight: AppFont.w500,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 21,
          height: 1.1,
          fontWeight: AppFont.w800,
        ),
      ),
    ],
  );

  Widget _buildRecentHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Transaksi Terakhir',
          style: TextStyle(
            color: AppPalette.ink,
            fontSize: 18,
            fontWeight: AppFont.w600,
          ),
        ),
        TextButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    CustomerDepositHistoryScreen(customer: widget.customer),
              ),
            );
            if (!mounted) return;
            context.read<CustomerDepositProvider>().fetch(widget.customer.id);
          },
          style: TextButton.styleFrom(
            foregroundColor: AppPalette.primary,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Lihat Riwayat',
            style: TextStyle(fontSize: 14, fontWeight: AppFont.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTransactions(List entries) {
    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 34,
              color: AppPalette.muted,
            ),
            SizedBox(height: 10),
            Text(
              'Belum ada aktivitas deposit',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppPalette.ink,
                fontSize: 14,
                fontWeight: AppFont.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Top up atau pemakaian deposit akan tampil di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppPalette.muted, fontSize: 12),
            ),
          ],
        ),
      );
    }
    final recent = entries.take(3).toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Column(
        children: recent.asMap().entries.map<Widget>((mapped) {
          final entry = mapped.value;
          final isTopUp = entry.entryType == 'TOP_UP';
          final isRefund = entry.entryType == 'REFUND';
          final isCorrection = entry.entryType == 'CORRECTION';
          final signedAmount = isTopUp
              ? entry.amount.abs()
              : isCorrection
              ? entry.amount
              : -entry.amount.abs();
          final amount = entry.depositType == 'KG'
              ? formatCompactQuantity(signedAmount.abs())
              : signedAmount.abs().toStringAsFixed(0);
          final suffix = entry.depositType == 'KG' ? ' Kg' : '';
          final positive = signedAmount >= 0;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minVerticalPadding: 12,
                  leading: _transactionIcon(
                    isTopUp,
                    isRefund,
                    isCorrection,
                    positive,
                  ),
                  title: Text(
                    isTopUp
                        ? 'Top Up Deposit'
                        : isRefund
                        ? 'Pengembalian Deposit'
                        : isCorrection
                        ? 'Koreksi Deposit'
                        : 'Pemakaian Deposit',
                    style: const TextStyle(
                      color: AppPalette.ink,
                      fontSize: 15,
                      fontWeight: AppFont.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${entry.depositType == 'KG' ? 'Deposit Kg' : 'Deposit Rupiah'} • ${_formatDate(entry.createdAt)}\nOleh ${entry.createdByName.isEmpty ? 'Sistem' : entry.createdByName}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppPalette.muted,
                      fontSize: 10,
                    ),
                  ),
                  trailing: Text(
                    '${positive ? '+' : '-'}${entry.depositType == 'KG' ? amount : _formatRupiah(signedAmount.abs())}$suffix',
                    style: TextStyle(
                      color: positive ? AppPalette.success : AppPalette.danger,
                      fontSize: 15,
                      fontWeight: AppFont.w600,
                    ),
                  ),
                ),
                if (mapped.key < recent.length - 1)
                  const Divider(height: 1, color: Color(0xFFE8EDF0)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _transactionIcon(
    bool isTopUp,
    bool isRefund,
    bool isCorrection,
    bool positive,
  ) {
    final color = positive ? AppPalette.success : AppPalette.danger;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isTopUp
            ? Icons.arrow_upward_rounded
            : isRefund
            ? Icons.keyboard_return_rounded
            : isCorrection
            ? Icons.edit_note_rounded
            : Icons.receipt_long_outlined,
        color: color,
        size: 18,
      ),
    );
  }

  String _formatRupiah(double value) {
    final rounded = value.round().toString();
    final groups = <String>[];
    for (var end = rounded.length; end > 0; end -= 3) {
      final start = (end - 3).clamp(0, end);
      groups.insert(0, rounded.substring(start, end));
    }
    return 'Rp${groups.join('.')}';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year}, ${two(local.hour)}:${two(local.minute)}';
  }

  void _showDepositInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: AppPalette.primary),
            SizedBox(width: 8),
            Text('Informasi Deposit'),
          ],
        ),
        content: const Text(
          'Deposit dapat digunakan untuk pembayaran laundry dalam bentuk saldo rupiah atau kiloan.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: FilledButton.styleFrom(backgroundColor: AppPalette.primary),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }
}

class _CustomerDepositSkeleton extends StatelessWidget {
  const _CustomerDepositSkeleton();

  @override
  Widget build(BuildContext context) => AppShimmer(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: const [
        Row(
          children: [
            AppSkeletonBox(width: 48, height: 48, radius: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeletonBox(width: 150, height: 18, radius: 8),
                  SizedBox(height: 8),
                  AppSkeletonBox(width: 110, height: 12, radius: 8),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 18),
        AppSkeletonBox(height: 184, radius: 20),
        SizedBox(height: 26),
        AppSkeletonBox(width: 150, height: 18, radius: 8),
        SizedBox(height: 12),
        AppSkeletonBox(height: 92, radius: 18),
        SizedBox(height: 10),
        AppSkeletonBox(height: 92, radius: 18),
        SizedBox(height: 10),
        AppSkeletonBox(height: 92, radius: 18),
      ],
    ),
  );
}
