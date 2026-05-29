package main

import (
	"database/sql"
	"log"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"

	_ "transport-auth/docs"
	"transport-auth/internal/middleware"

	"transport-auth/internal/config"
	appdb "transport-auth/internal/db"
	"transport-auth/internal/handlers"
)

// @title Transport Card Auth API
// @version 1.0
// @description REST API сервера авторизации платежей транспортными картами.
// @BasePath /api/v1
// @schemes https http
// @securityDefinitions.apikey ApiKeyAuth
// @in header
// @name Authorization
// @description Введите: Bearer <JWT_TOKEN>
func main() {
	cfg := config.MustLoad()
	db := appdb.MustOpen(cfg.DBPath)
	defer closeDB(db)

	if cfg.AppEnv == "prod" {
		gin.SetMode(gin.ReleaseMode)
	}

	r := gin.Default()

	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"service": "transport-auth",
		})
	})

	v1 := r.Group("/api/v1")
	{
		v1.GET("/health", handlers.Health())
		v1.POST("/auth/login", handlers.Login(db, cfg.JWTSecret))
		v1.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))

		authorized := v1.Group("")
		authorized.Use(middleware.AuthRequired(cfg.JWTSecret))
		{
			// compatibility with old Flutter/NFC client
			authorized.GET("/auth/me", handlers.GetMe(db))

			// user/admin: только чтение
			authorized.GET("/cards", handlers.ListCards(db))
			authorized.GET("/cards/:id", handlers.GetCard(db))

			authorized.GET("/terminals", handlers.ListTerminals(db))
			authorized.GET("/terminals/:id", handlers.GetTerminal(db))

			authorized.GET("/transactions", handlers.ListTransactions(db))
			authorized.GET("/transactions/:id", handlers.GetTransaction(db))
		}

		admin := v1.Group("")
		admin.Use(middleware.AuthRequired(cfg.JWTSecret), middleware.AdminOnly())
		{
			// users: только admin
			admin.GET("/users", handlers.ListUsers(db))
			admin.GET("/users/me", handlers.GetMe(db))
			admin.POST("/users", handlers.CreateUser(db))
			admin.PUT("/users/:id", handlers.UpdateUser(db))
			admin.DELETE("/users/:id", handlers.DeleteUser(db))

			// keys: только admin
			admin.GET("/keys", handlers.AdminListKeys(db))
			admin.GET("/keys/:id", handlers.GetKey(db))
			admin.POST("/keys", handlers.CreateKey(db))
			admin.PUT("/keys/:id", handlers.UpdateKey(db))
			admin.DELETE("/keys/:id", handlers.DeleteKey(db))

			// cards: запись только admin
			admin.POST("/cards", handlers.CreateCard(db))
			admin.PUT("/cards/:id", handlers.UpdateCard(db))
			admin.DELETE("/cards/:id", handlers.DeleteCard(db))

			// terminals: запись только admin
			admin.POST("/terminals", handlers.CreateTerminal(db))
			admin.PUT("/terminals/:id", handlers.UpdateTerminal(db))
			admin.DELETE("/terminals/:id", handlers.DeleteTerminal(db))

			// transactions: запись только admin
			admin.POST("/transactions", handlers.CreateTransaction(db))
			admin.PUT("/transactions/:id", handlers.UpdateTransaction(db))
			admin.DELETE("/transactions/:id", handlers.DeleteTransaction(db))

			// lab/admin tools
			admin.POST("/admin/clear-transactions", handlers.ClearTransactions(db))
			admin.POST("/admin/reset-demo-data", handlers.ResetDemoData(db))

			// terminal API: тоже только admin
			admin.POST("/terminal/authorize", handlers.AuthorizeTransaction(db))
			// compatibility with old Flutter/NFC client
			admin.POST("/terminal/transactions/authorize", handlers.AuthorizeTransaction(db))
			admin.GET("/terminal/keys", handlers.ListKeys(db))
		}
	}

	addr := ":" + cfg.AppPort
	log.Printf("API listening on %s", addr)
	if err := r.Run(addr); err != nil {
		log.Printf("server failed: %v", err)
		os.Exit(1)
	}
}

func closeDB(db *sql.DB) {
	if err := db.Close(); err != nil {
		log.Printf("db close error: %v", err)
	}
}
