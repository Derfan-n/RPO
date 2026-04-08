package handlers

import (
	"database/sql"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

type transactionResponse struct {
	ID         int64   `json:"id"`
	Amount     float64 `json:"amount"`
	CardID     int64   `json:"card_id"`
	TerminalID int64   `json:"terminal_id"`
	CreatedAt  string  `json:"created_at"`
}

type createTransactionRequest struct {
	Amount     float64 `json:"amount" binding:"required"`
	CardID     int64   `json:"card_id" binding:"required"`
	TerminalID int64   `json:"terminal_id" binding:"required"`
}

type updateTransactionRequest struct {
	Amount     *float64 `json:"amount"`
	CardID     *int64   `json:"card_id"`
	TerminalID *int64   `json:"terminal_id"`
}

// ListTransactions godoc
// @Summary Получить список транзакций
// @Tags transactions
// @Produce json
// @Security ApiKeyAuth
// @Success 200 {array} transactionResponse
// @Failure 500 {object} map[string]string
// @Router /transactions [get]
func ListTransactions(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		rows, err := db.Query(`SELECT id, amount, card_id, terminal_id, created_at FROM transactions ORDER BY id`)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		defer rows.Close()

		items := make([]transactionResponse, 0)
		for rows.Next() {
			var item transactionResponse
			if err := rows.Scan(&item.ID, &item.Amount, &item.CardID, &item.TerminalID, &item.CreatedAt); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
				return
			}
			items = append(items, item)
		}

		c.JSON(http.StatusOK, items)
	}
}

// GetTransaction godoc
// @Summary Получить транзакцию по ID
// @Tags transactions
// @Produce json
// @Param id path int true "ID транзакции"
// @Security ApiKeyAuth
// @Success 200 {object} transactionResponse
// @Failure 400 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /transactions/{id} [get]
func GetTransaction(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		id, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
			return
		}

		var item transactionResponse
		err = db.QueryRow(`SELECT id, amount, card_id, terminal_id, created_at FROM transactions WHERE id = ?`, id).
			Scan(&item.ID, &item.Amount, &item.CardID, &item.TerminalID, &item.CreatedAt)
		if err != nil {
			if err == sql.ErrNoRows {
				c.JSON(http.StatusNotFound, gin.H{"error": "transaction not found"})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, item)
	}
}

// CreateTransaction godoc
// @Summary Создать транзакцию
// @Tags transactions
// @Accept json
// @Produce json
// @Param request body createTransactionRequest true "Новая транзакция"
// @Security ApiKeyAuth
// @Success 201 {object} transactionResponse
// @Failure 400 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /transactions [post]
func CreateTransaction(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req createTransactionRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		res, err := db.Exec(
			`INSERT INTO transactions (amount, card_id, terminal_id) VALUES (?, ?, ?)`,
			req.Amount, req.CardID, req.TerminalID,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		id, _ := res.LastInsertId()

		var item transactionResponse
		err = db.QueryRow(`SELECT id, amount, card_id, terminal_id, created_at FROM transactions WHERE id = ?`, id).
			Scan(&item.ID, &item.Amount, &item.CardID, &item.TerminalID, &item.CreatedAt)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusCreated, item)
	}
}

// UpdateTransaction godoc
// @Summary Обновить транзакцию
// @Tags transactions
// @Accept json
// @Produce json
// @Param id path int true "ID транзакции"
// @Param request body updateTransactionRequest true "Изменения транзакции"
// @Security ApiKeyAuth
// @Success 200 {object} transactionResponse
// @Failure 400 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /transactions/{id} [put]
func UpdateTransaction(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		id, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
			return
		}

		var req updateTransactionRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		var current transactionResponse
		err = db.QueryRow(`SELECT id, amount, card_id, terminal_id, created_at FROM transactions WHERE id = ?`, id).
			Scan(&current.ID, &current.Amount, &current.CardID, &current.TerminalID, &current.CreatedAt)
		if err != nil {
			if err == sql.ErrNoRows {
				c.JSON(http.StatusNotFound, gin.H{"error": "transaction not found"})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		if req.Amount != nil {
			current.Amount = *req.Amount
		}
		if req.CardID != nil {
			current.CardID = *req.CardID
		}
		if req.TerminalID != nil {
			current.TerminalID = *req.TerminalID
		}

		if _, err := db.Exec(
			`UPDATE transactions SET amount = ?, card_id = ?, terminal_id = ? WHERE id = ?`,
			current.Amount, current.CardID, current.TerminalID, id,
		); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, current)
	}
}

// DeleteTransaction godoc
// @Summary Удалить транзакцию
// @Tags transactions
// @Param id path int true "ID транзакции"
// @Security ApiKeyAuth
// @Success 204
// @Failure 400 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /transactions/{id} [delete]
func DeleteTransaction(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		id, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
			return
		}

		res, err := db.Exec(`DELETE FROM transactions WHERE id = ?`, id)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		affected, _ := res.RowsAffected()
		if affected == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "transaction not found"})
			return
		}

		c.Status(http.StatusNoContent)
	}
}
