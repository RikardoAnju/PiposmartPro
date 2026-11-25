ALTER TABLE ac_notif_master
    ADD COLUMN IF NOT EXISTS nm_type VARCHAR(80) NOT NULL DEFAULT 'announcement' AFTER nm_image_url,
    ADD COLUMN IF NOT EXISTS nm_payload JSON NULL AFTER nm_type,
    ADD COLUMN IF NOT EXISTS nm_cta_label VARCHAR(80) NOT NULL DEFAULT '' AFTER nm_payload,
    ADD COLUMN IF NOT EXISTS nm_schema_version INT NOT NULL DEFAULT 1 AFTER nm_cta_label,
    ADD COLUMN IF NOT EXISTS nm_source VARCHAR(20) NOT NULL DEFAULT 'SYSTEM' AFTER nm_schema_version;

UPDATE ac_notif_master
SET nm_payload = JSON_OBJECT(
    'schema_version', 1,
    'notification_type', 'legacy_notification',
    'target', 'notification_detail',
    'category', nm_kategori,
    'master_id', nm_id
)
WHERE nm_payload IS NULL;

CREATE TABLE IF NOT EXISTS ac_notif_events (
    ne_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    ne_nm_id VARCHAR(60) NOT NULL,
    ne_outlet VARCHAR(20) NOT NULL,
    ne_actor_id VARCHAR(60) NOT NULL DEFAULT '',
    ne_actor_type VARCHAR(20) NOT NULL DEFAULT '',
    ne_event_type VARCHAR(40) NOT NULL,
    ne_target VARCHAR(80) NOT NULL DEFAULT '',
    ne_reason VARCHAR(255) NOT NULL DEFAULT '',
    ne_platform VARCHAR(20) NOT NULL DEFAULT '',
    ne_app_version VARCHAR(30) NOT NULL DEFAULT '',
    ne_created DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (ne_id),
    INDEX idx_notif_event_master (ne_nm_id),
    INDEX idx_notif_event_outlet (ne_outlet),
    INDEX idx_notif_event_type (ne_event_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
