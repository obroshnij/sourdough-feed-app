# UX design

Owner: `ux-designer`. Status: Phase 1, wave A draft (2026-11-26).

This document covers the portrait, one-handed mobile experience: screens, layout, gestures, flows, motion, accessibility, the components for the Godot Theme, and the copy slots.

Inputs used:
- `docs/vision.md` and `docs/decisions.md`.
- game-designer's flow message (feed, environment, events and return).
- sourdough-scientist's state table draft v0 (precedence, cues and durations).
- The Godot 4.7.2 touch facts from the director's source review, which godot-developer confirms in the spike.

Anything marked **[assumed]** waits on a teammate or the spike.

All sizes are in **pt**: 1 UI unit = 1 iOS point = 1 Android dp (see §19).

---

## 1. Principles

1. **The jar is the screen.** The 3D jar gets at least 55% of the height on the smallest phone at the largest text size, and about 65% at the default size. UI floats on plates around it. Nothing sits on top of the starter.
2. **Read the jar, not a meter.** The main screen shows one status word with an icon and one plain hint. It never shows digits, bars, charts or percentages. Numbers live in the feed sheet, environment sheet and journal details.
3. **One thumb, two taps.** Frequent actions sit in the bottom thumb zone. Checking the starter takes 0 taps, and feeding like last time takes 2 (§7).
4. **One thing at a time.** At most one sheet, one card and one toast are visible. An open sheet owns the screen: the 3D view ignores touches, and events wait.
5. **Gestures are a bonus, never a requirement.** Orbit, zoom and pokes are delight. Every piece of information they reveal can also be reached with a button.
6. **Calm, then clear.** Normal hunger, hooch and sharp smells use calm tones and calm words. Only `unhealthy` and `moldy` get the warning and stop tiers, and they say plainly what to do.
7. **Teach in place.** The first time each state, smell or inspection appears, the game explains it right where it happens: the status pill explainer, a coach mark or a "show me" camera move. There is no manual.

### Anti-patterns we avoid

| Never | Instead |
|---|---|
| Meters, gauges, percentages or countdown timers on the main screen | Status word, icon, hint and the jar's look |
| Red badges, flashing alerts, guilt copy ("You neglected…") | One calm card, worded as an invitation |
| Status shown by color alone | Icon shape + word + color (§11) |
| Modal stacks (a sheet over a sheet, a dialog over a sheet) | One sheet. Confirmations replace the sheet's content |
| Hidden gestures as the only way to do something (long-press, swipe, shake) | A visible button for every action. Gestures are shortcuts |
| Events interrupting a sheet, a feed or the smell moment | Queue until the main screen is idle (§12) |
| Default Godot controls | Everything is themed (§17) |
| Text placed straight on the 3D scene | Text sits on a plate at least 88% opaque (§16) |
| Timed messages the player can't hold | A setting that keeps messages until tapped |

---

## 2. Devices, safe areas and the stage

| Device | Size (pt) | Safe top / bottom | Notes |
|---|---|---|---|
| Android compact (smallest width) | 360 × 640 | status bar / nav bar (see below) | Copy limits are computed at this width |
| iPhone SE (2nd, 3rd gen) | 375 × 667 | 20 / 0 | Supported by iOS 27. Home button, square corners |
| iPhone 17e | 390 × 844 **[assumed]** | 47 / 34 **[assumed]** | Same chrome and corner radius (47.33) as the 16e in the Xcode 27.2 simulator profiles. Verify with the Phase 2 simulator check |
| iPhone 17 Pro | 402 × 874 | 62 / 34 | Corner radius 62 |
| iPhone 17 Pro Max (largest) | 440 × 956 | 62 / 34 | Corner radius 62 |
| Android, gesture navigation | varies | reported / max(reported, 24) | Edge-to-edge is forced on Android 15+ at target SDK 35 |
| Android, 3-button navigation | varies | reported / max(reported, 48) | |

**Insets (QA checks these):**
- HUD plate top = safe top + 8.
- Action bar plate bottom = safe bottom + 8.
- Side gutters are 16, plus any side safe-area inset.

Minimum bottom inset for the action bar:

| Device | Bottom inset |
|---|---|
| iPhone SE | 8 |
| iPhone 17e, 17 Pro, 17 Pro Max | 42 |
| Android, gesture navigation | 32 dp |
| Android, 3-button navigation | 56 dp |

Godot's `DisplayServer.get_display_safe_area()` may report only the Android status bar, not the navigation bar (forum reports). That's why the Android bottom values above are floors. godot-developer verifies this in the spike.

**Stage budget at 100% text** (jar region = space between the HUD plate and the action bar):

| Device | HUD ends at | Bar top at | Jar region |
|---|---|---|---|
| iPhone SE | 28 + 134 = 162 | 667 − 8 − 72 = 587 | 425 pt (64%) |
| iPhone 17 Pro Max | 70 + 134 = 204 | 956 − 42 − 72 = 842 | 638 pt (67%) |

At 150% text, the HUD plate grows to 189, and the SE jar region drops to 370 pt (55%).

The camera frames the jar to the jar region, not to the full screen. It shifts the frustum so the jar is centered between the HUD and the bar.

---

## 3. Screen map

| Screen | Type | Reached by | Dismissed by | 3D input |
|---|---|---|---|---|
| Main | Base | App launch | n/a | On |
| Feed | Half sheet (about 60%) | `feed` button; "Feed now" on a card or sheet | Mix (plays sequence), swipe down, tap above, Close | Off (jar visible above) |
| Smell result | Card above bar | `smell` button → smell moment (§9) | Tap anywhere, any action button, swipe down | On after the moment |
| Inspect | Peek sheet (about 42%) | `inspect` button; "Show me" in explainers | Swipe down, tap above, Done | Off (camera driven) |
| Environment | Peek sheet (about 45%) | `environment` button | Swipe down, tap above, Done | Off |
| Journal | Full sheet (screen − safe top − 12) | `journal` button | Swipe down on header, Close, Done | Off |
| Status explainer | Card above bar | Tap the status pill | Tap anywhere, swipe down | On |
| Settings | Full sheet | Gear button (HUD, top right) | Swipe down on header, Close | Off |
| Onboarding | In-world sequence + coach marks | First launch; Settings → Replay tutorial | Completes itself | Guided |
| While you were away | Time-lapse takeover → summary card | Return after ≥ 60 min with a change (game-designer) | Tap to skip; card: Got it, or any action | Off during the time-lapse |
| Event: `info` | Toast (top, under the HUD) | Event queue | Auto (§12), tap, swipe up | On |
| Event: `nudge` | Card above bar | Event queue | Its buttons, swipe down, any action | On |
| Event: `attention` | Half sheet | Event queue | Its buttons; a Close X only when closing is safe | Off |
| Confirmation | Replaces the current sheet's content | Erase data, discard a moldy starter | Its 2 buttons | Off |

