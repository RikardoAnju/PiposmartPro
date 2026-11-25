// Util murni untuk label satuan yang ditampilkan ke user.
//
// Konvensi: backend menyimpan satuan luas sebagai "m" (ternormalisasi), tapi
// SELURUH permukaan frontend menampilkannya sebagai "m²". Fungsi ini satu-satunya
// sumber kebenaran untuk konversi tampilan tersebut — pakai di mana pun satuan
// dirender ke layar/struk/laporan.
String displayUnitLabel(String unit) {
  final normalized = unit.trim().toLowerCase();
  if (normalized == 'm' || normalized == 'm2' || normalized == 'm²') {
    return 'm²';
  }
  return unit;
}
