package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math"
	"net/http"
	"os"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jmoiron/sqlx"
	"github.com/joho/godotenv"
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
	// Load .env file for API keys
	if err := godotenv.Load(); err != nil {
		log.Printf("INFO: No .env file found, relying on system environment variables")
	}

	InitDB()
	StartIngestionCron(db)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	r := gin.Default()

	r.GET("/api/v1/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok", "time": time.Now()})
	})

	r.GET("/api/v1/recommendation", handleRecommendation)
	r.POST("/api/v1/chat", handleChat)

	// WhatsApp Webhook
	r.POST("/api/v1/webhook/whatsapp", handleWhatsAppWebhook)

	log.Printf("🚀 AgriChain API listening on 0.0.0.0:%s\n", port)
	if err := r.Run("0.0.0.0:" + port); err != nil {
		log.Fatalf("server failed: %v", err)
	}
}

// ══════════════════════════════════════════════
//  WHATSAPP WEBHOOK HANDLER (Phase 7 – Crowdsourcing)
// ══════════════════════════════════════════════

type WhatsAppPayload struct {
	Entry []struct {
		Changes []struct {
			Value struct {
				Messages []struct {
					From string `json:"from"`
					Text struct {
						Body string `json:"body"`
					} `json:"text"`
				} `json:"messages"`
			} `json:"value"`
		} `json:"changes"`
	} `json:"entry"`
}

func handleWhatsAppWebhook(c *gin.Context) {
	// Verify token challenge if it's a GET request (required for WhatsApp Webhook registration)
	if c.Request.Method == http.MethodGet {
		challenge := c.Query("hub.challenge")
		c.String(http.StatusOK, challenge)
		return
	}

	var payload WhatsAppPayload
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid payload format"})
		return
	}

	for _, entry := range payload.Entry {
		for _, change := range entry.Changes {
			for _, msg := range change.Value.Messages {
				phone := msg.From
				text := strings.TrimSpace(msg.Text.Body)

				// Expected Format: "MarketName CropName Price" (e.g. "Azadpur Tomato 2500")
				parts := strings.Split(text, " ")
				if len(parts) >= 3 {
					// We'll assume the last part is the price, and the second-to-last is the crop
					priceStr := parts[len(parts)-1]
					cropName := parts[len(parts)-2]
					marketName := strings.Join(parts[:len(parts)-2], " ")

					if reportedPrice, err := strconv.ParseFloat(priceStr, 64); err == nil {
						query := `
							INSERT INTO crowdsource_reports (farmer_phone, market_name, crop_name, reported_price)
							VALUES ($1, $2, $3, $4)
						`
						_, err := db.Exec(query, phone, marketName, cropName, reportedPrice)
						if err != nil {
							log.Printf("Error inserting crowdsource report: %v", err)
						} else {
							log.Printf("✅ Crowdsource ping registered: %s reported %s at %s for ₹%.2f", phone, cropName, marketName, reportedPrice)
						}
					}
				}
			}
		}
	}

	c.JSON(http.StatusOK, gin.H{"status": "received"})
}

// ══════════════════════════════════════════════
//  RECOMMENDATION HANDLER (Phase 2 – Staggering + Confidence)
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

	// ── Step 1: Fetch farmer + crop ──
	farmer := fetchFarmer(farmerID)
	crop := fetchCrop(cropID)

	// Override location with live GPS if provided
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

	roadQuality := c.DefaultQuery("road_quality", "mixed")
	cropMaturity := c.DefaultQuery("crop_maturity", "Optimal")

	lang := c.DefaultQuery("lang", "en") // Default to English if not provided

	// ── Step 2: PostgreSQL / PostGIS Cached Fetches ──
	var wg sync.WaitGroup
	var weather WeatherInfo
	var markets []MandiPrice
	var soil SoilHealth

	wg.Add(3)
	go func() {
		defer wg.Done()
		weather = fetchWeatherFromDB(farmer.LocationLat, farmer.LocationLon, crop.IdealTemp)
	}()
	go func() {
		defer wg.Done()
		markets = fetchMarketPricesFromDB(cropID, crop.Name, farmer.LocationLat, farmer.LocationLon)
	}()
	go func() {
		defer wg.Done()
		soil = fetchSoilHealth(farmer.LocationLat, farmer.LocationLon)
	}()
	wg.Wait()

	// ── Step 3: Compute transit times + market scores ──
	marketOptions := computeMarketScores(farmer, crop, markets, weather, roadQuality, cropMaturity)

	sort.Slice(marketOptions, func(i, j int) bool {
		return marketOptions[i].MarketScore > marketOptions[j].MarketScore
	})

	// Flag best market as AI recommended
	marketOptions[0].IsAIRecommended = true

	bestMarket := marketOptions[0]

	// ── Step 4: Confidence Bands (±10%) ──
	confidenceMin := math.Round(bestMarket.CurrentPrice*0.90*100) / 100
	confidenceMax := math.Round(bestMarket.CurrentPrice*1.10*100) / 100

	// ── Step 5: Staggering Protocol ──
	// Check arrival volume trend for the best market
	var bestTrend string
	for _, m := range markets {
		if m.MarketName == bestMarket.MarketName {
			bestTrend = m.ArrivalVolumeTrend
			break
		}
	}

	var storageOpt *StorageOption
	action, harvestWindow, why := decideActionV2(crop, weather, soil, bestMarket, bestTrend, confidenceMin, confidenceMax)

	// If trend is HIGH → trigger staggering: find nearest cold storage
	if bestTrend == "HIGH" {
		action = "Delay & Store Locally"
		storage := fetchNearestStorage(farmer.LocationLat, farmer.LocationLon)
		storageOpt = &storage

		why = fmt.Sprintf(
			"1. Price is likely between ₹%.0f and ₹%.0f. However, due to a massive arrival surge at %s, we recommend storing at %s for ₹%.1f/kg to prevent distress sales. "+
				"2. Current temperature (%.1f°C) with %s conditions. "+
				"3. Once arrivals normalise, sell at %s for the best effective return (Market Score: %.0f). "+
				"4. Storage at %s has %.0f MT capacity available at ₹%.1f/kg/day, located %.1f km from your farm.",
			confidenceMin, confidenceMax,
			bestMarket.MarketName,
			storage.Name, storage.PricePerKg,
			weather.CurrentTemp, weather.Condition,
			bestMarket.MarketName, bestMarket.MarketScore,
			storage.Name, storage.CapacityMT, storage.PricePerKg, storage.DistanceKm,
		)
	}

	// Calculate Spoilage Risk and generate farmer trust explanation
	factors := SpoilageFactors{
		TemperatureCelsius: weather.CurrentTemp,
		HumidityPercent:    weather.Humidity,
		TransitTimeHours:   bestMarket.TransitTimeHr,
		RoadQuality:        roadQuality,
		CropMaturity:       cropMaturity,
	}
	riskLevel := CalculateSpoilageRisk(factors)

	rainProb := 0
	switch weather.Condition {
	case "Rain", "Rain Showers", "Thunderstorm":
		rainProb = 80
	case "Drizzle":
		rainProb = 50
	case "Partly Cloudy":
		rainProb = 20
	}

	explanationStr := GenerateExplanation(bestMarket.MarketName, bestMarket.NetProfitEstimate, riskLevel, rainProb)
	why = explanationStr + "\n\n" + why

	// ── Step 6: Localized Strings via SLM ──
	whyLocalized := generateLocalizedStrings(why, action, crop.Name, bestMarket.MarketName, lang)

	// ── Step 7: Preservation Actions ──
	preservationOptionsEn := getDynamicPreservationActions(crop.Name, riskLevel, weather, bestMarket.TransitTimeHr)
	preservationOptions := translatePreservationActions(preservationOptionsEn, lang)

	recommendation := Recommendation{
		FarmerID:          farmerID,
		CropName:          crop.Name,
		Action:            action,
		HarvestWindow:     harvestWindow,
		RecommendedMarket: bestMarket.MarketName,
		MarketScore:       math.Round(bestMarket.MarketScore*100) / 100,
		ConfidenceBandMin: confidenceMin,
		ConfidenceBandMax: confidenceMax,
		Why:               whyLocalized,
		Weather:           weather,
		Soil:              soil,
		Markets:           marketOptions,
		Storage:           storageOpt,
		Preservation:      preservationOptions,
		GeneratedAt:       time.Now(),
	}

	c.JSON(http.StatusOK, recommendation)
}

