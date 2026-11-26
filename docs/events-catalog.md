# Events catalog

Owner: `narrative-designer`. Status: Phase 1 wave A draft, 2026-11-26.

**Sources:**
- Event ids, triggers, tiers, caps and cooldowns: [`game-mechanics.md`](game-mechanics.md) §7, by `game-designer`. Their ids are kept unchanged.
- Sim variables (`rise`, `peak_rise`, `hooch`, `mold_risk`, `maturity`, `vigor`, `food`): the scientist's draft v0. Names may change when [`starter-simulation-spec.md`](starter-simulation-spec.md) lands. Thresholds marked **TBD (sim spec)** are never invented here.
- Slots: [`ux-design.md`](ux-design.md) §18.

Voice rules: [`narrative.md`](narrative.md) §4. Every string is in a `Key | Text | Max` table and appears once across the three narrative docs.

## 1. How events show up

| Tier | Presentation (ux) | Strings each event needs | Cap (mechanics) |
|---|---|---|---|
| `info` | A toast (60, no buttons). Tapping it opens its journal entry. While away, it becomes a summary row instead. | `_TOAST` (60), `_AWAY` (44) if it can happen offline, `_JOURNAL_TITLE` (26), `_JOURNAL_BODY` (200) | 4 live toasts a day. All logged. |
| `nudge` | A card: title 26, body 120, one action plus a dismiss (buttons 18). | `_TITLE`, `_BODY`, `_BTN`, `_DISMISS`, `_AWAY`, journal | 2 a day. Never created 22:00 to 08:00. |
| `attention` | A sheet: title 26, body 280, up to 2 buttons, plus a close X when closing is safe. | `_TITLE`, `_BODY`, buttons, `_AWAY`, journal | Max 1 waiting. |

**Narrative rules on top of the mechanics:**
1. Most events are `info`. Only warning signs and mold reach `attention`.
2. One idea per toast.
3. Every negative event says what to do, in the first sentence that can hold it.
4. Hunger events (`hungry_again`, `hooch_forming`, `first_acetone`) always say "normal" or "hunger" so they never read as danger.
5. No event mentions how long the player was away, except as a time of day or "about N hours ago" for warning signs, where the timing helps the player learn.
6. Warnings teach the real habit: **look first, then feed.** Warning copy says "No mold yet", never "not mold", because in real life a musty smell can come with mold.

## 2. Summary

| id | VS | Tier | Tone | Trigger type | Cooldown | Choices |
|---|---|---|---|---|---|---|
| `first_rise` | ✓ | info | positive | milestone | one-time per starter | |
| `peaked_while_away` (+ `peak_now`) | ✓ | info | positive | state_enter | once per rise cycle | |
| `hungry_again` | ✓ | nudge | neutral | state_enter | 12 h | Feed it / Later |
| `hooch_forming` | ✓ | info | neutral | threshold_cross | 24 h | Pour off / Stir in, in the feed sheet |
| `back_to_strength` | ✓ | info | positive | action_outcome | 24 h | |
| `warning_signs` | ✓ | attention | negative | state_enter | once per episode | Look first / Feed it now |
| `first_acetone` | | info | neutral | milestone | one-time | |
| `off_to_nap` | | info | neutral | state_enter | 24 h | |
| `waking_up` | | info | positive | action_outcome | once per fridge stay | |
| `fed_before_peak` | | nudge | neutral | action_outcome | 72 h | Got it |
| `warm_and_quick` | | info | neutral | action_outcome | 72 h | |
| `getting_stretchy` | | info (P1) | positive | threshold_cross | one-time | |
| `big_bubble` | | info | positive | ambient | 48 h, max 1 a day | |
| `trait_revealed` | | info (P1) | positive | milestone | one-time per trait | |
| `mold_found` | ✓ (debug) | attention | negative | state_enter | once | Discard it / Not yet |

**15 events, 6 in the vertical slice.** Positive 6, neutral 6, negative 2, plus the `peak_now` variant. Tier mix: 11 info, 2 nudge, 2 attention.

