extends Control

const TILE_SIZE : float = 60.0
const ROAD_HALF : float = 30.0  # ROAD_W * 0.5

var _path_pts : Array = []
var _path_clr : Color = Color(0.55, 0.88, 1.0)
var _island   : Rect2 = Rect2()
var _cols     : int   = 0
var _rows     : int   = 0

func setup(path: Array, biome_color: Color, island: Rect2) -> void:
	_path_pts = path
	_path_clr = Color(biome_color.r, biome_color.g, biome_color.b, 0.90)
	_island   = island
	_cols     = int(island.size.x) / int(TILE_SIZE)
	_rows     = int(island.size.y) / int(TILE_SIZE)
	queue_redraw()

func _dist_pt_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab   := b - a
	var len2 := ab.length_squared()
	if len2 < 0.0001:
		return p.distance_to(a)
	var t : float = clamp((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _is_path_blocked(tc: Vector2) -> bool:
	for i in range(_path_pts.size() - 1):
		if _dist_pt_seg(tc, _path_pts[i], _path_pts[i + 1]) <= ROAD_HALF:
			return true
	return false

func _draw() -> void:
	var sz := size
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.05, 0.07, 0.16))
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.28, 0.38, 0.65, 0.40), false, 1.5)
	if _path_pts.size() < 2:
		return

	# Bounds: include all path points AND the four island corners so tiles and
	# path share the same coordinate system.
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

	# Helper: world point → minimap point
	# (captured inline via the values above)

	# Draw buildable tiles
	if _cols > 0 and _rows > 0:
		var ts    := TILE_SIZE * sc
		var gox   := (_island.position.x - mn.x) * sc + ox
		var goy   := (_island.position.y - mn.y) * sc + oy

		# Fill pass
		for c in range(_cols):
			for r in range(_rows):
				var tc_world := Vector2(
					_island.position.x + c * TILE_SIZE + TILE_SIZE * 0.5,
					_island.position.y + r * TILE_SIZE + TILE_SIZE * 0.5
				)
				if _is_path_blocked(tc_world):
					continue
				draw_rect(Rect2(Vector2(gox + c * ts, goy + r * ts), Vector2(ts, ts)),
					Color(1.0, 1.0, 1.0, 0.12))

		# Grid lines — single pass avoids shared-edge misalignment
		var lclr := Color(1.0, 1.0, 1.0, 0.28)
		for c in range(_cols + 1):
			var x := gox + c * ts
			draw_line(Vector2(x, goy), Vector2(x, goy + _rows * ts), lclr, 0.8)
		for r in range(_rows + 1):
			var y := goy + r * ts
			draw_line(Vector2(gox, y), Vector2(gox + _cols * ts, y), lclr, 0.8)

	# Path
	var pts := PackedVector2Array()
	for pp in _path_pts:
		pts.append(Vector2((pp.x - mn.x) * sc + ox, (pp.y - mn.y) * sc + oy))
	draw_polyline(pts, Color(_path_clr.r, _path_clr.g, _path_clr.b, 0.20), 14.0)
	draw_polyline(pts, Color(_path_clr.r, _path_clr.g, _path_clr.b, 0.65), 5.0)
	draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.28), 1.5)
	draw_circle(pts[0],              6.0, Color(0.22, 0.92, 0.28))
	draw_circle(pts[pts.size() - 1], 6.0, Color(0.95, 0.28, 0.22))
