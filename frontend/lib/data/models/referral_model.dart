class ReferralSummaryModel {
  final String referralCode;
  final bool hasReferrer;
  final String myReferrerName;
  final int availableBalance;
  final int totalEarned;
  final int totalConverted;
  final int pendingPayout;
  final int recruitedOwners;
  final int rewardPerOwner;
  final int firstTopupPercent;
  final int firstTopupReferredPercent;
  final int nextTopupPercent;
  final int monthlyRewardLimit;
  final int payoutBudget;
  final int payoutBudgetUsed;
  final int payoutBudgetRemaining;
  final int payoutMinAmount;
  final int payoutMaxAmount;
  final String conversionRateText;
  final List<ReferralRewardModel> recentRewards;
  final List<ReferralRewardModel> availableRewards;
  final List<ReferralWalletHistoryModel> recentTransactions;
  final List<ReferralPayoutModel> payoutRequests;
  final List<ReferralOutletModel> ownerOutlets;
  final List<ReferralPayoutAccountModel> payoutAccounts;
  final bool isReferralLocked;

  ReferralSummaryModel({
    required this.referralCode,
    required this.hasReferrer,
    required this.myReferrerName,
    required this.availableBalance,
    required this.totalEarned,
    required this.totalConverted,
    required this.pendingPayout,
    required this.recruitedOwners,
    required this.rewardPerOwner,
    required this.firstTopupPercent,
    required this.firstTopupReferredPercent,
    required this.nextTopupPercent,
    required this.monthlyRewardLimit,
    required this.payoutBudget,
    required this.payoutBudgetUsed,
    required this.payoutBudgetRemaining,
    required this.payoutMinAmount,
    required this.payoutMaxAmount,
    required this.conversionRateText,
    required this.recentRewards,
    required this.availableRewards,
    required this.recentTransactions,
    required this.payoutRequests,
    required this.ownerOutlets,
    required this.payoutAccounts,
    required this.isReferralLocked,
  });

  factory ReferralSummaryModel.fromJson(Map<String, dynamic> json) {
    return ReferralSummaryModel(
      referralCode: json['referral_code']?.toString() ?? '',
      hasReferrer: json['has_referrer'] == true,
      myReferrerName: json['my_referrer_name']?.toString() ?? '',
      availableBalance: int.tryParse(json['available_balance'].toString()) ?? 0,
      totalEarned: int.tryParse(json['total_earned'].toString()) ?? 0,
      totalConverted: int.tryParse(json['total_converted'].toString()) ?? 0,
      pendingPayout: int.tryParse(json['pending_payout'].toString()) ?? 0,
      recruitedOwners: int.tryParse(json['recruited_owners'].toString()) ?? 0,
      rewardPerOwner: int.tryParse(json['reward_per_owner'].toString()) ?? 0,
      firstTopupPercent:
          int.tryParse(json['first_topup_percent'].toString()) ?? 0,
      firstTopupReferredPercent:
          int.tryParse(json['first_topup_referred_percent'].toString()) ?? 0,
      nextTopupPercent:
          int.tryParse(json['next_topup_percent'].toString()) ?? 0,
      monthlyRewardLimit:
          int.tryParse(json['monthly_reward_limit'].toString()) ?? 0,
      payoutBudget: int.tryParse(json['payout_budget'].toString()) ?? 0,
      payoutBudgetUsed:
          int.tryParse(json['payout_budget_used'].toString()) ?? 0,
      payoutBudgetRemaining:
          int.tryParse(json['payout_budget_remaining'].toString()) ?? 0,
      payoutMinAmount:
          int.tryParse(json['payout_min_amount'].toString()) ?? 100000,
      payoutMaxAmount:
          int.tryParse(json['payout_max_amount'].toString()) ?? 1000000,
      conversionRateText: json['conversion_rate_text']?.toString() ?? '-',
      recentRewards: ((json['recent_rewards'] ?? []) as List)
          .map((e) => ReferralRewardModel.fromJson(e))
          .toList(),
      availableRewards: ((json['available_rewards'] ?? []) as List)
          .map((e) => ReferralRewardModel.fromJson(e))
          .toList(),
      recentTransactions: ((json['recent_transactions'] ?? []) as List)
          .map((e) => ReferralWalletHistoryModel.fromJson(e))
          .toList(),
      payoutRequests: ((json['payout_requests'] ?? []) as List)
          .map((e) => ReferralPayoutModel.fromJson(e))
          .toList(),
      ownerOutlets: ((json['owner_outlets'] ?? []) as List)
          .map((e) => ReferralOutletModel.fromJson(e))
          .toList(),
      payoutAccounts: ((json['payout_accounts'] ?? []) as List)
          .map((e) => ReferralPayoutAccountModel.fromJson(e))
          .toList(),
      isReferralLocked: json['is_referral_locked'] == true,
    );
  }
}

