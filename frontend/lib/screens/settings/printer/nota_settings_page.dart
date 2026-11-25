import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:ayocucinew/core/utils/logo_thermal.dart';

import 'package:ayocucinew/core/utils/api_client.dart';
import 'package:ayocucinew/data/models/setting_nota_model.dart';
import 'package:ayocucinew/providers/app_provider.dart';
import 'package:ayocucinew/providers/setting_nota_provider.dart';
import 'package:ayocucinew/screens/settings/printer/widgets/review_nota.dart';
import 'package:ayocucinew/shared/widgets/app_cached_network_image.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class NotaSettingsPage extends StatefulWidget {
  const NotaSettingsPage({super.key});

  @override
  State<NotaSettingsPage> createState() => _NotaSettingsPageState();
}

class _NotaSettingsPageState extends State<NotaSettingsPage> {
  final TextEditingController _footerNoteController = TextEditingController();
  final TextEditingController _whatsappNoteController = TextEditingController();

  bool _isFooterDirty = false;
  bool _isWhatsappDirty = false;
  String _syncedFooterNote = '';
  String _syncedWhatsappNote = '';

  static const Color primaryColor = AppPalette.primary;
  static const Color darkColor = Color(0xFF2C3E50);
  static const Color backgroundColor = Color(0xFFF8F9FA);

  // Template siap-pakai. User cukup tap salah satu untuk mengisi field, lalu
  // tetap bebas mengeditnya. Tambah/kurangi entri di sini bila perlu.
  static const List<String> _printFooterTemplates = [
    'Harap membawa bon ini ketika mengambil pakaian',
    'Barang tidak diambil >30 hari di luar tanggung jawab kami',
    'Komplain maksimal 1x24 jam setelah barang diterima',
    'Simpan nota ini sebagai bukti pengambilan',
  ];

  static const List<String> _whatsappFooterTemplates = [
    'Terima kasih telah menggunakan jasa kami 🙏',
    'Terima Kasih, Datang Lagi ya 😊',
    'Cucian bersih, pelanggan senang 🧺',
    'Kepuasan Anda prioritas kami ✨',
  ];

  bool get _hasDraftChanges => _isFooterDirty || _isWhatsappDirty;

