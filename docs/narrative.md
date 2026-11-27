# Narrative

Owner: `narrative-designer`. Status: Phase 1 wave A draft, 2026-11-26.

Companion docs: [`events-catalog.md`](events-catalog.md) (events), [`game-copy.md`](game-copy.md) (all other strings). Canonical ids come from [`vision.md`](vision.md).

Inputs used: the scientist's draft v0 states and smells (message, 2026-11-26), game-designer's event, milestone and onboarding notes plus [`game-design.md`](game-design.md), and ux-designer's copy slots (message, 2026-11-26). Anything not confirmed by its owner is marked **ASSUMED**.

**String rule for all three docs:** every player-facing string appears exactly once, in a `Key | Text | Max` table. `Max` is the hard character limit for its UI slot, spaces included, with placeholders at their worst case (see [`game-copy.md`](game-copy.md) §1). A build script can lift every such row into `en.csv`.

---

## 1. The concept

The starter is a small, old, living thing in a jar on your counter. It has an appetite, a rhythm and a little vanity. It has no face. You learn its moods the way you learn a houseplant's: by looking.

The game speaks through **the journal**, a kitchen notebook that came with the jar. Its first pages were written by the starter's previous keeper, who signs as **M.** The journal describes what it sees, then what it means, with dry, fond wit. It never speaks *for* the starter.

**Why this frame works:**
- It explains why the game's voice knows sourdough: an experienced home baker wrote it.
- It keeps the starter faceless. The starter is described, never voiced.
- It gives onboarding, the memorial and the restart a natural home.
- It costs nothing: M. is never seen, never fully named and never returns. M. appears only in the first note and in the first restart (§9.4).

## 2. The four constants

Every starter has these. Traits (§7) color them but never change them.

| Constant | What it means | What the player sees (from the sim) | How the journal says it |
|---|---|---|---|
| **Appetite** | It eats, works, and shows you when the food is gone. | A rise after each feed. Hooch and sharp smells when hungry. | "It has eaten everything and fallen back." |
| **Rhythm** | Rise, peak, fall, like very slow breathing. | Height against the rubber band, bubble rate, the idle surface motion. | "Right on schedule." |
| **Quiet pride** | At peak it is at its best. | Dome, gloss, height. | "Domed and quietly pleased with itself." |
| **Patience with you** | It waits. A day away costs nothing a feed can't fix. | Recoverable hunger, the fridge. | "It waited. It's good at that." |

## 3. Personality without a face

### 3.1 Channels

| Channel | Source | Narrative rule |
|---|---|---|
| Height, dome, collapse | sim, through `VisualMapper` | Comment only on what is visible. |
| Bubbles | sim | Size and count words come from the state, not from mood. |
| Glass streaks, rubber band | sim | Streaks are "how tall it got". The band is "where it started". |
| Hooch layer | sim | Always framed as hunger. |
| Idle surface motion | art, scaled by sim activity | Never implies a mood the sim didn't produce. |
| Sound (soft pops) | audio, from sim activity | Same. |
| Smell text | sim descriptor to copy | [`game-copy.md`](game-copy.md) §5 |
| Inspection text | sim state and inspection kind to copy | [`game-copy.md`](game-copy.md) §6 |
| Reaction toasts | the action plus the new state | [`game-copy.md`](game-copy.md) §8 |
| Journal entries | sim history | [`game-copy.md`](game-copy.md) §11 |

### 3.2 Personification rules

1. **Behavior first, mood second.** State the visible fact, then lend it a mood. "Bubbles everywhere. Someone's in a good mood."
2. **Hedge or ground the mood.** Use "seems", "looks" or "as if", or follow the mood with the plain fact. "It looks sulky. It's just cold."
3. **Never a mood the sim contradicts.** No "content" on a hungry starter. No "sad" on a healthy cold one.
4. **No pain, fear, illness or suffering.** Hungry is hungry, not starving. Cold is resting, not freezing. A moldy starter "can't be saved". It is never "dying" or "killed".
5. **No face words.** No eyes, smile, mouth, tummy or voice. It doesn't "say", "ask" or "beg". It can "make its point" through behavior.
6. **No first person from the starter, ever.** The journal also avoids "I". It speaks to the player as "you".

## 4. Voice and tone

