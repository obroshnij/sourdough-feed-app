extends Node
## Autoload `Bus`: the ui and view contract (architecture.md §3.3). Signals only, no state.
## ui and view never reference each other; they talk only through these signals.
## Owner: T1. Additions by request, so T2 and T3 both see them.

## ui to view. Camera stops inertia, VFX dim.
@warning_ignore("unused_signal")
signal sheet_opened(sheet_id: StringName)
@warning_ignore("unused_signal")
signal sheet_closed(sheet_id: StringName)

## ui to view. target is one of &"bubbles", &"surface", &"height", &"top", &"home".
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

## view to ui. where is &"starter" or &"glass". A poke never changes the sim.
@warning_ignore("unused_signal")
signal starter_tapped(where: StringName)

## Both directions. Drives the frame cap (architecture.md §11).
@warning_ignore("unused_signal")
signal interaction_started()
@warning_ignore("unused_signal")
signal interaction_ended()
