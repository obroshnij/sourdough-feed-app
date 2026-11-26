class_name SimRates
extends RefCounted
## Per-hour rates from the start-of-step state (spec §7). Built by `Sim.rates()`.

var food: float = 0.0
var yeast: float = 0.0
var lab: float = 0.0
var acid: float = 0.0
var rise: float = 0.0
var hooch: float = 0.0
var dryness: float = 0.0
var vigor: float = 0.0
var starved_h: float = 0.0
var mold_risk: float = 0.0
## Derived, not integrated.
var gas: float = 0.0
var starving: bool = false
