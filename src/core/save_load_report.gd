class_name SaveLoadReport
extends RefCounted
## What `SaveStore.load_latest()` found (data-models.md §9.4).

var ok: bool = false
var payload: Dictionary = {}
## The winning file name: "save.json", "save.tmp" (already promoted to save.json) or "save.prev". "" if none.
var source: String = ""
## Paths (relative to the base dir) of the files moved to quarantine during this load.
var quarantined: PackedStringArray = []
## No candidate file existed at all: the first-run flow.
var first_run: bool = false
## "quarantine" when files existed but none passed (a new starter follows). Else "".
var recovered_from: String = ""
