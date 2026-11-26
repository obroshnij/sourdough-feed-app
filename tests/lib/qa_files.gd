class_name QaFiles
extends RefCounted
## File discovery shared by the runner and the lints.
## Skips hidden folders and any folder that holds a `.gdignore`, the same folders the
## editor skips, so deliberately broken fixtures in tests/runner_selftest/ stay out.


## Every file under `dir` (recursive) whose name ends with `suffix` and starts with
## `prefix`, as sorted res:// paths. Empty when `dir` doesn't exist.
static func find(dir: String, suffix: String, prefix: String = "") -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return out
	_walk(dir.trim_suffix("/"), suffix, prefix, out)
	out.sort()
	return out


static func is_ignored_dir(dir: String) -> bool:
	return dir.get_file().begins_with(".") or FileAccess.file_exists(dir.path_join(".gdignore"))


static func _walk(dir: String, suffix: String, prefix: String, out: PackedStringArray) -> void:
	if is_ignored_dir(dir):
		return
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(suffix) and file.begins_with(prefix):
			out.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		_walk(dir.path_join(sub), suffix, prefix, out)
