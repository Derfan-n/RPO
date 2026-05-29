package handlers

import (
	"database/sql"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

type terminalResponse struct {
	ID           int64  `json:"id"`
	SerialNumber string `json:"serial_number"`
	Address      string `json:"address"`
	DisplayName  string `json:"display_name"`
}

type createTerminalRequest struct {
	SerialNumber string `json:"serial_number" binding:"required"`
	Address      string `json:"address" binding:"required"`
	DisplayName  string `json:"display_name" binding:"required"`
}

type updateTerminalRequest struct {
	SerialNumber *string `json:"serial_number"`
	Address      *string `json:"address"`
	DisplayName  *string `json:"display_name"`
}

// ListTerminals godoc
// @Summary Получить список терминалов
// @Description Возвращает все терминалы
// @Tags terminals
// @Produce json
// @Security ApiKeyAuth
// @Success 200 {array} terminalResponse
// @Failure 500 {object} map[string]string
// @Router /terminals [get]
func ListTerminals(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		rows, err := db.Query(`SELECT id, serial_number, address, display_name FROM terminals ORDER BY id`)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		defer rows.Close()

		items := make([]terminalResponse, 0)
		for rows.Next() {
			var item terminalResponse
			if err := rows.Scan(&item.ID, &item.SerialNumber, &item.Address, &item.DisplayName); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
				return
			}
			items = append(items, item)
		}

		c.JSON(http.StatusOK, items)
	}
}

// GetTerminal godoc
// @Summary Получить терминал по ID
// @Tags terminals
// @Produce json
// @Param id path int true "ID терминала"
// @Security ApiKeyAuth
// @Success 200 {object} terminalResponse
// @Failure 400 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /terminals/{id} [get]
func GetTerminal(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		id, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
			return
		}

		var item terminalResponse
		err = db.QueryRow(`SELECT id, serial_number, address, display_name FROM terminals WHERE id = ?`, id).
			Scan(&item.ID, &item.SerialNumber, &item.Address, &item.DisplayName)
		if err != nil {
			if err == sql.ErrNoRows {
				c.JSON(http.StatusNotFound, gin.H{"error": "terminal not found"})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, item)
	}
}

// CreateTerminal godoc
// @Summary Создать терминал
// @Tags terminals
// @Accept json
// @Produce json
// @Param request body createTerminalRequest true "Новый терминал"
// @Security ApiKeyAuth
// @Success 201 {object} terminalResponse
// @Failure 400 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /terminals [post]
func CreateTerminal(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req createTerminalRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		res, err := db.Exec(
			`INSERT INTO terminals (serial_number, address, display_name) VALUES (?, ?, ?)`,
			req.SerialNumber, req.Address, req.DisplayName,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		id, _ := res.LastInsertId()
		c.JSON(http.StatusCreated, terminalResponse{
			ID:           id,
			SerialNumber: req.SerialNumber,
			Address:      req.Address,
			DisplayName:  req.DisplayName,
		})
	}
}

// UpdateTerminal godoc
// @Summary Обновить терминал
// @Tags terminals
// @Accept json
// @Produce json
// @Param id path int true "ID терминала"
// @Param request body updateTerminalRequest true "Изменения терминала"
// @Security ApiKeyAuth
// @Success 200 {object} terminalResponse
// @Failure 400 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /terminals/{id} [put]
func UpdateTerminal(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		id, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
			return
		}

		var req updateTerminalRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		var current terminalResponse
		err = db.QueryRow(`SELECT id, serial_number, address, display_name FROM terminals WHERE id = ?`, id).
			Scan(&current.ID, &current.SerialNumber, &current.Address, &current.DisplayName)
		if err != nil {
			if err == sql.ErrNoRows {
				c.JSON(http.StatusNotFound, gin.H{"error": "terminal not found"})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		if req.SerialNumber != nil {
			current.SerialNumber = *req.SerialNumber
		}
		if req.Address != nil {
			current.Address = *req.Address
		}
		if req.DisplayName != nil {
			current.DisplayName = *req.DisplayName
		}

		if _, err := db.Exec(
			`UPDATE terminals SET serial_number = ?, address = ?, display_name = ? WHERE id = ?`,
			current.SerialNumber, current.Address, current.DisplayName, id,
		); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, current)
	}
}

// DeleteTerminal godoc
// @Summary Удалить терминал
// @Tags terminals
// @Param id path int true "ID терминала"
// @Security ApiKeyAuth
// @Success 204
// @Failure 400 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /terminals/{id} [delete]
func DeleteTerminal(db *sql.DB) gin.HandlerFunc {
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

		// Deleting a terminal also removes transactions that reference it.
		if _, err := tx.Exec(`DELETE FROM transactions WHERE terminal_id = ?`, id); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		res, err := tx.Exec(`DELETE FROM terminals WHERE id = ?`, id)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		affected, _ := res.RowsAffected()
		if affected == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "terminal not found"})
			return
		}
		if err := tx.Commit(); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.Status(http.StatusNoContent)
	}
}