**D-017:** `mold_found` and the memorial are also built in the vertical slice, reachable through the debug time scale, so the safety copy is tested on screen early.

---

## 3. Vertical slice events

### 3.1 `first_rise`

| Field | Value |
|---|---|
| Trigger | First real-time feed of this starter, then `rise` crosses 1.25 upward ("noticeably risen", spec §14.1). |
| Tier, cooldown | `info`, one-time per starter. Pairs with the `first_rise` milestone, which goes to the journal only. |
| Teaches | It's alive on the real clock. The band is the reference. |

| Key | Text | Max |
|---|---|---|
| `EVENT_FIRST_RISE_TOAST` | Look at the band. It's rising, all by itself. | 60 |
| `EVENT_FIRST_RISE_AWAY` | It began to rise, all by itself. | 44 |
| `EVENT_FIRST_RISE_JOURNAL_TITLE` | First rise | 26 |
| `EVENT_FIRST_RISE_JOURNAL_BODY` | The first rise on the real clock. Fresh flour, a little time, and it climbed past the rubber band on its own. That never really gets old. | 200 |

### 3.2 `peaked_while_away` and `peak_now`

| Field | Value |
|---|---|
| Trigger | `rise_phase` enters and leaves `at_peak` while `ctx.app_foreground` is false. Uses `rise_phase`, not the state label, because `recovering` hides the rise phase (scientist). Payload: peak time, `peak_rise`. If the app is in the foreground when `rise_phase` enters `at_peak`, `peak_now` fires instead. At most one peak per absence (no feeds while away). |
| Tier, cooldown | `info`, once per rise cycle. |
| Teaches | Peaks happen while you're out, and that's fine. The streaks show the high point. |
| Rise words | From `peak_rise`, bands set by the scientist (spec §14.1): `SMALL` below 1.5×, `NEAR` 1.5 to 1.85×, `DOUBLE` 1.85 to 2.4×, `BIG` 2.4× and up. A normal 1:1:1 peak (2.1 to 2.25×) reads "doubled", as King Arthur would say. The same bands drive the height inspection (game-copy §6.2). |
| `peak_now` | Neutral toast below. Trait versions `EVENT_PEAK_NOW_<TRAIT>` are in [`narrative.md`](narrative.md) §7.3. |

| Key | Text | Max |
|---|---|---|
| `EVENT_PEAKED_WHILE_AWAY_AWAY_SMALL` | Rose a little, peaking around {time}. | 44 |
| `EVENT_PEAKED_WHILE_AWAY_AWAY_NEAR` | Nearly doubled, peaking around {time}. | 44 |
| `EVENT_PEAKED_WHILE_AWAY_AWAY_DOUBLE` | Doubled, peaking around {time}. | 44 |
| `EVENT_PEAKED_WHILE_AWAY_AWAY_BIG` | More than doubled, peaking around {time}. | 44 |
| `EVENT_PEAKED_WHILE_AWAY_JOURNAL_TITLE` | Peaked while you were out | 26 |
| `EVENT_PEAKED_WHILE_AWAY_JOURNAL_BODY` | It peaked around {time}. The streaks on the glass show how high it climbed before it fell back. | 200 |
| `EVENT_PEAK_NOW_TOAST` | At its peak. Tall, domed and rather pleased with itself. | 60 |
| `EVENT_PEAK_NOW_JOURNAL_TITLE` | Caught it at its peak | 26 |
| `EVENT_PEAK_NOW_JOURNAL_BODY` | Saw it at its peak around {time}: domed, glossy, bubbles right up to the top. The best moment to feed it, or to bake. | 200 |

The `_AWAY_` peak lines double as the journal's peak log lines, so peaks read the same everywhere.

### 3.3 `hungry_again`

| Field | Value |
|---|---|
| Trigger | Enters `hungry` (food used up, rise fallen back). |
| Tier, cooldown | `nudge`, 12 h. Created in quiet hours: deferred to 08:00, dropped if no longer `hungry` (`expires_if` fed). |
| Choices | **Feed it**: opens the feed sheet. Outcome is the normal feed result. **Later**: closes the card, nothing else happens. |
| Teaches | Hunger is a normal stage, and timing is the player's call. |

