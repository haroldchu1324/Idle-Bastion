# ui/WorldMapCanvas.gd
# Draws the fantasy campaign world map: ocean, continent, biomes, mountains,
# forests, river, campaign paths, and territory markers.
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
	# Subtle wave lines
	for i in range(14):
		var y : float = 28.0 + float(i) * 50.0
		draw_line(Vector2(0, y), Vector2(1280, y),
			Color(0.08, 0.15, 0.32, 0.20), 1.0)
	# Foam flecks near coastline corners (static decoration)
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
		Vector2(802, 40),  Vector2(958, 80),  Vector2(1052,122),
		Vector2(1102,204), Vector2(1120,324), Vector2(1082,454),
		Vector2(1022,574), Vector2(902, 632), Vector2(752, 658),
		Vector2(602, 651), Vector2(452, 641), Vector2(282, 621),
		Vector2(158, 571), Vector2(95,  461), Vector2(79,  341),
		Vector2(110, 221), Vector2(180, 131), Vector2(240, 70),
	])

	# Drop shadow
	var shd := PackedVector2Array()
	for p in cont:
		shd.append(p + Vector2(7, 8))
	draw_colored_polygon(shd, Color(0.01, 0.03, 0.09, 0.55))

	# Base parchment land
	draw_colored_polygon(cont, Color(0.56, 0.50, 0.34))

	# Biome blobs (colour regions around territories)
	_draw_biomes()

	# Faint parchment warmth overlay
	draw_colored_polygon(cont, Color(0.68, 0.62, 0.44, 0.16))

	# Map-grid texture
	for row in range(16):
		draw_line(
			Vector2(82,  34.0 + float(row) * 42.0),
			Vector2(1118, 34.0 + float(row) * 42.0),
			Color(0.38, 0.32, 0.20, 0.07), 0.8)

	# Mountain ranges
	_draw_mountains(Vector2(445,  91), 6, 16.0)
	_draw_mountains(Vector2(720, 132), 5, 15.0)
	_draw_mountains(Vector2(148, 210), 4, 13.0)
	_draw_mountains(Vector2(965, 285), 3, 11.0)

	# Forest patches
	_draw_forest(Vector2(162, 440), 7, 11.0)
	_draw_forest(Vector2(328, 576), 6,  9.5)
	_draw_forest(Vector2(876, 550), 5,  9.0)
	_draw_forest(Vector2(692, 492), 5,  8.5)

	# River
	var river := PackedVector2Array([
		Vector2(506,108), Vector2(520,196), Vector2(500,306),
		Vector2(514,399), Vector2(490,479), Vector2(454,558),
	])
	draw_polyline(river, Color(0.20, 0.42, 0.70, 0.52), 4.0)
	draw_polyline(river, Color(0.38, 0.60, 0.88, 0.26), 1.8)

	# Coastline border
	draw_polyline(cont, Color(0.34, 0.26, 0.14, 0.95), 2.5)
	var inner := PackedVector2Array()
	for p in cont:
		inner.append(p + Vector2(3, 3))
	draw_polyline(inner, Color(0.34, 0.26, 0.14, 0.20), 1.0)

# ── Biome blobs ───────────────────────────────────────────────────────────────
func _draw_biomes() -> void:
	# Offsets and fractional radii for the 4 sub-circles per biome
	var off  : Array = [Vector2(0,0), Vector2(22,-12), Vector2(-18,18), Vector2(14,22)]
	var frac : Array = [1.00, 0.65, 0.55, 0.48]
	var sz_v : Array = [1.00, 1.05, 0.95, 1.08, 1.02, 0.98, 0.94, 1.03, 0.97, 0.92]
	for i in range(mini(territory_states.size(), 10)):
		var ts  : Dictionary = territory_states[i]
		var pos : Vector2    = ts["pos"]
		var c   : Color      = ts["color"]
		var r   : float      = 72.0 * sz_v[i]
		var bc  := Color(c.r, c.g, c.b, 0.48)
		for j in range(4):
			draw_circle(pos + off[j], r * float(frac[j]), bc)

# ── Mountain range ────────────────────────────────────────────────────────────
func _draw_mountains(center: Vector2, count: int, sz: float) -> void:
	for i in range(count):
		var ox : float   = (float(i) - float(count - 1) * 0.5) * sz * 1.6
		var pk : Vector2 = center + Vector2(ox, 0.0)
		# Main peak
		draw_colored_polygon(PackedVector2Array([
			pk + Vector2(-sz,         sz * 0.78),
			pk + Vector2( 0.0,       -sz),
			pk + Vector2( sz,         sz * 0.78),
		]), Color(0.52, 0.50, 0.48))
		# Snow cap
		draw_colored_polygon(PackedVector2Array([
			pk + Vector2(-sz * 0.36, -sz * 0.04),
			pk + Vector2( 0.0,       -sz),
			pk + Vector2( sz * 0.36, -sz * 0.04),
		]), Color(0.93, 0.95, 0.98, 0.88))
		# Base shadow line
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

		# ── Outer glow / aura ──────────────────────────────────────────────
		match state:
			"active":
				# Pulsing radial glow
				draw_circle(pos, 54.0 + sin(p * TAU) * 8.0,
					Color(clr.r, clr.g, clr.b, 0.18 + sin(p * TAU) * 0.09))
				# Spinning arc
				var ra : float = p * TAU
				draw_arc(pos, 42.0, ra, ra + TAU * 0.72, 40,
					Color(1.0, 0.90, 0.28, 0.55 + sin(p * TAU) * 0.20), 3.0)
			"cleared":
				draw_circle(pos, 40.0, Color(0.22, 0.90, 0.26, 0.14))

		# ── Drop shadow ────────────────────────────────────────────────────
		draw_circle(pos + Vector2(3, 5), 33, Color(0, 0, 0, 0.40))

		# ── Plate layers ───────────────────────────────────────────────────
		var bc : Color = clr if state != "locked" else Color(0.28, 0.26, 0.24)
		draw_circle(pos, 33, bc.darkened(0.55))
		draw_circle(pos, 31, bc.darkened(0.28))
		draw_circle(pos, 29, bc)
		draw_circle(pos, 25, bc.lightened(0.14))

		# Specular highlight
		draw_circle(pos + Vector2(-5, -6), 7, Color(1, 1, 1, 0.17))

		# ── Centre fill ────────────────────────────────────────────────────
		match state:
			"active":
				var ca : float = 0.70 + sin(p * TAU) * 0.22
				draw_circle(pos, 18, Color(clr.r, clr.g, clr.b, ca))
				draw_circle(pos,  9, Color(1.0, 1.0, 1.0, ca * 0.55))
			"cleared":
				draw_circle(pos, 18, Color(0.10, 0.70, 0.14, 0.85))
				# Checkmark arc
				draw_arc(pos, 12, -PI * 0.25, PI * 1.22, 20, Color(1, 1, 1, 0.92), 3.5)
			"locked":
				draw_circle(pos, 18, Color(0.06, 0.06, 0.09, 0.78))

		# ── Outer border ring ──────────────────────────────────────────────
		var bclr : Color
		match state:
			"active":  bclr = Color(1.0, 0.92, 0.30, 0.90 + sin(p * TAU) * 0.10)
			"cleared": bclr = Color(0.28, 0.96, 0.32, 0.88)
			_:         bclr = Color(0.38, 0.36, 0.34, 0.60)
		draw_arc(pos, 31, 0, TAU, 44, bclr, 2.0)
