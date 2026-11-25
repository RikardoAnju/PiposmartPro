import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
// ignore_for_file: use_build_context_synchronously
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import '../../../../providers/pegawai_provider.dart';
import '../../../../providers/role_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/app_provider.dart';
import '../../../../providers/payroll_provider.dart';
import '../../../../data/models/pegawai_model.dart';
import '../../../../data/models/role_model.dart';
import '../../../../shared/widgets/custom_toast.dart';
import '../../../../shared/widgets/custom_textfield.dart';
import '../../../../shared/widgets/currency_formatter.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'day_of_month_picker.dart';
import 'salary_form_fields.dart';

class EmployeeFormScreen extends StatefulWidget {
  final Pegawai? existing;
  final int initialStep;

  const EmployeeFormScreen({super.key, this.existing, this.initialStep = 0});

  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _nohpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _storage = const FlutterSecureStorage();

  String? _selectedRoleId;
  DateTime? _tanggalLahir;
  int _status = 1;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isEditingSelf = false;
  bool _allOutletAccess = false;
  int _currentStep = 0;
  String? _savedEmployeeId;
  final _salaryFormKey = GlobalKey<SalarySettingsScreenEmbeddedState>();

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep == 1 ? 1 : 0;
    _initData();

    if (widget.existing != null) {
      _namaController.text = widget.existing!.nama;
      _emailController.text = widget.existing!.email;
      _nohpController.text = widget.existing!.nohp;
      _selectedRoleId = widget.existing!.roleId;
      _tanggalLahir = widget.existing!.tanggalLahir;
      _status = widget.existing!.status;
      _allOutletAccess = widget.existing!.allOutletAccess;
    }
  }

  Future<void> _initData() async {
    context.read<RoleProvider>().fetchRoles();
    context.read<PayrollProvider>().fetchConfigs(silent: true);

    final currentActorId = await _storage.read(key: 'actor_id');
    final savedEmail = await _storage.read(key: 'saved_email');

    if (mounted) {
      setState(() {
        _isEditingSelf =
            widget.existing != null &&
            ((widget.existing?.id == currentActorId) ||
                (widget.existing?.email == savedEmail));
      });
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _nohpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSave({bool includeSalaryConfig = false}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoleId == null) {
      CustomToast.show(
        context,
        message: "Pilih jabatan terlebih dahulu",
        isError: true,
      );
      return;
    }

    final salaryState = _salaryFormKey.currentState;
    if (includeSalaryConfig) {
      final salaryError = salaryState?.validateCurrentDraft();
      if (salaryError != null) {
        CustomToast.show(context, message: salaryError, isError: true);
        return;
      }
    }

    final auth = context.read<AuthProvider>();
    if (_isEditingSelf &&
        auth.actorType != 'user' &&
        _selectedRoleId != widget.existing?.roleId) {
      CustomToast.show(
        context,
        message: "Aksi ditolak: Anda tidak bisa mengubah jabatan sendiri",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    final employeeId = widget.existing?.id ?? _savedEmployeeId;
    final res = await context.read<PegawaiProvider>().saveEmployee(
      id: employeeId,
      nama: _namaController.text.trim(),
      email: _emailController.text.trim(),
      roleId: _selectedRoleId!,
      nohp: _nohpController.text.trim(),
      tanggalLahir: _tanggalLahir,
      password: _passwordController.text.isNotEmpty
          ? _passwordController.text
          : null,
      status: _status,
      allOutletAccess: auth.actorType == 'user' ? _allOutletAccess : null,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (res['success']) {
        final savedData = res['data'];
        if (_savedEmployeeId == null) {
          final dynamic returnedId = savedData is Map ? savedData['id'] : null;
          if (returnedId != null) {
            _savedEmployeeId = returnedId.toString();
          }
        }

        // Pegawai baru yang melewati kuota base → backend menyimpannya sebagai
        // add-on non-aktif (status 0). Harus diberitahukan ke owner, jangan
        // tertelan oleh pesan sukses simpan gaji.
        final bool isNewAddonPending =
            employeeId == null &&
            savedData is Map &&
            savedData['type']?.toString() == 'addon' &&
            (savedData['status'] == 0 ||
                savedData['status']?.toString() == '0');

        if (includeSalaryConfig) {
          final currentEmployeeId =
              widget.existing?.id ?? _savedEmployeeId ?? employeeId;
          final salaryPayload = salaryState?.currentPayload();
          if (salaryPayload == null) {
            CustomToast.show(
              context,
              message: "Lengkapi pengaturan gaji terlebih dahulu",
              isError: true,
            );
            return;
          }
          if (currentEmployeeId == null || currentEmployeeId.isEmpty) {
            CustomToast.show(
              context,
              message:
                  "ID pegawai belum tersedia untuk menyimpan pengaturan gaji",
              isError: true,
            );
            return;
          }

          final payrollRes = await context
              .read<PayrollProvider>()
              .saveSalaryConfig(
                pegawaiId: currentEmployeeId,
                payload: salaryPayload,
              );

          if (!mounted) return;

          if (payrollRes['success'] == true) {
            if (_isEditingSelf) {
              await auth.silentRefreshToken();
              await context.read<AppProvider>().fetchAppData(force: true);
            }
            if (isNewAddonPending) {
              _showAddonPendingDialog(
                res['message']?.toString() ??
                    'Pegawai ditambahkan sebagai add-on dan belum aktif. Aktifkan untuk mengaktifkannya.',
              );
            } else {
              CustomToast.show(context, message: payrollRes['message']);
              Navigator.pop(context);
            }
            return;
          }

          CustomToast.show(
            context,
            message: payrollRes['message'],
            isError: true,
          );
          return;
        }

        if (_isEditingSelf) {
          await auth.silentRefreshToken();
          await context.read<AppProvider>().fetchAppData(force: true);
        }
        if (isNewAddonPending) {
          _showAddonPendingDialog(
            res['message']?.toString() ??
                'Pegawai ditambahkan sebagai add-on dan belum aktif. Aktifkan untuk mengaktifkannya.',
          );
        } else {
          CustomToast.show(context, message: res['message']);
          Navigator.pop(context);
        }
      } else {
        if (res['is_limit'] == true) {
          _showLimitDialog(res['message']);
        } else {
          CustomToast.show(context, message: res['message'], isError: true);
        }
      }
    }
  }

  void _showLimitDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Kuota Penuh",
          style: TextStyle(fontWeight: AppFont.w700),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("TUTUP"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/addon-shop');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.primary,
            ),
            child: const Text(
              "BELI SLOT",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddonPendingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Pegawai Add-on (Non-aktif)",
          style: TextStyle(fontWeight: AppFont.w700),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            child: const Text("NANTI"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context);
              Navigator.pushNamed(context, '/addon-shop');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.primary,
            ),
            child: const Text(
              "AKTIFKAN",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _goNextStep() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoleId == null) {
      CustomToast.show(
        context,
        message: "Pilih jabatan terlebih dahulu",
        isError: true,
      );
      return;
    }
    setState(() => _currentStep = 1);
  }

  void _skipSalaryAndSave() {
    _handleSave(includeSalaryConfig: false);
  }

  @override
  Widget build(BuildContext context) {
    final List<Role> roles = context.watch<RoleProvider>().roles;
    final bool isRoleLoading = context.watch<RoleProvider>().isLoading;
    final auth = context.watch<AuthProvider>();
    final pegawaiProv = context.watch<PegawaiProvider>();
    final payrollProv = context.watch<PayrollProvider>();
    final Map<String, dynamic>? employeeSalaryConfig = widget.existing == null
        ? null
        : _findEmployeeSalaryConfig(payrollProv.configs, widget.existing!.id);

    int baseCount = pegawaiProv.employees.where((e) => e.type == 'base').length;
    bool willBeAddon = widget.existing == null && baseCount >= 2;

    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentStep == 1 && mounted) {
          setState(() => _currentStep = 0);
        }
      },
      child: AppScaffold(
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
            onPressed: () {
              if (_currentStep == 1) {
                setState(() => _currentStep = 0);
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(
            widget.existing != null ? "EDIT PEGAWAI" : "TAMBAH PEGAWAI",
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: AppFont.w800,
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStepIndicator(),
                const SizedBox(height: 18),
                if (_currentStep == 0) ...[
                  if (willBeAddon) _buildQuotaWarning(),
                  const SizedBox(height: 20),
                  _buildDataStep(roles, isRoleLoading, auth),
                  const SizedBox(height: 32),
                  _buildPrimaryButton(
                    text: "LANJUTKAN",
                    onPressed: _goNextStep,
                  ),
                ] else ...[
                  SalarySettingsScreenEmbedded(
                    key: _salaryFormKey,
                    initialConfig: employeeSalaryConfig,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSecondaryButton(
                          text: "LEWATI",
                          onPressed: () => _skipSalaryAndSave(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildPrimaryButton(
                          text: "SIMPAN",
                          onPressed: _isLoading
                              ? null
                              : () => _handleSave(includeSalaryConfig: true),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 70),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic>? _findEmployeeSalaryConfig(
    List<Map<String, dynamic>> configs,
    String employeeId,
  ) {
    for (final config in configs) {
      if (config['pegawai_id']?.toString() == employeeId) {
        return config;
      }
    }
    return null;
  }

  Widget _buildStepIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: _currentStep == 0
                      ? AppPalette.primary
                      : const Color(0xFFD0D5DD),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: _currentStep == 1
                      ? AppPalette.primary
                      : const Color(0xFFD0D5DD),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                "Informasi Pegawai",
                style: TextStyle(
                  color: _currentStep == 0 ? AppPalette.ink : AppPalette.muted,
                  fontWeight: AppFont.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Pengaturan Gaji",
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: _currentStep == 1 ? AppPalette.ink : AppPalette.muted,
                  fontWeight: AppFont.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDataStep(List<Role> roles, bool isLoading, AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Informasi Pegawai",
          style: TextStyle(
            fontSize: 18,
            fontWeight: AppFont.w800,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "Lengkapi data utama pegawai terlebih dahulu.",
          style: TextStyle(fontSize: 12, color: AppPalette.muted),
        ),
        const SizedBox(height: 18),
        CustomTextField(
          controller: _namaController,
          labelText: "NAMA PEGAWAI",
          hintText: "Contoh: Budi Santoso",
          isRequired: true,
          textCapitalization: TextCapitalization.words,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Nama pegawai wajib diisi'
              : null,
        ),
        const SizedBox(height: 18),
        CustomTextField(
          controller: _emailController,
          labelText: "EMAIL LOGIN",
          hintText: "budi@mail.com",
          keyboardType: TextInputType.emailAddress,
          isRequired: true,
          readOnly: _isEditingSelf,
          validator: (v) {
            final t = v?.trim() ?? '';
            if (t.isEmpty) return 'Email login wajib diisi';
            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
              return 'Format email tidak valid';
            }
            return null;
          },
        ),
        const SizedBox(height: 18),
        CustomTextField(
          controller: _nohpController,
          labelText: "NOMOR HP",
          hintText: "0812...",
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 18),
        _buildTanggalLahirField(),
        const SizedBox(height: 22),
        _buildRoleSection(roles, isLoading, auth),
        if (auth.actorType == 'user') ...[
          const SizedBox(height: 18),
          _buildAllOutletAccessToggle(),
        ],
        const SizedBox(height: 22),
        CustomTextField(
          controller: _passwordController,
          labelText: "PASSWORD BARU",
          hintText: widget.existing != null
              ? "Kosongkan jika tidak diganti"
              : "Minimal 6 karakter",
          isPassword: true,
          isPasswordVisible: _isPasswordVisible,
          onTogglePassword: () =>
              setState(() => _isPasswordVisible = !_isPasswordVisible),
          isRequired: widget.existing == null,
          validator: (v) {
            final t = v ?? '';
            if (widget.existing == null) {
              if (t.isEmpty) return 'Password wajib diisi';
              if (t.length < 6) return 'Password minimal 6 karakter';
            } else if (t.isNotEmpty && t.length < 6) {
              return 'Password minimal 6 karakter';
            }
            return null;
          },
        ),
        if (widget.existing != null) ...[
          const SizedBox(height: 22),
          _buildStatusToggle(auth),
        ],
      ],
    );
  }

  Widget _buildQuotaWarning() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "INFO KUOTA PEGAWAI",
                  style: TextStyle(
                    fontWeight: AppFont.w700,
                    fontSize: 12,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Kuota gratis sudah penuh. Pegawai baru akan otomatis berstatus 'Add-on' dan non-aktif.",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue[900],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTanggalLahirField() {
    final String displayText = _tanggalLahir == null
        ? 'Opsional'
        : DateFormat('dd MMM yyyy', 'id_ID').format(_tanggalLahir!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "TANGGAL LAHIR",
          style: TextStyle(
            fontSize: 13,
            fontWeight: AppFont.w700,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickTanggalLahir,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cake_rounded,
                  color: AppPalette.primary,
                  size: 17,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      fontSize: 13,
                      color: _tanggalLahir == null
                          ? Colors.black45
                          : const Color(0xFF2C3E50),
                    ),
                  ),
                ),
                if (_tanggalLahir != null)
                  GestureDetector(
                    onTap: () => setState(() => _tanggalLahir = null),
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(
                        Icons.close_rounded,
                        size: 17,
                        color: Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Tidak wajib diisi.",
          style: TextStyle(fontSize: 11, color: AppPalette.muted),
        ),
      ],
    );
  }

  Future<void> _pickTanggalLahir() async {
    final now = DateTime.now();
    final initial =
        _tanggalLahir ?? DateTime(now.year - 20, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: 'Pilih tanggal lahir',
    );
    if (picked != null && mounted) {
      setState(() => _tanggalLahir = picked);
    }
  }

  Widget _buildRoleSection(
    List<Role> roles,
    bool isLoading,
    AuthProvider auth,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "JABATAN / ROLE",
              style: TextStyle(
                fontSize: 13,
                fontWeight: AppFont.w700,
                color: Color(0xFF2C3E50),
              ),
            ),
            if (!_isEditingSelf || auth.actorType == 'user')
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/kelola-role'),
                child: const Text(
                  "KELOLA",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: AppFont.w800,
                    color: AppPalette.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isEditingSelf && auth.actorType != 'user')
          _buildReadOnlyRoleBox()
        else if (isLoading)
          const LinearProgressIndicator(
            color: AppPalette.primary,
            backgroundColor: Color(0xFFF9F9F9),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: roles
                .map((role) => _buildRoleSelectionCard(role))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildReadOnlyRoleBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: Colors.grey, size: 18),
          const SizedBox(width: 10),
          Text(
            widget.existing?.role?.nama ?? "Role Tidak Diketahui",
            style: const TextStyle(
              fontWeight: AppFont.w700,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllOutletAccessToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _allOutletAccess
            ? AppPalette.primary.withValues(alpha: 0.06)
            : const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _allOutletAccess
              ? AppPalette.primary.withValues(alpha: 0.35)
              : const Color(0xFFE0E0E0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppPalette.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: AppPalette.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Akses Semua Outlet',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: AppFont.w800,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Bisa berpindah ke seluruh cabang saat ini dan cabang baru.',
                  style: TextStyle(fontSize: 11, color: AppPalette.muted),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _allOutletAccess,
            activeTrackColor: AppPalette.primary,
            onChanged: (value) => setState(() => _allOutletAccess = value),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelectionCard(Role role) {
    bool isSelected = _selectedRoleId == role.id;
    return InkWell(
      onTap: () => setState(() => _selectedRoleId = role.id),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppPalette.primary.withValues(alpha: 0.1)
              : const Color(0xFFF9F9F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppPalette.primary : const Color(0xFFE0E0E0),
          ),
        ),
        child: Text(
          role.nama,
          style: TextStyle(
            fontSize: 13,
            fontWeight: AppFont.w700,
            color: isSelected ? AppPalette.primary : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusToggle(AuthProvider auth) {
    bool canChangeStatus = !_isEditingSelf || auth.actorType == 'user';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "PEGAWAI AKTIF",
            style: TextStyle(
              fontWeight: AppFont.w800,
              color: Color(0xFF2C3E50),
            ),
          ),
          Switch(
            value: _status == 1,
            onChanged: canChangeStatus
                ? (v) => setState(() => _status = v ? 1 : 0)
                : null,
            activeThumbColor: AppPalette.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
        ),
        child: _isLoading && text == "SIMPAN"
            ? const SizedBox(
                height: 20,
                width: 20,
                child: AppCircularLoader(color: Colors.white, strokeWidth: 2),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontWeight: AppFont.w900,
                  fontSize: 14,
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required String text,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFD0D5DD)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: AppFont.w900,
            fontSize: 14,
            color: Color(0xFF667085),
          ),
        ),
      ),
    );
  }
}

class SalarySettingsScreenEmbedded extends StatefulWidget {
  final Map<String, dynamic>? initialConfig;

  const SalarySettingsScreenEmbedded({super.key, this.initialConfig});

  @override
  State<SalarySettingsScreenEmbedded> createState() =>
      SalarySettingsScreenEmbeddedState();
}

class SalarySettingsScreenEmbeddedState
    extends State<SalarySettingsScreenEmbedded> {
  static const List<String> _weekDays = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  static const List<String> _monthlySchedules = ['Setiap Tanggal'];
  // Mingguan hanya boleh dibayar seminggu sekali (di hari tertentu).
  static const List<String> _weeklySchedules = ['Setiap Minggu'];
  static const List<String> _dailySchedules = [
    'Setiap Hari',
    'Setiap Beberapa Hari',
  ];
  static const List<String> _intervalOptions = [
    '3 Hari Sekali',
    '7 Hari Sekali',
    '14 Hari Sekali',
  ];

  final _amountController = TextEditingController();
  final _monthlyDayController = TextEditingController(text: '25');
  final _everyDaysController = TextEditingController(text: '3');

  String _salaryType = 'Bulanan';
  String _salarySchedule = 'Setiap Tanggal';
  String _weeklyDay = 'Senin';
  bool _prefilled = false;

  @override
  void dispose() {
    _amountController.dispose();
    _monthlyDayController.dispose();
    _everyDaysController.dispose();
    super.dispose();
  }

  List<String> get _activeScheduleOptions {
    switch (_salaryType) {
      case 'Mingguan':
        return _weeklySchedules;
      case 'Harian':
        return _dailySchedules;
      default:
        return _monthlySchedules;
    }
  }

  String get _nominalLabel {
    switch (_salaryType) {
      case 'Mingguan':
        return 'Upah Per Minggu';
      case 'Harian':
        return 'Upah Per Hari';
      default:
        return 'Nominal';
    }
  }

  String get _scheduleLabel {
    switch (_salaryType) {
      case 'Harian':
        return 'Jadwal Pembayaran';
      default:
        return 'Tanggal Gajian';
    }
  }

  void _updateSalaryType(String value) {
    setState(() {
      _salaryType = value;
      _salarySchedule = _activeScheduleOptions.first;
      if (_salaryType == 'Bulanan' &&
          _monthlyDayController.text.trim().isEmpty) {
        _monthlyDayController.text = '25';
      } else if (_salaryType == 'Mingguan' && _weeklyDay.trim().isEmpty) {
        _weeklyDay = 'Senin';
      } else if (_salaryType == 'Harian' &&
          _everyDaysController.text.trim().isEmpty) {
        _everyDaysController.text = '3';
      }
    });
  }

  void _updateSchedule(String value) {
    setState(() {
      _salarySchedule = value;
      if (_salaryType == 'Harian' && value == 'Setiap Hari') {
        _everyDaysController.text = '1';
      } else if (value == 'Setiap Beberapa Hari' &&
          _everyDaysController.text.trim().isEmpty) {
        _everyDaysController.text = '3';
      }
    });
  }

  double get _amountValue =>
      CurrencyFormatter.parseRupiahToDouble(_amountController.text);

  int? _parseIntField(String value) {
    final parsed = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
    return parsed == null || parsed <= 0 ? null : parsed;
  }

  String? validateCurrentDraft() {
    if (_amountValue <= 0) {
      return 'Nominal gaji wajib diisi';
    }
    if (_amountValue > 999999999) {
      return 'Nominal gaji maksimal Rp999.999.999';
    }

    if (_salaryType == 'Bulanan') {
      final day = _parseIntField(_monthlyDayController.text);
      if (day == null || day < 1 || day > 31) {
        return 'Tanggal gajian bulanan harus antara 1 sampai 31';
      }
    } else if (_salaryType == 'Mingguan') {
      if (_weeklyDay.isEmpty) {
        return 'Pilih hari pembayaran';
      }
    } else {
      if (_salarySchedule == 'Setiap Beberapa Hari') {
        final days = _parseIntField(_everyDaysController.text);
        if (days == null) {
          return 'Isi jumlah hari pembayaran';
        }
      }
    }

    return null;
  }

  Map<String, dynamic>? currentPayload() {
    final validationError = validateCurrentDraft();
    if (validationError != null) return null;

    final amount = _amountValue;
    final salaryType = switch (_salaryType) {
      'Mingguan' => 'weekly',
      'Harian' => 'daily',
      _ => 'monthly',
    };

    final payload = <String, dynamic>{
      'salary_type': salaryType,
      'amount': amount,
      'is_active': true,
    };

    if (_salaryType == 'Bulanan') {
      payload['schedule_type'] = 'fixed_date';
      payload['pay_day'] = _parseIntField(_monthlyDayController.text);
    } else if (_salaryType == 'Mingguan') {
      // Mingguan selalu dibayar seminggu sekali di hari tertentu.
      payload['schedule_type'] = 'every_week';
      payload['pay_day_name'] = _weeklyDay;
    } else {
      if (_salarySchedule == 'Setiap Hari') {
        payload['schedule_type'] = 'daily';
      } else {
        payload['schedule_type'] = 'every_n_days';
        payload['pay_every_days'] = _parseIntField(_everyDaysController.text);
      }
    }

    return payload;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyPrefill();
  }

  void _applyPrefill() {
    if (_prefilled) return;
    final config = widget.initialConfig;
    if (config == null) return;

    _salaryType = _salaryTypeFromConfig(config);
    _salarySchedule = _scheduleLabelFromConfig(config);
    _amountController.text = _formatAmountText(config);
    _monthlyDayController.text = _payDayText(config);
    _everyDaysController.text = _payEveryDaysText(config);
    _weeklyDay = _payDayNameText(config);
    // Pastikan schedule valid untuk tipe gaji ini. Config lama Mingguan yang
    // tersimpan 'tiap N hari' opsinya sudah dihapus → fallback ke opsi pertama
    // agar dropdown tidak error (value di luar items).
    if (!_activeScheduleOptions.contains(_salarySchedule)) {
      _salarySchedule = _activeScheduleOptions.first;
    }
    _prefilled = true;
  }

  String _salaryTypeFromConfig(Map<String, dynamic>? config) {
    final raw = config?['salary_type']?.toString().toLowerCase();
    switch (raw) {
      case 'weekly':
      case 'mingguan':
        return 'Mingguan';
      case 'daily':
      case 'harian':
        return 'Harian';
      case 'monthly':
      case 'bulanan':
        return 'Bulanan';
      default:
        return 'Bulanan';
    }
  }

  String _scheduleLabelFromConfig(Map<String, dynamic>? config) {
    final raw = config?['schedule_type']?.toString();
    if (raw == 'every_week') return 'Setiap Minggu';
    if (raw == 'daily' || raw == 'harian') return 'Setiap Hari';
    if (raw == 'every_n_days') {
      final amount = _parseIntField(
        config?['pay_every_days']?.toString() ?? '',
      );
      return (amount ?? 3) <= 1 ? 'Setiap Hari' : 'Setiap Beberapa Hari';
    }
    return 'Setiap Tanggal';
  }

  String _formatAmountText(Map<String, dynamic>? config) {
    final value = config?['amount'];
    if (value == null) return '';
    return CurrencyFormatter.formatNumberToInput(value);
  }

  String _payDayText(Map<String, dynamic>? config) {
    final value = config?['pay_day'];
    return value?.toString() ?? '25';
  }

  String _payEveryDaysText(Map<String, dynamic>? config) {
    final value = config?['pay_every_days'];
    return value?.toString() ?? '3';
  }

  String _payDayNameText(Map<String, dynamic>? config) {
    return config?['pay_day_name']?.toString() ?? 'Senin';
  }

  @override
  Widget build(BuildContext context) {
    final showMonthlyDate = _salaryType == 'Bulanan';
    final showDailyInterval =
        _salaryType == 'Harian' && _salarySchedule == 'Setiap Beberapa Hari';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF7A3D), Color(0xFFFF5A1F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Pengaturan Gaji",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: AppFont.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Isi nominal dan jadwal pembayaran pegawai.",
                      style: TextStyle(
                        color: Color(0xFFFFE7DD),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _salaryField(
          title: 'Tipe Gaji',
          child: SalaryChipSelect(
            value: _salaryType,
            options: const [
              SalaryChipOption('Bulanan', 'Bulanan'),
              SalaryChipOption('Mingguan', 'Mingguan'),
              SalaryChipOption('Harian', 'Harian'),
            ],
            onChanged: _updateSalaryType,
          ),
        ),
        const SizedBox(height: 14),
        _salaryField(
          title: _nominalLabel,
          child: SalaryAmountField(
            controller: _amountController,
            hintText: _salaryType == 'Harian' ? 'Rp 50.000' : 'Rp 350.000',
          ),
        ),
        const SizedBox(height: 14),
        if (showMonthlyDate) ...[
          _salaryField(
            title: _scheduleLabel,
            child: SalaryDateSelectField(
              valueText: _monthlyDayController.text.isNotEmpty
                  ? 'Tanggal ${_monthlyDayController.text}'
                  : 'Tanggal 25',
              onTap: _pickTanggalGajian,
            ),
          ),
        ] else if (_salaryType == 'Mingguan') ...[
          // Mingguan otomatis dibayar sekali seminggu → cukup pilih hari.
          _salaryField(
            title: 'Hari Pembayaran',
            child: SalarySelectField<String>(
              value: _weeklyDay,
              options: _weekDays.map((d) => SalarySelectOption(d, d)).toList(),
              onChanged: (val) => setState(() => _weeklyDay = val),
            ),
          ),
        ] else ...[
          _salaryField(
            title: _scheduleLabel,
            child: SalaryChipSelect(
              value: _salarySchedule,
              options: const [
                SalaryChipOption('Setiap Hari', 'Setiap Hari'),
                SalaryChipOption(
                  'Setiap Beberapa Hari',
                  'Setiap Beberapa Hari',
                ),
              ],
              onChanged: _updateSchedule,
            ),
          ),
          if (showDailyInterval) ...[
            const SizedBox(height: 14),
            _salaryField(
              title: 'Bayar Setiap',
              child: SalaryChipSelect(
                // Guard: nilai lama di luar opsi (mis. 5) → fallback ke 3.
                value:
                    _intervalOptions.contains(
                      '${_parseIntField(_everyDaysController.text) ?? 3} Hari Sekali',
                    )
                    ? '${_parseIntField(_everyDaysController.text) ?? 3} Hari Sekali'
                    : '3 Hari Sekali',
                options: _intervalOptions
                    .map((o) => SalaryChipOption(o, o))
                    .toList(),
                onChanged: (val) {
                  final days = val.split(' ').first;
                  setState(() => _everyDaysController.text = days);
                },
              ),
            ),
          ],
        ],
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6EAF2)),
          ),
          child: const Text(
            "Pengaturan ini dipakai untuk membuat payroll otomatis. Kalau belum mau diisi sekarang, nanti bisa diatur dari menu Penggajian.",
            style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: Color(0xFF667085),
            ),
          ),
        ),
      ],
    );
  }

  Widget _salaryField({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [SalaryFieldLabel(title), const SizedBox(height: 8), child],
    );
  }

  Future<void> _pickTanggalGajian() async {
    final currentDay = (_parseIntField(_monthlyDayController.text) ?? 25).clamp(
      1,
      31,
    );
    final picked = await showDayOfMonthPicker(
      context: context,
      selectedDay: currentDay,
    );
    if (picked != null && mounted) {
      setState(() => _monthlyDayController.text = '$picked');
    }
  }
}
