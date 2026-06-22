extends Node2D
class_name BuildGrid

const TILE_SIZE : int   = 60
const ROAD_W    : float = 60.0

# World 1 keeps its original hardcoded island.
# Worlds 2-10 call setup_world() which sets these dynamically.
var _island  : Rect2    = Rect2(280, 170, 540, 300)
var _cols    : int      = 9
var _rows    : int      = 5

var _occupied          : Dictionary = {}   # Vector2i → true
var _path_blocked      : Dictionary = {}   # Vector2i → true (tiles under the road)
var special_tiles      : Dictionary = {}   # Vector2i → "red" | "blue" | "green" (W2 S5 bonuses)
var tutorial_lock_tile : Vector2i   = Vector2i(-1, -1)  # when set, only this tile accepts drops
var hovered_tile       : Vector2i   = Vector2i(-1, -1)
var _time         : float      = 0.0

signal tiles_animation_done

# Per-tile drop animation: [{tile, elapsed, delay, landed}]
var _tile_anims      : Array = []
var _tiles_animating : bool  = false
# Landing impact rings: [{tile, t}]  t: 0 → 1 over 0.4 s
var _land_flashes    : Array = []

const _ANIM_DURATION : float = 1.5
const _ANIM_STAGGER  : float = 0.30
const _ANIM_START_Y  : float = -560.0


# Call this in Main._ready() after PATH is set (for worlds 2+).
func setup_world(world: int, path: Array) -> void:
	_island = GameData.get_world_island(world)
	_cols   = int(_island.size.x) / TILE_SIZE
	_rows   = int(_island.size.y) / TILE_SIZE
	_occupied.clear()
	_path_blocked.clear()
	special_tiles.clear()
	_tile_anims.clear()
	_land_flashes.clear()
	_tiles_animating    = false
	tutorial_lock_tile  = Vector2i(-1, -1)
	if world > 1:
		_compute_path_blocked(path)
		_trim_to_target(world)


# Max buildable tiles per world (from design spec). World 1 is always 45 (no path blocking).
const _WORLD_MAX_TILES : Dictionary = {
	2: 42, 3: 40, 4: 45, 5: 36, 6: 38, 7: 36, 8: 45, 9: 45, 10: 45
}

func _trim_to_target(world: int) -> void:
	var target : int = _WORLD_MAX_TILES.get(world, 45)
	var buildable : Array = []
	for c in range(_cols):
		for r in range(_rows):
			if not _path_blocked.has(Vector2i(c, r)):
				buildable.append(Vector2i(c, r))
	if buildable.size() <= target:
		return
	var cx : float = (_cols - 1) * 0.5
	var cy : float = (_rows - 1) * 0.5
	buildable.sort_custom(func(a, b):
		var da := (float(a.x) - cx) * (float(a.x) - cx) + (float(a.y) - cy) * (float(a.y) - cy)
		var db := (float(b.x) - cx) * (float(b.x) - cx) + (float(b.y) - cy) * (float(b.y) - cy)
		if da != db: return da > db
		if a.x != b.x: return a.x < b.x
		return a.y < b.y
	)
	var to_remove : int = buildable.size() - target
	for i in range(to_remove):
		_path_blocked[buildable[i]] = true


func _compute_path_blocked(path: Array) -> void:
	# Block any tile that physically overlaps the road at all.
	# A tile overlaps the road if its center is strictly closer than
	# ROAD_W/2 + TILE_SIZE/2 = 60 px to the path centerline.
	# Tiles at exactly 60 px are fully outside (corner-touching only) and kept.
	var half := ROAD_W * 0.5 + float(TILE_SIZE) * 0.5
	for c in range(_cols):
		for r in range(_rows):
			var tc := tile_center(Vector2i(c, r))
			for i in range(path.size() - 1):
				if _dist_point_seg(tc, path[i], path[i + 1]) < half:
					_path_blocked[Vector2i(c, r)] = true
					break