**The voice:** a kind, witty, experienced home baker writing margin notes for a friend.

### 4.1 Principles

1. **Look, then explain.** Fact first, meaning second, joke last (if at all).
2. **Short.** One idea per sentence. Most sentences under 12 words. One idea per toast.
3. **Specific beats cute.** Use kitchen comparisons people know: yogurt, beer, nail polish remover, pancake batter, a bakery door.
4. **One small joke, at most, per string.** None in safety copy.
5. **Dry, not silly.** The humor comes from treating flour paste with dignity.
6. **Warm to the player.** Never blame, guilt, nag, or count their absences.
7. **Calm.** No exclamation marks in status, smell, inspection or warning copy. At most one per milestone. No ALL CAPS, no emoji.
8. **Plain words.** Gloss a baking term the first time it appears (§4.5).
9. **Safety copy is direct.** What it is, what to do. No hedging, no jokes, no "probably".
10. **House style.** American spelling. No em dashes. Numerals for numbers. °C now, °F later. "About 6 hours", never "6.0 h".

### 4.2 Tone by moment

| Moment | Dial | Example |
|---|---|---|
| Thriving (`active`, `near_peak`, `at_peak`) | warm, a little playful | "Tall, domed, at its best." |
| Routine (`freshly_fed`, `developing`) | calm, brief | "Flat, smooth and settling in." |
| Hunger, hooch, acetone (`hungry`, `collapsing`) | reassuring, practical | "That's hunger, not trouble. A feed fixes it." |
| Cold (`dormant` in the fridge) | gentle, unbothered | "Cold and quiet. It can wait." |
| Run down (`dormant` from neglect, `recovering`) | kind, practical | "Run down. Feed it today." |
| Warning (`unhealthy`) | serious, kind, clear | "Warning signs. Look, then feed." |
| Loss (`moldy`) | plain, kind, final | "This is mold. Please discard it." |
| Milestones | fond, one flourish | "First peak. Domed and very pleased with itself." |

### 4.3 Do and don't

| Situation | Do | Don't | Why |
|---|---|---|---|
| At peak | "At its peak. Domed, glossy, quietly pleased with itself." | "WOW, your starter is PERFECT!!! 🎉" | Calm. No caps, no emoji. |
| Hungry | "Hungry. It has eaten everything and fallen back. A feed fixes this." | "Your poor starter is starving!" | Hunger is normal. No suffering words. |
| Player was away | "While you were out it rose, peaked and settled. Now it's hungry." | "You were gone 26 hours. It missed you." | Never count absences. No guilt. |
| Hooch | "A gray layer on top. That's hooch, a hunger sign. Pour it off or stir it in, then feed." | "Warning: strange liquid detected." | Hooch is normal. Don't scare. |
| Acetone smell | "Like nail polish remover. Odd, but it's just hunger." | "Toxic fumes. Throw it out." | Acetone means hungry (vision safety rules). |
| Fridge | "Cold and quiet. Resting, and in no hurry." | "It's freezing to death." | Cold is a pause, not harm. |
| Personifying | "It looks smug. It has doubled, so fair enough." | "Yay, I'm so full now, thank you!" | No first person, no speech. |
| Baby talk | "Fed and settling in." | "Nom nom, wittle starter is full!" | Adults. Never childish. |
| Warning signs | "It smells musty, and there's a dry skin on top. Warning signs. No mold yet. Look closely, then feed." | "Hmm, it's probably fine, don't worry." / "Musty, but not mold." | Warnings are direct, and teach the real habit: look first. Musty can come with mold, so never "not mold". |
| Mold | "That fuzz is mold. A moldy starter can't be saved. Discard all of it." | "Just scrape off the fuzzy bit and carry on." | Never present contamination as fixable or safe. |
| Explaining | "Peak: its tallest point, just before it falls." | "Optimal leavening window reached." | Plain language. |
| Puns | One light pun in a name suggestion, rarely elsewhere. | "You're on a roll! Rise and shine! You knead this!" | Pun pileups read childish. |
| Science | "Warmth speeds it up. The fridge slows it down." | "Sourdough is great for your gut." | No health claims (vision safety rules). |

### 4.4 Banned words

