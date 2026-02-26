<p align="center">
  <img src="https://img.shields.io/badge/Go-00ADD8?style=for-the-badge&logo=go&logoColor=white" />
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" />
  <img src="https://img.shields.io/badge/Gin-00ADD8?style=for-the-badge&logo=go&logoColor=white" />
</p>

# 🌾 AgriChain — Farm-to-Market Intelligence Platform

> **Empowering small-hold farmers with real-time, data-driven harvest and market recommendations — built to combat information asymmetry and prevent distress sales.**

AgriChain is a mobile-first intelligence platform that combines **live weather data**, **market price signals**, **transit time estimates**, and **arrival volume analysis** to generate actionable, trustworthy recommendations for farmers. It tells them **when** to harvest, **where** to sell, and **why** — in language they can trust.

---

## 🎯 The Problem

Indian farmers lose an estimated **₹92,651 crore annually** due to information asymmetry. They don't know:
- Which mandi offers the best price *after* accounting for transport and spoilage
- Whether a market is oversupplied (causing price crashes on arrival)
- If they should harvest now or wait for better conditions

AgriChain solves this with a **single API call** that fuses weather, market, logistics, and supply data into one clear recommendation.

---

## ✨ Key Features

### 🧠 Smart Recommendation Engine
- Fetches **live weather** from Open-Meteo (temperature, humidity, conditions)
- Compares **multiple mandi prices** with transit-time-adjusted scoring
- Calculates **spoilage risk** based on temperature delta, crop type, and transit duration
- Generates a **Market Score** = Effective Price − Transport Penalty − Spoilage Loss

### 🛡️ Anti-Glut Staggering Protocol
- Monitors `arrival_volume_trend` (HIGH / NORMAL / LOW) at each market
- When a market is oversupplied (**HIGH**), the system **blocks immediate sale** and routes the farmer to the **nearest cold storage facility**
- Prevents cartel-exploited distress sales during peak arrival surges

### 📊 Confidence Bands
- Displays a **price range** (±10%) instead of a single number
- Manages farmer psychology — prevents panic if the exact price isn't hit
- Includes oversupply warnings when relevant

### 🔒 Bulletproof Failsafes
Every external API call (Open-Meteo, OSRM, Database) has a **hardcoded fallback**:
- Weather API down → realistic seasonal dummy data
- OSRM timeout → haversine distance estimate at 40 km/h
- Database unavailable → demo farmer/crop/market data
- **The API endpoint never fails to return valid JSON**

### 📍 GPS Location Detection
- Auto-detects farmer's GPS position via `geolocator`
- Passes live coordinates to the backend for location-accurate weather + transit
- Graceful fallback to stored/default location if GPS is unavailable

### 💚 "Trust" UI
- **"Why are we suggesting this?"** — expandable section breaking down the reasoning
- Numbered explanations covering temperature, market score, humidity, and supply conditions
- Designed for low-literacy, low-bandwidth environments

---

## 🏗️ Architecture

