package handlers

import (
	"database/sql"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"

	appauth "transport-auth/internal/auth"
)

type loginRequest struct {
	Login    string `json:"login"`
	Username string `json:"username"` // compatibility with Flutter/NFC old client
	Password string `json:"password" binding:"required"`
}

// Login godoc
// @Summary Вход пользователя
// @Description Выполняет вход по логину и паролю и возвращает JWT
// @Tags auth
// @Accept json
// @Produce json
// @Param request body loginRequest true "Данные для входа"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]string
// @Failure 401 {object} map[string]string
// @Failure 500 {object} map[string]string
// @Router /auth/login [post]
func Login(db *sql.DB, jwtSecret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req loginRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		if req.Login == "" {
			req.Login = req.Username
		}
		if req.Login == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "login is required"})
			return
		}

		var id int64
		var login string
		var passwordValue string
		var isAdmin bool

		err := db.QueryRow(
			`SELECT id, login, password, is_admin FROM users WHERE login = ?`,
			req.Login,
		).Scan(&id, &login, &passwordValue, &isAdmin)
		if err != nil {
			if err == sql.ErrNoRows {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
				return
			}
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}

		// Временная обратная совместимость:
		// если в базе ещё старый plaintext-пароль, даём войти и сразу
		// пробуем заменить его на bcrypt-хеш.
		if appauth.LooksLikeBcryptHash(passwordValue) {
			if err := appauth.CheckPassword(passwordValue, req.Password); err != nil {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
				return
			}
		} else {
			if passwordValue != req.Password {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
				return
			}

			// Тихая миграция plaintext -> bcrypt после успешного логина.
			if hashed, err := appauth.HashPassword(req.Password); err == nil {
				_, _ = db.Exec(`UPDATE users SET password = ? WHERE id = ?`, hashed, id)
			}
		}

		token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
			"sub":      id,
			"login":    login,
			"is_admin": isAdmin,
			"exp":      time.Now().Add(24 * time.Hour).Unix(),
		})

		signed, err := token.SignedString([]byte(jwtSecret))
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "token sign failed"})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"token":    signed,
			"is_admin": isAdmin,
		})
	}
}
