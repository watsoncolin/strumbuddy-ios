---
tags: [strumbuddy, strategy]
updated: 2026-06-07
---
# Vision and Strategy

Strumbuddy listens to you play and gives feedback at the quality of a good human
teacher — not "right/wrong note" but *"your C is fine; it's the change into it
under tempo that's falling apart."*

## The real problem: retention
~90% of beginners quit within three months. The product is really **retention**;
every feature is judged by whether it keeps someone playing into month four.

## The moat is code, not content
Incumbents own filmed curricula and licensed song catalogs — a treadmill a solo
dev can't win. Strumbuddy's two differentiators are both algorithmic:
1. **Cleanliness feedback** — per-string clean / muted / buzzing (see [[Cleanliness Scoring]], [[Muted-String Detection]]).
2. **Adaptive, explainable diagnosis** — [[The Coach]] surfaces *your* weak spot and shows its reasoning.

## The crux
Everything reduces to one pipeline:
`audio → 4-axis grade (esp. cleanliness) → observation → credit assignment → mastery → "work on this"`
The hard, differentiating links are cleanliness detection (done) and credit
assignment (next). See [[Architecture]].
