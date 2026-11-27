extends CoreCase
## project.godot (architecture.md §13, D-046). It is committed in the exact form Godot 4.7.2 writes, so an
## import or a run leaves no diff. That form drops keys equal to the engine default (stretch mode, the
## mobile renderer override, the OpenGL fallback, inferred_declaration) and every comment, so the intended
## values are pinned here instead. Owner: T1 (who alone edits project.godot; other tracks ask T1).

const EXPECTED: Dictionary = {
	"application/run/main_scene": "res://src/main/main.tscn",
	"application/config/quit_on_go_back": false,
	"autoload/Bus": "*res://src/core/bus.gd",
	"autoload/Session": "*res://src/core/game_session.gd",
	"display/window/handheld/orientation": 1,
	"display/window/size/viewport_width": 390,
	"display/window/size/viewport_height": 844,
	"display/window/stretch/mode": "disabled",
	"display/window/energy_saving/keep_screen_on": false,
	"rendering/renderer/rendering_method": "mobile",
	"rendering/renderer/rendering_method.mobile": "mobile",
	"rendering/rendering_device/fallback_to_opengl3": true,
	"rendering/textures/vram_compression/import_etc2_astc": true,
	"rendering/scaling_3d/scale": 0.75,
	"rendering/anti_aliasing/quality/msaa_3d": 1,
	"debug/gdscript/warnings/untyped_declaration": 2,
	"debug/gdscript/warnings/inferred_declaration": 0,
	"debug/gdscript/warnings/unsafe_property_access": 2,
	"debug/gdscript/warnings/unsafe_method_access": 2,
	"debug/gdscript/warnings/unsafe_cast": 1,
	"debug/gdscript/warnings/unsafe_call_argument": 1,
	"input_devices/pointing/emulate_touch_from_mouse": true,
}


func test_settings_match_architecture_13() -> void:
	if not require(&"p3_contracts"):
		return
	for key: String in EXPECTED:
		check_eq(ProjectSettings.get_setting(key), EXPECTED[key], key)
	var translations: Variant = ProjectSettings.get_setting("internationalization/locale/translations",
		PackedStringArray())
	check(typeof(translations) == TYPE_PACKED_STRING_ARRAY and (translations as PackedStringArray).is_empty(),
		"translations register at runtime (D-039), never in project.godot")
	check(InputMap.has_action(&"dev_overlay"), "the F3 dev_overlay action")


func test_file_is_in_the_form_godot_writes() -> void:
	if not require(&"p3_contracts"):
		return
	var text: String = FileAccess.get_file_as_string("res://project.godot")
	check(not text.contains("Owner:") and not text.contains("git checkout"),
		"no hand-written comments; Godot drops them on save (they live in this test and architecture §14.2)")
	var lines: PackedStringArray = text.split("\n")
	var header_ok: bool = lines.size() > 7 and lines[0] == "; Engine configuration file."
	check(header_ok, "Godot's own header comment")
	for key: String in ["window/stretch/mode", "rendering_method.mobile", "fallback_to_opengl3",
			"inferred_declaration"]:
		check(not text.contains(key + "="), "%s is a default, so Godot's form leaves it out" % key)
