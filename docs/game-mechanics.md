# Game mechanics

Owner: `game-designer`. Status: Phase 1 wave A draft, 2026-11-26.

Design intent: [`game-design.md`](game-design.md). Progression: [`progression.md`](progression.md).

**Number sources:**

| Mark | Meaning |
|---|---|
| **v0** | From `sourdough-scientist`'s draft v0 (message, 2026-11-26). |
| **v1** | From the scientist's calibrated v1 answers (message, 2026-11-26). These replace v0 where both exist. A v1 number here is only a reading aid for checking a design floor. [`starter-simulation-spec.md`](starter-simulation-spec.md) and `tools/sim-reference/sim.py` are the source and win on any difference. Peak times are cited, not copied (§2.2). |
| **TBD (sim spec)** | Not yet given. Never invented here. |
| **design** | A game number I own: caps, timings, UI rules. |

**Defaults** for every rule and target unless stated:
- `white_bread`, 100% hydration
- `loose_lid`, `classic_jar`
- `counter` at 22 °C (v0)

## 1. Status

| Rule | Value |
|---|---|
| Status shown | The sim's state label, with icon plus word (CLAUDE.md rule 7). |
| Precedence (v0) | `moldy` > `unhealthy` > `dormant` > `hungry` > `recovering` > `freshly_fed` / `developing` / `active` / `near_peak` / `at_peak` / `collapsing` |
| Tap on status | One plain line on what it means, plus the forecast when one exists (§6). |
| Numbers on the main screen | None. |
| Fed in the `fridge` | Shows `dormant` right after the feed. Intended: it's cold, so it barely rises. The status tap line says it was fed and is napping in the cold (narrative). The same goes for a jar that was fed and then moved to the fridge, once the jar cools below the dormant temperature (v1 thermal lag, §3.1). |
| `moldy` | Only `inspect`, `journal` and Discard are enabled. `feed`, `smell` and `environment` are disabled, because the state is latched and nothing can change it. The `mold_found` sheet can be closed with "Not now" so the player can look and read, but Discard stays on screen. |

## 2. Feed

### 2.1 Inputs

| Input | P0 (VS) | P1 | P2 | Rule |
|---|---|---|---|---|
| `ratio` | Presets 1:1:1, 1:2:2, 1:5:5, chosen by the schedule question (§2.2) or an exact-preset picker. | Same | Free steppers | The main decision. Sets the timing of the next peak. |
| `flour` | `white_bread`, `whole_wheat` | + `rye`, `spelt` | 2-flour mixes | One flour per feed. Unlock triggers are in progression §3. |
| `hydration` | Fixed at 100% | Presets (v1):<br>stiff 60%: about 10% slower, taller (about 2.35×), almost no hooch, a bit more sour<br>standard 100%<br>loose 125%: about 3% faster, about 2.1×, more hooch, slightly milder | Free | Water g = flour g × hydration / 100. |
| `discard` | **Derived**, not chosen | Same | Free keep amount, no-discard | See §2.3. Always shown in grams so players learn real practice. |

### 2.2 The schedule question

"When will you check on it next?"

| Answer (labels by narrative, max 18 characters) | Target window after feeding (design) | Suggested ratio at `counter` |
|---|---|---|
| "In a few hours" | 4 to 7 h | 1:1:1 |
| "Later today" | 7 to 10 h | 1:2:2 |
| "Tomorrow morning" | 10 to 16 h | 1:5:5 |

**How the suggestion is picked:**
- The game picks the preset whose forecast **`at_peak` start**, at the **current location**, falls inside the window. If several do, it picks the one closest to the window center. At the counter, the spec §15 starts land one per window, so each answer maps to exactly one preset. This is testable as BT-17.
- If no preset lands inside the window, it says so in plain words and suggests a location. For example: "Even 1:5:5 will peak early in the warm spot. The counter fits better."
- In `fridge`: "It'll barely rise in the fridge. Feed it when you take it out, or feed now and let it start before it goes in." There's no blocking.
- **Routine hint** (design): if the player's last 3 feeds were each at least 20 h apart, and the ratio's forecast peak was under 10 h, the feed sheet shows one non-blocking line, `FEED_ROUTINE_HINT` (narrative). The copy is about feeding rhythm, never about counting absences. It's shown at most once every 7 days. Why: a mismatched routine (once a day at 1:1:1) is hungry half of each day and matures about 3× slower (v1), so the game must say why rather than let it go silent.

