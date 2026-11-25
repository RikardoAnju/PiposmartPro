package service

import (
	"reflect"
	"testing"
	"time"
)

func TestFormatIncomeReportDatesUsesMySQLDateFormat(t *testing.T) {
	location := time.FixedZone("WIB", 7*60*60)
	values := []time.Time{
		time.Date(2026, time.October, 4, 0, 0, 0, 0, location),
		time.Date(2026, time.September, 28, 0, 0, 0, 0, location),
	}

	got := formatIncomeReportDates(values)
	want := []string{"2026-10-04", "2026-09-28"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("formatIncomeReportDates() = %v, want %v", got, want)
	}
}
