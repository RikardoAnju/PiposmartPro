package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/database"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/notifier"
	"github.com/RikardoAnju/PiposmartPro/internal/push"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type ReferralService struct {
	db      *gorm.DB
	koinSvc *KoinService
}

func NewReferralService(db *gorm.DB, koinSvc *KoinService) *ReferralService {
	return &ReferralService{db: db, koinSvc: koinSvc}
}

type ReferralSummary struct {
	ReferralCode              string                        `json:"referral_code"`
	HasReferrer               bool                          `json:"has_referrer"`
	MyReferrerName            string                        `json:"my_referrer_name"`
	AvailableBalance          int                           `json:"available_balance"`
	TotalEarned               int                           `json:"total_earned"`
	TotalConverted            int                           `json:"total_converted"`
	PendingPayout             int                           `json:"pending_payout"`
	RecruitedOwners           int64                         `json:"recruited_owners"`
	RewardPerOwner            int                           `json:"reward_per_owner"`
	FirstTopupPercent         int                           `json:"first_topup_percent"`
	FirstTopupReferredPercent int                           `json:"first_topup_referred_percent"`
	NextTopupPercent          int                           `json:"next_topup_percent"`
	MonthlyRewardLimit        int                           `json:"monthly_reward_limit"`
	PayoutBudget              int                           `json:"payout_budget"`
	PayoutBudgetUsed          int                           `json:"payout_budget_used"`
	PayoutBudgetRemain        int                           `json:"payout_budget_remaining"`
	PayoutMinAmount           int                           `json:"payout_min_amount"`
	PayoutMaxAmount           int                           `json:"payout_max_amount"`
	ConversionRateText        string                        `json:"conversion_rate_text"`
	RecentRewards             []map[string]interface{}      `json:"recent_rewards"`
	AvailableRewards          []map[string]interface{}      `json:"available_rewards"`
	RecentTransactions        []model.ReferralWalletHistory `json:"recent_transactions"`
	PayoutRequests            []model.ReferralPayoutRequest `json:"payout_requests"`
	OwnerOutlets              []model.Outlet                `json:"owner_outlets"`
	PayoutAccounts            []model.ReferralPayoutAccount `json:"payout_accounts"`
	IsReferralLocked          bool                          `json:"is_referral_locked"`
}

type ReferralRecruitedOwner struct {
	OwnerID       uint       `json:"owner_id"`
	OwnerName     string     `json:"owner_name"`
	OutletName    string     `json:"outlet_name"`
	JoinDate      time.Time  `json:"join_date"`
	OutletCount   int64      `json:"outlet_count"`
	TopupCount    int64      `json:"topup_count"`
	TotalReward   int64      `json:"total_reward"`
	LatestTopupAt *time.Time `json:"latest_topup_at"`
}

type TopReferralOwnerRank struct {
	Rank         int    `json:"rank"`
	UserID       uint   `json:"user_id"`
	OwnerName    string `json:"owner_name"`
	ReferralCode string `json:"referral_code"`
	OutletName   string `json:"outlet_name"`
	TotalUsed    int64  `json:"total_used"`
	TotalReward  int64  `json:"total_reward"`
}

func (s *ReferralService) GetTopReferralOwnerRanks(limit int) ([]TopReferralOwnerRank, error) {
	if limit <= 0 {
		limit = 10
	}

	var results []TopReferralOwnerRank

	err := s.db.Table("ac_referral_wallet_history rwh").
		Select(`
            rwh.rwh_user AS user_id,
            u.usr_nama AS owner_name,
            u.usr_referral_code AS referral_code,
            COALESCE(
                (SELECT ot_nama FROM ac_outlet
                 WHERE ot_user = u.usr_id
                 ORDER BY ot_created ASC LIMIT 1),
                '-'
            ) AS outlet_name,
            COALESCE(
                (SELECT COUNT(DISTINCT rr.rr_referred_user)
                 FROM ac_referral_rewards rr
                 WHERE rr.rr_referrer_user = rwh.rwh_user
                   AND rr.rr_type = 'topup'),
                0
            ) AS total_used,
            COALESCE(SUM(CASE WHEN rwh.rwh_amount > 0 THEN rwh.rwh_amount ELSE 0 END), 0) AS total_reward
        `).
		Joins("JOIN ac_user u ON u.usr_id = rwh.rwh_user").
		Where("rwh.rwh_amount > 0").
		Group("rwh.rwh_user, u.usr_nama, u.usr_referral_code").
		Order("total_reward DESC, total_used DESC").
		Limit(limit).
		Scan(&results).Error

	if err != nil {
		return nil, err
	}

	for i := range results {
		results[i].Rank = i + 1
	}

	return results, nil
}

