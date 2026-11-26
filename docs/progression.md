# Progression

Owner: `game-designer`. Status: Phase 1 wave A draft, 2026-11-26.

See [`game-design.md`](game-design.md) for intent and [`game-mechanics.md`](game-mechanics.md) for rules. "v1" means the scientist's calibrated numbers (2026-11-26, now in `starter-simulation-spec.md` §6 and §9). "TBD (sim spec)" means not yet given.

## 1. What progresses

Only two things progress:

| What | How it shows | Never |
|---|---|---|
| **The starter**: maturity, and a trait (P1) | Stronger, more reliable rises. Stage milestones. Trait wording. | A level number, a bar, XP |
| **The player**: knowledge | Unlock introductions. Meaning lines fading (mechanics §4). Milestones. The journal. | Points, currency, ranks |

## 2. Maturity stages

The stage ids are proposed and wait on the director (game-design OD-7). "Seasoned" is a game label, not a biology claim.

| Stage | `maturity` (v1) | Day reached from 0.2, twice daily 1:2:2 (v1) | Once daily 1:5:5 (v1) | What the player sees (the sim decides how) | Introduced at this stage |
|---|---|---|---|---|---|
| `young` | below 0.33 | Day 0. The gifted starter begins at 0.2. | Day 0 | Uneven rises, smaller peaks, sometimes a `cheesy` smell | The P0 set |
| `steady` | 0.33 | Day 6 | Day 8 | Reliable rise and fall | Trait reveal. P1: `rye`, hydration presets, `window_sill`, `consistency` and `development` chips |
| `mature` | 0.50 | Day 16 | Day 21 | Reliably doubles ("ready to bake") | P1: `spelt`, `proofing_box` |
| `seasoned` | 0.83 | Day 51.5 | Day 69 | Robust (game label) | P2: containers |

**Rules:**

| Rule | Value |
|---|---|
| Gain (v1, sim spec §6 and §9) | `maturity += 0.01024 × w × (1 − m)` for each feed that follows a real peak (peak at least 1.5×, vigor at least 0.6). |
| Generation weight | `w = min(2.5, log2(total / kept) / log2(3))`. A bigger dilution buys more doublings. The 2.5 cap stops 1:50:50 farming. The basis is low confidence and marked "tuned". |
| Once-daily player | A once-daily player on the matched ratio (1:5:5) reaches each stage in 1.31× to 1.34× the twice-daily time. That meets the 1.5× design target (BT-14b). |
| Mismatched routine | Once daily at 1:1:1 is hungry half of each day. It reaches `steady` on day 18 and `mature` on day 46. Keep this as a gentle lesson. The feed sheet hint (mechanics §2.2) points the player to 1:5:5, so the slowness is always explained and never silent. |
| Decay | Maturity **never decreases** (v1). Neglect costs time, not progress. |
| Display | A stage change is a milestone. It shows in the `development` inspection (P1) and the journal, never as a bar. |

## 3. Unlocks

**Principle: unlocks pace information, not power.**
- Each one arrives with a one-time narrator intro and a journal line.
- Nothing costs anything, and nothing needs grinding.
- Every P1 trigger is reachable within about 3 weeks of a matched routine: day 16 twice daily at 1:2:2, day 21 once daily at 1:5:5 (v1).
- Players who choose "I've kept a starter before" get every P0 and P1 option at once.
- Unlocks are per player: they survive a lost starter.

| Item | Kind | Tier | Trigger |
|---|---|---|---|
| `counter`, `warm_spot`, `fridge` | location | P0 | Start |
| `white_bread` | flour | P0 | Start |
| `height`, `bubbles`, `surface` | inspection | P0 | Start (B5 teaches `bubbles`) |
| `whole_wheat` | flour | P0 (VS) | After the first real-time `first_peak` (day 0 to 1) |
| `window_sill` | location | P1 | After `first_wake` or stage `steady`, whichever comes first |
| `rye` | flour | P1 | Stage `steady` |
| Hydration presets | feed input | P1 | Stage `steady` |
| `consistency`, `development` | inspection | P1 | Stage `steady` (pairs with `getting_stretchy`) |
| `spelt` | flour | P1 | Stage `mature` |
| `proofing_box` | location | P1 | Stage `mature` |
| `wide_mouth_jar` | container | P2 | Stage `mature` |
| `ceramic_crock`, `fermentation_vessel` | container | P2 | Stage `seasoned` |
| `cloth`, `tight_lid` | cover | P2, cosmetic or cut (OD-10) | Stage `steady` |
| Flour mixes, free gram steppers, no-discard | feed input | P2 | Settings ("advanced") |

## 4. Milestones

