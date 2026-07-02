extends Node2D
class_name BuildGrid

const TILE_SIZE : int   = 60
const ROAD_W    : float = 60.0

# World 1 keeps its original hardcoded island.
# Worlds 2-10 call setup_world() which sets these dynamically.
var _island  : Rect2    = Rect2(280, 170, 540, 300)
var _cols    : int      = 9
var _rows    : int      = 5
# Multi-zone support: when non-empty, tiles are split across independent Rect2 zones.
# Zone n occupies absolute cols [_zone_col_offsets[n], _zone_col_offsets[n+1]).
var _zones            : Array = []   # Array[Rect2]
var _zone_col_offsets : Array = []   # Array[int]

var _occupied          : Dictionary = {}   # Vector2i → true
var _path_blocked      : Dictionary = {}   # Vector2i → true (tiles under the road)
var special_tiles      : Dictionary = {}   # Vector2i → "red" | "blue" | "green" (W2 S5 bonuses)
var null_zone_tiles    : Dictionary = {}   # Vector2i → true (curse_null_zones debuff: -50% range)
var disabled_tiles     : Dictionary = {}   # Vector2i → true (towers currently disabled by debuff)
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
	_zones  = GameData.get_world_zones(world)
	_occupied.clear()
	_path_blocked.clear()
	special_tiles.clear()
	null_zone_tiles.clear()
	_tile_anims.clear()
	_land_flashes.clear()
	_tiles_animating   = false
	tutorial_lock_tile = Vector2i(-1, -1)
	_zone_col_offsets.clear()
	if _zones.is_empty():
		_cols = int(_island.size.x) / TILE_SIZE
		_rows = int(_island.size.y) / TILE_SIZE
		if world > 1:
			_compute_path_blocked(path)
			_trim_to_target(world)
			_auto_compute_zones()
	if not _zones.is_empty() and _zone_col_offsets.is_empty():
		var off := 0
		var max_rows := 0
		for zr : Rect2 in _zones:
			_zone_col_offsets.append(off)
			off      += int(zr.size.x) / TILE_SIZE
			max_rows  = max(max_rows, int(zr.size.y) / TILE_SIZE)
		_cols = off
		_rows = max_rows
	queue_redraw()


