# Kitchenline — Pickleball Drill Coach

Category: Sports Training · Platform: iOS 17+ · Bundle: `com.shimondeitel.kitchenline`

## Concept

A solo pickleball skill-drill trainer built around an animated top-down court diagram
and a self-rated skill tracker — deliberately skipping any matchmaking or social layer.
Named for the "kitchen line" (the non-volley-zone boundary), the real term pickleball
players use dozens of times per session.

## Problem / evidence

Pickleball is the fastest-growing racquet sport in the US, and most players improve by
guessing at drills from YouTube with no structure, no way to track which shots they've
actually practiced, and no sense of whether they're covering their weak areas. A phone
can hold a real, categorized drill library, track self-rated progress over a session,
and — for players willing to pay for it — turn a self-rating into an actual weekly plan.

## Free tier

- The full drill library: 18 real, named pickleball drills across four categories
  (Dinking, Third Shot Drop, Serve & Return, Footwork), each with an animated
  top-down court diagram, a rep counter, and real coaching cues.
- The animated court diagram itself, for every drill: a glowing ball traces a fading
  trail across the kitchen line on every rep; tapping "In" locks that rep's arc onto
  a persistent daily progress court diagram on the Home tab.
- Self-rated skill tracker (1-5 per category) and a granular weak-shot picker (e.g.
  "Third Shot Drop", "Backhand Dink") — both free, since rating your own game
  shouldn't require a subscription.

## Pro — $4.99/month (auto-renewable subscription, `com.shimondeitel.kitchenline.pro.monthly`)

- **AI weekly practice plan**: sends the player's self-rated weak shots and today's
  available practice minutes to the shared text proxy, which returns a personalized
  multi-day plan (which bundled drills, in what order, how many reps) as JSON-in-text.
  Falls back to a deterministic hand-written plan (drawn from the same weak-shot →
  drill mapping) if the request fails or the response doesn't parse.
- **Ghost-rally mode** (quirky feature): for the exact drill being practiced, asks the
  AI for a short structured sequence of `{time, courtX, courtY}` waypoints describing
  where a simplified "opponent" would move — rendered as a labeled dot animating on
  the same court diagram, never a photo/video opponent. A static drill description
  becomes a moving, visualized point sequence tailored to that specific shot. Falls
  back to a hand-written waypoint sequence per drill category if parsing fails.

## Animation hook

The court diagram is a live top-down schematic: `Canvas`-drawn baseline, sidelines,
kitchen (non-volley-zone) lines, center service lines, and a dashed net, painted in
bold court-stripe line weight. The ball is a small citrus-yellow circle that traces a
glowing trailing arc — a `TimelineView(.animation)`-driven `Canvas` layer drawing
several successively-more-transparent copies of its recent positions, plus a blurred
glow halo — across the kitchen line on every rep. Completing a rep correctly ("In")
locks that rep's straight-line arc into a bright permanent citrus stroke (with its own
soft glow) on the Home tab's daily progress court diagram, which accumulates arcs from
every drill practiced that day and resets at midnight.

## AI feature (text)

Two independent calls to the shared no-key proxy's `/text` route:

1. **Weekly plan**: system prompt lists every bundled drill name verbatim and asks for
   a 3-4 day plan referencing only those names, given the player's weak-shot tags and
   minutes available today. `PracticePlanParser` fuzzy-matches each returned drill name
   against the library (dropping anything unrecognized) and clamps rep counts; falls
   back to `FallbackPlanner.generate` (a pure, deterministic weak-shot → drill mapping)
   on any parse failure.
2. **Ghost-rally**: system prompt describes the court's exact coordinate system (feet,
   net at y=22, kitchen from y=15 to y=29) and the specific drill being practiced, and
   asks for 3-6 `{time, courtX, courtY}` waypoints. `GhostRallyParser` drops any
   waypoint outside court bounds or with a non-advancing time, sorts and caps the
   result; falls back to `FallbackPlanner.ghostWaypoints` (a hand-written sequence
   shaped by the drill's category) if fewer than 2 valid waypoints remain.

Both calls throw only for genuine network/HTTP failure, in which case the UI shows a
plain "showing a default plan instead" message and uses the same fallback — the
feature never crashes or blanks a screen if the proxy is briefly unavailable.

## Design direction

Deep court blue-green (`#0F6E63`) playing surface with a sage-tinted kitchen zone,
bold white painted court lines (3.5pt, distinct from Vantage's 1pt hairlines
elsewhere in this batch), and **one** vivid citrus-yellow accent (`#D8E23A`, the
pickleball's own color) reserved for the ball, locked progress arcs, and the Pro CTA.
App chrome uses soft rounded cards and a rounded display font — the deliberate
opposite of Vantage's sharp 0-radius drafting-table chrome — even though the court
diagram itself is, by nature of the sport, entirely rectilinear straight-line
geometry.

## Monetization

Monthly auto-renewable subscription, $4.99/mo, StoreKit 2 with a real
`Transaction.currentEntitlements` / `Transaction.updates` listener and a
`Kitchenline.storekit` local test configuration. Free tier is the full drill library,
animated court diagrams, and self-rated skill tracker; Pro gates the AI weekly plan
and ghost-rally mode.
