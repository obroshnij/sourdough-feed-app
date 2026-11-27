class_name JarAudio
extends Node
## Sound playback (audio-direction.md §3, §5, §6). Buses Room, Sfx and Ui under Master, all at 0 dB:
## the mix is baked into the files. Pools: Room 2 (day and night loops, crossfaded by the night
## factor), Sfx 6, Ui 2; a full pool stops its oldest voice. Plain AudioStreamPlayers, no 3D.
## Sound off mutes Master, master_volume sets its level. Haptics are Session's, never here.

const DIR: String = "res://assets/audio/"
const SFX_POOL: int = 6
const UI_POOL: int = 2
const MAX_POPS: int = 2
const DUCK_DB: float = -3.0
const PITCH_CYCLE: Array[float] = [1.0, 1.03, 0.97]

## Bus.feedback moment to file (audio-direction.md §3). &"poke" has no sound.
const FEEDBACK: Dictionary[StringName, String] = {
	&"tap": "ui_tap", &"mix": "ui_tap", &"tick": "ui_tick", &"toggle_on": "ui_toggle_on",
	&"toggle_off": "ui_toggle_off", &"preview": "glass_tink", &"name": "event_chime_soft",
	&"status": "status_tick", &"discard": "mold_discard",
}
## Bus.feed_moment step to file. settle is the band snap.
const FEED: Dictionary[StringName, String] = {
	&"hooch": "feed_hooch", &"discard": "feed_discard", &"scoop": "feed_scoop", &"pour": "feed_pour",
	&"stir": "feed_stir", &"settle": "band_snap",
}
const UI_FILES: Array[String] = ["ui_tap", "ui_tick", "ui_toggle_on", "ui_toggle_off", "sheet_open", "sheet_close"]

var reduce_motion: bool = false
var night: float = 0.0
## Pops are off while a sheet is open, during a feed, the smell moment and the time-lapse (§5).
var pops_muted: bool = false
var _streams: Dictionary[String, AudioStream] = {}
var _sfx: Array[AudioStreamPlayer] = []
var _ui: Array[AudioStreamPlayer] = []
var _room_day: AudioStreamPlayer
var _room_night: AudioStreamPlayer
var _room_level: float = 0.0
var _room_target: float = 0.0
var _room_rate: float = 0.5
var _duck: float = 0.0
var _duck_target: float = 0.0
var _pitch_i: Dictionary[String, int] = {}
var _sheets_open: int = 0


## File name to the bus it plays on.
static func bus_for(file: String) -> StringName:
	if file.begins_with("room_"):
		return &"Room"
	return &"Ui" if file in UI_FILES else &"Sfx"


## Equal-power day and night gains for a night factor (§5).
static func room_gains(n: float) -> Vector2:
	var k: float = clampf(n, 0.0, 1.0)
	return Vector2(cos(k * PI * 0.5), sin(k * PI * 0.5))


## Master volume in dB for a 0..1 setting. 0 mutes.
static func master_db(v: float) -> float:
	return -80.0 if v <= 0.0001 else linear_to_db(clampf(v, 0.0, 1.0))


## Event tier to chime. mold_found has its own dark swell.
static func event_file(event_id: StringName, tier: StringName) -> String:
	if event_id == &"mold_found":
		return "mold_found"
	return "event_chime_soft" if tier == &"info" else "event_chime"


func _ready() -> void:
	for b: StringName in [&"Room", &"Sfx", &"Ui"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, &"Master")
	for i: int in SFX_POOL:
		_sfx.append(_player(&"Sfx"))
	for i: int in UI_POOL:
		_ui.append(_player(&"Ui"))
	_room_day = _player(&"Room")
	_room_night = _player(&"Room")
	_room_day.stream = _load("room_day.ogg")
	_room_night.stream = _load("room_night.ogg")