| Key | Text | Max |
|---|---|---|
| `EVENT_HUNGRY_AGAIN_TITLE` | Ready for a feed | 26 |
| `EVENT_HUNGRY_AGAIN_BODY` | It has eaten everything and fallen back. A sour smell is normal now. Feed it whenever it suits you. | 120 |
| `EVENT_HUNGRY_AGAIN_BTN` | Feed it | 18 |
| `EVENT_HUNGRY_AGAIN_DISMISS` | Later | 18 |
| `EVENT_HUNGRY_AGAIN_AWAY` | It ran out of food and fell back. | 44 |
| `EVENT_HUNGRY_AGAIN_JOURNAL_TITLE` | Hungry again | 26 |
| `EVENT_HUNGRY_AGAIN_JOURNAL_BODY` | The food ran out around {time}. It fell back and turned sour, right on cue. | 200 |

### 3.4 `hooch_forming`

| Field | Value |
|---|---|
| Trigger | `hooch` crosses 0.10 upward (visible, spec §14.1). Happens in `hungry` and in `dormant`, including in the fridge (scientist). |
| Tier, cooldown | `info`, 24 h. Pairs with the `first_hooch` milestone (journal only). |
| Choices | None on the toast (toasts have no buttons). The choice is the first step of the feed sheet while hooch is present: **Pour off** (default) or **Stir in**. Strings: [`game-copy.md`](game-copy.md) §7. |
| Outcome | A journal log line for the choice. Scientist v1: stirring in has no acid effect, it only makes the starter a little wetter. No flavor claim either way. |
| Teaches | Hooch means hungry. It is never danger. |
| Source | King Arthur Baking: hooch is alcohol from a hungry starter, and its gray or dark color doesn't mean spoiled ([black liquid](https://www.kingarthurbaking.com/blog/2023/08/28/sourdough-starter-black-liquid)). |

| Key | Text | Max |
|---|---|---|
| `EVENT_HOOCH_FORMING_TOAST` | Liquid on top? That's hooch. It just means hungry. | 60 |
| `EVENT_HOOCH_FORMING_AWAY` | A layer of hooch formed on top. | 44 |
| `EVENT_HOOCH_FORMING_JOURNAL_TITLE` | Hooch | 26 |
| `EVENT_HOOCH_FORMING_JOURNAL_BODY` | Liquid on top, gray to brown and sometimes even black, called hooch. It's mostly water and alcohol from a hungry starter, and it's normal. Pour it off or stir it in, then feed. | 200 |

### 3.5 `back_to_strength`

| Field | Value |
|---|---|
| Trigger | After a `very_late` feed or a fridge wake, a rise reaches at least 85% of the pre-neglect `peak_rise` **and** `vigor_at_feed` ≥ 0.75 (spec §14.1). Without the vigor check it would fire on the first recovering feed while the pill still says "Recovering". |
| Tier, cooldown | `info`, 24 h. Pairs with `comeback` when `starved_h` ≥ 24 (journal only). |
| Teaches | Starters are forgiving. Normal life never ruins one. |

| Key | Text | Max |
|---|---|---|
| `EVENT_BACK_TO_STRENGTH_TOAST` | Back to its old self. That was a proper rise. | 60 |
| `EVENT_BACK_TO_STRENGTH_AWAY` | It rose like its old self again. | 44 |
| `EVENT_BACK_TO_STRENGTH_JOURNAL_TITLE` | Back to strength | 26 |
| `EVENT_BACK_TO_STRENGTH_JOURNAL_BODY` | After a rough patch, a full rise again. Starters are forgiving like that. A couple of good feeds and it's itself again. | 200 |

### 3.6 `warning_signs`

