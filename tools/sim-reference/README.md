# Sim reference model

Owner: `sourdough-scientist`. One self-contained Python file, `sim.py`, that implements [`docs/starter-simulation-spec.md`](../../docs/starter-simulation-spec.md) **v1.1**. It is the oracle for the Phase 2 golden tests: the GDScript sim in `src/sim/` must reproduce its numbers. It is not game code and never ships.

## What it implements

- Spec v1.1: every equation in §3 to §11, the **§7 per-step procedure** (simultaneous explicit Euler, 60 s fixed step, start-of-step `temp_c`, then clamp, mold latch, peaks, temperature lag, clock), feeding in §6 (including `stir_in` and generation-weighted maturity), state and `rise_phase` derivation in §12 (with `dormant_cause`), the smell model in §13 (musty first and undamped, ties by vision.md order), and the §13.1 smell check (`smell_check()`, vector V21).
- v1.1 changed only smell (the `pleasantly_tangy` curve) and added the smell check. Stored fields and states are unchanged, so the `trace` output is byte-identical to v1 and the committed golden traces stay valid.
- `feed_u` is passed in explicitly. `feed_jitter = 0.95 + 0.10 × feed_u`, as in §17.
- Not implemented: the §14 inspection readouts and the §14.1 event rules. Those are thin lookups over the state, owned by the game layer.

## Run it

Python 3.8 or newer, standard library only. Verified with Python 3.15.2 on macOS. From the repo root:

```bash
python3 -I tools/sim-reference/sim.py vectors        # V1 to V21 (spec §18), with 269 range checks
python3 -I tools/sim-reference/sim.py calibration    # calibration rows (spec §15)
python3 -I tools/sim-reference/sim.py all            # both, about 5 s on the Mac
python3 -I tools/sim-reference/sim.py trace OUTDIR   # golden JSON traces (below)
```

`-I` (isolated mode) ignores environment variables and user site-packages. The file imports nothing outside the standard library, so it runs the same anywhere.

**Exit code:** `vectors` and `all` exit 1 if any §18 check fails, and list each miss as a `FAIL` line. Each check is the §18 range plus the drift allowance (±0.3 h, ±0.05 rise; "about X" = X ± 5% plus drift). Verified: a 10% change to `mu_y` alone fails 18 checks.

## Golden traces (`trace`)

`trace OUTDIR` writes `T01.json` to `T24.json` plus `manifest.json`: 24 fixed schedules, 3,988 rows, about 3 MB. qa-engineer commits them as `tests/golden/reference_traces/` for DIFF-01. Only `sourdough-scientist` regenerates them, and only when the spec changes. Two runs are byte-identical.

- **Schedules** (listed in `SCHEDULES` in `sim.py`): the fixture build; 1:1:1 at 22, 24 and 28 °C; 1:5:5 and 1:10:10; rye, whole wheat at 60%, spelt at 125%; neglect at the counter, the warm spot with cloth, and 35 °C; fridge round trips; rapid feeds; once- and twice-a-day routines; recovery from unhealthy; stir-in; location moves mid-rise; a young starter; a refused feed on a moldy starter; the 0 °C and 40 °C domain edges.
- **Events** carry explicit `feed_u` values, so traces need no RNG. Each event applies at its minute, in listed order. An `env` event replaces the whole environment.
- **Rows** are taken every whole hour, after that minute's events and before that minute's step. Each row holds `t_h`, every stored field, and the derived `state`, `rise_phase` and `dormant_cause`. Floats are written with Python's shortest round-trip repr, so they parse back to the exact double.
- **Start states:** `seed` = `State()` defaults; `mature` = `mature()`; `young` = `mature()` with maturity 0.2. The initial environment is the counter (22 °C, 50% RH, `loose_lid`, `classic_jar`).

## Regenerating the test vectors

1. Change parameters only in the `P`, `FLOURS`, `COVER_DRY`, `CONTAINER_DRY` and `LOCATIONS` tables at the top of `sim.py`, together with the matching spec sections.
2. Run `vectors` and `calibration`.
3. Copy the new ranges into spec §18 (V1 to V21) and §15. Each vector runs at `feed_u` 0, 0.5 and 1 (jitter 0.95, 1.00, 1.05), and the printed range covers all three.
4. Tell `qa-engineer`, because the golden tests change.

How to read the output: "at_peak" is when that phase starts; "peak" is the max-rise time and height. Checkpoint rows show the state (all states seen across the three draws), the rise range, the middle draw's displayed smells, whether hooch is visible (≥ 0.10), and the mold stage.

## Matching it from GDScript

- Use the same 60 s grid and step order (spec §7, §16). On one build, one long catch-up must equal many short ones exactly (V17 here prints a max difference of 0.0).
- For a 1e-9 trace match, repeat the same float operations in the same order. Integer powers are plain multiplication (`d * d`, `a * a * a * a`). Fractional powers use `pow`. The temperature lag uses `exp`. The maturity weight is `log(total / kept) / log(3)`, not `log2`. Clamp exactly where §7 says.
- Compare traces with a combined tolerance, |a - b| ≤ 1e-9 × max(|a|, |b|) + 1e-12, because several fields sit at or near 0. A 1-ulp difference that lands exactly on a threshold (for example food crossing 0.10) could shift one branch by one step. That is very unlikely, but if it happens, the diff will show it at one row, and the fix is to match the operation order, not to loosen the tolerance.
- Golden vector tests use the §18 allowances: the printed ranges, plus ±0.3 h on times and ±0.05 on rise.
- The `MATURE` fixture is `mature()`: the seed `State()` defaults, fed 50 g + 50 g white_bread + 50 g water, then 12 h at the counter with a loose lid.
