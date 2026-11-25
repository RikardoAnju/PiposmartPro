-- Cleanup orphan data after owner account deletions that previously did not cascade fully.
-- Target: development / maintenance usage.
-- Safe usage:
-- 1. Run the SELECT preview blocks first.
-- 2. Backup DB before DELETE.
-- 3. Execute inside a maintenance window.

-- Preview counts
SELECT 'ac_top_koin' AS table_name, COUNT(*) AS orphan_rows
FROM ac_top_koin tk
LEFT JOIN ac_outlet o ON o.ot_id = tk.tk_outlet
WHERE o.ot_id IS NULL
UNION ALL
SELECT 'ac_history_koin', COUNT(*)
FROM ac_history_koin hk
LEFT JOIN ac_outlet o ON o.ot_id = hk.hk_outlet
WHERE o.ot_id IS NULL
UNION ALL
SELECT 'ac_transaksi_addons', COUNT(*)
FROM ac_transaksi_addons ta
LEFT JOIN ac_outlet o ON o.ot_id = ta.ha_outlet
WHERE o.ot_id IS NULL
UNION ALL
SELECT 'ac_history_addons', COUNT(*)
FROM ac_history_addons ha
LEFT JOIN ac_outlet o ON o.ot_id = ha.ha_outlet
WHERE o.ot_id IS NULL
UNION ALL
SELECT 'ac_transaksi', COUNT(*)
FROM ac_transaksi t
LEFT JOIN ac_outlet o ON o.ot_id = t.tr_outlet
WHERE o.ot_id IS NULL
UNION ALL
SELECT 'ac_pelanggan', COUNT(*)
FROM ac_pelanggan p
LEFT JOIN ac_outlet o ON o.ot_id = p.pl_outlet
WHERE o.ot_id IS NULL
UNION ALL
SELECT 'ac_pengeluaran', COUNT(*)
FROM ac_pengeluaran p
LEFT JOIN ac_outlet o ON o.ot_id = p.pg_outlet
WHERE o.ot_id IS NULL
UNION ALL
SELECT 'ac_notif_receiver', COUNT(*)
FROM ac_notif_receiver nr
LEFT JOIN ac_outlet o ON o.ot_id = nr.nr_outlet
WHERE o.ot_id IS NULL
UNION ALL
SELECT 'ac_push_tokens', COUNT(*)
FROM ac_push_tokens pt
LEFT JOIN ac_outlet o ON o.ot_id = pt.pt_outlet
WHERE o.ot_id IS NULL
UNION ALL
SELECT 'ac_pegawai', COUNT(*)
FROM ac_pegawai pg
LEFT JOIN ac_outlet o ON o.ot_id = pg.pg_outlet
WHERE o.ot_id IS NULL
UNION ALL
SELECT 'ac_layanan', COUNT(*)
FROM ac_layanan ly
LEFT JOIN ac_outlet o ON o.ot_id = ly.ly_outlet
WHERE o.ot_id IS NULL
UNION ALL
SELECT 'ac_item', COUNT(*)
FROM ac_item it
LEFT JOIN ac_outlet o ON o.ot_id = it.it_outlet
WHERE o.ot_id IS NULL
UNION ALL
SELECT 'ac_parfum', COUNT(*)
FROM ac_parfum pf
LEFT JOIN ac_outlet o ON o.ot_id = pf.pf_outlet
WHERE o.ot_id IS NULL
UNION ALL
SELECT 'ac_metode_pembayaran', COUNT(*)
FROM ac_metode_pembayaran mp
LEFT JOIN ac_outlet o ON o.ot_id = mp.mp_outlet
WHERE o.ot_id IS NULL
UNION ALL
SELECT 'ac_kategori_pengeluaran', COUNT(*)
FROM ac_kategori_pengeluaran kp
LEFT JOIN ac_outlet o ON o.ot_id = kp.kp_outlet
WHERE o.ot_id IS NULL
UNION ALL
SELECT 'ac_role', COUNT(*)
FROM ac_role r
LEFT JOIN ac_outlet o ON o.ot_id = r.rl_outlet
WHERE o.ot_id IS NULL;

-- Preview transaction IDs whose parent outlet no longer exists
SELECT t.tr_id, t.tr_outlet, t.tr_created
FROM ac_transaksi t
LEFT JOIN ac_outlet o ON o.ot_id = t.tr_outlet
WHERE o.ot_id IS NULL
ORDER BY t.tr_created DESC;

-- Cleanup orphan transaction children first
START TRANSACTION;

DELETE dt
FROM ac_detail_transaksi dt
LEFT JOIN ac_transaksi t ON t.tr_id = dt.dt_transaksi
WHERE t.tr_id IS NULL;

DELETE it
FROM ac_item_transaksi it
LEFT JOIN ac_transaksi t ON t.tr_id = it.itr_transaksi
WHERE t.tr_id IS NULL;

