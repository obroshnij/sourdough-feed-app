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
## FL8: hooch-from-above V per flour (hungry, top views).
var _hooch_v: Dictionary[String, float] = {}


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
		if file.contains("_place_") and file.ends_with("_pose.png") and not file.contains("magenta"):
			_place(img, file, state)
		elif file.contains("_flour_"):
			_flour(img, file, state)
		elif file.contains("_focus_"):
			print("ROW info inspect framing capture, no rows")
		elif file.contains("magenta"):
			_magenta(img)
		elif file.contains("_orbit"):
			if file.contains("night") and (file.contains("_y-70_") or file.contains("_y70_")):
				_n4(img, 110 if file.contains("_p35_") else 260)
		elif file.ends_with("_side.png"):
			_side(img, state)
			if state == "hungry" or state == "unhealthy":
				_r13(img)
		elif file.ends_with("_top.png"):
			_top(img, state)
		elif file.contains("night"):
			_night_pose(img, state)
		else:
			_pose(img, state)
		_no_orange(img)
		_clipped(img)
	if _hooch_v.has("rye") and _hooch_v.has("white_bread"):
		var dv: float = absf(_hooch_v["rye"] - _hooch_v["white_bread"])
		var ok8: bool = dv <= 0.03
		print("ROW FL8 hooch rye vs white within %.1f V points [%s] want <= 3" % [dv * 100.0, "PASS" if ok8 else "FAIL"])
		if ok8:
			passed += 1
		else:
			failed += 1
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
	if state == "unhealthy":
		_row("R12 dark hooch from above", c, c.v >= 0.46 and c.v <= 0.60 and c.s >= 0.28 and c.s <= 0.45
				and _hue_in(c, 28.0, 40.0), "V 46-60, S 28-45, hue 28-40")
		return
	if state == "moldy":
		print("ROW info cap center %s (colonies and crust, no R9 row)" % _fmt(c))
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


## R13: old residue never reads as dirt: dark specks on the glass above the surface, 0.2% or less.
func _r13(img: Image) -> void:
	var dark: int = 0
	var n: int = 0
	for y: int in range(20, 150, 2):
		for x: int in range(60, 580, 2):
			n += 1
			if img.get_pixel(x, y).v < 0.40:
				dark += 1
	var share: float = float(dark) / float(maxi(n, 1))
	var ok: bool = share <= 0.002
	print("ROW R13 dark specks above the surface %.3f%% [%s] want <= 0.2%%" % [share * 100.0, "PASS" if ok else "FAIL"])
	if ok:
		passed += 1
	else:
		failed += 1


## Night rows N1 to N3 at the §7 pose (art-direction.md §18.6). N5 is the no-orange check.
func _night_pose(img: Image, state: String, place: bool = false) -> void:
	if state != "at_peak":
		return
	var lit: Color = _patch(img, Vector2i(290, 850))
	_row("N1 night paste lit", lit, lit.v >= 0.72 and lit.v <= 0.88 and lit.s <= 0.27 and _hue_in(lit, 30.0, 40.0)
			and _max_ch(lit) <= 0.92, "V 72-88, S <= 27 (art's tolerance), hue 30-40, max <= 0.92")
	var shade: Color = _patch(img, Vector2i(450, 830))
	_row("N2 night paste shadow", shade, shade.v >= 0.40, "V >= 40")
	_n7(img)
	if place:
		return
	var counter: Color = _patch(img, Vector2i(600, 1150))
	var clip: float = _clip_share(img, 252.0 / 255.0)
	_row("N6 night counter, clip %.2f%%" % (clip * 100.0), counter, counter.v >= 0.55 and counter.v <= 0.75 and clip < 0.005,
			"counter V 55-75, clipped < 0.5%")
	var wall: Color = _patch(img, Vector2i(360, 150))
	_row("N3 night wall behind the jar", wall, wall.v >= 0.25 and wall.v <= 0.45 and _hue_in(wall, 30.0, 60.0)
			and wall.s <= 0.45, "V 25-45, hue 30-60, S <= 45")