**Sim peak times:** see [`starter-simulation-spec.md`](starter-simulation-spec.md) §15 (calibration table) and `tools/sim-reference/sim.py`. The spec is the source. This doc doesn't copy its numbers.
- **Design requirement:** at `counter`, with a mature starter, white flour at 100%, each preset's `at_peak` start falls inside its window above. The scientist confirmed all three do.
- 1:1:1 can't honestly be faster at 22 °C, so the first window starts at 4 h and ends at 7 h.
- A 1:5:5 feed at 21:00 peaks the next morning.
- The sim also supports 1:10:10, but that's P2 only.

### 2.3 Derived discard

Total after feeding is fixed: `target_total_g` = 150 g (design knob).

For ratio 1 : f : w:
- `keep_g = round(target_total_g / (1 + f + w))`
- `flour_g = keep_g × f`
- `water_g = flour_g × hydration / 100`

| Ratio | Keep | Flour | Water | Total |
|---|---|---|---|---|
| 1:1:1 | 50 g | 50 g | 50 g | 150 g |
| 1:2:2 | 30 g | 60 g | 60 g | 150 g |
| 1:5:5 | 14 g | 70 g | 70 g | 154 g |

For 1:5:5, flour and water are rounded to the nearest 5 g for readable numbers.

**What this guarantees:**
- The jar never overflows, so there's no capacity warning.
- `classic_jar` only has to show a 3× rise of 150 g with headroom. Art-director sized it at D84 × H170 mm:
  - 150 g fills to about 30 mm.
  - A 3× rise reaches about 90 mm.
  - The streaks and headroom reach 125 mm, all below the shoulder.

### 2.4 Feed timing (no grade shown)

The state at feed time sets a timing class. Events, the journal and traits use it. The player never sees a score. Rise-phase rows read the sim's `rise_phase`, not the state label, because `recovering` hides the phase (spec, scientist).

| State at feed | Class | Sim effect | Player feedback |
|---|---|---|---|
| `freshly_fed`, `developing`, `active` | early | A later peak, from dilution. It's slower, not weaker, and there's no vigor penalty (v1). Example: three feeds 3 h apart push the next peak from 6.3 h to 10.5 h. | A non-blocking line in the sheet: "It's still rising. Feeding now is fine, but it'll take longer to peak." |
| `near_peak`, `at_peak`, `collapsing` | on_time | Full strength | Journal: "Fed at its peak." |
| `hungry` | late | Normal. After 24 h away, the first peak is 98% of normal (v1). | The hooch step if hooch is present. |
| `dormant`, `recovering` | very_late | 1 recovering feed, normal by feed 2 to 3 (v1, 3 days unfed) | Later `back_to_strength`. |
| `unhealthy` | rescue | Resets most of `mold_risk` (v0) | Journal: "Fed through the warning signs." |
| `moldy` | none | Feeding is disabled | The discard flow (game-design §5). |

### 2.5 The hooch step

This is shown only when `hooch` ≥ 0.1, the spec's visible threshold (spec §15: about 17 h after a feed at the counter). It is the first step of the feed sheet and has two choices:
- **Pour off** is the default. It sets `hooch` to 0 (v1).
- **Stir in** sets `hooch` to 0 and raises culture hydration by 5 × hooch points, so the starter is a little runnier (v1). **No acid effect:** hooch is mostly water and alcohol (scientist, citing King Arthur). Copy must not say "more sour".

Either choice is fine. Both are real practice.

### 2.7 Flour character (v1)

Each flour differs in at least one thing the player can see or smell.

| Flour | Speed vs. white | Look | Smell and taste |
|---|---|---|---|
| `white_bread` | Baseline | Tallest smooth dome | Mildest |
| `whole_wheat` | About 10% faster | Tan with flecks, lower dome | Sourer |
| `rye` | About 15% faster | Rises least (about 1.65×), cracked or pitted top | Sourest (`strongly_acidic` within a day) |
| `spelt` | About 8% faster | Looser paste, lower dome | |

### 2.6 Flow and feedback

The sheet opens with last time's ratio, flour and hooch choice preselected, and a "Same as last time" line above Mix (ux-designer, `ux-design.md` §8).

