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

type MarketChartResponse struct {
	Prices [][]float64 `json:"prices"`
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

	var result CoinGecko Response
	if err := json.Unmarshal(body, &result); err != nil {
		return 0, err
	}

	priceData, ok := result[coinID]
	if !ok {
		return 0, fmt.Errorf("coin %s not found in response", coinID)
	}

	return priceData.USD, nil
}

func (c *CoinGeckoClient) GetHistoricalPrices(coinID string, from, to time.Time) ([]PriceData, error) {
	url := fmt.Sprintf("%s/coins/%s/market_chart/range?vs_currency=usd&from=%d&to=%d",
		c.baseURL, coinID, from.Unix(), to.Unix())
	
	resp, err := c.httpClient.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API returned status: %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var result MarketChartResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, err
	}

	var prices []PriceData
	for _, price := range result.Prices {
		if len(price) >= 2 {
			timestamp := time.Unix(int64(price[0])/1000, 0)
			prices = append(prices, PriceData{
				Price:     price[1],
				Timestamp: timestamp,
			})
		}
	}

	return prices, nil
}

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

func backfillHistoricalData(client *CoinGeckoClient, coin, coinID string) error {
	// Check if data already exists
	pattern := filepath.Join("/data/raw", fmt.Sprintf("%s_*.json", coin))
	files, _ := filepath.Glob(pattern)
	if len(files) > 0 {
		log.Printf("Historical data already exists (%d files), skipping backfill", len(files))
		return nil
	}

	log.Println("🔄 Backfilling 5 minutes of historical data...")
	
	// Fetch last 5 minutes of data
	to := time.Now()
	from := to.Add(-5 * time.Minute)
	
	historicalPrices, err := client.GetHistoricalPrices(coinID, from, to)
	if err != nil {
		log.Printf("⚠️  Failed to fetch historical data: %v", err)
		return err
	}

	if len(historicalPrices) == 0 {
		log.Println("⚠️  No historical data received")
		return fmt.Errorf("no historical data available")
	}

	// Save each historical price point
	for _, priceData := range historicalPrices {
		priceData.Symbol = coin
		priceData.Source = "coingecko-historical"
		
		filename := fmt.Sprintf("/data/raw/%s_%d.json", coin, priceData.Timestamp.Unix())
		data, err := json.MarshalIndent(priceData, "", "  ")
		if err != nil {
			log.Printf("Error marshaling data: %v", err)
			continue
		}

		if err := os.WriteFile(filename, data, 0644); err != nil {
			log.Printf("Error writing file %s: %v", filename, err)
			continue
		}
	}

	log.Printf("✅ Backfilled %d historical data points", len(historicalPrices))
	return nil
}

func main() {
	coin := strings.ToUpper(os.Getenv("COIN"))
	if coin == "" {
		coin = "BTC"
	}

	coinID := getCoinID(coin)
	
	log.Printf("Starting %s Collector (Real Data Mode - CoinGecko)...", coin)
	log.Printf("Coin ID: %s", coinID)

	client := NewCoinGeckoClient()

	// Start HTTP server for health checks
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	go func() {
		log.Println("Server listening on port 8080")
		if err := http.ListenAndServe(":8080", nil); err != nil {
			log.Printf("Failed to start server: %v", err)
		}
	}()

	// Backfill historical data on startup
	if err := backfillHistoricalData(client, coin, coinID); err != nil {
		log.Printf("Warning: Could not backfill historical data: %v", err)
		// Continue anyway - not critical for operation
	}

	// Main collection loop
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			price, err := client.GetPrice(coinID)
			if err != nil {
				log.Printf("Error fetching price: %v", err)
				// Wait a bit before retrying on error
				time.Sleep(60 * time.Second)
				continue
			}

			data := PriceData{
				Symbol:    coin,
				Price:     price,
				Timestamp: time.Now(),
				Source:    "coingecko-api",
			}

			filename := fmt.Sprintf("/data/raw/%s_%d.json", coin, time.Now().Unix())
			jsonData, err := json.MarshalIndent(data, "", "  ")
			if err != nil {
				log.Printf("Error marshaling data: %v", err)
				continue
			}

			if err := os.WriteFile(filename, jsonData, 0644); err != nil {
				log.Printf("Error writing file: %v", err)
				continue
			}

			log.Printf("Saved: %s | Price: $%.2f", filename, price)
		}
	}
}
