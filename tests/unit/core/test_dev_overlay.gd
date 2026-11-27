extends CoreCase
## The F3 dev overlay drives the debug time scale and jumps, through the time-travel sandbox. Owner: T1.


func test_overlay_drives_debug_time_through_the_sandbox() -> void:
	if not require(&"p3_rules"):
		return
	var dir: String = fresh_dir("overlay")
	_dirs.append(dir + GameSession.TIME_TRAVEL_SUFFIX)
	var s := GameSession.new()
	s.setup(DebugClock.new(1.0), SaveStore.new(dir))
	s.boot()
	s.apply(AdoptStarterAction.new("Bramble"))
	var o := DevOverlay.new()
	o.session = s
	o._ready()
	check(not o.visible, "hidden until F3")
	check(o.set_scale_to(600.0) and s.get_debug_time_scale() == 600.0, "600x")
	check(s.is_time_traveling(), "time travel saves to the sandbox")
	var r: CatchUpResult = o.jump(86400)
	check(r.simulated_s >= 86400 - 60 and s.get_return_summary().show, "+1 d plays the return flow")
	check(o.set_scale_to(1.0) and s.is_time_traveling(), "back to 1x, still in the sandbox for this run")
	check(InputMap.has_action(&"dev_overlay"), "F3 is mapped")
	o.free()
	s.free()
