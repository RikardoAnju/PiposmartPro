// internal/utils/ws_hub.go
package utils

import (
	"fmt"
	"sync"

	"github.com/gorilla/websocket"
)

type Hub struct {
	// key: outlet_id, value: map koneksi (pake map supaya hapus koneksi lebih cepat)
	// kita simpan sebagai map[*websocket.Conn]bool
	Clients map[string]map[*websocket.Conn]bool
	mu      sync.RWMutex
}

var AppHub = &Hub{
	Clients: make(map[string]map[*websocket.Conn]bool),
}

// Register mendaftarkan koneksi baru ke group outlet tertentu
func (h *Hub) Register(outletID string, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if h.Clients[outletID] == nil {
		h.Clients[outletID] = make(map[*websocket.Conn]bool)
	}
	h.Clients[outletID][conn] = true
	fmt.Printf("✅ WS: Device terhubung ke Outlet %s (Total: %d)\n", outletID, len(h.Clients[outletID]))
}

// Unregister menghapus koneksi (saat disconnect/switch)
func (h *Hub) Unregister(outletID string, conn *websocket.Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()

	if _, ok := h.Clients[outletID]; ok {
		if _, ok := h.Clients[outletID][conn]; ok {
			delete(h.Clients[outletID], conn)
			conn.Close()
			fmt.Printf("🔌 WS: Device terputus dari Outlet %s\n", outletID)
		}
		// Opsional: Hapus key outletID jika sudah tidak ada client sama sekali
		if len(h.Clients[outletID]) == 0 {
			delete(h.Clients, outletID)
		}
	}
}

// BroadcastToOutlet mengirim pesan hanya ke user di outlet spesifik
func (h *Hub) BroadcastToOutlet(outletID string, message interface{}) {
	h.mu.RLock()
	clients, ok := h.Clients[outletID]
	if !ok {
		h.mu.RUnlock()
		// Gak perlu log error di sini kalau emang outlet lagi offline (kasir tutup aplikasi)
		return
	}

	// Copy client ke slice supaya kita bisa lepas RLock secepat mungkin
	// dan menghindari deadlock saat Unregister dipanggil di dalam loop
	var targets []*websocket.Conn
	for client := range clients {
		targets = append(targets, client)
	}
	h.mu.RUnlock()

	// Mulai pengiriman
	for _, client := range targets {
		err := client.WriteJSON(message)
		if err != nil {
			// Jika gagal (koneksi putus di tengah jalan), bersihkan
			h.Unregister(outletID, client)
		}
	}
}

// BroadcastAll mengirim pesan ke SELURUH device tanpa pandang outlet (Promo/Notif Sistem)
func (h *Hub) BroadcastAll(message interface{}) {
	h.mu.RLock()
	// Kita copy daftar outletIDs untuk menghindari lock map utama terlalu lama
	outletIDs := make([]string, 0, len(h.Clients))
	for id := range h.Clients {
		outletIDs = append(outletIDs, id)
	}
	h.mu.RUnlock()

	// Kirim ke tiap outlet (masing-masing sudah handle RLock sendiri di BroadcastToOutlet)
	for _, id := range outletIDs {
		h.BroadcastToOutlet(id, message)
	}
}