## N7: at night the pockets still read as cream cavities, not a dark sponge (x 240-480, y 800-990).
func _n7(img: Image) -> void:
	var vals: Array[float] = []
	for y: int in range(800, 990, 2):
		for x: int in range(240, 480, 2):
			var c: Color = img.get_pixel(x, y)
			# Paste pixels only (§16.1): skip the sage rubber band that crosses the patch.
			if c.s > 0.08 and c.h * 360.0 > 70.0 and c.h * 360.0 < 170.0:
				continue
			vals.append(c.v)
	vals.sort()
	var p80: float = vals[int(vals.size() * 0.8)]
	var pockets: Array[float] = []
	var sum: float = 0.0
	for v: float in vals:
		if v < p80 - 0.10:
			pockets.append(v)
			sum += v
	if pockets.is_empty():
		print("ROW N7 no pockets in the patch")
		return
	var mean_ratio: float = sum / float(pockets.size()) / maxf(p80, 0.001)
	var darkest: float = pockets[int(pockets.size() * 0.05)]
	var ok: bool = mean_ratio >= 0.68 and darkest >= 0.35
	print("ROW N7 night pockets mean %.2f x p80, darkest5 V %.0f [%s] want >= 0.68 and >= 35" % [mean_ratio, darkest * 100.0, "PASS" if ok else "FAIL"])
	if ok:
		passed += 1
	else:
		failed += 1


func _clip_share(img: Image, thr: float) -> float:
	var n: int = 0
	var c: int = 0
	for y: int in range(0, img.get_height(), 2):
		for x: int in range(0, img.get_width(), 2):
			n += 1
			var px: Color = img.get_pixel(x, y)
			if maxf(px.r, maxf(px.g, px.b)) >= thr:
				c += 1
	return float(c) / float(maxi(n, 1))


## N4: the darkest wall at yaw +-70 at night is never pure black (V 8% or more). Sampled near the
## top of the frame, above the counter line at every pitch.
func _n4(img: Image, row: int) -> void:
	var darkest := Color(1, 1, 1)
	for x: int in range(HALF, img.get_width() - HALF, 40):
		var c: Color = _patch(img, Vector2i(x, row))
		if c.v < darkest.v:
			darkest = c
	_row("N4 darkest wall at night", darkest, darkest.v >= 0.08, "V >= 8")


## §18.4 no-sky check: no magenta between the HUD plate (top 17%) and the action bar (bottom 12.5%).
func _magenta(img: Image) -> void:
	var hits: int = 0
	var y0: int = int(img.get_height() * 0.17)
	var y1: int = int(img.get_height() * 0.875)
	for y: int in range(y0, y1, 2):
		for x: int in range(0, img.get_width(), 2):
			var c: Color = img.get_pixel(x, y)
			if c.s > 0.5 and c.v > 0.3 and c.h * 360.0 > 280.0 and c.h * 360.0 < 330.0:
				hits += 1
	var ok: bool = hits == 0
	print("ROW magenta sky pixels in the free band: %d [%s]" % [hits, "PASS" if ok else "FAIL"])
	if ok:
		passed += 1
	else:
		failed += 1