# Max buildable tiles per world (from design spec). World 1 is always 45 (no path blocking).
const _WORLD_MAX_TILES : Dictionary = {
	2: 44, 3: 40, 4: 45, 5: 36, 6: 38, 7: 36, 8: 45, 9: 45, 10: 45
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


func _tile_zone_idx(t: Vector2i) -> int:
	if _zone_col_offsets.is_empty():
		return -1
	for i in range(_zone_col_offsets.size() - 1):
		if t.x < _zone_col_offsets[i + 1]:
			return i
	return _zone_col_offsets.size() - 1

func _tile_local_col(t: Vector2i) -> int:
	var z := _tile_zone_idx(t)
	return t.x - _zone_col_offsets[z] if z >= 0 else t.x


func _auto_compute_zones() -> void:
	var buildable : Dictionary = {}
	for c in range(_cols):
		for r in range(_rows):
			if not _path_blocked.has(Vector2i(c, r)):
				buildable[Vector2i(c, r)] = true
	if buildable.is_empty():
		return
	var visited    : Dictionary = {}
	var components : Array      = []
	var keys : Array = buildable.keys()
	for ki in range(keys.size()):
		var tile : Vector2i = keys[ki]
		if visited.has(tile):
			continue
		var comp  : Array = []
		var stack : Array = [tile]
		while not stack.is_empty():
			var t : Vector2i = stack.pop_back()
			if visited.has(t) or not buildable.has(t):
				continue
			visited[t] = true
			comp.append(t)
			var neighbors := [Vector2i(t.x+1,t.y), Vector2i(t.x-1,t.y), Vector2i(t.x,t.y+1), Vector2i(t.x,t.y-1)]
			for ni in range(neighbors.size()):
				var nb : Vector2i = neighbors[ni]
				if buildable.has(nb) and not visited.has(nb):
					stack.append(nb)
		if not comp.is_empty():
			components.append(comp)
	if components.size() <= 1:
		return
	components.sort_custom(func(a, b):
		var ax := 999999
		var ay := 999999
		var bx := 999999
		var by := 999999
		for i in range(a.size()):
			var t : Vector2i = a[i]
			if t.x < ax: ax = t.x
			if t.y < ay: ay = t.y
		for i in range(b.size()):
			var t : Vector2i = b[i]
			if t.x < bx: bx = t.x
			if t.y < by: by = t.y
		if ax != bx:
			return ax < bx
		return ay < by
	)
	_zones.clear()
	_zone_col_offsets.clear()
	var new_blocked : Dictionary = {}
	var abs_col     : int        = 0
	for ci in range(components.size()):
		var comp : Array = components[ci]
		var min_c := 999999
		var min_r := 999999
		var max_c := -999999
		var max_r := -999999
		for i in range(comp.size()):
			var t : Vector2i = comp[i]
			if t.x < min_c: min_c = t.x
			if t.y < min_r: min_r = t.y
			if t.x > max_c: max_c = t.x
			if t.y > max_r: max_r = t.y
		var zcols := max_c - min_c + 1
		var zrows := max_r - min_r + 1
		_zones.append(Rect2(
			_island.position.x + min_c * TILE_SIZE,
			_island.position.y + min_r * TILE_SIZE,
			zcols * TILE_SIZE, zrows * TILE_SIZE))
		_zone_col_offsets.append(abs_col)
		var comp_set : Dictionary = {}
		for i in range(comp.size()):
			comp_set[comp[i]] = true
		for lc in range(zcols):
			for lr in range(zrows):
				if not comp_set.has(Vector2i(min_c + lc, min_r + lr)):
					new_blocked[Vector2i(abs_col + lc, lr)] = true
		abs_col += zcols
	_cols = abs_col
	var max_rows := 0
	for zi in range(_zones.size()):
		var zr : Rect2 = _zones[zi]
		max_rows = max(max_rows, int(zr.size.y) / TILE_SIZE)
	_rows         = max_rows
	_path_blocked = new_blocked


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
	if _zones.is_empty():
		return Vector2i(
			int((p.x - _island.position.x) / TILE_SIZE),
			int((p.y - _island.position.y) / TILE_SIZE)
		)
	for z in range(_zones.size()):
		var zr : Rect2 = _zones[z]
		if zr.has_point(p):
			return Vector2i(
				_zone_col_offsets[z] + int((p.x - zr.position.x) / TILE_SIZE),
				int((p.y - zr.position.y) / TILE_SIZE)
			)
	return Vector2i(-1, -1)


func tile_center(t: Vector2i) -> Vector2:
	if _zones.is_empty():
		return Vector2(
			_island.position.x + t.x * TILE_SIZE + TILE_SIZE * 0.5,
			_island.position.y + t.y * TILE_SIZE + TILE_SIZE * 0.5
		)
	var z  := _tile_zone_idx(t)
	var lc := _tile_local_col(t)
	var zr : Rect2 = _zones[z]
	return Vector2(
		zr.position.x + lc * TILE_SIZE + TILE_SIZE * 0.5,
		zr.position.y + t.y * TILE_SIZE + TILE_SIZE * 0.5
	)


func is_in_grid(p: Vector2) -> bool:
	if _zones.is_empty():
		return _island.has_point(p)
	for zr : Rect2 in _zones:
		if zr.has_point(p):
			return true
	return false


func can_place(t: Vector2i) -> bool:
	if tutorial_lock_tile != Vector2i(-1, -1) and t != tutorial_lock_tile:
		return false
	if _zones.is_empty():
		if t.x < 0 or t.x >= _cols or t.y < 0 or t.y >= _rows:
			return false
		if _path_blocked.has(t):
			return false
	else:
		var z := _tile_zone_idx(t)
		if z < 0 or z >= _zones.size():
			return false
		var lc := _tile_local_col(t)
		var zr : Rect2 = _zones[z]
		if lc < 0 or lc >= int(zr.size.x) / TILE_SIZE:
			return false
		if t.y < 0 or t.y >= int(zr.size.y) / TILE_SIZE:
			return false
		if _path_blocked.has(t):
			return false
	return not _occupied.has(t)


func place(t: Vector2i) -> void:
	_occupied[t] = true


func unplace(t: Vector2i) -> void:
	_occupied.erase(t)


func _draw() -> void:
	var highlight_c := Color(0.82, 0.94, 1.00, 0.30)
	var grid_c      := Color(1.0, 1.0, 1.0, 0.20)
	if _zones.is_empty():
		_draw_single_grid(highlight_c, grid_c)
	else:
		for z in range(_zones.size()):
			_draw_zone(z, highlight_c, grid_c)

	# Special bonus tiles (World 2 Stage 5) — glass effect
	for t in special_tiles:
		var kind  : String = special_tiles[t]
		var y_off : float  = _get_tile_y_offset(t)
		var tc    : Vector2 = tile_center(t)
		var rx    : float   = tc.x - TILE_SIZE * 0.5
		var ry    : float   = tc.y - TILE_SIZE * 0.5
		var base_c : Color
		match kind:
			"red":   base_c = Color(0.95, 0.06, 0.06)
			"blue":  base_c = Color(0.08, 0.38, 1.0)
			"green": base_c = Color(0.05, 0.88, 0.22)
			_: continue
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
		var tc     : Vector2 = tile_center(tile)
		var radius : float   = TILE_SIZE * (0.5 + ft * 1.1)
		var alpha  : float   = (1.0 - ft) * 0.80
		draw_circle(tc, radius, Color(base_c.r, base_c.g, base_c.b, alpha), false, 3.5)

	# Null zone debuff tiles
	for t in null_zone_tiles:
		var tc := tile_center(t)
		_draw_null_zone_tile(tc.x - TILE_SIZE * 0.5, tc.y - TILE_SIZE * 0.5)

	# Disabled tower tiles (Curse of Silence / tower_rot)
	for t in disabled_tiles:
		var tc := tile_center(t)
		_draw_disabled_tile(tc.x - TILE_SIZE * 0.5, tc.y - TILE_SIZE * 0.5)

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


func _draw_single_grid(highlight_c: Color, grid_c: Color) -> void:
	for c in range(_cols):
		for r in range(_rows):
			if not _path_blocked.has(Vector2i(c, r)):
				var x0 := _island.position.x + c * TILE_SIZE
				var y0 := _island.position.y + r * TILE_SIZE
				draw_rect(Rect2(x0, y0, TILE_SIZE, TILE_SIZE), highlight_c)
	for cx_i in range(_cols + 1):
		var cx := _island.position.x + cx_i * float(TILE_SIZE)
		for r in range(_rows):
			var left_ok  := cx_i > 0     and not _path_blocked.has(Vector2i(cx_i - 1, r))
			var right_ok := cx_i < _cols and not _path_blocked.has(Vector2i(cx_i, r))
			if left_ok or right_ok:
				var y0 := _island.position.y + r * float(TILE_SIZE)
				draw_line(Vector2(cx, y0), Vector2(cx, y0 + float(TILE_SIZE)), grid_c, 1.0)
	for ry_i in range(_rows + 1):
		var ry := _island.position.y + ry_i * float(TILE_SIZE)
		for c in range(_cols):
			var top_ok    := ry_i > 0      and not _path_blocked.has(Vector2i(c, ry_i - 1))
			var bottom_ok := ry_i < _rows  and not _path_blocked.has(Vector2i(c, ry_i))
			if top_ok or bottom_ok:
				var x0 := _island.position.x + c * float(TILE_SIZE)
				draw_line(Vector2(x0, ry), Vector2(x0 + float(TILE_SIZE), ry), grid_c, 1.0)
	for c in range(_cols):
		for r in range(_rows):
			if not _path_blocked.has(Vector2i(c, r)):
				var x0 := _island.position.x + c * float(TILE_SIZE)
				var y0 := _island.position.y + r * float(TILE_SIZE)
				_draw_tile_corner_arcs(c, r, x0, y0, grid_c)


func _draw_zone(z: int, highlight_c: Color, grid_c: Color) -> void:
	var zr      : Rect2 = _zones[z]
	var zcols   : int   = int(zr.size.x) / TILE_SIZE
	var zrows   : int   = int(zr.size.y) / TILE_SIZE
	var col_off : int   = _zone_col_offsets[z]
	for lc in range(zcols):
		for lr in range(zrows):
			if _path_blocked.has(Vector2i(col_off + lc, lr)):
				continue
			var x0 := zr.position.x + lc * TILE_SIZE
			var y0 := zr.position.y + lr * TILE_SIZE
			draw_rect(Rect2(x0, y0, TILE_SIZE, TILE_SIZE), highlight_c)
	for cx_i in range(zcols + 1):
		var cx := zr.position.x + cx_i * float(TILE_SIZE)
		for lr in range(zrows):
			var left_ok  := cx_i > 0     and not _path_blocked.has(Vector2i(col_off + cx_i - 1, lr))
			var right_ok := cx_i < zcols and not _path_blocked.has(Vector2i(col_off + cx_i, lr))
			if left_ok or right_ok:
				var y0 := zr.position.y + lr * float(TILE_SIZE)
				draw_line(Vector2(cx, y0), Vector2(cx, y0 + float(TILE_SIZE)), grid_c, 1.0)
	for ry_i in range(zrows + 1):
		var ry := zr.position.y + ry_i * float(TILE_SIZE)
		for lc in range(zcols):
			var top_ok    := ry_i > 0     and not _path_blocked.has(Vector2i(col_off + lc, ry_i - 1))
			var bottom_ok := ry_i < zrows and not _path_blocked.has(Vector2i(col_off + lc, ry_i))
			if top_ok or bottom_ok:
				var x0 := zr.position.x + lc * float(TILE_SIZE)
				draw_line(Vector2(x0, ry), Vector2(x0 + float(TILE_SIZE), ry), grid_c, 1.0)
	for lc in range(zcols):
		for lr in range(zrows):
			if _path_blocked.has(Vector2i(col_off + lc, lr)):
				continue
			var x0 := zr.position.x + lc * float(TILE_SIZE)
			var y0 := zr.position.y + lr * float(TILE_SIZE)
			_draw_tile_corner_arcs(lc, lr, x0, y0, grid_c, 8.0, zcols, zrows)


func _is_bg(c: int, r: int) -> bool:
	if _zones.is_empty():
		if c < 0 or c >= _cols or r < 0 or r >= _rows:
			return true
		return _path_blocked.has(Vector2i(c, r))
	# In multi-zone mode treat out-of-zone neighbours as bg
	if c < 0 or r < 0:
		return true
	return not can_place(Vector2i(c, r))


func _draw_tile_corner_arcs(c: int, r: int, x0: float, y0: float, color: Color, rad: float = 8.0, zone_max_c: int = -1, zone_max_r: int = -1) -> void:
	var x1  := x0 + float(TILE_SIZE)
	var y1  := y0 + float(TILE_SIZE)
	var bg_t : bool
	var bg_r : bool
	var bg_b : bool
	var bg_l : bool
	if zone_max_c >= 0:
		# Zone-local coords: c and r are local within the zone
		bg_t = r <= 0
		bg_r = c + 1 >= zone_max_c
		bg_b = r + 1 >= zone_max_r
		bg_l = c <= 0
	else:
		bg_t = _is_bg(c, r - 1)
		bg_r = _is_bg(c + 1, r)
		bg_b = _is_bg(c, r + 1)
		bg_l = _is_bg(c - 1, r)
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


func _draw_null_zone_tile(rx: float, ry: float) -> void:
	var T   := float(TILE_SIZE)
	var p   := T * 0.18
	# Pulsing alpha so the zone draws the eye
	var pulse : float = 0.55 + sin(_time * 2.8) * 0.15
	# Dark crimson fill
	draw_rect(Rect2(rx, ry, T, T), Color(0.22, 0.02, 0.02, 0.70))
	# Hatched diagonal lines (interference pattern)
	var step : float = T / 4.0
	for i in range(5):
		var off := i * step
		draw_line(Vector2(rx,       ry + off), Vector2(rx + off,       ry),
			Color(0.80, 0.08, 0.08, 0.40 * pulse), 1.0)
		draw_line(Vector2(rx + off, ry + T),   Vector2(rx + T, ry + off),
			Color(0.80, 0.08, 0.08, 0.40 * pulse), 1.0)
	# Bold X
	draw_line(Vector2(rx + p, ry + p), Vector2(rx + T - p, ry + T - p),
		Color(0.95, 0.15, 0.15, 0.85 * pulse), 2.5)
	draw_line(Vector2(rx + T - p, ry + p), Vector2(rx + p, ry + T - p),
		Color(0.95, 0.15, 0.15, 0.85 * pulse), 2.5)
	# Outer border
	draw_rect(Rect2(rx, ry, T, T), Color(0.90, 0.12, 0.12, 0.90 * pulse), false, 2.0)


func _draw_disabled_tile(rx: float, ry: float) -> void:
	var T   := float(TILE_SIZE)
	var cx  := rx + T * 0.5
	# Reddish-purple tinted background
	var bg_pulse : float = 0.50 + sin(_time * 3.5) * 0.12
	draw_rect(Rect2(rx, ry, T, T), Color(0.42, 0.05, 0.38, 0.62 * bg_pulse))
	draw_rect(Rect2(rx, ry, T, T), Color(0.75, 0.10, 0.65, 0.80 * bg_pulse), false, 2.0)
	# Two staggered falling arrows (period = 0.7s each, offset by half)
	var period  : float = 0.70
	var arr_w   : float = 10.0
	var arr_h   : float = 8.0
	var travel  : float = T - 16.0   # usable vertical space inside tile
	for i in range(2):
		var t : float = fmod(_time + i * (period * 0.5), period) / period  # 0→1
		var ay : float = ry + 8.0 + t * travel
		# Fade in at top, fade out at bottom — peak alpha at mid-travel
		var alpha : float = sin(t * PI) * 0.90
		var tip   := Vector2(cx,              ay + arr_h)
		var left  := Vector2(cx - arr_w * 0.5, ay)
		var right := Vector2(cx + arr_w * 0.5, ay)
		draw_colored_polygon(PackedVector2Array([left, right, tip]),
			Color(0.95, 0.20, 0.85, alpha))
		# Thin stem above the arrowhead
		draw_line(Vector2(cx, ay - arr_h * 0.6), Vector2(cx, ay),
			Color(0.95, 0.20, 0.85, alpha * 0.70), 1.5)
