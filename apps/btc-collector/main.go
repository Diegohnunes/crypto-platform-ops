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

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	// Business metric - crypto price
	cryptoPrice = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "crypto_price",
			Help: "Current price of the cryptocurrency",
		},
		[]string{"symbol", "source"},
	)

	// Service health
	serviceUp = prometheus.NewGauge(
		prometheus.GaugeOpts{
			Name: "btc_collector_up",
			Help: "Service availability (1 = up, 0 = down)",
		},
	)

	// HTTP Request metrics (RED pattern)
	httpRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "btc_collector_http_requests_total",
			Help: "Total HTTP requests",
		},
		[]string{"method", "endpoint", "status"},
	)

	httpRequestDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "btc_collector_http_request_duration_seconds",
			Help:    "HTTP request duration in seconds",
			Buckets: []float64{.001, .005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10},
		},
		[]string{"method", "endpoint"},
	)

	// Business metrics
	dataCollectionTotal = prometheus.NewCounter(
		prometheus.CounterOpts{
			Name: "btc_collector_data_collection_total",
			Help: "Total data points collected",
		},
	)

	dataCollectionErrors = prometheus.NewCounter(
		prometheus.CounterOpts{
			Name: "btc_collector_data_collection_errors_total",
			Help: "Total data collection errors",
		},
	)

	apiCallsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "btc_collector_api_calls_total",
			Help: "Total API calls to external services",
		},
		[]string{"service", "status"},
	)
)

func init() {
	prometheus.MustRegister(cryptoPrice)
	prometheus.MustRegister(serviceUp)
	prometheus.MustRegister(httpRequestsTotal)
	prometheus.MustRegister(httpRequestDuration)
	prometheus.MustRegister(dataCollectionTotal)
	prometheus.MustRegister(dataCollectionErrors)
	prometheus.MustRegister(apiCallsTotal)

	// Set service as up on startup
	serviceUp.Set(1)
}

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

// instrumentHandler wraps HTTP handlers with Prometheus instrumentation
func instrumentHandler(endpoint string, handler http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		
		// Call the actual handler
		handler(w, r)
		
		// Record metrics
		duration := time.Since(start).Seconds()
		httpRequestsTotal.WithLabelValues(r.Method, endpoint, "200").Inc()
		httpRequestDuration.WithLabelValues(r.Method, endpoint).Observe(duration)
	}
}

func (c *BinanceClient) GetPrice(symbol string) (float64, error) {

	pair := fmt.Sprintf("%sUSDT", symbol)
	url := fmt.Sprintf("%s/api/v3/ticker/price?symbol=%s", c.baseURL, pair)
	
	resp, err := c.httpClient.Get(url)
	if err != nil {
		apiCallsTotal.WithLabelValues("binance", "error").Inc()
		return 0, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		apiCallsTotal.WithLabelValues("binance", fmt.Sprintf("%d", resp.StatusCode)).Inc()
		body, _ := io.ReadAll(resp.Body)
		return 0, fmt.Errorf("API returned status %d: %s", resp.StatusCode, string(body))
	}

	apiCallsTotal.WithLabelValues("binance", "success").Inc()

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
		apiCallsTotal.WithLabelValues("binance", "error").Inc()
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		apiCallsTotal.WithLabelValues("binance", fmt.Sprintf("%d", resp.StatusCode)).Inc()
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("API returned status %d: %s", resp.StatusCode, string(body))
	}

	apiCallsTotal.WithLabelValues("binance", "success").Inc()

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
		coin = "BTC"
	}
	
	log.Printf("Starting %s Collector (Binance API v2.0)...", coin)
	log.Printf("Trading Pair: %sUSDT", coin)

	client := NewBinanceClient()


	http.HandleFunc("/health", instrumentHandler("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	}))

	// Prometheus metrics endpoint
	http.Handle("/metrics", promhttp.Handler())

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
				dataCollectionErrors.Inc()
				time.Sleep(10 * time.Second)
				continue
			}

			// Update Prometheus metric
			cryptoPrice.WithLabelValues(coin, "binance-api").Set(price)

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
				dataCollectionErrors.Inc()
				continue
			}

			if err := os.WriteFile(filename, jsonData, 0644); err != nil {
				log.Printf("Error writing file: %v", err)
				dataCollectionErrors.Inc()
				continue
			}

			// Successfully collected data
			dataCollectionTotal.Inc()
			log.Printf("Saved: %s | Price: $%.2f", filename, price)
		}
	}
}