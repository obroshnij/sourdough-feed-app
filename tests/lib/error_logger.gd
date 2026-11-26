extends Logger
## Collects engine and script errors for tests/run_tests.gd (test-plan R-3).
## A runtime error aborts a test function silently and the run carries on, so this
## logger is the only reliable way to see it. Warnings are ignored.
## Logger callbacks can arrive from any thread, so every access holds the mutex.

var _mutex: Mutex = Mutex.new()
var _errors: PackedStringArray = PackedStringArray()


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	var kind: String = "SCRIPT ERROR" if error_type == ERROR_TYPE_SCRIPT else "ERROR"
	var text: String = "%s: %s" % [kind, code]
	if not rationale.is_empty():
		text += " (%s)" % rationale
	text += " at %s:%d in %s" % [file, line, function]
	_mutex.lock()
	_errors.append(text)
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass


## Returns every error logged since the last call, and clears the list.
func take() -> PackedStringArray:
	_mutex.lock()
	var out: PackedStringArray = _errors
	_errors = PackedStringArray()
	_mutex.unlock()
	return out