| Field | Value |
|---|---|
| Trigger | Enters `unhealthy` (v0: `mold_risk` ≥ 0.5). |
| Tier, cooldown | `attention`, once per episode. Re-armed after 24 h out of `unhealthy`. |
| Visible signs (scientist) | Musty note under the sour smell, a dull dry skin on top, thick dark hooch, flat and sluggish, few bubbles. **Never** fuzz or pink, orange or red color. Those only appear at `moldy`. Earlier, at the watch stage, a faint musty note (always listed first) and thicker, darker hooch already show. |
| Choices | **Look first** (primary): opens Inspect on `surface`, whose card says fuzz or color means discard, and if none, feed. This is the real-world habit: look, then feed (scientist). **Feed it now**: opens the feed sheet. A feed takes it out of `unhealthy` (v0, mechanics L-9). Outcome toast below. Close X allowed (closing is safe). |
| Teaches | Warning signs are different from hunger, and still fixable. What would mean discard. |
| Safety | Never says "safe". Names fuzz and pink or orange as the discard signs so the player learns the real rule. Scientist reviews. |

| Key | Text | Max |
|---|---|---|
| `EVENT_WARNING_SIGNS_TITLE` | Warning signs | 26 |
| `EVENT_WARNING_SIGNS_BODY` | It smells musty, and it looks run down: flat, few bubbles, maybe a dry skin on top. These are warning signs. No mold yet. Look at the surface first: fuzz of any color, or pink or orange, means discard. If you see none, feed it now. One feed usually turns it around. | 280 |
| `EVENT_WARNING_SIGNS_BTN_FEED` | Feed it now | 18 |
| `EVENT_WARNING_SIGNS_BTN_LOOK` | Look first | 18 |
| `EVENT_WARNING_SIGNS_OUTCOME_FED` | Fed through the warning signs. Look in again tomorrow. | 60 |
| `EVENT_WARNING_SIGNS_AWAY_HOURS` | Warning signs began about {hours} hours ago. | 44 |
| `EVENT_WARNING_SIGNS_AWAY_DAYS` | Warning signs began about {days} days ago. | 44 |
| `EVENT_WARNING_SIGNS_JOURNAL_TITLE` | Warning signs | 26 |
| `EVENT_WARNING_SIGNS_JOURNAL_BODY` | Warning signs showed up: a musty smell and a tired, flat look. No mold yet. A careful look, then a feed, is the fix. | 200 |

`_AWAY_HOURS` is used for 2 to 47 hours, `_AWAY_DAYS` for 2 days or more, so both plurals are always right.

---

## 4. Other events (after the vertical slice)

### 4.1 `first_acetone`

| Field | Value |
|---|---|
| Trigger | The first smell result whose primary descriptor is `acetone` or `alcohol`. |
| Tier, cooldown | `info`, one-time per player. |
| Teaches | Sharp, boozy or solvent smells mean hungry, not sick. |

| Key | Text | Max |
|---|---|---|
| `EVENT_FIRST_ACETONE_TOAST` | Sharp and boozy? That's hunger. A feed fixes it. | 60 |
| `EVENT_FIRST_ACETONE_JOURNAL_TITLE` | A sharp smell | 26 |
| `EVENT_FIRST_ACETONE_JOURNAL_BODY` | First whiff of alcohol or nail polish remover. Startling, but normal: a hungry starter makes these as it runs out of food. A feed or two clears it. | 200 |

### 4.2 `off_to_nap`

| Field | Value |
|---|---|
| Trigger | Moved to `fridge`. |
| Tier, cooldown | `info`, 24 h. Pairs with `first_nap` (journal only). |
| Trait versions | `EVENT_OFF_TO_NAP_<TRAIT>` in [`narrative.md`](narrative.md) §7.3. |
| Teaches | The fridge is a pause. |

| Key | Text | Max |
|---|---|---|
| `EVENT_OFF_TO_NAP_TOAST` | Into the fridge. It'll slow right down and wait. | 60 |
| `EVENT_OFF_TO_NAP_JOURNAL_TITLE` | Off for a nap | 26 |
| `EVENT_OFF_TO_NAP_JOURNAL_BODY` | Into the fridge around {time}. The cold slows it nearly to a stop, so it can wait days or weeks. When it comes out, a feed or two will wake it. | 200 |

### 4.3 `waking_up`