func (s *ReferralService) GetSummary(userID uint) (*ReferralSummary, error) {
	var user model.User
	if err := s.db.First(&user, userID).Error; err != nil {
		return nil, err
	}

	available, err := s.getAvailableBalance(s.db, userID)
	if err != nil {
		return nil, err
	}

	var totalEarned int
	s.db.Model(&model.ReferralWalletHistory{}).
		Where("rwh_user = ? AND rwh_amount > 0", userID).
		Select("COALESCE(SUM(rwh_amount), 0)").
		Scan(&totalEarned)

	var totalConverted int
	s.db.Model(&model.ReferralWalletHistory{}).
		Where("rwh_user = ? AND rwh_type = ?", userID, "convert_to_koin").
		Select("COALESCE(SUM(ABS(rwh_amount)), 0)").
		Scan(&totalConverted)

	var pendingPayout int
	s.db.Model(&model.ReferralPayoutRequest{}).
		Where("rp_user = ? AND rp_status = ?", userID, "pending").
		Select("COALESCE(SUM(rp_amount), 0)").
		Scan(&pendingPayout)

	var recruitedOwners int64
	s.db.Model(&model.ReferralReward{}).
		Where("rr_referrer_user = ? AND rr_type = ?", userID, "topup").
		Distinct("rr_referred_user").
		Count(&recruitedOwners)

	var rewards []map[string]interface{}
	s.db.Table("ac_referral_rewards rr").
		Select("rr.rr_id, rr.rr_reward_amount, rr.rr_type, rr.rr_status, rr.rr_created, rr.rr_percent AS percent, rr.rr_referred_user, rr.rr_referred_outlet, u.usr_nama AS owner_name, o.ot_nama AS outlet_name").
		Joins("JOIN ac_user u ON u.usr_id = rr.rr_referred_user").
		Joins("JOIN ac_outlet o ON o.ot_id = rr.rr_referred_outlet").
		Where("rr.rr_referrer_user = ?", userID).
		Order("rr.rr_created DESC").
		Limit(10).
		Scan(&rewards)

	var availableRewards []map[string]interface{}
	s.db.Table("ac_referral_rewards rr").
		Select("rr.rr_id, rr.rr_reward_amount, rr.rr_type, rr.rr_status, rr.rr_created, rr.rr_percent AS percent, rr.rr_referred_user, rr.rr_referred_outlet, u.usr_nama AS owner_name, o.ot_nama AS outlet_name").
		Joins("JOIN ac_user u ON u.usr_id = rr.rr_referred_user").
		Joins("JOIN ac_outlet o ON o.ot_id = rr.rr_referred_outlet").
		Where("rr.rr_referrer_user = ? AND rr.rr_status IN ?", userID, []string{"credited", "available"}).
		Order("rr.rr_created DESC").
		Scan(&availableRewards)

	var transactions []model.ReferralWalletHistory
	s.db.Where("rwh_user = ?", userID).
		Order("rwh_created DESC").
		Limit(12).
		Find(&transactions)

	var payouts []model.ReferralPayoutRequest
	s.db.Where("rp_user = ?", userID).
		Order("rp_created DESC").
		Limit(10).
		Find(&payouts)

	var outlets []model.Outlet
	s.db.Where("ot_user = ?", userID).
		Order("ot_created ASC").
		Find(&outlets)

	var payoutAccounts []model.ReferralPayoutAccount
	s.db.Where("rpa_user = ?", userID).
		Order("rpa_is_default DESC, rpa_created ASC").
		Find(&payoutAccounts)

	var myReferrerName string
	if user.ReferredBy != nil {
		s.db.Model(&model.User{}).Where("usr_id = ?", user.ReferredBy).Select("usr_nama").Scan(&myReferrerName)
	}

	pricePerCoin := s.getConfigInt("price_per_coin", 200)
	firstTopupPercent := s.getConfigInt("referral_percent_first", 15)
	firstTopupReferredPercent := s.getConfigInt("referral_percent_first_referred", 0)
	nextTopupPercent := s.getConfigInt("referral_percent_subsequent", 5)
	monthlyRewardLimit := s.getConfigInt("referral_reward_limit_monthly", 5)
	payoutBudget := s.getConfigInt("referral_payout_monthly_budget", 3000000)
	payoutMinAmount := s.getConfigInt("referral_payout_min_amount", 100000)
	payoutMaxAmount := s.getConfigInt("referral_payout_max_amount", 1000000)
	payoutBudgetUsed := s.getMonthlyPayoutUsed(s.db, time.Now())
	payoutBudgetRemain := payoutBudget - payoutBudgetUsed
	if payoutBudgetRemain < 0 {
		payoutBudgetRemain = 0
	}

	isReferralLocked := user.ReferredBy != nil
	if !isReferralLocked {
		var topupCount int64
		s.db.Table("ac_top_koin").
			Joins("JOIN ac_outlet ON ac_top_koin.tk_outlet = ac_outlet.ot_id").
			Where("ac_outlet.ot_user = ? AND ac_top_koin.tk_status = 'success'", userID).
			Count(&topupCount)

		if topupCount == 0 {
			var iapCount int64
			s.db.Table("ac_store_transactions").
				Where("st_owner_user_id = ? AND st_status = 'GRANTED'", userID).
				Count(&iapCount)
			if iapCount > 0 {
				topupCount = iapCount
			}
		}

		if topupCount > 0 {
			isReferralLocked = true
		}
	}

	return &ReferralSummary{
		ReferralCode:              user.ReferralCode,
		HasReferrer:               user.ReferredBy != nil,
		MyReferrerName:            myReferrerName,
		AvailableBalance:          available,
		TotalEarned:               totalEarned,
		TotalConverted:            totalConverted,
		PendingPayout:             pendingPayout,
		RecruitedOwners:           recruitedOwners,
		RewardPerOwner:            nextTopupPercent,
		FirstTopupPercent:         firstTopupPercent,
		FirstTopupReferredPercent: firstTopupReferredPercent,
		NextTopupPercent:          nextTopupPercent,
		MonthlyRewardLimit:        monthlyRewardLimit,
		PayoutBudget:              payoutBudget,
		PayoutBudgetUsed:          payoutBudgetUsed,
		PayoutBudgetRemain:        payoutBudgetRemain,
		PayoutMinAmount:           payoutMinAmount,
		PayoutMaxAmount:           payoutMaxAmount,
		ConversionRateText:        fmt.Sprintf("Setiap %d saldo referral = 1 koin", pricePerCoin),
		RecentRewards:             rewards,
		AvailableRewards:          availableRewards,
		RecentTransactions:        transactions,
		PayoutRequests:            payouts,
		OwnerOutlets:              outlets,
		PayoutAccounts:            payoutAccounts,
		IsReferralLocked:          isReferralLocked,
	}, nil
}

