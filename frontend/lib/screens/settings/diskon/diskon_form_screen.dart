// ignore_for_file: use_build_context_synchronously

import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../data/models/diskon_model.dart';
import '../../../providers/diskon_provider.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/custom_textfield.dart';
import '../../../shared/widgets/custom_toast.dart';
import '../../../shared/widgets/currency_formatter.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

/// Form full-screen untuk tambah/edit diskon.
/// Mendukung dua jadwal: rentang tanggal, atau berulang per hari tertentu.
class DiskonFormScreen extends StatefulWidget {
  final Diskon? existing;
  const DiskonFormScreen({super.key, this.existing});

  @override
  State<DiskonFormScreen> createState() => _DiskonFormScreenState();
}

class _DiskonFormScreenState extends State<DiskonFormScreen> {
  static const double _maxDiscountPercent = 100.0;
  static const int _maxNominalDiscount = 999999999;
  static const int _maxDurationDays = 90;

  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _nilaiController = TextEditingController();

  String _tipe = "nominal";
  String _jadwalTipe = kJadwalRentangTanggal;
  final Set<int> _selectedDays = {}; // 1=Senin..7=Minggu
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  bool _isActive = true;
  bool _isLoading = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _namaController.text = e.nama;
      _nilaiController.text = e.tipe == "nominal"
          ? CurrencyFormatter.formatNumberToInput(e.nilai)
          : e.nilai.toString().replaceAll('.0', '');
      _tipe = e.tipe;
      _jadwalTipe = e.jadwalTipe;
      _selectedDays.addAll(e.hari);
      _startDate = e.tanggalMulai;
      _endDate = e.tanggalAkhir;
      _isActive = e.status == 1;
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _nilaiController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final initialStart = _startDate.isBefore(today) ? today : _startDate;
    final DateTime? startPicked = await showDatePicker(
      context: context,
      initialDate: initialStart,
      firstDate: today,
      lastDate: DateTime(2101),
      helpText: "PILIH TANGGAL MULAI",
      builder: (context, child) => _calendarTheme(child!),
    );
    if (startPicked == null) return;

    final maxEnd = startPicked.add(const Duration(days: _maxDurationDays));
    final initialEnd =
        _endDate.isBefore(startPicked) || _endDate.isAfter(maxEnd)
        ? startPicked.add(const Duration(days: 1))
        : _endDate;
    final DateTime? endPicked = await showDatePicker(
      context: context,
      initialDate: initialEnd,
      firstDate: startPicked,
      lastDate: maxEnd,
      helpText: "PILIH TANGGAL AKHIR",
      builder: (context, child) => _calendarTheme(child!),
    );
    if (endPicked == null) return;

