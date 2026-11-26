# Game copy

Owner: `narrative-designer`. Status: Phase 1 wave A draft, 2026-11-26.

Every player-facing string with its `tr()` key, ready for `en.csv`. Voice: [`narrative.md`](narrative.md) §4. Events: [`events-catalog.md`](events-catalog.md). Onboarding, naming, traits and the memorial: [`narrative.md`](narrative.md) §6 to §9.

`sourdough-scientist` spot-checked every science claim on 2026-11-26 (yogurt, fruity, alcohol, cheesy, strands, collapse, doubling, hooch, mold depth) and confirmed them, with two wording fixes applied. Their wave B review (21 items) is applied, and they gave **safety sign-off** on this file, `events-catalog.md` and the `narrative.md` §9 mold flow (2026-11-26). Science source: [`sourdough-science.md`](sourdough-science.md).

## 1. Conventions

### 1.1 Keys and files

- Keys are `UPPER_SNAKE_CASE`, ASCII only (`^[A-Z][A-Z0-9_]*$`): `<AREA>_<ID>_<PART>`, for example `SMELL_YOGURT_2`. Agreed with `tech-architect` (architecture.md §10, ADR-014).
- **Each string appears exactly once** across `narrative.md`, `events-catalog.md` and this file, in a `Key | Text | Max` table. Nothing else in these docs is shipped text.
- `src/i18n/en.csv` (columns `keys,en`) is **generated** from those rows by `python3 -I tools/i18n/build_catalog.py .`, which runs the copy check (§16) first. Nobody hand-edits the CSV.
- Docs use straight quotes and apostrophes. The build converts them to curly ones. `ux-designer` checks that the Theme font has the glyphs.
- During Phase 2 and 3, code tracks put placeholder keys only in their own `src/i18n/pending_core.csv`, `pending_view.csv` or `pending_ui.csv`. Narrative moves them into these docs in a copy pass, and the track deletes its row. One writer per file.
- Godot CSV translations have no plural forms, so copy avoids plurals: counts appear as label and value pairs, or the key is split (`_HOURS` / `_DAYS`) so the number is always plural.

### 1.2 Slots and limits

Hard maximums from [`ux-design.md`](ux-design.md) §18, spaces included. The `Max` column in every table is one of these.

| Slot | Max |
|---|---|
| Starter name, name suggestion | 16 |
| Status word | 12 |
| Status hint (target 28) | 34 |
| Action bar label | 7 |
| Toast (`info`), coach mark, reaction, one-line note, feed result | 60 |
| Card, sheet, page, confirmation, empty-state and journal title | 26 |
| Card, onboarding page and confirmation body | 120 |
| Attention sheet body | 280 |
| Button label | 18 |
| Away heading / moment row | 26 / 44 |
| Smell title / sensory line / note / meaning | 20 / 60 / 30 / 90 |
| Inspect chip / observation / meaning | 11 / 90 / 90 |
| Feed ratio option title / sub-line | 20 / 34 |
| Flour chip, location card label and sub | 14 |
| Journal body | 200 |
| Empty-state body | 90 |
| Settings label / value | 24 / 12 |
| `accessibility_name` / description | 40 / 120 |
| Notification title / body (after the slice) | 30 / 90 |
| Status tap meaning (plus `FORECAST_LINE` during a rise) | 90 |
| Sheet section label | 26 |

### 1.3 Placeholders

Lengths are checked with each placeholder at its worst case.

| Placeholder | Worst case | Chars | Source |
|---|---|---|---|
| `{name}` | a 16-character name | 16 | player |
| `{window}` | "tomorrow afternoon" | 18 | §9 |
| `{time}` | "11:30 PM" | 8 | device locale |
| `{hours}`, `{days}` | "47", "14" | 2 | sim |
| `{start_date}`, `{end_date}` | "Nov 26, 2026" | 12 | device locale |
| `{grams}` | "150" | 3 | mechanics §2.3 |
| `{ratio}` | "1:5:5" | 5 | mechanics §2.1 |
| `{flour}` | "Whole wheat" | 11 | §7 |
| `{smell}` | "Nail polish remover" | 19 | §5 |
| `{note}` | "nail polish remover" | 19 | §5 |
| `{word}`, `{hint}` | status word, status hint | 12, 34 | §2 |

### 1.4 Deterministic picks

No string is ever picked with a free random call (CLAUDE.md rule 1).

| What | Rule | Why |
|---|---|---|
| Smell sensory line | `n = 1 + (feed_count + DESCRIPTOR_ORDER.find(d)) % 3` | Same line for the whole rise cycle (smelling twice gives the same answer), a new line next cycle, never the same line two cycles running for the same descriptor. |
| Feed reaction, neutral | `n = 1 + feed_count % 3` | Rotates. |
| `big_bubble` toast | `n = 1 + feed_count % 3` | Rotates. |
| Name suggestion | `(starter_seed + presses) % 24` | narrative.md §6 |
| Epitaph | trait if revealed, else `1 + starter_seed % 3` | narrative.md §9 |

`feed_count` is the starter's total number of feeds, saved. `DESCRIPTOR_ORDER` is vision.md's list order: `wet_flour`, `mildly_fruity`, `fresh_yeasty`, `yogurt`, `pleasantly_tangy`, `strongly_acidic`, `alcohol`, `acetone`, `cheesy`, `musty`. Inspection has one line per cell, so it needs no pick.

## 2. Status

The pill shows an icon plus the word, never color alone. The hint is always shown under it. Tapping the status shows the tap line, plus the forecast during a rise (§9).

`dormant` has two display versions. Use `_COLD` when the spec's cold condition holds (`ferm(temp_c)` < 0.30, below about 11 °C, [`starter-simulation-spec.md`](starter-simulation-spec.md) state table), otherwise `_STARVED` (`starved_h` ≥ 60).

| Key | Text | Max |
|---|---|---|
| `STATUS_FRESHLY_FED_WORD` | Just fed | 12 |
| `STATUS_FRESHLY_FED_HINT` | Flat, smooth and settling in | 34 |
| `STATUS_FRESHLY_FED_TAP` | Fresh flour and water, just mixed in. The rise comes next. | 90 |
| `STATUS_DEVELOPING_WORD` | Stirring | 12 |
| `STATUS_DEVELOPING_HINT` | First bubbles are forming | 34 |
| `STATUS_DEVELOPING_TAP` | The yeast is waking up. It's starting to rise. | 90 |
| `STATUS_ACTIVE_WORD` | Rising | 12 |
| `STATUS_ACTIVE_HINT` | Bubbly and climbing steadily | 34 |
| `STATUS_ACTIVE_TAP` | Busy making gas. That gas is what raises bread. | 90 |
| `STATUS_NEAR_PEAK_WORD` | Nearly there | 12 |
| `STATUS_NEAR_PEAK_HINT` | Rise slowing, dome forming | 34 |
| `STATUS_NEAR_PEAK_TAP` | Close to its tallest. Peak comes soon. | 90 |
| `STATUS_AT_PEAK_WORD` | At its peak | 12 |
| `STATUS_AT_PEAK_HINT` | Tall, domed, at its best | 34 |
| `STATUS_AT_PEAK_TAP` | Its tallest point, just before it falls. The best time to feed it. | 90 |
| `STATUS_COLLAPSING_WORD` | Past peak | 12 |
| `STATUS_COLLAPSING_HINT` | Dome falling, food running low | 34 |
| `STATUS_COLLAPSING_TAP` | It peaked and is falling back. A fine time to feed. | 90 |
| `STATUS_HUNGRY_WORD` | Hungry | 12 |
| `STATUS_HUNGRY_HINT` | Food's gone. Ready for a feed | 34 |
| `STATUS_HUNGRY_TAP` | It has eaten everything. Sour smells and hooch are normal now. Feed it. | 90 |
| `STATUS_DORMANT_COLD_WORD` | Resting | 12 |
| `STATUS_DORMANT_COLD_HINT` | Cold and quiet. It can wait | 34 |
| `STATUS_DORMANT_COLD_TAP` | The cold slows it nearly to a stop. A feed or two wakes it later. | 90 |
| `STATUS_DORMANT_STARVED_WORD` | Run down | 12 |
| `STATUS_DORMANT_STARVED_HINT` | Very hungry. Feed it today | 34 |
| `STATUS_DORMANT_STARVED_TAP` | It has gone a long time without food. A feed or two brings it round. | 90 |
| `STATUS_RECOVERING_WORD` | Recovering | 12 |
| `STATUS_RECOVERING_HINT` | Getting its strength back | 34 |
| `STATUS_RECOVERING_TAP` | Weaker than usual after a hard stretch. Regular feeds rebuild it. | 90 |
| `STATUS_UNHEALTHY_WORD` | At risk | 12 |
| `STATUS_UNHEALTHY_HINT` | Warning signs. Look, then feed | 34 |
| `STATUS_UNHEALTHY_TAP` | Musty, run down. No mold yet. Fuzz or color on top means discard. If none, feed it. | 90 |
| `STATUS_MOLDY_WORD` | Moldy | 12 |
| `STATUS_MOLDY_HINT` | Mold. Please discard it | 34 |
| `STATUS_MOLDY_TAP` | Mold can't be fixed. Discard all of it and wash the jar. | 90 |
| `STATUS_A11Y` | Status: {word}. {hint} | 120 |
| `STATUS_SHOW_ME_BTN` | Show me | 18 |

