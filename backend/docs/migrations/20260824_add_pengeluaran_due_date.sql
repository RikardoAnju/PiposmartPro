-- Menyimpan jadwal bayar payroll secara terpisah dari tanggal aktual pembayaran.
-- `pg_tanggal` tetap dipakai sebagai tanggal pembayaran aktual agar kompatibel
-- dengan laporan lama, sedangkan `pg_due_date` dipakai untuk mendeteksi telat bayar.

ALTER TABLE `ac_pengeluaran`
  ADD COLUMN IF NOT EXISTS `pg_due_date` datetime(3) NULL AFTER `pg_tanggal`;
