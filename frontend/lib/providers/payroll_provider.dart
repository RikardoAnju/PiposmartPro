import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/api_client.dart';
import '../core/utils/auth_storage.dart';

class PayrollDetailViewData {
  final String? employeeName;
  final String? salaryType;
  final String? status;
  final String period;
  final String dueDate;
  final String paidAt;
  final String paymentMethod;
  final String net;
  final num base;
  final num bonus;
  final num deduction;
  final String? baseNote;
  final String baseLabel;
  final num? workDays;
  final num? alfaDays;
  final num? overtimeMinutes;
  final num? pendingDeduction;
  final List<Map<String, dynamic>>? componentDetails;

  const PayrollDetailViewData({
    this.employeeName,
    this.salaryType,
    this.status,
    required this.period,
    required this.dueDate,
    required this.paidAt,
    required this.paymentMethod,
    required this.net,
    required this.base,
    required this.bonus,
    required this.deduction,
    this.baseNote,
    this.baseLabel = 'Gaji Pokok',
    this.workDays,
    this.alfaDays,
    this.overtimeMinutes,
    this.pendingDeduction,
    this.componentDetails,
  });
}

class PayrollProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _activeItems = [];
  List<Map<String, dynamic>> _upcomingItems = [];
  List<Map<String, dynamic>> _historyItems = [];
  List<Map<String, dynamic>> _pendingEmployees = [];
  List<Map<String, dynamic>> _configs = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get summary => _summary;
  List<Map<String, dynamic>> get activeItems => _activeItems;
  List<Map<String, dynamic>> get upcomingItems => _upcomingItems;
  List<Map<String, dynamic>> get historyItems => _historyItems;
  List<Map<String, dynamic>> get pendingEmployees => _pendingEmployees;
  List<Map<String, dynamic>> get configs => _configs;
  List<Map<String, dynamic>> get employeesWithoutSalaryConfig =>
      _pendingEmployees.where((employee) {
        final raw = employee['has_salary_config'];
        return raw != true && raw != 1 && raw?.toString() != '1';
      }).toList();
  Map<String, dynamic>? configForEmployee(String? employeeId) {
    final id = employeeId?.trim() ?? '';
    if (id.isEmpty) return null;
    for (final config in _configs) {
      if (config['pegawai_id']?.toString() == id) {
        return config;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> get unpaidPayrollItems {
    final items = _activeItems
        .where((item) => !_isDeletedPayrollItem(item))
        .where((item) => !_isPaidPayrollItem(item))
        .where(_isDuePayrollItem)
        .toList();
    items.sort(_comparePayrollItemForActive);
    return items;
  }

  bool _isDuePayrollItem(Map<String, dynamic> item) {
    final raw = item['due_date']?.toString();
    if (raw == null || raw.isEmpty) return true;
    final due = DateTime.tryParse(raw);
    if (due == null) return true;
    final today = DateTime.now();
    final dueDay = DateTime(due.year, due.month, due.day);
    final currentDay = DateTime(today.year, today.month, today.day);
    return !dueDay.isAfter(currentDay);
  }

  List<Map<String, dynamic>> get paidPayrollItems {
    final merged = <String, Map<String, dynamic>>{};
    for (final item in _historyItems) {
      if (_isDeletedPayrollItem(item)) continue;
      if (!_isPaidPayrollItem(item)) continue;
      // Jangan tampilkan record pembayaran kosong yang kadang tersisa dari
      // draft/duplikasi payroll. Record paid yang tidak memiliki nilai apa
      // pun bukan pembayaran yang valid untuk riwayat.
      if (_isEmptyPaidPayrollItem(item)) continue;
      final id = item['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        merged[id] = item;
      }
    }
    for (final item
        in _activeItems
            .where((item) => !_isDeletedPayrollItem(item))
            .where(_isPaidPayrollItem)
            .where((item) => !_isEmptyPaidPayrollItem(item))) {
      final id = item['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        merged[id] = item;
      }
    }
    final rawItems = merged.values.toList();
    // Kelompokkan item-item yang dibayar dalam 1 transaksi yang sama
    // (pegawai_id + period_id + paid_at yang sama).
    final payments = <String, List<Map<String, dynamic>>>{};
    for (final item in rawItems) {
      final employee = item['pegawai_id']?.toString().trim().isNotEmpty == true
          ? item['pegawai_id'].toString().trim()
          : (item['pegawai_nama']?.toString().toLowerCase().trim() ?? '');
      final periodKey = item['period_id']?.toString().trim().isNotEmpty == true
          ? item['period_id'].toString().trim()
          : '${item['period_year']}-${item['period_month']}';
      final paidAtRaw = item['paid_at']?.toString().trim() ?? '';
      final parsedDate = DateTime.tryParse(paidAtRaw)?.toLocal();
      final paidAtKey = parsedDate != null
          ? '${parsedDate.year}-${parsedDate.month}-${parsedDate.day}_${parsedDate.hour}:${parsedDate.minute}:${parsedDate.second}'
          : paidAtRaw;
      final key = '$employee|$periodKey|$paidAtKey';
      payments.putIfAbsent(key, () => []).add(item);
    }

    final combinedList = <Map<String, dynamic>>[];
    for (final group in payments.values) {
      if (group.isEmpty) continue;
      if (group.length == 1) {
        final single = group.first;
        if (!_isEmptyPaidPayrollItem(single)) {
          combinedList.add(single);
        }
        continue;
      }

      // Ada lebih dari 1 item dalam 1 kali transaksi bayar (mis. gaji harian
      // beberapa tanggal yang dibayar bersamaan). Gabungkan total dan metriknya.
      final first = Map<String, dynamic>.from(group.first);
      final totalBase = group.fold<double>(
        0,
        (sum, it) => sum + _numValue(it['base_amount']),
      );
      final totalBonus = group.fold<double>(
        0,
        (sum, it) => sum + _numValue(it['bonus_amount']),
      );
      final totalDeduction = group.fold<double>(
        0,
        (sum, it) => sum + _numValue(it['deduction_amount']),
      );
      final totalNet = (totalBase + totalBonus - totalDeduction).clamp(
        0.0,
        double.infinity,
      );

      final totalWorkDays = group.fold<int>(
        0,
        (sum, it) => sum + _numValue(it['work_days']).toInt(),
      );
      final totalAlfaDays = group.fold<int>(
        0,
        (sum, it) => sum + _numValue(it['alfa_days']).toInt(),
      );
      final totalOvertime = group.fold<int>(
        0,
        (sum, it) => sum + _numValue(it['overtime_minutes']).toInt(),
      );

      if (totalBase == 0 &&
          totalBonus == 0 &&
          totalDeduction == 0 &&
          totalNet == 0 &&
          totalWorkDays == 0) {
        continue;
      }

      final allComponents = <Map<String, dynamic>>[];
      for (final it in group) {
        final comps = it['components'];
        if (comps is List) {
          for (final c in comps) {
            if (c is Map<String, dynamic>) {
              allComponents.add(c);
            }
          }
        }
      }

      final combined = <String, dynamic>{
        ...first,
        'base_amount': totalBase,
        'bonus_amount': totalBonus,
        'deduction_amount': totalDeduction,
        'net_amount': totalNet,
        'work_days': totalWorkDays,
        'alfa_days': totalAlfaDays,
        'overtime_minutes': totalOvertime,
        if (allComponents.isNotEmpty) 'components': allComponents,
        '_item_ids': group
            .map((it) => it['id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toList(),
        '_combined': true,
      };
      combinedList.add(combined);
    }

    combinedList.sort(_comparePayrollItemForHistory);
    return combinedList;
  }

  bool _isEmptyPaidPayrollItem(Map<String, dynamic> item) {
    return _numValue(item['base_amount']) == 0 &&
        _numValue(item['bonus_amount']) == 0 &&
        _numValue(item['deduction_amount']) == 0 &&
        _numValue(item['net_amount']) == 0;
  }

  List<Map<String, dynamic>> get groupedUnpaidPayrollItems =>
      _groupPayrollItems(unpaidPayrollItems);
  List<Map<String, dynamic>> get groupedPaidPayrollItems =>
      _groupPayrollItems(paidPayrollItems);

  /// Riwayat dikelompokkan PER PERIODE (bulan). Tiap grup berisi item
  /// pembayaran semua pegawai pada periode tsb. Diurutkan periode terbaru dulu.
  List<Map<String, dynamic>> get periodGroupedPaidPayrollItems {
    return _periodGroupsFor(paidPayrollItems);
  }

  List<Map<String, dynamic>> periodGroupedPaidPayrollItemsBetween(
    DateTime? from,
    DateTime? to,
  ) {
    final start = from == null
        ? null
        : DateTime(from.year, from.month, from.day);
    final end = to == null
        ? null
        : DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    final filtered = paidPayrollItems.where((item) {
      final raw = item['paid_at']?.toString().trim().isNotEmpty == true
          ? item['paid_at']?.toString()
          : item['due_date']?.toString();
      final date = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
      if (date == null) return from == null && to == null;
      if (start != null && date.isBefore(start)) return false;
      if (end != null && date.isAfter(end)) return false;
      return true;
    }).toList();
    return _periodGroupsFor(filtered);
  }

  List<Map<String, dynamic>> _periodGroupsFor(
    List<Map<String, dynamic>> items,
  ) {
    final groups = <String, Map<String, dynamic>>{};
    for (final item in items) {
      final year = item['period_year']?.toString().trim() ?? '';
      final month = item['period_month']?.toString().trim() ?? '';
      final String key = (year.isNotEmpty && month.isNotEmpty)
          ? '$year-${month.padLeft(2, '0')}'
          : (_stringValue(item['period_label']) ??
                _stringValue(item['period_id']) ??
                '-');
      final group = groups.putIfAbsent(key, () {
        return {
          'period_key': key,
          'sample': item, // dipakai untuk menghitung label periode di UI
          'items': <Map<String, dynamic>>[],
          'total': 0.0,
        };
      });
      final groupItems = (group['items'] as List).cast<Map<String, dynamic>>();
      groupItems.add(item);
      group['items'] = groupItems;
      group['total'] =
          (group['total'] as double) + _numValue(item['net_amount']);
    }

    final result = groups.values.toList();
    // Satu section untuk satu bulan; beberapa tanggal bayar digabung di
    // dalamnya, tetapi setiap item pembayaran tetap menjadi kartu terpisah.
    result.sort(
      (a, b) =>
          (b['period_key'] as String).compareTo(a['period_key'] as String),
    );
    return result;
  }

  double _numValue(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  List<Map<String, dynamic>> _groupPayrollItems(
    List<Map<String, dynamic>> items,
  ) {
    final groups = <String, Map<String, dynamic>>{};
    for (final item in items) {
      final employeeId = item['pegawai_id']?.toString().trim();
      final employeeName = _stringValue(item['pegawai_nama']) ?? '-';
      final employeeKey = employeeId != null && employeeId.isNotEmpty
          ? employeeId
          : employeeName.toLowerCase().trim();
      // Gabungkan hanya item dalam PERIODE yang sama (selaras dengan logika
      // "tunggakan" di backend). Tanpa ini, item unpaid dari periode lama
      // yang masih nunggak ikut kejumlah diam-diam ke kartu periode berjalan,
      // sehingga "Total Gaji (Gabungan)" tidak sama dengan total yang
      // dihitung layar detail (yang memang dibatasi per periode).
      final periodKey = item['period_id']?.toString().trim().isNotEmpty == true
          ? item['period_id'].toString()
          : '${item['period_year']}-${item['period_month']}';
      final key = '$employeeKey|$periodKey';
      final group = groups.putIfAbsent(key, () {
        return {
          'pegawai_id': employeeId,
          'pegawai_nama': employeeName,
          'role_nama': item['role_nama']?.toString(),
          'salary_type': item['salary_type']?.toString(),
          'items': <Map<String, dynamic>>[],
        };
      });
      final groupItems = (group['items'] as List).cast<Map<String, dynamic>>();
      groupItems.add(item);
      group['items'] = groupItems;
    }

    final result = groups.values.toList();
    result.sort((a, b) {
      final aItem = _firstItem(a['items']);
      final bItem = _firstItem(b['items']);
      final cmp = _comparePayrollItemForActive(aItem, bItem);
      if (cmp != 0) return cmp;
      return _stringValue(a['pegawai_nama'])?.toLowerCase().compareTo(
            _stringValue(b['pegawai_nama'])?.toLowerCase() ?? '',
          ) ??
          0;
    });
    return result;
  }

  Map<String, dynamic> _firstItem(dynamic items) {
    final list =
        (items as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    return list.isNotEmpty ? list.first : const <String, dynamic>{};
  }

  int _comparePayrollItemForActive(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final dueA = _parseDateTime(a['due_date']);
    final dueB = _parseDateTime(b['due_date']);
    final cmpDue = dueA.compareTo(dueB);
    if (cmpDue != 0) return cmpDue;
    final cmpName =
        _stringValue(a['pegawai_nama'])?.toLowerCase().compareTo(
          _stringValue(b['pegawai_nama'])?.toLowerCase() ?? '',
        ) ??
        0;
    if (cmpName != 0) return cmpName;
    final cmpCreated = _parseDateTime(
      a['created_at'],
    ).compareTo(_parseDateTime(b['created_at']));
    if (cmpCreated != 0) return cmpCreated;
    return _stringValue(a['id'])?.compareTo(_stringValue(b['id']) ?? '') ?? 0;
  }

  int _comparePayrollItemForHistory(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final paidA = _parseDateTime(a['paid_at']);
    final paidB = _parseDateTime(b['paid_at']);
    final cmpPaid = paidB.compareTo(paidA);
    if (cmpPaid != 0) return cmpPaid;
    final dueA = _parseDateTime(a['due_date']);
    final dueB = _parseDateTime(b['due_date']);
    final cmpDue = dueB.compareTo(dueA);
    if (cmpDue != 0) return cmpDue;
    final cmpName =
        _stringValue(a['pegawai_nama'])?.toLowerCase().compareTo(
          _stringValue(b['pegawai_nama'])?.toLowerCase() ?? '',
        ) ??
        0;
    if (cmpName != 0) return cmpName;
    return _stringValue(a['id'])?.compareTo(_stringValue(b['id']) ?? '') ?? 0;
  }

  // Ringkasan tab Aktif harus mengikuti item yang benar-benar tampil dan
  // sudah jatuh tempo. Item unpaid yang belum jatuh tempo ada di Gaji
  // Mendatang dan tidak boleh ikut menghitung total aktif.
  //
  // Dihitung PER PEGAWAI (base+bonus-deduction, clamp ke 0 sekali di akhir),
  // bukan menjumlahkan net_amount tiap item mentah-mentah. Tiap item unpaid
  // sudah di-clamp ke 0 sendiri-sendiri oleh backend; kalau satu item punya
  // potongan lebih besar dari base+bonus item itu sendiri, potongannya bisa
  // "hilang" saat dijumlah per item alih-alih ikut mengurangi total
  // gabungan pegawai tsb — sehingga total di sini tidak sinkron dengan
  // "Total Gaji (Gabungan)" pada tiap kartu (lihat payroll_group_card.dart).
  double get totalAmount =>
      groupedUnpaidPayrollItems.fold<double>(0, (sum, group) {
        final items =
            (group['items'] as List?)?.cast<Map<String, dynamic>>() ??
            const <Map<String, dynamic>>[];
        final base = items.fold<double>(
          0,
          (t, item) => t + _numValue(item['base_amount']),
        );
        final bonus = items.fold<double>(
          0,
          (t, item) => t + _numValue(item['bonus_amount']),
        );
        final deduction = items.fold<double>(
          0,
          (t, item) => t + _numValue(item['deduction_amount']),
        );
        final net = (base + bonus - deduction).clamp(0, double.infinity);
        return sum + net;
      });
  int get unpaidCount => groupedUnpaidPayrollItems.length;
  int get paidCount => (_summary?['sudah_dibayar'] as num?)?.toInt() ?? 0;
  String get periodLabel {
    final candidates = [
      _summary?['periode_label'],
      _summary?['period_label'],
      _summary?['periode'],
      _summary?['period'],
      _summary?['label'],
    ];
    for (final candidate in candidates) {
      final value = candidate?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '-';
  }

  bool _isPaidPayrollItem(Map<String, dynamic> item) {
    final normalizedStatus = _normalizePayrollStatus(item);
    if (normalizedStatus.isNotEmpty) {
      const paidStatuses = {
        'paid',
        'sudah dibayar',
        'dibayar',
        'lunas',
        'success',
        'selesai',
        'completed',
        'settled',
      };
      const unpaidStatuses = {
        'unpaid',
        'belum dibayar',
        'pending',
        'generated',
        'draft',
        'aktif',
        'active',
      };
      if (normalizedStatus == 'deleted') return false;
      if (paidStatuses.contains(normalizedStatus)) return true;
      if (unpaidStatuses.contains(normalizedStatus)) return false;
    }

    final paidAt = item['paid_at']?.toString().trim();
    if (paidAt != null && paidAt.isNotEmpty && paidAt != '-') {
      return true;
    }

    return false;
  }

  bool _isDeletedPayrollItem(Map<String, dynamic> item) {
    final normalizedStatus = _normalizePayrollStatus(item);
    return normalizedStatus == 'deleted' ||
        normalizedStatus == 'soft_deleted' ||
        normalizedStatus == 'removed';
  }

  String _normalizePayrollStatus(Map<String, dynamic> item) {
    final candidates = [
      item['status'],
      item['payment_status'],
      item['paymentStatus'],
      item['status_pembayaran'],
      item['payroll_status'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim().toLowerCase() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String? _stringValue(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  DateTime _parseDateTime(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == '-') {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.tryParse(text) ??
        DateTime.tryParse('${text}T00:00:00') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> fetchAll({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      // Tampilkan payroll aktif terlebih dahulu. Data pendukung dimuat
      // setelahnya agar halaman tidak menunggu seluruh endpoint selesai.
      await fetchDashboard(silent: true);
      await Future.wait([
        fetchPendingEmployees(silent: true),
        fetchConfigs(silent: true),
        fetchHistory(silent: true),
      ]);
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchDashboard({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      final token = AuthStorage.token;
      final res = await ApiClient.get('/payroll/active', token: token);
      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body['status'] == true) {
        _summary = Map<String, dynamic>.from(body['data'] ?? {});
        _activeItems = List<Map<String, dynamic>>.from(
          (_summary?['items'] ?? const []).map(
            (e) => Map<String, dynamic>.from(e),
          ),
        );
        final apiUpcoming = List<Map<String, dynamic>>.from(
          (_summary?['akan_datang'] ?? const []).map(
            (e) => Map<String, dynamic>.from(e),
          ),
        );
        // Backend juga mengirim draft payroll berikutnya di `items`. Jangan
        // biarkan item unpaid yang tanggalnya belum tiba hilang hanya karena
        // pegawai tersebut sudah memiliki payroll paid pada periode ini.
        final today = DateTime.now();
        final todayOnly = DateTime(today.year, today.month, today.day);
        String upcomingKey(Map<String, dynamic> item) {
          final employee = item['pegawai_id']?.toString() ?? '';
          final due = item['due_date']?.toString().split('T').first ?? '';
          return '$employee|$due';
        }

        final existingUpcomingKeys = <String>{};
        final validApiUpcoming = apiUpcoming.where((item) {
          final raw = item['due_date']?.toString();
          final due = raw == null ? null : DateTime.tryParse(raw);
          if (due != null &&
              !DateTime(due.year, due.month, due.day).isAfter(todayOnly)) {
            return false;
          }
          existingUpcomingKeys.add(upcomingKey(item));
          return true;
        }).toList();
        final futureItems = _activeItems.where((item) {
          if (_isDeletedPayrollItem(item) || _isPaidPayrollItem(item)) {
            return false;
          }
          final raw = item['due_date']?.toString();
          final due = raw == null ? null : DateTime.tryParse(raw);
          if (due == null) return false;
          return DateTime(due.year, due.month, due.day).isAfter(todayOnly);
        });
        _upcomingItems = [
          ...validApiUpcoming,
          ...futureItems.where(
            (item) => !existingUpcomingKeys.contains(upcomingKey(item)),
          ),
        ];
        _errorMessage = null;
        // Beri tahu listener walau dipanggil silent, supaya card di list
        // (mis. setelah kembali dari layar detail) langsung ikut update
        // tanpa menunggu timer refresh 30 detik.
        notifyListeners();
      } else {
        _errorMessage = body['message']?.toString() ?? 'Gagal memuat payroll';
        // Surface error meski dipanggil silent (mis. via fetchAll) supaya UI
        // bisa menampilkannya, bukan diam dengan data lama.
        if (silent) notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Gagal memuat payroll';
      if (silent) notifyListeners();
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchPendingEmployees({bool silent = false}) async {
    try {
      final token = AuthStorage.token;
      final res = await ApiClient.get(
        '/payroll/pending-employees',
        token: token,
      );
      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body['status'] == true) {
        _pendingEmployees = List<Map<String, dynamic>>.from(
          (body['data'] ?? const []).map((e) => Map<String, dynamic>.from(e)),
        );
        notifyListeners();
      }
    } catch (_) {
      _errorMessage = 'Gagal memuat data payroll';
      notifyListeners();
    }
  }

  Future<void> fetchConfigs({bool silent = false}) async {
    try {
      final token = AuthStorage.token;
      final res = await ApiClient.get('/payroll/configs', token: token);
      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body['status'] == true) {
        _configs = List<Map<String, dynamic>>.from(
          (body['data'] ?? const []).map((e) => Map<String, dynamic>.from(e)),
        );
        notifyListeners();
      }
    } catch (_) {
      _errorMessage = 'Gagal memuat data payroll';
      notifyListeners();
    }
  }

  Future<void> fetchHistory({bool silent = false}) async {
    try {
      final token = AuthStorage.token;
      final res = await ApiClient.get('/payroll/history', token: token);
      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body['status'] == true) {
        _historyItems = List<Map<String, dynamic>>.from(
          (body['data'] ?? const []).map((e) => Map<String, dynamic>.from(e)),
        );
        notifyListeners();
      }
    } catch (_) {
      _errorMessage = 'Gagal memuat data payroll';
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> saveSalaryConfig({
    required String pegawaiId,
    required Map<String, dynamic> payload,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final res = await ApiClient.post(
        '/payroll/configs/$pegawaiId',
        body: payload,
        token: token,
      );
      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body['status'] == true) {
        await fetchAll(silent: true);
        return {
          'success': true,
          'message': body['message'] ?? 'Tersimpan',
          'data': body['data'],
        };
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Gagal menyimpan konfigurasi gaji',
      };
    } catch (_) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> fetchItemDetail(String itemId) async {
    try {
      final token = AuthStorage.token;
      final res = await ApiClient.get('/payroll/items/$itemId', token: token);
      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body['status'] == true) {
        return {
          'success': true,
          'data': Map<String, dynamic>.from(body['data'] ?? {}),
        };
      }
      return {
        'success': false,
        'message': body['message']?.toString() ?? 'Gagal memuat detail payroll',
      };
    } catch (_) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    }
  }

  Future<Map<String, dynamic>> updateItemComponents({
    required String itemId,
    required Map<String, dynamic> payload,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final res = await ApiClient.put(
        '/payroll/items/$itemId',
        body: payload,
        token: token,
      );
      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body['status'] == true) {
        await fetchAll(silent: true);
        return {
          'success': true,
          'message': body['message'] ?? 'Tersimpan',
          'data': body['data'] is Map
              ? Map<String, dynamic>.from(body['data'])
              : <String, dynamic>{},
        };
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Gagal menyimpan komponen payroll',
      };
    } catch (_) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> deleteItem(String itemId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      final res = await ApiClient.delete(
        '/payroll/items/$itemId',
        token: token,
      );
      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body['status'] == true) {
        await fetchAll(silent: true);
        return {'success': true, 'message': body['message'] ?? 'Berhasil'};
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Gagal menghapus item payroll',
      };
    } catch (_) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> markPaid({
    required String itemId,
    required String paymentMethod,
    String? buktiPath,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final token = AuthStorage.token;
      // Multipart: kirim metode + (opsional) file struk sebagai bukti, yang
      // otomatis dilampirkan ke record pengeluaran di backend.
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiClient.baseUrl}/payroll/items/$itemId/paid'),
      );
      request.headers.addAll({'Authorization': 'Bearer $token'});
      request.fields['payment_method'] = paymentMethod;
      if (buktiPath != null && buktiPath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath('bukti', buktiPath),
        );
      }
      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);
      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body['status'] == true) {
        await fetchAll(silent: true);
        return {
          'success': true,
          'message': body['message'] ?? 'Berhasil',
          'data': body['data'] is Map
              ? Map<String, dynamic>.from(body['data'])
              : <String, dynamic>{},
        };
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Gagal memproses pembayaran',
      };
    } catch (_) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> markBulkPaid({
    required List<String> itemIds,
    required String paymentMethod,
  }) async {
    final token = AuthStorage.token;
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiClient.baseUrl}/payroll/items/bulk-paid'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['item_ids'] = jsonEncode(itemIds);
    request.fields['payment_method'] = paymentMethod;
    final response = await http.Response.fromStream(await request.send());
    final body = jsonDecode(response.body);
    if (response.statusCode == 200 && body['status'] == true) {
      await fetchAll(silent: true);
      return {'success': true, 'data': body['data'] ?? {}};
    }
    return {
      'success': false,
      'message': body['message'] ?? 'Gagal membayar payroll',
    };
  }

  // ===== Helper format & util payroll (dipindah dari screen) =====

  static String formatDueLabel(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    return DateFormat('d MMM yyyy', 'id_ID').format(date);
  }

  static String displayComponentLabel(String? raw, {required String fallback}) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return fallback;
    if (value.toLowerCase() == 'pulkam') return 'Potongan (Pulkam)';
    return value[0].toUpperCase() + value.substring(1);
  }

  static num toNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    return num.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
  }

  static String formatCurrency(num value) {
    final format = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    );
    return format.format(value);
  }

  static String formatInputCurrency(int value) {
    return formatCurrency(value).replaceAll('Rp', 'Rp ');
  }

  static int parseRupiah(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  static String paymentMethodLabel(String? raw) {
    final value = raw?.toLowerCase().trim() ?? '';
    if (value.isEmpty) return 'Belum dipilih';
    if (value.startsWith('transfer_')) {
      final bank = value.substring('transfer_'.length).toUpperCase();
      return bank.isEmpty ? 'Transfer' : 'Transfer - $bank';
    }
    switch (value) {
      case 'cash':
        return 'Tunai';
      case 'ewallet':
        return 'E-Wallet';
      default:
        // Termasuk data lama 'bank_transfer' → tampil sebagai Transfer.
        return 'Transfer';
    }
  }

  static String formatDateTime(dynamic value) {
    final dt = parseLocalDateTime(value);
    if (dt == null) return '-';
    return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(dt);
  }

  static DateTime? parseLocalDateTime(dynamic value) {
    if (value is DateTime) return value.toLocal();
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty || raw == '-') return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;

    if (!parsed.isUtc && !hasTimezoneSuffix(raw)) {
      return DateTime.utc(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
        parsed.millisecond,
      ).toLocal();
    }
    return parsed.toLocal();
  }

  // Deteksi apakah string tanggal menyertakan info zona waktu (Z atau ±hh:mm).
  static bool hasTimezoneSuffix(String raw) {
    if (raw.endsWith('Z') || raw.endsWith('z')) return true;
    // Cari offset +hh:mm / -hh:mm pada bagian waktu (setelah 'T' atau spasi).
    final timePart = raw.contains('T')
        ? raw.substring(raw.indexOf('T') + 1)
        : (raw.contains(' ') ? raw.substring(raw.indexOf(' ') + 1) : raw);
    return RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(timePart);
  }

  static String salaryTypeFromConfig(Map<String, dynamic>? config) {
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

  static String salaryTypeLabel(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'monthly':
        return 'Bulanan';
      case 'weekly':
        return 'Mingguan';
      case 'daily':
        return 'Harian';
      default:
        return raw == null || raw.trim().isEmpty ? '-' : raw;
    }
  }

  static String scheduleTypeFromConfig(Map<String, dynamic>? config) {
    final raw = config?['schedule_type']?.toString();
    if (raw == 'weekly_day') return 'weekly_day';
    if (raw == 'every_n_days') return 'every_n_days';
    if (raw == 'daily') return 'daily';
    return 'fixed_date';
  }

  static String formatConfigAmount(Map<String, dynamic>? config) {
    final value = toNum(config?['amount']);
    if (value <= 0) return '';
    return formatInputCurrency(value.toInt());
  }

  static String payDayFromConfig(Map<String, dynamic>? config) {
    final value = config?['pay_day'];
    return value?.toString() ?? '25';
  }

  static String payEveryDaysFromConfig(Map<String, dynamic>? config) {
    final value = config?['pay_every_days'];
    return value?.toString() ?? '3';
  }

  static String payDayNameFromConfig(Map<String, dynamic>? config) {
    return config?['pay_day_name']?.toString() ?? 'Senin';
  }

  static String scheduleText(Map<String, dynamic>? config) {
    if (config == null) return '-';
    final type = scheduleTypeFromConfig(config);
    switch (type) {
      case 'weekly_day':
        return config['pay_day_name']?.toString() ?? 'Senin';
      case 'every_n_days':
        return '${config['pay_every_days']?.toString() ?? '3'} Hari Sekali';
      case 'daily':
        return 'Setiap Hari';
      default:
        final day = config['pay_day']?.toString() ?? '25';
        return 'Setiap Tanggal $day';
    }
  }

  static String payrollDueLabel(Map<String, dynamic> item) {
    final dueDate = parseLocalDateTime(item['due_date']);
    if (dueDate != null) {
      return DateFormat('d MMMM yyyy', 'id_ID').format(dueDate.toLocal());
    }

    final salaryType = item['salary_type']?.toString().toLowerCase().trim();
    final scheduleType = scheduleTypeFromConfig(item);
    switch (scheduleType) {
      case 'weekly_day':
        return 'Setiap ${weekdayLabel(item['pay_day_name']?.toString())}';
      case 'every_n_days':
        final every = item['pay_every_days']?.toString().trim();
        return 'Setiap ${every == null || every.isEmpty ? '3' : every} hari';
      case 'daily':
        return 'Setiap hari';
      case 'fixed_date':
      default:
        if (salaryType == 'weekly') {
          final dayName = item['pay_day_name']?.toString().trim();
          if (dayName != null && dayName.isNotEmpty) {
            return 'Setiap ${weekdayLabel(dayName)}';
          }
        }
        final day = item['pay_day']?.toString().trim();
        return 'Setiap tanggal ${day == null || day.isEmpty ? '25' : day}';
    }
  }

  static String weekdayLabel(String? raw) {
    switch (raw?.toLowerCase().trim()) {
      case 'monday':
      case 'senin':
        return 'Senin';
      case 'tuesday':
      case 'selasa':
        return 'Selasa';
      case 'wednesday':
      case 'rabu':
        return 'Rabu';
      case 'thursday':
      case 'kamis':
        return 'Kamis';
      case 'friday':
      case 'jumat':
      case 'jum\'at':
        return 'Jumat';
      case 'saturday':
      case 'sabtu':
        return 'Sabtu';
      case 'sunday':
      case 'minggu':
        return 'Minggu';
      default:
        return raw == null || raw.trim().isEmpty ? '-' : raw;
    }
  }

  static String employeeAmountText(Map<String, dynamic> employee) {
    final amount = toNum(employee['amount']);
    if (amount <= 0) return '-';
    final formatted = formatCurrency(amount);
    final salaryType = employee['salary_type']?.toString().toLowerCase();
    switch (salaryType) {
      case 'weekly':
        return '$formatted/Minggu';
      case 'daily':
        return '$formatted/Hari';
      default:
        return '$formatted/Bulan';
    }
  }

  /// Keterangan di bawah "Gaji Pokok" untuk gaji harian:
  /// "23 hari kerja × Rp90.000". Null bila bukan gaji harian / data tak ada.
  static String? baseBreakdownText(Map<String, dynamic> item) {
    final salaryType = item['salary_type']?.toString().toLowerCase().trim();
    if (salaryType != 'daily') return null;
    final workDays = toNum(item['work_days']).toInt();
    final dailyRate = toNum(item['daily_rate']) > 0
        ? toNum(item['daily_rate'])
        : (toNum(item['base_amount']) / workDays);
    if (workDays <= 0) return null;
    if (dailyRate > 0) {
      return '$workDays hari kerja × ${formatCurrency(dailyRate)}';
    }
    return '$workDays hari kerja';
  }

  /// Keterangan lembur yang mudah dibaca, misalnya "3 jam (20 menit) lembur".
  static String? overtimeText(Map<String, dynamic> item) {
    final minutes = toNum(item['overtime_minutes']).toInt();
    if (minutes <= 0) return null;
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours > 0 && rest > 0) return '$hours jam ($rest menit) lembur';
    if (hours > 0) return '$hours jam lembur';
    return '$minutes menit lembur';
  }

  static String formatDate(dynamic raw) {
    if (raw == null) return '-';
    final text = raw.toString();
    final date = DateTime.tryParse(text);
    if (date == null) return text;
    return DateFormat('dd MMM yyyy', 'id_ID').format(date.toLocal());
  }

  static String formatPeriod(Map<String, dynamic> item) {
    // Utamakan bulan/tahun numerik agar label selalu Bahasa Indonesia (Agu),
    // bukan mengikuti label backend yang berbahasa Inggris (Aug).
    final month = item['period_month'];
    final year = item['period_year'];
    if (month != null && year != null) {
      final m = int.tryParse(month.toString()) ?? 0;
      final y = int.tryParse(year.toString()) ?? 0;
      if (m > 0 && y > 0) {
        return '${monthAbbrId(m)} $y';
      }
    }

    final labelCandidates = [
      item['period_label'],
      item['periodLabel'],
      item['periode_label'],
      item['periode'],
      item['period'],
    ];
    for (final candidate in labelCandidates) {
      final value = candidate?.toString().trim();
      if (value != null && value.isNotEmpty && value != '-') {
        return indoPeriodLabel(value);
      }
    }

    final fallbackDate = parseLocalDateTime(
      item['due_date'] ?? item['paid_at'],
    );
    if (fallbackDate != null) {
      return DateFormat('MMM yyyy', 'id_ID').format(fallbackDate.toLocal());
    }

    final periodId = item['period_id']?.toString() ?? '';
    return periodId.isEmpty ? '-' : periodId;
  }

  static String monthAbbrId(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return month >= 1 && month <= 12 ? months[month] : '-';
  }

  static String monthNameId(int month) {
    const months = [
      '',
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
    return month >= 1 && month <= 12 ? months[month] : '-';
  }

  // Periode dengan nama bulan penuh (mis. "Agustus 2026"). Dipakai di layar yang
  // punya ruang lega seperti struk sukses; layar list tetap pakai versi singkat.
  static String formatPeriodLong(Map<String, dynamic> item) {
    final month = item['period_month'];
    final year = item['period_year'];
    if (month != null && year != null) {
      final m = int.tryParse(month.toString()) ?? 0;
      final y = int.tryParse(year.toString()) ?? 0;
      if (m > 0 && y > 0) {
        return '${monthNameId(m)} $y';
      }
    }
    final fallbackDate = parseLocalDateTime(
      item['due_date'] ?? item['paid_at'],
    );
    if (fallbackDate != null) {
      return DateFormat('MMMM yyyy', 'id_ID').format(fallbackDate.toLocal());
    }
    return formatPeriod(item);
  }

  /// Ubah nama bulan berbahasa Inggris (mis. "Aug 2026" / "August 2026") pada
  /// label periode dari backend menjadi singkatan Bahasa Indonesia ("Agu 2026").
  static String indoPeriodLabel(String raw) {
    const map = {
      'january': 'Jan',
      'jan': 'Jan',
      'february': 'Feb',
      'feb': 'Feb',
      'march': 'Mar',
      'mar': 'Mar',
      'april': 'Apr',
      'apr': 'Apr',
      'may': 'Mei',
      'june': 'Jun',
      'jun': 'Jun',
      'july': 'Jul',
      'jul': 'Jul',
      'august': 'Agu',
      'aug': 'Agu',
      'september': 'Sep',
      'sep': 'Sep',
      'sept': 'Sep',
      'october': 'Okt',
      'oct': 'Okt',
      'november': 'Nov',
      'nov': 'Nov',
      'december': 'Des',
      'dec': 'Des',
    };
    return raw.replaceAllMapped(RegExp(r'[A-Za-z]+'), (m) {
      final key = m.group(0)!.toLowerCase();
      return map[key] ?? m.group(0)!;
    });
  }

  static String payrollStatusText(Map<String, dynamic> item) {
    final candidates = [
      item['status'],
      item['payment_status'],
      item['paymentStatus'],
      item['status_pembayaran'],
      item['payroll_status'],
    ];
    for (final candidate in candidates) {
      final value = candidate?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return 'unpaid';
  }

  static bool isPaidPayrollStatus(String? rawStatus) {
    final status = rawStatus?.toLowerCase().trim() ?? '';
    const paidStatuses = {
      'paid',
      'sudah dibayar',
      'dibayar',
      'lunas',
      'success',
      'selesai',
      'completed',
      'settled',
    };
    if (paidStatuses.contains(status)) return true;
    if (status.isEmpty) return false;
    const unpaidStatuses = {
      'unpaid',
      'belum dibayar',
      'pending',
      'generated',
      'draft',
      'aktif',
      'active',
    };
    if (unpaidStatuses.contains(status)) return false;
    return false;
  }

  static bool isOverduePayroll(Map<String, dynamic> item) {
    if (isPaidPayrollStatus(payrollStatusText(item))) return false;
    final dueDate = parseLocalDateTime(item['due_date']);
    if (dueDate == null) return false;
    final today = DateTime.now();
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final current = DateTime(today.year, today.month, today.day);
    return due.isBefore(current);
  }

  static String payrollStatusLabel(Map<String, dynamic> item) {
    if (isPaidPayrollStatus(payrollStatusText(item))) return 'SUDAH DIBAYAR';
    return isOverduePayroll(item) ? 'TERLAMBAT DIBAYAR' : 'BELUM DIBAYAR';
  }

  // ===== Welcome state (dipindah dari SalarySettingsScreen) =====

  static const String welcomeSeenKey = 'payroll_welcome_seen_v1';

  Future<bool> isWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(welcomeSeenKey) ?? false;
  }

  Future<void> markWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(welcomeSeenKey, true);
  }

  // ===== Metode pembayaran =====

  /// Normalisasi metode ke salah satu: 'cash' | 'ewallet' | 'transfer'.
  static String normalizePaymentMethod(String? raw) {
    final value = raw?.toLowerCase().trim() ?? '';
    if (value.isEmpty) return '';
    switch (value) {
      case 'cash':
      case 'tunai':
        return 'cash';
      case 'ewallet':
      case 'e-wallet':
        return 'ewallet';
      case 'transfer':
      case 'bank_transfer':
        return 'transfer';
      default:
        return value.startsWith('transfer_') ? value : 'transfer';
    }
  }

  // ===== Komponen payroll (bonus/potongan) =====

  static bool isSameComponent(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aId = a['id']?.toString().trim();
    final bId = b['id']?.toString().trim();
    if (aId != null && bId != null && aId.isNotEmpty && bId.isNotEmpty) {
      return aId == bId;
    }
    return a['type']?.toString() == b['type']?.toString() &&
        a['name']?.toString() == b['name']?.toString() &&
        toNum(a['amount']) == toNum(b['amount']);
  }

  /// Komponen manual (tanpa baris "base") dari detail item.
  static List<Map<String, dynamic>> manualComponents(
    Map<String, dynamic> detail,
  ) {
    final current =
        (detail['components'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    return current.where((e) => e['type']?.toString().toLowerCase() != 'base')
    // Potongan alfa dari absensi bukan potongan manual. Jangan kirim
    // kembali saat pengguna menambah bonus/potongan agar gaji tidak
    // terpotong sebelum tombol potong dipilih.
    .where((e) {
      final type = e['type']?.toString().toLowerCase() ?? '';
      final source = e['source']?.toString().toLowerCase() ?? '';
      return !(type == 'deduction' && source == 'attendance');
    }).toList();
  }

  Map<String, dynamic> _componentPayload(
    Map<String, dynamic> detail,
    List<Map<String, dynamic>> components,
  ) {
    return {
      'base_amount': toNum(detail['base_amount']),
      'components': components,
      'notes': detail['notes']?.toString() ?? '',
    };
  }

  /// Tambah satu komponen bonus/potongan lalu simpan ke server.
  Future<Map<String, dynamic>> addItemComponent({
    required String itemId,
    required Map<String, dynamic> detail,
    required String type,
    required String rawName,
    required num amount,
  }) async {
    if (amount <= 0) {
      return {'success': false, 'message': 'Nominal harus lebih dari 0'};
    }
    // Pertahankan potongan alfa yang sudah diterapkan. Komponen tersebut
    // tidak boleh hilang ketika bonus/potongan manual baru ditambahkan.
    final current =
        (detail['components'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final next = current.where((component) {
      return component['type']?.toString().toLowerCase() != 'base';
    }).toList();
    next.add({
      'type': type,
      'name': rawName.trim().isEmpty
          ? (type == 'deduction' ? 'Potongan' : 'Bonus')
          : rawName.trim(),
      'amount': amount,
    });
    return updateItemComponents(
      itemId: itemId,
      payload: _componentPayload(detail, next),
    );
  }

  /// Hapus SATU kemunculan komponen (occurrence pertama) lalu simpan.
  Future<Map<String, dynamic>> removeItemComponent({
    required String itemId,
    required Map<String, dynamic> detail,
    required Map<String, dynamic> component,
  }) async {
    final current =
        (detail['components'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final next = <Map<String, dynamic>>[];
    var removed = false;
    for (final item in current) {
      if (!removed && isSameComponent(item, component)) {
        removed = true;
        continue;
      }
      next.add(item);
    }
    return updateItemComponents(
      itemId: itemId,
      payload: _componentPayload(detail, next),
    );
  }

  // ===== Simpan konfigurasi gaji dari input form =====

  Future<Map<String, dynamic>> saveConfigInputs({
    required String pegawaiId,
    required String salaryType,
    required num amount,
    required String scheduleType,
    required int payDay,
    required int payEveryDays,
    required String payDayName,
  }) async {
    if (amount <= 0) {
      return {'success': false, 'message': 'Nominal gaji harus lebih dari 0'};
    }
    return saveSalaryConfig(
      pegawaiId: pegawaiId,
      payload: {
        'salary_type': salaryType.toLowerCase(),
        'is_active': true,
        'amount': amount,
        'schedule_type': scheduleType,
        'pay_day': payDay,
        'pay_every_days': payEveryDays,
        'pay_day_name': payDayName,
      },
    );
  }
}
