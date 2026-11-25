package service

import "testing"

func TestCalculateDepositAdjustment(t *testing.T) {
	tests := []struct {
		name, kind                 string
		value, paid, current, cash float64
		balance                    float64
		wantValue, wantCash        float64
		wantError                  bool
	}{
		{"correct overstatement", "CORRECTION", 100000, 90000, 120000, 110000, 120000, -20000, -20000, false},
		{"refund unspent", "REFUND", 50000, 45000, 100000, 90000, 100000, -50000, -45000, false},
		{"spent balance", "REFUND", 50000, 45000, 100000, 90000, 20000, 0, 0, true},
		{"exceeds topup", "REFUND", 120000, 90000, 100000, 90000, 200000, 0, 0, true},
		{"no change", "CORRECTION", 100000, 90000, 100000, 90000, 100000, 0, 0, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			value, cash, err := calculateDepositAdjustment(tt.kind, tt.value, tt.paid, tt.current, tt.cash, tt.balance)
			if (err != nil) != tt.wantError || value != tt.wantValue || cash != tt.wantCash {
				t.Fatalf("got delta=(%v,%v) error=%v; want delta=(%v,%v) error=%v", value, cash, err, tt.wantValue, tt.wantCash, tt.wantError)
			}
		})
	}
}

func TestValidDepositPrecision(t *testing.T) {
	tests := []struct {
		typ         string
		value, paid float64
		want        bool
	}{
		{"RUPIAH", 10000, 9000, true},
		{"RUPIAH", 10000.5, 9000, false},
		{"KG", 10.25, 50000, true},
		{"KG", 10.255, 50000, false},
		{"KG", 10.25, 50000.5, false},
	}
	for _, tt := range tests {
		if got := validDepositPrecision(tt.typ, tt.value, tt.paid); got != tt.want {
			t.Errorf("precision(%s, %v, %v) = %v, want %v", tt.typ, tt.value, tt.paid, got, tt.want)
		}
	}
}