DELETE dp
FROM ac_dp_transaksi dp
LEFT JOIN ac_transaksi t ON t.tr_id = dp.dptr_transaksi
WHERE t.tr_id IS NULL;

DELETE lt
FROM ac_log_transaksi lt
LEFT JOIN ac_transaksi t ON t.tr_id = lt.lr_transaksi
WHERE t.tr_id IS NULL;

DELETE dt
FROM ac_detail_transaksi_addons dt
LEFT JOIN ac_transaksi_addons ta ON ta.ha_id = dt.dha_transaksi
WHERE ta.ha_id IS NULL;

-- Cleanup rows whose outlet parent is gone
DELETE tk
FROM ac_top_koin tk
LEFT JOIN ac_outlet o ON o.ot_id = tk.tk_outlet
WHERE o.ot_id IS NULL;

DELETE hk
FROM ac_history_koin hk
LEFT JOIN ac_outlet o ON o.ot_id = hk.hk_outlet
WHERE o.ot_id IS NULL;

DELETE ta
FROM ac_transaksi_addons ta
LEFT JOIN ac_outlet o ON o.ot_id = ta.ha_outlet
WHERE o.ot_id IS NULL;

DELETE ha
FROM ac_history_addons ha
LEFT JOIN ac_outlet o ON o.ot_id = ha.ha_outlet
WHERE o.ot_id IS NULL;

DELETE t
FROM ac_transaksi t
LEFT JOIN ac_outlet o ON o.ot_id = t.tr_outlet
WHERE o.ot_id IS NULL;

DELETE p
FROM ac_pelanggan p
LEFT JOIN ac_outlet o ON o.ot_id = p.pl_outlet
WHERE o.ot_id IS NULL;

DELETE p
FROM ac_pengeluaran p
LEFT JOIN ac_outlet o ON o.ot_id = p.pg_outlet
WHERE o.ot_id IS NULL;

DELETE nr
FROM ac_notif_receiver nr
LEFT JOIN ac_outlet o ON o.ot_id = nr.nr_outlet
WHERE o.ot_id IS NULL;

DELETE pt
FROM ac_push_tokens pt
LEFT JOIN ac_outlet o ON o.ot_id = pt.pt_outlet
WHERE o.ot_id IS NULL;

DELETE pg
FROM ac_pegawai pg
LEFT JOIN ac_outlet o ON o.ot_id = pg.pg_outlet
WHERE o.ot_id IS NULL;

DELETE ly
FROM ac_layanan ly
LEFT JOIN ac_outlet o ON o.ot_id = ly.ly_outlet
WHERE o.ot_id IS NULL;

DELETE it
FROM ac_item it
LEFT JOIN ac_outlet o ON o.ot_id = it.it_outlet
WHERE o.ot_id IS NULL;

DELETE pf
FROM ac_parfum pf
LEFT JOIN ac_outlet o ON o.ot_id = pf.pf_outlet
WHERE o.ot_id IS NULL;

DELETE mp
FROM ac_metode_pembayaran mp
LEFT JOIN ac_outlet o ON o.ot_id = mp.mp_outlet
WHERE o.ot_id IS NULL;

DELETE kp
FROM ac_kategori_pengeluaran kp
LEFT JOIN ac_outlet o ON o.ot_id = kp.kp_outlet
WHERE o.ot_id IS NULL;

DELETE r
FROM ac_role r
LEFT JOIN ac_outlet o ON o.ot_id = r.rl_outlet
WHERE o.ot_id IS NULL;

COMMIT;

-- Final verification
SELECT 'ac_top_koin' AS table_name, COUNT(*) AS orphan_rows
FROM ac_top_koin tk
LEFT JOIN ac_outlet o ON o.ot_id = tk.tk_outlet
WHERE o.ot_id IS NULL
UNION ALL
SELECT 'ac_history_koin', COUNT(*)
FROM ac_history_koin hk
LEFT JOIN ac_outlet o ON o.ot_id = hk.hk_outlet
WHERE o.ot_id IS NULL
UNION ALL
SELECT 'ac_transaksi_addons', COUNT(*)
FROM ac_transaksi_addons ta
LEFT JOIN ac_outlet o ON o.ot_id = ta.ha_outlet
WHERE o.ot_id IS NULL
UNION ALL
SELECT 'ac_history_addons', COUNT(*)
FROM ac_history_addons ha
LEFT JOIN ac_outlet o ON o.ot_id = ha.ha_outlet
WHERE o.ot_id IS NULL
UNION ALL
SELECT 'ac_transaksi', COUNT(*)
FROM ac_transaksi t
LEFT JOIN ac_outlet o ON o.ot_id = t.tr_outlet
WHERE o.ot_id IS NULL;
