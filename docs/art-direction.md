# Art direction

Owner: art-director. Status: Phase 2. Look-dev jar v0 is built and verified (§12). New in Phase 2: the real-time starter look for T2, with masks and a reference board (§16, D-037), and the production icons (§11, D-034).

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
| Bubble pocket | `#D3BF9E` | Inside a bubble seen through glass. Only a little darker than the starter |
| Hooch | `#8A7860` | Gray-brown, glossy |
| Hooch, long-sitting | `#5A5045` | `unhealthy` and dark hooch |
| Dry skin or crust | `#CDBB98` | Dull, matte |
| Glass tint | `#FAFDFB` | Per surface. Compounds to a faint green over four crossings |
| Lid wood (oiled oak) | `#AD9670` / `#6E5B3F` | Kept low-chroma on purpose, see 2.3 |
| Enamel cap | `#EFE7D8` | Cream |
| Linen | `#E6DCCA` with stripe `#8E9F86` | Oatmeal linen, sage stripes |
| Twine | `#B79C74` | |
| Rubber band | `#7A9271` | Sage. Was `#5F7458`; T2 lifted it because it read near-black in real time. Accepted in Phase 2 sign-off |
| Counter oak | `#D2C09E` / `#B19B76` | Pale butcher block |
| Tiles | `#A3B69F` / `#97AB91`, grout `#DCD4C4` | Sage glaze, out of focus. Authored greener because warm light pulls it toward khaki |
| World ambient | `#F3E8D8` top, `#5A554E` bottom | Near-neutral floor. A brown floor turned the starter's shadow side caramel |
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
| Key | Area 0.30 x 0.80 m, front-left high, 3.8 W, `#FFEAD6`, spread 75 degrees | DirectionalLight3D, 60 degrees left and 50 degrees up, `#FFF6EE` (T2, accepted: puts the shadow side in its row). Shadows on (1 split, max distance 1.5 m, soft PCF) | No shadow maps (a shadowed light lit about 5x too hard). Analytic drop shadow in the counter shader. Filmic plus a grade, since Compatibility has no AgX |
| Fill | Area 0.9 m, front-right, 16% of key, `#F2F2F2` | Ambient from the sky or cubemap, energy 0.35 | Same |
| Rim | Strip 0.10 x 0.55 m behind-right, 85% of key, `#FFEEDD` | DirectionalLight3D from behind-right, no shadow, `#FFEEDD` (T2, accepted: no falloff to tune, and one light type on both renderers). It draws the glass edge highlight | Same |
| Top | Area 0.4 m overhead, 15% of key | Folded into ambient | Same |
| Environment | Gradient world, strength 0.30 | One baked 128 px cubemap of the kitchen (reflections on glass and starter). Tonemap and exposure: T2's choice, signed off against the reference look below | Cubemap only. Tonemap and exposure: T2, against the same reference look |
| Contact shadow | Real | Baked soft AO decal under the jar (64 px texture) | Same |

**Reference look (the target for every renderer).** Per the director's ruling, Compatibility tonemap and exposure parity belongs to the Phase 2 view track (T2), with art-director sign-off. This section gives T2 the target, not the engine settings.

Measured from `art/previews/` at the preview pose (§7). Values are 31 px patch means, sRGB 8-bit, HSV.

| Sample (preview pixel) | Target | Hue | Saturation | Value | Tolerance for Godot |
|---|---|---|---|---|---|
| Starter, lit front-left, mid-height (290, 850 at_peak) | `#DDD3C4` | 36 | 11% | 87% | Value ±6 points, saturation 8 to 16%, max channel 0.92 or less (never clipped) |
| Starter, shadow side front-right (450, 830 at_peak) | `#8A7253` | 34 | 40% | 54% | Value 50 to 62%, saturation 45% or less |
| Starter, lit, all 8 states | `#D8CEBE` to `#DCD1C2` | 35 to 37 | 11 to 12% | 85 to 86% | Same as the first row |
| Counter, front right (600, 1150) | `#E3D7C9` | 32 | 11% | 89% | Saturation 15% or less, never clipped |
| Tile wall, top center (360, 150) | `#A7A183` | 50 | 22% | 65% | Hue 45 to 70 (reads sage, not khaki or gray) |
| Lid top (330, 350) | `#C9AE91` | 31 | 28% | 79% | Saturation 35% or less |

**Rules behind the numbers:**
- **Lit cream is nearly neutral.** The form reads through a lit-to-shadow value ratio of about 1.6 : 1, not through saturation.
- **Starter hue stays 30 to 40 degrees in every state.** Below 25 degrees at saturation over 50% is orange territory, which is reserved for mold (§2.3).
- **Nothing in the frame clips.**

godot-developer's spike readings, at the spike's own pose and lighting, are open with T2:
- Mobile lit starter: 21% HSV saturation, over the 8 to 16% target (reads a little too yellow).
- Compatibility: 3%, washed out.

Likely Mobile fix: desaturate the view's `starter_color` a few points. Keep the palette hex as the authoring reference. A match is signed off against this table at the preview pose.

**Key-to-fill about 4:1.** The right side of the jar stays a little darker, and the rim brings the edge back. Flat front light makes glass look cheap.

**Time of day.** Three presets cross-fade on the device's local clock over about 20 minutes:

