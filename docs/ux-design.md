# UX design

Owner: `ux-designer`. Status: Phase 1, wave A draft (2026-11-26). **Phase 4 pass (2026-11-27):** iOS first (D-054), no screen-reader work (D-055). Changed: §3 (sheet sizing, HUD tuck), §7, §8 (compact feed sheet), §9 (smell check), §10 (5 chips, "What it means"), §11.1 (forecast hint), §13 (5 places), §14 (journal and traits, rename, settings, onboarding, empty jar), §15, §16, §17, §18, §20.

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

1. **The jar is the screen.** The 3D jar gets at least 55% of the screen height on every iPhone and every Android phone larger than 360 × 640, at every text size. On the 360 × 640 Android profile the floor is 51% (D-043). UI floats on plates around it. Nothing sits on top of the starter.
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
| Android, any navigation mode | varies | reported / max(reported, 48) | Edge-to-edge is forced on Android 15+ at target SDK 35. Godot has no API to tell gesture navigation from 3-button navigation (spike), so every Android phone gets the 3-button floor |

**Insets (QA checks these):**
- HUD plate top = safe top + 8.
- Action bar plate bottom = safe bottom + 8.
- Side gutters are 16, plus any side safe-area inset.

Minimum bottom inset for the action bar:

| Device | Bottom inset |
|---|---|
| iPhone SE | 8 |
| iPhone 17e, 17 Pro, 17 Pro Max | 42 |
| Android, any navigation mode | 56 dp (48 floor + 8) |

`DisplayServer.get_display_safe_area()` is implemented on Android and iOS (spike, from the docs). Forum reports say it may cover only the Android status bar, not the navigation bar. The spike couldn't test this: there are no export templates and no device (D-016). So the Android bottom value is a floor until the Phase 2 device check.

**Stage budget at 100% text** (jar region = space between the HUD plate and the action bar):

The HUD plate is about 144 pt tall with the 44 pt pill, and the bar plate is exactly 72. These are T3's measured jar regions (commit 5ef89e9, test-asserted against the principle 1 floors):

| Device | Jar region at 100% text | At 150% text |
|---|---|---|
| Android 360 × 640 | 336 pt (52%) | 327 pt (51%) |
| iPhone SE 375 × 667 | 415 pt (62%) | 406 pt (61%) |
| iPhone 17e 390 × 844 | 531 pt (63%) | 522 pt (62%) |
| iPhone 17 Pro Max 440 × 956 | 628 pt (66%) | 619 pt (65%) |

A compact-height layout for short screens (a 64 pt bar and a tighter HUD) was considered and dropped. It would have added about 24 pt on 360 × 640, but D-043 accepts 51% there, so a second layout mode isn't worth its test cost.

The camera frames the jar to the jar region, not to the full screen. It shifts the frustum so the jar is centered between the HUD and the bar.

---

## 3. Screen map

| Screen | Type | Reached by | Dismissed by | 3D input |
|---|---|---|---|---|
| Main | Base | App launch | n/a | On |
| Feed | Fit sheet (§8.1). Full at Largest text | `feed` button; "Feed now" on a card or sheet | Mix (plays sequence), swipe down, tap above, Close | Off (jar visible above) |
| Smell result | Card above bar | `smell` button → smell moment (§9) | Tap anywhere, any action button, swipe down | On after the moment |
| Inspect | Peek sheet: 42%, or the chip grid's height if taller (§10) | `inspect` button; "Show me" in explainers; Inspect on a smell card | Swipe down, tap above, Done | Off (camera driven) |
| Place | Fit sheet (§13) | `environment` button | Swipe down, tap above, Done | Off |
| Journal | Full sheet (screen − safe top − 12) | `journal` button; a toast's › | Swipe down on header, Close, Done | Off |
| Rename | Replaces the journal's content (§14.2) | Journal → Rename | ‹ Back, "That's its name" | Off |
| Status explainer | Card above bar | Tap the status pill | Tap anywhere, swipe down | On |
| Settings | Full sheet | Gear button (HUD, top right); gear on an onboarding page (§14.4) | Swipe down on header, Close, Done | Off |
| Onboarding | Pages + coach marks over the live jar (§14.4) | First launch | Completes itself; "Skip tour" on any coach mark | Guided |
| Empty jar | Main screen variant (§14.5) | Restart page → "Not today"; launch while empty | "Start again" | On |
| While you were away | Time-lapse takeover → summary card | Return after ≥ 60 min with a change (game-designer) | Tap to skip; card: Got it, or any action | Off during the time-lapse |
| Event: `info` | Toast (top, under the HUD) | Event queue | Auto (§12), tap, swipe up | On |
| Event: `nudge` | Card above bar | Event queue | Its buttons, swipe down, any action | On |
| Event: `attention` | Half sheet | Event queue | Its buttons; a Close X only when closing is safe | Off |
| Confirmation | Replaces the current sheet's content | Erase data, discard a moldy starter | Its 2 buttons | Off |

**Sheet sizing (Phase 4, replaces the old "top edge never above 40%" rule).**

| Rule | Value |
|---|---|
| HUD tuck | When any sheet opens, the HUD plate tucks away: fade out plus 12 pt rise, 180 ms, `CUBIC` `EASE_IN`. It returns 240 ms `CUBIC` `EASE_OUT` after the sheet closes. Reduce motion: fade only, 120 ms. The scrim already blocks it, and the space goes to the jar |
| Jar band | A non-full sheet's top edge stays at least **160 pt** below `safe top + 8`. Max non-full height = screen h − safe top − 168: SE 479 (72%), 17e 629 (75%), 17 Pro 644 (74%), Pro Max 726 (76%), Android 360 × 640 448 (70%) |
| Fit sheet | Height = header + content + footer, capped by the jar band. Past the cap, the content scrolls and the header and footer stay pinned. Feed and Place are fit sheets |
| Share sheets | Peek 42%, half 60%. These sit under the cap on every phone |
| Overflow cue | When content scrolls: a 24 pt fade to surface at the bottom of the scroll area, and the scrollbar stays visible (3 pt, outline color). No tile is ever ellipsized |
| Camera | T2 reframes to the band between `safe top + 8` and the sheet's top edge (`jar_region_changed`, architecture §3.3). T3 re-emits it on every sheet open, close and resize, including when a fit sheet's content grows (the hooch row appearing, the place dial opening). For feed and place, frame the **whole jar** in that band, so the ghost band line and the move to a new place are visible |

The inspect `bubbles` framing was tuned for the old band between the HUD plate and a 42% sheet (art §18.7). The band is now taller, and the frustum shift centers the target in it. T2 and art-director re-check it once (§20).

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
- **Center.** The jar, and nothing else. The idle camera shows the jar at a slight 3/4 angle with the fed-mark band visible. The rubber band at the fed mark (§11) is decided (D-023).
- **Bottom.** Five actions in canonical order: `feed`, `smell`, `inspect`, `environment`, `journal`. The `environment` label is "Place" (narrative-designer), because "Environment" measures 82 pt and a slot holds 64. Its sheet is titled "Where it lives".
- **Bar slot layout.** The bar plate is exactly 72 tall, and the buttons fill it: 10 top, icon 28, gap 4, label line (≤ 19 pt at the 16 pt label cap), and the remainder at the bottom (≥ 10). Content never grows the plate. The button draws its own icon and label, because Godot's icon-over-text layout grew the bar to 84 (T3, 5ef89e9).
- **Feed emphasis.** When the state is `hungry` or `collapsing`, the Feed button gets a soft halo ring plus a 10 pt dot badge (a shape, not just color), and the hint says why. No other button ever gets a badge.
- **`moldy`** (game-mechanics §1, AC-08.5, D-043; T3 builds it in Phase 3).
  - Only Inspect, Journal and the discard flow work.
  - Feed, Smell and Place are locked: the icon dims to the disabled color and gets a 12 pt lock badge (a shape, not just color). A tap opens no sheet and shows the reason, using existing copy only (narrative.md §9.2):
    - Feed shows a toast, `MOLD_FEED_BLOCKED`.
    - Smell shows the "Best not" card (`SMELL_MOLDY_*`). The smell moment doesn't play: not sniffing mold matches real-world advice (D-043).
    - Place shows a toast, `REASON_MOLDY_LOCKED`.
  - After "Not yet", a discard card sits above the bar and can't be dismissed while the state is `moldy`. It shows the `moldy` hint ("Mold. Please discard it.") and a "Discard it" button (`MOLD_BTN_DISCARD`), so it needs no new copy (§12).
- **No digits rule.** The main screen and its toasts and cards show no digits, except in a name the player typed. Times are fuzzy words ("in a few hours", "around lunchtime"). QA can test this by scanning visible strings.
- **HUD variants (Phase 4).**

| Variant | Row 1 | Row 2 (pill) | Row 3 (hint) | Plate height at 100% |
|---|---|---|---|---|
| Normal | Name + ⚙ | Status pill | Hint, or the forecast hint (§11.1) | about 144 |
| Unnamed (onboarding, before B4) | Hidden. ⚙ moves to the right end of the pill row | Status pill, inert, no "new" dot | Hint | about 104 |
| Empty jar (§14.5) | `EMPTY_JAR_TITLE` in the name style + ⚙ | Hidden | Hidden | about 72 |

