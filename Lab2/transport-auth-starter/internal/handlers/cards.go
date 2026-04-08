package handlers

import (
	"database/sql"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

type cardResponse struct {
	ID        int64   `json:"id"`
	CardNo    string  `json:"card_no"`
	Balance   float64 `json:"balance"`
	Blocked   bool    `json:"blocked"`
	OwnerName string  `json:"owner_name"`
	KeyID     int64   `json:"key_id"`
}

type createCardRequest struct {
	CardNo    string  `json:"card_no" binding:"required"`
	Balance   float64 `json:"balance" binding:"required"`
	Blocked   bool    `json:"blocked"`
	OwnerName string  `json:"owner_name" binding:"required"`
	KeyID     int64   `json:"key_id" binding:"required"`
}

type updateCardRequest struct {
	CardNo    *string  `json:"card_no"`
	Balance   *float64 `json:"balance"`
	Blocked   *bool    `json:"blocked"`
	OwnerName *string  `json:"owner_name"`
	KeyID     *int64   `json:"key_id"`
}

// ListCards godoc
// @Summary Получить список карт
// @Description Возвращает все транспортные карты
// @Tags cards
// @Produce json
// @Security ApiKeyAuth
// @Success 200 {array} cardResponse
// @Failure 500 {object} map[string]string
// @Router /cards [get]
func ListCards(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		rows, err := db.Query(`SELECT id, card_no, balance, blocked, owner_name, key_id FROM cards ORDER BY id`)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		defer rows.Close()

		items := make([]cardResponse, 0)
		for rows.Next() {
			var item cardResponse
			if err := rows.Scan(&item.ID, &item.CardNo, &item.Balance, &item.Blocked, &item.OwnerName, &item.KeyID); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
				return
			}
			items = append(items, item)
		}

		c.JSON(http.StatusOK, items)
	}
}

// GetCard godoc
// @Summary Получить карту по ID
// @Tags cards
// @Produce json
// @Param id path int true "ID карты"
// @Security ApiKeyAuth
// @Success 200 {object} cardResponse
// @Failure 400 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /cards/{id} [get]
func GetCard(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		id, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
			return
		}

		var item cardResponse
		err = db.QueryRow(`SELECT id, card_no, balance, blocked, owner_name, key_id FROM cards WHERE id = ?`, id).
			Scan(&item.ID, &item.CardNo, &item.Balance, &item.Blocked, &item.OwnerName, &item.KeyID)
		if err != nil {
			if err == sql.ErrNoRows {
				c.JSON(http.StatusNotFound, gin.H{"error": "card not found"})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, item)
	}
}

// CreateCard godoc
// @Summary Создать карту
// @Tags cards
// @Accept json
// @Produce json
// @Param request body createCardRequest true "Новая карта"
// @Security ApiKeyAuth
// @Success 201 {object} cardResponse
// @Failure 400 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /cards [post]
func CreateCard(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req createCardRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		res, err := db.Exec(
			`INSERT INTO cards (card_no, balance, blocked, owner_name, key_id) VALUES (?, ?, ?, ?, ?)`,
			req.CardNo, req.Balance, req.Blocked, req.OwnerName, req.KeyID,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		id, _ := res.LastInsertId()
		c.JSON(http.StatusCreated, cardResponse{
			ID:        id,
			CardNo:    req.CardNo,
			Balance:   req.Balance,
			Blocked:   req.Blocked,
			OwnerName: req.OwnerName,
			KeyID:     req.KeyID,
		})
	}
}

// UpdateCard godoc
// @Summary Обновить карту
// @Tags cards
// @Accept json
// @Produce json
// @Param id path int true "ID карты"
// @Param request body updateCardRequest true "Изменения карты"
// @Security ApiKeyAuth
// @Success 200 {object} cardResponse
// @Failure 400 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /cards/{id} [put]
func UpdateCard(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		id, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
			return
		}

		var req updateCardRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		var current cardResponse
		err = db.QueryRow(`SELECT id, card_no, balance, blocked, owner_name, key_id FROM cards WHERE id = ?`, id).
			Scan(&current.ID, &current.CardNo, &current.Balance, &current.Blocked, &current.OwnerName, &current.KeyID)
		if err != nil {
			if err == sql.ErrNoRows {
				c.JSON(http.StatusNotFound, gin.H{"error": "card not found"})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		if req.CardNo != nil {
			current.CardNo = *req.CardNo
		}
		if req.Balance != nil {
			current.Balance = *req.Balance
		}
		if req.Blocked != nil {
			current.Blocked = *req.Blocked
		}
		if req.OwnerName != nil {
			current.OwnerName = *req.OwnerName
		}
		if req.KeyID != nil {
			current.KeyID = *req.KeyID
		}

		if _, err := db.Exec(
			`UPDATE cards SET card_no = ?, balance = ?, blocked = ?, owner_name = ?, key_id = ? WHERE id = ?`,
			current.CardNo, current.Balance, current.Blocked, current.OwnerName, current.KeyID, id,
		); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, current)
	}
}

// DeleteCard godoc
// @Summary Удалить карту
// @Tags cards
// @Param id path int true "ID карты"
// @Security ApiKeyAuth
// @Success 204
// @Failure 400 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /cards/{id} [delete]
func DeleteCard(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		id, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
			return
		}

		res, err := db.Exec(`DELETE FROM cards WHERE id = ?`, id)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		affected, _ := res.RowsAffected()
		if affected == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "card not found"})
			return
		}

		c.Status(http.StatusNoContent)
	}
}