## Flour looks (art-direction.md §20.5): FL2 to FL5 on the side, FL6 to FL8 on the top, FL9 everywhere.
func _flour(img: Image, file: String, state: String) -> void:
	var flour: String = ""
	for f: String in ["white_bread", "whole_wheat", "rye", "spelt"]:
		if file.contains("_flour_" + f):
			flour = f
	if file.ends_with("_top.png"):
		var c: Color = _patch(img, Vector2i(320, 400))
		if state == "hungry":
			_hooch_v[flour] = c.v
			_row("FL8 R10 %s hooch" % flour, c, c.v >= 0.55 and c.v <= 0.70 and c.s >= 0.25 and c.s <= 0.40, "V 55-70, S 25-40")
		elif flour == "rye" and state == "at_peak":
			var tone: int = 0
			var n: int = 0
			for y: int in range(250, 550, 2):
				for x: int in range(170, 470, 2):
					var px: Color = img.get_pixel(x, y)
					n += 1
					if px.v >= 0.55 and px.v < c.v - 0.06 and _hue_in(px, 28.0, 40.0):
						tone += 1
			print("ROW FL6 rye cap: %.1f%% fissure-tone pixels (V >= 55, hue 28-40, under the paste), cap %s" % [100.0 * tone / maxf(n, 1.0), _fmt(c)])
		else:
			print("ROW info %s %s cap %s" % [flour, state, _fmt(c)])
	elif file.ends_with("_side.png") and state == "at_peak":
		var cols: Array[Color] = []
		for y: int in range(40, 720, 2):
			var row: Array[Color] = []
			var pasty: int = 0
			for x: int in range(60, 580, 2):
				var px: Color = img.get_pixel(x, y)
				row.append(px)
				if px.v > 0.45 and px.s < 0.45 and (px.s < 0.05 or _hue_in(px, 22.0, 50.0)):
					pasty += 1
			if float(pasty) >= 0.85 * float(row.size()):
				cols.append_array(row)
		if cols.size() < 100:
			print("ROW %s side: too few paste pixels" % flour)
			return
		var vs: Array[float] = []
		for px: Color in cols:
			vs.append(px.v)
		vs.sort()
		var p80: float = vs[int(vs.size() * 0.8)]
		var sum := Color(0, 0, 0)
		var n_paste: int = 0
		for px: Color in cols:
			if px.v >= p80 - 0.10:
				sum += px
				n_paste += 1
		var paste: Color = sum / float(maxi(n_paste, 1))
		match flour:
			"whole_wheat":
				_row("FL2 whole_wheat paste", paste, _hue_in(paste, 30.0, 40.0) and paste.s >= 0.14 and paste.s <= 0.26 and paste.v >= 0.74 and paste.v <= 0.88, "hue 30-40, S 14-26, V 74-88")
				var bran: int = 0
				for px: Color in cols:
					if px.v <= paste.v - 0.20 and _hue_in(px, 25.0, 40.0):
						bran += 1
				var share: float = float(bran) / float(cols.size())
				var ok5: bool = share >= 0.005 and share <= 0.03
				print("ROW FL5 bran %.2f%% of paste pixels [%s] want 0.5-3%%" % [share * 100.0, "PASS" if ok5 else "FAIL"])
				if ok5:
					passed += 1
				else:
					failed += 1
			"rye":
				_row("FL3 rye paste", paste, _hue_in(paste, 30.0, 38.0) and paste.s >= 0.16 and paste.s <= 0.30 and paste.v >= 0.66 and paste.v <= 0.82, "hue 30-38, S 16-30, V 66-82")
			"spelt":
				_row("FL4 spelt paste", paste, _hue_in(paste, 33.0, 44.0) and paste.s >= 0.14 and paste.s <= 0.26 and paste.v >= 0.78 and paste.v <= 0.90, "hue 33-44, S 14-26, V 78-90")
			_:
				print("ROW FL1 white paste %s (the §16.6 rows hold)" % _fmt(paste))
	_no_pink(img)


