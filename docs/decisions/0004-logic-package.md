# 4. Logic lives in the QuicknoteKit package

**Decision:** code with no UI and no system permission goes in `QuicknoteKit/`; the app target holds windows and integrations.

**Why:** logic is tested with `swift test` in seconds without launching the app, and features can be built in parallel without touching each other's files.
