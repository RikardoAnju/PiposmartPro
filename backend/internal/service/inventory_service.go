package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type InventoryService struct{ db *gorm.DB }

func NewInventoryService(db *gorm.DB) *InventoryService { return &InventoryService{db: db} }

var defaultInventoryCategories = []struct{ Name, Icon string }{
	{"Bahan Pencucian", "category_icon_05.webp"}, {"Pewangi & Pelembut", "category_icon_15.webp"},
	{"Packaging", "category_icon_22.webp"}, {"Perlengkapan", "category_icon_17.webp"},
}

func (s *InventoryService) ensureDefaults(outletID string) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		var count int64
		if err := tx.Model(&model.InventoryCategory{}).Where("ic_outlet = ?", outletID).Count(&count).Error; err != nil {
			return err
		}
		if count == 0 {
			for i, category := range defaultInventoryCategories {
				if err := tx.Create(&model.InventoryCategory{ID: "IC." + uuid.NewString(), OutletID: outletID, Name: category.Name, IconKey: category.Icon, SortOrder: i + 1, Status: 1}).Error; err != nil {
					return err
				}
			}
		}
		return tx.Where("is_outlet = ?", outletID).FirstOrCreate(&model.InventorySetting{OutletID: outletID, ReminderFrequency: "mingguan", ReminderDay: "Senin"}).Error
	})
}

func (s *InventoryService) Overview(outletID, query, status string) (map[string]any, error) {
	if err := s.ensureDefaults(outletID); err != nil {
		return nil, err
	}
	items, err := s.ListItems(outletID, query, status)
	if err != nil {
		return nil, err
	}
	var total, low, out int64
	if err := s.db.Model(&model.InventoryItem{}).Where("ii_outlet = ? AND ii_status = 1", outletID).Count(&total).Error; err != nil {
		return nil, err
	}
	s.db.Model(&model.InventoryItem{}).Where("ii_outlet = ? AND ii_status = 1 AND ii_stock <= 0", outletID).Count(&out)
	s.db.Model(&model.InventoryItem{}).Where("ii_outlet = ? AND ii_status = 1 AND ii_stock > 0 AND ii_stock <= ii_minimum_stock", outletID).Count(&low)
	categories, err := s.ListCategories(outletID)
	if err != nil {
		return nil, err
	}
	return map[string]any{"summary": ginMap("total_items", total, "low_stock", low, "out_of_stock", out), "items": items, "categories": categories}, nil
}

func ginMap(values ...any) map[string]any {
	result := map[string]any{}
	for i := 0; i < len(values); i += 2 {
		result[values[i].(string)] = values[i+1]
	}
	return result
}

func (s *InventoryService) ListItems(outletID, query, status string) ([]model.InventoryItem, error) {
	var results []model.InventoryItem
	db := s.db.Table("ac_inventory_item ii").Select("ii.*, ic.ic_name AS category_name, ic.ic_icon_key AS category_icon_key").Joins("JOIN ac_inventory_category ic ON ic.ic_id = ii.ii_category_id AND ic.ic_status = 1").Where("ii.ii_outlet = ? AND ii.ii_status = 1", outletID)
	if query = strings.TrimSpace(query); query != "" {
		db = db.Where("LOWER(ii.ii_name) LIKE ? OR LOWER(ic.ic_name) LIKE ?", "%"+strings.ToLower(query)+"%", "%"+strings.ToLower(query)+"%")
	}
	switch status {
	case "low":
		db = db.Where("ii.ii_stock > 0 AND ii.ii_stock <= ii.ii_minimum_stock")
	case "out":
		db = db.Where("ii.ii_stock <= 0")
	}
	return results, db.Order("ii.ii_stock ASC, ii.ii_name ASC").Scan(&results).Error
}

func (s *InventoryService) ListCategories(outletID string) ([]model.InventoryCategory, error) {
	if err := s.ensureDefaults(outletID); err != nil {
		return nil, err
	}
	var results []model.InventoryCategory
	return results, s.db.Where("ic_outlet = ? AND ic_status = 1", outletID).Order("ic_sort_order, ic_name").Find(&results).Error
}

func (s *InventoryService) CreateCategory(outletID, name, icon string) (model.InventoryCategory, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return model.InventoryCategory{}, fmt.Errorf("nama kategori wajib diisi")
	}
	var count int64
	s.db.Model(&model.InventoryCategory{}).Where("ic_outlet = ? AND LOWER(ic_name) = LOWER(?) AND ic_status = 1", outletID, name).Count(&count)
	if count > 0 {
		return model.InventoryCategory{}, fmt.Errorf("nama kategori sudah ada")
	}
	var last int
	s.db.Model(&model.InventoryCategory{}).Where("ic_outlet = ?", outletID).Select("COALESCE(MAX(ic_sort_order), 0)").Scan(&last)
	category := model.InventoryCategory{ID: "IC." + uuid.NewString(), OutletID: outletID, Name: name, IconKey: icon, SortOrder: last + 1, Status: 1}
	return category, s.db.Create(&category).Error
}

