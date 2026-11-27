extends SceneTree
## Headless test runner. Contract: docs/test-plan.md §1 (R-1 to R-7), architecture.md §12.
## Run it through tests/run.sh, which imports first (R-0) and applies the outer timeout (R-6).
## Holds no test logic, and uses preload paths only, so it parses without the class cache.
##
## User args after `--`: --filter=<substring of "file::test">, --seeds=<n> (default 100),
## --update-golden (refused when CI=1).
## Output: one PASS, SKIP or FAIL line per test (a FAIL may add indented detail lines),
## then exactly `RESULT: <n> passed, <m> failed, <k> skipped` as the last line.

const LoggerScript := preload("res://tests/lib/error_logger.gd")
const CaseScript := preload("res://tests/lib/case_base.gd")
const Files := preload("res://tests/lib/qa_files.gd")
const TEST_ROOT := "res://tests"
## Timing tests run first, in a fresh process. Measured 2026-11-27: the 14-day catch-up took a median of
## about 228 ms alone but 256 to 283 ms after the ~300 other tests in the same process.
const RUN_FIRST_DIR := "res://tests/perf/"

var _logger: LoggerScript
var _passed: int = 0
var _failed: int = 0
var _skipped: int = 0
var _filter: String = ""
var _config: Dictionary = {"seeds": 100, "update_golden": false}


func _initialize() -> void:
	_logger = LoggerScript.new()
	OS.add_logger(_logger)
	_run_all()


func _run_all() -> void:
	var started_ms: int = Time.get_ticks_msec()
	var arg_error: String = _parse_args(OS.get_cmdline_user_args())
	if not arg_error.is_empty():
		_record_fail("<runner>", "<args>", PackedStringArray([arg_error]))
	else:
		_logger.take()
		var paths: PackedStringArray = Files.find(TEST_ROOT, ".gd", "test_")
		var ordered: PackedStringArray = PackedStringArray()
		for path: String in paths:
			if path.begins_with(RUN_FIRST_DIR):
				ordered.append(path)
		for path: String in paths:
			if not path.begins_with(RUN_FIRST_DIR):
				ordered.append(path)
		for path: String in ordered:
			await _run_file(path)
		var stray: PackedStringArray = _logger.take()
		if not stray.is_empty():
			_record_fail("<runner>", "<outside any test>", stray)
	print("Ran %d tests in %.1f s" % [_passed + _failed + _skipped,
			(Time.get_ticks_msec() - started_ms) / 1000.0])
	print("RESULT: %d passed, %d failed, %d skipped" % [_passed, _failed, _skipped])
	OS.remove_logger(_logger)
	quit(1 if _failed > 0 else 0)


func _parse_args(args: PackedStringArray) -> String:
	for arg: String in args:
		if arg.begins_with("--filter="):
			_filter = arg.trim_prefix("--filter=")
		elif arg.begins_with("--seeds="):
			var value: String = arg.trim_prefix("--seeds=")
			if not value.is_valid_int() or value.to_int() < 1:
				return "--seeds needs a positive integer, got \"%s\"" % value
			_config["seeds"] = value.to_int()
		elif arg == "--update-golden":
			if OS.get_environment("CI") == "1":
				return "--update-golden is refused when CI=1"
			_config["update_golden"] = true
		else:
			return "unknown argument \"%s\" (known: --filter=, --seeds=, --update-golden)" % arg
	return ""


func _run_file(path: String) -> void:
	var script: GDScript = load(path) as GDScript
	var load_errors: PackedStringArray = _logger.take()
	if script == null or not script.can_instantiate():
		var why: PackedStringArray = PackedStringArray(["cannot load or instantiate: parse or type error"])
		why.append_array(load_errors)
		_record_fail(path, "<load>", why)
		return
	if not _extends_case(script):
		_record_fail(path, "<load>", PackedStringArray(["must extend TestCase (res://tests/lib/case_base.gd)"]))
		return
	var names: PackedStringArray = PackedStringArray()
	for method: Dictionary in script.get_script_method_list():
		var name: String = method.get("name", "")
		if not name.begins_with("test_") or names.has(name):
			continue
		if (method.get("args", []) as Array).size() > 0:
			_record_fail(path, name, PackedStringArray(["test methods take no arguments"]))
			continue
		names.append(name)
	if names.is_empty():
		_record_fail(path, "<suite>", PackedStringArray(["no test_ methods: an empty suite is a failure"]))
		return
	var selected: PackedStringArray = PackedStringArray()
	for name: String in names:
		if _filter.is_empty() or ("%s::%s" % [path, name]).contains(_filter):
			selected.append(name)
	if selected.is_empty():
		return
	var instance: CaseScript = script.new()
	var init_errors: PackedStringArray = _logger.take()
	if not load_errors.is_empty() or not init_errors.is_empty():
		var why: PackedStringArray = load_errors.duplicate()
		why.append_array(init_errors)
		_record_fail(path, "<init>", why)
		return
	for name: String in selected:
		await _run_test(path, instance, name)


func _run_test(path: String, instance: CaseScript, name: String) -> void:
	instance._begin_test(_config.duplicate())
	await instance.before_each()
	await instance.call(name)
	await instance.after_each()
	var outcome: Dictionary = instance._end_test(_logger.take())
	var failures: PackedStringArray = outcome["failures"]
	var skip_reason: String = outcome["skip"]
	var checks: int = outcome["checks"]
	if not failures.is_empty():
		_record_fail(path, name, failures)
	elif not skip_reason.is_empty():
		_skipped += 1
		print("SKIP %s::%s %s" % [path, name, skip_reason])
	elif checks == 0:
		_record_fail(path, name, PackedStringArray(["no checks: a test must assert through check*()"]))
	else:
		_passed += 1
		print("PASS %s::%s (%d checks)" % [path, name, checks])


func _record_fail(path: String, test: String, messages: PackedStringArray) -> void:
	_failed += 1
	var first: String = messages[0] if not messages.is_empty() else "failed"
	print("FAIL %s::%s %s" % [path, test, first.replace("\n", "\n    ")])
	for i: int in range(1, mini(messages.size(), 20)):
		print("    " + messages[i].replace("\n", "\n    "))
	if messages.size() > 20:
		print("    ... and %d more" % (messages.size() - 20))


func _extends_case(script: Script) -> bool:
	var current: Script = script
	while current != null:
		if current == CaseScript:
			return true
		current = current.get_base_script()
	return false
