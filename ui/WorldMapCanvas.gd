# ui/WorldMapCanvas.gd
# Draws the fantasy campaign world map: ocean, continent, themed biomes,
# unique per-world landmark nodes with hover/selected/click animations.
extends Node2D

# ── Data injected by HUD ──────────────────────────────────────────────────────
# Each entry: { "pos": Vector2, "color": Color, "state": String }
var territory_states : Array = []
var hovered_world    : int   = -1   # 0-9 or -1
var selected_world   : int   = -1   # 0-9 or -1

# ── Animation state ───────────────────────────────────────────────────────────
var _pulse   : float = 0.0
var _hover_t : Array = []   # float[10]  0→1 lerp
var _click_t : Array = []   # float[10]  click bounce countdown
var _burst_particles : Array = []   # Array[Array] per-world burst

func _ready() -> void:
	for _i in range(10):
		_hover_t.append(0.0)
		_click_t.append(0.0)
		_burst_particles.append([])

# ── Public API (called by HUD) ────────────────────────────────────────────────
func set_hovered(idx: int) -> void:
	hovered_world = idx

func do_click(idx: int) -> void:
	_click_t[idx] = 1.0
	_spawn_burst(idx)

# ── Burst particle helpers ────────────────────────────────────────────────────
func _spawn_burst(idx: int) -> void:
	if territory_states.size() <= idx:
		return
	var center : Vector2 = territory_states[idx]["pos"]
	var bclr   : Color   = _burst_color(idx)
	var burst  : Array   = []
	for i in range(20):
		var a   : float = float(i) * TAU / 20.0 + randf() * 0.4
		var spd : float = 45.0 + randf() * 65.0
		burst.append([center, Vector2(cos(a), sin(a)) * spd,
			1.0, 1.0, bclr, 2.5 + randf() * 3.0])
	_burst_particles[idx] = burst

func _burst_color(idx: int) -> Color:
	match idx:
		0: return Color(0.50, 1.00, 0.30)
		1: return Color(0.30, 0.90, 0.30)
		2: return Color(1.00, 0.82, 0.28)
		3: return Color(0.72, 0.94, 1.00)
		4: return Color(1.00, 0.50, 0.08)
		5: return Color(0.40, 0.80, 0.28)
		6: return Color(0.85, 0.40, 1.00)
		7: return Color(0.65, 0.22, 1.00)
		8: return Color(1.00, 0.92, 0.28)
		9: return Color(0.92, 0.94, 1.00)
	return Color.WHITE

# ── Process: animation updates ────────────────────────────────────────────────
func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 0.72, 1.0)
	for i in range(10):
		var is_locked : bool = i < territory_states.size() and territory_states[i].get("state", "locked") == "locked"
		var target := 1.0 if not is_locked and i == hovered_world else 0.0
		_hover_t[i] = move_toward(_hover_t[i], target, delta * 5.5)
		if _click_t[i] > 0.0:
			_click_t[i] = max(0.0, _click_t[i] - delta * 3.8)
		# Update burst particles
		var alive : Array = []
		for pp in _burst_particles[i]:
			pp[0] = pp[0] + pp[1] * delta
			pp[1] = pp[1] * (1.0 - delta * 3.2)
			pp[2] -= delta * 1.6
			if pp[2] > 0.0:
				alive.append(pp)
		_burst_particles[i] = alive
	queue_redraw()

# ─────────────────────────────────────────────────────────────────────────────
func _draw() -> void:
	_draw_ocean()
	_draw_land()
	_draw_paths()
	_draw_ambient_all()
	_draw_world_nodes()

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
	# NOTE: _draw_landmarks() removed — landmarks now drawn inside _draw_world_nodes()

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

# ── Ambient world effects (drawn without landmark transform) ──────────────────
func _draw_ambient_all() -> void:
	var p := _pulse
	for i in range(mini(territory_states.size(), 10)):
		var c : Vector2 = territory_states[i]["pos"]
		match i:
			0: _draw_ambient_garden(c, p)
			1: _draw_ambient_forest(c, p)
			2: _draw_ambient_desert(c, p)
			3: _draw_ambient_frost(c, p)
			4: _draw_ambient_volcano(c, p)
			5: _draw_ambient_swamp(c, p)
			6: _draw_ambient_crystal(c, p)
			7: _draw_ambient_shadow(c, p)
			8: _draw_ambient_celestial(c, p)
			9: _draw_ambient_citadel(c, p)

