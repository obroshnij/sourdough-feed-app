# Art direction

Owner: art-director. Status: Phase 1 draft, wave A. Look-dev jar v0 is built and verified (see §12).

Source of truth for the jar: `art/blender/scripts/build_jar.py`. Change a parameter, re-run, and the .blend, GLB and previews all follow. Never hand-edit `jar_v0.blend` or the GLB.

## 1. Mood

**A quiet, sunlit corner of a home kitchen at mid-afternoon.** A premium product photo you could live inside.

- Warm window light from the left, soft shadows, nothing harsh.
- The glass is the hero: clean, thick-based, with long vertical highlights like a studio softbox.
- The starter looks like whipped cream or soft dough: creamy, glossy, a little translucent at the edges. Never gray sludge, never hyper-real or slimy.
- Calm surroundings: pale oak butcher block, sage glazed tiles, all soft-focus. The jar is the only sharp thing in frame.
- References, in words: Scandinavian kitchen photography (natural light, matte wood, linen), ceramic studio product shots (soft gradients, warm whites), and the calm still-life framing of cozy games like *Unpacking* and *A Little to the Left*, but in realistic 3D.
- Anti-references: glossy toy plastic, saturated cartoon colors, dark moody "food porn", lab or medical looks.

## 2. Palette

### 2.1 Scene (sRGB hex, as authored in `build_jar.py` `C{}`)

| Role | Hex | Notes |
|---|---|---|
| Starter, white_bread | `#F0E3C9` | Warm ivory. The anchor color of the game |
| Starter, whole_wheat | `#DCC29C` | Tan, plus bran flecks `#8A6A48` |
| Starter, rye | `#BE9F7E` | Cocoa-latte. Warm, never gray |
| Starter, spelt | `#E3CCA6` | Golden cream |
| Bubble pocket | `#CDB590` | Inside a bubble seen through glass. Only a little darker than the starter |
| Hooch | `#8A7860` | Gray-brown, glossy |
| Hooch, long-sitting | `#5A5045` | `unhealthy` and dark hooch |
| Dry skin or crust | `#CDBB98` | Dull, matte |
| Glass tint | `#FAFDFB` | Per surface. Compounds to a faint green over four crossings |
| Lid wood (oiled oak) | `#AD9670` / `#6E5B3F` | Kept low-chroma on purpose, see 2.3 |
| Enamel cap | `#EFE7D8` | Cream |
| Linen | `#E6DCCA` with stripe `#8E9F86` | Oatmeal linen, sage stripes |
| Twine | `#B79C74` | |
| Rubber band | `#5F7458` | Deep sage |
| Counter oak | `#D2C09E` / `#B19B76` | Pale butcher block |
| Tiles | `#A9B49F` / `#9DAA92`, grout `#DCD4C4` | Sage glaze, out of focus |
| World ambient | `#F3E8D8` top, `#5B4B3D` bottom | |
| Mold, halo / ring / core / spores | `#F4F4EE` / `#8FB0A2` / `#2F7465` / `#1F2A27` | `moldy` only |

### 2.2 UI (agreed with ux-designer, ratios in `ux-design.md` §16.1)

| Role | Hex |
|---|---|
| surface | `#FBF6EC` |
| surface_night | `#EDE3D2` (HUD plate at alpha 0.94) |
| surface_alt | `#F1E7D6` |
| ink / ink_muted | `#33241A` / `#6A5444` |
| accent / on_accent | `#4F6B47` / `#FFFCF5` (deep sibling of the scene sage) |
| outline / disabled | `#8A7461` / `#8F7D6E` |
| Status tones | good `#4F7A45`, rest `#4E6A80`, watch `#8A6414`, care `#6E4F12`, stop `#8E2B22` |

Type: Figtree for all UI (measured 0.427 to 0.440 em). Fraunces only for the starter's name and journal titles, if it measures under 0.47 em. Both SIL OFL 1.1, and the license text ships with the app.

### 2.3 Reserved hues (hard rule)

