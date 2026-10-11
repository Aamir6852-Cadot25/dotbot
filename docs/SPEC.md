# Dotbot — original spec (prompt)

Build "Dotbot" overnight while I sleep. Do NOT ask questions. Make sensible decisions and log them in docs/DECISIONS.md. Be token-efficient: short commits, no long explanations, don't reread files unnecessarily. Never commit secrets.

FIRST: save this prompt as docs/SPEC.md and commit.

WHAT: an open-source AI mentor agent that grows with the user and makes them independent. It is silent by default and speaks only at the right moment, sometimes leaving the user to struggle on purpose. Help fades as skill grows. Tone adapts to logged mood (firm when lazy, gentle when low). First user: Aamir, 2nd-year CSE, learning Java + DSA for placements.

STACK: Flutter (stable), one codebase targeting Android + Windows. Riverpod, drift (SQLite), flutter_secure_storage, flutter_local_notifications, workmanager (Android). Local-first, no backend.

AI BRAIN: LlmProvider interface with Gemini and Groq (OpenAI-compatible) implementations over REST with function calling. User pastes their own free key in onboarding (secure storage). Agent loop: plan, call tool, observe; max 6 steps.
TOOLS: tasks/day plan (create, update, complete), schedule check-in, tutor quiz, summarize text/PDF (open-source permissive PDF package), journal read/write, memory (user model: goals, weak topics, mastery 0-1 per topic, streaks, mood history), offline challenge.

MENTOR POLICY (rule-based, cheap; calls the LLM only when it decides to speak, to save the user's free quota): triggers = missed tasks, broken study streak, low quiz scores, low mood, morning/night check-in times. Includes a "silence budget" and occasional deliberate non-intervention.

FEATURES:
- Onboarding: name, goals, daily schedule, API key.
- Chat with the agent.
- Socratic tutor: hint ladder (question, hint, partial, answer), hint level driven by mastery.
- Day planner.
- Stoic morning intention + night review: the USER writes; the agent asks one question back.
- One-tap mood/energy log.
- Proactive notifications.
- Offline challenges.
- Stubs for v0.2: SyncService (no-op; Supabase planned), AppUsageService (no-op).
UI: Material 3, clean, dark/light, simple.

ENGINEERING (like a real team): feature-folder structure, docs/ARCHITECTURE.md with a diagram, ADRs in docs/adr, unit tests (agent loop with a fake LLM, mentor policy, hint ladder), README, CONTRIBUTING.md.
CI: GitHub Actions. On every push run flutter analyze + test; build the Android APK (ubuntu) and Windows release zip (windows runner); upload both as artifacts.

PROCESS: milestones.
1. Scaffold + CI green on both builds.
2. Storage + memory/user model.
3. LLM providers + agent loop + tools.
4. Mentor policy + notifications.
5. Tutor, planner, stoic review, mood, challenges UI.
6. Polish + docs.
After EACH milestone: commit, push, confirm CI passes, update PROGRESS.md (done / left / install steps). A working app after every milestone beats an unfinished perfect one.