| Step | Common path (2 taps) | Custom path |
|---|---|---|
| 1 | Tap `feed` | Tap `feed` |
| 2 | Tap Mix | Change the schedule question answer (or exact preset) |
| 3 | | Flour chip |
| 4 | | (P1) Hydration preset |
| 5 | | Tap Mix |

Mix is a plain tap, and no hold is required anywhere. During the stir beat, the player can optionally circle-drag on the jar to stir faster.

**After Mix:**
1. The tactile sequence plays: scrape the discard, scoop, pour, stir. It lasts about 6 s, and the player can skip it after their first feed.
2. The band snaps on at the new level.
3. A card shows the forecast in words (§6).
4. A journal line is written.

**What the player learns:** timing, that ratio sets the schedule, flour character, and real gram practice.

## 3. Environment

### 3.1 Locations

| `location` | Temperature (v0) | Tier | What it teaches | Introduced |
|---|---|---|---|---|
| `counter` | 22 °C | P0 | The baseline rhythm | B1 |
| `warm_spot` | 26 °C | P0 | Warmer means faster: earlier peak and earlier hunger. | Free play on day 0, plus `warm_and_quick` |
| `fridge` | 4 °C | P0 | A pause. Goes `dormant`. After 14 days: 1 recovering feed, normal on feed 2 (v1). | The B8 line, plus `off_to_nap` |
| `window_sill` | 18 °C | P1 | Cooler means slower. Fits a once-a-day schedule. | Progression §3 |
| `proofing_box` | 26 °C, dial 24 to 30 | P1 | Precise control. The only temperature dial. | Progression §3 |

**Rules:**
- A move applies instantly, with no confirmation (design).
- The camera carries the jar to the spot, and the light changes per location (art-director).
- Temperature is read-only and follows the location.
- Thermal lag (v1): the jar's stored `temp_c` follows the location with a 1.5 h time constant (a Newton cooling estimate). A move to the counter lifts a fridge jar above the dormant temperature in well under an hour.
- Humidity is a fixed per-location constant (v1 RH: counter 50, warm_spot 40, window_sill 55, fridge 70, proofing_box 60). It is not a player control and not shown (OD-4).

### 3.2 Cover and container

| Field | P0 | P1 | P2 |
|---|---|---|---|
| `cover` | `loose_lid`, fixed, no UI | | `cloth`, `tight_lid` as cosmetic choices, or cut (OD-10) |

**Why cover left P1** (v1): cover only changes dryness, which makes mold at most 40% faster.
- `cloth` is strictly worse (mold at 8.2 days).
- `tight_lid` is about 1 day later (10.0 days), with no sourced cost.
- Neither is a real decision.
| `container` | `classic_jar` only | | `wide_mouth_jar`, `ceramic_crock`, `fermentation_vessel` (OD-3) |

## 4. Smell

| Rule | Value |
|---|---|
| Input | 1 tap on `smell` |
| Cost, cooldown | None. Repeating gives the same result for the same state. |
| Result | Descriptors from the state (the sim spec maps state to descriptor). The card shows at most 2. If `musty` is present, it is always listed first (v1). The copy variant is picked deterministically (narrative). |
| Moment | A camera nudge and wisps, about 1.2 s, then a card (ux). |
| Card | The descriptor, plus a meaning line for the first 3 times each descriptor appears. After that, the meaning is one tap away. |
| Safety | A `musty` meaning line **never fades** and always says it's a warning sign. |
| Journal | Logged once per descriptor per rise cycle. |
| Learns | Smell tracks the cycle. Sharp or solvent smells mean hungry, not sick. Musty is different. |

| Descriptor class | Descriptors (seed list, vision) | Meaning gist (narrative writes it) |
|---|---|---|
| Cycle | `wet_flour`, `mildly_fruity`, `fresh_yeasty`, `yogurt`, `pleasantly_tangy` | Where it is in its rise |
| Hungry | `strongly_acidic`, `alcohol`, `acetone` | It has eaten everything. Normal. Feed it. |
| Young | `cheesy` | Still young. Normal. |
| Warning | `musty` | A warning sign. Feed it now and look at the surface. It first appears as a faint note at the watch stage (v1: about 3.1 days unfed at the counter). |

