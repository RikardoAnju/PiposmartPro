package notifier

import "testing"

func TestNormalizedNotificationPayloadTargets(t *testing.T) {
	tests := []struct {
		name     string
		category string
		payload  map[string]interface{}
		want     string
	}{
		{name: "coin topup detail", category: "KOIN", payload: map[string]interface{}{"topup_id": "TOP-1"}, want: "coin_topup_detail"},
		{name: "coin management", category: "KOIN", payload: map[string]interface{}{}, want: "coin_management"},
		{name: "addon purchases", category: "ADDON", payload: map[string]interface{}{}, want: "addon_purchases"},
		{name: "referral", category: "REFERRAL", payload: map[string]interface{}{}, want: "referral_dashboard"},
		{name: "activation action", category: "SISTEM", payload: map[string]interface{}{"action": "aktivasi_pro"}, want: "pro_activation"},
		{name: "explicit target wins", category: "SISTEM", payload: map[string]interface{}{"target": "report_dashboard"}, want: "report_dashboard"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			result := normalizedNotificationPayload(test.category, "NOTIF-1", test.payload)
			if got := result["target"]; got != test.want {
				t.Fatalf("target = %v, want %s", got, test.want)
			}
			if result["master_id"] != "NOTIF-1" {
				t.Fatalf("master_id was not normalized")
			}
			if result["schema_version"] != notificationSchemaVersion {
				t.Fatalf("schema_version was not normalized")
			}
		})
	}
}
