---
phase: 3
plan: 1
wave: 1
---

# Plan 3.1: Offline Resilience & SharedPreferences Caching

## Objective
Implement local caching of the `Recommendation` data using `shared_preferences` so farmers can access their last known market and price trends when they lose internet connection. The UI must clearly indicate when data is being served from the offline cache versus live.

## Context
- .gsd/SPEC.md
- /home/endertrailer/agrichain/frontend/lib/api_service.dart
- /home/endertrailer/agrichain/frontend/lib/main.dart

## Tasks

<task type="auto" effort="medium">
  <name>Implement API Service Caching</name>
  <files>/home/endertrailer/agrichain/frontend/lib/api_service.dart</files>
  <action>
    Add an `isOffline` boolean (default `false`) to the `Recommendation` model and its `fromJson` parsing.
    In `ApiService.getRecommendation`, after a successful API fetch (HTTP 200), serialize and save the raw JSON string to `shared_preferences` under a key like `cached_recommendation`.
    In the `catch` block (when the network request times out or fails), attempt to retrieve `cached_recommendation` from `shared_preferences`. If it exists, parse it, set `isOffline = true`, and return it. If it does not exist, fall back to `_fallbackRecommendation()`.
  </action>
  <verify>dart build / flutter analyze</verify>
  <done>api_service.dart compiles and properly implements shared_preferences caching logic</done>
</task>

<task type="auto" effort="low">
  <name>Render Offline Indicator UI</name>
  <files>/home/endertrailer/agrichain/frontend/lib/main.dart</files>
  <action>
    Modify `_buildBody()` or `_buildLocationBanner()` to check `rec.isOffline`. 
    If `true`, render a clearly visible warning banner (e.g., orange or grey background with an `Icons.cloud_off` icon) at the top of the screen stating "Viewing cached offline data. Check connection to refresh." (You can use hardcoded string or translation if practical).
  </action>
  <verify>flutter analyze</verify>
  <done>Flutter UI properly checks for `isOffline` and conditionally renders a warning banner</done>
</task>

## Success Criteria
- [ ] Successful API recommendations are serialized and stored to local device storage.
- [ ] Network failures gracefully load the last known cached data instead of just the static mock.
- [ ] The farmer is visually informed when looking at stale `isOffline` data.