| Field | Value |
|---|---|
| Trigger | The first rise after leaving `fridge`: `rise` crosses 1.25 upward after a feed (spec §14.1). |
| Tier, cooldown | `info`, once per fridge stay. Pairs with `first_wake` (journal only). |

| Key | Text | Max |
|---|---|---|
| `EVENT_WAKING_UP_TOAST` | It's rising again. The nap is over. | 60 |
| `EVENT_WAKING_UP_AWAY` | It woke up and started to rise. | 44 |
| `EVENT_WAKING_UP_JOURNAL_TITLE` | Awake | 26 |
| `EVENT_WAKING_UP_JOURNAL_BODY` | The first rise since the fridge. Cold starters take a feed or two to get going, and this one is on its way. | 200 |

### 4.4 `fed_before_peak`

| Field | Value |
|---|---|
| Trigger | `consecutive_early_feeds` reaches 3 (fed while `rise_phase` is `freshly_fed`, `developing` or `active`; `rise_phase`, not the state label, per the scientist). |
| Tier, cooldown | `nudge`, 72 h. |
| Choices | **Got it**: closes the card. No dismiss button needed. |
| Sim effect | Scientist v1 (via `game-designer`): feeding before peak dilutes the starter, so the next peak comes **later**. It does not get weaker. The copy says exactly that. |
| Teaches | Timing. Peak is the sweet spot. No guilt: "that's fine" comes first. |

| Key | Text | Max |
|---|---|---|
| `EVENT_FED_BEFORE_PEAK_TITLE` | Try waiting for the peak | 26 |
| `EVENT_FED_BEFORE_PEAK_BODY` | Fed mid-rise a few times now. That's fine, but it dilutes it, so each peak comes later. The dome is the sweet spot. | 120 |
| `EVENT_FED_BEFORE_PEAK_BTN` | Got it | 18 |
| `EVENT_FED_BEFORE_PEAK_JOURNAL_TITLE` | Note to self | 26 |
| `EVENT_FED_BEFORE_PEAK_JOURNAL_BODY` | Peak is the sweet spot for feeding. Look for a full dome and big bubbles near the top. | 200 |

### 4.5 `warm_and_quick`

| Field | Value |
|---|---|
| Trigger | At a warm location, the peak comes at no more than 0.85 × the 22 °C forecast for the same feed (game-mechanics §7.4). |
| Tier, cooldown | `info`, 72 h. |
| Teaches | Warm means faster, and hungry sooner. |

| Key | Text | Max |
|---|---|---|
| `EVENT_WARM_AND_QUICK_TOAST` | Peaked early. The warm spot speeds everything up. | 60 |
| `EVENT_WARM_AND_QUICK_AWAY` | It was warm, so it peaked early. | 44 |
| `EVENT_WARM_AND_QUICK_JOURNAL_TITLE` | Warm and quick | 26 |
| `EVENT_WARM_AND_QUICK_JOURNAL_BODY` | Peaked well ahead of its usual counter time. Warmth speeds it up, and it gets hungry sooner too. Handy when you want a peak soon. | 200 |

### 4.6 `getting_stretchy` (P1)

| Field | Value |
|---|---|
| Trigger | `maturity` reaches the `steady` threshold (TBD sim spec). Arrives with the `consistency` and `development` chips. |
| Tier, cooldown | `info`, one-time per starter. Pairs with `stage_steady` (journal only). |

| Key | Text | Max |
|---|---|---|
| `EVENT_GETTING_STRETCHY_TOAST` | It's getting stretchy. A sign it's growing up. | 60 |
| `EVENT_GETTING_STRETCHY_JOURNAL_TITLE` | Getting stretchy | 26 |
| `EVENT_GETTING_STRETCHY_JOURNAL_BODY` | Lift a spoonful at its peak and it pulls into strands now. That's a stronger, steadier starter. Check any time with Inspect, then Consistency. | 200 |

### 4.7 `big_bubble`

