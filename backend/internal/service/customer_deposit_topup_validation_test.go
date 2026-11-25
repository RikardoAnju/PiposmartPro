package service

import "testing"

func TestTopUpRejectsCashAboveRupiahDepositValue(t *testing.T) {
	svc := NewCustomerDepositService(nil)

	_, err := svc.TopUp(
		"customer-id",
		"outlet-id",
		"actor-id",
		"user",
		"request-id",
		"RUPIAH",
		"payment-method-id",
		"",
		100000,
		110000,
		0,
	)

	if err == nil {
		t.Fatal("expected cash above Rupiah deposit value to be rejected")
	}
	const expected = "kas diterima tidak boleh melebihi nominal deposit"
	if err.Error() != expected {
		t.Fatalf("expected %q, got %q", expected, err.Error())
	}
}

func TestTopUpRejectsUnexplainedRupiahDifference(t *testing.T) {
	svc := NewCustomerDepositService(nil)

	_, err := svc.TopUp(
		"customer-id", "outlet-id", "actor-id", "user", "request-id",
		"RUPIAH", "payment-method-id", "", 100000, 80000, 0,
	)

	if err == nil {
		t.Fatal("expected an unexplained Rupiah difference to be rejected")
	}
	const expected = "kas diterima ditambah diskon harus sama dengan nominal deposit"
	if err.Error() != expected {
		t.Fatalf("expected %q, got %q", expected, err.Error())
	}
}

func TestTopUpRejectsNegativeDiscount(t *testing.T) {
	svc := NewCustomerDepositService(nil)

	_, err := svc.TopUp(
		"customer-id", "outlet-id", "actor-id", "user", "request-id",
		"RUPIAH", "payment-method-id", "", 100000, 100000, -1,
	)

	if err == nil || err.Error() != "nilai deposit tidak valid" {
		t.Fatalf("expected negative discount rejection, got %v", err)
	}
}