type referralTopupRewardInput struct {
	ReferenceID string
	OutletID    string
	TotalRp     float64
	CoinAmount  int
}

func (s *ReferralService) ApplyReferralCode(userID uint, code string) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		var user model.User
		if err := tx.First(&user, userID).Error; err != nil {
			return errors.New("user tidak ditemukan")
		}

		if user.ReferredBy != nil {
			return errors.New("anda sudah terdaftar melalui referral sebelumnya")
		}

		// Enforce check: referral code cannot be applied after first top-up
		var topupCount int64
		tx.Table("ac_top_koin").
			Joins("JOIN ac_outlet ON ac_top_koin.tk_outlet = ac_outlet.ot_id").
			Where("ac_outlet.ot_user = ? AND ac_top_koin.tk_status = 'success'", userID).
			Count(&topupCount)

		if topupCount == 0 {
			var iapCount int64
			tx.Table("ac_store_transactions").
				Where("st_owner_user_id = ? AND st_status = 'GRANTED'", userID).
				Count(&iapCount)
			if iapCount > 0 {
				topupCount = iapCount
			}
		}

		if topupCount > 0 {
			return errors.New("kode referral tidak dapat digunakan setelah melakukan top up pertama")
		}

		var referrer model.User
		if err := tx.Where("usr_referral_code = ?", strings.ToUpper(code)).First(&referrer).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return errors.New("kode referral tidak valid")
			}
			return err
		}

		if referrer.ID == userID {
			return errors.New("anda tidak bisa menggunakan kode referral sendiri")
		}

		if err := tx.Model(&user).Update("usr_referred_by", referrer.ID).Error; err != nil {
			return err
		}

		if err := s.NotifyReferralCodeUsed(tx, referrer.ID, user.Nama); err != nil {
			fmt.Printf("Gagal membuat notifikasi referral digunakan: %v\n", err)
		}

		return nil
	})
}

func (s *ReferralService) ProcessTopupReward(tx *gorm.DB, topup model.TopupKoin) error {
	return s.processTopupReward(tx, referralTopupRewardInput{
		ReferenceID: topup.ID,
		OutletID:    topup.OutletID,
		TotalRp:     topup.Total,
		CoinAmount:  topup.Jumlah,
	})
}

func (s *ReferralService) ProcessStoreTopupReward(tx *gorm.DB, storeTx model.StoreTransaction) error {
	if storeTx.OutletID == nil || strings.TrimSpace(*storeTx.OutletID) == "" || storeTx.CoinAmount <= 0 {
		return nil
	}
	outletID := strings.TrimSpace(*storeTx.OutletID)

	pricePerCoin := s.getConfigIntTx(tx, "price_per_coin", 200)
	return s.processTopupReward(tx, referralTopupRewardInput{
		ReferenceID: storeTx.ID,
		OutletID:    outletID,
		TotalRp:     float64(storeTx.CoinAmount * pricePerCoin),
		CoinAmount:  storeTx.CoinAmount,
	})
}