class ReferralTopRankModel {
  final int rank;
  final int userId;
  final String ownerName;
  final String referralCode;
  final String outletName;
  // Pakai double lalu konversi ke int agar aman dari nilai desimal JSON
  // (backend int64 bisa datang sebagai number besar dari jsonDecode)
  final int totalUsed;
  final int totalReward;

  ReferralTopRankModel({
    required this.rank,
    required this.userId,
    required this.ownerName,
    required this.referralCode,
    required this.outletName,
    required this.totalUsed,
    required this.totalReward,
  });

  factory ReferralTopRankModel.fromJson(Map<String, dynamic> json) {
    return ReferralTopRankModel(
      rank: _parseInt(json['rank']),
      userId: _parseInt(json['user_id']),
      ownerName: (json['owner_name'] ?? '')
          .toString()
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim(),
      referralCode: json['referral_code']?.toString() ?? '-',
      outletName: json['outlet_name']?.toString() ?? '-',
      totalUsed: _parseInt(json['total_used']),
      totalReward: _parseInt(json['total_reward']),
    );
  }

  // Helper: aman untuk nilai int maupun double dari JSON
  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}

class ReferralOutletModel {
  final String id;
  final String name;
  final int koin;

  ReferralOutletModel({
    required this.id,
    required this.name,
    required this.koin,
  });

  factory ReferralOutletModel.fromJson(Map<String, dynamic> json) {
    return ReferralOutletModel(
      id: json['ot_id']?.toString() ?? '',
      name: json['ot_nama']?.toString() ?? '-',
      koin: int.tryParse(json['ot_koin'].toString()) ?? 0,
    );
  }
}

class ReferralRewardModel {
  final int id;
  final String ownerName;
  final String outletName;
  final int rewardAmount;
  final String createdAt;
  final String type;
  final String status;
  final int coinAmount;
  final String coinStatus;
  final String? coinClaimedOutletId;
  final int percent;

  ReferralRewardModel({
    required this.id,
    required this.ownerName,
    required this.outletName,
    required this.rewardAmount,
    required this.createdAt,
    required this.type,
    required this.status,
    required this.coinAmount,
    required this.coinStatus,
    this.coinClaimedOutletId,
    required this.percent,
  });

  factory ReferralRewardModel.fromJson(Map<String, dynamic> json) {
    return ReferralRewardModel(
      id: int.tryParse(json['rr_id']?.toString() ?? '') ?? 0,
      ownerName: json['owner_name']?.toString() ?? '-',
      outletName: json['outlet_name']?.toString() ?? '-',
      rewardAmount:
          int.tryParse(json['rr_reward_amount']?.toString() ?? '') ?? 0,
      createdAt: json['rr_created']?.toString() ?? '',
      type: json['rr_type']?.toString() ?? 'recruit',
      status: json['rr_status']?.toString() ?? 'credited',
      coinAmount: int.tryParse(json['rr_coin_amount']?.toString() ?? '') ?? 0,
      coinStatus: json['rr_coin_status']?.toString() ?? 'no_bonus',
      coinClaimedOutletId: json['rr_coin_claimed_outlet']?.toString(),
      percent: int.tryParse(json['percent']?.toString() ?? '') ?? 0,
    );
  }
}

