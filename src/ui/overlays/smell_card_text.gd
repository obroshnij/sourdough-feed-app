class_name SmellCardText
extends RefCounted
## Builds the smell card's keys from the sim's SmellReadout (game-copy §5.1 and §1.4, CLAUDE.md rule 2).
## Pure and deterministic: no random pick. The sensory line is 1 + (feed_count + DESCRIPTOR_ORDER index) % 3,
## so smelling twice in one rise cycle gives the same line.

## vision.md's descriptor order (game-copy §1.4).
const DESCRIPTOR_ORDER: Array[StringName] = [
	&"wet_flour", &"mildly_fruity", &"fresh_yeasty", &"yogurt", &"pleasantly_tangy", &"strongly_acidic",
	&"alcohol", &"acetone", &"cheesy", &"musty",
]
## A second descriptor shows as a note from this intensity (game-copy §5.1, ASSUMED there).
const NOTE_MIN: float = 0.15
const NOTE_CLEAR_MIN: float = 0.5
## Below this for every descriptor (and no musty), the faint lines are used (cold dormant).
const FAINT_MAX: float = 0.3
## The meaning line shows the first 3 times a descriptor is smelled; musty's never fades.
const MEANING_VIEWS: int = 3

var title_key: StringName = &""
var body_key: StringName = &""
var note_key: StringName = &""
## {note}: the second descriptor's SMELL_<D>_NOTE key (Session.format_text translates it).
var note_args: Dictionary = {}
var meaning_key: StringName = &""
## After the first 3 appearances the meaning sits one tap away (AC-07.5): the key stays, hidden behind a
## button. Never for musty, which always shows.
var meaning_hidden: bool = false
var primary: StringName = &""
var is_warning: bool = false


## `feed_count` is PlayerHistory.real_feeds. `seen` is how many times the primary has been smelled,
## including this one (PlayerHistory.seen_counts["smell.<id>"] after apply).
static func build(r: SmellReadout, moldy: bool, feed_count: int, seen: int) -> SmellCardText:
	var c := SmellCardText.new()
	if moldy:
		c.title_key = &"SMELL_MOLDY_TITLE"
		c.body_key = &"SMELL_MOLDY_BODY"
		c.is_warning = true
		return c
	var values: Dictionary[StringName, float] = r.intensities
	var musty: float = values.get(&"musty", 0.0)
	var top: StringName = r.primary
	if musty > 0.0:
		top = &"musty"
	c.primary = top
	c.is_warning = top == &"musty" or r.is_warning
	var all_faint: bool = true
	for d: StringName in values:
		if values[d] >= FAINT_MAX:
			all_faint = false
	if top == &"" or (all_faint and musty <= 0.0):
		c.title_key = &"SMELL_FAINT_TITLE"
		c.body_key = StringName("SMELL_FAINT_%d" % (1 + posmod(feed_count, 2)))
		c.meaning_key = &"SMELL_FAINT_MEANING"
		c.meaning_hidden = seen > MEANING_VIEWS
		if top != &"":
			c.note_key = &"SMELL_NOTE_FAINT"
			c.note_args = {"note": String(Keys.smell(top, "NOTE"))}
		return c
	c.title_key = Keys.smell(top, "TITLE")
	var n: int = 1 + posmod(feed_count + maxi(DESCRIPTOR_ORDER.find(top), 0), 3)
	c.body_key = Keys.smell(top, str(n))
	var second: StringName = &""
	var best: float = 0.0
	for d: StringName in values:
		if d != top and values[d] > best:
			best = values[d]
			second = d
	if second != &"" and best >= NOTE_MIN:
		c.note_key = &"SMELL_NOTE_CLEAR" if best >= NOTE_CLEAR_MIN else &"SMELL_NOTE_FAINT"
		c.note_args = {"note": String(Keys.smell(second, "NOTE"))}
	c.meaning_key = Keys.smell(top, "MEANING")
	c.meaning_hidden = top != &"musty" and seen > MEANING_VIEWS
	return c
