package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
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

	log.Printf("Starting %s Collector...", coin)

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
			log.Printf("Collected: %s", string(jsonData))
			
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
