import Foundation

/// Persistence seam (design-doc §5.5 "Storage").
///
/// v0.1 persists the observation log as JSON (see `ObservationLog`), which is enough
/// to validate the coach. The intended production store is on-device **SQLite**: the
/// append-only observation log as one table, with mastery state derived as a
/// projection. The skill graph is small enough to live as a conceptual layer over
/// relational tables — no graph database needed at this scale.
///
/// TODO(persistence): introduce a SQLite-backed `ObservationStore` implementing the
/// same append/query API as `ObservationLog`, then switch `AppEnvironment` to it.
/// Candidate: GRDB.swift (permissive license) or the system `SQLite3` C API directly
/// to keep the zero-dependency posture.
enum Database {
    /// Planned schema, documented here until the SQLite store lands.
    static let plannedSchema = """
    CREATE TABLE observations (
        id            TEXT PRIMARY KEY,
        timestamp     REAL NOT NULL,
        implicated    TEXT NOT NULL,   -- JSON array of skill IDs
        context       TEXT NOT NULL,   -- JSON: isolation, bpm, source
        accuracy      REAL NOT NULL,
        cleanliness   REAL NOT NULL,
        timing        REAL NOT NULL
    );
    CREATE INDEX idx_obs_timestamp ON observations(timestamp);
    """
}
