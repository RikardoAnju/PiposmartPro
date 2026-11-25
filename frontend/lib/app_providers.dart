// lib/app_providers.dart
//
// Semua provider didaftarkan di sini.
// Import file ini di main.dart dan gunakan AppProviders.build().

import 'package:ayocucinew/providers/referral_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/providers/addon_provider.dart';
import 'package:ayocucinew/providers/app_provider.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/providers/customer_provider.dart';
import 'package:ayocucinew/providers/customer_deposit_provider.dart';
import 'package:ayocucinew/providers/deposit_report_provider.dart';
import 'package:ayocucinew/providers/content_provider.dart';
import 'package:ayocucinew/providers/diskon_provider.dart';
import 'package:ayocucinew/providers/item_provider.dart';
import 'package:ayocucinew/providers/iap_provider.dart';
import 'package:ayocucinew/providers/kategori_pengeluaran_provider.dart';
import 'package:ayocucinew/providers/koin_provider.dart';
import 'package:ayocucinew/providers/laporan_provider.dart';
import 'package:ayocucinew/providers/metode_pembayaran_provider.dart';
import 'package:ayocucinew/providers/nobu_payment_provider.dart';
import 'package:ayocucinew/providers/notaprint_provider.dart';
import 'package:ayocucinew/providers/notification_provider.dart';
import 'package:ayocucinew/providers/parfum_provider.dart';
import 'package:ayocucinew/providers/payroll_provider.dart';
import 'package:ayocucinew/providers/pegawai_provider.dart';
import 'package:ayocucinew/providers/pengeluaran_provider.dart';
import 'package:ayocucinew/providers/permission_provider.dart';
import 'package:ayocucinew/providers/register_provider.dart';
import 'package:ayocucinew/providers/report_provider.dart';
import 'package:ayocucinew/providers/role_provider.dart';
import 'package:ayocucinew/providers/service_provider.dart';
import 'package:ayocucinew/providers/setting_nota_provider.dart';
import 'package:ayocucinew/providers/setting_provider.dart';
import 'package:ayocucinew/providers/status_provider.dart';
import 'package:ayocucinew/providers/summary_provider.dart';
import 'package:ayocucinew/providers/transaction_provider.dart';
import 'package:ayocucinew/providers/work_log_provider.dart';
import 'package:ayocucinew/providers/attendance_provider.dart';
import 'package:ayocucinew/providers/inventory_provider.dart';

class AppProviders {
  /// Bungkus [child] dengan seluruh provider yang dibutuhkan aplikasi.
  static Widget build({
    required AuthProvider authProvider,
    required Widget child,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => ServiceProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => CustomerDepositProvider()),
        ChangeNotifierProvider(create: (_) => DepositReportProvider()),
        ChangeNotifierProvider(create: (_) => ContentProvider()),
        ChangeNotifierProvider(create: (_) => ParfumProvider()),
        ChangeNotifierProvider(create: (_) => PayrollProvider()),
        ChangeNotifierProvider(create: (_) => DiskonProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => NotaPrintProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        ChangeNotifierProvider(create: (_) => KategoriPengeluaranProvider()),
        ChangeNotifierProvider(create: (_) => PengeluaranProvider()),
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => PaymentMethodProvider()),
        ChangeNotifierProvider(create: (_) => NobuPaymentProvider()),
        ChangeNotifierProvider(create: (_) => NotaSettingsProvider()),
        ChangeNotifierProvider(create: (_) => ItemProvider()),
        ChangeNotifierProvider(create: (_) => RegisterProvider()),
        ChangeNotifierProvider(create: (_) => SettingProvider()),
        ChangeNotifierProvider(create: (_) => RoleProvider()),
        ChangeNotifierProvider(create: (_) => PegawaiProvider()),
        ChangeNotifierProvider(create: (_) => StatusProvider()),
        ChangeNotifierProvider(create: (_) => SummaryProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => KoinProvider()),
        ChangeNotifierProvider(create: (_) => IapProvider()),
        ChangeNotifierProvider(create: (_) => AddonProvider()),
        ChangeNotifierProvider(create: (_) => LaporanProvider()),
        ChangeNotifierProvider(create: (_) => ReferralProvider()),
        ChangeNotifierProvider(create: (_) => PermissionProvider()),
        ChangeNotifierProvider(create: (_) => WorkLogProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
      ],
      child: child,
    );
  }
}
