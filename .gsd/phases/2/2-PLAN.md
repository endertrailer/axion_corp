---
phase: 2
plan: 2
wave: 2
depends_on: ["1-PLAN"]
files_modified: ["backend/main.go", "backend/models.go", "frontend/lib/api_service.dart", "frontend/lib/main.dart"]
autonomous: true

must_haves:
  truths:
    - "A new REST endpoint receives the STT string and contextual farmer IDs."
    - "Google Gemini SLM generates a precise response in the requested regional language."
    - "The Flutter App retrieves the backend string and reads it aloud using the existing `flutter_tts` instance."
  artifacts:
    - "backend/main.go must contain the `/api/v1/chat` endpoint logic mapped to Gemini 2.5."
---

# Plan 2.2: Contextual LLM Chat & Audio Playback Route

<objective>
To securely route the captured STT string to the Go Backend, inject it into an LLM prompt wrapped with the existing farmer's data context, and return the output dynamically translated into the native ISO language. The app will then vocalize the response.

Purpose: Bridge the audio input safely to Gemini, giving the farmer an intelligent companion.
Output: Integrated API routes and live Flutter TTS vocalization matching the AI's reply.
</objective>

<context>
Load for context:
- .gsd/SPEC.md
- backend/main.go
- backend/models.go
</context>

<tasks>

<task type="auto">
  <name>Construct Context-Aware API Route</name>
  <files>backend/main.go, backend/models.go</files>
  <action>
    Create a `POST /api/v1/assistant` or `/chat` endpoint. Accept a struct: `{ farmer_id, crop_id, query_text, lang }`.
    Fetch the crop and location data implicitly like `handleRecommendation` does.
    Structure a strictly constrained prompt to `gemini-2.5-flash:generateContent`: "The farmer asks: [query_text]. Use the context of their current market scores to answer efficiently in under 3 sentences. Answer EXCLUSIVELY in ISO language: [lang]."
    AVOID: Permitting raw unfiltered web queries. The agent must act as an agricultural advisor contextually bound to the AgriChain schema.
  </action>
  <verify>curl -X POST payload succeeds against localhost:8080.</verify>
  <done>Gemini replies contextually in the target lang script without English.</done>
</task>

<task type="auto">
  <name>Frontend Chat Integration & TTS Triggers</name>
  <files>frontend/lib/api_service.dart, frontend/lib/main.dart</files>
  <action>
    Add an async fetching method `sendVoiceQuery(query)` in ApiService.
    When the Voice FAB releases and STT finishes, show a simple loading spinner overlay or standard circular indicator.
    Await the response string from the backend `POST` endpoint. 
    Upon receiving the string, immediately run `_speak(responseString)` so the `flutter_tts` engine synthesizes the audio.
    Dismiss the loading indicator.
    AVOID: Cluttering the UI with a persistent chat window unless designed. A simple overlay text that reads aloud is sufficient.
  </action>
  <verify>flutter analyze and build succeeds.</verify>
  <done>Audio flows out natively based on the returned response.</done>
</task>

</tasks>

<verification>
After all tasks, verify:
- [ ] Backend accepts the POST string payload and contextualizes it reliably.
- [ ] TTS successfully converts the localized response into audio stream output.
</verification>

<success_criteria>
- [ ] All tasks verified
- [ ] Must-haves confirmed
</success_criteria>
