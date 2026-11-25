import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

enum RewardActivityMode { hadiah, riwayat }

class RewardActivityItem extends StatelessWidget {
  final RewardActivityMode mode;
  final String? type;
  final String title;
  final String subtitle;
  final String? badge;
  final String amount;
  final String? date;
  final String? status;
  final Color? statusColor;

  const RewardActivityItem._({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.type,
    this.badge,
    this.date,
    this.status,
    this.statusColor,
  });

  factory RewardActivityItem.hadiah({
    required String type,
    required String title,
    required String subtitle,
    required String amount,
    required String date,
    String? badge,
  }) {
    return RewardActivityItem._(
      mode: RewardActivityMode.hadiah,
      type: type,
      title: title,
      subtitle: subtitle,
      amount: amount,
      date: date,
      badge: badge,
    );
  }

  factory RewardActivityItem.riwayat({
    required String type,
    required String title,
    required String subtitle,
    required String amount,
    required String status,
    required Color statusColor,
  }) {
    return RewardActivityItem._(
      mode: RewardActivityMode.riwayat,
      type: type,
      title: title,
      subtitle: subtitle,
      amount: amount,
      status: status,
      statusColor: statusColor,
    );
  }

  String _formatTypeLabel(String value) {
    switch (value.toLowerCase()) {
      case 'payout_request':
      case 'pencairan':
        return 'Pengajuan Pencairan';
      case 'convert_to_koin':
      case 'tukar':
        return 'Tukar Saldo ke Koin';
      case 'reward_owner_recruit':
      case 'reward_recruit':
        return 'Reward Referral';
      case 'reward_topup':
      case 'topup':
        return 'Komisi Top Up Masuk';
      case 'register':
      case 'recruit':
        return 'Referral';
      default:
        return value.replaceAll('_', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = type != null && type!.isNotEmpty
        ? _formatTypeLabel(type!)
        : title;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: null,
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Text(
                            displayTitle,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: AppFont.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (mode == RewardActivityMode.hadiah &&
                            badge != null) ...[
                          const SizedBox(width: 6),
                          _BadgeChip(label: badge!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black45,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (mode == RewardActivityMode.hadiah)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amount,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: AppFont.w700,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (date != null)
                      Text(
                        date!,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black38,
                        ),
                      ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      amount,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: AppFont.w700,
                        color: amount.startsWith('-')
                            ? AppPalette.primary
                            : const Color(0xFF4CAF50),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (status != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor!.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: AppFont.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    final t = (type ?? '').toLowerCase();

    late Color bgColor;
    late Widget iconWidget;

    if (t == 'payout_request' || t == 'pencairan') {
      bgColor = AppPalette.primarySoft;
      iconWidget = const Icon(
        Icons.account_balance_rounded,
        color: AppPalette.primary,
        size: 20,
      );
    } else if (t == 'convert_to_koin' || t == 'tukar') {
      bgColor = const Color(0xFFFFF7E8);
      iconWidget = const Icon(
        Icons.currency_exchange_rounded,
        color: AppPalette.warning,
        size: 20,
      );
    } else if (t == 'register' ||
        t == 'reward_recruit' ||
        t == 'recruit' ||
        t == 'reward_owner_recruit') {
      bgColor = const Color(0xFFEAF2FF);
      iconWidget = const Icon(
        Icons.person_add_alt_1_rounded,
        color: Color(0xFF4A90E2),
        size: 19,
      );
    } else if (t == 'topup' || t == 'reward_topup') {
      bgColor = const Color(0xFFFFF3E6);
      iconWidget = Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: AppPalette.warning,
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 18,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFE58A00),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      );
    } else {
      bgColor = const Color(0xFFF2F2F2);
      iconWidget = const Icon(
        Icons.receipt_long_rounded,
        color: Color(0xFF9E9E9E),
        size: 20,
      );
    }

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: iconWidget),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String label;

  const _BadgeChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: AppFont.w600,
          color: Color(0xFF4CAF50),
        ),
      ),
    );
  }
}