func _dist_point_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.0001:
		return p.distance_to(a)
	var t: float = clamp((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func start_tile_animation() -> void:
	_tile_anims.clear()
	_land_flashes.clear()
	var i := 0
	for kind in ["red", "blue", "green"]:
		for tile in special_tiles:
			if special_tiles[tile] == kind:
				_tile_anims.append({
					"tile":    tile,
					"elapsed": 0.0,
					"delay":   i * _ANIM_STAGGER,
					"landed":  false,
				})
				i += 1
				break
	_tiles_animating = not _tile_anims.is_empty()


func _ease_out_elastic(t: float) -> float:
	if t <= 0.0: return 0.0
	if t >= 1.0: return 1.0
	var c4 := (2.0 * PI) / 3.0
	return pow(2.0, -10.0 * t) * sin((t * 10.0 - 0.75) * c4) + 1.0


func _get_tile_y_offset(tile: Vector2i) -> float:
	for anim in _tile_anims:
		if anim["tile"] == tile:
			var eff : float = anim["elapsed"] - anim["delay"]
			if eff <= 0.0:
				return _ANIM_START_Y
			var t : float = minf(eff / _ANIM_DURATION, 1.0)
			return _ANIM_START_Y * (1.0 - _ease_out_elastic(t))
	return 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _tile_anims.is_empty() and _land_flashes.is_empty():
		return
	var all_done := true
	for anim in _tile_anims:
		anim["elapsed"] += delta
		var eff : float = anim["elapsed"] - anim["delay"]
		if eff < _ANIM_DURATION:
			all_done = false
		elif not anim["landed"]:
			anim["landed"] = true
			_land_flashes.append({"tile": anim["tile"], "t": 0.0})
	var next_flashes : Array = []
	for flash in _land_flashes:
		flash["t"] += delta / 0.5
		if flash["t"] < 1.0:
			next_flashes.append(flash)
	_land_flashes = next_flashes
	if _tiles_animating and all_done:
		_tiles_animating = false
		_tile_anims.clear()
		tiles_animation_done.emit()


func world_to_tile(p: Vector2) -> Vector2i:
	return Vector2i(
		int((p.x - _island.position.x) / TILE_SIZE),
		int((p.y - _island.position.y) / TILE_SIZE)
	)


func tile_center(t: Vector2i) -> Vector2:
	return Vector2(
		_island.position.x + t.x * TILE_SIZE + TILE_SIZE * 0.5,
		_island.position.y + t.y * TILE_SIZE + TILE_SIZE * 0.5
	)


func is_in_grid(p: Vector2) -> bool:
	return _island.has_point(p)


func can_place(t: Vector2i) -> bool:
	if tutorial_lock_tile != Vector2i(-1, -1) and t != tutorial_lock_tile:
		return false
	if t.x < 0 or t.x >= _cols or t.y < 0 or t.y >= _rows:
		return false
	if _path_blocked.has(t):
		return false
	return not _occupied.has(t)


func place(t: Vector2i) -> void:
	_occupied[t] = true


func unplace(t: Vector2i) -> void:
	_occupied.erase(t)


func _draw() -> void:
	# Highlight + grid outlines for every buildable (non-road-blocked) tile.
	# Two-pass: all fills first, then all outlines so no fill can overwrite a grid line.
	var highlight_c := Color(0.82, 0.94, 1.00, 0.30)
	var grid_c      := Color(1.0, 1.0, 1.0, 0.20)
	for c in range(_cols):
		for r in range(_rows):
			if not _path_blocked.has(Vector2i(c, r)):
				var x0 := _island.position.x + c * TILE_SIZE
				var y0 := _island.position.y + r * TILE_SIZE
				draw_rect(Rect2(x0, y0, TILE_SIZE, TILE_SIZE), highlight_c)
	for c in range(_cols):
		for r in range(_rows):
			if not _path_blocked.has(Vector2i(c, r)):
				var x0 := _island.position.x + c * TILE_SIZE
				var y0 := _island.position.y + r * TILE_SIZE
				_draw_tile_smart_outline(c, r, x0, y0, grid_c)

	# Special bonus tiles (World 2 Stage 5) — glass effect
	for t in special_tiles:
		var kind  : String = special_tiles[t]
		var y_off : float  = _get_tile_y_offset(t)
		var rx    : float  = _island.position.x + t.x * TILE_SIZE
		var ry    : float  = _island.position.y + t.y * TILE_SIZE
		var base_c : Color
		match kind:
			"red":   base_c = Color(0.95, 0.06, 0.06)
			"blue":  base_c = Color(0.08, 0.38, 1.0)
			"green": base_c = Color(0.05, 0.88, 0.22)
			_: continue
		# Drop shadow on the landing spot while tile is still in the air
		if y_off < -2.0:
			var fall_frac : float = clampf(1.0 - (-y_off / (-_ANIM_START_Y)), 0.0, 1.0)
			draw_rect(Rect2(rx + 4.0, ry + 5.0, TILE_SIZE, TILE_SIZE),
				Color(0.0, 0.0, 0.0, fall_frac * 0.40))
		_draw_glass_tile(rx, ry + y_off, base_c)

	# Landing impact rings
	for flash in _land_flashes:
		var tile   : Vector2i = flash["tile"]
		var ft     : float    = flash["t"]
		var kind   : String   = special_tiles.get(tile, "")
		var base_c : Color
		match kind:
			"red":   base_c = Color(1.0, 0.25, 0.25)
			"blue":  base_c = Color(0.25, 0.6,  1.0)
			"green": base_c = Color(0.25, 1.0,  0.40)
			_: continue
		var cx     : float = _island.position.x + tile.x * TILE_SIZE + TILE_SIZE * 0.5
		var cy     : float = _island.position.y + tile.y * TILE_SIZE + TILE_SIZE * 0.5
		var radius : float = TILE_SIZE * (0.5 + ft * 1.1)
		var alpha  : float = (1.0 - ft) * 0.80
		draw_circle(Vector2(cx, cy), radius, Color(base_c.r, base_c.g, base_c.b, alpha), false, 3.5)

	if tutorial_lock_tile != Vector2i(-1, -1):
		return  # TutorialOverlay handles the target highlight during move lock
	if hovered_tile.x < 0 or not can_place(hovered_tile):
		return

	var center := tile_center(hovered_tile)
	var half   := TILE_SIZE * 0.5

	draw_rect(
		Rect2(center.x - half, center.y - half, TILE_SIZE, TILE_SIZE),
		Color(1.0, 1.0, 1.0, 0.12)
	)
	draw_rect(
		Rect2(center.x - half, center.y - half, TILE_SIZE, TILE_SIZE),
		Color(1.0, 1.0, 1.0, 0.35), false, 1.5
	)

	var bob := sin(_time * 5.0) * 4.0
	var gp  := center + Vector2(0.0, bob - 6.0)
	var col := Color(1.0, 1.0, 1.0, 0.40)
	var rim := Color(1.0, 1.0, 1.0, 0.60)

	draw_circle(gp, 14.0, col)
	draw_circle(gp, 14.0, rim, false, 1.5)
	draw_rect(Rect2(gp.x - 4.0, gp.y - 22.0, 8.0, 12.0), col)
	draw_rect(Rect2(gp.x - 4.0, gp.y - 22.0, 8.0, 12.0), rim, false, 1.5)

	var shadow_alpha : float = 0.18 - abs(bob) * 0.012
	draw_circle(
		center + Vector2(0.0, half - 6.0),
		10.0 - abs(bob) * 0.5,
		Color(0.0, 0.0, 0.0, max(0.0, shadow_alpha))
	)


func _is_bg(c: int, r: int) -> bool:
	if c < 0 or c >= _cols or r < 0 or r >= _rows:
		return true
	return _path_blocked.has(Vector2i(c, r))


func _draw_tile_smart_outline(c: int, r: int, x0: float, y0: float, color: Color, rad: float = 8.0) -> void:
	var x1 := x0 + TILE_SIZE
	var y1 := y0 + TILE_SIZE

	# Always draw all 4 sides with draw_rect — guaranteed to be visible on every tile
	draw_rect(Rect2(x0, y0, TILE_SIZE, TILE_SIZE), color, false, 1.0)

	# Rounded arc only at outer corners (both adjacent sides face background).
	# Drawn on top of the rect outline to soften the corner.
	var bg_t := _is_bg(c, r - 1)
	var bg_r := _is_bg(c + 1, r)
	var bg_b := _is_bg(c, r + 1)
	var bg_l := _is_bg(c - 1, r)
	if bg_t and bg_l: draw_arc(Vector2(x0 + rad, y0 + rad), rad, PI,        PI * 1.5, 8, color)
	if bg_t and bg_r: draw_arc(Vector2(x1 - rad, y0 + rad), rad, -PI * 0.5, 0.0,      8, color)
	if bg_r and bg_b: draw_arc(Vector2(x1 - rad, y1 - rad), rad,  0.0,      PI * 0.5, 8, color)
	if bg_b and bg_l: draw_arc(Vector2(x0 + rad, y1 - rad), rad,  PI * 0.5, PI,       8, color)


func _draw_glass_tile(rx: float, ry: float, base: Color) -> void:
	var T := float(TILE_SIZE)

	# Layer 1 — opaque dark base (gives the glass depth and makes color pop)
	draw_rect(Rect2(rx, ry, T, T),
		Color(base.r * 0.12, base.g * 0.12, base.b * 0.12, 1.0))

	# Layer 2 — main glass body, richly coloured and semi-transparent
	draw_rect(Rect2(rx, ry, T, T), Color(base.r, base.g, base.b, 0.72))

	# Layer 3 — centre brightening (light refracting through the glass)
	var p := T * 0.18
	draw_rect(Rect2(rx + p, ry + p, T - p * 2.0, T - p * 2.0),
		Color(minf(base.r + 0.35, 1.0), minf(base.g + 0.35, 1.0), minf(base.b + 0.35, 1.0), 0.22))

	# Layer 4 — top-left diagonal reflection band (primary glass gloss)
	var hi := PackedVector2Array([
		Vector2(rx + 1,        ry + 1),
		Vector2(rx + T * 0.72, ry + 1),
		Vector2(rx + T * 0.38, ry + T * 0.44),
		Vector2(rx + 1,        ry + T * 0.44),
	])
	draw_colored_polygon(hi, Color(1.0, 1.0, 1.0, 0.20))

	# Layer 5 — small bright corner triangle (specular highlight / glint)
	var glint := PackedVector2Array([
		Vector2(rx + 2,        ry + 2),
		Vector2(rx + T * 0.30, ry + 2),
		Vector2(rx + 2,        ry + T * 0.30),
	])
	draw_colored_polygon(glint, Color(1.0, 1.0, 1.0, 0.55))

	# Layer 6 — bottom-right shadow (depth inside glass)
	var shd := PackedVector2Array([
		Vector2(rx + T * 0.52, ry + T - 1),
		Vector2(rx + T - 1,    ry + T - 1),
		Vector2(rx + T - 1,    ry + T * 0.52),
	])
	draw_colored_polygon(shd, Color(0.0, 0.0, 0.0, 0.22))

	# Layer 7 — bright outer border (crisp coloured edge)
	draw_rect(Rect2(rx, ry, T, T), Color(base.r, base.g, base.b, 1.0), false, 2.5)

	# Layer 8 — inner white border (thin glass-edge shimmer, inset by 2 px)
	draw_rect(Rect2(rx + 2, ry + 2, T - 4, T - 4), Color(1.0, 1.0, 1.0, 0.22), false, 1.0)