The status pill's `accessibility_name` is the status word itself (12, within 40). `STATUS_A11Y` is its description. `STATUS_SHOW_ME_BTN` is the button in the status explainer.

## 3. Action bar and main screen

| Key | Text | Max |
|---|---|---|
| `ACTION_FEED` | Feed | 7 |
| `ACTION_SMELL` | Smell | 7 |
| `ACTION_INSPECT` | Inspect | 7 |
| `ACTION_ENVIRONMENT` | Place | 7 |
| `ACTION_JOURNAL` | Journal | 7 |
| `ACTION_FEED_A11Y` | Feed the starter | 40 |
| `ACTION_SMELL_A11Y` | Smell the starter | 40 |
| `ACTION_INSPECT_A11Y` | Inspect the starter | 40 |
| `ACTION_ENVIRONMENT_A11Y` | Place: choose where it lives | 40 |
| `ACTION_JOURNAL_A11Y` | Open the journal | 40 |
| `SETTINGS_A11Y` | Settings | 40 |
| `JAR_A11Y_NAME` | Starter jar | 40 |
| `JAR_A11Y_DESC` | Drag to turn the jar. Pinch to look closer. | 120 |
| `TOAST_A11Y_MORE` | Opens the journal entry | 40 |

### 3.1 Why an action didn't run

`ActionResult.reason_key` when the session rejects an action (data-models §4). Shown as a toast, or as the reason line under a disabled control (ux-design §17), so every line uses the toast limit. Most of these only fire on a stale or buggy UI, so they stay short and neutral. A rejected feed on a moldy starter uses `MOLD_FEED_BLOCKED` ([`narrative.md`](narrative.md) §9).

| Key | Text | Max |
|---|---|---|
| `REASON_MOLDY_LOCKED` | Not while there's mold. Please discard it. | 60 |
| `REASON_NOT_MOLDY` | No mold here, so there's no need to throw it out. | 60 |
| `REASON_KEEP_RANGE` | Keep at least 1 g, and no more than is in the jar. | 60 |
| `REASON_FLOUR` | Pick a flour to feed with. | 60 |
| `REASON_WATER` | Too much or too little water for a starter. | 60 |
| `REASON_MASS` | Those amounts don't add up. Try one of the ratios. | 60 |
| `REASON_HOOCH_CHOICE` | Pour off the hooch or stir it in first. | 60 |
| `REASON_ENVIRONMENT` | That place isn't available. | 60 |
| `REASON_INSPECT_KIND` | That one can't be inspected yet. | 60 |
| `REASON_NAME` | A name needs 1 to 16 characters. | 60 |
| `REASON_EVENT` | That note is already gone. | 60 |
| `REASON_SAVE_FAILED` | Couldn't save just now. Trying again soon. | 60 |
| `REASON_NOT_READY` | One moment. Still getting ready. | 60 |

`REASON_NAME` states the 16-character name slot (ux-design §18, the `{name}` worst case in §1.3). `REASON_SAVE_FAILED` is shown once per failing streak. The next action, state change or 10-minute autosave tries again.

### 3.2 Shared controls and settings

Used by the UI component inventory (ux-design §14 and §17). Settings rows so far: text size and reduce motion.

| Key | Text | Max |
|---|---|---|
| `UI_DONE_BTN` | Done | 18 |
| `UI_CLOSE_A11Y` | Close | 40 |
| `UI_DECREASE_A11Y` | Decrease | 40 |
| `UI_INCREASE_A11Y` | Increase | 40 |
| `SETTINGS_TITLE` | Settings | 26 |
| `SETTINGS_TEXT_SIZE` | Text size | 24 |
| `SETTINGS_TEXT_STANDARD` | Standard | 12 |
| `SETTINGS_TEXT_LARGE` | Large | 12 |
| `SETTINGS_TEXT_LARGEST` | Largest | 12 |
| `SETTINGS_REDUCE_MOTION` | Reduce motion | 24 |

## 4. Forecast

Shown on the feed result card and on a status tap during a rise phase. Not shown for `hungry`, `dormant`, `unhealthy` or `moldy` (mechanics §6).

| Key | Text | Max |
|---|---|---|
| `FORECAST_LINE` | It should be at its best {window}. | 60 |

## 5. Smell

### 5.1 How a smell card is built

| Part | Rule |
|---|---|
| Title | The primary descriptor's `_TITLE`. |
| Body | The primary descriptor's sensory line `_<n>` (§1.4), then a note on the secondary descriptor if its intensity is at least 0.15 (**ASSUMED**): `SMELL_NOTE_FAINT` below 0.5, `SMELL_NOTE_CLEAR` at 0.5 or more. Max 60 + 1 + 30 = 91, so the note slot is 29 in practice. Checked below. |
| Meaning | The primary descriptor's `_MEANING`, for the first 3 times that descriptor appears. Then one tap away. **`musty` never fades.** |
| `musty` rule | If `musty` has any intensity, it is the primary descriptor, so a warning is never buried in a note. |
| Faint rule | If every descriptor is below 0.3 (cold `dormant`) **and `musty` is absent**, use the `SMELL_FAINT_*` lines and note the top descriptor. At the watch stage `musty` sits at 0.2 to 0.3, so the faint rule must never hide it (scientist). |
| `moldy` | Use `SMELL_MOLDY_*` only. No sniffing (scientist). |
| Third descriptor | Not shown in text. The scientist suggests the top two or three; the slot fits two. |

### 5.2 Notes

| Key | Text | Max |
|---|---|---|
| `SMELL_NOTE_FAINT` | A hint of {note}. | 30 |
| `SMELL_NOTE_CLEAR` | And some {note}. | 30 |

### 5.3 Descriptors

`wet_flour`: just fed.

| Key | Text | Max |
|---|---|---|
| `SMELL_WET_FLOUR_TITLE` | Wet flour | 20 |
| `SMELL_WET_FLOUR_NOTE` | wet flour | 19 |
| `SMELL_WET_FLOUR_1` | Like flour and water stirred together. Mild and clean. | 60 |
| `SMELL_WET_FLOUR_2` | A clean, floury smell, like a bag of flour on a damp day. | 60 |
| `SMELL_WET_FLOUR_3` | Raw dough, plain and mild. Not much else, yet. | 60 |
| `SMELL_WET_FLOUR_MEANING` | Just fed. The yeast hasn't really got going yet. | 90 |

`mildly_fruity`: early rise.

| Key | Text | Max |
|---|---|---|
| `SMELL_MILDLY_FRUITY_TITLE` | Fruity | 20 |
| `SMELL_MILDLY_FRUITY_NOTE` | ripe fruit | 19 |
| `SMELL_MILDLY_FRUITY_1` | A soft fruitiness, like a bowl of ripe apples. | 60 |
| `SMELL_MILDLY_FRUITY_2` | Faintly fruity. Pear, maybe, or apple skins. | 60 |
| `SMELL_MILDLY_FRUITY_3` | A gentle fruit note, like a fresh-cut apple. | 60 |
| `SMELL_MILDLY_FRUITY_MEANING` | Often early in the rise, as the yeast wakes up. | 90 |

`fresh_yeasty`: mid-rise.

| Key | Text | Max |
|---|---|---|
| `SMELL_FRESH_YEASTY_TITLE` | Yeasty | 20 |
| `SMELL_FRESH_YEASTY_NOTE` | fresh bread | 19 |
| `SMELL_FRESH_YEASTY_1` | Fresh and bready, like a bakery door opening. | 60 |
| `SMELL_FRESH_YEASTY_2` | Warm and yeasty, like bread dough left to rise. | 60 |
| `SMELL_FRESH_YEASTY_3` | That fresh-bread smell, soft and inviting. | 60 |
| `SMELL_FRESH_YEASTY_MEANING` | Mid-rise. The yeast is busy making gas. | 90 |

