class_name T1Api
extends RefCounted
## Runtime access to T1's classes (sim and core), so QA tests compile before T1's code
## exists and never break the parse when a T1 class is renamed.
##
## Gate: T1 owns `src/core/milestones.gd` (`class_name Milestones`) with
## `const LANDED: Array[StringName]`. A test that needs real T1 behavior calls
## `require(&"<id>")` on TestCase: it SKIPs, with the reason below, until T1 lists the id.
## Stubs from the contracts commit therefore skip instead of failing, and the test turns
## on in the same commit that makes the code real.

const MILESTONES: Dictionary[StringName, String] = {
	&"contracts": "the contracts commit (class_name stubs, project.godot)",
	&"m2_sim": "the real sim: Sim.step, Sim.feed, StateDeriver.derive, SimFixtures",
	&"m3_clock": "FakeClock and TimePolicy",
	&"m4_save": "SaveStore with fault_point, load_from_path and quarantine",
	&"m5_catchup": "CatchUp.run and GameSession.on_resume",
	&"p3_contracts": "the Phase 3 contracts: return summary, last_feed_action, debug time travel, Session.shutdown, NightFade, naming",
}


## The script registered under `class_id`, or null if no such global class exists.
static func find_script(class_id: StringName) -> GDScript:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if StringName(entry.get("class", "")) == class_id:
			return load(String(entry.get("path", ""))) as GDScript
	return null


## QA only: `QA_FORCE_MILESTONES=m3_clock,m4_save tests/run.sh` runs gated tests before T1
## declares them, to report problems early. Never set it in CI or in a green-run report.
static func forced(milestone: StringName) -> bool:
	var ids: PackedStringArray = OS.get_environment("QA_FORCE_MILESTONES").split(",", false)
	return ids.has(String(milestone)) or ids.has("all")


static func landed(milestone: StringName) -> bool:
	if forced(milestone):
		return true
	var script: GDScript = find_script(&"Milestones")
	if script == null:
		return false
	var ids: Variant = script.get_script_constant_map().get(&"LANDED", [])
	if typeof(ids) != TYPE_ARRAY:
		return false
	for id: Variant in ids:
		if typeof(id) in [TYPE_STRING, TYPE_STRING_NAME] and StringName(id) == milestone:
			return true
	return false


## Empty when the milestone has landed, otherwise the SKIP reason.
static func missing_reason(milestone: StringName) -> String:
	if landed(milestone):
		return ""
	var what: String = MILESTONES.get(milestone, "an unknown milestone")
	return "waits for T1 milestone %s (%s)" % [milestone, what]
