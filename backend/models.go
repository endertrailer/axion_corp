package main

import (
	"time"
)

// ---------- Database Models ----------

// Farmer represents a registered farmer with geolocation.
type Farmer struct {
	ID          string  `json:"id" db:"id"`
	LocationLat float64 `json:"location_lat" db:"location_lat"`
	LocationLon float64 `json:"location_lon" db:"location_lon"`
	Phone       string  `json:"phone" db:"phone"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
}

// Crop represents an agricultural crop and its spoilage parameters.
type Crop struct {
	ID                  string  `json:"id" db:"id"`
	Name                string  `json:"name" db:"name"`
	IdealTemp           float64 `json:"ideal_temp" db:"ideal_temp"`
	BaselineSpoilageRate float64 `json:"baseline_spoilage_rate" db:"baseline_spoilage_rate"`
	CreatedAt           time.Time `json:"created_at" db:"created_at"`
}

// MandiPrice represents a live market price entry for a specific crop.
type MandiPrice struct {
	ID           string    `json:"id" db:"id"`
	MarketName   string    `json:"market_name" db:"market_name"`
	CropID       string    `json:"crop_id" db:"crop_id"`
	CurrentPrice float64   `json:"current_price" db:"current_price"`
	MarketLat    float64   `json:"market_lat" db:"market_lat"`
	MarketLon    float64   `json:"market_lon" db:"market_lon"`
	Timestamp    time.Time `json:"timestamp" db:"timestamp"`
}

// ---------- API Response Models ----------

// MarketOption represents a single market with its computed score.
type MarketOption struct {
	MarketName    string  `json:"market_name"`
	CurrentPrice  float64 `json:"current_price"`
	TransitTimeHr float64 `json:"transit_time_hr"`
	SpoilageLoss  float64 `json:"spoilage_loss_pct"`
	MarketScore   float64 `json:"market_score"`
}

// WeatherInfo holds the weather data relevant to the recommendation.
type WeatherInfo struct {
	CurrentTemp    float64 `json:"current_temp_c"`
	Humidity       float64 `json:"humidity_pct"`
	TempDelta      float64 `json:"temp_delta_from_ideal"`
	Condition      string  `json:"condition"`
}

// Recommendation is the top-level JSON payload returned to the frontend.
type Recommendation struct {
	FarmerID        string         `json:"farmer_id"`
	CropName        string         `json:"crop_name"`
	Action          string         `json:"action"`           // "Harvest Now" or "Wait"
	RecommendedMarket string       `json:"recommended_market"`
	MarketScore     float64        `json:"market_score"`
	Why             string         `json:"why"`
	Weather         WeatherInfo    `json:"weather"`
	Markets         []MarketOption `json:"markets"`
	GeneratedAt     time.Time      `json:"generated_at"`
}
