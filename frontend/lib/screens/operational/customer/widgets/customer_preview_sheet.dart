// lib/screens/operational/customer/widgets/customer_preview_sheet.dart

import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/utils/quantity_formatter.dart';
import '../../../../data/models/customer_model.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/providers/customer_deposit_provider.dart';
import 'package:provider/provider.dart';
import '../customer_deposit_screen.dart';

class CustomerPreviewSheet extends StatelessWidget {
  final Customer customer;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CustomerPreviewSheet({
    super.key,
    required this.customer,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Handle Bar (Indikator geser)
          Container(
            width: 45,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(28, 25, 28, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- HEADER SECTION ---
                Text(
                  customer.name,
                  style: const TextStyle(
                    fontWeight: AppFont.w900,
                    fontSize: 24,
                    color: Color(0xFF2C3E50),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "ID PELANGGAN: #${customer.kode}",
                  style: const TextStyle(
                    color: AppPalette.primary,
                    fontWeight: AppFont.w900,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(height: 1, thickness: 1.2),
                const SizedBox(height: 20),

                // --- DATA DETAIL SECTION ---
                _buildInfoSection("INFORMASI KONTAK", [
                  _buildInfoRow(
                    Icons.phone_iphone_rounded,
                    "WhatsApp",
                    customer.phone.trim().isEmpty
                        ? "No. WA belum diisi"
                        : customer.formattedPhone,
                  ),
                  _buildInfoRow(
                    Icons.location_on_rounded,
                    "Alamat",
                    customer.address.isEmpty
                        ? "Alamat belum diatur"
                        : customer.address,
                  ),
                ]),

                const SizedBox(height: 10),

                _buildInfoSection("PROFIL PELANGGAN", [
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoRow(
                          Icons.wc_rounded,
                          "Jenis Kelamin",
                          customer.genderLong,
                        ),
                      ),
                      Expanded(
                        child: _buildInfoRow(
                          Icons.cake_rounded,
                          "Umur",
                          customer.displayAge,
                        ),
                      ),
                    ],
                  ),
                  _buildInfoRow(
                    Icons.calendar_today_rounded,
                    "Tanggal Lahir",
                    customer.formattedBirthDate,
                  ),
                ]),

                const SizedBox(height: 8),
                Consumer<CustomerDepositProvider>(
                  builder: (context, deposit, _) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7043),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SALDO DEPOSIT',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Rp${deposit.balance?.balanceRupiah.toStringAsFixed(0) ?? '0'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${formatCompactQuantity(deposit.balance?.balanceKg ?? 0)} Kg',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CustomerDepositScreen(customer: customer),
                                ),
                              );
                            },
                            child: const Text('Detail Deposit'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // PADDING BOTTOM EXTRA
                const SizedBox(height: 20),
                if (onEdit != null || onDelete != null)
                  Row(
                    children: [
                      if (onEdit != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onEdit,
                            icon: const Icon(
                              Icons.edit_rounded,
                              size: 18,
                              color: Colors.green,
                            ),
                            label: const Text(
                              'Edit',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: AppFont.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Colors.green),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      if (onEdit != null && onDelete != null)
                        const SizedBox(width: 12),
                      if (onDelete != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onDelete,
                            icon: const Icon(
                              Icons.delete_rounded,
                              size: 18,
                              color: AppPalette.primary,
                            ),
                            label: const Text(
                              'Hapus',
                              style: TextStyle(
                                color: AppPalette.primary,
                                fontWeight: AppFont.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: AppPalette.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 10),
                SafeArea(bottom: true, child: const SizedBox(height: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String sectionTitle, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sectionTitle,
          style: TextStyle(
            color: Colors.blueGrey.shade400,
            fontSize: 12,
            fontWeight: AppFont.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        // Menggunakan center agar ikon berada di tengah tinggi Column teks
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: const Color(0xFF607D8B)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize:
                  MainAxisSize.min, // Agar column tidak memakan ruang berlebih
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize:
                        11, // Sedikit disesuaikan untuk keseimbangan visual
                    fontWeight: AppFont.w800,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ), // Jarak label ke value diperkecil agar sejajar tengah dengan ikon
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight
                        .w600, // Menyesuaikan agar tidak terlalu berat dibanding label
                    color: Color(0xFF263238),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
