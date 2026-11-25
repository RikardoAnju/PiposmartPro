package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model/admin"

	"gorm.io/gorm"
)

type AdminCustomerService interface {
	GetAllCustomers(outletID string) ([]admin.CustomerListResult, error)
}

type adminCustomerService struct {
	db *gorm.DB
}

func NewAdminCustomerService(db *gorm.DB) AdminCustomerService {
	return &adminCustomerService{db}
}

func (s *adminCustomerService) GetAllCustomers(outletID string) ([]admin.CustomerListResult, error) {
    var results []admin.CustomerListResult

    // Mapping:
    // Pelanggan: p.pl_id (primary key), p.pl_nama, p.pl_nohp
    // Transaksi: t.tr_pelanggan (foreign key ke pl_id)
    // Outlet: o.ot_id (primary key), p.pl_outlet (foreign key di pelanggan)
    
    query := `
        SELECT 
            p.pl_id as pel_id, 
            p.pl_nama as pel_nama, 
            p.pl_nohp as pel_nohp, 
            p.pl_created as pel_created,
            o.ot_nama, 
            o.ot_id,
            (SELECT COUNT(*) FROM ac_transaksi t WHERE t.tr_pelanggan = p.pl_id) as total_trans
        FROM ac_pelanggan p
        JOIN ac_outlet o ON p.pl_outlet = o.ot_id
    `

    // Filter per Outlet jika ada
    if outletID != "" {
        query += " WHERE o.ot_id = '" + outletID + "'"
    }

    query += " ORDER BY p.pl_created DESC LIMIT 1000"

    err := s.db.Raw(query).Scan(&results).Error
    return results, err
}