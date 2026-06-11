# ui/WorldMapCanvas.gd
# Draws the fantasy campaign world map: ocean, continent, 10 themed biomes with
# landmarks, rivers, coastlines, campaign paths, and animated territory markers.
# Territory data is injected by HUD.gd via `territory_states`.
extends Node2D

# ── Data injected by HUD ──────────────────────────────────────────────────────
# Each entry: { "pos": Vector2, "color": Color, "state": String }
# state: "cleared" | "active" | "locked"
var territory_states : Array = []

# ── Animation clock ───────────────────────────────────────────────────────────
var _pulse : float = 0.0

func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 0.72, 1.0)
	queue_redraw()

# ─────────────────────────────────────────────────────────────────────────────
func _draw() -> void:
	_draw_ocean()
	_draw_land()
	_draw_paths()
	_draw_territories()

# ── Ocean ─────────────────────────────────────────────────────────────────────
func _draw_ocean() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.05, 0.10, 0.24))
	for i in range(14):
		var y : float = 28.0 + float(i) * 50.0
		draw_line(Vector2(0, y), Vector2(1280, y), Color(0.08, 0.15, 0.32, 0.20), 1.0)
	for fx in range(6):
		var fpos := Vector2(55.0 + float(fx) * 28.0, 430.0 + float(fx) * 18.0)
		draw_circle(fpos, 4.0, Color(0.55, 0.68, 0.85, 0.18))
	for fx in range(5):
		var fpos2 := Vector2(1105.0 + float(fx) * 14.0, 180.0 + float(fx) * 22.0)
		draw_circle(fpos2, 3.5, Color(0.55, 0.68, 0.85, 0.15))

# ── Continent + decorations ───────────────────────────────────────────────────
func _draw_land() -> void:
	var cont := PackedVector2Array([
		Vector2(302, 50),  Vector2(482, 30),  Vector2(658, 52),
		Vector2(802, 40),  Vector2(958, 80),  Vector2(1052, 122),
		Vector2(1102, 204), Vector2(1120, 324), Vector2(1082, 454),
		Vector2(1022, 574), Vector2(902, 632), Vector2(752, 658),
		Vector2(602, 651), Vector2(452, 641), Vector2(282, 621),
		Vector2(158, 571), Vector2(95, 461),  Vector2(79, 341),
		Vector2(110, 221), Vector2(180, 131), Vector2(240, 70),
	])

	var shd := PackedVector2Array()
	for p in cont:
		shd.append(p + Vector2(7, 8))
	draw_colored_polygon(shd, Color(0.01, 0.03, 0.09, 0.55))
	draw_colored_polygon(cont, Color(0.56, 0.50, 0.34))

	_draw_biomes()

	draw_colored_polygon(cont, Color(0.68, 0.62, 0.44, 0.16))

	for row in range(16):
		draw_line(
			Vector2(82,  34.0 + float(row) * 42.0),
			Vector2(1118, 34.0 + float(row) * 42.0),
			Color(0.38, 0.32, 0.20, 0.07), 0.8)

	_draw_mountains(Vector2(445, 91),  6, 16.0)
	_draw_mountains(Vector2(720, 122), 5, 15.0)
	_draw_mountains(Vector2(148, 205), 4, 13.0)
	_draw_mountains(Vector2(962, 278), 3, 11.0)
	_draw_mountains(Vector2(596, 590), 3, 10.0)

	_draw_forest(Vector2(162, 508), 8, 10.5)
	_draw_forest(Vector2(105, 378), 9, 12.0)
	_draw_forest(Vector2(322, 580), 5,  9.5)
	_draw_forest(Vector2(970, 342), 6, 10.0)
	_draw_forest(Vector2(872, 514), 4,  9.0)

	var r1 := PackedVector2Array([
		Vector2(488, 90), Vector2(502, 180), Vector2(490, 278),
		Vector2(508, 362), Vector2(480, 455), Vector2(448, 545),
	])
	draw_polyline(r1, Color(0.20, 0.42, 0.70, 0.52), 4.0)
	draw_polyline(r1, Color(0.38, 0.60, 0.88, 0.26), 1.8)

	var r2 := PackedVector2Array([
		Vector2(948, 312), Vector2(968, 385), Vector2(1008, 458), Vector2(1018, 528),
	])
	draw_polyline(r2, Color(0.20, 0.42, 0.70, 0.38), 3.0)
	draw_polyline(r2, Color(0.38, 0.60, 0.88, 0.20), 1.5)

	draw_polyline(cont, Color(0.34, 0.26, 0.14, 0.95), 2.5)
	var inner := PackedVector2Array()
	for p in cont:
		inner.append(p + Vector2(3, 3))
	draw_polyline(inner, Color(0.34, 0.26, 0.14, 0.20), 1.0)

	_draw_landmarks()

