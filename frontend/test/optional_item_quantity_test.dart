import 'package:ayocucinew/providers/transaction_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('menyimpan ulang pilihan global tidak mereset jumlah item lama', () {
    final provider = TransactionProvider();
    provider.addOptionalItem('baju', 'Baju', qty: 2);
    provider.addOptionalItem('jaket', 'Jaket', qty: 4);
    provider.addOptionalItem('handuk', 'Handuk', qty: 3);
    provider.setOptionalItemKeterangan('jaket', 'Warna hitam');

    provider.replaceGlobalOptionalItemSelection([
      {'id': 'baju', 'name': 'Baju'},
      {'id': 'jaket', 'name': 'Jaket'},
      {'id': 'handuk', 'name': 'Handuk'},
      {'id': 'sprei', 'name': 'Sprei'},
    ]);

    final items = {
      for (final item in provider.globalOptionalItems) item.id: item,
    };
    expect(items['baju']?.qty, 2);
    expect(items['jaket']?.qty, 4);
    expect(items['jaket']?.keterangan, 'Warna hitam');
    expect(items['handuk']?.qty, 3);
    expect(items['sprei']?.qty, 1);
  });

  test('item yang tidak lagi dipilih dihapus tanpa memengaruhi item lain', () {
    final provider = TransactionProvider();
    provider.addOptionalItem('baju', 'Baju', qty: 2);
    provider.addOptionalItem('jaket', 'Jaket', qty: 4);

    provider.replaceGlobalOptionalItemSelection([
      {'id': 'jaket', 'name': 'Jaket'},
    ]);

    expect(provider.globalOptionalItems, hasLength(1));
    expect(provider.globalOptionalItems.single.id, 'jaket');
    expect(provider.globalOptionalItems.single.qty, 4);
  });
}
