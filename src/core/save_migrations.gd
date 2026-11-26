class_name SaveMigrations
extends RefCounted
## Pure, ordered payload migrations (data-models.md §9.5). Each released version keeps a fixture forever in
## tests/fixtures/saves/v<N>_*.json. v1 is the first version, so there is nothing to migrate yet.


## Returns the payload at SaveCodec.CURRENT_VERSION, or {} when the version is unknown.
static func migrate(payload: Dictionary, from_version: int) -> Dictionary:
	if from_version < 1 or from_version > SaveCodec.CURRENT_VERSION:
		return {}
	var p: Dictionary = payload
	# Future steps go here in order, for example: if from_version < 2: p = _v1_to_v2(p)
	return p
