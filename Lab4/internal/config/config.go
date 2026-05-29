package config

import "os"

type Config struct {
	AppPort   string
	AppEnv    string
	JWTSecret string
	DBPath    string
}

func MustLoad() Config {
	cfg := Config{
		AppPort:   getEnv("APP_PORT", "8080"),
		AppEnv:    getEnv("APP_ENV", "dev"),
		JWTSecret: getEnv("JWT_SECRET", "change-me"),
		DBPath:    getEnv("DB_PATH", "./data/app.db"),
	}
	if cfg.JWTSecret == "" {
		panic("JWT_SECRET is empty")
	}
	return cfg
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
