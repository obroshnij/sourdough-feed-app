class_name SaveStore
extends RefCounted
## Durable saves (data-models.md §9, D-024, ADR-005).
## Write: save.tmp, then rotate a *trusted* save.json to save.prev (an untrusted one goes to quarantine),
## then rename save.tmp over save.json. Renames use an instance DirAccess (POSIX rename(2) on every target;
## rename_absolute goes through Java on Android).
## Load: save.json, save.tmp, save.prev, first passing wins. Failed files are quarantined, never deleted,
## except to keep the newest 5 quarantine sets.

const FILE_MAIN: String = "save.json"
const FILE_TMP: String = "save.tmp"
const FILE_PREV: String = "save.prev"
const QUARANTINE_DIR: String = "quarantine"
const QUARANTINE_KEEP_SETS: int = 5
const FAULT_POINTS: Array[StringName] = [&"before_tmp_write", &"mid_tmp_write", &"before_rename", &"after_rename"]

var base_dir: String = "user://saves"
## Tests set one of FAULT_POINTS; save() then stops there, as if the app died.
var fault_point: StringName = &""
## Optional. Quarantine set stamps use it when set, else the system clock.
var clock: Clock = null
## save.json is the file this session loaded or wrote.
var _main_trusted: bool = false


func _init(dir: String = "user://saves") -> void:
	base_dir = dir.trim_suffix("/")


func path_of(file_name: String) -> String:
	return base_dir + "/" + file_name


func has_any_save() -> bool:
	for n: String in [FILE_MAIN, FILE_TMP, FILE_PREV]:
		if FileAccess.file_exists(path_of(n)):
			return true
	return false


## Writes `payload` durably. Returns OK, or the error (the old files are then unchanged).
func save(payload: Dictionary) -> Error:
	var err: Error = DirAccess.make_dir_recursive_absolute(base_dir)
	if err != OK:
		return err
	var bytes: PackedByteArray = SaveCodec.encode(payload)
	if fault_point == &"before_tmp_write":
		return ERR_UNAVAILABLE
	var f: FileAccess = FileAccess.open(path_of(FILE_TMP), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	if fault_point == &"mid_tmp_write":
		@warning_ignore("integer_division")
		f.store_buffer(bytes.slice(0, bytes.size() / 2))
		f.close()
		return ERR_UNAVAILABLE
	var stored: bool = f.store_buffer(bytes)
	var length: int = f.get_length()
	f.close()
	if not stored or length != bytes.size():
		return ERR_FILE_CANT_WRITE
	if fault_point == &"before_rename":
		return ERR_UNAVAILABLE
	var dir: DirAccess = DirAccess.open(base_dir)
	if dir == null:
		return DirAccess.get_open_error()
	if dir.file_exists(FILE_MAIN):
		if _main_trusted:
			err = dir.rename(FILE_MAIN, FILE_PREV)
			if err != OK:
				return err
		else:
			_quarantine(dir, [FILE_MAIN], _next_stamp(dir))
	if fault_point == &"after_rename":
		return ERR_UNAVAILABLE
	err = dir.rename(FILE_TMP, FILE_MAIN)
	if err != OK:
		return err
	_main_trusted = true
	return OK


## Tries save.json, save.tmp, save.prev. `validator` (payload -> bool) adds the from_dict check.
func load_latest(validator: Callable = Callable()) -> SaveLoadReport:
	var report := SaveLoadReport.new()
	_main_trusted = false
	var dir: DirAccess = DirAccess.open(base_dir)
	if dir == null:
		report.first_run = true
		return report
	var stamp: int = -1
	var any_file: bool = false
	for n: String in [FILE_MAIN, FILE_TMP, FILE_PREV]:
		if not dir.file_exists(n):
			continue
		any_file = true
		var dec: SaveDecoded = SaveCodec.decode(FileAccess.get_file_as_bytes(path_of(n)))
		var good: bool = dec.ok and (not validator.is_valid() or _accepts(validator, dec.payload))
		if good:
			report.ok = true
			report.payload = dec.payload
			report.source = n
			if n == FILE_TMP:
				# Promote at once, so the loaded file is the trusted save.json before any write.
				if dir.rename(FILE_TMP, FILE_MAIN) == OK:
					_main_trusted = true
			elif n == FILE_MAIN:
				_main_trusted = true
			break
		if stamp < 0:
			stamp = _next_stamp(dir)
		report.quarantined.append_array(_quarantine(dir, [n], stamp))
	if not any_file:
		report.first_run = true
	elif not report.ok:
		report.recovered_from = "quarantine"
	return report


## A dev fixture or a test file: a full save file or a bare payload (data-models §9.5). {} on failure.
func load_from_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var dec: SaveDecoded = SaveCodec.decode(FileAccess.get_file_as_bytes(path), true)
	return dec.payload if dec.ok else {}


static func _accepts(validator: Callable, payload: Dictionary) -> bool:
	var verdict: Variant = validator.call(payload)
	return typeof(verdict) == TYPE_BOOL and verdict == true


func _quarantine(dir: DirAccess, names: Array[String], stamp: int) -> PackedStringArray:
	var moved: PackedStringArray = []
	if not dir.dir_exists(QUARANTINE_DIR):
		dir.make_dir(QUARANTINE_DIR)
	for n: String in names:
		var dest: String = "%s/%d_%s" % [QUARANTINE_DIR, stamp, n]
		if dir.rename(n, dest) == OK:
			moved.append(dest)
	_prune_quarantine()
	return moved


## A set stamp newer than every existing set, so sets stay distinct even within one second.
func _next_stamp(_dir: DirAccess) -> int:
	var now: int = clock.now_unix() if clock != null else int(Time.get_unix_time_from_system())
	var newest: int = -1
	for s: int in _quarantine_stamps():
		newest = maxi(newest, s)
	return maxi(now, newest + 1)


func _quarantine_stamps() -> Array[int]:
	var stamps: Array[int] = []
	var q: DirAccess = DirAccess.open(path_of(QUARANTINE_DIR))
	if q == null:
		return stamps
	for f: String in q.get_files():
		var head: String = f.get_slice("_", 0)
		if head.is_valid_int() and not stamps.has(head.to_int()):
			stamps.append(head.to_int())
	stamps.sort()
	return stamps


func _prune_quarantine() -> void:
	var stamps: Array[int] = _quarantine_stamps()
	if stamps.size() <= QUARANTINE_KEEP_SETS:
		return
	var q: DirAccess = DirAccess.open(path_of(QUARANTINE_DIR))
	if q == null:
		return
	var drop: Array[int] = stamps.slice(0, stamps.size() - QUARANTINE_KEEP_SETS)
	for f: String in q.get_files():
		var head: String = f.get_slice("_", 0)
		if head.is_valid_int() and drop.has(head.to_int()):
			q.remove(f)
