---
phase: 3
plan: 1
wave: 1
depends_on: []
files_modified: ["frontend/lib/widgets/chat_dialog.dart", "frontend/lib/main.dart"]
autonomous: true

must_haves:
  truths:
    - "Tapping the home screen's bottom-right AI FAB opens a Chat Dialog Interface."
    - "The Chat UI contains a conversational message list, quick actions, and a bottom text input field with a send/microphone button."
    - "The UI matches the aesthetic of a standard digital assistant (header bar, distinct user/bot bubbles)."
  artifacts:
    - "frontend/lib/widgets/chat_dialog.dart must encapsulate the chat UI layer."
---

# Plan 3.1: Frontend UI - Chat Dialog Interface

<objective>
To replace the simple "hold to speak" FAB logic with a full-fledged Chat Dialog UI overlay. The dialog will feature a header, a scrollable list of message bubbles, horizontal quick action chips, and a bottom text input area capable of toggling between keyboard and microphone input.

Purpose: Provide farmers a visual history of their conversation with the AI Advisor and allow them to explicitly type or speak their queries.
Output: A new stateful `ChatDialog` widget integrated into `main.dart`.
</objective>

<context>
Load for context:
- .gsd/SPEC.md
- frontend/lib/main.dart
</context>

<tasks>

<task type="auto">
  <name>Build ChatDialog UI Widget</name>
  <files>frontend/lib/widgets/chat_dialog.dart</files>
  <action>
    Create a new file `frontend/lib/widgets/chat_dialog.dart`.
    Implement a `StatefulWidget` named `ChatDialog`.
    Design the UI: 
    - Top bar: Blue/Green header with an AI Avatar icon (e.g. `Icons.smart_toy`), title "AgriChain Assistant", and a close button.
    - Body: A `ListView.builder` for rendering a mock list of `ChatMessage` objects (User vs AI bubbles styled with different background colors and border radiuses).
    - Quick Actions: A horizontal scrollable row of `ActionChip` widgets (e.g. "What should I do?", "Weather check").
    - Bottom Input: A `Row` containing an `Expanded(TextField)` and a right-aligned `IconButton` that alternates between `Icons.mic` and `Icons.send` depending on text input state.
    AVOID: Binding API logic right now. Focus strictly on the UX presentation and scaffolding the local list state.
  </action>
  <verify>flutter analyze passes on the new widget file.</verify>
  <done>ChatDialog widget accurately models the conversational mockup.</done>
</task>

<task type="auto">
  <name>Wire FAB to Open Dialog</name>
  <files>frontend/lib/main.dart</files>
  <action>
    Import `widgets/chat_dialog.dart`.
    Update the `FloatingActionButton` on the bottom-right: Remove the `GestureDetector` `onLongPress` STT logic temporarily.
    Change `onPressed` to invoke `showModalBottomSheet` or `showDialog` to display the `ChatDialog` taking up the majority of the screen height.
    Ensure padding constraints allow the keyboard to push the dialog up via `Scaffold`'s `resizeToAvoidBottomInset`.
  </action>
  <verify>flutter build apk dry-runs successfully.</verify>
  <done>FAB click seamlessly launches the Chat UI overlay.</done>
</task>

</tasks>

<verification>
After all tasks, verify:
- [ ] FAB tap triggers the Chat Dialog.
- [ ] Chat Dialog contains header, messages, quick action chips, and the bottom input bar.
</verification>

<success_criteria>
- [ ] All tasks verified
- [ ] Must-haves confirmed
</success_criteria>
