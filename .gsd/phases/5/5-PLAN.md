---
phase: 5
plan: 1
wave: 1
---

# Plan 5.1: Database-Driven Historical Forecasting

## Objective
Replace the heuristic `simulateHistoricalData` functions with genuine machine learning / regression models calculating trends based on the exact historical dataset accrued asynchronously in Phase 4.

## Context
- .gsd/ROADMAP.md (Phase 5)
- /home/endertrailer/agrichain/backend/main.go
- /home/endertrailer/agrichain/backend/models.go

## Tasks

<task type="auto" effort="medium">
  <name>Transition forecasting to real PostGIS data</name>
  <files>
    /home/endertrailer/agrichain/backend/main.go
  </files>
  <action>
    Remove `simulateHistoricalData()` from `main.go`.
    Update `fetchMarketPricesFromDB` to query the `daily_prices` table for the last 15 days of real price points for a given `mandi_id` and `crop_name`.
    Refactor `forecastPriceTrend()` and `calculateVolumeTrend()` to accept these literal database slices (`[]float64`) instead of `[]HistoricalDataPoint` synthesized on the fly.
    Handle sparse data gracefully (e.g., if there are fewer than 3 days of historical prices, fall back to a 0% trend).
  </action>
  <verify>go build</verify>
  <done>Price and Volume predictions are derived exclusively from actual cached database ledgers</done>
</task>

---

---
phase: 5
plan: 2
wave: 2
---

# Plan 5.2: Advanced Spoilage & Maturity Logistics

## Objective
Enhance the hollow baseline spoilage calculation to integrate real-world logistics parameters: Unpaved rural road penalties, truck vibration risk, and strict crop maturity phases.

## Tasks

<task type="auto" effort="medium">
  <name>Augment Spoilage Risk Matrices</name>
  <files>
    /home/endertrailer/agrichain/backend/models.go
    /home/endertrailer/agrichain/backend/main.go
  </files>
  <action>
    In `models.go`, update the `SpoilageFactors` struct to include:
      - `RoadQuality` (string: "paved", "unpaved", "mixed")
      - `CropMaturity` (string: "Early", "Optimal", "Late")
    
    In `main.go`'s `CalculateSpoilageRisk()`, implement a tiered scalar logic:
      - If `RoadQuality` is "unpaved", inflate the baseline transit time spoilage by 1.8x due to vibration bruising.
      - If `CropMaturity` is "Late", accelerate the ambient temperature degradation curve by 2.0x.
      
    Update `handleRecommendation` to parse these optional parameters from the JSON via `c.Query` (defaulting to "mixed" and "Optimal") and feed them into the calculation.
  </action>
  <verify>go build</verify>
  <done>Spoilage modeling realistically accounts for road logistics and maturity phases</done>
</task>

## Success Criteria
- [ ] Live API queries do not use `simulateHistoricalData`.
- [ ] Regressions perform against PostGIS queries.
- [ ] Spoilage calculations scale penalty integers based on physical unpaved road vibration and biological crop maturity states.
