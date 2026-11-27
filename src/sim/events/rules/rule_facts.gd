class_name RuleFacts
extends RefCounted
## Shared, pure helpers and thresholds for the slice event rules (T4, architecture.md §7).
## Every number here cites its source. Nothing reads the clock or an RNG.

## Spec §14.1 RISE_NOTICEABLE: rise >= 1.25, crossed upward after a feed.
const RISE_NOTICEABLE: float = 1.25
## Spec §14.1 back_to_strength: the rise reaches 0.85 x the reference peak.
const STRENGTH_SHARE: float = 0.85
## events-catalog §3.6: warning_signs is re-armed after 24 h out of `unhealthy`.
const WARNING_REARM_S: int = 24 * 3600


## Sim time of the feed that started the current cycle. since_feed_s is a whole number of grid steps
## after a feed, so this is exact.
static func feed_unix(s: StarterState) -> int:
	return s.sim_time_unix - int(s.since_feed_s)


## Start of the current rise cycle of this starter: its last feed, or its adoption when that feed came
## before it (presets carry a feed from before born_unix; first_restart's is 14 days old). Without the
## born_unix floor, the previous starter's events would count as this cycle's.
static func cycle_start(s: StarterState) -> int:
	return maxi(feed_unix(s), s.born_unix)


## True when `id` was admitted strictly after `t`. Events of a cycle come at least one step after the
## feed that started it, so `fired_after(ledger, id, cycle_start(s))` means "fired in this cycle".
static func fired_after(ledger: EventLedger, id: StringName, t: int) -> bool:
	return ledger.last_fired_unix.has(id) and ledger.last_fired_unix[id] > t


## "Once per starter": admitted after this starter was born (StarterState.rebase_to sets born_unix).
## The scheduler's own one_time flag is per save, so a second starter would never get the event again.
static func fired_for_starter(ledger: EventLedger, id: StringName, s: StarterState) -> bool:
	return fired_after(ledger, id, s.born_unix)


## Positive and neutral events never fire while the starter shows warning signs or mold (CLAUDE.md rule 5).
static func shows_danger(d: DerivedState) -> bool:
	return d.state == &"unhealthy" or d.state == &"moldy"
