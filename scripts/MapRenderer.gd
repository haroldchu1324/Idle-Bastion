extends Node2D
# Per-world battlefield road renderer.
# World 1 uses the original polygon road ring. Worlds 2-10 use a themed
# thick-polyline road following the same waypoints as the enemy PATH.

# ── Colors — World 1 (kept exactly as before) ────────────────────────────────
const C_ROAD    := Color(0.60, 0.42, 0.18)
const C_SHADOW  := Color(0.00, 0.00, 0.00, 0.22)
const C_ISLAND  := Color(0.30, 0.62, 0.18)
const C_GRID    := Color(0.00, 0.00, 0.00, 0.06)
const C_GRID_BD := Color(0.00, 0.00, 0.00, 0.10)

# ── Road geometry (World 1 polygon approach) ──────────────────────────────────
const ROAD_W  : int   = 60
const R_LEFT  : float = 220.0
const R_RIGHT : float = 880.0
const R_TOP   : float = 110.0
const R_BOT   : float = 530.0

const I_LEFT  : float = 280.0
const I_RIGHT : float = 820.0
const I_TOP   : float = 170.0
const I_BOT   : float = 470.0

const ISLAND    := Rect2(280, 170, 540, 300)
const TILE_SIZE : int  = 60

const OUTER_R  : float = 16.0
const INNER_R  : float = 10.0
const STEPS    : int   = 12

const CY_TOP   : float = R_TOP   + ROAD_W * 0.5
const CY_BOT   : float = I_BOT   + ROAD_W * 0.5
const CX_LEFT  : float = R_LEFT  + ROAD_W * 0.5
const CX_RIGHT : float = I_RIGHT + ROAD_W * 0.5

# ── Per-world themed road colors ──────────────────────────────────────────────
const WORLD_ROAD_COLORS : Array = [
	Color(0.60, 0.42, 0.18),   # W1  Garden Plains — warm dirt brown (kept)
	Color(0.18, 0.22, 0.10),   # W2  Deep Forest — dark mossy earth
	Color(0.74, 0.62, 0.32),   # W3  Desert Ruins — sandy stone
	Color(0.65, 0.75, 0.85),   # W4  Frost Peaks — icy pale stone
	Color(0.28, 0.18, 0.14),   # W5  Volcanic Wastes — scorched dark rock
	Color(0.20, 0.28, 0.14),   # W6  Swamplands — murky olive mud
	Color(0.35, 0.22, 0.52),   # W7  Crystal Highlands — purple-tinted stone
	Color(0.08, 0.05, 0.18),   # W8  Shadow Realm — near-black void stone
	Color(0.82, 0.75, 0.48),   # W9  Celestial Kingdom — golden marble
	Color(0.72, 0.74, 0.82),   # W10 Eternal Citadel — silver marble
]

const WORLD_BORDER_COLORS : Array = [
	Color(0.38, 0.26, 0.10),   # W1
	Color(0.08, 0.14, 0.05),   # W2
	Color(0.52, 0.42, 0.18),   # W3
	Color(0.45, 0.58, 0.72),   # W4
	Color(0.55, 0.15, 0.05),   # W5
	Color(0.10, 0.18, 0.06),   # W6
	Color(0.22, 0.10, 0.38),   # W7
	Color(0.35, 0.20, 0.55),   # W8
	Color(0.60, 0.52, 0.22),   # W9
	Color(0.52, 0.55, 0.65),   # W10
]

const WORLD_ISLAND_COLORS : Array = [
	Color(0.30, 0.62, 0.18),   # W1  lush grass
	Color(0.14, 0.38, 0.08),   # W2  deep forest floor
	Color(0.58, 0.48, 0.22),   # W3  desert sand
	Color(0.72, 0.82, 0.88),   # W4  frost-dusted stone
	Color(0.22, 0.14, 0.10),   # W5  scorched earth
	Color(0.18, 0.32, 0.12),   # W6  swamp mud
	Color(0.28, 0.18, 0.42),   # W7  crystal plateau
	Color(0.06, 0.04, 0.14),   # W8  void plane
	Color(0.75, 0.68, 0.40),   # W9  golden cloud platform
	Color(0.60, 0.62, 0.72),   # W10 marble floor
]


func _draw() -> void:
	var world : int = clamp(GameData.selected_world, 1, 10)
	if world == 1:
		_draw_world1()
	else:
		_draw_world_n(world)


# ── World 1 — original polygon road ring (unchanged) ─────────────────────────
func _draw_world1() -> void:
	var road   := _road_outer_poly()
	var island := _island_poly()

	var shadow := road.duplicate()
	for i in range(shadow.size()):
		shadow[i] += Vector2(5, 7)
	draw_colored_polygon(shadow, C_SHADOW)
	draw_colored_polygon(road, C_ROAD)
	draw_colored_polygon(island, C_ISLAND)
	_draw_grid(C_ISLAND)


