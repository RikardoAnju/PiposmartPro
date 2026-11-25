CREATE TABLE IF NOT EXISTS ac_notif_templates (
    nt_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    nt_name VARCHAR(120) NOT NULL,
    nt_description VARCHAR(255) NOT NULL DEFAULT '',
    nt_title VARCHAR(180) NOT NULL,
    nt_message TEXT NOT NULL,
    nt_category VARCHAR(20) NOT NULL DEFAULT 'INFO',
    nt_target VARCHAR(80) NOT NULL DEFAULT 'notification_detail',
    nt_fallback_target VARCHAR(80) NOT NULL DEFAULT '',
    nt_cta_label VARCHAR(80) NOT NULL DEFAULT '',
    nt_is_active TINYINT(1) NOT NULL DEFAULT 1,
    nt_created_by VARCHAR(120) NOT NULL DEFAULT '',
    nt_updated_by VARCHAR(120) NOT NULL DEFAULT '',
    nt_created DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    nt_updated DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (nt_id),
    INDEX idx_notif_template_active (nt_is_active),
    UNIQUE KEY uq_notif_template_name (nt_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
