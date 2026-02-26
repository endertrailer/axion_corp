---
phase: 2
plan: 1
wave: 1
depends_on: []
files_modified: ["frontend/lib/main.dart", "frontend/pubspec.yaml", "frontend/android/app/src/main/AndroidManifest.xml"]
autonomous: true

must_haves:
  truths:
    - "The 'Change Location' button rests stably on the bottom-left of the main UI."
    - "A conversational AI 'Microphone' FAB floats on the bottom-right."
    - "Speech-to-Text records accurate audio in the user's selected UI language locale."
  artifacts:
    - "frontend/lib/main.dart must contain speech-to-text integration logic."
---

# Plan 2.1: Frontend UI & Speech-to-Text Initialization

<objective>
To restructure the app layout per requirements and integrate microphone hardware access to capture farmer queries natively in regional Indian languages.

Purpose: Farmers shouldn't have to type queries. The mic enables accessible conversational interactions.
Output: Updated main UI logic with granted permissions layout shifts, and functional STT capturing.
</objective>

<context>
Load for context:
- .gsd/SPEC.md
- frontend/lib/main.dart
- frontend/pubspec.yaml
</context>

<tasks>

<task type="auto">
  <name>UI Restructure</name>
  <files>frontend/lib/main.dart</files>
  <action>
    Remove the existing 'Change Location' FloatingActionButton location entirely, and reconstruct the bottom stack.
    Place a `Positioned` or `Align` widget at the bottom-left for a standard 'Change Location' ElevatedButton/IconButton.
    Add a new `FloatingActionButton` at the bottom-right for the 'AI Assistant Microphone'. 
    AVOID: Breaking the scrollable constraint inside existing `Stack`/`Scaffold` layouts. Ensure padding accommodates the relocated button.
  </action>
  <verify>flutter build apk dry-runs successfully without flex boundary errors.</verify>
  <done>Location button physically sits bottom-left, LLM Mic physically sits bottom-right.</done>
</task>

<task type="auto">
  <name>Install STT & Permissions</name>
  <files>frontend/pubspec.yaml, frontend/android/app/src/main/AndroidManifest.xml</files>
  <action>
    Install `speech_to_text: ^6.6.1` and `permission_handler: ^11.3.1` (or latest stable) in pubspec.yaml.
    Inject `<uses-permission android:name="android.permission.RECORD_AUDIO"/>` into AndroidManifest.xml.
    AVOID: Editing `.gradle` files unnecessarily.
  </action>
  <verify>flutter pub get runs cleanly.</verify>
  <done>Dependencies and native Android microphone permissions are successfully declared.</done>
</task>

<task type="auto">
  <name>Bind STT to Active UI Language Locale</name>
  <files>frontend/lib/main.dart</files>
  <action>
    Initialize the `speech_to_text` instance inside the frontend state.
    On holding the new bottom-right FAB, start listening. Map the active UI `_lang` variable (e.g. 'hi') to Android STT Locales (e.g. 'hi-IN'). 
    Update an interim dialogue string `farmerQueryText` on the screen while capturing, then submit the final output format.
    AVOID: Hardcoding "en-US". The dictation MUST adapt to the dynamically active user app language.
  </action>
  <verify>flutter analyze passes.</verify>
  <done>Mic picks up native speech translated directly as raw String output.</done>
</task>

</tasks>

<verification>
After all tasks, verify:
- [ ] Change Location is accessible on the bottom-left.
- [ ] Assistant UI FAB rests on the bottom-right.
- [ ] STT parses verbal regional Indian language strictly to string.
</verification>

<success_criteria>
- [ ] All tasks verified
- [ ] Must-haves confirmed
</success_criteria>
