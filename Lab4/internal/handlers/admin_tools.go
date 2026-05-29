package handlers

import (
	"database/sql"
	"net/http"

	"github.com/gin-gonic/gin"
)

// ClearTransactions removes all payment transactions. It is intended for lab/demo resets.
func ClearTransactions(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		if _, err := db.Exec(`DELETE FROM transactions`); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		_, _ = db.Exec(`DELETE FROM sqlite_sequence WHERE name = 'transactions'`)
		c.JSON(http.StatusOK, gin.H{"ok": true, "message": "transactions cleared"})
	}
}

// ResetDemoData clears demo cards/transactions and recreates the default key, terminal and Kirill card.
// Users are preserved, so admin/admin123 keeps working.
func ResetDemoData(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		tx, err := db.Begin()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		defer tx.Rollback()

		statements := []string{
			`DELETE FROM transactions`,
			`DELETE FROM cards`,
			`DELETE FROM terminals`,
			`DELETE FROM keys`,
			`DELETE FROM sqlite_sequence WHERE name IN ('transactions', 'cards', 'terminals', 'keys')`,
			`INSERT INTO keys (id, key_name, key_value) VALUES (1, 'MIFARE_KEY_A_DEFAULT', 'FFFFFFFFFFFF')`,
			`INSERT INTO terminals (id, serial_number, address, display_name) VALUES (1, 'TERM-001', 'MacBook lab', 'PN532 terminal')`,
			`INSERT INTO cards (id, card_no, balance, blocked, owner_name, key_id) VALUES (1, '84f07c05', 500.00, 0, 'Kirill MIFARE Demo', 1)`,
		}

		for _, stmt := range statements {
			if _, err := tx.Exec(stmt); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error(), "statement": stmt})
				return
			}
		}

		if err := tx.Commit(); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"ok":      true,
			"message": "demo database reset",
			"card_no": "84f07c05",
			"balance": 500,
		})
	}
}
