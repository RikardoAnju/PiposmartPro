# Internal Data Ops API Surface

## Scope
API ini untuk MVP internal data kelolaan:
- lead management
- assignment
- follow-up logging
- status tracking
- history dan audit trail

## Prinsip Akses
- Admin bisa lihat semua data.
- PIC hanya bisa lihat data yang ditugaskan ke dirinya atau timnya.
- Semua endpoint mutating harus menulis ke ledger/history.

## Endpoint Inti

### Leads

`GET /admin/data-leads`
- list lead
- filter: `status`, `source`, `assigned_user`, `team`, `search`, `date_from`, `date_to`

`POST /admin/data-leads`
- create lead manual

`GET /admin/data-leads/:id`
- detail lead + history ringkas

`PATCH /admin/data-leads/:id`
- update data dasar lead

`POST /admin/data-leads/import`
- import batch lead

### Assignment

`POST /admin/data-leads/:id/assign`
- assign lead ke PIC
- body:
  - `to_user_id`
  - `team_id`
  - `reason`
  - `note`

`POST /admin/data-leads/:id/reassign`
- pindah PIC
- body:
  - `to_user_id`
  - `reason`
  - `note`

`POST /admin/data-leads/:id/release`
- lepas assignment aktif

### Follow-up

`GET /data-leads/:id/followups`
- list follow-up per lead

`POST /data-leads/:id/followups`
- tambah aktivitas follow-up
- body:
  - `type`
  - `result`
  - `note`
  - `next_follow_up_at`
  - `attachment`

### Status

`POST /data-leads/:id/status`
- ubah status lead
- body:
  - `status`
  - `note`

### Ledger / History

`GET /data-leads/:id/ledger`
- riwayat event lead

`GET /data-leads/:id/history`
- alias history lengkap

### Dashboard

`GET /admin/data-dashboard`
- total lead
- lead by status
- lead by PIC
- follow-up hari ini
- overdue follow-up

`GET /me/data-dashboard`
- lead aktif saya
- follow-up hari ini
- overdue follow-up
- status pipeline saya

## Response Pattern
Semua response pakai format konsisten:

```json
{
  "status": true,
  "message": "OK",
  "data": {}
}
```

## Event Yang Wajib Masuk Ledger
- lead created
- lead updated
- lead assigned
- lead reassigned
- follow-up added
- status changed
- lead released
- lead closed

## Kontrak Minimal Data Lead
```json
{
  "id": 123,
  "source": "new_download",
  "name": "Nadhiya",
  "phone": "0812xxxx",
  "email": "n@example.com",
  "location": "Jakarta",
  "status": "assigned",
  "priority": 1,
  "assigned_user": "U001",
  "assigned_team": "T01",
  "last_followup_at": "2026-07-06T10:00:00Z",
  "next_followup_at": "2026-07-07T10:00:00Z",
  "created_at": "2026-07-06T09:00:00Z"
}
```

## Kontrak Minimal Follow-up
```json
{
  "id": 10,
  "lead_id": 123,
  "user_id": "U001",
  "type": "call",
  "result": "contacted",
  "note": "Sudah dihubungi dan minta follow up besok",
  "next_follow_up_at": "2026-07-07T10:00:00Z",
  "created_at": "2026-07-06T10:00:00Z"
}
```

## Catatan Implementasi
- Endpoint admin dan PIC bisa dibagi ke route group yang berbeda.
- Hasil update status dan follow-up jangan overwrite data history.
- Untuk import batch, setiap row valid harus tetap bisa diproses walau ada row lain yang gagal.