| Preset | When | Key | Ambient | Backdrop |
|---|---|---|---|---|
| morning | 06 to 11 | Neutral `#FFF1E2`, higher angle | Slightly cool | Tiles brighter |
| afternoon (default, the previews) | 11 to 17 | `#FFEAD6`, low left | Warm | As built |
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
| `M_Starter` | Creamy, glossy, soft, alive | Principled with subsurface 0.22 (scale 1.8 mm, 0.08 inside bubble pockets), coat by state. Voronoi bubbles (domain-warped, size per cell), crackle for dryness, flecks, hooch band by height, mold colonies | One opaque spatial shader (D-010). Vertex: the formula in §5. Fragment: the side-bubble and top-pit masks (§16.3), plus a small noise for tone and crackle. No 3D noise at runtime. Warm `BACKLIGHT` instead of SSS, glossy cap from `sheen` (§16.5). Hooch band from the vertex height against `u_level` | Same masks and math. The cavity shading is baked from two extra mask taps, so Tier A loses nothing but the optional normal tilt |
| `M_Starter_Liner` | Cream residue ring at `peak_line`, streaks down to the surface; aged streaks dry and break up; mold colonies on the glass for `moldy` | Mix of transparent and Principled by a streak mask from UV v | Residue from the liner mask anchored at the peak line (§16.5g). Alpha scissor (threshold 0.5) with blue-noise dither for soft edges, `cull_disabled`. Stays in the opaque pass, so no sorting with the glass | Same |
| `M_Lid_Wood` | Oiled oak, horizontal growth rings, cathedral grain on top | Wave bands along Z, noise-warped | `lid_oak_detail.png` (256 px, gray, tiles), triplanar in object space, mixing T2's oak colors (§17) | Same |
| `M_Lid_Enamel` | Cream enamel, clearcoat, knurled skirt | Principled + coat, knurl from a radial-angle sine bump | StandardMaterial3D, clearcoat 0.6. Knurl from `sin(atan(z,x) * 120)` in a tiny shader, skirt only | StandardMaterial3D, no knurl |
| `M_Cloth_Linen`, `M_Twine` | Oatmeal linen with sage tea-towel stripes, fine weave | Stripes from UV, weave from two wave textures, sheen 0.6 | 512 px tileable linen albedo + normal, stripes from UV in shader, rim (sheen) 0.4, `cull_disabled` | Same |
| `M_Rubber_Band` | Deep sage rubber, soft matte | Principled, roughness 0.55 | StandardMaterial3D | Same |
| `M_Counter_Wood` | Pale oak butcher block, fine grain | Brick-strip planks multiplied by wave grain | `counter_oak_detail.png` (512 px, gray, tiles) on world XZ, mixing T2's oak colors (§17) | Same |
| `M_Backdrop` | Sage zellige, out of focus | Brick texture tiles, glossy glaze bump, real DOF | `kitchen_backdrop.png` (1024 x 512): the lit wall, pre-blurred, unshaded, with a time-of-day tint (§17) | Same |
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

- Godot: Counter mesh plus `Backdrop_placeholder`, a wall card showing the baked, pre-blurred wall (§17). No real DOF needed on mobile. The card fills the frame to about ±15 degrees of yaw. Beyond that, T2's `kitchen_sky` shows. A set that holds up over the whole ±70 degree orbit is an open item (§15).
- Props (P1, soft-focus only, never competing with the jar): a flour canister, a folded linen towel, a small herb pot.

## 11. Icons (style for ux-designer's set)

- Rounded line icons, 24 pt grid, 2 pt stroke, round caps and joins, 2 pt corner radius. Filled variant for selected.
- Motifs are drawn from the jar world: jar silhouette, bubbles, wisps, band, wheat ear, spoon.
- Status icons are distinct shapes, readable in grayscale.
- No faces or eyes (the starter has none). Watch dot patterns: two level dots over a third read as a face.

**Production set (D-034): `assets/icons/`, 42 SVGs, plus 5 utility icons for T3** (`ui_settings`, `ui_close`, `ui_back`, `ui_check`, `ui_chevron_right`, one variant each, same grid and stroke). The 10 pt dot badge is drawn by T3. Generated by `python3 -I art/icons/make_icons.py`; add `--check` to re-render the 24 px sheet `art/previews/icons_check_24px.png` (needs `rsvg-convert` and `magick`).

- **Names:** `<group>_<canonical id>_<outline|filled>.svg`. Groups are `status`, `action` and `inspect`. Example: `status_at_peak_filled.svg`.
- **Color:** pure white `#FFFFFF` on transparent. Godot tints with `modulate` (white x tone = tone), so one file serves ink, tone, on_accent and the cream-on-stop `moldy` pill.
- **Safe for ThorVG:** no masks, filters, text or `currentColor`. Filled variants cut details out with `fill-rule="evenodd"` only.
- **Pill states (ux-design §17):** normal uses outline. `unhealthy` (care) and `moldy` (stop) use filled. Action bar "open" uses filled.

