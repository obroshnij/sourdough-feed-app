class_name QaSaveFormat
extends RefCounted
## QA's own reading of the save file layout (data-models §9.2), written from the doc and not
## from T1's SaveCodec, plus the corrupt-file corpus for SAVE-03, SAVE-04, SAVE-05 and SAVE-10.
##   line 1: {"bytes":N,"format":"sourdough.save","sha256":"<64 hex>","version":V}
##   then the payload bytes: JSON.stringify(payload, "", true, true)

const FORMAT := "sourdough.save"


static func payload_text(payload: Dictionary) -> String:
	return JSON.stringify(payload, "", true, true)


## A save file around `text`, with a header that matches it unless overridden in `header_patch`.
static func encode_text(text: String, version: int = 1, header_patch: Dictionary = {}) -> PackedByteArray:
	var body: PackedByteArray = text.to_utf8_buffer()
	var header: Dictionary = {"bytes": body.size(), "format": FORMAT, "sha256": text.sha256_text(),
			"version": version}
	header.merge(header_patch, true)
	var out: PackedByteArray = JSON.stringify(header, "", true, true).to_utf8_buffer()
	out.append(10)
	out.append_array(body)
	return out


static func encode(payload: Dictionary, version: int = 1) -> PackedByteArray:
	return encode_text(payload_text(payload), version)


## A small synthetic payload. `tag` makes two payloads distinguishable.
static func sample_payload(tag: String) -> Dictionary:
	return {
		"meta": {"note": tag, "third": 1.0 / 3.0, "big": "9223372036854775807"},
		"starter": {"name": "Dough “Nut” " + tag, "rise": 1.9300000000000002, "moldy": false},
	}


## name -> bytes. Every entry must fail to load (SAVE-03 to SAVE-05, SAVE-10).
static func corrupt_corpus(good_payload: Dictionary) -> Dictionary:
	var good: PackedByteArray = encode(good_payload)
	var text: String = payload_text(good_payload)
	var newline: int = good.find(10)
	var garbage: PackedByteArray = PackedByteArray()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261126
	for i: int in 512:
		garbage.append(rng.randi() % 256)
	garbage[0] = 0xFF  # never valid UTF-8
	return {
		"wrong_sha256": encode_text(text, 1, {"sha256": "0".repeat(64)}),
		"wrong_byte_count": encode_text(text, 1, {"bytes": text.to_utf8_buffer().size() + 1}),
		"one_flipped_payload_byte": _flip(good, good.size() - 3),
		"truncated_to_0": PackedByteArray(),
		"truncated_to_1": good.slice(0, 1),
		"truncated_to_half": good.slice(0, int(good.size() / 2.0)),
		"truncated_to_len_minus_1": good.slice(0, good.size() - 1),
		"header_line_only": good.slice(0, newline + 1),
		"header_without_newline": good.slice(0, newline),
		"binary_garbage": garbage,
		"garbage_after_valid_header": encode_text(text).slice(0, newline + 1) + garbage,
		"payload_is_json_array": encode_text("[1,2,3]"),
		"payload_is_nan_text": encode_text("{\"rise\":NaN}"),
		"payload_is_empty_object": encode_text("{}"),
		"wrong_format": encode_text(text, 1, {"format": "other.save"}),
		"version_0": encode_text(text, 0),
		"version_too_new": encode_text(text, 2),
		"header_not_json": "not a header\n".to_utf8_buffer() + text.to_utf8_buffer(),
	}


static func _flip(bytes: PackedByteArray, index: int) -> PackedByteArray:
	var out: PackedByteArray = bytes.duplicate()
	out[index] = out[index] ^ 0x01
	return out
