package handlers

import (
	"database/sql"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

type authorizeRequest struct {
	CardNo         string  `json:"card_no"`
	CardNumber     string  `json:"card_number"` // compatibility with Flutter/NFC old client
	TerminalSerial string  `json:"terminal_serial"`
	Amount         float64 `json:"amount"`
}

// AuthorizeTransaction godoc
// @Summary Авторизация платежной транзакции
// @Description Проверяет карту, терминал и сумму, затем возвращает результат авторизации. Поддерживает React body card_no и старый NFC/Flutter body card_number.
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

		cardNo := strings.ToLower(strings.TrimSpace(req.CardNo))
		if cardNo == "" {
			cardNo = strings.ToLower(strings.TrimSpace(req.CardNumber))
		}
		terminalSerial := strings.TrimSpace(req.TerminalSerial)

		if cardNo == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "card_no or card_number is required"})
			return
		}
		if terminalSerial == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "terminal_serial is required"})
			return
		}
		if req.Amount <= 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "amount must be greater than zero"})
			return
		}

		var cardID int64
		var balanceBefore float64
		var blocked bool
		err := db.QueryRow(`SELECT id, balance, blocked FROM cards WHERE LOWER(card_no) = LOWER(?)`, cardNo).
			Scan(&cardID, &balanceBefore, &blocked)
		if err != nil {
			if err == sql.ErrNoRows {
				c.JSON(http.StatusOK, gin.H{
					"authorized":  false,
					"approved":    false,
					"reason":      "card not found",
					"message":     "Card not found",
					"card_no":     cardNo,
					"card_number": cardNo,
					"amount":      req.Amount,
				})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		if blocked {
			c.JSON(http.StatusOK, gin.H{
				"authorized":     false,
				"approved":       false,
				"reason":         "card blocked",
				"message":        "Card is blocked",
				"card_no":        cardNo,
				"card_number":    cardNo,
				"balance_before": balanceBefore,
				"amount":         req.Amount,
				"balance_after":  balanceBefore,
			})
			return
		}

		if balanceBefore < req.Amount {
			c.JSON(http.StatusOK, gin.H{
				"authorized":     false,
				"approved":       false,
				"reason":         "insufficient balance",
				"message":        "Insufficient funds",
				"card_no":        cardNo,
				"card_number":    cardNo,
				"balance_before": balanceBefore,
				"amount":         req.Amount,
				"balance_after":  balanceBefore,
			})
			return
		}

		var terminalID int64
		err = db.QueryRow(`SELECT id FROM terminals WHERE serial_number = ?`, terminalSerial).Scan(&terminalID)
		if err != nil {
			if err == sql.ErrNoRows {
				c.JSON(http.StatusOK, gin.H{
					"authorized":  false,
					"approved":    false,
					"reason":      "terminal not found",
					"message":     "Terminal not found",
					"card_no":     cardNo,
					"card_number": cardNo,
					"amount":      req.Amount,
				})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		tx, err := db.Begin()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		defer tx.Rollback()

		balanceAfter := balanceBefore - req.Amount
		if _, err := tx.Exec(`UPDATE cards SET balance = ? WHERE id = ?`, balanceAfter, cardID); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		result, err := tx.Exec(`INSERT INTO transactions (amount, card_id, terminal_id, created_at) VALUES (?, ?, ?, ?)`, req.Amount, cardID, terminalID, time.Now().UTC())
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		if err := tx.Commit(); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		transactionID, _ := result.LastInsertId()
		c.JSON(http.StatusOK, gin.H{
			"authorized":     true,
			"approved":       true,
			"message":        "Transaction approved",
			"card_no":        cardNo,
			"card_number":    cardNo,
			"balance_before": balanceBefore,
			"amount":         req.Amount,
			"balance_after":  balanceAfter,
			"transaction_id": transactionID,
		})
	}
}