Height changes animate 280 ms `CUBIC` `EASE_OUT` (reduce motion: instant) and emit `jar_region_changed`. A smaller plate only grows the jar region, so the D-043 floors still hold.

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
| Tap | Scrim above a sheet | Close the sheet. Not during the feed sequence, on attention sheets, or on onboarding pages (§14.4). During the tour it advances a read coach instead | none |

### Thresholds (QA)

| Value | Number |
|---|---|
| Tap slop (move before a tap becomes a drag) | 10 pt (20 px at 2x, 30 px at 3x) |
| Double-tap window | 300 ms between taps, at most 24 pt apart |
| Long-press | 500 ms, within the 10 pt slop |
| Orbit yaw | ±70° from the front, with an 8° rubber band. Revisited when the set works all the way round (D-023, D-036). The spike benchmark orbits 360°, so the frame budget already covers unlimited yaw |
| Orbit pitch (free orbit) | −5° to +35°, with a 5° rubber band. At −10° the zoomed-out camera sat at counter height (spike). Inspection presets may go past this: `surface` uses 76° |
| Zoom | 1.0× (home distance) to 2.2× (home distance ÷ 2.2), with an 8% rubber band |
| Orbit inertia | exponential decay, τ = 250 ms. Off with reduce motion |
| Idle return | after 20 s with no touch, the camera eases home over 1,500 ms. Off with reduce motion |
| Sheet swipe dismiss | 25% of the sheet height or 700 pt/s |

### Routing rules (Godot 4.7.2)

These come from the director's source review. godot-developer confirms them in the spike.

1. **The camera owns a finger from press to release.**
   - Godot gives only half of this by default (spike, run). A drag that starts on a `STOP` Control never orbits. But a drag that starts on the jar stops orbiting once the finger slides over a `STOP` bar, because Godot hands the drag to the Control under the finger.
   - The fix: the camera rig claims the finger index on press in `_unhandled_input`, then follows that index in `_input` until it's released. With that, the orbit continues over the bar, and a release over the bar ends it (spike, run, PASS).
   - A drag that starts on a bar button never orbits, and it cancels the button press when it leaves the button by more than 10 pt.
2. **Full-screen layout Controls use `mouse_filter = IGNORE`** (roots, margin containers, the HUD layer). The top HUD plate is also `IGNORE`, so a drag that starts on it orbits. Only the settings button and the status pill inside it are `STOP`. The action bar plate, sheets, cards, toasts and scrims use `STOP`, so a near-miss between bar buttons never turns into a poke or an orbit. The 3D rig reads only touches no Control consumed, in `_unhandled_input` (architecture.md §9).
   - As built in T3 (test-asserted): on the top plate, only the pill and settings stop touches. The whole bar plate stops touches. Sheets put a full-screen `STOP` scrim behind the panel, and cards and toasts stop touches only inside their own rect.
   - Controls read emulated mouse events only, never `InputEventScreenTouch`. So they never double-handle a finger the camera is tracking.