// ══════════════════════════════════════════════
//  DATA FETCHERS WITH FAILSAFE FALLBACKS
// ══════════════════════════════════════════════

// ── Soil Health ─────────────────────────────

func fetchSoilHealth(lat, lon float64) SoilHealth {
	// NPK are mocked deterministically based on geographical location.
	// This ensures stable, realistic data instead of random noise every request.
	hashLat := int(lat * 1000)
	hashLon := int(lon * 1000)
	geoHash := hashLat ^ hashLon
	if geoHash < 0 {
		geoHash = -geoHash
	}

	moisture := 15.0 + float64(geoHash%5) // Default fallback mock

	// Fetch real soil moisture from Open-Meteo
	url := fmt.Sprintf("https://api.open-meteo.com/v1/forecast?latitude=%.4f&longitude=%.4f&hourly=soil_moisture_0_to_1cm", lat, lon)
	client := &http.Client{Timeout: 5 * time.Second}
	if resp, err := client.Get(url); err == nil {
		defer resp.Body.Close()
		if resp.StatusCode == http.StatusOK {
			var apiResp struct {
				Hourly struct {
					SoilMoisture []float64 `json:"soil_moisture_0_to_1cm"`
				} `json:"hourly"`
			}
			if err := json.NewDecoder(resp.Body).Decode(&apiResp); err == nil && len(apiResp.Hourly.SoilMoisture) > 0 {
				// OpenMeteo returns m³/m³, multiply by 100 for percentage
				moisture = apiResp.Hourly.SoilMoisture[0] * 100
				if moisture <= 0 {
					moisture = 15.0 + float64(geoHash%5)
				} // sanity check
			}
		}
	}

	status := "Good"
	if moisture < 20.0 {
		status = "Low Moisture - Irrigate Soon"
	}

	return SoilHealth{
		MoisturePct: math.Round(moisture*10) / 10,
		Nitrogen:    float64(30 + (geoHash % 25)),
		Phosphorus:  float64(15 + ((geoHash / 10) % 15)),
		Potassium:   float64(20 + ((geoHash / 100) % 20)),
		Status:      status,
	}
}

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
	// Fallback dictionary for 30+ Indian crops
	var cropDB = map[string]Crop{
		// Vegetables
		"c3d4e5f6-a7b8-9012-cdef-123456789012": {Name: "Tomato", IdealTemp: 25.0, BaselineSpoilageRate: 2.5},
		"d4e5f6a7-b890-12cd-ef12-345678901234": {Name: "Onion", IdealTemp: 20.0, BaselineSpoilageRate: 1.0},
		"e5f6a7b8-9012-cdef-1234-567890123456": {Name: "Potato", IdealTemp: 15.0, BaselineSpoilageRate: 1.5},
		"f6a7b8c9-0123-def0-2345-678901234567": {Name: "Brinjal (Eggplant)", IdealTemp: 26.0, BaselineSpoilageRate: 2.2},
		"a7b8c9d0-1234-ef01-3456-789012345678": {Name: "Cabbage", IdealTemp: 18.0, BaselineSpoilageRate: 2.8},
		"b8c9d0e1-2345-f012-4567-890123456789": {Name: "Cauliflower", IdealTemp: 18.0, BaselineSpoilageRate: 3.0},
		"c9d0e1f2-3456-0123-5678-901234567890": {Name: "Spinach", IdealTemp: 16.0, BaselineSpoilageRate: 4.5},
		"d0e1f2a3-4567-1234-6789-012345678901": {Name: "Carrot", IdealTemp: 16.0, BaselineSpoilageRate: 1.8},
		"e1f2a3b4-5678-2345-7890-123456789012": {Name: "Radish", IdealTemp: 15.0, BaselineSpoilageRate: 2.0},
		"f2a3b4c5-6789-3456-8901-234567890123": {Name: "Garlic", IdealTemp: 18.0, BaselineSpoilageRate: 0.8},
		// Fruits
		"a3b4c5d6-7890-4567-9012-345678901234": {Name: "Apple", IdealTemp: 4.0, BaselineSpoilageRate: 1.2},
		"b4c5d6e7-8901-5678-0123-456789012345": {Name: "Banana", IdealTemp: 14.0, BaselineSpoilageRate: 3.5},
		"c5d6e7f8-9012-6789-1234-567890123456": {Name: "Mango", IdealTemp: 12.0, BaselineSpoilageRate: 2.8},
		"d6e7f8a9-0123-7890-2345-678901234567": {Name: "Orange", IdealTemp: 8.0, BaselineSpoilageRate: 2.0},
		"e7f8a9b0-1234-8901-3456-789012345678": {Name: "Grapes", IdealTemp: 2.0, BaselineSpoilageRate: 3.2},
		"f8a9b0c1-2345-9012-4567-890123456789": {Name: "Papaya", IdealTemp: 12.0, BaselineSpoilageRate: 4.0},
		"a9b0c1d2-3456-0123-5678-901234567890": {Name: "Guava", IdealTemp: 10.0, BaselineSpoilageRate: 2.5},
		"b0c1d2e3-4567-1234-6789-012345678901": {Name: "Pineapple", IdealTemp: 10.0, BaselineSpoilageRate: 1.8},
		"c1d2e3f4-5678-2345-7890-123456789012": {Name: "Pomegranate", IdealTemp: 5.0, BaselineSpoilageRate: 1.5},
		// Cash Crops & Grains
		"d2e3f4a5-6789-3456-8901-234567890123": {Name: "Wheat", IdealTemp: 20.0, BaselineSpoilageRate: 0.5},
		"e3f4a5b6-7890-4567-9012-345678901234": {Name: "Rice", IdealTemp: 25.0, BaselineSpoilageRate: 0.8},
		"f4a5b6c7-8901-5678-0123-456789012345": {Name: "Sugarcane", IdealTemp: 30.0, BaselineSpoilageRate: 2.0},
		"a5b6c7d8-9012-6789-1234-567890123456": {Name: "Cotton", IdealTemp: 25.0, BaselineSpoilageRate: 0.4},
		"b6c7d8e9-0123-7890-2345-678901234567": {Name: "Maize", IdealTemp: 24.0, BaselineSpoilageRate: 0.9},
		"c7d8e9f0-1234-8901-3456-789012345678": {Name: "Tea", IdealTemp: 20.0, BaselineSpoilageRate: 1.0},
		"d8e9f0a1-2345-9012-4567-890123456789": {Name: "Coffee", IdealTemp: 22.0, BaselineSpoilageRate: 1.2},
		"e9f0a1b2-3456-0123-5678-901234567890": {Name: "Mustard", IdealTemp: 15.0, BaselineSpoilageRate: 0.6},
		// Spices
		"f0a1b2c3-4567-1234-6789-012345678901": {Name: "Ginger", IdealTemp: 15.0, BaselineSpoilageRate: 1.5},
		"a1b2c3d4-5678-2345-7890-123456789012": {Name: "Turmeric", IdealTemp: 25.0, BaselineSpoilageRate: 0.5},
		"b2c3d4e5-6789-3456-8901-234567890123": {Name: "Coriander", IdealTemp: 20.0, BaselineSpoilageRate: 3.5},
		"c3d4e5f6-7890-4567-9012-345678901234": {Name: "Cumin", IdealTemp: 25.0, BaselineSpoilageRate: 0.5},
		"d4e5f6a7-8901-5678-0123-456789012345": {Name: "Black Pepper", IdealTemp: 25.0, BaselineSpoilageRate: 0.8},
	}

	if cropData, exists := cropDB[id]; exists {
		cropData.ID = id
		cropData.CreatedAt = time.Now()
		return cropData
	}

	// Default fallback to Tomato if unknown UUID
	return Crop{
		ID:                   id,
		Name:                 "Unknown Crop (Default: Tomato)",
		IdealTemp:            25.0,
		BaselineSpoilageRate: 2.5,
		CreatedAt:            time.Now(),
	}
}

