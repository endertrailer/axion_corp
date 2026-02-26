---
phase: 6
plan: 1
wave: 1
---

# Plan 6.1: SLM-Driven Explainability (Backend)

## Objective
Implement a Small Language Model (SLM) or LLM via Gemini to dynamically synthesize the mathematical recommendation parameters into culturally empathetic and easily understandable strings for the farmer, across English, Hindi, and Marathi.

## Context
- .gsd/ROADMAP.md (Phase 6)
- /home/endertrailer/agrichain/backend/main.go

## Tasks

<task type="auto" effort="medium">
  <name>Integrate LLM API for localized synthesis</name>
  <files>
    /home/endertrailer/agrichain/backend/main.go
  </files>
  <action>
    Refactor `generateLocalizedStrings()` inside `main.go`. 
    Remove the hard-coded `switch` statements for Marathi and Hindi translations.
    Implement an HTTP POST request to the Gemini API (using the `GEMINI_API_KEY` from `.env`).
    Construct a prompt injecting the calculated `action`, `cropName`, `marketName`, and `weather` state, requesting a 2-sentence empathetic explanation returned in English, Hindi, and Marathi JSON format.
    Parse the LLM response safely with fallbacks to the old hardcoded strings if the API errors.
  </action>
  <verify>go build</verify>
  <done>Backend dynamically generates native, empathetic advice strings using an AI language model.</done>
</task>

---

---
phase: 6
plan: 2
wave: 2
---

# Plan 6.2: Audio-First UX (Frontend TTS)

## Objective
Convert the dynamic "Why" strings into localized Audio playback directly within the Flutter application, fulfilling the Audio-First UX accessibility requirement for farmers with low literacy.

## Tasks

<task type="auto" effort="low">
  <name>Install flutter_tts dependency</name>
  <files>
    /home/endertrailer/agrichain/frontend/pubspec.yaml
  </files>
  <action>
    Run `flutter pub add flutter_tts` in the `frontend` directory.
  </action>
  <verify>flutter pub get</verify>
  <done>Flutter TTS dependency is installed.</done>
</task>

<task type="auto" effort="medium">
  <name>Implement Audio Playback UI</name>
  <files>
    /home/endertrailer/agrichain/frontend/lib/screens/recommendation_screen.dart
  </files>
  <action>
    Initialize the `FlutterTts` instance within the Recommendation Screen state.
    Add a prominent "Listen / सुनें / ऐका" Floating Action Button or localized IconButton next to the "Why" text block.
    Wire the button to call `flutterTts.speak()` using the localized `why` string from the backend payload.
    Ensure `flutterTts.setLanguage()` dynamically switches between "en-IN", "hi-IN", and "mr-IN" based on the user's active locale before speaking.
  </action>
  <verify>Wait for manual or automated frontend review.</verify>
  <done>Farmers can tap a button to hear their personalized recommendation spoken aloud.</done>
</task>

## Success Criteria
- [ ] Backend generates explainability strings via an LLM.
- [ ] Frontend successfully compiles with `flutter_tts`.
- [ ] App UI exposes a playable button that dictations the fetched string natively.
