class_name SimFixtures
extends RefCounted
## The reference model's start states (spec §18, tools/sim-reference/README.md). Pure.
## seed_state = sim.py State() at temp_c 22; mature = mature(); young = mature() with maturity 0.2.

static var _mature: StarterState = null


static func seed_state() -> StarterState:
	return StarterState.new()


## The MATURE fixture: seed, fed 50 g + 50 g white_bread + 50 g water (feed_u 0.5), then 12 h at the counter
## with a loose lid. Computed once, then copied.
static func mature() -> StarterState:
	if _mature == null:
		var s: StarterState = seed_state()
		feed_ratio(s)
		var counter: EnvironmentState = EnvironmentState.make(22.0, 50.0)
		for i: int in 720:
			Sim.step(s, counter)
		s.sim_time_unix = 0
		_mature = s
	return _mature.copy()


static func young() -> StarterState:
	var s: StarterState = mature()
	s.maturity = 0.2
	return s


## sim.py feed_ratio(): ratio a : b : _ with `kept` grams kept and water = flour * hydration / 100.
static func feed_ratio(s: StarterState, a: float = 1.0, b: float = 1.0, flour: StringName = &"white_bread",
		hydration: float = 100.0, kept: float = 50.0, feed_u: float = 0.5, stir_in: bool = false) -> bool:
	var flour_g: float = kept * b / a
	return Sim.feed(s, kept, {flour: flour_g}, flour_g * hydration / 100.0, feed_u, stir_in)
