class_name SettingsStore
extends RefCounted
## Player preferences in user://settings.cfg (ConfigFile), kept apart from the save so a bad save never
## resets them, and the reverse (data-models.md §9.1, SAVE-18). The settings sheet (ux-design §14) changes
## these fields on Session.get_settings(), then calls Session.save_settings(), which writes the file and
## emits Bus.settings_changed.

const SECTION: String = "prefs"
## 1.0, 1.25 or 1.5. Scales Theme font sizes only, never content_scale_factor (architecture §9.1).
const TEXT_SCALES: Array[float] = [1.0, 1.25, 1.5]

var path: String = "user://settings.cfg"
var text_scale: float = 1.0
## Tier A glass and reduced VFX (architecture §8.1).
var reduce_effects: bool = false
var reduce_motion: bool = false
## "Show time-lapse on return" (game-mechanics §8). Off skips the time-lapse; the summary card still shows.
var show_time_lapse: bool = true
## "Haptics" (ux-design §15): on by default. Every haptic moment also has a sound, so off loses nothing.
var haptics: bool = true
## "Keep messages on screen" (ux-design §12, §16): toasts and cards stay until dismissed instead of
## auto-hiding. Off by default.
var keep_messages: bool = false


func _init(file_path: String = "user://settings.cfg") -> void:
	path = file_path


## Missing or unreadable file: defaults. A missing key keeps its default. Never touches the save.
func load_settings() -> void:
	if not FileAccess.file_exists(path):
		return
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	var ts: Variant = cfg.get_value(SECTION, "text_scale", 1.0)
	if typeof(ts) == TYPE_FLOAT and TEXT_SCALES.has(ts):
		text_scale = ts
	reduce_effects = _bool(cfg, "reduce_effects", false)
	reduce_motion = _bool(cfg, "reduce_motion", false)
	show_time_lapse = _bool(cfg, "show_time_lapse", true)
	haptics = _bool(cfg, "haptics", true)
	keep_messages = _bool(cfg, "keep_messages", false)


func save_settings() -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "text_scale", text_scale)
	cfg.set_value(SECTION, "reduce_effects", reduce_effects)
	cfg.set_value(SECTION, "reduce_motion", reduce_motion)
	cfg.set_value(SECTION, "show_time_lapse", show_time_lapse)
	cfg.set_value(SECTION, "haptics", haptics)
	cfg.set_value(SECTION, "keep_messages", keep_messages)
	return cfg.save(path)


func _bool(cfg: ConfigFile, key: String, fallback: bool) -> bool:
	var v: Variant = cfg.get_value(SECTION, key, fallback)
	if typeof(v) == TYPE_BOOL:
		var b: bool = v
		return b
	return fallback
