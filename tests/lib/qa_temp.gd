class_name QaTemp
extends RefCounted
## Throwaway folders under user://qa_tmp/ for save and session tests. Each test makes its own
## and removes it in after_each(), so no test sees another's files.

const ROOT := "user://qa_tmp"

static var _counter: int = 0


## A new, empty folder. `label` only makes failures easier to read.
static func make(label: String) -> String:
	_counter += 1
	var dir: String = "%s/%s_%d_%d" % [ROOT, label.validate_filename(), Time.get_ticks_usec(), _counter]
	remove(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	return dir


## Deletes `dir` and everything in it. Silent when it doesn't exist.
static func remove(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for file: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		remove(dir.path_join(sub))
	DirAccess.remove_absolute(dir)


static func write(path: String, bytes: PackedByteArray) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


static func read(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path)


## Copies every file in `from` (not recursive) into `to`, which is created if needed.
static func copy_files(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	for file: String in DirAccess.get_files_at(from):
		write(to.path_join(file), read(from.path_join(file)))
