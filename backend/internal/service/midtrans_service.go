package service

import (
	"fmt"
	"strings"
)

type MidtransService struct {
	koinSvc  *KoinService
	addonSvc *AddonService
}

func NewMidtransService(koin *KoinService, addon *AddonService) *MidtransService {
	return &MidtransService{
		koinSvc:  koin,
		addonSvc: addon,
	}
}

func (s *MidtransService) ProcessNotification(payload map[string]interface{}) error {
	orderID, ok := payload["order_id"].(string)
	if !ok {
		return fmt.Errorf("order_id not found in payload")
	}

	// 1. Prefix TK- -> Topup Koin
	if strings.HasPrefix(orderID, "TK-") {
		return s.koinSvc.ProcessMidtransNotification(payload)
	}

	// 2. Prefix HA- (Addon Eceran) atau PRO- (Aktivasi Outlet)
	if strings.HasPrefix(orderID, "HA-") || strings.HasPrefix(orderID, "PRO-") {
		return s.addonSvc.ProcessMidtransNotification(payload)
	}

	// Tambahkan prefix lain di sini jika nanti ada modul baru (misal: SMS- untuk beli kuota SMS)

	return fmt.Errorf("unknown order_id prefix: %s", orderID)
}