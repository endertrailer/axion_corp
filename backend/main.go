package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math"
	"net/http"
	"os"
	"sort"
	"strconv"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq"
)

// ──────────────────────────────────────────────
// Global DB handle
// ──────────────────────────────────────────────

var db *sqlx.DB

// ──────────────────────────────────────────────
// main – bootstrap DB + router
// ──────────────────────────────────────────────

func main() {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://postgres:postgres@localhost:5432/agrichain?sslmode=disable"
	}

	var err error
	db, err = sqlx.Connect("postgres", dsn)
	if err != nil {
		log.Printf("WARNING: Could not connect to PostgreSQL (%v). Running in demo mode with fallback data.\n", err)
		// We continue anyway – handlers will use dummy data when db is nil.
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	r := gin.Default()

	// Health check
	r.GET("/api/v1/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok", "time": time.Now()})
	})

	// Core recommendation endpoint
	r.GET("/api/v1/recommendation", handleRecommendation)

	log.Printf("🚀 AgriChain API listening on 0.0.0.0:%s\n", port)
	if err := r.Run("0.0.0.0:" + port); err != nil {
		log.Fatalf("server failed: %v", err)
	}
}

// ══════════════════════════════════════════════
//  RECOMMENDATION HANDLER
// ══════════════════════════════════════════════

func handleRecommendation(c *gin.Context) {
	farmerID := c.Query("farmer_id")
	cropID := c.Query("crop_id")

	if farmerID == "" || cropID == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "farmer_id and crop_id query parameters are required",
		})
		return
	}

	// ── Step 1: Fetch farmer + crop from DB (with fallback) ──
	farmer := fetchFarmer(farmerID)
	crop := fetchCrop(cropID)

	// Override farmer location with live GPS coordinates if provided
	if latStr := c.Query("lat"); latStr != "" {
		if lat, err := strconv.ParseFloat(latStr, 64); err == nil {
			farmer.LocationLat = lat
		}
	}
	if lonStr := c.Query("lon"); lonStr != "" {
		if lon, err := strconv.ParseFloat(lonStr, 64); err == nil {
			farmer.LocationLon = lon
		}
	}
	log.Printf("📍 Using location: lat=%.4f, lon=%.4f", farmer.LocationLat, farmer.LocationLon)

	// ── Step 2: Concurrent external data fetches ──
	var wg sync.WaitGroup
	var weather WeatherInfo
	var markets []MandiPrice

	wg.Add(2)

	// Goroutine 1 – Weather from Open-Meteo
	go func() {
		defer wg.Done()
		weather = fetchWeather(farmer.LocationLat, farmer.LocationLon, crop.IdealTemp)
	}()

	// Goroutine 2 – Live market prices
	go func() {
		defer wg.Done()
		markets = fetchMarketPrices(cropID)
	}()

	wg.Wait()

	// ── Step 3: Compute transit times + market scores ──
	marketOptions := computeMarketScores(farmer, crop, markets, weather)

	// ── Step 4: Pick best market + decide action ──
	sort.Slice(marketOptions, func(i, j int) bool {
		return marketOptions[i].MarketScore > marketOptions[j].MarketScore
	})

	bestMarket := marketOptions[0]

	action, why := decideAction(crop, weather, bestMarket)

	recommendation := Recommendation{
		FarmerID:          farmerID,
		CropName:          crop.Name,
		Action:            action,
		RecommendedMarket: bestMarket.MarketName,
		MarketScore:       math.Round(bestMarket.MarketScore*100) / 100,
		Why:               why,
		Weather:           weather,
		Markets:           marketOptions,
		GeneratedAt:       time.Now(),
	}

	c.JSON(http.StatusOK, recommendation)
}

// ══════════════════════════════════════════════
//  DATA FETCHERS WITH FAILSAFE FALLBACKS
// ══════════════════════════════════════════════

// ── Farmer ──────────────────────────────────

