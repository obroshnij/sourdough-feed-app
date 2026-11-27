extends Node
## Autoload `Bus`: the ui and view contract (architecture.md §3.3). Signals only, no state.
## ui and view never reference each other; they talk only through these signals.
## Owner: T1. Additions by request, so T2 and T3 both see them.

## ui to view. Camera stops inertia, VFX dim.
@warning_ignore("unused_signal")
signal sheet_opened(sheet_id: StringName)
@warning_ignore("unused_signal")
signal sheet_closed(sheet_id: StringName)

## ui to view. target is one of &"bubbles", &"surface", &"height", &"top", &"home", &"mold".
## &"mold" is the close-up of the colony (D-023, ux-design §12): T3 emits it when the mold_found sheet opens
## (SimEvent.id == &"mold_found"), and camera_focus_released() when the sheet closes.
@warning_ignore("unused_signal")
signal camera_focus_requested(target: StringName)
@warning_ignore("unused_signal")
signal camera_focus_released()

## ui to view. Camera nudge and wisps.
@warning_ignore("unused_signal")
signal smell_moment_started()
@warning_ignore("unused_signal")
signal smell_moment_finished()

## ui to view. step is one of &"discard", &"scoop", &"pour", &"stir".
@warning_ignore("unused_signal")
signal feed_moment(step: StringName)

## ui to view. The free space between the HUD plate and the action bar, in UI units (pt), emitted on every
## layout change (text size, safe areas, rotation). The camera frames the jar to it (ux-design §2, §19.5).
@warning_ignore("unused_signal")
signal jar_region_changed(region: Rect2)

## core to view. Player settings changed (reduce_effects swaps the glass tier, reduce_motion stops camera
## inertia). Emitted by Session.save_settings(); read the values from Session.get_settings().
@warning_ignore("unused_signal")
signal settings_changed()

## view to ui. The "while you were away" time-lapse (game-mechanics §8 step 1) began playing CatchUpResult.
## keyframes. T2 starts playback itself on Session.session_ready or resumed when result.play_time_lapse is
## true, and emits this; T3 reads the same flag to know a time-lapse is coming.
@warning_ignore("unused_signal")
signal time_lapse_started()
## ui to view. The player tapped the SkipPill, or anywhere, during the time-lapse (ux-design §12). T2 jumps to
## the last keyframe, then emits time_lapse_finished() as usual.
@warning_ignore("unused_signal")
signal time_lapse_skip_requested()
## view to ui. The time-lapse ended, by itself or after a skip. T3 then shows the away summary card. When
## there is no time-lapse (the setting is off, or play_time_lapse is false), T3 shows the summary at once and
## no time-lapse signal fires.
@warning_ignore("unused_signal")
signal time_lapse_finished()

## view to ui. where is &"starter" or &"glass". A poke never changes the sim.
@warning_ignore("unused_signal")
signal starter_tapped(where: StringName)

## Both directions. Drives the frame cap (architecture.md §11).
@warning_ignore("unused_signal")
signal interaction_started()
@warning_ignore("unused_signal")
signal interaction_ended()
