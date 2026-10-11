# Contributing
- Fork, branch, small PRs. Keep commits short and imperative.
- `flutter analyze` and `flutter test` must pass (CI enforces both).
- Logic goes in pure Dart classes with unit tests (use a fake `LlmProvider`); keep widgets thin.
- Run `dart run build_runner build --delete-conflicting-outputs` after changing drift tables and commit `database.g.dart`.
- Record notable choices in `docs/DECISIONS.md`; larger ones get an ADR in `docs/adr/`.
- Never commit API keys. Keys live only in secure storage on the user's device.