# ── Themed biome blobs ────────────────────────────────────────────────────────
func _draw_biomes() -> void:
	var themes : Array = [
		[Color(0.28, 0.72, 0.18, 0.52), Color(0.38, 0.84, 0.24, 0.28), 78.0],
		[Color(0.04, 0.26, 0.06, 0.60), Color(0.06, 0.38, 0.10, 0.35), 72.0],
		[Color(0.82, 0.65, 0.22, 0.52), Color(0.70, 0.52, 0.16, 0.32), 75.0],
		[Color(0.75, 0.90, 0.98, 0.50), Color(0.55, 0.78, 0.96, 0.32), 70.0],
		[Color(0.88, 0.20, 0.06, 0.48), Color(1.00, 0.42, 0.04, 0.28), 75.0],
		[Color(0.18, 0.42, 0.12, 0.55), Color(0.28, 0.58, 0.20, 0.32), 80.0],
		[Color(0.55, 0.14, 0.88, 0.48), Color(0.78, 0.38, 0.98, 0.25), 74.0],
		[Color(0.12, 0.02, 0.28, 0.65), Color(0.28, 0.06, 0.55, 0.38), 70.0],
		[Color(0.95, 0.88, 0.28, 0.48), Color(1.00, 0.95, 0.55, 0.25), 76.0],
		[Color(0.90, 0.93, 1.00, 0.46), Color(0.75, 0.80, 0.98, 0.25), 72.0],
	]
	var off  : Array = [Vector2(0,0), Vector2(22,-12), Vector2(-18,18), Vector2(14,22)]
	var frac : Array = [1.00, 0.65, 0.55, 0.48]
	for i in range(mini(territory_states.size(), themes.size())):
		var ts  : Dictionary = territory_states[i]
		var pos : Vector2    = ts["pos"]
		var th  : Array      = themes[i]
		var r   : float      = th[2]
		for j in range(4):
			draw_circle(pos + off[j], r * frac[j], th[0] if j < 2 else th[1])

# ── Dispatch per-world landmark drawings ──────────────────────────────────────
func _draw_landmarks() -> void:
	for i in range(mini(territory_states.size(), 10)):
		var pos : Vector2 = territory_states[i]["pos"]
		match i:
			0: _draw_lm_garden_plains(pos)
			1: _draw_lm_deep_forest(pos)
			2: _draw_lm_desert_ruins(pos)
			3: _draw_lm_frost_peaks(pos)
			4: _draw_lm_volcanic_wastes(pos)
			5: _draw_lm_swamplands(pos)
			6: _draw_lm_crystal_highlands(pos)
			7: _draw_lm_shadow_realm(pos)
			8: _draw_lm_celestial_kingdom(pos)
			9: _draw_lm_eternal_citadel(pos)

# W1: Garden Plains — flower clusters and rolling hills
func _draw_lm_garden_plains(c: Vector2) -> void:
	var flowers : Array = [Vector2(-55,22), Vector2(-65,-8), Vector2(54,26), Vector2(62,-4)]
	var fcols   : Array = [Color(0.95,0.25,0.45), Color(1.0,0.85,0.20), Color(0.85,0.30,0.90), Color(0.30,0.90,0.45)]
	for fi in range(flowers.size()):
		var fp : Vector2 = c + flowers[fi]
		for petal in range(5):
			var pa : float = float(petal) * TAU / 5.0
			draw_circle(fp + Vector2(cos(pa), sin(pa)) * 5.0, 3.0, fcols[fi].lightened(0.22))
		draw_circle(fp, 5.5, fcols[fi])
		draw_circle(fp, 2.5, Color(1.0, 0.95, 0.60, 0.90))
	draw_arc(c + Vector2(-50, 42), 22.0, PI, TAU, 16, Color(0.30, 0.68, 0.18, 0.55), 3.5)
	draw_arc(c + Vector2(-28, 48), 18.0, PI, TAU, 14, Color(0.28, 0.65, 0.16, 0.50), 3.0)