func _player(bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _load(file: String) -> AudioStream:
	if not _streams.has(file):
		_streams[file] = load(DIR + file) as AudioStream
	return _streams[file]


## Plays a one-shot by file name (no extension) on its bus. Returns the player.
func play(file: String) -> AudioStreamPlayer:
	if file.is_empty():
		return null
	var pool: Array[AudioStreamPlayer] = _ui if bus_for(file) == &"Ui" else _sfx
	var p: AudioStreamPlayer = null
	for q: AudioStreamPlayer in pool:
		if not q.playing:
			p = q
			break
	if p == null:
		p = pool.pop_front()
		p.stop()
		pool.append(p)
	p.stream = _load(file + ".wav")
	p.volume_db = 0.0
	p.pitch_scale = 1.0
	if file == "glass_tink" or file == "ui_tap":
		var i: int = _pitch_i.get(file, 0)
		p.pitch_scale = PITCH_CYCLE[i % PITCH_CYCLE.size()]
		_pitch_i[file] = i + 1
	p.play()
	return p


func play_pop(serial: int) -> void:
	if pops_muted:
		return
	var live: int = 0
	for q: AudioStreamPlayer in _sfx:
		if q.playing and q.stream != null and q.stream.resource_path.contains("bubble_pop"):
			live += 1
	if live < MAX_POPS:
		play("bubble_pop_%d" % (posmod(serial, 6) + 1))


## Fades out every playing Sfx voice of a file over `seconds`.
func fade_out(file: String, seconds: float) -> void:
	for q: AudioStreamPlayer in _sfx:
		if q.playing and q.stream != null and q.stream.resource_path.ends_with(file + ".wav"):
			var t: Tween = create_tween()
			t.tween_property(q, "volume_db", -60.0, seconds)
			t.tween_callback(q.stop)


func on_feedback(moment: StringName) -> void:
	play(FEEDBACK.get(moment, ""))


func on_feed(step: StringName) -> void:
	if reduce_motion and step != &"settle":
		return
	if step == &"settle":
		fade_out("feed_stir", 0.12)
	play(FEED.get(step, ""))


func on_event(event_id: StringName, tier: StringName) -> void:
	play(event_file(event_id, tier))
	if event_id == &"mold_found":
		_duck_target = DUCK_DB


func on_sheet(opened: bool) -> void:
	_sheets_open = maxi(_sheets_open + (1 if opened else -1), 0)
	play("sheet_open" if opened else "sheet_close")
	if not opened and _sheets_open == 0:
		_duck_target = 0.0


func on_smell(started: bool) -> void:
	_duck_target = DUCK_DB if started else 0.0
	if started:
		play("smell_swell")
	else:
		fade_out("smell_swell", 0.15)


## Room tone: fade in over `seconds` (2 s at session_ready, 1.5 s on resume), or out.
func room_fade(on: bool, seconds: float) -> void:
	_room_target = 1.0 if on else 0.0
	_room_rate = 1.0 / maxf(seconds, 0.01)
	if on and not _room_day.playing:
		_room_day.play()
		_room_night.play()


func apply_settings(sound: bool, volume: float) -> void:
	var m: int = AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_mute(m, not sound or volume <= 0.0001)
	AudioServer.set_bus_volume_db(m, master_db(volume))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		for q: AudioStreamPlayer in _sfx + _ui:
			q.stop()
		room_fade(false, 0.15)


func _process(delta: float) -> void:
	_room_level = move_toward(_room_level, _room_target, _room_rate * delta)
	_duck = move_toward(_duck, _duck_target, absf(DUCK_DB) / 0.3 * delta)
	if _room_day == null:
		return
	var g: Vector2 = room_gains(night)
	_room_day.volume_db = linear_to_db(maxf(g.x * _room_level, 0.0001)) + _duck
	_room_night.volume_db = linear_to_db(maxf(g.y * _room_level, 0.0001)) + _duck
	if _room_level <= 0.0 and _room_target <= 0.0 and _room_day.playing:
		_room_day.stop()
		_room_night.stop()
