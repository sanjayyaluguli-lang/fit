# Autonomy

A private, local-first iOS training and lifestyle app for one person, built
around a single idea: **it should get less necessary over time.**

It tracks training, recovery, food and habits well enough to be useful for
years, and it actively rewards you for taking over — writing your own sessions,
changing the plan when life changes, and eventually not needing the suggestions
at all.

No accounts. No social feed. No coach dashboard. No analytics SDK. Your data is
a JSON file on your phone that you can export and read without this app.

---

## What's here

| Layer | Location | Builds on Linux? |
|---|---|---|
| Domain logic, scoring, persistence, export | `Sources/AutonomyKit` | yes |
| Tests | `Tests/AutonomyKitTests` | yes |
| SwiftUI app, HealthKit, Whoop, YouTube | `App/Autonomy` | no — needs Xcode |

`AutonomyKit` is deliberately free of Apple frameworks. Everything that touches
HealthKit, SwiftUI or the network lives in the app target, so the parts worth
testing are testable from a terminal.

## Running it

```bash
swift test                      # domain logic — works anywhere Swift runs

brew install xcodegen           # the app itself
xcodegen generate
open Autonomy.xcodeproj
```

The `.xcodeproj` is generated from `project.yml` and isn't committed.

> Status: the domain layer and its tests are complete and self-contained. The
> app layer is written but has never been compiled — it was built in a Linux
> container with no Swift toolchain, so expect a first pass of small Xcode
> fixes (imports, minor API drift) before it runs on device.

## The features, and why they work the way they do

### Readiness

One number, built from whatever you have connected — Whoop recovery, Apple
Health sleep and HRV, resting heart rate — and **your own read of the day**,
which carries a real 20% weight. An app that overrules how you say you feel
teaches you to stop noticing.

Everything is judged against your own trailing 30-day baseline, never a
population average, and the score reports its own confidence: one subjective tap
does not get to look like three synced signals. With nothing at all, it says so
instead of inventing a number.

### Workouts

- Native plans: blocks, straight sets, supersets, circuits, RPE, rest.
- **Any YouTube video becomes a first-class session.** Paste a link — watch,
  short, embed, live, playlist, with or without a timestamp — and it's saved,
  schedulable, playable, loggable and rateable. Metadata fetching is optional
  and needs your own API key; without one you type a title and lose nothing.
  Chapters are parsed from the description, using YouTube's own rule that a
  chapter list must start at `0:00`.
- Progressive overload: Epley e1RM, PR detection, and one quiet suggestion for
  next time — held back entirely when there isn't enough history to say
  anything honest.
- Periodization templates that exist to be edited. The moment you change one,
  it's marked as yours.

### Nutrition and habits

Three taps — *ate well / okay / off plan* — is a complete day's log. Macros are
there for the weeks you want them, not as the default unit of account. Meal
templates hold food the way you actually think about it ("dal, rice, curd,
salad"), not as gram weights.

Habits — protein, steps, bedtime, stress, mobility — get the same storage and
trend views as training, because that's where a year is actually won or lost.

### Progress

Default window is a **year**, not a week. Weight is shown as a scatter with a
trailing average through it, and small drifts are explicitly called flat rather
than dressed up as progress. Consistency is "weeks you showed up", never a
streak a holiday can destroy.

### Independence Score

The one metric the app is actually built around. It scores:

| Component | Weight |
|---|---|
| Sessions that were yours to shape | 30% |
| Adjusting the plan on the day | 25% |
| A library you built yourself | 20% |
| Reviewing honestly, and acting on it | 25% |

It does **not** score compliance, streaks or volume. Deviating from the plan
raises it. The top stage is called *"You don't need this app"*, and it means it.

### Weekly review

Four questions about sustainability and friction, asked before any numbers are
shown. Whatever you decide to change yourself is recorded, and it's the single
strongest input to the Independence Score.

## Privacy

- One JSON file in the app's Application Support directory. Nothing else.
- No account, no telemetry, no third-party SDKs.
- Whoop's OAuth token lives in the Keychain, device-only, and talks to Whoop
  directly — there is no server of ours in the loop.
- Progress photos are referenced by filename and never leave the device.
- **Export everything** — JSON plus five CSVs — from Settings, any time. An app
  about not depending on things has to be leaveable.
- Notifications are off by default and stay off unless you turn them on.

## Adding another wearable

Conform to `HealthDataProvider` or `RecoveryDataProvider` in the app target and
add it to `AppModel`'s provider list. That's the whole integration surface —
`AutonomyKit` knows nothing about any specific device. Garmin, Oura, Strava and
MyFitnessPal fit this seam as-is.

## Layout

```
Sources/AutonomyKit/
  Model/          Profile, Exercise, Workout, Session, YouTube, Health,
                  Nutrition, Habits, Progress, WeeklyReview
  Services/       ReadinessEngine, ProgressiveOverload, IndependenceScore,
                  Trends, InsightEngine, PeriodizationTemplates, Exporter,
                  YouTubeLink
  Persistence/    AutonomyData (the whole database), AutonomyStore (actor)
  Integrations/   Provider protocols, SyncCoordinator
App/Autonomy/
  State/          AppModel
  Views/          Home, Train, PlanBuilder, LogSession, YouTube, Progress,
                  WeeklyReview, Settings, Onboarding, Theme
  Integrations/   HealthKitProvider, WhoopProvider, YouTubeMetadataService
```

See [`docs/architecture.md`](docs/architecture.md) for the decisions behind
this, and [`docs/roadmap.md`](docs/roadmap.md) for what's deliberately not built
yet.
