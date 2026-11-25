// lib/providers/register_provider.dart

import 'package:flutter/material.dart';

class RegisterProvider extends ChangeNotifier {
  // 1. Controller Data Akun
  final phoneController = TextEditingController();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final referralController = TextEditingController();

  // 2. Controller Data Outlet
  final outletNameController = TextEditingController();
  final outletPhoneController = TextEditingController();
  final outletAddressController = TextEditingController();

  // 3. State Lokasi & Sumber Lead
  String? selectedProvince;
  String? selectedCity;
  String? selectedDistrict;
  String? selectedLeadSource;
  String? selectedBusinessLocation;
  String? selectedBusinessCapital;
  String? selectedEmployeeCount;
  String? selectedMachineCount;
  DateTime? selectedBusinessStartDate;

  bool isGoogleLogin = false;
  String? googleId;
  String? googleRegistrationToken;
  bool isAppleLogin = false;
  String? appleId;
  String? appleRegistrationToken;
  String? otpVerificationToken;

  bool get isSocialLogin => isGoogleLogin || isAppleLogin;
  String? get socialEmail {
    final value = emailController.text.trim();
    return value.isEmpty ? null : value;
  }

  void reset() {
    phoneController.clear();
    nameController.clear();
    emailController.clear();
    referralController.clear();
    outletNameController.clear();
    outletPhoneController.clear();
    outletAddressController.clear();

    selectedProvince = null;
    selectedCity = null;
    selectedDistrict = null;
    selectedLeadSource = null;
    selectedBusinessLocation = null;
    selectedBusinessCapital = null;
    selectedEmployeeCount = null;
    selectedMachineCount = null;
    selectedBusinessStartDate = null;
    isGoogleLogin = false;
    googleId = null;
    googleRegistrationToken = null;
    isAppleLogin = false;
    appleId = null;
    appleRegistrationToken = null;
    otpVerificationToken = null;

    notifyListeners();
  }

  void initGoogleData(Map<String, dynamic>? data) {
    if (data != null) {
      resetSocialState();
      nameController.text = data['name'] ?? '';
      emailController.text = data['email'] ?? '';
      googleId = data['google_id'];
      googleRegistrationToken = data['registration_token'];
      otpVerificationToken = null;
      isGoogleLogin = true;
      notifyListeners();
    }
  }

  void initAppleData(Map<String, dynamic>? data) {
    if (data != null) {
      resetSocialState();
      nameController.text = data['name'] ?? '';
      emailController.text = data['email'] ?? '';
      appleId = data['apple_id'];
      appleRegistrationToken = data['registration_token'];
      otpVerificationToken = null;
      isAppleLogin = true;
      notifyListeners();
    }
  }

  void resetSocialState() {
    isGoogleLogin = false;
    googleId = null;
    googleRegistrationToken = null;
    isAppleLogin = false;
    appleId = null;
    appleRegistrationToken = null;
  }

  void setOtpVerificationToken(String? token) {
    otpVerificationToken = token;
    notifyListeners();
  }

  void updateLeadSource(String? source) {
    selectedLeadSource = source;
    notifyListeners();
  }

  void updateLocation(String? p, String? c, String? d) {
    selectedProvince = p;
    selectedCity = c;
    selectedDistrict = d;
    notifyListeners();
  }

  void updateBusinessLocation(String? value) {
    selectedBusinessLocation = value;
    notifyListeners();
  }

  void updateBusinessCapital(String? value) {
    selectedBusinessCapital = value;
    notifyListeners();
  }

  void updateEmployeeCount(String? value) {
    selectedEmployeeCount = value;
    notifyListeners();
  }

  void updateMachineCount(String? value) {
    selectedMachineCount = value;
    notifyListeners();
  }

  void updateBusinessStartDate(DateTime? date) {
    selectedBusinessStartDate = date;
    notifyListeners();
  }

  // PAYLOAD UPDATE: Mengikuti struktur JSON bersarang (Nested Object)
  Map<String, dynamic> collectFinalData() {
    return {
      'username': nameController.text.trim(),
      'email': emailController.text.trim(),
      'nomor_hp': phoneController.text.trim(),
      'google_id': googleId,
      'google_registration_token': googleRegistrationToken,
      'apple_id': appleId,
      'apple_registration_token': appleRegistrationToken,
      'otp_verification_token': otpVerificationToken,
      'referral_code': referralController.text.trim(),
      'lead_source': selectedLeadSource,
      'outlet': {
        'nama_outlet': outletNameController.text.trim(),
        'nomor_hp': outletPhoneController.text.trim(),
        'provinsi': selectedProvince,
        'kota': selectedCity,
        'kecamatan': selectedDistrict ?? "-",
        'alamat': outletAddressController.text.trim(),
        'tipe_lokasi_usaha': selectedBusinessLocation,
        'modal_usaha': selectedBusinessCapital,
        'jumlah_karyawan': selectedEmployeeCount,
        'jumlah_mesin': selectedMachineCount,
        'tanggal_berjalan': selectedBusinessStartDate != null
            ? '${selectedBusinessStartDate!.year}-${selectedBusinessStartDate!.month.toString().padLeft(2, '0')}-01'
            : null,
      },
    };
  }

  @override
  void dispose() {
    phoneController.dispose();
    nameController.dispose();
    emailController.dispose();
    referralController.dispose();
    outletNameController.dispose();
    outletPhoneController.dispose();
    outletAddressController.dispose();
    super.dispose();
  }
}
