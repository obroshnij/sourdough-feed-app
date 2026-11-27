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
##   p3_rules      EventRules.registry() is T4's RuleIndex, live in catch-up, live ticks and every action;
##                 launch and resume catch-ups of 2 h or more run on a WorkerThreadPool thread in the real app
##                 (boot_async, resume_async, wait_for_catch_up); D-048's strong-peak reference
##   p4_contracts  Phase 4 contracts: hydration presets (FeedAction.from_preset), unlocks, traits, the empty
##                 jar (DiscardStarterAction.to_empty_jar, StartAgainAction), the onboarding demo (begin_demo,
##                 play_demo, demo_start), the journal merge of quick moves (OD-22), Notifier, Haptics,
##                 sound settings, EventContext.prev_env, feed_ref_at_peak_s, the smell check

const LANDED: Array[StringName] = [
	&"contracts", &"m2_sim", &"m3_clock", &"m4_save", &"m5_catchup", &"p3_contracts", &"p3_rules",
	&"p4_contracts",
]


static func has(id: StringName) -> bool:
	return LANDED.has(id)