// ── Weather (Database Cache) ────────────────

func fetchWeatherFromDB(lat, lon, idealTemp float64) WeatherInfo {
	if db != nil {
		var w struct {
			Temp     float64 `db:"temp"`
			Humidity float64 `db:"humidity"`
		}
		err := db.Get(&w, `
			SELECT temp, humidity 
			FROM weather_cache 
			ORDER BY location <-> ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography 
			LIMIT 1`, lon, lat)
		if err == nil {
			return WeatherInfo{
				CurrentTemp: w.Temp,
				Humidity:    w.Humidity,
				TempDelta:   w.Temp - idealTemp,
				Condition:   "Clear Sky", // Static for now
			}
		}
		log.Printf("⚠ DB fetch weather failed: %v", err)
	}

	// Mock fallback
	return WeatherInfo{
		CurrentTemp: 32.4,
		Humidity:    68.0,
		TempDelta:   32.4 - idealTemp,
		Condition:   "Partly Cloudy",
	}
}

// ── Historical AI Models ────────────────────

// ── Historical AI Models ────────────────────

// forecastPriceTrend performs a simple linear regression over the historical prices to project a 7-day trend (pct)
func forecastPriceTrend(prices []float64) float64 {
	if len(prices) < 3 {
		return 0 // Need at least 3 points for a meaningful trend
	}

	// We'll use up to 15 recent prices
	if len(prices) > 15 {
		prices = prices[len(prices)-15:]
	}

	n := float64(len(prices))
	sumX, sumY, sumXY, sumX2 := 0.0, 0.0, 0.0, 0.0

	for i, y := range prices {
		x := float64(i)
		sumX += x
		sumY += y
		sumXY += x * y
		sumX2 += x * x
	}

	denom := (n*sumX2 - sumX*sumX)
	if denom == 0 {
		return 0
	}
	slope := (n*sumXY - sumX*sumY) / denom

	current := prices[len(prices)-1]
	projected := current + (slope * 7)

	if current <= 0 {
		return 0
	}
	pctChange := ((projected - current) / current) * 100.0
	return pctChange
}

