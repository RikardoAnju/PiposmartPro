# Internal Data Ops Schema

## Tujuan
Skema ini diturunkan dari kebutuhan operasional utama:
- lead masuk terpusat
- assignment ke PIC
- follow-up history
- status history
- audit ledger

Desain ini sengaja dibuat sederhana untuk MVP, tapi tetap aman untuk dikembangkan ke phase berikutnya.

## Entitas Inti

### 1. `data_leads`
Tabel master untuk semua lead/prospect yang masuk.

Field:
- `dl_id` bigint unsigned primary key auto increment
- `dl_source` varchar(50) not null
- `dl_name` varchar(150) not null
- `dl_phone` varchar(30) null
- `dl_email` varchar(150) null
- `dl_location` varchar(150) null
- `dl_notes` text null
- `dl_status` varchar(30) not null default 'new'
- `dl_priority` tinyint not null default 0
- `dl_assigned_user` varchar(50) null
- `dl_assigned_team` varchar(50) null
- `dl_last_followup_at` datetime null
- `dl_next_followup_at` datetime null
- `dl_closed_at` datetime null
- `dl_created_by` varchar(50) null
- `dl_created_at` datetime not null default current_timestamp
- `dl_updated_at` datetime null on update current_timestamp

Index:
- index `idx_data_leads_status` on `dl_status`
- index `idx_data_leads_assigned_user` on `dl_assigned_user`
- index `idx_data_leads_source` on `dl_source`
- index `idx_data_leads_phone` on `dl_phone`

### 2. `data_lead_assignments`
Riwayat pembagian lead ke PIC.

Field:
- `dla_id` bigint unsigned primary key auto increment
- `dla_lead_id` bigint unsigned not null
- `dla_from_user` varchar(50) null
- `dla_to_user` varchar(50) not null
- `dla_team_id` varchar(50) null
- `dla_reason` varchar(100) null
- `dla_note` text null
- `dla_status` varchar(20) not null default 'active'
- `dla_assigned_at` datetime not null default current_timestamp
- `dla_released_at` datetime null

Index:
- index `idx_data_lead_assignments_lead` on `dla_lead_id`
- index `idx_data_lead_assignments_to_user` on `dla_to_user`
- index `idx_data_lead_assignments_status` on `dla_status`

### 3. `data_lead_followups`
Log aktivitas follow-up per lead.

Field:
- `dlf_id` bigint unsigned primary key auto increment
- `dlf_lead_id` bigint unsigned not null
- `dlf_user_id` varchar(50) not null
- `dlf_type` varchar(30) not null
- `dlf_result` varchar(30) not null
- `dlf_note` text null
- `dlf_attachment` text null
- `dlf_followup_at` datetime not null default current_timestamp
- `dlf_next_followup_at` datetime null
- `dlf_created_at` datetime not null default current_timestamp

Index:
- index `idx_data_lead_followups_lead` on `dlf_lead_id`
- index `idx_data_lead_followups_user` on `dlf_user_id`
- index `idx_data_lead_followups_created_at` on `dlf_created_at`

### 4. `data_lead_status_history`
Jejak perubahan status lead.

Field:
- `dls_id` bigint unsigned primary key auto increment
- `dls_lead_id` bigint unsigned not null
- `dls_old_status` varchar(30) null
- `dls_new_status` varchar(30) not null
- `dls_changed_by` varchar(50) not null
- `dls_note` text null
- `dls_created_at` datetime not null default current_timestamp

Index:
- index `idx_data_lead_status_history_lead` on `dls_lead_id`
- index `idx_data_lead_status_history_status` on `dls_new_status`
- index `idx_data_lead_status_history_created_at` on `dls_created_at`

### 5. `data_lead_ledger`
Tabel audit ringkas untuk semua kejadian penting.

