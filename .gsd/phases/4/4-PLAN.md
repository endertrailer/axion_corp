---
phase: 4
plan: 1
wave: 1
---

# Plan 4.1: Database Schema & Async Ingestion Workers

## Objective
Shift from synchronous API calls to an asynchronous PostgreSQL + PostGIS architecture. We will define the database schema, write background cron-like workers in Go to ingest data, and refactor the main endpoint to query the database instantly.

## Context
- .gsd/SPEC.md
- /home/endertrailer/agrichain/backend/main.go
- Postgres connection handles already exist in `backend/go.mod` via `github.com/lib/pq`.

## Tasks

<task type="auto" effort="medium">
  <name>Init PostgreSQL + PostGIS Schema</name>
  <files>
    /home/endertrailer/agrichain/backend/schema.sql
    /home/endertrailer/agrichain/backend/db.go
  </files>
  <action>
    Create a `schema.sql` file containing the tables:
    1. `mandis` (id, name, location (GEOGRAPHY(Point,4326)))
    2. `daily_prices` (mandi_id, crop_name, price, recorded_at)
    3. `weather_cache` (geohash, temp, humidity, recorded_at)
    
    In `db.go`, write an initialization function `InitDB()` that connects using the `DATABASE_URL` environment variable and applies this schema if it doesn't exist.
  </action>
  <verify>go build</verify>
  <done>Database schema defined and connect logic written</done>
</task>

<task type="auto" effort="high">
  <name>Build Async Ingestion Workers</name>
  <files>
    /home/endertrailer/agrichain/backend/ingestion.go
    /home/endertrailer/agrichain/backend/main.go
  </files>
  <action>
    Create `ingestion.go` containing a background routine `StartIngestionCron(db *sqlx.DB)`.
    This routine should logically run on a `time.Ticker` (e.g., every 12 hours for Mandi prices, 1 hour for weather).
    Move the Open-Meteo and Data.gov.in fetch logic from `models.go` into these workers. The workers should parse the APIs and perform `INSERT INTO ... ON CONFLICT` upserts into PostgreSQL.
    Spawn this generic worker in `main.go` via a goroutine (`go StartIngestionCron(db)`) before `r.Run()`.
  </action>
  <verify>go build</verify>
  <done>Cron routines implemented to ingest and save data autonomously</done>
</task>

---

---
phase: 4
plan: 2
wave: 2
---

# Plan 4.2: Fast Database Query Endpoint

## Objective
Refactor the client endpoint to stop hanging on external APIs and completely rely on the PostgreSQL materialized tables.

## Tasks

<task type="auto" effort="medium">
  <name>Refactor Recommendation Endpoint</name>
  <files>
    /home/endertrailer/agrichain/backend/main.go
    /home/endertrailer/agrichain/backend/models.go
  </files>
  <action>
    Modify `handleRecommendation` in `main.go` to inject the DB context.
    Remove synchronous calls to weather and Mandi HTTP functions.
    Instead, execute an optimized PostGIS `ST_Distance` query to find the nearest `mandis` to the farmer's `lat`/`lon`, returning their latest `daily_prices` from the DB.
    Fetch the nearest `weather_cache` record.
    If the DB is empty (cache miss), fall back gracefully to the mock response.
  </action>
  <verify>go build</verify>
  <done>Endpoint optimized to serve responses purely from cached PostgreSQL data</done>
</task>

## Success Criteria
- [ ] No external API requests are performed during `GET /api/v1/recommendation` execution.
- [ ] Background workers successfully parse and insert external data into Postgres tables.
- [ ] PostGIS `ST_Distance` is used instead of naive haversine math to find nearby markets.