  @override
  void initState() {
    super.initState();
    _footerNoteController.addListener(_handleFooterDraftChanged);
    _whatsappNoteController.addListener(_handleWhatsappDraftChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotaSettingsProvider>().fetchNotaSettings(force: true);
    });
  }

  @override
  void dispose() {
    _footerNoteController
      ..removeListener(_handleFooterDraftChanged)
      ..dispose();
    _whatsappNoteController
      ..removeListener(_handleWhatsappDraftChanged)
      ..dispose();
    super.dispose();
  }

  void _handleFooterDraftChanged() {
    final isDirty = _footerNoteController.text != _syncedFooterNote;
    if (_isFooterDirty == isDirty || !mounted) return;
    setState(() => _isFooterDirty = isDirty);
  }

  void _handleWhatsappDraftChanged() {
    final isDirty = _whatsappNoteController.text != _syncedWhatsappNote;
    if (_isWhatsappDirty == isDirty || !mounted) return;
    setState(() => _isWhatsappDirty = isDirty);
  }

  void _syncDraftFromSettings(NotaSettings? settings, {bool force = false}) {
    if (settings == null) return;

    if (force || !_isFooterDirty) {
      _syncedFooterNote = settings.cnFooterNota;
      _setControllerText(_footerNoteController, settings.cnFooterNota);
    }

    if (force || !_isWhatsappDirty) {
      _syncedWhatsappNote = settings.cnFooterWhatsapp;
      _setControllerText(_whatsappNoteController, settings.cnFooterWhatsapp);
    }
  }

  void _setControllerText(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  String _pickValue(String primary, String fallback) {
    final candidate = primary.trim();
    if (candidate.isNotEmpty) return candidate;
    return fallback.trim();
  }

  bool _hasProfileMismatch({
    required NotaSettings? settings,
    required AppProvider appProvider,
  }) {
    final outlet = appProvider.outlet;
    if (outlet == null) return false;

    final expectedName = outlet.nama.trim();
    final expectedAddress = (outlet.alamat ?? '').trim();
    final expectedPhone = (outlet.noHp ?? '').trim();

    if (settings == null) {
      return expectedName.isNotEmpty ||
          expectedAddress.isNotEmpty ||
          expectedPhone.isNotEmpty;
    }

    return settings.cnNamaOutlet.trim() != expectedName ||
        settings.cnAlamat.trim() != expectedAddress ||
        settings.cnKontak.trim() != expectedPhone;
  }

  Future<void> _saveFooterSettings() async {
    final provider = context.read<NotaSettingsProvider>();
    if (provider.notaSettings == null) {
      await provider.fetchNotaSettings(force: true);
      if (!mounted) return;
    }

    if (provider.notaSettings == null) {
      _showToast('Pengaturan nota belum siap. Coba muat ulang halaman.', false);
      return;
    }

    final result = await provider.updateNotaSettings({
      'cn_footer_nota': _footerNoteController.text.trim(),
      'cn_footer_whatsapp': _whatsappNoteController.text.trim(),
    });

    if (!mounted) return;

    if (result['success'] == true) {
      _syncDraftFromSettings(provider.notaSettings, force: true);
    }

    _showToast(
      result['message'] ?? 'Pengaturan nota berhasil disimpan',
      result['success'] == true,
    );
  }

  Future<void> _handleToggleChange(String fieldName, bool value) async {
    final result = await context.read<NotaSettingsProvider>().toggleField(
      fieldName,
      value,
    );

    if (!mounted) return;

    _showToast(
      result['message'] ??
          (result['success'] == true
              ? 'Pengaturan tampilan berhasil diperbarui'
              : 'Gagal menyimpan perubahan'),
      result['success'] == true,
    );
  }

  Future<void> _handlePrinterSizeChange(int value) async {
    final result = await context.read<NotaSettingsProvider>().updatePrinterSize(
      value,
    );

    if (!mounted) return;

    _showToast(
      result['message'] ??
          (result['success'] == true
              ? 'Ukuran printer berhasil diperbarui'
              : 'Gagal memperbarui ukuran printer'),
      result['success'] == true,
    );
  }

  Future<void> _syncProfileFromOutlet() async {
    final appProvider = context.read<AppProvider>();
    final outlet = appProvider.outlet;

    if (outlet == null) {
      _showToast('Profil outlet belum tersedia. Coba muat ulang data.', false);
      return;
    }

    final result = await context
        .read<NotaSettingsProvider>()
        .updateNotaSettings({
          'cn_nama_outlet': outlet.nama,
          'cn_alamat': outlet.alamat ?? '',
          'cn_kontak': outlet.noHp ?? '',
        });

    if (!mounted) return;

    _showToast(
      result['message'] ?? 'Profil nota berhasil disinkronkan',
      result['success'] == true,
    );
  }

  void _showPreview() {
    final settings = context.read<NotaSettingsProvider>().notaSettings;
    if (settings == null) {
      _showToast('Pengaturan nota belum siap untuk dipreview', false);
      return;
    }

    final previewSettings = settings.copyWith(
      cnFooterNota: _footerNoteController.text.trim(),
      cnFooterWhatsapp: _whatsappNoteController.text.trim(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotaPreviewPage(previewSettings: previewSettings),
      ),
    );
  }

  Future<void> _pickAndUploadNotaLogo() async {
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );

    if (image == null || !mounted) return;

    final imageBytes = await image.readAsBytes();
    if (!mounted) return;

    final File? croppedFile = await Navigator.of(context).push<File?>(
      MaterialPageRoute(
        builder: (_) => _NotaLogoCropScreen(imageBytes: imageBytes),
      ),
    );

    final File? imageFile = croppedFile;
    if (imageFile == null || !mounted) return;

    final result = await context.read<NotaSettingsProvider>().uploadNotaLogo(
      imageFile,
    );

    if (!mounted) return;

    _showToast(
      result['message'] ?? 'Gagal upload logo nota',
      result['success'] == true,
    );
  }

  Future<void> _deleteNotaLogo() async {
    final result = await context.read<NotaSettingsProvider>().deleteNotaLogo();
    if (!mounted) return;

    _showToast(
      result['message'] ?? 'Gagal menghapus logo nota',
      result['success'] == true,
    );
  }

  Future<void> _refreshData() {
    return context.read<NotaSettingsProvider>().fetchNotaSettings(force: true);
  }

  void _showToast(String message, bool isSuccess) {
    if (!mounted) return;

    CustomToast.show(
      context,
      message: message,
      isError: !isSuccess,
      duration: Duration(seconds: isSuccess ? 2 : 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<NotaSettingsProvider, AppProvider>(
      builder: (context, provider, appProvider, _) {
        final settings = provider.notaSettings;
        _syncDraftFromSettings(settings);

        final outlet = appProvider.outlet;
        final outletName = _pickValue(
          settings?.cnNamaOutlet ?? '',
          outlet?.nama ?? '',
        );
        final outletAddress = _pickValue(
          settings?.cnAlamat ?? '',
          outlet?.alamat ?? '',
        );
        final outletPhone = _pickValue(
          settings?.cnKontak ?? '',
          outlet?.noHp ?? '',
        );
        final printerSize = settings?.cnUkuran ?? 58;
        final showProfileSync = _hasProfileMismatch(
          settings: settings,
          appProvider: appProvider,
        );

        final bottomSafeArea = MediaQuery.paddingOf(context).bottom;

        return AppScaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            title: const Text(
              'Format Nota',
              style: TextStyle(
                color: darkColor,
                fontWeight: AppFont.w800,
                fontSize: 16,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: darkColor,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: provider.isLoading && settings == null
              ? const SettingsFormSkeleton()
              : RefreshIndicator(
                  onRefresh: _refreshData,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      bottomSafeArea + 28,
                    ),
                    children: [
                      if (provider.errorMessage != null && settings == null)
                        _buildErrorState(provider.errorMessage!),
                      if (provider.errorMessage == null ||
                          settings != null) ...[
                        _buildSectionTitle(
                          'Profil Nota',
                          showProfileSync
                              ? 'Info outlet di nota belum sinkron. Anda bisa tarik ulang dari profil outlet.'
                              : 'Info outlet yang tampil di nota mengikuti profil outlet aktif.',
                        ),
                        if (showProfileSync)
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: provider.isBusy
                                    ? null
                                    : _syncProfileFromOutlet,
                                icon: provider.isBusy
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: primaryColor,
                                        ),
                                      )
                                    : const Icon(Icons.sync_rounded, size: 16),
                                label: const Text(
                                  'Sinkronkan dari profil outlet',
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: primaryColor,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 0,
                                    vertical: 0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        _buildCardWrapper(
                          child: Column(
                            children: [
                              _buildModernReadOnlyField(
                                Icons.storefront_rounded,
                                'Nama Outlet',
                                outletName,
                              ),
                              const Divider(
                                height: 1,
                                indent: 40,
                                color: Color(0xFFF1F3F5),
                              ),
                              _buildModernReadOnlyField(
                                Icons.location_on_rounded,
                                'Alamat Outlet',
                                outletAddress,
                              ),
                              const Divider(
                                height: 1,
                                indent: 40,
                                color: Color(0xFFF1F3F5),
                              ),
                              _buildModernReadOnlyField(
                                Icons.phone_rounded,
                                'Nomor Kontak',
                                outletPhone,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSectionTitle(
                          'Pesan Footer',
                          'Edit isi footer cetak dan WhatsApp. Perubahan di area ini disimpan saat Anda menekan tombol simpan.',
                        ),
                        _buildCardWrapper(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildModernMultilineField(
                                label: 'Footer Nota (Cetak)',
                                controller: _footerNoteController,
                                hint:
                                    'Harap membawa bon ini ketika mengambil pakaian',
                                icon: Icons.receipt_long_rounded,
                                templates: _printFooterTemplates,
                              ),
                              const Divider(
                                height: 1,
                                indent: 40,
                                color: Color(0xFFF1F3F5),
                              ),
                              _buildModernMultilineField(
                                label: 'Footer Nota (WhatsApp)',
                                controller: _whatsappNoteController,
                                hint:
                                    'Terima kasih telah menggunakan jasa kami.',
                                icon: Icons.message_rounded,
                                templates: _whatsappFooterTemplates,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSectionTitle(
                          'Konfigurasi Tampilan',
                          'Toggle dan ukuran kertas tersimpan otomatis. Perubahan footer tidak ikut tersimpan sampai Anda menekan simpan.',
                        ),
                        _buildStatusBanner(),
                        const SizedBox(height: 12),
                        _buildCardWrapper(
                          child: Column(
                            children: [
                              _buildModernToggle(
                                'Tampilkan Logo',
                                settings?.cnSettLogo ?? false,
                                provider.isInlineSaving
                                    ? null
                                    : (value) => _handleToggleChange(
                                        'cn_sett_logo',
                                        value,
                                      ),
                              ),
                              const Divider(
                                height: 1,
                                color: Color(0xFFF1F3F5),
                              ),
                              _buildModernToggle(
                                'Tampilkan QR Code',
                                settings?.cnSettQr ?? true,
                                provider.isInlineSaving
                                    ? null
                                    : (value) => _handleToggleChange(
                                        'cn_sett_qr',
                                        value,
                                      ),
                              ),
                              const Divider(
                                height: 1,
                                color: Color(0xFFF1F3F5),
                              ),
                              _buildModernToggle(
                                'Tampilkan Nama Kasir',
                                settings?.cnSettKasir ?? false,
                                provider.isInlineSaving
                                    ? null
                                    : (value) => _handleToggleChange(
                                        'cn_sett_kasir',
                                        value,
                                      ),
                              ),
                              const Divider(
                                height: 1,
                                color: Color(0xFFF1F3F5),
                              ),
                              _buildModernToggle(
                                'Tampilkan Keterangan',
                                settings?.cnSettKeterangan ?? true,
                                provider.isInlineSaving
                                    ? null
                                    : (value) => _handleToggleChange(
                                        'cn_sett_keterangan',
                                        value,
                                      ),
                              ),
                              const Divider(
                                height: 1,
                                color: Color(0xFFF1F3F5),
                              ),
                              _buildModernToggle(
                                'Tampilkan Footer Nota',
                                settings?.cnSettNota ?? true,
                                provider.isInlineSaving
                                    ? null
                                    : (value) => _handleToggleChange(
                                        'cn_sett_nota',
                                        value,
                                      ),
                              ),
                              const Divider(
                                height: 1,
                                color: Color(0xFFF1F3F5),
                              ),
                              _buildModernToggle(
                                'Tampilkan Pembulatan',
                                settings?.cnSettRounding ?? true,
                                provider.isInlineSaving
                                    ? null
                                    : (value) => _handleToggleChange(
                                        'cn_sett_rounding',
                                        value,
                                      ),
                              ),
                              const Divider(
                                height: 1,
                                color: Color(0xFFF1F3F5),
                              ),
                              _buildModernToggle(
                                'Tampilkan Durasi Layanan',
                                settings?.cnSettDurasi ?? true,
                                provider.isInlineSaving
                                    ? null
                                    : (value) => _handleToggleChange(
                                        'cn_sett_durasi',
                                        value,
                                      ),
                              ),
                              const Divider(
                                height: 1,
                                color: Color(0xFFF1F3F5),
                              ),
                              _buildModernToggle(
                                'Tampilkan Pesan WhatsApp',
                                settings?.cnSettWhatsapp ?? true,
                                provider.isInlineSaving
                                    ? null
                                    : (value) => _handleToggleChange(
                                        'cn_sett_whatsapp',
                                        value,
                                      ),
                              ),
                              const Divider(
                                height: 1,
                                color: Color(0xFFF1F3F5),
                              ),
                              _buildLogoUploadInfo(
                                provider: provider,
                                logoPath: settings?.cnLogo ?? '',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSectionTitle(
                          'Ukuran Kertas Printer',
                          'Pilih ukuran yang sesuai dengan printer thermal Anda.',
                        ),
                        _buildCardWrapper(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildModernRadioOption(
                                    label: '58 mm',
                                    isSelected: printerSize == 58,
                                    onTap: provider.isInlineSaving
                                        ? null
                                        : () => _handlePrinterSizeChange(58),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildModernRadioOption(
                                    label: '80 mm',
                                    isSelected: printerSize == 80,
                                    onTap: provider.isInlineSaving
                                        ? null
                                        : () => _handlePrinterSizeChange(80),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        SafeArea(
                          top: false,
                          minimum: const EdgeInsets.only(bottom: 12),
                          child: _buildActionButtons(provider),
                        ),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      margin: const EdgeInsets.only(top: 60),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppPalette.primaryBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_rounded, color: primaryColor, size: 34),
          const SizedBox(height: 12),
          const Text(
            'Pengaturan nota belum bisa dimuat',
            style: TextStyle(
              fontSize: 15,
              fontWeight: AppFont.w800,
              color: darkColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Muat Ulang'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF3E8B73).withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFF3E8B73),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Perubahan toggle dan ukuran akan langsung tersimpan.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: AppFont.w600,
                color: Color(0xFF3E8B73),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: AppFont.w900,
              fontSize: 14,
              color: darkColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: AppFont.w500,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardWrapper({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildModernReadOnlyField(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade400),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: AppFont.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: AppFont.w700,
                    color: darkColor,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_outline_rounded, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildModernMultilineField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    List<String> templates = const [],
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: AppFont.w700,
                  color: darkColor,
                ),
              ),
            ],
          ),
          if (templates.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 13,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 5),
                Text(
                  'Pilih template, lalu bebas diedit',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: AppFont.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: templates
                    .map(
                      (tpl) => _buildTemplateChip(
                        controller,
                        tpl,
                        maxWidth: constraints.maxWidth,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: controller,
              maxLines: 4,
              minLines: 3,
              style: const TextStyle(
                fontSize: 14,
                color: darkColor,
                fontWeight: AppFont.w500,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateChip(
    TextEditingController controller,
    String template, {
    required double maxWidth,
  }) {
    final bool isSelected = controller.text.trim() == template.trim();

    return GestureDetector(
      onTap: () {
        // Isi field dengan template; listener controller otomatis menandai
        // draft "dirty" sehingga tombol simpan aktif. setState hanya untuk
        // menyegarkan highlight chip yang aktif.
        _setControllerText(controller, template);
        setState(() {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        // Batasi lebar chip ke lebar area yang tersedia agar teks panjang
        // ter-truncate (ellipsis), bukan meluber keluar layar.
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.10)
              : const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_rounded, size: 13, color: primaryColor),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                template,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? AppFont.w700 : AppFont.w500,
                  color: isSelected ? primaryColor : darkColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernToggle(
    String title,
    bool value,
    ValueChanged<bool>? onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: AppFont.w600,
                color: darkColor,
              ),
            ),
          ),
          SizedBox(
            height: 30,
            child: CupertinoSwitch(
              value: value,
              activeTrackColor: primaryColor,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernRadioOption({
    required String label,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? primaryColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? primaryColor : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(Icons.circle, size: 8, color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? AppFont.w800 : AppFont.w600,
                color: isSelected ? primaryColor : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoGuidance() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF8A97A8)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Printer thermal hanya mencetak HITAM-PUTIH. Untuk hasil terbaik '
              'pakai logo sederhana kontras tinggi (hitam di atas latar terang), '
              'bentuk bujur sangkar / persegi = 500×500px. Logo warna/terang bisa hilang '
              'atau jadi gumpalan saat dicetak.',
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF6E7B8B),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoUploadInfo({
    required NotaSettingsProvider provider,
    required String logoPath,
  }) {
    final imageUrl = logoPath.isNotEmpty
        ? ApiClient.resolveImageVariantUrl(logoPath, width: 240)
        : null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: thumbnail + judul/keterangan.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F1EE),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppPalette.primaryBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl != null
                    ? AppCachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: const Icon(
                          Icons.storefront_rounded,
                          color: primaryColor,
                        ),
                      )
                    : const Icon(Icons.storefront_rounded, color: primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Logo khusus nota',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: AppFont.w700,
                        color: darkColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      imageUrl != null
                          ? 'Logo ini dipakai khusus untuk nota dan tidak mengikuti foto profil outlet.'
                          : 'Belum ada logo nota khusus. Upload logo agar tampilan nota terpisah dari foto profil outlet.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Panduan, preview, dan tombol → full width.
          const SizedBox(height: 14),
          _buildLogoGuidance(),
          if (imageUrl != null) ...[
            const SizedBox(height: 12),
            _LogoPrintPreview(imageUrl: imageUrl),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: provider.isBusy ? null : _pickAndUploadNotaLogo,
                icon: const Icon(Icons.camera_alt_outlined, size: 16),
                label: Text(
                  imageUrl != null ? 'Ubah Logo Nota' : 'Upload Logo Nota',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: const BorderSide(color: AppPalette.primaryBorder),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              if (imageUrl != null)
                OutlinedButton(
                  onPressed: provider.isBusy ? null : _deleteNotaLogo,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                    side: BorderSide(color: Colors.red.shade100),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Hapus'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(NotaSettingsProvider provider) {
    final bool canPreview = provider.notaSettings != null;
    final bool isSaving = provider.isBusy;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: isSaving || !_hasDraftChanges
                ? null
                : _saveFooterSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              disabledBackgroundColor: const Color(0xFFFFC8BF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: isSaving
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'MENYIMPAN...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: AppFont.w800,
                        ),
                      ),
                    ],
                  )
                : Text(
                    _hasDraftChanges
                        ? 'SIMPAN PERUBAHAN FOOTER'
                        : 'FOOTER SUDAH TERSIMPAN',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: AppFont.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: TextButton(
            onPressed: isSaving || !canPreview ? null : _showPreview,
            style: TextButton.styleFrom(
              foregroundColor: darkColor,
              disabledForegroundColor: Colors.grey.shade400,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade300, width: 1.5),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.remove_red_eye_rounded, size: 18),
                SizedBox(width: 8),
                Text(
                  'LIHAT PREVIEW STRUK',
                  style: TextStyle(fontWeight: AppFont.w800),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Menampilkan perkiraan hasil cetak logo (monokrom 1-bit) memakai konversi
/// yang SAMA dengan jalur cetak (LogoThermal), sehingga user paham tampilan
/// aslinya di struk thermal.
class _LogoPrintPreview extends StatefulWidget {
  const _LogoPrintPreview({required this.imageUrl});

  final String imageUrl;

  @override
  State<_LogoPrintPreview> createState() => _LogoPrintPreviewState();
}

class _LogoPrintPreviewState extends State<_LogoPrintPreview> {
  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _LogoPrintPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) _future = _load();
  }

  Future<Uint8List?> _load() async {
    try {
      final res = await http
          .get(Uri.parse(widget.imageUrl))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final mono = LogoThermal.toMonochrome(res.bodyBytes, targetWidth: 240);
      if (mono == null) return null;
      return LogoThermal.previewPng(mono);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE7EBF0)),
          ),
          clipBehavior: Clip.antiAlias,
          child: FutureBuilder<Uint8List?>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              final data = snap.data;
              if (data == null) {
                return const Icon(
                  Icons.broken_image_outlined,
                  size: 20,
                  color: Colors.grey,
                );
              }
              return Image.memory(
                data,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Perkiraan hasil cetak (hitam-putih). Beginilah logo tampil di struk thermal.',
            style: TextStyle(
              fontSize: 11.5,
              color: Color(0xFF6E7B8B),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _NotaLogoCropScreen extends StatefulWidget {
  const _NotaLogoCropScreen({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_NotaLogoCropScreen> createState() => _NotaLogoCropScreenState();
}

class _NotaLogoCropScreenState extends State<_NotaLogoCropScreen> {
  final _cropController = CropController();

  bool _isReady = false;
  bool _isCropping = false;

  Future<void> _handleCropResult(CropResult result) async {
    switch (result) {
      case CropSuccess(:final croppedImage):
        final file = File(
          '${Directory.systemTemp.path}/nota_logo_crop_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await file.writeAsBytes(croppedImage);
        if (mounted) Navigator.pop(context, file);
      case CropFailure(:final cause):
        if (!mounted) return;
        setState(() => _isCropping = false);
        CustomToast.show(
          context,
          message: 'Gagal crop logo nota: $cause',
          isError: true,
        );
    }
  }

  void _cropImage() {
    if (!_isReady || _isCropping) return;
    setState(() => _isCropping = true);
    _cropController.crop();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: _isCropping ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          'Crop Logo Nota',
          style: TextStyle(
            color: Colors.black,
            fontWeight: AppFont.w800,
            fontSize: 16,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: Color(0xFFF7F7F7)),
                  child: Crop(
                    image: widget.imageBytes,
                    controller: _cropController,
                    aspectRatio: 1,
                    initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                      size: 0.86,
                      aspectRatio: 1,
                    ),
                    interactive: true,
                    fixCropRect: true,
                    withCircleUi: false,
                    maskColor: Colors.black.withValues(alpha: 0.48),
                    baseColor: const Color(0xFFF7F7F7),
                    progressIndicator: const Center(child: AppCircularLoader()),
                    onStatusChanged: (status) {
                      final ready = status == CropStatus.ready;
                      if (ready != _isReady && mounted) {
                        setState(() => _isReady = ready);
                      }
                    },
                    onCropped: _handleCropResult,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  const Text(
                    'Atur area logo di dalam bingkai kotak.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF8A8A8A),
                      fontSize: 12,
                      fontWeight: AppFont.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isReady && !_isCropping ? _cropImage : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.primary,
                        disabledBackgroundColor: const Color(0xFFE0E0E0),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isCropping
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: AppCircularLoader(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : const Text(
                              'GUNAKAN LOGO',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: AppFont.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
