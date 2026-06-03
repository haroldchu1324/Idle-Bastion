extends Node2D
# Road rendered as two filled polygons — no rectangles, no border strips, no seams.
#
#  1. _road_outer_poly()  — the full outer road shape (3 rounded corners + entry notch)
#  2. _island_poly()      — the inner build area (rounded rect drawn on top)
#
# The visible "road ring" is simply the part of polygon 1 not covered by polygon 2.

# ── Colors ────────────────────────────────────────────────────────────────────
const C_ROAD    := Color(0.60, 0.42, 0.18)   # warm dirt brown
const C_SHADOW  := Color(0.00, 0.00, 0.00, 0.22)
const C_ISLAND  := Color(0.30, 0.62, 0.18)   # inner grass
const C_GRID    := Color(0.00, 0.00, 0.00, 0.06)
const C_GRID_BD := Color(0.00, 0.00, 0.00, 0.10)

# ── Road geometry ─────────────────────────────────────────────────────────────
const ROAD_W  : int   = 60
const R_LEFT  : float = 220.0
const R_RIGHT : float = 880.0
const R_TOP   : float = 110.0   # pushed down 20px to give space below boss bar
const R_BOT   : float = 530.0

const I_LEFT  : float = 280.0   # R_LEFT  + ROAD_W
const I_RIGHT : float = 820.0   # R_RIGHT - ROAD_W
const I_TOP   : float = 170.0   # R_TOP + ROAD_W
const I_BOT   : float = 470.0   # R_BOT   - ROAD_W

const ISLAND    := Rect2(280, 170, 540, 300)   # 9 cols × 5 rows at 60px
const TILE_SIZE : int  = 60

# ── Corner radii ──────────────────────────────────────────────────────────────
const OUTER_R  : float = 16.0
const INNER_R  : float = 10.0
const STEPS    : int   = 12

# ── Path centres ──────────────────────────────────────────────────────────────
const CY_TOP   : float = R_TOP   + ROAD_W * 0.5   # 120
const CY_BOT   : float = I_BOT   + ROAD_W * 0.5   # 500
const CX_LEFT  : float = R_LEFT  + ROAD_W * 0.5   # 250
const CX_RIGHT : float = I_RIGHT + ROAD_W * 0.5   # 850


func _draw() -> void:
	var road   := _road_outer_poly()
	var island := _island_poly()

	# 1 — soft drop shadow (offset copy of road shape)
	var shadow := road.duplicate()
	for i in range(shadow.size()):
		shadow[i] += Vector2(5, 7)
	draw_colored_polygon(shadow, C_SHADOW)

	# 2 — road surface (one seamless warm-brown polygon)
	draw_colored_polygon(road, C_ROAD)

	# 3 — island grass drawn on top → creates the road ring with zero seams
	draw_colored_polygon(island, C_ISLAND)

	# 4 — faint build grid (only inside island)
	_draw_grid()


# ── Road outer polygon ────────────────────────────────────────────────────────
# Traces the outer boundary clockwise:
#   top-left entry (x=0) → top edge → [rounded top-right] →
#   right edge → [rounded bottom-right] → bottom edge → [rounded bottom-left] →
#   left edge up to entry height → entry bottom-left → close
func _road_outer_poly() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r   : float = OUTER_R

	# ── Top edge ──────────────────────────────────────────────────────────────
	pts.append(Vector2(0.0, R_TOP))
	pts.append(Vector2(R_RIGHT - r, R_TOP))

	# Rounded top-right corner  (centre: R_RIGHT-r, R_TOP+r)
	_arc(pts, Vector2(R_RIGHT - r, R_TOP + r), r, -PI * 0.5, 0.0)

	# ── Right edge ────────────────────────────────────────────────────────────
	pts.append(Vector2(R_RIGHT, R_BOT - r))

	# Rounded bottom-right corner  (centre: R_RIGHT-r, R_BOT-r)
	_arc(pts, Vector2(R_RIGHT - r, R_BOT - r), r, 0.0, PI * 0.5)

	# ── Bottom edge ───────────────────────────────────────────────────────────
	pts.append(Vector2(R_LEFT + r, R_BOT))

	# Rounded bottom-left corner  (centre: R_LEFT+r, R_BOT-r)
	_arc(pts, Vector2(R_LEFT + r, R_BOT - r), r, PI * 0.5, PI)

	# ── Left edge (going up) + entry notch ────────────────────────────────────
	# Left edge rises from bottom-left corner up to the entry-corridor height
	pts.append(Vector2(R_LEFT, I_TOP))
	# Entry corridor bottom edge goes all the way to the screen left edge
	pts.append(Vector2(0.0, I_TOP))
	# (polygon closes back to (0, R_TOP) automatically)

	return pts


# ── Island polygon (rounded rectangle) ───────────────────────────────────────
func _island_poly() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r   : float = INNER_R
	var x0  : float = ISLAND.position.x + r
	var y0  : float = ISLAND.position.y + r
	var x1  : float = ISLAND.end.x - r
	var y1  : float = ISLAND.end.y - r

	_arc(pts, Vector2(x0, y0), r, -PI,       -PI * 0.5)   # top-left
	_arc(pts, Vector2(x1, y0), r, -PI * 0.5,  0.0)        # top-right
	_arc(pts, Vector2(x1, y1), r,  0.0,       PI * 0.5)   # bottom-right
	_arc(pts, Vector2(x0, y1), r,  PI * 0.5,  PI)         # bottom-left

	return pts


# ── Arc helper — appends STEPS+1 points along a circular arc ─────────────────
func _arc(pts: PackedVector2Array, centre: Vector2,
          radius: float, a_from: float, a_to: float) -> void:
	for i in range(STEPS + 1):
		var t : float = float(i) / float(STEPS)
		var a : float = lerp(a_from, a_to, t)
		pts.append(centre + Vector2(cos(a), sin(a)) * radius)


# ── Build grid (faint lines inside island only) ───────────────────────────────
# Grid lines are inset by INNER_R so they never reach the rounded corners,
# which previously caused visible square outlines at the four corners.
func _draw_grid() -> void:
	var pad  : float = INNER_R + 2.0   # keep lines clear of rounded corners
	var x0   : float = ISLAND.position.x + pad
	var y0   : float = ISLAND.position.y + pad
	var x1   : float = ISLAND.end.x - pad
	var y1   : float = ISLAND.end.y - pad

	var cols : int = int(ISLAND.size.x) / TILE_SIZE
	var rows : int = int(ISLAND.size.y) / TILE_SIZE

	for c in range(1, cols):   # interior column lines only (skip outer edges)
		var x : float = ISLAND.position.x + c * TILE_SIZE
		draw_line(Vector2(x, y0), Vector2(x, y1), C_GRID, 1.0)

	for r in range(1, rows):   # interior row lines only
		var y : float = ISLAND.position.y + r * TILE_SIZE
		draw_line(Vector2(x0, y), Vector2(x1, y), C_GRID, 1.0)
	# No draw_rect border — the island polygon edge is the visual boundary
