package database

import (
	"encoding/json"
	"reflect"
	"testing"
)

func TestPermissionsWithoutDeleteExpandsAllSafely(t *testing.T) {
	raw := json.RawMessage(`{
		"transaksi":["all"],
		"pelanggan":["all"],
		"laporan":["all"]
	}`)

	got, changed := permissionsWithoutDelete(raw)
	if !changed {
		t.Fatal("expected legacy all permission to be migrated")
	}

	wantTransaction := []string{"create", "read", "update", "update_status", "update_delivery_fee"}
	if !reflect.DeepEqual(got["transaksi"], wantTransaction) {
		t.Fatalf("unexpected transaction permissions: %#v", got["transaksi"])
	}
	if containsString(got["pelanggan"], "delete") || containsString(got["laporan"], "delete") {
		t.Fatalf("delete permission must be disabled: %#v", got)
	}
	if containsString(got["transaksi"], "all") || containsString(got["pelanggan"], "all") {
		t.Fatalf("all wildcard must be expanded: %#v", got)
	}
}

func TestPermissionsWithoutDeletePreservesOtherOwnerChoices(t *testing.T) {
	raw := json.RawMessage(`{"pelanggan":["read","update","delete"],"item":["read"]}`)

	got, changed := permissionsWithoutDelete(raw)
	if !changed {
		t.Fatal("expected delete permission to be removed")
	}
	if !reflect.DeepEqual(got["pelanggan"], []string{"read", "update"}) {
		t.Fatalf("unexpected customer permissions: %#v", got["pelanggan"])
	}
	if !reflect.DeepEqual(got["item"], []string{"read"}) {
		t.Fatalf("unrelated permissions changed: %#v", got["item"])
	}
}

func containsString(values []string, target string) bool {
	for _, value := range values {
		if value == target {
			return true
		}
	}
	return false
}
