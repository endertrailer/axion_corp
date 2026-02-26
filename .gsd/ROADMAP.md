# ROADMAP.md

> **Current Phase**: Not started
> **Milestone**: v1.0

## Must-Haves (from SPEC)
- [ ] Implement Predictive Modeling & Historical Data Analysis in Backend
- [ ] Connect Frontend to Backend Dynamic Recommendations
- [ ] Render localization and dynamic explainability strings correctly in UI

## Phases

### Phase 1: Foundation (Backend AI Refactoring)
**Status**: ✅ Complete
**Objective**: Overhaul the Go backend to use deterministic geographical data and actual predictive modeling regressions instead of hardcoded rules.

### Phase 2: Frontend Integration
**Status**: ✅ Complete
**Objective**: Update the Flutter app `api_service` and UI screens to properly consume the new `why` fields and dynamic `preservation_actions` arrays.

### Phase 3: Offline Resilience & Testing
**Status**: ✅ Complete
**Objective**: Build out the offline failover capability as defined in the spec, allowing the farmer to get previous caching data without an internet connection.

### Phase 4: Async Data Ingestion & PostGIS Foundation
**Status**: ⬜ Not Started
**Objective**: Shift from synchronous remote API calls to an asynchronous ingestion architecture. Setup cron jobs in Go to continuously index Mandi prices, Weather, and pre-compute OSRM matrices into a PostgreSQL+PostGIS database.

### Phase 5: Genuine Machine Learning & Predictive Modeling
**Status**: ⬜ Not Started
**Objective**: Replace hardcoded if/else rules with true predictive models for historical price forecasting, volume trends, dynamic soil health, and comprehensive spoilage calculations incorporating road quality and crop maturity.

### Phase 6: SLM Explainability & Audio-First UX
**Status**: ⬜ Not Started
**Objective**: Implement Small Language Models (SLMs) to generate dynamic, culturally empathetic "Why" strings. Connect to a Text-to-Speech (TTS) API to deliver these outputs as audio directly to the farmer within the Flutter app.

### Phase 7: Hyper-local Crowdsourcing (WhatsApp Bot)
**Status**: ⬜ Not Started
**Objective**: Build a lightweight WhatsApp integration that allows farmers to verify live Mandi prices, creating a crowdsourced feedback loop to ground the AI and adjust confidence bands.