Sheet heights are a share of the screen height, clamped so the jar's top half stays visible: the sheet's top edge is never above 40% of the screen height. The exceptions are full sheets (journal, settings).

---

## 4. Main screen layout

Shown on a 375 × 667 iPhone SE at 100% text. On larger phones the same structure grows, and the extra height goes to the jar.

```
 0 ┌─────────────────────────────────────┐
   │ 9:41                        ▮▮▮ ◔   │  status bar (safe top 20)
28 │ ╭─────────────────────────────────╮ │  HUD plate: surface at 88%, radius 24
   │ │ Bramble                     (⚙) │ │  row 1: name (20 semibold) + settings, 48 pt circle
   │ │ ╭──────────────╮                │ │
   │ │ │ ◠⋆ At peak    │               │ │  row 2: status pill, icon 24 + word 17 semibold
   │ │ ╰──────────────╯                │ │         tone border 2 pt. Tap → explainer
   │ │ At its best right now.          │ │  row 3: hint (16, ink_muted), 1 line, 2 at 150%
162│ ╰─────────────────────────────────╯ │
   │              (toast slot)           │  toasts drop in here, under the plate
   │                                     │
   │              ╭───────╮              │
   │             ╱  ○ ° ○  ╲             │
   │            │ ° dome ° ○│            │  THE JAR (3D), jar region 425 pt
   │            │  ○  °  ○  │            │  rubber band at the fed mark
   │            │═══════════│ ← band     │  tap starter = poke · tap glass = tink
   │            │           │            │  drag = orbit · pinch = zoom · double-tap = reset
   │            ╰───────────╯            │
   │                                     │
   │        (card slot: nudge, smell,    │  cards rise from here, above the bar
   │         explainer, away summary)    │
587│ ╭─────────────────────────────────╮ │  action bar plate: surface at 88%, radius 28, height 72
   │ │ Feed  Smell Inspect Place Journal│ │  5 × 67 pt slots, icon 28 + label 14 semibold
659│ ╰─────────────────────────────────╯ │  bottom = safe bottom + 8
667└─────────────────────────────────────┘
```

- **Top (read-mostly).** Name, status and hint, plus settings. The plate hugs the full width so the hint gets 296 pt of line. There's no profile button: the game has no accounts.
- **Center.** The jar, and nothing else. The idle camera shows the jar at a slight 3/4 angle with the fed-mark band visible. **[assumed]** The rubber band at the fed mark (§11) depends on art-director.
- **Bottom.** Five actions in canonical order: `feed`, `smell`, `inspect`, `environment`, `journal`. The `environment` label is "Place" (narrative-designer), because "Environment" measures 82 pt and a slot holds 64. Its sheet is titled "Where it lives".
- **Feed emphasis.** When the state is `hungry` or `collapsing`, the Feed button gets a soft halo ring plus a 10 pt dot badge (a shape, not just color), and the hint says why. No other button ever gets a badge.
- **`moldy`.** Feed, Smell and Inspect stay visible. Feed is disabled with a reason ("Can't feed a moldy starter"), and the attention sheet leads to the discard ceremony (§12).
- **No digits rule.** The main screen and its toasts and cards show no digits, except in a name the player typed. Times are fuzzy words ("in a few hours", "around lunchtime"). QA can test this by scanning visible strings.

---

## 5. One-handed reach map

These zones are approximate, after Hoober's thumb-reach observations: 49% of people touched their phones one-handed, so we design for that first. They aren't measured by us. The drawing assumes a right thumb, with the hand gripping the lower half. Mirror it for left hands. The layout is symmetric where it matters.

Legend: E = easy, S = stretch, H = hard.

```
iPhone SE 375 × 667                      iPhone 17 Pro Max 440 × 956
 y    L ─────────────── R                  y    L ──────────────────── R
   0  H  H  H  S  S  S   HUD name / ⚙         0  H  H  H  H  H  H  H   island, HUD
 111  H  S  S  S  S  S   HUD status          160  H  H  H  H  H  S  S   HUD status / hint
 222  S  S  E  E  E  S   jar top             320  H  H  S  S  S  S  S   toast slot
 333  S  E  E  E  E  E   jar                 480  S  S  S  E  E  E  S   jar
 444  S  E  E  E  E  S   card slot           640  S  S  E  E  E  E  S   card slot
 556  S  E  E  E  E  S   sheet buttons       800  S  E  E  E  E  S  S   sheet buttons
 611  S  S  E  E  S  S   action bar          880  S  S  E  E  E  S  S   action bar
```

| Zone | What lives there | Rule |
|---|---|---|
| H | Name, status, hint, settings, toasts, sheet Close X | Read-only or rare. Every Close X has a twin in the E zone (swipe down or tap above) or at the bottom (Done) |
| S | The jar's upper body, the card body | Nothing that must be tapped often |
| E | Action bar, sheet primary buttons, card buttons, chips | All frequent taps. Primary buttons are pinned to the sheet bottom, never the top |

On the Pro Max, the far-left bar slot (Feed) falls in S for a right thumb. That's acceptable: it's a 67 × 72 pt target, and canonical order puts Feed first. A left-handed mirror setting is an open decision, not in scope.

---

## 6. Gestures and touch routing

### Gesture map (main screen only, no sheet open)

| Gesture | Where it starts | Result | Haptic |
|---|---|---|---|
| Tap | Starter surface | Poke: the starter wobbles, 1 to 3 small bubbles pop, the status pill pulses once. Never changes the sim | light |
| Tap | Glass | "Tink" sound, a ring ripple on the glass, the starter quivers | light |
| Tap | Status pill | Status explainer card | light |
| Double-tap | Anywhere in 3D | Camera resets to home over 350 ms. The first tap's poke still plays, so we don't delay single taps | none |
| One-finger drag | Anywhere in 3D | Orbit: yaw 0.30°/pt, pitch 0.20°/pt | none |
| Two-finger pinch | Both fingers in 3D | Zoom toward the jar center | light tick at each limit |
| Long-press (500 ms) | Action bar button | Large label popup (200% size) for low vision | light |
| Swipe down | Sheet header or grabber | Close the sheet | none |
| Tap | Scrim above a sheet | Close the sheet. Not during the feed sequence or on attention sheets | none |

### Thresholds (QA)