func (s *InventoryService) UpdateCategory(outletID, id, name, icon string) error {
	name = strings.TrimSpace(name)
	if name == "" {
		return fmt.Errorf("nama kategori wajib diisi")
	}
	return s.db.Model(&model.InventoryCategory{}).Where("ic_id = ? AND ic_outlet = ? AND ic_status = 1", id, outletID).Updates(map[string]any{"ic_name": name, "ic_icon_key": icon}).Error
}
func (s *InventoryService) DeleteCategory(outletID, id string) error {
	var items int64
	s.db.Model(&model.InventoryItem{}).Where("ii_outlet = ? AND ii_category_id = ? AND ii_status = 1", outletID, id).Count(&items)
	if items > 0 {
		return fmt.Errorf("kategori masih digunakan oleh %d barang", items)
	}
	result := s.db.Model(&model.InventoryCategory{}).Where("ic_id = ? AND ic_outlet = ?", id, outletID).Update("ic_status", 0)
	if result.RowsAffected == 0 {
		return fmt.Errorf("kategori tidak ditemukan")
	}
	return result.Error
}

func (s *InventoryService) CreateItem(item model.InventoryItem, actorID, actorType string) (model.InventoryItem, error) {
	item.Name = strings.TrimSpace(item.Name)
	item.Unit = strings.TrimSpace(item.Unit)
	if item.Name == "" || item.CategoryID == "" || item.Unit == "" {
		return item, fmt.Errorf("nama, kategori, dan satuan wajib diisi")
	}
	if item.Stock < 0 || item.MinimumStock < 0 {
		return item, fmt.Errorf("stok tidak boleh negatif")
	}
	item.ID, item.Status = "II."+uuid.NewString(), 1
	err := s.db.Transaction(func(tx *gorm.DB) error {
		var count int64
		tx.Model(&model.InventoryCategory{}).Where("ic_id = ? AND ic_outlet = ? AND ic_status = 1", item.CategoryID, item.OutletID).Count(&count)
		if count == 0 {
			return fmt.Errorf("kategori tidak ditemukan")
		}
		if err := tx.Create(&item).Error; err != nil {
			return err
		}
		return tx.Create(&model.InventoryStockMovement{ID: "ISM." + uuid.NewString(), OutletID: item.OutletID, ItemID: item.ID, Type: "initial", Quantity: item.Stock, StockBefore: 0, StockAfter: item.Stock, Note: "Stok awal", ActorID: actorID, ActorType: actorType, CreatedAt: time.Now()}).Error
	})
	return item, err
}

func (s *InventoryService) AdjustStock(outletID, itemID, movementType string, quantity float64, note, actorID, actorType string) (model.InventoryItem, error) {
	if quantity <= 0 {
		return model.InventoryItem{}, fmt.Errorf("jumlah penyesuaian harus lebih dari 0")
	}
	var item model.InventoryItem
	err := s.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("ii_id = ? AND ii_outlet = ? AND ii_status = 1", itemID, outletID).First(&item).Error; err != nil {
			return fmt.Errorf("barang tidak ditemukan")
		}
		before := item.Stock
		after := before
		switch movementType {
		case "in":
			after += quantity
		case "out":
			after -= quantity
		case "set":
			after = quantity
		default:
			return fmt.Errorf("tipe stok harus in, out, atau set")
		}
		if after < 0 {
			return fmt.Errorf("stok tidak mencukupi")
		}
		if err := tx.Model(&item).Update("ii_stock", after).Error; err != nil {
			return err
		}
		item.Stock = after
		return tx.Create(&model.InventoryStockMovement{ID: "ISM." + uuid.NewString(), OutletID: outletID, ItemID: itemID, Type: movementType, Quantity: quantity, StockBefore: before, StockAfter: after, Note: strings.TrimSpace(note), ActorID: actorID, ActorType: actorType, CreatedAt: time.Now()}).Error
	})
	return item, err
}
func (s *InventoryService) GetSetting(outletID string) (model.InventorySetting, error) {
	if err := s.ensureDefaults(outletID); err != nil {
		return model.InventorySetting{}, err
	}
	var setting model.InventorySetting
	return setting, s.db.Where("is_outlet = ?", outletID).First(&setting).Error
}
func (s *InventoryService) SaveSetting(setting model.InventorySetting) error {
	if setting.ReminderHour < 0 || setting.ReminderHour > 23 || setting.ReminderMinute < 0 || setting.ReminderMinute > 59 {
		return fmt.Errorf("jam pengingat tidak valid")
	}
	return s.db.Save(&setting).Error
}
