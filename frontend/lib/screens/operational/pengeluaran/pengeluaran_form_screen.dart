import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
// lib/screens/operational/pengeluaran/pengeluaran_form_screen.dart

import 'package:ayocucinew/core/theme/app_font.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/api_client.dart';
import '../../../../providers/pengeluaran_provider.dart';
import '../../../../providers/kategori_pengeluaran_provider.dart';
import '../../../../shared/widgets/app_cached_network_image.dart';
import '../../../../shared/widgets/currency_formatter.dart';
import '../../../../shared/widgets/custom_textfield.dart';
import '../../../../shared/widgets/custom_toast.dart';
import '../../../../data/models/pengeluaran_model.dart';
import '../../settings/keuangan/kategori%20pengeluaran/kategori_list.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class PengeluaranFormScreen extends StatefulWidget {
  final Pengeluaran? item; // Parameter untuk mode edit

  const PengeluaranFormScreen({super.key, this.item});

  @override
  State<PengeluaranFormScreen> createState() => _PengeluaranFormScreenState();
}

class _PengeluaranFormScreenState extends State<PengeluaranFormScreen> {
  static const double _maxExpenseAmount = 999999999;
  final _formKey = GlobalKey<FormState>();
  final _totalController = TextEditingController();
  final _ketController = TextEditingController();
  final _dateController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _selectedKategoriId;
  String? _selectedKategoriNama;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  File? _selectedImage;
  String? _existingImageUrl; // Menyimpan URL foto lama jika ada

  bool get isEditMode => widget.item != null;

  bool get _isPayrollLocked => widget.item?.isPayrollSource == true;

