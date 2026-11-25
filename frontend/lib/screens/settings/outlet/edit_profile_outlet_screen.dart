import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:ayocucinew/providers/app_provider.dart';
import 'package:ayocucinew/providers/setting_nota_provider.dart';
import 'package:ayocucinew/core/utils/api_client.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:ayocucinew/shared/widgets/app_cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/custom_textfield.dart';
import '../../../shared/widgets/custom_toast.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'outlet_location_picker.dart';

class EditProfileOutletScreen extends StatefulWidget {
  const EditProfileOutletScreen({super.key});

  @override
  State<EditProfileOutletScreen> createState() =>
      _EditProfileOutletScreenState();
}

class _EditProfileOutletScreenState extends State<EditProfileOutletScreen> {
  final _namaController = TextEditingController();
  final _phoneController = TextEditingController();
  final _alamatController = TextEditingController();

  bool _isLoading = false;
  bool _isProvinceLoading = false;
  bool _isCityLoading = false;
  bool _isDistrictLoading = false;
  bool _isInitialDataLoading = true;

  List<dynamic> _provinces = [];
  List<dynamic> _cities = [];
  List<dynamic> _districts = [];

  String? _selectedProvince;
  String? _selectedCity;
  String? _selectedDistrict;

  File? _imageFile;
  String? _currentImageUrl;
  LatLng? _outletLocation;
  int _locationRadiusMeters = 5;

