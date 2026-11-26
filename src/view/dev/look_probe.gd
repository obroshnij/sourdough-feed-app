extends SceneTree
## Dev only. Measures captures against art-direction.md §3 "Reference look" and the §16.6 rows.
## 31 px patch means, sRGB 8-bit, HSV, like the art director's numbers.
##   Godot --headless --path . -s res://src/view/dev/look_probe.gd -- <png> [<png> ...]
## The view comes from the file name: *_pose.png or jar_v0_*.png (720 x 1280, §7 pose),
## *_side.png and *_top.png (640 x 800, §16.2 close-ups). Prints one ROW line per check, with
## PASS or FAIL, then a SUMMARY line.

const HALF: int = 15

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	for path: String in OS.get_cmdline_user_args():
		var img: Image = Image.load_from_file(path)
		if img == null:
			print("PROBE could not load %s" % path)
			continue
		img.convert(Image.FORMAT_RGB8)
		var file: String = path.get_file()
		var state: String = _state_of(file)
		print("PROBE %s (%dx%d) state=%s" % [file, img.get_width(), img.get_height(), state])
		if file.ends_with("_side.png"):
			_side(img, state)
		elif file.ends_with("_top.png"):
			_top(img, state)
		else:
			_pose(img, state)
		_no_orange(img)
		_clipped(img)
	print("SUMMARY %d pass, %d fail" % [passed, failed])
	quit()


func _state_of(file: String) -> String:
	for s: String in ["freshly_fed", "developing", "active", "near_peak", "at_peak", "collapsing",
			"hungry", "dormant", "recovering", "unhealthy", "moldy"]:
		if file.contains(s):
			return s
	return ""


## The §3 pixels are fixed for the at_peak preview. Other states put the paste elsewhere in
## frame, so their paste rows are printed for information only.
func _pose(img: Image, state: String) -> void:
	if state != "at_peak" and state != "":
		print("ROW info paste (290,850) %s, (450,830) %s" % [_fmt(_patch(img, Vector2i(290, 850))), _fmt(_patch(img, Vector2i(450, 830)))])
		return
	var lit: Color = _patch(img, Vector2i(290, 850))
	_row("paste lit (290,850)", lit, lit.v >= 0.81 and lit.v <= 0.93 and lit.s >= 0.08 and lit.s <= 0.16
			and _hue_in(lit, 30.0, 40.0) and _max_ch(lit) <= 0.92, "V 81-93, S 8-16, hue 30-40, max <= 0.92")
	var shade: Color = _patch(img, Vector2i(450, 830))
	_row("paste shadow (450,830)", shade, shade.v >= 0.50 and shade.v <= 0.62 and shade.s <= 0.45,
			"V 50-62, S <= 45")
	var counter: Color = _patch(img, Vector2i(600, 1150))
	_row("counter (600,1150)", counter, counter.s <= 0.15 and _max_ch(counter) < 0.99, "S <= 15, not clipped")
	var tile: Color = _patch(img, Vector2i(360, 150))
	_row("tile wall (360,150)", tile, _hue_in(tile, 45.0, 70.0), "hue 45-70")
	var lid: Color = _patch(img, Vector2i(330, 350))
	_row("lid top (330,350)", lid, lid.s <= 0.35, "S <= 35")


func _top(img: Image, state: String) -> void:
	var c: Color = _patch(img, Vector2i(320, 400))
	if state == "unhealthy" or state == "moldy":
		print("ROW info cap center %s (crust or dark hooch, no R9 row)" % _fmt(c))
		return
	if state == "hungry" or state == "dormant":
		_row("R10 hooch from above", c, c.v >= 0.55 and c.v <= 0.70 and c.s >= 0.25 and c.s <= 0.40
				and _hue_in(c, 30.0, 40.0), "V 55-70, S 25-40, hue 30-40")
	else:
		_row("R9 cap center", c, c.v >= 0.84 and c.v <= 0.92 and c.s >= 0.07 and c.s <= 0.14,
				"V 84-92, S 7-14")


