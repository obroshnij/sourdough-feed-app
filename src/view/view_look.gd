class_name ViewLook
extends RefCounted
## The per-renderer look: Environment, light energies and the starter grade (architecture.md §8.1,
## art-direction.md §3 and §16.5b). T2 owns Compatibility color parity. Both renderers are tuned
## to hit the same "Reference look" rows; the palette hexes never change per renderer, only this grade.
## On Mobile, ambient is set through sky contribution: ambient_light_energy does nothing with a
## sky source at contribution 1.0 (D-037).

var tonemap: Environment.ToneMapper = Environment.TONE_MAPPER_AGX
var exposure: float = 0.9
var white: float = 1.0
## 1.0 = all ambient from the sky. Lower mixes in ambient_color at ambient_energy.
var sky_contribution: float = 1.0
## Kitchen sky brightness: ambient, reflections and the room past the backdrop.
var sky_energy: float = 0.5
var ambient_color: Color = Color(0.95, 0.91, 0.85)
var ambient_energy: float = 0.5
var key_energy: float = 1.6
var key_color: Color = Color("#FFF6EE")     # art #FFEAD6, whitened: AgX here keeps more warmth than Cycles
var rim_energy: float = 0.9
var rim_color: Color = Color(1.0, 0.933, 0.867)     # #FFEEDD
var shadow_blur: float = 1.5
## 1 = the key casts real shadows. Off by default: on Compatibility in 4.7.2 a shadowed
## DirectionalLight3D lights about 5x too hard and clips the scene (T2 measurement). The counter
## shader draws an analytic drop shadow instead, the same on both renderers.
var key_shadow: float = 0.0
## DirectionalLight3D.ShadowMode: 0 orthogonal (1 split), 1 PSSM 2 splits, 2 PSSM 4 splits.
var key_shadow_mode: int = 0
## Starter grade (starter_common.gdshaderinc).
var starter_saturation: float = 1.0
var starter_value: float = 1.0
var backlight_k: float = 0.15
var clearcoat_on: float = 1.0
var pocket_tilt: float = 0.25
var pocket_k: float = 0.75
var cap_spec: float = 0.6
var cap_value: float = 0.86
## Glass key and rim highlight strength (glass_common spec_strength). Compatibility's Filmic
## clipped the softbox stripe to white over the paste (art review of 293b09c).
var glass_spec: float = 5.0
## Glass reflection of the kitchen cubemap (glass_common reflection_strength). Its HDR window
## softbox is what clipped to a white stripe on Compatibility: the highlight alone did not.
var glass_reflection: float = 1.0
var hooch_value: float = 1.0
var hooch_desat: float = 0.0
var backdrop_energy: float = 1.0
## Counter and lid brightness.
var dressing_value: float = 1.0


static func for_renderer(renderer: String) -> ViewLook:
	var look := ViewLook.new()
	if renderer == QualityTier.RENDERER_COMPATIBILITY:
		# 4.7.2 Compatibility has no AgX: AgX renders as linear (measured identical to Linear and
		# to Reinhard at white 1.0). Filmic works there, so Compatibility uses Filmic, graded to
		# hit the same reference rows as Mobile's AgX.
		look.tonemap = Environment.TONE_MAPPER_FILMIC
		look.exposure = 0.7
		look.pocket_k = 0.35
		look.cap_spec = 0.3
		look.cap_value = 0.76
		look.hooch_value = 1.8
		look.hooch_desat = 0.5
		look.clearcoat_on = 0.0
		look.starter_saturation = 0.9
		look.glass_spec = 1.5
		look.glass_reflection = 0.35
	return look


## Dev tuning: --look-<field>=<value> on the command line (dev scrubber only).
func apply_overrides(args: Dictionary) -> void:
	for key: String in args:
		if not key.begins_with("look-"):
			continue
		var field: String = key.trim_prefix("look-").replace("-", "_")
		if not field in self:
			push_warning("ViewLook: no field %s" % field)
			continue
		var current: Variant = get(field)
		var text: String = str(args[key])
		match typeof(current):
			TYPE_FLOAT:
				set(field, float(text))
			TYPE_INT:
				set(field, int(text))
			TYPE_COLOR:
				set(field, Color(text))


func make_environment(sky_material: ShaderMaterial) -> Environment:
	sky_material.set_shader_parameter(&"energy", sky_energy)
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = sky_contribution
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = ambient_energy
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = tonemap
	env.tonemap_exposure = exposure
	env.tonemap_white = white
	return env


func describe() -> String:
	return "tonemap=%d exposure=%.2f white=%.2f sky_energy=%.2f sky_contribution=%.2f ambient=%s@%.2f key=%.2f rim=%.2f starter_sat=%.2f starter_val=%.2f backlight_k=%.2f clearcoat=%.0f" % [
		tonemap, exposure, white, sky_energy, sky_contribution, ambient_color.to_html(false), ambient_energy,
		key_energy, rim_energy, starter_saturation, starter_value, backlight_k, clearcoat_on]
