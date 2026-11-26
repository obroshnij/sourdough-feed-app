class_name ReturnSummary
extends RefCounted
## "While you were away" selection (game-mechanics.md §8). Pure. At most 3 lines and 1 prompt.
## Phase 2 skeleton: priority by tier only. Phase 3 adds the milestone, peak and hunger classes.

const MAX_LINES: int = 3

var lines: Array[SimEvent] = []
## The one attention event, else the newest nudge, else null.
var prompt: SimEvent = null
## Not shown. Always written to the journal.
var dropped: Array[SimEvent] = []
## The absence passed the 14-day catch-up cap (D-024).
var capped: bool = false
## Away long enough to show the summary at all (AWAY_SUMMARY_MIN_S).
var show: bool = false


static func build(result: CatchUpResult) -> ReturnSummary:
	var s := ReturnSummary.new()
	s.capped = result.capped
	s.show = result.simulated_s >= SimConstants.AWAY_SUMMARY_MIN_S \
		and (not result.events.is_empty() or not result.transitions.is_empty())
	var infos: Array[SimEvent] = []
	for e: SimEvent in result.events:
		if e.tier == &"attention":
			if s.prompt == null or s.prompt.tier != &"attention":
				if s.prompt != null:
					s.dropped.append(s.prompt)
				s.prompt = e
			else:
				s.dropped.append(e)
		elif e.tier == &"nudge":
			if s.prompt == null or s.prompt.tier == &"nudge":
				if s.prompt != null:
					s.dropped.append(s.prompt)
				s.prompt = e
			else:
				s.dropped.append(e)
		else:
			infos.append(e)
	# Newest info first; the oldest is dropped first.
	for i: int in range(infos.size() - 1, -1, -1):
		if s.lines.size() < MAX_LINES:
			s.lines.append(infos[i])
		else:
			s.dropped.append(infos[i])
	return s
