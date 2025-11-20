package main

import (
	"encoding/json"
	"fmt"
	"log"
	"math"
	"math/rand"
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

// Realistic price simulator using random walk
type PriceSimulator struct {
	basePrice    float64
	currentPrice float64
	volatility   float64
	trend        float64
	rng          *rand.Rand
}

func NewPriceSimulator(basePrice, volatility float64) *PriceSimulator {
	return &PriceSimulator{
		basePrice:    basePrice,
		currentPrice: basePrice,
		volatility:   volatility,
		trend:        0.0,
		rng:          rand.New(rand.NewSource(time.Now().UnixNano())),
	}
}

func (ps *PriceSimulator) NextPrice() float64 {
	// Random walk with mean reversion
	randomChange := (ps.rng.Float64() - 0.5) * 2 * ps.volatility
	
	// Add trending behavior (momentum)
	ps.trend = ps.trend*0.9 + randomChange*0.1
	
	// Mean reversion force (pull back to base price)
	meanReversionForce := (ps.basePrice - ps.currentPrice) * 0.01
	
	// Combine all forces
	totalChange := randomChange + ps.trend + meanReversionForce
	
	// Update price
	ps.currentPrice += totalChange
	
	// Add micro-volatility (small jitter)
	microJitter := (ps.rng.Float64() - 0.5) * ps.volatility * 0.1
	ps.currentPrice += microJitter
	
	// Ensure price doesn't go too far from base (±15%)
	maxDeviation := ps.basePrice * 0.15
	if ps.currentPrice > ps.basePrice+maxDeviation {
		ps.currentPrice = ps.basePrice + maxDeviation
	}
	if ps.currentPrice < ps.basePrice-maxDeviation {
		ps.currentPrice = ps.basePrice - maxDeviation
	}
	
	// Round to 2 decimals
	return math.Round(ps.currentPrice*100) / 100
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

	log.Printf("Starting %s Collector (Realistic Simulation Mode)...", coin)

	// Initialize price simulator
	// BTC base: ~$96,000, volatility: $300 per tick
	simulator := NewPriceSimulator(96000.0, 300.0)

	// Simulate collection loop
	go func() {
		for {
			price := simulator.NextPrice()
			
			data := PriceData{
				Symbol:    coin,
				Price:     price,
				Timestamp: time.Now(),
				Source:    "realistic-simulator",
			}
			
			jsonData, _ := json.Marshal(data)
			
			// Write to file
			filename := fmt.Sprintf("%s_%d.json", coin, time.Now().Unix())
			filePath := filepath.Join(dataDir, filename)
			
			if err := os.WriteFile(filePath, jsonData, 0644); err != nil {
				log.Printf("Error writing file: %v", err)
			} else {
				log.Printf("Saved: %s | Price: $%.2f", filePath, price)
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
