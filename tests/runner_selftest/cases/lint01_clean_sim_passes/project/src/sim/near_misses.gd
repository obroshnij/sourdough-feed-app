extends RefCounted
## Pure, so LINT-01 must pass. Never touches Time. or OS. or load( in code: those words
## sit only in comments. # A hash inside this doc comment is fine too.

const NOTE: String = "a # in a string is not a comment start"


## The RNG is passed in, so its methods are allowed: rng.randi(), rng.randf().
static func draw(rng: RandomNumberGenerator) -> float:
	var whole: int = rng.randi() % 10
	return rng.randf() + float(whole)


static func text(x: int) -> String:
	return str(x)  # str( contains "tr(" but is not tr()


static func _load(value: float) -> float:
	return value  # a method named _load is not load()


static func shift(date_time_s: int) -> int:
	var DateTimeOffset: int = 3600
	return date_time_s + DateTimeOffset
