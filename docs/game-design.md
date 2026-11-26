# Game design

Owner: `game-designer`. Status: Phase 1 wave A draft, 2026-11-26.

Companion docs:
- [`game-mechanics.md`](game-mechanics.md): every rule and number.
- [`progression.md`](progression.md): maturity, milestones, unlocks, traits.

Starter numbers come from the scientist's calibrated v1 answers (2026-11-26). [`starter-simulation-spec.md`](starter-simulation-spec.md) is the final authority. Canonical ids are from [`vision.md`](vision.md).

## 1. Pitch and player fantasy

**Pitch:** a real, living starter in a beautiful jar on your phone. It rises and falls on the real clock. You learn to read it by looking and smelling, until you can glance at the jar and know what it needs.

**Fantasy:** "I'm the person who can read a starter." Feeding is not the goal. The goal is competence: predicting the peak, knowing a sour smell means hungry and not sick, and fitting a living thing into a busy life without stress.

**Two deep mechanics, not ten shallow ones:**

| Mechanic | The player decision | Why it is deep |
|---|---|---|
| **Timing** | *When* to feed, judged by reading the jar. | Feeding at or just after peak is ideal. Too early dilutes it, so the next peak comes later. Very late needs a recovery feed. Every inspection and smell feeds this decision. |
| **Scheduling** | *How* to feed (ratio, location) so the next peak lands when you are around. | This is how real bakers fit a starter into a life. A bigger ratio or a cooler spot slows it, and the fridge pauses it. It gives a busy adult control instead of forgiveness timers. |

Everything else (smell, inspect, flours, traits, journal) either feeds those two decisions or records what came of them.

## 2. Core loop at every time scale

| Scale | What the player does | What they get | Target length |
|---|---|---|---|
| **30-second check-in** | Opens the app, sees the jar and status (icon plus word), maybe smells or inspects once, closes. | The return time-lapse if they were away, plus one glance of real progress: the rise against the band, the bubbles, the dome. | 10 to 60 s. Zero required taps. |
| **Feeding session** | Feed, then Mix, with last time's settings preselected (2 taps). Or the custom path: "When will you check on it next?", then flour, then mix. | A tactile ritual (scrape, scoop, pour, stir, band snaps on) and a plain-words forecast ("Best around lunchtime"). | 20 s common, 60 to 90 s custom. |
| **Day** | One or two feeds, one to three glances. At night, nothing. | A visible rise and fall per feed, a few journal lines, and maybe a milestone. | Under 5 min total. |
| **Week** | Settles into a rhythm. Uses the fridge for busy days. Tries a new flour or spot. | Maturity climbs (rises get stronger and more reliable), a personality trait appears, unlocks are introduced, and the journal fills. | Player-chosen. |

**Session rule:** the game never asks for more than one decision per check-in. The status, the jar and at most one prompt are all the player has to handle.

## 3. The first 15 minutes, beat by beat

These are agreed with `narrative-designer` (2026-11-26). Beat ids are theirs. Naming plays after the demo, so the play order is B1, B2, B3, B5, B6, B4, B7, B8. Narrative owns the words. The tutorial time scale is used **only** in B6. Everything else is real time.

| Beat | Time | What happens | Player learns | Mechanic introduced |
|---|---|---|---|---|
| B1 | 0:00 | A kitchen counter in warm light. The starter left by M. (the previous keeper) with a note: young but established, just mixed, in `classic_jar`. No menu. | This is alive and it's mine. | None |
| B2 | 0:20 | Prompted to drag (orbit) and pinch (zoom). | The jar rewards looking. | Camera |
| B3 | 0:50 | Smell: `wet_flour`. The card pairs the descriptor with its meaning ("just fed"). | Smell tells you where it is in its cycle. | `smell` |
| B5 | 1:20 | Inspect `bubbles`: few, small. | Bubbles mean activity. | `inspect` |
| B6 | 1:50 | "Let's watch a few hours pass." A sped-up demo of about 90 to 120 s: developing, active, near_peak, at_peak. The band shows the rise. It pauses at peak. | The shape of a cycle and what peak looks like. | Band, height |
| B4 | 3:50 | Naming moment, once it has shown it's alive (narrative). | Attachment. | Name |
| B7 | 4:30 | First real feed, at peak (the ideal timing). The game asks "When will you check on it next?": "In a few hours" (1:1:1), "Later today" (1:2:2) or "Tomorrow morning" (1:5:5). Then mix. Real time starts. | Feed at peak. The ratio sets when the next peak comes. | `feed`, ratio |
| B8 | 6:00 | Handoff: "It should be at its best around lunchtime" (time-of-day words from the forecast). One line says the fridge is a pause button for busy days. The first journal entry is written. | When to come back. The fridge exists. | Forecast, `journal` |
| Free | 7:00 to 15:00 | Optional free play. `environment` is open (counter, warm_spot, fridge). No more forced steps. | Exploration. | `environment` |

