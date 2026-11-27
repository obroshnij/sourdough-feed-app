extends TestCase
## Audio rules (audio-direction.md §3, §5, §6): which file plays for which beat, buses, the room
## crossfade, the master volume, and that every mapped file exists.


func test_every_mapped_file_exists_and_imports() -> void:
	var files: Array[String] = []
	files.append_array(JarAudio.FEEDBACK.values())
	files.append_array(JarAudio.FEED.values())
	files.append_array(["glass_tink", "starter_poke", "lid_lift", "lid_set", "sheet_open", "sheet_close",
			"smell_swell", "event_chime", "event_chime_soft", "mold_found", "starter_new"])
	for i: int in 6:
		files.append("bubble_pop_%d" % (i + 1))
	for f: String in files:
		check(ResourceLoader.exists(JarAudio.DIR + f + ".wav"), "%s.wav imports" % f)
	for f: String in ["room_day.ogg", "room_night.ogg"]:
		var s: AudioStreamOggVorbis = load(JarAudio.DIR + f) as AudioStreamOggVorbis
		check(s != null and s.loop, "%s loops" % f)


func test_beats_map_to_their_sounds() -> void:
	check_eq(JarAudio.FEED[&"settle"], "band_snap", "settle snaps the band")
	check_eq(JarAudio.FEED[&"scoop"], "feed_scoop", "scoop")
	check_eq(JarAudio.FEEDBACK[&"tick"], "ui_tick", "tick")
	check_eq(JarAudio.FEEDBACK[&"preview"], "glass_tink", "volume preview")
	check(not JarAudio.FEEDBACK.has(&"poke"), "a poke's pulse has no sound")
	check_eq(JarAudio.event_file(&"mold_found", &"attention"), "mold_found", "mold has its own swell")
	check_eq(JarAudio.event_file(&"first_rise", &"info"), "event_chime_soft", "info chime")
	check_eq(JarAudio.event_file(&"hungry_again", &"nudge"), "event_chime", "nudge chime")
	check_eq(JarAudio.bus_for("ui_tap"), &"Ui", "clicks on Ui")
	check_eq(JarAudio.bus_for("sheet_open"), &"Ui", "sheet air on Ui")
	check_eq(JarAudio.bus_for("feed_pour"), &"Sfx", "feed on Sfx")
	check_eq(JarAudio.bus_for("room_day"), &"Room", "room tone on Room")


func test_room_crossfade_is_equal_power_and_volume_maps_to_db() -> void:
	for n: float in [0.0, 0.25, 0.5, 1.0]:
		var g: Vector2 = JarAudio.room_gains(n)
		check_close(g.x * g.x + g.y * g.y, 1.0, 0.0, 1e-6, "equal power at n=%s" % n)
	check_close(JarAudio.room_gains(0.0).y, 0.0, 0.0, 1e-6, "day: night loop silent")
	check_close(JarAudio.room_gains(1.0).x, 0.0, 0.0, 1e-6, "night: day loop silent")
	check_close(JarAudio.master_db(1.0), 0.0, 0.0, 1e-6, "full volume is 0 dB")
	check(JarAudio.master_db(0.0) <= -79.0, "0 mutes")
	check_close(JarAudio.master_db(0.5), linear_to_db(0.5), 0.0, 1e-6, "linear to dB")