func (s *ReferralService) processTopupReward(tx *gorm.DB, input referralTopupRewardInput) error {
	// Ambil outlet yang melakukan topup
	var outlet model.Outlet
	if err := tx.Where("ot_id = ?", input.OutletID).First(&outlet).Error; err != nil {
		return nil
	}

	// Ambil owner dari outlet
	var referee model.User
	if err := tx.First(&referee, outlet.UserID).Error; err != nil {
		return nil
	}

	// Kalau owner tidak punya referrer, skip
	if referee.ReferredBy == nil {
		return nil
	}

	referrerID := *referee.ReferredBy

	var duplicateCount int64
	tx.Model(&model.ReferralReward{}).
		Where("rr_reference_id = ? AND rr_type = ?", input.ReferenceID, "topup").
		Count(&duplicateCount)
	if duplicateCount > 0 {
		return nil
	}

	monthlyLimit := s.getConfigIntTx(tx, "referral_reward_limit_monthly", 5)
	if monthlyLimit > 0 {
		start, end := referralMonthRange(time.Now())
		var monthlyCount int64
		tx.Model(&model.ReferralReward{}).
			Where(
				"rr_referrer_user = ? AND rr_referred_user = ? AND rr_type = ? AND rr_created >= ? AND rr_created < ?",
				referrerID,
				referee.ID,
				"topup",
				start,
				end,
			).
			Count(&monthlyCount)
		if monthlyCount >= int64(monthlyLimit) {
			return nil
		}
	}

	// Cek apakah si B sudah pernah topup sebelumnya
	var previousCount int64
	tx.Model(&model.ReferralReward{}).
		Where("rr_referrer_user = ? AND rr_referred_user = ? AND rr_type = ?", referrerID, referee.ID, "topup").
		Count(&previousCount)

	// Tentukan persentase berdasarkan topup pertama atau tidak
	var percent int
	var rewardLabel string
	if previousCount == 0 {
		percent = s.getConfigIntTx(tx, "referral_percent_first", 15)
		rewardLabel = "Komisi Bonus Topup Pertama"
	} else {
		percent = s.getConfigIntTx(tx, "referral_percent_subsequent", 5)
		rewardLabel = "Komisi Top Up"
	}

	rewardAmount := int(input.TotalRp * (float64(percent) / 100.0))
	if rewardAmount <= 0 {
		percent = 0
	}

	if rewardAmount > 0 {
		reward := model.ReferralReward{
			ReferrerUserID:   referrerID,
			ReferredUserID:   referee.ID,
			ReferredOutletID: input.OutletID,
			RewardAmount:     rewardAmount,
			Percent:          percent,
			Type:             "topup",
			ReferenceID:      input.ReferenceID,
			Status:           "credited",
		}
		if err := tx.Create(&reward).Error; err != nil {
			return err
		}

		if err := s.lockUserWallet(tx, referrerID); err != nil {
			return err
		}

		desc := fmt.Sprintf("%s (%d%%) dari %s", rewardLabel, percent, referee.Nama)
		if err := s.addWalletHistory(tx, referrerID, rewardAmount, "reward_topup", "topup", input.ReferenceID, desc); err != nil {
			return err
		}

		if err := s.NotifyReferralTopupReward(tx, referrerID, referee.Nama, rewardAmount, percent); err != nil {
			fmt.Printf("Gagal membuat notifikasi komisi referral: %v\n", err)
		}
	}

	if previousCount == 0 {
		if err := s.grantReferredFirstTopupBonus(tx, referee, input.OutletID, input.ReferenceID, input.TotalRp); err != nil {
			return err
		}
	}

	return nil
}

func (s *ReferralService) grantReferredFirstTopupBonus(tx *gorm.DB, referee model.User, outletID, referenceID string, totalRp float64) error {
	bonusPercent := s.getConfigIntTx(tx, "referral_percent_first_referred", 0)
	if bonusPercent <= 0 || totalRp <= 0 {
		return nil
	}

	// Bonus dihitung dari nominal RUPIAH yang dibayar (sesudah diskon), lalu
	// dikonversi ke koin memakai harga per koin. Dulu berbasis jumlah koin.
	pricePerCoin := s.getConfigIntTx(tx, "price_per_coin", 200)
	if pricePerCoin <= 0 {
		pricePerCoin = 200
	}
	bonusRp := totalRp * (float64(bonusPercent) / 100.0)
	bonusCoins := int(bonusRp / float64(pricePerCoin))
	if bonusCoins <= 0 {
		return nil
	}

	if err := tx.Model(&model.Outlet{}).
		Where("ot_id = ?", outletID).
		Update("ot_koin", gorm.Expr("ot_koin + ?", bonusCoins)).Error; err != nil {
		return err
	}

	desc := fmt.Sprintf("Bonus referral top up pertama (+%d koin)", bonusCoins)
	if err := s.koinSvc.AddHistoryKoin(tx, outletID, "masuk", bonusCoins, desc, fmt.Sprintf("%d", referee.ID)); err != nil {
		return err
	}

	if notifErr := notifier.CreateOutletNotification(
		tx,
		outletID,
		"KOIN",
		"Bonus Referral Masuk",
		fmt.Sprintf("Top up pertama berhasil. Bonus referral %d koin sudah ditambahkan ke akun laundry kamu.", bonusCoins),
		map[string]interface{}{
			"reference_id": referenceID,
			"type":         "referral_first_topup_bonus",
			"bonus_coins":  bonusCoins,
			"percent":      bonusPercent,
		},
	); notifErr != nil {
		fmt.Printf("Gagal membuat notifikasi bonus referral top up pertama: %v\n", notifErr)
	}

	database.InvalidateCache(fmt.Sprintf("outlet:profile:%s", outletID))
	utils.AppHub.BroadcastToOutlet(outletID, map[string]interface{}{
		"type":    "KOIN_UPDATED",
		"title":   "Bonus Referral Masuk",
		"message": fmt.Sprintf("%d koin bonus referral sudah ditambahkan setelah top up pertama berhasil.", bonusCoins),
		"payload": map[string]interface{}{
			"reference_id": referenceID,
			"type":         "referral_first_topup_bonus",
			"bonus_coins":  bonusCoins,
			"percent":      bonusPercent,
		},
	})

	return nil
}

func (s *ReferralService) NotifyReferralCodeUsed(tx *gorm.DB, referrerID uint, referredName string) error {
	name := utils.CleanNotificationText(referredName, "Owner baru")

	return s.notifyReferrer(
		tx,
		referrerID,
		"Owner Baru dari Referral",
		fmt.Sprintf("%s baru saja mendaftar menggunakan kode referral kamu. Bantu owner ini melakukan top up pertama agar komisi referral kamu aktif.", name),
	)
}

func (s *ReferralService) NotifyReferralTopupReward(tx *gorm.DB, referrerID uint, referredName string, rewardAmount int, percent int) error {
	name := utils.CleanNotificationText(referredName, "Owner referral")

	return s.notifyReferrer(
		tx,
		referrerID,
		"Komisi Referral Masuk",
		fmt.Sprintf("%s baru saja top up koin. Komisi Rp %s (%d%%) sudah masuk ke saldo referral kamu.", name, formatRupiahInt(rewardAmount), percent),
	)
}

