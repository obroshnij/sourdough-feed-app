class_name TimeLapsePlayer
extends RefCounted
## Plays CatchUpResult.keyframes back as a short time-lapse (art-direction.md §8, ux-design.md §12).
## Pure: the caller passes dt. Time runs from the first keyframe's at_unix to the last one's with an
## ease-in-out cubic over `duration` seconds, and the shown VisualParams lerp between the two
## keyframes around the current time. With reduce motion it shows two stills, first then last.

var frames: Array[TimeLapseKeyframe] = []
var duration: float = 3.0
var stills: bool = false
var t: float = 0.0


func _init(keyframes: Array[TimeLapseKeyframe], duration_s: float, reduce_motion: bool) -> void:
	frames = keyframes
	duration = maxf(duration_s, 0.1)
	stills = reduce_motion


static func can_play(result: CatchUpResult) -> bool:
	return result != null and result.play_time_lapse and result.keyframes.size() >= 2


func advance(dt: float) -> void:
	t = minf(t + dt, duration)


func done() -> bool:
	return t >= duration - 1e-4


## 0..1, eased (ease-in-out cubic).
func progress() -> float:
	var x: float = clampf(t / duration, 0.0, 1.0)
	return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) * 0.5


## The sim time being shown (drives the night factor through NightFade.at_unix).
func unix_now() -> float:
	if stills:
		return float(frames[0].at_unix if t < duration * 0.5 else frames[-1].at_unix)
	return lerpf(float(frames[0].at_unix), float(frames[-1].at_unix), progress())


func sample() -> VisualParams:
	if stills:
		return (frames[0] if t < duration * 0.5 else frames[-1]).visuals
	var u: float = unix_now()
	for i: int in range(1, frames.size()):
		var a: TimeLapseKeyframe = frames[i - 1]
		var b: TimeLapseKeyframe = frames[i]
		if u <= float(b.at_unix) or i == frames.size() - 1:
			var span: float = maxf(float(b.at_unix - a.at_unix), 1.0)
			return lerp_params(a.visuals, b.visuals, clampf((u - float(a.at_unix)) / span, 0.0, 1.0))
	return frames[-1].visuals


## Field-by-field blend of two VisualParams. The cover comes from the nearer one.
static func lerp_params(a: VisualParams, b: VisualParams, k: float) -> VisualParams:
	var out := VisualParams.new()
	for f: StringName in VisualEaser.eased_fields():
		out.set(f, lerpf(float(a.get(f)), float(b.get(f)), k))
	out.tint = a.tint.lerp(b.tint, k)
	out.cover = a.cover if k < 0.5 else b.cover
	out.time_override = b.time_override
	return out
