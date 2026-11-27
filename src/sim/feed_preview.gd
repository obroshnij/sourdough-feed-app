class_name FeedPreview
extends RefCounted
## Everything the feed sheet shows before Mix (game-mechanics §2, game-copy §7), from `FeedPlanner`.
## Built from the state as it is now; applying `action` through `Session.apply()` is what commits it.

## Ready to apply. Same instance the UI hands to Session.apply() (it may change hooch_choice first).
var action: FeedAction = null
## The schedule answer it was planned for (&"soon", &"later", &"tomorrow"), or &"" for an exact preset.
var answer: StringName = &""
## Grams to scrape out before feeding: the jar's mass now minus kept_g, rounded (always shown in grams).
var discard_g: int = 0
var kept_g: int = 0
var flour_g: int = 0
var water_g: int = 0
## The {ratio} text, "1:5:5".
var ratio_text: String = ""
## The peak forecast after this feed. has_window is false in the fridge and similar.
var forecast: PeakForecast = null
## WINDOW_* for FORECAST_LINE ({window}), or &"" when the forecast has no window.
var window_key: StringName = &""
## The forecast at_peak start lands inside the schedule answer's window (always true for an exact preset).
var fits_window: bool = true
## &"", or FEED_FIT_TOO_WARM, FEED_FIT_TOO_COOL or FEED_FIT_FRIDGE (non-blocking line, game-copy §7).
var fit_key: StringName = &""
## The timing class this feed would get: early, on_time, late, very_late, rescue (game-mechanics §2.4).
var timing: StringName = &""
## &"", FEED_EARLY_NOTE (early) or FEED_RESCUE_NOTE (rescue). Non-blocking.
var note_key: StringName = &""
## True when hooch is visible (hooch >= 0.10): the sheet opens on the hooch step, Pour off preselected.
var hooch_step: bool = false
## Show FEED_ROUTINE_HINT (game-mechanics §2.2): the last 3 feeds were each 20 h or more apart, this feed
## peaks in under 10 h, and the hint wasn't shown in the last 7 days.
var routine_hint: bool = false
## &"" when Mix would be accepted, else the reason key Session.apply() would return (MOLD_FEED_BLOCKED...).
var reason_key: StringName = &""
