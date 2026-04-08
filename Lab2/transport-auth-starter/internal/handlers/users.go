package handlers

import (
	"database/sql"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	appauth "transport-auth/internal/auth"
)

type userResponse struct {
	ID      int64  `json:"id"`
	Login   string `json:"login"`
	Name    string `json:"name"`
	IsAdmin bool   `json:"is_admin"`
}

type createUserRequest struct {
	Login    string `json:"login" binding:"required"`
	Name     string `json:"name" binding:"required"`
	Password string `json:"password" binding:"required"`
	IsAdmin  bool   `json:"is_admin"`
}

type updateUserRequest struct {
	Name     string `json:"name"`
	Password string `json:"password"`
	IsAdmin  *bool  `json:"is_admin"`
}

// ListUsers godoc
// @Summary Получить список пользователей
// @Tags users
// @Produce json
// @Security ApiKeyAuth
// @Success 200 {array} userResponse
// @Failure 500 {object} map[string]string
// @Router /users [get]
func ListUsers(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		rows, err := db.Query(`SELECT id, login, name, is_admin FROM users ORDER BY id`)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		defer rows.Close()

		items := make([]userResponse, 0)
		for rows.Next() {
			var item userResponse
			if err := rows.Scan(&item.ID, &item.Login, &item.Name, &item.IsAdmin); err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
				return
			}
			items = append(items, item)
		}

		c.JSON(http.StatusOK, items)
	}
}

// GetMe godoc
// @Summary Получить текущего пользователя
// @Tags users
// @Produce json
// @Security ApiKeyAuth
// @Success 200 {object} userResponse
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /users/me [get]
func GetMe(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetInt64("user_id")

		var item userResponse
		err := db.QueryRow(`SELECT id, login, name, is_admin FROM users WHERE id = ?`, userID).
			Scan(&item.ID, &item.Login, &item.Name, &item.IsAdmin)
		if err != nil {
			if err == sql.ErrNoRows {
				c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, item)
	}
}

// CreateUser godoc
// @Summary Создать пользователя
// @Tags users
// @Accept json
// @Produce json
// @Security ApiKeyAuth
// @Param request body createUserRequest true "Новый пользователь"
// @Success 201 {object} userResponse
// @Failure 400 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /users [post]
func CreateUser(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req createUserRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		hashedPassword, err := appauth.HashPassword(req.Password)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		res, err := db.Exec(
			`INSERT INTO users (login, name, password, is_admin) VALUES (?, ?, ?, ?)`,
			req.Login, req.Name, hashedPassword, req.IsAdmin,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		id, _ := res.LastInsertId()
		c.JSON(http.StatusCreated, userResponse{
			ID:      id,
			Login:   req.Login,
			Name:    req.Name,
			IsAdmin: req.IsAdmin,
		})
	}
}

// UpdateUser godoc
// @Summary Обновить пользователя
// @Tags users
// @Accept json
// @Produce json
// @Security ApiKeyAuth
// @Param id path int true "ID пользователя"
// @Param request body updateUserRequest true "Изменения пользователя"
// @Success 200 {object} userResponse
// @Failure 400 {object} map[string]string
// @Failure 403 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /users/{id} [put]
func UpdateUser(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		targetID, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
			return
		}

		requesterID := c.GetInt64("user_id")
		isAdmin := c.GetBool("is_admin")

		if !isAdmin && requesterID != targetID {
			c.JSON(http.StatusForbidden, gin.H{"error": "you can edit only your own user"})
			return
		}

		var req updateUserRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		if req.IsAdmin != nil && !isAdmin {
			c.JSON(http.StatusForbidden, gin.H{"error": "only admin can change admin flag"})
			return
		}

		var current userResponse
		var currentPassword string
		err = db.QueryRow(
			`SELECT id, login, name, password, is_admin FROM users WHERE id = ?`,
			targetID,
		).Scan(&current.ID, &current.Login, &current.Name, &currentPassword, &current.IsAdmin)
		if err != nil {
			if err == sql.ErrNoRows {
				c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		newName := current.Name
		if req.Name != "" {
			newName = req.Name
		}

		newPassword := currentPassword
		if req.Password != "" {
			hashedPassword, err := appauth.HashPassword(req.Password)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
				return
			}
			newPassword = hashedPassword
		}

		newIsAdmin := current.IsAdmin
		if req.IsAdmin != nil && isAdmin {
			newIsAdmin = *req.IsAdmin
		}

		if _, err := db.Exec(
			`UPDATE users SET name = ?, password = ?, is_admin = ? WHERE id = ?`,
			newName, newPassword, newIsAdmin, targetID,
		); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		c.JSON(http.StatusOK, userResponse{
			ID:      current.ID,
			Login:   current.Login,
			Name:    newName,
			IsAdmin: newIsAdmin,
		})
	}
}

// DeleteUser godoc
// @Summary Удалить пользователя
// @Tags users
// @Security ApiKeyAuth
// @Param id path int true "ID пользователя"
// @Success 204
// @Failure 400 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /users/{id} [delete]
func DeleteUser(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		id, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
			return
		}

		res, err := db.Exec(`DELETE FROM users WHERE id = ?`, id)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		affected, _ := res.RowsAffected()
		if affected == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
			return
		}

		c.Status(http.StatusNoContent)
	}
}
