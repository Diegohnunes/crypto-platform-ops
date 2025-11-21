package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type PriceData struct {
	Symbol    string    `json:"symbol"`
	Price     float64   `json:"price"`
	Timestamp time.Time `json:"timestamp"`
	Source    string    `json:"source"`
}

type CoinGeckoResponse map[string]struct {
	USD float64 `json:"usd"`
}

type CoinGeckoClient struct {
	httpClient *http.Client
	baseURL    string
}

func NewCoinGeckoClient() *CoinGeckoClient {
	return &CoinGeckoClient{
		httpClient: &http.Client{Timeout: 10 * time.Second},
		baseURL:    "https://api.coingecko.com/api/v3",
	}
}

func (c *CoinGeckoClient) GetPrice(coinID string) (float64, error) {
	url := fmt.Sprintf("%s/simple/price?ids=%s&vs_currencies=usd", c.baseURL, coinID)
	
	resp, err := c.httpClient.Get(url)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return 0, fmt.Errorf("API returned status: %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return 0, err
	}

	var result CoinGeckoResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return 0, err
	}

	if data, ok := result[coinID]; ok {
		return data.USD, nil
	}

	return 0, fmt.Errorf("coin %s not found in response", coinID)
}

// Map symbol to CoinGecko ID
func getCoinID(symbol string) string {
	symbol = strings.ToUpper(symbol)
	switch symbol {
	case "BTC":
		return "bitcoin"
	case "ETH":
		return "ethereum"
	case "SOL":
		return "solana"
	default:
		return strings.ToLower(symbol)
	}
}

func main() {
	coin := os.Getenv("COIN")
	if coin == "" {
		coin = "BTC"
	}
	
	coinID := getCoinID(coin)
	
	dataDir := "/data/raw"
	if err := os.MkdirAll(dataDir, 0755); err != nil {
		log.Printf("Warning: Could not create data dir: %v", err)
	}

	log.Printf("Starting %s Collector (Real Data Mode - CoinGecko)...", coin)
	log.Printf("Coin ID: %s", coinID)

	client := NewCoinGeckoClient()

	// Collection loop
	go func() {
		for {
			price, err := client.GetPrice(coinID)
			
			if err != nil {
				log.Printf("Error fetching price: %v", err)
				// Wait a bit before retrying on error
				time.Sleep(10 * time.Second)
				continue
			}
			
			data := PriceData{
				Symbol:    coin,
				Price:     price,
				Timestamp: time.Now(),
				Source:    "coingecko-api",
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
			
			// Rate limit: 30 seconds (CoinGecko free tier is ~10-30 req/min)
			time.Sleep(30 * time.Second)
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