## Paste rows of the side close-up: rows where at least 85% of the samples look like paste
## (warm hue, not green band, not glass over the backdrop). The bottom glass base is skipped.
func _side(img: Image, state: String) -> void:
	var vals: Array[float] = []
	var cols: Array[Color] = []
	# Rows that are mostly band (green), so rows next to them can be skipped.
	var band_rows: Array[int] = []
	for y: int in range(0, img.get_height(), 2):
		var green: int = 0
		for x: int in range(60, 580, 8):
			var gc: Color = img.get_pixel(x, y)
			if gc.s > 0.08 and gc.h * 360.0 > 70.0 and gc.h * 360.0 < 170.0:
				green += 1
		if green > 30:
			band_rows.append(y)
	for y: int in range(40, 720, 2):
		var near_band: bool = false
		for by: int in band_rows:
			if absi(by - y) <= 8:
				near_band = true
				break
		if near_band:
			continue
		var row: Array[Color] = []
		var pasty: int = 0
		for x: int in range(60, 580, 2):
			var c: Color = img.get_pixel(x, y)
			row.append(c)
			var h: float = c.h * 360.0
			if c.v > 0.45 and c.s < 0.4 and (c.s < 0.05 or (h >= 22.0 and h <= 50.0)):
				pasty += 1
		if float(pasty) < 0.85 * float(row.size()):
			continue
		for c: Color in row:
			vals.append(c.v)
			cols.append(c)
	if vals.size() < 100:
		print("ROW side: too few paste pixels (%d)" % vals.size())
		return
	var sorted: Array[float] = vals.duplicate()
	sorted.sort()
	var p80: float = sorted[int(sorted.size() * 0.8)]
	var pocket_sum := Color(0, 0, 0)
	var paste_sum := Color(0, 0, 0)
	var pockets: Array[float] = []
	var n_paste: int = 0
	for i: int in cols.size():
		if vals[i] < p80 - 0.10:
			pocket_sum += cols[i]
			pockets.append(vals[i])
		else:
			paste_sum += cols[i]
			n_paste += 1
	var share: float = float(pockets.size()) / float(cols.size())
	var paste: Color = paste_sum / maxf(float(n_paste), 1.0)
	print("ROW side paste mean %s" % _fmt(paste))
	if pockets.is_empty():
		print("ROW side: no pockets")
		if state == "active" or state == "at_peak":
			failed += 1
		return
	pockets.sort()
	var pocket: Color = pocket_sum / float(pockets.size())
	var darkest: float = pockets[int(pockets.size() * 0.05)]
	if state == "active" or state == "at_peak":
		_row("R7 pocket mean", pocket, pocket.v >= 0.66 and pocket.v <= 0.76 and pocket.s >= 0.18 and pocket.s <= 0.30
				and _hue_in(pocket, 30.0, 40.0) and darkest >= 0.58, "V 66-76, S 18-30, hue 30-40, darkest5 >= 58 (got %.0f)" % (darkest * 100.0))
		var lo: float = 0.08 if state == "active" else 0.12
		var hi: float = 0.16 if state == "active" else 0.22
		var ok: bool = share >= lo and share <= hi
		print("ROW R8 pocket share %.1f%% [%s] want %.0f-%.0f%%" % [share * 100.0, "PASS" if ok else "FAIL", lo * 100.0, hi * 100.0])
		if ok:
			passed += 1
		else:
			failed += 1
	else:
		print("ROW pockets %s share %.1f%% darkest5 V %.0f" % [_fmt(pocket), share * 100.0, darkest * 100.0])
	if state == "collapsing":
		_residue(img)


## R11: residue on the glass above the surface, top band of the side close-up.
func _residue(img: Image) -> void:
	var vals: Array[float] = []
	var sats: Array[float] = []
	for y: int in range(20, 200, 2):
		for x: int in range(100, 540, 2):
			var c: Color = img.get_pixel(x, y)
			if c.v > 0.72 and c.s < 0.3:
				vals.append(c.v)
				sats.append(c.s)
	if vals.size() < 50:
		print("ROW R11 residue: too few light pixels (%d)" % vals.size())
		return
	sats.sort()
	vals.sort()
	var s80: float = sats[int(sats.size() * 0.8)]
	var ok: bool = s80 <= 0.15
	print("ROW R11 residue light pixels=%d V p20-p80 %.0f-%.0f S p80 %.0f [%s] want S <= 15" % [
		vals.size(), vals[int(vals.size() * 0.2)] * 100.0, vals[int(vals.size() * 0.8)] * 100.0, s80 * 100.0,
		"PASS" if ok else "FAIL"])
	if ok:
		passed += 1
	else:
		failed += 1


## §3 "nothing clips": share of pixels with a channel at 254 or more (the board pose: 0.07%).
func _clipped(img: Image) -> void:
	var clip: int = 0
	var n: int = 0
	for y: int in range(0, img.get_height(), 2):
		for x: int in range(0, img.get_width(), 2):
			var c: Color = img.get_pixel(x, y)
			n += 1
			if maxf(c.r, maxf(c.g, c.b)) >= 254.0 / 255.0:
				clip += 1
	print("ROW clipped %.2f%% of pixels" % (100.0 * float(clip) / float(maxi(n, 1))))


## §2.3: nothing under hue 25 at saturation over 50% (orange is reserved for mold).
func _no_orange(img: Image) -> void:
	var bad: int = 0
	for y: int in range(0, img.get_height(), 2):
		for x: int in range(0, img.get_width(), 2):
			var c: Color = img.get_pixel(x, y)
			var h: float = c.h * 360.0
			if c.s > 0.5 and c.v > 0.15 and (h < 25.0 or h > 340.0):
				if bad == 0:
					print("ROW first orange pixel at (%d, %d) %s" % [x, y, _fmt(c)])
				bad += 1
	var ok: bool = bad == 0
	print("ROW no orange: %d sampled pixels under hue 25 at S > 50%% [%s]" % [bad, "PASS" if ok else "FAIL"])
	if ok:
		passed += 1
	else:
		failed += 1


func _row(label: String, c: Color, ok: bool, want: String) -> void:
	print("ROW %s %s [%s] want %s" % [label, _fmt(c), "PASS" if ok else "FAIL", want])
	if ok:
		passed += 1
	else:
		failed += 1


func _fmt(c: Color) -> String:
	return "#%s H %.0f S %.0f%% V %.0f%%" % [c.to_html(false).to_upper(), c.h * 360.0, c.s * 100.0, c.v * 100.0]


func _hue_in(c: Color, lo: float, hi: float) -> bool:
	var h: float = c.h * 360.0
	return h >= lo and h <= hi


func _max_ch(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b))


func _patch(img: Image, center: Vector2i) -> Color:
	var sum := Color(0, 0, 0, 0)
	var n: int = 0
	for y: int in range(-HALF, HALF + 1):
		for x: int in range(-HALF, HALF + 1):
			var p: Vector2i = center + Vector2i(x, y)
			if p.x < 0 or p.y < 0 or p.x >= img.get_width() or p.y >= img.get_height():
				continue
			sum += img.get_pixelv(p)
			n += 1
	return sum / float(maxi(n, 1))