func fetchFarmer(id string) Farmer {
	if db != nil {
		var f Farmer
		err := db.Get(&f, "SELECT id, location_lat, location_lon, phone, created_at FROM farmers WHERE id = $1", id)
		if err == nil {
			return f
		}
		log.Printf("⚠ DB fetch farmer failed: %v – using fallback", err)
	}
	// FALLBACK: realistic dummy farmer near New Delhi
	return Farmer{
		ID:          id,
		LocationLat: 28.6139,
		LocationLon: 77.2090,
		Phone:       "+919876543210",
		CreatedAt:   time.Now(),
	}
}

// ── Crop ────────────────────────────────────

func fetchCrop(id string) Crop {
	if db != nil {
		var c Crop
		err := db.Get(&c, "SELECT id, name, ideal_temp, baseline_spoilage_rate, created_at FROM crops WHERE id = $1", id)
		if err == nil {
			return c
		}
		log.Printf("⚠ DB fetch crop failed: %v – using fallback", err)
	}
	// FALLBACK: Tomato
	return Crop{
		ID:                   id,
		Name:                 "Tomato",
		IdealTemp:            25.0,
		BaselineSpoilageRate: 2.5,
		CreatedAt:            time.Now(),
	}
}

// ── Weather (Open-Meteo) ────────────────────

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
	// FALLBACK: realistic warm weather
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

// ── Market Prices (Mandi) ───────────────────

func fetchMarketPrices(cropID string) []MandiPrice {
	if db != nil {
		var prices []MandiPrice
		err := db.Select(&prices,
			"SELECT id, market_name, crop_id, current_price, market_lat, market_lon, timestamp FROM mandi_prices WHERE crop_id = $1 ORDER BY timestamp DESC LIMIT 10",
			cropID,
		)
		if err == nil && len(prices) > 0 {
			return prices
		}
		log.Printf("⚠ DB fetch mandi prices failed: %v – using fallback", err)
	}
	// FALLBACK: realistic market data for tomatoes in North India
	now := time.Now()
	return []MandiPrice{
		{ID: "m1", MarketName: "Azadpur Mandi", CropID: cropID, CurrentPrice: 2500, MarketLat: 28.7041, MarketLon: 77.1525, Timestamp: now},
		{ID: "m2", MarketName: "Vashi APMC", CropID: cropID, CurrentPrice: 2800, MarketLat: 19.0728, MarketLon: 73.0169, Timestamp: now},
		{ID: "m3", MarketName: "Ghazipur Mandi", CropID: cropID, CurrentPrice: 2350, MarketLat: 28.6233, MarketLon: 77.3230, Timestamp: now},
	}
}

// ── Transit Time (OSRM) ────────────────────

func fetchTransitTime(farmerLat, farmerLon, marketLat, marketLon float64) float64 {
	url := fmt.Sprintf(
		"http://router.project-osrm.org/route/v1/driving/%.4f,%.4f;%.4f,%.4f?overview=false",
		farmerLon, farmerLat, marketLon, marketLat,
	)

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(url)
	if err == nil && resp.StatusCode == http.StatusOK {
		defer resp.Body.Close()
		body, readErr := io.ReadAll(resp.Body)
		if readErr == nil {
			var result struct {
				Routes []struct {
					Duration float64 `json:"duration"` // seconds
				} `json:"routes"`
			}
			if json.Unmarshal(body, &result) == nil && len(result.Routes) > 0 {
				return result.Routes[0].Duration / 3600.0 // convert to hours
			}
		}
	}

	log.Printf("⚠ OSRM API failed – using haversine fallback")
	// FALLBACK: estimate transit time from haversine distance at 40 km/h average
	dist := haversine(farmerLat, farmerLon, marketLat, marketLon)
	return dist / 40.0 // hours
}

// haversine computes distance in km between two lat/lon coordinates.
func haversine(lat1, lon1, lat2, lon2 float64) float64 {
	const R = 6371.0 // Earth radius km
	dLat := (lat2 - lat1) * math.Pi / 180.0
	dLon := (lon2 - lon1) * math.Pi / 180.0
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*math.Pi/180.0)*math.Cos(lat2*math.Pi/180.0)*
			math.Sin(dLon/2)*math.Sin(dLon/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
	return R * c
}

