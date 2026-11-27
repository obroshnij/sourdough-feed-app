class_name RuleBackToStrength
extends EventRule
## back_to_strength (events-catalog §3.5, game-mechanics §7.4, spec §14.1): after a very_late feed or a
## fridge wake, a cycle with vigor_at_feed >= 0.75 rises to at least 0.85 x last_strong_peak_rise.
## info, 24 h cooldown, once per arming.
##
## Readings (open decisions in the T4 report):
## - Armed by the latest of PlayerHistory.last_very_late_feed_unix (very_late or rescue feeds) and
##   fridge_left_unix (left the fridge while cold). A rescue counts: an unhealthy starter is also neglected.
## - Judged while `rise_phase` is at_peak, on the cycle's peak_rise, so a low reference can't fire it
##   right after the feed, and the toast's "That was a proper rise" is true when it shows.
## - Any qualifying cycle after the arming may fire it, not only the first one.

const COOLDOWN_S: int = 24 * 3600


func _init() -> void:
	id = &"back_to_strength"
	tier = &"info"
	cooldown_s = COOLDOWN_S


func evaluate(ctx: EventContext) -> SimEvent:
	if ctx.derived.rise_phase != &"at_peak":
		return null
	var d: DerivedState = ctx.derived
	if RuleFacts.shows_danger(d) or d.state == &"recovering":
		return null
	var s: StarterState = ctx.state
	if s.vigor_at_feed < PlayerHistory.STRONG_VIGOR_AT_FEED:
		return null
	var armed: int = maxi(RuleFacts.history_int(ctx.history, &"last_very_late_feed_unix"),
		RuleFacts.history_int(ctx.history, &"fridge_left_unix"))
	if armed <= 0 or RuleFacts.feed_unix(s) < armed:
		return null
	if RuleFacts.fired_after(ctx.ledger, id, armed):
		return null
	var reference: float = ctx.history.last_strong_peak_rise
	if reference <= 0.0 or s.peak_rise < RuleFacts.STRENGTH_SHARE * reference:
		return null
	return make_event(ctx)