**Skip path:** "I've kept a starter before" skips B2, B3, B5 and B6. It keeps B4 and the B7 question, and unlocks every P0 and P1 option at once (see [`progression.md`](progression.md) §3).

**Why a gifted young starter and not day 0:**
- A real from-scratch starter takes days to become reliable, and a beginner can't tell its early false rise from real activity.
- That is a terrible first week for a game.
- Starting "young but established" gives a reliable rise on day 0 and leaves maturity room to grow (§5 of progression).
- From-scratch is P2 at most.
- I've asked the scientist to confirm a young starter has no extra mold risk (R4).

## 4. What players learn, and in what order

Each lesson is taught by something the player sees first, then names, then acts on.

| When | Lesson | Taught by |
|---|---|---|
| Day 0 | Look closely. The jar shows everything. | B2, B5 |
| Day 0 | Smell maps to the cycle. | B3. Meaning lines on the first 3 smells of each descriptor. |
| Day 0 | A cycle: rise, peak, fall. Feed at peak. | B6, B7 |
| Day 0 | Ratio sets timing. | The B7 question |
| Day 1 | Peaks happen while you're away, and that's fine. | The return time-lapse and `peaked_while_away` |
| Day 1 | Sour, alcohol, acetone and hooch mean hungry, not sick. | `hooch_forming`, `first_acetone` |
| Days 1 to 3 | Fridge = pause. Warm = faster. | B8 line, `off_to_nap`, `warm_and_quick` |
| Days 1 to 3 | Different flours, different character. | The whole_wheat intro after `first_peak` |
| Week 1 | Read bubbles and the dome to predict the peak. | Inspection, and the meaning lines fading out |
| Week 1 | Feeding before peak delays the next one. | `fed_before_peak` (rare) |
| Week 1 | It gets stronger with care. | Maturity stage `steady`, trait reveal |
| Week 2+ | Warning signs (musty, sluggish, dry skin) are different from hunger. | The surface inspection, and `warning_signs` if it ever happens |
| Week 2+ | Advanced levers: rye, spelt, hydration, cool spot, proofing box. | P1 unlocks |

**Training wheels fade:** smell and inspection cards show a "what this means" line for the first 3 times each result appears. After that, the line hides behind a tap. This is the only skill progression, and it has no XP.

## 5. Loss and recovery

Mold is the only loss (D-002).

**Neglect timeline** (`counter` 22 °C, loose lid). The hungry and hooch times are v0 (at 24 °C); the rest are v1.

| Unfed for | State | What the player sees | Fix |
|---|---|---|---|
| ~12 h | `hungry` | Fallen back, sour smell | 1 feed |
| ~24 h | `hungry` + hooch | Gray liquid on top, alcohol or acetone smell | 1 feed (first peak at 98% of normal) |
| ~3 days | `dormant` | Flat, few bubbles | 1 recovering feed, normal by feed 2 to 3 |
| 3.1 days | `dormant` (watch stage) | A faint musty note listed first, thicker and darker hooch | Same |
| 4.5 days | `unhealthy` | Musty, sluggish. `warning_signs` (attention). | 1 feed leaves `unhealthy`. Normal by feed 3. |
| 8.9 days | `moldy` | Visible mold | **Loss.** Discard, memorial. |

`warm_spot` is faster: unhealthy at 3.5 days, mold at 7.1. The MVP cover is fixed at a loose lid. Mold hours are tuned for the game; real mold timing is not predictable (scientist).

**Rules:**
1. No single action causes a loss. A bad ratio, feeding too early or the wrong flour only changes timing or strength.
2. There are at least 72 h from the first attention warning to mold at the counter, and at least 48 h in the worst combination. This is a requirement on the sim; see the mechanics doc, BT-7.
3. A return to `moldy` replays the warning stages in the time-lapse and the summary, so the loss is understood rather than a surprise.
4. **The loss moment:**
   - The memorial is a journal page (narrative writes it).
   - The game says plainly to discard it, and never "scrape it off".
   - The jar is shown being emptied and washed.
   - Then "Start again with a fresh spoonful." The first loss frames it as M.'s spare, later ones as a spoonful from a friend (narrative). Either way it's the same young but established starter, with no new mechanic.
