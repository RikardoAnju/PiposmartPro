import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
// ignore_for_file: use_build_context_synchronously

import 'package:ayocucinew/core/theme/app_font.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/setting_provider.dart';
import '../../../shared/widgets/custom_textfield.dart';
import '../../../shared/widgets/custom_toast.dart';
import 'change_password_screen.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class EditProfileOwnerScreen extends StatefulWidget {
  final bool isEditMode;

  const EditProfileOwnerScreen({super.key, this.isEditMode = false});

  @override
  State<EditProfileOwnerScreen> createState() => _EditProfileOwnerScreenState();
}

class _EditProfileOwnerScreenState extends State<EditProfileOwnerScreen> {
  static const List<Map<String, String>> _deleteReasons = [
    {'value': 'business_closed', 'label': 'Usaha sudah tutup'},
    {'value': 'switch_app', 'label': 'Pindah ke aplikasi lain'},
    {'value': 'privacy_concern', 'label': 'Masalah privasi / keamanan'},
    {'value': 'duplicate_account', 'label': 'Akun ganda'},
    {'value': 'other', 'label': 'Lainnya'},
  ];

  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _referralController = TextEditingController(); // Controller baru
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoadData();
  }

  void _checkAccessAndLoadData() async {
    final auth = context.read<AuthProvider>();

    if (auth.actorType != 'user') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        CustomToast.show(
          context,
          message: "Akses Ditolak: Khusus Owner",
          isError: true,
        );
        Navigator.pop(context);
      });
      return;
    }

    final res = await auth.getMe();
    if (res['success'] && mounted) {
      final data = res['data'];
      setState(() {
        _namaController.text = data['usr_nama'] ?? '';
        _emailController.text = data['usr_email'] ?? '';
        _phoneController.text = data['usr_nohp'] ?? '';
        _referralController.text =
            data['usr_referral_code'] ?? ''; // Set referral code
        _isInitialLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isEditMode = widget.isEditMode;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafe = math.max(
      MediaQuery.of(context).padding.bottom,
      MediaQuery.of(context).viewPadding.bottom,
    );
    final scrollBottomPadding = isEditMode
        ? 196.0 + bottomSafe
        : 146.0 + bottomSafe;

    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Profil Owner",
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
      ),
      body: _isInitialLoading
          ? _OwnerProfileSkeleton(
              isEditMode: isEditMode,
              bottomSafe: bottomSafe,
            )
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(25, 25, 25, scrollBottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Informasi Pribadi",
                    style: TextStyle(fontSize: 14, color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    controller: _namaController,
                    labelText: "Nama Lengkap",
                    prefixIcon: const Icon(Icons.person_outline),
                    hintText: "Masukkan nama lengkap Anda",
                    readOnly: !isEditMode,
                    fillColor: isEditMode ? null : Colors.grey[50],
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _emailController,
                    labelText: "Email",
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.email_outlined),
                    hintText: "Masukkan alamat email Anda",
                    readOnly: !isEditMode,
                    fillColor: isEditMode ? null : Colors.grey[50],
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _phoneController,
                    labelText: "Nomor WhatsApp",
                    keyboardType: TextInputType.phone,
                    prefixIcon: const Icon(Icons.phone_android_outlined),
                    hintText: "Masukkan nomor WhatsApp Anda",
                    readOnly: !isEditMode,
                    fillColor: isEditMode ? null : Colors.grey[50],
                  ),
                  const SizedBox(height: 16),
                  // Field Referral Code (Read Only)
                  CustomTextField(
                    controller: _referralController,
                    labelText: "Kode Referral Anda",
                    readOnly: true, // Membuat field tidak bisa diedit
                    prefixIcon: const Icon(Icons.confirmation_number_outlined),
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.copy_rounded,
                        size: 20,
                        color: Colors.blue,
                      ),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: _referralController.text),
                        );
                        CustomToast.show(
                          context,
                          message: "Kode referral disalin!",
                        );
                      },
                    ),
                    hintText: "-",
                    fillColor: Colors.grey[100],
                  ),
                  if (isEditMode) ...[
                    const SizedBox(height: 30),
                    const Divider(),
                    ListTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen(),
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.lock_reset_rounded,
                        color: AppPalette.primary,
                      ),
                      title: const Text(
                        "Ganti Kata Sandi",
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: const Text("Keamanan akun Anda"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    ),
                    const Divider(),
                    const SizedBox(height: 12),
                    _buildDangerZoneCard(auth),
                  ] else ...[
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: _isInitialLoading
          ? null
          : AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SafeArea(
                top: false,
                minimum: EdgeInsets.fromLTRB(25, 12, 25, 20 + bottomSafe),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: isEditMode
                        ? auth.isLoading
                              ? null
                              : () async {
                                  final currentContext = context;
                                  final res = await auth.updateOwnerProfile(
                                    nama: _namaController.text,
                                    email: _emailController.text,
                                    noHp: _phoneController.text,
                                  );
                                  if (!mounted) return;
                                  if (res['success']) {
                                    CustomToast.show(
                                      currentContext,
                                      message: "Profil diperbarui",
                                    );
                                    Navigator.pop(currentContext);
                                  }
                                }
                        : () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const EditProfileOwnerScreen(
                                  isEditMode: true,
                                ),
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isEditMode && auth.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: AppCircularLoader(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : Text(
                            isEditMode ? "SIMPAN PROFIL" : "EDIT PROFIL",
                            style: const TextStyle(color: Colors.white),
                          ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildDangerZoneCard(AuthProvider auth) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.redAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Zona Berbahaya",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: AppFont.w700,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Hapus akun hanya tersedia dari profil owner dan akan diminta alasan dulu.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: auth.isLoading
                  ? null
                  : () => _showDeleteAccountFlow(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(
                Icons.delete_forever_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
              label: const Text(
                "HAPUS AKUN OWNER",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: AppFont.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountFlow(BuildContext context) {
    HapticFeedback.mediumImpact();
    final confirmController = TextEditingController();
    final detailController = TextEditingController();
    String? selectedReason;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetBuildContext, setSheetState) {
            final isConfirmReady =
                selectedReason != null &&
                confirmController.text.trim().toUpperCase() == 'HAPUS AKUN';

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetBuildContext).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Container(
                            width: 48,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          "Hapus Akun Owner",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: AppFont.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Proses ini permanen. Pilih alasan penghapusan, isi detail bila perlu, lalu ketik HAPUS AKUN untuk melanjutkan.",
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          "Alasan penghapusan",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: AppFont.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _deleteReasons.map((reason) {
                            final value = reason['value']!;
                            final label = reason['label']!;
                            final isSelected = selectedReason == value;
                            return ChoiceChip(
                              label: Text(label),
                              selected: isSelected,
                              selectedColor: Colors.redAccent.withValues(
                                alpha: 0.12,
                              ),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.redAccent
                                    : const Color(0xFF2C3E50),
                                fontWeight: isSelected
                                    ? AppFont.w600
                                    : AppFont.w400,
                              ),
                              onSelected: (_) {
                                setSheetState(() {
                                  selectedReason = value;
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: detailController,
                          labelText: "Detail alasan",
                          hintText: "Contoh: pindah operasional ke sistem lain",
                          prefixIcon: const Icon(Icons.notes_rounded),
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: confirmController,
                          labelText: "Ketik HAPUS AKUN untuk konfirmasi",
                          hintText: "HAPUS AKUN",
                          prefixIcon: const Icon(Icons.verified_user_rounded),
                          onChanged: (_) {
                            setSheetState(() {});
                          },
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: (!isConfirmReady || isSubmitting)
                                ? null
                                : () async {
                                    final currentContext = context;
                                    if (selectedReason == null) {
                                      CustomToast.show(
                                        currentContext,
                                        message:
                                            "Pilih alasan penghapusan dulu",
                                        isError: true,
                                      );
                                      return;
                                    }

                                    setSheetState(() {
                                      isSubmitting = true;
                                    });

                                    final auth = context.read<AuthProvider>();
                                    final res = await auth.deleteAccount(
                                      reason: selectedReason!,
                                      reasonDetail: detailController.text,
                                    );

                                    if (!mounted) return;
                                    setSheetState(() {
                                      isSubmitting = false;
                                    });

                                    if (res['success'] == true) {
                                      currentContext
                                          .read<SettingProvider>()
                                          .clearData();
                                      Navigator.pop(sheetContext);
                                      Navigator.pushReplacementNamed(
                                        currentContext,
                                        '/login',
                                      );
                                    } else {
                                      CustomToast.show(
                                        currentContext,
                                        message:
                                            res['message'] ??
                                            'Gagal menghapus akun',
                                        isError: true,
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    "HAPUS PERMANEN",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: AppFont.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Center(
                            child: Text(
                              "Batal",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _OwnerProfileSkeleton extends StatelessWidget {
  final bool isEditMode;
  final double bottomSafe;

  const _OwnerProfileSkeleton({
    required this.isEditMode,
    required this.bottomSafe,
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                25,
                25,
                25,
                (isEditMode ? 196.0 : 146.0) + bottomSafe,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeletonBox(
                    width: isEditMode ? 120 : 92,
                    height: 14,
                    radius: 99,
                  ),
                  const SizedBox(height: 20),
                  const AppSkeletonBox(height: 74, radius: 24),
                  const SizedBox(height: 16),
                  const AppSkeletonBox(height: 74, radius: 24),
                  const SizedBox(height: 16),
                  const AppSkeletonBox(height: 74, radius: 24),
                  const SizedBox(height: 16),
                  const AppSkeletonBox(height: 74, radius: 24),
                  if (isEditMode) ...[
                    const SizedBox(height: 30),
                    AppSkeletonBox(
                      width: MediaQuery.of(context).size.width,
                      height: 1,
                      radius: 0,
                    ),
                    const SizedBox(height: 20),
                    const AppSkeletonBox(height: 68, radius: 18),
                    const SizedBox(height: 20),
                    AppSkeletonBox(
                      width: MediaQuery.of(context).size.width,
                      height: 1,
                      radius: 0,
                    ),
                    const SizedBox(height: 20),
                    const AppSkeletonBox(height: 180, radius: 24),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            minimum: EdgeInsets.fromLTRB(25, 12, 25, 20 + bottomSafe),
            child: const AppSkeletonBox(
              width: double.infinity,
              height: 54,
              radius: 12,
            ),
          ),
        ],
      ),
    );
  }
}
