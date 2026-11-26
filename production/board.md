# Production board

Owner: director (the only writer). Teammates report by message. Last updated 2026-11-26.

## Phase 1: research and design (branch `phase-1-design`)

| Task | Owner | Status | Notes |
|---|---|---|---|
| Studio plan, vision brief, decision log, agent definitions | director | done | |
| Science doc and simulation spec v1 | `sourdough-scientist` | done | Reference model in `tools/sim-reference/`; V1 to V20 pass |
| Game design, mechanics, progression | `game-designer` | done | BT-1 to BT-17, L-1 to L-11 |
| Narrative, events catalog, game copy | `narrative-designer` | done | 612 strings; checker in `tools/i18n/` passes |
| Art direction and look-dev jar v0 | `art-director` | done | GLB passes `verify_glb.py`; 8 preview renders |
| Architecture, data models, technical decisions | `tech-architect` | done | ADR-001, 002, 003 and 015 wait on the spike |
| Jar spike | `godot-developer` | in progress | Benchmarks running |
| UX design | `ux-designer` | done | |
| Test plan and acceptance criteria | `qa-engineer` | done | AC-01 to AC-12 |
| Wave B cross-review | all | done | Scientist's safety sign-off: yes |
| MVP scope, roadmap, decision log | director | done | `docs/mvp-scope.md`, `docs/roadmap.md`, D-017 to D-034 |
| Present to the user | director | next | |

## Waiting on the user

- Review Phase 1, then approve Phase 2.
- Confirm D-018 (temperature by place, humidity not a control) and D-019 (containers and covers in P2). Both narrow the brief.
- Approve the downloads in `docs/roadmap.md`: export templates (1,281 MB) and the two fonts.
- The repo is public. Decide whether it stays that way.

## Later phases

| Phase | Status |
|---|---|
| 2. Foundation | Waiting for Phase 1 approval and the downloads |
| 3. Vertical slice | |
| 4. Polish and the rest of the MVP | |
| 5. Mobile validation | |
