extends Node2D
# ─────────────────────────────────────────────────────────────────────────────
# InfernalSerpent.gd
# Summoned battlefield creature from the Infernal Serpent fusion tower (5% proc).
# Travels the reverse of the current world's enemy path, one pass only.
# Rendered above terrain (z=1).
# ─────────────────────────────────────────────────────────────────────────────

const SPEED       : float = 270.0    # px/s ≈ 4.5 tiles/s
const SEG_COUNT   : int   = 14       # number of ribbon sample points
const SEG_DIST    : float = 18.0     # px between samples
const HEAD_R      : float = 14.0
const MOUTH_R     : float = 22.0     # bite hitbox radius
const PORTAL_DIST : float = 120.0

# ── State ──────────────────────────────────────────────────────────────────────
var _damage    : float = 100.0
var _traveled  : float = 0.0
var _total_len : float = 0.0
var _cum_lens  : Array = []
var _anim_time : float = 0.0
var _hit_set   : Array = []
var _embers    : Array = []
var _bite_fx   : Array = []

# Computed in setup() from the world's enemy path (reversed, one pass)
var _lap_path  : Array = []

# Call BEFORE add_child so _ready() sees the computed path.
func setup(dmg: float, enemy_path: Array = []) -> void:
	_damage   = dmg
	_lap_path = _make_serpent_path(enemy_path)

# Build the serpent's travel path: the enemy road reversed so the serpent
# moves from the enemy EXIT back to the enemy ENTRY.
# For worlds with repeated loops (W1, W5-W9), we extract one circuit.
# For figure-8 / crossing paths (W3, W8, W10) where the repeated waypoint
# is a mid-map crossing rather than a loop repetition, we use the full path.
static func _make_serpent_path(enemy_path: Array) -> Array:
	if enemy_path.size() < 2:
		return [Vector2(-40,140), Vector2(250,140), Vector2(250,500),
				Vector2(850,500), Vector2(850,140), Vector2(-40,140)]

	# Find the first repeated waypoint (marks where a loop closes or a road crosses itself).
	var cutoff : int = enemy_path.size()
	for i in range(1, enemy_path.size()):
		var found : bool = false
		for j in range(i):
			if enemy_path[i].distance_to(enemy_path[j]) < 5.0:
				found = true
				break
		if found:
			cutoff = i
			break

	var one_pass : Array
	if cutoff < enemy_path.size():
		var remaining : int = enemy_path.size() - cutoff
		# If remaining points after cutoff are fewer than 60% of the circuit
		# length, the repeated point is a road crossing (figure-8 / end-revisit),
		# NOT a repeated loop.  Use the full path to avoid a diagonal shortcut.
		if remaining * 10 < cutoff * 6:
			one_pass = enemy_path.duplicate()
		else:
			# True repeated loop — extract one circuit and close back to entry.
			one_pass = enemy_path.slice(0, cutoff)
			if (one_pass as Array).back().distance_to(enemy_path[0]) > 5.0:
				one_pass.append(enemy_path[0])
	else:
		one_pass = enemy_path.duplicate()

	# Reverse so serpent travels from exit → entry, opposite to enemies.
	(one_pass as Array).reverse()
	return one_pass

func _ready() -> void:
	z_index = 1
	# _lap_path should already be set by setup(); build cumulative lengths now.
	if _lap_path.is_empty():
		_lap_path = _make_serpent_path([])
	_build_path_data()

func _build_path_data() -> void:
	_cum_lens = [0.0]
	var t : float = 0.0
	for i in range(_lap_path.size() - 1):
		t += (_lap_path[i] as Vector2).distance_to(_lap_path[i + 1] as Vector2)
		_cum_lens.append(t)
	_total_len = t

# ── Path helpers ───────────────────────────────────────────────────────────────
func _path_pos(dist: float) -> Vector2:
	dist = clampf(dist, 0.0, _total_len)
	for i in range(_cum_lens.size() - 1):
		if dist <= _cum_lens[i + 1]:
			var seg_len : float = _cum_lens[i + 1] - _cum_lens[i]
			if seg_len < 0.001:
				return _lap_path[i + 1]
			return (_lap_path[i] as Vector2).lerp(_lap_path[i + 1] as Vector2,
					(dist - _cum_lens[i]) / seg_len)
	return _lap_path[-1]

