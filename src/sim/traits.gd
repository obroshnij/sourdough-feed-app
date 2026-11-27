class_name Traits
extends RefCounted
## Personality traits (P1, progression.md §5, narrative.md §7). Traits change wording only, never biology:
## nothing in the sim reads them. Pure and deterministic (no RNG): a trait comes from what the player did,
## recorded in PlayerHistory.daily, the rolling ring of the last 14 local days.
##
## Each trait scores its progress toward its signal threshold (1.0 = the threshold is met). A trait with two
## signals ("or") takes the better one. T1's reading of progression §5, listed as an open decision:
##   energetic  max(share of hours at 24 C or warmer / 0.5, days with 2+ feeds at 1:1:1 or 1:2:2 / 10)
##   patient    max(share of hours at 18 C or cooler / 0.5, share of fed days with exactly one feed at
##              1:5:5 or thinner / 0.5)   ("mostly" read as half the fed days)
##   resilient  comebacks / 2   (a feed from unhealthy, or after 24 or more weighted starved hours)
##   sensitive  changes / 8     (a move to another place, or a feed that changed flour, ratio or hydration)
## Reveal: the first feed that brings maturity to `steady` (0.33). The highest score wins; ties go by
## TIE_ORDER. Every starter gets a trait. Drift: when another trait leads at 14 day rolls in a row and the
## last change was 28 days ago or more, it becomes dominant.

const IDS: Array[StringName] = [&"patient", &"energetic", &"sensitive", &"resilient"]
## progression §5: fixed tie-break order.
const TIE_ORDER: Array[StringName] = [&"resilient", &"patient", &"energetic", &"sensitive"]
const WARM_C: float = 24.0
const COOL_C: float = 18.0
const WARM_SHARE: float = 0.5
const COOL_SHARE: float = 0.5
const BUSY_DAYS: float = 10.0
const BUSY_MIN_FEEDS: int = 2
const BUSY_MAX_RATIO: float = 2.0
const SLOW_SHARE: float = 0.5
const SLOW_MIN_RATIO: float = 5.0
const COMEBACKS: float = 2.0
const CHANGES: float = 8.0
## A comeback feed: the starter had starved at least this many weighted hours (progression §4 `comeback`).
const COMEBACK_STARVED_H: float = 24.0
## A hydration change of at least this many points counts as a change.
const HYDRATION_CHANGE_PCT: float = 5.0
const DRIFT_DAYS: int = 14
const DRIFT_MIN_GAP_S: int = 28 * 86400


## Each trait's score over the ring. 0 for every trait on an empty ring.
static func scores(daily: Array[DailyBucket]) -> Dictionary[StringName, float]:
	var hours: float = 0.0
	var warm: float = 0.0
	var cool: float = 0.0
	var busy: int = 0
	var fed_days: int = 0
	var slow: int = 0
	var comebacks: int = 0
	var changes: int = 0
	for b: DailyBucket in daily:
		hours += b.hours
		warm += b.hours_warm
		cool += b.hours_cool
		comebacks += b.comebacks
		changes += b.changes
		if b.feeds <= 0:
			continue
		fed_days += 1
		var mean_ratio: float = b.ratio_sum / float(b.feeds)
		if b.feeds >= BUSY_MIN_FEEDS and mean_ratio <= BUSY_MAX_RATIO + 0.001:
			busy += 1
		if b.feeds == 1 and mean_ratio >= SLOW_MIN_RATIO - 0.001:
			slow += 1
	var warm_share: float = warm / hours if hours > 0.0 else 0.0
	var cool_share: float = cool / hours if hours > 0.0 else 0.0
	var slow_share: float = float(slow) / float(fed_days) if fed_days > 0 else 0.0
	return {
		&"patient": maxf(cool_share / COOL_SHARE, slow_share / SLOW_SHARE),
		&"energetic": maxf(warm_share / WARM_SHARE, float(busy) / BUSY_DAYS),
		&"sensitive": float(changes) / CHANGES,
		&"resilient": float(comebacks) / COMEBACKS,
	}


## The highest score, ties broken by TIE_ORDER. Never empty.
static func leader(daily: Array[DailyBucket]) -> StringName:
	var s: Dictionary[StringName, float] = scores(daily)
	var best: StringName = TIE_ORDER[0]
	for id: StringName in TIE_ORDER:
		if s[id] > s[best] + 0.000001:
			best = id
	return best
