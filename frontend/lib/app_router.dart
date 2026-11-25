import 'package:flutter/material.dart';
import 'dart:io';
import 'package:ayocucinew/screens/auth/login_screen.dart';
import 'package:ayocucinew/screens/auth/register_master_screen.dart';
import 'package:ayocucinew/screens/auth/onboarding_screen.dart';
import 'package:ayocucinew/screens/auth/splash_screen.dart';
import 'package:ayocucinew/screens/auth/forgot_password_screen.dart';
import 'package:ayocucinew/screens/home/home_screen.dart';
import 'package:ayocucinew/screens/home/notification_screen.dart';
import 'package:ayocucinew/screens/operational/customer/customer_list_screen.dart';
import 'package:ayocucinew/screens/operational/employee/employee_list_screen.dart';
import 'package:ayocucinew/screens/operational/employee/kelola_karyawan_screen.dart';
import 'package:ayocucinew/screens/operational/employee/work_log/work_log_screen.dart';
import 'package:ayocucinew/screens/operational/employee/salary_settings_screen.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/owner/attendance_dashboard_screen.dart';
import 'package:ayocucinew/screens/operational/employee/employee_attendance_screen.dart';
import 'package:ayocucinew/screens/operational/outlet/outlet_list_screen.dart';
import 'package:ayocucinew/screens/operational/services/kelola_layanan_screen.dart';
import 'package:ayocucinew/screens/operational/services/add_service_screen.dart';
import 'package:ayocucinew/screens/operational/services/service_list_screen.dart';
import 'package:ayocucinew/screens/operational/transaction/payment/payment_page.dart';
import 'package:ayocucinew/screens/operational/pengeluaran/pengeluaran_list_screen.dart';
import 'package:ayocucinew/screens/settings/diskon/diskon_list_screen.dart';
import 'package:ayocucinew/screens/inventory/inventory_screen.dart';
import 'package:ayocucinew/screens/settings/item/item_list_screen.dart';
import 'package:ayocucinew/screens/settings/parfum/parfum_list_screen.dart';
import 'package:ayocucinew/screens/settings/role/role_list_screen.dart';
import 'package:ayocucinew/screens/settings/setting_screen.dart';
import 'package:ayocucinew/screens/settings/aktivasi/aktivasi_akun_screen.dart';
import 'package:ayocucinew/screens/settings/aktivasi/pembelian_saya_screen.dart';
import 'package:ayocucinew/screens/settings/koin/koin_management_screen.dart';
import 'package:ayocucinew/screens/settings/referral/referral_page.dart';
import 'package:ayocucinew/screens/report/report_screen.dart';
import 'package:ayocucinew/screens/report/finance_report_screen.dart';
import 'package:ayocucinew/screens/report/laporan%20pelanggan/detail%20laporan/customer_detail_report_screen.dart';
import 'package:ayocucinew/screens/report/laporan%20pelanggan/ringkasan/customer_report_screen.dart';
import 'package:ayocucinew/screens/report/laporan%20transakasi/data_transaksi/all_transactions_screen.dart';
import 'package:ayocucinew/screens/report/laporan%20transakasi/ringkasan_transaksi/transaksi_per_layanan_screen.dart';

class AppRouter {
  static Map<String, WidgetBuilder> get routes => {
    '/': (context) => const SplashScreen(),
    '/onboarding': (context) => const OnboardingScreen(),
    '/login': (context) => const LoginScreen(),
    '/register': (context) => const RegisterMasterScreen(),
    '/forgot-password': (context) => const ForgotPasswordScreen(),
    '/home': (context) => const HomeScreen(),
    '/setup-outlet': (context) =>
        Platform.isIOS ? const HomeScreen() : const LoginScreen(),
    '/kelola-layanan': (context) => const KelolaLayananScreen(),
    '/service-list': (context) => const ServiceListScreen(),
    '/add-service': (context) => const AddServiceScreen(),
    '/customer-list': (context) => const CustomerListScreen(),
    '/pegawai-list': (context) => const KelolaKaryawanScreen(),
    '/pegawai-data': (context) => const EmployeeListScreen(),
    '/pegawai-log-kerja': (context) => const WorkLogScreen(),
    '/pegawai-gaji': (context) => const SalarySettingsScreen(),
    '/pegawai-absen': (context) => const AttendanceDashboardScreen(),
    '/employee-attendance': (context) => const EmployeeAttendanceScreen(),
    '/laporan': (context) => const ReportScreen(),
    '/expense-list': (context) => const PengeluaranListScreen(),
    '/parfum-list': (context) => const ParfumListScreen(),
    '/diskon-list': (context) => const DiskonListScreen(),
    '/item-list': (context) => const InventoryScreen(),
    '/item-cuci-list': (context) => const ItemListScreen(),
    '/manage-outlet': (context) => const OutletListScreen(),
    '/notifications': (context) => const NotificationScreen(),
    '/kelola-role': (context) => const RoleListScreen(),
    '/aktivasi-akun': (context) => const AktivasiAkunScreen(),
    '/coin-management': (context) => const KoinManagementScreen(),
    '/addon-purchases': (context) => const PembelianSayaScreen(),
    '/referral': (context) => const ReferralPage(),
    '/finance-report': (context) => const FinanceReportScreen(),
    '/all-transactions': (context) => const AllTransactionsScreen(),
    '/service-report': (context) => const TransaksiPerLayananScreen(),
    '/customer-summary': (context) => const CustomerReportScreen(),
    '/customer-growth': (context) => const CustomerDetailReportScreen(),
    '/outlet-list': (context) => const OutletListScreen(),
    '/settings': (context) => const SettingScreen(),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == '/payment') {
      return MaterialPageRoute(builder: (context) => const PaymentPage());
    }
    return null;
  }
}
