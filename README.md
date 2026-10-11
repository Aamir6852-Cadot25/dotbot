# Dotbot

Open-source AI mentor that stays quiet, speaks at the right moment, and works to make you independent. Built first for a 2nd-year CSE student preparing for placements with Java + DSA.

- Silent by default; rule-based policy decides when to speak (missed tasks, broken streak, low quiz scores, low mood, morning/night check-ins).
- Socratic tutor with a hint ladder that fades as mastery grows.
- Day planner, Stoic morning intention + night review (you write, it asks one question back), one-tap mood/energy, offline challenges.
- Visible reasoning trace (Think → Act → Observe → Answer) on every reply.
- Long-term memory you can inspect and delete; nightly self-reflection that grades its own nudges and adapts.
- Bring your own free Gemini or Groq API key, or use the offline demo brain. Everything is stored on-device.
- **Simulate a student's day** (You tab) replays every behaviour in about a minute, for demos.

College project docs: [slides](docs/slides/Dotbot.pptx) · [report](docs/REPORT.md) · [evaluation](docs/EVALUATION.md) · [demo script](docs/DEMO_SCRIPT.md).

## Install
Download the latest artifacts from the GitHub Actions run: `dotbot-apk` (Android) or `dotbot-windows` (unzip, run `dotbot.exe`).

## Develop
```
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze && flutter test
flutter run -d windows   # or an Android device
```
See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/DECISIONS.md](docs/DECISIONS.md), [PROGRESS.md](PROGRESS.md).

## License
MIT
