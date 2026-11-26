class_name Milestones
extends RefCounted
## Which T1 pieces are real, not stubs. qa-engineer's suites SKIP with "waits for T1 <id>" until the id is here.
## T1 appends an id in the same commit that makes the piece real.
##   contracts   every class_name, Session API, Bus, project settings
##   m2_sim      Sim.step, Sim.feed, StateDeriver.derive, SmellModel, SimFixtures
##   m3_clock    Clock seam (FakeClock), TimePolicy
##   m4_save     SaveStore, SaveCodec, fault_point, load_from_path, quarantine
##   m5_catchup  CatchUp.run

const LANDED: Array[StringName] = [&"contracts", &"m2_sim"]


static func has(id: StringName) -> bool:
	return LANDED.has(id)
