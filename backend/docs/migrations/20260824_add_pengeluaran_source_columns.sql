-- Menandai pengeluaran yang berasal dari payroll agar flow edit/delete bisa dikunci
-- dari menu Pengeluaran dan tetap diarahkan ke menu Penggajian.

ALTER TABLE `ac_pengeluaran`
  ADD COLUMN IF NOT EXISTS `pg_source_type` varchar(30) NULL AFTER `pg_bukti`,
  ADD COLUMN IF NOT EXISTS `pg_source_id` varchar(50) NULL AFTER `pg_source_type`;