  @override
  void initState() {
    super.initState();
    _loadCurrentOutletData();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _phoneController.dispose();
    _alamatController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentOutletData() async {
    final appProv = context.read<AppProvider>();
    final auth = context.read<AuthProvider>();

    if (!auth.isOwnerOrAdmin) {
      if (mounted) {
        CustomToast.show(
          context,
          message: 'Hanya owner/admin yang dapat mengubah profil outlet',
          isError: true,
        );
        Navigator.pop(context);
      }
      return;
    }

    final profile = appProv
        .outlet; // Ambil data outlet langsung dari model Outlet di AppProvider
    if (profile == null) {
      await appProv.fetchOutletProfile();
    }

    final data = appProv
        .outlet; // Ambil data outlet langsung dari model Outlet di AppProvider setelah memastikan data sudah dimuat
    if (data != null) {
      _namaController.text = data.nama;
      _phoneController.text = data.noHp ?? '';
      _alamatController.text = data.alamat ?? '';
      _selectedProvince = data.provinsi?.toString();
      _selectedCity = data.kota?.toString();
      _selectedDistrict = data.kecamatan?.toString();
      _currentImageUrl = data.gambar;
      if (data.latitude != null && data.longitude != null) {
        _outletLocation = LatLng(data.latitude!, data.longitude!);
      }
      _locationRadiusMeters = data.locationRadiusMeters;
    }

    final provData = await auth.getProvinces();

    if (_selectedProvince != null) {
      final cityData = await auth.getCities(_selectedProvince!);
      _cities = cityData;
      if (_selectedCity != null) {
        final distData = await auth.getDistricts(_selectedCity!);
        _districts = distData;
      }
    }

    if (mounted) {
      setState(() {
        _provinces = provData;
        _isInitialDataLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 800,
    );

    if (image == null) return;

    final imageBytes = await image.readAsBytes();
    if (!mounted) return;

    final croppedFile = await Navigator.of(context).push<File?>(
      MaterialPageRoute(
        builder: (_) => _OutletImageCropScreen(imageBytes: imageBytes),
      ),
    );

    if (croppedFile != null && mounted) {
      setState(() => _imageFile = croppedFile);
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
    final data = await context.read<AuthProvider>().getCities(provinceCode);
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
    final data = await context.read<AuthProvider>().getDistricts(cityCode);
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

  void _handleUpdate() async {
    if (_namaController.text.isEmpty || _selectedDistrict == null) {
      CustomToast.show(context, message: "Mohon lengkapi data", isError: true);
      return;
    }

    if (_outletLocation == null) {
      CustomToast.show(
        context,
        message: 'Pilih lokasi outlet di Google Maps terlebih dahulu',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    final nama = _namaController.text.trim();
    final noHp = _phoneController.text.trim();
    final alamat = _alamatController.text.trim();

    final res = await context.read<AppProvider>().updateOutletProfile(
      nama: nama,
      noHp: noHp,
      alamat: alamat,
      provinsi: _selectedProvince!,
      kota: _selectedCity!,
      kecamatan: _selectedDistrict!,
      latitude: _outletLocation!.latitude,
      longitude: _outletLocation!.longitude,
      locationRadiusMeters: _locationRadiusMeters,
      imageFile: _imageFile,
    );

    debugPrint('🔍 updateOutletProfile result: $res');

    if (res['success'] == true && mounted) {
      // ✅ Sync nota dulu baru fire event
      await context.read<NotaSettingsProvider>().syncOutletInfoToNota(
        nama: nama,
        alamat: alamat,
        kontak: noHp,
      );

      // ✅ Fire OutletSwitched setelah semua selesai via AppProvider
      if (mounted) context.read<AppProvider>().fireOutletSwitched();
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (res['success'] == true) {
        CustomToast.show(context, message: "Profil Outlet berhasil diperbarui");
        Navigator.pop(context, true);
      } else {
        CustomToast.show(
          context,
          message: res['message'] ?? 'Gagal update',
          isError: true,
        );
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
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Edit Profil Outlet",
          style: TextStyle(
            color: Colors.black,
            fontWeight: AppFont.w800,
            fontSize: 16,
          ),
        ),
      ),
      body: _isInitialDataLoading
          ? const EditOutletProfileSkeleton()
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImagePicker(),
                const SizedBox(height: 32),
                CustomTextField(
                  controller: _namaController,
                  labelText: 'Nama outlet',
                  isRequired: true,
                  hintText: 'Masukkan nama outlet Anda',
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _phoneController,
                  labelText: 'No handphone outlet',
                  keyboardType: TextInputType.phone,
                  hintText: 'Masukkan nomor handphone outlet Anda',
                  isRequired: true,
                ),
                const SizedBox(height: 16),
                _buildLabel("Provinsi", isRequired: true),
                _buildSelectorTrigger(
                  label: _getNameFromList(_provinces, _selectedProvince),
                  isLoading: _isProvinceLoading,
                  onTap: () => _showLocationPicker(
                    "Pilih Provinsi",
                    _provinces,
                    _selectedProvince,
                    (c) => _fetchCities(c),
                  ),
                ),
                const SizedBox(height: 16),
                _buildLabel("Kabupaten/Kota", isRequired: true),
                _buildSelectorTrigger(
                  label: _getNameFromList(_cities, _selectedCity),
                  isLoading: _isCityLoading,
                  onTap: () => _showLocationPicker(
                    "Pilih Kota",
                    _cities,
                    _selectedCity,
                    (c) => _fetchDistricts(c),
                  ),
                ),
                const SizedBox(height: 16),
                _buildLabel("Kecamatan", isRequired: true),
                _buildSelectorTrigger(
                  label: _getNameFromList(_districts, _selectedDistrict),
                  isLoading: _isDistrictLoading,
                  onTap: () => _showLocationPicker(
                    "Pilih Kecamatan",
                    _districts,
                    _selectedDistrict,
                    (c) => setState(() => _selectedDistrict = c),
                  ),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _alamatController,
                  labelText: 'Alamat Lengkap',
                  maxLines: 3,
                  hintText: 'Masukkan alamat lengkap outlet Anda',
                  isRequired: true,
                ),
                const SizedBox(height: 16),
                _buildOutletLocationField(),
              ],
            ),
          ),
        ),
        _buildActionButton(),
      ],
    );
  }

  Widget _buildOutletLocationField() {
    final location = _outletLocation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Lokasi Outlet untuk Absensi', isRequired: true),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final selected = await Navigator.push<LatLng>(
              context,
              MaterialPageRoute(
                builder: (_) => OutletLocationPicker(initialLocation: location),
              ),
            );
            if (selected != null && mounted) {
              setState(() => _outletLocation = selected);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: AppPalette.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    location == null
                        ? 'Pilih titik outlet di Google Maps'
                        : '${location.latitude.toStringAsFixed(6)}, '
                              '${location.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      color: location == null ? Colors.grey : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Karyawan dapat absen dalam radius $_locationRadiusMeters meter dari titik ini.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipOval(
              child: _imageFile != null
                  ? Image.file(_imageFile!, fit: BoxFit.cover)
                  : (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
                  ? AppCachedNetworkImage(
                      imageUrl: ApiClient.resolveImageVariantUrl(
                        _currentImageUrl,
                        width: 720,
                      ),
                      fit: BoxFit.cover,
                      errorWidget: Image.asset(
                        'assets/icons/logo/logo_final_with_frame.webp',
                        fit: BoxFit.contain,
                      ),
                    )
                  : Image.asset(
                      'assets/icons/logo/logo_final_with_frame.webp',
                      fit: BoxFit.contain,
                    ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppPalette.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationPicker(
    String title,
    List<dynamic> items,
    String? selectedCode,
    Function(String code) onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                title,
                style: const TextStyle(fontWeight: AppFont.w700, fontSize: 16),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: AppCircularLoader())
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final item = items[i];
                        final isSelected =
                            item['code'].toString() == selectedCode;
                        return ListTile(
                          title: Text(
                            item['name'],
                            style: TextStyle(
                              color: isSelected
                                  ? AppPalette.primary
                                  : Colors.black,
                              fontWeight: isSelected
                                  ? AppFont.w700
                                  : AppFont.w400,
                            ),
                          ),
                          onTap: () {
                            onSelected(item['code'].toString());
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: AppFont.w700,
        color: Color(0xFF2C3E50),
      ),
    ),
  );

  Widget _buildSelectorTrigger({
    required String label,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9F9),
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: label == "Pilih" ? Colors.grey : Colors.black,
                fontWeight: AppFont.w600,
              ),
            ),
            isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: AppCircularLoader(strokeWidth: 2),
                  )
                : const Icon(Icons.keyboard_arrow_down),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleUpdate,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppPalette.primary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: AppCircularLoader(color: Colors.white, strokeWidth: 3),
                )
              : const Text(
                  'SIMPAN PERUBAHAN',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: AppFont.w900,
                    letterSpacing: 1,
                  ),
                ),
        ),
      ),
    ),
  );
}

class _OutletImageCropScreen extends StatefulWidget {
  const _OutletImageCropScreen({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_OutletImageCropScreen> createState() => _OutletImageCropScreenState();
}

class _OutletImageCropScreenState extends State<_OutletImageCropScreen> {
  final _cropController = CropController();

  bool _isReady = false;
  bool _isCropping = false;

  Future<void> _handleCropResult(CropResult result) async {
    switch (result) {
      case CropSuccess(:final croppedImage):
        final file = File(
          '${Directory.systemTemp.path}/outlet_crop_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        await file.writeAsBytes(croppedImage);
        if (mounted) Navigator.pop(context, file);
      case CropFailure(:final cause):
        if (!mounted) return;
        setState(() => _isCropping = false);
        CustomToast.show(
          context,
          message: 'Gagal crop foto: $cause',
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
          'Crop Foto Outlet',
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
                      size: 0.82,
                      aspectRatio: 1,
                    ),
                    interactive: true,
                    fixCropRect: true,
                    withCircleUi: true,
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
                    'Geser dan zoom foto agar pas di area outlet.',
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
                              'GUNAKAN FOTO',
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