| Value | Number |
|---|---|
| Tap slop (move before a tap becomes a drag) | 10 pt (20 px at 2x, 30 px at 3x) |
| Double-tap window | 300 ms between taps, at most 24 pt apart |
| Long-press | 500 ms, within the 10 pt slop |
| Orbit yaw | ±70° from the front, with an 8° rubber band. Unlimited if art-director's set reads well at 360° (open) |
| Orbit pitch | −10° to +35°, with a 5° rubber band |
| Zoom | 1.0× (home distance) to 2.2× (home distance ÷ 2.2), with an 8% rubber band |
| Orbit inertia | exponential decay, τ = 250 ms. Off with reduce motion |
| Idle return | after 20 s with no touch, the camera eases home over 1,500 ms. Off with reduce motion |
| Sheet swipe dismiss | 25% of the sheet height or 700 pt/s |

### Routing rules (Godot 4.7.2)

These come from the director's source review. godot-developer confirms them in the spike.

1. **A touch belongs to the Control it started on for the whole drag.** A drag that starts on the jar and slides over the action bar keeps orbiting. A drag that starts on a bar button never orbits, and it cancels the button press when it leaves the button by more than 10 pt.
2. **Full-screen layout Controls use `mouse_filter = IGNORE`** (roots, margin containers, the HUD layer). The top HUD plate is also `IGNORE`, so a drag that starts on it orbits. Only the settings button and the status pill inside it are `STOP`. The action bar plate, sheets, cards, toasts and scrims use `STOP`, so a near-miss between bar buttons never turns into a poke or an orbit. The 3D rig reads only touches no Control consumed, in `_unhandled_input` (architecture.md §9).
3. **An open sheet blocks the 3D view.** Its scrim covers the whole screen above the sheet with `STOP`. A tap on the scrim closes the sheet, and a drag on it does nothing.
4. **iOS sends no pinch event, so we build pinch ourselves** from `InputEventScreenTouch` and `InputEventScreenDrag` indices, on both platforms. Pinch counts only when both touches started in 3D. A second finger landing on a plate is ignored.
5. **Cards and toasts don't block 3D** outside their own rect.

---

## 7. Tap budgets

Counted from the main screen being visible. App-icon taps aren't counted. QA asserts each budget.

| Task | Path | Taps | Budget |
|---|---|---|---|
| Check the starter's condition | Open the app. Status, hint and jar are on screen | 0 | 0 |
| Understand the status | Status pill → explainer | 1 | 1 |
| **Feed like last time** | Feed → Mix ("Mix like last time") | **2** | **3** |
| Feed like last time after a return | Skip the time-lapse → Feed → Mix | 3 | 3 |
| Feed from an attention or nudge | (Skip) → Feed now → Mix | 3 | 3 |
| Feed with a different ratio | Feed → ratio option → Mix | 3 | 4 |
| Feed with a different ratio and flour | Feed → ratio → flour → Mix | 4 | 4 |
| Smell | Smell (the result card appears by itself) | 1 | 1 |
| Inspect one kind | Inspect → chip | 2 | 2 |
| Move to the fridge | Place → Fridge (applies instantly) → Done or tap above | 3 | 3 |
| Read the journal | Journal | 1 | 1 |
| Change text size | ⚙ → Large | 2 | 2 |

Tap 3 is spare on the common path on purpose. It absorbs the time-lapse skip on returns.

---

## 8. Feed flow

The rules follow game-designer:
- Ratio is the decision, and discard is derived. The total after feeding is a fixed target of about 150 g.
- The MVP has single flours only.
- Hydration is P1 with 3 presets. The vertical slice is fixed at 100%.
- An optional hooch step appears when hooch is present.
- The first feed happens in onboarding.

### Feed sheet (half sheet). It opens with last time's choices already selected.