| Group | Icon (id: shape) |
|---|---|
| status | `freshly_fed`: spoon. `developing`: two bubbles. `active`: three rising bubbles. `near_peak`: dome + up chevron. `at_peak`: dome + sparkle. `collapsing`: sagging dome + down chevron. `hungry`: empty bowl. `dormant`: crescent moon. `recovering`: half sun with rays. `unhealthy`: wilted sprout. `moldy`: octagon with ! |
| action | `feed`: wheat ear. `smell`: two wisps over a nose in profile. `inspect`: magnifier with a bubble in the lens. `environment`: house ("Place", "Where it lives"). `journal`: book with spine and ribbon |
| inspect | `height`: double arrow between the band and a top line. `bubbles`: jar with bubbles at the glass. `surface`: the top seen at an angle, scattered pinholes. `consistency`: a strand pulled from the spoon, ending in a drop. `development`: a circular arrow around a small jar (the slow orbit) |

**24 px render check (rsvg-convert, 1x, magnified 4x with nearest-neighbor):**
- All 11 status shapes stay distinct in grayscale, in outline and filled, and in their real tones on their real pill fills. The closest pairs are `developing` and `active` (2 vs 3 bubbles), and `near_peak`, `at_peak` and `collapsing` (same dome family). They are told apart by count, by chevron direction and by the sag, never by tone.
- Three icons failed the first pass and were redrawn: `surface` read as a face, `development` read as a top hat, and the `smell` nose read as a hook.
- Weakest now: `smell` filled. The nose wedge is clear only with its label. It is fine in the action bar, which always shows the label.

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
| `Backdrop_placeholder` | Still a flat card. The look is final (the §17 bake), and the node keeps its name because names are the interface | A wider or curved backdrop, if the full ±70 degree orbit needs one (§15) |
| All GLB materials | By design | Godot shaders (§4) |
| `M_Mold_Fuzz_preview` | Blender-only hair | Godot shells (§6) |

## 15. Open items

- **Icon import check (T3):** import one filled file with holes (`status_moldy_filled.svg`) through Godot's SVG importer at 2x and 3x, and confirm the evenodd holes survive. rsvg-convert renders them correctly; ThorVG was not run here.
- **`surface` inspection pitch (ux-designer, T2):** at the 60 degree preset (D-036, ux-design §10), the line of sight to the cap center crosses the shoulder glass whenever the cap is lower than 111 mm above the jar base, which is every state (`at_peak` center is about 85 mm). At 76 degrees it passes through the open mouth at every level. **Agreed with ux-designer: 76 degrees** (ux-design §10). At 76 degrees the cap must sit at least 33.6 mm above the jar base. The lowest cap of any state is about 36 mm (`unhealthy` and `moldy`: 8 mm floor + 0.95 x 30 mm, dome -0.5 mm). `freshly_fed` is 39 mm. 72 degrees would fail below 65 mm. The reference board uses 76 degrees (§16.2).
- **Backdrop beyond ±15 degrees of yaw:** the 1.0 m wall card ends there, and the kitchen sky takes over. To keep the soft-focus kitchen over the whole ±70 degree orbit, art would add a curved wall node to the GLB with a wider bake. It's not needed while the home pose sits near yaw 0.
- **Mask import (T2):** confirm on first import that a gray + alpha PNG samples as (L, L, L, A) in 4.7.2 on both renderers (§16.3).
- Pink or orange mold tint: not in v0. sourdough-scientist agrees this is the conservative choice for safety: text already teaches "fuzz, pink or orange means discard". A visual variant can come later as an optional P1 item. Either way, the hard rule stays: never pink, orange or red outside `moldy`.
- `moldy` from the default pose relies on glass colonies. Consider an automatic `surface` close-up on entering `moldy` (game-designer and ux-designer).

## 16. The real-time starter look (D-037, for T2)

The target is Godot captures that hold up next to `art/previews/reference/`. Those renders apply the **same three masks with the same math as this section**, so they show what the masks can do in a renderer. They are not a separate procedural look. Values below are starting points. The rows in §16.6 are what gets signed off.

### 16.1 What the spike gets wrong, measured

Side close-ups at `at_peak`: spike `spikes/jar-spike/screenshots/*_tierA_at_peak_side_closeup.png` against `art/previews/reference/ref_at_peak_side.png`. "Pockets" are paste pixels more than 10 value points under the 80th-percentile value.

| | Spike Mobile | Spike Compatibility | Reference |
|---|---|---|---|
| Paste, lit | `#E3D1B9`, S 19%, V 89% | `#E8E7E4`, S 2%, V 91% | `#DDD3C5`, S 11%, V 87% |
| Bubble pockets, mean | `#977D63`, S 35%, V 59% | `#8B7055`, S 39%, V 54% | `#B4A48A`, S 23%, V 71% |
| Darkest 5% | `#75593F`, S 46%, V 46% | `#593F25`, S 58%, V 35% | `#A18E71`, S 30%, V 63% |

- **Swiss cheese.** The holes are round, evenly spread, one size family, brown, and hard-edged. Bubbles pressed against glass are irregular, clustered and varied: many tiny voids, some medium, a few big ones, often taller than wide, with teardrops and merged lobes. Their pockets are only a little darker than the paste.
- **No translucency.** The shadow side goes flat. Cream should stay warm and a little lifted into its shadow.
- **Weak dome.** The spike makes the cap rougher as bubbles increase (`mix(0.38, 0.6, bubble_density)`), so at peak no highlight shows the curve. Invert that: the peak is the glossiest moment.
- **Compatibility washes the paste to 2% saturation.** T2's tonemap fix (D-037). The rows in §16.6 apply in both renderers.
- **Streaks read as torn paper**: a hard, ragged band. Real residue is a lacy film, a negative print of the bubbles that touched the glass, with a creamy ring at the top and a few soft drips.