func (s *ReferralService) notifyReferrer(tx *gorm.DB, referrerID uint, title string, message string) error {
	title = utils.CleanNotificationText(title, "Notifikasi Referral")
	message = utils.CleanNotificationText(message, "Ada informasi referral baru dari AyoCuci.")

	var outletIDs []string
	if err := tx.Model(&model.Outlet{}).
		Where("ot_user = ? AND ot_status = ?", referrerID, 1).
		Order("ot_created ASC").
		Pluck("ot_id", &outletIDs).Error; err != nil {
		return err
	}

	if len(outletIDs) == 0 {
		if err := tx.Model(&model.Outlet{}).
			Where("ot_user = ?", referrerID).
			Order("ot_created ASC").
			Pluck("ot_id", &outletIDs).Error; err != nil {
			return err
		}
	}

	if len(outletIDs) == 0 {
		return nil
	}

	masterID := utils.GenNotifID()
	master := model.NotifMaster{
		ID:         masterID,
		Kategori:   "REFERRAL",
		Judul:      title,
		Pesan:      message,
		UserUpdate: "SYSTEM",
	}
	if err := tx.Create(&master).Error; err != nil {
		return err
	}

	for _, outletID := range outletIDs {
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

		utils.AppHub.BroadcastToOutlet(outletID, map[string]interface{}{
			"type":    "SYSTEM_ANNOUNCEMENT",
			"title":   title,
			"message": message,
			"payload": map[string]interface{}{
				"category":  "REFERRAL",
				"master_id": masterID,
			},
		})
	}

	push.SendNotificationToTokens(
		context.Background(),
		activeReferralPushTokens(tx, outletIDs),
		title,
		message,
		map[string]string{
			"category": "REFERRAL",
		},
	)

	return nil
}

func activeReferralPushTokens(tx *gorm.DB, outletIDs []string) []string {
	tokens, err := push.ActiveTokensByOutletIDs(tx, outletIDs)
	if err != nil {
		return nil
	}
	return tokens
}

