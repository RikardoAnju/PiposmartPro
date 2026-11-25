CREATE TABLE IF NOT EXISTS ac_lifecycle_events (
    le_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    le_event_id VARCHAR(80) NOT NULL,
    le_outlet VARCHAR(20) NOT NULL,
    le_actor_id VARCHAR(60) NOT NULL DEFAULT '',
    le_actor_type VARCHAR(20) NOT NULL DEFAULT '',
    le_event_name VARCHAR(60) NOT NULL,
    le_metadata JSON NOT NULL,
    le_occurred_at DATETIME(3) NOT NULL,
    le_created DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (le_id),
    UNIQUE KEY uq_lifecycle_event_id (le_event_id),
    INDEX idx_lifecycle_event_outlet (le_outlet),
    INDEX idx_lifecycle_event_name (le_event_name),
    INDEX idx_lifecycle_event_occurred (le_occurred_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ac_lifecycle_automation_runs (
    lar_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    lar_rule_key VARCHAR(60) NOT NULL,
    lar_outlet VARCHAR(20) NOT NULL,
    lar_source_event_id VARCHAR(80) NOT NULL DEFAULT '',
    lar_status VARCHAR(20) NOT NULL,
    lar_reason VARCHAR(255) NOT NULL DEFAULT '',
    lar_master_id VARCHAR(60) NOT NULL DEFAULT '',
    lar_converted_at DATETIME(3) NULL,
    lar_created DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    PRIMARY KEY (lar_id),
    INDEX idx_lifecycle_run_rule (lar_rule_key),
    INDEX idx_lifecycle_run_outlet (lar_outlet),
    INDEX idx_lifecycle_run_status (lar_status),
    INDEX idx_lifecycle_run_source (lar_source_event_id),
    INDEX idx_lifecycle_run_converted (lar_converted_at),
    INDEX idx_lifecycle_run_created (lar_created)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ac_lifecycle_automation_rules (
    laru_key VARCHAR(60) NOT NULL,
    laru_name VARCHAR(120) NOT NULL,
    laru_description VARCHAR(255) NOT NULL DEFAULT '',
    laru_is_active BOOLEAN NOT NULL DEFAULT TRUE,
    laru_delay_hours INT NOT NULL DEFAULT 0,
    laru_cooldown_hours INT NOT NULL DEFAULT 24,
    laru_threshold_value INT NOT NULL DEFAULT 0,
    laru_priority INT NOT NULL DEFAULT 50,
    laru_title VARCHAR(180) NOT NULL,
    laru_message TEXT NOT NULL,
    laru_cta_label VARCHAR(80) NOT NULL DEFAULT '',
    laru_target VARCHAR(80) NOT NULL,
    laru_quiet_start_hour INT NOT NULL DEFAULT 20,
    laru_quiet_end_hour INT NOT NULL DEFAULT 9,
    laru_updated_by VARCHAR(120) NOT NULL DEFAULT '',
    laru_created DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    laru_updated DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (laru_key),
    INDEX idx_lifecycle_rule_active (laru_is_active),
    INDEX idx_lifecycle_rule_priority (laru_priority)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
