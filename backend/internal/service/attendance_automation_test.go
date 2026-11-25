package service

import (
	"testing"
	"time"

	"github.com/RikardoAnju/PiposmartPro/internal/model"
)

func intPtr(value int) *int { return &value }

func TestAttendanceShiftEndAt(t *testing.T) {
	loc := time.FixedZone("WIB", 7*60*60)
	workDate := time.Date(2026, time.October, 8, 0, 0, 0, 0, loc)
	cfg := model.AttendanceConfiguration{
		StartHour: 8,
		EndHour:   17,
	}

	tests := []struct {
		name  string
		shift AttendanceShift
		want  time.Time
	}{
		{
			name: "same day shift",
			shift: AttendanceShift{
				StartHour: intPtr(8),
				EndHour:   intPtr(17),
			},
			want: time.Date(2026, time.October, 8, 17, 0, 0, 0, loc),
		},
		{
			name: "overnight shift ends next day",
			shift: AttendanceShift{
				StartHour: intPtr(22),
				EndHour:   intPtr(17),
			},
			want: time.Date(2026, time.October, 9, 17, 0, 0, 0, loc),
		},
		{
			name: "equal time is a full overnight window",
			shift: AttendanceShift{
				StartHour: intPtr(22),
				EndHour:   intPtr(22),
			},
			want: time.Date(2026, time.October, 9, 22, 0, 0, 0, loc),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := attendanceShiftEndAt(workDate, cfg, tt.shift); !got.Equal(tt.want) {
				t.Fatalf("attendanceShiftEndAt() = %s, want %s", got, tt.want)
			}
		})
	}
}
