class_name DerivedState
extends RefCounted
## Derived, never stored (data-models.md §2, spec §12). Built by `StateDeriver.derive()`.

## One of the 11 canonical state ids.
var state: StringName = &""
## Always a rise-phase id, even when state is recovering or hungry. &"" only when moldy
## (the reference model computes no phase for a moldy starter).
var rise_phase: StringName = &""
## ferm(temp_c), spec §3. Not clamped: about 1.33 at 35 C.
var ferm: float = 0.0
## &"cold" or &"starved" when state is dormant (cold wins), else &"".
var dormant_cause: StringName = &""
## 0..1, the clamped gas term (spec §13 gas_n). Drives breathing and bubble motion.
var activity: float = 0.0
## d rise / dt in x/h, from the spec §7 equations at this state.
var rise_rate: float = 0.0
## Gas production (spec §7), unclamped.
var gas: float = 0.0