// calculateVolumeTrend infers arrival volume based on recent price pressure.
// A sharp drop in price implies a HIGH arrival glut. A sharp rise implies LOW arrivals.
func calculateVolumeTrend(prices []float64) string {
	if len(prices) < 5 {
		return "NORMAL"
	}

	recentSum := 0.0
	for i := len(prices) - 3; i < len(prices); i++ {
		recentSum += prices[i]
	}
	recentAvg := recentSum / 3.0

	pastSum := 0.0
	// use up to 7 days prior to the last 3 days
	pastCount := 0
	for i := len(prices) - 10; i < len(prices)-3; i++ {
		if i >= 0 {
			pastSum += prices[i]
			pastCount++
		}
	}

	if pastCount == 0 {
		return "NORMAL"
	}

	pastAvg := pastSum / float64(pastCount)

	// Price dropped significantly -> huge arrivals (Glut)
	if recentAvg < pastAvg*0.85 {
		return "HIGH"
	} else if recentAvg > pastAvg*1.15 {
		return "LOW" // Price spiked -> shortage
	}
	return "NORMAL"
}

// fetchHistoricalPrices fetches chronological price slices for a given market and crop
func fetchHistoricalPrices(mandiName string, cropName string) []float64 {
	var prices []float64
	if db != nil {
		err := db.Select(&prices, `
			SELECT dp.price 
			FROM daily_prices dp
			JOIN mandis m ON m.id = dp.mandi_id
			WHERE m.name = $1 AND dp.crop_name = $2
			ORDER BY dp.recorded_at ASC
			LIMIT 15`, mandiName, cropName)
		if err == nil {
			return prices
		}
	}
	return prices
}

// ── Market Prices (PostGIS Cache) ─────────────

func fetchMarketPricesFromDB(cropID string, cropName string, lat, lon float64) []MandiPrice {
	if db != nil {
		type result struct {
			MarketName string    `db:"market_name"`
			Price      float64   `db:"price"`
			Lat        float64   `db:"lat"`
			Lon        float64   `db:"lon"`
			RecordedAt time.Time `db:"recorded_at"`
		}
		var rows []result
		err := db.Select(&rows, `
			SELECT m.name as market_name, dp.price, ST_Y(m.location::geometry) as lat, ST_X(m.location::geometry) as lon, dp.recorded_at
			FROM mandis m
			JOIN daily_prices dp ON dp.mandi_id = m.id
			WHERE dp.crop_name = $1
			ORDER BY m.location <-> ST_SetSRID(ST_MakePoint($3, $2), 4326)::geography
			LIMIT 10`, cropName, lat, lon)

		if err == nil && len(rows) > 0 {
			var prices []MandiPrice
			for i, r := range rows {
				pricesList := fetchHistoricalPrices(r.MarketName, cropName)
				if len(pricesList) == 0 {
					pricesList = []float64{r.Price} // Fallback to at least current payload price
				}

				prices = append(prices, MandiPrice{
					ID:                 fmt.Sprintf("db-%d", i+1),
					MarketName:         r.MarketName,
					CropID:             cropID,
					CurrentPrice:       r.Price,
					MarketLat:          r.Lat,
					MarketLon:          r.Lon,
					ArrivalVolumeTrend: calculateVolumeTrend(pricesList),
					PriceTrendPct:      math.Round(forecastPriceTrend(pricesList)*100) / 100,
					Timestamp:          r.RecordedAt,
				})
			}
			return prices
		}
		log.Printf("⚠ DB fetch mandi prices failed: %v", err)
	}

	// FALLBACK
	now := time.Now()
	m1Hist := []float64{2400, 2450, 2480, 2520, 2500}
	m2Hist := []float64{2700, 2720, 2750, 2780, 2800}
	m3Hist := []float64{2500, 2480, 2420, 2380, 2350} // Dropping
	m4Hist := []float64{2600, 2610, 2630, 2640, 2650}

	return []MandiPrice{
		{ID: "m1", MarketName: "Azadpur Mandi", CropID: cropID, CurrentPrice: 2500, MarketLat: 28.7041, MarketLon: 77.1525, ArrivalVolumeTrend: calculateVolumeTrend(m1Hist), PriceTrendPct: math.Round(forecastPriceTrend(m1Hist)*100) / 100, Timestamp: now},
		{ID: "m2", MarketName: "Vashi APMC", CropID: cropID, CurrentPrice: 2800, MarketLat: 19.0728, MarketLon: 73.0169, ArrivalVolumeTrend: calculateVolumeTrend(m2Hist), PriceTrendPct: math.Round(forecastPriceTrend(m2Hist)*100) / 100, Timestamp: now},
		{ID: "m3", MarketName: "Ghazipur Mandi", CropID: cropID, CurrentPrice: 2350, MarketLat: 28.6233, MarketLon: 77.3230, ArrivalVolumeTrend: calculateVolumeTrend(m3Hist), PriceTrendPct: math.Round(forecastPriceTrend(m3Hist)*100) / 100, Timestamp: now},
		{ID: "m4", MarketName: "Pune APMC", CropID: cropID, CurrentPrice: 2650, MarketLat: 18.5204, MarketLon: 73.8567, ArrivalVolumeTrend: calculateVolumeTrend(m4Hist), PriceTrendPct: math.Round(forecastPriceTrend(m4Hist)*100) / 100, Timestamp: now},
	}
}

// LiveMandiRecord represents a single record from the data.gov.in API.
type LiveMandiRecord struct {
	Market     string  `json:"market"`
	Commodity  string  `json:"commodity"`
	ModalPrice float64 `json:"modal_price"`
	State      string  `json:"state"`
	District   string  `json:"district"`
}

