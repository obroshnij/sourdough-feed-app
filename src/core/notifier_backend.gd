class_name NotifierBackend
extends RefCounted
## Where local notifications go (D-007, D-057). This base is the stand-in used on desktop, in tests and until
## the iOS plugin is downloaded and checked on the user's iPhone: it schedules nothing on the device, keeps the
## pending notifications in memory and records every call. The iOS backend will subclass it.

## id -> {"fire_unix": int, "title": String, "body": String}.
var pending: Dictionary[String, Dictionary] = {}
## Every call in order, for tests: "permission", "schedule:<id>@<fire_unix>", "cancel:<id>".
var calls: PackedStringArray = []
## What request_permission() answers. Tests set it false to see a refusal.
var grant: bool = true


## Asks the OS for permission to notify (iOS shows its prompt once). True when allowed.
func request_permission() -> bool:
	calls.append("permission")
	return grant


## Replaces any pending notification with the same id.
func schedule(id: String, fire_unix: int, title: String, body: String) -> void:
	calls.append("schedule:%s@%d" % [id, fire_unix])
	pending[id] = {"fire_unix": fire_unix, "title": title, "body": body}


func cancel(id: String) -> void:
	calls.append("cancel:" + id)
	pending.erase(id)