## Places (art-direction.md §19.7): WS1 to WS6 and WS8 at the window, PB1 to PB6 and PB8 in the box.
## WS7 and PB7's sky part are the magenta orbit files; PB7's occlusion is art's ray check.
func _place(img: Image, file: String, state: String) -> void:
	if state != "at_peak":
		return
	var night: bool = file.contains("night")
	var ws: bool = file.contains("window_sill")
	var lit: Color = _patch(img, Vector2i(290, 850))
	var shade: Color = _patch(img, Vector2i(450, 830))
	var top: Color = _patch(img, Vector2i(360, 150))
	var left: Color = _patch(img, Vector2i(120, 520))
	var floor_c: Color = _patch(img, Vector2i(600, 1150))
	var clip: float = _clip_share(img, 252.0 / 255.0)
	if night:
		# N3 and N6 sample the kitchen wall and counter; here those patches are the panes, the box lid
		# and the box door, so WS8 and PB8 replace them. N1, N2 and N7 still apply.
		_night_pose(img, state, true)
		if ws:
			_row("WS8 panes at night", top, top.v >= 0.05 and top.v <= 0.25 and (_hue_in(top, 180.0, 240.0) or top.s <= 0.15), "V 5-25, cool or S <= 15")
		else:
			_row("PB8 box back wall at night", left, left.v >= 0.35 and left.v <= 0.60 and _hue_in(left, 28.0, 40.0) and left.s <= 0.45, "V 35-60, hue 28-40, S <= 45")
		return
	if ws:
		_row("WS1 paste lit", lit, lit.v >= 0.81 and lit.v <= 0.93 and lit.s >= 0.07 and lit.s <= 0.16 and _hue_in(lit, 30.0, 42.0) and _max_ch(lit) <= 0.92, "V 81-93, S 7-16, hue 30-42")
		_row("WS2 paste shadow", shade, shade.v >= 0.50 and shade.v <= 0.66 and shade.s <= 0.45, "V 50-66, S <= 45")
		_row("WS3 window behind", top, top.v >= 0.65 and top.v <= 0.88 and top.s <= 0.14 and _max_ch(top) <= 0.95, "V 65-88, S <= 14, max <= 0.95")
		_row("WS4 curtain", left, left.v >= 0.65 and left.v <= 0.88 and left.s <= 0.14 and _hue_in(left, 30.0, 60.0), "V 65-88, S <= 14, hue 30-60")
		_row("WS5 sill", floor_c, floor_c.v >= 0.82 and floor_c.v <= 0.93 and floor_c.s <= 0.10 and _max_ch(floor_c) < 0.99, "V 82-93, S <= 10")
		_row("WS6 clipped %.2f%%" % (clip * 100.0), lit, clip < 0.005, "< 0.5%")
	else:
		_row("PB1 paste lit", lit, lit.v >= 0.78 and lit.v <= 0.92 and lit.s >= 0.08 and lit.s <= 0.18 and _hue_in(lit, 30.0, 40.0), "V 78-92, S 8-18, hue 30-40")
		_row("PB2 paste shadow", shade, shade.v >= 0.46 and shade.v <= 0.62, "V 46-62")
		var lum_lit: float = 0.2126 * lit.r + 0.7152 * lit.g + 0.0722 * lit.b
		var lum_wall: float = 0.2126 * left.r + 0.7152 * left.g + 0.0722 * left.b
		_row("PB3 box back wall", left, _hue_in(left, 28.0, 40.0) and left.s >= 0.16 and left.s <= 0.28 and lum_wall <= 0.9 * lum_lit and left.s >= lit.s + 0.03, "hue 28-40, S 16-28, 10% darker and 3 S points over PB1")
		_row("PB4 lid inside", top, top.v >= 0.60 and top.v <= 0.85 and _hue_in(top, 28.0, 45.0), "V 60-85, hue 28-45")
		_row("PB5 door", floor_c, floor_c.v >= 0.70 and floor_c.v <= 0.88 and _hue_in(floor_c, 28.0, 40.0) and floor_c.s <= 0.25, "V 70-88, hue 28-40, S <= 25")
		_row("PB6 clipped %.2f%%" % (clip * 100.0), lit, clip < 0.005, "< 0.5%")


## FL9: no pink, nothing at hue 330 to 20 with S over 25%.
func _no_pink(img: Image) -> void:
	var bad: int = 0
	for y: int in range(0, img.get_height(), 2):
		for x: int in range(0, img.get_width(), 2):
			var c: Color = img.get_pixel(x, y)
			var h: float = c.h * 360.0
			if c.s > 0.25 and c.v > 0.15 and (h >= 330.0 or h <= 20.0):
				bad += 1
	var ok: bool = bad == 0
	print("ROW FL9 no pink: %d sampled pixels [%s]" % [bad, "PASS" if ok else "FAIL"])
	if ok:
		passed += 1
	else:
		failed += 1


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