## 5. Inspect

| Kind | Tier | Camera | Reveals (v0 variables) | Learns |
|---|---|---|---|---|
| `height` | P0 | Side view at band level | `rise` against the band, last `peak_rise` (glass streaks), trend (rising or falling) | Where it is in the cycle, how strong the last peak was |
| `bubbles` | P0 | Close-up through the glass | Activity (`yeast`, `lab`, gas): bubble density and size | Activity level. Large bubbles high up mean near peak. |
| `surface` | P0 | Top-down through the mouth | Dome, flat or sunken. `hooch`, `dryness` skin. Watch-stage signs (v1): thicker, darker hooch, and a dull dry skin if the cover allows. **Never fuzz or color before `moldy`.** Then mold. | Peak vs. collapse, hunger, warnings |
| `consistency` | P1 | A spoon lifts some starter | Structure: thick, stretchy, or soupy (`maturity`, hunger, hydration) | Strength and maturity |
| `development` | P1 | A slow orbit | Maturity stage, plus strength from `vigor`: `strong`, `steady` or `weakened` (spec §14). The sim keeps no rise history. | Progress |

**Rules:**
- No cost and no cooldown.
- The camera holds for up to 3 s, then shows the card.
- Readouts are words, never raw numbers. Height may say "about doubled".
- The meaning line fades like smell does. Lines about warning or mold signs never fade.
- The `surface` card at `moldy` must say to discard it (CLAUDE.md rule 5).

## 6. Forecast

| Rule | Value |
|---|---|
| Source | `Forecast.peak_window(state, env, feed)`. It runs the same step function forward from the post-feed state, at jitter 0.95 and 1.05, up to 48 h (tech-architect, scientist v1: about 700 steps). |
| Shown | On the post-feed card, and when the status is tapped during a rise phase. |
| Format | Time-of-day words with a range ("best around lunchtime", "overnight", "tomorrow morning"). Never a countdown. |
| Recompute | On any environment change. |
| Not shown | `dormant`, `unhealthy`, `moldy`, `hungry` |

## 7. Events

### 7.1 Trigger types

| Type | Meaning | Example |
|---|---|---|
| `state_enter` | The state label changes to X. | `hungry_again` |
| `threshold_cross` | A variable crosses a value. | `hooch_forming` |
| `duration` | In a state or condition for N h. | (reserved) |
| `action_outcome` | The result of a player action. | `fed_before_peak` |
| `milestone` | A one-time first. | `first_rise` |
| `calendar` | Days since `adopted_at`. | `one_week` (progression) |
| `ambient` | Eligible by phase, then decided by the stored per-feed draw `feed_u`. There is no RNG in event rules. | `big_bubble` |

### 7.2 Tiers

| Tier | Presentation (ux) | Used for | Cap per local day |
|---|---|---|---|
| `info` | A toast live, or a line in the return summary | Observations, positive moments, reassurance | Max 4 live toasts. All are logged. |
| `nudge` | A card with one action and a dismiss | A good moment to act | **Max 2** |
| `attention` | A sheet that must be acknowledged | Warning signs and loss only | Max 1 created. **Never more than 1 waiting.** |

### 7.3 Scheduler rules

These are pure, in `src/sim/events/event_scheduler.gd`, with history saved in `EventLedger` (tech-architect).

| Rule | Value |
|---|---|
| Evaluation | At sim step boundaries, including offline catch-up. Each rule is `(prev_state, state, ctx)`. |
| Quiet hours | 22:00 to 08:00 device local time (`ctx.local_utc_offset_s`). |
| `info` in quiet hours | Logged normally |
| `nudge` in quiet hours | Deferred to 08:00, then re-checked. **Dropped** if its condition no longer holds. |
| `attention` in quiet hours | Never dropped or deferred in-app. It only affects future notifications. |
| Staleness | Every nudge has `expires_if`. It is re-checked when shown and dropped silently if stale, for example if already fed. |
| Attention queue | If one is waiting, a new attention event replaces it **only** for `mold_found`. Otherwise it's held until the first is acknowledged. |
| Open sheet | Nothing interrupts it, attention included. Events queue until it closes (UI layer). |
| Same moment | When an event and a milestone fire for the same moment (for example `first_rise`), only the event shows. The milestone goes to the journal only, so there is never a double toast. |
| Randomness | None in event rules. `ambient` rules read the sim's stored per-feed draw `feed_u` (spec §17), so events stay a pure function of state (CLAUDE.md rule 2). |
| Thresholds | From spec §14.1: `RISE_NOTICEABLE` = rise 1.25 crossed upward after a feed, `HOOCH_VISIBLE` = hooch 0.10. Peak words: small under 1.5, near-double under 1.85, doubled under 2.4, big at 2.4 or more. |
| Phase triggers | Triggers that mean a rise phase (`at_peak`, early feeds, `near_peak`) read `rise_phase`, never the state label. |