| Banned | Use instead |
|---|---|
| safe, safely, probably fine, should be OK | Say what to do: "Discard it." "That's normal." |
| scrape, salvage, save some, just a little mold | "Discard all of it." |
| starving, dying, dead, killed, poor thing | hungry, run down, can't be saved |
| toxic, poison, danger (about hooch or smells) | "a hunger sign" |
| tummy, yummy, nom, wittle, baby, bestie, vibes, oopsie, uh oh | plain words |
| you forgot, you neglected, finally, missed you, daily streak | "While you were away..." |
| healthy (about people), gut, probiotic, immune, cure | nothing. Sourdough is food. |

"Safe" is banned in all player copy, not only near mold, so it can never slip into the wrong place. The copy check in [`game-copy.md`](game-copy.md) §16 enforces this list.

### 4.5 Terms glossed on first use

The gloss strings are the `GLOSS_*` keys in [`game-copy.md`](game-copy.md) §12.

| Term | Gloss idea |
|---|---|
| Starter | Flour and water, alive with wild yeast and bacteria. It raises sourdough bread. |
| Feed | Fresh flour and water, so it has food again. |
| Discard | The part you take out before feeding, so the jar doesn't overflow. |
| Peak | Its tallest point after a feed, just before it falls. |
| Hooch | Liquid on top, gray to brown, sometimes black. A hunger sign. |
| Ratio | Starter : flour : water by weight. 1:1:1 means equal parts. |
| Hydration | Water ÷ flour × 100. 100% means equal weights. (P1, when hydration presets unlock.) |
| Rubber band | Marks where it started after a feed, so you can see the rise. |

## 5. Who M. is (and isn't)

- The previous keeper. Moved away, left the starter, the jar and the journal.
- Signs "M." Gender, age and story are never stated. Players fill the gap.
- Appears in: the arrival note (B1) and the first restart (§9.4). Nowhere else.
- The journal's voice *is* M.'s voice, continued. After B1 it no longer signs. It's just the journal.
- M. never judges, never returns and never becomes a quest.

## 6. Naming

### 6.1 The naming moment

