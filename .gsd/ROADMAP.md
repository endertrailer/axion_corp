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
**Status**: 🚧 Planned
**Objective**: Transform the single AI microphone interaction into a full-fledged chat interface dialog. Include conversation history bubbles, quick-action suggestion chips, text input, and voice input integration.

**Must-Haves**:
1. Tapping the AI Assistant FAB opens a modal/bottom-sheet chat window.
2. The UI must match a modern standard digital assistant interface (Header bar, scrollable message list, input area at the bottom).
3. The input area must contain both a text field and a submit/microphone button for dual modalities.
4. Chat bubbles must show the user's queries and the AI's contextual responses, keeping track of history for the session.
