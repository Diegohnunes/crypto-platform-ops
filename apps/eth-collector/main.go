package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

type PriceData struct {
	Symbol    string    `json:"symbol"`
	Price     float64   `json:"price"`
	Timestamp time.Time `json:"timestamp"`
	Source    string    `json:"source"`
}

type BinancePriceResponse struct {
	Symbol string `json:"symbol"`
	Price  string `json:"price"`
}


type BinanceKlineResponse [][]interface{}

type BinanceClient struct {
	httpClient *http.Client
	baseURL    string
}

func NewBinanceClient() *BinanceClient {
	return &BinanceClient{
		httpClient: &http.Client{Timeout: 10 * time.Second},
		baseURL:    "https://api.binance.com",
	}
}

func (c *BinanceClient) GetPrice(symbol string) (float64, error) {

	pair := fmt.Sprintf("%sUSDT", symbol)
	url := fmt.Sprintf("%s/api/v3/ticker/price?symbol=%s", c.baseURL, pair)
	
	resp, err := c.httpClient.Get(url)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return 0, fmt.Errorf("API returned status %d: %s", resp.StatusCode, string(body))
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return 0, err
	}

	var result BinancePriceResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return 0, err
	}

	price, err := strconv.ParseFloat(result.Price, 64)
	if err != nil {
		return 0, fmt.Errorf("failed to parse price: %v", err)
	}

	return price, nil
}

func (c *BinanceClient) GetHistoricalPrices(symbol string, from, to time.Time) ([]PriceData, error) {

	pair := fmt.Sprintf("%sUSDT", symbol)
	

	startTime := from.UnixMilli()
	endTime := to.UnixMilli()
	

	url := fmt.Sprintf("%s/api/v3/klines?symbol=%s&interval=1m&startTime=%d&endTime=%d&limit=500",
		c.baseURL, pair, startTime, endTime)
	
	resp, err := c.httpClient.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("API returned status %d: %s", resp.StatusCode, string(body))
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var klines BinanceKlineResponse
	if err := json.Unmarshal(body, &klines); err != nil {
		return nil, err
	}

	var prices []PriceData
	for _, kline := range klines {
		if len(kline) < 5 {
			continue
		}
		

		timestampMs, ok := kline[0].(float64)
		if !ok {
			continue
		}
		
		closePrice, ok := kline[4].(string)
		if !ok {
			continue
		}
		
		price, err := strconv.ParseFloat(closePrice, 64)
		if err != nil {
			continue
		}
		
		timestamp := time.UnixMilli(int64(timestampMs))
		prices = append(prices, PriceData{
			Price:     price,
			Timestamp: timestamp,
		})
	}

	return prices, nil
}

func backfillHistoricalData(client *BinanceClient, coin string) error {

	pattern := filepath.Join("/data/raw", fmt.Sprintf("%s_*.json", coin))
	files, _ := filepath.Glob(pattern)
	if len(files) > 0 {
		log.Printf("Historical data already exists (%d files), skipping backfill", len(files))
		return nil
	}

	log.Println("Backfilling 5 minutes of historical data from Binance...")
	

	to := time.Now()
	from := to.Add(-5 * time.Minute)
	
	historicalPrices, err := client.GetHistoricalPrices(coin, from, to)
	if err != nil {
		log.Printf("Failed to fetch historical data: %v", err)
		return err
	}

	if len(historicalPrices) == 0 {
		log.Println("No historical data received")
		return fmt.Errorf("no historical data available")
	}


	for _, priceData := range historicalPrices {
		priceData.Symbol = coin
		priceData.Source = "binance-historical"
		
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

	log.Printf("Backfilled %d historical data points from Binance", len(historicalPrices))
	return nil
}

func main() {
	coin := strings.ToUpper(os.Getenv("COIN"))
	if coin == "" {
		coin = "ETH"
	}
	
	log.Printf("Starting %s Collector (Binance API v2.0)...", coin)
	log.Printf("Trading Pair: %sUSDT", coin)

	client := NewBinanceClient()


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


	if err := backfillHistoricalData(client, coin); err != nil {
		log.Printf("Warning: Could not backfill historical data: %v", err)

	}


	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			price, err := client.GetPrice(coin)
			if err != nil {
				log.Printf("Error fetching price: %v", err)

				time.Sleep(10 * time.Second)
				continue
			}

			data := PriceData{
				Symbol:    coin,
				Price:     price,
				Timestamp: time.Now(),
				Source:    "binance-api",
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