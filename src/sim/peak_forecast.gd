class_name PeakForecast
extends RefCounted
## `Forecast.peak_window()` output (game-mechanics.md §6). Times are seconds after the feed, simulated at
## jitter 0.95 and 1.05. The UI turns them into time-of-day words, never a countdown.

## False for dormant, unhealthy, moldy and hungry, or when no peak comes within 48 h.
var has_window: bool = false
var at_peak_start_min_s: float = 0.0
var at_peak_start_max_s: float = 0.0
var peak_min_s: float = 0.0
var peak_max_s: float = 0.0
var peak_rise_min: float = 0.0
var peak_rise_max: float = 0.0
