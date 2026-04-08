package handlers

import (
	"database/sql"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

type authorizeRequest struct {
	CardNo         string  `json:"card_no" binding:"required"`
	TerminalSerial string  `json:"terminal_serial" binding:"required"`
	Amount         float64 `json:"amount" binding:"required"`
}

// AuthorizeTransaction godoc
// @Summary Авторизация платежной транзакции
// @Description Проверяет карту, терминал и сумму, затем возвращает результат авторизации
// @Tags terminal
// @Accept json
// @Produce json
// @Param request body authorizeRequest true "Данные транзакции"
// @Security ApiKeyAuth
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]string
// @Failure 401 {object} map[string]interface{}
// @Failure 500 {object} map[string]string
// @Router /terminal/authorize [post]
func AuthorizeTransaction(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req authorizeRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		var cardID int64
		var balance float64
		var blocked bool
		err := db.QueryRow(`SELECT id, balance, blocked FROM cards WHERE card_no = ?`, req.CardNo).
			Scan(&cardID, &balance, &blocked)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"authorized": false, "reason": "card not found"})
			return
		}
		if blocked {
			c.JSON(http.StatusUnauthorized, gin.H{"authorized": false, "reason": "card blocked"})
			return
		}
		if balance < req.Amount {
			c.JSON(http.StatusUnauthorized, gin.H{"authorized": false, "reason": "insufficient balance"})
			return
		}

		var terminalID int64
		err = db.QueryRow(`SELECT id FROM terminals WHERE serial_number = ?`, req.TerminalSerial).Scan(&terminalID)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"authorized": false, "reason": "terminal not found"})
			return
		}

		tx, err := db.Begin()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		defer tx.Rollback()

		if _, err := tx.Exec(`UPDATE cards SET balance = balance - ? WHERE id = ?`, req.Amount, cardID); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		if _, err := tx.Exec(`INSERT INTO transactions (amount, card_id, terminal_id, created_at) VALUES (?, ?, ?, ?)`, req.Amount, cardID, terminalID, time.Now().UTC()); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		if err := tx.Commit(); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, gin.H{"authorized": true})
	}
}
