extends RefCounted
## Three LINT-01 violations, on lines 6, 10 and 14.


static func now() -> int:
	return int(Time.get_unix_time_from_system())


static func noise() -> int:
	return randi()


static func flour() -> Resource:
	return load("res://data/flours/rye.tres")
