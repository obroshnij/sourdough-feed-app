class_name Milestones
extends RefCounted
## Which T1 pieces are real, not stubs. qa-engineer's suites SKIP with "waits for T1 <id>" until the id is here.
## T1 appends an id in the same commit that makes the piece real.
##   contracts     every class_name, Session API, Bus, project settings
##   m2_sim        Sim.step, Sim.feed, StateDeriver.derive, SmellModel, SimFixtures
##   m3_clock      Clock seam (FakeClock), TimePolicy
##   m4_save       SaveStore, SaveCodec, fault_point, load_from_path, quarantine
##   m5_catchup    CatchUp.run
##   p3_contracts  Phase 3 contracts: AdoptStarterAction, FeedPlanner and FeedPreview, event release and
##                 withdrawal, ReturnSummary lines and prompt, time-lapse keyframes, journal hooch and Day one
##                 entries, memorial stats, NightFade, settings haptics and keep_messages, debug time travel
##                 (event rules themselves arrive with T4 and milestone p3_rules)

const LANDED: Array[StringName] = [&"contracts", &"m2_sim", &"m3_clock", &"m4_save", &"m5_catchup", &"p3_contracts"]


static func has(id: StringName) -> bool:
	return LANDED.has(id)