### 16.2 Reference board

Rebuild (about 2 minutes on an M4, never touches the GLB, the .blend or the §7 previews):
`/Applications/Blender.app/Contents/MacOS/Blender -b -P art/blender/scripts/render_starter_reference.py`

| File | What it is |
|---|---|
| `art/previews/reference/board_starter.png` | Contact sheet. One row per state: side close-up, then surface close-up |
| `ref_<state>_side.png` | Bubbles through the glass: the inspect `bubbles` framing. 640 x 800 |
| `ref_<state>_top.png` | Into the mouth, lid lifted: the inspect `surface` framing. 640 x 800 |
| `ref_at_peak_pose.png`, `ref_collapsing_pose.png` | The §7 preview pose, 720 x 1280, to compare with spike captures |

States: `freshly_fed`, `active`, `at_peak`, `collapsing`, `hungry`, with the §6 VisualParams.

| State | Side, through the glass | Surface from above |
|---|---|---|
| `freshly_fed` | Smooth satin paste, a light scatter of tiny pinholes | Smooth, a handful of pinholes |
| `active` | Many small and medium bubbles in clusters, some taller than wide, clouds of tiny voids | An even sprinkle of small pits |
| `at_peak` | Big irregular bubbles with teardrops and merged lobes, bigger higher up, plus many small ones | Many pits, a few open craters |
| `collapsing` | Big bubbles, fewer small ones. Above the surface: a creamy ring at the peak line, a lacy film with bubble-shaped gaps, short drips | Sunken and pocked with craters, the ring visible on the glass |
| `hungry` | Few, big, loose holes. A gray-brown hooch band on top. Old residue dried into flecks | Hooch pooled over the top: a flat, glossy gray-brown disc |

**Close-up cameras in Godot terms** (meters, jar base at the origin, `level = rise x 0.030`), so T2 captures the same frames:

| View | Camera position | Looks at | FOV |
|---|---|---|---|
| side | (-0.0737, y + 0.012, 0.1386), with y = 0.008 + 0.55 x level | (0, y, 0) | vertical 33.4 degrees, 640 x 800 |
| top | (0, y + 0.194, 0.0484), with y = 0.008 + level + 0.6 x max(dome x 0.010, 0) | (0, y, -0.004) | same |

The top view is pitched 76 degrees, not 60: see the open item in §15.

### 16.3 Runtime masks and UV mapping

Generator: `python3 -I art/textures/make_starter_masks.py` (numpy only, about 1.5 s, seeded; reruns are byte-identical, checked with md5).

| File | Size | Channels | Tiles | Texel | Covers |
|---|---|---|---|---|---|
| `assets/textures/starter_side_bubbles.png` | 512 x 512 | L = F, A = P | u and v | 0.117 mm | 59.7 mm square, 4 tiles around the starter |
| `assets/textures/starter_top_pits.png` | 512 x 512 | L = F, A = P | u and v | 0.094 mm | 48 mm square, planar on the cap |
| `assets/textures/starter_liner_streaks.png` | 512 x 256 | L = E, A = D | u only | 0.235 mm | 120.5 x 60.2 mm, 2 tiles around the liner |

- **F, feature field:** 1 - rho inside a bubble or pit (rho is 0 at its center and 1 at its full-size outline), 0 outside. Thresholding F at 1 - s shows every feature scaled by s about its own center, so irregular outlines stay irregular at every size.
- **P, presence rank:** the rank of the nearest feature (Voronoi cells, so mip blending only happens in the gaps between features). 0.02 to 0.90; 1.0 means far from any feature. Big and clustered features rank low, so they appear first. That is what makes `hungry` (density 0.2, size 0.85) a few big holes and `freshly_fed` (0.1, 0.1) a few pinholes.
- **E, residue onset:** residue shows where E > 1 - `streak_amount`. The ring at the peak line appears first, then the film and drips, then a faint haze. How far E is above the threshold is the film's thickness.
- **D, drying breakup:** dried residue is removed where D < 0.55 x age. Fine cells (about 2 x 3 mm) crack at their edges first, so old film breaks into flecks, never strips.
- **Why two channels:** `bubble_density` and `bubble_size` are separate VisualParams. One channel can't give both "few and big" and "many and small".

**Import:** these are data, not color. Sampler uniforms without `source_color`, with `filter_linear_mipmap, repeat_enable` (the liner too: its first and last rows are zero, and v is clamped in code). **Use VRAM Uncompressed** (`compress/mode=3`). T2 measured that VRAM Compressed stores gray + alpha as DXT5, which puts F in 5:6:5 color endpoints: max error 0.20, and feathery pocket edges. P in alpha stayed exact. Uncompressed is 0.7 MB per 512 x 512 mask with mips, 1.75 MB for all three, inside the 8 MB scene budget. A gray + alpha PNG should sample as (L, L, L, A): read `.r` and `.a`, and confirm it on first import (§15). The settled `.import` files (mode 3, mipmaps on) come from T2's Godot import. Art runs no Godot.

