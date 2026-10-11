# Architecture

Local-first Flutter app (Android + Windows). No backend; the user's own LLM key talks directly to Gemini or Groq.

```mermaid
flowchart TD
  UI[Feature UIs<br/>today, chat, tutor, practice, settings] --> P[Riverpod providers]
  P --> AG[Agent loop<br/>plan, tool, observe, max 6 steps]
  P --> TU[TutorService + HintLadder]
  AG --> LLM[LlmProvider<br/>Gemini / Groq REST + function calling]
  AG --> TL[Tools<br/>tasks, check-in, quiz, summarize, journal, memory, challenge]
  TL --> UM[UserModel<br/>goals, mastery, streak, mood]
  UM --> DB[(drift SQLite)]
  TL --> DB
  BG[workmanager 15 min / desktop Timer] --> MS[MentorService]
  MS --> POL[MentorPolicy<br/>rule-based, free]
  POL -- speak --> AG
  MS --> NOT[Notifier<br/>flutter_local_notifications]
  KS[(secure storage<br/>API keys)] --> LLM
```

## Layout
- `lib/core/` db (drift), llm providers, secure key store, notifications, v0.2 stubs (`sync/`, `usage/`).
- `lib/features/<name>/` agent (loop, tools, prompts), memory (UserModel), mentor (policy, service, background), tutor, challenges, today, chat, onboarding, settings.
- `lib/app/` app shell, Riverpod providers, composition.

## Key flows
1. **Silent by default**: every tick builds a `MentorState` from the DB and asks `MentorPolicy.decide` (no LLM). Only on "speak" is the agent called; failures fall back to an offline line.
2. **Silence budget**: max 3 proactive messages/day, 90 min gap; ~25% deliberate non-intervention on non-urgent nudges.
3. **Fading help**: `HintLadder.cap(mastery)` — strong learners never get the answer, only a hint.
4. **Tone**: mood <= 2.2 -> gentle; missed tasks/broken streak -> firm; otherwise warm.