`yogurt`: rising well.

| Key | Text | Max |
|---|---|---|
| `SMELL_YOGURT_TITLE` | Yogurt | 20 |
| `SMELL_YOGURT_NOTE` | yogurt | 19 |
| `SMELL_YOGURT_1` | Mild and milky-sour, like plain yogurt. | 60 |
| `SMELL_YOGURT_2` | A soft, creamy tang. Plain yogurt, more or less. | 60 |
| `SMELL_YOGURT_3` | Like a freshly opened tub of yogurt. | 60 |
| `SMELL_YOGURT_MEANING` | The bacteria are at work. Lactic acid gives that yogurt note. | 90 |

`pleasantly_tangy`: around peak.

| Key | Text | Max |
|---|---|---|
| `SMELL_PLEASANTLY_TANGY_TITLE` | Tangy | 20 |
| `SMELL_PLEASANTLY_TANGY_NOTE` | tang | 19 |
| `SMELL_PLEASANTLY_TANGY_1` | A bright, clean tang with a little sweetness behind it. | 60 |
| `SMELL_PLEASANTLY_TANGY_2` | Pleasantly sour, like the crumb of a good sourdough. | 60 |
| `SMELL_PLEASANTLY_TANGY_3` | Tangy and lively. Your nose will want another go. | 60 |
| `SMELL_PLEASANTLY_TANGY_MEANING` | Around its peak, or just past it. The smell bakers hope for. | 90 |

`strongly_acidic`: hungry.

| Key | Text | Max |
|---|---|---|
| `SMELL_STRONGLY_ACIDIC_TITLE` | Very sour | 20 |
| `SMELL_STRONGLY_ACIDIC_NOTE` | vinegar | 19 |
| `SMELL_STRONGLY_ACIDIC_1` | Sharp and sour, like vinegar. | 60 |
| `SMELL_STRONGLY_ACIDIC_2` | Strongly sour. It catches the back of your nose. | 60 |
| `SMELL_STRONGLY_ACIDIC_3` | Vinegar-sharp, with not much sweetness left. | 60 |
| `SMELL_STRONGLY_ACIDIC_MEANING` | Hungry. Acid builds up once the food runs out. Normal. Feed it. | 90 |

`alcohol`: hungry.

| Key | Text | Max |
|---|---|---|
| `SMELL_ALCOHOL_TITLE` | Boozy | 20 |
| `SMELL_ALCOHOL_NOTE` | beer | 19 |
| `SMELL_ALCOHOL_1` | Boozy, like stale beer. | 60 |
| `SMELL_ALCOHOL_2` | A whiff of alcohol, like cheap wine. | 60 |
| `SMELL_ALCOHOL_3` | Beery and sharp, like the morning after a party. | 60 |
| `SMELL_ALCOHOL_MEANING` | Hungry. Alcohol builds up when food runs low. Normal. Feed it. | 90 |

`acetone`: very hungry.

| Key | Text | Max |
|---|---|---|
| `SMELL_ACETONE_TITLE` | Nail polish remover | 20 |
| `SMELL_ACETONE_NOTE` | nail polish remover | 19 |
| `SMELL_ACETONE_1` | Sharp and solvent, like nail polish remover. | 60 |
| `SMELL_ACETONE_2` | Sharp and chemical. Nail polish remover, clearly. | 60 |
| `SMELL_ACETONE_3` | Like nail polish remover. Odd, from flour and water. | 60 |
| `SMELL_ACETONE_MEANING` | Very hungry. Odd, but normal. A feed or two clears it. | 90 |

`cheesy`: young starter (`maturity` below 0.33, spec §14.1).

| Key | Text | Max |
|---|---|---|
| `SMELL_CHEESY_TITLE` | Cheesy | 20 |
| `SMELL_CHEESY_NOTE` | parmesan | 19 |
| `SMELL_CHEESY_1` | A little cheesy, like parmesan rind. | 60 |
| `SMELL_CHEESY_2` | Faintly cheesy. A bit like old socks, honestly. | 60 |
| `SMELL_CHEESY_3` | Cheesy and slightly funky, like a cheese counter. | 60 |
| `SMELL_CHEESY_MEANING` | Normal for a young starter. It fades as it matures. | 90 |

`musty`: warning sign. Its meaning line never fades.

| Key | Text | Max |
|---|---|---|
| `SMELL_MUSTY_TITLE` | Musty | 20 |
| `SMELL_MUSTY_NOTE` | damp cellar | 19 |
| `SMELL_MUSTY_1` | Musty, like a damp cellar. | 60 |
| `SMELL_MUSTY_2` | A stale, musty note, like damp cardboard. | 60 |
| `SMELL_MUSTY_3` | Damp and musty, under the sourness. | 60 |
| `SMELL_MUSTY_MEANING` | A warning sign. Check the surface first: fuzz or color means discard. If none, feed it. | 90 |

### 5.4 Faint and moldy

| Key | Text | Max |
|---|---|---|
| `SMELL_FAINT_TITLE` | Very faint | 20 |
| `SMELL_FAINT_1` | Barely anything. The cold keeps its smells to itself. | 60 |
| `SMELL_FAINT_2` | Faint and cool. A ghost of tang, not much more. | 60 |
| `SMELL_FAINT_MEANING` | It's cold, so everything slows down, smells included. | 90 |
| `SMELL_MOLDY_TITLE` | Best not | 20 |
| `SMELL_MOLDY_BODY` | No need to sniff a moldy jar. The surface says enough. Please discard it. | 90 |

`SMELL_FAINT_<n>` uses `n = 1 + feed_count % 2`.

## 6. Inspection

P0 kinds: `height`, `bubbles`, `surface`. P1: `consistency`, `development` (game-design OD-5). One line per cell. Keys: `INSPECT_<KIND>_<STATE>_OBS` and `_MEAN`. Meaning lines fade after 3 views, except warning and mold lines, which never fade (mechanics §5).

**Shared rules:**
- `dormant` has one observation and two meanings: `_MEAN_COLD` and `_MEAN_STARVED` (same rule as §2).
- `moldy`: `surface` uses its own mold lines. Every other kind shows `INSPECT_ANY_MOLDY_*`.
- Hooch: while `hooch` ≥ 0.10 (visible) and the state is not `unhealthy` or `moldy`, `surface` shows `INSPECT_SURFACE_HOOCH_*` instead of the state's lines. It shows `INSPECT_SURFACE_HOOCH_DARK_*` instead when `hooch` ≥ 0.8, or when `hooch` ≥ 0.10 and `mold_risk` ≥ 0.3 (the watch stage). Those never fade.
- `recovering`: `recovering` overlaps every rise phase, so `bubbles`, `height`, `surface` and `consistency` show the observation for the current `rise_phase`, with `INSPECT_RECOVERING_MEAN` as the meaning line (scientist).
- Flour: at `at_peak`, `surface` uses the flour's `_OBS` override if one exists (`whole_wheat`, `rye`, `spelt`). White bread flour uses the default.

| Key | Text | Max |
|---|---|---|
| `INSPECT_SHEET_TITLE` | Inspect | 26 |
| `INSPECT_CHIP_BUBBLES` | Bubbles | 11 |
| `INSPECT_CHIP_HEIGHT` | Height | 11 |
| `INSPECT_CHIP_SURFACE` | Surface | 11 |
| `INSPECT_CHIP_CONSISTENCY` | Consistency | 11 |
| `INSPECT_CHIP_DEVELOPMENT` | Development | 11 |
| `INSPECT_ANY_MOLDY_OBS` | There's mold on the surface. No need to look closer. | 90 |
| `INSPECT_ANY_MOLDY_MEAN` | Please discard all of it and wash the jar. | 90 |
| `INSPECT_RECOVERING_MEAN` | Weaker than usual for now. Regular feeds rebuild it. | 90 |

### 6.1 Bubbles (P0)

