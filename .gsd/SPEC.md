# SPEC.md — Project Specification

> **Status**: `FINALIZED`

## Vision
Transform AgriChain into a fully App-Wide Native Language Engine, ensuring that every interface element, AI recommendation, and text-to-speech (TTS) output seamlessly adapts to any of the 22 supported Indian Scheduled Languages selected by the user.

## Goals
1. Implement dynamic translation of backend AI reasoning ('Why' string) via Gemini SLM by passing the language context in API headers or query parameters.
2. Synchronize the Flutter Text-to-Speech (TTS) engine (`flutter_tts`) to use the exact locale corresponding to the user's active language selection.
3. Ensure static UI elements and dynamic data arrays switch languages instantaneously upon user selection without requiring an app restart.
4. **[Phase 2]** Create an Agricultural Voice AI Assistant that farmers can converse with using Speech-to-Text (STT), maintaining context of the recommended data.
5. **[Phase 2]** Restructure UI: Float an LLM Assistant FAB (Floating Action Button) in the bottom right, and move the "Change Location" button to the bottom left.
6. **[Phase 3]** Build an Interactive Chatbot Dialog Interface: When the Assistant FAB is tapped, launch a dialog box containing a chat history, text input field, and voice chat integration.
7. **[Phase 4]** Chat UX Polish: Ensure fully localized UI texts inside the Chatbot, correct the home FAB icon to represent "Chat", and restrict TTS audio playback to *only* trigger when responding to voice inputs.
8. **[Phase 5]** Voice UX Enhancements: When using STT, stream the recognized speech directly into the text input box for visibility, and enforce strict audio response mirroring.

## Non-Goals (Out of Scope)
- Adding languages outside of the 22 Indian Scheduled Languages + English.
- Real-time video or real-time streaming translation.

## Users
Farmers and agricultural logistics personnel who are primarily comfortable in their native regional languages rather than English.

## Constraints
- Must maintain <= 2s latency for the recommendation endpoint, even with SLM language translation overhead.
- Must fall back gracefully to English or Hindi if the TTS engine lacks voice modules for a specific language on the user's Android device.

## Success Criteria
- [x] Users can select any supported language in the app settings, and it persists.
- [x] Backend API correctly receives the language context and returns fully translated Gemini AI reasoning.
- [x] Flutter TTS reads aloud the translated recommendations in the correct native phonetic voice.
- [x] **[Phase 2]** A farmer can tap the newly positioned bottom-right floating button to trigger STT and speak to the LLM.
- [x] **[Phase 2]** The LLM responds contextually incorporating the active farmer recommendations and converses entirely in the natively selected language.
- [x] **[Phase 2]** The 'Change Location' button is properly anchored to the bottom-left of the screen.
- [x] **[Phase 3]** Tapping the AI Assistant button opens a chat dialog / bottom sheet with a conversation history.
- [x] **[Phase 3]** The dialog supports both text input (keyboard) and voice input (STT microphone).
- [x] **[Phase 3]** Quick action chips (e.g. "What should I do?", "Weather context") are available above the input area.
- [x] **[Phase 4]** The Chat Dialog's UI text strings accurately translate to the active language.
- [x] **[Phase 4]** The Dashboard Assistant Button displays an appropriate chatbot/assistant icon, not strictly a microphone.
- [x] **[Phase 4]** The LLM plays TTS audio *only* if the user initiated the prompt via STT, remaining silent for text submissions.
- [x] **[Phase 5]** Speech-to-Text outputs are typed live into the ChatDialog's text input box.
- [x] **[Phase 5]** Voice Inputs trigger Voice Outputs. Text Inputs trigger Text Outputs.
