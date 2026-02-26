package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/jmoiron/sqlx"
)

// StartIngestionCron spawns background workers to ingest external API data into the DB.
func StartIngestionCron(db *sqlx.DB) {
	if db == nil {
		log.Println("Ingestion workers disabled: Database connection is nil.")
		return
	}

	apiKey := os.Getenv("DATA_GOV_API_KEY")
	if apiKey == "" || apiKey == "your_api_key_here" {
		log.Println("Ingestion workers disabled: no valid DATA_GOV_API_KEY provided.")
		return
	}

	log.Println("Starting background async ingestion workers...")

	// Tick every 12 hours for Mandis
	mandiTicker := time.NewTicker(12 * time.Hour)
	go func() {
		// Run once immediately
		ingestMandiPrices(db, apiKey)
		for range mandiTicker.C {
			ingestMandiPrices(db, apiKey)
		}
	}()

	// Weather ticker could tick every 1 hour, but simplified for now:
	weatherTicker := time.NewTicker(1 * time.Hour)
	go func() {
		ingestWeatherGrid(db)
		for range weatherTicker.C {
			ingestWeatherGrid(db)
		}
	}()
}

func ingestMandiPrices(db *sqlx.DB, apiKey string) {
	log.Println("[worker] Fetching data.gov.in live prices...")
	crops := []string{"Tomato", "Wheat", "Rice"}

	for _, crop := range crops {
		livePrices, err := fetchLiveMandiPrices(apiKey, crop)
		if err != nil {
			log.Printf("[worker] Failed to fetch live prices for %s: %v", crop, err)
			continue
		}

		for _, lp := range livePrices {
			// 1. Ensure Mandi exists and get ID
			var mandiID int
			err := db.Get(&mandiID, "SELECT id FROM mandis WHERE name = $1", lp.Market)
			if err != nil {
				// Create mandi
				lat, lon := getCoordinatesForMarket(lp.Market, lp.State)
				err = db.QueryRow("INSERT INTO mandis (name, location) VALUES ($1, ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography) RETURNING id", lp.Market, lon, lat).Scan(&mandiID)
				if err != nil {
					log.Printf("[worker] Failed to insert mandi %s: %v", lp.Market, err)
					continue
				}
			}

			// 2. Insert into daily_prices
			_, err = db.Exec(`
				INSERT INTO daily_prices (mandi_id, crop_name, price) 
				VALUES ($1, $2, $3) 
				ON CONFLICT (mandi_id, crop_name, recorded_at) DO NOTHING`,
				mandiID, crop, lp.ModalPrice,
			)
			if err != nil {
				log.Printf("[worker] Failed to insert price for %s at %s: %v", crop, lp.Market, err)
			}
		}
	}
	log.Println("[worker] Completed mandi price ingestion cycle.")
}

func ingestWeatherGrid(db *sqlx.DB) {
	// In a real system, we'd query all farmer locations or a grid spanning India.
	// We'll mock a small grid loop here.
	log.Println("[worker] Fetching Open-Meteo weather updates...")
	lat, lon := 28.6139, 77.2090 // Delhi base

	w := fetchWeather(lat, lon, 25.0)

	_, err := db.Exec(`
		INSERT INTO weather_cache (geohash, temp, humidity, recorded_at)
		VALUES ('hash123', $1, $2, CURRENT_TIMESTAMP)
		ON CONFLICT (geohash, recorded_at) DO NOTHING`,
		w.CurrentTemp, w.Humidity,
	)
	if err != nil {
		log.Printf("[worker] Weather ingestion failed: %v", err)
	}
}

// ── Shared Weather Fetcher for Cron ────────────────────

func fetchWeather(lat, lon, idealTemp float64) WeatherInfo {
	url := fmt.Sprintf(
		"https://api.open-meteo.com/v1/forecast?latitude=%.4f&longitude=%.4f&current_weather=true&hourly=relative_humidity_2m",
		lat, lon,
	)

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(url)
	if err == nil && resp.StatusCode == http.StatusOK {
		defer resp.Body.Close()
		body, readErr := io.ReadAll(resp.Body)
		if readErr == nil {
			var result struct {
				CurrentWeather struct {
					Temperature float64 `json:"temperature"`
					WeatherCode int     `json:"weathercode"`
				} `json:"current_weather"`
				Hourly struct {
					Humidity []float64 `json:"relative_humidity_2m"`
				} `json:"hourly"`
			}
			if json.Unmarshal(body, &result) == nil {
				humidity := 60.0
				if len(result.Hourly.Humidity) > 0 {
					humidity = result.Hourly.Humidity[0]
				}
				condition := weatherCodeToCondition(result.CurrentWeather.WeatherCode)
				return WeatherInfo{
					CurrentTemp: result.CurrentWeather.Temperature,
					Humidity:    humidity,
					TempDelta:   result.CurrentWeather.Temperature - idealTemp,
					Condition:   condition,
				}
			}
		}
	}

	log.Printf("⚠ Open-Meteo API failed – using fallback weather data")
	return WeatherInfo{
		CurrentTemp: 32.4,
		Humidity:    68.0,
		TempDelta:   32.4 - idealTemp,
		Condition:   "Partly Cloudy",
	}
}

func weatherCodeToCondition(code int) string {
	switch {
	case code == 0:
		return "Clear Sky"
	case code <= 3:
		return "Partly Cloudy"
	case code <= 48:
		return "Foggy"
	case code <= 57:
		return "Drizzle"
	case code <= 67:
		return "Rain"
	case code <= 77:
		return "Snow"
	case code <= 82:
		return "Rain Showers"
	case code <= 86:
		return "Snow Showers"
	case code <= 99:
		return "Thunderstorm"
	default:
		return "Unknown"
	}
}
