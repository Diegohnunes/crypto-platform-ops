package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

type PriceData struct {
	Symbol    string    `json:"symbol"`
	Price     float64   `json:"price"`
	Timestamp time.Time `json:"timestamp"`
	Source    string    `json:"source"`
}

func main() {
	coin := os.Getenv("COIN")
	if coin == "" {
		coin = "BTC"
	}
	
	dataDir := "/data/raw"
	if err := os.MkdirAll(dataDir, 0755); err != nil {
		log.Printf("Warning: Could not create data dir: %v", err)
	}

	log.Printf("Starting %s Collector (File Mode)...", coin)

	// Simulate collection loop
	go func() {
		for {
			price := 90000.0 + (float64(time.Now().Unix()%100) / 10.0) // Stub data
			data := PriceData{
				Symbol:    coin,
				Price:     price,
				Timestamp: time.Now(),
				Source:    "stub-generator",
			}
			
			jsonData, _ := json.Marshal(data)
			
			// Write to file
			filename := fmt.Sprintf("%s_%d.json", coin, time.Now().Unix())
			filePath := filepath.Join(dataDir, filename)
			
			if err := os.WriteFile(filePath, jsonData, 0644); err != nil {
				log.Printf("Error writing file: %v", err)
			} else {
				log.Printf("Saved: %s", filePath)
			}
			
			time.Sleep(10 * time.Second)
		}
	}()

	// HTTP Server for Health Checks & Metrics
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Crypto Collector running for %s", coin)
	})

	port := "8080"
	log.Printf("Server listening on port %s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
