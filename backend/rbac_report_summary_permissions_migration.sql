-- Tambahkan permission laporan baru untuk role existing
-- read_home_summary: mengakses ringkasan home screen
-- read_daily_summary: mengakses ringkasan harian di dashboard laporan

UPDATE ac_role
SET rl_permission = JSON_ARRAY_APPEND(
    rl_permission,
    '$.laporan',
    'read_home_summary'
)
WHERE JSON_VALID(rl_permission)
  AND JSON_CONTAINS_PATH(rl_permission, 'one', '$.laporan')
  AND JSON_SEARCH(rl_permission, 'one', 'all', NULL, '$.laporan[*]') IS NULL
  AND JSON_SEARCH(rl_permission, 'one', 'read_home_summary', NULL, '$.laporan[*]') IS NULL
  AND (
    JSON_SEARCH(rl_permission, 'one', 'read_omset', NULL, '$.laporan[*]') IS NOT NULL
    OR JSON_SEARCH(rl_permission, 'one', 'read_pengeluaran', NULL, '$.laporan[*]') IS NOT NULL
    OR JSON_SEARCH(rl_permission, 'one', 'read_pendapatan', NULL, '$.laporan[*]') IS NOT NULL
    OR JSON_SEARCH(rl_permission, 'one', 'read_transaction', NULL, '$.laporan[*]') IS NOT NULL
  );

UPDATE ac_role
SET rl_permission = JSON_ARRAY_APPEND(
    rl_permission,
    '$.laporan',
    'read_daily_summary'
)
WHERE JSON_VALID(rl_permission)
  AND JSON_CONTAINS_PATH(rl_permission, 'one', '$.laporan')
  AND JSON_SEARCH(rl_permission, 'one', 'all', NULL, '$.laporan[*]') IS NULL
  AND JSON_SEARCH(rl_permission, 'one', 'read_daily_summary', NULL, '$.laporan[*]') IS NULL
  AND (
    JSON_SEARCH(rl_permission, 'one', 'read_omset', NULL, '$.laporan[*]') IS NOT NULL
    OR JSON_SEARCH(rl_permission, 'one', 'read_pengeluaran', NULL, '$.laporan[*]') IS NOT NULL
    OR JSON_SEARCH(rl_permission, 'one', 'read_pendapatan', NULL, '$.laporan[*]') IS NOT NULL
    OR JSON_SEARCH(rl_permission, 'one', 'read_profit_loss', NULL, '$.laporan[*]') IS NOT NULL
    OR JSON_SEARCH(rl_permission, 'one', 'read_transaction', NULL, '$.laporan[*]') IS NOT NULL
  );
