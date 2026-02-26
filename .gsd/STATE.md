# STATE.md

> **Purpose**: Session memory and context handoff. Update this frequently.

## Current Focus
* Integrating GSD framework.
* Phase 1 is done (Backend API).
* Preparing to execute Phase 2 (Frontend consumption).

## Blockers / Open Questions
* None currently.

## Key Technical Decisions
* Replaced fallback math with deterministic geohash for SoilHealth.
* Using local linear regression for 7-day trend projections instead of calling expensive ML APIs.