// getCoordinatesForMarket provides a static mapping of market names to coordinates.
func getCoordinatesForMarket(market, state string) (float64, float64) {
	dict := map[string][]float64{
		"Azadpur":       {28.7041, 77.1525},
		"Ghazipur":      {28.6233, 77.3230},
		"Narela":        {28.8526, 77.0932},
		"Vashi":         {19.0728, 73.0169},
		"Pune":          {18.5204, 73.8567},
		"Nashik":        {20.0059, 73.7900},
		"Doharighat":    {26.2736, 83.5822},
		"Kolar":         {13.1367, 78.1292},
		"Chittoor":      {13.2172, 79.1003},
		"Delhi":         {28.6139, 77.2090},
		"Maharashtra":   {19.7515, 75.7139},
		"Uttar Pradesh": {26.8467, 80.9462},
		"Gujarat":       {22.2587, 71.1924},
		"Karnataka":     {15.3173, 75.7139},
	}

	if coords, ok := dict[market]; ok {
		return coords[0], coords[1]
	}
	if coords, ok := dict[state]; ok {
		return coords[0] + 0.1, coords[1] + 0.1 // Slight perturbation to avoid exact duplicates
	}
	// Fallback random perturbation around central India to ensure variance
	randOffset := float64(len(market)) / 100.0
	return 28.6139 + randOffset, 77.2090 + randOffset
}

// fetchLiveMandiPrices fetches live mandi prices from data.gov.in.
func fetchLiveMandiPrices(apiKey string, cropName string) ([]LiveMandiRecord, error) {
	url := fmt.Sprintf(
		"https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070?api-key=%s&format=json&filters[commodity]=%s&sort[arrival_date]=desc&limit=10",
		apiKey, cropName,
	)

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("data.gov.in request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("data.gov.in returned status %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response body: %w", err)
	}

	// The API returns: { "records": [ { "market": "...", "modal_price": "...", ... } ] }
	var apiResp struct {
		Records []struct {
			Market     string  `json:"market"`
			Commodity  string  `json:"commodity"`
			ModalPrice float64 `json:"modal_price"`
			State      string  `json:"state"`
			District   string  `json:"district"`
		} `json:"records"`
	}

	if err := json.Unmarshal(body, &apiResp); err != nil {
		return nil, fmt.Errorf("failed to parse data.gov.in JSON: %w", err)
	}

	var records []LiveMandiRecord
	for _, r := range apiResp.Records {
		// modal_price is per Quintal (100kg), divide by 100 for price_per_kg
		records = append(records, LiveMandiRecord{
			Market:     r.Market,
			Commodity:  r.Commodity,
			ModalPrice: r.ModalPrice, // keep as per quintal to match our CurrentPrice field
			State:      r.State,
			District:   r.District,
		})
	}

	return records, nil
}

// ── Storage Facilities ──────────────────────

func fetchNearestStorage(farmerLat, farmerLon float64) StorageOption {
	if db != nil {
		var facilities []StorageFacility
		err := db.Select(&facilities, "SELECT id, name, location_lat, location_lon, capacity_mt, price_per_kg FROM storage_facilities")
		if err == nil && len(facilities) > 0 {
			// Find nearest by haversine
			bestIdx := 0
			bestDist := math.MaxFloat64
			for i, f := range facilities {
				d := haversine(farmerLat, farmerLon, f.LocationLat, f.LocationLon)
				if d < bestDist {
					bestDist = d
					bestIdx = i
				}
			}
			f := facilities[bestIdx]
			return StorageOption{
				Name:       f.Name,
				DistanceKm: math.Round(bestDist*10) / 10,
				PricePerKg: f.PricePerKg,
				CapacityMT: f.CapacityMT,
			}
		}
		log.Printf("⚠ DB fetch storage failed: %v – using fallback", err)
	}
	// FALLBACK: realistic cold storage near Delhi
	dist := haversine(farmerLat, farmerLon, 28.8526, 77.0932)
	return StorageOption{
		Name:       "Narela Cold Storage",
		DistanceKm: math.Round(dist*10) / 10,
		PricePerKg: 2.0,
		CapacityMT: 500.0,
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
					Duration float64 `json:"duration"`
				} `json:"routes"`
			}
			if json.Unmarshal(body, &result) == nil && len(result.Routes) > 0 {
				return result.Routes[0].Duration / 3600.0
			}
		}
	}

	log.Printf("⚠ OSRM API failed – using haversine fallback")
	dist := haversine(farmerLat, farmerLon, marketLat, marketLon)
	return dist / 40.0
}

func haversine(lat1, lon1, lat2, lon2 float64) float64 {
	const R = 6371.0
	dLat := (lat2 - lat1) * math.Pi / 180.0
	dLon := (lon2 - lon1) * math.Pi / 180.0
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*math.Pi/180.0)*math.Cos(lat2*math.Pi/180.0)*
			math.Sin(dLon/2)*math.Sin(dLon/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
	return R * c
}

// ══════════════════════════════════════════════
//  SCORING & DECISION ENGINE (Phase 2)
// ══════════════════════════════════════════════

func CalculateSpoilageRisk(factors SpoilageFactors) string {
	effectiveTransit := factors.TransitTimeHours
	if factors.RoadQuality == "unpaved" {
		effectiveTransit *= 1.8
	}

	effectiveTemp := factors.TemperatureCelsius
	if factors.CropMaturity == "Late" {
		effectiveTemp += 5.0
	}

	if effectiveTemp > 35 && effectiveTransit > 10 {
		return "HIGH"
	}
	if effectiveTemp > 30 || effectiveTransit > 5 {
		return "MEDIUM"
	}
	return "LOW"
}

func GenerateExplanation(marketName string, netProfitPerKg float64, riskLevel string, rainProb int) string {
	return fmt.Sprintf("Sell at %s. It offers ₹%.2f/kg more after transport costs. Spoilage risk during transit is %s. Weather context: %d%% chance of rain tomorrow.",
		marketName, netProfitPerKg, riskLevel, rainProb)
}