Milestones are one-time. Each writes a journal entry. If a milestone fires at the same moment as an event, only the event shows and the milestone is journal-only (mechanics §7.3). Narrative writes the copy.

**Scope:**
- **Starter:** resets with a new starter.
- **Player:** kept forever.

| id | Scope | Tier | Trigger |
|---|---|---|---|
| `named` | Starter | P0 | Name confirmed (B4) |
| `first_feed` | Starter | P0 | First real-time feed (B7) |
| `first_rise` | Starter | P0 | Paired with the `first_rise` event |
| `first_peak` | Starter | P0 | First real-time `at_peak`, seen or not |
| `first_double` | Starter | P0 | `peak_rise` ≥ 2.0 for the first time |
| `first_hooch` | Starter | P0 | `hooch_forming` first fires |
| `first_nap` | Starter | P0 | First move to `fridge` |
| `first_wake` | Starter | P0 | Paired with the `waking_up` event |
| `comeback` | Starter | P0 | `back_to_strength` after a feed with `starved_h` ≥ 24 |
| `rescued` | Starter | P0 | Out of `unhealthy` after a rescue feed |
| `nose_for_it` | Player | P0 | 4 distinct smell descriptors smelled |
| `stage_steady`, `stage_mature`, `stage_seasoned` | Starter | P0 | The stage is reached. `stage_mature` reads "ready to bake". |
| `one_week`, `one_month` | Starter | P0 | Calendar days since `adopted_at`: days owned, not days played |
| `flour_<id>` | Player | P1 | First feed with each flour |
| `trait_revealed` | Starter | P1 | Paired with the `trait_revealed` event |
| `memorial` | Starter | P0 | `moldy`. Closes the starter's journal chapter (game-design §5). |

## 5. Personality traits (P1)

Narrative owns the voice. **Traits change wording only, never the biology** (CLAUDE.md rule 2). Signals are read from the rolling 14-day ledger buckets (mechanics §7.5).

| Trait | Behavior signal over 14 days (design) | Attitude (narrative's voice; never a claim about speed or biology) |
|---|---|---|
| `energetic` | At least 50% of hours at 24 °C or above, **or** 2 or more feeds a day at 1:1:1 or 1:2:2 on at least 10 days | Eager |
| `patient` | At least 50% of hours at 18 °C or below, **or** mostly once-a-day 1:5:5 | Unhurried, calm |
| `resilient` | 2 or more `comeback` or `rescued` events | Unfazed. Neglect becomes character, not guilt. |
| `sensitive` | 8 or more changes of location, flour or ratio | Notices every change |

**Rules:**

| Rule | Value |
|---|---|
| Score | Each trait scores its progress toward its signal threshold. |
| Reveal | At stage `steady`, the highest score wins. Every starter gets a trait. |
| Tie-break | Fixed order: `resilient`, `patient`, `energetic`, `sensitive`. Deterministic. |
| Drift | If another trait leads for 14 days in a row, it becomes dominant and the journal says so. At most one change per 28 days. |

The trait ids follow narrative's list. New ids need the director (game-design OD-7).

## 6. Achievements (P2, small)

**Rules:**
- They're quiet: shown only on the journal's back page, with no toast pressure.
- None counts consecutive days.
- None asks for many feeds in one day.

| id | Condition |
|---|---|
| `peak_watcher` | Opened the app during `at_peak` 5 times |
| `full_nose` | Smelled every non-warning descriptor |
| `flour_tour` | Fed with all 4 flours |
| `good_timing` | 10 `on_time` feeds |
| `deep_sleeper` | Woke a starter after 14 or more days in the `fridge` |
| `rescuer` | Brought a starter back from `unhealthy` |
| `long_haul` | 100 days with one starter |

## 7. The journal: the record of progress

| Tier | Content |
|---|---|
| **P0 (minimal log)** | A chronological list of feeds (time, ratio, flour, grams), peaks (time, `peak_rise` in words), smells (once per descriptor per cycle), milestones, return summaries and dropped events, plus the memorial page. One chapter per starter. Read-only. |
| **P1 (rich)** | A rise sketch per cycle from recorded samples, a jar snapshot at each stage milestone, a name page and a trait page. |
| **P2** | Player notes, achievements on the back page, bread bakes. |

## 8. What we deliberately don't do

- No XP, levels, currency or shop.
- No streaks, daily login rewards or "don't break the chain".
- No milestones that need presence at a specific minute. `first_peak` counts unseen peaks.
- No unlocks behind grinding or behind payment.
- No loss of unlocks or knowledge when a starter is lost.
- No numbers or bars for maturity or traits on the main screen.
- No traits that change the sim, and no "bad" traits.
