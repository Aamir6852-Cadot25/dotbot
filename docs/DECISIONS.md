# Decisions log
- Repo lives at D:\dotbot; Flutter stable cloned to D:\flutter (3.47.x).
- PDF: syncfusion rejected (non-permissive community license); decide at M3 (pdfrx/MIT or plain text only).
- sqlite3_flutter_libs dropped (EOL); drift_flutter bundles sqlite3.
- Generated drift code is gitignored; CI runs build_runner.
- Generated drift code (database.g.dart) is committed; CI still runs build_runner.
- Android: core library desugaring on, minSdk 23 (flutter_local_notifications, secure storage).
- Agent: tools return JSON observations; errors become observations, never crashes. After 6 LLM steps a final tool-free call is forced.
- Models: Gemini gemini-2.5-flash, Groq llama-3.3-70b-versatile (configurable in constructors).
- Hint ladder cap: mastery>=0.7 -> max "hint"; >=0.4 -> "partial"; else may reveal "answer". Beginners (<0.2) skip the bare question.
- PDF extraction injected via `extract(path)`; real implementation wired in M5.
- Renamed enum Trigger->Cause (clashes with drift's Trigger).

## College MVP (3-day build)
- Showcase = visible reasoning trace, long-term memory page, proactive policy, nightly self-reflection, results screen.
- `DemoProvider`: offline deterministic brain speaking the same function-calling protocol, so live demos never depend on Wi-Fi or quota.
- `DaySimulator`: replays a student's day on a fake clock through the REAL policy/agent/tools/tutor/reflection; covered by a test.
- Reflection is rule-based (testable) + optional LLM wording; it grades its own nudges (user acted within 2h?) and adapts the daily budget (1-4) and a strategy note injected into prompts.
- Rituals (morning/night) don't spend the silence budget; low mood uses the last 6h and is not repeated within 6h.
- Persona (friend/stoic/coach) + language (English/Hinglish) in the system prompt; the "healthy bond" rule redirects lonely users to people.
- Schema v2 migration: chat trace, mentor event reason/tone/message/effective, Facts, Reflections.
