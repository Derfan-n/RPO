package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// Health godoc
// @Summary Проверка состояния API
// @Description Возвращает статус API
// @Tags system
// @Produce json
// @Success 200 {object} map[string]string
// @Router /health [get]
func Health() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status": "ok",
		})
	}
}
