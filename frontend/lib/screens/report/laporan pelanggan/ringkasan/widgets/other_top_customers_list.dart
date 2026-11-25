import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ayocucinew/screens/report/laporan%20pelanggan/ringkasan/widgets/top_customer_podium.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OtherTopCustomersList extends StatelessWidget {
  final List<TopCustomerData> customers;
  final int startRank;

  const OtherTopCustomersList({
    super.key,
    required this.customers,
    this.startRank = 4,
  });

  // Helper untuk mendapatkan nama depan saja
  String _getFirstName(String fullName) {
    final names = fullName.split(' ');
    return names.first;
  }

  // Helper untuk mendapatkan 2 huruf inisial (misal "Adani Haris" -> "AH")
  String _getInitials(String fullName) {
    final names = fullName.trim().split(RegExp(r'\s+'));
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    } else if (names.isNotEmpty && names[0].isNotEmpty) {
      // Jika hanya 1 kata, ambil 2 huruf pertama (misal "Jule" -> "JU")
      final word = names[0];
      return word.length >= 2
          ? word.substring(0, 2).toUpperCase()
          : word[0].toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'RP ',
      decimalDigits: 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PERINGKAT PELANGGAN LAINNYA',
          style: TextStyle(
            fontSize: 12,
            fontWeight: AppFont.w700,
            color: Color(0xFF888888),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        ...customers.asMap().entries.map((entry) {
          final rank = startRank + entry.key;
          final customer = entry.value;
          return _CustomerListTile(
            rank: rank,
            customer: customer,
            currencyFormat: currencyFormat,
            getFirstName: _getFirstName,
            getInitials: _getInitials,
          );
        }),
      ],
    );
  }
}

class _CustomerListTile extends StatelessWidget {
  final int rank;
  final TopCustomerData customer;
  final NumberFormat currencyFormat;
  final Function(String) getFirstName;
  final Function(String) getInitials;

  const _CustomerListTile({
    required this.rank,
    required this.customer,
    required this.currencyFormat,
    required this.getFirstName,
    required this.getInitials,
  });

  @override
  Widget build(BuildContext context) {
    final firstName = getFirstName(customer.name);
    final initials = getInitials(customer.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Row(
        children: [
          // Rank number
          SizedBox(
            width: 24,
            child: Text(
              '#$rank',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: AppFont.w600,
                color: Color(0xFF999999),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Avatar: URL > initial 2 huruf
          _buildCustomerAvatar(size: 44, initials: initials),

          const SizedBox(width: 12),

          // Name + transaksi
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  firstName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: AppFont.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${customer.jumlahTransaksi} Transaksi',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),

          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currencyFormat.format(customer.totalTransaksi),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: AppFont.w700,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(height: 2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerAvatar({
    required double size,
    required String initials,
  }) {
    // Prioritas 1: Avatar URL
    if (customer.avatarUrl != null && customer.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: const Color(0xFFEEEEEE),
        backgroundImage: CachedNetworkImageProvider(customer.avatarUrl!),
        onBackgroundImageError: (exception, stackTrace) {},
      );
    }

    // Fallback: 2 huruf inisial nama
    return _buildInitialsAvatar(size, initials);
  }

  Widget _buildInitialsAvatar(double size, String initials) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFFEEEEEE),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: AppFont.w700,
          color: const Color(0xFF666666),
        ),
      ),
    );
  }
}