func _path_dir(dist: float) -> Vector2:
	var p0 := _path_pos(dist)
	var p1 := _path_pos(minf(dist + 6.0, _total_len))
	var d  := p1 - p0
	return d.normalized() if d.length_squared() > 0.01 else Vector2.RIGHT

# ── Per-frame ──────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_anim_time += delta
	_traveled  += SPEED * delta

	if _traveled - (SEG_COUNT - 1) * SEG_DIST > _total_len:
		queue_free()
		return

	# Bite damage — head only
	if _traveled <= _total_len:
		var head_pos := _path_pos(_traveled)
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or e._dead or e in _hit_set:
				continue
			if e.position.distance_to(head_pos) <= MOUTH_R:
				e.take_damage(_damage)
				_hit_set.append(e)
				_bite_fx.append({"pos": head_pos, "r": 0.0, "life": 0.40})

	# Embers from body
	for i in range(SEG_COUNT):
		var sd : float = _traveled - i * SEG_DIST
		if sd < 0.0 or sd > _total_len or _embers.size() >= 80:
			continue
		if randf() < 0.22:
			var sp := _path_pos(sd)
			_embers.append({
				"x": sp.x + randf_range(-6.0, 6.0),
				"y": sp.y + randf_range(-6.0, 6.0),
				"vx": randf_range(-14.0, 14.0),
				"vy": randf_range(-40.0, -10.0),
				"life": randf_range(0.2, 0.5),
				"ml": 0.5,
			})

	for i in range(_embers.size() - 1, -1, -1):
		var em = _embers[i]
		em["life"] -= delta
		em["x"]    += em["vx"] * delta
		em["y"]    += em["vy"] * delta
		if em["life"] <= 0.0:
			_embers.remove_at(i)

	for i in range(_bite_fx.size() - 1, -1, -1):
		_bite_fx[i]["life"] -= delta
		_bite_fx[i]["r"]    += delta * 70.0
		if _bite_fx[i]["life"] <= 0.0:
			_bite_fx.remove_at(i)

	queue_redraw()

# ── Drawing ────────────────────────────────────────────────────────────────────
func _draw() -> void:
	_draw_portals()
	_draw_embers()
	_draw_body()
	_draw_bite_fx()

func _draw_portals() -> void:
	var in_t : float = 1.0 - clampf(_traveled / PORTAL_DIST, 0.0, 1.0)
	if in_t > 0.005:
		_draw_portal(_lap_path[0], in_t)
	var exit_start := _total_len - PORTAL_DIST
	if _traveled > exit_start:
		var ex_t := clampf((_traveled - exit_start) / PORTAL_DIST, 0.0, 1.0)
		_draw_portal(_lap_path[-1], ex_t)

func _draw_portal(pos: Vector2, intensity: float) -> void:
	var pulse := 0.88 + sin(_anim_time * 9.0) * 0.12
	var r     := 32.0 * intensity * pulse
	draw_circle(pos, r * 1.85, Color(0.90, 0.18, 0.0, 0.16 * intensity))
	draw_arc(pos, r, 0.0, TAU, 30, Color(1.00, 0.50, 0.0, 0.88 * intensity), 4.0)
	draw_circle(pos, r * 0.42, Color(1.00, 0.90, 0.30, 0.72 * intensity))
	var ra := _anim_time * 6.2
	draw_arc(pos, r * 0.72, ra, ra + TAU * 0.6, 16,
			 Color(1.00, 0.70, 0.10, 0.80 * intensity), 2.5)
	draw_arc(pos, r * 0.72, ra + PI, ra + PI + TAU * 0.3, 8,
			 Color(1.00, 0.50, 0.00, 0.60 * intensity), 2.0)