class ReferralWalletHistoryModel {
  final int amount;
  final int balanceAfter;
  final String type;
  final String description;
  final String createdAt;

  ReferralWalletHistoryModel({
    required this.amount,
    required this.balanceAfter,
    required this.type,
    required this.description,
    required this.createdAt,
  });

  factory ReferralWalletHistoryModel.fromJson(Map<String, dynamic> json) {
    return ReferralWalletHistoryModel(
      amount: int.tryParse(json['rwh_amount'].toString()) ?? 0,
      balanceAfter: int.tryParse(json['rwh_balance_after'].toString()) ?? 0,
      type: json['rwh_type']?.toString() ?? '',
      description: json['rwh_description']?.toString() ?? '',
      createdAt: json['rwh_created']?.toString() ?? '',
    );
  }
}

class ReferralPayoutModel {
  final String id;
  final int? payoutAccountId;
  final int amount;
  final String status;
  final String bankName;
  final String accountName;
  final String accountNumber;
  final String? note;
  final String? adminNote;
  final String createdAt;
  final String? processedAt;
  final String? completedAt;

  ReferralPayoutModel({
    required this.id,
    this.payoutAccountId,
    required this.amount,
    required this.status,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    this.note,
    this.adminNote,
    required this.createdAt,
    this.processedAt,
    this.completedAt,
  });

  factory ReferralPayoutModel.fromJson(Map<String, dynamic> json) {
    return ReferralPayoutModel(
      id: json['rp_id']?.toString() ?? '',
      payoutAccountId: int.tryParse(
        (json['rp_payout_account_id'] ?? '').toString(),
      ),
      amount: int.tryParse(json['rp_amount'].toString()) ?? 0,
      status: json['rp_status']?.toString() ?? 'pending',
      bankName: json['rp_bank_name']?.toString() ?? '-',
      accountName: json['rp_account_name']?.toString() ?? '-',
      accountNumber: json['rp_account_number']?.toString() ?? '-',
      note: json['rp_note']?.toString(),
      adminNote: json['rp_admin_note']?.toString(),
      createdAt: json['rp_created']?.toString() ?? '',
      processedAt: json['rp_processed_at']?.toString(),
      completedAt: json['rp_completed_at']?.toString(),
    );
  }
}

class ReferralPayoutAccountModel {
  final int id;
  final String bankName;
  final String accountName;
  final String accountNumber;
  final bool isDefault;

  ReferralPayoutAccountModel({
    required this.id,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    required this.isDefault,
  });

  factory ReferralPayoutAccountModel.fromJson(Map<String, dynamic> json) {
    return ReferralPayoutAccountModel(
      id: int.tryParse((json['rpa_id'] ?? '').toString()) ?? 0,
      bankName: json['rpa_bank_name']?.toString() ?? '-',
      accountName: json['rpa_account_name']?.toString() ?? '-',
      accountNumber: json['rpa_account_number']?.toString() ?? '-',
      isDefault: json['rpa_is_default'] == true || json['rpa_is_default'] == 1,
    );
  }
}

class ReferralRecruitedOwnerModel {
  final String ownerName;
  final String outletName; // FIX: field ini hilang di versi sebelumnya
  final String joinDate;

  ReferralRecruitedOwnerModel({
    required this.ownerName,
    required this.outletName,
    required this.joinDate,
  });

  factory ReferralRecruitedOwnerModel.fromJson(Map<String, dynamic> json) {
    final rawDate =
        json['join_date'] ?? json['rr_created'] ?? json['created_at'] ?? '';
    return ReferralRecruitedOwnerModel(
      ownerName: json['owner_name'] ?? json['nama'] ?? '',
      outletName: json['outlet_name']?.toString() ?? '-',
      joinDate: _formatDate(rawDate.toString()),
    );
  }

  static String _formatDate(String raw) {
    if (raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw).toLocal();
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
      return '${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}
