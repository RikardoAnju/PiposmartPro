-- =========================================================
-- RBAC Migration for AyoCuci Admin Panel
-- Jalankan di MySQL: mysql -u [user] -p [database] < rbac_migration.sql
-- =========================================================

-- 1. Tambah kolom ke ac_admin
ALTER TABLE ac_admin ADD COLUMN IF NOT EXISTS adm_role VARCHAR(50) NULL;
ALTER TABLE ac_admin ADD COLUMN IF NOT EXISTS adm_is_master BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. Tandai akun master admin
UPDATE ac_admin SET adm_is_master = TRUE WHERE adm_id = 'ADM.000001';

-- 3. Buat tabel role admin baru
CREATE TABLE IF NOT EXISTS ac_admin_role (
    ar_id        VARCHAR(50)  NOT NULL PRIMARY KEY,
    ar_nama      VARCHAR(100) NOT NULL,
    ar_permissions TEXT       NOT NULL DEFAULT '{}',
    ar_created_by VARCHAR(12) NOT NULL,
    ar_created   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4. FK dari ac_admin ke ac_admin_role (opsional, bisa di-skip jika mau loose coupling)
-- ALTER TABLE ac_admin ADD CONSTRAINT fk_admin_role
--     FOREIGN KEY (adm_role) REFERENCES ac_admin_role(ar_id) ON DELETE SET NULL;

SELECT 'Migration RBAC berhasil!' AS status;