| Item | Rule |
|---|---|
| When | B4, played **after** the B6 time-lapse, so the player names something they've just watched come alive. Agreed with `game-designer`. |
| Screen | Onboarding page over the jar. Name field prefilled with a suggestion. |
| Length | 1 to 16 characters after trimming spaces (ux-designer's name slot). |
| Characters | Whatever the UI font renders. No emoji (font coverage). `ux-designer` and `tech-architect` set the exact filter. |
| Empty input | Keeps the suggestion. Never an error. |
| Profanity filter | None. Offline, single player, their kitchen. |
| Rename later | Yes, in P1, from the journal's starter page (D-022). |
| Suggestion order | Deterministic. First suggestion is `NAME_SUGGEST[(starter_seed) % 24]`. "Suggest another" steps to the next index, wrapping. `starter_seed` is the int saved when the starter is created. |

### 6.2 Naming strings

| Key | Text | Max |
|---|---|---|
| `NAME_TITLE` | Give it a name | 26 |
| `NAME_BODY` | Plenty of bakers name their starter. It's easier to care about a name than a jar. | 120 |
| `NAME_FIELD_A11Y` | Starter name | 40 |
| `NAME_BTN_SUGGEST` | Suggest another | 18 |
| `NAME_BTN_PICK` | Pick for me | 18 |
| `NAME_BTN_CONFIRM` | That's its name | 18 |
| `NAME_DONE_TOAST` | {name} it is. | 60 |

### 6.3 Name suggestions

No real people, no brands. Puns are allowed here, gently.

| Key | Text | Max |
|---|---|---|
| `NAME_SUGGEST_01` | Mabel | 16 |
| `NAME_SUGGEST_02` | Otto | 16 |
| `NAME_SUGGEST_03` | Agnes | 16 |
| `NAME_SUGGEST_04` | Walter | 16 |
| `NAME_SUGGEST_05` | Florence | 16 |
| `NAME_SUGGEST_06` | Gus | 16 |
| `NAME_SUGGEST_07` | Edna | 16 |
| `NAME_SUGGEST_08` | Herman | 16 |
| `NAME_SUGGEST_09` | Dolores | 16 |
| `NAME_SUGGEST_10` | Bernard | 16 |
| `NAME_SUGGEST_11` | Crumb | 16 |
| `NAME_SUGGEST_12` | Barm | 16 |
| `NAME_SUGGEST_13` | Biscuit | 16 |
| `NAME_SUGGEST_14` | Treacle | 16 |
| `NAME_SUGGEST_15` | Nutmeg | 16 |
| `NAME_SUGGEST_16` | Pickle | 16 |
| `NAME_SUGGEST_17` | Mother | 16 |
| `NAME_SUGGEST_18` | Ferdinand | 16 |
| `NAME_SUGGEST_19` | Proofrock | 16 |
| `NAME_SUGGEST_20` | Breadley | 16 |
| `NAME_SUGGEST_21` | Gluten Morgen | 16 |
| `NAME_SUGGEST_22` | The Lodger | 16 |
| `NAME_SUGGEST_23` | Sourpuss | 16 |
| `NAME_SUGGEST_24` | Patience | 16 |

Notes: "Barm" is the old word for the yeasty foam on fermenting beer. "Mother" is what many bakers call a starter. "Proofrock" nods to a long-public poem.

## 7. Traits (P1)

### 7.1 Rules

- Four traits: `patient`, `energetic`, `sensitive`, `resilient`. Approved (D-022).
- One per starter, revealed at maturity stage `steady` through the `trait_revealed` event. How the trait is picked belongs to `game-designer` ([`progression.md`](progression.md)).
- **Traits change wording, never biology.** A trait line describes manner or attitude only. It never states or implies speed, height, smell, timing, strength or safety.
- **No trait variants** for status, smell, inspection, warnings, mold, or "while you were away" facts. Those stay neutral so the information is identical for everyone.
- Trait variants exist only for: the feed reaction, the `off_to_nap` toast, the fridge-out reaction, the `peak_now` toast, the trait reveal and the epitaph. Before the reveal, the neutral line is used.
- `game-designer`'s trait signals ([`progression.md`](progression.md) §5) come from real conditions, such as warm hours for `energetic`. The words still never claim speed, because the trait stays when conditions change (an `energetic` starter in the fridge is not fast).

### 7.2 How each trait reads

| Trait | Essence | The journal's lens | Avoid |
|---|---|---|---|
| `patient` | Unhurried, unbothered, does things properly. | Stately, a touch of the butler. | "Slow", "takes ages" (speed claims). |
| `energetic` | Keen on everything. | Fond amusement at its enthusiasm. | "Fast", "rises quicker" (speed claims). |
| `sensitive` | Notices everything, takes things to heart. | Tender, a little protective. | "Fragile", "gets sick easily" (biology). |
| `resilient` | Hard to rattle, has seen things. | Dry respect. | "Tough to kill", "survives anything" (biology, and grim). |

### 7.3 Trait strings

| Key | Text | Max |
|---|---|---|
| `TRAIT_PATIENT_NAME` | Patient | 12 |
| `TRAIT_ENERGETIC_NAME` | Energetic | 12 |
| `TRAIT_SENSITIVE_NAME` | Sensitive | 12 |
| `TRAIT_RESILIENT_NAME` | Resilient | 12 |
| `TRAIT_PATIENT_REVEAL_TOAST` | It's clear now: {name} is the patient type. | 60 |
| `TRAIT_ENERGETIC_REVEAL_TOAST` | It's clear now: {name} is the energetic type. | 60 |
| `TRAIT_SENSITIVE_REVEAL_TOAST` | It's clear now: {name} is the sensitive type. | 60 |
| `TRAIT_RESILIENT_REVEAL_TOAST` | It's clear now: {name} is the resilient type. | 60 |
| `TRAIT_PATIENT_JOURNAL_TITLE` | The patient type | 26 |
| `TRAIT_PATIENT_JOURNAL_BODY` | Unhurried and unbothered. It does things properly, in order, without fuss. This won't change how it rises, only how it carries itself. | 200 |
| `TRAIT_ENERGETIC_JOURNAL_TITLE` | The energetic type | 26 |
| `TRAIT_ENERGETIC_JOURNAL_BODY` | Keen on everything: a feed, a warm spot, a bit of attention. It greets each feed like good news. This won't change how it rises, only how it carries itself. | 200 |
| `TRAIT_SENSITIVE_JOURNAL_TITLE` | The sensitive type | 26 |
| `TRAIT_SENSITIVE_JOURNAL_BODY` | It notices things. A new flour, a new spot, a cold draft. It seems to take it all to heart. This won't change how it rises, only how it carries itself. | 200 |
| `TRAIT_RESILIENT_JOURNAL_TITLE` | The resilient type | 26 |
| `TRAIT_RESILIENT_JOURNAL_BODY` | Hard to rattle. It meets cold and hunger with something like a shrug. This won't change how it rises, only how it carries itself. | 200 |
| `REACT_FEED_PATIENT` | Fed. It settles in without any fuss. | 60 |
| `REACT_FEED_ENERGETIC` | Fed. It seems delighted with the new flour. | 60 |
| `REACT_FEED_SENSITIVE` | Fed. It seems to appreciate the attention. | 60 |
| `REACT_FEED_RESILIENT` | Fed. Business as usual. | 60 |
| `EVENT_OFF_TO_NAP_PATIENT` | Into the fridge. It seems to find this restful. | 60 |
| `EVENT_OFF_TO_NAP_ENERGETIC` | Into the fridge. It seems mildly offended. | 60 |
| `EVENT_OFF_TO_NAP_SENSITIVE` | Into the fridge. It takes the cold a bit personally. | 60 |
| `EVENT_OFF_TO_NAP_RESILIENT` | Into the fridge. It takes this in stride. | 60 |
| `REACT_FRIDGE_OUT_PATIENT` | Out of the cold. It'll wake when it's ready. A feed helps. | 60 |
| `REACT_FRIDGE_OUT_ENERGETIC` | Out of the cold. A feed or two and it'll be itself again. | 60 |
| `REACT_FRIDGE_OUT_SENSITIVE` | Out of the cold. Be gentle. A feed or two will wake it. | 60 |
| `REACT_FRIDGE_OUT_RESILIENT` | Out of the cold, unbothered. A feed or two will wake it. | 60 |
| `EVENT_PEAK_NOW_PATIENT` | At its peak. No fuss, no hurry, just there. | 60 |
| `EVENT_PEAK_NOW_ENERGETIC` | At its peak, and thoroughly pleased about it. | 60 |
| `EVENT_PEAK_NOW_SENSITIVE` | At its peak. It seems to like being noticed. | 60 |
| `EVENT_PEAK_NOW_RESILIENT` | At its peak. Steady as ever. | 60 |

The neutral versions of these lines live in [`game-copy.md`](game-copy.md) §8 and [`events-catalog.md`](events-catalog.md).

## 8. Onboarding script

Synced with `game-designer` ([`game-design.md`](game-design.md) §3). Beat ids are theirs; the play order below moves naming after the time-lapse, which they agreed was my call.

**Setup:** a gifted starter, young but established, fed by M. shortly before. It starts at `freshly_fed` or early `developing` on the `counter`. The tutorial time scale runs **only** during B6, and the jar shows a "Time-lapse" badge while it does. Everything else is real time.

**Targets:** under 7 minutes, no more than one thing to do at a time, nothing to read longer than 120 characters.

### 8.1 Beats in play order

| Order | Beat | What happens | Player learns | Strings |
|---|---|---|---|---|
| 1 | B1 Arrival | Warm kitchen. The jar on the counter, a note under the rubber band. Note page opens. Two choices. | This is alive, and it's mine now. | `ONBOARD_NOTE_*` |
| 2 | B2 Look | Coach marks for drag and pinch. Done after about 90° of orbit or 10 s. | The jar rewards looking. | `ONBOARD_LOOK_*` |
| 3 | B3 Smell | Coach mark on Smell. The normal smell card shows (`wet_flour`, with its meaning line). Then one coach line. | Smell tells you where it is in its cycle. | `ONBOARD_SMELL_*`, `SMELL_WET_FLOUR_*` |
| 4 | B5 Inspect | Coach mark on Inspect, then `bubbles`. The normal inspect card shows. | Bubbles mean activity. | `ONBOARD_INSPECT_*`, `INSPECT_BUBBLES_*` |
| 5 | B6 Time-lapse | Page, then about 90 to 120 s of sped-up sim with the badge. It pauses at `at_peak`. Coach line on peak. | What a cycle looks like, and what peak is. | `ONBOARD_TIMELAPSE_*` |
| 6 | B4 Name | Naming page (§6). | Attachment. | `NAME_*` |
| 7 | B7 First feed | Coach on Feed. Feed sheet with coach lines for discard and the schedule question. Real time starts on confirm. | Feed at peak. The ratio sets when the next peak comes. | `ONBOARD_FEED_*`, `FEED_*` |
| 8 | B8 Handoff | Page with the forecast. Two coach lines: fridge, journal. The first journal entry is written. | When to come back. The fridge exists. | `ONBOARD_HANDOFF_*`, `JOURNAL_DAY_ONE_*` |

**Skip path** ("I know starters"): B1, then B4 naming, then B7's schedule question, then a single toast. The save starts at `at_peak` (the state B6 ends on), so the first feed is on time (mechanics §8.1).

### 8.2 Onboarding strings

Slots: onboarding page title 26 and body 120, coach marks 60, buttons 18, badge 12.

| Key | Text | Max |
|---|---|---|
| `ONBOARD_NOTE_TITLE` | It came with a note | 26 |
| `ONBOARD_NOTE_BODY` | A sourdough starter: flour and water, alive with wild yeast and bacteria. Feed it, and it will raise bread for years. M. | 120 |
| `ONBOARD_NOTE_BTN_TOUR` | Show me around | 18 |
| `ONBOARD_NOTE_BTN_SKIP` | I know starters | 18 |
| `ONBOARD_LOOK_COACH` | Drag to turn the jar. Pinch to look closer. | 60 |
| `ONBOARD_LOOK_DONE` | The jar shows you almost everything. Almost. | 60 |
| `ONBOARD_SMELL_COACH` | Now smell it. Tap Smell. | 60 |
| `ONBOARD_SMELL_AFTER` | The smell changes as it rises. Your nose will learn it. | 60 |
| `ONBOARD_INSPECT_COACH` | Look closer. Tap Inspect, then Bubbles. | 60 |
| `ONBOARD_TIMELAPSE_TITLE` | Watch it rise | 26 |
| `ONBOARD_TIMELAPSE_BODY` | Here are the next few hours, sped up. The rubber band marks where it started. | 120 |
| `ONBOARD_TIMELAPSE_BTN` | Watch | 18 |
| `ONBOARD_TIMELAPSE_BADGE` | Time-lapse | 12 |
| `ONBOARD_TIMELAPSE_PEAK` | That's its peak: as tall as it gets. Time to feed it. | 60 |
| `ONBOARD_FEED_COACH` | It's at its peak, so it's ready for a feed. Tap Feed. | 60 |
| `ONBOARD_FEED_DISCARD` | First, the discard: take some out so it won't overflow. | 60 |
| `ONBOARD_FEED_SCHEDULE` | More fresh flour for the same starter means a later peak. | 60 |
| `ONBOARD_FEED_DONE` | Fed. The rubber band marks its new starting line. | 60 |
| `ONBOARD_HANDOFF_TITLE` | Now, the real clock | 26 |
| `ONBOARD_HANDOFF_BODY` | From here, time runs for real. It should be at its best {window}. Look in then, or whenever suits you. | 120 |
| `ONBOARD_HANDOFF_BTN` | Got it | 18 |
| `ONBOARD_HANDOFF_FRIDGE` | Busy few days? The fridge slows it right down. | 60 |
| `ONBOARD_HANDOFF_JOURNAL` | M.'s journal is yours now. It keeps notes for you. | 60 |
| `ONBOARD_SKIP_DONE` | All yours. The journal has notes if you want them. | 60 |
| `JOURNAL_DAY_ONE_TITLE` | Day one | 26 |
| `JOURNAL_DAY_ONE_BODY` | Took over from M. today. Named it {name}. Watched it rise, then fed it right at its peak. It seemed to approve. | 200 |
| `JOURNAL_DAY_ONE_SKIP_BODY` | Took over from M. today. Named it {name}. Fed it and left it to get on with things. | 200 |

`{window}` comes from the sim's forecast peak time, mapped to the `WINDOW_*` phrases in [`game-copy.md`](game-copy.md) §9.

## 9. The memorial moment

### 9.1 Principles

- **Kind, honest, clear, final.** No jokes on the mold sheet. Warmth returns only on the memorial page.
- **Never implies any part can be saved.** No "scrape", no "save some", no "probably". "Discard all of it, even the parts that look clean" rules out scraping without naming it, so the safety lint can ban the word outright.
- **No blame.** The cause is stated once, as a fact, on the memorial page. Advice is framed as "worth knowing", not "next time you should".
- **No rush.** No timer, no repeated prompts, no notification about mold. The player can say "Not yet" and come back.
- **Don't sniff it.** Smell is replaced by a short "Best not" card (scientist's request).

