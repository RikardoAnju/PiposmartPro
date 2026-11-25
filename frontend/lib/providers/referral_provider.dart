import 'dart:convert';
import 'package:ayocucinew/core/constants/api_endpoints.dart';
import 'package:ayocucinew/core/events/app_events.dart';
import 'package:ayocucinew/core/utils/api_client.dart';
import 'package:ayocucinew/data/models/referral_model.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum ReferralStatus { idle, loading, success, error }

class ReferralProvider extends ChangeNotifier {
  ReferralSummaryModel? _summary;
  ReferralSummaryModel? get summary => _summary;

  List<ReferralRecruitedOwnerModel> _recruitedOwners = [];
  List<ReferralRecruitedOwnerModel> get recruitedOwners => _recruitedOwners;

  List<ReferralTopRankModel> _topRanks = [];
  List<ReferralTopRankModel> get topRanks => _topRanks;

  ReferralStatus _status = ReferralStatus.idle;
  ReferralStatus get status => _status;

  // FIX: masing-masing status punya errorMessage sendiri agar tidak saling override
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _recruitedErrorMessage;
  String? get recruitedErrorMessage => _recruitedErrorMessage;

  String? _topRankErrorMessage;
  String? get topRankErrorMessage => _topRankErrorMessage;

  ReferralStatus _recruitedStatus = ReferralStatus.idle;
  ReferralStatus get recruitedStatus => _recruitedStatus;

  ReferralStatus _topRankStatus = ReferralStatus.idle;
  ReferralStatus get topRankStatus => _topRankStatus;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  Future<void> fetchSummary({String? token}) async {
    _setStatus(ReferralStatus.loading);
    try {
      final res = await ApiClient.get('/referral/summary', token: token);
      final body = _handleResponse(res);
      _summary = ReferralSummaryModel.fromJson(body['data']);
      _setStatus(ReferralStatus.success);
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> fetchRecruitedOwners({String? token}) async {
    _recruitedStatus = ReferralStatus.loading;
    _recruitedErrorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.get(
        '/referral/recruited-owners',
        token: token,
      );
      final body = _handleResponse(res);
      final data = body['data'];
      _recruitedOwners = (data as List<dynamic>? ?? [])
          .map(
            (e) =>
                ReferralRecruitedOwnerModel.fromJson(e as Map<String, dynamic>),
          )
          .toList();
      _recruitedStatus = ReferralStatus.success;
    } catch (e) {
      _recruitedStatus = ReferralStatus.error;
      _recruitedErrorMessage = e.toString();
    }

    notifyListeners();
  }

  Future<void> fetchTopRanks({String? token}) async {
    _topRankStatus = ReferralStatus.loading;
    _topRankErrorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.get(
        ApiEndpoints.referralTopRankOwner,
        token: token,
      );
      final body = _handleResponse(res);

      _topRanks = ((body['data'] ?? []) as List)
          .map((e) => ReferralTopRankModel.fromJson(e))
          .toList();

      if (kDebugMode) {
        debugPrint(
          '[ReferralProvider] fetchTopRanks: ${_topRanks.length} item',
        );
      }

      _topRankStatus = ReferralStatus.success;
    } catch (e) {
      _topRankStatus = ReferralStatus.error;
      _topRankErrorMessage = e.toString();
      _topRanks = [];

      if (kDebugMode) {
        debugPrint('[ReferralProvider] fetchTopRanks error: $e');
      }
    }

    notifyListeners();
  }