# W2: Deep Forest — mushrooms and dark tree silhouettes
func _draw_lm_deep_forest(c: Vector2) -> void:
	var mpos  : Array = [Vector2(-56,14), Vector2(50,10), Vector2(-46,-16)]
	var mcols : Array = [Color(0.85,0.25,0.20), Color(0.90,0.55,0.20), Color(0.70,0.20,0.75)]
	for mi in range(mpos.size()):
		var mp : Vector2 = c + mpos[mi]
		draw_rect(Rect2(mp.x - 3, mp.y, 6, 10), Color(0.85, 0.80, 0.70, 0.85))
		draw_colored_polygon(PackedVector2Array([
			mp + Vector2(-9, 0), mp + Vector2(0, -14), mp + Vector2(9, 0)
		]), mcols[mi])
		draw_circle(mp + Vector2(0, -6), 3.0, Color(1, 1, 1, 0.32))
	for ti in range(3):
		var ta  : float  = float(ti) * TAU / 3.0 + 0.5
		var tp  : Vector2 = c + Vector2(cos(ta), sin(ta)) * 52.0
		draw_line(tp, tp + Vector2(0, 16), Color(0.12, 0.08, 0.04, 0.88), 5.0)
		draw_circle(tp, 8.0, Color(0.04, 0.20, 0.04, 0.72))

# W3: Desert Ruins — ancient pillars and pyramid
func _draw_lm_desert_ruins(c: Vector2) -> void:
	for pi in range(3):
		var px : float = c.x - 50.0 + float(pi) * 22.0
		var py : float = c.y + 16.0
		var ph : float = 28.0 - float(pi) * 5.0
		draw_rect(Rect2(px - 5, py - ph, 10, ph), Color(0.78, 0.70, 0.48))
		draw_rect(Rect2(px - 7, py - ph - 4, 14, 5), Color(0.65, 0.58, 0.38))
		draw_rect(Rect2(px - 7, py, 14, 4), Color(0.65, 0.58, 0.38))
	var pyr : Vector2 = c + Vector2(48, 18)
	draw_colored_polygon(PackedVector2Array([
		pyr + Vector2(-14, 14), pyr + Vector2(0, -14), pyr + Vector2(14, 14)
	]), Color(0.82, 0.68, 0.38, 0.90))
	draw_colored_polygon(PackedVector2Array([
		pyr + Vector2(-14, 14), pyr + Vector2(0, -14), pyr + Vector2(-4, 14)
	]), Color(0.62, 0.50, 0.28, 0.58))
	draw_arc(c + Vector2(0, 52), 30.0, PI, TAU, 16, Color(0.82, 0.70, 0.38, 0.48), 3.5)

# W4: Frost Peaks — ice spires and snowflakes
func _draw_lm_frost_peaks(c: Vector2) -> void:
	var sp_o : Array = [Vector2(-52,12), Vector2(-38,6), Vector2(44,10), Vector2(58,14)]
	var sp_h : Array = [24.0, 32.0, 28.0, 20.0]
	for si in range(sp_o.size()):
		var sp : Vector2 = c + sp_o[si]
		var sh : float   = sp_h[si]
		draw_colored_polygon(PackedVector2Array([
			sp + Vector2(-6, 0), sp + Vector2(0, -sh), sp + Vector2(6, 0)
		]), Color(0.78, 0.92, 1.00, 0.80))
		draw_colored_polygon(PackedVector2Array([
			sp + Vector2(-6, 0), sp + Vector2(0, -sh), sp + Vector2(-2, 0)
		]), Color(0.55, 0.78, 0.98, 0.48))
	for flake in range(2):
		var fp : Vector2 = c + ([Vector2(-55,-20), Vector2(50,-16)][flake])
		for arm in range(3):
			var aa : float = float(arm) * PI / 3.0
			draw_line(fp + Vector2(cos(aa), sin(aa)) * 8.0,
				fp + Vector2(cos(aa + PI), sin(aa + PI)) * 8.0,
				Color(0.85, 0.94, 1.00, 0.78), 1.5)
		draw_circle(fp, 2.5, Color(0.92, 0.97, 1.00, 0.88))
	draw_circle(c + Vector2(0, 52), 16.0, Color(0.65, 0.85, 0.98, 0.42))
	draw_arc(c + Vector2(0, 52), 16.0, 0, TAU, 24, Color(0.72, 0.90, 1.00, 0.58), 1.5)

