class_name RuleIndex
extends RefCounted
## The slice's event rules (D-017, events-catalog §3 and §4.9), one instance each. T1's
## `EventRules.registry()` returns this list. The order is the tie-break when two rules fire on one step,
## and it follows the return summary's keep priority (game-mechanics §8): attention, milestone, peak,
## hunger and hooch, then other info.


static func all() -> Array[EventRule]:
	var rules: Array[EventRule] = [
		RuleMoldFound.new(),
		RuleWarningSigns.new(),
		RuleFirstRise.new(),
		RulePeakNow.new(),
		RulePeakedWhileAway.new(),
		RuleHungryAgain.new(),
		RuleHoochForming.new(),
		RuleBackToStrength.new(),
	]
	return rules
