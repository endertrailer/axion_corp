# AgriChain — Project Specification

**Status**: DRAFT (Review with User)

## Core Value Proposition
AgriChain is a Farm-to-Market Intelligence Platform designed to help Indian farmers minimize post-harvest produce loss (which is currently up to 40% due to poor timing and market mismatch). The AI system ingests weather, soil health, and historical Mandi price data to recommend optimal harvest windows and target markets. It also suggests dynamic post-harvest preservation actions based on transit time and storage conditions to maximize the farmer's net profit.

## User Personas
* **The Farmer**: Basic Android smartphone user. Requires minimal data literacy. Outputs must be in plain, localized languages (Hindi, Marathi, English).
* **Core Need**: "Tell me *when* to harvest, *where* to sell it to make the most money, *how* to prevent rot during transit, and explicitly *why* you are giving me this advice."

## Technical Stack
* **Backend**: Go (Gin, sqlx, PostgreSQL)
* **Frontend**: Flutter / Dart
* **Integrations**: data.gov.in (Mandi Prices), Open-Meteo (Weather/Soil Moisture), OSRM (Transit Time)

## AI / Predictive Engine
* **Price Forecasting**: Real-time regressions over historical data to predict 7-day market trends.
* **Spoilage Risk AI**: Multi-variable calculation incorporating temperature deviation, transit hours, and crop-specific traits.
* **Staggering Protocol**: Volume-trend detection to flag market gluts ("HIGH" arrivals) and dynamically reroute to Cold Storage to prevent distress sales.

## Key Principles & Non-Negotiables
1. **Explainability & Trust**: The system must inherently explain *why* an action is recommended (e.g., citing a 17% price forecast increase or a 91% humidity risk). It cannot just say "Go to Market X".
2. **Deterministic Stability**: A specific farm shouldn't yield entirely erratic mock baseline data; geographical hashing provides stability while layering live open-source weather data.
3. **Low-Bandwidth Reality Check**: The architecture assumes poor rural connections (e.g., minimizing live API chokepoints by predicting and pre-stating knowns where possible).

---
*(Generated as part of the Get Shit Done for Antigravity standard framework integration.)*