**Pink, orange and red never appear in or on the jar, except as mold.** In real life they mean discard (`vision.md` safety rules). So:
- No terracotta bands, no orange wood, no warm-red rim lights.
- Woods are desaturated toward yellow-brown. AgX pushes warm wood toward peach, so check every wood change in a render.
- UI: stop (red) is used only for `moldy` (ux-designer agreed).
- Status is never color alone. The pill always has an icon and a word.

## 3. Lighting

| Light | Blender v0 (`setup_lights_camera`) | Godot (Mobile) | Compatibility |
|---|---|---|---|
| Key | Area 0.30 x 0.80 m, front-left high, 3.8 W, `#FFE6CC`, spread 75 degrees | DirectionalLight3D, warm 4300 K look, shadows on (1 split, max distance 1.5 m, soft PCF) | Same, shadow filter low |
| Fill | Area 0.9 m, front-right, 10% of key, `#EEF0F5` | Ambient from the sky or cubemap, energy 0.35 | Same |
| Rim | Strip 0.10 x 0.55 m behind-right, 85% of key, `#FFE0BC` | SpotLight3D behind-right, no shadow. It draws the glass edge highlight | OmniLight3D, no shadow |
| Top | Area 0.4 m overhead, 15% of key | Folded into ambient | Same |
| Environment | Gradient world, strength 0.30 | One baked 128 px cubemap of the kitchen (reflections on glass and starter). AgX tonemap (matches Blender), exposure tuned to the previews | Cubemap only, Filmic if AgX is unavailable |
| Contact shadow | Real | Baked soft AO decal under the jar (64 px texture) | Same |

**Key-to-fill about 4:1.** The right side of the jar stays a little darker, and the rim brings the edge back. Flat front light makes glass look cheap.

**Time of day.** Three presets cross-fade on the device's local clock over about 20 minutes:

| Preset | When | Key | Ambient | Backdrop |
|---|---|---|---|---|
| morning | 06 to 11 | Neutral `#FFF1E2`, higher angle | Slightly cool | Tiles brighter |
| afternoon (default, the previews) | 11 to 17 | `#FFE6CC`, low left | Warm | As built |
| evening and night | 17 to 06 | Under-cabinet lamp `#FFD7A8` close above-left, window dark | Low, warm | Darkest about `#1A1310` |

The HUD plate cross-fades from surface to surface_night on the same blend factor as the evening preset. The jar is always well lit; night never hides the starter.

**Locations** (one kitchen scene, camera moves and light presets, per game-designer):
- `counter`: as built.
- `warm_spot`: next to the kettle or oven. Key 10% warmer, a faint heat shimmer is optional.
- `fridge`: cool top key `#DCE8F2`, lower saturation (-20%), glass shader `fog` 0.3 for condensation. P1 adds frost at the base.
- `window_sill` and `proofing_box`: P1.

## 4. Materials, Blender to Godot

Every GLB material is a placeholder. Godot assigns shader materials by node and surface. "Tier B" is the Mobile renderer, "Tier A" is Compatibility (D-008, D-009).

