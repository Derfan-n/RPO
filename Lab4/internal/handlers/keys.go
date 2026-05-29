package handlers

import (
	"database/sql"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

type keyResponse struct {
	ID       int64  `json:"id"`
	KeyName  string `json:"key_name"`
	KeyValue string `json:"key_value"`
}

type createKeyRequest struct {
	KeyName  string `json:"key_name" binding:"required"`
	KeyValue string `json:"key_value" binding:"required"`
}

type updateKeyRequest struct {
	KeyName  *string `json:"key_name"`
	KeyValue *string `json:"key_value"`
}

// ListKeys godoc
// @Summary Получить список ключей для терминала
// @Description Возвращает список ключей для расшифровки карт
// @Tags terminal
// @Produce json
// @Security ApiKeyAuth
// @Success 200 {array} keyResponse
// @Failure 500 {object} map[string]string
// @Router /terminal/keys [get]
func ListKeys(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		rows, err := db.Query(`SELECT id, key_name, key_value FROM keys ORDER BY id`)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		defer rows.Close()

		items := make([]keyResponse, 0)
		for rows.Next() {
			var item keyResponse
			if err := rows.Scan(&item.ID, &item.KeyName, &item.KeyValue); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
				return
			}
			items = append(items, item)
		}

		c.JSON(http.StatusOK, items)
	}
}

// AdminListKeys godoc
// @Summary Получить список ключей
// @Tags keys
// @Produce json
// @Security ApiKeyAuth
// @Success 200 {array} keyResponse
// @Failure 500 {object} map[string]string
// @Router /keys [get]
func AdminListKeys(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		rows, err := db.Query(`SELECT id, key_name, key_value FROM keys ORDER BY id`)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		defer rows.Close()

		items := make([]keyResponse, 0)
		for rows.Next() {
			var item keyResponse
			if err := rows.Scan(&item.ID, &item.KeyName, &item.KeyValue); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
				return
			}
			items = append(items, item)
		}

		c.JSON(http.StatusOK, items)
	}
}

// GetKey godoc
// @Summary Получить ключ по ID
// @Tags keys
// @Produce json
// @Param id path int true "ID ключа"
// @Security ApiKeyAuth
// @Success 200 {object} keyResponse
// @Failure 400 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /keys/{id} [get]
func GetKey(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		id, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
			return
		}

		var item keyResponse
		err = db.QueryRow(`SELECT id, key_name, key_value FROM keys WHERE id = ?`, id).
			Scan(&item.ID, &item.KeyName, &item.KeyValue)
		if err != nil {
			if err == sql.ErrNoRows {
				c.JSON(http.StatusNotFound, gin.H{"error": "key not found"})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, item)
	}
}

// CreateKey godoc
// @Summary Создать ключ
// @Tags keys
// @Accept json
// @Produce json
// @Param request body createKeyRequest true "Новый ключ"
// @Security ApiKeyAuth
// @Success 201 {object} keyResponse
// @Failure 400 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /keys [post]
func CreateKey(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req createKeyRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		res, err := db.Exec(
			`INSERT INTO keys (key_name, key_value) VALUES (?, ?)`,
			req.KeyName, req.KeyValue,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		id, _ := res.LastInsertId()
		c.JSON(http.StatusCreated, keyResponse{
			ID:       id,
			KeyName:  req.KeyName,
			KeyValue: req.KeyValue,
		})
	}
}

// UpdateKey godoc
// @Summary Обновить ключ
// @Tags keys
// @Accept json
// @Produce json
// @Param id path int true "ID ключа"
// @Param request body updateKeyRequest true "Изменения ключа"
// @Security ApiKeyAuth
// @Success 200 {object} keyResponse
// @Failure 400 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /keys/{id} [put]
func UpdateKey(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		id, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
			return
		}

		var req updateKeyRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		var current keyResponse
		err = db.QueryRow(`SELECT id, key_name, key_value FROM keys WHERE id = ?`, id).
			Scan(&current.ID, &current.KeyName, &current.KeyValue)
		if err != nil {
			if err == sql.ErrNoRows {
				c.JSON(http.StatusNotFound, gin.H{"error": "key not found"})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		if req.KeyName != nil {
			current.KeyName = *req.KeyName
		}
		if req.KeyValue != nil {
			current.KeyValue = *req.KeyValue
		}

		if _, err := db.Exec(
			`UPDATE keys SET key_name = ?, key_value = ? WHERE id = ?`,
			current.KeyName, current.KeyValue, id,
		); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, current)
	}
}

// DeleteKey godoc
// @Summary Удалить ключ
// @Tags keys
// @Param id path int true "ID ключа"
// @Security ApiKeyAuth
// @Success 204
// @Failure 400 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /keys/{id} [delete]
func DeleteKey(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		id, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
			return
		}

		tx, err := db.Begin()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		defer tx.Rollback()

		// A key can be referenced by cards. For the lab UI, deleting a key
		// deletes cards with that key and their transactions first.
		if _, err := tx.Exec(`DELETE FROM transactions WHERE card_id IN (SELECT id FROM cards WHERE key_id = ?)`, id); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		if _, err := tx.Exec(`DELETE FROM cards WHERE key_id = ?`, id); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		res, err := tx.Exec(`DELETE FROM keys WHERE id = ?`, id)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		affected, _ := res.RowsAffected()
		if affected == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "key not found"})
			return
		}
		if err := tx.Commit(); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.Status(http.StatusNoContent)
	}
}
