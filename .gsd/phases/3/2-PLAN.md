---
phase: 3
plan: 2
wave: 2
depends_on: ["1-PLAN"]
files_modified: ["frontend/lib/widgets/chat_dialog.dart", "frontend/lib/main.dart"]
autonomous: true

must_haves:
  truths:
    - "Speech-to-Text records accurate audio inside the `ChatDialog` view directly."
    - "Text typed into the input field functions identically, parsing into the same API context."
    - "Both input modes populate the chat history bubble list with user queries, trigger a loading state, and append the translated AI response."
    - "The Flutter App retrieves the backend string and reads it aloud using the existing `flutterTts` instance."
  artifacts:
    - "frontend/lib/widgets/chat_dialog.dart must fully bind API integrations."
---

# Plan 3.2: UI Chat State Binding & Dual Modality AI Sync

<objective>
To migrate the `speech_to_text` and backend execution logic off the main screen's FAB and wire it directly into the newly created `ChatDialog`.

Purpose: Consolidate the context interaction into a single cohesive chat bubble sequence that supports both keyboard-typed intent and native vocal speech.
Output: A fully functional `ChatDialog` linked securely to the Go LLM `/api/v1/chat` endpoint.
</objective>

<context>
Load for context:
- .gsd/SPEC.md
- frontend/lib/widgets/chat_dialog.dart
- frontend/lib/main.dart
- frontend/lib/api_service.dart
</context>

<tasks>

<task type="auto">
  <name>Migrate STT State and Logic to Dialog</name>
  <files>frontend/lib/widgets/chat_dialog.dart, frontend/lib/main.dart</files>
  <action>
    Cut the `_initStt()`, `_startListening()`, and `_stopListening()` blocks from `main.dart`'s `DashboardScreen` and paste them into the `ChatDialog` state.
    Pass necessary contextual variables (`_lang`, `_farmerId`, `_cropId`, `flutterTts`) down through the `ChatDialog` constructor from `main.dart`.
    Update the `IconButton` toggle at the bottom of the Dialog to activate `_startListening()` when held if the TextField is empty, otherwise process it as a Text Submission.
  </action>
  <verify>flutter analyze</verify>
  <done>STT logic isolated into the Dialog UI component maintaining the `lang` Locale mapping.</done>
</task>

<task type="auto">
  <name>Bind Conversational AI Endpoint to Bubbles</name>
  <files>frontend/lib/widgets/chat_dialog.dart</files>
  <action>
    When a query is submitted (either via finalized STT speech or Text Send):
    1. Append a new User `ChatMessage` to the list.
    2. Add a temporary "Typing..." AI bubble and call `ApiService.sendVoiceQuery`.
    3. Upon response resolution, replace the temporary bubble with the actual AI `reply` data.
    4. Automatically trigger `_speak(reply)` using the injected `flutterTts` instance.
    AVOID: Keeping the `CircularProgressIndicator` overlay. Ensure interactions are seamlessly logged as inline dialogue bubbles.
  </action>
  <verify>flutter build apk dry-runs successfully</verify>
  <done>Text and Voice queries natively interact with Gemini and respond both visually and phonetically.</done>
</task>

</tasks>

<verification>
After all tasks, verify:
- [ ] Typing "What is the temp" pushes an AI bubble with the weather context.
- [ ] Tapping "Speak" captures STT strings, pushes an AI bubble, and reads the reply aloud natively.
</verification>

<success_criteria>
- [ ] All tasks verified
- [ ] Must-haves confirmed
</success_criteria>