```
┌─────────────────┐     HTTP/JSON      ┌──────────────────────┐
│   Flutter App    │ ◄──────────────► │    Go / Gin API       │
│   (Android)      │                   │    :8080              │
│                  │                   │                      │
│  • Dashboard     │                   │  • /recommendation   │
│  • GPS Location  │                   │  • Concurrent Fetch   │
│  • Trust UI      │                   │  • Scoring Engine     │
│  • Offline Mode  │                   │  • Staggering Logic   │
└─────────────────┘                   └──────────┬───────────┘
                                                  │
                              ┌────────────────────┼────────────────────┐
                              ▼                    ▼                    ▼
                     ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
                     │  Open-Meteo   │    │    OSRM      │    │  PostgreSQL  │
                     │  Weather API  │    │  Routing API │    │  (sqlx)      │
                     └──────────────┘    └──────────────┘    └──────────────┘
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| **Backend** | Go 1.21+, Gin, sqlx |
| **Database** | PostgreSQL 15+ |
| **Frontend** | Flutter 3.x (Android) |
| **Weather** | Open-Meteo API (free, no key) |
| **Routing** | OSRM (public demo server) |
| **Location** | Geolocator (Flutter) |

---

## 📁 Project Structure

```
agrichain/
├── backend/
│   ├── main.go          # Gin router, recommendation handler, staggering protocol
│   ├── models.go        # Go structs (DB + API response models)
│   ├── schema.sql       # PostgreSQL DDL + seed data
│   ├── go.mod / go.sum  # Go module dependencies
│
├── frontend/
│   ├── lib/
│   │   ├── main.dart        # Dashboard UI (cards, confidence bands, trust section)
│   │   ├── api_service.dart  # HTTP client, data models, offline fallback
│   │   └── api_config.dart   # Toggleable Wi-Fi / USB endpoint config
│   ├── android/              # Android manifest (GPS + network permissions)
│   └── pubspec.yaml
│
└── README.md
```

---

## 🚀 Quick Start

### Prerequisites
- Go 1.21+
- Flutter 3.x with Android SDK
- PostgreSQL 15+ *(optional — app runs fine without it)*

### 1. Start the Backend

```bash
cd backend
go run .
# 🚀 AgriChain API listening on 0.0.0.0:8080
```

> **No PostgreSQL?** No problem — the server starts in demo mode with hardcoded fallback data.

### 2. Run the Flutter App

```bash
cd frontend

# For Android emulator:
flutter run

# For physical device over Wi-Fi:
# Edit lib/api_config.dart → set lanIp to your machine's IP
flutter run

# For physical device over USB:
# Edit lib/api_config.dart → set useUsb = true
adb reverse tcp:8080 tcp:8080
flutter run
```

### 3. (Optional) Set Up PostgreSQL

```bash
createdb agrichain
psql agrichain < backend/schema.sql
export DATABASE_URL="postgres://user:pass@localhost:5432/agrichain?sslmode=disable"
cd backend && go run .
```

---

## 📡 API Reference

### `GET /api/v1/health`
Health check endpoint.

### `GET /api/v1/recommendation`

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `farmer_id` | UUID | ✅ | Farmer identifier |
| `crop_id` | UUID | ✅ | Crop identifier |
| `lat` | float | ❌ | GPS latitude (overrides stored location) |
| `lon` | float | ❌ | GPS longitude (overrides stored location) |

**Response:**
```json
{
  "action": "Delay & Store Locally",
  "recommended_market": "Azadpur Mandi",
  "market_score": 2097.13,
  "confidence_band_min": 2250,
  "confidence_band_max": 2750,
  "why": "1. Price is likely between ₹2250 and ₹2750. However, due to a massive arrival surge at Azadpur Mandi, we recommend storing at Narela Cold Storage for ₹2.0/kg...",
  "weather": { "current_temp_c": 27.1, "humidity_pct": 82, "condition": "Clear Sky" },
  "markets": [
    { "market_name": "Azadpur Mandi", "market_score": 2097, "arrival_volume_trend": "HIGH" }
  ],
  "storage": { "name": "Narela Cold Storage", "distance_km": 28.5, "price_per_kg": 2.0 }
}
```

---

## 🧪 Demo IDs (Seed Data)

| Entity | ID | Details |
|--------|-----|---------|
| **Farmer** | `a1b2c3d4-e5f6-7890-abcd-ef1234567890` | New Delhi |
| **Farmer** | `b2c3d4e5-f6a7-8901-bcde-f12345678901` | Mumbai |
| **Crop** | `c3d4e5f6-a7b8-9012-cdef-123456789012` | Tomato |
| **Crop** | `d4e5f6a7-b8c9-0123-defa-234567890123` | Wheat |
| **Crop** | `e5f6a7b8-c9d0-1234-efab-345678901234` | Rice |

---

## 🔮 Roadmap

- [ ] SMS-based interface for feature phones (USSD/WhatsApp)
- [ ] Historical price trend charts
- [ ] Multi-language support (Hindi, Marathi, Telugu)
- [ ] Cooperative group buying for cold storage
- [ ] ML-based price prediction models
- [ ] Integration with eNAM (National Agriculture Market)

---

## 📜 License

Built with ❤️ during a 24-hour hackathon. MIT License.
