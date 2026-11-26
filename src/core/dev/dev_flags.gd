class_name DevFlags
extends RefCounted
## Debug-build command-line flags (architecture.md §6.1, LINT-10). Pass them after `--`:
##   --fixture=<path>    load a save or bare payload instead of user://saves (state shown as of now)
##   --time-scale=<x>    DebugClock time scale
##   --perf-log=<csv>    PerfLog output (Phase 2 later)
##   --capture=<png>     capture a frame and quit (T2)
## In release builds every field stays empty.

var fixture: String = ""
var time_scale: float = 1.0
var perf_log: String = ""
var capture: String = ""


static func parse() -> DevFlags:
	var f := DevFlags.new()
	if not OS.is_debug_build():
		return f
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture="):
			f.fixture = arg.trim_prefix("--fixture=")
		elif arg.begins_with("--time-scale="):
			var v: String = arg.trim_prefix("--time-scale=")
			if v.is_valid_float():
				f.time_scale = maxf(v.to_float(), 0.0)
		elif arg.begins_with("--perf-log="):
			f.perf_log = arg.trim_prefix("--perf-log=")
		elif arg.begins_with("--capture="):
			f.capture = arg.trim_prefix("--capture=")
	return f