| Material (GLB name) | Look | Blender look-dev build | Godot Tier B (Mobile) | Godot Tier A fallback |
|---|---|---|---|---|
| `M_Glass` (surface 0), `M_Glass_Inner` (surface 1) | Clear, thick base, long highlights, faint green at grazing edges, a whisper of smudge | Principled, transmission 1, IOR 1.5, roughness 0.008 to 0.045 from noise. Shadow rays see a transparent BSDF (light shadows). No volume absorption: with two surfaces, Cycles floods the cavity | Two passes on one node: `cull_front` then `cull_back`, `blend_mix`, `depth_draw_never`. Alpha and reflection from fresnel (Schlick, F0 0.04). Cubemap reflection. Screen-texture refraction (`hint_screen_texture`, mip blur 1 to 2) offset by the view-space normal times 0.02. Edge tint `#CFE3D6` weighted by fresnel stands in for thick-edge absorption. `fog` uniform for fridge condensation | Same two passes without the screen texture: fresnel alpha, cubemap reflection, edge tint |
| `M_Starter` | Creamy, glossy, soft, alive | Principled with subsurface 0.35, coat by state. Voronoi bubbles (domain-warped, size per cell), crackle for dryness, flecks, hooch band by height, mold colonies | One opaque spatial shader (D-010). Vertex: the formula in §5. Fragment: one packed 256 px RGBA noise texture (R bubble cells, G cell random, B crackle edges, A fine noise), sampled through the UV0 atlas, no 3D noise at runtime. Wrap diffuse (0.3) plus a warm back-scatter term instead of SSS. Sheen into roughness and specular. Hooch band from the vertex height against `u_level` | Same shader with the bubble normal from a precomputed normal channel, no back-scatter |
| `M_Starter_Liner` | Cream residue ring at `peak_line`, streaks down to the surface; aged streaks dry and break up; mold colonies on the glass for `moldy` | Mix of transparent and Principled by a streak mask from UV v | Alpha scissor (threshold 0.5) with blue-noise dither for soft edges, `cull_disabled`. Stays in the opaque pass, so no sorting with the glass | Same |
| `M_Lid_Wood` | Oiled oak, horizontal growth rings, cathedral grain on top | Wave bands along Z, noise-warped | 512 px tileable oak albedo + roughness baked from the Blender material, triplanar on object space | Same |
| `M_Lid_Enamel` | Cream enamel, clearcoat, knurled skirt | Principled + coat, knurl from a radial-angle sine bump | StandardMaterial3D, clearcoat 0.6. Knurl from `sin(atan(z,x) * 120)` in a tiny shader, skirt only | StandardMaterial3D, no knurl |
| `M_Cloth_Linen`, `M_Twine` | Oatmeal linen with sage tea-towel stripes, fine weave | Stripes from UV, weave from two wave textures, sheen 0.6 | 512 px tileable linen albedo + normal, stripes from UV in shader, rim (sheen) 0.4, `cull_disabled` | Same |
| `M_Rubber_Band` | Deep sage rubber, soft matte | Principled, roughness 0.55 | StandardMaterial3D | Same |
| `M_Counter_Wood` | Pale oak butcher block, fine grain | Brick-strip planks multiplied by wave grain | 1024 x 512 albedo + roughness baked from Blender | Same |
| `M_Backdrop` | Sage zellige, out of focus | Brick texture tiles, glossy glaze bump, real DOF | Pre-blurred 1024 px image baked from a Blender render with DOF, unshaded with a time-of-day tint | Same |
| `M_Mold_Fuzz_preview` | Render-only hair, not in the GLB | GN curves | See §6, `moldy` | |

## 5. Starter shader contract

Uniform names follow `VisualParams` (`data-models.md` §7). Values below are as Godot reads them.

```glsl
// Constants: art scale, tuned in look-dev. Mirror them in jar_geometry.gd.
const float AUTHORED_H  = 0.030;  // extras starter_authored_height_m (= fed level)
const float DOME_MAX_M  = 0.010;  // dome = 1 -> +10 mm at the center
const float LUMPS_MAX_M = 0.003;
const float HOOCH_MAX_M = 0.010;  // hooch_depth = 1 -> 1 cm (scientist)

// Vertex
float w   = UV2.y;                       // stretch weight: 0 at and below the foot, 1 on rim and cap
float cap = w * (1.0 - UV2.x * UV2.x);   // 0 on side, floor, foot; 1 at the center
float u_level = level_m * rise;
VERTEX.y += w * (u_level - AUTHORED_H)
          + cap * (dome * DOME_MAX_M + lumps * LUMPS_MAX_M * (noise(VERTEX * 70.0) - 0.5) + breath);
```

