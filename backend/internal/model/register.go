// internal/model/register.go
package model
type RegisterSession struct {
    PhoneNumber string `json:"phone_number"`
    IsVerified  bool   `json:"is_verified"`
    // Data Akun
    Nama     string `json:"nama"`
    Email    string `json:"email"`
    Password string `json:"password"` // Hashed
    // Data Outlet
    OutletNama   string `json:"outlet_nama"`
    OutletAlamat string `json:"outlet_alamat"`
    OutletKota   string `json:"outlet_kota"`
}