| Key | Text | Max |
|---|---|---|
| `INSPECT_BUBBLES_FRESHLY_FED_OBS` | Hardly any. Just a few air pockets from stirring. | 90 |
| `INSPECT_BUBBLES_FRESHLY_FED_MEAN` | Normal right after a feed. Bubbles come as the yeast wakes up. | 90 |
| `INSPECT_BUBBLES_DEVELOPING_OBS` | A scattering of small bubbles, mostly against the glass. | 90 |
| `INSPECT_BUBBLES_DEVELOPING_MEAN` | Fermentation has started. The rise is on its way. | 90 |
| `INSPECT_BUBBLES_ACTIVE_OBS` | Lots of bubbles, small and medium, all through the jar. | 90 |
| `INSPECT_BUBBLES_ACTIVE_MEAN` | It's making gas steadily. That gas is what raises bread. | 90 |
| `INSPECT_BUBBLES_NEAR_PEAK_OBS` | Big bubbles near the top, a few popping at the surface. | 90 |
| `INSPECT_BUBBLES_NEAR_PEAK_MEAN` | Big bubbles up high mean peak is close. | 90 |
| `INSPECT_BUBBLES_AT_PEAK_OBS` | Bubbles all the way up, some breaking through the dome. | 90 |
| `INSPECT_BUBBLES_AT_PEAK_MEAN` | Peak activity. A great moment to feed it. | 90 |
| `INSPECT_BUBBLES_COLLAPSING_OBS` | Bubbles are bursting, and the top looks pocked. | 90 |
| `INSPECT_BUBBLES_COLLAPSING_MEAN` | The gas is escaping as the food runs out. It's past peak. | 90 |
| `INSPECT_BUBBLES_HUNGRY_OBS` | A few spent bubbles. Most have burst. | 90 |
| `INSPECT_BUBBLES_HUNGRY_MEAN` | It has used up its food. A feed brings the bubbles back. | 90 |
| `INSPECT_BUBBLES_DORMANT_OBS` | Almost none. Maybe one, rising very slowly. | 90 |
| `INSPECT_BUBBLES_DORMANT_MEAN_COLD` | The cold slows everything down. It's resting, and can wait. | 90 |
| `INSPECT_BUBBLES_DORMANT_MEAN_STARVED` | It has waited a long time for food. A feed or two will wake it. | 90 |
| `INSPECT_BUBBLES_UNHEALTHY_OBS` | Very few bubbles, and slow to form. | 90 |
| `INSPECT_BUBBLES_UNHEALTHY_MEAN` | A warning sign. Check the surface, then feed. One feed usually turns it around. | 90 |

### 6.2 Height (P0)

At peak, the observation depends on `peak_rise` (bands in [`events-catalog.md`](events-catalog.md) §3.2) and the meaning is shared.

| Key | Text | Max |
|---|---|---|
| `INSPECT_HEIGHT_FRESHLY_FED_OBS` | Level with the rubber band. | 90 |
| `INSPECT_HEIGHT_FRESHLY_FED_MEAN` | That's the starting line. Watch it climb from here. | 90 |
| `INSPECT_HEIGHT_DEVELOPING_OBS` | Just above the rubber band. | 90 |
| `INSPECT_HEIGHT_DEVELOPING_MEAN` | The rise has begun. | 90 |
| `INSPECT_HEIGHT_ACTIVE_OBS` | Above the band, and climbing. | 90 |
| `INSPECT_HEIGHT_ACTIVE_MEAN` | It's rising steadily. Peak is still to come. | 90 |
| `INSPECT_HEIGHT_NEAR_PEAK_OBS` | High up the jar, and the climb is slowing. | 90 |
| `INSPECT_HEIGHT_NEAR_PEAK_MEAN` | Peak is close. | 90 |
| `INSPECT_HEIGHT_AT_PEAK_SMALL_OBS` | At its peak, not far above the band. | 90 |
| `INSPECT_HEIGHT_AT_PEAK_NEAR_OBS` | At its peak, nearly double its starting height. | 90 |
| `INSPECT_HEIGHT_AT_PEAK_DOUBLE_OBS` | At its peak, about double its starting height. | 90 |
| `INSPECT_HEIGHT_AT_PEAK_BIG_OBS` | At its peak, well over double its starting height. | 90 |
| `INSPECT_HEIGHT_AT_PEAK_MEAN` | Peak: its tallest point, just before it falls. Feed it now. | 90 |
| `INSPECT_HEIGHT_COLLAPSING_OBS` | Dropped from its high point. Streaks on the glass show how tall it got. | 90 |
| `INSPECT_HEIGHT_COLLAPSING_MEAN` | It peaked and is falling back. A good time to feed. | 90 |
| `INSPECT_HEIGHT_HUNGRY_OBS` | Sunk back down, with streaks high on the glass. | 90 |
| `INSPECT_HEIGHT_HUNGRY_MEAN` | It rose and fell. The food is gone. | 90 |
| `INSPECT_HEIGHT_DORMANT_OBS` | Barely above the band, and not moving. | 90 |
| `INSPECT_HEIGHT_DORMANT_MEAN_COLD` | The cold keeps it low and still. It'll rise again once it's warm and fed. | 90 |
| `INSPECT_HEIGHT_DORMANT_MEAN_STARVED` | It has run out of energy. A feed or two will get it rising. | 90 |
| `INSPECT_HEIGHT_UNHEALTHY_OBS` | Flat. It has barely risen in a while. | 90 |
| `INSPECT_HEIGHT_UNHEALTHY_MEAN` | A warning sign. Check the surface, then feed it. | 90 |

### 6.3 Surface (P0)

The surface is where the player learns the real discard rule, so its warning and mold lines never fade.

| Key | Text | Max |
|---|---|---|
| `INSPECT_SURFACE_FRESHLY_FED_OBS` | Smooth, flat and a little glossy. | 90 |
| `INSPECT_SURFACE_FRESHLY_FED_MEAN` | Freshly fed. Nothing to see yet. | 90 |
| `INSPECT_SURFACE_DEVELOPING_OBS` | Mostly smooth, with a few pinprick bubbles. | 90 |
| `INSPECT_SURFACE_DEVELOPING_MEAN` | Things are starting. | 90 |
| `INSPECT_SURFACE_ACTIVE_OBS` | Bumpy and bubbly, starting to dome. | 90 |
| `INSPECT_SURFACE_ACTIVE_MEAN` | Good, steady activity. | 90 |
| `INSPECT_SURFACE_NEAR_PEAK_OBS` | Domed, with bubbles stretching the top. | 90 |
| `INSPECT_SURFACE_NEAR_PEAK_MEAN` | Nearly at its peak. | 90 |
| `INSPECT_SURFACE_AT_PEAK_OBS` | A full, rounded dome, freckled with bubbles. | 90 |
| `INSPECT_SURFACE_AT_PEAK_WHOLE_WHEAT_OBS` | A rounded dome, tan and flecked, freckled with bubbles. | 90 |
| `INSPECT_SURFACE_AT_PEAK_RYE_OBS` | A low top, cracked and pitted with bubbles. | 90 |
| `INSPECT_SURFACE_AT_PEAK_SPELT_OBS` | A low, soft dome, freckled with bubbles. | 90 |
| `INSPECT_SURFACE_AT_PEAK_MEAN` | The dome means peak. A great moment to feed. | 90 |
| `INSPECT_SURFACE_COLLAPSING_OBS` | The dome has sunk in the middle, wrinkled and pocked. | 90 |
| `INSPECT_SURFACE_COLLAPSING_MEAN` | Past peak. It's falling back. | 90 |
| `INSPECT_SURFACE_HUNGRY_OBS` | Flat and sunken, pocked with burst bubbles. | 90 |
| `INSPECT_SURFACE_HUNGRY_MEAN` | Hungry. Feed it when it suits you. | 90 |
| `INSPECT_SURFACE_DORMANT_OBS` | Flat and still. | 90 |
| `INSPECT_SURFACE_DORMANT_MEAN_COLD` | Resting in the cold. That's what the fridge is for. | 90 |
| `INSPECT_SURFACE_DORMANT_MEAN_STARVED` | Run down after a long wait. Feed it today. | 90 |
| `INSPECT_SURFACE_HOOCH_OBS` | A layer of grayish liquid on top. That's hooch. | 90 |
| `INSPECT_SURFACE_HOOCH_MEAN` | A hunger sign, and normal. Pour it off or stir it in, then feed. | 90 |
| `INSPECT_SURFACE_HOOCH_DARK_OBS` | A thicker, darker layer of hooch on top. | 90 |
| `INSPECT_SURFACE_HOOCH_DARK_MEAN` | Dark hooch is still a hunger sign, but it has been a while. Feed it today. | 90 |
| `INSPECT_SURFACE_UNHEALTHY_OBS` | A dull, dry skin across the top, maybe with dark liquid. | 90 |
| `INSPECT_SURFACE_UNHEALTHY_MEAN` | Warning sign. Fuzz, or pink or orange color, means discard. If none, feed it now. | 90 |
| `INSPECT_SURFACE_MOLDY_FUZZ_OBS` | Fuzzy spots on the surface. That's mold. | 90 |
| `INSPECT_SURFACE_MOLDY_TINT_OBS` | Fuzzy spots of mold, and pink or orange spoilage. | 90 |
| `INSPECT_SURFACE_MOLDY_MEAN` | It can't be saved. Discard all of it, even parts that look clean. | 90 |

