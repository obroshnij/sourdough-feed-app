class_name Notifier
extends RefCounted
## The one opt-in "warning signs" notification (D-025, D-057), behind a backend so the third-party iOS plugin
## stays swappable (D-007). The scheduling logic is pure (plan()) and tested with the stand-in backend.
##
## Rules:
## - Opt-in: nothing is ever scheduled unless SettingsStore.notifications is on.
## - One notification, at most one pending (one id, replaced on every update).
## - When: the sim's forecast of when warning signs would appear if nothing changes
##   (Forecast.warning_signs_after_s: mold_risk reaches 0.5, the state turns unhealthy), stepping the starter
##   in its current place. None when that never happens within 14 days (the fridge), when the signs are
##   already there (the in-app warning_signs sheet covers it), or for a moldy starter or an empty jar.
## - Quiet hours (22:00 to 08:00 local, the event scheduler's): a time inside them moves to 08:00. Later, never
##   earlier: the warning-to-mold gap is at least 60 h (spec §10), so a few hours' wait is safe.
## - Session updates it when the app goes to the background, and cancels it at launch, on resume and on
##   opt-out. A feed, a move, a discard or a new start while one is pending re-plans it at once.

const WARNING_ID: String = "warning_signs"
const QUIET_START_MIN: int = 22 * 60
const QUIET_END_MIN: int = 8 * 60

var backend: NotifierBackend = null
## The fire time of the pending notification, 0 when none is pending.
var scheduled_unix: int = 0


func _init(notifier_backend: NotifierBackend = null) -> void:
	backend = notifier_backend if notifier_backend != null else NotifierBackend.new()


## Pure: when the warning-signs notification should fire (Unix seconds), or 0 for none. `now_unix` is the
## wall clock; the forecast starts from the state's own sim time, which Session keeps at grid(now).
static func plan(state: StarterState, env: EnvironmentState, now_unix: int, utc_offset_s: int) -> int:
	if state == null or env == null or state.empty or state.moldy:
		return 0
	var after_s: int = Forecast.warning_signs_after_s(state, env)
	if after_s <= 0:
		return 0
	var fire: int = state.sim_time_unix + after_s
	if fire <= now_unix:
		return 0
	return after_quiet_hours(fire, utc_offset_s)


## Moves a time inside quiet hours (22:00 to 08:00 local) to the 08:00 that ends them.
static func after_quiet_hours(unix: int, utc_offset_s: int) -> int:
	var minute: int = LocalDay.minute_of_day(unix, utc_offset_s)
	var into_day_s: int = posmod(unix + utc_offset_s, 86400)
	var day_start: int = unix - into_day_s
	if minute >= QUIET_START_MIN:
		return day_start + 86400 + QUIET_END_MIN * 60
	if minute < QUIET_END_MIN:
		return day_start + QUIET_END_MIN * 60
	return unix


## Replaces the pending notification with a fresh plan (or none). `enabled` is the opt-in setting; `name`
## fills {name} in the body. Returns the new fire time, 0 for none.
func update(state: StarterState, env: EnvironmentState, now_unix: int, utc_offset_s: int, enabled: bool,
		starter_name: String) -> int:
	var fire: int = plan(state, env, now_unix, utc_offset_s) if enabled else 0
	if fire == 0:
		cancel()
		return 0
	if fire == scheduled_unix and backend.pending.has(WARNING_ID):
		return fire
	var args: Dictionary = {"name": starter_name}
	backend.schedule(WARNING_ID, fire, Keys.format(&"NOTIF_WARNING_TITLE", args),
		Keys.format(&"NOTIF_WARNING_BODY", args))
	scheduled_unix = fire
	return fire


## Cancels the pending notification, if any.
func cancel() -> void:
	if scheduled_unix != 0 or backend.pending.has(WARNING_ID):
		backend.cancel(WARNING_ID)
	scheduled_unix = 0


func is_pending() -> bool:
	return scheduled_unix != 0