func _draw_ambient_garden(c: Vector2, p: float) -> void:
	for bi in range(3):
		var ba : float   = float(bi) * TAU / 3.0 + p * TAU * 0.45
		var br : float   = 50.0 + sin(p * TAU * 1.5 + float(bi)) * 7.0
		var bp : Vector2 = c + Vector2(cos(ba), sin(ba) * 0.6) * br
		var wo : float   = abs(sin(p * TAU * 4.5 + float(bi) * 1.8)) * 5.5
		var bcol : Array = [Color(1.0, 0.45, 0.75), Color(0.75, 0.28, 1.0), Color(0.28, 0.85, 1.0)]
		var cc : Color = bcol[bi]
		draw_colored_polygon(PackedVector2Array([bp+Vector2(-wo,0), bp+Vector2(0,-7), bp+Vector2(0,3)]),
			Color(cc.r, cc.g, cc.b, 0.72))
		draw_colored_polygon(PackedVector2Array([bp+Vector2( wo,0), bp+Vector2(0,-7), bp+Vector2(0,3)]),
			Color(cc.r, cc.g, cc.b, 0.72))

func _draw_ambient_forest(c: Vector2, p: float) -> void:
	for fi in range(6):
		var fa  : float  = float(fi) * TAU / 6.0 + p * TAU * 0.28
		var fr  : float  = 46.0 + sin(p * TAU * 1.2 + float(fi) * 1.4) * 10.0
		var fp  : Vector2 = c + Vector2(cos(fa), sin(fa)) * fr
		var fal : float  = 0.45 + sin(p * TAU * 3.5 + float(fi) * 2.2) * 0.50
		if fal > 0.25:
			draw_circle(fp, 3.0, Color(0.72, 0.98, 0.18, fal))
			draw_circle(fp, 1.2, Color(1.0, 1.0, 0.55, fal * 0.7))

func _draw_ambient_desert(c: Vector2, p: float) -> void:
	for si in range(10):
		var sa    : float = float(si) * TAU / 10.0 + p * 0.4
		var sdrift: float = fmod(p * 0.85 + float(si) * 0.12, 1.0)
		var sr    : float = 36.0 + sdrift * 22.0
		var sp    : Vector2 = c + Vector2(cos(sa), sin(sa) * 0.45) * sr
		draw_circle(sp, 1.5, Color(0.94, 0.82, 0.48, (1.0 - sdrift) * 0.55))

func _draw_ambient_frost(c: Vector2, p: float) -> void:
	for si in range(7):
		var sx : float = c.x + (float(si) - 3.0) * 15.0 + sin(p * TAU + float(si) * 0.9) * 6.0
		var sy : float = c.y - 52.0 + fmod(p * 1.1 + float(si) * 0.16, 1.0) * 115.0
		var sp : Vector2 = Vector2(sx, sy)
		draw_circle(sp, 1.8, Color(0.88, 0.95, 1.00, 0.62))
		for arm in range(3):
			var aa : float = float(arm) * PI / 3.0
			draw_line(sp + Vector2(cos(aa), sin(aa)) * 4.5,
				sp + Vector2(cos(aa + PI), sin(aa + PI)) * 4.5,
				Color(0.88, 0.95, 1.00, 0.48), 0.8)

func _draw_ambient_volcano(c: Vector2, p: float) -> void:
	for ei in range(10):
		var ex  : float = c.x + (float(ei) - 4.5) * 11.0 + sin(p * TAU * 1.8 + float(ei)) * 4.5
		var ep  : float = fmod(p * 1.9 + float(ei) * 0.11, 1.0)
		var ey  : float = c.y + 24.0 - ep * 88.0
		var eal : float = (1.0 - ep) * 0.72
		draw_circle(Vector2(ex, ey), 1.8 + (1.0 - ep) * 1.8, Color(1.0, 0.48 + ep * 0.28, 0.04, eal))

func _draw_ambient_swamp(c: Vector2, p: float) -> void:
	for fi in range(5):
		var fa  : float  = float(fi) * TAU / 5.0 + p * 0.18
		var fr  : float  = 40.0 + sin(p * TAU * 0.8 + float(fi) * 1.2) * 12.0
		var fp  : Vector2 = c + Vector2(cos(fa), sin(fa)) * fr
		var fal : float  = 0.08 + sin(p * TAU * 0.6 + float(fi)) * 0.05
		draw_circle(fp, 10.0, Color(0.55, 0.70, 0.40, fal))
		draw_circle(fp, 6.0, Color(0.45, 0.65, 0.32, fal * 0.8))