func computeMarketScores(farmer Farmer, crop Crop, markets []MandiPrice, weather WeatherInfo, roadQuality string, cropMaturity string) []MarketOption {
	options := make([]MarketOption, 0, len(markets))

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
		if roadQuality == "unpaved" {
			transitHr *= 1.8 // Vibration bruising penalty
		}

		tempFactor := 1.0 + math.Abs(weather.TempDelta)/10.0
		if cropMaturity == "Late" {
			tempFactor *= 2.0 // Late harvest decays twice as fast from ambient heat
		}

		spoilagePct := crop.BaselineSpoilageRate * transitHr * tempFactor
		transportPenalty := transitTimes[i] * 50.0 // Standard hr cost
		effectivePrice := m.CurrentPrice * (1 - spoilagePct/100.0)
		score := effectivePrice - transportPenalty

		// Distance via haversine
		distKm := haversine(farmer.LocationLat, farmer.LocationLon, m.MarketLat, m.MarketLon)

		// Net profit estimate: effective price minus transport cost
		netProfit := effectivePrice - transportPenalty

		// Penalize HIGH arrival volume markets (glut discount)
		if m.ArrivalVolumeTrend == "HIGH" {
			score *= 0.85 // 15% penalty for oversupply risk
			netProfit *= 0.85
		} else if m.ArrivalVolumeTrend == "LOW" {
			score *= 1.05 // 5% bonus for undersupply opportunity
			netProfit *= 1.05
		}

		// ── PHASE 7: Ground Truth Confidence Aggregation ──
		var avgReportedPrice float64
		var reportCount int

		err := db.QueryRow(`
			SELECT COALESCE(AVG(reported_price), 0), COUNT(report_id)
			FROM crowdsource_reports
			WHERE market_name = $1 AND crop_name = $2
			  AND timestamp >= NOW() - INTERVAL '24 hours'
		`, m.MarketName, crop.Name).Scan(&avgReportedPrice, &reportCount)

		// If we have statistical significance via WhatsApp pings (n >= 3)
		if err == nil && reportCount >= 3 && avgReportedPrice > 0 {
			varianceRatio := avgReportedPrice / m.CurrentPrice
			log.Printf("🤖 Ground Truth Active: %s / %s (n=%d) -> Official API: %.2f | Crowd: %.2f | Variance: %.2fx",
				m.MarketName, crop.Name, reportCount, m.CurrentPrice, avgReportedPrice, varianceRatio)

			// Override Official scores using the Crowd Truth variance
			score *= varianceRatio
			netProfit *= varianceRatio
		}

		options = append(options, MarketOption{
			MarketName:         m.MarketName,
			CurrentPrice:       m.CurrentPrice,
			DistanceKm:         math.Round(distKm*100) / 100,
			TransitTimeHr:      math.Round(transitHr*100) / 100,
			SpoilageLoss:       math.Round(spoilagePct*100) / 100,
			NetProfitEstimate:  math.Round(netProfit*100) / 100,
			MarketScore:        math.Round(score*100) / 100,
			ArrivalVolumeTrend: m.ArrivalVolumeTrend,
			PriceTrendPct:      m.PriceTrendPct,
		})
	}

	return options
}

func decideActionV2(crop Crop, weather WeatherInfo, soil SoilHealth, best MarketOption, trend string, cbMin, cbMax float64) (string, string, string) {
	action := "Sell at Mandi"
	harvestWindow := "Harvest Today"
	var reasons []string

	// Price Forecast logic (replacing hallucinated text)
	if best.PriceTrendPct > 2.0 {
		reasons = append(reasons,
			fmt.Sprintf("Our regression model projects a +%.1f%% price increase over the next 7 days at %s.", best.PriceTrendPct, best.MarketName))
		if best.TransitTimeHr < 5 && weather.TempDelta < 5 { // Safe to wait
			action = "Wait"
			harvestWindow = "Delay Harvest (3-5 Days)"
		}
	} else if best.PriceTrendPct < -2.0 {
		reasons = append(reasons,
			fmt.Sprintf("Our model projects a %.1f%% price drop over the next 7 days at %s. Selling immediately is advised to lock in profits.", best.PriceTrendPct, best.MarketName))
	} else {
		reasons = append(reasons,
			fmt.Sprintf("Prices at %s are projected to remain relatively stable (%.1f%% change) over the next week. Recommended price band: ₹%.0f to ₹%.0f.", best.MarketName, best.PriceTrendPct, cbMin, cbMax))
	}

	// Soil & Temperature analysis for Harvest Window
	if soil.MoisturePct < 20 {
		harvestWindow = "Harvest Today"
		reasons = append(reasons,
			fmt.Sprintf("Soil moisture is critically low (%.1f%%). Harvest immediately to prevent wilting and preserve crop weight.", soil.MoisturePct))
	} else if math.Abs(weather.TempDelta) <= 5 {
		if action != "Wait" {
			harvestWindow = "Optimal: Next 2-3 Days"
		}
		reasons = append(reasons,
			fmt.Sprintf("Current temperature (%.1f°C) is close to the ideal %.1f°C for %s with good soil moisture (%.1f%%).",
				weather.CurrentTemp, crop.IdealTemp, crop.Name, soil.MoisturePct))
	} else if weather.TempDelta > 5 {
		if action != "Wait" {
			harvestWindow = "Harvest Today"
			action = "Sell at Mandi"
		}
		reasons = append(reasons,
			fmt.Sprintf("It is %.1f°C hotter than ideal for %s. Harvesting sooner reduces heat-related spoilage.",
				weather.TempDelta, crop.Name))
	} else {
		if action != "Sell at Mandi" {
			action = "Wait"
			harvestWindow = "Delay Harvest (4-7 Days)"
		}
		reasons = append(reasons,
			fmt.Sprintf("Temperatures are %.1f°C below ideal for %s. Waiting for warmer conditions may improve quality.",
				math.Abs(weather.TempDelta), crop.Name))
	}

	// Market analysis
	reasons = append(reasons,
		fmt.Sprintf("%s offers the best effective price at ₹%.0f/quintal (Market Score: %.0f, Transit: %.1f hrs, Spoilage: %.1f%%).",
			best.MarketName, best.CurrentPrice, best.MarketScore, best.TransitTimeHr, best.SpoilageLoss))

	// Volume trend warning
	if trend == "HIGH" {
		reasons = append(reasons,
			fmt.Sprintf("⚠ HIGH arrival volumes detected at %s — risk of price depression due to oversupply.", best.MarketName))
	} else if trend == "LOW" {
		reasons = append(reasons,
			fmt.Sprintf("LOW arrival volumes at %s — favorable conditions for higher realized prices.", best.MarketName))
	}

	// Humidity warning
	if weather.Humidity > 80 {
		reasons = append(reasons,
			fmt.Sprintf("High humidity (%.0f%%) — consider immediate transport to reduce moisture-related decay.", weather.Humidity))
	}

	// Weather condition
	if weather.Condition == "Rain" || weather.Condition == "Rain Showers" || weather.Condition == "Thunderstorm" {
		action = "Wait"
		reasons = append(reasons,
			fmt.Sprintf("Current weather: %s. Delaying transport until conditions improve.", weather.Condition))
	}

	why := ""
	for i, r := range reasons {
		why += fmt.Sprintf("%d. %s\n", i+1, r)
	}

	return action, harvestWindow, why
}

