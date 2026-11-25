package model

import "time"

type SalaryConfig struct {
	ID           string     `gorm:"column:spc_id;primaryKey;size:36" json:"id"`
	OutletID     string     `gorm:"column:spc_outlet;size:20;index" json:"outlet_id"`
	PegawaiID    string     `gorm:"column:spc_pegawai;size:36;index" json:"pegawai_id"`
	SalaryType   string     `gorm:"column:spc_salary_type;size:20;default:'monthly'" json:"salary_type"`
	Amount       float64    `gorm:"column:spc_amount;default:0" json:"amount"`
	ScheduleType string     `gorm:"column:spc_schedule_type;size:30;default:'fixed_date'" json:"schedule_type"`
	PayDay       *int       `gorm:"column:spc_pay_day" json:"pay_day"`
	PayDayName   *string    `gorm:"column:spc_pay_day_name;size:20" json:"pay_day_name"`
	PayEveryDays *int       `gorm:"column:spc_pay_every_days" json:"pay_every_days"`
	IsActive     int        `gorm:"column:spc_is_active;default:1" json:"is_active"`
	CreatedAt    time.Time  `gorm:"column:spc_created;autoCreateTime" json:"created_at"`
	UpdatedAt    *time.Time `gorm:"column:spc_lastupdate;autoUpdateTime" json:"updated_at"`
	Pegawai      *Pegawai   `gorm:"foreignKey:PegawaiID;references:ID" json:"pegawai,omitempty"`
}

func (SalaryConfig) TableName() string { return "ac_salary_config" }

type PayrollPeriod struct {
	ID        string     `gorm:"column:pp_id;primaryKey;size:36" json:"id"`
	OutletID  string     `gorm:"column:pp_outlet;size:20;index" json:"outlet_id"`
	Month     int        `gorm:"column:pp_month;index" json:"month"`
	Year      int        `gorm:"column:pp_year;index" json:"year"`
	StartDate time.Time  `gorm:"column:pp_start_date" json:"start_date"`
	EndDate   time.Time  `gorm:"column:pp_end_date" json:"end_date"`
	Status    string     `gorm:"column:pp_status;size:20;default:'draft'" json:"status"`
	CreatedAt time.Time  `gorm:"column:pp_created;autoCreateTime" json:"created_at"`
	UpdatedAt *time.Time `gorm:"column:pp_lastupdate;autoUpdateTime" json:"updated_at"`
}

func (PayrollPeriod) TableName() string { return "ac_payroll_period" }

type PayrollItem struct {
	ID              string     `gorm:"column:pi_id;primaryKey;size:36" json:"id"`
	OutletID        string     `gorm:"column:pi_outlet;size:20;index" json:"outlet_id"`
	PeriodID        string     `gorm:"column:pi_period;size:36;index" json:"period_id"`
	PegawaiID       string     `gorm:"column:pi_pegawai;size:36;index" json:"pegawai_id"`
	SalaryType      string     `gorm:"column:pi_salary_type;size:20" json:"salary_type"`
	BaseAmount      float64    `gorm:"column:pi_base_amount;default:0" json:"base_amount"`
	WorkDays        int        `gorm:"column:pi_work_days;default:0" json:"work_days"`
	OvertimeMinutes int        `gorm:"column:pi_overtime_minutes;default:0" json:"overtime_minutes"`
	AlfaDays        int        `gorm:"column:pi_alfa_days;default:0" json:"alfa_days"`
	BonusAmount     float64    `gorm:"column:pi_bonus_amount;default:0" json:"bonus_amount"`
	DeductionAmount float64    `gorm:"column:pi_deduction_amount;default:0" json:"deduction_amount"`
	NetAmount       float64    `gorm:"column:pi_net_amount;default:0" json:"net_amount"`
	DueDate         time.Time  `gorm:"column:pi_due_date" json:"due_date"`
	Status          string     `gorm:"column:pi_status;size:20;default:'unpaid'" json:"status"`
	PaymentMethod   *string    `gorm:"column:pi_payment_method;size:30" json:"payment_method"`
	PaidAt          *time.Time `gorm:"column:pi_paid_at" json:"paid_at"`
	Notes           *string    `gorm:"column:pi_notes" json:"notes"`
	CreatedAt       time.Time  `gorm:"column:pi_created;autoCreateTime" json:"created_at"`
	UpdatedAt       *time.Time `gorm:"column:pi_lastupdate;autoUpdateTime" json:"updated_at"`
	Pegawai         *Pegawai   `gorm:"foreignKey:PegawaiID;references:ID" json:"pegawai,omitempty"`
}

func (PayrollItem) TableName() string { return "ac_payroll_item" }

type PayrollItemComponent struct {
	ID        string    `gorm:"column:pic_id;primaryKey;size:36" json:"id"`
	ItemID    string    `gorm:"column:pic_item;size:36;index" json:"item_id"`
	Type      string    `gorm:"column:pic_type;size:20" json:"type"`
	Name      string    `gorm:"column:pic_name;size:100" json:"name"`
	Amount    float64   `gorm:"column:pic_amount;default:0" json:"amount"`
	Source    string    `gorm:"column:pic_source;size:50" json:"source"`
	CreatedAt time.Time `gorm:"column:pic_created;autoCreateTime" json:"created_at"`
}

func (PayrollItemComponent) TableName() string { return "ac_payroll_item_component" }

type PayrollPayment struct {
	ID            string    `gorm:"column:pay_id;primaryKey;size:36" json:"id"`
	OutletID      string    `gorm:"column:pay_outlet;size:20;index" json:"outlet_id"`
	PeriodID      string    `gorm:"column:pay_period;size:36;index" json:"period_id"`
	TotalAmount   float64   `gorm:"column:pay_total_amount;default:0" json:"total_amount"`
	PaymentMethod string    `gorm:"column:pay_payment_method;size:30" json:"payment_method"`
	ReferenceNo   *string   `gorm:"column:pay_reference_no;size:80" json:"reference_no"`
	PaidBy        *string   `gorm:"column:pay_paid_by;size:50" json:"paid_by"`
	PaidAt        time.Time `gorm:"column:pay_paid_at" json:"paid_at"`
	Status        string    `gorm:"column:pay_status;size:20;default:'success'" json:"status"`
	CreatedAt     time.Time `gorm:"column:pay_created;autoCreateTime" json:"created_at"`
}

func (PayrollPayment) TableName() string { return "ac_payroll_payment" }
