-- AgriChain Database Schema
-- PostgreSQL DDL for the farm-to-market intelligence platform.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Farmers table: stores farmer identity and geolocation.
CREATE TABLE IF NOT EXISTS farmers (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    location_lat DOUBLE PRECISION NOT NULL,
    location_lon DOUBLE PRECISION NOT NULL,
    phone       VARCHAR(20) NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Crops table: catalogue of supported crops with agri-parameters.
CREATE TABLE IF NOT EXISTS crops (
    id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name                 VARCHAR(100) NOT NULL,
    ideal_temp           DOUBLE PRECISION NOT NULL,  -- degrees Celsius
    baseline_spoilage_rate DOUBLE PRECISION NOT NULL, -- percentage per hour
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Mandi Prices table: live market prices for a given crop at a named market.
CREATE TABLE IF NOT EXISTS mandi_prices (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    market_name   VARCHAR(200) NOT NULL,
    crop_id       UUID NOT NULL REFERENCES crops(id) ON DELETE CASCADE,
    current_price DOUBLE PRECISION NOT NULL,  -- INR per quintal
    market_lat    DOUBLE PRECISION NOT NULL DEFAULT 0,
    market_lon    DOUBLE PRECISION NOT NULL DEFAULT 0,
    timestamp     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for frequent lookups.
CREATE INDEX IF NOT EXISTS idx_mandi_prices_crop_id ON mandi_prices(crop_id);
CREATE INDEX IF NOT EXISTS idx_mandi_prices_timestamp ON mandi_prices(timestamp DESC);

-- Seed data for development / demo.
INSERT INTO farmers (id, location_lat, location_lon, phone) VALUES
    ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', 28.6139, 77.2090, '+919876543210'),  -- New Delhi
    ('b2c3d4e5-f6a7-8901-bcde-f12345678901', 19.0760, 72.8777, '+919876543211');  -- Mumbai

INSERT INTO crops (id, name, ideal_temp, baseline_spoilage_rate) VALUES
    ('c3d4e5f6-a7b8-9012-cdef-123456789012', 'Tomato',  25.0, 2.5),
    ('d4e5f6a7-b8c9-0123-defa-234567890123', 'Wheat',   20.0, 0.5),
    ('e5f6a7b8-c9d0-1234-efab-345678901234', 'Rice',    30.0, 1.0);

INSERT INTO mandi_prices (market_name, crop_id, current_price, market_lat, market_lon) VALUES
    ('Azadpur Mandi',   'c3d4e5f6-a7b8-9012-cdef-123456789012', 2500.00, 28.7041, 77.1525),
    ('Vashi APMC',      'c3d4e5f6-a7b8-9012-cdef-123456789012', 2800.00, 19.0728, 73.0169),
    ('Ghazipur Mandi',  'c3d4e5f6-a7b8-9012-cdef-123456789012', 2350.00, 28.6233, 77.3230),
    ('Azadpur Mandi',   'd4e5f6a7-b8c9-0123-defa-234567890123', 2200.00, 28.7041, 77.1525),
    ('Indore Mandi',    'd4e5f6a7-b8c9-0123-defa-234567890123', 2100.00, 22.7196, 75.8577),
    ('Vashi APMC',      'e5f6a7b8-c9d0-1234-efab-345678901234', 3200.00, 19.0728, 73.0169);
