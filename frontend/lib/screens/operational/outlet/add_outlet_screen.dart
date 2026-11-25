import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/providers/app_provider.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';

import '../../../shared/widgets/custom_textfield.dart';
import '../../../shared/widgets/custom_toast.dart';
import '../../../shared/widgets/ceremonial_success_screen.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class AddOutletScreen extends StatefulWidget {
  const AddOutletScreen({super.key});

  @override
  State<AddOutletScreen> createState() => _AddOutletScreenState();
}

class _AddOutletScreenState extends State<AddOutletScreen> {
  final _namaController = TextEditingController();
  final _phoneController = TextEditingController();
  final _alamatController = TextEditingController();

  bool _isLoading = false;
  bool _isProvinceLoading = false;
  bool _isCityLoading = false;
  bool _isDistrictLoading = false;

  List<dynamic> _provinces = [];
  List<dynamic> _cities = [];
  List<dynamic> _districts = [];

  String? _selectedProvince;
  String? _selectedCity;
  String? _selectedDistrict;

  // Data tambahan dari pendaftaran
  static const _businessLocationOptions = ['Ruko', 'Rumah', 'Kios'];
  static const _businessCapitalOptions = [
    'Rp20 juta - Rp50 juta',
    'Rp50 juta - Rp80 juta',
    'Di atas Rp100 juta',
  ];
  static const _employeeCountOptions = [
    '1 orang',
    '2 orang',
    'Lebih dari 3 orang',
  ];
  static const _machineCountOptions = [
    '2 unit',
    '4 unit',
    '6 unit',
    'Lebih dari 6 unit',
  ];

  String? _selectedBusinessLocation;
  String? _selectedBusinessCapital;
  String? _selectedEmployeeCount;
  String? _selectedMachineCount;
  DateTime? _selectedBusinessStartDate;

  static const _bulanOptions = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  @override
  void initState() {
    super.initState();
    _fetchProvinces();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _phoneController.dispose();
    _alamatController.dispose();
    super.dispose();
  }

  // --- LOGIKA FETCH LOKASI ---

  void _fetchProvinces() async {
    setState(() => _isProvinceLoading = true);
    final auth = context.read<AuthProvider>();
    final data = await auth.getProvinces();
    if (mounted) {
      setState(() {
        _provinces = data;
        _isProvinceLoading = false;
      });
    }
  }

  void _fetchCities(String provinceCode) async {
    setState(() {
      _isCityLoading = true;
      _cities = [];
      _districts = [];
      _selectedProvince = provinceCode;
      _selectedCity = null;
      _selectedDistrict = null;
    });
    final auth = context.read<AuthProvider>();
    final data = await auth.getCities(provinceCode);
    if (mounted) {
      setState(() {
        _cities = data;
        _isCityLoading = false;
      });
    }
  }

  void _fetchDistricts(String cityCode) async {
    setState(() {
      _isDistrictLoading = true;
      _districts = [];
      _selectedCity = cityCode;
      _selectedDistrict = null;
    });
    final auth = context.read<AuthProvider>();
    final data = await auth.getDistricts(cityCode);
    if (mounted) {
      setState(() {
        _districts = data;
        _isDistrictLoading = false;
      });
    }
  }

  String _getNameFromList(List<dynamic> list, String? code) {
    if (code == null || list.isEmpty) return "Pilih";
    final item = list.firstWhere(
      (e) => e['code'].toString() == code,
      orElse: () => null,
    );
    return item != null ? item['name'] : "Pilih";
  }

  // --- UI PICKER ---