    setState(() {
      _startDate = startPicked;
      _endDate = endPicked;
    });
  }

  Widget _calendarTheme(Widget child) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: const ColorScheme.light(
        primary: AppPalette.primary,
        onPrimary: Colors.white,
        onSurface: Colors.black87,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppPalette.primary),
      ),
    ),
    child: child,
  );

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_jadwalTipe == kJadwalHariBerulang && _selectedDays.isEmpty) {
      CustomToast.show(
        context,
        message: "Pilih minimal satu hari untuk diskon berulang",
        isError: true,
      );
      return;
    }

    if (_jadwalTipe == kJadwalRentangTanggal &&
        (_endDate.isBefore(_startDate) ||
            _endDate.isAfter(
              _startDate.add(const Duration(days: _maxDurationDays)),
            ))) {
      CustomToast.show(
        context,
        message: 'Masa berlaku diskon maksimal 90 hari',
        isError: true,
      );
      return;
    }

    final double rawNilai = _tipe == "nominal"
        ? CurrencyFormatter.parseRupiahToInt(_nilaiController.text).toDouble()
        : double.tryParse(_nilaiController.text) ?? 0;

    if (_tipe == "persen" && rawNilai > _maxDiscountPercent) {
      CustomToast.show(
        context,
        message: "Persentase diskon maksimal 100%",
        isError: true,
      );
      return;
    }
    if (_tipe == "nominal" && rawNilai > _maxNominalDiscount) {
      CustomToast.show(
        context,
        message: "Nominal diskon maksimal Rp 999.999.999",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    // Diskon berulang juga punya masa berlaku maksimal 90 hari.
    final bool recurring = _jadwalTipe == kJadwalHariBerulang;
    final DateTime mulai = recurring
        ? DateUtils.dateOnly(DateTime.now())
        : _startDate;
    final DateTime akhir = recurring
        ? mulai.add(const Duration(days: _maxDurationDays))
        : _endDate;

    final res = await context.read<DiskonProvider>().saveDiscount(
      id: widget.existing?.id,
      nama: _namaController.text.trim().toUpperCase(),
      nilai: rawNilai,
      tipe: _tipe,
      jadwalTipe: _jadwalTipe,
      hari: recurring ? hariToCsv(_selectedDays.toList()) : '',
      mulai: mulai,
      akhir: akhir,
      status: _isActive ? 1 : 0,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);
    if (res['success'] == true) {
      CustomToast.show(context, message: res['message']);
      Navigator.pop(context, true);
    } else {
      CustomToast.show(context, message: res['message'], isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppPalette.ink,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEdit ? "EDIT DISKON" : "TAMBAH DISKON",
          style: const TextStyle(
            color: AppPalette.ink,
            fontSize: 17,
            fontWeight: AppFont.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 16),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              CustomTextField(
                controller: _namaController,
                labelText: "NAMA DISKON",
                hintText: "Contoh: JUMAT BERKAH",
                isRequired: true,
                fillColor: const Color(0xFFF9F9F9),
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [UpperCaseTextFormatter()],
              ),
              const SizedBox(height: 20),
              _buildTypeSelector(),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _nilaiController,
                labelText: _tipe == "persen"
                    ? "PERSENTASE (%)"
                    : "NILAI NOMINAL (RP)",
                hintText: _tipe == "persen" ? "Contoh: 10" : "Contoh: 10.000",
                keyboardType: TextInputType.number,
                isRequired: true,
                fillColor: const Color(0xFFF9F9F9),
                inputFormatters: _tipe == "persen"
                    ? [
                        DecimalNumberTextInputFormatter(
                          maxIntegerDigits: 3,
                          maxDecimalDigits: 2,
                          maxValue: _maxDiscountPercent,
                        ),
                      ]
                    : [LengthLimitingTextInputFormatter(9)],
                onChanged: (val) {
                  if (_tipe == "nominal") {
                    final formatted = CurrencyFormatter.formatInputToRupiah(
                      val,
                    );
                    _nilaiController.value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(
                        offset: formatted.length,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 24),
              _buildScheduleSection(dateFormat),
              const SizedBox(height: 24),
              _buildStatusToggle(),
              const SizedBox(height: 28),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: AppFont.w700,
      color: Color(0xFF2C3E50),
    ),
  );

  Widget _buildTypeSelector() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionLabel("JENIS DISKON"),
      const SizedBox(height: 10),
      Row(
        children: [
          _radioTile("Nominal", "nominal"),
          const SizedBox(width: 20),
          _radioTile("Persen", "persen"),
        ],
      ),
    ],
  );

  Widget _radioTile(String label, String value) => GestureDetector(
    onTap: () {
      setState(() {
        _tipe = value;
        _nilaiController.clear();
      });
    },
    child: Row(
      children: [
        Icon(
          _tipe == value ? Icons.radio_button_checked : Icons.radio_button_off,
          color: _tipe == value ? AppPalette.primary : Colors.grey,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    ),
  );

  Widget _buildScheduleSection(DateFormat df) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionLabel("JADWAL BERLAKU"),
      const SizedBox(height: 10),
      // Segmen pilihan jadwal
      Row(
        children: [
          Expanded(
            child: _segmentTile(
              label: "Rentang Tanggal",
              icon: Icons.date_range_rounded,
              selected: _jadwalTipe == kJadwalRentangTanggal,
              onTap: () => setState(() => _jadwalTipe = kJadwalRentangTanggal),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _segmentTile(
              label: "Hari Tertentu",
              icon: Icons.event_repeat_rounded,
              selected: _jadwalTipe == kJadwalHariBerulang,
              onTap: () => setState(() => _jadwalTipe = kJadwalHariBerulang),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      if (_jadwalTipe == kJadwalRentangTanggal)
        _buildDateRangePicker(df)
      else
        _buildDaySelector(),
    ],
  );

  Widget _segmentTile({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: selected ? AppPalette.primarySoft : const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? AppPalette.primary : const Color(0xFFE3E7EE),
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 22,
            color: selected ? AppPalette.primary : AppPalette.muted,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? AppFont.w800 : AppFont.w600,
              color: selected ? AppPalette.primary : AppPalette.ink,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildDateRangePicker(DateFormat df) => GestureDetector(
    onTap: _selectDateRange,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "${df.format(_startDate)} - ${df.format(_endDate)}",
            style: const TextStyle(fontSize: 14),
          ),
          const Icon(
            Icons.calendar_today_outlined,
            size: 20,
            color: AppPalette.primary,
          ),
        ],
      ),
    ),
  );

  Widget _buildDaySelector() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        "Diskon aktif pada hari yang dipilih selama 90 hari sejak disimpan.",
        style: TextStyle(fontSize: 11.5, color: AppPalette.muted),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: List.generate(7, (i) {
          final day = i + 1; // 1..7
          final selected = _selectedDays.contains(day);
          return GestureDetector(
            onTap: () => setState(() {
              if (selected) {
                _selectedDays.remove(day);
              } else {
                _selectedDays.add(day);
              }
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? AppPalette.primarySoft
                    : const Color(0xFFF9F9F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? AppPalette.primary
                      : const Color(0xFFE3E7EE),
                  width: selected ? 1.4 : 1,
                ),
              ),
              child: Text(
                kNamaHari[day],
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? AppFont.w800 : AppFont.w600,
                  color: selected ? AppPalette.primary : AppPalette.ink,
                ),
              ),
            ),
          );
        }),
      ),
    ],
  );

  Widget _buildStatusToggle() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Text(
        "STATUS AKTIF",
        style: TextStyle(fontSize: 14, fontWeight: AppFont.w700),
      ),
      Switch(
        value: _isActive,
        onChanged: (v) => setState(() => _isActive = v),
        activeThumbColor: AppPalette.primary,
      ),
    ],
  );

  Widget _buildSubmitButton() => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      onPressed: _isLoading ? null : _handleSave,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppPalette.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 0,
      ),
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: AppCircularLoader(color: Colors.white, strokeWidth: 2),
            )
          : const Text(
              "SIMPAN",
              style: TextStyle(
                color: Colors.white,
                fontWeight: AppFont.w900,
                letterSpacing: 1,
              ),
            ),
    ),
  );
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class DecimalNumberTextInputFormatter extends TextInputFormatter {
  final int maxIntegerDigits;
  final int maxDecimalDigits;
  final double? maxValue;

  DecimalNumberTextInputFormatter({
    required this.maxIntegerDigits,
    required this.maxDecimalDigits,
    this.maxValue,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(text)) return oldValue;

    final parts = text.split('.');
    if (parts[0].length > maxIntegerDigits) return oldValue;
    if (parts.length > 1 && parts[1].length > maxDecimalDigits) {
      return oldValue;
    }
    final parsed = double.tryParse(text);
    if (maxValue != null && parsed != null && parsed > maxValue!) {
      return oldValue;
    }
    return newValue;
  }
}
