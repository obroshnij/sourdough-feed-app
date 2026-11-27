class_name DeviceHapticsBackend
extends HapticsBackend
## The real pulse (D-059): Godot's built-in Input.vibrate_handheld(), only on a phone (the "mobile" feature).
## A no-op on desktop. This is the only place in the game that calls vibrate_handheld. Whether short, soft
## pulses feel right is judged on the user's iPhone; an iOS haptics plugin comes only if they don't.


func vibrate(moment: StringName, duration_ms: int, amplitude: float) -> void:
	super.vibrate(moment, duration_ms, amplitude)
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms, amplitude)