func _draw_ambient_crystal(c: Vector2, p: float) -> void:
	for ki in range(7):
		var ka  : float  = float(ki) * TAU / 7.0 + p * 0.14
		var kr  : float  = 48.0 + sin(p * TAU * 1.4 + float(ki)) * 9.0
		var kp  : Vector2 = c + Vector2(cos(ka), sin(ka)) * kr
		var kal : float  = 0.35 + sin(p * TAU * 2.8 + float(ki) * 1.3) * 0.55
		if kal > 0.42:
			draw_circle(kp, 2.8, Color(0.90, 0.65, 1.00, kal))
			draw_line(kp + Vector2(-5, 0), kp + Vector2(5, 0), Color(0.90, 0.65, 1.00, kal * 0.55), 0.8)
			draw_line(kp + Vector2(0, -5), kp + Vector2(0, 5), Color(0.90, 0.65, 1.00, kal * 0.55), 0.8)

func _draw_ambient_shadow(c: Vector2, p: float) -> void:
	for wi in range(6):
		var wa  : float  = float(wi) * TAU / 6.0 + p * TAU * 0.22
		var wr  : float  = 46.0 + sin(p * TAU * 1.4 + float(wi)) * 9.0
		var wp  : Vector2 = c + Vector2(cos(wa), sin(wa)) * wr
		var wal : float  = 0.18 + sin(p * TAU * 1.1 + float(wi)) * 0.10
		draw_circle(wp, 5.5, Color(0.42, 0.06, 0.72, wal))
		draw_circle(wp, 2.2, Color(0.68, 0.38, 1.00, wal * 1.5))

func _draw_ambient_celestial(c: Vector2, p: float) -> void:
	for ri in range(8):
		var ra : float = float(ri) * TAU / 8.0 + p * 0.12
		var rl : float = 38.0 + sin(p * TAU * 0.9 + float(ri) * 0.75) * 9.0
		draw_line(c + Vector2(cos(ra), sin(ra)) * 26.0,
			c + Vector2(cos(ra), sin(ra)) * (26.0 + rl),
			Color(1.00, 0.95, 0.42, 0.16 + sin(p * TAU + float(ri)) * 0.06), 2.2)

func _draw_ambient_citadel(c: Vector2, p: float) -> void:
	for fi in range(5):
		var fa  : float  = float(fi) * TAU / 5.0 + p * TAU * 0.14
		var fr  : float  = 45.0 + sin(p * TAU * 0.75 + float(fi) * 1.2) * 9.0
		var fp  : Vector2 = c + Vector2(cos(fa), sin(fa)) * fr
		var fal : float  = 0.30 + sin(p * TAU * 1.4 + float(fi)) * 0.22
		draw_circle(fp, 2.5, Color(0.96, 0.96, 1.00, fal))
		draw_line(fp, fp + Vector2(sin(fa) * 3.0, -9.0), Color(0.88, 0.90, 1.00, fal * 0.55), 0.8)

