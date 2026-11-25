package service

import "testing"

func TestIsProviderOutageMessage(t *testing.T) {
	tests := []struct {
		name    string
		message string
		want    bool
	}{
		{name: "fonnte device disconnected", message: "Device disconnected", want: true},
		{name: "localized disconnected device", message: "Device tidak terhubung", want: true},
		{name: "provider gateway timeout", message: "504 Gateway Timeout", want: true},
		{name: "number is not registered", message: "nomor belum terdaftar di WhatsApp", want: false},
		{name: "invalid target", message: "target phone is invalid", want: false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := isProviderOutageMessage(tt.message); got != tt.want {
				t.Fatalf("isProviderOutageMessage(%q) = %v, want %v", tt.message, got, tt.want)
			}
		})
	}
}
