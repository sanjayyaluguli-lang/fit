# Roadmap

Ordered by what would actually get used, not by what's easiest to demo.

## Next

- **Xcode shakedown.** The app layer has never been compiled. First job is
  `xcodegen generate`, build, and fix whatever the compiler finds.
- **Whoop OAuth flow.** `WhoopProvider` reads and refreshes nothing yet — the
  token store and API client are written, but the `ASWebAuthenticationSession`
  sign-in screen isn't. Until it exists, Whoop is inert and Apple Health carries
  readiness on its own.
- **Photo capture and private gallery.** `ProgressPhoto` and `NutritionEntry`
  already reference files by name; the capture UI and the app-private directory
  are not written.
- **Scheduling UI.** `ScheduledItem` and `YouTubeCollection` are modelled and
  read by the home screen, but nothing writes them yet.

## Soon

- Apple Watch app: start a session, log sets on the wrist, live heart rate.
- Widgets and Lock Screen: readiness and today's session.
- More export targets — a single `.zip`, and writing body metrics back to
  Apple Health.
- Optional iCloud (CloudKit private database) sync, off by default.

## Later, maybe

- Garmin, Oura, Strava, MyFitnessPal providers. The seam exists; each is a day
  of work when there's a reason.
- On-device trend narration for the weekly review.
- Android. Only if the domain layer can be shared as-is.

## Deliberately not doing

- Accounts, social features, sharing, leaderboards.
- Streaks, badges, challenge language.
- Any analytics SDK, crash reporter, or third-party dependency that phones home.
- A 1,200-exercise database. You add the twelve lifts you actually do.
- Calorie targets computed from a formula and presented as truth.