**Mapping.** `v_pos` is the object-space `VERTEX` after displacement. Both meshes have their origin on the inner floor, so `v_pos.y` is the height above the floor. Side and liner use UV0.x, the lathe angle, which has no derivative seam. Godot v grows down the image, so the minus signs keep image-up = world-up, as in the reference renders.

```glsl
// Mirror art/textures/make_starter_masks.py.
const float SIDE_REPEATS  = 4.0;
const float SIDE_TILE_M   = 0.059690;   // 2 pi 0.038 / 4, square texels
const float TOP_TILE_M    = 0.048;
const float TOP_ROT       = 0.6;        // radians, hides the axis-aligned repeat on the cap
const float LINER_REPEATS = 2.0;
const float LINER_SPAN_M  = 0.060240;
const float LINER_EDGE_V  = 0.10;       // the peak line in the liner mask
const float GROW_RAMP     = 0.08;       // a feature grows in over this much density
const float SIZE_MIN      = 0.12;       // bubble_size 0 still shows features at 12% scale
const float STRETCH_K     = 0.35;       // vertical stretch at full `stretch` (web strands, §5)
const float TAP           = 1.5 / 512.0;
const vec2  LIGHT_UV      = vec2(-0.35, 0.94);   // key light in mask space: left and image-up

// Starter_Body, side and rim. stretch = bubble_size * smoothstep(1.5, 2.3, rise) (§5).
vec2 uv_side = vec2(UV.x * SIDE_REPEATS,
                    -v_pos.y / (SIDE_TILE_M * (1.0 + STRETCH_K * stretch)));
// Starter_Body, cap: planar on object XZ, rotated.
float c = cos(TOP_ROT), s = sin(TOP_ROT);
vec2 uv_top = vec2(v_pos.x * c + v_pos.z * s, v_pos.z * c - v_pos.x * s) / TOP_TILE_M;
// Starter_Liner: anchored to the peak line, not to UV.y.
float peak_h = peak_line * level_m;
vec2 uv_liner = vec2(UV.x * LINER_REPEATS + 0.5,
                     clamp(LINER_EDGE_V + (peak_h - v_pos.y) / LINER_SPAN_M, 0.004, 0.996));
// Side vs cap blend: n_obj = object-space normal of the displaced surface.
float top_w = smoothstep(0.55, 0.85, n_obj.y);
```

The cap's UV0 is the disc atlas, so `uv_side` is garbage there, but `top_w` is 1 on the cap, so it never shows.

### 16.4 The feature function and bubble depth

```glsl
// m.r = F, m.a = P. Returns (air, depth 0 at the outline to 1 at the center, lip).
vec3 feature(vec4 m, float density, float size) {
	float grow  = smoothstep(m.a, m.a + GROW_RAMP, density);
	float frac  = (SIZE_MIN + (1.0 - SIZE_MIN) * size) * grow;
	if (frac < 0.002) return vec3(0.0);
	float thr   = 1.0 - frac;
	float aa    = min(max(fwidth(m.r), 0.01), frac * 0.5);
	float air   = smoothstep(thr - aa, thr + aa, m.r);
	float depth = clamp((m.r - thr) / frac, 0.0, 1.0);
	float lip   = smoothstep(thr - 0.35 * frac, thr, m.r) * (1.0 - air);
	return vec3(air, depth, lip);
}

// Side: bigger bubbles higher up, then the cavity light from two extra taps.
vec4  ms    = texture(side_mask, uv_side);
float hfrac = clamp(v_pos.y / max(u_level, 0.001), 0.0, 1.0);
vec3  fs    = feature(ms, bubble_density, clamp(bubble_size * (0.85 + 0.3 * hfrac), 0.0, 1.0));
float gx    = texture(side_mask, uv_side + vec2(TAP, 0.0)).r - ms.r;
float gy    = texture(side_mask, uv_side - vec2(0.0, TAP)).r - ms.r;   // toward image-up
float facing = dot(vec2(gx, gy), LIGHT_UV) / max(length(vec2(gx, gy)), 1e-4);
float cav_s = (0.82 + 0.22 * facing * (1.0 - fs.y * fs.y))   // dark under the top lip, lit lower wall
            * (1.0 - 0.72 * fs.x * (1.0 - fs.x));             // thin contact line at the outline

// Cap: fewer, smaller open pits than at the glass; pinholes darkest at the center.
vec4  mt    = texture(top_mask, uv_top);
vec3  ft    = feature(mt, bubble_density * 0.9, bubble_size * 0.8);
float cav_t = 0.86 - 0.28 * ft.y;

float air = mix(fs.x, ft.x, top_w) * (1.0 - in_hooch);
float dep = mix(fs.y, ft.y, top_w);
float cav = mix(cav_s, cav_t, top_w);
```

**How bubble depth reads through the glass.** Depth comes from four cues, all in the reference:
1. **Pocket albedo:** `albedo = mix(albedo, pocket_color, air * (0.55 + 0.35 * dep))` with pocket `#D3BF9E`. A little darker and warmer, never brown. For whole wheat and rye, scale the pocket by the flour tint ratio.
2. **Cavity light:** `albedo *= mix(1.0, cav, air)`. The top inner wall sits in the shadow of the paste above it, and the lower wall catches the key. This is what makes a hole read as a hole and not a stain. It is baked, so it works on Tier A.
3. **Wet glint:** pocket `ROUGHNESS` 0.18, so the key leaves a small highlight on the lower wall. Optional on Tier B: tilt the normal toward the pocket center, `n += (tan_u * g.x + up * g.y) * 0.6 * air * (1.0 - dep)` with `g = normalize(vec2(gx, gy))`, so the glint lands in the right place when the camera orbits.
4. **No translucency inside a pocket:** it is air. Multiply the backlight and rim terms by `1.0 - 0.75 * air`.