func (s *ReferralService) ConvertBalanceToKoin(userID uint, outletID string, rewardIDs []uint) (map[string]interface{}, error) {
	if len(rewardIDs) == 0 {
		return nil, errors.New("pilih minimal satu bonus referral untuk ditukar ke koin")
	}

	pricePerCoin := s.getConfigInt("price_per_coin", 200)
	var selectedAmount int
	var coinAmount int

	err := s.db.Transaction(func(tx *gorm.DB) error {
		if err := s.ensureOwnerOutlet(tx, userID, outletID); err != nil {
			return err
		}

		var rewards []model.ReferralReward
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			Where("rr_id IN ? AND rr_referrer_user = ? AND rr_status IN ?", rewardIDs, userID, []string{"credited", "available"}).
			Find(&rewards).Error; err != nil {
			return err
		}
		if len(rewards) != len(uniqueUintIDs(rewardIDs)) {
			return errors.New("sebagian bonus referral tidak tersedia atau sudah digunakan")
		}

		for _, reward := range rewards {
			selectedAmount += reward.RewardAmount
		}
		if selectedAmount < pricePerCoin {
			return fmt.Errorf("minimal konversi Rp %d", pricePerCoin)
		}
		coinAmount = selectedAmount / pricePerCoin
		if coinAmount <= 0 {
			return errors.New("bonus terpilih belum cukup untuk membeli koin")
		}

		if err := s.addWalletHistory(tx, userID, -selectedAmount, "convert_to_koin", "outlet", outletID, fmt.Sprintf("Konversi referral menjadi %d koin", coinAmount)); err != nil {
			return err
		}
		if err := tx.Model(&model.Outlet{}).Where("ot_id = ?", outletID).Update("ot_koin", gorm.Expr("ot_koin + ?", coinAmount)).Error; err != nil {
			return err
		}
		if err := tx.Model(&model.ReferralReward{}).
			Where("rr_id IN ?", uniqueUintIDs(rewardIDs)).
			Updates(map[string]interface{}{
				"rr_status":              "converted",
				"rr_coin_amount":         coinAmount,
				"rr_coin_status":         "claimed",
				"rr_coin_claimed_outlet": outletID,
			}).Error; err != nil {
			return err
		}
		if err := s.koinSvc.AddHistoryKoin(tx, outletID, "masuk", coinAmount, "Konversi saldo referral ke koin", fmt.Sprintf("%d", userID)); err != nil {
			return err
		}
		if notifErr := notifier.CreateOutletNotification(
			tx,
			outletID,
			"REFERRAL",
			"Saldo Referral Ditukar ke Koin",
			fmt.Sprintf("Saldo referral berhasil ditukar menjadi %d koin dan sudah masuk ke outlet tujuan.", coinAmount),
			map[string]interface{}{"status": "converted", "coins": coinAmount, "amount": selectedAmount},
		); notifErr != nil {
			fmt.Printf("Gagal membuat notifikasi konversi referral: %v\n", notifErr)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}

	database.InvalidateCache(fmt.Sprintf("outlet:profile:%s", outletID))
	utils.AppHub.BroadcastToOutlet(outletID, map[string]interface{}{
		"type": "COIN_UPDATED",
		"payload": map[string]interface{}{
			"outlet_id": outletID,
			"coins":     coinAmount,
			"source":    "referral_convert",
		},
	})

	return map[string]interface{}{
		"selected_amount":  selectedAmount,
		"converted_amount": selectedAmount,
		"coins":            coinAmount,
		"remaining_amount": 0,
	}, nil
}

func (s *ReferralService) CreatePayoutRequest(userID uint, rewardIDs []uint, payoutAccountID *uint, bankName, accountName, accountNumber string, note *string) (*model.ReferralPayoutRequest, error) {
	if len(rewardIDs) == 0 {
		return nil, errors.New("pilih minimal satu bonus referral untuk dicairkan")
	}
	if note != nil && strings.TrimSpace(*note) == "" {
		note = nil
	}

	var payout model.ReferralPayoutRequest
	err := s.db.Transaction(func(tx *gorm.DB) error {
		var payoutAccount *model.ReferralPayoutAccount
		if payoutAccountID != nil {
			account, err := s.getPayoutAccountByID(tx, userID, *payoutAccountID)
			if err != nil {
				return err
			}
			payoutAccount = account
			bankName = account.BankName
			accountName = account.AccountName
			accountNumber = account.AccountNumber
		}

		if strings.TrimSpace(bankName) == "" || strings.TrimSpace(accountName) == "" || strings.TrimSpace(accountNumber) == "" {
			return errors.New("data rekening payout wajib lengkap")
		}

		minAmount := s.getConfigIntTx(tx, "referral_payout_min_amount", 100000)

		var rewards []model.ReferralReward
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			Where("rr_id IN ? AND rr_referrer_user = ? AND rr_status IN ?", rewardIDs, userID, []string{"credited", "available"}).
			Find(&rewards).Error; err != nil {
			return err
		}
		if len(rewards) != len(uniqueUintIDs(rewardIDs)) {
			return errors.New("sebagian bonus referral tidak tersedia atau sudah masuk pengajuan pencairan")
		}

		amount := 0
		for _, reward := range rewards {
			amount += reward.RewardAmount
		}
		if amount <= 0 {
			return errors.New("nominal bonus referral tidak valid")
		}
		if minAmount > 0 && amount < minAmount {
			return fmt.Errorf("minimal pencairan bonus referral adalah Rp %s", formatRupiahInt(minAmount))
		}

		monthlyOwnerLimit := s.getConfigIntTx(tx, "referral_payout_monthly_owner_limit", 200000)
		if monthlyOwnerLimit <= 0 {
			monthlyOwnerLimit = s.getConfigIntTx(tx, "referral_payout_max_amount", 200000)
		}
		if monthlyOwnerLimit > 0 {
			usedByOwner := s.getMonthlyPayoutUsedByUser(tx, userID, time.Now())
			if usedByOwner+amount > monthlyOwnerLimit {
				remaining := monthlyOwnerLimit - usedByOwner
				if remaining < 0 {
					remaining = 0
				}
				return fmt.Errorf("maksimal pencairan referral bulan ini Rp %s. Sisa kuota kamu Rp %s", formatRupiahInt(monthlyOwnerLimit), formatRupiahInt(remaining))
			}
		}

		monthlyBudget := s.getConfigIntTx(tx, "referral_payout_monthly_budget", 3000000)
		if monthlyBudget > 0 {
			used := s.getMonthlyPayoutUsed(tx, time.Now())
			if used+amount > monthlyBudget {
				return errors.New("kuota pencairan mitra bulan ini sudah terpenuhi, silakan coba lagi minggu depan")
			}
		}

		payout = model.ReferralPayoutRequest{
			ID:              fmt.Sprintf("RP-%d%s", time.Now().Unix(), strings.ToUpper(utils.RandomString(4))),
			UserID:          userID,
			Amount:          amount,
			Status:          "pending",
			BankName:        bankName,
			AccountName:     accountName,
			AccountNumber:   accountNumber,
			Note:            note,
			PayoutAccountID: nil,
		}
		if payoutAccount != nil {
			payout.PayoutAccountID = &payoutAccount.ID
		}
		if err := tx.Create(&payout).Error; err != nil {
			return err
		}

		payoutItems := make([]model.ReferralPayoutItem, 0, len(rewards))
		rewardIDList := make([]uint, 0, len(rewards))
		for _, reward := range rewards {
			payoutItems = append(payoutItems, model.ReferralPayoutItem{
				PayoutID: payout.ID,
				RewardID: reward.ID,
				Amount:   reward.RewardAmount,
			})
			rewardIDList = append(rewardIDList, reward.ID)
		}
		if err := tx.Create(&payoutItems).Error; err != nil {
			return err
		}
		if err := tx.Model(&model.ReferralReward{}).
			Where("rr_id IN ?", rewardIDList).
			Updates(map[string]interface{}{"rr_status": "pending"}).Error; err != nil {
			return err
		}

		if err := s.addWalletHistory(tx, userID, -amount, "payout_request", "payout", payout.ID, "Pengajuan payout bonus referral"); err != nil {
			return err
		}
		if notifErr := notifier.CreateUserNotification(
			tx,
			userID,
			"REFERRAL",
			"Pengajuan Pencairan Diterima",
			fmt.Sprintf("Pengajuan pencairan saldo referral Rp %s sudah diterima dan menunggu verifikasi finance.", formatRupiahInt(amount)),
			map[string]interface{}{"payout_id": payout.ID, "status": "pending", "amount": amount},
		); notifErr != nil {
			fmt.Printf("Gagal membuat notifikasi pengajuan payout: %v\n", notifErr)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}

	return &payout, nil
}

func (s *ReferralService) ListPayoutAccounts(userID uint) ([]model.ReferralPayoutAccount, error) {
	var accounts []model.ReferralPayoutAccount
	err := s.db.Where("rpa_user = ?", userID).
		Order("rpa_is_default DESC, rpa_created ASC").
		Find(&accounts).Error
	return accounts, err
}

func (s *ReferralService) CreatePayoutAccount(userID uint, bankName, accountName, accountNumber string, isDefault bool) (*model.ReferralPayoutAccount, error) {
	if strings.TrimSpace(bankName) == "" || strings.TrimSpace(accountName) == "" || strings.TrimSpace(accountNumber) == "" {
		return nil, errors.New("data rekening payout wajib lengkap")
	}

	var account model.ReferralPayoutAccount
	err := s.db.Transaction(func(tx *gorm.DB) error {
		if isDefault {
			if err := s.clearDefaultPayoutAccounts(tx, userID); err != nil {
				return err
			}
		}

		account = model.ReferralPayoutAccount{
			UserID:        userID,
			BankName:      strings.TrimSpace(bankName),
			AccountName:   strings.TrimSpace(accountName),
			AccountNumber: strings.TrimSpace(accountNumber),
			IsDefault:     isDefault,
		}
		if err := tx.Create(&account).Error; err != nil {
			return err
		}

		if !isDefault {
			var count int64
			if err := tx.Model(&model.ReferralPayoutAccount{}).Where("rpa_user = ?", userID).Count(&count).Error; err != nil {
				return err
			}
			if count == 1 {
				return tx.Model(&account).Update("rpa_is_default", true).Error
			}
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return &account, nil
}

func (s *ReferralService) UpdatePayoutAccount(userID uint, accountID uint, bankName, accountName, accountNumber string, isDefault bool) (*model.ReferralPayoutAccount, error) {
	if strings.TrimSpace(bankName) == "" || strings.TrimSpace(accountName) == "" || strings.TrimSpace(accountNumber) == "" {
		return nil, errors.New("data rekening payout wajib lengkap")
	}

	var account model.ReferralPayoutAccount
	err := s.db.Transaction(func(tx *gorm.DB) error {
		existing, err := s.getPayoutAccountByID(tx, userID, accountID)
		if err != nil {
			return err
		}
		account = *existing

		if isDefault {
			if err := s.clearDefaultPayoutAccounts(tx, userID); err != nil {
				return err
			}
		}

		if err := tx.Model(&account).Updates(map[string]interface{}{
			"rpa_bank_name":      strings.TrimSpace(bankName),
			"rpa_account_name":   strings.TrimSpace(accountName),
			"rpa_account_number": strings.TrimSpace(accountNumber),
			"rpa_is_default":     isDefault,
		}).Error; err != nil {
			return err
		}

		return tx.Where("rpa_id = ?", accountID).First(&account).Error
	})
	if err != nil {
		return nil, err
	}
	return &account, nil
}

func (s *ReferralService) GetRecruitedOwners(userID uint) ([]ReferralRecruitedOwner, error) {
	var results []ReferralRecruitedOwner
	err := s.db.Table("ac_user u").
		Select(`
			u.usr_id AS owner_id,
			u.usr_nama AS owner_name,
			COALESCE(
				(
					SELECT o1.ot_nama
					FROM ac_outlet o1
					WHERE o1.ot_user = u.usr_id
					ORDER BY o1.ot_created ASC
					LIMIT 1
				),
				'-'
			) AS outlet_name,
			u.usr_created AS join_date,
			COALESCE(
				(
					SELECT COUNT(*)
					FROM ac_outlet o2
					WHERE o2.ot_user = u.usr_id
				),
				0
			) AS outlet_count,
			COALESCE(
				(
					SELECT COUNT(*)
					FROM ac_referral_rewards rr
					WHERE rr.rr_referrer_user = ?
					  AND rr.rr_referred_user = u.usr_id
					  AND rr.rr_type = 'topup'
				),
				0
			) AS topup_count,
			COALESCE(
				(
					SELECT SUM(rr.rr_reward_amount)
					FROM ac_referral_rewards rr
					WHERE rr.rr_referrer_user = ?
					  AND rr.rr_referred_user = u.usr_id
					  AND rr.rr_type = 'topup'
				),
				0
			) AS total_reward,
			(
				SELECT MAX(rr.rr_created)
				FROM ac_referral_rewards rr
				WHERE rr.rr_referrer_user = ?
				  AND rr.rr_referred_user = u.usr_id
				  AND rr.rr_type = 'topup'
			) AS latest_topup_at
		`, userID, userID, userID).
		Where("u.usr_referred_by = ?", userID).
		Order("u.usr_created DESC").
		Scan(&results).Error
	return results, err
}

func (s *ReferralService) SetDefaultPayoutAccount(userID uint, accountID uint) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		account, err := s.getPayoutAccountByID(tx, userID, accountID)
		if err != nil {
			return err
		}
		if err := s.clearDefaultPayoutAccounts(tx, userID); err != nil {
			return err
		}
		return tx.Model(account).Update("rpa_is_default", true).Error
	})
}

func (s *ReferralService) DeletePayoutAccount(userID uint, accountID uint) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		account, err := s.getPayoutAccountByID(tx, userID, accountID)
		if err != nil {
			return err
		}

		if err := tx.Model(&model.ReferralPayoutRequest{}).
			Where("rp_payout_account_id = ?", accountID).
			Update("rp_payout_account_id", nil).Error; err != nil {
			return err
		}

		if err := tx.Delete(account).Error; err != nil {
			return err
		}

		if account.IsDefault {
			var next model.ReferralPayoutAccount
			if err := tx.Where("rpa_user = ?", userID).Order("rpa_created ASC").First(&next).Error; err == nil {
				return tx.Model(&next).Update("rpa_is_default", true).Error
			}
		}
		return nil
	})
}

func (s *ReferralService) getAvailableBalance(tx *gorm.DB, userID uint) (int, error) {
	var balance int
	err := tx.Model(&model.ReferralWalletHistory{}).
		Where("rwh_user = ?", userID).
		Select("COALESCE(SUM(rwh_amount), 0)").
		Scan(&balance).Error
	return balance, err
}

func referralMonthRange(now time.Time) (time.Time, time.Time) {
	loc := now.Location()
	start := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, loc)
	return start, start.AddDate(0, 1, 0)
}

