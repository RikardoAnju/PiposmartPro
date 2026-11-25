package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	// Izinkan koneksi dari aplikasi mobile (CheckOrigin true untuk testing)
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

func HandleWS(c *gin.Context) {
	// 1. Ambil outlet_id dari query params: /ws?outlet_id=5.001
	outletID := c.Query("outlet_id")
	if outletID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "outlet_id is required"})
		return
	}

	// 2. Upgrade koneksi HTTP ke WebSocket
	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		fmt.Printf("❌ WS Upgrade Error: %v\n", err)
		return
	}

	// 3. Daftarkan ke Hub
	utils.AppHub.Register(outletID, conn)

	// 4. Jaga koneksi tetap terbuka (Read Loop)
	// Tanpa loop ini, koneksi akan langsung tertutup setelah fungsi selesai
	go func() {
		defer utils.AppHub.Unregister(outletID, conn)
		for {
			// Kita tidak mengharapkan data dari mobile, 
			// tapi kita butuh ReadMessage untuk mendeteksi jika koneksi putus
			_, _, err := conn.ReadMessage()
			if err != nil {
				// User close app / koneksi putus
				break
			}
		}
	}()
}