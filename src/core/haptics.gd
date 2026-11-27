class_name Haptics
extends RefCounted
## The haptics hook (D-059). Every haptic goes through play(moment): it looks up the moment's pulse and sends
## it to the backend, only when SettingsStore.haptics is on. Session owns one and plays it for every
## Bus.feedback(moment), so T3 emits Bus.feedback and never vibrates itself. Sound is separate: T2 plays the
## moment's sound from the same signal whatever this setting says (ux-design §15: haptics off loses nothing).
##
## Pulses are short and soft, first values to judge on the iPhone (D-059). A moment not in PATTERNS is valid
## on the Bus (it may have a sound) but never vibrates.

## moment id -> Vector2(duration in ms, amplitude 0..1).
const PATTERNS: Dictionary[StringName, Vector2] = {
	&"tap": Vector2(10.0, 0.25),
	&"tick": Vector2(6.0, 0.15),
	&"toggle_on": Vector2(12.0, 0.3),
	&"toggle_off": Vector2(8.0, 0.2),
	&"mix": Vector2(18.0, 0.35),
	&"discard": Vector2(35.0, 0.5),
	&"name": Vector2(20.0, 0.4),
	&"status": Vector2(8.0, 0.2),
	&"poke": Vector2(8.0, 0.2),
}
## Bus.feedback ids with a sound but deliberately no pulse (sound-designer): the volume slider's release.
const SOUND_ONLY: Array[StringName] = [&"preview"]

var backend: HapticsBackend = null
var settings: SettingsStore = null


func _init(haptics_backend: HapticsBackend = null, settings_store: SettingsStore = null) -> void:
	backend = haptics_backend if haptics_backend != null else HapticsBackend.new()
	settings = settings_store


## Plays `moment`'s pulse. Returns true when a pulse went to the backend: false when haptics are off, or
## the moment has no pattern.
func play(moment: StringName) -> bool:
	if settings != null and not settings.haptics:
		return false
	if not PATTERNS.has(moment):
		return false
	var p: Vector2 = PATTERNS[moment]
	backend.vibrate(moment, roundi(p.x), p.y)
	return true