**Craters on the cap:** add `0.25 * ft.z` (the lip) to the cap height for a soft raised rim, Tier B only. Optional blisters: features with P just above density (`density < P < density + 0.15`) can show as faint raised domes before they open. That is a nice tell for the rise, but not required for sign-off.

**Motion (Phase 3):** `grow` already fades features in as density rises, so new bubbles grow from a point instead of popping. For the §8 bubble life, breathe each one with `size *= 0.92 + 0.08 * sin(TIME * 0.9 + m.a * 40.0)`, since P is constant per bubble.

### 16.5 The look in Godot terms

**a. Albedo per state.** The paste never changes hue by state. State shows through bubbles, cap texture, hooch and residue. Flour tint per §2.1, times a tone of 0.96 to 1.02 from fine noise and a low-frequency mottle (any noise T2 already has).

| State | Paste and pockets | Cap extras | Liner residue | Cap `ROUGHNESS` |
|---|---|---|---|---|
| `freshly_fed` | Flour tint; few tiny pockets | Lumps, satin | none | 0.44 |
| `developing` | Small pockets | | none | 0.41 |
| `active` | Many small and medium | | none | 0.38 |
| `near_peak` | Bigger toward the top | | none | 0.36 |
| `at_peak` | Big, stretched | | none | 0.35 |
| `collapsing` | Big, fewer | Sunken, more open craters | Fresh cream ring, film and drips (age about 0.15) | 0.33 |
| `hungry` | Few, big | Hooch `#8A7860` band | Dried flecks (age about 0.55) | 0.33 |
| `dormant` | Very few | Hooch `#8A7860` | As stored | 0.40 |
| `recovering` | Like `developing` | | As stored | 0.41 |
| `unhealthy` | Almost none | Crust `#CDBB98` at 0.85 dryness, crackle, dark hooch `#5A5045` | Aged (1.0), crust color | 0.76 (dry) |
| `moldy` | None | As `unhealthy`, plus §6 colonies | Aged, plus glass colonies | 0.76 |

`ROUGHNESS` on the cap = `mix(0.55, 0.24, sheen)`, then `mix(r, 0.18, air)`, `mix(r, 0.8, dryness)` and `mix(r, 0.04, in_hooch)`.

**b. Fake translucency.** Keep the built-in lighting and add Godot's `BACKLIGHT`. It adds light where N·L is low, which is the cream-glow-into-shadow look.
- `BACKLIGHT = scatter_color * backlight_k * (1.0 - 0.75 * air) * (1.0 - in_hooch) * (1.0 - dryness)`.
- `scatter_color` = `#E3BF8F` (hue 34, warm cream). Start `backlight_k` at 0.35 and tune it until the shadow-side row passes (§16.6). If it is too weak, the shadow goes gray and flat. If it is too strong, the jar looks lit from inside.
- `RIM` 0.10 with `RIM_TINT` 0.5, times the same `(1.0 - 0.75 * air)`. It reads as thin-edge translucency where the paste meets the glass.
- Fallback, only if `BACKLIGHT` can't reach the row on one renderer: a custom `light()` with wrap 0.35, `max(0, (N·L + 0.35) / 1.35)`, plus `scatter_color` x 0.15 in the terminator band (N·L from -0.35 to 0.6). It replaces Godot's specular, so add GGX back. Check whether 4.7.2 multiplies `DIFFUSE_LIGHT` by `ALBEDO` after `light()`: the 4.x docs example leaves `ALBEDO` out.
- **Not allowed:** a per-renderer change to the palette hexes. **Allowed:** a per-renderer grade (starter color, `backlight_k`) set by the quality-tier switch, as long as both renderers hit the same rows.

