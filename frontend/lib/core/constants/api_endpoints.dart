class ApiEndpoints {
  ApiEndpoints._();

  // Auth & Profile
  static String get register => '/auth/register';
  static String get login => '/auth/login';
  static String get googleLogin => '/auth/google-login';
  static String get updateProfile => '/auth/update-profile';
  static String get userProfile => '/auth/profile';
  static String get resetPassword => '/auth/reset-password';
  static String get sendOTP => '/auth/send-otp';
  static String get verifyOTP => '/auth/verify-otp';

  // Koin
  static String get koinTopup => '/koin/request-topup';
  static String get koinHistory => '/koin/history';
  static String get koinActiveTopups => '/koin/active-topups';
  static String get validateVoucher => '/koin/check-voucher';
  static String get koinEconomyConfig => '/koin/economy-config';

  // Referral
  static String get referralSummary => '/referral/summary';
  static String get referralApply => '/referral/apply';
  static String get referralConvertToKoin => '/referral/convert-to-koin';
  static String get referralPayoutRequests => '/referral/payout-requests';
  static String get referralPayoutAccounts => '/referral/payout-accounts';
  static String get referralTopRankOwner => '/referral/top-rank-owner';
  static String get referralRecruitedOwners => '/referral/recruited-owners';

  // Core Business
  static String get createOutlet => '/outlet/create';
  static String get outlet => '/outlet';
  static String get services => '/services';
  static String get customers => '/customers';
  static String get employees => '/employees';
  static String get transactions => '/transactions';
  static String get performanceTransactions => '/transactions/performance';
  static String get nobuQris => '/transactions/qris/nobu';
  static String get items => '/items';

  // Master Data
  static String get parfum => '/master/parfums';
  static String get diskon => '/master/discounts';
  static String get pengeluaran => '/pengeluaran';
  static String get kategoriPengeluaran => '/kategori-pengeluaran';
  static String get paymentMethods => '/payment-methods';
  static String get notaSettings => '/nota-setting';
  static String get notaLogo => '/nota-setting/logo';

  static String notaPublic(String encodedId) => '/nota/public/$encodedId';

  // Finance Dashboard
  static String get financeDashboardSummary => '/finance/dashboard/summary';
  static String get financeDashboardChart => '/finance/dashboard/chart';

  // Omset
  static String get reportOmset => '/finance/report-omset';
  static String get reportOmsetDetail => '/finance/report-omset/detail';

  // Pengeluaran
  static String get reportExpense => '/finance/report-expense';
  static String get reportExpenseCategory => '/finance/report-expense/category';
  static String get reportExpenseDetail => '/finance/report-expense/detail';

  // Pendapatan
  static String get reportIncome => '/finance/report-income';
  static String get reportIncomeMethods => '/finance/report-income/methods';
  static String get reportDeposit => '/finance/report-deposit';

  // Laporan Transaksi
  static String get reportTransactions => '/report/transactions';

  // Transaksi Per Layanan
  static String get reportTransaksiPerLayanan => '/report/services';

  // Piutang
  static String get reportPiutang => '/finance/report-piutang';

  // Laba Rugi
  static String get reportProfitLoss => '/finance/report-profit-loss';
  static String get reportProfitLossDetailMetode =>
      '/finance/report-profit-loss/detail-metode';
  static String get reportProfitLossDetailExpense =>
      '/finance/report-profit-loss/detail-expense';

  // Customer Reports
  static String get customerGrowthSummary => '/report-customer/growth';
  static String get customerTopCustomer => '/report-customer/top';
}