// ══════════════════════════════════════════════
//  SCORING & DECISION ENGINE
// ══════════════════════════════════════════════

func computeMarketScores(farmer Farmer, crop Crop, markets []MandiPrice, weather WeatherInfo) []MarketOption {
	options := make([]MarketOption, 0, len(markets))

	// Fetch transit times concurrently
	type transitResult struct {
		idx      int
		duration float64
	}
	results := make(chan transitResult, len(markets))
	for i, m := range markets {
		go func(idx int, mkt MandiPrice) {
			dur := fetchTransitTime(farmer.LocationLat, farmer.LocationLon, mkt.MarketLat, mkt.MarketLon)
			results <- transitResult{idx: idx, duration: dur}
		}(i, m)
	}

	transitTimes := make([]float64, len(markets))
	for range markets {
		r := <-results
		transitTimes[r.idx] = r.duration
	}

	for i, m := range markets {
		transitHr := transitTimes[i]
		// Spoilage increases with temperature delta and transit time
		tempFactor := 1.0 + math.Abs(weather.TempDelta)/10.0
		spoilagePct := crop.BaselineSpoilageRate * transitHr * tempFactor

		// Transport cost penalty: ₹50/hr of transit (fuel, labor, depreciation)
		transportPenalty := transitHr * 50.0

		// Market score: effective price after losses
		effectivePrice := m.CurrentPrice * (1 - spoilagePct/100.0)
		score := effectivePrice - transportPenalty

		options = append(options, MarketOption{
			MarketName:    m.MarketName,
			CurrentPrice:  m.CurrentPrice,
			TransitTimeHr: math.Round(transitHr*100) / 100,
			SpoilageLoss:  math.Round(spoilagePct*100) / 100,
			MarketScore:   math.Round(score*100) / 100,
		})
	}

	return options
}

func decideAction(crop Crop, weather WeatherInfo, best MarketOption) (string, string) {
	action := "Harvest Now"
	var reasons []string

	// Temperature analysis
	if math.Abs(weather.TempDelta) <= 5 {
		reasons = append(reasons,
			fmt.Sprintf("Current temperature (%.1f°C) is close to the ideal %.1f°C for %s, making conditions favorable for harvest.",
				weather.CurrentTemp, crop.IdealTemp, crop.Name))
	} else if weather.TempDelta > 5 {
		reasons = append(reasons,
			fmt.Sprintf("It is %.1f°C hotter than the ideal %.1f°C for %s. Harvesting sooner reduces heat-related spoilage.",
				weather.TempDelta, crop.IdealTemp, crop.Name))
	} else {
		action = "Wait"
		reasons = append(reasons,
			fmt.Sprintf("Temperatures are %.1f°C below the ideal for %s. Waiting for warmer conditions may improve crop quality.",
				math.Abs(weather.TempDelta), crop.Name))
	}

	// Market analysis
	reasons = append(reasons,
		fmt.Sprintf("%s offers the best effective price at ₹%.0f/quintal after accounting for %.1f hrs transit and %.1f%% estimated spoilage (Market Score: %.0f).",
			best.MarketName, best.CurrentPrice, best.TransitTimeHr, best.SpoilageLoss, best.MarketScore))

	// Humidity warning
	if weather.Humidity > 80 {
		reasons = append(reasons,
			fmt.Sprintf("High humidity (%.0f%%) detected — consider immediate transport to reduce moisture-related decay.", weather.Humidity))
	}

	// Weather condition
	if weather.Condition == "Rain" || weather.Condition == "Rain Showers" || weather.Condition == "Thunderstorm" {
		action = "Wait"
		reasons = append(reasons,
			fmt.Sprintf("Current weather: %s. Delaying transport until conditions improve is recommended.", weather.Condition))
	}

	why := ""
	for i, r := range reasons {
		why += fmt.Sprintf("%d. %s ", i+1, r)
	}

	return action, why
}
