extends TestCase
## Time-lapse playback from CatchUpResult.keyframes (art-direction.md §8, ux-design.md §12).


func _frame(at: int, rise: float) -> TimeLapseKeyframe:
	var k := TimeLapseKeyframe.new()
	k.at_unix = at
	k.visuals = VisualParams.new()
	k.visuals.rise = rise
	return k


func _frames() -> Array[TimeLapseKeyframe]:
	return [_frame(1000, 1.0), _frame(4600, 2.3), _frame(8200, 1.9)]


func test_plays_from_first_to_last_keyframe() -> void:
	var p := TimeLapsePlayer.new(_frames(), 3.0, false)
	check_close(p.sample().rise, 1.0, 0.0, 1e-6, "starts at the first keyframe")
	check_close(p.unix_now(), 1000.0, 0.0, 1e-6, "at the first keyframe's time")
	var prev_u: float = p.unix_now()
	for i: int in 180:
		p.advance(1.0 / 60.0)
		check(p.unix_now() >= prev_u - 1e-6, "time never runs backward")
		prev_u = p.unix_now()
	check(p.done(), "done after its duration")
	check_close(p.sample().rise, 1.9, 0.0, 1e-6, "ends at the last keyframe")


func test_passes_through_the_peak_keyframe() -> void:
	var p := TimeLapsePlayer.new(_frames(), 3.0, false)
	var best: float = 0.0
	for i: int in 180:
		p.advance(1.0 / 60.0)
		best = maxf(best, p.sample().rise)
	check_close(best, 2.3, 0.0, 0.05, "shows the peak in between")


func test_reduce_motion_shows_two_stills() -> void:
	var p := TimeLapsePlayer.new(_frames(), 4.0, true)
	p.advance(1.0)
	check_close(p.sample().rise, 1.0, 0.0, 1e-6, "first still")
	p.advance(2.0)
	check_close(p.sample().rise, 1.9, 0.0, 1e-6, "last still, no in-between frames")


func test_plays_only_when_the_sim_asks() -> void:
	var r := CatchUpResult.new()
	r.keyframes = _frames()
	r.play_time_lapse = false
	check(not TimeLapsePlayer.can_play(r), "play_time_lapse false")
	r.play_time_lapse = true
	check(TimeLapsePlayer.can_play(r), "play_time_lapse true with frames")
	check(not TimeLapsePlayer.can_play(null), "no result")
