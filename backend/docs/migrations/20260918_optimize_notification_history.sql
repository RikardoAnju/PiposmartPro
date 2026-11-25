CREATE INDEX idx_notif_receiver_master_status
    ON ac_notif_receiver (nr_nm_id, nr_status);

CREATE INDEX idx_notif_event_master_type
    ON ac_notif_events (ne_nm_id, ne_event_type);
