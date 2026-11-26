class_name UiIcon
extends RefCounted
## Art's icons (art-direction.md §11, D-034): white on transparent, tinted with modulate or the Button icon
## colors. Status, action and inspection icons come in outline and filled variants; the utility icons have
## one. Imported at svg/scale 4 with mipmaps (96 px for a 24 pt icon), so they stay sharp at 3x.

const DIR: String = "res://assets/icons/"
const UTILITY: Array[StringName] = [&"ui_settings", &"ui_close", &"ui_back", &"ui_check", &"ui_chevron_right"]

static var _cache: Dictionary[String, Texture2D] = {}


## `id` is a full icon id: &"status_at_peak", &"action_feed", &"inspect_surface" or &"ui_settings".
static func path(id: StringName, filled: bool = false) -> String:
	if UTILITY.has(id):
		return DIR + String(id) + ".svg"
	return DIR + "%s_%s.svg" % [id, "filled" if filled else "outline"]


static func texture(id: StringName, filled: bool = false) -> Texture2D:
	var p: String = path(id, filled)
	if _cache.has(p):
		return _cache[p]
	var tex: Texture2D = null
	if ResourceLoader.exists(p):
		tex = load(p) as Texture2D
	if tex == null:
		push_error("UiIcon: missing icon " + p)
	_cache[p] = tex
	return tex


static func status(state_id: StringName, filled: bool = false) -> Texture2D:
	return texture(StringName("status_%s" % state_id), filled)


static func action(action_id: StringName, filled: bool = false) -> Texture2D:
	return texture(StringName("action_%s" % action_id), filled)
