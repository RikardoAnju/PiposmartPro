import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/register_provider.dart';
import '../../../shared/widgets/custom_textfield.dart';
import '../../../shared/widgets/custom_toast.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class StepOutlet extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const StepOutlet({super.key, required this.onNext, required this.onBack});

  @override
  State<StepOutlet> createState() => _StepOutletState();
}

class _StepOutletState extends State<StepOutlet> {
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

  // Bulan dalam bahasa Indonesia
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

  bool _isLoading = false;
  bool _isProvinceLoading = false;
  bool _isCityLoading = false;
  bool _isDistrictLoading = false;

  List<dynamic> _provinces = [];
  List<dynamic> _cities = [];
  List<dynamic> _districts = [];

  @override
  void initState() {
    super.initState();
    _fetchProvinces();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final regProv = context.read<RegisterProvider>();
      // Sinkronisasi nomor HP default dari data pribadi jika kosong
      if (regProv.outletPhoneController.text.isEmpty) {
        regProv.outletPhoneController.text = regProv.phoneController.text;
      }
    });
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
    final auth = context.read<AuthProvider>();
    final regProv = context.read<RegisterProvider>();
    setState(() {
      _isCityLoading = true;
      _cities = [];
      _districts = [];
      regProv.updateLocation(provinceCode, null, null);
    });
    final data = await auth.getCities(provinceCode);
    if (mounted) {
      setState(() {
        _cities = data;
        _isCityLoading = false;
      });
    }
  }

  void _fetchDistricts(String cityCode) async {
    final auth = context.read<AuthProvider>();
    final regProv = context.read<RegisterProvider>();
    setState(() {
      _isDistrictLoading = true;
      _districts = [];
      regProv.updateLocation(regProv.selectedProvince, cityCode, null);
    });
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

  // --- UI MODAL PICKER ---
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
              mainAxisSize: MainAxisSize.min,
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
                      fontWeight: AppFont.w800,
                      fontSize: 16,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                Flexible(
                  child: Builder(
                    builder: (context) {
                      if (isLoading) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: AppCircularLoader(color: AppPalette.primary),
                          ),
                        );
                      }
                      if (items.isEmpty) {
                        return const Center(
                          child: Text(
                            "Data tidak tersedia, coba pilih provinsi lagi",
                          ),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: items.length,
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 60),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final isSelected =
                              item['code'].toString() == selectedCode;

                          return InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
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
                                        fontWeight: isSelected
                                            ? AppFont.w800
                                            : AppFont.w500,
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

  // --- VALIDASI & SUBMIT ---
  void _handleStepOutlet() async {
    final regProv = context.read<RegisterProvider>();

    final nama = regProv.outletNameController.text.trim();
    final phone = regProv.outletPhoneController.text.trim();
    final alamat = regProv.outletAddressController.text.trim();

    // 1. Validasi Nama Outlet
    if (nama.length < 3) {
      CustomToast.show(
        context,
        message: "Nama outlet minimal 3 karakter",
        isError: true,
      );
      return;
    }

    // 2. Validasi Nomor HP Outlet
    if (phone.length < 10) {
      CustomToast.show(
        context,
        message: "Nomor handphone outlet tidak valid",
        isError: true,
      );
      return;
    }

    // 3. Validasi Lokasi (Picker)
    if (regProv.selectedProvince == null) {
      CustomToast.show(
        context,
        message: "Silakan pilih provinsi",
        isError: true,
      );
      return;
    }
    if (regProv.selectedCity == null) {
      CustomToast.show(
        context,
        message: "Silakan pilih kabupaten/kota",
        isError: true,
      );
      return;
    }
    if (regProv.selectedDistrict == null) {
      CustomToast.show(
        context,
        message: "Silakan pilih kecamatan",
        isError: true,
      );
      return;
    }

    // 4. Validasi Alamat Lengkap
    if (alamat.length < 10) {
      CustomToast.show(
        context,
        message: "Tuliskan alamat lengkap secara detail",
        isError: true,
      );
      return;
    }

    if (regProv.selectedBusinessLocation == null) {
      CustomToast.show(
        context,
        message: "Pilih tempat usaha laundry kamu",
        isError: true,
      );
      return;
    }
    if (regProv.selectedBusinessCapital == null) {
      CustomToast.show(
        context,
        message: "Pilih kisaran modal usaha",
        isError: true,
      );
      return;
    }
    if (regProv.selectedEmployeeCount == null) {
      CustomToast.show(
        context,
        message: "Pilih jumlah karyawan",
        isError: true,
      );
      return;
    }
    if (regProv.selectedMachineCount == null) {
      CustomToast.show(
        context,
        message: "Pilih jumlah mesin dan pengering",
        isError: true,
      );
      return;
    }
    if (regProv.selectedBusinessStartDate == null) {
      CustomToast.show(
        context,
        message: "Pilih kapan usaha berjalan",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();
    try {
      final res = await authProvider.validateOutlet(
        namaOutlet: nama,
        alamat: alamat,
        provinsi: regProv.selectedProvince!,
        kota: regProv.selectedCity!,
        tipeLokasiUsaha: regProv.selectedBusinessLocation,
        modalUsaha: regProv.selectedBusinessCapital,
        jumlahKaryawan: regProv.selectedEmployeeCount,
        jumlahMesin: regProv.selectedMachineCount,
        tanggalBerjalan: regProv.selectedBusinessStartDate != null
            ? '${regProv.selectedBusinessStartDate!.year}-${regProv.selectedBusinessStartDate!.month.toString().padLeft(2, '0')}-01'
            : null,
      );

      if (!mounted) return;
      if (res['success']) {
        widget.onNext();
      } else {
        CustomToast.show(context, message: res['message'], isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final regProv = context.watch<RegisterProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 50, 24, 30),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomTextField(
                    controller: regProv.outletNameController,
                    labelText: 'Nama outlet',
                    hintText: 'Ayo cuci',
                    isRequired: true,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: regProv.outletPhoneController,
                    labelText: 'No handphone outlet',
                    hintText: '08123456789',
                    isRequired: true,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(15),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildLabel("Provinsi", isRequired: true),
                  _buildSelectorTrigger(
                    label: _getNameFromList(
                      _provinces,
                      regProv.selectedProvince,
                    ),
                    isLoading: _isProvinceLoading,
                    onTap: () => _showLocationPicker(
                      title: "Pilih Provinsi",
                      items: _provinces,
                      selectedCode: regProv.selectedProvince,
                      onSelected: (code) => _fetchCities(code),
                      isLoading: _isProvinceLoading,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildLabel("Kabupaten/Kota", isRequired: true),
                  _buildSelectorTrigger(
                    label: _getNameFromList(_cities, regProv.selectedCity),
                    isLoading: _isCityLoading,
                    onTap: regProv.selectedProvince == null
                        ? () => CustomToast.show(
                            context,
                            message: "Pilih provinsi dulu",
                          )
                        : () => _showLocationPicker(
                            title: "Pilih Kabupaten/Kota",
                            items: _cities,
                            selectedCode: regProv.selectedCity,
                            onSelected: (code) => _fetchDistricts(code),
                            isLoading: _isCityLoading,
                          ),
                  ),
                  const SizedBox(height: 16),

                  _buildLabel("Kecamatan", isRequired: true),
                  _buildSelectorTrigger(
                    label: _getNameFromList(
                      _districts,
                      regProv.selectedDistrict,
                    ),
                    isLoading: _isDistrictLoading,
                    onTap: regProv.selectedCity == null
                        ? () => CustomToast.show(
                            context,
                            message: "Pilih kota dulu",
                          )
                        : () => _showLocationPicker(
                            title: "Pilih Kecamatan",
                            items: _districts,
                            selectedCode: regProv.selectedDistrict,
                            onSelected: (code) => regProv.updateLocation(
                              regProv.selectedProvince,
                              regProv.selectedCity,
                              code,
                            ),
                            isLoading: _isDistrictLoading,
                          ),
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: regProv.outletAddressController,
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
                    selectedValue: regProv.selectedBusinessLocation,
                    onSelected: regProv.updateBusinessLocation,
                  ),
                  const SizedBox(height: 18),
                  _buildOptionGroup(
                    title: 'Modal awal usaha',
                    helper:
                        'Bantu AyoCuci menyesuaikan rekomendasi setup awal.',
                    options: _businessCapitalOptions,
                    selectedValue: regProv.selectedBusinessCapital,
                    onSelected: regProv.updateBusinessCapital,
                  ),
                  const SizedBox(height: 18),
                  _buildOptionGroup(
                    title: 'Jumlah karyawan',
                    helper: 'Termasuk owner jika ikut operasional harian.',
                    options: _employeeCountOptions,
                    selectedValue: regProv.selectedEmployeeCount,
                    onSelected: regProv.updateEmployeeCount,
                  ),
                  const SizedBox(height: 18),
                  _buildOptionGroup(
                    title: 'Jumlah mesin dan pengering',
                    helper:
                        'Total mesin cuci dan pengering yang aktif dipakai.',
                    options: _machineCountOptions,
                    selectedValue: regProv.selectedMachineCount,
                    onSelected: regProv.updateMachineCount,
                  ),
                  const SizedBox(height: 18),
                  _buildBusinessStartDatePicker(regProv),
                  const SizedBox(height: 12),
                  const Text(
                    '*Wajib diisi',
                    style: TextStyle(
                      color: AppPalette.primary,
                      fontSize: 11,
                      fontWeight: AppFont.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildBusinessStartDatePicker(dynamic regProv) {
    final selected = regProv.selectedBusinessStartDate as DateTime?;
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
              fontWeight: AppFont.w500,
              height: 1.35,
            ),
          ),
        ),
        Row(
          children: [
            // Bulan dropdown
            Expanded(
              flex: 3,
              child: _buildCompactDropdown<int>(
                value: selected != null ? selectedMonth : null,
                hint: 'Bulan',
                items: List.generate(
                  12,
                  (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text(
                      _bulanOptions[i],
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: AppFont.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ),
                ),
                onChanged: (val) {
                  if (val != null) {
                    regProv.updateBusinessStartDate(
                      DateTime(selectedYear, val),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            // Tahun dropdown
            Expanded(
              flex: 2,
              child: _buildCompactDropdown<int>(
                value: selected != null ? selectedYear : null,
                hint: 'Tahun',
                items: years
                    .map(
                      (y) => DropdownMenuItem(
                        value: y,
                        child: Text(
                          '$y',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: AppFont.w600,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    regProv.updateBusinessStartDate(
                      DateTime(val, selectedMonth),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(
            hint,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: Color(0xFF2C3E50),
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(16),
          items: items,
          onChanged: onChanged,
        ),
      ),
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
              fontWeight: AppFont.w500,
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
                        fontWeight: isSelected
                            ? AppFont.w800
                            : AppFont.w600,
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
            style: TextStyle(
              color: AppPalette.primary,
              fontWeight: AppFont.w700,
              fontSize: 14,
            ),
          ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: AppFont.w700,
            color: Color(0xFF2C3E50),
          ),
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
                  fontWeight: label == "Pilih"
                      ? AppFont.w400
                      : AppFont.w600,
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

  Widget _buildActionButtons() => SafeArea(
    child: Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                widget.onBack();
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey[300]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'KEMBALI',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: AppFont.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      _handleStepOutlet();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: AppCircularLoader(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'SELANJUTNYA',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: AppFont.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}
