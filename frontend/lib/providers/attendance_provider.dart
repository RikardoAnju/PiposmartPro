import 'dart:convert';

import 'package:ayocucinew/core/utils/api_client.dart';
import 'package:ayocucinew/core/utils/auth_storage.dart';
import 'package:ayocucinew/data/models/pegawai_model.dart';
import 'package:ayocucinew/providers/pegawai_provider.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/attendance_configuration.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceProvider extends ChangeNotifier {
  AttendanceConfiguration _configuration = AttendanceConfiguration.defaults();
  AttendanceConfiguration get configuration => _configuration;

  bool _isSubmittingAttendance = false;
  Map<String, dynamic>? _lastAttendance;
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _leaveRequests = [];
  List<Map<String, dynamic>> _overtimeRequests = [];
  bool _hasMoreRecords = true;
  bool _hasMoreLeaveRequests = true;
  bool _loadingMoreHistory = false;
  static const int _historyPageSize = 12;
  List<Map<String, dynamic>> _holidays = [];
  String? _attendanceError;
  Position? _currentPosition;
  bool _loadingLocation = false;
  String? _locationError;
  bool _isLoadingConfig = true;
  String? _loadConfigError;
  Map<String, String> _employeeNames = const {};

  bool get isSubmittingAttendance => _isSubmittingAttendance;
  Map<String, dynamic>? get lastAttendance => _lastAttendance;
  String? get attendanceError => _attendanceError;
  List<Map<String, dynamic>> get records => List.unmodifiable(_records);
  List<Map<String, dynamic>> get leaveRequests =>
      List.unmodifiable(_leaveRequests);
  List<Map<String, dynamic>> get overtimeRequests =>
      List.unmodifiable(_overtimeRequests);
  bool get loadingMoreHistory => _loadingMoreHistory;
  bool get hasMoreHistory => _hasMoreRecords || _hasMoreLeaveRequests;
  List<Map<String, dynamic>> get holidays => List.unmodifiable(_holidays);
  Position? get currentPosition => _currentPosition;
  bool get loadingLocation => _loadingLocation;
  String? get locationError => _locationError;
  bool get isLoadingConfig => _isLoadingConfig;
  String? get loadConfigError => _loadConfigError;
  Map<String, String> get employeeNames => _employeeNames;

  /// Membersihkan data outlet sebelumnya sebelum mengambil data outlet baru.
  /// Tanpa reset ini, dashboard masih dapat menghitung records/izin dari outlet
  /// lama selama request outlet baru belum selesai.
  void resetForOutlet() {
    _records = [];
    _leaveRequests = [];
    _overtimeRequests = [];
    _holidays = [];
    _employeeNames = const {};
    _hasMoreRecords = true;
    _hasMoreLeaveRequests = true;
    _attendanceError = null;
    _loadConfigError = null;
    notifyListeners();
  }

  bool _isInCurrentMonth(Map<String, dynamic> record) {
    final date = DateTime.tryParse(record['work_date']?.toString() ?? '');
    final now = DateTime.now();
    return date != null && date.year == now.year && date.month == now.month;
  }

  int get hadirCount => _records.where((record) {
    final status = (record['status']?.toString() ?? 'HADIR').toUpperCase();
    return _isInCurrentMonth(record) &&
        (status == 'HADIR' ||
            status == 'TERLAMBAT' ||
            status == 'LUPA_ABSEN_PULANG');
  }).length;
  int get izinCount {
    final approvedLeaveDates = _leaveRequests.where((request) {
      final status = (request['status']?.toString() ?? '').toUpperCase();
      return _isInCurrentMonth(request) &&
          (status == 'APPROVED' || status == 'DISETUJUI' || status == 'APROVE');
    }).length;
    final recordedLeaveDates = _records.where((record) {
      return _isInCurrentMonth(record) &&
          (record['status']?.toString() ?? '').toUpperCase() == 'IZIN';
    }).length;
    return approvedLeaveDates + recordedLeaveDates;
  }
  int get alfaCount => _records
      .where(
        (record) =>
            _isInCurrentMonth(record) &&
            (record['status']?.toString() ?? '').toUpperCase() == 'ALFA',
      )
      .length;

  bool get hasCheckedIn => todayRecord?['check_in_at'] != null;
  bool get hasCheckedOut => todayRecord?['check_out_at'] != null;
  bool get canRequestOvertime {
    if (overtimeRequests.any((item) {
      final status = item['status']?.toString().toUpperCase();
      return status == 'PENDING' || status == 'APPROVED';
    })) return false;
    final record = todayRecord;
    if (record == null || record['check_in_at'] == null) return false;
    if (record['auto_checkout'] == true) return true;
    final shiftName = record['shift_name']?.toString();
    final shift = _configuration.shifts.where((s) => s.name == shiftName);
    final end = shift.isNotEmpty ? shift.first.endTime : _configuration.endTime;
    final now = DateTime.now();
    final endAt = DateTime(now.year, now.month, now.day, end.hour, end.minute);
    return now.isAfter(endAt);
  }

  bool get hasPendingOvertime => overtimeRequests.any(
    (item) => item['status']?.toString().toUpperCase() == 'PENDING',
  );

  String get actionLabel {
    if (hasActiveLeave) return 'Sedang Izin';
    if (hasCheckedOut) return 'Absensi Selesai';
    if (hasCheckedIn && !isShiftEndReached) return 'Menunggu Jam Pulang';
    if (hasCheckedIn) return 'Absen Pulang';
    return 'Hadir';
  }

  IconData get actionIcon {
    if (hasActiveLeave) return Icons.event_busy_rounded;
    if (hasCheckedOut) return Icons.check_circle_rounded;
    if (hasCheckedIn && !isShiftEndReached) return Icons.lock_clock_rounded;
    if (hasCheckedIn) return Icons.logout_rounded;
    return Icons.login_rounded;
  }

  bool get isShiftEndReached {
    final record = todayRecord;
    if (record == null || record['check_in_at'] == null) return false;
    final shiftName = record['shift_name']?.toString();
    final shift = _configuration.shifts.where((s) => s.name == shiftName);
    final end = shift.isNotEmpty ? shift.first.endTime : _configuration.endTime;
    final now = DateTime.now();
    final endAt = DateTime(now.year, now.month, now.day, end.hour, end.minute);
    return !now.isBefore(endAt);
  }

  bool get isCheckOutAction =>
      hasCheckedIn && !hasCheckedOut && !hasActiveLeave && isShiftEndReached;

  bool get isActionAvailable =>
      !hasActiveLeave && !hasCheckedOut && (!hasCheckedIn || isShiftEndReached);

  /// Label libur untuk [date] jika outlet libur pada hari itu, selain itu null.
  String? holidayLabelFor(DateTime date) {
    final weekday =
        date.weekday % 7; // Dart: Senin=1..Minggu=7 -> 0=Minggu..6=Sabtu
    final ymd =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    String? weekly;
    for (final h in _holidays) {
      if ((h['date']?.toString() ?? '').startsWith(ymd)) {
        return h['label']?.toString();
      }
      if (h['date'] == null && h['weekday'] == weekday) {
        weekly = h['label']?.toString();
      }
    }
    return weekly;
  }

  Map<String, dynamic>? get todayRecord {
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    for (final record in _records) {
      if ((record['work_date']?.toString() ?? '').startsWith(today)) {
        return record;
      }
    }
    return null;
  }

  /// Izin aktif = ada pengajuan izin berstatus disetujui untuk tanggal hari ini.
  /// Diambil dari data server (leaveRequests), bukan cache lokal.
  bool get hasActiveLeave {
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    for (final request in _leaveRequests) {
      if (!(request['work_date']?.toString() ?? '').startsWith(today)) continue;
      final status = (request['status']?.toString() ?? '').toUpperCase();
      if (status == 'APPROVED' || status == 'DISETUJUI' || status == 'APROVE') {
        return true;
      }
    }
    return false;
  }

  /// True bila sudah ada pengajuan izin untuk hari ini yang belum ditolak
  /// (masih PENDING atau sudah disetujui). Dipakai untuk mencegah pengajuan
  /// izin ganda di hari yang sama selagi menunggu keputusan owner.
  bool get hasPendingLeaveToday {
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    for (final request in _leaveRequests) {
      if (!(request['work_date']?.toString() ?? '').startsWith(today)) continue;
      final status = (request['status']?.toString() ?? '').toUpperCase();
      if (status == 'REJECTED' || status == 'DITOLAK' || status == 'TOLAK') {
        continue;
      }
      return true;
    }
    return false;
  }

  Future<void> loadLeaveState() async {
    // Migrasi: hapus cache izin lama yang tidak lagi dipakai.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('attendance_leave_until');
  }

  Future<Map<String, dynamic>> checkIn() =>
      _submitAttendance('/attendance/check-in');
  Future<Map<String, dynamic>> checkOut() =>
      _submitAttendance('/attendance/check-out');

  Future<Map<String, dynamic>> requestLeave({
    required DateTime date,
    required String reason,
    String leaveType = 'IZIN',
    int durationDays = 1,
  }) async {
    final response = await ApiClient.post(
      '/attendance/leave-requests',
      token: AuthStorage.token,
      body: {
        'work_date':
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'leave_type': leaveType,
        'reason': reason,
        'duration_days': durationDays,
      },
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final success =
        response.statusCode >= 200 &&
        response.statusCode < 300 &&
        body['status'] == true;
    if (success) {
      await loadLeaveRequests(paginated: true);
    }
    return {
      'success': success,
      'message': body['message'] ?? 'Pengajuan izin gagal',
    };
  }

  Future<Map<String, dynamic>> requestOvertime({
    required DateTime workDate,
    required DateTime startAt,
    required DateTime endAt,
    required String reason,
  }) async {
    final response = await ApiClient.post(
      '/attendance/overtime-requests',
      token: AuthStorage.token,
      body: {
        'work_date': DateFormat('yyyy-MM-dd').format(workDate),
        'start_at': startAt.toUtc().toIso8601String(),
        'end_at': endAt.toUtc().toIso8601String(),
        'reason': reason,
      },
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final success = response.statusCode >= 200 &&
        response.statusCode < 300 &&
        body['status'] == true;
    if (success) await loadOvertimeRequests();
    return {
      'success': success,
      'message': body['message'] ?? 'Pengajuan lembur gagal',
    };
  }

  Future<List<Map<String, dynamic>>> loadOvertimeRequests({
    String? status,
  }) async {
    final query = status == null ? '' : '?status=$status';
    final response = await ApiClient.get(
      '/attendance/overtime-requests$query',
      token: AuthStorage.token,
    );
    if (response.statusCode != 200) return [];
    final raw = (jsonDecode(response.body) as Map<String, dynamic>)['data'];
    final data = raw is Map ? raw['requests'] : raw;
    if (data is! List) return [];
    final rows = data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (status == 'PENDING' || status == null) {
      _overtimeRequests = rows;
      notifyListeners();
    }
    return rows;
  }

  Future<Map<String, dynamic>> decideOvertime({
    required String id,
    required String status,
    int? approvedMinutes,
  }) async {
    final response = await ApiClient.patch(
      '/attendance/overtime-requests/$id',
      token: AuthStorage.token,
      body: {
        'status': status,
        if (approvedMinutes != null) 'approved_minutes': approvedMinutes,
      },
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final success = response.statusCode >= 200 && response.statusCode < 300;
    if (success) {
      await loadOvertimeRequests(status: 'PENDING');
    }
    return {
      'success': success,
      'message': body['message'] ?? 'Keputusan lembur gagal',
    };
  }

  Future<void> loadRecords({
    DateTime? date,
    DateTime? month,
    bool paginated = false,
    bool append = false,
  }) async {
    final token = AuthStorage.token;
    if (token == null || token.isEmpty) return;
    final query = <String>[];
    if (date != null) {
      query.add('date=${DateFormat('yyyy-MM-dd').format(date)}');
    }
    if (month != null) {
      query.add('month=${DateFormat('yyyy-MM').format(month)}');
    }
    if (paginated) {
      if (month == null) {
        query.add('month=${DateFormat('yyyy-MM').format(DateTime.now())}');
      }
      query.add('limit=$_historyPageSize');
      query.add('offset=${append ? _records.length : 0}');
    }
    final path =
        '/attendance/records${query.isEmpty ? '' : '?${query.join('&')}'}';
    final response = await ApiClient.get(path, token: token);
    if (response.statusCode != 200) return;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rawData = body['data'];
    final data = rawData is Map ? rawData['records'] : rawData;
    if (data is List) {
      final items = data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      _records = append ? [..._records, ...items] : items;
      _hasMoreRecords = paginated && rawData is Map
          ? rawData['has_more'] == true
          : false;
      notifyListeners();
    }
  }

  Future<void> loadLeaveRequests({
    DateTime? month,
    bool paginated = false,
    bool append = false,
  }) async {
    final token = AuthStorage.token;
    if (token == null || token.isEmpty) return;
    final currentMonth = DateFormat('yyyy-MM').format(month ?? DateTime.now());
    final query = paginated
        ? '?month=$currentMonth&limit=$_historyPageSize&offset=${append ? _leaveRequests.length : 0}'
        : month == null
        ? ''
        : '?month=$currentMonth';
    final response = await ApiClient.get(
      '/attendance/leave-requests$query',
      token: token,
    );
    if (response.statusCode != 200) return;
    final rawData = (jsonDecode(response.body) as Map<String, dynamic>)['data'];
    final data = rawData is Map ? rawData['requests'] : rawData;
    if (data is List) {
      final items = data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      _leaveRequests = append ? [..._leaveRequests, ...items] : items;
      _hasMoreLeaveRequests = paginated && rawData is Map
          ? rawData['has_more'] == true
          : false;
      notifyListeners();
    }
  }

  Future<void> loadMoreEmployeeAttendanceHistory() async {
    if (_loadingMoreHistory || !hasMoreHistory) return;
    _loadingMoreHistory = true;
    notifyListeners();
    try {
      await Future.wait([
        if (_hasMoreRecords) loadRecords(paginated: true, append: true),
        if (_hasMoreLeaveRequests)
          loadLeaveRequests(paginated: true, append: true),
      ]);
    } finally {
      _loadingMoreHistory = false;
      notifyListeners();
    }
  }

  Future<void> loadHolidays() async {
    final token = AuthStorage.token;
    if (token == null || token.isEmpty) return;
    final response = await ApiClient.get('/attendance/holidays', token: token);
    if (response.statusCode != 200) return;
    final data = (jsonDecode(response.body) as Map<String, dynamic>)['data'];
    if (data is List) {
      _holidays = data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      notifyListeners();
    }
  }

  /// Nama hari (index 0 = Minggu) untuk UI absensi & hari libur.
  static const List<String> weekdayNames = [
    'Minggu',
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
  ];
  static const List<String> weekdayShort = [
    'Min',
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
  ];

  /// Format tanggal ISO "yyyy-MM-dd" untuk payload API.
  static String isoDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  /// Label tanggal untuk kartu record absensi (mis. "Sen, 04 Sep 2026").
  static String formatAttendanceDate(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    return parsed == null
        ? 'Tanggal absensi'
        : DateFormat('EEE, dd MMM yyyy', 'id_ID').format(parsed);
  }

  /// Jam absensi "HH:mm" dari timestamp server (null → "--:--").
  static String formatAttendanceTime(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null
        ? '--:--'
        : DateFormat('HH:mm').format(parsed.toLocal());
  }

  /// Pecahan label tanggal libur untuk kartu di layar hari libur.
  static ({String text, String day, String month}) holidayDateParts(
    String raw,
  ) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return (text: raw, day: '--', month: '');
    }
    return (
      text: DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(parsed),
      day: DateFormat('dd').format(parsed),
      month: DateFormat('MMM', 'id_ID').format(parsed).toUpperCase(),
    );
  }

  Future<Map<String, dynamic>> addHoliday({
    String? date,
    int? weekday,
    String? label,
  }) async {
    final resolvedLabel = (label != null && label.trim().isNotEmpty)
        ? label.trim()
        : (weekday != null && weekday >= 0 && weekday < weekdayNames.length
              ? 'Libur ${weekdayNames[weekday]}'
              : 'Hari Libur');
    final response = await ApiClient.post(
      '/attendance/holidays',
      token: AuthStorage.token,
      body: {'date': date, 'weekday': weekday, 'label': resolvedLabel},
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final success =
        response.statusCode >= 200 &&
        response.statusCode < 300 &&
        body['status'] == true;
    if (success) await loadHolidays();
    return {
      'success': success,
      'message': body['message'] ?? 'Gagal menambah hari libur',
    };
  }

  Future<Map<String, dynamic>> deleteHoliday(String id) async {
    final response = await ApiClient.delete(
      '/attendance/holidays/$id',
      token: AuthStorage.token,
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final success =
        response.statusCode >= 200 &&
        response.statusCode < 300 &&
        body['status'] == true;
    if (success) await loadHolidays();
    return {
      'success': success,
      'message': body['message'] ?? 'Gagal menghapus hari libur',
    };
  }

  Future<Map<String, dynamic>> _submitAttendance(String endpoint) async {
    _isSubmittingAttendance = true;
    _attendanceError = null;
    notifyListeners();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('GPS belum aktif di perangkat');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Izin lokasi diblokir. Aktifkan dari pengaturan aplikasi',
        );
      }
      if (permission == LocationPermission.denied) {
        throw Exception('Izin lokasi diperlukan untuk melakukan absensi');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final response = await ApiClient.post(
        endpoint,
        token: AuthStorage.token,
        body: {'latitude': position.latitude, 'longitude': position.longitude},
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          body['status'] != true) {
        throw Exception(body['message']?.toString() ?? 'Absensi gagal');
      }
      _lastAttendance = Map<String, dynamic>.from(body['data'] ?? {});
      await loadRecords(paginated: true);
      return {
        'success': true,
        'message': body['message'],
        'data': _lastAttendance,
      };
    } catch (e) {
      _attendanceError = e.toString().replaceFirst('Exception: ', '');
      // Refresh even when the server says the check-in already exists.
      await loadRecords();
      return {'success': false, 'message': _attendanceError};
    } finally {
      _isSubmittingAttendance = false;
      notifyListeners();
    }
  }

  List<AttendanceShift> addShift(
    List<AttendanceShift> shifts,
    String shiftName, {
    bool autoApproveLeave = false,
    TimeOfDay startTime = const TimeOfDay(hour: 6, minute: 0),
    TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0),
  }) {
    if (shifts.any((shift) => shift.name == shiftName)) {
      return shifts;
    }
    return [
      ...shifts,
      AttendanceShift(
        name: shiftName,
        autoApproveLeave: autoApproveLeave,
        startTime: startTime,
        endTime: endTime,
      ),
    ];
  }

  List<AttendanceShift> removeShift(
    List<AttendanceShift> shifts,
    String shiftName,
  ) => shifts.where((shift) => shift.name != shiftName).toList();

  /// Pilihan nama shift standar untuk form pengaturan absensi.
  static const List<String> shiftOptions = ['Shift Pagi', 'Shift Malam'];

  /// True bila [name] sudah dipakai shift lain (selain [except]).
  bool isShiftNameTaken(
    List<AttendanceShift> shifts,
    String name, {
    String? except,
  }) => shifts.any((s) => s.name == name && s.name != except);

  /// Ganti nama shift [oldName] menjadi [newName] beserta jam & auto-approve.
  List<AttendanceShift> renameShift(
    List<AttendanceShift> shifts,
    String oldName,
    String newName, {
    required bool autoApproveLeave,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) => shifts
      .map(
        (shift) => shift.name == oldName
            ? AttendanceShift(
                name: newName,
                autoApproveLeave: autoApproveLeave,
                startTime: startTime,
                endTime: endTime,
                employeeIds: shift.employeeIds,
              )
            : shift,
      )
      .toList();

  /// Ubah status persetujuan izin otomatis untuk shift [shiftName].
  List<AttendanceShift> setShiftAutoApprove(
    List<AttendanceShift> shifts,
    String shiftName,
    bool autoApproveLeave,
  ) => shifts
      .map(
        (shift) => shift.name == shiftName
            ? AttendanceShift(
                name: shift.name,
                autoApproveLeave: autoApproveLeave,
                startTime: shift.startTime,
                endTime: shift.endTime,
                employeeIds: shift.employeeIds,
              )
            : shift,
      )
      .toList();

  Future<Map<String, dynamic>> toggleShiftAutoApprove({
    required String shiftName,
    required bool autoApproveLeave,
  }) async {
    try {
      final updatedShifts = setShiftAutoApprove(
        _configuration.shifts,
        shiftName,
        autoApproveLeave,
      );
      final updated = await save(
        AttendanceConfiguration(
          isConfigured: true,
          startTime: _configuration.startTime,
          endTime: _configuration.endTime,
          autoApproveLeave: _configuration.autoApproveLeave,
          shifts: updatedShifts,
        ),
      );
      return {
        'success': true,
        'message': 'Persetujuan izin otomatis diperbarui',
        'data': updated,
      };
    } catch (error) {
      return {
        'success': false,
        'message': error.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  List<AttendanceShift> assignEmployees(
    List<AttendanceShift> shifts,
    String shiftName,
    List<String> employeeIds,
  ) => shifts
      .map(
        (shift) => AttendanceShift(
          name: shift.name,
          autoApproveLeave: shift.autoApproveLeave,
          startTime: shift.startTime,
          endTime: shift.endTime,
          employeeIds: shift.name == shiftName ? employeeIds : shift.employeeIds,
        ),
      )
      .toList();

  Future<AttendanceConfiguration> load() async {
    final token = AuthStorage.token;
    if (token == null || token.isEmpty) {
      return _configuration;
    }
    final response = await ApiClient.get(
      '/attendance/configuration',
      token: token,
    );
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat konfigurasi absensi');
    }
    final data =
        ((jsonDecode(response.body) as Map<String, dynamic>)['data'] as Map?)
            ?.cast<String, dynamic>() ??
        const {};
    _configuration = AttendanceConfiguration.fromApi(data);
    notifyListeners();
    return _configuration;
  }

  Future<AttendanceConfiguration> save(AttendanceConfiguration value) async {
    final token = AuthStorage.token;
    if (token == null || token.isEmpty) {
      throw Exception('Sesi login tidak tersedia');
    }
    if (value.isConfigured && value.shifts.isEmpty) {
      throw Exception('Minimal satu shift harus dipilih');
    }
    final uniqueShifts = <String, AttendanceShift>{
      for (final shift in value.shifts) shift.name: shift,
    }.values.toList();
    final normalized = uniqueShifts.isEmpty
        ? value
        : AttendanceConfiguration(
            isConfigured: value.isConfigured,
            startTime: _earliestStart(uniqueShifts),
            endTime: _latestEnd(uniqueShifts),
            autoApproveLeave: value.autoApproveLeave,
            lateToleranceMinutes: value.lateToleranceMinutes,
            shifts: uniqueShifts,
          );
    final response = await ApiClient.put(
      '/attendance/configuration',
      token: token,
      body: normalized.toApi(),
    );
    if (response.statusCode != 200) {
      throw Exception('Gagal menyimpan konfigurasi absensi');
    }
    _configuration = normalized;
    notifyListeners();
    return normalized;
  }

  TimeOfDay _earliestStart(List<AttendanceShift> shifts) => shifts
      .map((shift) => shift.startTime)
      .reduce((a, b) => _minutes(a) < _minutes(b) ? a : b);

  TimeOfDay _latestEnd(List<AttendanceShift> shifts) => shifts
      .map((shift) => shift.endTime)
      .reduce((a, b) => _minutes(a) > _minutes(b) ? a : b);

  int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;

  static String formatTimeOfDay(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}.'
      '${time.minute.toString().padLeft(2, '0')}';

  Future<AttendanceConfiguration> deleteShift(String shiftName) async {
    final remainingShifts = removeShift(_configuration.shifts, shiftName);
    final updated = AttendanceConfiguration(
      isConfigured: remainingShifts.isNotEmpty,
      startTime: _configuration.startTime,
      endTime: _configuration.endTime,
      autoApproveLeave: _configuration.autoApproveLeave,
      shifts: remainingShifts,
    );
    return save(updated);
  }

  Future<void> loadEmployeeAttendanceData() async {
    await loadLeaveState();
    await Future.wait([
      loadRecords(paginated: true),
      loadLeaveRequests(paginated: true),
      loadHolidays(),
      loadOvertimeRequests(),
    ]);
  }

  Future<Position?> refreshLocation() async {
    _loadingLocation = true;
    _locationError = null;
    debugPrint('📍 Location: mulai membaca lokasi perangkat');
    notifyListeners();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _locationError = 'Aktifkan GPS/lokasi perangkat Anda.';
        return null;
      }
      var permission = await Geolocator.checkPermission();
      debugPrint('📍 Location: service=true permission=$permission');
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _locationError = 'Izinkan akses lokasi untuk aplikasi ini.';
        return null;
      }
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 0,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (_) {
        debugPrint(
          '📍 Location: current position timeout/error, mencoba lokasi terakhir',
        );
        position = await Geolocator.getLastKnownPosition();
      }
      if (position == null) {
        _locationError =
            'Lokasi belum tersedia. Tunggu beberapa detik lalu coba lagi.';
        return null;
      }
      _currentPosition = position;
      debugPrint(
        '📍 Location: berhasil lat=${position.latitude}, lng=${position.longitude}, accuracy=${position.accuracy}m',
      );
      return position;
    } catch (error) {
      debugPrint('📍 Location: gagal membaca lokasi: $error');
      _locationError = 'Lokasi belum dapat dibaca. Coba aktifkan GPS kembali.';
      return null;
    } finally {
      _loadingLocation = false;
      notifyListeners();
    }
  }

  double? calculateDistance(double? outletLat, double? outletLng) {
    if (outletLat == null || outletLng == null || _currentPosition == null) {
      return null;
    }
    return Geolocator.distanceBetween(
      outletLat,
      outletLng,
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );
  }

  bool isWithinRadius(
    double? outletLat,
    double? outletLng,
    double radiusMeters,
  ) {
    final dist = calculateDistance(outletLat, outletLng);
    return dist != null && dist <= radiusMeters;
  }

  Future<Map<String, dynamic>> submitAttendance({required bool isCheckOut}) {
    if (isSubmittingAttendance) {
      return Future.value({
        'success': false,
        'message': 'Sedang memproses absensi',
      });
    }
    return isCheckOut ? checkOut() : checkIn();
  }

  Future<Map<String, dynamic>> submitLeaveRequest({
    required String leaveType,
    required String duration,
    required String reason,
  }) {
    final durationDays = int.tryParse(duration) ?? 1;
    return requestLeave(
      date: DateTime.now(),
      leaveType: leaveType,
      durationDays: durationDays,
      reason: '$duration: $reason',
    );
  }

  Future<void> loadConfigurationData(PegawaiProvider employeeProvider) async {
    _isLoadingConfig = true;
    _loadConfigError = null;
    notifyListeners();

    try {
      await load();
      try {
        if (employeeProvider.employees.isEmpty) {
          await employeeProvider.fetchEmployees();
        }
        _employeeNames = {
          for (final employee in employeeProvider.employees)
            employee.id: employee.nama,
        };
      } catch (_) {
        // Schedule data remains usable even if employee names cannot load.
      }
    } catch (_) {
      _configuration = AttendanceConfiguration.defaults();
      _loadConfigError =
          'Backend absensi belum tersedia. Hubungi administrator untuk memperbarui server.';
    } finally {
      _isLoadingConfig = false;
      notifyListeners();
    }
  }

  Future<void> loadOwnerDashboard(PegawaiProvider employeeProvider) async {
    _isLoadingConfig = true;
    _loadConfigError = null;
    notifyListeners();
    try {
      if (employeeProvider.employees.isEmpty) {
        await employeeProvider.fetchEmployees();
      }
      await Future.wait([
        load(),
        loadRecords(),
        loadLeaveRequests(),
        loadHolidays(),
        loadOvertimeRequests(status: 'PENDING'),
      ]);
      _employeeNames = {
        for (final e in employeeProvider.employees) e.id: e.nama,
      };
    } catch (_) {
      _loadConfigError =
          'Backend absensi belum tersedia. Hubungi administrator untuk memperbarui server.';
    } finally {
      _isLoadingConfig = false;
      notifyListeners();
    }
  }

  Future<void> loadOwnerAttendanceMonth(DateTime month) async {
    await Future.wait([
      loadRecords(month: month),
      loadLeaveRequests(month: month),
    ]);
  }

  Future<void> loadOwnerAttendanceRange(DateTimeRange range) async {
    _isLoadingConfig = true;
    _loadConfigError = null;
    notifyListeners();
    final startMonth = DateTime(range.start.year, range.start.month);
    final endMonth = DateTime(range.end.year, range.end.month);
    try {
      await load();
      await loadHolidays();
      await loadOwnerAttendanceMonth(startMonth);
      if (startMonth.year != endMonth.year || startMonth.month != endMonth.month) {
        final firstRecords = List<Map<String, dynamic>>.from(_records);
        final firstLeaves = List<Map<String, dynamic>>.from(_leaveRequests);
        await loadOwnerAttendanceMonth(endMonth);
        final recordKeys = <String>{
          for (final record in _records)
            '${record['employee_id']}:${record['work_date']}:${record['id']}',
        };
        _records = [
          ..._records,
          ...firstRecords.where((record) => recordKeys.add(
                '${record['employee_id']}:${record['work_date']}:${record['id']}',
              )),
        ];
        final leaveKeys = <String>{
          for (final leave in _leaveRequests)
            '${leave['employee_id']}:${leave['work_date']}:${leave['id']}',
        };
        _leaveRequests = [
          ..._leaveRequests,
          ...firstLeaves.where((leave) => leaveKeys.add(
                '${leave['employee_id']}:${leave['work_date']}:${leave['id']}',
              )),
        ];
      }
    } catch (error) {
      _loadConfigError = error.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoadingConfig = false;
      notifyListeners();
    }
  }

  bool _isTodayField(dynamic workDate) =>
      (workDate?.toString() ?? '').startsWith(isoDate(DateTime.now()));

  bool _leaveApproved(dynamic status) {
    final st = (status?.toString() ?? '').toUpperCase();
    return st == 'APPROVED' || st == 'DISETUJUI' || st == 'APROVE';
  }

  /// Nama shift yang memuat [employeeId] (kosong bila belum ditugaskan).
  String shiftNameForEmployee(String employeeId) {
    for (final s in _configuration.shifts) {
      if (s.employeeIds.contains(employeeId)) return s.name;
    }
    return '';
  }

  /// Status kehadiran hari ini: BELUM_ABSEN | HADIR | TERLAMBAT | ALFA | IZIN.
  String todayStatusFor(String employeeId) {
    for (final r in _leaveRequests) {
      if (_isTodayField(r['work_date']) &&
          r['employee_id']?.toString() == employeeId &&
          _leaveApproved(r['status'])) {
        return 'IZIN';
      }
    }
    for (final r in _records) {
      if (!_isTodayField(r['work_date'])) continue;
      if (r['employee_id']?.toString() != employeeId) continue;
      final st = (r['status']?.toString() ?? 'HADIR').toUpperCase();
      if (r['check_in_at'] != null) {
        return st == 'TERLAMBAT' ? 'TERLAMBAT' : 'HADIR';
      }
      if (st == 'ALFA') return 'ALFA';
    }

    // Setelah jam selesai shift, pegawai yang tidak memiliki record absen
    // harus dihitung sebagai ALFA (bukan terus-menerus BELUM_ABSEN).
    // Status ini dihitung di client karena ALFA bukan record yang dibuat saat
    // check-in; backend hanya menyimpan record ketika pegawai benar-benar absen.
    final now = DateTime.now();
    if (_configuration.isConfigured && holidayLabelFor(now) == null) {
      final shiftName = shiftNameForEmployee(employeeId);
      if (shiftName.isEmpty) return 'BELUM_ABSEN';
      AttendanceShift? shift;
      for (final item in _configuration.shifts) {
        if (item.name == shiftName) {
          shift = item;
          break;
        }
      }
      final end = shift?.endTime ?? _configuration.endTime;
      final endAt = DateTime(
        now.year,
        now.month,
        now.day,
        end.hour,
        end.minute,
      );
      if (now.isAfter(endAt)) return 'ALFA';
    }
    return 'BELUM_ABSEN';
  }

  Map<String, dynamic>? todayRecordFor(String employeeId) {
    Map<String, dynamic>? fallback;
    for (final r in _records) {
      if (_isTodayField(r['work_date']) &&
          r['employee_id']?.toString() == employeeId) {
        fallback ??= r;
        if (r['check_in_at'] != null) return r;
      }
    }
    return fallback;
  }

  /// Daftar karyawan aktif + status absensi hari ini untuk kartu
  /// "Kehadiran Hari Ini". Diurutkan: masalah dulu (alfa, belum absen).
  List<Map<String, dynamic>> ownerTodayRoster(
    PegawaiProvider employeeProvider,
  ) {
    const rank = {
      'ALFA': 0,
      'BELUM_ABSEN': 1,
      'TERLAMBAT': 2,
      'IZIN': 3,
      'HADIR': 4,
    };
    final rows = employeeProvider.employees
        .where(PegawaiProvider.isActiveEmployee)
        .map(
          (e) => {
            'id': e.id,
            'name': e.nama,
            'shift_name': shiftNameForEmployee(e.id),
            'status': todayStatusFor(e.id),
            'record': todayRecordFor(e.id),
            'overtime': _overtimeRequests.firstWhere(
              (o) => o['employee_id']?.toString() == e.id,
              orElse: () => <String, dynamic>{},
            ),
          },
        )
        .toList();
    rows.sort((a, b) {
      final byRank = (rank[a['status']] ?? 9).compareTo(rank[b['status']] ?? 9);
      return byRank != 0
          ? byRank
          : (a['name'] as String).toLowerCase().compareTo(
              (b['name'] as String).toLowerCase(),
            );
    });
    return rows;
  }

  List<Map<String, dynamic>> ownerRosterForMonth(
    PegawaiProvider employeeProvider,
    DateTime month,
    {DateTimeRange? range}
  ) {
    bool inSelectedPeriod(dynamic value) {
      final date = DateTime.tryParse(value?.toString() ?? '');
      if (date == null) return false;
      final day = DateTime(date.year, date.month, date.day);
      if (range != null) {
        final start = DateTime(range.start.year, range.start.month, range.start.day);
        final end = DateTime(range.end.year, range.end.month, range.end.day);
        return !day.isBefore(start) && !day.isAfter(end);
      }
      return date.year == month.year && date.month == month.month;
    }

    final rows = employeeProvider.employees
        .where(PegawaiProvider.isActiveEmployee)
        .map((employee) {
          final records = _records.where((record) {
            return record['employee_id']?.toString() == employee.id &&
                inSelectedPeriod(record['work_date']);
          }).toList();
          final leaves = _leaveRequests.where((leave) {
            return leave['employee_id']?.toString() == employee.id &&
                inSelectedPeriod(leave['work_date']) &&
                _leaveApproved(leave['status']);
          }).toList();
          // Dalam rekap bulanan satu karyawan dapat memiliki beberapa record
          // (HADIR dan ALFA). Pilih record kehadiran aktual terlebih dahulu,
          // bukan record ALFA yang kebetulan berada di posisi pertama.
          records.sort((a, b) {
            int priority(Map<String, dynamic> record) {
              final status = (record['status']?.toString() ?? 'HADIR').toUpperCase();
              if (record['check_in_at'] != null && status == 'TERLAMBAT') return 0;
              if (record['check_in_at'] != null) return 1;
              if (status == 'IZIN') return 2;
              if (status == 'ALFA') return 3;
              return 4;
            }
            final byStatus = priority(a).compareTo(priority(b));
            if (byStatus != 0) return byStatus;
            return (b['work_date']?.toString() ?? '').compareTo(
              a['work_date']?.toString() ?? '',
            );
          });
          records.removeWhere((item) {
            final status = (item['status']?.toString() ?? '').toUpperCase();
            final date = DateTime.tryParse(item['work_date']?.toString() ?? '');
            return status == 'ALFA' && date != null && holidayLabelFor(date) != null;
          });
          final record = records.isEmpty ? null : records.first;
          String status = 'BELUM_ABSEN';
          if (record != null) {
            status = (record['status']?.toString() ?? 'HADIR').toUpperCase();
          } else if (leaves.isNotEmpty) {
            status = 'IZIN';
          }
          return <String, dynamic>{
            'id': employee.id,
            'name': employee.nama,
            'shift_name': shiftNameForEmployee(employee.id),
            'status': status,
            'record': record,
            'has_leave': leaves.isNotEmpty,
            'has_alfa': records.any(
              (item) => (item['status']?.toString() ?? '').toUpperCase() == 'ALFA',
            ),
          };
        })
        .toList();
    const rank = {
      'ALFA': 0,
      'BELUM_ABSEN': 1,
      'TERLAMBAT': 2,
      'IZIN': 3,
      'HADIR': 4,
    };
    rows.sort((a, b) {
      final byRank = (rank[a['status']] ?? 9).compareTo(rank[b['status']] ?? 9);
      return byRank != 0
          ? byRank
          : (a['name'] as String).compareTo(b['name'] as String);
    });
    return rows;
  }

  int ownerCountByStatus(PegawaiProvider ep, String status) =>
      ownerTodayRoster(ep).where((r) => r['status'] == status).length;

  /// Jumlah pengajuan izin yang masih menunggu keputusan owner.
  int get pendingLeaveCount => _leaveRequests.where((r) {
    final st = (r['status']?.toString() ?? '').toUpperCase();
    return st == 'PENDING' || st == 'MENUNGGU' || st.isEmpty;
  }).length;

  /// Semua pengajuan izin, terbaru dulu.
  List<Map<String, dynamic>> get leaveRequestsSorted {
    final list = List<Map<String, dynamic>>.from(_leaveRequests);
    list.sort(
      (a, b) =>
          (b['created_at']?.toString() ?? b['work_date']?.toString() ?? '')
              .compareTo(
                a['created_at']?.toString() ?? a['work_date']?.toString() ?? '',
              ),
    );
    return list;
  }

  List<Map<String, dynamic>> recordsForEmployee(String employeeId) {
    final list = _records
        .where((r) => r['employee_id']?.toString() == employeeId)
        .toList();
    list.sort(
      (a, b) => (b['work_date']?.toString() ?? '').compareTo(
        a['work_date']?.toString() ?? '',
      ),
    );
    return list;
  }

  List<Map<String, dynamic>> leavesForEmployee(String employeeId) =>
      _leaveRequests
          .where((r) => r['employee_id']?.toString() == employeeId)
          .toList();

  /// Rekap Hadir / Izin / Alfa sepanjang data yang termuat untuk 1 karyawan.
  ({int hadir, int izin, int alfa}) attendanceSummaryFor(
    String employeeId, {
    int? year,
    int? month,
    DateTime? from,
    DateTime? to,
  }) {
    var hadir = 0;
    var alfa = 0;
    for (final r in recordsForEmployee(employeeId)) {
      final date = DateTime.tryParse(r['work_date']?.toString() ?? '');
      if (date == null ||
          (from != null &&
              date.isBefore(DateTime(from.year, from.month, from.day))) ||
          (to != null && date.isAfter(DateTime(to.year, to.month, to.day))) ||
          (year != null && date.year != year) ||
          (month != null && date.month != month)) {
        continue;
      }
      final st = (r['status']?.toString() ?? 'HADIR').toUpperCase();
      if (st == 'ALFA') {
        alfa++;
      } else if (r['check_in_at'] != null) {
        hadir++;
      }
    }
    final izin = _leaveRequests
        .where(
          (r) =>
              r['employee_id']?.toString() == employeeId &&
              _leaveApproved(r['status']) &&
              (from == null ||
                  (DateTime.tryParse(r['work_date']?.toString() ?? '')?.isAfter(
                        DateTime(
                          from.year,
                          from.month,
                          from.day,
                        ).subtract(const Duration(days: 1)),
                      ) ??
                      false)) &&
              (to == null ||
                  (DateTime.tryParse(
                        r['work_date']?.toString() ?? '',
                      )?.isBefore(
                        DateTime(
                          to.year,
                          to.month,
                          to.day,
                        ).add(const Duration(days: 1)),
                      ) ??
                      false)) &&
              (year == null ||
                  DateTime.tryParse(r['work_date']?.toString() ?? '')?.year ==
                      year) &&
              (month == null ||
                  DateTime.tryParse(r['work_date']?.toString() ?? '')?.month ==
                      month),
        )
        .length;
    return (hadir: hadir, izin: izin, alfa: alfa);
  }

  /// Setujui / tolak / batalkan pengajuan izin.
  /// [status]: APPROVED | REJECTED | PENDING.
  Future<Map<String, dynamic>> setLeaveStatus(
    String id,
    String status, {
    String? reason,
  }) async {
    final response = await ApiClient.patch(
      '/attendance/leave-requests/$id',
      token: AuthStorage.token,
      body: {
        'status': status,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final success =
        response.statusCode >= 200 &&
        response.statusCode < 300 &&
        body['status'] == true;
    if (success) await loadLeaveRequests();
    return {
      'success': success,
      'message':
          body['message'] ??
          'Gagal memperbarui pengajuan izin (server belum siap)',
    };
  }

  List<Pegawai> getAvailableEmployeesForShift(
    String shiftName,
    List<Pegawai> allEmployees,
  ) {
    return allEmployees
        .where((employee) => employee.status == 1)
        .toList();
  }

  Set<String> getAssignedEmployeeIdsForShift(String shiftName) {
    try {
      final shift = _configuration.shifts.firstWhere(
        (item) => item.name == shiftName,
      );
      return shift.employeeIds.toSet();
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>> assignEmployeesToShift({
    required String shiftName,
    required List<String> employeeIds,
    required PegawaiProvider employeeProvider,
  }) async {
    try {
      final updatedShifts = assignEmployees(
        _configuration.shifts,
        shiftName,
        employeeIds,
      );
      final updated = await save(
        AttendanceConfiguration(
          isConfigured: true,
          startTime: _configuration.startTime,
          endTime: _configuration.endTime,
          autoApproveLeave: _configuration.autoApproveLeave,
          shifts: updatedShifts,
        ),
      );
      _employeeNames = {
        for (final employee in employeeProvider.employees)
          employee.id: employee.nama,
      };
      notifyListeners();
      return {
        'success': true,
        'message': 'Karyawan berhasil diatur',
        'data': updated,
      };
    } catch (error) {
      return {
        'success': false,
        'message': error.toString().replaceFirst('Exception: ', ''),
      };
    }
  }

  Future<Map<String, dynamic>> deleteShiftAndSave(String shiftName) async {
    try {
      final updated = await deleteShift(shiftName);
      return {
        'success': true,
        'message': 'Shift $shiftName berhasil dihapus',
        'data': updated,
      };
    } catch (_) {
      return {'success': false, 'message': 'Gagal menghapus shift $shiftName'};
    }
  }
}
