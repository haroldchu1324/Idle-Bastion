extends Control

const TILE_SIZE  : float = 60.0
const BLOCK_HALF : float = 60.0  # ROAD_W/2 + TILE_SIZE/2 — matches BuildGrid blocking radius

# Mirrors BuildGrid._WORLD_MAX_TILES so the minimap trims identically to the real game.
const _WORLD_MAX_TILES : Dictionary = {
	2: 42, 3: 40, 4: 45, 5: 36, 6: 38, 7: 36, 8: 45, 9: 45, 10: 45
}

var _path_pts  : Array = []
var _path_clr  : Color = Color(0.55, 0.88, 1.0)
var _island    : Rect2 = Rect2()
var _cols      : int   = 0
var _rows      : int   = 0
var _buildable : Array = []   # Vector2i list — exactly what the game shows

func setup(path: Array, biome_color: Color, island: Rect2, world: int = 0) -> void:
	_path_pts = path
	_path_clr = Color(biome_color.r, biome_color.g, biome_color.b, 0.90)
	_island   = island
	_cols     = int(island.size.x) / int(TILE_SIZE)
	_rows     = int(island.size.y) / int(TILE_SIZE)
	_buildable = _compute_buildable(world)
	queue_redraw()

func _dist_pt_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab   := b - a
	var len2 := ab.length_squared()
	if len2 < 0.0001:
		return p.distance_to(a)
	var t : float = clamp((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _compute_buildable(world: int) -> Array:
	# Step 1: block tiles that physically overlap the road (same rule as BuildGrid).
	var blocked : Dictionary = {}
	for c in range(_cols):
		for r in range(_rows):
			var tc := Vector2(
				_island.position.x + c * TILE_SIZE + TILE_SIZE * 0.5,
				_island.position.y + r * TILE_SIZE + TILE_SIZE * 0.5
			)
			for i in range(_path_pts.size() - 1):
				if _dist_pt_seg(tc, _path_pts[i], _path_pts[i + 1]) < BLOCK_HALF:
					blocked[Vector2i(c, r)] = true
					break

	# Step 2: collect buildable tiles.
	var buildable : Array = []
	for c in range(_cols):
		for r in range(_rows):
			if not blocked.has(Vector2i(c, r)):
				buildable.append(Vector2i(c, r))

	# Step 3: trim to the same cap as BuildGrid._trim_to_target (outermost tiles first).
	if world > 1:
		var target : int = _WORLD_MAX_TILES.get(world, 45)
		if buildable.size() > target:
			var cx : float = (_cols - 1) * 0.5
			var cy : float = (_rows - 1) * 0.5
			buildable.sort_custom(func(a, b):
				var da := (float(a.x)-cx)*(float(a.x)-cx) + (float(a.y)-cy)*(float(a.y)-cy)
				var db := (float(b.x)-cx)*(float(b.x)-cx) + (float(b.y)-cy)*(float(b.y)-cy)
				if da != db: return da > db
				if a.x != b.x: return a.x < b.x
				return a.y < b.y
			)
			buildable = buildable.slice(buildable.size() - target)

	return buildable

func _draw() -> void:
	var sz := size
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.05, 0.07, 0.16))
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.28, 0.38, 0.65, 0.40), false, 1.5)
	if _path_pts.size() < 2:
		return

	# Bounds: include all path points AND island corners.
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for pp in _path_pts:
		mn.x = minf(mn.x, pp.x); mn.y = minf(mn.y, pp.y)
		mx.x = maxf(mx.x, pp.x); mx.y = maxf(mx.y, pp.y)
	if _island != Rect2():
		mn.x = minf(mn.x, _island.position.x)
		mn.y = minf(mn.y, _island.position.y)
		mx.x = maxf(mx.x, _island.end.x)
		mx.y = maxf(mx.y, _island.end.y)

	var pad  : float = 18.0
	var sc_x := (sz.x - pad * 2.0) / maxf(mx.x - mn.x, 1.0)
	var sc_y := (sz.y - pad * 2.0) / maxf(mx.y - mn.y, 1.0)
	var sc   := minf(sc_x, sc_y)
	var dw   := (mx.x - mn.x) * sc
	var dh   := (mx.y - mn.y) * sc
	var ox   := (sz.x - dw) * 0.5
	var oy   := (sz.y - dh) * 0.5

	# Draw buildable tiles — filled only, no internal outlines, so touching tiles
	# merge into one solid shape.
	if _cols > 0 and _rows > 0 and not _buildable.is_empty():
		var ts  := TILE_SIZE * sc
		var gox := (_island.position.x - mn.x) * sc + ox
		var goy := (_island.position.y - mn.y) * sc + oy
		for t in _buildable:
			draw_rect(
				Rect2(Vector2(gox + t.x * ts, goy + t.y * ts), Vector2(ts, ts)),
				Color(1.0, 1.0, 1.0, 0.18)
			)

	# Path
	var pts := PackedVector2Array()
	for pp in _path_pts:
		pts.append(Vector2((pp.x - mn.x) * sc + ox, (pp.y - mn.y) * sc + oy))
	draw_polyline(pts, Color(_path_clr.r, _path_clr.g, _path_clr.b, 0.20), 14.0)
	draw_polyline(pts, Color(_path_clr.r, _path_clr.g, _path_clr.b, 0.65), 5.0)
	draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.28), 1.5)
	draw_circle(pts[0],              6.0, Color(0.22, 0.92, 0.28))
	draw_circle(pts[pts.size() - 1], 6.0, Color(0.95, 0.28, 0.22))