# W5: Volcanic Wastes — lava pools and smoke plumes
func _draw_lm_volcanic_wastes(c: Vector2) -> void:
	draw_circle(c + Vector2(0, 48), 18.0, Color(1.00, 0.35, 0.05, 0.28))
	draw_circle(c + Vector2(0, 48), 13.0, Color(1.00, 0.50, 0.08, 0.52))
	draw_circle(c + Vector2(0, 48),  8.0, Color(1.00, 0.72, 0.20, 0.72))
	var rocks : Array = [Vector2(-55,16), Vector2(50,14), Vector2(-40,36), Vector2(40,39)]
	for rk in rocks:
		var rp : Vector2 = c + rk
		draw_colored_polygon(PackedVector2Array([
			rp + Vector2(-8, 6), rp + Vector2(-4, -8), rp + Vector2(5, -6), rp + Vector2(9, 5)
		]), Color(0.22, 0.10, 0.06, 0.88))
	var p := _pulse
	for si in range(3):
		var sx : float = c.x - 20.0 + float(si) * 20.0
		var sy : float = c.y - 42.0 - float(si) * 5.0 - sin(p * TAU + float(si)) * 4.0
		draw_circle(Vector2(sx, sy), 5.0 + float(si),
			Color(0.55, 0.50, 0.48, 0.28 - float(si) * 0.05))

# W6: Swamplands — murky pools and dead trees
func _draw_lm_swamplands(c: Vector2) -> void:
	draw_circle(c + Vector2(50, 26), 16.0, Color(0.12, 0.22, 0.10, 0.65))
	draw_circle(c + Vector2(50, 26), 10.0, Color(0.18, 0.32, 0.12, 0.52))
	for li in range(4):
		var la  : float  = float(li) * TAU / 4.0 + 0.3
		var lp  : Vector2 = c + Vector2(50, 26) + Vector2(cos(la), sin(la)) * 8.0
		draw_circle(lp, 3.5, Color(0.22, 0.55, 0.16, 0.78))
	var tp : Vector2 = c + Vector2(-52, 12)
	draw_line(tp, tp + Vector2(0, -28), Color(0.20, 0.14, 0.08, 0.90), 4.0)
	draw_line(tp + Vector2(0, -18), tp + Vector2(-12, -28), Color(0.20, 0.14, 0.08, 0.82), 2.5)
	draw_line(tp + Vector2(0, -14), tp + Vector2(10, -22), Color(0.20, 0.14, 0.08, 0.82), 2.5)
	draw_line(tp + Vector2(0, -10), tp + Vector2(-8, -16), Color(0.20, 0.14, 0.08, 0.72), 2.0)
	for mi in range(5):
		var ma : float = float(mi) * TAU / 5.0
		draw_circle(c + Vector2(cos(ma), sin(ma)) * 46.0, 6.0, Color(0.25, 0.45, 0.18, 0.18))

# W7: Crystal Highlands — purple crystal formations
func _draw_lm_crystal_highlands(c: Vector2) -> void:
	var crys : Array = [
		[Vector2(-55,14), 18.0, Color(0.65, 0.20, 0.95, 0.85)],
		[Vector2(-44,10), 26.0, Color(0.78, 0.35, 1.00, 0.75)],
		[Vector2(-35,16), 16.0, Color(0.55, 0.15, 0.88, 0.80)],
		[Vector2(46,12),  20.0, Color(0.72, 0.28, 0.98, 0.78)],
		[Vector2(58,17),  14.0, Color(0.58, 0.18, 0.82, 0.70)],
	]
	for cr in crys:
		var cp : Vector2 = c + cr[0]
		var ch : float   = cr[1]
		var cc : Color   = cr[2]
		draw_colored_polygon(PackedVector2Array([
			cp + Vector2(-5, 0), cp + Vector2(0, -ch), cp + Vector2(5, 0)
		]), cc)
		draw_colored_polygon(PackedVector2Array([
			cp + Vector2(-5, 0), cp + Vector2(0, -ch), cp + Vector2(-1, 0)
		]), Color(cc.r, cc.g, cc.b, cc.a * 0.42))
		draw_circle(cp + Vector2(0, -ch), 3.0, Color(0.92, 0.70, 1.00, 0.68))
	for mi in range(4):
		var ma : float = float(mi) * TAU / 4.0 + 1.0
		draw_circle(c + Vector2(cos(ma), sin(ma)) * 52.0, 9.0, Color(0.55, 0.12, 0.85, 0.14))