### 7.4 Event list

Narrative owns the final ids and copy in `events-catalog.md`. VS means the event is in the vertical slice.

| id | VS | Tier | Trigger type | Trigger (sim terms) | Cooldown | Choices |
|---|---|---|---|---|---|---|
| `first_rise` | ✓ | info | milestone | After the first real-time feed, `rise` crosses `RISE_NOTICEABLE` (1.25) upward (spec §14.1). | One-time | |
| `peaked_while_away` | ✓ | info | state_enter | `rise_phase` enters and leaves `at_peak` with `ctx.app_foreground` false. The payload has the peak time and `peak_rise`. Variant `peak_now` when in the foreground. | Once per rise cycle | |
| `hungry_again` | ✓ | nudge | state_enter | Enters `hungry` | 12 h | Feed |
| `hooch_forming` | ✓ | info | threshold_cross | `hooch` crosses 0.1 (spec §15) | 24 h | Pour off or stir in, inside the feed sheet |
| `back_to_strength` | ✓ | info | action_outcome | After a very_late feed or a fridge wake, the first cycle with `vigor_at_feed` ≥ 0.75 reaches at least 85% of `last_strong_peak_rise`. Gating on vigor stops it firing while the pill still says Recovering (scientist). | 24 h | |
| `warning_signs` | ✓ | attention | state_enter | Enters `unhealthy` (v0: `mold_risk` ≥ 0.5) | Once per episode. Re-armed after 24 h out of `unhealthy`. | The primary is "Look first", which opens the `surface` inspect and teaches looking before feeding. The secondary is "Feed it now" (narrative). |
| `first_acetone` | | info | milestone | The first smell result is `acetone` or `alcohol`. | One-time | |
| `off_to_nap` | | info | state_enter | Moved to `fridge` | 24 h | |
| `waking_up` | | info | action_outcome | The first rise after leaving `fridge` | Once per fridge stay | |
| `fed_before_peak` | | nudge | action_outcome | `consecutive_early_feeds` reaches 3 | 72 h | |
| `warm_and_quick` | | info | action_outcome | At a warm location, the feed-to-peak time is at most 0.85 × the forecast for the same feed at 22 °C (one extra forecast run). The sim's ratios at 26, 28 and 30 °C are 0.80, 0.76 and 0.73 (scientist). | 72 h | |
| `getting_stretchy` | | info | threshold_cross | `maturity` reaches the `steady` threshold (P1; pairs with `consistency`) | One-time | |
| `big_bubble` | | info | ambient | `rise_phase` enters `near_peak` and `feed_u` ≥ 0.85, the stored per-feed draw. That's 15% of cycles, deterministic (scientist). | 48 h, max 1 a day | |
| `trait_revealed` | | info | milestone | The dominant trait is first set (P1) | One-time per trait | |
| `mold_found` | | attention | state_enter | Enters `moldy` | Once | Discard (one action) |

Six VS events: `first_rise`, `peaked_while_away`, `hungry_again`, `hooch_forming`, `back_to_strength`, `warning_signs`. Tier mix: 11 info, 2 nudge, 2 attention.

### 7.5 Ledger fields the rules need

These were sent to `tech-architect`.

| Field | Used by |
|---|---|
| `last_fired[id]`, `one_time[id]`, `open_attention` | Every cooldown, cap and queue rule |
| `consecutive_early_feeds` | `fed_before_peak` |
| `last_strong_peak_rise`: the last `peak_rise` from a cycle with `vigor_at_feed` ≥ 0.75 | `back_to_strength` |
| `starved_h` read from the **pre-feed** state (the feed resets it) | The `comeback` milestone |
| `smelled_descriptors`, `seen_count[result]` | The `nose_for_it` milestone and the meaning-line fade |
| `adopted_at_unix` | Calendar milestones |
| Rolling 14-day buckets: warm hours, cool hours, feeds, ratio sum, changes, comebacks | Traits (P1) |
| `ctx.app_foreground` | `peak_now` vs. `peaked_while_away` |