func (s *ReferralService) getMonthlyPayoutUsed(tx *gorm.DB, now time.Time) int {
	start, end := referralMonthRange(now)
	var used int
	tx.Model(&model.ReferralPayoutRequest{}).
		Where("rp_status IN ? AND rp_created >= ? AND rp_created < ?", []string{"pending", "approved", "process", "done", "paid"}, start, end).
		Select("COALESCE(SUM(rp_amount), 0)").
		Scan(&used)
	return used
}

func (s *ReferralService) getMonthlyPayoutUsedByUser(tx *gorm.DB, userID uint, now time.Time) int {
	start, end := referralMonthRange(now)
	var used int
	tx.Model(&model.ReferralPayoutRequest{}).
		Where("rp_user = ? AND rp_status IN ? AND rp_created >= ? AND rp_created < ?", userID, []string{"pending", "approved", "process", "done", "paid"}, start, end).
		Select("COALESCE(SUM(rp_amount), 0)").
		Scan(&used)
	return used
}

func uniqueUintIDs(ids []uint) []uint {
	seen := map[uint]bool{}
	result := make([]uint, 0, len(ids))
	for _, id := range ids {
		if id == 0 || seen[id] {
			continue
		}
		seen[id] = true
		result = append(result, id)
	}
	return result
}

