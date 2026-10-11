# Decisions log
- Repo lives at D:\dotbot; Flutter stable cloned to D:\flutter (3.47.x).
- PDF: syncfusion rejected (non-permissive community license); decide at M3 (pdfrx/MIT or plain text only).
- sqlite3_flutter_libs dropped (EOL); drift_flutter bundles sqlite3.
- Generated drift code is gitignored; CI runs build_runner.
