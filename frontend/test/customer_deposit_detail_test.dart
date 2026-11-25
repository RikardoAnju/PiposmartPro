import 'package:ayocucinew/data/models/customer_deposit_model.dart';
import 'package:ayocucinew/data/models/customer_model.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/providers/customer_deposit_provider.dart';
import 'package:ayocucinew/screens/operational/customer/customer_deposit_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

class _DepositProvider extends CustomerDepositProvider {
  @override
  Future<Map<String, dynamic>> adjustmentState(
    String customerId,
    String topupId,
  ) async => {
    'original_value': 100000,
    'original_paid': 95000,
    'current_value': 10000,
    'current_paid': 15000,
    'adjustment_count': 2,
    'events': [
      {
        'kind': 'REFUND',
        'value_delta': -100000,
        'cash_delta': -80000,
        'payment_method': 'Tunai / Cash',
        'note': 'Pengembalian',
        'created_by_name': 'Admin',
        'created_at': '2026-09-28T14:14:51+07:00',
      },
      {
        'kind': 'CORRECTION',
        'value_delta': 10000,
        'cash_delta': 0,
        'payment_method': 'QRIS',
        'note': 'Koreksi saldo',
        'created_by_name': 'Admin',
        'created_at': '2026-09-28T14:20:34+07:00',
      },
    ],
  };
}

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  final customer = Customer(
    id: 'customer-1',
    outletId: 'outlet-1',
    kode: '001',
    name: 'liza',
    phone: '',
    gender: '',
    address: '',
    status: 1,
  );

  Future<void> showDetail(
    WidgetTester tester,
    CustomerDepositLedgerEntry entry,
  ) async {
    tester.view.physicalSize = const Size(450, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CustomerDepositProvider>(
            create: (_) => _DepositProvider(),
          ),
          ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ],
        child: MaterialApp(
          home: CustomerDepositDetailScreen(customer: customer, entry: entry),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('top up separates credited balance from cash received', (
    tester,
  ) async {
    await showDetail(
      tester,
      CustomerDepositLedgerEntry(
        entryType: 'TOP_UP',
        depositType: 'RUPIAH',
        referenceId: 'topup-1',
        note: '',
        paymentMethod: 'QRIS',
        createdBy: '',
        createdByName: 'Admin',
        createdByType: 'user',
        amount: 100000,
        paidAmount: 95000,
        balanceBefore: 0,
        balanceAfter: 100000,
        createdAt: DateTime(2026, 9, 28, 14, 8),
      ),
    );

    expect(find.text('Saldo deposit bertambah'), findsOneWidget);
    expect(find.text('Uang diterima'), findsOneWidget);
    expect(find.text('+Rp95.000'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Total uang bersih rangkaian ini'),
      250,
    );
    expect(find.text('Rp15.000'), findsOneWidget);
    expect(find.text('Riwayat top up ini'.toUpperCase()), findsOneWidget);
  });

  testWidgets('cashless correction does not imply money was paid', (
    tester,
  ) async {
    await showDetail(
      tester,
      CustomerDepositLedgerEntry(
        entryType: 'CORRECTION',
        depositType: 'KG',
        referenceId: 'adjustment-1',
        note: 'Koreksi saldo',
        paymentMethod: 'QRIS',
        createdBy: '',
        createdByName: 'Admin',
        createdByType: 'user',
        amount: -4,
        paidAmount: 0,
        balanceBefore: 7.64,
        balanceAfter: 3.64,
        createdAt: DateTime(2026, 9, 28, 12, 1),
      ),
    );

    expect(find.text('Saldo deposit berkurang'), findsOneWidget);
    expect(find.text('-4 Kg'), findsOneWidget);
    expect(find.text('Tidak ada perpindahan uang'), findsOneWidget);
    expect(find.text('Uang diterima'), findsNothing);
  });

  testWidgets('refund shows both balance reduction and cash leaving', (
    tester,
  ) async {
    await showDetail(
      tester,
      CustomerDepositLedgerEntry(
        entryType: 'REFUND',
        depositType: 'RUPIAH',
        referenceId: 'adjustment-2',
        note: 'Pengembalian',
        paymentMethod: 'Tunai / Cash',
        createdBy: '',
        createdByName: 'Admin',
        createdByType: 'user',
        amount: 100000,
        paidAmount: -80000,
        balanceBefore: 100000,
        balanceAfter: 0,
        createdAt: DateTime(2026, 9, 28, 14, 14),
      ),
    );

    expect(find.text('-Rp100.000'), findsOneWidget);
    expect(find.text('Uang dikembalikan'), findsOneWidget);
    expect(find.text('-Rp80.000'), findsOneWidget);
    expect(find.text('Tunai / Cash'), findsOneWidget);
  });

  testWidgets('cash-only correction keeps deposit unchanged', (tester) async {
    await showDetail(
      tester,
      CustomerDepositLedgerEntry(
        entryType: 'CORRECTION',
        depositType: 'RUPIAH',
        referenceId: 'adjustment-3',
        note: 'Koreksi kas',
        paymentMethod: 'QRIS',
        createdBy: '',
        createdByName: 'Admin',
        createdByType: 'user',
        amount: 0,
        paidAmount: 5000,
        balanceBefore: 10000,
        balanceAfter: 10000,
        createdAt: DateTime(2026, 9, 28, 14, 20),
      ),
    );

    expect(find.text('Saldo deposit tidak berubah'), findsOneWidget);
    expect(find.text('Uang diterima'), findsOneWidget);
    expect(find.text('+Rp5.000'), findsOneWidget);
  });
}