`INSPECT_SURFACE_MOLDY_TINT_OBS` is unused in v0 (art shows no tint), kept unused. D-026: no tint in the MVP.

### 6.4 Consistency (P1)

`dormant` splits its observation too: cold is firm, starved is runny (acid, scientist). With the P1 stiff hydration preset (60%, spec `stiff_dough`), use a `_STIFF_` observation where one exists. Stiff starter is never soupy or pourable.

| Key | Text | Max |
|---|---|---|
| `INSPECT_CONSISTENCY_FRESHLY_FED_OBS` | Thick and smooth, like pancake batter. | 90 |
| `INSPECT_CONSISTENCY_FRESHLY_FED_MEAN` | Fresh flour and water, just mixed in. | 90 |
| `INSPECT_CONSISTENCY_DEVELOPING_OBS` | Still thick, with a few small air pockets. | 90 |
| `INSPECT_CONSISTENCY_DEVELOPING_MEAN` | Mostly fresh food so far. Give it time. | 90 |
| `INSPECT_CONSISTENCY_ACTIVE_OBS` | Softer and airier as it fills with gas. | 90 |
| `INSPECT_CONSISTENCY_ACTIVE_MEAN` | Good activity. It's on track. | 90 |
| `INSPECT_CONSISTENCY_NEAR_PEAK_OBS` | Light and spongy. It stretches a little off the spoon. | 90 |
| `INSPECT_CONSISTENCY_NEAR_PEAK_MEAN` | Strands are forming. A sign of a strong rise. | 90 |
| `INSPECT_CONSISTENCY_AT_PEAK_OBS` | Light, stretchy and webby, like marshmallow fluff. | 90 |
| `INSPECT_CONSISTENCY_AT_PEAK_MEAN` | This texture means it's strong and ready. | 90 |
| `INSPECT_CONSISTENCY_COLLAPSING_OBS` | Looser now. The web is breaking down. | 90 |
| `INSPECT_CONSISTENCY_COLLAPSING_MEAN` | Acid and time soften it as the food runs out. Feed soon. | 90 |
| `INSPECT_CONSISTENCY_HUNGRY_OBS` | Thin and soupy, almost pourable. | 90 |
| `INSPECT_CONSISTENCY_HUNGRY_MEAN` | A hungry starter goes runny. A feed thickens it again. | 90 |
| `INSPECT_CONSISTENCY_DORMANT_OBS_COLD` | Firm and cold. | 90 |
| `INSPECT_CONSISTENCY_DORMANT_OBS_STARVED` | Thin and runny. | 90 |
| `INSPECT_CONSISTENCY_DORMANT_MEAN_COLD` | The cold keeps it firm and quiet. | 90 |
| `INSPECT_CONSISTENCY_DORMANT_MEAN_STARVED` | It has waited a long time. Feed it to bring it round. | 90 |
| `INSPECT_CONSISTENCY_UNHEALTHY_OBS` | Slack and lifeless under a dry skin. | 90 |
| `INSPECT_CONSISTENCY_UNHEALTHY_MEAN` | A warning sign. Check the surface, then feed it. | 90 |
| `INSPECT_CONSISTENCY_FRESHLY_FED_STIFF_OBS` | Firm, like a soft bread dough. | 90 |
| `INSPECT_CONSISTENCY_AT_PEAK_STIFF_OBS` | Puffy and spongy, like a well-risen dough. | 90 |
| `INSPECT_CONSISTENCY_HUNGRY_STIFF_OBS` | Softer and sticky, but it still holds its shape. | 90 |
| `INSPECT_CONSISTENCY_DORMANT_STIFF_OBS_STARVED` | Soft and sticky. | 90 |

### 6.5 Development (P1)

Keyed by maturity stage (progression §2), not by state. Overlays win in this order: `moldy`, then `unhealthy`, then weakened (`recovering`, or `vigor` below 0.6), then the stage.

| Key | Text | Max |
|---|---|---|
| `INSPECT_DEVELOPMENT_YOUNG_OBS` | Young. A little slower and lower for now, and sometimes a cheesy smell. | 90 |
| `INSPECT_DEVELOPMENT_YOUNG_MEAN` | Normal for a young starter. Regular feeds build it up. | 90 |
| `INSPECT_DEVELOPMENT_STEADY_OBS` | Steadier now. It rises higher and sooner than it did when young. | 90 |
| `INSPECT_DEVELOPMENT_STEADY_MEAN` | Maturing nicely. Keep doing what you're doing. | 90 |
| `INSPECT_DEVELOPMENT_MATURE_OBS` | Strong and reliable. It doubles, and bounces back well. | 90 |
| `INSPECT_DEVELOPMENT_MATURE_MEAN` | A mature starter, strong enough to raise bread. | 90 |
| `INSPECT_DEVELOPMENT_SEASONED_OBS` | Robust and dependable. It has seen a few things. | 90 |
| `INSPECT_DEVELOPMENT_SEASONED_MEAN` | A seasoned starter. The kind people hand down. | 90 |
| `INSPECT_DEVELOPMENT_WEAKENED_OBS` | Weaker than usual after a hard stretch. | 90 |
| `INSPECT_DEVELOPMENT_WEAKENED_MEAN` | Regular feeds at room temperature rebuild it. | 90 |
| `INSPECT_DEVELOPMENT_UNHEALTHY_OBS` | Run down, with warning signs. | 90 |
| `INSPECT_DEVELOPMENT_UNHEALTHY_MEAN` | Check the surface, then feed it. It can still recover. | 90 |

## 7. Feed sheet

Flow (ux §8, mechanics §2): the sheet opens with last time's choices preselected. The common path is Feed, then Mix.

| Key | Text | Max |
|---|---|---|
| `FEED_SHEET_TITLE` | Feed | 26 |
| `FEED_SAME_AS_LAST` | Same as last time | 18 |
| `FEED_SUMMARY` | Keep {grams} g · {ratio} · {flour} | 34 |
| `FEED_SCHEDULE_QUESTION` | When will you check next? | 26 |
| `FEED_OPTION_SOON_TITLE` | In a few hours | 20 |
| `FEED_OPTION_LATER_TITLE` | Later today | 20 |
| `FEED_OPTION_TOMORROW_TITLE` | Tomorrow morning | 20 |
| `FEED_OPTION_SUB` | {ratio} · keep {grams} g | 34 |
| `FEED_EXACT_BTN` | Pick a ratio | 18 |
| `FEED_FIT_TOO_WARM` | Even 1:5:5 will peak early here. A cooler spot fits better. | 60 |
| `FEED_FIT_TOO_COOL` | Even 1:1:1 will peak late here. A warmer spot fits better. | 60 |
| `FEED_FIT_FRIDGE` | It'll barely rise in the fridge. Feed it when it comes out. | 60 |
| `FEED_EARLY_NOTE` | Still rising. Fine to feed, but the next peak comes later. | 60 |
| `FEED_RESCUE_NOTE` | Good call. Fresh food gives it a clean start. | 60 |
| `FEED_ROUTINE_HINT` | Feeding once a day? "Tomorrow morning" fits that rhythm. | 60 |
| `FEED_HOOCH_PROMPT` | Hooch on top. Pour it off, or stir it in? | 60 |
| `FEED_HOOCH_NOTE` | Either is fine. Stirring it in just makes it a bit runnier. | 60 |
| `FEED_HOOCH_POUR` | Pour off | 18 |
| `FEED_HOOCH_STIR` | Stir in | 18 |
| `FEED_STEP_HOOCH` | Hooch | 14 |
| `FEED_STEP_TIMING` | Timing | 14 |
| `FEED_STEP_FLOUR` | Flour | 14 |
| `FEED_STEP_HYDRATION` | Hydration | 14 |
| `FEED_MIX_BTN` | Mix | 18 |
| `FEED_MIX_HOLD` | Hold to mix. | 60 |
| `FEED_SKIP_ANIM_BTN` | Skip | 18 |
| `FEED_DONE_TITLE` | Fed | 26 |

`FEED_ROUTINE_HINT` shows when the last 3 feeds were each at least 20 h apart and the chosen ratio peaks in under 10 h, at most once a week (mechanics §2.2). It describes the feeding rhythm, never how long the player was away.

Scientist v1 (via `game-designer`): feeding before peak dilutes the starter, so the next peak comes later. Stirring hooch in has no acid effect; it only makes the starter a little wetter. Neither label claims a flavor change.

### 7.1 Flours

