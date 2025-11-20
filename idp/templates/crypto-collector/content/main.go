package main

import (
	"fmt"
	"log"
	"os"
	"time"
)

func main() {
	coin := os.Getenv("COIN_SYMBOL")
	if coin == "" {
		coin = "UNKNOWN"
	}

	serviceName := "${{ values.name }}"

	fmt.Printf("Starting %s for %s...\n", serviceName, coin)

	for {
		log.Printf("[%s] Collecting data for %s...", serviceName, coin)
		// Simulate work
		time.Sleep(10 * time.Second)
	}
}
