import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:ayocucinew/data/models/finance_model.dart';
import 'package:ayocucinew/core/utils/api_client.dart' show ApiClient;
import 'package:ayocucinew/core/utils/user_friendly_error.dart';
import 'package:ayocucinew/core/constants/api_endpoints.dart';
import 'dart:async';
import 'package:ayocucinew/core/events/app_events.dart';
import 'package:ayocucinew/data/models/income_detail_model.dart';

/// Agregat server-side untuk laporan detail berpaginasi (omset/pengeluaran/
/// pendapatan). Berisi total baris & total nominal atas SELURUH data terfilter,
/// sehingga kartu ringkasan tidak perlu menunggu semua halaman dimuat.
class ReportDetailHeader {
  final int totalTransaksi;
  final double totalNominal;

  const ReportDetailHeader({this.totalTransaksi = 0, this.totalNominal = 0});

  factory ReportDetailHeader.fromJson(Map<String, dynamic> json) {
    return ReportDetailHeader(
      totalTransaksi: (json['total_transaksi'] as num?)?.toInt() ?? 0,
      totalNominal: (json['total_nominal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class LaporanProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _isFetching = false;
  String? _errorMessage;

  // --- Real-time WebSocket Event Subscription & Cache ---
  StreamSubscription? _eventSubscription;
  String? _lastToken;

  // Last Income Report query parameters
  String? _lastIncomeStartDate;
  String? _lastIncomeEndDate;
  String? _lastIncomeMetodePembayaran;

  // Last Income Detail query parameters
  String? _lastDetailStartDate;
  String? _lastDetailEndDate;
  String? _lastDetailMetodeNama;

  // Last All Transactions query parameters
  String? _lastAllTransactionsStartDate;
  String? _lastAllTransactionsEndDate;
  String? _lastAllTransactionsStatusOrder;
  String? _lastAllTransactionsStatusPembayaran;
  String? _lastAllTransactionsSearch;
  String? _lastAllTransactionsCustomerId;
  int _currentAllTransactionsPage = 1;

  // Last Customer Report query parameters
  String? _lastCustomerGrowthStartDate;
  String? _lastCustomerGrowthEndDate;
  String? _lastCustomerGrowthJenisKelamin;
  String? _lastCustomerDetailStartDate;
  String? _lastCustomerDetailEndDate;

  LaporanProvider() {
    _listenToEvents();
  }

  void _listenToEvents() {
    _eventSubscription = appEventBus.stream.listen((event) {
      if (event is OrderStatusChanged ||
          event is CustomerDataChanged ||
          event is ExpenseChanged ||
          event is DepositChanged ||
          event is OutletSwitched ||
          event is AddonActivated ||
          event is OutletActivated ||
          (event is AddonPaymentStatusChanged &&
              event.status.toUpperCase() == 'SUCCESS')) {
        debugPrint(
          "📡 Real-time Laporan: Event ${event.runtimeType} dideteksi. Menyegarkan laporan...",
        );
        _refreshActiveReports();
      }
    });
  }

  void _refreshActiveReports() {
    final token = _lastToken;
    if (token == null) return;

    // 1. Refresh Income Report if was active
    if (_lastIncomeStartDate != null && _lastIncomeEndDate != null) {
      fetchIncomeReport(
        token,
        startDate: _lastIncomeStartDate!,
        endDate: _lastIncomeEndDate!,
        metodePembayaran: _lastIncomeMetodePembayaran,
        notify: false, // Background refresh, don't flash loading spinner
        forceRefresh: true,
      );
    }

    // 2. Refresh Income Detail if was active
    if (_lastDetailStartDate != null &&
        _lastDetailEndDate != null &&
        _lastDetailMetodeNama != null) {
      fetchIncomeDetail(
        token,
        startDate: _lastDetailStartDate!,
        endDate: _lastDetailEndDate!,
        metodeNama: _lastDetailMetodeNama!,
        page: 1, // Refresh back to the first page to get freshest data
        forceRefresh: true,
      );
    }

    // 3. Refresh All Transactions if it was the active screen
    if (_lastAllTransactionsStartDate != null &&
        _lastAllTransactionsEndDate != null) {
      fetchAllTransactions(
        token,
        startDate: _lastAllTransactionsStartDate!,
        endDate: _lastAllTransactionsEndDate!,
        statusOrder: _lastAllTransactionsStatusOrder,
        statusPembayaran: _lastAllTransactionsStatusPembayaran,
        customerId: _lastAllTransactionsCustomerId,
        search: _lastAllTransactionsSearch,
        page: 1,
        forceRefresh: true,
      );
    }

    // 4. Refresh Customer Growth / Add-on dependent report if it was active
    if (_lastCustomerGrowthStartDate != null &&
        _lastCustomerGrowthEndDate != null) {
      fetchCustomerGrowthReport(
        token,
        startDate: _lastCustomerGrowthStartDate!,
        endDate: _lastCustomerGrowthEndDate!,
        jenisKelamin: _lastCustomerGrowthJenisKelamin,
        notifyLoading: false,
      );
    }

    // 5. Refresh kedua cache tab detail pelanggan di background. Perpindahan
    // tab tetap lokal dan tidak menunggu request baru.
    if (_lastCustomerDetailStartDate != null &&
        _lastCustomerDetailEndDate != null) {
      fetchCustomerDetailReport(
        token,
        startDate: _lastCustomerDetailStartDate,
        endDate: _lastCustomerDetailEndDate,
        notifyLoading: false,
      );
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  FinanceSummary? _summary;
  List<FinanceChartData> _chartData = [];

  List<OmsetReport> _omsetReport = [];
  Map<String, dynamic> _omsetHeader = {};
  bool _hasMoreOmsetReport = true;
  int _omsetReportPage = 1;
  String? _lastOmsetStart, _lastOmsetEnd, _lastOmsetStatus;
  List<OmsetDetail> _omsetDetail = [];
  ReportDetailHeader? _omsetDetailHeader;
  String? _lastOmsetDetailDate;
  String? _lastOmsetDetailStatus;
  int _currentOmsetDetailPage = 1;

  List<OmsetDetail> _allTransactions = [];
  TransactionHeader? _allTransactionsHeader;

  List<ExpenseAnalisa> _expenseAnalisa = [];
  bool _hasMoreExpenseReport = true;
  int _expenseReportPage = 1;
  String? _lastExpenseStart, _lastExpenseEnd;
  ExpenseSummary? _expenseSummary;
  List<ExpenseByCategory> _expenseByCategory = [];
  List<ExpenseDetail> _expenseDetail = [];
  ReportDetailHeader? _expenseDetailHeader;

  double _totalIncome = 0;
  int _incomeTotalDays = 0;
  List<IncomeReport> _incomeReport = [];
  List<IncomeReport> _allIncomeReport = [];
  bool _hasMoreIncomeReport = true;
  int _incomeReportPage = 1;
  List<PaymentMethod> _incomeMethods = [];
  List<IncomeDetailTransaction> _incomeDetailList = [];
  ReportDetailHeader? _incomeDetailHeader;
  bool _hasMoreIncomeDetail = true;

  List<PiutangReport> _piutangReport = [];
  PiutangSummary? _piutangSummary;
  bool _hasMorePiutang = true;
  int _currentPiutangPage = 1;
  String? _lastPiutangToken;
  String? _lastPiutangStartDate;
  String? _lastPiutangEndDate;
  String? _lastPiutangSearch;
  String? _lastPiutangStatus;

  ProfitLossReport? _profitLossReport;
  ProfitLossReport? _profitLossReportLastMonth;
  List<ProfitLossDetailMetode> _profitLossDetailMetode = [];
  List<ProfitLossDetailPengeluaran> _profitLossDetailPengeluaran = [];

  List<TransaksiLayananItem> _transaksiPerLayanan = [];
  TransaksiPerLayananHeader? _transaksiPerLayananHeader;
  bool _hasMoreTransaksiPerLayanan = true;
  int _transaksiPerLayananPage = 1;
  String? _lastServiceToken, _lastServiceStart, _lastServiceEnd;

  CustomerGrowthSummary? _customerGrowthSummary;
  TopCustomerPodiumData? _topCustomerData;
  bool _isLoadingMoreTopCustomer = false;
  TopCustomerPodiumData? _customerDetailActiveData;
  TopCustomerPodiumData? _customerDetailInactiveData;
  String? _customerDetailCacheKey;
  bool _isLoadingMoreCustomer = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;
  bool get isLoadingMoreCustomer => _isLoadingMoreCustomer;

  bool _hasMoreOmset = true;
  bool get hasMoreOmset => _hasMoreOmset;

  bool _hasMoreExpense = true;
  bool get hasMoreExpense => _hasMoreExpense;

  bool _hasMoreTransactions = true;
  bool get hasMoreTransactions => _hasMoreTransactions;

  List<IncomeDetailTransaction> get incomeDetailList => _incomeDetailList;
  ReportDetailHeader? get incomeDetailHeader => _incomeDetailHeader;
  bool get hasMoreIncomeDetail => _hasMoreIncomeDetail;
  bool get hasMorePiutang => _hasMorePiutang;
  bool get hasMoreIncomeReport => _hasMoreIncomeReport;
  bool get hasMoreOmsetReport => _hasMoreOmsetReport;
  bool get hasMoreExpenseReport => _hasMoreExpenseReport;

  void _setLoadingMore(bool val) {
    _isLoadingMore = val;
    notifyListeners();
  }

  FinanceSummary? get summary => _summary;
  List<FinanceChartData> get chartData => _chartData;

  List<OmsetReport> get omsetReport => _omsetReport;
  Map<String, dynamic> get omsetHeader => _omsetHeader;
  List<OmsetDetail> get omsetDetail => _omsetDetail;
  ReportDetailHeader? get omsetDetailHeader => _omsetDetailHeader;

  List<OmsetDetail> get allTransactions => _allTransactions;
  TransactionHeader? get allTransactionsHeader => _allTransactionsHeader;

  List<ExpenseAnalisa> get expenseAnalisa => _expenseAnalisa;
  ExpenseSummary? get expenseSummary => _expenseSummary;
  List<ExpenseByCategory> get expenseByCategory => _expenseByCategory;
  List<ExpenseDetail> get expenseDetail => _expenseDetail;
  ReportDetailHeader? get expenseDetailHeader => _expenseDetailHeader;

  double get totalIncome => _totalIncome;
  List<IncomeReport> get incomeReport => _incomeReport;
  int get incomeTotalDays => _incomeTotalDays;
  List<IncomeReport> get allIncomeReport => _allIncomeReport;
  List<PaymentMethod> get incomeMethods => _incomeMethods;

  List<PiutangReport> get piutangReport => _piutangReport;
  PiutangSummary? get piutangSummary => _piutangSummary;

  ProfitLossReport? get profitLossReport => _profitLossReport;
  ProfitLossReport? get profitLossReportLastMonth => _profitLossReportLastMonth;
  List<ProfitLossDetailMetode> get profitLossDetailMetode =>
      _profitLossDetailMetode;
  List<ProfitLossDetailPengeluaran> get profitLossDetailPengeluaran =>
      _profitLossDetailPengeluaran;

  List<TransaksiLayananItem> get transaksiPerLayanan => _transaksiPerLayanan;
  TransaksiPerLayananHeader? get transaksiPerLayananHeader =>
      _transaksiPerLayananHeader;
  bool get hasMoreTransaksiPerLayanan => _hasMoreTransaksiPerLayanan;

  CustomerGrowthSummary? get customerGrowthSummary => _customerGrowthSummary;
  TopCustomerPodiumData? get topCustomerData => _topCustomerData;
  bool get isLoadingMoreTopCustomer => _isLoadingMoreTopCustomer;
  bool get hasMoreTopCustomer => _topCustomerData?.hasMore ?? false;

  int get customerTotalPelanggan =>
      _customerGrowthSummary?.totalTransactingCustomers ?? 0;
  int get customerTotalPria => _customerGrowthSummary?.transactingPria ?? 0;
  int get customerTotalWanita => _customerGrowthSummary?.transactingWanita ?? 0;
  int get customerGrowthNewTotal => _customerGrowthSummary?.totalPelanggan ?? 0;
  int get customerTransactionOrder => _customerGrowthSummary?.totalOrder ?? 0;
  double get customerTransactionNominal =>
      _customerGrowthSummary?.totalNominal ?? 0;
  List<CustomerGrowthTableRow> get customerGrowthTableRows =>
      _customerGrowthSummary?.detailTable ?? [];
  List<CustomerChartData> get customerChartData =>
      _customerGrowthSummary?.chartData ?? [];
  List<TopCustomerItem> get customerPodium => _topCustomerData?.podium ?? [];
  List<TopCustomerItem> get customerOthers => _topCustomerData?.others ?? [];
  TopCustomerPodiumData? customerDetailData(String activityStatus) =>
      activityStatus == 'inactive'
      ? _customerDetailInactiveData
      : _customerDetailActiveData;

  double get percentLabaRugi {
    final current = _profitLossReport;
    final lastMonth = _profitLossReportLastMonth;

    if (current == null || lastMonth == null) return 0.0;
    if (lastMonth.labaRugi == 0) return 0.0;

    final percent =
        ((current.labaRugi - lastMonth.labaRugi) / lastMonth.labaRugi.abs()) *
        100;
    return percent.clamp(-100.0, 100.0);
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message == null ? null : userFriendlyError(message);
    notifyListeners();
  }

  dynamic _parseResponse(dynamic response) {
    dev.log("🟢 API RESPONSE [${response.statusCode}]: ${response.body}");

    final body = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(
        body['message'] ?? 'Kesalahan server (${response.statusCode})',
      );
    }

    return body['data'];
  }

  String _buildUrl(String base, Map<String, String?> params) {
    params.removeWhere((_, value) => value == null || value.isEmpty);

    if (params.isEmpty) return base;

    return Uri.parse(base).replace(queryParameters: params).toString();
  }

  String? _mapStatusPembayaran(String? uiStatus) {
    if (uiStatus == null) return null;

    switch (uiStatus) {
      case 'lunas':
      case 'Lunas':
        return 'Lunas';
      case 'belum_lunas':
      case 'Belum Lunas':
        return 'Belum Lunas';
      default:
        return uiStatus;
    }
  }

  Future<void> fetchTransaksiPerLayanan(
    String token, {
    required String startDate,
    required String endDate,
    int page = 1,
  }) async {
    if (page == 1) {
      _setLoading(true);
      _transaksiPerLayanan = [];
      _transaksiPerLayananHeader = null;
      _hasMoreTransaksiPerLayanan = true;
      _lastServiceToken = token;
      _lastServiceStart = startDate;
      _lastServiceEnd = endDate;
    } else {
      _setLoadingMore(true);
    }
    _setError(null);

    try {
      final url = _buildUrl(ApiEndpoints.reportTransaksiPerLayanan, {
        'start_date': startDate,
        'end_date': endDate,
        'page': '$page',
        'limit': '20',
      });

      final response = await ApiClient.getWithCache(url, token: token);
      final data = _parseResponse(response);

      if (data is Map<String, dynamic>) {
        final List list = data['list'] ?? data['data'] ?? [];

        final mapped = list
            .map(
              (e) =>
                  TransaksiLayananItem.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList();
        if (page == 1) {
          _transaksiPerLayanan = mapped;
        } else {
          _transaksiPerLayanan.addAll(mapped);
        }
        _transaksiPerLayananPage = page;
        _hasMoreTransaksiPerLayanan = data['has_more'] == true;

        if (data['header'] != null) {
          _transaksiPerLayananHeader = TransaksiPerLayananHeader.fromJson(
            Map<String, dynamic>.from(data['header']),
          );
        }
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      if (page == 1) _setLoading(false);
      _setLoadingMore(false);
    }
  }

  Future<void> loadMoreTransaksiPerLayanan() async {
    if (_isLoading || _isLoadingMore || !_hasMoreTransaksiPerLayanan) return;
    final token = _lastServiceToken;
    final start = _lastServiceStart;
    final end = _lastServiceEnd;
    if (token == null || start == null || end == null) return;
    await fetchTransaksiPerLayanan(
      token,
      startDate: start,
      endDate: end,
      page: _transaksiPerLayananPage + 1,
    );
  }

  Future<void> fetchAllTransactions(
    String token, {
    String? startDate,
    String? endDate,
    String? statusOrder,
    String? statusPembayaran,
    String? search,
    String? customerId,
    int page = 1,
    bool forceRefresh = false,
  }) async {
    _lastToken = token;
    if (page == 1) {
      _lastAllTransactionsStartDate = startDate;
      _lastAllTransactionsEndDate = endDate;
      _lastAllTransactionsStatusOrder = statusOrder;
      _lastAllTransactionsStatusPembayaran = statusPembayaran;
      _lastAllTransactionsSearch = search;
      _lastAllTransactionsCustomerId = customerId;
    }
    if (page == 1) {
      _setLoading(true);
      _allTransactions = [];
      _allTransactionsHeader = null;
      _hasMoreTransactions = true;
    } else {
      if (!_hasMoreTransactions) return;
      _setLoadingMore(true);
    }
    _setError(null);

    try {
      final url = _buildUrl(ApiEndpoints.reportTransactions, {
        'start_date': startDate,
        'end_date': endDate,
        'status_order': statusOrder,
        'status_pembayaran': _mapStatusPembayaran(statusPembayaran),
        if (search != null && search.isNotEmpty) 'search': search,
        if (customerId != null && customerId.isNotEmpty)
          'customer_id': customerId,
        'page': page.toString(),
        'limit': '20',
      });

      final response = forceRefresh
          ? await ApiClient.get(url, token: token)
          : await ApiClient.getWithCache(url, token: token);
      final data = _parseResponse(response);

      if (data is Map<String, dynamic>) {
        if (page == 1 && data['header'] != null) {
          _allTransactionsHeader = TransactionHeader.fromJson(
            Map<String, dynamic>.from(data['header']),
          );
        }

        final List list = data['data'] ?? data['list'] ?? [];
        if (list.length < 20) {
          _hasMoreTransactions = false;
        }

        final mapped = list
            .map((e) => OmsetDetail.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        if (page == 1) {
          _allTransactions = mapped;
        } else {
          _allTransactions.addAll(mapped);
        }
        _currentAllTransactionsPage = page;
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
      _setLoadingMore(false);
    }
  }

  /// Muat halaman berikutnya untuk daftar "Semua Data Transaksi".
  /// Memakai filter terakhir yang tersimpan agar konsisten dengan page 1.
  Future<void> loadMoreAllTransactions() async {
    if (_isLoadingMore || _isLoading || !_hasMoreTransactions) return;
    final token = _lastToken;
    if (token == null || token.isEmpty) return;
    if (_lastAllTransactionsStartDate == null ||
        _lastAllTransactionsEndDate == null) {
      return;
    }

    await fetchAllTransactions(
      token,
      startDate: _lastAllTransactionsStartDate,
      endDate: _lastAllTransactionsEndDate,
      statusOrder: _lastAllTransactionsStatusOrder,
      statusPembayaran: _lastAllTransactionsStatusPembayaran,
      search: _lastAllTransactionsSearch,
      customerId: _lastAllTransactionsCustomerId,
      page: _currentAllTransactionsPage + 1,
    );
  }

  Future<void> fetchDashboardSummary(
    String token, {
    String? startDate,
    String? endDate,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final url = _buildUrl(ApiEndpoints.financeDashboardSummary, {
        'start_date': startDate,
        'end_date': endDate,
      });

      final response = await ApiClient.getWithCache(url, token: token);
      _summary = FinanceSummary.fromJson(_parseResponse(response));
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchDashboardChart(String token) async {
    _setLoading(true);
    _setError(null);

    try {
      final response = await ApiClient.getWithCache(
        ApiEndpoints.financeDashboardChart,
        token: token,
      );
      final List data = _parseResponse(response) ?? [];
      _chartData = data.map((e) => FinanceChartData.fromJson(e)).toList();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchOmsetReport(
    String token, {
    required String startDate,
    required String endDate,
    String? statusPembayaran,
    int page = 1,
  }) async {
    if (page == 1) {
      _setLoading(true);
      _omsetReport = [];
      _lastOmsetStart = startDate;
      _lastOmsetEnd = endDate;
      _lastOmsetStatus = statusPembayaran;
      _hasMoreOmsetReport = true;
    } else {
      _setLoadingMore(true);
    }
    _setError(null);

    try {
      final url = _buildUrl(ApiEndpoints.reportOmset, {
        'start_date': startDate,
        'end_date': endDate,
        'status_pembayaran': _mapStatusPembayaran(statusPembayaran),
        'page': '$page',
        'limit': '20',
      });

      final response = await ApiClient.getWithCache(url, token: token);
      final data = _parseResponse(response) as Map<String, dynamic>;

      if (page == 1) _omsetHeader = data['header'] ?? {};

      final List list = data['list'] ?? [];
      final mapped = list.map((e) => OmsetReport.fromJson(e)).toList();
      if (page == 1) {
        _omsetReport = mapped;
      } else {
        _omsetReport.addAll(mapped);
      }
      _omsetReportPage = page;
      _hasMoreOmsetReport = data['has_more'] == true;
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
      _setLoadingMore(false);
    }
  }

  Future<void> loadMoreOmsetReport(String token) async {
    if (_isLoading || _isLoadingMore || !_hasMoreOmsetReport) return;
    final start = _lastOmsetStart, end = _lastOmsetEnd;
    if (start == null || end == null) return;
    await fetchOmsetReport(
      token,
      startDate: start,
      endDate: end,
      statusPembayaran: _lastOmsetStatus,
      page: _omsetReportPage + 1,
    );
  }

  Future<void> fetchOmsetDetail(
    String token, {
    required String date,
    String? statusPembayaran,
    int page = 1,
  }) async {
    _lastToken = token;
    if (page == 1) {
      _lastOmsetDetailDate = date;
      _lastOmsetDetailStatus = statusPembayaran;
      _setLoading(true);
      _omsetDetail = [];
      _omsetDetailHeader = null;
      _hasMoreOmset = true;
    } else {
      if (!_hasMoreOmset) return;
      _setLoadingMore(true);
    }
    _setError(null);

    try {
      final dateOnly = date.split('T').first;

      final url = _buildUrl(ApiEndpoints.reportOmsetDetail, {
        'date': dateOnly,
        'status_pembayaran': _mapStatusPembayaran(statusPembayaran),
        'page': page.toString(),
        'limit': '20',
      });

      final response = await ApiClient.getWithCache(url, token: token);
      final dynamic data = _parseResponse(response);
      List list = [];
      if (data is List) {
        list = data;
      } else if (data is Map<String, dynamic>) {
        list = data['data'] ?? [];
        if (list.length < 20) {
          _hasMoreOmset = false;
        }
        if (page == 1 && data['header'] != null) {
          _omsetDetailHeader = ReportDetailHeader.fromJson(
            Map<String, dynamic>.from(data['header']),
          );
        }
      }

      final mapped = list.map((e) => OmsetDetail.fromJson(e)).toList();
      if (page == 1) {
        _omsetDetail = mapped;
      } else {
        _omsetDetail.addAll(mapped);
      }
      _currentOmsetDetailPage = page;
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
      _setLoadingMore(false);
    }
  }

  /// Muat halaman berikutnya untuk "Detail Omset" (rincian transaksi per hari).
  /// Memakai parameter terakhir agar konsisten dengan page 1.
  Future<void> loadMoreOmsetDetail() async {
    if (_isLoadingMore || _isLoading || !_hasMoreOmset) return;
    final token = _lastToken;
    final date = _lastOmsetDetailDate;
    if (token == null || token.isEmpty || date == null) return;

    await fetchOmsetDetail(
      token,
      date: date,
      statusPembayaran: _lastOmsetDetailStatus,
      page: _currentOmsetDetailPage + 1,
    );
  }

  Future<void> fetchExpenseAnalisa(
    String token, {
    required String startDate,
    required String endDate,
    bool notify = true,
    int page = 1,
  }) async {
    if (page == 1 && notify) {
      _setLoading(true);
      _setError(null);
      _expenseAnalisa = [];
      _lastExpenseStart = startDate;
      _lastExpenseEnd = endDate;
      _hasMoreExpenseReport = true;
    } else if (page > 1) {
      _setLoadingMore(true);
    }

    try {
      final url = _buildUrl(ApiEndpoints.reportExpense, {
        'start_date': startDate,
        'end_date': endDate,
        'page': '$page',
        'limit': '20',
      });

      final response = await ApiClient.getWithCache(url, token: token);
      final data = _parseResponse(response) as Map<String, dynamic>;

      final List list = data['list'] ?? [];
      final mapped = list.map((e) => ExpenseAnalisa.fromJson(e)).toList();
      if (page == 1) {
        _expenseAnalisa = mapped;
      } else {
        _expenseAnalisa.addAll(mapped);
      }
      _expenseReportPage = page;
      _hasMoreExpenseReport = data['has_more'] == true;

      if (data['summary'] != null) {
        _expenseSummary = ExpenseSummary.fromJson(data['summary']);
      }
    } catch (e) {
      if (notify) _setError(e.toString());
      rethrow;
    } finally {
      if (notify) _setLoading(false);
      _setLoadingMore(false);
    }
  }

  Future<void> loadMoreExpenseReport(String token) async {
    if (_isLoading || _isLoadingMore || !_hasMoreExpenseReport) return;
    final start = _lastExpenseStart, end = _lastExpenseEnd;
    if (start == null || end == null) return;
    await fetchExpenseAnalisa(
      token,
      startDate: start,
      endDate: end,
      page: _expenseReportPage + 1,
    );
  }

  Future<void> fetchExpenseDetail(
    String token, {
    String? startDate,
    String? endDate,
    String? kategoriId,
    int page = 1,
  }) async {
    if (page == 1) {
      _setLoading(true);
      _expenseDetail = [];
      _expenseDetailHeader = null;
      _hasMoreExpense = true;
    } else {
      if (!_hasMoreExpense) return;
      _setLoadingMore(true);
    }
    _setError(null);

    try {
      final url = _buildUrl(ApiEndpoints.reportExpenseDetail, {
        'start_date': startDate,
        'end_date': endDate,
        'kategori_id': kategoriId,
        'page': page.toString(),
        'limit': '20',
      });

      final response = await ApiClient.getWithCache(url, token: token);
      final dynamic data = _parseResponse(response);
      List list = [];
      if (data is List) {
        list = data;
      } else if (data is Map<String, dynamic>) {
        list = data['data'] ?? [];
        if (list.length < 20) {
          _hasMoreExpense = false;
        }
        if (page == 1 && data['header'] != null) {
          _expenseDetailHeader = ReportDetailHeader.fromJson(
            Map<String, dynamic>.from(data['header']),
          );
        }
      }

      final mapped = list.map((e) => ExpenseDetail.fromJson(e)).toList();
      if (page == 1) {
        _expenseDetail = mapped;
      } else {
        _expenseDetail.addAll(mapped);
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
      _setLoadingMore(false);
    }
  }

  Future<List<ExpenseDetail>> fetchAllExpenseDetails(
    String token, {
    String? startDate,
    String? endDate,
    String? kategoriId,
  }) async {
    final result = <ExpenseDetail>[];
    var page = 1;
    while (true) {
      final url = _buildUrl(ApiEndpoints.reportExpenseDetail, {
        'start_date': startDate,
        'end_date': endDate,
        'kategori_id': kategoriId,
        'page': '$page',
        'limit': '100',
      });
      final response = await ApiClient.get(url, token: token);
      final data = _parseResponse(response);
      final list = data is Map<String, dynamic>
          ? (data['data'] as List? ?? const [])
          : const [];
      result.addAll(list.map((e) => ExpenseDetail.fromJson(e)));
      if (list.length < 100) break;
      page++;
    }
    return result;
  }

  Future<void> fetchIncomeReport(
    String token, {
    required String startDate,
    required String endDate,
    String? metodePembayaran,
    bool notify = true,
    bool forceRefresh = false,
    int page = 1,
  }) async {
    _lastToken = token;
    _lastIncomeStartDate = startDate;
    _lastIncomeEndDate = endDate;
    _lastIncomeMetodePembayaran = metodePembayaran;

    if (page == 1 && notify) {
      _setLoading(true);
      _setError(null);
      _allIncomeReport = [];
      _incomeReport = [];
      _hasMoreIncomeReport = true;
    } else if (page > 1) {
      _setLoadingMore(true);
    }

    try {
      final url = _buildUrl(ApiEndpoints.reportIncome, {
        'start_date': startDate,
        'end_date': endDate,
        'metode_pembayaran_id': metodePembayaran,
        'page': '$page',
        'limit': '20',
      });

      final response = forceRefresh
          ? await ApiClient.get(url, token: token)
          : await ApiClient.getWithCache(url, token: token);
      final data = _parseResponse(response) as Map<String, dynamic>;

      final List list = data['list'] ?? [];
      final mapped = list.map((e) => IncomeReport.fromJson(e)).toList();
      if (page == 1) {
        _allIncomeReport = mapped;
      } else {
        _allIncomeReport.addAll(mapped);
      }
      _incomeReport = List.from(_allIncomeReport);
      _incomeReportPage = page;
      _hasMoreIncomeReport = data['has_more'] == true;
      _totalIncome =
          ((data['header'] as Map?)?['total_income'] as num?)?.toDouble() ?? 0;
      _incomeTotalDays = (data['total'] as num?)?.toInt() ?? mapped.length;

      if (page == 1) {
        final methodsUrl = _buildUrl(ApiEndpoints.reportIncomeMethods, {
          'start_date': startDate,
          'end_date': endDate,
        });
        final methodsResponse = await ApiClient.getWithCache(
          methodsUrl,
          token: token,
        );
        final methods = _parseResponse(methodsResponse) as List? ?? const [];
        _incomeMethods = methods
            .map((e) => PaymentMethod.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      notifyListeners();
    } catch (e) {
      if (notify) _setError(e.toString());
      rethrow;
    } finally {
      if (notify) _setLoading(false);
      _setLoadingMore(false);
    }
  }

  Future<void> loadMoreIncomeReport() async {
    if (_isLoading || _isLoadingMore || !_hasMoreIncomeReport) return;
    final token = _lastToken,
        start = _lastIncomeStartDate,
        end = _lastIncomeEndDate;
    if (token == null || start == null || end == null) return;
    await fetchIncomeReport(
      token,
      startDate: start,
      endDate: end,
      metodePembayaran: _lastIncomeMetodePembayaran,
      page: _incomeReportPage + 1,
    );
  }

  void applyIncomeFilter(String? metodePembayaran) {
    if (metodePembayaran == null) {
      _incomeReport = List.from(_allIncomeReport);
      _totalIncome = _incomeReport.fold(
        0,
        (sum, report) => sum + report.totalHarian,
      );
    } else {
      _incomeReport = _allIncomeReport
          .map((report) {
            final filtered = report.breakdown
                .where((breakdown) => breakdown.nama == metodePembayaran)
                .toList();

            if (filtered.isEmpty) return null;

            final total = filtered.fold<double>(
              0,
              (sum, breakdown) => sum + breakdown.nominal,
            );

            return IncomeReport(
              tanggal: report.tanggal,
              totalHarian: total,
              breakdown: filtered,
            );
          })
          .whereType<IncomeReport>()
          .toList();

      _totalIncome = _incomeReport.fold(
        0,
        (sum, report) => sum + report.totalHarian,
      );
    }

    notifyListeners();
  }

  Future<void> fetchPiutangReport(
    String token, {
    required String startDate,
    required String endDate,
    String? search,
    String? status,
    int page = 1,
    bool showInitialLoading = true,
  }) async {
    if (_isFetching) return;

    _isFetching = true;
    if (page == 1) {
      if (showInitialLoading) {
        _setLoading(true);
        _piutangReport = [];
      }
      _hasMorePiutang = true;
      _lastPiutangToken = token;
      _lastPiutangStartDate = startDate;
      _lastPiutangEndDate = endDate;
      _lastPiutangSearch = search;
      _lastPiutangStatus = status;
    } else {
      if (!_hasMorePiutang) {
        _isFetching = false;
        return;
      }
      _setLoadingMore(true);
    }
    _errorMessage = null;

    try {
      final url = _buildUrl(ApiEndpoints.reportPiutang, {
        'start_date': startDate,
        'end_date': endDate,
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null && status.isNotEmpty) 'status': status,
        'page': '$page',
        'limit': '20',
      });

      final response = await ApiClient.getWithCache(url, token: token);
      final data = _parseResponse(response) as Map<String, dynamic>;

      final List belumJatuhTempo = data['belum_jatuh_tempo'] ?? [];
      final List jatuhTempo = data['jatuh_tempo'] ?? [];

      final mapped = <PiutangReport>[
        ...belumJatuhTempo.map(
          (e) => PiutangReport.fromJson(e, isJatuhTempo: false),
        ),
        ...jatuhTempo.map((e) => PiutangReport.fromJson(e, isJatuhTempo: true)),
      ];
      if (page == 1) {
        _piutangReport = mapped;
      } else {
        _piutangReport.addAll(mapped);
      }
      _currentPiutangPage = page;
      _hasMorePiutang = data['has_more'] == true;

      if (data['summary'] != null) {
        _piutangSummary = PiutangSummary.fromJson(data['summary']);
      }
    } catch (e) {
      _errorMessage = userFriendlyError(e);
    } finally {
      _isFetching = false;
      if (showInitialLoading) _isLoading = false;
      if (page > 1) _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadMorePiutang() async {
    if (_isFetching || !_hasMorePiutang) return;
    final token = _lastPiutangToken;
    final start = _lastPiutangStartDate;
    final end = _lastPiutangEndDate;
    if (token == null || start == null || end == null) return;
    await fetchPiutangReport(
      token,
      startDate: start,
      endDate: end,
      search: _lastPiutangSearch,
      status: _lastPiutangStatus,
      page: _currentPiutangPage + 1,
    );
  }

  Future<void> fetchProfitLossReport(
    String token, {
    required String startDate,
    required String endDate,
    bool notify = true,
  }) async {
    if (notify) {
      _setLoading(true);
      _setError(null);
    }

    try {
      final url = _buildUrl(ApiEndpoints.reportProfitLoss, {
        'start_date': startDate,
        'end_date': endDate,
      });

      final response = await ApiClient.getWithCache(url, token: token);
      final parsed = Map<String, dynamic>.from(_parseResponse(response));
      _profitLossReport = ProfitLossReport.fromJson(parsed);
      _profitLossDetailMetode = (parsed['metode_pembayaran'] as List? ?? [])
          .whereType<Map>()
          .map(
            (e) =>
                ProfitLossDetailMetode.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
      _profitLossDetailPengeluaran =
          (parsed['detail_pengeluaran'] as List? ?? [])
              .whereType<Map>()
              .map(
                (e) => ProfitLossDetailPengeluaran.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList();
    } catch (e) {
      if (notify) _setError(e.toString());
      rethrow;
    } finally {
      if (notify) _setLoading(false);
    }
  }

  Future<void> fetchAllLabaRugiData(
    String token, {
    required String startDate,
    required String endDate,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      await fetchProfitLossReport(
        token,
        startDate: startDate,
        endDate: endDate,
        notify: false,
      );
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchProfitLossReportLastMonth(
    String token, {
    required String startDate,
    required String endDate,
  }) async {
    try {
      final url = _buildUrl(ApiEndpoints.reportProfitLoss, {
        'start_date': startDate,
        'end_date': endDate,
      });

      final response = await ApiClient.getWithCache(url, token: token);
      _profitLossReportLastMonth = ProfitLossReport.fromJson(
        _parseResponse(response),
      );

      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchCustomerDetailReport(
    String token, {
    String? startDate,
    String? endDate,
    String? jenisKelamin,
    bool notifyLoading = true,
  }) async {
    _lastToken = token;
    _lastCustomerDetailStartDate = startDate;
    _lastCustomerDetailEndDate = endDate;
    final cacheKey = '$startDate|$endDate|$jenisKelamin';
    final hasCurrentCache =
        _customerDetailCacheKey == cacheKey &&
        _customerDetailActiveData != null &&
        _customerDetailInactiveData != null;
    if (!hasCurrentCache) {
      _customerDetailActiveData = null;
      _customerDetailInactiveData = null;
      _customerDetailCacheKey = cacheKey;
    }
    _errorMessage = null;
    if (notifyLoading && !hasCurrentCache) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final results = await Future.wait([
        _fetchTopCustomerData(
          token,
          startDate: startDate,
          endDate: endDate,
          jenisKelamin: jenisKelamin,
          activityStatus: 'active',
        ),
        _fetchTopCustomerData(
          token,
          startDate: startDate,
          endDate: endDate,
          jenisKelamin: jenisKelamin,
          activityStatus: 'inactive',
        ),
      ]);
      _customerDetailActiveData = results[0];
      _customerDetailInactiveData = results[1];
    } catch (e) {
      if (!hasCurrentCache) _errorMessage = userFriendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchCustomerGrowthReport(
    String token, {
    String? startDate,
    String? endDate,
    String? jenisKelamin,
    bool notifyLoading = true,
  }) async {
    _lastToken = token;
    _lastCustomerGrowthStartDate = startDate;
    _lastCustomerGrowthEndDate = endDate;
    _lastCustomerGrowthJenisKelamin = jenisKelamin;
    if (notifyLoading) {
      _customerGrowthSummary = null;
      _topCustomerData = null;
    }
    _errorMessage = null;
    if (notifyLoading) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      await Future.wait([
        _doFetchCustomerGrowth(
          token,
          startDate: startDate,
          endDate: endDate,
          jenisKelamin: jenisKelamin,
        ),
        _doFetchTopCustomer(
          token,
          startDate: startDate,
          endDate: endDate,
          jenisKelamin: jenisKelamin,
        ),
      ]);
    } catch (e) {
      _errorMessage = userFriendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _doFetchCustomerGrowth(
    String token, {
    String? startDate,
    String? endDate,
    String? jenisKelamin,
  }) async {
    final url = _buildUrl(ApiEndpoints.customerGrowthSummary, {
      'start_date': startDate,
      'end_date': endDate,
      'jenis_kelamin': jenisKelamin,
    });

    final response = await ApiClient.getWithCache(url, token: token);
    final data = _parseResponse(response);

    _customerGrowthSummary = CustomerGrowthSummary.fromJson(
      Map<String, dynamic>.from(data),
    );
  }

  Future<void> _doFetchTopCustomer(
    String token, {
    String? startDate,
    String? endDate,
    String? jenisKelamin,
    String? activityStatus,
  }) async {
    _topCustomerData = await _fetchTopCustomerData(
      token,
      startDate: startDate,
      endDate: endDate,
      jenisKelamin: jenisKelamin,
      activityStatus: activityStatus,
    );
  }

  Future<void> loadMoreTopCustomer() async {
    final current = _topCustomerData;
    final token = _lastToken;
    if (_isLoadingMoreTopCustomer ||
        current == null ||
        !current.hasMore ||
        token == null) {
      return;
    }
    _isLoadingMoreTopCustomer = true;
    notifyListeners();
    try {
      final next = await _fetchTopCustomerData(
        token,
        startDate: _lastCustomerGrowthStartDate,
        endDate: _lastCustomerGrowthEndDate,
        jenisKelamin: _lastCustomerGrowthJenisKelamin,
        page: current.page + 1,
      );
      _topCustomerData = current.append(next);
    } finally {
      _isLoadingMoreTopCustomer = false;
      notifyListeners();
    }
  }

  Future<TopCustomerPodiumData> _fetchTopCustomerData(
    String token, {
    String? startDate,
    String? endDate,
    String? jenisKelamin,
    String? activityStatus,
    int page = 1,
  }) async {
    final url = _buildUrl(ApiEndpoints.customerTopCustomer, {
      'start_date': startDate,
      'end_date': endDate,
      'jenis_kelamin': jenisKelamin,
      'activity_status': activityStatus,
      'page': '$page',
      'limit': '15',
    });

    final response = await ApiClient.getWithCache(url, token: token);
    final data = _parseResponse(response);

    return TopCustomerPodiumData.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> loadMoreCustomerDetail(String activityStatus) async {
    if (_isLoadingMoreCustomer) return;
    final current = activityStatus == 'inactive'
        ? _customerDetailInactiveData
        : _customerDetailActiveData;
    final token = _lastToken;
    if (current == null || !current.hasMore || token == null) return;
    _isLoadingMoreCustomer = true;
    notifyListeners();
    try {
      final next = await _fetchTopCustomerData(
        token,
        startDate: _lastCustomerDetailStartDate,
        endDate: _lastCustomerDetailEndDate,
        activityStatus: activityStatus,
        page: current.page + 1,
      );
      if (activityStatus == 'inactive') {
        _customerDetailInactiveData = current.append(next);
      } else {
        _customerDetailActiveData = current.append(next);
      }
    } finally {
      _isLoadingMoreCustomer = false;
      notifyListeners();
    }
  }

  Future<void> fetchCustomerGrowthSummary(
    String token, {
    String? startDate,
    String? endDate,
    String? jenisKelamin,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      await _doFetchCustomerGrowth(
        token,
        startDate: startDate,
        endDate: endDate,
        jenisKelamin: jenisKelamin,
      );
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchTopCustomer(
    String token, {
    String? startDate,
    String? endDate,
    String? jenisKelamin,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      await _doFetchTopCustomer(
        token,
        startDate: startDate,
        endDate: endDate,
        jenisKelamin: jenisKelamin,
      );
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchIncomeDetail(
    String token, {
    required String startDate,
    required String endDate,
    required String metodeNama,
    int page = 1,
    bool forceRefresh = false,
  }) async {
    _lastToken = token;
    _lastDetailStartDate = startDate;
    _lastDetailEndDate = endDate;
    _lastDetailMetodeNama = metodeNama;

    if (page == 1) {
      _setLoading(true);
      _incomeDetailList = [];
      _incomeDetailHeader = null;
      _hasMoreIncomeDetail = true;
    } else {
      if (!_hasMoreIncomeDetail) return;
      _setLoadingMore(true);
    }
    _setError(null);

    try {
      final url = _buildUrl('${ApiEndpoints.reportIncome}/detail', {
        'start_date': startDate,
        'end_date': endDate,
        'metode_nama': metodeNama,
        'page': page.toString(),
        'limit': '20',
      });

      final response = forceRefresh
          ? await ApiClient.get(url, token: token)
          : await ApiClient.getWithCache(url, token: token);
      final dynamic data = _parseResponse(response);
      List list = [];
      if (data is Map<String, dynamic>) {
        list = data['data'] ?? [];
        if (list.length < 20) {
          _hasMoreIncomeDetail = false;
        }
        if (page == 1 && data['header'] != null) {
          _incomeDetailHeader = ReportDetailHeader.fromJson(
            Map<String, dynamic>.from(data['header']),
          );
        }
      }

      final mapped = list
          .map((e) => IncomeDetailTransaction.fromJson(e))
          .toList();
      if (page == 1) {
        _incomeDetailList = mapped;
      } else {
        _incomeDetailList.addAll(mapped);
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
      _setLoadingMore(false);
    }
  }

  void resetState() {
    _summary = null;
    _chartData = [];

    _omsetReport = [];
    _omsetHeader = {};
    _omsetDetail = [];
    _omsetDetailHeader = null;

    _allTransactions = [];
    _allTransactionsHeader = null;

    _expenseAnalisa = [];
    _expenseSummary = null;
    _expenseByCategory = [];
    _expenseDetail = [];
    _expenseDetailHeader = null;

    _totalIncome = 0;
    _incomeReport = [];
    _allIncomeReport = [];
    _incomeMethods = [];
    _incomeDetailList = [];
    _incomeDetailHeader = null;

    _piutangReport = [];
    _piutangSummary = null;

    _profitLossReport = null;
    _profitLossReportLastMonth = null;
    _profitLossDetailMetode = [];
    _profitLossDetailPengeluaran = [];

    _transaksiPerLayanan = [];
    _transaksiPerLayananHeader = null;

    _customerGrowthSummary = null;
    _topCustomerData = null;

    _lastAllTransactionsStartDate = null;
    _lastAllTransactionsEndDate = null;
    _lastAllTransactionsStatusOrder = null;
    _lastAllTransactionsStatusPembayaran = null;
    _lastAllTransactionsSearch = null;
    _currentAllTransactionsPage = 1;
    _hasMoreTransactions = true;

    _errorMessage = null;
    _isFetching = false;

    notifyListeners();
  }
}
