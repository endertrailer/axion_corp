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