func _draw_embers() -> void:
	for em in _embers:
		var t := clampf(em["life"] / em["ml"], 0.0, 1.0)
		var col : Color
		if t > 0.65:
			col = Color(1.0, 1.0, 0.80, t)
		elif t > 0.35:
			col = Color(1.0, 0.65, 0.10, t)
		else:
			col = Color(0.9, 0.22, 0.04, t)
		draw_circle(Vector2(em["x"], em["y"]), maxf(1.2, 2.8 * t), col)

# ── Body ribbon ────────────────────────────────────────────────────────────────
func _draw_body() -> void:
	# Build per-segment data from tail (i=SEG_COUNT-1) to neck (i=1)
	var seg_data : Array = []
	for i in range(SEG_COUNT - 1, 0, -1):
		var sd : float = _traveled - i * SEG_DIST
		if sd < 0.0 or sd > _total_len:
			continue
		var frac : float  = 1.0 - float(i) / float(SEG_COUNT - 1)
		var pos           := _path_pos(sd)
		var dir           := _path_dir(sd)
		var perp          := Vector2(-dir.y, dir.x)
		var w    : float  = lerp(3.0, 10.5, frac)
		var wob  : float  = sin(_anim_time * 5.5 + float(i) * 0.7) * 4.5 * frac
		pos += perp * wob
		seg_data.append({"pos": pos, "perp": perp, "dir": dir, "w": w, "frac": frac})

	if seg_data.size() < 4:
		var hsd : float = _traveled
		if hsd >= 0.0 and hsd <= _total_len:
			var hd := _path_dir(hsd)
			_draw_head(_path_pos(hsd), hd, Vector2(-hd.y, hd.x))
		return

	# Precompute edge + centre point arrays
	var left_pts   : PackedVector2Array = []
	var right_pts  : PackedVector2Array = []
	var center_pts : PackedVector2Array = []
	for seg in seg_data:
		var _p  : Vector2 = seg["pos"]
		var _pe : Vector2 = seg["perp"]
		var _w  : float   = seg["w"]
		left_pts.append(_p + _pe * _w)
		right_pts.append(_p - _pe * _w)
		center_pts.append(_p)

	# ── Layer 1: Outer dark scale shell (wider by 2.5 px) ────────────────────────
	var outer_poly   : PackedVector2Array = []
	var outer_colors : PackedColorArray   = []
	for seg in seg_data:
		outer_poly.append(seg["pos"] + seg["perp"] * (seg["w"] + 2.5))
		outer_colors.append(Color(0.20, 0.03, 0.01, lerp(0.58, 0.88, seg["frac"])))
	for i in range(seg_data.size() - 1, -1, -1):
		var seg = seg_data[i]
		outer_poly.append(seg["pos"] - seg["perp"] * (seg["w"] + 2.5))
		outer_colors.append(Color(0.20, 0.03, 0.01, lerp(0.58, 0.88, seg["frac"])))
	draw_polygon(outer_poly, outer_colors)

	# ── Layer 2: Main molten body ─────────────────────────────────────────────────
	var main_poly   : PackedVector2Array = []
	var main_colors : PackedColorArray   = []
	for seg in seg_data:
		main_poly.append(seg["pos"] + seg["perp"] * seg["w"])
		main_colors.append(Color(0.84, 0.16, 0.03, lerp(0.75, 0.97, seg["frac"])))
	for i in range(seg_data.size() - 1, -1, -1):
		var seg = seg_data[i]
		main_poly.append(seg["pos"] - seg["perp"] * seg["w"])
		main_colors.append(Color(0.84, 0.16, 0.03, lerp(0.75, 0.97, seg["frac"])))
	draw_polygon(main_poly, main_colors)

	# ── Layer 3: Inner molten core strip (38 % of half-width) ────────────────────
	var core_poly   : PackedVector2Array = []
	var core_colors : PackedColorArray   = []
	for seg in seg_data:
		core_poly.append(seg["pos"] + seg["perp"] * seg["w"] * 0.38)
		core_colors.append(Color(1.0, 0.60, 0.06, lerp(0.22, 0.58, seg["frac"])))
	for i in range(seg_data.size() - 1, -1, -1):
		var seg = seg_data[i]
		core_poly.append(seg["pos"] - seg["perp"] * seg["w"] * 0.38)
		core_colors.append(Color(1.0, 0.60, 0.06, lerp(0.22, 0.58, seg["frac"])))
	draw_polygon(core_poly, core_colors)

	# ── Spine magma vein ──────────────────────────────────────────────────────────
	var mag_a : float = 0.46 + sin(_anim_time * 7.2) * 0.16
	draw_polyline(center_pts, Color(1.0, 0.88, 0.28, mag_a),        2.0)
	draw_polyline(center_pts, Color(1.0, 1.0,  0.82, mag_a * 0.48), 0.8)

	# ── Scale arcs ────────────────────────────────────────────────────────────────
	for i in range(1, left_pts.size() - 1):
		var l      : Vector2 = left_pts[i]
		var r      : Vector2 = right_pts[i]
		var mid    : Vector2 = (l + r) * 0.5
		var half_w : float   = l.distance_to(r) * 0.5
		if half_w < 3.0:
			continue
		var next_mid : Vector2 = (left_pts[i + 1] + right_pts[i + 1]) * 0.5
		var fwd      : Vector2 = (next_mid - mid).normalized()
		var arc_ctr  : Vector2 = mid + fwd * half_w * 0.65
		var arm      : Vector2 = l - arc_ctr
		var arc_r    : float   = arm.length()
		if arc_r < 1.5:
			continue
		var ang_l : float = arm.angle()
		var ang_r : float = (r - arc_ctr).angle()
		var diff  : float = fposmod(ang_r - ang_l, TAU)
		if diff > PI:
			var tmp : float = ang_l
			ang_l = ang_r
			ang_r = tmp
		var frac_i : float = float(i) / float(maxf(float(left_pts.size() - 1), 1.0))
		# Dark outer scale edge
		draw_arc(arc_ctr, arc_r,        ang_l, ang_r, 10, Color(0.14, 0.01, 0.0, lerp(0.28, 0.60, frac_i)), 2.2)
		# Orange highlight inside scale
		draw_arc(arc_ctr, arc_r * 0.68, ang_l, ang_r, 8,  Color(1.0, 0.50, 0.08, lerp(0.08, 0.26, frac_i)), 1.0)

	# ── Dark edge outlines ────────────────────────────────────────────────────────
	draw_polyline(left_pts,  Color(0.15, 0.02, 0.0, 0.68), 1.8)
	draw_polyline(right_pts, Color(0.15, 0.02, 0.0, 0.68), 1.8)

	# ── Flame tail tip ────────────────────────────────────────────────────────────
	var ts    = seg_data[0]
	var tp    : Vector2 = ts["pos"]
	var td    : Vector2 = ts["dir"]
	var tperp : Vector2 = ts["perp"]
	var tw    : float   = ts["w"]
	var ftail : float   = 0.55 + sin(_anim_time * 8.5) * 0.30
	# Outer flame tongue
	draw_colored_polygon(PackedVector2Array([
		tp + tperp * tw * 0.55,
		tp - tperp * tw * 0.55,
		tp - td * (7.0 + ftail * 5.0)
	]), Color(1.0, 0.52, 0.06, 0.82))
	# Inner bright tongue
	draw_colored_polygon(PackedVector2Array([
		tp + tperp * tw * 0.28,
		tp - tperp * tw * 0.28,
		tp - td * (10.0 + ftail * 7.0)
	]), Color(1.0, 0.86, 0.26, 0.65))
	draw_circle(tp - td * (9.0 + ftail * 4.0), 2.5, Color(1.0, 1.0, 0.72, 0.52))

	# ── Head (drawn last — on top of body) ───────────────────────────────────────
	var sd0 : float = _traveled
	if sd0 >= 0.0 and sd0 <= _total_len:
		var hpos := _path_pos(sd0)
		var hdir := _path_dir(sd0)
		_draw_head(hpos, hdir, Vector2(-hdir.y, hdir.x))