func (s *ReferralService) ensureOwnerOutlet(tx *gorm.DB, userID uint, outletID string) error {
	var count int64
	if err := tx.Model(&model.Outlet{}).
		Where("ot_id = ? AND ot_user = ?", outletID, userID).
		Count(&count).Error; err != nil {
		return err
	}
	if count == 0 {
		return errors.New("outlet referral tidak valid")
	}
	return nil
}

func (s *ReferralService) lockUserWallet(tx *gorm.DB, userID uint) error {
	var user model.User
	return tx.Clauses(clause.Locking{Strength: "UPDATE"}).
		Select("usr_id").
		Where("usr_id = ?", userID).
		First(&user).Error
}

func (s *ReferralService) getPayoutAccountByID(tx *gorm.DB, userID uint, accountID uint) (*model.ReferralPayoutAccount, error) {
	var account model.ReferralPayoutAccount
	if err := tx.Where("rpa_id = ? AND rpa_user = ?", accountID, userID).First(&account).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("rekening payout tidak ditemukan")
		}
		return nil, err
	}
	return &account, nil
}

func (s *ReferralService) clearDefaultPayoutAccounts(tx *gorm.DB, userID uint) error {
	return tx.Model(&model.ReferralPayoutAccount{}).
		Where("rpa_user = ?", userID).
		Update("rpa_is_default", false).Error
}

func (s *ReferralService) addWalletHistory(tx *gorm.DB, userID uint, amount int, typ, referenceType, referenceID, desc string) error {
	currentBalance, err := s.getAvailableBalance(tx, userID)
	if err != nil {
		return err
	}

	history := model.ReferralWalletHistory{
		UserID:        userID,
		Amount:        amount,
		BalanceAfter:  currentBalance + amount,
		Type:          typ,
		ReferenceType: referenceType,
		ReferenceID:   referenceID,
		Description:   desc,
	}
	return tx.Create(&history).Error
}

func (s *ReferralService) getConfigInt(key string, fallback int) int {
	return s.getConfigIntTx(s.db, key, fallback)
}

func (s *ReferralService) getConfigIntTx(tx *gorm.DB, key string, fallback int) int {
	var cfg model.EconomyConfig
	if err := tx.Where("cfg_key = ?", key).First(&cfg).Error; err != nil {
		return fallback
	}
	val := utils.StringToInt(cfg.Value)
	if val <= 0 {
		return fallback
	}
	return val
}

func formatRupiahInt(amount int) string {
	value := fmt.Sprintf("%d", amount)
	if len(value) <= 3 {
		return value
	}

	var builder strings.Builder
	firstGroupLen := len(value) % 3
	if firstGroupLen == 0 {
		firstGroupLen = 3
	}

	builder.WriteString(value[:firstGroupLen])
	for i := firstGroupLen; i < len(value); i += 3 {
		builder.WriteString(".")
		builder.WriteString(value[i : i+3])
	}

	return builder.String()
}