  Future<String?> applyReferralCode(String code, {String? token}) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      final res = await ApiClient.post(
        '/referral/apply',
        body: {'code': code},
        token: token,
      );
      _handleResponse(res);
      await fetchSummary(token: token);
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> convertToKoin({
    required String outletId,
    required List<int> rewardIds,
    String? token,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      final res = await ApiClient.post(
        ApiEndpoints.referralConvertToKoin,
        body: {'outlet_id': outletId, 'reward_ids': rewardIds},
        token: token,
      );

      final body = _handleResponse(res);
      await fetchSummary(token: token);
      appEventBus.add(CoinBalanceChanged());

      return {
        'success': true,
        'message': body['message'],
        'data': body['data'],
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // PAYOUT REQUESTS
  // ─────────────────────────────────────────────
  // FIX: hilangkan try-catch { rethrow } yang tidak berguna
  Future<ReferralPayoutModel?> createPayoutRequest({
    required List<int> rewardIds,
    int? payoutAccountId,
    String bankName = '',
    String accountName = '',
    String accountNumber = '',
    String? note,
    String? token,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      final body = <String, dynamic>{'reward_ids': rewardIds};

      if (payoutAccountId != null) body['payout_account_id'] = payoutAccountId;
      if (bankName.isNotEmpty) body['bank_name'] = bankName;
      if (accountName.isNotEmpty) body['account_name'] = accountName;
      if (accountNumber.isNotEmpty) body['account_number'] = accountNumber;
      if (note != null && note.isNotEmpty) body['note'] = note;

      final res = await ApiClient.post(
        '/referral/payout-requests',
        body: body,
        token: token,
      );
      final resBody = _handleResponse(res);

      await fetchSummary(token: token);

      return ReferralPayoutModel.fromJson(resBody['data']);
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<List<ReferralPayoutAccountModel>> fetchPayoutAccounts({
    String? token,
  }) async {
    final res = await ApiClient.get('/referral/payout-accounts', token: token);
    final body = _handleResponse(res);
    return (body['data'] as List)
        .map((e) => ReferralPayoutAccountModel.fromJson(e))
        .toList();
  }

  Future<ReferralPayoutAccountModel> createPayoutAccount({
    required String bankName,
    required String accountName,
    required String accountNumber,
    bool isDefault = false,
    String? token,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      final res = await ApiClient.post(
        '/referral/payout-accounts',
        body: {
          'bank_name': bankName,
          'account_name': accountName,
          'account_number': accountNumber,
          'is_default': isDefault,
        },
        token: token,
      );

      final body = _handleResponse(res);
      await fetchSummary(token: token);

      return ReferralPayoutAccountModel.fromJson(body['data']);
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<ReferralPayoutAccountModel> updatePayoutAccount({
    required int accountId,
    required String bankName,
    required String accountName,
    required String accountNumber,
    bool isDefault = false,
    String? token,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      final res = await ApiClient.put(
        '/referral/payout-accounts/$accountId',
        body: {
          'bank_name': bankName,
          'account_name': accountName,
          'account_number': accountNumber,
          'is_default': isDefault,
        },
        token: token,
      );

      final body = _handleResponse(res);
      await fetchSummary(token: token);

      return ReferralPayoutAccountModel.fromJson(body['data']);
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> setDefaultPayoutAccount(int accountId, {String? token}) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      final res = await ApiClient.patch(
        '/referral/payout-accounts/$accountId/default',
        token: token,
      );
      _handleResponse(res);
      await fetchSummary(token: token);
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> deletePayoutAccount(int accountId, {String? token}) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      final res = await ApiClient.delete(
        '/referral/payout-accounts/$accountId',
        token: token,
      );
      _handleResponse(res);
      await fetchSummary(token: token);
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void reset() {
    _summary = null;
    _status = ReferralStatus.idle;
    _recruitedStatus = ReferralStatus.idle;
    _topRankStatus = ReferralStatus.idle;
    _recruitedOwners = [];
    _topRanks = [];
    // FIX: reset semua error message masing-masing
    _errorMessage = null;
    _recruitedErrorMessage = null;
    _topRankErrorMessage = null;
    _isSubmitting = false;
    notifyListeners();
  }

  void _setStatus(ReferralStatus s) {
    _status = s;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _status = ReferralStatus.error;
    _errorMessage = msg;
    notifyListeners();
  }

  // FIX: sertakan status code asli di pesan error agar lebih informatif
  Map<String, dynamic> _handleResponse(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }

    final serverMsg = body['message']?.toString() ?? body['error']?.toString();
    final msg = serverMsg != null
        ? '$serverMsg (${res.statusCode})'
        : 'Terjadi kesalahan (${res.statusCode})';

    throw Exception(msg);
  }
}