3. **An open sheet blocks the 3D view.** Its scrim covers the whole screen above the sheet with `STOP`. A tap on the scrim closes the sheet, and a drag on it does nothing.
4. **iOS sends no pinch event, so we build pinch ourselves** from `InputEventScreenTouch` and `InputEventScreenDrag` indices, on both platforms (spike, run: no orbit during a pinch).
   - Keep `input_devices/pointing/android/enable_pan_and_scale_gestures` off, so Android sends raw touches only.
   - Pinch counts only when both touches started in 3D. A second finger landing on a plate is ignored.
   - Real-device behavior is untested.
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
| Feed from a nudge (`hungry_again`) | (Skip) → Feed now → Mix | 3 | 3 |
| Feed from `warning_signs`, quick (secondary button) | (Skip) → Feed it now → Mix | 3 | 3 |
| Feed from `warning_signs`, safe path (primary button) | (Skip) → Look first → Feed now (on the surface result) → Mix | 4 | 4. The extra tap is deliberate: the safety check comes first (scientist's review) |
| Feed with a different ratio | Feed → ratio option → Mix | 3 | 4 |
| Feed with a different ratio and flour | Feed → ratio → flour → Mix | 4 | 4 |
| Smell | Smell (the result card appears by itself) | 1 | 1 |
| Inspect one kind | Inspect → chip | 2 | 2 |
| Move to the fridge | Place → Fridge (applies instantly) → Done or tap above | 3 | 3 |
| Read the journal | Journal | 1 | 1 |
| Discard a moldy starter (after "Not yet") | Discard card "Discard it" → confirm "Discard" | 2 | 2. The confirmation is deliberate, because discarding can't be undone |
| Change text size | ⚙ → Large | 2 | 2 |
| **Phase 4** | | | |
| Feed with a different flour (or water) | Feed → flour tile → Mix | 3 | 4 |
| Feed with a different ratio, flour and water | Feed → schedule tile → flour tile → water tile → Mix | 5 | 5. Rare: an experienced baker changing everything |
| Read a faded inspect meaning | Inspect → chip → "What it means" | 3 | 3 |
| Read a faded smell meaning | Smell → "What it means" | 2 | 2 |
| Move to the proofing box at 28 °C | Place → Proofing box → + → + → Done | 5 | 5 |
| Rename | Journal → Rename → (type) → "That's its name" | 3 + typing | 3 |
| See the trait | Journal (the starter card shows it) | 1 | 1 |
| Mute | ⚙ → Sound | 2 | 2 |
| New starter from the empty jar | "Start again" → "Pick for me" | 2 | 2 (D-047) |
| Moldy to a new starter | "Discard it" → "Discard" → memorial "Continue" → "Start again" → "Pick for me" | 5 | 5 |
| Onboarding, skip path | "I know starters" → "That's its name" → Mix | 3 | 3 |
| Onboarding, full tour | §14.4 | 11 | 15 |
| Leave the tour from any coach mark | "Skip tour" | 1 | 1 |

Tap 3 is spare on the common path on purpose. It absorbs the time-lapse skip on returns.

---

## 8. Feed flow

The rules follow game-designer:
- Ratio is the decision, and discard is derived. The total after feeding is a fixed target of about 150 g.
- The MVP has single flours only: all 4 in Phase 4, each shown once unlocked (progression §3).
- Hydration has 3 presets (60, 100, 125%), shown once unlocked.
- An optional hooch step appears when hooch is visible (≥ 0.10).
- The first feed happens in onboarding (§14.4).

### 8.1 The compact feed sheet (Phase 4)

T3 found the Phase 3 sheet put the flour chips, discard line and forecast below the fold on 390 × 844 with only 2 flours: its 64 pt ratio rows alone took 230 pt. The compact sheet keeps every choice visible at 100% text by using equal-width **ChoiceTiles** (§17) in rows, two inline rows, a pinned result block, and the HUD tuck (§3). It opens with last time's choices selected.

```
 390 × 844, 100% text, everything unlocked, hooch visible (sheet 558 pt, 66%)
  47 ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄  safe top. HUD is tucked away (§3)
     │            ╭─────╮              │
     │            │     │  whole jar   │  jar band 231 pt. Ghost line at the new band level
     │            │═ ═ ═│              │
 286 ╭─────────────────────────────────╮  sheet top. Content width 350 (20 pt sides)
     │              ▬▬                 │  grabber zone 8
     │ Feed  ✓ Same as last time   (✕) │  title row 48. Caption only while choices = last time's
     │ Hooch     [✓Pour off][ Stir in ]│  inline row 44. Only when hooch is visible
     │ When will you check next?       │  label 22, gap 8
     │ [✓In a few][ Later  ][Tomorrow ]│  3 tiles, 78 tall: title ≤ 2 lines + ratio line
     │ [  hours  ][ today  ][ morning ]│
     │ [  1:1:1  ][ 1:2:2  ][  1:5:5  ]│
     │ Flour                           │  label 22, gap 8. Only with 2+ flours unlocked
     │ [✓Bread][Whole][ Rye ][Spelt]   │  4 tiles, 56 tall
     │ [ flour][wheat][     ][     ]   │
     │ Water   [Stiff][✓Standard][Loose]│ inline row 44, shared label column. Only once unlocked
     ├─────────────────────────────────┤  scroll area ends; footer pinned
     │ Take out 100 g first.           │  FEED_DISCARD_LINE, ink 16
     │ It should be at its best around │  FORECAST_LINE, ink 16 (1 line at 100% on 390)
     │ [            Mix              ] │  primary 56
 802 ╰─────────────────────────────────╯  bottom = safe bottom + 8
```

**Order and blocks.** Blocks are 16 apart, top pad 4. Hidden blocks take no space.

| # | Block | Shown when | Layout | Height at 100% |
|---|---|---|---|---|
| 0 | Header | always | Grabber zone 8 + title row 48: `FEED_SHEET_TITLE` (20 semibold), then 12 pt, then `FEED_SAME_AS_LAST` (16 ink_muted, a 16 pt accent ✓ before it), then Close ✕ 48 at the right. If they don't fit one row, the caption takes a second header line (+24) | 56 |
| 1 | Hooch | hooch ≥ 0.10 | Inline row: `FEED_STEP_HOOCH` + 2 tiles (`FEED_HOOCH_POUR`, `FEED_HOOCH_STIR`). First, because it is the first physical step | 44 |
| 2 | Schedule | always | `FEED_SCHEDULE_QUESTION` above (22 + gap 8), then 3 tiles: answer title (`FEED_OPTION_*_TITLE`, centered, ≤ 2 lines) over the ratio (`preview` ratio text, a value like the grams, no key). All 3 share the tallest height | 108 |
| 3 | Flour | 2 or more flours unlocked | `FEED_STEP_FLOUR` above, then one row of equal tiles (`FLOUR_*`, ≤ 2 lines). Order: `white_bread`, `whole_wheat`, `rye`, `spelt`. One flour means no choice, so no row | 74 (2 flours) / 86 (3 or 4) |
| 4 | Water | hydration unlocked | Inline row: `FEED_STEP_HYDRATION` + 3 tiles (`HYDRATION_STIFF`, `_STANDARD`, `_LOOSE`) | 44 |
| 5 | Note | a note applies | One slot, 16 ink_muted, ≤ 2 lines, 12 above. Priority: refusal reason, fit line, early or rescue note, routine hint, then `FEED_HOOCH_NOTE` (only while the hooch row shows) | 0 / 34 / 56 |
| 6 | Footer (pinned) | always | 12, then the result block: `FEED_DISCARD_LINE` and `FORECAST_LINE` (16 ink, 22 each, 2 apart; the forecast hides when there is none, as in the fridge), then 12, then Mix 56, then safe bottom + 8 | 168 (17e) / 134 (SE) |

**Inline rows.** Hooch and Water share one label column, as wide as the wider label (16 semibold, ink, vertically centered), then 12 pt, then the tiles. If the column + 12 + every tile at its label width + 16 doesn't fit the row, that row's label goes above it instead, like Schedule and Flour. At Largest text, labels always go above.

**Fit at 100% text** (cap from §3: 629 on the 17e, 479 on the SE):

| Case | 17e 390 × 844 | SE 375 × 667 |
|---|---|---|
| Tour and first days: 1 flour, no water | 336 (40%) | 302 (45%) |
| 2 flours (day 1 on) | 426 (50%) | 392 (59%) |
| Everything unlocked | 498 (59%) | 464 (70%) |
| Everything + a 2-line note | 554 (66%) | 520: scrolls 41 |
| Everything + hooch | 558 (66%) | 524: scrolls 45 |
| Everything + hooch + a 2-line note (worst) | **614 (73%), fits** | 580: scrolls 101 |
| 2 flours + hooch (a once-a-day player in week 1) | 486 (58%) | 452 (68%) |

So on the 390 × 844 target, every case fits above the fold at 100%. On the SE, the everyday cases fit, and only an unlocked-everything sheet with hooch or a note scrolls. The overflow cue (§3) shows it, and Mix and the result block stay pinned.

**Larger text.**

| Text size | Sheet | What happens (390 × 844) |
|---|---|---|
| Large 125% | Fit sheet, same cap | Tiles grow (schedule 93, flour 64). The Water row stays inline ("Water" is 44 pt at 20 pt; the old "Hydration" would have pushed it above). Everything unlocked fits at 568. Hooch or a note makes it scroll, up to about 63 pt in the worst case |
| Largest 150% | **Full sheet** (screen − safe top − 12). The jar is hidden while it's open: at this size, reading comes first | Caption on its own header line. Every label goes above its row. Tiles: schedule 108, flour 74, water 48. Everything unlocked fits (697 of 785). The worst case scrolls about 53. On the SE, everything unlocked scrolls about 28 |

Tile labels never ellipsize and never shrink below the type scale. Schedule titles stay inside the tile at 150% on the SE ("Tomorrow" is 84 pt at 24 pt, the tile's inner width is 90).

### 8.2 Behavior

- **Smart defaults.** Every control opens on last time's value, so "feed like last time" is Feed → Mix (2 taps). There's no separate repeat button. "✓ Same as last time" shows while the current choices **equal** last time's (ratio, flour, water, hooch). It's recomputed on every change, so changing back brings it back. The very first feed uses onboarding's choices.
- **What a tap updates.** The tile's selected state (120 ms), the result block, the note, the caption, and T2's ghost band line on the jar. Light haptic. Nothing reflows: a tile's size never changes when selected.
- **Newly unlocked options.** A new flour or water tile shows a 10 pt "new" dot (the pill's dot) at its top-left until it is first selected.
- **Mix is a plain tap.** We never require a hold, for motor accessibility. When the preview has a refusal reason, Mix is disabled and the reason fills the note slot.
- **Coach marks (onboarding B7)** sit in the jar band above the sheet and point down into it, so they never cover a tile (§14.4).
- **Tactile sequence after Mix.** The sheet slides down. From the second feed on, a "Skip" pill appears, and tapping anywhere skips to the end. The final haptic still plays. The first feed always plays in full, because it teaches the steps (game-mechanics §2.6).

| # | Beat | Duration | Feel | Haptic |
|---|---|---|---|---|
| 1 | Hooch: pour off or stir in (only if present) | 0.6 s | thin pour from the lip | light |
| 2 | Scrape the discard into a bowl | 0.8 s | spoon scrape, starter stretches | light at release |
| 3 | Scoop flour in | 0.9 s | flour puff on landing | medium at landing |
| 4 | Pour water | 0.8 s | glug | 3 × light, 150 ms apart |
| 5 | Stir. The player may circle-drag on the jar to stir faster (optional) | 1.2 s | spoon swirls, paste smooths | light tick every 180 ms |
| 6 | Settle. The band snaps on at the new level | 0.5 s | surface flattens, band snaps | firm |

That totals about 4.2 s without hooch, and 4.8 s with it. The first feed runs at about 6 s, and later feeds at 4.2 s (D-023). Afterward:
- The status changes to `freshly_fed`.
- A result card shows the plain-words forecast from the sim (`FORECAST_LINE`). Its body is a fuzzy time, with no digits.
- The forecast also becomes the status hint, in its short form, until the rise is well under way (§11.1).
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
- An optional "what this means" line (≤ 90, ink_muted), shown the first 3 times for each descriptor and then dropped (game-designer, narrative-designer). After that, the `SMELL_MEANING_BTN` ("What it means") TextButton in the card's button row brings it back with 1 tap: the line appears under the body and the button hides. A `musty` meaning line never fades, and it always says it's a warning sign. With two TextButtons in the row, "What it means" is on the left and Inspect on the right.
- **Smell check** (the rule is the scientist's, sim spec §13.1, `smell_check(state, env)`):

| `check` | Card adds | Why |
|---|---|---|
| `faint` (every non-musty smell below 0.30: the fridge, or early in some rises) | `SMELL_TRY_INSPECT` as the last body line, plus the `SMELL_TRY_INSPECT_BTN` TextButton in the button row | The nose can't settle it; the surface can |
| `musty` (mold_risk ≥ 0.3) | The Inspect button only, **never** the "Hard to say" line | "Hard to say" would soften a warning. The musty meaning line already says to check the surface |
| `""` (a clear smell, or moldy) | Nothing | |

  The Inspect button closes the card and opens the inspect sheet straight on the `surface` result (2 taps from the main screen: Smell → Inspect). The `faint` line set (cold or mild) is narrative's (game-copy §5.1).
- At 150% text the card can reach about 340 pt on an iPhone SE, and it scrolls past the jar region's height.

The Phase 1 "ambiguous pairs" table is gone: it ran the other way (states that look alike but smell different). The scientist's matching "Smell it" button on inspect results (sim spec §14, "Inspect to smell") is **dropped**: it has no copy and isn't on the board, and the status pill already names the state (§10).

**Delight and safety:**
- On the first smell of each new descriptor, the card shows a "New smell" ribbon (icon + word) and writes a journal entry.
- `musty` and the `unhealthy` smells use the care tone on the card's icon, and the body says what to do (feed today).
- The card is dismissed by tapping anywhere or any action. It auto-hides after 8 s unless "Keep messages on screen" is on.
- The smell moment can't be interrupted. Events queue.
- Reduce motion: no dolly and no wisp motion. The wisps fade in place, and the moment shortens to 600 ms.

---

## 10. Inspection

Inspect opens a peek sheet with a 2-column chip grid. The slice had the 3 P0 chips. Phase 4 adds `consistency` and `development` once unlocked (stage `steady`, progression §3), so the grid holds 3 or 5 chips.

Tapping a chip moves the camera (500 ms, ease-in-out cubic). The camera then holds on the cue for 1.0 s before the result text fades in: look first, then read. game-mechanics allows up to 3 s, and a tap anywhere shows the text at once. The back arrow ‹ (48 pt) or another chip returns to the grid.

```
┌─────────────────────────────────────┐
│ ▬▬                                  │
│ Inspect                         (✕) │
│ [ ◌ Bubbles      ] [ ↕ Height      ] │  2 equal columns, (350 − 8) / 2 = 171 × 48 on 390
│ [ ◠ Surface      ] [ ≈ Consistency ] │  icon 24 (inspect_*_outline; filled when chosen) + label
│ [ ✦ Development  ]                   │  the 5th chip sits in the left column
│ [              Done              ]   │
└─────────────────────────────────────┘
 result view:  ‹ Bubbles                                         ← back row 48
               Lots of small bubbles all the way up the glass.   ← observation, ink 16, ≤ 90
               It's busy and rising.                             ← meaning, ink_muted 16, ≤ 90 (first 3 views)
                  (or, after 3 views:)
               [What it means]                                   ← TextButton, SMELL_MEANING_BTN
               [ Feed now ]                                      ← only when opened from warning_signs
```

**Chips (Phase 4).**

| Rule | Value |
|---|---|
| Order | `bubbles`, `height`, `surface`, `consistency`, `development`: P0 first, then P1 in unlock order. Locked kinds are not shown |
| Size | 2 equal columns, 8 apart, 48 tall at 100%. Labels may wrap to 2 lines at 150% ("Development" is 115 pt at 24 pt), and the chip grows |
| Sheet height | 42%, or the grid's content height if taller, whichever is larger: 322 pt on the 17e (fits in 354), 288 on the SE (just over 42% = 280). The result view keeps that height, so the sheet never jumps between grid and result. A long result scrolls |

**"What it means" (Phase 4).** Inspect meanings fade after 3 views, like smell's (mechanics §5). The control matches the smell card's:

| Rule | Value |
|---|---|
| When | The readout has a meaning, it has been seen more than 3 times, and it isn't a warning or mold line (those never fade, so they never get the button) |
| Control | TextButton, `SMELL_MEANING_BTN` ("What it means"), height 44, left-aligned, directly under the observation, where the meaning would be. Same key, style and behavior as the smell card |
| Tap | The meaning line fades in where the button was (180 ms; height grows 180 ms `CUBIC` `EASE_OUT`), and the button hides. Reduce motion: instant. Light haptic |
| Lasts | Until the player leaves this result (‹, another chip, Done). Coming back shows the button again |
| Counting | A reveal is not a view and doesn't reset the fade |
| Taps | Inspect → chip → "What it means" = 3 |
| Timing | The button fades in with the observation, after the 1.0 s camera hold |

**Opened from `warning_signs`** ("Look first"):
- The inspect sheet replaces the attention sheet and goes straight to the `surface` result.
- The result says what the sim shows, then the check rule: fuzz or color means discard, and none means feed.
- A primary "Feed now" button swaps this sheet for the feed sheet.
- Closing without feeding is allowed. The status pill keeps showing `unhealthy`, and the attention event isn't shown again.

| Kind | Camera target | Framing | Extra animation |
|---|---|---|---|
| `bubbles` | Glass wall, the side facing the light. Fixed distance 0.36 m and a fixed direction (yaw −28°, pitch 4.4°), so bubbles appear at the same scale in every state, because bubble size is one of the cues the player reads. Target y = max(floor + 0.55 × level × rise, starter_top_y − 0.028). It stays at mid-paste until the paste gets tall, then rises so the cap stays in view (art-direction §18.7) | Close-up, glass about 70% of the width, fitted to the visible band between the HUD plate and the inspect sheet (195 to 340 pt tall, 31 to 36% of the screen). The frustum shift centers the target in the band. art-director checked it with a masked SE render at `freshly_fed`, `at_peak` and maximum rise: the whole cap stays inside the band | Glass focus pull, bubbles in sharp focus |
| `consistency` | Jar mouth, from 50° above | Medium | A spoon lifts a strand and lets it fall |
| `height` | Side view at the band | Medium, band and top both in frame | Band glints, a faint guide line rises from band to top |
| `surface` | Into the mouth from **76°** pitch, a preset beyond the free-orbit cap (art-director's proposal, art-direction §15). The sight line clears the lip when tan θ ≥ (170 − h) / 34 mm, where h is the cap height. At 60° that needs h ≥ 111 mm, which no state reaches, so the view went through two layers of glass. At 76° it needs h ≥ 33.6 mm, so the top is visible at every level above that. art-director confirmed the lowest cap is about 36 mm (`unhealthy` and `moldy`, rise 0.95), with freshly_fed at 39 mm, so 76° holds at every level. Fall back to 78° (h ≥ 10 mm) only if the sim ever drops rise below about 0.87 | Close-up | Lid lifts away |
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
3. **The jar itself.** Each state's cues come from the scientist's draft. The rubber band at the fed mark makes rise readable at a glance with no number. It's decided in D-023, and it's a real baker's habit.

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
| `unhealthy` | wilted sprout | care (deep honey, 3 pt border, filled icon) | dull dry skin, thick dark hooch, flat, almost no bubbles | Warning signs. Look, then feed |
| `moldy` | octagon with ! | stop (filled pill, cream word) | fuzzy spots. No pink or orange tint in the MVP (D-026) | Mold. Please discard it. |

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

### 11.1 The forecast as the status hint (Phase 4)

**Problem.** T3 shows the forecast as the hint only while `freshly_fed`, which at 22 °C after 1:1:1 lasts about 0.3 h (sim spec, state table). And `FORECAST_LINE` ("It should be at its best {window}.") reaches 44 characters with "tomorrow afternoon", so it wraps in the 34-character hint slot and grows the HUD.

**Rule.**

| Item | Rule |
|---|---|
| When | The hint shows the short forecast while the status is `freshly_fed`, `developing` or `active` **and** `Session.get_forecast_window_key()` is not empty. Otherwise it shows the state's own hint |
| How long | At 22 °C after 1:1:1, from the feed to about 4.9 h, out of a peak at about 6.1 h (sim spec, state table). That is the stretch when "when?" is the question and the jar changes slowly |
| Then | At `near_peak`, the state's hint returns ("Rise slowing, dome forming"). Near the peak the jar is the best guide, and that hint teaches the dome cue. `at_peak` and later have no future peak |
| Not shown | `recovering` keeps its own hint, because it explains why the rise is weaker. `dormant`, `hungry`, `unhealthy` and `moldy` have no forecast (mechanics §6) |
| Change | The hint changes with the status-change animation (§15), at the same moment as the pill |
| Elsewhere | Unchanged: the long `FORECAST_LINE` stays on the feed result card, in the feed sheet's result block (60 slot), and in the status explainer during every rise phase |
| Copy | A new short key, `FORECAST_HINT`: "At its best {window}" (Max 34; worst case "At its best tomorrow afternoon", 30). No trailing period, like the other hints. Added by narrative (§18.1). The long `FORECAST_LINE` never goes in the hint slot |

**Hint slot rule (all keys).** The hint never wraps at 100% text, and takes at most 2 lines at 125% and 150% (§18). The copy checker's Max 34 is the guard, so every key that can fill the slot, including `FORECAST_HINT` with every `WINDOW_*`, has Max 34. QA's layout test renders each one at 360 pt width and 100% text and asserts 1 line.

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
| `warning_signs` | attention. Primary (bottom): "Look first", which opens the `surface` check (§10). Secondary: "Feed it now" (narrative-designer, after the scientist's safety review) |
| `mold_found` | attention. Built in the slice behind the debug time scale (D-017) |

**`mold_found`** (events-catalog §4.9, game-mechanics §1, D-023):
- When the sheet opens, the camera moves to a close-up of the colony.
- Primary: "Discard it". The sheet's content is replaced by a confirmation: "Discard {name}?", with the buttons "Discard" and "Not yet" (`MOLD_CONFIRM_*`). "Discard" starts the ceremony: the jar is emptied and washed, a memorial page is added to the journal, and a fresh start is offered (narrative.md §9.2).
- Secondary: "Not yet". It closes the sheet so the player can look and read.
  - Inspect and Journal still work.
  - The discard card (§4) stays above the bar until the player discards.
  - There's no Close X.
- Discarding from the main screen takes 2 taps: "Discard it" on the card, then "Discard" in the confirmation.

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

**Phase 4: 5 places.** A fit sheet (§3), so the jar stays in view while it moves and the light changes.

```
 390 × 844, 100% text, all 5 unlocked, proofing box selected (sheet 454 pt, 54%)
┌─────────────────────────────────────┐
│ ▬▬                                  │
│ Where it lives                  (✕) │  header 56
│ ┌─────────┐ ┌─────────┐ ┌─────────┐ │  OptionCards, 3 across, 111 × 112, 8 apart
│ │ Fridge  │ │ Window  │ │ Counter │ │  label 16 semibold (≤ 2 lines)
│ │A long   │ │ sill    │ │Usual    │ │  sub LOC_*_SUB, ink_muted 16
│ │ pause   │ │Slower   │ │ pace    │ │
│ │  4 °C   │ │ rise    │ │ 22 °C   │ │  PLACE_TEMP_C
│ └─────────┘ └─────────┘ └─────────┘ │
│ ┌─────────┐ ┌─────────┐             │  row 2, left-aligned
│ │Warm spot│ │Proofing✓│             │  selected: 3 pt accent border + ✓ badge
│ │ Faster  │ │ box     │             │
│ │ 26 °C   │ │ 28 °C   │             │  shows the dial's value
│ └─────────┘ └─────────┘             │
│ Warmth          [ − ]  28 °C  [ + ] │  only while proofing box is selected: 12 + 48
│ [              Done               ] │  footer 12 + 52 + safe bottom + 8
└─────────────────────────────────────┘
```

| Rule | Value |
|---|---|
| Order | Cool to warm, so the grid reads like a thermometer and teaches "warmer is faster" without a number: `fridge`, `window_sill`, `counter`, `warm_spot`, `proofing_box`. Locked places are not shown (progression §3), so the slice's 3 read Fridge, Counter, Warm spot |
| Grid | 3 across at 100% and 125%, 2 across at 150%. The last row is left-aligned. Every card in a row shares the tallest height |
| Card | OptionCard (§17): label `LOC_*`, sub `LOC_*_SUB`, temperature `PLACE_TEMP_C`. Text only, no illustration in the MVP |
| Selected | 3 pt accent border + ✓ badge. Never color alone |
| Apply | A tap applies at once, with no confirmation. The jar moves to its spot behind the sheet and the light shifts (art §19). The first fridge move fires `off_to_nap` after the sheet closes |
| Proofing box dial | Appears under the grid while `proofing_box` is selected: `PLACE_DIAL_LABEL` at the left, a Stepper (§17) at the right, 24 to 30 °C in 1 °C steps, value `PLACE_TEMP_C` (20 semibold). The sheet grows by 60 pt over 220 ms `CUBIC` `EASE_OUT` (reduce motion: instant). The new value applies 300 ms after the last step, so holding + sends one action. At 24 or 30, that button is disabled and gives a light tick. Many quick changes merge into one journal line (OD-22, T1) |
| Heights at 100% | 17e: 3 places 274 (32%); 5 places 394 (47%); with the dial 454 (54%). SE: 5 with the dial 420 (63%), under its 479 cap |
| Larger text | 125%: labels like "Proofing box" and "Window sill" wrap; cards about 153 tall; 5 + dial = 536 on the 17e. 150%: 2 across, 3 rows of about 118; 5 + dial = 600 on the 17e (under 629). The SE scrolls at 150% |
| Taps | Move to the fridge: Place → Fridge → Done = 3. Proofing box at 28 °C: Place → Proofing box (opens at its last value, default 26) → + → + → Done = 5 |

- Temperature is read-only and shown in °C next to a word on the card (the sub). °F is P2.
- Humidity, containers and covers stay out of the MVP (D-018, D-019).

---

## 14. Journal, settings, onboarding

### 14.1 Journal and traits

The journal is a full sheet: a **starter card** at the top, then the timeline grouped by day (feeds, smells, inspections, events, away summaries, memorials). Advanced numbers live here, never on the main screen.

```
┌ Journal ─────────────────────── (✕) ┐
│ ╭─────────────────────────────────╮ │  starter card: surface_alt, radius 20, padding 16
│ │ Bramble                         │ │  name, Fraunces 30 (display), auto-fit (§17)
│ │ Since Nov 6, 2026               │ │  JOURNAL_CHAPTER_SINCE, ink_muted 16
│ │ The patient type              › │ │  trait row, 44 tall. Only after the reveal
│ │ [ Rename ]                      │ │  SecondaryButton, JOURNAL_RENAME_BTN
│ ╰─────────────────────────────────╯ │
│ Nov 26, 2026                        │  timeline
```

**Where a revealed trait shows** (traits change wording only, never biology, narrative §7.1):

| Place | What | Copy |
|---|---|---|
| The reveal | The `trait_revealed` info toast, with a › that opens its journal entry | `TRAIT_*_REVEAL_TOAST`, `TRAIT_*_JOURNAL_TITLE` / `_BODY` |
| The journal's starter card | One row: the trait's title, ink 16 semibold, with a › chevron. A tap scrolls the timeline to the trait entry and flashes it (surface_alt, 600 ms; reduce motion: scroll only). If the entry was dropped by the journal cap, the row has no chevron and does nothing. After a drift (progression §5), it shows the new dominant trait | `TRAIT_*_JOURNAL_TITLE` |
| The memorial page | The "Character" stat | `MEMORIAL_STAT_TRAIT`, `TRAIT_*_NAME` |
| Wording | The trait variants narrative lists (feed reaction, `off_to_nap`, fridge-out, `peak_now`, epitaph) | narrative §7.3 |
| **Never** | The main screen, the status pill, hints, smell, inspection, warnings | progression §8 |

Before the reveal there is no trait row at all, never an "unknown" placeholder.

### 14.2 Rename

| Step | Spec |
|---|---|
| Open | Journal → Rename. The rename page **replaces** the journal's content (no sheet over a sheet). Header: ‹ (48) and `JOURNAL_RENAME_TITLE` |
| Field | TextField, prefilled with the current name, all text selected, keyboard open at once (the player came here to type). Max 16 characters after trimming, the same character filter as naming (narrative §6.1) |
| Buttons | `NAME_BTN_SUGGEST` (TextButton) under the field. `NAME_BTN_CONFIRM` (primary) pinned at the bottom, which sits on top of the keyboard while it is open. The return key also confirms |
| Empty or unchanged | Confirm keeps the current name, writes nothing and goes back. Never an error |
| Confirm | `RenameAction`, then the journal line `JOURNAL_LOG_RENAME`. Back to the journal: the new name on the starter card crossfades in (250 ms + one 1.06× pulse; reduce motion: crossfade only) with a medium haptic. No toast, because the journal is still open |
| Back | ‹ or a swipe down returns to the journal with no change |
| Taps | Journal → Rename → (type) → "That's its name" = 3 + typing |

Rename lives only in the journal, the starter's own page (narrative §6.1). Settings has no rename row.

### 14.3 Settings

Full sheet, one row each, in this order. Dividers (outline, 1 pt) separate the 3 groups, with no section titles, so no new copy.

| # | Row | Control | Key | Default | Behavior |
|---|---|---|---|---|---|
| 1 | Text size | 3 chips | `SETTINGS_TEXT_SIZE`, `_STANDARD`, `_LARGE`, `_LARGEST` | Standard | As built |
| | divider | | | | |
| 2 | Sound | Toggle | `SETTINGS_SOUND` (**new**) | On | Mutes or unmutes the master bus. When off, the Volume row is disabled (dimmed); the toggle above is its visible reason |
| 3 | Volume | Slider, under its label, full row width | `SETTINGS_VOLUME` (**new**) | **100%** (sound-designer: the set is already mixed quiet, about −21 LUFS at its loudest, so the phone's own volume buttons are the main control) | 0 to 100% in 10% steps, linear to dB on the master bus. Each step while dragging plays `ui_tick` (`Bus.feedback(&"tick")`) and a light haptic if Vibration is on. On release it plays `glass_tink` (`Bus.feedback(&"preview")`, no haptic), so the player hears the level. No number shown |
| 4 | Vibration | Toggle | `SETTINGS_HAPTICS` ("Vibration") | On | Turning it on plays one medium pulse and `ui_toggle_on` as a preview. Off means no `vibrate_handheld` call at all |
| | divider | | | | |
| 5 | Reduce motion | Toggle | `SETTINGS_REDUCE_MOTION` | Off | As built |
| 6 | Keep messages on screen | Toggle | `SETTINGS_KEEP_MESSAGES` | Off | As built |
| 7 | Time-lapse on return | Toggle | `SETTINGS_TIME_LAPSE` (**new**) | On | The existing `show_time_lapse` field. Off still shows the summary card |
| 8 | Warning alert | Toggle + one note line | new, deferred | Off | Only once D-057's iOS plugin is wired. Turning it on is the only thing that asks for iOS notification permission: never at launch, never in onboarding |
| | Done | SecondaryButton, pinned | `UI_DONE_BTN` | | |

- **Settings fields** are T1's, as T1 built them: `sound: bool = true` and `master_volume: float = 1.0` (0 to 1). data-models §9.1 should match T1's names.
- **Sounds** for every new Phase 4 haptic moment are in `audio-direction.md` §3 (sound-designer).
- **iOS audio session: Ambient.** The game obeys the ring/silent switch and mixes with the player's own music or podcast, as a calm game should. sound-designer found `audio/general/ios/session_category` (with Ambient) and `audio/general/ios/mix_with_others` in the 4.7.2 binary's strings (read, not run). T1 sets it in `project.godot`. The silent-switch behavior still needs the iPhone.
- Slider: track 6, thumb 28, hit area 48 tall (§17). Disabled: track and fill in the disabled color.
- Out of Phase 4: "Replay tutorial" (cut, §20), "Erase all data" and a credits and licenses page (Figtree's OFL text must ship, so that page is needed before a store release; §20).
- There are no accounts.

### 14.4 Onboarding, beats B1 to B8

The beats, their order and the words are game-designer's and narrative's (game-design §3, narrative §8). Play order: B1, B2, B3, B5, B6, B4, B7, B8. Target: under 7 minutes, 11 taps minimum, one thing at a time.

**What the jar is.** Before naming, the session holds an unnamed starter. During B1 to B5 it must look and smell **freshly fed** (M. fed it shortly before): flat and smooth at the band, `wet_flour`, a few small bubbles, because B3's and B5's coach lines describe that (narrative §8 setup). B6 plays `Demo.run()` on a **temporary copy** (architecture §5.5). B4's confirm adopts the copy's at-peak state and creates the save. How T1 provides the freshly fed tour state is T1's call (§20).

**Tour-wide rules.**

| Rule | Spec |
|---|---|
| HUD | The unnamed variant (§4) until B4. The pill is inert and shows no "new" dots during the tour. The ⚙ stays usable, so text size can be set at any point |
| Pages | Onboarding pages are fit sheets with no ✕ (they must be answered). The header's right slot holds the ⚙ (48) instead. It swaps the page for Settings and restores the same page when Settings closes (no sheet over a sheet) |
| Action bar | Visible from B2. Buttons the current beat doesn't use are dimmed to 40% and inert. Tapping one shakes the current coach mark (6 pt, 200 ms; reduce motion: the ring flashes once). From B8's journal coach on, the bar is fully active |
| Events | Held until the tour ends (treated like an open sheet, §12) |
| Coach marks | §17 CoachMark. One at a time. **Do** coaches ("Tap Smell") advance when the player does it. **Read** coaches advance on a tap anywhere, or after 2.5 s + 70 ms per character (at most 7 s). With "Keep messages on screen" on, only on a tap. While a read coach shows, a full-screen `STOP` layer takes that tap, so it never also pokes or orbits (like the time-lapse skip layer, architecture §9) |
| Placement | Never over the starter. Over the main screen: in the card slot above the bar, or the toast slot under the HUD when a card is up. With a sheet open: in the jar band just above the sheet, with no pointer; the target inside the sheet gets the spotlight ring |
| Skip tour | A TextButton on every coach mark (`ONBOARD_SKIP_TOUR_BTN`, **new**), and the tertiary button on the B6 page. Not on B1 (it has "I know starters") or B4 (one tap confirms) |

**Beats.**

| Beat | Screen and layout | The jar | Advances when | Taps |
|---|---|---|---|---|
| **B1 Arrival** (0:00) | No HUD and no bar at first. At 1.6 s the note page rises: `ONBOARD_NOTE_TITLE`, `_BODY`, secondary "I know starters" above primary "Show me around" (both E zone) | Freshly fed, breathing. The camera starts at yaw −25°, pitch +20° and eases home over 2.4 s, `SINE` in-out (inside the orbit limits, so the kitchen wall covers it, D-049). A folded note under the band is not built this round (§20). Reduce motion: starts at home, the page fades in at 0.6 s | Either button | 1 |
| **B2 Look** (0:20) | HUD (unnamed) and the bar fade in (300 ms). Do coach `ONBOARD_LOOK_COACH` in the card slot, with a drag cue: a 24 pt surface dot sliding 60 pt left and right twice (reduce motion: static ‹ › icons) | Orbit, pinch, pokes and tinks all work | 90° of total orbit (summed), or 10 s. Then the read coach `ONBOARD_LOOK_DONE` | 0. Gestures are optional (§16) |
| **B3 Smell** (0:50) | Do coach `ONBOARD_SMELL_COACH`; spotlight on Smell, which pulses 1.0 to 1.06 every 1.2 s (reduce motion: ring only) | The smell moment (§9): lid tips, slow lazy wisps | The `wet_flour` card shows with its meaning line and "New smell" ribbon, and no auto-hide in the tour. 1.5 s later the read coach `ONBOARD_SMELL_AFTER` shows in the toast slot. A tap anywhere dismisses both | 2 |
| **B5 Inspect** (1:20) | Do coach `ONBOARD_INSPECT_COACH` on Inspect. In the sheet, the spotlight moves to Bubbles; other chips are dimmed and inert | The `bubbles` close-up (§10): a few small bubbles | The result shows (observation + meaning). Done, ‹ then Done, or a tap above | 3 |
| **B6 Time-lapse** (1:50) | Page: `ONBOARD_TIMELAPSE_TITLE`, `_BODY`, primary `_BTN` ("Watch"), tertiary "Skip tour". Then the demo: the HUD shows each frame's status (pill and hint change with the status animation and a light haptic); a `ONBOARD_TIMELAPSE_BADGE` ink plate centered under the HUD; a Skip pill (`FEED_SKIP_ANIM_BTN`) in the card slot; the bar is dimmed | Demo frames from the band to the peak: bubbles grow, a dome forms, the band stays put, the light follows the demo's clock. 90 to 120 s (BT-12). **Orbit and pinch stay on** (unlike the return time-lapse; T2). At `at_peak` it stops, idles, and the camera eases to the `height` framing (500 ms). Skip: a 400 ms crossfade to the peak frame | The read coach `ONBOARD_TIMELAPSE_PEAK`, pointing at the dome. The demo marks no state as seen | 1 (+1 to skip) |
| **B4 Name** (3:50) | Page: `NAME_TITLE`, `NAME_BODY`, the field prefilled with the first suggestion. The keyboard does **not** open by itself, so the peak stays in view and 1 tap accepts. Tapping the field opens it with the text selected. Primary `NAME_BTN_CONFIRM`, TextButton `NAME_BTN_SUGGEST`. ("Pick for me" is only after a discard, D-047) | Holding at the peak | Confirm: `Session.adopt_starter(state, name)`, the save is made. The HUD's name row grows in (280 ms) with the name. `NAME_DONE_TOAST`, medium haptic | 1 |
| **B7 First feed** (4:30) | Do coach `ONBOARD_FEED_COACH` on Feed (only while `at_peak`). The tour feed sheet: schedule tiles only, "In a few hours" preselected (336 pt on the 17e, §8.1). Read coaches in the jar band: `ONBOARD_FEED_DISCARD` (ring on the discard line), then `ONBOARD_FEED_SCHEDULE` (ring on the tiles). They never block Mix | Ghost band line on the jar for the chosen answer. After Mix, the full first-feed sequence (about 6 s, no Skip, §8). During the settle beat the camera holds the `height` framing | The read coach `ONBOARD_FEED_DONE`, pointing at the band | 2 (+1 to change the answer) |
| **B8 Handoff** (6:00) | Page: `ONBOARD_HANDOFF_TITLE`, `_BODY` (with the forecast's `{window}`), primary `_BTN`. Then read coaches `ONBOARD_HANDOFF_FRIDGE` (spotlight on Place) and `ONBOARD_HANDOFF_JOURNAL` (spotlight on Journal). The bar goes fully active with the second | Freshly fed at the new band. The hint shows the forecast (§11.1) | The last coach. The tour ends: events are released and "new" dots begin. T1 writes the Day one page | 1 |

**Skip paths.**

| From | "Skip tour" does | Onboarding path |
|---|---|---|
| B1 | "I know starters": B4 naming → the B7 feed sheet with no coaches (an at-peak starter, mechanics §8.1) → `ONBOARD_SKIP_DONE` toast. Unlocks every P0 and P1 option (progression §3). 3 taps | `skip` |
| B2, B3, B5, or B6 before the peak | Closes any card or sheet, then the same as B1's skip | `skip`. Whether this also unlocks everything is an open decision (§20); I recommend not |
| B6 at the peak | B4 → B7 with no coaches | `tour` (the player watched the rise) |
| B7, B8 | Removes the remaining coaches. The open sheet or page stays | unchanged |

**Interruptions.**

| What happens | Result |
|---|---|
| Background or kill before B4 | Nothing is saved (`is_first_run()`). The next launch starts at B1 |
| After B4, before the first feed | Next launch: if the starter is still `at_peak`, resume at B7 with its coach. Otherwise end the tour, because no coach may say "at its peak" when it isn't. The return flow runs as usual |
| During or after B7 | The rest of the tour is dropped |

### 14.5 The empty jar

The empty jar is a real state (D-059): the discard is committed at "Discard", and "Not today" on the restart page leaves a clean jar.

| Part | Spec |
|---|---|
| Reached by | The restart page's `RESTART_BTN_LATER` ("Not today"), or launching while empty. No time-lapse and no away summary: nothing happened |
| HUD | The empty variant (§4): `EMPTY_JAR_TITLE` in the name row, ⚙, no pill, no hint |
| Jar (art-director, confirmed) | Clean, washed, empty glass with the lid on. No band, no starter, no streaks, no breathing or bubbles. T2 hides the starter, liner and band, so no new asset. The jar **stays in its current place** (an empty jar in the proofing box still shows the box), with the same light. Orbit, pinch, double-tap reset and glass tinks work. Day and night continue |
| Card | Above the bar, can't be dismissed (like the discard card, §4). Body `EMPTY_JAR_BODY`, primary `RESTART_BTN_YES` ("Start again"). It rises 600 ms after the restart page closes (card in, 280 ms) |
| Action bar | Feed, Smell, Inspect and Place are locked: dimmed with the 12 pt lock badge, as for `moldy`. A tap shows the toast `REASON_EMPTY_JAR` (**new**). Journal works: the closed chapter and its memorial page |
| Events | None. There's no starter |
| Start again | Opens naming in its restart version: `NAME_BTN_PICK` ("Pick for me") picks the current suggestion and confirms in 1 tap (D-047). The restart story page is not shown again: the player already read it before choosing "Not today" |
| New starter | The jar fills: a 600 ms crossfade from empty to the new starter with `starter_new` (0.9 s, played by T2 from the fill animation), then the band snaps on with `band_snap` and a firm haptic. Reduce motion: a 300 ms crossfade. First restart: M.'s spare, cold `dormant`; later ones: a friend's spoonful at its peak (mechanics §8.2). The HUD returns to normal |
| Taps | "Start again" → "Pick for me" = 2 |

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
| **Phase 4** | | | |
| HUD tuck out / back (§3) | 180 ms, fade + 12 pt rise / 240 ms | `CUBIC` in / out | fade only, 120 ms |
| HUD variant height change (§4) | 280 ms | `CUBIC`, `EASE_OUT` | instant |
| ChoiceTile select (§8) | 120 ms color; press 0.96× (80 / 120 ms) | `QUAD`, `EASE_OUT` | instant, color only |
| Fit sheet height change (place dial, §13) | 220 ms | `CUBIC`, `EASE_OUT` | instant |
| "What it means" reveal (§10) | 180 ms fade + 180 ms height | `CUBIC`, `EASE_OUT` | instant |
| Coach mark in / out | 220 ms fade + 8 pt rise / 160 ms fade | `CUBIC` out / in | fade only |
| Spotlight ring | scales 1.15× to 1.0× over 300 ms, then opacity 100% to 60% and back every 1.6 s | `CUBIC` out, then `SINE` | static ring |
| Onboarding B1 camera | 2,400 ms from yaw −25°, pitch +20° to home | `SINE`, `EASE_IN_OUT` | starts at home |
| B6 demo skip | 400 ms crossfade to the peak frame | linear | same |
| Empty jar fills (§14.5) | 600 ms crossfade, then the band snaps | linear, then `BACK` out | 300 ms crossfade |

**Reduce motion** turns off decorative and camera motion: dollies, inertia, idle drift, slides, pulses, wisp motion, parallax and ambient motes. It keeps sim-driven content: the starter rising, bubbles and hooch. That content is information, and it moves slowly.

**Haptics** (the setting defaults on). `Input.vibrate_handheld(ms, amplitude)`. The amplitude argument has existed since Godot 4.3. Android needs the VIBRATE permission.

| Level | Call | Used for |
|---|---|---|
| light | 10 ms, 0.3 | taps, chip select, stepper ticks, stir ticks, pokes |
| medium | 20 ms, 0.6 | flour landing, smell inhale peak |
| firm | 35 ms, 1.0 | band snap (feed complete), discard ceremony |

**iOS levels are judged on the user's iPhone 13 Pro in Phase 4 (D-059).** iOS amplitude is untested. If the three levels don't feel distinct there, iOS keeps the medium and firm moments as one fixed pulse and skips the light cues, and an iOS haptics plugin is considered only if that feels poor (D-059). Every haptic moment also has a sound, so players with haptics off lose nothing. Phase 4 adds: a light tick per volume step, a medium pulse when Vibration is turned on, a medium pulse on naming, a light tick per status change in the B6 demo, and a firm snap when the empty jar fills.

---

## 16. Accessibility

| Requirement | Spec |
|---|---|
| Touch targets | 48 × 48 standard, 44 × 44 absolute minimum, and hit areas never overlap. Bar slots are at least 64 × 64. The compact feed sheet's inline tiles (Hooch, Water) are 44 tall, the minimum, 6 apart; every other tile is taller |
| Text size | Body is at least 16 pt at 100%. Three in-app sizes: Standard 100%, Large 125%, Largest 150% (type scale in §17). Godot 4.7.2 has no OS text-size API (spike, doctool), so the in-app setting is the only control |
| Contrast | Text ≥ 4.5:1, non-text (icons, borders, focus) ≥ 3:1. Computed in §16.1. No text sits straight on the 3D scene |
| Status | Never color alone: icon shape + word + tone (§11). Selected states add a ✓ or a filled icon. Disabled controls show a reason |
| Motion | Reduce motion setting (§15). `DisplayServer.accessibility_should_reduce_animation()` exists but is implemented only on macOS and Windows (spike), so phones get the in-app toggle |
| Haptics | Can be turned off. Never the only cue |
| Timing | "Keep messages on screen". Nothing auto-confirms. The time-lapse is skippable |
| Gestures | All optional. No required hold, multi-finger gesture or path-drag. Mix is a tap |
| Screen readers | **No screen-reader work for now (D-055, which supersedes D-012).** We stay on Godot 4.7.2. The existing `accessibility_name` labels stay as they are; new Phase 4 controls set one only where an existing key fits, with no new copy or tests for it. Everything else in this table is visible accessibility and still applies |
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

**Night surface** (the scene follows the local time of day; darkest backdrop about #1A1310, per art-director): sheets and cards switch to `surface_night` #EDE3D2 to cut glare, and the HUD plate uses it at alpha 0.94. The switch cross-fades on the same blend factor as art-director's evening preset (art-direction.md §3).

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
| ActionBarButton | ≥ 64 × 64. Fills the 72 plate (67 × 72 on 375) | icon 28 + label 14 semibold, drawn by the button itself | normal, pressed, open (filled icon + 4 pt accent pill under the label), emphasized (halo + dot badge), locked (disabled color + 12 pt lock badge; a tap shows the reason, Phase 3) |
| Plate (HUD, action bar) | HUD about 144, bar 72 | surface (or surface_night) at alpha ≥ 0.88 (0.94 at night), radius 24 / 28. Phase 4 (D-043): a soft shadow, ink at 10%, y 4, blur 16 (T3's proposal) | day, night |
| StatusPill | height ≥ 44 (it's a touch target, D-043). Accessibility name: the status word; description: `STATUS_A11Y` | surface_alt fill, tone border 2 pt, tone icon 24, ink word 17 semibold | normal, pressed, new (10 pt dot), peak glow, care (3 pt border, filled icon, #F4E4BE fill), stop (stop fill, cream word and icon) |
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
| CoachMark | ≤ 280 wide, padding 16, radius 16 | ink plate, surface text 16, a 12 pt pointer (none when it sits above a sheet). Spotlight ring on the target: 3 pt surface color with a 1 pt ink outer stroke, so it holds 3:1 on light and dark scenes. "Skip tour" TextButton inside, bottom-right, 44 tall, surface label (13.85:1 on ink) | entering, shown, shaking (a dimmed control was tapped), exiting |
| SkipPill (time-lapse, feed, B6 demo) | 48 tall | surface plate at 88%, ink 16 | shown |
| **Phase 4** | | | |
| ChoiceTile (feed sheet) | Equal widths in a row, 6 apart. Min 44 tall, padding 8. All tiles in a row share the tallest height | Rest: surface_alt fill, 1.5 pt outline, ink title 16 semibold (centered, wraps at words, ≤ 2 lines, 3 at 150%), optional sub line 16 ink_muted. Selected: accent fill, on_accent title and sub (5.81:1), a 14 pt on_accent ✓ in the top-right corner, inset 5. **Size never changes on select** | rest, pressed (0.96×), selected, new (10 pt dot top-left until first selected), disabled |
| InlinePickerRow | Label column (the widest inline label in the sheet), 12 pt gap, tiles | label 16 semibold ink, vertically centered. Falls back to label-above when the tiles don't fit, and always at 150% | n/a |
| StarterCard (journal) | Full width, padding 16 | surface_alt, radius 20. Name (Fraunces 30), since line, trait row (44, ›), Rename (SecondaryButton) | normal, trait revealed, renamed (name crossfade + pulse) |
| Plate (HUD) | Normal, unnamed and empty variants (§4) | as Plate above | shown, tucked (a sheet is open, §3) |
| EmptyStateCard | as Card | Card with body + one PrimaryButton, no title, can't be dismissed | entering, shown |

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

**Display face.** **Fraunces** is used for the starter's name and journal titles only (D-029). T3 measured it in Godot at opsz 20, SOFT 50, WONK 0, wght 600:
- 0.464 em over all 612 catalog strings, against Figtree SemiBold's 0.439 by the same method (CoreText gave 0.435). It fits the 0.47 rule.
- 0.519 em on names alone, against Figtree's 0.486.
- All 24 suggested names fit the 240 pt name row at 30 pt (widest 219).
- A 16-character name relies on the auto-fit, which shrinks it to 85% before ellipsizing at 150% text. The auto-fit is built.

For reference, other faces measured: SF 0.43, SF bold 0.46, Avenir Next 0.43, Helvetica Neue 0.43, Mariupol 0.41. A wider face means recomputing §18.

---

## 18. Copy slots

These are hard maximums in characters, spaces included. They were computed on a 360 pt wide screen with 16 pt gutters, using 0.47 em per character plus 10% slack for ragged wrapping. Each slot fits its line cap at 150% text. narrative-designer owns the words.

| Slot | Max | Lines at 100% / 150% |
|---|---|---|
| Starter name (player-typed) | 16 | 1 / 1 |
| Status word | 12 | 1 / 1, never wraps |
| Status hint, and the forecast hint `FORECAST_HINT` (§11.1) | 34 (target 28) | 1 / 2 |
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
| Feed: schedule tile title (`FEED_OPTION_*_TITLE`). The tile's second line is the ratio value, no key. Grams show in `FEED_DISCARD_LINE` (game-mechanics §2.3). `FEED_OPTION_SUB` is unused by the compact sheet | 20 | 2 / 3, in a 91 to 112 pt tile |
| Feed: flour tile (`FLOUR_*`) | 14 | 2 / 2, in a 75 to 83 pt tile |
| Feed: hooch and water tiles (`FEED_HOOCH_POUR` / `_STIR`, `HYDRATION_*`). One word per hydration label keeps them inline | 18 / 14 | 1 / 2 |
| Feed: inline row label (`FEED_STEP_HOOCH`, `FEED_STEP_HYDRATION`). One word keeps the row inline at 125% | 14 | 1 / 1 |
| Feed: "Same as last time" header caption | 18 | 1 / 1 (own line when the header is full) |
| Feed: one-line note | 60 | 2 / 3 |
| Feed: result block (`FEED_DISCARD_LINE`, `FORECAST_LINE`) | 60 each | 1 / 2 each |
| Coach mark "Skip tour" button | 18 | 1 / 1 |
| Journal starter card: trait row (`TRAIT_*_JOURNAL_TITLE`) | 26 | 1 / 2 |
| Empty-jar card body (`EMPTY_JAR_BODY`) | 90 | 3 / 4 |
| Location card label / sub | 14 / 14 | 1 / 2 |
| Journal entry title / body | 26 / 200 | scrolls |
| Onboarding page title / body, coach mark | 26 / 120, 60 | 1 / 2, 4 / 6, 2 / 3 |
| Confirmation title / body | 26 / 120 | 1 / 2, 4 / 6 |
| Empty state title / body | 26 / 90 | |
| Settings row label / value | 24 / 12 | 1 / 2 |
| `accessibility_name` / description (not shown) | 40 / 120 | n/a |
| Notification title / body (after the slice, OS-rendered) | 30 / 90 | OS |

### 18.1 Copy added for Phase 4

narrative-designer added all of these (commit aef63eb). Listed here so the slot each one fills is clear.

| Key | Max | Used by |
|---|---|---|
| `FORECAST_HINT` | 34 | Status hint after a feed (§11.1). Its fixed part must stay ≤ 16 characters so "tomorrow afternoon" (18) fits |
| `ONBOARD_SKIP_TOUR_BTN` | 18 | Every tour coach mark, and the B6 page (§14.4) |
| `REASON_EMPTY_JAR` | 60 | Toast on a locked bar button in the empty jar (§14.5) |
| `SETTINGS_SOUND`, `SETTINGS_VOLUME`, `SETTINGS_TIME_LAPSE` | 24 each | Settings rows 2, 3 and 7 (§14.3) |
| `SETTINGS_WARNING_ALERT`, `_NOTE` | 24 / 60 | Settings row 8, **deferred** until D-057's plugin is wired |

`FEED_STEP_HYDRATION` now reads "Water", which keeps the Water row inline at 125% (§8.1).

Reused, no new copy: `SMELL_MEANING_BTN` on inspect results (§10), `FEED_SKIP_ANIM_BTN` for the B6 demo's Skip pill, `NAME_BTN_PICK` from the empty jar, `RESTART_BTN_LATER` and `EMPTY_JAR_*` (D-047).

---

## 19. Notes for godot-developer and tech-architect

1. **1 unit = 1 pt or dp on every device.** Lay out at the device's real logical size (360 to 440 wide). Don't stretch a fixed base resolution. Example: a 390 × 844 base with `canvas_items` + `expand` scales by min(w, h) ratio. On an iPhone SE that's 1.58 px per unit instead of 2 px per pt, so a 48-unit target would come out at 38 pt and fail the 44 pt minimum. Use `DisplayServer.screen_get_scale()`. It's implemented on Android, iOS, Web and macOS, and returns 2.0 on the dev Mac (spike). Real phone values need the Phase 2 simulator. architecture.md sets stretch mode to `disabled`.
2. **Text size.** Scale Theme font sizes, not `content_scale_factor`, so targets don't balloon. Every text container must grow vertically.
3. **Input.** See §6 for the touch routing rules. 3D input lives in `_unhandled_input` on the camera rig. Pinch is built from touch indices on both platforms.
4. **Safe areas.** Read `get_display_safe_area()` each time the app resumes or the screen resizes, and apply the §2 floors on Android.
5. **Camera framing.** Frame to the jar region (§2), not the viewport, and reframe when a sheet opens (§15). The spike confirmed an off-axis frustum shift with a 300 ms ease (`set_frame_shift`), which moves the jar 18% up the frame with no perspective change.
6. **Hard rule 2 in the UI.** Status, hint, smell, inspection, forecast and the time-lapse read from sim state only.

---

## 20. Open items in this doc

| Item | Status |
|---|---|
| Icons | Done: 47 SVGs in `assets/icons/` (D-034) |
| Rubber band, ±70° yaw, feed animation (6 s first, then 4.2 s) | Decided, D-023 |
| No mold tint | Decided, D-026 |
| 4-tap warning route | Decided, D-027 |
| Fraunces | Measured by T3 (§17), D-029 |
| Pill 44, moldy locks (Phase 3), 51% jar floor on 360 × 640, plate shadows (Phase 4) | Decided, D-043 |
| Still unverified: iOS haptic amplitude and `screen_get_scale()` on a real iPhone | The user's iPhone 13 Pro, Phase 4 (D-058, D-059). The Android navigation-bar inset waits for the Android phase (D-054) |
| **Phase 4** | |
| HUD tucks for every sheet (§3). The inspect `bubbles` band grows, so T2 and art-director re-check that framing once | Proposed here. T2, art |
| Feed sheet opens full at Largest text (§8.1) | Proposed here. One sheet's height choice, not a layout mode (D-043) |
| A mid-tour "Skip tour" also unlocks every P0 and P1 option? I recommend no: only B1's "I know starters" says the player has kept a starter | game-designer |
| "Replay tutorial" is cut for the MVP. Replaying B6 and B7 on a real starter would need a sandbox that never touches the save | director |
| Day one text: use `JOURNAL_DAY_ONE_BODY` ("fed it right at its peak") only when the path is `tour` and the first feed's timing class is `on_time`, else `_SKIP_BODY`. Otherwise an interrupted tour can make it false | T1, narrative |
| The pre-adoption starter must look and smell freshly fed during B1 to B5 (§14.4). How: T1's tour preset | T1 |
| Orbit and pinch on during the B6 demo | T2 |
| iOS audio session Ambient (obeys the silent switch, mixes with other audio) | The setting exists in 4.7.2 (sound-designer, from the binary's strings, not run). T1 sets it. The behavior is checked on the iPhone |
| A folded note under the band for B1 | art-director: cheap, but not built this round, and it needs a slot in the jar GLB contract. It may carry pencil scribbles only, no readable words (rule 3). Director's call |
| A credits and licenses page (Figtree's OFL text must ship) and "Erase all data" | Before a store release (Phase 5) |
| Inspect's "Smell it" button: dropped, as the scientist recommends (sim spec §14, "Inspect to smell") | Decided here |

## Sources

- Hoober, S. "How Do Users Really Hold Mobile Devices?" UXmatters, 2013. https://uxmatters.com/mt/archives/2013/02/how-do-users-really-hold-mobile-devices.php
- iPhone screen sizes and safe areas: https://useyourloaf.com/blog/iphone-17-screen-sizes/ and Apple, iPhone 17 Pro tech specs: https://www.apple.com/iphone-17-pro/specs/
- iOS 27 device support (iPhone 11 and later, SE 2nd gen and later): https://appleinsider.com/articles/26/06/08/ios-27-keeps-iphone-11-and-newer-compatibility
- iPhone 17e keeps a notch: https://www.macrumors.com/roundup/iPhone-17e/
- Godot `Input.vibrate_handheld` amplitude: https://docs.godotengine.org/en/4.3/classes/class_input.html
- Godot safe area on Android, community reports: https://forum.godotengine.org/t/android-edge-to-edge-feature-does-what-exactly/123675
- WCAG 2.2, contrast (1.4.3, 1.4.11) and target size: https://www.w3.org/TR/WCAG22/
- Local measurements: CoreText glyph widths and WCAG contrast math, scripts in the ux-designer scratchpad (not committed).