5. **What carries over:**
   - These are kept: unlocks, the journal (the old starter's chapter is closed), achievements, and the training-wheel fades. **The player's skill isn't lost.**
   - These reset: maturity, the trait and milestones that belong to that starter.

## 6. Is "real time with no catch-up help" fair to a busy adult?

**Mostly yes.** I keep D-006 (a 1:1 clock and no forgiveness timers) because real starters are already lenient and the fridge is a real pause. But four cases are unfair as the vision stands. Each fix below changes **information or tools, never the sim.**

| Unfair case | Fix | Cost |
|---|---|---|
| **Peaks are short and happen while you're at work.** Rewarding presence at peak would punish every office worker. | Never require presence. The return time-lapse replays the absence in 3 to 6 s. Glass streaks show the high-water mark. Milestones count peaks seen or unseen. | Low. The sim is pure, so sampling `VisualMapper` is cheap (asked `tech-architect` to confirm). |
| **The player can't plan around a living thing.** | Scheduling is the main mechanic: the "When will you check on it next?" question, the forecast after each feed, and the fridge introduced on day 0. | Low. It needs `forecast(state, feed)` from the sim (asked the scientist, R8). |
| **Nighttime.** | Nudges are never created in quiet hours. A twice-daily schedule with 8 h of sleep never produces a warning (BT-3). | None |
| **"Warnings the player could have seen" is false without notifications.** A player who doesn't open the app for about 9 days (about 7 at `warm_spot`) loses a starter whose warnings they never saw. With v1 this is now a rare case, a trip without using the fridge, so OD-1 is weaker than it was. I still recommend it. | **Recommend:** one opt-in local notification kind in the MVP, after the VS: "It's been a while. If you're away, that's OK." It fires once when `unhealthy` begins, outside quiet hours. On-device only, no backend (D-007's plugin). | Medium. This conflicts with the vision's "Not in MVP: push notifications". Open decision OD-1. |

**What I'd refuse even under pressure:** pausing the clock, a "rescue" token, or mold that waits for the player to look. Those break pillar 4 (honest science) and the pure sim.

## 7. P0 / P1 / P2 review

These are my verdicts on [`vision.md`](vision.md) scope. "Smallest premium" is the least we can build that still feels high quality.

### P0

| Item | Verdict | Smallest premium version | Reason |
|---|---|---|---|
| Beautiful 3D starter | **Confirm** | One jar (`classic_jar`), one starter shader, one kitchen with three spots. Rotate and zoom, with limits. | It's the whole game. Spend the art budget here. |
| Starter simulation | **Confirm** | The v1 variables. Humidity is a per-location constant, not an input. | Every sign has to come from it. |
| Feeding | **Confirm, narrowed** | Ratio presets (1:1:1, 1:2:2, 1:5:5) picked through the schedule question. A single flour. Discard derived (see mechanics §2). Hydration fixed at 100%. A tactile mix. "Feed like last time". | Ratio and timing are the depth. Free gram steppers and mixes are numbers to manage. |
| Temperature | **Confirm, as location** | `counter` 22, `warm_spot` 26, `fridge` 4 °C. No thermostat slider. | A slider is a number to manage. Choosing a place is a real-world decision. |
| Smell | **Confirm** | One tap, a camera nudge, a descriptor card, and a meaning line that fades. | High delight, low cost, teaches the most. |
| Inspection | **Challenge: 3 kinds in P0** | `height`, `bubbles` and `surface` in P0. `consistency` and `development` in P1. | Those three cover cycle position, activity and safety. `consistency` needs a spoon animation, and `development` overlaps the journal. |
| Offline progression | **Confirm, plus time-lapse** | Deterministic catch-up (D-013) with a time-lapse return and a summary of up to 3 lines. | The time-lapse is the main fairness tool. |
| Core UI | **Confirm** | As `ux-designer` specifies. | |
| **Events** (vision says P1) | **Promote the 6 VS events to P0** | The 6 events marked VS in mechanics §7. | The VS needs at least 5 events, and the return summary is built from them. |
| **Journal** (vision says P1) | **Promote a minimal log to P0** | A chronological list of feeds, peaks, smells, milestones and return summaries, plus the memorial page. | D-002's memorial needs it, and it fills a bottom-bar slot. A rich journal is P1. |

### P1

| Item | Verdict | Smallest premium version | Reason |
|---|---|---|---|
| Personality | **Confirm** | 4 traits that change wording only (narrative), revealed at stage `steady`. | Cheap (text) and it's the attachment hook. Never touches biology. |
| Flour types | **Confirm** | All 4. The VS ships `white_bread` and `whole_wheat` so choosing a flour means something. | Each flour must differ in at least one thing you can see or smell. |
| Jars (containers) | **Challenge: move to P2** | Ship `classic_jar` only. | Each container is a new glass mesh, two-pass glass tuning and a starter-shader fit, for almost no gameplay. Spend the budget on making one jar perfect. |
| Hydration | **P1 presets** | Stiff, standard, loose. Exact % from the sim spec. | Visible through consistency and the dome, but second-order. |
| Locations beyond 3 | **P1** | `window_sill` (cool, 18 °C) and `proofing_box` (dial 24 to 30 °C). | Useful scheduling levers once the basics land. |
| Cover | **Challenge: move to P2** | `loose_lid` is fixed in the MVP. | v1: cover only changes dryness. `cloth` is strictly worse, and `tight_lid` is about a day later with no sourced cost. Neither is a decision (OD-10). |

### P2

**Agree:**
- multiple starters
- bread recipes (the `stage_mature` "ready to bake" milestone sets them up)
- achievements (kept tiny; see progression)
- advanced customization: free gram steppers, flour mixes, no-discard feeding
- more environments, containers

**Add as P2 ideas:** from-scratch starter, discard recipes as journal flavor, and dried-starter backup (a real practice).

## 8. Anti-patterns we refuse

| Refused | Instead |
|---|---|
| XP, levels, currency, energy | Progress is the starter's maturity plus the player's knowledge. |
| Streaks, daily login rewards | Calendar milestones count days owned, not days played. |
| Guilt copy ("Your starter misses you") | Hunger is described as a state, never a feeling about the player. |
| A health bar or meters on the main screen | The jar, the status word and the icon. |
| Grades or stars on feeds | The next rise is the grade. |
| Fear of missing out, limited-time events | Events come only from the starter's own state. |
| Paying or waiting to skip | Never (D-005). |
| Pausing the clock or rescue tokens | Real tools: the fridge, ratio, forecast, time-lapse. |
| Random events not grounded in the sim | Ambient flavor only when the state allows it (CLAUDE.md rule 2). |
| Interrupting the player | Nothing interrupts an open sheet. Max 1 prompt per return. |
| Gross-out or scare copy about hooch | Hooch is normal hunger, said plainly. |

## 9. Design comparisons

- **Viridi** (Ice Water Games): real-time succulents that grow, or die, while the app is closed. Reviewers call it forgiving and calm. Lesson: real-time care works for adults if neglect is slow and visible. Sources: [Steam page](https://store.steampowered.com/app/375950/Viridi/), [Twinfinite review](https://twinfinite.net/2015/08/viridi-review/), [Fast Company](https://www.fastcompany.com/3050237/viridi-a-game-about-succulents).
- **Neko Atsume** (Hit-Point): check in, see what happened while you were away, check out. Low pressure, no guilt. Lesson: the return reveal *is* the reward. That's our time-lapse. Sources: [Boing Boing](https://boingboing.net/2015/12/15/homecoming-games.html), [Daily Dot](https://dailydot.com/?p=150551).

## 10. Open decisions (for the director)

| ID | Decision | My recommendation |
|---|---|---|
| OD-1 | One opt-in local notification kind (unhealthy onset) in the MVP, after the VS. | Yes. Without it, "warnings the player could have seen" isn't true for long absences. |
| OD-2 | Promote the 6 VS events and a minimal journal from P1 to P0. | Yes |
| OD-3 | Move containers (jars) from P1 to P2. | Yes |
| OD-4 | Humidity is not a player control. | Yes |
| OD-5 | P0 inspection kinds: `height`, `bubbles`, `surface`. | Yes |
| OD-6 | P0 locations: `counter`, `warm_spot`, `fridge`. `window_sill` and `proofing_box` P1. | Yes |
| OD-7 | New ids: maturity stages `young`, `steady`, `mature`, `seasoned`. Event and milestone ids are listed in mechanics and progression (narrative owns the final event ids). | Approve the stage ids |
| OD-8 | The start: a gifted, young but established starter, not a day-0 mix. | Yes |
| OD-9 | A rubber band on the jar marks the start level after each feed. It's a real baker's trick and makes height readable without numbers. Art-director has already added `Rubber_Band` to `jar_v0.glb`, and it snaps to `VisualParams.band_height_m`. | Yes |
| OD-10 | Move `cover` (`cloth`, `tight_lid`) from P1 to P2, as cosmetic or cut. The MVP has a fixed `loose_lid`. | Yes |
| OD-11 | **Resolved with the scientist.** Maturity gain is weighted by generations per feed (sim spec §6 and §9). A once-daily player on 1:5:5 now takes 1.31× to 1.34× as long as twice daily, within the 1.5× target. A mismatched routine (once daily at 1:1:1) stays slow as a gentle lesson, explained by the feed-sheet routine hint (mechanics §2.2). | No decision needed |
