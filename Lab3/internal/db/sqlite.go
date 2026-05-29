package db

import (
	"database/sql"
	"log"
	"path/filepath"

	_ "github.com/mattn/go-sqlite3"
)

func MustOpen(dbPath string) *sql.DB {
	abs, err := filepath.Abs(dbPath)
	if err != nil {
		log.Fatalf("db path error: %v", err)
	}

	db, err := sql.Open("sqlite3", abs+"?_foreign_keys=on")
	if err != nil {
		log.Fatalf("open sqlite: %v", err)
	}

	if err := db.Ping(); err != nil {
		log.Fatalf("ping sqlite: %v", err)
	}
	return db
}
