package main

import (
	"time"
)

// ---------- Database Models ----------

// Farmer represents a registered farmer with geolocation.
type Farmer struct {
	ID          string    `json:"id" db:"id"`
	LocationLat float64   `json:"location_lat" db:"location_lat"`
	LocationLon float64   `json:"location_lon" db:"location_lon"`
	Phone       string    `json:"phone" db:"phone"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
}

// Crop represents an agricultural crop and its spoilage parameters.
type Crop struct {
	ID                   string    `json:"id" db:"id"`
	Name                 string    `json:"name" db:"name"`
	IdealTemp            float64   `json:"ideal_temp" db:"ideal_temp"`
	BaselineSpoilageRate float64   `json:"baseline_spoilage_rate" db:"baseline_spoilage_rate"`
	CreatedAt            time.Time `json:"created_at" db:"created_at"`
}

// MandiPrice represents a live market price entry for a specific crop.
type MandiPrice struct {
	ID                 string    `json:"id" db:"id"`
	MarketName         string    `json:"market_name" db:"market_name"`
	CropID             string    `json:"crop_id" db:"crop_id"`
	CurrentPrice       float64   `json:"current_price" db:"current_price"`
	MarketLat          float64   `json:"market_lat" db:"market_lat"`
	MarketLon          float64   `json:"market_lon" db:"market_lon"`
	ArrivalVolumeTrend string    `json:"arrival_volume_trend" db:"arrival_volume_trend"`
	Timestamp          time.Time `json:"timestamp" db:"timestamp"`
}

// StorageFacility represents a cold storage / micro-storage option.
type StorageFacility struct {
	ID          string    `json:"id" db:"id"`
	Name        string    `json:"name" db:"name"`
	LocationLat float64   `json:"location_lat" db:"location_lat"`
	LocationLon float64   `json:"location_lon" db:"location_lon"`
	CapacityMT  float64   `json:"capacity_mt" db:"capacity_mt"`
	PricePerKg  float64   `json:"price_per_kg" db:"price_per_kg"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
}

// ---------- API Response Models ----------

// MarketOption represents a single market with its computed score.
type MarketOption struct {
	MarketName         string  `json:"market_name"`
	CurrentPrice       float64 `json:"current_price"`
	DistanceKm         float64 `json:"distance_km"`
	TransitTimeHr      float64 `json:"transit_time_hr"`
	SpoilageLoss       float64 `json:"spoilage_loss_pct"`
	NetProfitEstimate  float64 `json:"net_profit_estimate"`
	MarketScore        float64 `json:"market_score"`
	ArrivalVolumeTrend string  `json:"arrival_volume_trend"`
	IsAIRecommended    bool    `json:"is_ai_recommended"`
}

// WeatherInfo holds the weather data relevant to the recommendation.
type WeatherInfo struct {
	CurrentTemp float64 `json:"current_temp_c"`
	Humidity    float64 `json:"humidity_pct"`
	TempDelta   float64 `json:"temp_delta_from_ideal"`
	Condition   string  `json:"condition"`
}

// SoilHealth holds the mock soil indicators for the farmer's region.
type SoilHealth struct {
	MoisturePct float64 `json:"moisture_pct"`
	Nitrogen    float64 `json:"nitrogen"`
	Phosphorus  float64 `json:"phosphorus"`
	Potassium   float64 `json:"potassium"`
	Status      string  `json:"status"`
}

// StorageOption represents a nearby cold storage recommendation.
type StorageOption struct {
	Name       string  `json:"name"`
	DistanceKm float64 `json:"distance_km"`
	PricePerKg float64 `json:"price_per_kg"`
	CapacityMT float64 `json:"capacity_mt"`
}

// ConfidenceBand represents a price range for farmer psychology management.
type ConfidenceBand struct {
	Min float64 `json:"min"`
	Max float64 `json:"max"`
}

// PreservationAction represents a suggested preservation method ranked by effectiveness.
type PreservationAction struct {
	ActionName    string `json:"action_name"`
	CostEstimate  string `json:"cost_estimate"`
	Effectiveness string `json:"effectiveness"`
	Rank          int    `json:"rank"`
}

// Recommendation is the top-level JSON payload returned to the frontend.
type Recommendation struct {
	FarmerID          string               `json:"farmer_id"`
	CropName          string               `json:"crop_name"`
	Action            string               `json:"action"` // e.g. "Sell at Mandi", "Delay & Store Locally"
	HarvestWindow     string               `json:"harvest_window"`
	RecommendedMarket string               `json:"recommended_market"`
	MarketScore       float64              `json:"market_score"`
	ConfidenceBandMin float64              `json:"confidence_band_min"`
	ConfidenceBandMax float64              `json:"confidence_band_max"`
	Why               string               `json:"why"`
	WhyHi             string               `json:"explainability_string_hi"`
	WhyMr             string               `json:"explainability_string_mr"`
	Weather           WeatherInfo          `json:"weather"`
	Soil              SoilHealth           `json:"soil_health"`
	Markets           []MarketOption       `json:"markets"`
	Storage           *StorageOption       `json:"storage,omitempty"`
	Preservation      []PreservationAction `json:"preservation_actions"`
	GeneratedAt       time.Time            `json:"generated_at"`
}

// SpoilageFactors holds environmental and logistical data to determine spoilage risk.
type SpoilageFactors struct {
	TemperatureCelsius float64
	HumidityPercent    float64
	TransitTimeHours   float64
}