```
┌─────────────────────────────────────┐
│ ▬▬ grabber                          │
│ Feed                            (✕) │  title 20 semibold; ✕ is 48 pt
│ ┌ Hooch on top ───────────────────┐ │  only when hooch is present
│ │ ( Pour off ✓ )  ( Stir in )     │ │  preselected: last choice, else Pour off. No flavor qualifiers:
│ │                                 │ │  stirring in only makes it a bit wetter (scientist v1)
│ └─────────────────────────────────┘ │
│ When will you check on it next?     │  section label 16 semibold
│ ┌─────────────────────────────────┐ │
│ │ ◉ Soon, a few hours        ✓    │ │  ratio option rows, 64 pt minimum
│ │   1:1:1 · keep 50 g             │ │  sub-line: ratio and grams (digits OK here)
│ ├─────────────────────────────────┤ │
│ │ ○ Later today                   │ │
│ │   1:2:2 · keep 30 g             │ │
│ ├─────────────────────────────────┤ │
│ │ ○ Tomorrow                      │ │
│ │   1:5:5 · keep 14 g             │ │
│ └─────────────────────────────────┘ │
│ Flour  ( White bread ✓ ) ( Whole wheat ) │  chips, unlocked flours only
│ Water  ( Stiff ) ( Standard ✓ ) ( Loose ) │  P1: 60 / 100 / 125%. Hidden in the vertical slice (fixed 100%)
│ ⓘ It hasn't peaked yet. Feeding now is fine. │  optional one-line note, never a block
│           ✓ Same as last time       │  reassurance line; hidden once anything changes
│ ┌─────────────────────────────────┐ │
│ │               Mix               │ │  primary, 56 pt, pinned to the sheet bottom
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

- **Smart defaults.** Every control opens on last time's value, so "feed like last time" is Feed → Mix. There's no separate repeat button: it would be a third control saying the same thing. A "✓ Same as last time" line (narrative-designer's copy) sits right above Mix. It uses a shape, not just color, and hides once anything changes. The very first feed after onboarding uses onboarding's choices.
- **The jar above previews the choice.** When the player picks a ratio, a ghost line shows where the band will land after discarding. The camera frames the jar mouth in the 40% above the sheet.
- **Mix is a plain tap.** We never require a hold, for motor accessibility. game-designer asked for this.
- **Tactile sequence after Mix.** The sheet slides down. From the second feed on, a "Skip" pill appears, and tapping anywhere skips to the end. The final haptic still plays. The first feed always plays in full, because it teaches the steps (game-mechanics §2.6).

| # | Beat | Duration | Feel | Haptic |
|---|---|---|---|---|
| 1 | Hooch: pour off or stir in (only if present) | 0.6 s | thin pour from the lip | light |
| 2 | Scrape the discard into a bowl | 0.8 s | spoon scrape, starter stretches | light at release |
| 3 | Scoop flour in | 0.9 s | flour puff on landing | medium at landing |
| 4 | Pour water | 0.8 s | glug | 3 × light, 150 ms apart |
| 5 | Stir. The player may circle-drag on the jar to stir faster (optional) | 1.2 s | spoon swirls, paste smooths | light tick every 180 ms |
| 6 | Settle. The band snaps on at the new level | 0.5 s | surface flattens, band snaps | firm |

That totals about 4.2 s without hooch, and 4.8 s with it. game-mechanics §2.6 says about 6 s. UX wants the shorter time because the sequence plays every day; the first feed can run at about 6 s. Afterward:
- The status changes to `freshly_fed`.
- A result card shows the plain-words forecast from the sim ("Best around lunchtime"). Its body is a fuzzy time, with no digits.
- The forecast also becomes the status hint.
- Reduce motion: a 600 ms crossfade to the fed state, plus one firm haptic.

---

## 9. Smell interaction

The nose button is `smell`. Its icon is curling wisps over a nose outline, the player's nose. The starter has no face.

| t (ms) | What happens |
|---|---|
| 0 | Tap Smell. The lid tips open (or the cloth folds back). The camera dollies 12% toward the jar mouth and tilts down 8° (600 ms, ease-in-out sine) |
| 200 | Wisps rise from the mouth. Their shape comes from the smell family: slow lazy curls (mild), quick thin threads (sharp), heavy low drift (alcohol or acetone). Wisps are cream-white in every family, so color carries nothing |
| 300 to 1,000 | "Breathe in": 3 soft haptic swells (light, light, medium, 330 ms apart) and a quiet inhale sound. The HUD dims to 60% |
| 1,200 | The smell result card rises above the bar, and the camera eases back at the same time (400 ms). That matches game-mechanics §4, about 1.2 s |

**Result card:**
- Descriptor icon and title, for example "Pleasantly tangy". The descriptor comes from the sim state (CLAUDE.md hard rule 2).
- Body (≤ 90 characters): one sensory line (≤ 60) plus an optional note (≤ 30).
- An optional "what this means" line (≤ 90, ink_muted), shown the first 3 times for each descriptor and then dropped (game-designer, narrative-designer). After that, a "What does this mean?" text button brings it back with 1 tap. A `musty` meaning line never fades, and it always says it's a warning sign.
- When the sim marks the state ambiguous, add "Try inspecting the surface" with a button.
- At 150% text the card can reach about 340 pt on an iPhone SE, and it scrolls past the jar region's height.

**Ambiguous pairs, from sourdough-scientist:**

| Pair | What tells them apart |
|---|---|
| `freshly_fed` vs `dormant` | smell |
| `near_peak` vs `at_peak` | time |
| `collapsing` vs `hungry` | both lower with streaks |
| `hungry` vs `dormant` from neglect | |
| `dormant` vs `unhealthy` | musty smell and dry skin |

**Delight and safety:**
- On the first smell of each new descriptor, the card shows a "New smell" ribbon (icon + word) and writes a journal entry.
- `musty` and the `unhealthy` smells use the care tone on the card's icon, and the body says what to do (feed today).
- The card is dismissed by tapping anywhere or any action. It auto-hides after 8 s unless "Keep messages on screen" is on.
- The smell moment can't be interrupted. Events queue.
- Reduce motion: no dolly and no wisp motion. The wisps fade in place, and the moment shortens to 600 ms.

---

## 10. Inspection

Inspect opens a peek sheet with a 2-column chip grid, each chip 48 pt tall. The vertical slice has the 3 P0 chips: `height`, `bubbles`, `surface`. P1 adds `consistency` and `development` (game-mechanics §5).

Tapping a chip moves the camera (500 ms, ease-in-out cubic). The camera then holds on the cue for 1.0 s before the result text fades in: look first, then read. game-mechanics allows up to 3 s, and a tap anywhere shows the text at once. The back arrow ‹ (48 pt) or another chip returns to the grid.

```
┌─────────────────────────────────────┐
│ ▬▬                                  │
│ Inspect                        Done │
│ ( ◌ Bubbles      ) ( ≈ Consistency ) │  icon + label chips, 156 × 48
│ ( ↕ Height       ) ( ◠ Surface     ) │
│ ( ✦ Development  )                   │
└─────────────────────────────────────┘
 result view:  ‹ Bubbles
               Lots of small bubbles all the way up the glass.   ← observation, 90 chars max
               It's busy and rising.                             ← meaning, 90 chars max, optional
               [ Smell it ]                                      ← only when ambiguous (§9)
