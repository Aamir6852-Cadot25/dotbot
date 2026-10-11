# Dotbot vision (from the owner's answers)

Dotbot is an **inner companion** that keeps you on track, with an **assistant** layer and a **learning** layer (the v0.1 mentor). Built for one user first (Aamir); open-source later.

## Layers
1. **Companion core**: personality, memory, adaptive timing, the "warm, then redirect" rule.
2. **Assistant**: day planning/reminders, relationship nudges, health and routine, money/career/college admin.
3. **Learning**: Socratic tutor, hint ladder, mastery (shipped in v0.1).

## Principles
- **Not a crutch**: comfort briefly, then send the user toward real people and the outside world ("go play, call your family"). Track reliance and taper availability; never pretend to be human.
- **Suggest only**: no phone lock-outs, no accessibility/device-admin. It earns trust through good suggestions.
- **Privacy**: everything on-device; a Memory page where the user can view, edit and delete every fact; only prompts go to the LLM. Minimal permissions, each opt-in.
- **Voice**: close friend + stoic mentor, mood-adaptive, English/Hindi/Hinglish.
- **Timing**: one adaptive scheduler that learns from everything (replies, logs, mood, routine) behind the existing silence budget.

## Roadmap
- v0.2 Memory page (view/delete) + persona and language settings (friend/stoic, Hinglish).
- v0.3 People: relationships list (who, last contact, birthdays) + "reach out" nudges and the loneliness flow.
- v0.4 Adaptive timing: record nudge outcomes (opened/replied/ignored by hour and tone), bandit-style scheduler.
- v0.5 Routine and health: sleep, water, outside-time logging; "go outside" suggestions.
- v0.6 Admin: expenses, placement/assignment deadlines, resume/interview prep tools.
- Reliance guard: weekly check of chat volume vs real-world activity; the agent reduces its own availability when dependence rises.