| Key | Text | Max |
|---|---|---|
| `FLOUR_WHITE_BREAD` | Bread flour | 14 |
| `FLOUR_WHOLE_WHEAT` | Whole wheat | 14 |
| `FLOUR_RYE` | Rye | 14 |
| `FLOUR_SPELT` | Spelt | 14 |
| `FLOUR_WHITE_BREAD_NOTE` | The mildest. A tall, smooth dome. | 60 |
| `FLOUR_WHOLE_WHEAT_NOTE` | Tan and flecked, with a sourer smell. | 60 |
| `FLOUR_RYE_NOTE` | The sourest. A lower rise and a cracked top. | 60 |
| `FLOUR_SPELT_NOTE` | Looser, with a lower, softer dome. | 60 |

Flour notes follow the scientist's v1 flour character (via `game-designer`): white tallest and mildest, whole wheat tan, flecked and sourer, rye sourest with the lowest rise and a cracked or pitted top, spelt looser with a lower dome.

### 7.2 Hydration presets (P1)

Presets from scientist v1: stiff 60%, standard 100%, loose 125%. No speed or flavor claims.

| Key | Text | Max |
|---|---|---|
| `HYDRATION_STIFF` | Stiff | 14 |
| `HYDRATION_STANDARD` | Standard | 14 |
| `HYDRATION_LOOSE` | Loose | 14 |
| `HYDRATION_STIFF_NOTE` | Water at 60% of the flour. Thick and firm. | 60 |
| `HYDRATION_STANDARD_NOTE` | Equal weights of flour and water. The usual. | 60 |
| `HYDRATION_LOOSE_NOTE` | Water at 125% of the flour. Loose and pourable. | 60 |

## 8. Reactions

Toasts after an action. Trait versions are in [`narrative.md`](narrative.md) §7.3.

**Feed result card:** `FORECAST_LINE` (§4), plus the reaction below as an optional second 60-character line (confirmed by ux).

**Feed reaction pick:** fed `at_peak` gives `REACT_FEED_AT_PEAK`. Fed `hungry`, `dormant` or `recovering` gives `REACT_FEED_LATE`. Fed `unhealthy` gives `EVENT_WARNING_SIGNS_OUTCOME_FED`. Otherwise the trait line if revealed, else `REACT_FEED_NEUTRAL_<n>` (§1.4).

| Key | Text | Max |
|---|---|---|
| `REACT_FEED_NEUTRAL_1` | Fed. Flat, smooth and full of possibility. | 60 |
| `REACT_FEED_NEUTRAL_2` | Fresh flour, fresh water. It'll take it from here. | 60 |
| `REACT_FEED_NEUTRAL_3` | Fed. Now the quiet part, where it does all the work. | 60 |
| `REACT_FEED_AT_PEAK` | Fed right at its peak. Nicely timed. | 60 |
| `REACT_FEED_LATE` | Fed. That should perk it up. | 60 |
| `REACT_FRIDGE_OUT_NEUTRAL` | Out of the cold. A feed or two will wake it. | 60 |
| `REACT_MOVE_COUNTER` | Back on the counter. Its usual pace. | 60 |
| `REACT_MOVE_WARM` | Somewhere warmer. A faster rise, and hungry sooner. | 60 |
| `REACT_MOVE_COOL` | A cooler spot. Things will slow down a little. | 60 |
| `REACT_MOVE_PROOFING` | Into the proofing box. Warm and steady. | 60 |

Moving into the fridge is the `off_to_nap` event ([`events-catalog.md`](events-catalog.md) §4.2).

## 9. Forecast windows

`{window}` is picked from the forecast's peak midpoint, in device local time:

| Midpoint | Key |
|---|---|
| Within 90 min of now | `WINDOW_SOON` |
| Today 05:00 to 10:59 | `WINDOW_THIS_MORNING` |
| Today 11:00 to 13:59 | `WINDOW_LUNCHTIME` |
| Today 14:00 to 16:59 | `WINDOW_THIS_AFTERNOON` |
| Today 17:00 to 20:59 | `WINDOW_THIS_EVENING` |
| Today 21:00 to 23:59 | `WINDOW_TONIGHT` |
| Tomorrow 00:00 to 04:59 | `WINDOW_OVERNIGHT` |
| Tomorrow 05:00 to 10:59 | `WINDOW_TOMORROW_MORNING` |
| Tomorrow 11:00 to 13:59 | `WINDOW_TOMORROW_LUNCHTIME` |
| Tomorrow 14:00 to 16:59 | `WINDOW_TOMORROW_AFTERNOON` |
| Tomorrow 17:00 to 23:59 | `WINDOW_TOMORROW_EVENING` |
| Later | `WINDOW_LATER` |

| Key | Text | Max |
|---|---|---|
| `WINDOW_SOON` | within the hour | 18 |
| `WINDOW_THIS_MORNING` | this morning | 18 |
| `WINDOW_LUNCHTIME` | around lunchtime | 18 |
| `WINDOW_THIS_AFTERNOON` | this afternoon | 18 |
| `WINDOW_THIS_EVENING` | this evening | 18 |
| `WINDOW_TONIGHT` | tonight | 18 |
| `WINDOW_OVERNIGHT` | overnight | 18 |
| `WINDOW_TOMORROW_MORNING` | tomorrow morning | 18 |
| `WINDOW_TOMORROW_LUNCHTIME` | tomorrow lunchtime | 18 |
| `WINDOW_TOMORROW_AFTERNOON` | tomorrow afternoon | 18 |
| `WINDOW_TOMORROW_EVENING` | tomorrow evening | 18 |
| `WINDOW_LATER` | in a day or two | 18 |

## 10. While you were away

Heading, then at most 3 moment rows (oldest first), then the "Now" row, which reuses the status word and hint. Event rows are in [`events-catalog.md`](events-catalog.md). These rows cover moments that aren't events.

| Key | Text | Max |
|---|---|---|
| `AWAY_TITLE` | While you were away | 26 |
| `AWAY_TITLE_LONG` | Welcome back | 26 |
| `AWAY_ROSE` | It rose steadily. | 44 |
| `AWAY_FELL` | It fell back after its peak. | 44 |
| `AWAY_FRIDGE` | It rested in the fridge. Barely a bubble. | 44 |
| `AWAY_RAN_DOWN` | It ran low and went quiet. | 44 |
| `AWAY_RECOVERING` | It's still getting its strength back. | 44 |
| `AWAY_QUIET` | A quiet stretch. Not much changed. | 44 |
| `AWAY_LONG_REST` | A long rest. It mostly just waited. | 44 |
| `AWAY_CAPPED` | After two weeks, it held still until now. | 44 |

`AWAY_TITLE_LONG` replaces the heading after 3 days or more away. It says hello, not how long.

`AWAY_CAPPED` is the D-024 line for an absence longer than 14 days. Show it when `CatchUpResult.capped` is true. It is always kept, as the last moment row before "Now", because the hold comes after everything else that happened. It tells the player the starter stopped changing at the 14-day cap (architecture §5.1) without counting the days or scolding. If the cap ever changes, "two weeks" changes with it.

## 11. Journal

The P0 journal is a read-only log (progression §7). Log lines use the toast length.

| Key | Text | Max |
|---|---|---|
| `JOURNAL_SCREEN_TITLE` | Journal | 26 |
| `JOURNAL_CHAPTER_SINCE` | Since {start_date} | 34 |
| `JOURNAL_LOG_FEED` | Fed {ratio}, {flour}. Kept {grams} g. | 60 |
| `JOURNAL_LOG_FEED_AT_PEAK` | Fed at its peak. {ratio}, {flour}. | 60 |
| `JOURNAL_LOG_FEED_RESCUE` | Fed through the warning signs. | 60 |
| `JOURNAL_LOG_SMELL` | Smell: {smell}. | 60 |
| `JOURNAL_LOG_HOOCH_POURED` | Poured off the hooch. | 60 |
| `JOURNAL_LOG_HOOCH_STIRRED` | Stirred the hooch back in. | 60 |
| `JOURNAL_LOG_MOVE_COUNTER` | Moved to the counter. | 60 |
| `JOURNAL_LOG_MOVE_WARM_SPOT` | Moved to the warm spot. | 60 |
| `JOURNAL_LOG_MOVE_WINDOW_SILL` | Moved to the window sill. | 60 |
| `JOURNAL_LOG_MOVE_PROOFING_BOX` | Into the proofing box. | 60 |
| `JOURNAL_LOG_MOVE_FRIDGE` | Moved to the fridge. | 60 |
| `JOURNAL_LOG_RENAME` | Renamed to {name}. | 60 |
| `JOURNAL_EMPTY_TITLE` | Nothing yet | 26 |
| `JOURNAL_EMPTY_BODY` | Notes appear here as it rises, falls and gets fed. | 90 |
| `JOURNAL_RENAME_BTN` | Rename | 18 |
| `JOURNAL_RENAME_TITLE` | A new name | 26 |

