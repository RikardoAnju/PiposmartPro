package notifier

import (
	"github.com/RikardoAnju/PiposmartPro/internal/database"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/push"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"gorm.io/gorm"
)

const notificationSchemaVersion = 1

func normalizedNotificationPayload(category, masterID string, payload map[string]interface{}) map[string]interface{} {
	result := map[string]interface{}{}
	for key, value := range payload {
		result[key] = value
	}
	result["category"] = category
	result["master_id"] = masterID
	result["schema_version"] = notificationSchemaVersion
	if _, ok := result["target"]; !ok {
		result["target"] = defaultNotificationTarget(category, result)
	}
	if _, ok := result["notification_type"]; !ok {
		result["notification_type"] = strings.ToLower(category) + "_notification"
	}
	return result
}

func defaultNotificationTarget(category string, payload map[string]interface{}) string {
	action := strings.ToLower(strings.TrimSpace(fmt.Sprint(payload["action"])))
	if action == "aktivasi_pro" {
		return "pro_activation"
	}
	if action == "topup_koin" {
		return "coin_management"
	}
	switch strings.ToUpper(category) {
	case "KOIN":
		if _, ok := payload["topup_id"]; ok {
			return "coin_topup_detail"
		}
		return "coin_management"
	case "ADDON":
		if _, ok := payload["id"]; ok {
			return "addon_purchase_detail"
		}
		return "addon_purchases"
	case "REFERRAL":
		if _, ok := payload["payout_id"]; ok {
			return "referral_payout_detail"
		}
		return "referral_dashboard"
	default:
		return "notification_detail"
	}
}

func notificationMasterPayload(payload map[string]interface{}) []byte {
	encoded, err := json.Marshal(payload)
	if err != nil {
		return []byte("{}")
	}
	return encoded
}

func notificationPayloadString(payload map[string]interface{}, key, fallback string) string {
	value, ok := payload[key]
	if !ok || value == nil {
		return fallback
	}
	cleaned := strings.TrimSpace(fmt.Sprint(value))
	if cleaned == "" || cleaned == "<nil>" {
		return fallback
	}
	return cleaned
}

func CreateOutletNotification(tx *gorm.DB, outletID, category, title, message string, payload map[string]interface{}) error {
	return createOutletNotification(tx, outletID, category, title, message, payload, true)
}

func CreateOutletNotificationWithoutPush(tx *gorm.DB, outletID, category, title, message string, payload map[string]interface{}) error {
	return createOutletNotification(tx, outletID, category, title, message, payload, false)
}

func CreateOwnerNotification(tx *gorm.DB, outlet model.Outlet, category, title, message string, payload map[string]interface{}) error {
	if strings.TrimSpace(outlet.ID) == "" || outlet.UserID == 0 {
		return nil
	}
	category = strings.ToUpper(utils.CleanNotificationText(category, "SISTEM"))
	title = utils.CleanNotificationText(title, "Notifikasi AyoCuci")
	message = utils.CleanNotificationText(message, "Ada informasi baru dari AyoCuci.")
	masterID := utils.GenNotifID()
	normalizedPayload := normalizedNotificationPayload(category, masterID, payload)
	normalizedPayload["outlet_id"] = outlet.ID
	normalizedPayload["owner_only"] = true
	master := model.NotifMaster{
		ID: masterID, Kategori: category, Judul: title, Pesan: message,
		Type:          notificationPayloadString(normalizedPayload, "notification_type", "announcement"),
		Payload:       notificationMasterPayload(normalizedPayload),
		CTALabel:      notificationPayloadString(normalizedPayload, "cta_label", ""),
		SchemaVersion: notificationSchemaVersion, Source: "SYSTEM", UserUpdate: "SYSTEM",
	}
	if err := tx.Create(&master).Error; err != nil {
		return err
	}
	ownerID := fmt.Sprint(outlet.UserID)
	receiver := model.NotifReceiver{
		MasterID: masterID, OutletID: outlet.ID, Status: 0,
		RecipientActorID: ownerID, RecipientActorType: "user",
	}
	if err := tx.Create(&receiver).Error; err != nil {
		return err
	}
	database.InvalidateCache(fmt.Sprintf("notif:list:%s", outlet.ID), fmt.Sprintf("notif:unread:%s", outlet.ID))
	var tokens []string
	tx.Model(&model.PushToken{}).Distinct("pt_token").
		Where("pt_is_active = ? AND pt_outlet = ? AND pt_actor_type = ? AND pt_actor_id = ?", true, outlet.ID, "user", ownerID).
		Pluck("pt_token", &tokens)
	push.SendNotificationToTokens(context.Background(), tokens, title, message, stringifyPushData(normalizedPayload))
	return nil
}