**c. Glossy domed skin.**
- Cap: the `ROUGHNESS` above, `SPECULAR` 0.5, and `CLEARCOAT = sheen * mix(0.25, 0.6, top_w) * (1.0 - dryness)` with `CLEARCOAT_ROUGHNESS` 0.08. Where a renderer has no clearcoat, drop it and lower the cap `ROUGHNESS` by 0.06.
- Per-pixel cap normal from the displaced height (the spike's central differences are right), including lumps.
- The dome reads when, at the preview pose, `at_peak` shows a soft key highlight on the front-left of the cap, the far edge of the cap at least 6 value points darker than its center, and a convex silhouette. All three come from gloss and normals, not from more displacement. Keep `DOME_MAX_M` (§5).
- The side behind the glass touches the glass, so it gets little specular of its own. Its gloss lives in the pockets.

**d. Hooch:** as in §5. Its `ROUGHNESS` is 0.04, with no backlight.

**e. Liner residue** (`M_Starter_Liner`, the mapping in §16.3):

```glsl
vec4  ml    = texture(liner_mask, uv_liner);
float age   = clamp(max(surface_dryness, 1.4 * (peak_line - rise) / max(peak_line, 0.01) - 0.1), 0.0, 1.0);
float thr   = 1.0 - streak_amount;
float vis   = smoothstep(thr - 0.02, thr + 0.02, ml.r)
            * smoothstep(0.55 * age, 0.55 * age + 0.04, ml.a);
float above = smoothstep(u_level + 0.0003, u_level + 0.0018, v_pos.y);   // never over the paste
float thick = clamp((ml.r - thr) / 0.5, 0.0, 1.0);
ALPHA     = vis * above * (0.30 + 0.62 * thick) * (1.0 - 0.25 * age) * step(0.001, streak_amount);
ALBEDO    = mix(starter_color, crust_color, age);    // #CDBB98
ROUGHNESS = mix(0.22, 0.8, age);
```

`age` is derived, with no new field (§5 "residue aging"). It gives about 0.15 for `collapsing`, 0.55 for `hungry` and 0.85 for `unhealthy`. Keep the §4 alpha scissor with dither. The liner sits 0.35 mm outside the paste, so `above` is what keeps residue off the paste.

**f. Tier A vs Tier B:** the same masks, albedo, cavity light, `BACKLIGHT` and gloss. Tier B adds only the optional pocket normal tilt and the crater lip. Cost: 5 texture fetches on the starter (side 3, cap 2), 1 on the liner.

### 16.6 Sign-off: the rows each part must hit, in both renderers

Measure as in §3: 31 px patch means, sRGB 8-bit, HSV. Captures at the §7 pose and the §16.2 close-ups, for Mobile Tier B, Mobile Tier A and Compatibility Tier A. "Pockets" use the §16.1 split. Reference values are in brackets.

| Part | Capture | Row | Target [reference] |
|---|---|---|---|
| Paste, lit | Pose (290, 850), every state | §3 rows 1 and 3 | V 81 to 93%, S 8 to 16%, hue 30 to 40, max channel 0.92 or less [`#DACFBF`, V 85%, S 12%] |
| Paste, shadow side | Pose (450, 830) | §3 row 2 | V 50 to 62%, S 45% or less [`#816B4C`, V 51%, S 41%] |
| Bubble pockets | Side close-up, `active` and `at_peak` | R7 (new) | Pocket mean V 66 to 76%, S 18 to 30%, hue 30 to 40. Darkest 5% V 58% or more [V 71 to 73%, S 20 to 24%; darkest V 63%] |
| Pocket share | Side close-up | R8 (new) | `active` 8 to 16% of paste pixels, `at_peak` 12 to 22% [12%, 17%]. Bubbles irregular and clustered, not a grid of round holes |
| Cap | Top close-up, cap center | R9 (new) | V 84 to 92%, S 7 to 14% [`#E9E1D5`, V 91%, S 9%] |
| Hooch from above | Top close-up, `hungry` | R10 (new) | V 55 to 70%, S 25 to 40%, hue 30 to 40 [`#A28B69`, V 64%, S 35%] |
| Residue | Side close-up, `collapsing`, glass above the surface | R11 (new) | Cream to near-white, S 15% or less [20th to 80th percentile `#D4CAB9` to `#EAE5DE`]. A lacy film with a ring at the top, not a hard ragged band |
| Everywhere | Every capture | §2.3 | Nothing under hue 25 at S over 50% (orange is reserved for mold) |

I sign off when every row passes in all three captures and the board's tells (§16.2) read side by side. The director then shows the user, as D-037 requires.

**Review, 2026-11-26** (T2 work merged in 6aa85c1, `captures/view/`, 99 frames; 153 of 156 rows pass). **Not signed off yet on any renderer.** Bubbles, pockets, cap color, hooch and residue match the board on all three captures.

| Renderer | Verdict | Fixes before re-check |
|---|---|---|
| Mobile Tier B | Not yet | Fix 1 |
| Mobile Tier A | Not yet | Fix 1. Its R7 pocket S of 17.95% counts as a pass (rounding) |
| Compatibility Tier A | Not yet | Fixes 1 and 2, then re-measure R7 and R8 on `active` |

- **Fix 1, pointed cap** (`src/view/shaders/starter_common.gdshaderinc`, `cap_offset()`). The cap term in `starter.gdshader` is correct (`1 - UV2.x²`). The point comes from the lump term:
  - `fbm3` spans about 0 to 1, which is wider than the Blender noise the board uses, and a lump near the center shows as a corner at grazing angles. A Blender render without depth of field confirms the board's arc stays round at the same height.
  - Change it to `float lump = lumps * LUMPS_MAX_M * (fbm3(xz * 70.0) - 0.5) * 0.5 * smoothstep(0.0, 0.3, length(xz) / starter_r);`.
  - Target: in the `at_peak` §16.2 side close-up, the cap's top edge is a smooth arc with no corner. To confirm the cause first, capture once with `lumps` = 0.
- **Fix 2, clipped glass stripe on Compatibility** (`glass_common.gdshaderinc`, `spec_strength`, now 5.0 on both renderers). Make it a `ViewLook` field. Set it to about 1.5 for Compatibility, where Filmic clips what AgX rolls off, and keep 5.0 on Mobile.
  - Target: under 0.5% of pixels at max channel 0.99 or above in the `at_peak` side close-up (now 11.5%), and under 0.1% in the pose (now 1.3%; the board has 0.07%).
- **Minor, not blocking:** from the top view, the glass walls read gray. Lower `reflection_strength` on the inner pass, or lighten what the sky shows below the horizon.
- **Rulings on T2's deviations:**
  - **Shadow maps off on both renderers, with the counter shader drawing the drop shadow: accepted.** The drop shadow must follow the key direction. The lid shadow offset is a known gap to fix.
  - **Masks VRAM Uncompressed: accepted** (§16.3).
  - **Directional rim light: accepted** (§3).
  - **Home yaw:** reference captures and sign-off stay at yaw 0 (§7). The in-game home pose may use ux-designer's slight 3/4 angle. I propose -12 degrees, which moves the camera toward the key side so more of the lit cream faces the player. The baked backdrop card covers about ±15 degrees of yaw. Past that, the kitchen sky shows (§10).
  - **Also accepted:** key light direction and color (§3), backlight_k 0.15 instead of 0.35, Filmic plus a grade on Compatibility, band `#7A9271` (§2.1), pale dried residue.

## 17. Kitchen set textures (for T2)

Generator: `/Applications/Blender.app/Contents/MacOS/Blender -b -P art/blender/scripts/bake_kitchen_set.py` (about 30 s on an M4, seeded). It also writes `art/previews/kitchen_set_check.png`: the §7 pose at `at_peak` with these textures, the wall unshaded, no depth of field, which is how Godot draws it on a phone.

| File | Size | Format | What it is | Import |
|---|---|---|---|---|
| `assets/textures/kitchen_backdrop.png` | 1024 x 512 | RGB, color (`source_color`) | The sage zellige wall under the afternoon lights. It is stored as scene-linear radiance with the sRGB curve and no tonemap, blurred by the §7 lens (sigma 8 mm on the wall, from a 21 mm circle of confusion) | VRAM Compressed, mipmaps off (it is always magnified). About 0.5 MB |
| `assets/textures/counter_oak_detail.png` | 512 x 512 | Gray, data | Butcher-block strips (9 per tile, about 40 mm), latewood lines, pores, glue lines, a few end joints. Tiles; strips run along u. Tile = 0.36 m | Mipmaps on. 0.35 MB |
| `assets/textures/lid_oak_detail.png` | 256 x 256 | Gray, data | Oak growth rings (26 per tile) with one cathedral arch, plus pores. Tiles; grain runs along u. Tile = 64 mm | Mipmaps on. 0.09 MB |

**Check render against the original preview** (31 px patches, §3 rows):

| Patch | Original preview | Check render with these textures |
|---|---|---|
| Tile wall (360, 150) | `#A7A183` | `#A49F80` (H 52, S 22%, V 64%) |
| Counter (600, 1150) | `#E3D7C9` | `#E6D9CC` (S 11%) |
| Lid top (330, 350) | `#C9AE91` | `#CEB498` (S 26%) |

**What T2 changes.** Node names and UVs stay as in §12. Only the three materials change.

1. **`Backdrop_placeholder`, `M_Backdrop` slot, `backdrop.gdshader`.**
   - Replace the procedural tiles and the `shade` falloff with the image. The light is baked, so drop the falloff.
   - The card's UV0 maps the image 1:1, and row 0 of the PNG is the top of the wall.
   - Keep `unshaded` and `tod_tint`.
   - Start `ViewLook.backdrop_energy` at 1.0 and tune each renderer to the §3 tile row. Cycles with the texture as emission strength 1.0 under AgX gives `#A49F80`.
   ```glsl
   uniform sampler2D wall_tex : source_color, filter_linear, repeat_disable;
   ALBEDO = texture(wall_tex, UV).rgb * tod_tint * energy;
   ```
2. **`Counter`, `M_Counter_Wood`, `counter.gdshader`.**
   - Replace the plank function with the map, and keep the measured `oak_light` and `oak_dark`, the contact shadow and the drop shadow.
   - The strips run left to right along world x.
   ```glsl
   uniform sampler2D oak_detail : filter_linear_mipmap, repeat_enable;
   float d = texture(oak_detail, v_world.xz / 0.36).r;
   vec3 oak = mix(oak_dark, oak_light, d);
   ROUGHNESS = mix(0.62, 0.42, d);
   ```
3. **`Jar_Lid_Loose`, `M_Lid_Wood`, `lid_wood.gdshader`.**
   - Triplanar in object space, so the grain runs around the side (horizontal rings) and shows the cathedral arch on top.
   - Pass the object-space `VERTEX` and `NORMAL` as varyings.
   ```glsl
   uniform sampler2D grain : filter_linear_mipmap, repeat_enable;
   vec3 w = pow(abs(v_nrm), vec3(4.0));
   w /= w.x + w.y + w.z;
   float d = texture(grain, v_pos.zy / 0.064).r * w.x    // sides facing +-X
           + texture(grain, v_pos.xz / 0.064).r * w.y    // top
           + texture(grain, v_pos.xy / 0.064).r * w.z;   // sides facing +-Z
   vec3 oak = mix(oak_dark, oak_light, d);
   ROUGHNESS = mix(0.6, 0.4, d);
   ```

Total texture memory for the set is about 0.95 MB, inside the §13 budget. Time of day stays a tint on the wall (§3): the bake is the afternoon preset.
