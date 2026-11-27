class_name HapticsBackend
extends RefCounted
## Where a haptic pulse goes. This base is the stand-in: it vibrates nothing and records every pulse, so
## tests (and the desktop) can see what would have played. DeviceHapticsBackend is the real one.

## Each {"moment": StringName, "duration_ms": int, "amplitude": float}, oldest first.
var pulses: Array[Dictionary] = []


func vibrate(moment: StringName, duration_ms: int, amplitude: float) -> void:
	pulses.append({"moment": moment, "duration_ms": duration_ms, "amplitude": amplitude})
