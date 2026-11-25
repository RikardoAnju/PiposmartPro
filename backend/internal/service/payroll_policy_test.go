package service

import "testing"

func TestPayrollRequiresAttendance(t *testing.T) {
	tests := []struct {
		name       string
		salaryType string
		want       bool
	}{
		{name: "daily requires attendance", salaryType: "daily", want: true},
		{name: "daily is case insensitive", salaryType: " DAILY ", want: true},
		{name: "monthly remains payable", salaryType: "monthly", want: false},
		{name: "weekly remains payable", salaryType: "weekly", want: false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := payrollRequiresAttendance(tt.salaryType); got != tt.want {
				t.Fatalf("payrollRequiresAttendance(%q) = %v, want %v", tt.salaryType, got, tt.want)
			}
		})
	}
}
