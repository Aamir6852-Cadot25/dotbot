# Progress
## Done
- M1 scaffold + CI (analyze, test, APK, Windows zip artifacts)
- M2 drift storage + UserModel (profile, mastery, streak, mood)
- M3 Gemini/Groq providers, agent loop (max 6 steps), 12 tools, hint ladder
- M4 mentor policy (budget, gap, deliberate silence), MentorService, notifications, workmanager tick
- M5 UI: onboarding, chat (+PDF summarize), today/planner, mood, stoic journal, tutor, offline challenges, settings
- M6 docs: README, ARCHITECTURE, ADRs, DECISIONS, CONTRIBUTING; v0.2 stubs (SyncService, AppUsageService)
## Left / ideas
- Windows has no background scheduler (app ticks while open); tray/startup task in v0.2
- Per-task reminders via scheduled notifications; streaming chat; Supabase sync; app-usage signal
- Not yet tested on real devices; verify notification permission prompt on Android 13+
## Install
Latest GitHub Actions run -> artifacts: `dotbot-apk` (sideload) or `dotbot-windows` (unzip, run dotbot.exe). Open Settings/onboarding and paste a free Gemini or Groq key.
