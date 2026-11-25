import 'package:ayocucinew/shared/widgets/rupiah_input_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final formatter = RupiahThousandsInputFormatter();

  test('groups Rupiah digits and parses them without changing value', () {
    final result = formatter.formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(
        text: '98000',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );
    expect(result.text, '98.000');
    expect(result.selection.baseOffset, 6);
    expect(RupiahThousandsInputFormatter.parse(result.text), 98000);
  });

  test('pasted currency is normalized and caret stays near edited digit', () {
    final result = formatter.formatEditUpdate(
      const TextEditingValue(text: '100.000'),
      const TextEditingValue(
        text: 'Rp 120000',
        selection: TextSelection.collapsed(offset: 6),
      ),
    );
    expect(result.text, '120.000');
    expect(result.selection.baseOffset, 3);
    expect(RupiahThousandsInputFormatter.parse(result.text), 120000);
  });

  test('rejects values above maximum', () {
    const old = TextEditingValue(text: '999.999.999');
    final result = formatter.formatEditUpdate(
      old,
      const TextEditingValue(text: '1000000000'),
    );
    expect(result, old);
  });
}
