import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/utils/assets_utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TopCustomerData {
  final String name;
  final double totalTransaksi;
  final int jumlahTransaksi;
  final String? avatarUrl;
  final String? iconPath;

  const TopCustomerData({
    required this.name,
    required this.totalTransaksi,
    required this.jumlahTransaksi,
    this.avatarUrl,
    this.iconPath,
  });
}

class TopCustomerPodium extends StatelessWidget {
  final TopCustomerData first;
  final TopCustomerData? second;
  final TopCustomerData? third;

  const TopCustomerPodium({super.key, required this.first, this.second, this.third});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return SizedBox(
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: second == null
                ? const SizedBox()
                : _PodiumItem(
                    customer: second!,
                    rank: 2,
                    avatarSize: 52,
                    nameSize: 11,
                    amountSize: 10,
                    medalAsset: AppImages.icSilver,
                    currencyFormat: currencyFormat,
                  ),
          ),
          Expanded(
            child: _PodiumItem(
              customer: first,
              rank: 1,
              avatarSize: 64,
              nameSize: 12,
              amountSize: 11,
              medalAsset: AppImages.icGold,
              showTrophy: true,
              currencyFormat: currencyFormat,
            ),
          ),
          Expanded(
            child: third == null
                ? const SizedBox()
                : _PodiumItem(
                    customer: third!,
                    rank: 3,
                    avatarSize: 52,
                    nameSize: 11,
                    amountSize: 10,
                    medalAsset: AppImages.icBronze,
                    currencyFormat: currencyFormat,
                  ),
          ),
        ],
      ),
    );
  }
}

class _PodiumItem extends StatelessWidget {
  final TopCustomerData customer;
  final int rank;
  final double avatarSize;
  final double nameSize;
  final double amountSize;
  final String medalAsset; // path ke asset gold/silver/bronze
  final bool showTrophy;
  final NumberFormat currencyFormat;

  const _PodiumItem({
    required this.customer,
    required this.rank,
    required this.avatarSize,
    required this.nameSize,
    required this.amountSize,
    required this.medalAsset,
    required this.currencyFormat,
    this.showTrophy = false,
  });

  // Ambil 2 huruf inisial dari nama lengkap
  String _getInitials(String fullName) {
    final names = fullName.trim().split(RegExp(r'\s+'));
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    } else if (names.isNotEmpty && names[0].isNotEmpty) {
      final word = names[0];
      return word.length >= 2 ? word.substring(0, 2).toUpperCase() : word[0].toUpperCase();
    }
    return '?';
  }

  String _getFirstName(String fullName) {
    return fullName.trim().split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    final firstName = _getFirstName(customer.name);
    final currencyFormat = this.currencyFormat;
    final isFirst = rank == 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Trophy icon hanya untuk rank 1
        if (showTrophy)
          const Icon(Icons.emoji_events, color: Color(0xFFFFA726), size: 28)
        else
          const SizedBox(height: 28),

        const SizedBox(height: 4),

        // Avatar dengan icon asset (gold/silver/bronze)
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Avatar circle — pakai icon asset sebagai gambar utama
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _getBorderColor(), width: isFirst ? 3 : 2),
              ),
              child: ClipOval(
                child: Image.asset(
                  medalAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback ke inisial jika asset tidak ditemukan
                    return _buildInitialsAvatar(avatarSize);
                  },
                ),
              ),
            ),

            // Badge rank di bawah avatar
            Positioned(
              bottom: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _getBadgeColor(), borderRadius: BorderRadius.circular(10)),
                child: Text(
                  '#$rank',
                  style: const TextStyle(fontSize: 10, fontWeight: AppFont.w700, color: Colors.white),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Nama
        Text(
          firstName,
          style: TextStyle(
            fontSize: nameSize,
            fontWeight: isFirst ? AppFont.w700 : AppFont.w600,
            color: isFirst ? const Color(0xFFE65100) : const Color(0xFF333333),
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          softWrap: true,
        ),

        const SizedBox(height: 2),

        // Total transaksi
        Text(
          currencyFormat.format(customer.totalTransaksi),
          style: TextStyle(fontSize: amountSize, fontWeight: AppFont.w600, color: const Color(0xFF555555)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInitialsAvatar(double size) {
    final initials = _getInitials(customer.name);
    return Container(
      color: const Color(0xFFEEEEEE),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(fontSize: size * 0.3, fontWeight: AppFont.w700, color: const Color(0xFF666666)),
      ),
    );
  }

  Color _getBorderColor() {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return const Color(0xFFEEEEEE);
    }
  }

  Color _getBadgeColor() {
    switch (rank) {
      case 1:
        return const Color(0xFFFFA726); // Orange-gold
      case 2:
        return const Color(0xFF9E9E9E); // Grey-silver
      case 3:
        return const Color(0xFFA1634B); // Brown-bronze
      default:
        return const Color(0xFF999999);
    }
  }
}