# ── Worlds 2-10 — polyline road following world-specific path ─────────────────
func _draw_world_n(world: int) -> void:
	var w_idx      : int   = clamp(world - 1, 0, WORLD_ROAD_COLORS.size() - 1)
	var road_c     : Color = WORLD_ROAD_COLORS[w_idx]
	var border_c   : Color = WORLD_BORDER_COLORS[w_idx]
	var island_c   : Color = WORLD_ISLAND_COLORS[w_idx]

	var pts := _path_to_pv2(GameData.get_world_path(world))

	# 1 — shadow
	var shadow_pts := PackedVector2Array()
	for p in pts:
		shadow_pts.append(p + Vector2(5, 7))
	draw_polyline(shadow_pts, Color(0, 0, 0, 0.35), float(ROAD_W) + 8.0, true)

	# 2 — road border (slightly wider, darker)
	draw_polyline(pts, border_c, float(ROAD_W) + 8.0, true)

	# 3 — road surface
	draw_polyline(pts, road_c, float(ROAD_W), true)

	# 4 — bright center stripe
	draw_polyline(pts, Color(road_c.r + 0.12, road_c.g + 0.08, road_c.b + 0.06, 0.35),
		float(ROAD_W) * 0.28, true)

	# 5 — island (build area) drawn on top
	draw_colored_polygon(_island_poly(), island_c)
	_draw_grid(island_c)

	# 6 — themed edge details
	_draw_world_edge_details(world, pts, road_c)


func _draw_world_edge_details(world: int, _pts: PackedVector2Array, road_c: Color) -> void:
	match world:
		2:  # Deep Forest — vine-edge tint
			draw_polyline(_pts, Color(0.08, 0.35, 0.05, 0.22), float(ROAD_W) + 12.0, true)
		3:  # Desert Ruins — sandy dust fringe
			draw_polyline(_pts, Color(0.88, 0.72, 0.35, 0.18), float(ROAD_W) + 14.0, true)
		4:  # Frost Peaks — icy blue glow
			draw_polyline(_pts, Color(0.55, 0.80, 1.00, 0.20), float(ROAD_W) + 14.0, true)
		5:  # Volcanic Wastes — lava-orange rim
			draw_polyline(_pts, Color(1.00, 0.40, 0.05, 0.22), float(ROAD_W) + 14.0, true)
		6:  # Swamplands — murky green mist
			draw_polyline(_pts, Color(0.20, 0.48, 0.10, 0.20), float(ROAD_W) + 14.0, true)
		7:  # Crystal Highlands — purple shimmer
			draw_polyline(_pts, Color(0.68, 0.22, 0.95, 0.25), float(ROAD_W) + 14.0, true)
		8:  # Shadow Realm — void aura
			draw_polyline(_pts, Color(0.45, 0.10, 0.80, 0.28), float(ROAD_W) + 16.0, true)
		9:  # Celestial Kingdom — golden halo
			draw_polyline(_pts, Color(1.00, 0.90, 0.40, 0.22), float(ROAD_W) + 14.0, true)
		10: # Eternal Citadel — divine white glow
			draw_polyline(_pts, Color(0.90, 0.92, 1.00, 0.25), float(ROAD_W) + 14.0, true)


func _path_to_pv2(path: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in path:
		pts.append(p)
	return pts


# ── Build grid ────────────────────────────────────────────────────────────────
func _draw_grid(_island_c: Color) -> void:
	var pad  : float = INNER_R + 2.0
	var x0   : float = ISLAND.position.x + pad
	var y0   : float = ISLAND.position.y + pad
	var x1   : float = ISLAND.end.x - pad
	var y1   : float = ISLAND.end.y - pad

	var cols : int = int(ISLAND.size.x) / TILE_SIZE
	var rows : int = int(ISLAND.size.y) / TILE_SIZE

	for c in range(1, cols):
		var x : float = ISLAND.position.x + c * TILE_SIZE
		draw_line(Vector2(x, y0), Vector2(x, y1), C_GRID, 1.0)

	for r in range(1, rows):
		var y : float = ISLAND.position.y + r * TILE_SIZE
		draw_line(Vector2(x0, y), Vector2(x1, y), C_GRID, 1.0)


# ── World 1 road polygon (original — untouched) ───────────────────────────────
func _road_outer_poly() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r   : float = OUTER_R

	pts.append(Vector2(0.0, R_TOP))
	pts.append(Vector2(R_RIGHT - r, R_TOP))
	_arc(pts, Vector2(R_RIGHT - r, R_TOP + r), r, -PI * 0.5, 0.0)
	pts.append(Vector2(R_RIGHT, R_BOT - r))
	_arc(pts, Vector2(R_RIGHT - r, R_BOT - r), r, 0.0, PI * 0.5)
	pts.append(Vector2(R_LEFT + r, R_BOT))
	_arc(pts, Vector2(R_LEFT + r, R_BOT - r), r, PI * 0.5, PI)
	pts.append(Vector2(R_LEFT, I_TOP))
	pts.append(Vector2(0.0, I_TOP))

	return pts


func _island_poly() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r   : float = INNER_R
	var x0  : float = ISLAND.position.x + r
	var y0  : float = ISLAND.position.y + r
	var x1  : float = ISLAND.end.x - r
	var y1  : float = ISLAND.end.y - r

	_arc(pts, Vector2(x0, y0), r, -PI,       -PI * 0.5)
	_arc(pts, Vector2(x1, y0), r, -PI * 0.5,  0.0)
	_arc(pts, Vector2(x1, y1), r,  0.0,       PI * 0.5)
	_arc(pts, Vector2(x0, y1), r,  PI * 0.5,  PI)

	return pts


func _arc(pts: PackedVector2Array, centre: Vector2,
		  radius: float, a_from: float, a_to: float) -> void:
	for i in range(STEPS + 1):
		var t : float = float(i) / float(STEPS)
		var a : float = lerp(a_from, a_to, t)
		pts.append(centre + Vector2(cos(a), sin(a)) * radius)
