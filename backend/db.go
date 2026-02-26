package main

import (
	"log"
	"os"

	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
)

func InitDB() {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		log.Println("DATABASE_URL is not set, skipping DB Init for now.")
		return
	}

	conn, err := sqlx.Connect("postgres", dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	// Apply schema if needed. For production, use migrations.
	schema, err := os.ReadFile("schema.sql")
	if err == nil {
		conn.MustExec(string(schema))
		log.Println("Applied schema.sql successfully.")
	} else {
		log.Printf("Could not read schema.sql: %v", err)
	}

	db = conn // assigning to the package-level db in main.go
	log.Println("PostgreSQL connected successfully.")
}
