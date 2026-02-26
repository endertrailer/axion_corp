# AgriChain — Project Specification

**Status**: DRAFT (Review with User)

## Core Value Proposition
AgriChain is a Farm-to-Market Intelligence Platform designed to help Indian farmers minimize post-harvest produce loss (which is currently up to 40% due to poor timing and market mismatch). The platform utilizes robust, async machine learning to ingest historical Mandi price data, dynamic soil health, and weather to recommend optimal harvest windows and target markets. It delivers highly personalized, dynamic post-harvest preservation actions and explains them via Audio-First UX.

## User Personas
* **The Farmer**: Basic Android smartphone user. Requires minimal data literacy. Outputs must be in plain, localized languages (Hindi, Marathi, English).
* **Core Need**: "Tell me *when* to harvest, *where* to sell it to make the most money, *how* to prevent rot during transit, and explicitly *why* you are giving me this advice."

## Technical Stack
* **Backend**: Go (Gin, sqlx, PostgreSQL with PostGIS extension for spatial queries)
* **Frontend**: Flutter / Dart
* **Integrations**: data.gov.in (Mandi Prices), Open-Meteo (Weather/Soil Moisture), OSRM (Transit Time), Small Language Models (SLM), Text-to-Speech (TTS), WhatsApp Business API.
* **Architecture Paradigms**: Asynchronous Data Ingestion (Cron), Offline-First Apps, Audio-First UX.

## AI / Predictive Engine
* **Price Forecasting**: Real-time regressions over historical data to predict 7-day market trends.
* **Spoilage Risk AI**: Multi-variable calculation incorporating temperature deviation, transit hours, and crop-specific traits.
* **Staggering Protocol**: Volume-trend detection to flag market gluts ("HIGH" arrivals) and dynamically reroute to Cold Storage to prevent distress sales.

## Key Principles & Non-Negotiables
1. **Explainability via SLMs**: The system must inherently explain *why* an action is recommended using culturally empathetic, dynamic language via Small Language Models, delivered as Audio-First (TTS) for accessibility.
2. **Asynchronous Ingestion**: Never run external APIs (gov.in, weather) synchronously during a farmer's request. Maintain a PostGIS database updated via cron, and serve recommendations instantly.
3. **Genuine Reality & Crowdsourcing**: Base spoilage calculations on reality (unpaved roads, truck vibration, crop maturity). Base price confidence on local WhatsApp crowdsourcing feedback loops.
4. **Offline-First Resilience**: Always cache last known data. Use SMS/USSD as fallbacks when internet fails completely.

---
*(Generated as part of the Get Shit Done for Antigravity standard framework integration.)*