Field:
- `dll_id` bigint unsigned primary key auto increment
- `dll_lead_id` bigint unsigned not null
- `dll_event_type` varchar(30) not null
- `dll_actor_id` varchar(50) not null
- `dll_actor_type` varchar(20) not null
- `dll_before` json null
- `dll_after` json null
- `dll_note` text null
- `dll_created_at` datetime not null default current_timestamp

Contoh `dll_event_type`:
- `created`
- `assigned`
- `reassigned`
- `followup_added`
- `status_changed`
- `closed`
- `reopened`

Index:
- index `idx_data_lead_ledger_lead` on `dll_lead_id`
- index `idx_data_lead_ledger_event_type` on `dll_event_type`
- index `idx_data_lead_ledger_created_at` on `dll_created_at`

### 6. `data_lead_sources`
Master referensi sumber lead.

Field:
- `dlsrc_id` bigint unsigned primary key auto increment
- `dlsrc_code` varchar(50) not null unique
- `dlsrc_name` varchar(100) not null
- `dlsrc_is_active` tinyint not null default 1
- `dlsrc_created_at` datetime not null default current_timestamp

Contoh seed:
- `new_download`
- `manual_input`
- `import`
- `campaign`
- `referral`

### 7. `data_lead_teams`
Opsional untuk grouping PIC.

Field:
- `dlt_id` bigint unsigned primary key auto increment
- `dlt_name` varchar(100) not null
- `dlt_code` varchar(50) not null unique
- `dlt_is_active` tinyint not null default 1
- `dlt_created_at` datetime not null default current_timestamp

### 8. `users`
Pakai tabel user internal yang sudah ada.

Minimal field yang dipakai oleh modul ini:
- `id`
- `name`
- `email`
- `role`
- `status`
- `team_id` jika ada

## Status Yang Disarankan

### Lead Status
- `new`
- `queued`
- `assigned`
- `contacted`
- `follow_up`
- `qualified`
- `won`
- `lost`
- `closed`
- `reassigned`

### Assignment Status
- `active`
- `released`
- `moved`

### Follow-up Result
- `attempted`
- `contacted`
- `no_answer`
- `interested`
- `not_interested`
- `callback`
- `closed`

### Event Type
- `created`
- `assigned`
- `reassigned`
- `followup_added`
- `status_changed`
- `closed`
- `reopened`

## Relasi
- `data_leads` 1..n `data_lead_assignments`
- `data_leads` 1..n `data_lead_followups`
- `data_leads` 1..n `data_lead_status_history`
- `data_leads` 1..n `data_lead_ledger`
- `data_lead_sources` 1..n `data_leads`
- `data_lead_teams` 1..n `data_lead_assignments`

## Aturan Bisnis
- Lead baru dibuat dengan status `new`.
- Assignment pertama mengubah status ke `assigned`.
- Follow-up pertama bisa mengubah status ke `contacted` atau `follow_up`.
- Reassignment tidak menghapus assignment lama.
- Closed lead tidak boleh hilang dari ledger.
- Setiap update status wajib menulis ke history.
- Ledger bersifat append-only.

## Query Dasar Yang Harus Didukung

### Dashboard Admin
- jumlah lead baru hari ini
- jumlah lead aktif per PIC
- jumlah lead per status
- jumlah follow-up hari ini
- lead yang belum di-follow-up

### Dashboard PIC
- lead aktif saya
- lead overdue follow-up
- follow-up hari ini
- status pipeline saya

### Audit
- riwayat assignment per lead
- riwayat follow-up per lead
- riwayat perubahan status per lead
- jejak siapa melakukan aksi terakhir

## Catatan Implementasi
- Untuk MVP, semua tabel bisa dibuat di satu schema database existing.
- Tidak perlu event sourcing penuh, tapi pola append-only harus dipertahankan untuk assignment, follow-up, dan status history.
- Kolom JSON di ledger dipakai untuk menyimpan before/after state tanpa membuat tabel audit terlalu lebar.

