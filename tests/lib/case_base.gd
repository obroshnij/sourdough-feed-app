class_name TestCase
extends RefCounted
## Base class for every `tests/**/test_*.gd` file (test-plan R-2, R-4).
##
## - Each `func test_*() -> void` with no arguments is one test. It may `await`.
## - Assert only through the `check*` methods. `assert()` is stripped from release builds,
##   and a test that makes zero checks fails.
## - Any engine or script error logged during a test fails it (R-3), unless the test
##   declared it first with `expect_error()`.
## - `skip(reason)` marks the test skipped. Skips are printed and counted, never passes.
##   `require(milestone)` skips until T1 lists that milestone (see t1_api.gd).

const _T1 := preload("res://tests/lib/t1_api.gd")

var _checks: int = 0
var _failures: PackedStringArray = PackedStringArray()
var _skip_reason: String = ""
var _expected_errors: PackedStringArray = PackedStringArray()
var _config: Dictionary = {}


## Optional hooks. They may `await`.
func before_each() -> void:
	pass


func after_each() -> void:
	pass


# ---------------------------------------------------------------- checks

func check(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
	return condition


func check_eq(actual: Variant, expected: Variant, message: String = "") -> bool:
	if typeof(actual) == TYPE_DICTIONARY and typeof(expected) == TYPE_DICTIONARY:
		return check(values_equal(actual, expected),
				"%sdictionaries differ: %s" % [_prefix(message), dict_diff(actual, expected)])
	return check(values_equal(actual, expected),
			"%sexpected %s, got %s" % [_prefix(message), show(expected), show(actual)])


func check_ne(actual: Variant, unexpected: Variant, message: String = "") -> bool:
	return check(not values_equal(actual, unexpected),
			"%sexpected anything but %s" % [_prefix(message), show(unexpected)])


## |actual - expected| <= rel * max(|actual|, |expected|) + abs_tol. NaN never passes.
func check_close(actual: float, expected: float, rel: float, abs_tol: float, message: String = "") -> bool:
	return check(is_close(actual, expected, rel, abs_tol),
			"%sexpected %s, got %s (rel %s, abs %s)" % [_prefix(message), show(expected), show(actual),
			show(rel), show(abs_tol)])


func check_between(actual: float, low: float, high: float, message: String = "") -> bool:
	return check(not is_nan(actual) and actual >= low and actual <= high,
			"%sexpected %s to %s, got %s" % [_prefix(message), show(low), show(high), show(actual)])


func fail(message: String) -> void:
	check(false, message)


## Marks the test skipped. Return right after calling it. A skipped test that also
## recorded a failure is reported as failed.
func skip(reason: String) -> void:
	_skip_reason = reason


## True when T1 has landed `milestone`. Otherwise skips with the reason and returns false:
## `if not require(&"m4_save"): return`
func require(milestone: StringName) -> bool:
	var reason: String = _T1.missing_reason(milestone)
	if reason.is_empty():
		return true
	skip(reason)
	return false


## Declares that an error containing `fragment` will be logged during this test. It then
## doesn't fail the test, and the test fails if it never appears.
func expect_error(fragment: String) -> void:
	_expected_errors.append(fragment)


## Seeds per property or golden test: `--seeds=<n>`, default 100 (R-7).
func seeds() -> int:
	return int(_config.get("seeds", 100))


## True when run with `--update-golden` (refused when CI=1, R-7).
func update_golden() -> bool:
	return bool(_config.get("update_golden", false))


# ---------------------------------------------------------------- helpers

static func is_close(a: float, b: float, rel: float, abs_tol: float) -> bool:
	if is_nan(a) or is_nan(b):
		return false
	return absf(a - b) <= rel * maxf(absf(a), absf(b)) + abs_tol


## Equality that never raises on mismatched types: int and float compare as numbers,
## String and StringName as text, anything else of different types is unequal.
static func values_equal(a: Variant, b: Variant) -> bool:
	var ta: int = typeof(a)
	var tb: int = typeof(b)
	if ta == tb:
		return a == b
	if ta in [TYPE_INT, TYPE_FLOAT] and tb in [TYPE_INT, TYPE_FLOAT]:
		return float(a) == float(b)
	if ta in [TYPE_STRING, TYPE_STRING_NAME] and tb in [TYPE_STRING, TYPE_STRING_NAME]:
		return String(a) == String(b)
	return false


## Full-precision text for messages: floats round-trip, strings are quoted.
static func show(value: Variant) -> String:
	match typeof(value):
		TYPE_FLOAT:
			return JSON.stringify(value, "", false, true)
		TYPE_STRING, TYPE_STRING_NAME:
			return "\"%s\"" % String(value)
		_:
			return str(value)


## The keys whose values differ, as "key: expected X, got Y; ...". Missing keys show as <none>.
static func dict_diff(actual: Dictionary, expected: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var keys: Array = expected.keys()
	for key: Variant in actual.keys():
		if not expected.has(key):
			keys.append(key)
	for key: Variant in keys:
		var has_a: bool = actual.has(key)
		var has_e: bool = expected.has(key)
		if has_a and has_e and values_equal(actual[key], expected[key]):
			continue
		parts.append("%s: expected %s, got %s" % [str(key), show(expected[key]) if has_e else "<none>",
				show(actual[key]) if has_a else "<none>"])
	return "; ".join(parts)


static func _prefix(message: String) -> String:
	return "" if message.is_empty() else message + ": "


# ---------------------------------------------------------------- runner interface

func _begin_test(config: Dictionary) -> void:
	_checks = 0
	_failures = PackedStringArray()
	_skip_reason = ""
	_expected_errors = PackedStringArray()
	_config = config


## Returns {"failures": PackedStringArray, "skip": String, "checks": int}. `logged` holds
## the errors the runner's Logger saw during the test.
func _end_test(logged: PackedStringArray) -> Dictionary:
	var failures: PackedStringArray = _failures.duplicate()
	var unseen: PackedStringArray = _expected_errors.duplicate()
	for error: String in logged:
		var expected: bool = false
		for i: int in unseen.size():
			if error.contains(unseen[i]):
				unseen.remove_at(i)
				expected = true
				break
		if not expected:
			failures.append("logged: " + error)
	for fragment: String in unseen:
		failures.append("expected an error containing \"%s\", none was logged" % fragment)
	return {"failures": failures, "skip": _skip_reason, "checks": _checks}