# ── Head — dragon face with crests, armored brow, slit eyes, forked tongue ─────
func _draw_head(pos: Vector2, dir: Vector2, perp: Vector2) -> void:
	var jaw_open  : float   = clampf(0.40 + sin(_anim_time * 9.5) * 0.38, 0.02, 0.78)
	var jaw_len   : float   = HEAD_R * 0.9
	var jaw_spread: float   = jaw_open * 9.0
	var jaw_root  : Vector2 = pos + dir * HEAD_R * 0.72
	var jaw_tip_u : Vector2 = jaw_root + dir * jaw_len + perp * jaw_spread
	var jaw_tip_l : Vector2 = jaw_root + dir * jaw_len - perp * jaw_spread

	# ── Flame aura ────────────────────────────────────────────────────────────────
	var ap : float = 0.82 + sin(_anim_time * 5.8) * 0.12
	draw_circle(pos, HEAD_R * 2.0 * ap,  Color(0.72, 0.10, 0.0, 0.18))
	draw_circle(pos, HEAD_R * 1.42 * ap, Color(0.96, 0.22, 0.0, 0.28))

	# ── Flame crests — swept-back horns from skull crown ──────────────────────────
	for _si in [1, -1]:
		var _sf : float   = float(_si)
		var cr  : Vector2 = pos + perp * HEAD_R * 0.52 * _sf - dir * HEAD_R * 0.12
		var ct  : Vector2 = cr  - dir * HEAD_R * 0.85 + perp * HEAD_R * 0.55 * _sf
		# Dark horn base
		draw_colored_polygon(PackedVector2Array([
			cr + perp * 3.2 * _sf, cr - perp * 1.5 * _sf, ct
		]), Color(0.28, 0.05, 0.01, 0.92))
		# Orange highlight
		draw_colored_polygon(PackedVector2Array([
			cr + perp * 2.0 * _sf, cr - perp * 0.8 * _sf, ct + perp * 0.8 * _sf
		]), Color(0.95, 0.45, 0.06, 0.75))
		# Hot tip
		draw_circle(ct, 2.8, Color(1.0, 0.88, 0.28, 0.80))

	# ── Skull (layered) ───────────────────────────────────────────────────────────
	draw_circle(pos, HEAD_R + 1.8, Color(0.20, 0.03, 0.01, 0.92))
	draw_circle(pos, HEAD_R,       Color(0.80, 0.14, 0.02, 0.97))

	# Armored brow plate
	draw_colored_polygon(PackedVector2Array([
		pos - perp * HEAD_R * 0.88 + dir * HEAD_R * 0.08,
		pos + perp * HEAD_R * 0.88 + dir * HEAD_R * 0.08,
		pos + perp * HEAD_R * 0.70 + dir * HEAD_R * 0.52,
		pos - perp * HEAD_R * 0.70 + dir * HEAD_R * 0.52,
	]), Color(0.60, 0.10, 0.02, 0.90))
	draw_colored_polygon(PackedVector2Array([
		pos - perp * HEAD_R * 0.82 + dir * HEAD_R * 0.10,
		pos + perp * HEAD_R * 0.82 + dir * HEAD_R * 0.10,
		pos + perp * HEAD_R * 0.62 + dir * HEAD_R * 0.22,
		pos - perp * HEAD_R * 0.62 + dir * HEAD_R * 0.22,
	]), Color(0.96, 0.24, 0.05, 0.48))

	# Snout hot glow
	draw_circle(pos + dir * HEAD_R * 0.30, HEAD_R * 0.52, Color(1.0, 0.72, 0.16, 0.62))

	# ── Eyes — glowing iris with slit pupils ──────────────────────────────────────
	for _si in [1, -1]:
		var _sf : float   = float(_si)
		var ep  : Vector2 = pos + perp * HEAD_R * 0.46 * _sf - dir * HEAD_R * 0.10
		draw_circle(ep, 6.0, Color(1.0, 0.90, 0.20, 0.32))   # outer glow halo
		draw_circle(ep, 4.8, Color(1.0, 0.88, 0.10, 1.0))    # iris
		# Vertical slit pupil (two triangles sharing the eye centre)
		draw_colored_polygon(PackedVector2Array([ep + perp * 1.0, ep - perp * 1.0, ep + dir * 3.2]),
			Color(0.04, 0.0, 0.0, 0.95))
		draw_colored_polygon(PackedVector2Array([ep + perp * 1.0, ep - perp * 1.0, ep - dir * 3.2]),
			Color(0.04, 0.0, 0.0, 0.95))
		draw_circle(ep - perp * 1.6 * _sf + dir * 1.2, 1.3, Color(1, 1, 1, 0.68))  # catch-light

	# ── Jaw bone lines (thicker, double-pass for depth) ───────────────────────────
	draw_line(jaw_root + perp * 3.0, jaw_tip_u, Color(0.98, 0.60, 0.10, 0.95), 3.5)
	draw_line(jaw_root - perp * 3.0, jaw_tip_l, Color(0.98, 0.60, 0.10, 0.95), 3.5)
	draw_line(jaw_root + perp * 3.0, jaw_tip_u, Color(0.28, 0.05, 0.01, 0.65), 1.2)
	draw_line(jaw_root - perp * 3.0, jaw_tip_l, Color(0.28, 0.05, 0.01, 0.65), 1.2)

	# ── Teeth (3 upper + 3 lower) ─────────────────────────────────────────────────
	var tooth_count : int   = 3
	var tooth_len   : float = jaw_open * 5.0 + 2.5

	for t in range(tooth_count):
		var tf   : float   = (float(t) + 0.5) / float(tooth_count)
		var tb_u : Vector2 = jaw_root.lerp(jaw_tip_u, tf)
		var tt_u : Vector2 = tb_u - perp * tooth_len
		draw_polygon(
			PackedVector2Array([tb_u + dir * 2.5, tb_u - dir * 2.5, tt_u]),
			PackedColorArray([Color.WHITE, Color.WHITE, Color(1.0, 0.92, 0.85, 0.85)])
		)
		var tb_l : Vector2 = jaw_root.lerp(jaw_tip_l, tf)
		var tt_l : Vector2 = tb_l + perp * tooth_len
		draw_polygon(
			PackedVector2Array([tb_l + dir * 2.5, tb_l - dir * 2.5, tt_l]),
			PackedColorArray([Color.WHITE, Color.WHITE, Color(1.0, 0.92, 0.85, 0.85)])
		)

	# ── Fire breath between open jaws ─────────────────────────────────────────────
	if jaw_open > 0.35:
		var flame_a : float   = jaw_open - 0.35
		var flame_p : Vector2 = jaw_root + dir * (jaw_len * 0.6)
		draw_circle(flame_p, flame_a * 14.0, Color(1.0, 0.78, 0.22, flame_a * 0.55))
		draw_circle(flame_p, flame_a * 8.0,  Color(1.0, 1.0,  0.70, flame_a * 0.38))

	# ── Forked tongue flicker ─────────────────────────────────────────────────────
	if jaw_open > 0.15:
		var tfa   : float   = 0.62 + sin(_anim_time * 13.0) * 0.30
		var troot : Vector2 = jaw_root + dir * jaw_len * 0.52
		draw_line(troot, troot + dir * 6.0 + perp * 3.5, Color(1.0, 0.30, 0.05, tfa), 1.2)
		draw_line(troot, troot + dir * 6.0 - perp * 3.5, Color(1.0, 0.30, 0.05, tfa), 1.2)

# ── Bite impact rings ──────────────────────────────────────────────────────────
func _draw_bite_fx() -> void:
	for bf in _bite_fx:
		var t := clampf(bf["life"] / 0.40, 0.0, 1.0)
		var p : Vector2 = bf["pos"]
		var r : float   = bf["r"]
		draw_circle(p, r, Color(1.0, 0.45, 0.0, t * 0.40))
		draw_arc(p, r, 0.0, TAU, 14, Color(1.0, 0.82, 0.20, t * 0.85), 2.2)
		if r > 6.0:
			draw_arc(p, r * 0.52, 0.0, TAU, 8, Color(1.0, 1.0, 0.65, t * 0.60), 1.2)