func getDynamicPreservationActions(cropName string, riskLevel string, weather WeatherInfo, transitHrs float64) []PreservationAction {
	var actions []PreservationAction

	// Base actions based on risk level
	if riskLevel == "HIGH" {
		actions = append(actions, PreservationAction{
			ActionName:    "Use Refrigerated Transport (Cold Chain)",
			CostEstimate:  "₹1500/trip",
			Effectiveness: "Very High (Halts rot completely)",
		})
	}

	// Weather based actions
	if weather.Condition == "Rain" || weather.Condition == "Rain Showers" || weather.Condition == "Thunderstorm" {
		actions = append(actions, PreservationAction{
			ActionName:    "Cover with Heavy-Duty Tarpaulin",
			CostEstimate:  "₹300/trip",
			Effectiveness: "High (Prevents waterlogging)",
		})
	} else if weather.CurrentTemp > 35 {
		actions = append(actions, PreservationAction{
			ActionName:    "Use Reflective Thermal Covers",
			CostEstimate:  "₹500/trip",
			Effectiveness: "Medium (Reduces heat absorption)",
		})
	}

	// Crop specific actions
	if cropName == "Tomato" {
		actions = append(actions, PreservationAction{
			ActionName:    "Use Ventilated Plastic Crates instead of Sacks",
			CostEstimate:  "₹50/crate",
			Effectiveness: "High (Prevents 80% crushing)",
		})
	} else if cropName == "Onion" || cropName == "Potato" {
		actions = append(actions, PreservationAction{
			ActionName:    "Ensure Dry Jute Bags / Mesh Sacks",
			CostEstimate:  "₹20/bag",
			Effectiveness: "High (Allows breathing)",
		})
	}

	// Transit time based actions
	if transitHrs > 8 {
		actions = append(actions, PreservationAction{
			ActionName:    "Apply Neem-based Anti-fungal spray pre-transit",
			CostEstimate:  "₹120/acre",
			Effectiveness: "Medium (Delays fungal growth)",
		})
	}

	// Default fallback if no conditions met
	if len(actions) == 0 {
		actions = append(actions, PreservationAction{
			ActionName:    "Basic Sorting & Grading before Transport",
			CostEstimate:  "Labor Intensive",
			Effectiveness: "Medium (Removes infected crops)",
		})
	}

	// Assign ranks based on order of addition (highest priority first)
	for i := range actions {
		actions[i].Rank = i + 1
	}

	// Cap to top 3 actions for UI simplicity
	if len(actions) > 3 {
		actions = actions[:3]
	}

	return actions
}

// ══════════════════════════════════════════════
//  LOCALIZED EXPLAINABILITY STRINGS (SLM)
// ══════════════════════════════════════════════