Peak log lines reuse `EVENT_PEAKED_WHILE_AWAY_AWAY_*`.

Move lines are `JOURNAL_LOG_MOVE_<LOCATION>`, one per location id. When a fridge move also fires `off_to_nap`, the event's journal entry tells the story, so skip the move line for that action. Otherwise (the event's 24 h cooldown) the move line logs it.

The inspect log line is the observation the player just read, `INSPECT_<KIND>_<STATE>_OBS` from §6 (at most 90, within the 200 journal body). It needs no key of its own. Logged once per observation per rise cycle (data-models §6).

Journal args use the §1.3 placeholder names. `JOURNAL_LOG_FEED` needs `ratio`, `flour` (the flour's display name, `FLOUR_<ID>`) and `grams` (grams kept). `JOURNAL_LOG_FEED_AT_PEAK` needs `ratio` and `flour`. `JOURNAL_LOG_SMELL` needs `smell` (the descriptor's `SMELL_<ID>_TITLE`).

## 12. Glossary

Shown the first time a term appears (coach mark or tap), per [`narrative.md`](narrative.md) §4.5.

| Key | Text | Max |
|---|---|---|
| `GLOSS_STARTER` | Starter: flour and water, alive with wild yeast and bacteria. It raises sourdough bread. | 90 |
| `GLOSS_FEED` | Feed: fresh flour and water, so it has food again. | 90 |
| `GLOSS_DISCARD` | Discard: the part you take out before feeding, so the jar doesn't overflow. | 90 |
| `GLOSS_PEAK` | Peak: its tallest point after a feed, just before it falls. | 90 |
| `GLOSS_HOOCH` | Hooch: liquid on top, gray to brown, sometimes black. A sign it's hungry. | 90 |
| `GLOSS_RATIO` | Ratio: starter, flour and water by weight. 1:1:1 means equal parts. | 90 |
| `GLOSS_HYDRATION` | Hydration: water divided by flour, times 100. Equal weights make 100%. | 90 |
| `GLOSS_RUBBER_BAND` | The rubber band marks where it started after a feed. Bakers really do this. | 90 |

## 13. Place sheet

Locations follow mechanics §3.1. Containers are P2, so their names are listed with no notes. Covers moved to P2 with a fixed `loose_lid` (scientist v1, via `game-designer`), so there is no cover copy yet.

| Key | Text | Max |
|---|---|---|
| `PLACE_TITLE` | Where it lives | 26 |
| `PLACE_TEMP_LABEL` | Temperature | 24 |
| `PLACE_DIAL_LABEL` | Warmth | 24 |
| `LOC_COUNTER` | Counter | 14 |
| `LOC_COUNTER_SUB` | Usual pace | 14 |
| `LOC_WARM_SPOT` | Warm spot | 14 |
| `LOC_WARM_SPOT_SUB` | Faster rise | 14 |
| `LOC_WINDOW_SILL` | Window sill | 14 |
| `LOC_WINDOW_SILL_SUB` | Slower rise | 14 |
| `LOC_FRIDGE` | Fridge | 14 |
| `LOC_FRIDGE_SUB` | A long pause | 14 |
| `LOC_PROOFING_BOX` | Proofing box | 14 |
| `LOC_PROOFING_BOX_SUB` | You set it | 14 |
| `CONTAINER_CLASSIC_JAR` | Classic jar | 14 |
| `CONTAINER_WIDE_MOUTH_JAR` | Wide-mouth jar | 14 |
| `CONTAINER_CERAMIC_CROCK` | Ceramic crock | 14 |
| `CONTAINER_FERMENTATION_VESSEL` | Fermenter | 14 |

## 14. Milestones, unlocks, achievements

### 14.1 Milestones

Ids from [`progression.md`](progression.md) §4. A milestone that fires with an event shows the event and writes no extra entry: `first_rise`, `first_hooch`, `first_nap`, `first_wake`, `comeback`, `trait_revealed`. `named` uses `NAME_DONE_TOAST`, and `memorial` is in [`narrative.md`](narrative.md) §9. If `first_peak` coincides with `peak_now`, the event toast shows and the milestone is journal-only.

| Key | Text | Max |
|---|---|---|
| `MILESTONE_NAMED_TITLE` | Named | 26 |
| `MILESTONE_NAMED_BODY` | It answers to {name} now. Well, it doesn't answer. But it's a good name. | 200 |
| `MILESTONE_FIRST_FEED_TITLE` | First feed | 26 |
| `MILESTONE_FIRST_FEED_BODY` | The first feed on the real clock: {ratio}, {flour}. From here on, it runs on its own time. | 200 |
| `MILESTONE_FIRST_PEAK_TOAST` | Its first peak with you. Domed and very pleased. | 60 |
| `MILESTONE_FIRST_PEAK_TITLE` | First peak | 26 |
| `MILESTONE_FIRST_PEAK_BODY` | The first peak on the real clock, seen or not. Peak is its tallest point, and the best moment to feed it or bake with it. | 200 |
| `MILESTONE_FIRST_DOUBLE_TOAST` | It doubled. Bakers love to see that. | 60 |
| `MILESTONE_FIRST_DOUBLE_TITLE` | Doubled | 26 |
| `MILESTONE_FIRST_DOUBLE_BODY` | It doubled its height after a feed for the first time. Many bakers use doubling as their sign that a starter is ready to bake with. | 200 |
| `MILESTONE_RESCUED_TOAST` | Out of the woods. The warning signs are gone. | 60 |
| `MILESTONE_RESCUED_TITLE` | Rescued | 26 |
| `MILESTONE_RESCUED_BODY` | Warning signs, then a feed, and it pulled through. Worth remembering: musty and flat means look closely, then feed. | 200 |
| `MILESTONE_NOSE_FOR_IT_TOAST` | Four smells and counting. You've got a nose for this. | 60 |
| `MILESTONE_NOSE_FOR_IT_TITLE` | A nose for it | 26 |
| `MILESTONE_NOSE_FOR_IT_BODY` | Four different smells so far. Smell is the quickest way to read a starter, and you're getting good at it. | 200 |
| `MILESTONE_STAGE_STEADY_TOAST` | Stronger now. It has come into its own. | 60 |
| `MILESTONE_STAGE_STEADY_TITLE` | Steady | 26 |
| `MILESTONE_STAGE_STEADY_BODY` | It rises higher and sooner now than the young thing M. left behind. A steady starter. | 200 |
| `MILESTONE_STAGE_MATURE_TOAST` | Ready to bake. It doubles reliably now. | 60 |
| `MILESTONE_STAGE_MATURE_TITLE` | Ready to bake | 26 |
| `MILESTONE_STAGE_MATURE_BODY` | A mature starter: it doubles reliably and bounces back well. Strong enough to raise a loaf. M. would be pleased. | 200 |
| `MILESTONE_STAGE_SEASONED_TOAST` | Seasoned. It has seen a few things. | 60 |
| `MILESTONE_STAGE_SEASONED_TITLE` | Seasoned | 26 |
| `MILESTONE_STAGE_SEASONED_BODY` | Robust, reliable and hard to rattle. This is the kind of starter people hand down. | 200 |
| `MILESTONE_ONE_WEEK_TOAST` | One week together. | 60 |
| `MILESTONE_ONE_WEEK_TITLE` | One week | 26 |
| `MILESTONE_ONE_WEEK_BODY` | A week of rising and falling. It has settled into your kitchen, and you've settled into its rhythm. | 200 |
| `MILESTONE_ONE_MONTH_TOAST` | One month together. A proper partnership. | 60 |
| `MILESTONE_ONE_MONTH_TITLE` | One month | 26 |
| `MILESTONE_ONE_MONTH_BODY` | A month in. Plenty of feeds, plenty of peaks, and a jar that smells like home. | 200 |
| `MILESTONE_FLOUR_WHOLE_WHEAT_TOAST` | First whole wheat feed. Notice the flecks? | 60 |
| `MILESTONE_FLOUR_WHOLE_WHEAT_TITLE` | Whole wheat | 26 |
| `MILESTONE_FLOUR_WHOLE_WHEAT_BODY` | Fed with whole wheat for the first time. It turns the starter tan and flecked, and a little sourer than white flour. | 200 |
| `MILESTONE_FLOUR_RYE_TOAST` | First rye feed. Expect it sourer, and a bit lower. | 60 |
| `MILESTONE_FLOUR_RYE_TITLE` | Rye | 26 |
| `MILESTONE_FLOUR_RYE_BODY` | Fed with rye for the first time. Rye makes the sourest starter of all, with a lower rise and a cracked, pitted top. | 200 |
| `MILESTONE_FLOUR_SPELT_TOAST` | First spelt feed. Looser, with a softer dome. | 60 |
| `MILESTONE_FLOUR_SPELT_TITLE` | Spelt | 26 |
| `MILESTONE_FLOUR_SPELT_BODY` | Fed with spelt for the first time. Spelt is an old relative of wheat. It makes a looser starter with a lower dome. | 200 |

