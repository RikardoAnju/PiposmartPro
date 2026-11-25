package model

import "time"

type PayrollItemSnapshot struct {
	ID              string     `gorm:"column:pis_id;primaryKey;size:36" json:"id"`
	ItemID          string     `gorm:"column:pis_item;size:36;uniqueIndex" json:"item_id"`
	OutletID        string     `gorm:"column:pis_outlet;size:20;index" json:"outlet_id"`
	PegawaiID       string     `gorm:"column:pis_pegawai;size:36;index" json:"pegawai_id"`
	PegawaiNama     string     `gorm:"column:pis_pegawai_nama;size:120" json:"pegawai_nama"`
	PegawaiEmail    string     `gorm:"column:pis_pegawai_email;size:120" json:"pegawai_email"`
	PegawaiNoHP     string     `gorm:"column:pis_pegawai_nohp;size:30" json:"pegawai_nohp"`
	RoleNama        string     `gorm:"column:pis_role_nama;size:100" json:"role_nama"`
	PeriodID        string     `gorm:"column:pis_period;size:36;index" json:"period_id"`
	PeriodLabel     string     `gorm:"column:pis_period_label;size:50" json:"period_label"`
	SalaryType      string     `gorm:"column:pis_salary_type;size:20" json:"salary_type"`
	BaseAmount      float64    `gorm:"column:pis_base_amount;default:0" json:"base_amount"`
	BonusAmount     float64    `gorm:"column:pis_bonus_amount;default:0" json:"bonus_amount"`
	DeductionAmount float64    `gorm:"column:pis_deduction_amount;default:0" json:"deduction_amount"`
	NetAmount       float64    `gorm:"column:pis_net_amount;default:0" json:"net_amount"`
	DueDate         time.Time  `gorm:"column:pis_due_date" json:"due_date"`
	Status          string     `gorm:"column:pis_status;size:20" json:"status"`
	PaymentMethod   *string    `gorm:"column:pis_payment_method;size:30" json:"payment_method,omitempty"`
	PaidAt          *time.Time `gorm:"column:pis_paid_at" json:"paid_at,omitempty"`
	ComponentsJSON  string     `gorm:"column:pis_components_json;type:longtext" json:"components_json"`
	Notes           *string    `gorm:"column:pis_notes;type:longtext" json:"notes,omitempty"`
	CreatedAt       time.Time  `gorm:"column:pis_created;autoCreateTime" json:"created_at"`
	UpdatedAt       *time.Time `gorm:"column:pis_lastupdate;autoUpdateTime" json:"updated_at"`
}

func (PayrollItemSnapshot) TableName() string { return "ac_payroll_item_snapshot" }
