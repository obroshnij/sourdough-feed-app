class_name CatchUpResult
extends RefCounted
## What a catch-up produced (data-models.md §8). Carried by session_ready and resumed; may be empty.
##
## The time-lapse feed (`keyframes`) is bounded and pure:
## - Cap: at most MAX_KEYFRAMES (30) frames, matching AC-09.5's 30 snapshots.
## - Always kept: the first frame (the state before the first step), every state transition (at most
##   MAX_TRANSITION_FRAMES, 16; a catch-up has no feeds, so the state walks down its chain once and
##   real absences give 11 or fewer), and the last frame (the state at to_unix).
## - Filled with evenly spaced samples (one every ceil(steps / 30) steps). When the total is over the cap,
##   the sample with the shortest gap to the frame before it is dropped first, until it fits.
## - Sorted by at_unix, one frame per sim time.

const MAX_SNAPSHOTS: int = 30
const MAX_KEYFRAMES: int = 30
const MAX_TRANSITION_FRAMES: int = 16
## Playback length (game-mechanics §8): 3 s at the 1 h return threshold, growing to 6 s at 24 h and beyond.
const TIME_LAPSE_MIN_S: float = 3.0
const TIME_LAPSE_MAX_S: float = 6.0
const TIME_LAPSE_FULL_AT_S: int = 24 * 3600

var from_unix: int = 0
var to_unix: int = 0
var simulated_s: int = 0
## The absence passed the 14-day cap; the state was held and the clock jumped to now.
var capped: bool = false
## The clock was more than 6 h behind the anchor and was re-anchored (architecture §5.3).
var reanchored: bool = false
var steps: int = 0
## Each {"at_unix": int, "from": String, "to": String, "cause": String}.
var transitions: Array[Dictionary] = []
var events: Array[SimEvent] = []
## At most 30, evenly spaced (Phase 2 field; the time-lapse plays `keyframes`).
var snapshots: Array[VisualParams] = []
## The time-lapse feed, at most 30 frames, oldest first (rules above). Empty when nothing was stepped.
var keyframes: Array[TimeLapseKeyframe] = []
## Set by Session on launch and resume: true when the return flow should play the time-lapse, which is when
## the summary shows (ReturnSummary.show) and the "Show time-lapse on return" setting is on.
var play_time_lapse: bool = false
## For example peak_unix, peak_rise, hooch_first_unix.
var notable: Dictionary = {}


static func empty(at_unix: int) -> CatchUpResult:
	var r := CatchUpResult.new()
	r.from_unix = at_unix
	r.to_unix = at_unix
	return r


## Seconds the time-lapse should take: 3 s for a 1 h absence, rising linearly to 6 s at 24 h and beyond.
func time_lapse_duration_s() -> float:
	var span: float = float(TIME_LAPSE_FULL_AT_S - SimConstants.AWAY_SUMMARY_MIN_S)
	var t: float = clampf(float(simulated_s - SimConstants.AWAY_SUMMARY_MIN_S) / span, 0.0, 1.0)
	return lerpf(TIME_LAPSE_MIN_S, TIME_LAPSE_MAX_S, t)


## Merges the collected frames into `keyframes` under the rules in the class comment. CatchUp calls it once.
func finish_keyframes(first: TimeLapseKeyframe, collected: Array[TimeLapseKeyframe]) -> void:
	var all: Array[TimeLapseKeyframe] = []
	if first != null:
		all.append(first)
	all.append_array(collected)
	all.sort_custom(func(a: TimeLapseKeyframe, b: TimeLapseKeyframe) -> bool:
		if a.at_unix != b.at_unix:
			return a.at_unix < b.at_unix
		return a.transition and not b.transition)
	var merged: Array[TimeLapseKeyframe] = []
	for k: TimeLapseKeyframe in all:
		if not merged.is_empty() and merged[-1].at_unix == k.at_unix:
			merged[-1].transition = merged[-1].transition or k.transition
			continue
		merged.append(k)
	while merged.size() > MAX_KEYFRAMES:
		var drop: int = -1
		var gap: int = 0
		for i: int in range(1, merged.size() - 1):
			if merged[i].transition:
				continue
			var g: int = merged[i].at_unix - merged[i - 1].at_unix
			if drop < 0 or g < gap:
				drop = i
				gap = g
		if drop < 0:
			break
		merged.remove_at(drop)
	keyframes = merged
