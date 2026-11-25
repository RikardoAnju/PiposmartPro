-- Add Karyawan Performance addon
INSERT INTO ac_addons (ad_id, ad_addons, ad_link, ad_harga, ad_keterangan, ad_status, ad_created)
VALUES (
  'ADDON-PERF-001',
  'Karyawan Performance',
  'KARYAWAN_PERFORMANCE',
  25,
  'Akses performa dan analisis data karyawan secara mendalam.',
  1,
  NOW()
)
ON DUPLICATE KEY UPDATE ad_status = 1;
