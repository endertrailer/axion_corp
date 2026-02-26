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
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	r := gin.Default()

	r.GET("/api/v1/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok", "time": time.Now()})
	})

	r.GET("/api/v1/recommendation", handleRecommendation)

	log.Printf("🚀 AgriChain API listening on 0.0.0.0:%s\n", port)
	if err := r.Run("0.0.0.0:" + port); err != nil {
		log.Fatalf("server failed: %v", err)
	}
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

	// ── Step 2: Concurrent external data fetches ──
	var wg sync.WaitGroup
	var weather WeatherInfo
	var markets []MandiPrice

	wg.Add(2)
	go func() {
		defer wg.Done()
		weather = fetchWeather(farmer.LocationLat, farmer.LocationLon, crop.IdealTemp)
	}()
	go func() {
		defer wg.Done()
		markets = fetchMarketPrices(cropID)
	}()
	wg.Wait()

	// ── Step 3: Compute transit times + market scores ──
	marketOptions := computeMarketScores(farmer, crop, markets, weather)

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
	action, why := decideActionV2(crop, weather, bestMarket, bestTrend, confidenceMin, confidenceMax)

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

	// ── Step 6: Localized Strings ──
	whyHi, whyMr := generateLocalizedStrings(action, crop.Name, bestMarket.MarketName, confidenceMin, confidenceMax, weather, storageOpt)

	recommendation := Recommendation{
		FarmerID:          farmerID,
		CropName:          crop.Name,
		Action:            action,
		RecommendedMarket: bestMarket.MarketName,
		MarketScore:       math.Round(bestMarket.MarketScore*100) / 100,
		ConfidenceBandMin: confidenceMin,
		ConfidenceBandMax: confidenceMax,
		Why:               why,
		WhyHi:             whyHi,
		WhyMr:             whyMr,
		Weather:           weather,
		Markets:           marketOptions,
		Storage:           storageOpt,
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
			"SELECT id, market_name, crop_id, current_price, market_lat, market_lon, arrival_volume_trend, timestamp FROM mandi_prices WHERE crop_id = $1 ORDER BY timestamp DESC LIMIT 10",
			cropID,
		)
		if err == nil && len(prices) > 0 {
			return prices
		}
		log.Printf("⚠ DB fetch mandi prices failed: %v – using fallback", err)
	}
	// FALLBACK: realistic market data with volume trends
	now := time.Now()
	return []MandiPrice{
		{ID: "m1", MarketName: "Azadpur Mandi", CropID: cropID, CurrentPrice: 2500, MarketLat: 28.7041, MarketLon: 77.1525, ArrivalVolumeTrend: "HIGH", Timestamp: now},
		{ID: "m2", MarketName: "Vashi APMC", CropID: cropID, CurrentPrice: 2800, MarketLat: 19.0728, MarketLon: 73.0169, ArrivalVolumeTrend: "NORMAL", Timestamp: now},
		{ID: "m3", MarketName: "Ghazipur Mandi", CropID: cropID, CurrentPrice: 2350, MarketLat: 28.6233, MarketLon: 77.3230, ArrivalVolumeTrend: "LOW", Timestamp: now},
		{ID: "m4", MarketName: "Pune APMC", CropID: cropID, CurrentPrice: 2650, MarketLat: 18.5204, MarketLon: 73.8567, ArrivalVolumeTrend: "NORMAL", Timestamp: now},
	}
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
	if factors.TemperatureCelsius > 35 && factors.TransitTimeHours > 10 {
		return "HIGH"
	}
	if factors.TemperatureCelsius > 30 || factors.TransitTimeHours > 5 {
		return "MEDIUM"
	}
	return "LOW"
}

func GenerateExplanation(marketName string, netProfitPerKg float64, riskLevel string, rainProb int) string {
	return fmt.Sprintf("Sell at %s. It offers ₹%.2f/kg more after transport costs. Spoilage risk during transit is %s. Weather context: %d%% chance of rain tomorrow.",
		marketName, netProfitPerKg, riskLevel, rainProb)
}

func computeMarketScores(farmer Farmer, crop Crop, markets []MandiPrice, weather WeatherInfo) []MarketOption {
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
		tempFactor := 1.0 + math.Abs(weather.TempDelta)/10.0
		spoilagePct := crop.BaselineSpoilageRate * transitHr * tempFactor
		transportPenalty := transitHr * 50.0
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

		options = append(options, MarketOption{
			MarketName:         m.MarketName,
			CurrentPrice:       m.CurrentPrice,
			DistanceKm:         math.Round(distKm*100) / 100,
			TransitTimeHr:      math.Round(transitHr*100) / 100,
			SpoilageLoss:       math.Round(spoilagePct*100) / 100,
			NetProfitEstimate:  math.Round(netProfit*100) / 100,
			MarketScore:        math.Round(score*100) / 100,
			ArrivalVolumeTrend: m.ArrivalVolumeTrend,
		})
	}

	return options
}

