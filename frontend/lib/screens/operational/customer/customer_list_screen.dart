import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/utils/contact_phone_formatter.dart';
import 'package:ayocucinew/data/models/customer_model.dart';
import 'package:ayocucinew/shared/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:ayocucinew/shared/widgets/app_search_field.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:ayocucinew/shared/widgets/customer_deposit_balance_panel.dart';
import 'package:provider/provider.dart';
import '../../../providers/customer_provider.dart';
import '../../../providers/auth_provider.dart';
import 'customer_deposit_screen.dart';
import 'customer_detail_screen.dart';
import '../../../shared/widgets/custom_textfield.dart';
import '../../../shared/widgets/custom_toast.dart';
import 'manage_customer_screen.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

enum _BirthdayFilter { all, today, next3Days, next7Days, date, range }

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _selectionMode = false;
  final Set<String> _selectedCustomerIds = <String>{};
  _BirthdayFilter _birthdayFilter = _BirthdayFilter.all;
  DateTime? _birthdayDate;
  DateTimeRange? _birthdayRange;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _birthdayInYear(DateTime birthDate, int year) {
    if (birthDate.month == 2 && birthDate.day == 29) {
      final leapYear = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
      if (!leapYear) return DateTime(year, 2, 28);
    }
    return DateTime(year, birthDate.month, birthDate.day);
  }

  DateTime? _nextBirthday(Customer customer) {
    final birthDate = customer.birthDate;
    if (birthDate == null) return null;
    var result = _birthdayInYear(birthDate, _today.year);
    if (result.isBefore(_today)) {
      result = _birthdayInYear(birthDate, _today.year + 1);
    }
    return result;
  }

  int? _daysUntilBirthday(Customer customer) {
    final birthday = _nextBirthday(customer);
    return birthday?.difference(_today).inDays;
  }

  bool _matchesBirthdayFilter(Customer customer) {
    final birthDate = customer.birthDate;
    if (_birthdayFilter == _BirthdayFilter.all) return true;
    if (birthDate == null) return false;
    final days = _daysUntilBirthday(customer)!;
    switch (_birthdayFilter) {
      case _BirthdayFilter.all:
        return true;
      case _BirthdayFilter.today:
        return days == 0;
      case _BirthdayFilter.next3Days:
        return days >= 0 && days <= 3;
      case _BirthdayFilter.next7Days:
        return days >= 0 && days <= 7;
      case _BirthdayFilter.date:
        final selected = _birthdayDate;
        return selected != null &&
            birthDate.month == selected.month &&
            birthDate.day == selected.day;
      case _BirthdayFilter.range:
        final range = _birthdayRange;
        if (range == null) return false;
        for (var year = range.start.year; year <= range.end.year; year++) {
          final occurrence = _birthdayInYear(birthDate, year);
          if (!occurrence.isBefore(range.start) &&
              !occurrence.isAfter(range.end)) {
            return true;
          }
        }
        return false;
    }
  }

  bool get _hasBirthdayFilter => _birthdayFilter != _BirthdayFilter.all;

  String formatPhoneNumber(String phone) {
    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    return cleanPhone
        .replaceAllMapped(RegExp(r'.{4}'), (match) => '${match.group(0)}-')
        .replaceAll(RegExp(r'-$'), '');
  }

  String customerDisplayId(Customer customer) {
    final raw = customer.id.trim();
    final value = raw.isEmpty ? customer.kode : raw;
    return value.length <= 5 ? value : value.substring(value.length - 5);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<AuthProvider>().canAccess('pelanggan', 'read')) {
        context.read<CustomerProvider>().fetchCustomers();
      }
    });
  }

  void _showCustomerPreview(dynamic customer, CustomerProvider provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerDetailScreen(customer: customer),
      ),
    );
    return;
    /* showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomerPreviewSheet(
        customer: customer,
        onEdit: () {
          final auth = context.read<AuthProvider>();
          if (!auth.isOwnerOrAdmin && !auth.hasAccess('pelanggan', 'update')) {
            CustomToast.show(
              context,
              message:
                  "Mohon maaf Anda tidak dapat melakukan Edit, Otorisasi tidak diberikan.",
              isError: true,
            );
            return;
          }
          Navigator.pop(context);
          _goToManageCustomer(existingCustomer: customer);
        },
        onDelete: () {
          final auth = context.read<AuthProvider>();
          if (!auth.isOwnerOrAdmin && !auth.hasAccess('pelanggan', 'delete')) {
            CustomToast.show(
              context,
              message:
                  "Mohon maaf Anda tidak dapat melakukan Hapus, Otorisasi tidak diberikan.",
              isError: true,
            );
            return;
          }
          Navigator.pop(context);
          _showDeleteDialog(this.context, customer.id, provider);
        },
      ),
    ); */
  }

  void _goToManageCustomer({dynamic existingCustomer}) {
    final customerProvider = context.read<CustomerProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ManageCustomerScreen(existingCustomer: existingCustomer),
      ),
    ).then((_) {
      customerProvider.fetchCustomers();
    });
  }

  void _toggleSelectionMode([bool enabled = true]) {
    setState(() {
      _selectionMode = enabled;
      if (!enabled) {
        _selectedCustomerIds.clear();
      }
    });
  }

  void _toggleCustomerSelection(String customerId) {
    setState(() {
      if (_selectedCustomerIds.contains(customerId)) {
        _selectedCustomerIds.remove(customerId);
      } else {
        _selectedCustomerIds.add(customerId);
      }
    });
  }

  Future<void> _confirmBulkDelete(
    List<Customer> customers,
    CustomerProvider provider,
  ) async {
    final selected = customers
        .where((customer) => _selectedCustomerIds.contains(customer.id))
        .toList();
    if (selected.isEmpty) return;

    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Hapus pelanggan terpilih?"),
        content: Text(
          "${selected.length} pelanggan akan diproses. Pelanggan yang punya riwayat transaksi tidak akan bisa dihapus.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final res = await provider.deleteCustomersBulk(
      selected.map((customer) => customer.id).toList(),
    );
    if (!mounted) return;

    if (!(res['success'] == true)) {
      CustomToast.show(
        context,
        message:
            res['message']?.toString() ?? 'Gagal menghapus pelanggan terpilih',
        isError: true,
      );
      return;
    }

    _toggleSelectionMode(false);

    final data = Map<String, dynamic>.from(
      (res['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final successCount = data['success_count'] ?? 0;
    final failedCount = data['failed_count'] ?? 0;
    final rawResults = (data['results'] as List? ?? const [])
        .cast<dynamic>()
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BulkDeleteResultSheet(
        successCount: successCount,
        failedCount: failedCount,
        results: rawResults,
      ),
    );
  }

  void _showAddCustomerActions() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomSafe = MediaQuery.of(sheetContext).viewPadding.bottom;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottomSafe),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                "Tambah Pelanggan",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: AppFont.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Pilih cara menambahkan pelanggan ke database outlet.",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 18),
              _ActionTile(
                icon: Icons.person_add_alt_1_rounded,
                title: "Tambah Satu Pelanggan",
                subtitle:
                    "Input manual atau ambil satu kontak seperti flow saat ini.",
                onTap: () {
                  Navigator.pop(sheetContext);
                  _goToManageCustomer();
                },
              ),
              const SizedBox(height: 12),
              _ActionTile(
                icon: Icons.contacts_rounded,
                title: "Import Banyak dari Kontak",
                subtitle:
                    "Pilih banyak kontak, review dulu, lalu simpan sekaligus.",
                onTap: () {
                  Navigator.pop(sheetContext);
                  _startBulkContactImport();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String get _birthdayFilterLabel {
    switch (_birthdayFilter) {
      case _BirthdayFilter.all:
        return 'Semua ulang tahun';
      case _BirthdayFilter.today:
        return 'Ulang tahun hari ini';
      case _BirthdayFilter.next3Days:
        return 'Ulang tahun 3 hari ke depan';
      case _BirthdayFilter.next7Days:
        return 'Ulang tahun 7 hari ke depan';
      case _BirthdayFilter.date:
        return _birthdayDate == null
            ? 'Tanggal tertentu'
            : DateFormat('d MMMM', 'id_ID').format(_birthdayDate!);
      case _BirthdayFilter.range:
        final range = _birthdayRange;
        return range == null
            ? 'Rentang tanggal'
            : '${DateFormat('d MMM', 'id_ID').format(range.start)} – ${DateFormat('d MMM', 'id_ID').format(range.end)}';
    }
  }

  Future<void> _openBirthdayFilter() async {
    var draftFilter = _birthdayFilter;
    var draftDate = _birthdayDate;
    var draftRange = _birthdayRange;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> selectDate() async {
            final selected = await showDatePicker(
              context: context,
              initialDate: draftDate ?? _today,
              firstDate: DateTime(_today.year - 1),
              lastDate: DateTime(_today.year + 2, 12, 31),
              helpText: 'Pilih tanggal ulang tahun',
            );
            if (selected != null) {
              setSheetState(() {
                draftDate = selected;
                draftFilter = _BirthdayFilter.date;
              });
            }
          }

          Future<void> selectRange() async {
            final selected = await showDateRangePicker(
              context: context,
              initialDateRange: draftRange,
              firstDate: DateTime(_today.year - 1),
              lastDate: DateTime(_today.year + 2, 12, 31),
              helpText: 'Pilih rentang ulang tahun',
            );
            if (selected != null) {
              setSheetState(() {
                draftRange = DateTimeRange(
                  start: DateTime(
                    selected.start.year,
                    selected.start.month,
                    selected.start.day,
                  ),
                  end: DateTime(
                    selected.end.year,
                    selected.end.month,
                    selected.end.day,
                  ),
                );
                draftFilter = _BirthdayFilter.range;
              });
            }
          }

          Widget option(
            _BirthdayFilter value,
            String label,
            IconData icon,
            VoidCallback onTap,
          ) {
            final selected = draftFilter == value;
            return InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppPalette.primarySoft
                      : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? AppPalette.primary
                        : const Color(0xFFE7EBEF),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 19,
                      color: selected ? AppPalette.primary : AppPalette.muted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: selected ? AppPalette.primary : AppPalette.ink,
                          fontSize: 13,
                          fontWeight: AppFont.w700,
                        ),
                      ),
                    ),
                    if (selected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppPalette.primary,
                        size: 18,
                      ),
                  ],
                ),
              ),
            );
          }

          return Container(
            padding: EdgeInsets.fromLTRB(
              18,
              12,
              18,
              18 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9DEE3),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Filter Ulang Tahun',
                    style: TextStyle(
                      color: AppPalette.ink,
                      fontSize: 18,
                      fontWeight: AppFont.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Cari pelanggan berdasarkan tanggal ulang tahun.',
                    style: TextStyle(color: AppPalette.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Semua'),
                        selected: draftFilter == _BirthdayFilter.all,
                        onSelected: (_) => setSheetState(
                          () => draftFilter = _BirthdayFilter.all,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('Hari Ini'),
                        selected: draftFilter == _BirthdayFilter.today,
                        onSelected: (_) => setSheetState(
                          () => draftFilter = _BirthdayFilter.today,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('3 Hari'),
                        selected: draftFilter == _BirthdayFilter.next3Days,
                        onSelected: (_) => setSheetState(
                          () => draftFilter = _BirthdayFilter.next3Days,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('7 Hari'),
                        selected: draftFilter == _BirthdayFilter.next7Days,
                        onSelected: (_) => setSheetState(
                          () => draftFilter = _BirthdayFilter.next7Days,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  option(
                    _BirthdayFilter.date,
                    draftDate == null
                        ? 'Pilih tanggal tertentu'
                        : DateFormat(
                            'EEEE, d MMMM',
                            'id_ID',
                          ).format(draftDate!),
                    Icons.calendar_today_outlined,
                    selectDate,
                  ),
                  const SizedBox(height: 10),
                  option(
                    _BirthdayFilter.range,
                    draftRange == null
                        ? 'Pilih rentang tanggal'
                        : '${DateFormat('d MMM', 'id_ID').format(draftRange!.start)} – ${DateFormat('d MMM', 'id_ID').format(draftRange!.end)}',
                    Icons.date_range_outlined,
                    selectRange,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () {
                        if (draftFilter == _BirthdayFilter.date &&
                            draftDate == null) {
                          selectDate();
                          return;
                        }
                        if (draftFilter == _BirthdayFilter.range &&
                            draftRange == null) {
                          selectRange();
                          return;
                        }
                        setState(() {
                          _birthdayFilter = draftFilter;
                          _birthdayDate = draftDate;
                          _birthdayRange = draftRange;
                        });
                        Navigator.pop(sheetContext);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('TERAPKAN FILTER'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _sendBirthdayGreeting(Customer customer) async {
    final digits = customer.phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      CustomToast.show(
        context,
        message: 'Nomor WhatsApp pelanggan belum diisi.',
        isError: true,
      );
      return;
    }
    final phone = digits.startsWith('0')
        ? '62${digits.substring(1)}'
        : digits.startsWith('8')
        ? '62$digits'
        : digits;
    final firstName = customer.name.trim().split(RegExp(r'\s+')).first;
    final days = _daysUntilBirthday(customer) ?? 0;
    final message = days == 0
        ? 'Selamat ulang tahun, Kak $firstName! 🎉 Semoga sehat, bahagia, dan segala urusannya lancar. Salam hangat dari kami.'
        : 'Hai Kak $firstName! 🎉 Sebentar lagi hari ulang tahun Kakak. Semoga selalu sehat, bahagia, dan segala urusannya lancar. Salam hangat dari kami.';
    final uri = Uri.https('wa.me', '/$phone', {'text': message});
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      CustomToast.show(
        context,
        message: 'WhatsApp tidak dapat dibuka.',
        isError: true,
      );
    }
  }

  Future<void> _startBulkContactImport() async {
    HapticFeedback.mediumImpact();

    // Apple 5.1.2: minta persetujuan eksplisit & jelaskan bahwa kontak yang
    // dipilih akan diunggah ke server AyoCuci sebelum mengakses kontak.
    final consent = await _showContactConsentDialog();
    if (consent != true || !mounted) return;

    try {
      final status = await FlutterContacts.permissions.request(
        PermissionType.read,
      );

      if (status != PermissionStatus.granted &&
          status != PermissionStatus.limited) {
        if (!mounted) return;
        CustomToast.show(
          context,
          message: "Akses kontak ditolak",
          isError: true,
        );
        return;
      }

      final contacts = await FlutterContacts.getAll(
        properties: const {ContactProperty.name, ContactProperty.phone},
      );

      if (!mounted) return;

      final selectedContacts =
          await Navigator.push<List<_BulkContactCandidate>>(
            context,
            MaterialPageRoute(
              builder: (_) => _BulkContactPickerScreen(contacts: contacts),
            ),
          );

      if (!mounted || selectedContacts == null || selectedContacts.isEmpty) {
        return;
      }

      final reviewResult = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              _BulkCustomerImportReviewScreen(items: selectedContacts),
        ),
      );

      if (reviewResult == true && mounted) {
        context.read<CustomerProvider>().fetchCustomers();
      }
    } catch (e) {
      debugPrint("Error bulk import contact: $e");
      if (!mounted) return;
      CustomToast.show(
        context,
        message: "Gagal mengambil daftar kontak",
        isError: true,
      );
    }
  }

  /// Dialog persetujuan sebelum mengakses & mengunggah kontak (Apple 5.1.2).
  /// Menjelaskan data apa yang diunggah, ke mana, dan untuk apa.
  Future<bool?> _showContactConsentDialog() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppPalette.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.contacts_rounded,
                        color: AppPalette.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Impor dari Kontak",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: AppFont.w700,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  "Untuk mempercepat pendaftaran pelanggan, aplikasi akan membuka daftar kontak di perangkat Anda.\n\n"
                  "Hanya kontak yang Anda pilih (nama & nomor telepon) yang akan diunggah ke server AyoCuci dan disimpan sebagai data pelanggan laundry Anda. Kontak yang tidak dipilih tidak akan dikirim ke mana pun.\n\n"
                  "Dengan melanjutkan, Anda menyetujui pengunggahan kontak yang dipilih ke server AyoCuci.",
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5B6675),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          foregroundColor: Colors.grey.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text(
                          "Batal",
                          style: TextStyle(fontWeight: AppFont.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text(
                          "Setuju & Lanjut",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: AppFont.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider>();
    final auth = context.watch<AuthProvider>();
    final canRead = auth.canAccess('pelanggan', 'read');
    final canCreate = auth.canAccess('pelanggan', 'create');
    final canDelete = auth.canAccess('pelanggan', 'delete');

    if (!canRead) {
      return const _CustomerAccessDenied();
    }

    final filteredCustomers = provider.customers.where((c) {
      final query = _searchQuery.toLowerCase();
      final matchesSearch =
          c.name.toLowerCase().contains(query) ||
          c.phone.contains(query) ||
          c.kode.contains(query);
      return matchesSearch && _matchesBirthdayFilter(c);
    }).toList();

    filteredCustomers.sort((a, b) {
      if (_hasBirthdayFilter) {
        final dateCompare = (_nextBirthday(a) ?? DateTime(9999)).compareTo(
          _nextBirthday(b) ?? DateTime(9999),
        );
        if (dateCompare != 0) return dateCompare;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(
          _selectionMode
              ? "${_selectedCustomerIds.length} dipilih"
              : 'Pelanggan',
          style: const TextStyle(
            color: AppPalette.ink,
            fontSize: 16,
            fontWeight: AppFont.w800,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            _selectionMode ? Icons.close_rounded : Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => _selectionMode
              ? _toggleSelectionMode(false)
              : Navigator.pop(context),
        ),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              icon: const Icon(
                Icons.select_all_rounded,
                color: AppPalette.primary,
              ),
              tooltip: "Pilih Semua",
              onPressed: filteredCustomers.isEmpty
                  ? null
                  : () {
                      setState(() {
                        final allSelected = filteredCustomers.every(
                          (customer) =>
                              _selectedCustomerIds.contains(customer.id),
                        );
                        if (allSelected) {
                          _selectedCustomerIds.clear();
                        } else {
                          _selectedCustomerIds
                            ..clear()
                            ..addAll(
                              filteredCustomers.map((customer) => customer.id),
                            );
                        }
                      });
                    },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              tooltip: "Hapus Terpilih",
              onPressed: _selectedCustomerIds.isEmpty
                  ? null
                  : () => _confirmBulkDelete(filteredCustomers, provider),
            ),
          ] else if (canDelete) ...[
            IconButton(
              icon: Badge(
                isLabelVisible: _hasBirthdayFilter,
                smallSize: 7,
                backgroundColor: AppPalette.primary,
                child: Icon(
                  Icons.tune_rounded,
                  color: _hasBirthdayFilter
                      ? AppPalette.primary
                      : AppPalette.ink,
                ),
              ),
              tooltip: 'Filter Ulang Tahun',
              onPressed: _openBirthdayFilter,
            ),
            IconButton(
              icon: const Icon(
                Icons.checklist_rounded,
                color: AppPalette.primary,
              ),
              tooltip: "Pilih Pelanggan",
              onPressed: () => _toggleSelectionMode(true),
            ),
          ] else ...[
            IconButton(
              icon: Badge(
                isLabelVisible: _hasBirthdayFilter,
                smallSize: 7,
                backgroundColor: AppPalette.primary,
                child: Icon(
                  Icons.tune_rounded,
                  color: _hasBirthdayFilter
                      ? AppPalette.primary
                      : AppPalette.ink,
                ),
              ),
              tooltip: 'Filter Ulang Tahun',
              onPressed: _openBirthdayFilter,
            ),
          ],
        ],
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // SEARCH BAR
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: AppSearchField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              hintText: "Cari nama / No. WA / kode pelanggan",
            ),
          ),
          if (_hasBirthdayFilter)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Text('🎂', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              '$_birthdayFilterLabel • ${filteredCustomers.length} pelanggan',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppPalette.primary,
                                fontSize: 11.5,
                                fontWeight: AppFont.w700,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => setState(
                              () => _birthdayFilter = _BirthdayFilter.all,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: AppPalette.primary,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: provider.isLoading
                ? const CustomerListSkeleton()
                : filteredCustomers.isEmpty
                ? EmptyStateWidget.pelanggan(
                    message: _hasBirthdayFilter
                        ? 'Tidak ada pelanggan pada periode ulang tahun ini'
                        : 'Tidak ada data pelanggan',
                  )
                : _buildList(filteredCustomers, provider),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _selectionMode
          ? null
          : !canCreate
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.68,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _showAddCustomerActions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 10,
                      shadowColor: AppPalette.primary.withValues(alpha: 0.4),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_add_alt_1_rounded, size: 20),
                        SizedBox(width: 10),
                        Text(
                          "TAMBAH PELANGGAN",
                          style: TextStyle(fontSize: 14, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildList(
    List<Customer> filteredCustomers,
    CustomerProvider provider,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 184),
      itemCount: filteredCustomers.length,
      itemBuilder: (context, index) {
        final customer = filteredCustomers[index];
        final selected = _selectedCustomerIds.contains(customer.id);
        final birthdayDays = _daysUntilBirthday(customer);
        final canSendGreeting =
            birthdayDays != null && birthdayDays >= 0 && birthdayDays <= 3;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF0F2F5)),
            boxShadow: AppShadows.cardSoft,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                InkWell(
                  onTap: () => _selectionMode
                      ? _toggleCustomerSelection(customer.id)
                      : _showCustomerPreview(customer, provider),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 12, 13),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFE5DD),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: AppPalette.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customer.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppPalette.ink,
                                  fontWeight: AppFont.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'ID #${customerDisplayId(customer)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppPalette.muted,
                                  fontWeight: AppFont.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                customer.phone.trim().isEmpty
                                    ? 'No. WA belum diisi'
                                    : formatPhoneNumber(customer.phone),
                                style: const TextStyle(
                                  color: AppPalette.muted,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (_selectionMode)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppPalette.primary
                                  : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? AppPalette.primary
                                    : const Color(0xFFD7DEE5),
                              ),
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              color: selected
                                  ? Colors.white
                                  : Colors.transparent,
                              size: 18,
                            ),
                          )
                        else
                          Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF5F7F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chevron_right_rounded,
                              color: AppPalette.muted,
                              size: 22,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (!_selectionMode) ...[
                  if (_hasBirthdayFilter || canSendGreeting)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF6ED),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: const Color(0xFFFFE0C2)),
                        ),
                        child: Row(
                          children: [
                            const Text('🎂', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                birthdayDays == 0
                                    ? 'Ulang tahun hari ini'
                                    : birthdayDays == 1
                                    ? 'Ulang tahun besok'
                                    : birthdayDays != null && birthdayDays <= 7
                                    ? 'Ulang tahun $birthdayDays hari lagi'
                                    : customer.birthDate == null
                                    ? '-'
                                    : DateFormat(
                                        'd MMMM',
                                        'id_ID',
                                      ).format(customer.birthDate!),
                                style: const TextStyle(
                                  color: Color(0xFFE87924),
                                  fontSize: 11.5,
                                  fontWeight: AppFont.w700,
                                ),
                              ),
                            ),
                            if (canSendGreeting)
                              TextButton.icon(
                                onPressed: () =>
                                    _sendBirthdayGreeting(customer),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF159447),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 15,
                                ),
                                label: const Text(
                                  'Kirim Ucapan',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: AppFont.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: CustomerDepositBalancePanel(customer: customer),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CustomerDepositScreen(customer: customer),
                            ),
                          );
                          if (context.mounted) {
                            context.read<CustomerProvider>().fetchCustomers();
                          }
                        },
                        icon: const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 18,
                        ),
                        label: const Text('Kelola Deposit'),
                        style: FilledButton.styleFrom(
                          foregroundColor: AppPalette.primary,
                          backgroundColor: const Color(0xFFFFF0EB),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: AppFont.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CustomerAccessDenied extends StatelessWidget {
  const _CustomerAccessDenied();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text('Pelanggan'),
        centerTitle: true,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 52,
                color: AppPalette.primary,
              ),
              SizedBox(height: 16),
              Text(
                'Akses pelanggan tidak tersedia',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppPalette.ink,
                  fontSize: 17,
                  fontWeight: AppFont.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Minta pemilik outlet memberikan izin Lihat pada modul Pelanggan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppPalette.muted, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulkDeleteResultSheet extends StatelessWidget {
  final int successCount;
  final int failedCount;
  final List<Map<String, dynamic>> results;

  const _BulkDeleteResultSheet({
    required this.successCount,
    required this.failedCount,
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 18, 16, 16 + bottomSafe),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
            'Hasil Hapus',
            style: TextStyle(fontSize: 20, fontWeight: AppFont.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryBadge(
                label: 'Terhapus',
                value: '$successCount',
                color: Colors.green,
              ),
              _SummaryBadge(
                label: 'Gagal',
                value: '$failedCount',
                color: Colors.redAccent,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: results.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = results[index];
                final status = item['status']?.toString() ?? '';
                final nama = item['nama']?.toString() ?? '-';
                final id = item['id']?.toString() ?? '-';
                final reason = item['reason']?.toString() ?? '';
                final tone = status == 'deleted'
                    ? Colors.green
                    : Colors.redAccent;
                final label = status == 'deleted' ? 'Terhapus' : 'Gagal';
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              nama,
                              style: const TextStyle(fontWeight: AppFont.w700),
                            ),
                          ),
                          Text(
                            label,
                            style: TextStyle(
                              color: tone,
                              fontSize: 12,
                              fontWeight: AppFont.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        id,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      if (reason.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          reason,
                          style: TextStyle(fontSize: 12, color: tone),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text('SELESAI'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppPalette.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppPalette.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: AppFont.w700,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulkContactCandidate {
  final String name;
  final String phone;
  final String gender;

  const _BulkContactCandidate({
    required this.name,
    required this.phone,
    this.gender = '',
  });

  Map<String, dynamic> toPayload() => {
    'nama': name,
    'no_hp': phone,
    'alamat': '',
    'jenis_kelamin': gender,
  };

  _BulkContactCandidate copyWith({
    String? name,
    String? phone,
    String? gender,
  }) {
    return _BulkContactCandidate(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
    );
  }
}

class _BulkContactPickerScreen extends StatefulWidget {
  final List<Contact> contacts;

  const _BulkContactPickerScreen({required this.contacts});

  @override
  State<_BulkContactPickerScreen> createState() =>
      _BulkContactPickerScreenState();
}

class _BulkContactPickerScreenState extends State<_BulkContactPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _selectedIndexes = <int>{};
  String _query = '';

  List<_BulkContactCandidate> get _candidates {
    final items = <_BulkContactCandidate>[];
    for (final contact in widget.contacts) {
      final name = sanitizeCustomerName(contact.displayName ?? '');
      final phone = pickContactPhoneNumber(contact.phones);
      if (name.isEmpty && phone.isEmpty) continue;
      items.add(
        _BulkContactCandidate(
          name: name.isEmpty ? 'Tanpa Nama' : name,
          phone: phone,
        ),
      );
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _candidates;
    final filtered = candidates.asMap().entries.where((entry) {
      final item = entry.value;
      final query = _query.toLowerCase();
      return query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.phone.contains(query);
    }).toList();

    return AppScaffold(
      backgroundColor: const Color(0xFFF8F9FA),
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
          'Pilih Kontak',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
            child: Column(
              children: [
                AppSearchField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  hintText: "Cari kontak",
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _SummaryBadge(
                      label: 'Total',
                      value: '${filtered.length}',
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(width: 8),
                    _SummaryBadge(
                      label: 'Terpilih',
                      value: '${_selectedIndexes.length}',
                      color: AppPalette.primary,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: filtered.isEmpty
                          ? null
                          : () {
                              final selectable = filtered
                                  .where(
                                    (entry) => entry.value.phone.isNotEmpty,
                                  )
                                  .map((entry) => entry.key)
                                  .toSet();
                              setState(() {
                                final allSelected =
                                    selectable.isNotEmpty &&
                                    selectable.every(_selectedIndexes.contains);
                                if (allSelected) {
                                  _selectedIndexes.removeAll(selectable);
                                } else {
                                  _selectedIndexes.addAll(selectable);
                                }
                              });
                            },
                      icon: Icon(
                        filtered
                                .where((entry) => entry.value.phone.isNotEmpty)
                                .map((entry) => entry.key)
                                .every(_selectedIndexes.contains)
                            ? Icons.deselect_rounded
                            : Icons.select_all_rounded,
                        size: 18,
                      ),
                      label: Text(
                        filtered
                                .where((entry) => entry.value.phone.isNotEmpty)
                                .map((entry) => entry.key)
                                .every(_selectedIndexes.contains)
                            ? 'Batalkan Semua'
                            : 'Pilih Semua',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              itemBuilder: (context, index) {
                final entry = filtered[index];
                final actualIndex = entry.key;
                final item = entry.value;
                final selected = _selectedIndexes.contains(actualIndex);
                final hasPhone = item.phone.isNotEmpty;
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: hasPhone
                        ? () {
                            setState(() {
                              if (selected) {
                                _selectedIndexes.remove(actualIndex);
                              } else {
                                _selectedIndexes.add(actualIndex);
                              }
                            });
                          }
                        : null,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? AppPalette.primary
                              : Colors.grey.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppPalette.primary
                                  : AppPalette.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              selected
                                  ? Icons.check_rounded
                                  : Icons.person_rounded,
                              color: selected
                                  ? Colors.white
                                  : AppPalette.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: AppFont.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  hasPhone
                                      ? formatPhoneForDisplay(item.phone)
                                      : 'Tidak ada nomor',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: hasPhone
                                        ? Colors.grey.shade600
                                        : Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemCount: filtered.length,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _selectedIndexes.isEmpty
                  ? null
                  : () {
                      final selectedItems = _selectedIndexes
                          .map((index) => candidates[index])
                          .toList();
                      Navigator.pop(context, selectedItems);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                "LANJUTKAN (${_selectedIndexes.length})",
                style: const TextStyle(letterSpacing: 0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String formatPhoneForDisplay(String phone) {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    return cleanPhone
        .replaceAllMapped(RegExp(r'.{4}'), (match) => '${match.group(0)}-')
        .replaceAll(RegExp(r'-$'), '');
  }
}

class _BulkCustomerImportReviewScreen extends StatefulWidget {
  final List<_BulkContactCandidate> items;

  const _BulkCustomerImportReviewScreen({required this.items});

  @override
  State<_BulkCustomerImportReviewScreen> createState() =>
      _BulkCustomerImportReviewScreenState();
}

class _BulkCustomerImportReviewScreenState
    extends State<_BulkCustomerImportReviewScreen> {
  late List<_BulkContactCandidate> _items;
  bool _submitting = false;

  ({Set<int> invalidIndexes, int validCount, int invalidCount}) _reviewState() {
    final seenPhones = <String>{};
    final invalidIndexes = <int>{};
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.name.trim().isEmpty || item.phone.trim().isEmpty) {
        invalidIndexes.add(i);
        continue;
      }
      if (!seenPhones.add(item.phone.trim())) {
        invalidIndexes.add(i);
      }
    }
    return (
      invalidIndexes: invalidIndexes,
      validCount: _items.length - invalidIndexes.length,
      invalidCount: invalidIndexes.length,
    );
  }

  @override
  void initState() {
    super.initState();
    _items = List<_BulkContactCandidate>.from(widget.items);
  }

  @override
  Widget build(BuildContext context) {
    final review = _reviewState();
    final invalidIndexes = review.invalidIndexes;

    return AppScaffold(
      backgroundColor: const Color(0xFFF8F9FA),
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
          'Review Import',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              itemBuilder: (context, index) {
                final item = _items[index];
                final invalid = invalidIndexes.contains(index);
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () async {
                      final updated = await _showBulkContactEditor(
                        context,
                        item,
                      );
                      if (updated == null || !mounted) return;
                      setState(() {
                        _items[index] = updated;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: invalid
                              ? Colors.redAccent.withValues(alpha: 0.3)
                              : Colors.grey.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: AppFont.w700,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.edit_rounded,
                                size: 16,
                                color: AppPalette.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.phone.isEmpty
                                ? 'Tidak ada nomor WhatsApp'
                                : item.phone,
                            style: TextStyle(
                              fontSize: 12,
                              color: item.phone.isEmpty
                                  ? Colors.redAccent
                                  : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.gender.isEmpty
                                ? 'Gender: Netral / belum diisi'
                                : 'Gender: ${item.gender == 'P' ? 'Wanita' : 'Pria'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (invalid) ...[
                            const SizedBox(height: 8),
                            Text(
                              item.phone.isEmpty
                                  ? 'Nomor WhatsApp kosong'
                                  : 'Nomor duplikat di daftar import ini',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemCount: _items.length,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _submitting
                  ? null
                  : () async {
                      final payload = <Map<String, dynamic>>[];
                      final localSeen = <String>{};
                      for (final item in _items) {
                        if (item.name.trim().isEmpty ||
                            item.phone.trim().isEmpty) {
                          continue;
                        }
                        if (!localSeen.add(item.phone.trim())) {
                          continue;
                        }
                        payload.add(item.toPayload());
                      }

                      if (payload.isEmpty) {
                        CustomToast.show(
                          context,
                          message: "Tidak ada kontak valid untuk diimport",
                          isError: true,
                        );
                        return;
                      }

                      setState(() => _submitting = true);
                      final res = await context
                          .read<CustomerProvider>()
                          .importCustomersBulk(payload);
                      if (!context.mounted) return;
                      setState(() => _submitting = false);

                      if (!(res['success'] == true)) {
                        CustomToast.show(
                          context,
                          message:
                              res['message']?.toString() ??
                              'Gagal import pelanggan',
                          isError: true,
                        );
                        return;
                      }

                      final data = Map<String, dynamic>.from(
                        (res['data'] as Map?)?.cast<String, dynamic>() ??
                            const {},
                      );
                      final successCount = data['success_count'] ?? 0;
                      final skippedCount = data['skipped_count'] ?? 0;
                      final failedCount = data['failed_count'] ?? 0;
                      final rawResults = (data['results'] as List? ?? const [])
                          .cast<dynamic>()
                          .map((item) => Map<String, dynamic>.from(item as Map))
                          .toList();

                      if (!context.mounted) return;
                      await showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (sheetContext) => _ImportResultSheet(
                          successCount: successCount,
                          skippedCount: skippedCount,
                          failedCount: failedCount,
                          results: rawResults,
                        ),
                      );
                      if (!context.mounted) return;
                      Navigator.pop(context, true);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      "IMPORT ${_items.length} KONTAK",
                      style: const TextStyle(letterSpacing: 0.4),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<_BulkContactCandidate?> _showBulkContactEditor(
    BuildContext context,
    _BulkContactCandidate item,
  ) {
    final nameController = TextEditingController(text: item.name);
    final phoneController = TextEditingController(text: item.phone);
    String selectedGender = item.gender;

    return showModalBottomSheet<_BulkContactCandidate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final bottomSafe = MediaQuery.of(sheetContext).viewPadding.bottom;
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(16, 18, 16, 16 + bottomSafe),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
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
                        'Edit Kontak Import',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: AppFont.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: nameController,
                        labelText: 'Nama Lengkap',
                        hintText: 'Nama pelanggan',
                        fillColor: const Color(0xFFF9F9F9),
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: phoneController,
                        labelText: 'Nomor WhatsApp',
                        hintText: '08123456789',
                        keyboardType: TextInputType.phone,
                        fillColor: const Color(0xFFF9F9F9),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Jenis Kelamin',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildEditorGenderChip(
                            label: 'Netral',
                            value: '',
                            selectedGender: selectedGender,
                            onSelected: (value) {
                              setSheetState(() => selectedGender = value);
                            },
                          ),
                          const SizedBox(width: 10),
                          _buildEditorGenderChip(
                            label: 'Pria',
                            value: 'L',
                            selectedGender: selectedGender,
                            onSelected: (value) {
                              setSheetState(() => selectedGender = value);
                            },
                          ),
                          const SizedBox(width: 10),
                          _buildEditorGenderChip(
                            label: 'Wanita',
                            value: 'P',
                            selectedGender: selectedGender,
                            onSelected: (value) {
                              setSheetState(() => selectedGender = value);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(
                              sheetContext,
                              item.copyWith(
                                name: sanitizeCustomerName(
                                  nameController.text,
                                  fallback: 'Tanpa Nama',
                                ),
                                phone: normalizeContactPhone(
                                  phoneController.text,
                                ),
                                gender: selectedGender,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppPalette.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text('SIMPAN PERUBAHAN'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEditorGenderChip({
    required String label,
    required String value,
    required String selectedGender,
    required ValueChanged<String> onSelected,
  }) {
    final selected = selectedGender == value;
    return Expanded(
      child: InkWell(
        onTap: () => onSelected(value),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppPalette.primary
                : AppPalette.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppPalette.primary
                  : AppPalette.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: AppFont.w600,
                color: selected ? Colors.white : AppPalette.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 12, color: color, fontFamily: 'Inter'),
          children: [
            TextSpan(
              text: '$value ',
              style: const TextStyle(fontWeight: AppFont.w700),
            ),
            TextSpan(text: label),
          ],
        ),
      ),
    );
  }
}

class _ImportResultSheet extends StatelessWidget {
  final int successCount;
  final int skippedCount;
  final int failedCount;
  final List<Map<String, dynamic>> results;

  const _ImportResultSheet({
    required this.successCount,
    required this.skippedCount,
    required this.failedCount,
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 18, 16, 16 + bottomSafe),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
            'Hasil Import',
            style: TextStyle(fontSize: 20, fontWeight: AppFont.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryBadge(
                label: 'Berhasil',
                value: '$successCount',
                color: Colors.green,
              ),
              _SummaryBadge(
                label: 'Skip',
                value: '$skippedCount',
                color: Colors.orange,
              ),
              _SummaryBadge(
                label: 'Gagal',
                value: '$failedCount',
                color: Colors.redAccent,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: results.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = results[index];
                final status = item['status']?.toString() ?? '';
                final nama = item['nama']?.toString() ?? '-';
                final phone = item['no_hp']?.toString() ?? '-';
                final reason = item['reason']?.toString() ?? '';
                final tone = switch (status) {
                  'created' => Colors.green,
                  'skipped' => Colors.orange,
                  _ => Colors.redAccent,
                };
                final label = switch (status) {
                  'created' => 'Berhasil',
                  'skipped' => 'Skip',
                  _ => 'Gagal',
                };
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              nama,
                              style: const TextStyle(fontWeight: AppFont.w700),
                            ),
                          ),
                          Text(
                            label,
                            style: TextStyle(
                              color: tone,
                              fontSize: 12,
                              fontWeight: AppFont.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        phone,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      if (reason.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          reason,
                          style: TextStyle(fontSize: 12, color: tone),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text('SELESAI'),
            ),
          ),
        ],
      ),
    );
  }
}