- `breath = activity * 0.0006 * sin(TIME * 0.9 + phase)`. See §8.
- Mold cushions (only when `mold > 0`): `+ cap * mold * 0.0047 * colony_mask`, where colony_mask comes from the same noise channel the fragment uses for colonies.
- **glTF V flip:** Blender stores `1 - v` for the two data channels (`UV2_Shape` and the liner's UV), so Godot reads the values above directly. `verify_glb.py` checks it. Image-style UV0 maps use the normal convention.
- Hooch band: fragment uses `VERTEX.y_local > u_level - hooch_depth * HOOCH_MAX_M`. Color goes from 45% hooch at the starter side to 100% at the top, roughness 0.04, no back-scatter. Hooch color = `mix(#8A7860, #5A5045, dullness)`, darker with whole grain via `tint`.
- Web strands at peak: bubble cells squash vertically by `1 - 0.7 * stretch`, where `stretch = bubble_size * smoothstep(1.5, 2.3, rise)`. Derived in the shader, no new field.
- Residue aging: liner streaks dry with `surface_dryness`. Derived, no new field.

## 6. The starter in each state

Values are look-dev targets for `VisualMapper`. Previews exist for the eight states marked R. The scientist's spec decides when each state applies.

| State | rise | dome | lumps | bubble_density | bubble_size | peak_line | streak_amount | hooch_depth | surface_dryness | sheen | dullness | mold | activity | What the player sees |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `freshly_fed` R | 1.0 | 0.1 | 0.85 | 0.1 | 0.1 | 0 | 0 | 0 | 0 | 0.35 | 0 | 0 | 0.15 | Surface at the band. Lumpy from stirring, satin, a few pinholes |
| `developing` | 1.2 | 0.25 | 0.5 | 0.35 | 0.15 | 0 | 0 | 0 | 0 | 0.45 | 0 | 0 | 0.4 | First small bubbles at the glass. Just above the band |
| `active` R | 1.7 | 0.45 | 0.45 | 0.7 | 0.35 | 0 | 0 | 0 | 0 | 0.55 | 0 | 0 | 0.8 | Many small and medium bubbles, convex top, steady rise |
| `near_peak` | 2.1 | 0.65 | 0.4 | 0.75 | 0.55 | 0 | 0 | 0 | 0 | 0.6 | 0 | 0 | 0.7 | Dome forming, bigger bubbles near the top |
| `at_peak` R | 2.3 | 0.8 | 0.5 | 0.65 | 0.8 | 0 | 0 | 0 | 0 | 0.65 | 0 | 0 | 0.5 | Tallest, clear dome, big irregular bubbles at the top, stretched pockets through the glass |
| `collapsing` R | 1.9 | -0.4 | 0.45 | 0.4 | 0.75 | 2.3 | 0.8 | 0 | 0 | 0.7 | 0 | 0 | 0.3 | Center sinks below the rim. Cream ring at the peak line, streaks down to the surface |
| `hungry` R | 1.25 | -0.1 | 0.15 | 0.2 | 0.85 | 2.3 | 0.5 | 0.35 | 0.1 | 0.7 | 0 | 0 | 0.1 | Lower and loose, few big holes, thin gray-brown hooch band, old dried ring above |
| `dormant` R | 1.0 | 0 | 0.2 | 0.05 | 0.2 | as stored | as stored | 0.5 | 0.1 | 0.5 | 0 | 0 | 0.02 | Flat and still, hooch layer, no visible breathing |
| `recovering` | 1.1 to 1.5 | 0.2 | 0.4 | 0.25 | 0.3 | as stored | as stored | 0 | 0 | 0.45 | 0 | 0 | 0.3 | Like developing, lower and slower |
| `unhealthy` R | 0.95 | -0.05 | 0.35 | 0.03 | 0.2 | as stored | 0.6 | 0.4 | 0.85 | 0.1 | 1.0 | 0 | 0.05 | Dull dry skin with fine crackle, thick dark hooch, flat, almost no bubbles. **Never fuzz, never pink, orange or red** |
| `moldy` R | 0.95 | -0.05 | 0.4 | 0.02 | 0.2 | as stored | 0.6 | 0 | 0.7 | 0.1 | 1.0 | 0.75 | 0 | Fuzzy colonies: frayed white halo, gray-green ring, blue-green core, dark spores. Raised on the surface and on the glass up to about 2 cm above it. The only state with any colony or fuzz |

Flour: `tint` from §2.1. `fleck` 0.6 for whole_wheat, 0.35 for rye. Rye at rise 1.3 or more cracks instead of doming: `dome` x 0.3, crackle at 0.5, matching the scientist's `cracked` shape.

**Mold in Godot.** `moldy` is terminal and rare, so it may cost more:
- Tier B: 6 shells of the top cap, offset 0.4 mm apart along the normal, alpha scissor on a hair-noise channel. Plus colonies in the liner shader, face-on behind the glass.
- Tier A: no shells. Colonies, sheen and raised bump in both shaders.
- When the state enters `moldy`, colonies fade in over 2 s.

## 7. Reference renders (for QA)

Files: `art/previews/jar_v0_<state>.png` for `freshly_fed`, `active`, `at_peak`, `collapsing`, `hungry`, `dormant`, `unhealthy`, `moldy`. 720 x 1280, Cycles 64 samples with denoising, about 13 s each on an Apple M4.

**Preview pose, in Godot terms:**

| Field | Value |
|---|---|
| Target | (0, 0.105, 0) m |
| Distance | 0.58 m |
| Yaw | 0 degrees (camera on +Z, looking toward -Z) |
| Pitch | -15 degrees |
| Camera position | (0, 0.2551, 0.5602) m |
| Vertical FOV | 33.4 degrees (`keep_aspect = KEEP_HEIGHT`) |
| Near | 0.01 m |
| DOF | Focus 0.556 m, about f/2.4 at 60 mm on full frame. Optional in captures |
| Framing check | Jar and lid between 23% and 82% of frame height. HUD keeps out of the top 22% and bottom 18% |

**Tells to check per state.** Match the tells, not the pixels. Blender is Cycles, Godot is real time.
- `freshly_fed`: surface level with the band (within 1 mm). No ring on the glass. Bubbles fewer than `active`.
- `active`: surface clearly above the band (about 1.7x). Convex top. Many small bubbles visible at the glass.
- `at_peak`: highest surface of the set (about 2.3x). Dome visible in silhouette. Bubbles larger than `active`. No streaks.
- `collapsing`: surface below the peak. Center lower than the rim (concave). Cream ring and streaks above the surface. No pink, orange or red.
- `hungry`: surface lower than collapsing. Gray-brown liquid band on top. Faint dried ring above.
- `dormant`: surface near the band. Hooch band. No streak ring. No motion over 10 s.
- `unhealthy`: dull, matte top with crackle. Dark hooch. No colonies, no fuzz, no pink, orange or red anywhere.
- `moldy`: at least 3 blue-green colonies with white halos visible from the preview pose, readable at 25% scale (180 px wide jar). The status pill shows the moldy icon and word.

## 8. Animation

The jar is alive at all times, but calm. Nothing snaps except the band.

| Motion | Spec |
|---|---|
| Breathing | Cap swell, amplitude `activity * 0.6 mm`, period 6 to 9 s, phase noise per cycle. Zero for `dormant` and `moldy` |
| Bubble life | Side bubbles grow over 3 to 8 s and drift up 1 to 3 mm. Top pops at `activity * 0.4` per second, each a 0.25 s ring ripple in the starter shader. No particles inside the glass (D-009) |
| Real rise | 1:1 clock, effectively invisible. Fine |
| Catch-up on return | Time-lapse from `snapshots`, 1.5 to 3 s total, ease-in-out cubic |
| Feed | Level drops for the discard (0.6 s ease-in), then flour and water: level rises with a damped wobble (spring, 0.8 s, 2 oscillations, max 1.5 mm), lumps jump to the fed value |
| Band snap | After a feed, the band moves to the new `level_m` in 0.35 s, ease-out back, 6% overshoot, with a soft rubber "tick" sound |
| Cover change | Lid lifts 8 mm and rotates 10 degrees, 0.5 s ease-in-out. Cloth fades and scales 0.97 to 1.0 in 0.4 s |
| Camera | Rotate and zoom with inertia, damping 6 per second, zoom 0.35 to 0.8 m |
| Reduced motion | Breathing and drift off. State visuals unchanged |

**Easing:** never linear. UI 150 to 400 ms, scene 0.6 to 3 s.

**Largest change per 60 s sim step that doesn't read as a pop** (QA PROP-10). The view also smooths every field with a 1.5 s critically damped follow. Feeds and state entry into `moldy` are animated events and exempt.

| Field | max_delta / 60 s | Field | max_delta / 60 s |
|---|---|---|---|
| `rise` | 0.02 | `streak_amount` | 0.05 |
| `dome` | 0.03 | `hooch_depth` | 0.02 |
| `lumps` | 0.03 | `surface_dryness` | 0.02 |
| `bubble_density` | 0.03 | `sheen` | 0.03 |
| `bubble_size` | 0.02 | `dullness` | 0.02 |
| `activity` | 0.05 | `tint` (per channel) | 0.02 |
| `peak_line` | never decreases within a cycle | `mold` | 0 except the latched fade-in |

## 9. VFX (mobile-cheap)

Budget: at most 64 particles on screen, 2 systems at once, 2 overdraw layers. Everything drawn after the glass, outside the jar. CPUParticles3D on Compatibility.

| Effect | Spec |
|---|---|
| Smell wisps | 2 or 3 soft ribbon quads (128 x 256 gradient sprite) rise from the mouth when the cover is off. 2.5 s. Tint by family: warm cream (yeasty, fruity, yogurt), pale straw (tangy, acidic, alcohol), pale cool gray (acetone), gray-green (musty). Never red, orange or pink |
| Bubble pops | In the starter shader, not particles (see §8) |
| Flour dust | 20 to 40 beige quads, 2 to 4 mm, on the feed pour, falling and fading over 1.2 s |
| Steam (warm_spot) | P1, 8 quads |

## 10. Environment

v0: a kitchen corner. Oak butcher-block counter, sage tile wall, soft focus. The window is off-screen left as the key light.

- Godot: Counter mesh plus `Backdrop_placeholder`, a wall card with a pre-blurred image. No real DOF needed on mobile.
- Props (P1, soft-focus only, never competing with the jar): a flour canister, a folded linen towel, a small herb pot.

## 11. Icons (style for ux-designer's set)

- Rounded line icons, 24 pt grid, 2 pt stroke, round caps and joins, 2 pt corner radius. Filled variant for selected.
- Motifs are drawn from the jar world: jar silhouette, bubbles, wisps, band, wheat ear, spoon.
- Status icons are distinct shapes, readable in grayscale.
- No faces or eyes (the starter has none).
- Production SVGs: see Open decisions.

## 12. Mesh contract (`assets/3d/jar_v0.glb`)

Agreed with tech-architect and godot-developer. **The node names are an interface.** Later containers are separate GLBs with the same names.

**Conventions:**
- Meters, real scale. Godot +Y up (Blender +Z). The jar front faces Godot +Z.
- Flat hierarchy. Rotation and scale are identity; nodes carry translation only.
- No cameras or lights.
- Materials are placeholders with stable names.
- Smooth normals. Inner glass surfaces face the jar axis.

| Node | Origin (Godot) | Built as | Tris | Notes |
|---|---|---|---|---|
| `Jar_Glass` | (0, 0, 0) base center | Closed solid shell. Outer D 84 mm, H 170 mm, wall 3.5 mm, base 8 mm. Inner r 38.5 mm, inner corner r 4 mm, neck r 37.5 mm | 4032 | Surface 0 = outer, lip and base. Surface 1 = inner wall and floor. Extras: inner_radius_m, outer_radius_m, height_m, wall_m, floor_y_m |
| `Starter_Body` | (0, 0.008, 0) inner floor | Closed cylinder, r 38.0 mm, authored 30 mm (= fed level). Rounded foot concentric with the glass inner corner, foot top 4 mm. 48 segments, 10 side rings, 16 cap rings | 3360 | UV0 = non-overlapping atlas (side strip, cap disc, floor disc). UV2.x = radial 0..1, UV2.y = stretch weight (§5). Extras: starter_authored_height_m, starter_foot_top_m, starter_radius_m, inner_radius_m, floor_y_m |
| `Starter_Liner` | (0, 0.008, 0) | Open cylinder r 38.35 mm, from the foot top (4 mm) to 125 mm | 2304 | UV v = height above floor / 0.125 (bottom 0.032). Double-sided. Extras: liner_height_m |
| `Jar_Lid_Loose` | (0, 0.170, 0) rim top | Turned oak lid with a plug, knob | 2592 | Cover `loose_lid` |
| `Jar_Lid_Tight` | (0, 0.170, 0) | Enamel screw cap | 1536 | Cover `tight_lid` |
| `Cloth_Cover` | (0, 0.170, 0) | Draped 150 mm square linen with folds, short skirt that never hides the starter, plus twine (surface 1) | 3576 | Cover `cloth`. Single-sided, render double-sided |
| `Rubber_Band` | (0, 0.038, 0) its center | Flat band on the body | 1152 | y = floor + `level_m` |
| `Counter` | (0, 0, 0) top surface | Slab, rounded front edge | 32 | |
| `Backdrop_placeholder` | (0, 0, 0) | Wall card at z = -0.45 m, UV 0..1 | 96 | Placeholder |
| `StarterFloor` | (0, 0.008, 0) | Empty | | Fallback for extras |
| `StarterRim` | (0.0385, 0.133, 0) | Empty | | Inner radius, liner top |

All variants: 18,680 tris (budget 30k). **Visible set** (base + one cover, `architecture.md` §11 budget 16k): loose lid 13,568, tight lid 12,512, cloth 14,552. Verify after every export: `python3 art/blender/scripts/verify_glb.py` (asserts both budgets, exits 1 on any break). Last run: PASS.

## 13. Asset conventions and budgets

- **Naming:** contract nodes as above. Materials `M_*`. Temporary assets `*_placeholder`. Blender-only helpers `*_preview`.
- **Pipeline:** one script per asset in `art/blender/scripts/`, parameters at the top, headless:
  `/Applications/Blender.app/Contents/MacOS/Blender -b -P art/blender/scripts/build_jar.py [-- --no-render | --states a,b | --samples N | --scale P | --cover NAME | --out DIR]`.
  The full run takes about 2 minutes (build, export, .blend, 8 renders). The .blend keeps a live Geometry Nodes modifier, `StarterShape` (Level, Dome, Lumps, Mold), that mirrors §5.
- **Polycount:** glass 5k or less, starter 4k or less. The rendered scene (base plus one cover) is 16k or less. All variants in the GLB are 30k or less. Lathed parts share 48 segments.
- **Textures:** 1024 px max, ASTC or ETC2, 8 MB VRAM for the whole scene. Prefer procedural shader detail over big maps.
- **Draw calls:** the jar is under 10 draw surfaces (`architecture.md` §11): glass 4 (2 surfaces x 2 passes), starter, liner, band, cover 1 or 2. Counter and backdrop are 2 more.

## 14. Placeholders

| Asset | Why it's a placeholder | Replaced by |
|---|---|---|
| `Backdrop_placeholder` | Flat card | Baked soft-focus kitchen image, Phase 2 |
| All GLB materials | By design | Godot shaders (§4) |
| `M_Mold_Fuzz_preview` | Blender-only hair | Godot shells (§6) |

## 15. Open items

- Production icon SVGs (11 status, 5 action, 5 inspection, plus filled variants): art-director in Phase 2, unless the director assigns them elsewhere.
- Pink or orange mold tint: not in v0. sourdough-scientist agrees this is the conservative choice for safety: text already teaches "fuzz, pink or orange means discard". A visual variant can come later as an optional P1 item. Either way, the hard rule stays: never pink, orange or red outside `moldy`.
- `moldy` from the default pose relies on glass colonies. Consider an automatic `surface` close-up on entering `moldy` (game-designer and ux-designer).