func decideActionV2(crop Crop, weather WeatherInfo, best MarketOption, trend string, cbMin, cbMax float64) (string, string) {
	action := "Sell at Mandi"
	var reasons []string

	// Confidence band
	reasons = append(reasons,
		fmt.Sprintf("Price is likely between ₹%.0f and ₹%.0f at %s.",
			cbMin, cbMax, best.MarketName))

	// Temperature analysis
	if math.Abs(weather.TempDelta) <= 5 {
		reasons = append(reasons,
			fmt.Sprintf("Current temperature (%.1f°C) is close to the ideal %.1f°C for %s, making conditions favorable for harvest.",
				weather.CurrentTemp, crop.IdealTemp, crop.Name))
	} else if weather.TempDelta > 5 {
		reasons = append(reasons,
			fmt.Sprintf("It is %.1f°C hotter than ideal for %s. Harvesting sooner reduces heat-related spoilage.",
				weather.TempDelta, crop.Name))
	} else {
		action = "Wait"
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
		why += fmt.Sprintf("%d. %s ", i+1, r)
	}

	return action, why
}

// ══════════════════════════════════════════════
//  LOCALIZED EXPLAINABILITY STRINGS
// ══════════════════════════════════════════════

func generateLocalizedStrings(action, cropName, marketName string, cbMin, cbMax float64, weather WeatherInfo, storage *StorageOption) (string, string) {
	var hi, mr string

	if action == "Delay & Store Locally" && storage != nil {
		hi = fmt.Sprintf(
			"कीमतें ₹%.0f से ₹%.0f के बीच हो सकती हैं। %s में भारी आवक के कारण, हम %s में ₹%.1f/kg पर भंडारण की सलाह देते हैं। "+
				"तापमान %.1f°C है, मौसम %s है। आवक सामान्य होने पर %s में बेचें।",
			cbMin, cbMax, marketName, storage.Name, storage.PricePerKg,
			weather.CurrentTemp, translateWeatherHi(weather.Condition), marketName,
		)
		mr = fmt.Sprintf(
			"किमती ₹%.0f ते ₹%.0f दरम्यान असू शकतात। %s मध्ये मोठ्या प्रमाणात आवक झाल्यामुळे, %s मध्ये ₹%.1f/kg दराने साठवणूक करा। "+
				"तापमान %.1f°C आहे, हवामान %s आहे। आवक सामान्य झाल्यावर %s मध्ये विक्री करा.",
			cbMin, cbMax, marketName, storage.Name, storage.PricePerKg,
			weather.CurrentTemp, translateWeatherMr(weather.Condition), marketName,
		)
	} else if action == "Wait" {
		hi = fmt.Sprintf(
			"अभी %s की कटाई न करें। तापमान %.1f°C है और मौसम %s है। बेहतर परिस्थितियों की प्रतीक्षा करें। "+
				"कीमतें ₹%.0f से ₹%.0f के बीच हो सकती हैं। %s सबसे अच्छा बाजार है।",
			cropName, weather.CurrentTemp, translateWeatherHi(weather.Condition),
			cbMin, cbMax, marketName,
		)
		mr = fmt.Sprintf(
			"सध्या %s कापणी करू नका। तापमान %.1f°C आहे आणि हवामान %s आहे। चांगल्या परिस्थितीची वाट पहा। "+
				"किमती ₹%.0f ते ₹%.0f दरम्यान असू शकतात। %s सर्वोत्तम बाजार आहे.",
			cropName, weather.CurrentTemp, translateWeatherMr(weather.Condition),
			cbMin, cbMax, marketName,
		)
	} else {
		// Sell at Mandi / Harvest Now
		hi = fmt.Sprintf(
			"कीमतें स्थिर हैं। %s की कटाई करें और %s में बेचें। "+
				"अपेक्षित कीमत ₹%.0f से ₹%.0f प्रति क्विंटल है। तापमान %.1f°C है, मौसम %s है।",
			cropName, marketName, cbMin, cbMax,
			weather.CurrentTemp, translateWeatherHi(weather.Condition),
		)
		mr = fmt.Sprintf(
			"किमती स्थिर आहेत. %s पीक काढा आणि %s मध्ये विका. "+
				"अपेक्षित किंमत ₹%.0f ते ₹%.0f प्रति क्विंटल आहे. तापमान %.1f°C आहे, हवामान %s आहे.",
			cropName, marketName, cbMin, cbMax,
			weather.CurrentTemp, translateWeatherMr(weather.Condition),
		)
	}

	return hi, mr
}

func translateWeatherHi(condition string) string {
	switch condition {
	case "Clear Sky":
		return "साफ आसमान"
	case "Partly Cloudy":
		return "आंशिक बादल"
	case "Foggy":
		return "कोहरा"
	case "Drizzle":
		return "बूंदाबांदी"
	case "Rain":
		return "बारिश"
	case "Rain Showers":
		return "बारिश की बौछारें"
	case "Snow":
		return "बर्फबारी"
	case "Thunderstorm":
		return "आंधी-तूफान"
	default:
		return condition
	}
}

func translateWeatherMr(condition string) string {
	switch condition {
	case "Clear Sky":
		return "स्वच्छ आकाश"
	case "Partly Cloudy":
		return "अंशतः ढगाळ"
	case "Foggy":
		return "धुके"
	case "Drizzle":
		return "रिमझिम"
	case "Rain":
		return "पाऊस"
	case "Rain Showers":
		return "पावसाच्या सरी"
	case "Snow":
		return "बर्फवृष्टी"
	case "Thunderstorm":
		return "वादळ"
	default:
		return condition
	}
}
