---
tags: [strumbuddy, retention, progress]
updated: 2026-10-04
---
# Progress

The answer to "how far have I come?" — what a beginner needs around week three,
when motivation dips ([[Learning Philosophy]]). Status: **built**; screens checked
in the simulator with seeded data, mic-driven counting not yet on device.

## One-minute changes
The classic benchmark: clean switches between two chords in 60 s — a number that
reliably goes up. `Features/Drill/OneMinuteChangesView.swift` (from Practice →
Drills, and the progress screen).
- `OneMinuteCounter` (pure, tested): land the first chord clean to start; each clean
  landing on the *other* chord is one change. Misses don't count or advance. Bar =
  accuracy ≥ 0.6 (same as the daily session's chord blocks).
- 3-2-1 countdown (no scoring), then 60 s; the engine target switches after every
  landing.
- `OneMinuteStore` persists results (UserDefaults JSON); history + personal best per
  **order-independent pair** (C↔G = G↔C).
- Not logged to [[The Coach]] — it's a benchmark, not evidence (open question below).

## Your progress
`Features/Progress/` — reached from the Today hero and the Practice tab.
- **Stat tiles:** streak, days practiced in the last 30, chords mastered (/8),
  changes mastered (/graph transitions).
- **Practice, last 28 days:** graded attempts per day (`ProgressStats.dailyAttempts`,
  pure + tested, zero-filled so gaps read honestly).
- **One-minute changes:** line chart per pair with the best labeled directly.
- Charts are single-series Swift Charts (first-party): accent hue only, neutral
  axes, no legend, drag to read exact values.

## Open questions
- Should one-minute landings feed the coach as transition evidence? They have no
  timing axis, and speed-under-pressure may be a different skill from in-time changes.