func createOutletNotification(tx *gorm.DB, outletID, category, title, message string, payload map[string]interface{}, sendPush bool) error {
	if strings.TrimSpace(outletID) == "" {
		return nil
	}

	category = strings.ToUpper(utils.CleanNotificationText(category, "SISTEM"))
	title = utils.CleanNotificationText(title, "Notifikasi AyoCuci")
	message = utils.CleanNotificationText(message, "Ada informasi baru dari AyoCuci.")

	masterID := utils.GenNotifID()
	normalizedPayload := normalizedNotificationPayload(category, masterID, payload)
	normalizedPayload["outlet_id"] = outletID
	master := model.NotifMaster{
		ID:            masterID,
		Kategori:      category,
		Judul:         title,
		Pesan:         message,
		Type:          notificationPayloadString(normalizedPayload, "notification_type", "announcement"),
		Payload:       notificationMasterPayload(normalizedPayload),
		CTALabel:      notificationPayloadString(normalizedPayload, "cta_label", ""),
		SchemaVersion: notificationSchemaVersion,
		Source:        "SYSTEM",
		UserUpdate:    "SYSTEM",
	}
	if err := tx.Create(&master).Error; err != nil {
		return err
	}

	receiver := model.NotifReceiver{
		MasterID: masterID,
		OutletID: outletID,
		Status:   0,
	}
	if err := tx.Create(&receiver).Error; err != nil {
		return err
	}

	database.InvalidateCache(
		fmt.Sprintf("notif:list:%s", outletID),
		fmt.Sprintf("notif:unread:%s", outletID),
	)

	broadcastPayload := normalizedPayload

	utils.AppHub.BroadcastToOutlet(outletID, map[string]interface{}{
		"type":    "SYSTEM_ANNOUNCEMENT",
		"title":   title,
		"message": message,
		"payload": broadcastPayload,
	})

	if sendPush {
		push.SendNotificationToTokens(
			context.Background(),
			activePushTokens(tx, []string{outletID}),
			title,
			message,
			stringifyPushData(broadcastPayload),
		)
	}

	return nil
}

func CreateUserNotification(tx *gorm.DB, userID uint, category, title, message string, payload map[string]interface{}) error {
	if userID == 0 {
		return nil
	}

	var outletIDs []string
	if err := tx.Model(&model.Outlet{}).
		Where("ot_user = ? AND ot_status = ?", userID, 1).
		Order("ot_created ASC").
		Pluck("ot_id", &outletIDs).Error; err != nil {
		return err
	}

	if len(outletIDs) == 0 {
		if err := tx.Model(&model.Outlet{}).
			Where("ot_user = ?", userID).
			Order("ot_created ASC").
			Pluck("ot_id", &outletIDs).Error; err != nil {
			return err
		}
	}

	for _, outletID := range outletIDs {
		if err := createOutletNotificationRecord(tx, outletID, category, title, message, payload); err != nil {
			return err
		}
	}

	pushPayload := map[string]interface{}{}
	for key, value := range payload {
		pushPayload[key] = value
	}
	pushPayload["category"] = strings.ToUpper(utils.CleanNotificationText(category, "SISTEM"))

	push.SendNotificationToTokens(
		context.Background(),
		activePushTokens(tx, outletIDs),
		utils.CleanNotificationText(title, "Notifikasi AyoCuci"),
		utils.CleanNotificationText(message, "Ada informasi baru dari AyoCuci."),
		stringifyPushData(pushPayload),
	)

	return nil
}

func createOutletNotificationRecord(tx *gorm.DB, outletID, category, title, message string, payload map[string]interface{}) error {
	if strings.TrimSpace(outletID) == "" {
		return nil
	}

	category = strings.ToUpper(utils.CleanNotificationText(category, "SISTEM"))
	title = utils.CleanNotificationText(title, "Notifikasi AyoCuci")
	message = utils.CleanNotificationText(message, "Ada informasi baru dari AyoCuci.")

	masterID := utils.GenNotifID()
	normalizedPayload := normalizedNotificationPayload(category, masterID, payload)
	normalizedPayload["outlet_id"] = outletID
	master := model.NotifMaster{
		ID:            masterID,
		Kategori:      category,
		Judul:         title,
		Pesan:         message,
		Type:          notificationPayloadString(normalizedPayload, "notification_type", "announcement"),
		Payload:       notificationMasterPayload(normalizedPayload),
		CTALabel:      notificationPayloadString(normalizedPayload, "cta_label", ""),
		SchemaVersion: notificationSchemaVersion,
		Source:        "SYSTEM",
		UserUpdate:    "SYSTEM",
	}
	if err := tx.Create(&master).Error; err != nil {
		return err
	}

	receiver := model.NotifReceiver{
		MasterID: masterID,
		OutletID: outletID,
		Status:   0,
	}
	if err := tx.Create(&receiver).Error; err != nil {
		return err
	}

	database.InvalidateCache(
		fmt.Sprintf("notif:list:%s", outletID),
		fmt.Sprintf("notif:unread:%s", outletID),
	)

	broadcastPayload := normalizedPayload

	utils.AppHub.BroadcastToOutlet(outletID, map[string]interface{}{
		"type":    "SYSTEM_ANNOUNCEMENT",
		"title":   title,
		"message": message,
		"payload": broadcastPayload,
	})

	return nil
}

func activePushTokens(tx *gorm.DB, outletIDs []string) []string {
	tokens, err := push.ActiveTokensByOutletIDs(tx, outletIDs)
	if err != nil {
		return nil
	}
	return tokens
}

func stringifyPushData(payload map[string]interface{}) map[string]string {
	data := map[string]string{}
	for key, value := range payload {
		switch v := value.(type) {
		case nil:
			continue
		case string:
			data[key] = v
		default:
			data[key] = fmt.Sprint(v)
		}
	}
	return data
}