# ── World node drawing (replaces _draw_territories) ──────────────────────────
func _draw_world_nodes() -> void:
	var p := _pulse
	for i in range(mini(territory_states.size(), 10)):
		var ts    : Dictionary = territory_states[i]
		var c     : Vector2   = ts["pos"]
		var state : String    = ts["state"]
		var clr   : Color     = ts["color"]
		var ht    : float     = _hover_t[i]
		var ct    : float     = _click_t[i]

		# Bounce: quick pop on click
		var bounce : float = sin(ct * PI) * 0.10
		var sc     : float = 1.0 + ht * 0.10 + bounce
		var lift   : float = ht * -6.0

		# Hover glow ring
		if ht > 0.01:
			draw_circle(c, 58.0 * sc, Color(clr.r, clr.g, clr.b, 0.18 * ht))
			draw_circle(c, 44.0 * sc, Color(clr.r + 0.15, clr.g + 0.15, clr.b + 0.15, 0.12 * ht))

		# Selection ring
		if i == selected_world:
			var glow_r : float = 64.0 + sin(p * TAU) * 9.0
			draw_circle(c, glow_r, Color(clr.r, clr.g, clr.b, 0.26 + sin(p * TAU) * 0.10))
			var ra : float = p * TAU
			draw_arc(c, 52.0, ra, ra + TAU * 0.76, 56,
				Color(clr.r, clr.g, clr.b, 0.95), 3.2)
			draw_arc(c, 47.0, -ra * 0.65, -ra * 0.65 + TAU * 0.52, 36,
				Color(1.0, 1.0, 1.0, 0.38), 1.5)
		elif state == "active":
			draw_circle(c, 54.0 + sin(p * TAU) * 6.0,
				Color(clr.r, clr.g, clr.b, 0.14 + sin(p * TAU) * 0.07))
			var ra : float = p * TAU
			draw_arc(c, 44.0, ra, ra + TAU * 0.70, 44,
				Color(1.0, 0.90, 0.28, 0.58 + sin(p * TAU) * 0.18), 2.8)
		elif state == "cleared":
			draw_circle(c, 42.0, Color(0.22, 0.92, 0.28, 0.12))

		# Drop shadow (no transform)
		draw_circle(c + Vector2(4, 7), 36.0, Color(0, 0, 0, 0.38))

		# ── Apply hover transform ──────────────────────────────────────────────
		draw_set_transform(c + Vector2(0.0, lift), 0.0, Vector2(sc, sc))

		# Base disc
		var bc : Color = clr if state != "locked" else Color(0.22, 0.20, 0.18)
		if state == "locked":
			bc = bc.darkened(0.50)
		draw_circle(Vector2.ZERO, 35.0, bc.darkened(0.58))
		draw_circle(Vector2.ZERO, 33.0, bc.darkened(0.30))
		draw_circle(Vector2.ZERO, 31.0, bc)
		draw_circle(Vector2.ZERO, 27.0, bc.lightened(0.13))
		# Specular highlight
		draw_circle(Vector2(-5, -7), 7.5, Color(1, 1, 1, 0.17))

		# Draw the biome landmark
		match i:
			0: _draw_lm_garden_plains(Vector2.ZERO)
			1: _draw_lm_deep_forest(Vector2.ZERO)
			2: _draw_lm_desert_ruins(Vector2.ZERO)
			3: _draw_lm_frost_peaks(Vector2.ZERO)
			4: _draw_lm_volcanic_wastes(Vector2.ZERO)
			5: _draw_lm_swamplands(Vector2.ZERO)
			6: _draw_lm_crystal_highlands(Vector2.ZERO)
			7: _draw_lm_shadow_realm(Vector2.ZERO)
			8: _draw_lm_celestial_kingdom(Vector2.ZERO)
			9: _draw_lm_eternal_citadel(Vector2.ZERO)

		# Locked overlay + padlock
		if state == "locked":
			draw_circle(Vector2.ZERO, 32.0, Color(0.04, 0.03, 0.10, 0.65))
			var lk : Color = Color(0.62, 0.60, 0.56, 0.92)
			draw_arc(Vector2(0, -2), 6.5, PI, TAU, 18, lk, 2.5)
			draw_rect(Rect2(-6, -2, 12, 11), lk)
			draw_rect(Rect2(-4, 0, 8, 9), Color(0.24, 0.22, 0.28, 0.85))
			draw_circle(Vector2(0, 4), 2.0, lk)

		# Active / cleared interior indicator
		match state:
			"active":
				var ca : float = 0.68 + sin(p * TAU) * 0.22
				draw_circle(Vector2.ZERO, 16.0, Color(clr.r, clr.g, clr.b, ca))
				draw_circle(Vector2.ZERO,  8.0, Color(1.0, 1.0, 1.0, ca * 0.50))
			"cleared":
				draw_circle(Vector2.ZERO, 16.0, Color(0.10, 0.70, 0.14, 0.82))
				draw_arc(Vector2.ZERO, 9.0, -PI * 0.25, PI * 1.22, 20, Color(1, 1, 1, 0.92), 3.5)

		# Outer border ring
		var bclr : Color
		match state:
			"active":  bclr = Color(1.0, 0.92, 0.30, 0.90 + sin(p * TAU) * 0.10)
			"cleared": bclr = Color(0.28, 0.96, 0.32, 0.88)
			_:         bclr = Color(0.38, 0.36, 0.34, 0.50)
		if i == selected_world:
			bclr = Color(clr.r, clr.g, clr.b, 1.0)
			# Extra bright inner ring on selected
			draw_arc(Vector2.ZERO, 27.0, 0, TAU, 36, Color(1, 1, 1, 0.28), 1.5)
		draw_arc(Vector2.ZERO, 33.0, 0, TAU, 48, bclr, 2.5)

		# Dimming overlay for non-selected worlds
		if selected_world >= 0 and i != selected_world:
			var dim : float = (1.0 - ht) * 0.42
			draw_circle(Vector2.ZERO, 35.0, Color(0.02, 0.02, 0.06, dim))

		# Reset transform
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Sword icon floats above the active (attackable) world
		if state == "active":
			_draw_sword_icon(c)

		# Burst particles (absolute coords, drawn after transform reset)
		for pp in _burst_particles[i]:
			var plife : float = pp[2] / pp[3]
			draw_circle(pp[0], float(pp[5]) * plife, Color(
				float(pp[4].r), float(pp[4].g), float(pp[4].b), plife * 0.82))