| Field | Value |
|---|---|
| Trigger | `rise_phase` enters `near_peak` and `feed_u` ≥ 0.85, where `feed_u` is the sim's stored per-feed draw. That is about 15% of cycles, and fully deterministic: event rules use no RNG (ADR-013, game-mechanics §7.3). The sim produces the bubble, so the jar shows it (CLAUDE.md rule 2). |
| Tier, cooldown | `info`, 48 h, max 1 a day. Ambient: first to be dropped from a summary. |
| Variant pick | `EVENT_BIG_BUBBLE_TOAST_<1 + (feed_count % 3)>`. |

| Key | Text | Max |
|---|---|---|
| `EVENT_BIG_BUBBLE_TOAST_1` | One big bubble just rose and popped. Showing off, really. | 60 |
| `EVENT_BIG_BUBBLE_TOAST_2` | Pop. A big one, right at the top. | 60 |
| `EVENT_BIG_BUBBLE_TOAST_3` | A big bubble surfaced and burst. It's in fine form. | 60 |
| `EVENT_BIG_BUBBLE_JOURNAL_TITLE` | Big bubble | 26 |
| `EVENT_BIG_BUBBLE_JOURNAL_BODY` | A big bubble rose and popped around {time}. Showing off. | 200 |

### 4.8 `trait_revealed` (P1)

| Field | Value |
|---|---|
| Trigger | The dominant trait is first set at stage `steady` (progression §5). Also fires when the trait drifts. |
| Tier, cooldown | `info`, one-time per trait. |
| Strings | Reveal toasts and journal pages: `TRAIT_*` in [`narrative.md`](narrative.md) §7.3. Drift lines below. |

| Key | Text | Max |
|---|---|---|
| `EVENT_TRAIT_DRIFT_TOAST` | {name} seems to have changed its ways lately. | 60 |
| `EVENT_TRAIT_DRIFT_JOURNAL_TITLE` | A change of character | 26 |
| `EVENT_TRAIT_DRIFT_JOURNAL_BODY` | Lately it has seemed like a different sort of starter. The journal has updated its opinion. Character, not chemistry: it rises the same as ever. | 200 |

### 4.9 `mold_found`

| Field | Value |
|---|---|
| Trigger | Enters `moldy` (`mold_risk` reaches 1.0, latched). |
| Tier, cooldown | `attention`, once. Replaces any waiting attention sheet (mechanics §7.3). |
| Visible signs (scientist) | Fuzzy spots of any color (white, green, blue, black) on the surface or the glass above it. Optionally a pink or orange tint or streaks. |
| Choices | **Discard it**: confirmation, then the memorial. **Not yet**: closes. Nothing else nags. |
| Strings | The whole flow is in [`narrative.md`](narrative.md) §9: `MOLD_SHEET_*` (use `_BODY_TINT` when tint is shown), `MOLD_CONFIRM_*`, `MEMORIAL_*`, `RESTART_*`. The return row is below. |
| Safety | Never "scrape it off", never "safe", no jokes. Scientist reviews. |

| Key | Text | Max |
|---|---|---|
| `EVENT_MOLD_FOUND_AWAY` | Mold appeared on the surface. | 44 |

---

## 5. Return summary order

Rows are built by `ReturnSummary.build()` (mechanics §8). Narrative ordering on top of their keep priority:
1. At most 3 rows, oldest first, so the summary reads as a story.
2. If warnings began during the absence, `EVENT_WARNING_SIGNS_AWAY_*` is always kept.
3. On a return to `moldy`, the rows are: the warning line, then `EVENT_MOLD_FOUND_AWAY`. Then the sheet opens.
4. The "Now" row reuses the status word and hint (ux). No new string.
5. Moments that aren't events (resting in the fridge, a quiet stretch) use the `AWAY_*` rows in [`game-copy.md`](game-copy.md) §10.

## 6. Decisions (events)

None open.
- OD-E1: `mold_found` in the slice behind the debug time scale. Accepted, D-017.
- OD-E2: rise-word bands. Set by the scientist (spec §14.1).
- OD-E3: `fed_before_peak` says peaks come later (dilution). Settled with the scientist.
- OD-E4: `game-designer`'s event ids kept.
- OD-E5: no pink or orange tint in the MVP. Accepted, D-026. The two tint strings stay unused.
