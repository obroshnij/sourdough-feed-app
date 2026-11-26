extends SceneTree
## Samples 9 x 9 px patch averages from screenshots for the tonemap parity check
## (art-direction.md §3): luminance, max channel, saturation and hue.
## Run: Godot --headless --path spikes/jar-spike -s res://scripts/patch_probe.gd -- <png> [<png> ...]
## Patch centers are for the 603 x 1311 at_peak shots at the default pose.

const PATCHES: Dictionary[String, Vector2i] = {
	"starter_front_mid": Vector2i(255, 700),
	"counter_front_right": Vector2i(500, 1050),
	"background_top_center": Vector2i(300, 150),
}


func _initialize() -> void:
	for path: String in OS.get_cmdline_user_args():
		var img: Image = Image.load_from_file(path)
		if img == null:
			print("PATCH could not load %s" % path)
			continue
		var line: String = "PATCH %s" % path.get_file()
		for key: String in PATCHES:
			var c: Color = _avg(img, PATCHES[key])
			var lum: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			line += " | %s lum=%.3f max=%.3f sat=%.3f hue=%.0f" % [key, lum, maxf(c.r, maxf(c.g, c.b)), c.s, c.h * 360.0]
		print(line)
	quit()


func _avg(img: Image, center: Vector2i) -> Color:
	var sum := Color(0, 0, 0, 0)
	for y: int in range(-4, 5):
		for x: int in range(-4, 5):
			sum += img.get_pixelv(center + Vector2i(x, y))
	return sum / 81.0
