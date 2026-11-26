class_name DictReader
extends RefCounted
## Quiet, typed reads from a parsed-JSON Dictionary (data-models.md §1).
## It checks typeof() before every read and never logs an engine error. A missing key or a wrong type
## sets `ok` to false and returns a zero value, so `from_dict` can return null on a corrupt file.
## JSON gives every number back as a float, so integer fields accept whole floats.

const _MAX_SAFE_INT: float = 9007199254740992.0

var ok: bool = true
var _d: Dictionary


func _init(d: Dictionary) -> void:
	_d = d


func has(key: String) -> bool:
	return _d.has(key)


func num(key: String) -> float:
	if not _d.has(key):
		ok = false
		return 0.0
	return _to_float(_d[key])


func integer(key: String) -> int:
	if not _d.has(key):
		ok = false
		return 0
	return _to_int(_d[key])


func text(key: String) -> String:
	if not _d.has(key):
		ok = false
		return ""
	var v: Variant = _d[key]
	var t: int = typeof(v)
	if t == TYPE_STRING or t == TYPE_STRING_NAME:
		var s: String = v
		return s
	ok = false
	return ""


func id(key: String) -> StringName:
	return StringName(text(key))


func flag(key: String) -> bool:
	if not _d.has(key):
		ok = false
		return false
	var v: Variant = _d[key]
	if typeof(v) == TYPE_BOOL:
		var b: bool = v
		return b
	ok = false
	return false


func dict(key: String) -> Dictionary:
	if not _d.has(key):
		ok = false
		return {}
	var v: Variant = _d[key]
	if typeof(v) == TYPE_DICTIONARY:
		var out: Dictionary = v
		return out
	ok = false
	return {}


func list(key: String) -> Array:
	if not _d.has(key):
		ok = false
		return []
	var v: Variant = _d[key]
	if typeof(v) == TYPE_ARRAY:
		var out: Array = v
		return out
	ok = false
	return []


func num_map(key: String) -> Dictionary[StringName, float]:
	var out: Dictionary[StringName, float] = {}
	var src: Dictionary = dict(key)
	for k: Variant in src:
		if typeof(k) != TYPE_STRING and typeof(k) != TYPE_STRING_NAME:
			ok = false
			continue
		out[StringName("%s" % [k])] = _to_float(src[k])
	return out


func int_map(key: String) -> Dictionary[StringName, int]:
	var out: Dictionary[StringName, int] = {}
	var src: Dictionary = dict(key)
	for k: Variant in src:
		if typeof(k) != TYPE_STRING and typeof(k) != TYPE_STRING_NAME:
			ok = false
			continue
		out[StringName("%s" % [k])] = _to_int(src[k])
	return out


func bool_map(key: String) -> Dictionary[StringName, bool]:
	var out: Dictionary[StringName, bool] = {}
	var src: Dictionary = dict(key)
	for k: Variant in src:
		var v: Variant = src[k]
		if (typeof(k) != TYPE_STRING and typeof(k) != TYPE_STRING_NAME) or typeof(v) != TYPE_BOOL:
			ok = false
			continue
		var b: bool = v
		out[StringName("%s" % [k])] = b
	return out


## Payload dictionaries hold primitives only (int, float, String, bool), per data-models §5.
func primitives(key: String) -> Dictionary:
	var src: Dictionary = dict(key)
	for k: Variant in src:
		var t: int = typeof(src[k])
		if typeof(k) != TYPE_STRING or not (t == TYPE_INT or t == TYPE_FLOAT or t == TYPE_STRING or t == TYPE_BOOL):
			ok = false
			return {}
	return src


## D-040: a float's save form is the 16-character hex of its 64-bit pattern (little-endian bytes, as
## PackedByteArray.encode_double writes them): 0.25 is "000000000000d03f". Lossless, unlike JSON numbers.
static func float_to_hex(x: float) -> String:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, x)
	return b.hex_encode()


static func is_float_hex(s: String) -> bool:
	if s.length() != 16:
		return false
	for c: String in s:
		if not "0123456789abcdef".contains(c):
			return false
	return true


## A float from a JSON number or a D-040 hex string. NaN when it is neither (callers check).
static func float_of(v: Variant) -> float:
	var t: int = typeof(v)
	if t == TYPE_FLOAT:
		var x: float = v
		return x
	if t == TYPE_INT:
		var n: int = v
		return float(n)
	if t == TYPE_STRING:
		var s: String = v
		if is_float_hex(s):
			return s.hex_decode().decode_double(0)
	return NAN


## The canonical form for free-form dictionaries (event payloads, journal args and data): whole numbers are
## ints, everything else unchanged, recursively. JSON gives every number back as a float, so without this a
## save and load would turn 50 into 50.0 and change the saved text (PROP-02).
static func canonical(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			var x: float = v
			if not is_nan(x) and not is_inf(x) and x == floorf(x) and absf(x) < _MAX_SAFE_INT:
				return int(x)
			return x
		TYPE_DICTIONARY:
			var src: Dictionary = v
			var out: Dictionary = {}
			for k: Variant in src:
				out[k] = canonical(src[k])
			return out
		TYPE_ARRAY:
			var arr: Array = v
			var list: Array = []
			for item: Variant in arr:
				list.append(canonical(item))
			return list
	return v


static func canonical_dict(d: Dictionary) -> Dictionary:
	var out: Dictionary = canonical(d)
	return out


## Accepts a JSON number (hand-written fixtures) or a D-040 hex string (saves).
func _to_float(v: Variant) -> float:
	var x: float = float_of(v)
	if is_nan(x) or is_inf(x):
		ok = false
		return 0.0
	return x


func _to_int(v: Variant) -> int:
	var t: int = typeof(v)
	if t == TYPE_INT:
		var n: int = v
		return n
	if t == TYPE_FLOAT:
		var x: float = v
		if is_nan(x) or is_inf(x) or absf(x) > _MAX_SAFE_INT or x != floorf(x):
			ok = false
			return 0
		return int(x)
	ok = false
	return 0
