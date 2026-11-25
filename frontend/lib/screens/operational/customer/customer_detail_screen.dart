import 'package:flutter/material.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/theme/app_palette.dart';
import '../../../data/models/customer_model.dart';
import '../../../shared/widgets/custom_toast.dart';
import 'manage_customer_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late Customer customer;

  @override
  void initState() {
    super.initState();
    customer = widget.customer;
  }

  String get displayId {
    final raw = customer.id.trim().isEmpty ? customer.kode : customer.id.trim();
    return raw.length <= 5 ? raw : raw.substring(raw.length - 5);
  }

  Future<void> _sendBirthdayGreeting() async {
    final digits = customer.phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      final updated = await Navigator.push<Customer>(
        context,
        MaterialPageRoute(
          builder: (_) => ManageCustomerScreen(existingCustomer: customer),
        ),
      );
      if (mounted && updated != null) setState(() => customer = updated);
      return;
    }
    final phone = digits.startsWith('0')
        ? '62${digits.substring(1)}'
        : digits.startsWith('8')
        ? '62$digits'
        : digits;
    final firstName = customer.name.trim().split(RegExp(r'\s+')).first;
    final uri = Uri.https('wa.me', '/$phone', {
      'text':
          'Selamat ulang tahun, Kak $firstName! 🎉 Semoga sehat, bahagia, dan segala urusannya lancar. Salam hangat dari kami.',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      CustomToast.show(
        context,
        message: 'WhatsApp tidak dapat dibuka.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final systemBottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: AppBar(
        title: const Text('Detail Pelanggan'),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          _profileHeader(),
          if (customer.isBirthdayToday) ...[
            const SizedBox(height: 16),
            _birthdayCard(),
          ],
          const SizedBox(height: 24),
          _informationCard(),
        ],
      ),
      // Keep an explicit visual gap above Android's navigation bar. Some
      // emulator/device configurations report an inset of zero while drawing
      // the system bar on top of the app.
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE8EDF0))),
        ),
        padding: EdgeInsets.fromLTRB(16, 10, 16, 24 + systemBottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (customer.isBirthdayToday) ...[
              ElevatedButton.icon(
                onPressed: _sendBirthdayGreeting,
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: Text(
                  customer.phone.trim().isEmpty
                      ? 'Lengkapi Nomor WhatsApp'
                      : 'Ucapkan via WhatsApp',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            ElevatedButton.icon(
              onPressed: () async {
                final updated = await Navigator.push<Customer>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ManageCustomerScreen(existingCustomer: customer),
                  ),
                );
                if (!mounted || updated == null) return;
                setState(() => customer = updated);
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Pelanggan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _birthdayCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4E8),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFFFD6AE)),
    ),
    child: const Row(
      children: [
        Text('🎂', style: TextStyle(fontSize: 26)),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ulang tahun hari ini',
                style: TextStyle(
                  color: AppPalette.ink,
                  fontSize: 15,
                  fontWeight: AppFont.w700,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Kirim ucapan untuk menjaga hubungan dengan pelanggan.',
                style: TextStyle(color: AppPalette.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _profileHeader() => Row(
    children: [
      Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: Color(0xFFFFE5DD),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.person_rounded,
          color: AppPalette.primary,
          size: 29,
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              customer.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppPalette.ink,
                fontSize: 19,
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
              customer.phone.trim().isEmpty
                  ? 'No. WA belum diisi'
                  : customer.formattedPhone,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppPalette.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _informationCard() => Container(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
    decoration: AppDecorations.card(radius: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: AppPalette.primaryPale,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.badge_outlined,
                color: AppPalette.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Informasi Pelanggan',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: AppFont.w700,
                  color: AppPalette.ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _infoRow(Icons.location_on_outlined, 'Alamat', customer.address),
        _infoRow(Icons.wc_outlined, 'Jenis Kelamin', customer.genderLong),
        _infoRow(Icons.cake_outlined, 'Umur', customer.displayAge),
        _infoRow(
          Icons.calendar_today_outlined,
          'Tanggal Lahir',
          customer.formattedBirthDate,
        ),
        _infoRow(
          Icons.person_add_alt_1_outlined,
          'Terdaftar Sejak',
          customer.formattedRegisteredAt,
        ),
        _infoRow(
          Icons.history_rounded,
          'Transaksi Terakhir',
          customer.formattedLastTransactionAt,
          last: true,
        ),
      ],
    ),
  );

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    bool last = false,
  }) => Padding(
    padding: EdgeInsets.only(bottom: last ? 8 : 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Color(0xFFFFF3EF),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: AppPalette.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 13, color: AppPalette.muted),
              ),
              const SizedBox(height: 2),
              Text(
                value.trim().isEmpty ? 'Belum diisi' : value,
                style: TextStyle(
                  fontSize: 14,
                  color: value.trim().isEmpty
                      ? AppPalette.muted
                      : AppPalette.ink,
                  fontWeight: AppFont.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
