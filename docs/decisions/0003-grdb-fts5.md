# 3. SQLite through GRDB, search with FTS5

**Decision:** one SQLite file managed by GRDB 7, with FTS5 external-content indexes kept in sync by `synchronize(withTable:)`.

**Why:** full-text search over notes, transcripts and attachment text, explicit migrations, and a single inspectable file. GRDB's Swift package compiles with `SQLITE_ENABLE_FTS5`.

**Rejected:** SwiftData (no full-text search), Core Data.
