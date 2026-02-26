---
phase: 7
plan: 1
wave: 1
---

# Plan 7.1: Crowdsourced Feedback Schema & Ingestion

## Objective
Establish the database architecture and webhook endpoints necessary to receive localized Mandi price verification pings directly from Farmers via WhatsApp.

## Context
- .gsd/ROADMAP.md (Phase 7)
- backend/schema.sql
- backend/main.go

## Tasks

<task type="auto" effort="low">
  <name>Extend PostgreSQL Database Schema</name>
  <files>
    /home/endertrailer/agrichain/backend/schema.sql
  </files>
  <action>
    Append a new `crowdsource_reports` table to the database initialization.
    Fields must track: `report_id` (UUID), `phone_number` (String), `market_name` (String), `crop_name` (String), `reported_price` (Decimal), and `timestamp` (Time).
  </action>
  <verify>Check `schema.sql` parsing in Go backend restart.</verify>
  <done>The database can structurally accept verified prices pinged from WhatsApp farmers.</done>
</task>

<task type="auto" effort="medium">
  <name>Construct WhatsApp Webhook Receiver</name>
  <files>
    /home/endertrailer/agrichain/backend/main.go
  </files>
  <action>
    Deploy a new `POST /api/v1/webhook/whatsapp` Gin HTTP route.
    Accept generic JSON payloads (mimicking the Meta WhatsApp Business API). 
    Extract the localized string (e.g. "Azadpur Tomato 2500"). Add simple regex logic to parse Market, Crop, and Price.
    Commit this extracted data using standard SQL `INSERT INTO crowdsource_reports`.
  </action>
  <verify>go build</verify>
  <done>The backend actively listens for incoming WhatsApp confirmation packets and indexes them.</done>
</task>

---

---
phase: 7
plan: 2
wave: 2
---

# Plan 7.2: Confidence Band Aggregation (Ground Truth)

## Objective
Rewire the `computeMarketScores` AI predictive engine to intersect official API market data with crowd-sourced WhatsApp inputs, functionally overriding or skewing the Profitability Output Confidence bands based on raw reality.

## Tasks

<task type="auto" effort="high">
  <name>Calculate Crowd-Truth Variance in Engine</name>
  <files>
    /home/endertrailer/agrichain/backend/main.go
  </files>
  <action>
    Within `computeMarketScores`, immediately after calculating the Base `NetProfitEstimate` for a `MarketOption`:
    Execute an SQL `SELECT AVG(reported_price), COUNT(report_id) FROM crowdsource_reports` targeting the last 24 hours.
    If `COUNT > 3` (minimum threshold met), calculate the % variance between the official data.gov API and the WhatsApp farmers.
    Apply a "Ground Truth Penalty/Boost" to the `MarketScore` matrix based on this difference, actively overriding the SLM recommendation logic if official data is hallucinating or heavily delayed.
  </action>
  <verify>go build && run backend unit tests</verify>
  <done>The Recommendation AI inherently distrusts stale Official data if WhatsApp farmers report contrarian reality parameters over the preceding 24 hours.</done>
</task>

## Success Criteria
- [ ] Database accepts WhatsApp webhook parameters via Regex parsing mapping.
- [ ] Predictive AI confidence dynamically shrinks or balloons proportional to validated Crowd-truth variance checks.