## 8. Return flow ("while you were away")

| Rule | Value (design) |
|---|---|
| Shown when | Away at least 60 min **and** at least one event or state change happened. |
| Step 1 | The time-lapse: about 30 `VisualParams` snapshots from catch-up, played over 3 to 6 s (longer absences get more time, capped at 6 s). Tap to skip. Reduce motion shows before and after stills. The setting "Show time-lapse on return" is on by default; when it's off, this step is skipped. |
| Step 2 | A summary card of up to 3 lines. It is non-modal, and tapping any action dismisses it. **If an `attention` event is pending, the card is skipped and its lines go at the top of the attention sheet** (ux-designer). |
| Step 3 | The main screen, with at most 1 prompt: an `attention` sheet, or else the newest valid `nudge`. |
| Selection | A pure function, `ReturnSummary.build(catch_up_result)`. |
| Keep priority | attention > milestone > peak > hunger and hooch > other info > ambient |
| Drop order | Ambient first, then same-kind info merged into one line (for example hooch plus a sour smell becomes one hunger line), then the oldest info. A starter can't peak twice without a feed, so there are no repeated peaks to merge. |
| Dropped items | Always written to the journal. |
| Return to `moldy` | The time-lapse runs past the warning stages. The summary names when the warnings began. Then `mold_found`. |
| More than 14 days away | Catch-up is capped (D-013). The summary says the time was long. A fridge starter is just `dormant`. |

### 8.1 Tutorial time scale (B6 only)

| Rule | Value |
|---|---|
| Scope | **Only** the B6 demo, and debug builds. No other release code path scales time. |
| How (accepted, `architecture.md` §5.5) | `Demo.run(state, env, steps)` runs ordinary 60 s `Sim.step` calls on a **temporary copy**, many per frame. dt is never scaled, so the demo curve is exactly the real one. The global clock is never scaled. |
| After B6 | `StarterState.rebase_to(now)` sets `sim_time` and `born_unix` to now, then the real save is made from the copy's `at_peak` state. Sim time is never ahead of the wall clock, so D-013 is untouched. |
| Duration | Set the scale so feed-to-peak lasts 90 to 120 s (BT-12). |
| Skip path | Skipping B6 creates the save from the same at-peak preset state. The B7 feed then lands on time, not early. |

### 8.2 Start states

These are built by `StarterPresets.make(preset_id, now)` (tech-architect). The preset ids are `new_game`, `first_restart` and `restart`, in table order.