```

| Kind | Camera target | Framing | Extra animation |
|---|---|---|---|
| `bubbles` | Glass wall at the starter's mid-height, the side facing the light | Close-up, glass fills 70% of the jar region | Glass focus pull, bubbles in sharp focus |
| `consistency` | Jar mouth, from 50° above | Medium | A spoon lifts a strand and lets it fall |
| `height` | Side view at the band | Medium, band and top both in frame | Band glints, a faint guide line rises from band to top |
| `surface` | Top-down into the mouth | Close-up | Lid lifts away |
| `development` | Slow orbit, 40° over 3 s, at home distance × 1.2 | Wide | None. Reduce motion: a static wide 3/4 view |

- Results come from the sim state only (CLAUDE.md hard rule 2). The observation describes what the jar shows. The meaning connects it to the state, in plain words.
- Readouts are words, never raw numbers ("about doubled" is fine). Meaning lines fade like smell's do, except lines about warning or mold signs, which never fade. The `surface` result at `moldy` says to discard it.
- 3D input stays off while the sheet is open. The camera is driven, which is simpler for less tech-fluent players.
- Reduce motion: the camera move is a 200 ms crossfade cut.

---

## 11. Showing condition without numbers

Three layers, always in agreement because all three read the same sim state:

1. **Status pill.** It shows one winning state, with this precedence from the scientist: `moldy` > `unhealthy` > `dormant` > `hungry` > `recovering` > the rise phases. It always has an icon (distinct shape), a word, and a tone color on the icon and border only. The word is always in ink, so text contrast never depends on the tone.
2. **Hint line.** One plain sentence: what is happening, and the gentle next step. It changes with the state and with the sim forecast. It never shows digits.
3. **The jar itself.** Each state's cues come from the scientist's draft. The rubber band at the fed mark makes rise readable at a glance with no number. It's an **[assumed]** art element, and a real baker's habit.

| State | Icon (shape) | Tone | Jar cues (scientist v0) | Hint example (narrative owns) |
|---|---|---|---|---|
| `freshly_fed` | spoon | good | flat, smooth, at the band | Just fed. Let it rest. |
| `developing` | two small bubbles | good | tiny bubbles at the glass, just above the band | Waking up. First bubbles. |
| `active` | three rising bubbles | good | many small bubbles, clearly rising, convex top | Rising nicely. |
| `near_peak` | dome + up chevron | good | about 1.7 to 2× the band, dome forming, bigger bubbles near the top | Almost at its best. |
| `at_peak` | dome + sparkle | good, plus a soft glow on the pill | tallest (about 2 to 2.5×), domed, big bubbles on top | At its best right now. |
| `collapsing` | dome + down chevron | watch | top flat or sunken, cream streaks and a ring on the glass | Past its best. Feed it soon. |
| `hungry` | empty bowl | watch | low and loose, few bubbles, maybe thin gray hooch | Hungry. A feed will help. |
| `dormant` | crescent moon | rest | flat and still, hooch common | Resting. Cold slows it down. |
| `recovering` | half sun with rays | rest | like its rise phase, but lower and slower | Getting its strength back. |
| `unhealthy` | wilted sprout | care (deep honey, 3 pt border, filled icon) | dull dry skin, thick dark hooch, flat, almost no bubbles | Needs care. Feed it today. |
| `moldy` | octagon with ! | stop (filled pill, cream word) | fuzzy spots, maybe a pink or orange tint | Mold. This starter must go. |

**Red belongs to mold only.** Inside the jar, pink, orange and red mean discard, so the UI uses no red-family tone for anything recoverable (art-director). `unhealthy` is a deeper honey than `hungry`. It's told apart from hungry by its icon, its word and a heavier border, not by hue.

**Status explainer card** (tap the pill):
- Title: the state word.
- Body: a meaning line (≤ 90) on what it means and what to look for, plus the forecast line (≤ 60) during a rise phase (game-mechanics §6).
- A "Show me" button moves the camera to the state's main cue, using the inspection framing.
- First appearance: the first time a state appears, the pill shows a 10 pt "new" dot until the player taps it. This is the main "no manual" teaching tool.

**Safety copy rules (from vision.md):**
- `moldy` never says scrape it off, and never implies the starter is usable.
- Hooch, acetone and alcohol never use the care or stop tones.
- `unhealthy` is "needs care soon", not alarm (scientist).

---

## 12. Events and "while you were away"

### Tiers

| Tier | Form | Where | Stays | Buttons | Caps |
|---|---|---|---|---|---|
| `info` | Toast: ink plate, cream text, icon, and a › chevron when the journal exists | Under the HUD plate | 2.5 s + 70 ms per character, at most 7 s. Until dismissed if "Keep messages on screen" is on | none. Tap opens its journal entry (title 26, body 200, from narrative-designer). Swipe up dismisses. In the vertical slice, which has no journal, tap dismisses | 1 visible. Queue of 3 (the oldest drops to the journal). 1.2 s gap between toasts. At most 4 live toasts a day (game-mechanics); the rest are logged only |
| `nudge` | Card | Above the action bar | Until acted on or dismissed | ≤ 2, stacked, primary at the bottom | 1 visible. At most 2 a day. None in quiet hours, 22:00 to 08:00 (game-designer) |
| `attention` | Half sheet | Bottom | Until acted on. Close X only if it's safe to defer | ≤ 2, stacked, primary at the bottom | At most 1 waiting, ever (vision.md) |

**Queue rules (agreed with game-designer):**
- Nothing interrupts an open sheet, the feed sequence, the smell moment, inspection or the time-lapse. That includes `attention`.
- The queue releases 600 ms after the main screen goes idle, in priority order: attention, then nudge, then info.
- Only one tier presents at a time, except that a toast may show while a card is up.
- Items dropped by the caps still go to the journal. Drop order: ambient first, then merged duplicate info, then the oldest info.

**Vertical slice events (game-designer):**

| Event | Tier |
|---|---|
| `first_rise` | info |
| `peaked_while_away` | info |
| `hungry_again` | nudge, with "Feed now" |
| `hooch_forming` | info (its choice lives in the feed sheet) |
| `back_to_strength` | info |
| `warning_signs` | attention, with "Feed now" |
| `mold_found` | attention (later) |

**`mold_found`:**
- The sheet has no Close X.
- Primary: "Say goodbye". This leads to the discard ceremony: the jar empties, a memorial entry is added to the journal, and a new starter begins.
- Secondary: "Look closer". This runs the surface inspection, then returns to the sheet.

### Return flow

Triggered when the player has been away ≥ 60 min and something changed (game-designer).

1. **Time-lapse.** 3 to 6 s, replayed from the sim's offline catch-up, so it shows only what the sim produced. The HUD hides, and a small plate reads "While you were away". A "Tap to skip" pill sits in the E zone, and a tap anywhere skips. Reduce motion: a before still and an after still, 1.2 s each, crossfaded.
2. **Summary card.**
   - It holds a heading, up to 3 moment rows (icon + text), and a "Now" row that reuses the status word and hint, so there's no new copy. Times are fuzzy, with no digits.
   - It's non-modal. Tapping any action dismisses it, so the common path costs no extra tap.
   - Settings has "Show time-lapse on return" (default on). With it off, the summary card still shows, so the record of the absence is never lost (game-designer).
3. **Main screen**, with at most one nudge card or one attention sheet.
   - If an attention event is pending, the summary card is skipped. Its rows appear at the top of the attention sheet instead. This keeps "Feed now" at 3 taps (§7).

---

## 13. Environment sheet

The scope follows game-designer:
- P0: 3 locations (`counter`, `warm_spot`, `fridge`).
- P1: `window_sill` (shown as a cool spot) and `proofing_box`, the only dial, 24 to 30 °C.
- Temperature is read-only and derived from location. Humidity isn't shown.
- No cover row in the MVP: cover is P2, because cloth is strictly worse and a tight lid has no real cost (game-designer, from scientist v1). No containers in the MVP either.

```
┌─────────────────────────────────────┐
│ ▬▬                                  │
│ Where it lives                  Done │
│ ┌───────────┐ ┌───────────┐ ┌───────────┐ │  option cards, 3 across on 360 (104 × 112),
│ │  [illus]  │ │  [illus]  │ │  [illus]  │ │  2 across at 150% text
│ │  Counter ✓│ │ Warm spot │ │  Fridge   │ │  selected: 3 pt accent border + ✓ badge
│ │ 22 °C·Mild│ │ 26 °C·Warm│ │ 4 °C·Cold │ │  digits OK here (a dedicated screen)
│ └───────────┘ └───────────┘ └───────────┘ │
│ Proofing box  [ − ]  26 °C  [ + ]   │  P1 only, appears when selected; 48 pt steppers
└─────────────────────────────────────┘
```

- A choice applies instantly, with no confirmation.
- The jar animates to its new spot behind the sheet, and the scene lighting shifts.
- The first fridge move fires `off_to_nap` (info) after the sheet closes.
- The temperature word (Cold, Cool, Mild, Warm) is always next to the number, and °F is P2.

---

## 14. Journal, settings, onboarding

**Journal** (full sheet, P1):
- Header: name, plus "12 days old" (digits are OK here).
- A timeline grouped by day: feeds (ratio, flour), smells, inspections, events, away summaries and memorials.
- A "Details" switch reveals numbers for experienced bakers: temperature, ratio, hydration, rise relative to the band. Advanced information lives here, never on the main screen.

**Settings** (full sheet), one row each:
- Text size (Standard, Large, Largest)
- Reduce motion
- Haptics
- Keep messages on screen
- Show time-lapse on return
- Sound
- Rename starter
- Replay tutorial
- Credits
- Erase all data. This opens a confirmation that replaces the sheet's content: 2 buttons, with the destructive one not preselected.

There are no accounts.

**Onboarding:**
- About 90 s, all in-world.
- Coach marks: one at a time, ≤ 60 characters, each with a spotlight ring (3 pt, at least 3:1 against the scene) on its target.
- Beats: meet the jar, then name it (text field + 3 suggestion chips + "Pick for me"), then a guided first feed (game-designer owns the fiction), then smell once, then a time-lapse preview of the coming rise.
  - The preview runs the sim forward on a copy at the tutorial time scale, so it shows only sim output.
  - It closes with "Come back in a few hours".
- Inspect and Journal teach themselves with one coach mark on first use.

---

## 15. Motion and haptics

| Element | Duration | Easing (Godot Tween) | Reduce motion |
|---|---|---|---|
| Sheet open | 300 ms | `TRANS_CUBIC`, `EASE_OUT` | 150 ms fade |
| Sheet close | 220 ms | `TRANS_CUBIC`, `EASE_IN` | 120 ms fade |
| Scrim | with the sheet, ink at 0% → 30% | linear | same |
| Card in / out | 280 / 200 ms, 24 pt slide + fade | `CUBIC` out / in | fade only |
| Toast in / out | 220 / 180 ms, 12 pt slide + fade | `CUBIC` out / in | fade only |
| Button press | scale 0.96: 80 ms in, 120 ms out | `QUAD`, `EASE_OUT` | color change only |
| Chip select | 120 ms | `QUAD`, `EASE_OUT` | instant |
| Status change | 250 ms crossfade + one 1.06× pulse | `BACK`, `EASE_OUT` | crossfade only |
| Camera: double-tap reset | 350 ms | `CUBIC`, `EASE_OUT` | 150 ms crossfade cut |
| Camera: inspect or "Show me" | 500 ms | `CUBIC`, `EASE_IN_OUT` | 200 ms crossfade cut |
| Camera: smell dolly | 600 ms in, 400 ms out | `SINE`, `EASE_IN_OUT` | none |
| Camera: reframe above a sheet | 300 ms, matches the sheet | `CUBIC`, `EASE_OUT` | instant |
| Orbit inertia / idle return | τ 250 ms / 1,500 ms | exponential / `SINE` | off / off |

**Reduce motion** turns off decorative and camera motion: dollies, inertia, idle drift, slides, pulses, wisp motion, parallax and ambient motes. It keeps sim-driven content: the starter rising, bubbles and hooch. That content is information, and it moves slowly.

**Haptics** (the setting defaults on). `Input.vibrate_handheld(ms, amplitude)`. The amplitude argument has existed since Godot 4.3. Android needs the VIBRATE permission.

| Level | Call | Used for |
|---|---|---|
| light | 10 ms, 0.3 | taps, chip select, stepper ticks, stir ticks, pokes |
| medium | 20 ms, 0.6 | flour landing, smell inhale peak |
| firm | 35 ms, 1.0 | band snap (feed complete), discard ceremony |

**[assumed]** If iOS ignores amplitude, iOS keeps medium and firm only, and the light cues are skipped. godot-developer checks this. Every haptic moment also has a sound, so players with haptics off lose nothing.

---

## 16. Accessibility

| Requirement | Spec |
|---|---|
| Touch targets | 48 × 48 standard, 44 × 44 absolute minimum, and hit areas never overlap. Bar slots are at least 64 × 64 |
| Text size | Body is at least 16 pt at 100%. Three in-app sizes: Standard 100%, Large 125%, Largest 150% (type scale in §17). The OS text-size setting can't be read in 4.7.2 **[assumed]** |
| Contrast | Text ≥ 4.5:1, non-text (icons, borders, focus) ≥ 3:1. Computed in §16.1. No text sits straight on the 3D scene |
| Status | Never color alone: icon shape + word + tone (§11). Selected states add a ✓ or a filled icon. Disabled controls show a reason |
| Motion | Reduce motion setting (§15). The OS flag can't be read in 4.7.2 **[assumed]** |
| Haptics | Can be turned off. Never the only cue |
| Timing | "Keep messages on screen". Nothing auto-confirms. The time-lapse is skippable |
| Gestures | All optional. No required hold, multi-finger gesture or path-drag. Mix is a tap |
| Screen readers | Every Control sets `accessibility_name` (≤ 40 characters, via `tr()`) and, where useful, a description (≤ 120). The jar exposes one element: "Starter, [state]. [hint]", with actions Feed, Smell and Inspect. The order: HUD, jar, bar, then open sheet content. VoiceOver and TalkBack arrive with Godot 4.8 (D-012). We build the names now so 4.8 just turns them on |
| Older and less tech-fluent players | Plain words, one idea per message, no jargon on the main screen (baker's terms appear in the journal and get explained there), no hidden menus, and a visible Done on every sheet |

### 16.1 Color roles and measured contrast

art-director adopted these hexes unchanged as the UI palette (art-direction.md). The accent is the deep sibling of the scene's sage. The ratios come from the WCAG 2 relative luminance formula, computed in Python, not eyeballed.

| Role | Hex | On | Ratio | Need |
|---|---|---|---|---|
| ink (text) | #33241A | surface #FBF6EC | 13.85 | 4.5 ✓ |
| ink | #33241A | surface_alt #F1E7D6 | 12.17 | 4.5 ✓ |
| ink_muted (hint, secondary) | #6A5444 | surface | 6.58 | 4.5 ✓ |
| ink_muted | #6A5444 | surface_alt | 5.78 | 4.5 ✓ |
| on_accent (button label) | #FFFCF5 | accent #4F6B47 | 5.81 | 4.5 ✓ |
| accent (button, selected) | #4F6B47 | surface / surface_alt | 5.53 / 4.86 | 3 ✓ |
| outline (borders, tracks) | #8A7461 | surface / surface_alt | 4.10 / 3.61 | 3 ✓ (first try #9A8470 failed at 2.90) |
| disabled text | #8F7D6E | surface | 3.66 | exempt; kept ≥ 3 |
| toast text | #FBF6EC | ink #33241A | 13.85 | 4.5 ✓ |
| tone good / watch / care / stop / rest | #4F7A45 / #8A6414 / #6E4F12 / #8E2B22 / #4E6A80 | surface | 4.64 / 4.98 / 6.99 / 7.74 / 5.27 | 3 ✓ |
| tone good / watch / rest | same | surface_alt (pill fill) | 4.08 / 4.38 / 4.64 | 3 ✓ |
| care icon / ink on care tint | #6E4F12 / #33241A | #F4E4BE (`unhealthy` pill fill) | 5.98 / 11.85 | 3 ✓ / 4.5 ✓ |
| on_accent on stop (`moldy` pill) | #FFFCF5 | #8E2B22 | 8.14 | 4.5 ✓ |

The first draft's terracotta care tone (#A4482C) was dropped: it was red-family.

**Night surface** (the scene follows the local time of day; darkest backdrop about #1A1310, per art-director): sheets and cards switch to `surface_night` #EDE3D2 to cut glare, and the HUD plate uses it at alpha 0.94.

| On surface_night #EDE3D2 | ink | ink_muted | accent | outline | good / watch / care / rest / stop | disabled |
|---|---|---|---|---|---|---|
| Ratio | 11.73 | 5.57 | 4.68 | 3.48 | 3.93 / 4.22 / 5.92 / 4.47 / 6.56 | 3.10 |

The night plate at 0.94 over #120C08 gives ink 10.37 and ink_muted 4.93. That passes, but with the least margin of any pairing, so don't go dimmer.

**HUD plate over the 3D scene.** Surface at alpha a, blended over the worst-case backgrounds:

| Background | ink at a = 0.88 | ink_muted at a = 0.88 | ink_muted at a = 0.80 |
|---|---|---|---|
| white highlight | 13.95 | 6.63 | 6.69 |
| mid-brown wood #6B4A30 | 11.53 | 5.47 | 4.84 |
| night kitchen #120C08 | 10.71 | 5.09 | **4.21 ✗** |

So the **plate alpha is at least 0.88**. For reference, bare ink on mid-brown wood is 1.88, and on the night kitchen it's 1.30. Bare text fails.

Checked against the real scene colors in `art/blender/scripts/build_jar.py`, darkest is #5B4B3D: the plate at 0.88 gives ink 11.49 and ink_muted 5.46. Bare ink on that color is 1.79.

The five tones have nearly equal luminance (0.13 to 0.16), so they can't separate states by lightness for color-blind players. That's acceptable only because the icon shape and word always carry the meaning.

---

## 17. Component inventory (Godot Theme)

Every component is a themed Control. Default Godot styles never ship. Sizes are at 100% text. Labels grow with text size, and containers grow with them.

| Component | Size | Look | States |
|---|---|---|---|
| PrimaryButton | height ≥ 56, full sheet width | accent fill, on_accent 17 semibold, fully rounded | normal, pressed (0.96×, fill −8% lightness), focused (2 pt ink ring + 2 pt gap), disabled (surface_alt fill, disabled text, reason line below) |
| SecondaryButton | height ≥ 52 | 1.5 pt outline, ink label | same |
| TextButton ("Later", "Got it") | height ≥ 44, width ≥ 64 | ink_muted label, no fill | normal, pressed (surface_alt fill), focused |
| IconButton (⚙, ✕, ‹) | 48 circle | surface plate at 88%, icon 24 ink | normal, pressed, focused |
| ActionBarButton | ≥ 64 × 64 (67 × 72 on 375) | icon 28 + label 14 semibold | normal, pressed, open (filled icon + 4 pt accent pill under the label), emphasized (halo + dot badge), disabled (reason on tap) |
| StatusPill | height ≥ 40 | surface_alt fill, tone border 2 pt, tone icon 24, ink word 17 semibold | normal, pressed, new (10 pt dot), peak glow, care (3 pt border, filled icon, #F4E4BE fill), stop (stop fill, cream word and icon) |
| Chip | height ≥ 48 | surface_alt fill, outline 1.5 pt, ink 16 semibold | rest, pressed, selected (accent fill, on_accent label, ✓ icon), disabled |
| OptionRow (ratio) | ≥ 64, full width | radio ring 22 + title 17 semibold + sub 16 ink_muted | rest, selected (filled ring + ✓ + "last time" tag), pressed |
| OptionCard (location) | ≥ 104 × 112 | illustration + label + sub | rest, selected (3 pt accent border + ✓ badge), pressed |
| Sheet (peek / half / full) | 42% / 60% / full | surface, top radius 24, grabber 36 × 5 | opening, open, dragging, closing |
| Scrim | full screen above the sheet | ink at 30% | n/a |
| Card | full width − 32, padding 20 | surface, radius 20, shadow y 8 / blur 24 / ink at 18% | entering, shown, exiting |
| Toast | full width − 32, padding 16 | ink plate, surface text 16, icon 24, radius 16 | entering, shown, exiting |
| Stepper | [−] value [+], each 48 | outline buttons, value 20 semibold | rest, pressed, at limit (button disabled + light tick), repeats at 8/s after 400 ms |
| Slider (P1, if needed) | track 6, thumb 28 (hit 48) | track surface_alt + outline, fill accent | rest, dragging (value bubble), focused, disabled. Snaps with a light tick |
| Toggle (settings) | row ≥ 52, switch 51 × 31 | on: accent with ✓ in the knob; off: outline track | on, off, pressed, focused, disabled |
| TextField (name) | ≥ 52 | outline 1.5 pt, ink 17, focus ring | empty, focused, filled, error (icon + message) |
| CoachMark | ≤ 280 wide | ink plate, surface text, pointer, spotlight ring 3 pt | shown, dismissed |
| SkipPill (time-lapse, feed) | 48 tall | surface plate at 88%, ink 16 | shown |

**Type scale (QA).** Sizes in pt at each text size.

| Role | Standard 100% | Large 125% | Largest 150% |
|---|---|---|---|
| Name, card title, sheet title | 20 semibold | 25 | 30 |
| Status word, button | 17 semibold | 21 | 26 |
| Body, hint, chip, toast | 16 | 20 | 24 |
| Action bar label | 14 semibold | 16 (capped) | 16 (capped). Long-press shows 28 |

Line height is 1.35 for body and 1.2 for titles and buttons.

**Font.** The UI face is **Figtree** (SIL OFL 1.1). art-director proposed it with Nunito Sans. The license text ships with the app.

Measured with CoreText on the sample copy:

| Figtree weight | Average width |
|---|---|
| Regular | 0.427 em |
| Medium | 0.430 em |
| SemiBold | 0.435 em |
| Bold | 0.440 em |

All weights are under the 0.47 em the copy limits assume. "Inspect" at 16 pt semibold is 54 pt, inside the 64 pt bar slot.

Nunito Sans wasn't measured, because it isn't on this machine.

**Display face.** **Fraunces** (soft, low "wonk") is art-director's pick for the starter's name and journal titles only, on the condition that it's measured first. It isn't on this machine either, and fetching it is a download that waits for approval. If its width is above 0.47 em, the name auto-fits down to 85% before ellipsizing at 150% text. The name row is 240 pt on a 360 pt screen.

For reference, other faces measured: SF 0.43, SF bold 0.46, Avenir Next 0.43, Helvetica Neue 0.43, Mariupol 0.41. A wider face means recomputing §18.

---

## 18. Copy slots

These are hard maximums in characters, spaces included. They were computed on a 360 pt wide screen with 16 pt gutters, using 0.47 em per character plus 10% slack for ragged wrapping. Each slot fits its line cap at 150% text. narrative-designer owns the words.

| Slot | Max | Lines at 100% / 150% |
|---|---|---|
| Starter name (player-typed) | 16 | 1 / 1 |
| Status word | 12 | 1 / 1, never wraps |
| Status hint | 34 (target 28) | 1 / 2 |
| Action bar label | 7 | 1 / 1 |
| Toast (`info`) | 60 | 2 / 3 |
| Card title / sheet title | 26 | 1 / 2 |
| Card body (`nudge`) | 120 | 4 / 6 |
| Status explainer: meaning / forecast (optional) | 90 / 60 | 3 / 4, 2 / 3 |
| Sheet section label (e.g. the schedule question) | 26 | 1 / 2 |
| Attention sheet body | 280 | scrolls |
| Button label (every button, choices included) | 18 | 1 / 1 |
| Away summary: heading / each moment row (≤ 3 rows) | 26 / 44 | row 2 / 3 |
| Feed result card: forecast / reaction (optional) | 60 / 60 | 2 / 3 each |
| Smell result: title / body (sensory 60 + note 30) / meaning line | 20 / 90 / 90 | 1 / 1, 3 / 4, 3 / 4 |
| Inspect chip label | 11 | 1 / 2 |
| Inspect observation / meaning | 90 / 90 | 3 / 4 each |
| Feed: ratio option title / sub-line ("{ratio} · keep {g} g": grams must show, per game-mechanics §2.3) | 20 / 34 | 1 / 2 |
| Feed: flour chip | 14 | 1 / 2 |
| Feed: hooch option (2 options, side by side) | 18 | 1 / 2 (option chips may wrap; buttons may not) |
| Feed: "Same as last time" line | 18 | 1 / 1 |
| Feed: one-line note | 60 | 2 / 3 |
| Location card label / sub | 14 / 14 | 1 / 2 |
| Journal entry title / body | 26 / 200 | scrolls |
| Onboarding page title / body, coach mark | 26 / 120, 60 | 1 / 2, 4 / 6, 2 / 3 |
| Confirmation title / body | 26 / 120 | 1 / 2, 4 / 6 |
| Empty state title / body | 26 / 90 | |
| Settings row label / value | 24 / 12 | 1 / 2 |
| `accessibility_name` / description (not shown) | 40 / 120 | n/a |
| Notification title / body (after the slice, OS-rendered) | 30 / 90 | OS |

---

## 19. Notes for godot-developer and tech-architect

1. **1 unit = 1 pt or dp on every device.** Lay out at the device's real logical size (360 to 440 wide). Don't stretch a fixed base resolution. Example: a 390 × 844 base with `canvas_items` + `expand` scales by min(w, h) ratio. On an iPhone SE that's 1.58 px per unit instead of 2 px per pt, so a 48-unit target would come out at 38 pt and fail the 44 pt minimum. Derive `content_scale_factor` from the screen scale (iOS) or density (Android). Please confirm the API.
2. **Text size.** Scale Theme font sizes, not `content_scale_factor`, so targets don't balloon. Every text container must grow vertically.
3. **Input.** See §6 for the touch routing rules. 3D input lives in `_unhandled_input` on the camera rig. Pinch is built from touch indices on both platforms.
4. **Safe areas.** Read `get_display_safe_area()` each time the app resumes or the screen resizes, and apply the §2 floors on Android.
5. **Camera framing.** Frame to the jar region (§2), not the viewport, and reframe when a sheet opens (§15).
6. **Hard rule 2 in the UI.** Status, hint, smell, inspection, forecast and the time-lapse read from sim state only.

---

## 20. Open items in this doc

| Item | Waiting on |
|---|---|
| Icon set (11 status, 5 action, 5 inspection, on a 24 pt grid) | art-director (§17) |
| Fraunces width measurement before it's adopted for the name | needs a font download (approval) |
| Rubber band at the fed mark as a jar element | art-director, sourdough-scientist |
| Yaw limit (±70° or unlimited), depending on whether the set reads at 360° | art-director |
| Spike checks: touch ownership, pinch, safe area on Android, haptic amplitude on iOS, content scale, OS text-size and reduce-motion flags | godot-developer |

## Sources

- Hoober, S. "How Do Users Really Hold Mobile Devices?" UXmatters, 2013. https://uxmatters.com/mt/archives/2013/02/how-do-users-really-hold-mobile-devices.php
- iPhone screen sizes and safe areas: https://useyourloaf.com/blog/iphone-17-screen-sizes/ and Apple, iPhone 17 Pro tech specs: https://www.apple.com/iphone-17-pro/specs/
- iOS 27 device support (iPhone 11 and later, SE 2nd gen and later): https://appleinsider.com/articles/26/06/08/ios-27-keeps-iphone-11-and-newer-compatibility
- iPhone 17e keeps a notch: https://www.macrumors.com/roundup/iPhone-17e/
- Godot `Input.vibrate_handheld` amplitude: https://docs.godotengine.org/en/4.3/classes/class_input.html
- Godot safe area on Android, community reports: https://forum.godotengine.org/t/android-edge-to-edge-feature-does-what-exactly/123675
- WCAG 2.2, contrast (1.4.3, 1.4.11) and target size: https://www.w3.org/TR/WCAG22/
- Local measurements: CoreText glyph widths and WCAG contrast math, scripts in the ux-designer scratchpad (not committed).