func generateLocalizedStrings(whyEn, action, cropName, marketName, langCode string) string {
	if langCode == "en" {
		return whyEn
	}

	apiKey := os.Getenv("GEMINI_API_KEY")
	if apiKey == "" || apiKey == "your_api_key_here" {
		log.Println("WARNING: GEMINI_API_KEY not found. Using fallback translation.")
		return whyEn
	}

	url := "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=" + apiKey

	prompt := fmt.Sprintf("You are a professional translator for an Indian agricultural app.\n"+
		"Translate the following English recommendation into the language represented by this ISO code: '%s'.\n\n"+
		"Action: %s\nCrop: %s\nMarket: %s\n"+
		"English Text to Translate:\n%s\n\n"+
		"CRITICAL INSTRUCTIONS:\n"+
		"1. You MUST translate the ENTIRE text into the exact regional language for ISO code '%s' (e.g. if 'gu', output ONLY Gujarati).\n"+
		"2. Do NOT leave any English words. Translate terms like 'Market Score', 'Transit', and 'Spoilage' into the target language.\n"+
		"3. Maintain the numbered list formatting (1., 2., 3.).\n"+
		"4. Respond with ONLY the translated text. No markdown, no introductions, no JSON.", langCode, action, cropName, marketName, whyEn, langCode)

	reqBody := map[string]interface{}{
		"contents": []map[string]interface{}{
			{
				"parts": []map[string]string{
					{"text": prompt},
				},
			},
		},
		"generationConfig": map[string]interface{}{
			"temperature": 0.3,
		},
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return whyEn
	}

	client := &http.Client{Timeout: 60 * time.Second}
	resp, err := client.Post(url, "application/json", bytes.NewBuffer(jsonData))
	if err != nil || resp.StatusCode != http.StatusOK {
		var bodyStr string
		if resp != nil && resp.Body != nil {
			b, _ := io.ReadAll(resp.Body)
			bodyStr = string(b)
		}
		status := 0
		if resp != nil {
			status = resp.StatusCode
		}
		log.Printf("SLM API failed: err %v, status: %d, body: %s", err, status, bodyStr)
		return whyEn
	}
	defer resp.Body.Close()

	var result struct {
		Candidates []struct {
			Content struct {
				Parts []struct {
					Text string `json:"text"`
				} `json:"parts"`
			} `json:"content"`
		} `json:"candidates"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err == nil {
		if len(result.Candidates) > 0 && len(result.Candidates[0].Content.Parts) > 0 {
			responseText := result.Candidates[0].Content.Parts[0].Text
			responseText = strings.TrimSpace(responseText)
			return responseText
		}
	}

	return whyEn
}
func translatePreservationActions(actions []PreservationAction, langCode string) []PreservationAction {
	if langCode == "en" || len(actions) == 0 {
		return actions
	}

	apiKey := os.Getenv("GEMINI_API_KEY")
	if apiKey == "" || apiKey == "your_api_key_here" {
		return actions
	}

	url := "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=" + apiKey

	actionsJSON, _ := json.Marshal(actions)

	prompt := fmt.Sprintf("You are an expert translator for Indian agriculture. "+
		"Translate the values of 'action_name', 'cost_estimate', and 'effectiveness' in this JSON array to the language represented by ISO code '%s'. "+
		"Keep the JSON structure strictly identical. Return ONLY valid JSON, no markdown formatting.\n\n%s", langCode, string(actionsJSON))

	reqBody := map[string]interface{}{
		"contents": []map[string]interface{}{
			{
				"parts": []map[string]string{
					{"text": prompt},
				},
			},
		},
		"generationConfig": map[string]interface{}{
			"temperature":      0.1,
			"responseMimeType": "application/json",
		},
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return actions
	}

	client := &http.Client{Timeout: 60 * time.Second}
	resp, err := client.Post(url, "application/json", bytes.NewBuffer(jsonData))
	if err != nil || resp.StatusCode != http.StatusOK {
		return actions
	}
	defer resp.Body.Close()

	var result struct {
		Candidates []struct {
			Content struct {
				Parts []struct {
					Text string `json:"text"`
				} `json:"parts"`
			} `json:"content"`
		} `json:"candidates"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err == nil {
		if len(result.Candidates) > 0 && len(result.Candidates[0].Content.Parts) > 0 {
			responseText := strings.TrimSpace(result.Candidates[0].Content.Parts[0].Text)
			// Remove possible markdown backticks if Gemini ignored instructions
			responseText = strings.TrimPrefix(responseText, "```json")
			responseText = strings.TrimPrefix(responseText, "```")
			responseText = strings.TrimSuffix(responseText, "```")
			responseText = strings.TrimSpace(responseText)

			var translatedActions []PreservationAction
			if err := json.Unmarshal([]byte(responseText), &translatedActions); err == nil {
				return translatedActions
			}
		}
	}

	return actions
}

func fallbackTranslations(action, cropName, marketName string) (string, string) {
	if action == "Wait" {
		hi := fmt.Sprintf("अभी %s की कटाई न करें। बेहतर परिस्थितियों की प्रतीक्षा करें। %s सबसे अच्छा बाजार है।", cropName, marketName)
		mr := fmt.Sprintf("सध्या %s कापणी करू नका। चांगल्या परिस्थितीची वाट पहा। %s सर्वोत्तम बाजार आहे.", cropName, marketName)
		return hi, mr
	}
	hi := fmt.Sprintf("कीमतें स्थिर हैं। %s की कटाई करें और %s में बेचें।", cropName, marketName)
	mr := fmt.Sprintf("किमती स्थिर आहेत. %s पीक काढा आणि %s मध्ये विका.", cropName, marketName)
	return hi, mr
}

// ══════════════════════════════════════════════
//  CHAT / ASSISTANT HANDLER (Phase 2)
// ══════════════════════════════════════════════

func handleChat(c *gin.Context) {
	var req ChatRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid payload format"})
		return
	}

	if req.FarmerID == "" || req.CropID == "" || req.QueryText == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "farmer_id, crop_id, and query_text are required"})
		return
	}

	farmer := fetchFarmer(req.FarmerID)
	crop := fetchCrop(req.CropID)

	langCode := req.Lang
	if langCode == "" {
		langCode = "en"
	}

	apiKey := os.Getenv("GEMINI_API_KEY")
	if apiKey == "" || apiKey == "your_api_key_here" {
		c.JSON(http.StatusOK, ChatResponse{Reply: "Error: AI not configured."})
		return
	}

	url := "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=" + apiKey

	prompt := fmt.Sprintf("You are an agricultural advisor for a farmer.\n"+
		"Farmer's Crop: %s\n"+
		"Location Lat/Lon: %.4f, %.4f\n\n"+
		"The farmer asks: \"%s\"\n\n"+
		"Use the context of their crop and role to answer efficiently in under 3 sentences.\n"+
		"CRITICAL: Answer EXCLUSIVELY in the language represented by this ISO code: '%s'. Do NOT leave any English words un-translated. Respond with ONLY the exact translated paragraph. No markdown, no URLs, no JSON.",
		crop.Name, farmer.LocationLat, farmer.LocationLon, req.QueryText, langCode)

	reqBody := map[string]interface{}{
		"contents": []map[string]interface{}{
			{
				"parts": []map[string]string{
					{"text": prompt},
				},
			},
		},
		"generationConfig": map[string]interface{}{
			"temperature": 0.4,
		},
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to build AI request"})
		return
	}

	client := &http.Client{Timeout: 60 * time.Second}
	resp, err := client.Post(url, "application/json", bytes.NewBuffer(jsonData))
	if err != nil || resp.StatusCode != http.StatusOK {
		status := 0
		var bodyStr string
		if resp != nil {
			status = resp.StatusCode
			if resp.Body != nil {
				b, _ := io.ReadAll(resp.Body)
				bodyStr = string(b)
				resp.Body.Close()
			}
		}
		log.Printf("Chat SLM API failed. Status: %d, err: %v, Body: %s", status, err, bodyStr)

		fallbackReply := "I'm currently experiencing high network traffic. Please try again in about a minute."
		if status == 429 {
			if langCode == "hi" {
				fallbackReply = "सर्वर पर अभी अधिक लोड है। कृपया एक मिनट प्रतीक्षा करें।"
			} else {
				fallbackReply = "Google Gemini rate limit exceeded. Please wait a minute before querying."
			}
		}

		c.JSON(http.StatusOK, ChatResponse{Reply: fallbackReply})
		return
	}
	defer resp.Body.Close()

	var result struct {
		Candidates []struct {
			Content struct {
				Parts []struct {
					Text string `json:"text"`
				} `json:"parts"`
			} `json:"content"`
		} `json:"candidates"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err == nil {
		if len(result.Candidates) > 0 && len(result.Candidates[0].Content.Parts) > 0 {
			responseText := strings.TrimSpace(result.Candidates[0].Content.Parts[0].Text)
			c.JSON(http.StatusOK, ChatResponse{Reply: responseText})
			return
		}
	}

	c.JSON(http.StatusOK, ChatResponse{Reply: "I couldn't generate a response."})
}
