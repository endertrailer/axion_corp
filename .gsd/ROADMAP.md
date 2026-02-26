# ROADMAP.md

> **Current Phase**: Phase 1
> **Milestone**: v1.1

## Must-Haves (from SPEC)
- [x] Backend API accepts a `lang` parameter and dynamically returns Gemini SLM translations.
- [x] Frontend reads active `language_code` and passes it automatically to the Go Backend.
- [x] Flutter UI Text-To-Speech (TTS) updates its internal locale string based on selected language (e.g. `hi-IN` for Hindi, `te-IN` for Telugu).

## Phases

### Phase 1: Dynamic SLM Language Context & TTS Localization
**Status**: ✅ Complete
**Objective**: Overhaul the hardcoded English/Hindi/Marathi strings into a fully dynamic context-driven translation engine bridging Gemini AI to the Flutter TTS module.

### Phase 2: Agricultural Voice AI Assistant
**Status**: ✅ Complete
**Objective**: Introduce a conversational voice assistant integrating Speech-to-Text (STT) and contextual awareness of current recommendations, coupled with a bottom-nav UI restructure.

**Must-Haves**:
1. Float Assistant FAB bottom-right, move "Change Location" to bottom-left.
2. Implement Speech-to-Text capturing audio correctly into the selected UI language context.
3. Transmit audio text securely to the backend or use local Gemini integration to reply with relevant contextual data.
4. Synthesize that reply back through TTS natively.

### Phase 3: Interactive Chatbot Dialog Interface
**Status**: ✅ Complete
**Objective**: Transform the single AI microphone interaction into a full-fledged chat interface dialog. Include conversation history bubbles, quick-action suggestion chips, text input, and voice input integration.

**Must-Haves**:
1. Tapping the AI Assistant FAB opens a modal/bottom-sheet chat window.
2. The UI must match a modern standard digital assistant interface (Header bar, scrollable message list, input area at the bottom).
3. The input area must contain both a text field and a submit/microphone button for dual modalities.
4. Chat bubbles must show the user's queries and the AI's contextual responses, keeping track of history for the session.

### Phase 4: Chatbot Polish & Bug Fixes
**Status**: ✅ Complete
**Objective**: Fix the reported bugs in the Chatbot interface to ensure robust localization, stable backend connection, and accurate input-mode audio feedback.

**Must-Haves**:
1. All hardcoded English strings in the `ChatDialog` must be translated using `AppTranslations.t(key, _lang)` or passed translation context, including the initial welcome message.
2. Restart the Go backend process using the updated binary to eliminate the missing Endpoint `404` error for `/api/v1/chat`.
3. Change the Home Screen's `FloatingActionButton` icon from `Icons.mic` to `Icons.smart_toy` or `Icons.chat` to accurately reflect its new Chat interface behavior.
4. Modify the TTS logic so the Assistant's voice is *only* synthesized out loud if the preceding user query was inputted via Voice (Mic), remaining silent if inputted via Keyboard.

### Phase 5: Voice UX Enhancements
**Status**: ✅ Complete
**Objective**: Enhance the voice interaction loop by providing real-time transcription feedback and enforcing strict voice-response mirroring.

**Must-Haves**:
1. When the user taps the microphone and speaks, the STT engine must stream the recognized transcription directly into the ChatDialog's text input box in real-time, allowing them to verify or edit their query before it sends.
2. The AI assistant must strictly reply out loud (TTS) *only* when the user submits their query via voice. Text inputs strictly result in text outputs.

### Phase 6: Dynamic Crop Selection
**Status**: ✅ Complete
**Objective**: Allow the user to toggle which crop they are tracking directly from the Dashboard, fetching updated market, environmental, and preservation data for that specific item.

**Must-Haves**:
1. The backend must mathematically evaluate dynamic crop UUIDs for Tomatoes, Onions, and Potatoes.
2. The frontend must feature a dynamic crop switcher in the AppBar, visually reloading the metrics instantly upon selection.

### Phase 7: Comprehensive Crop Database & Picker UI
**Status**: ✅ Complete
**Objective**: Overhaul the application to support a vast array of Indian crops, vegetables, and fruits through a dedicated, searchable, language-localized selection screen rather than a simple 3-item dropdown.

**Must-Haves**:
1. Create a `CropPickerScreen` returning the selected UUID. Features a search bar and visually appealing grid or list layout.
2. Provide a master-list of ~20-30 diverse Indian crops spanning vegetables, fruits, and cash crops, completely mapped in the backend fallback logic.
3. Ensure every single crop name dynamically translates to the 22 Indian Languages through `frontend/lib/l10n/translations.dart`.