Sources for the safety lines: King Arthur Baking says pink or orange streaks mean discard and that hooch is a hunger sign ([troubleshooting](https://www.kingarthurbaking.com/blog/2018/03/09/sourdough-starter-troubleshooting-2), [black liquid](https://www.kingarthurbaking.com/blog/2023/08/28/sourdough-starter-black-liquid)). USDA FSIS says mold can reach below the surface of soft, moist foods, and bacteria can grow along with it ([Molds on Food, PDF](https://www.fsis.usda.gov/sites/default/files/media_file/2021-02/Molds_on_Food.pdf)). Final authority: [`sourdough-science.md`](sourdough-science.md). **The scientist reviews every line in this section in wave B.**

### 9.2 Flow

| Step | What happens | Strings |
|---|---|---|
| 1. Found | State becomes `moldy` (live, or on return after the time-lapse replays the warning stages). Status pill: icon plus "Moldy". The `mold_found` attention sheet opens. | `MOLD_SHEET_*` |
| 2. "Not yet" | Sheet closes. Status hint stays: "Mold. Please discard it." Feed shows a toast. Smell shows the "Best not" card. Inspect still works and shows the mold. | `MOLD_FEED_BLOCKED`, `SMELL_MOLDY_*`, `INSPECT_*_MOLDY_*` |
| 3. Confirm | "Discard it" opens a confirmation. | `MOLD_CONFIRM_*` |
| 4. Discard | The jar is emptied and washed on screen (art-director). One toast. | `MOLD_DONE_TOAST` |
| 5. Memorial | A journal page closes the starter's chapter. Stats, an epitaph, what happened, one tip. | `MEMORIAL_*` |
| 6. Start again | A page offers a fresh spoonful. "Not today" leaves a clean, empty jar. | `RESTART_*`, `EMPTY_JAR_*`. Slice: "Start again" only. "Not today" and the empty jar are Phase 4 (D-047). |
| 7. New starter | Naming (§6), then normal play. Earned knowledge stays (game-design §5). | `NAME_*` |

### 9.3 Memorial strings

Slots: attention sheet title 26 and body 280; confirmation title 26 and body 120; journal title 26 and body 200; stat label 24 and value 12; buttons 18.

| Key | Text | Max |
|---|---|---|
| `MOLD_SHEET_TITLE` | This is mold | 26 |
| `MOLD_SHEET_BODY` | There's fuzzy growth on the surface. That's mold. A moldy starter can't be saved. Mold reaches deeper than it shows, so discard all of it, even the parts that look clean. Please don't use it or taste it. Then wash the jar well. This happens, even to careful bakers. | 280 |
| `MOLD_SHEET_BODY_TINT` | There's fuzzy growth on the surface. That's mold, and the pink or orange color is spoilage too. A moldy starter can't be saved. Discard all of it, even the parts that look clean. Please don't use it or taste it. Then wash the jar well. This happens, even to careful bakers. | 280 |
| `MOLD_BTN_DISCARD` | Discard it | 18 |
| `MOLD_BTN_LATER` | Not yet | 18 |
| `MOLD_FEED_BLOCKED` | Feeding can't fix mold. Please discard it. | 60 |
| `MOLD_CONFIRM_TITLE` | Discard {name}? | 26 |
| `MOLD_CONFIRM_BODY` | This can't be undone. Its journal stays, with a page of its own. | 120 |
| `MOLD_CONFIRM_YES` | Discard | 18 |
| `MOLD_CONFIRM_NO` | Not yet | 18 |
| `MOLD_DONE_TOAST` | Done. The jar is washed and drying. | 60 |
| `MEMORIAL_TITLE` | {name} | 26 |
| `MEMORIAL_DATES` | {start_date} to {end_date} | 34 |
| `MEMORIAL_STAT_DAYS` | Days together | 24 |
| `MEMORIAL_STAT_FEEDS` | Feeds | 24 |
| `MEMORIAL_STAT_PEAKS` | Peaks | 24 |
| `MEMORIAL_STAT_BEST` | Tallest rise | 24 |
| `MEMORIAL_STAT_TRAIT` | Character | 24 |
| `MEMORIAL_EPITAPH_1` | It rose and fell and rose again. A good life for flour and water. | 90 |
| `MEMORIAL_EPITAPH_2` | Flour, water and good company. Not a bad recipe. | 90 |
| `MEMORIAL_EPITAPH_3` | It made the kitchen smell like a bakery. That counts for a lot. | 90 |
| `MEMORIAL_EPITAPH_PATIENT` | It never hurried, and never needed to. | 90 |
| `MEMORIAL_EPITAPH_ENERGETIC` | It greeted every feed like good news. | 90 |
| `MEMORIAL_EPITAPH_SENSITIVE` | It noticed everything, including you. | 90 |
| `MEMORIAL_EPITAPH_RESILIENT` | It weathered plenty before this. | 90 |
| `MEMORIAL_CAUSE_UNFED` | It went about {days} days without a feed at room temperature. That's long enough for mold to take hold. | 120 |
| `MEMORIAL_BTN_NEXT` | Continue | 18 |
| `MEMORIAL_TIP` | Worth knowing: in the fridge, a starter can wait weeks between feeds. | 90 |
| `RESTART_TITLE` | Start again? | 26 |
| `RESTART_BODY_FIRST` | In the fridge, a small jar with M.'s writing on the lid: "Spare. Just in case." | 120 |
| `RESTART_BODY_LATER` | A friend has a spoonful of starter to spare. It's young, but it's ready. | 120 |
| `RESTART_BTN_YES` | Start again | 18 |
| `RESTART_BTN_LATER` | Not today | 18 |
| `EMPTY_JAR_TITLE` | An empty jar | 26 |
| `EMPTY_JAR_BODY` | Clean and waiting. Start again whenever you're ready. | 90 |

**P4, unused in the slice (D-047):** `RESTART_BTN_LATER`, `EMPTY_JAR_TITLE`, `EMPTY_JAR_BODY`. They stay in the table until Phase 4.

**Tint variant:** art-director's v0 mold never shows pink or orange, so `MOLD_SHEET_BODY_TINT` has no trigger yet. It stays in the table, unused. D-026: no tint in the MVP. The rule "fuzz, or pink or orange color, means discard" is still taught in the `warning_signs` sheet and the unhealthy surface lines.

**Epitaph pick (deterministic):** if a trait was revealed, use `MEMORIAL_EPITAPH_<TRAIT>`. Otherwise `MEMORIAL_EPITAPH_<1 + starter_seed % 3>`.

**`{days}` in `MEMORIAL_CAUSE_UNFED`** counts days since the last feed spent at `temp_c` ≥ 11 °C. Fridge days don't count toward mold (scientist). The in-game minimum is 6, so the plural is always correct.

**Stat values** are numbers or short words (`{height}` such as "2.3×", a trait name). They use the 12-character value slot.

### 9.4 Restart frame

- **First loss:** M.'s spare in the fridge (`RESTART_BODY_FIRST`). It closes M.'s thread kindly. Agreed with `game-designer` (mechanics §8.2) and the scientist (fixture `SPARE_FROM_FRIDGE`: the mature fixture at 4 °C, `food` 0.02, `starved_h` 20, `vigor` 0.70, `hooch` 0.25): it starts cold `dormant` on the counter and warms up. The first feed gives `recovering`, and the rise is normal by the second. That reuses `REACT_FRIDGE_OUT_NEUTRAL`, `waking_up` and `back_to_strength`, so the restart is an active beat, not a wait.
- **Later losses:** "a spoonful from a friend" (`RESTART_BODY_LATER`), starting at `at_peak`, so a second loss never brings another wait.

## 10. Decisions (narrative)

None open. OD-N1 (traits), OD-N2 (the M. frame) and OD-N5 (renaming, P1) were accepted in D-022. OD-N3 (skip path starts at `at_peak`) and OD-N4 (M.'s spare starts cold `dormant`) were settled with `game-designer` (game-mechanics §8.1, §8.2).