### 14.2 Unlock intros

One toast and one journal entry each (progression §3).

| Key | Text | Max |
|---|---|---|
| `UNLOCK_WHOLE_WHEAT_TOAST` | New in the pantry: whole wheat flour. | 60 |
| `UNLOCK_WHOLE_WHEAT_BODY` | Whole wheat is in the pantry now. Pick it in the feed sheet to see how it changes things. | 200 |
| `UNLOCK_WINDOW_SILL_TOAST` | New spot: the window sill. Cooler, slower. | 60 |
| `UNLOCK_WINDOW_SILL_BODY` | The window sill is a few degrees cooler than the counter. A slower rise suits a once-a-day feed. | 200 |
| `UNLOCK_RYE_TOAST` | New in the pantry: rye flour. | 60 |
| `UNLOCK_RYE_BODY` | Rye is in the pantry now. Try it in the feed sheet. | 200 |
| `UNLOCK_HYDRATION_TOAST` | New: stiffer or looser feeds. | 60 |
| `UNLOCK_HYDRATION_BODY` | You can now change how much water goes in. Stiff, standard or loose. Standard is equal weights of flour and water. | 200 |
| `UNLOCK_INSPECT_TOAST` | Two new things to inspect: Consistency and Development. | 60 |
| `UNLOCK_INSPECT_BODY` | It's steady enough now to show more. Consistency shows how strong it is. Development shows how far it has come. | 200 |
| `UNLOCK_SPELT_TOAST` | New in the pantry: spelt flour. | 60 |
| `UNLOCK_SPELT_BODY` | Spelt is in the pantry now. Try it in the feed sheet. | 200 |
| `UNLOCK_PROOFING_BOX_TOAST` | New spot: a proofing box. You set the warmth. | 60 |
| `UNLOCK_PROOFING_BOX_BODY` | A proofing box holds a steady warmth you choose, from 24 to 30 °C. Handy for timing a peak just so. | 200 |

### 14.3 Achievements (P2)

Quiet, on the journal's back page only (progression §6).

| Key | Text | Max |
|---|---|---|
| `ACH_PEAK_WATCHER_TITLE` | Peak watcher | 26 |
| `ACH_PEAK_WATCHER_BODY` | Looked in at its peak 5 times. | 90 |
| `ACH_FULL_NOSE_TITLE` | Full nose | 26 |
| `ACH_FULL_NOSE_BODY` | Smelled every stage of a healthy rise and fall. | 90 |
| `ACH_FLOUR_TOUR_TITLE` | Flour tour | 26 |
| `ACH_FLOUR_TOUR_BODY` | Fed it all four flours. | 90 |
| `ACH_GOOD_TIMING_TITLE` | Good timing | 26 |
| `ACH_GOOD_TIMING_BODY` | Fed it at or just after its peak 10 times. | 90 |
| `ACH_DEEP_SLEEPER_TITLE` | Deep sleeper | 26 |
| `ACH_DEEP_SLEEPER_BODY` | Woke a starter after two weeks or more in the fridge. | 90 |
| `ACH_RESCUER_TITLE` | Rescuer | 26 |
| `ACH_RESCUER_BODY` | Brought a starter back from warning signs. | 90 |
| `ACH_LONG_HAUL_TITLE` | The long haul | 26 |
| `ACH_LONG_HAUL_BODY` | 100 days with the same starter. | 90 |

## 15. Notifications (after the vertical slice)

Local only, opt-in, outside quiet hours (D-007, game-design OD-1). No guilt, no counting. **No notification about mold**: nothing about it is urgent, and the sheet waits for the player.

| Key | Text | Max |
|---|---|---|
| `NOTIF_PEAK_SOON_TITLE` | Nearly at its peak | 30 |
| `NOTIF_PEAK_SOON_BODY` | {name} should peak soon. A good time to feed it. | 90 |
| `NOTIF_HUNGRY_TITLE` | Ready for a feed | 30 |
| `NOTIF_HUNGRY_BODY` | {name} has eaten everything. Feed it whenever suits you. | 90 |
| `NOTIF_WARNING_TITLE` | Warning signs | 30 |
| `NOTIF_WARNING_BODY` | Away? That's OK. {name} is showing warning signs. A feed soon turns it around. | 90 |

## 16. Copy check

[`tools/i18n/check_copy.py`](../tools/i18n/check_copy.py) checks every `Key | Text | Max` row in the three narrative docs. It is the build gate for the generated `en.csv` (ADR-014, D-028). Run it from the repo root: `python3 -I tools/i18n/check_copy.py .`. Exit 0 means clean.

| Check | Rule |
|---|---|
| Length | Text with every placeholder at its worst case (§1.3) is within `Max`. |
| Unique keys | No key appears twice across the three docs. |
| Key format | `^[A-Z][A-Z0-9_]*$` |
| No em dashes | In any line of the three docs. |
| Banned words | [`narrative.md`](narrative.md) §4.4, case-insensitive, whole words. |
| No exclamation marks | In any string except `MILESTONE_*` and `ACH_*`. |
| Smell variants | Each of the 10 descriptors has `_1` to `_3`, `_TITLE`, `_NOTE` and `_MEANING`. |
| Status coverage | Every state id in vision.md has `_WORD`, `_HINT` and `_TAP` (`dormant` twice). |
| Pending CSVs | Every row in `src/i18n/pending_*.csv` (header `keys,en`) gets the key format, placeholder, banned-word, exclamation, em dash and safety checks, but no length check (no `Max`). A pending key that is also in the docs or `en.csv`, or in two pending files, is an error (LINT-11). |

It also runs `qa-engineer`'s LINT-06 word lists, mapped to the real key prefixes (safety: `STATUS_MOLDY`, `STATUS_UNHEALTHY`, `SMELL_MUSTY`, `SMELL_MOLDY`, `INSPECT_*_MOLDY*`, `INSPECT_*_UNHEALTHY*`, `INSPECT_SURFACE_HOOCH_DARK`, `EVENT_WARNING_SIGNS`, `EVENT_MOLD_FOUND`, `MOLD_`, `MEMORIAL_`, `NOTIF_WARNING`, `REASON_MOLDY`, `REASON_NOT_MOLDY`; hunger: `STATUS_HUNGRY`, `STATUS_DORMANT_STARVED`, `SMELL_ACETONE`, `SMELL_ALCOHOL`, `SMELL_STRONGLY_ACIDIC`, `EVENT_HOOCH_FORMING`, `EVENT_HUNGRY_AGAIN`, `EVENT_FIRST_ACETONE`, `INSPECT_SURFACE_HOOCH`, `INSPECT_*_HUNGRY*`, `FEED_HOOCH`, `GLOSS_HOOCH`). Every moldy *message* (`STATUS_MOLDY_HINT` and `_TAP`, `SMELL_MOLDY_BODY`, `INSPECT_*MOLDY*_MEAN`, `MOLD_SHEET_BODY*`, `MOLD_FEED_BLOCKED`, `REASON_MOLDY_LOCKED`) must contain "discard". Titles, status words, observations and buttons are exempt because they always appear beside one of those.

**Last run, 2026-11-26:** `python3 -I tools/i18n/check_copy.py .` over 614 strings (narrative 123, events 69, game copy 422). First run found 3 over-length strings, all fixed. Second run: 0 problems. After the scientist's wave B review (21 fixes, 3 strings removed, 6 added, net 612 strings), the run still finds 0 problems. It also confirmed the smell rule shows all 3 variants within 300 feeds and never repeats a line on consecutive cycles. Phase 2, 2026-11-26: after adding `AWAY_CAPPED`, the checker reports 613 strings (narrative 123, events 68, game copy 422) and 0 problems, and `build_catalog.py` writes all 613 to `en.csv`. The T1 copy pass added the 13 `REASON_*` lines (§3.1), `JOURNAL_LOG_MOVE_FRIDGE` and `JOURNAL_LOG_RENAME`: 628 strings. The T3 copy pass added 12 UI keys (§2, §3.2, §6): 640 strings. The checker now also lints `pending_*.csv`.