# ── Per-world landmark draw functions (draw at c, used by _draw_world_nodes) ──

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
		var ta  : float   = float(ti) * TAU / 3.0 + 0.5
		var tp  : Vector2 = c + Vector2(cos(ta), sin(ta)) * 52.0
		draw_line(tp, tp + Vector2(0, 16), Color(0.12, 0.08, 0.04, 0.88), 5.0)
		draw_circle(tp, 8.0, Color(0.04, 0.20, 0.04, 0.72))

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

func _draw_lm_swamplands(c: Vector2) -> void:
	draw_circle(c + Vector2(50, 26), 16.0, Color(0.12, 0.22, 0.10, 0.65))
	draw_circle(c + Vector2(50, 26), 10.0, Color(0.18, 0.32, 0.12, 0.52))
	for li in range(4):
		var la  : float   = float(li) * TAU / 4.0 + 0.3
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
		var wa  : float   = float(wi) * TAU / 4.0 + p * TAU * 0.3
		var wr  : float   = 44.0 + sin(p * TAU * 2.0 + float(wi)) * 6.0
		var wp  : Vector2 = c + Vector2(cos(wa), sin(wa)) * wr
		draw_circle(wp, 4.5, Color(0.72, 0.55, 1.00, 0.32 + sin(p * TAU + float(wi)) * 0.12))
		draw_circle(wp, 2.0, Color(0.90, 0.80, 1.00, 0.52))
	draw_arc(c, 50.0, 0, TAU, 48, Color(0.18, 0.02, 0.42, 0.32), 6.0)

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

# ── Sword icon (floats above the active/attackable world node) ───────────────
func _draw_sword_icon(c: Vector2) -> void:
	var bob : float   = sin(_pulse * TAU * 0.85) * 3.5
	var s   : Vector2 = c + Vector2(0.0, -56.0 + bob)

	# Pulsing glow halo
	var ga : float = 0.55 + sin(_pulse * TAU * 1.6) * 0.28
	draw_circle(s, 16.0, Color(1.0, 0.88, 0.18, ga * 0.30))
	draw_circle(s, 10.0, Color(1.0, 0.95, 0.45, ga * 0.20))

	# Blade — tapered polygon pointing up
	draw_colored_polygon(PackedVector2Array([
		s + Vector2(-2.5,  8.0),
		s + Vector2(-0.8, -13.0),
		s + Vector2( 0.0, -16.0),
		s + Vector2( 0.8, -13.0),
		s + Vector2( 2.5,  8.0),
	]), Color(0.84, 0.90, 1.00, 0.97))
	draw_line(s + Vector2(0.0, -14.0), s + Vector2(0.0, 7.0),
		Color(1.0, 1.0, 1.0, 0.48), 1.0)

	# Guard
	draw_rect(Rect2(s.x - 8.5, s.y + 6.5, 17.0, 3.5),
		Color(0.88, 0.74, 0.20, 0.96))
	draw_line(s + Vector2(-8.5, 6.5), s + Vector2(8.5, 6.5),
		Color(1.0, 0.92, 0.48, 0.60), 1.0)

	# Grip
	draw_rect(Rect2(s.x - 1.8, s.y + 10.0, 3.6, 8.5),
		Color(0.48, 0.30, 0.14, 0.94))

	# Pommel
	draw_circle(s + Vector2(0.0, 20.5), 3.8, Color(0.88, 0.72, 0.22, 0.96))
	draw_circle(s + Vector2(0.0, 20.5), 1.6, Color(1.0, 0.94, 0.56, 0.82))


# ── Forest cluster ────────────────────────────────────────────────────────────
func _draw_forest(center: Vector2, count: int, sz: float) -> void:
	for i in range(count):
		var a   : float   = float(i) * TAU / float(count)
		var pos : Vector2 = center + Vector2(cos(a), sin(a)) * sz * 1.8
		draw_circle(pos,        sz,        Color(0.07, 0.25, 0.05, 0.72))
		draw_circle(pos, sz * 0.60,        Color(0.11, 0.36, 0.07, 0.82))
