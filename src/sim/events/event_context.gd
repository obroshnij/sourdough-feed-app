class_name EventContext
extends RefCounted
## What every rule sees (data-models.md §5). Not saved. No RNG: rules are deterministic functions of this.

## After an action: the state before the action. On a plain step: the state one step earlier.
var prev_state: StarterState = null
var state: StarterState = null
var derived: DerivedState = null
## Derivation of prev_state, so state_enter rules can compare labels.
var prev_derived: DerivedState = null
var env: EnvironmentState = null
var history: PlayerHistory = null
var ledger: EventLedger = null
var now_unix: int = 0
var local_minute_of_day: int = 0
var utc_offset_s: int = 0
var app_foreground: bool = false
## Null on plain steps.
var last_action: GameAction = null
## For Forecast calls such as warm_and_quick's 22 C run.
var catalog: SimCatalog = null