  @override
  void initState() {
    super.initState();

    // Inisialisasi data jika dalam mode edit
    if (isEditMode) {
      final item = widget.item!;
      _selectedKategoriId = item.kategoriId;
      _selectedKategoriNama = item.kategoriNama;
      _selectedDate = item.tanggal;
      _totalController.text = CurrencyFormatter.formatToRupiah(item.total);
      _ketController.text = item.keterangan;
      if (item.bukti.isNotEmpty) {
        _existingImageUrl = ApiClient.resolveUploadUrl(item.bukti.first);
      }
    }

    _dateController.text = DateFormat(
      'dd MMMM yyyy',
      'id',
    ).format(_selectedDate);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KategoriPengeluaranProvider>().fetchKategoriPengeluaran();
    });
  }

  @override
  void dispose() {
    _totalController.dispose();
    _ketController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _showKategoriPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Consumer<KategoriPengeluaranProvider>(
        builder: (context, kategoriProv, _) {
          final kategoriList = kategoriProv.kategoriList;
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(context).padding.bottom + 18,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5DCD8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppPalette.primarySoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.category_rounded,
                        color: AppPalette.primary,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pilih Kategori',
                            style: TextStyle(
                              fontWeight: AppFont.w900,
                              fontSize: 18,
                              color: Color(0xFF241815),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            kategoriList.isEmpty
                                ? 'Belum ada kategori pengeluaran'
                                : '${kategoriList.length} kategori tersedia',
                            style: const TextStyle(
                              fontWeight: AppFont.w600,
                              fontSize: 12.5,
                              color: Color(0xFF9A8F8A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF7F3F1),
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF9A8F8A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.48,
                  ),
                  child: kategoriProv.isLoading && kategoriList.isEmpty
                      ? const SizedBox(
                          height: 150,
                          child: Center(
                            child: AppCircularLoader(color: AppPalette.primary),
                          ),
                        )
                      : kategoriList.isEmpty
                      ? _buildKategoriEmptyState()
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: kategoriList.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final kat = kategoriList[index];
                            final bool isSelected =
                                _selectedKategoriId == kat.id;
                            return Material(
                              color: isSelected
                                  ? AppPalette.primarySoft
                                  : const Color(0xFFFCFAF9),
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedKategoriId = kat.id;
                                    _selectedKategoriNama = kat.kategori;
                                  });
                                  Navigator.pop(context);
                                },
                                borderRadius: BorderRadius.circular(18),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppPalette.primaryBorderStrong
                                          : const Color(0xFFF0E7E3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppPalette.primary
                                              : AppPalette.primarySoft,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.receipt_long_rounded,
                                          color: isSelected
                                              ? Colors.white
                                              : AppPalette.primary,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          kat.kategori,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: AppFont.w800,
                                            color: Color(0xFF2E2521),
                                            height: 1.25,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppPalette.primary
                                              : Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected
                                                ? AppPalette.primary
                                                : const Color(0xFFE4D8D3),
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Icon(
                                                Icons.check_rounded,
                                                color: Colors.white,
                                                size: 18,
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        this.context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const KategoriPengeluaranListScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppPalette.primary,
                      side: const BorderSide(color: AppPalette.primaryBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text(
                      'KELOLA KATEGORI',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: AppFont.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildKategoriEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFAF9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E7E3)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.category_outlined,
            color: AppPalette.primaryAccent,
            size: 32,
          ),
          SizedBox(height: 10),
          Text(
            'Belum ada kategori',
            style: TextStyle(
              fontWeight: AppFont.w800,
              fontSize: 15,
              color: Color(0xFF2E2521),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Tambahkan kategori agar pengeluaran lebih rapi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: AppFont.w600,
              fontSize: 12.5,
              color: Color(0xFF9A8F8A),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _existingImageUrl =
              null; // Hapus referensi foto lama jika pilih foto baru
        });
      }
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(
        context,
        message: "Gagal mengambil gambar",
        isError: true,
      );
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedKategoriId == null) {
      CustomToast.show(
        context,
        message: "Pilih kategori pengeluaran",
        isError: true,
      );
      return;
    }

    final total = CurrencyFormatter.parseRupiahToDouble(_totalController.text);
    if (total > _maxExpenseAmount) {
      CustomToast.show(
        context,
        message: "Nominal pengeluaran maksimal Rp 999.999.999",
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    Map<String, dynamic> res;

    if (isEditMode) {
      // LOGIKA UPDATE (Gunakan ID dari item yang ada)
      res = await context.read<PengeluaranProvider>().updateExpense(
        id: widget.item!.id,
        kategoriId: _selectedKategoriId!,
        total: total,
        keterangan: _ketController.text,
        tanggal: DateFormat('yyyy-MM-dd').format(_selectedDate),
        images: _selectedImage != null ? [_selectedImage!] : [],
      );
    } else {
      // LOGIKA CREATE
      res = await context.read<PengeluaranProvider>().createExpense(
        kategoriId: _selectedKategoriId!,
        total: total,
        keterangan: _ketController.text,
        tanggal: DateFormat('yyyy-MM-dd').format(_selectedDate),
        images: _selectedImage != null ? [_selectedImage!] : [],
      );
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (res['success']) {
        CustomToast.show(
          context,
          message: isEditMode ? "Data diperbarui" : "Pengeluaran disimpan",
        );
        Navigator.pop(context, true); // Kembali dengan sinyal refresh
      } else {
        CustomToast.show(context, message: res['message'], isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isPayrollLocked) {
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
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            "Pengeluaran Terkunci",
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: AppFont.w800,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppPalette.primarySoft,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: AppPalette.primary,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Tidak bisa diedit dari Pengeluaran',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: AppFont.w900,
                    color: Color(0xFF241815),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Data ini dibuat otomatis dari menu Penggajian. Jika perlu perubahan, buka dan ubah dari menu Penggajian.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFF8D7F78),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/pegawai-gaji'),
                    icon: const Icon(Icons.payments_rounded, size: 18),
                    label: const Text(
                      'Buka Penggajian',
                      style: TextStyle(fontWeight: AppFont.w900),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditMode ? "Edit Pengeluaran" : "Catat Pengeluaran",
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: AppFont.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel("Tanggal Transaksi"),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    locale: const Locale('id', 'ID'),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: AppPalette.primary,
                          onPrimary: Colors.white,
                          onSurface: Color(0xFF2C3E50),
                        ),
                        textButtonTheme: TextButtonThemeData(
                          style: TextButton.styleFrom(
                            foregroundColor: AppPalette.primary,
                          ),
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                      _dateController.text = DateFormat(
                        'dd MMMM yyyy',
                        'id',
                      ).format(picked);
                    });
                  }
                },
                decoration: _inputDecoration(
                  Icons.calendar_month_rounded,
                  "Pilih Tanggal",
                ),
              ),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLabel("Kategori"),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const KategoriPengeluaranListScreen(),
                      ),
                    ),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppPalette.primarySoft,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppPalette.primaryBorder),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: AppPalette.primary,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _showKategoriPicker,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _selectedKategoriNama ?? "Pilih Kategori",
                          style: TextStyle(
                            color: _selectedKategoriNama == null
                                ? Colors.grey
                                : Colors.black,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.expand_more_rounded, color: Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              _buildLabel("Nominal (Rp)"),
              const SizedBox(height: 8),
              TextFormField(
                controller: _totalController,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontWeight: AppFont.w900,
                  color: Color(0xFFE03131),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(9),
                ],
                onChanged: (v) => _totalController.value = TextEditingValue(
                  text: CurrencyFormatter.formatInputToRupiah(v),
                  selection: TextSelection.collapsed(
                    offset: CurrencyFormatter.formatInputToRupiah(v).length,
                  ),
                ),
                decoration: _inputDecoration(Icons.payments_outlined, "0"),
              ),

              const SizedBox(height: 16),
              _buildLabel("Keterangan"),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _ketController,
                hintText: "Contoh: Beli Token Listrik",
                maxLines: 2,
                fillColor: const Color(0xFFFBFBFE),
              ),

              const SizedBox(height: 16),
              _buildLabel("Bukti Nota (Optional)"),
              const SizedBox(height: 12),
              _buildModernImagePicker(),

              const SizedBox(height: 50),
              Center(child: _buildSubmitButton()),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: AppFont.w900,
        fontSize: 13,
        color: Color(0xFF2C3E50),
        letterSpacing: 0.5,
      ),
    );
  }

  InputDecoration _inputDecoration(IconData icon, String hint) {
    return InputDecoration(
      prefixIcon: Icon(icon, size: 20, color: Colors.grey),
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFFBFBFE),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppPalette.primary),
      ),
    );
  }

  Widget _buildModernImagePicker() {
    // Tampilkan foto terpilih atau foto lama (untuk mode edit)
    if (_selectedImage != null || _existingImageUrl != null) {
      return Stack(
        children: [
          Container(
            width: double.infinity,
            height: 300,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _selectedImage != null
                  ? Image.file(_selectedImage!, fit: BoxFit.contain)
                  : AppCachedNetworkImage(
                      imageUrl: ApiClient.resolveImageVariantUrl(
                        _existingImageUrl,
                        width: 900,
                        quality: 82,
                      ),
                      fit: BoxFit.contain,
                      errorWidget: const Icon(Icons.broken_image),
                    ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedImage = null;
                _existingImageUrl = null;
              }),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        _buildPickerBtn(
          Icons.camera_alt_rounded,
          "Kamera",
          () => _pickImage(ImageSource.camera),
        ),
        const SizedBox(width: 12),
        _buildPickerBtn(
          Icons.image_rounded,
          "Galeri",
          () => _pickImage(ImageSource.gallery),
        ),
      ],
    );
  }

  Widget _buildPickerBtn(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          foregroundColor: const Color(0xFF607D8B),
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.75,
        height: 56,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppPalette.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: AppCircularLoader(color: Colors.white, strokeWidth: 3),
                )
              : Text(
                  isEditMode ? "PERBARUI DATA" : "SIMPAN PENGELUARAN",
                  style: const TextStyle(
                    fontWeight: AppFont.w900,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
        ),
      ),
    );
  }
}