# W8: Shadow Realm — void rifts and ghostly wisps
func _draw_lm_shadow_realm(c: Vector2) -> void:
	var rifts : Array = [Vector2(-54,10), Vector2(48,14), Vector2(-38,-18)]
	for ri in rifts:
		var rp : Vector2 = c + ri
		draw_colored_polygon(PackedVector2Array([
			rp + Vector2(-3,-14), rp + Vector2(0,-18), rp + Vector2(3,-14),
			rp + Vector2(2,0), rp + Vector2(0,4), rp + Vector2(-2,0)
		]), Color(0.05, 0.00, 0.15, 0.90))
		draw_arc(rp, 6.0, 0, TAU, 24, Color(0.55, 0.15, 0.90, 0.48), 1.5)
	var p := _pulse
	for wi in range(4):
		var wa  : float  = float(wi) * TAU / 4.0 + p * TAU * 0.3
		var wr  : float  = 44.0 + sin(p * TAU * 2.0 + float(wi)) * 6.0
		var wp  : Vector2 = c + Vector2(cos(wa), sin(wa)) * wr
		draw_circle(wp, 4.5, Color(0.72, 0.55, 1.00, 0.32 + sin(p * TAU + float(wi)) * 0.12))
		draw_circle(wp, 2.0, Color(0.90, 0.80, 1.00, 0.52))
	draw_arc(c, 50.0, 0, TAU, 48, Color(0.18, 0.02, 0.42, 0.32), 6.0)

# W9: Celestial Kingdom — golden light rays and cloud puffs
func _draw_lm_celestial_kingdom(c: Vector2) -> void:
	var p := _pulse
	for ri in range(6):
		var ra    : float = float(ri) * TAU / 6.0 + p * 0.15
		var r_far : float = 62.0 + sin(p * TAU + float(ri)) * 5.0
		draw_line(
			c + Vector2(cos(ra), sin(ra)) * 38.0,
			c + Vector2(cos(ra), sin(ra)) * r_far,
			Color(1.00, 0.95, 0.45, 0.26 + sin(p * TAU + float(ri)) * 0.08), 3.0)
	var clouds : Array = [Vector2(-55,-8), Vector2(50,-12), Vector2(0,-54)]
	for cl in clouds:
		var cp : Vector2 = c + cl
		draw_circle(cp, 12.0, Color(1.00, 0.98, 0.88, 0.72))
		draw_circle(cp + Vector2(-10, 4),  9.0, Color(1.00, 0.97, 0.84, 0.68))
		draw_circle(cp + Vector2( 10, 4),  9.0, Color(1.00, 0.97, 0.84, 0.68))
	draw_rect(Rect2(c.x - 4, c.y + 38, 8, 20), Color(1.00, 0.95, 0.70, 0.55))
	draw_rect(Rect2(c.x - 6, c.y + 36, 12, 4), Color(1.00, 0.90, 0.60, 0.65))

# W10: Eternal Citadel — castle battlements and divine aura
func _draw_lm_eternal_citadel(c: Vector2) -> void:
	var bx : float = c.x - 30.0
	var by : float = c.y + 36.0
	draw_rect(Rect2(bx, by - 16, 60, 16), Color(0.70, 0.72, 0.80, 0.82))
	for bi in range(5):
		draw_rect(Rect2(bx + float(bi) * 12.0, by - 22, 8, 8), Color(0.75, 0.78, 0.88, 0.82))
	draw_rect(Rect2(c.x - 7, by - 32, 14, 16), Color(0.80, 0.82, 0.92, 0.85))
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - 7, by - 32), Vector2(c.x, by - 44), Vector2(c.x + 7, by - 32)
	]), Color(0.88, 0.18, 0.18, 0.90))
	var p := _pulse
	draw_circle(c, 48.0 + sin(p * TAU) * 4.0,
		Color(0.92, 0.95, 1.00, 0.12 + sin(p * TAU) * 0.05))
	draw_arc(c, 40.0, 0, TAU, 48,
		Color(0.88, 0.90, 1.00, 0.42 + sin(p * TAU) * 0.10), 2.0)

# ── Mountain range ────────────────────────────────────────────────────────────
func _draw_mountains(center: Vector2, count: int, sz: float) -> void:
	for i in range(count):
		var ox : float   = (float(i) - float(count - 1) * 0.5) * sz * 1.6
		var pk : Vector2 = center + Vector2(ox, 0.0)
		draw_colored_polygon(PackedVector2Array([
			pk + Vector2(-sz,  sz * 0.78),
			pk + Vector2(0.0, -sz),
			pk + Vector2( sz,  sz * 0.78),
		]), Color(0.52, 0.50, 0.48))
		draw_colored_polygon(PackedVector2Array([
			pk + Vector2(-sz * 0.36, -sz * 0.04),
			pk + Vector2( 0.0,       -sz),
			pk + Vector2( sz * 0.36, -sz * 0.04),
		]), Color(0.93, 0.95, 0.98, 0.88))
		draw_line(pk + Vector2(-sz, sz * 0.78), pk + Vector2(sz, sz * 0.78),
			Color(0.40, 0.38, 0.36), 1.0)

