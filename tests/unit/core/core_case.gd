class_name CoreCase
extends TestCase
## Shared helpers for T1's core tests: throwaway save dirs under user://test_tmp/t1/ and payload comparison.
## Owner: T1.

const ROOT: String = "user://test_tmp/t1"
const T0: int = 1795651200

var _dirs: Array[String] = []


func after_each() -> void:
	for d: String in _dirs:
		rm_tree(d)
	_dirs.clear()


## A fresh, empty directory for one test case. Removed after the test.
func fresh_dir(case_name: String) -> String:
	var d: String = "%s/%s_%d" % [ROOT, case_name, Time.get_ticks_usec()]
	rm_tree(d)
	DirAccess.make_dir_recursive_absolute(d)
	_dirs.append(d)
	return d


static func rm_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub: String in DirAccess.get_directories_at(path):
		rm_tree(path + "/" + sub)
	for f: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path + "/" + f)
	DirAccess.remove_absolute(path)


static func copy_file(from: String, to: String) -> void:
	var f: FileAccess = FileAccess.open(to, FileAccess.WRITE)
	f.store_buffer(FileAccess.get_file_as_bytes(from))
	f.close()


static func write_text(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


static func write_bytes(path: String, bytes: PackedByteArray) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


## Sorted, full-precision payload text without `meta` (saved_unix and save_count legitimately differ).
static func payload_text(p: Dictionary) -> String:
	var copy: Dictionary = p.duplicate(true)
	copy.erase("meta")
	return JSON.stringify(copy, "", true, true)


static func session(dir: String, clock: FakeClock) -> GameSession:
	var s := GameSession.new()
	s.setup(clock, SaveStore.new(dir))
	return s