| Start | State | Location | Why |
|---|---|---|---|
| New game, after B6 or the skip | `at_peak`, maturity 0.2 | `counter` | B7 teaches feeding at peak. |
| First restart after mold (M.'s spare, narrative) | `dormant`, maturity 0.2, `temp_c` 4 (just out of the fridge) | `counter` | Honest, since it was in the fridge. Warms up with the 1.5 h lag. First feed then `recovering`, normal by feed 2 (v1). It reuses `waking_up` and `back_to_strength`, so the restart is an active beat, not a reset. |
| Later restarts ("a spoonful from a friend") | `at_peak`, maturity 0.2 | `counter` | No repeated wait after a second loss. |

## 9. Leniency rules

At counter, loose lid, unless noted.

| ID | Rule | Number (v1 at 22 °C) | Design floor | Pass |
|---|---|---|---|---|
| L-1 | Fed once or twice a day at `counter` with any P0 ratio, it never becomes `unhealthy`. | | | Checked by BT-1 and BT-2 |
| L-2 | One day unfed: `hungry`, hooch possible. | 1 feed, first peak at 98% of normal | 1 feed, at least 85% | ✓ |
| L-3 | Three days unfed: `dormant`. | 1 recovering feed, normal by feed 2 to 3 | 3 feeds or fewer | ✓ |
| L-4 | The earliest `unhealthy` | 4.5 d at `counter`, 3.5 d at `warm_spot` | 4 d at `counter` | ✓ |
| L-5 | The earliest `moldy` | 8.9 d at `counter`, 7.1 d at `warm_spot` | 7 d at `counter` | ✓ |
| L-6 | From `unhealthy` onset to `moldy` | 106 h at `counter`, about 86 h at `warm_spot`. The spec guarantees at least 60 h at any temperature. | 72 h at `counter`, 48 h anywhere | ✓ |
| L-7 | From the watch stage (faint musty note) to `moldy` | 138 h at `counter`. The spec guarantees at least 77 h at any temperature. | 96 h at `counter` | ✓ |
| L-8 | `fridge` never molds within the 14-day catch-up cap. | 14 d: 1 recovering feed, normal on feed 2 | 2 feeds or fewer | ✓ |
| L-9 | Feeding at any state before `moldy` lowers `mold_risk`. | Out of `unhealthy` after 1 feed, normal by feed 3 | 1 feed, 3 feeds | ✓ |
| L-10 | No single action causes a loss. | | | design |
| L-11 | **No dead ends.** From any non-`moldy` state, the corrective action gives a state that is no worse within 6 h. The corrective action is a feed, or a move to `counter` for a cold `dormant`. "No worse" means equal or lower in the §1 precedence, with `mold_risk` not rising. | 1.5 h thermal constant | 6 h | design |

Mold hours are tuned for the game. Real mold timing is not predictable (scientist). The MVP cover is fixed at `loose_lid`, so `cloth` (8.2 d) and `tight_lid` (10.0 d) don't apply until P2. If the final spec puts any number under a design floor, that's a fun-vs-biology conflict for the director.

## 10. Balancing targets (testable)

These are for `qa-engineer`. Scenario first, then the pass condition. "Steady state" means after 3 days of BT-1.

| ID | Scenario | Pass condition |
|---|---|---|
| BT-1 | Twice daily: 1:2:2, feeds at 08:00 and 20:00, 14 days | Never `unhealthy`. `mold_risk` < 0.3 throughout. At least 1 `at_peak` per 24 h. Zero attention events. `hungry` no more than 4 h a day. |
| BT-2 | Once daily: 1:5:5, feed at 19:00, 14 days | Never `unhealthy`. `mold_risk` < 0.3. `at_peak` starts 9 to 13 h after each feed. Zero attention events. Hooch allowed. |
| BT-3 | A real day with sleep: 1:2:2, feeds at 07:00 and 22:00, 14 days | As BT-1, plus no nudge has a creation time between 22:00 and 08:00. |
| BT-4 | Weekend in the fridge: from steady state, feed Fri 18:00, move to `fridge` Fri 19:00, move to `counter` and feed Sun 18:00, then BT-1 | Zero attention events. `mold_risk` < 0.3. `peak_rise` at least 85% of the pre-weekend value within 2 feeds. |
| BT-5 | 24 h away from steady state | On return `hungry`, hooch allowed, no attention event. 1 feed gives `peak_rise` of at least 85% of normal. |
| BT-6 | 14 days in the `fridge` | Never `unhealthy`. Normal rise within 2 feeds. |
| BT-7 | Neglect at `counter` | `unhealthy` no sooner than 96 h unfed. `moldy` no sooner than 168 h. At least 72 h from `unhealthy` to `moldy`. Any location or temperature: at least 48 h. |
| BT-8 | Rescue: feed at `unhealthy` onset, then BT-1 | Out of `unhealthy` after 1 feed. Normal rise within 3 feeds. |
| BT-9 | 30 days of BT-1 | Zero attention events. Nudges at most 2 per local day. |
| BT-10 | Determinism | Same save and inputs give the same states, events and summary, byte for byte. |
| BT-11 | Forecast | With the environment unchanged, the actual `at_peak` start falls inside the forecast window for 100% of feeds. |
| BT-12 | Tutorial demo (B6) | From feed to `at_peak` in 90 to 120 s of wall time, at the tutorial time scale. The scale applies **only** inside B6 (§8.1). The saved starter's clock never runs at anything but 1:1. |
| BT-13 | Taps | Feeding like last time takes 2 taps from the main screen (Feed, Mix). Returning with a pending attention event and feeding (skip the time-lapse, the secondary "Feed it now", Mix) takes 3 taps or fewer. The safe path takes 4 taps, by design: skip the time-lapse, "Look first" (the surface check), "Feed now", Mix. |
| BT-14 | Pacing, twice daily | Starting at maturity 0.2 with BT-1 care: `steady` by days 5 to 8, `mature` by days 12 to 18, `seasoned` by days 45 to 60. v1 gives days 6, 16 and 51.5. |
| BT-14b | Pacing, once daily | Starting at maturity 0.2 with BT-2 care: each stage within 1.5× the BT-14 day. v1, with generation-weighted gain, gives days 8, 21 and 69 (1.31× to 1.34×). |
| BT-15 | Return flow | Every catch-up gives at most 3 summary lines plus at most 1 prompt. Every dropped item appears in the journal. |
| BT-17 | Schedule question | Mature starter at `counter`, defaults. The forecast `at_peak` start is inside 4 to 7 h for 1:1:1, 7 to 10 h for 1:2:2 and 10 to 16 h for 1:5:5, and each answer suggests its preset. |
| BT-16 | No dead ends (L-11) | For each non-`moldy` state, apply the corrective action. Within 6 h, the state is no worse and `mold_risk` hasn't risen. |

## 11. Tuning knobs

| Knob | Default | Owner |
|---|---|---|
| `target_total_g` | 150 g | design |
| Ratio presets | 1:1:1, 1:2:2, 1:5:5 | design |
| Schedule question windows | 4 to 7, 7 to 10, 10 to 16 h | design |
| Hydration presets (P1) | 60, 100, 125% (v1) | scientist |
| Location temperatures | 22, 26, 4, 18, 26 (24 to 30) °C | scientist (v0) |
| Location humidity (fixed) | 50, 40, 70, 55, 60% (v1) | scientist |
| Thermal time constant | 1.5 h (v1) | scientist |
| Mold days at the reference temperature, cover and humidity multipliers, the 48 h gap cap | v1 | scientist |
| Dormant and unhealthy thresholds, vigor recovery per feed | v1 | scientist |
| Maturity gain per feed, stage thresholds | 0.01024 × w × (1 − m), where w = min(2.5, log2(total / kept) / log2(3)). Thresholds 0.33, 0.50, 0.83 (v1). Paced to BT-14 and BT-14b. | scientist + design |
| Routine hint | Last 3 feeds at least 20 h apart with a forecast under 10 h. At most once per 7 days. | design |
| Quiet hours | 22:00 to 08:00 | design |
| Caps per day | info toasts 4, nudge 2, attention 1 | design |
| Cooldowns | §7.4 | design |
| `big_bubble` gate | `feed_u` ≥ 0.85 (15% of cycles) | design + scientist |
| Return threshold | 60 min | design |
| Return lines, prompts | 3, 1 | design |
| Time-lapse length, samples | 3 to 6 s, ~30 | design + tech |
| "Show time-lapse on return" setting | On | ux + design |
| Meaning-line fade | After 3 views (never for warnings) | design |
| Early-feed nudge count | 3 in a row | design |
| `warm_and_quick` ratio | ≤ 0.85 × the 22 °C forecast | design |
| Tutorial demo speed (60 s sim steps per frame) | Set so B6 lasts 90 to 120 s | design + tech |
| Trait window, drift window | 14 d, 14 d | design |

## 12. Questions for `sourdough-scientist`

**Answered in v1:**

| # | Question | Answer |
|---|---|---|
| 1 | Peak hours | §2.2 |
| 2 | Does a young starter (maturity 0.2) raise mold risk? | No |
| 3 | Maturity thresholds | §11 |
| 4 | Effect of stirring hooch in | §2.5 |
| 5 | Thermal lag | §3.1 |
| 6 | A cost for `tight_lid` | None, so cover moves to P2 |
| 7 | Flour differences | §2.7 |
| 8 | Hydration presets | §2.1 |
| 9 | Does repeated early feeding weaken it? | It's slower, not weaker |
| 10 | Watch-stage signs | §4 and §5 |

Also answered: maturity gain for a once-daily schedule. It is now generation-weighted (progression §2).

Also settled: the `hooch` visible threshold is 0.1 (spec §15). The `first_rise` level is `RISE_NOTICEABLE` (rise 1.25, spec §14.1).

**Still open:**
- Peak times for a young starter (maturity 0.2), for B6 and the first days.
