class_name UiFonts
extends RefCounted
## Font faces (D-029). Figtree for all UI text, Fraunces for the starter's name and journal titles only.
## Both files are variable fonts, so every face sets its axes explicitly: Figtree's default instance is
## Light (wght 300), not Regular.

const FIGTREE_PATH: String = "res://assets/fonts/figtree/Figtree-Variable.ttf"
const FRAUNCES_PATH: String = "res://assets/fonts/fraunces/Fraunces-Variable.ttf"

const WEIGHT_REGULAR: int = 400
const WEIGHT_SEMIBOLD: int = 600
## Fraunces "soft, low wonk" (art-direction §2.2): SOFT 50, WONK off. Godot doesn't set the optical size
## from the font size, and the axis default (9) is the widest cut, so it is pinned to the 20 pt name size.
const FRAUNCES_SOFT: int = 50
const FRAUNCES_OPSZ: int = 20


static func figtree(weight: int) -> FontVariation:
	var base: FontFile = load(FIGTREE_PATH)
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {_tag("weight"): weight}
	return v


static func fraunces(weight: int) -> FontVariation:
	var base: FontFile = load(FRAUNCES_PATH)
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {
		_tag("weight"): weight, _tag("optical_size"): FRAUNCES_OPSZ, _tag("custom_SOFT"): FRAUNCES_SOFT,
		_tag("custom_WONK"): 0,
	}
	return v


static func _tag(axis: String) -> int:
	return TextServerManager.get_primary_interface().name_to_tag(axis)
