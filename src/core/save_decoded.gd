class_name SaveDecoded
extends RefCounted
## `SaveCodec.decode()` output.

var ok: bool = false
## Migrated to the current version when ok.
var payload: Dictionary = {}
## The version in the file's header (0 for a bare payload).
var version: int = 0
## True when the file had no header (a hand-written dev fixture).
var bare: bool = false
## Why it failed, for logs and tests: &"no_header", &"bad_header", &"format", &"too_new", &"length",
## &"checksum", &"json", &"not_object", &"migration".
var reason: StringName = &""
