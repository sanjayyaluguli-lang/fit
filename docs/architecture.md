# Architecture

Written for one maintainer, working alone, coming back to this after six months
away.

## The one rule

`AutonomyKit` imports `Foundation` and nothing else. No SwiftUI, no HealthKit,
no `URLSession` calls, no `Bundle`. Everything platform-specific lives in
`App/Autonomy`.

This buys three things:

1. `swift test` runs anywhere, in seconds, with no simulator.
2. The scoring logic can be reasoned about without a device attached.
3. When Apple changes HealthKit again, the change is confined to one file.

## Data

The entire database is one `Codable` struct (`AutonomyData`) serialised to one
JSON file. For one user generating a few thousand rows a year, this beats Core
Data or SQLite on every axis that matters here: no migrations to hand-write, no
schema to debug, trivial export, and a file the owner can still read in ten
years with any text editor.

`AutonomyStore` is an actor. Reads come from memory; writes are applied in
memory immediately and flushed to disk atomically after a one-second debounce,
so the UI never waits on I/O and a crash mid-write can't truncate the file.

Two failure modes are deliberately loud rather than convenient:

- A corrupt file **throws** instead of silently starting fresh. Losing a year of
  history to an automatic reset is the one unforgivable bug in an app like this.
- A file written by a newer schema version is rejected rather than partially
  decoded.

When the store can't open at all, the app runs fully in memory, writes nothing,
and says so in Settings. It never overwrites a file it couldn't read.

## Integrations

```
HealthDataProvider      dailyMetrics / importedSessions / export
RecoveryDataProvider    recovery
```

`AppModel` holds arrays of each and syncs them all. Providers are independent:
one failing never blocks another, and failures surface as text in Settings
rather than as a modal.

`SyncCoordinator` merges by day and **only fills empty fields** — an imported
value never overwrites something entered by hand. Recovery snapshots are the
exception and are replaced wholesale, because Whoop revises them through the
morning; the row keeps its identity so nothing duplicates.

Sessions written to HealthKit are filtered out on the way back in by bundle
identifier, so two-way sync can't duplicate history.

## Scoring

Both scores follow the same shape: a set of weighted components, each carrying
its own human-readable detail string, renormalised over whatever inputs actually
exist. This means:

- Missing data reduces confidence rather than producing a wrong number.
- The UI can always explain the score by listing its parts.
- Adding a component is a local change with no rebalancing of the others.

`ReadinessEngine` weights: recovery 0.40, sleep 0.25, HRV 0.15, resting HR 0.10,
subjective 0.20 — normalised over what's present.

`IndependenceScore` weights: own sessions 0.30, adjusting 0.25, own library
0.20, reviewing 0.25. Its "adjusting" component saturates at ~35% of sessions:
deviating from everything is not a higher form of autonomy than deviating when
it's warranted.

## Tone

Copy is part of the design and lives next to the logic that produces it —
`ReadinessEngine.guidance`, `IndependenceScore.summary`, `DayEatingRating.caption`.
The rules:

- No streak language. Consistency is counted in weeks, and a missed week resets
  nothing.
- No guilt for food. "Off plan" is followed by "and it costs nothing long term."
- No urgency. The strongest phrasing available is "worth a look, not a panic."
- Silence is allowed. `InsightEngine.headline` returns nil when there's nothing
  worth saying, rather than manufacturing encouragement.

## Testing

The tests cover the parts where being wrong would matter and where behaviour is
easy to break by accident: readiness weighting and baselines, e1RM and PR
detection, overload suggestions, Independence Score components, YouTube link and
chapter parsing, trend direction and smoothing, CSV escaping, store round-trips,
and the two loud failure modes above.

Views are not unit tested. For a single-user app, the cost of testing SwiftUI
exceeds what it catches.
