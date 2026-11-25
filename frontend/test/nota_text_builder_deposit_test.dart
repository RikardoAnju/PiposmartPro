import 'package:ayocucinew/shared/widgets/nota_text_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id'));

  String build(Map<String, dynamic> snapshot) {
    return NotaTextBuilder.buildForWhatsApp(
      snapshot: snapshot,
      customer: null,
      showKasir: true,
      showKeterangan: true,
      footer: '',
      outletName: 'Laundry Test',
      outletAddress: '',
      kontakOutlet: '',
    );
  }

  Map<String, dynamic> baseSnapshot() => {
    'tr_id': 'TRX/TEST',
    'tr_total': 6000,
    'tr_status_pembayaran': 'Lunas',
    'created_at': '2026-10-05T13:26:00+07:00',
    'details': [
      {
        'dtr_nama_layanan': 'Cuci Kiloan Reguler',
        'dtr_qty': 1,
        'dtr_satuan': 'Kg',
        'dtr_subtotal': 6000,
      },
    ],
  };

  test('nota transaksi baru menampilkan pemakaian deposit Rupiah', () {
    final snapshot = baseSnapshot()
      ..['payment_method'] = {'id': 'DEPOSIT_RUPIAH', 'name': 'Deposit Rupiah'};

    final text = build(snapshot);

    expect(text, contains('Metode     : Deposit Rupiah'));
    expect(text, contains('Deposit    : Rp6.000'));
  });

  test('nota dari detail menampilkan jumlah Kg dari ledger deposit', () {
    final snapshot = baseSnapshot()
      ..['payment_history_full'] = [
        {
          'metode_pembayaran_id': 'DEPOSIT_KG',
          'jumlah_dp': 6000,
          'deposit_usage_amount': 1.5,
        },
      ];

    final text = build(snapshot);

    expect(text, contains('Metode     : Deposit Kg'));
    expect(text, contains('Deposit    : 1,5 Kg'));
  });
}
