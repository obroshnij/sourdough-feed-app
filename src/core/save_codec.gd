class_name SaveCodec
extends RefCounted
## Save file layout (data-models.md §9.2 and §9.4). Line 1 is a JSON header; everything after the first
## newline is the payload, byte for byte. The checksum covers the stored bytes, never a re-serialization.
## Decoding is silent on bad input: no engine error is ever logged for a corrupt file.

const FORMAT: String = "sourdough.save"
const CURRENT_VERSION: int = 1
const NEWLINE: int = 10
const OPEN_BRACE: int = 123
## Godot 4.7.2's JSON parser is not correctly rounded for 17-digit numbers: about 1 in 4 sim floats came
## back 1 ulp off after stringify(full_precision) and parse (measured in tests/unit/core). A float whose
## text doesn't parse back exactly is written as {"$f64": "<16 hex digits of its bits>"}, so a save and
## load is lossless (PROP-01, PROP-02). Values that round-trip stay plain numbers.
const F64_KEY: String = "$f64"

static var _json: JSON = JSON.new()


## Sorted keys, full precision, one line, floats packed losslessly.
static func payload_text(payload: Dictionary) -> String:
	return JSON.stringify(pack_floats(payload), "", true, true)


static func pack_floats(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			var x: float = v
			if _round_trips(x):
				return x
			var b := PackedByteArray()
			b.resize(8)
			b.encode_double(0, x)
			return {F64_KEY: b.hex_encode()}
		TYPE_DICTIONARY:
			var src: Dictionary = v
			var out: Dictionary = {}
			for k: Variant in src:
				out[k] = pack_floats(src[k])
			return out
		TYPE_ARRAY:
			var arr: Array = v
			var list: Array = []
			for item: Variant in arr:
				list.append(pack_floats(item))
			return list
	return v


static func unpack_floats(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			var src: Dictionary = v
			if src.size() == 1 and src.has(F64_KEY) and typeof(src[F64_KEY]) == TYPE_STRING:
				var hex: String = src[F64_KEY]
				if hex.length() == 16 and hex.is_valid_hex_number():
					return hex.hex_decode().decode_double(0)
			var out: Dictionary = {}
			for k: Variant in src:
				out[k] = unpack_floats(src[k])
			return out
		TYPE_ARRAY:
			var arr: Array = v
			var list: Array = []
			for item: Variant in arr:
				list.append(unpack_floats(item))
			return list
	return v


static func _round_trips(x: float) -> bool:
	if is_nan(x) or is_inf(x):
		return false
	if _json.parse(JSON.stringify(x, "", false, true)) != OK:
		return false
	var back: Variant = _json.data
	return typeof(back) == TYPE_FLOAT and back == x


static func encode(payload: Dictionary) -> PackedByteArray:
	var text: String = payload_text(payload)
	var body: PackedByteArray = text.to_utf8_buffer()
	var header: Dictionary = {
		"bytes": body.size(), "format": FORMAT, "sha256": text.sha256_text(), "version": CURRENT_VERSION,
	}
	var out: PackedByteArray = JSON.stringify(header, "", true, true).to_utf8_buffer()
	out.append(NEWLINE)
	out.append_array(body)
	return out


## `allow_bare`: accept a file with no header line as a bare payload (dev fixtures, data-models §9.5).
static func decode(bytes: PackedByteArray, allow_bare: bool = false) -> SaveDecoded:
	var out := SaveDecoded.new()
	var nl: int = bytes.find(NEWLINE)
	var header: Dictionary = {}
	# Only text that starts with "{" is decoded, so binary garbage never reaches the UTF-8 decoder (which
	# prints "Unicode parsing error" to stderr, though it logs no error).
	if nl > 0 and bytes[0] == OPEN_BRACE:
		header = _parse_object(bytes.slice(0, nl).get_string_from_utf8())
	if header.is_empty() or not header.has("format"):
		if allow_bare:
			return _decode_bare(bytes)
		out.reason = &"no_header" if nl <= 0 else &"bad_header"
		return out
	var r := DictReader.new(header)
	var fmt: String = r.text("format")
	var version: int = r.integer("version")
	var length: int = r.integer("bytes")
	var sha: String = r.text("sha256")
	if not r.ok:
		out.reason = &"bad_header"
		return out
	if fmt != FORMAT:
		out.reason = &"format"
		return out
	out.version = version
	if version > CURRENT_VERSION or version < 1:
		out.reason = &"too_new" if version > CURRENT_VERSION else &"bad_header"
		return out
	var body: PackedByteArray = bytes.slice(nl + 1)
	if body.size() != length or body.is_empty() or body[0] != OPEN_BRACE:
		out.reason = &"length"
		return out
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(body)
	if ctx.finish().hex_encode() != sha:
		out.reason = &"checksum"
		return out
	var payload: Dictionary = _parse_object(body.get_string_from_utf8())
	if payload.is_empty():
		out.reason = &"json"
		return out
	var migrated: Dictionary = SaveMigrations.migrate(payload, version)
	if migrated.is_empty():
		out.reason = &"migration"
		return out
	out.payload = migrated
	out.ok = true
	return out


static func _decode_bare(bytes: PackedByteArray) -> SaveDecoded:
	var out := SaveDecoded.new()
	out.bare = true
	var start: int = 0
	while start < bytes.size() and bytes[start] in [9, 10, 13, 32]:
		start += 1
	if start >= bytes.size() or bytes[start] != OPEN_BRACE:
		out.reason = &"json"
		return out
	var payload: Dictionary = _parse_object(bytes.get_string_from_utf8())
	if payload.is_empty():
		out.reason = &"json"
		return out
	var migrated: Dictionary = SaveMigrations.migrate(payload, CURRENT_VERSION)
	if migrated.is_empty():
		out.reason = &"migration"
		return out
	out.payload = migrated
	out.version = CURRENT_VERSION
	out.ok = true
	return out


## {} unless `text` is a JSON object. Uses JSON.new().parse(), which never logs (JSON.parse_string does).
static func _parse_object(text: String) -> Dictionary:
	if text.is_empty():
		return {}
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = unpack_floats(data)
	return d