  void _showLocationPicker({
    required String title,
    required List<dynamic> items,
    required String? selectedCode,
    required Function(String code) onSelected,
    bool isLoading = false,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 15),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 25),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                Expanded(
                  child: isLoading
                      ? const Center(
                          child: AppCircularLoader(color: AppPalette.primary),
                        )
                      : items.isEmpty
                      ? const Center(child: Text("Data tidak tersedia"))
                      : ListView.builder(
                          itemCount: items.length,
                          padding: const EdgeInsets.only(bottom: 50),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final isSelected =
                                item['code'].toString() == selectedCode;
                            return InkWell(
                              onTap: () {
                                onSelected(item['code'].toString());
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 25,
                                  vertical: 18,
                                ),
                                color: isSelected
                                    ? AppPalette.primary.withValues(alpha: 0.05)
                                    : Colors.transparent,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['name'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isSelected
                                              ? AppPalette.primary
                                              : const Color(0xFF2C3E50),
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: AppPalette.primary,
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- ACTION SIMPAN ---

  void _handleSave() async {
    if (_namaController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _alamatController.text.isEmpty ||
        _selectedProvince == null ||
        _selectedCity == null ||
        _selectedDistrict == null) {
      CustomToast.show(
        context,
        message: "Semua data wajib diisi",
        isError: true,
      );
      return;
    }

    if (_selectedBusinessLocation == null ||
        _selectedBusinessCapital == null ||
        _selectedEmployeeCount == null ||
        _selectedMachineCount == null ||
        _selectedBusinessStartDate == null) {
      CustomToast.show(
        context,
        message: "Lengkapi data profil usaha",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    final res = await context.read<AppProvider>().createOutlet(
      nama: _namaController.text.trim(),
      noHp: _phoneController.text.trim(),
      alamat: _alamatController.text.trim(),
      provinsi: _selectedProvince!,
      kota: _selectedCity!,
      kecamatan: _selectedDistrict!,
      tipeLokasiUsaha: _selectedBusinessLocation,
      modalUsaha: _selectedBusinessCapital,
      jumlahKaryawan: _selectedEmployeeCount,
      jumlahMesin: _selectedMachineCount,
      tanggalBerjalan: _selectedBusinessStartDate != null
          ? '${_selectedBusinessStartDate!.year}-${_selectedBusinessStartDate!.month.toString().padLeft(2, '0')}-01'
          : null,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (res['success']) {
        final bool isAdditionalOutlet = res['isAdditionalOutlet'] == true;
        final navigator = Navigator.of(context, rootNavigator: true);
        final appProvider = context.read<AppProvider>();
        final String outletId =
            res['outletId']?.toString() ??
            res['data']?['ot_id']?.toString() ??
            '';
        final String outletName =
            res['outletName']?.toString() ??
            res['data']?['ot_nama']?.toString() ??
            _namaController.text.trim();
        final String outletAddress =
            res['outletAddress']?.toString() ??
            res['data']?['ot_alamat']?.toString() ??
            _alamatController.text.trim();
        final String outletPhone =
            res['outletPhone']?.toString() ??
            res['data']?['ot_nohp']?.toString() ??
            _phoneController.text.trim();
        final locationParts = <String>[
          res['data']?['ot_kecamatan']?.toString() ?? '',
          res['data']?['ot_kota']?.toString() ?? '',
          res['data']?['ot_provinsi']?.toString() ?? '',
        ].where((e) => e.isNotEmpty).toList();
        final String outletLocation = locationParts.join(', ');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CeremonialSuccessScreen(
              badge: isAdditionalOutlet
                  ? 'Outlet Tambahan Dibuat'
                  : 'Outlet Baru Dibuat',
              title: isAdditionalOutlet
                  ? 'Outlet tambahan siap'
                  : 'Outlet utama siap',
              subtitle: isAdditionalOutlet
                  ? 'Outlet sudah dibuat. Pindahkan sesi ke outlet ini untuk lanjut aktivasi.'
                  : 'Outlet sudah dibuat. Masuk ke outlet ini untuk melengkapi setup awal.',
              primaryLabel: 'Pindah ke Outlet Ini',
              onPrimary: () async {
                if (outletId.isEmpty) {
                  navigator.pop();
                  return;
                }
                final result = await appProvider.switchOutlet(outletId);
                if (result['success'] == true) {
                  navigator.popUntil((route) => route.isFirst);
                }
                if (result['success'] != true && navigator.mounted) {
                  navigator.pop();
                }
              },
              chips: isAdditionalOutlet
                  ? [
                      CelebrationChipData(
                        icon: Icons.store_rounded,
                        text: outletName,
                      ),
                      CelebrationChipData(
                        icon: Icons.location_on_rounded,
                        text: outletAddress.isNotEmpty
                            ? outletAddress
                            : (outletLocation.isNotEmpty
                                  ? outletLocation
                                  : 'Lokasi belum lengkap'),
                      ),
                      CelebrationChipData(
                        icon: Icons.call_rounded,
                        text: outletPhone.isNotEmpty
                            ? outletPhone
                            : 'No HP belum diisi',
                      ),
                    ]
                  : [
                      CelebrationChipData(
                        icon: Icons.verified_rounded,
                        text: outletName,
                      ),
                      CelebrationChipData(
                        icon: Icons.location_on_rounded,
                        text: outletAddress.isNotEmpty
                            ? outletAddress
                            : (outletLocation.isNotEmpty
                                  ? outletLocation
                                  : 'Lokasi belum lengkap'),
                      ),
                      CelebrationChipData(
                        icon: Icons.call_rounded,
                        text: outletPhone.isNotEmpty
                            ? outletPhone
                            : 'No HP belum diisi',
                      ),
                    ],
              soundAsset: isAdditionalOutlet
                  ? 'assets/sounds/success_bright_1.wav'
                  : 'assets/sounds/success_warm.wav',
            ),
          ),
        );
      } else {
        CustomToast.show(context, message: res['message'], isError: true);
      }
    }
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
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Tambah Outlet Baru",
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomTextField(
                    controller: _namaController,
                    labelText: 'Nama outlet',
                    hintText: 'Contoh: Ayo Cuci Cabang 2',
                    isRequired: true,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _phoneController,
                    labelText: 'No handphone outlet',
                    hintText: '08123456789',
                    isRequired: true,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  _buildLabel("Provinsi", isRequired: true),
                  _buildSelectorTrigger(
                    label: _getNameFromList(_provinces, _selectedProvince),
                    isLoading: _isProvinceLoading,
                    onTap: () => _showLocationPicker(
                      title: "Pilih Provinsi",
                      items: _provinces,
                      selectedCode: _selectedProvince,
                      onSelected: (code) => _fetchCities(code),
                      isLoading: _isProvinceLoading,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildLabel("Kabupaten/Kota", isRequired: true),
                  _buildSelectorTrigger(
                    label: _getNameFromList(_cities, _selectedCity),
                    isLoading: _isCityLoading,
                    onTap: _selectedProvince == null
                        ? () => CustomToast.show(
                            context,
                            message: "Pilih provinsi dulu",
                          )
                        : () => _showLocationPicker(
                            title: "Pilih Kabupaten/Kota",
                            items: _cities,
                            selectedCode: _selectedCity,
                            onSelected: (code) => _fetchDistricts(code),
                            isLoading: _isCityLoading,
                          ),
                  ),
                  const SizedBox(height: 16),

                  _buildLabel("Kecamatan", isRequired: true),
                  _buildSelectorTrigger(
                    label: _getNameFromList(_districts, _selectedDistrict),
                    isLoading: _isDistrictLoading,
                    onTap: _selectedCity == null
                        ? () => CustomToast.show(
                            context,
                            message: "Pilih kota dulu",
                          )
                        : () => _showLocationPicker(
                            title: "Pilih Kecamatan",
                            items: _districts,
                            selectedCode: _selectedDistrict,
                            onSelected: (code) =>
                                setState(() => _selectedDistrict = code),
                            isLoading: _isDistrictLoading,
                          ),
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _alamatController,
                    labelText: 'Alamat Lengkap',
                    hintText: 'Jl. Ahmad Yani No. 123...',
                    isRequired: true,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 22),

                  _buildOptionGroup(
                    title: 'Tempat usaha',
                    helper: 'Pilih lokasi utama operasional laundry kamu.',
                    options: _businessLocationOptions,
                    selectedValue: _selectedBusinessLocation,
                    onSelected: (val) =>
                        setState(() => _selectedBusinessLocation = val),
                  ),
                  const SizedBox(height: 18),
                  _buildOptionGroup(
                    title: 'Modal awal usaha',
                    helper:
                        'Bantu AyoCuci menyesuaikan rekomendasi setup awal.',
                    options: _businessCapitalOptions,
                    selectedValue: _selectedBusinessCapital,
                    onSelected: (val) =>
                        setState(() => _selectedBusinessCapital = val),
                  ),
                  const SizedBox(height: 18),
                  _buildOptionGroup(
                    title: 'Jumlah karyawan',
                    helper: 'Termasuk owner jika ikut operasional harian.',
                    options: _employeeCountOptions,
                    selectedValue: _selectedEmployeeCount,
                    onSelected: (val) =>
                        setState(() => _selectedEmployeeCount = val),
                  ),
                  const SizedBox(height: 18),
                  _buildOptionGroup(
                    title: 'Jumlah mesin dan pengering',
                    helper:
                        'Total mesin cuci dan pengering yang aktif dipakai.',
                    options: _machineCountOptions,
                    selectedValue: _selectedMachineCount,
                    onSelected: (val) =>
                        setState(() => _selectedMachineCount = val),
                  ),
                  const SizedBox(height: 18),
                  _buildBusinessStartDatePicker(),

                  const SizedBox(height: 12),
                  const Text(
                    '*Wajib diisi',
                    style: TextStyle(color: AppPalette.primary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildBusinessStartDatePicker() {
    final selected = _selectedBusinessStartDate;
    final now = DateTime.now();
    final years = List.generate(30, (i) => now.year - i);
    final selectedMonth = selected?.month ?? 1;
    final selectedYear = selected?.year ?? now.year;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Usaha berjalan sejak', isRequired: true),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'Bantu team AyoCuci mengetahui kapan bisnis laundry kamu mulai beroperasi.',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildBottomSheetSelector<int>(
                value: selectedMonth,
                hint: 'Bulan',
                displayText: selected != null
                    ? _bulanOptions[selectedMonth - 1]
                    : null,
                options: List.generate(12, (i) => i + 1),
                itemLabel: (val) => _bulanOptions[val - 1],
                onSelected: (val) {
                  setState(
                    () => _selectedBusinessStartDate = DateTime(
                      selectedYear,
                      val,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _buildBottomSheetSelector<int>(
                value: selectedYear,
                hint: 'Tahun',
                displayText: selected != null ? '$selectedYear' : null,
                options: years,
                itemLabel: (val) => '$val',
                onSelected: (val) {
                  setState(
                    () => _selectedBusinessStartDate = DateTime(
                      val,
                      selectedMonth,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomSheetSelector<T>({
    required T? value,
    required String hint,
    required List<T> options,
    required String Function(T value) itemLabel,
    required ValueChanged<T> onSelected,
    String? displayText,
  }) {
    return InkWell(
      onTap: () => _showBottomSheetSelector<T>(
        title: hint,
        value: value,
        options: options,
        itemLabel: itemLabel,
        onSelected: onSelected,
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE6EAF0)),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayText ?? hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: displayText != null
                      ? const Color(0xFF2C3E50)
                      : const Color(0xFFB6C0CC),
                  fontSize: 13,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  void _showBottomSheetSelector<T>({
    required String title,
    required T? value,
    required List<T> options,
    required String Function(T value) itemLabel,
    required ValueChanged<T> onSelected,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.mediumImpact();

    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5EAF0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        Text(
                          'Pilih salah satu',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: title.toLowerCase() == 'bulan'
                        ? GridView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.fromLTRB(
                              12,
                              0,
                              12,
                              24 + MediaQuery.of(sheetContext).padding.bottom,
                            ),
                            itemCount: options.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  mainAxisExtent: 46,
                                ),
                            itemBuilder: (context, index) {
                              final item = options[index];
                              final selected = value != null && item == value;
                              return InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  onSelected(item);
                                  Navigator.pop(sheetContext);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppPalette.primary.withValues(
                                            alpha: 0.08,
                                          )
                                        : const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: selected
                                          ? AppPalette.primary
                                          : const Color(0xFFE8EDF2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          itemLabel(item),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: selected
                                                ? AppPalette.primary
                                                : const Color(0xFF2C3E50),
                                          ),
                                        ),
                                      ),
                                      if (selected)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 17,
                                          color: AppPalette.primary,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.fromLTRB(
                              12,
                              0,
                              12,
                              24 + MediaQuery.of(sheetContext).padding.bottom,
                            ),
                            itemCount: options.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final item = options[index];
                              final selected = value != null && item == value;
                              return InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  onSelected(item);
                                  Navigator.pop(sheetContext);
                                },
                                borderRadius: BorderRadius.circular(18),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppPalette.primary.withValues(
                                            alpha: 0.08,
                                          )
                                        : const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: selected
                                          ? AppPalette.primary
                                          : const Color(0xFFE8EDF2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          itemLabel(item),
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            color: selected
                                                ? AppPalette.primary
                                                : const Color(0xFF2C3E50),
                                          ),
                                        ),
                                      ),
                                      if (selected)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 18,
                                          color: AppPalette.primary,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionGroup({
    required String title,
    required String helper,
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(title, isRequired: true),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            helper,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.map((option) {
            final isSelected = selectedValue == option;
            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(option);
              },
              borderRadius: BorderRadius.circular(18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppPalette.primary.withValues(alpha: 0.1)
                      : const Color(0xFFF9F9F9),
                  border: Border.all(
                    color: isSelected
                        ? AppPalette.primary
                        : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? AppPalette.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? AppPalette.primary
                              : Colors.grey.shade400,
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 12,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      option,
                      style: TextStyle(
                        color: isSelected
                            ? AppPalette.primary
                            : const Color(0xFF2C3E50),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Row(
      children: [
        if (isRequired)
          const Text(
            '*',
            style: TextStyle(color: AppPalette.primary, fontSize: 14),
          ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: Color(0xFF2C3E50)),
        ),
      ],
    ),
  );

  Widget _buildSelectorTrigger({
    required String label,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9F9),
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: label == "Pilih"
                      ? Colors.grey
                      : const Color(0xFF2C3E50),
                ),
              ),
            ),
            isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: AppCircularLoader(
                      strokeWidth: 2,
                      color: AppPalette.primary,
                    ),
                  )
                : const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 24,
                    color: Color(0xFF2C3E50),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppPalette.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: AppCircularLoader(color: Colors.white, strokeWidth: 2),
                )
              : const Text(
                  'BUAT OUTLET SEKARANG',
                  style: TextStyle(color: Colors.white, letterSpacing: 1),
                ),
        ),
      ),
    ),
  );
}