# ── Forest cluster ────────────────────────────────────────────────────────────
func _draw_forest(center: Vector2, count: int, sz: float) -> void:
	for i in range(count):
		var a   : float   = float(i) * TAU / float(count)
		var pos : Vector2 = center + Vector2(cos(a), sin(a)) * sz * 1.8
		draw_circle(pos,        sz,        Color(0.07, 0.25, 0.05, 0.72))
		draw_circle(pos, sz * 0.60,        Color(0.11, 0.36, 0.07, 0.82))

# ── Campaign paths ────────────────────────────────────────────────────────────
func _draw_paths() -> void:
	if territory_states.size() < 2:
		return
	for i in range(territory_states.size() - 1):
		var pa    : Vector2 = territory_states[i]["pos"]
		var pb    : Vector2 = territory_states[i + 1]["pos"]
		var lit   : bool    = territory_states[i]["state"] == "cleared"
		var pclr  : Color   = Color(0.88, 0.74, 0.28, 0.90) if lit else Color(0.30, 0.26, 0.18, 0.48)
		var sclr  : Color   = Color(0.55, 0.44, 0.16, 0.40) if lit else Color(0.14, 0.12, 0.08, 0.22)
		var total : float   = pa.distance_to(pb)
		if total < 0.1:
			continue
		var dir : Vector2 = (pb - pa) / total
		var d   : float   = 30.0
		while d < total - 30.0:
			var e : float = minf(d + 14.0, total - 30.0)
			draw_line(pa + dir * d + Vector2(1, 1), pa + dir * e + Vector2(1, 1), sclr, 2.5)
			draw_line(pa + dir * d,                 pa + dir * e,                 pclr, 2.5)
			d += 22.0

# ── Territory circles ─────────────────────────────────────────────────────────
func _draw_territories() -> void:
	var p : float = _pulse
	for i in range(territory_states.size()):
		var ts    : Dictionary = territory_states[i]
		var pos   : Vector2   = ts["pos"]
		var clr   : Color     = ts["color"]
		var state : String    = ts["state"]

		match state:
			"active":
				draw_circle(pos, 54.0 + sin(p * TAU) * 8.0,
					Color(clr.r, clr.g, clr.b, 0.18 + sin(p * TAU) * 0.09))
				var ra : float = p * TAU
				draw_arc(pos, 42.0, ra, ra + TAU * 0.72, 40,
					Color(1.0, 0.90, 0.28, 0.55 + sin(p * TAU) * 0.20), 3.0)
			"cleared":
				draw_circle(pos, 40.0, Color(0.22, 0.90, 0.26, 0.14))

		draw_circle(pos + Vector2(3, 5), 33, Color(0, 0, 0, 0.40))

		var bc : Color = clr if state != "locked" else Color(0.28, 0.26, 0.24)
		draw_circle(pos, 33, bc.darkened(0.55))
		draw_circle(pos, 31, bc.darkened(0.28))
		draw_circle(pos, 29, bc)
		draw_circle(pos, 25, bc.lightened(0.14))

		draw_circle(pos + Vector2(-5, -6), 7, Color(1, 1, 1, 0.17))

		match state:
			"active":
				var ca : float = 0.70 + sin(p * TAU) * 0.22
				draw_circle(pos, 18, Color(clr.r, clr.g, clr.b, ca))
				draw_circle(pos,  9, Color(1.0, 1.0, 1.0, ca * 0.55))
			"cleared":
				draw_circle(pos, 18, Color(0.10, 0.70, 0.14, 0.85))
				draw_arc(pos, 12, -PI * 0.25, PI * 1.22, 20, Color(1, 1, 1, 0.92), 3.5)
			"locked":
				draw_circle(pos, 18, Color(0.06, 0.06, 0.09, 0.78))

		var bclr : Color
		match state:
			"active":  bclr = Color(1.0, 0.92, 0.30, 0.90 + sin(p * TAU) * 0.10)
			"cleared": bclr = Color(0.28, 0.96, 0.32, 0.88)
			_:         bclr = Color(0.38, 0.36, 0.34, 0.60)
		draw_arc(pos, 31, 0, TAU, 44, bclr, 2.0)
