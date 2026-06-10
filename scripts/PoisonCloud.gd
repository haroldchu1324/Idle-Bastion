extends Node2D
# Persistent poison cloud spawned by the Venom Drake.
# Expands along the enemy path over EXPAND_TIME seconds.
# Enemies touching the cloud take TICK_DAMAGE per second.
# Visual: sparse, animated cloud blobs with organic gaps —
#   never a solid overlay, path and enemies always readable.

const EXPAND_TIME  : float = 10.0   # seconds to cover full path
const TICK_DAMAGE  : float = 2.0    # damage per second to enemies in cloud
const SAMPLE_DIST  : float = 8.0    # path sample spacing (pixels)
const CLOUD_RADIUS : float = 50.0   # damage hitbox radius per sample point

var _sampled    : PackedVector2Array = PackedVector2Array()
var _start_idx  : int   = 0
var _coverage   : float = 0.0   # 0.0 → 1.0
var _tick_timer : float = 0.0
var _anim_time  : float = 0.0

# Per-sample noise data, generated once in setup() for organic variation.
# Each entry: {dx, dy, r, phase, spd, skip}
var _noise : Array = []


func setup(path: Array, tower_pos: Vector2) -> void:
	# Build dense sample array from path waypoints
	_sampled.clear()
	for i in range(path.size() - 1):
		var a : Vector2 = path[i]
		var b : Vector2 = path[i + 1]
		var steps : int = max(1, int(a.distance_to(b) / SAMPLE_DIST))
		for s in range(steps):
			_sampled.append(a.lerp(b, float(s) / float(steps)))
	if path.size() > 0:
		_sampled.append(path[-1])

	# Find the sample point nearest to the tower
	var best_idx  : int   = 0
	var best_dist : float = INF
	for i in range(_sampled.size()):
		var d : float = tower_pos.distance_to(_sampled[i])
		if d < best_dist:
			best_dist = d
			best_idx  = i
	_start_idx  = best_idx
	_coverage   = 0.0
	_tick_timer = 0.0
	_anim_time  = 0.0

	# Pre-generate per-sample noise (deterministic seed = consistent look)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9731
	_noise.clear()
	for _k in range(_sampled.size()):
		_noise.append({
			"dx":    rng.randf_range(-15.0, 15.0),   # static offset X
			"dy":    rng.randf_range(-15.0, 15.0),   # static offset Y
			"r":     rng.randf_range(0.55, 1.45),    # size multiplier
			"phase": rng.randf_range(0.0, TAU),      # animation phase
			"spd":   rng.randf_range(0.18, 0.60),    # drift speed
			"skip":  rng.randf() > 0.72,             # ~28% are invisible gaps
		})

	add_to_group("poison_clouds")


func reset_cloud() -> void:
	_coverage   = 0.0
	_tick_timer = 0.0


func _process(delta: float) -> void:
	_anim_time += delta
	_coverage = minf(_coverage + delta / EXPAND_TIME, 1.0)
	queue_redraw()

	_tick_timer += delta
	if _tick_timer >= 1.0:
		_tick_timer -= 1.0
		_apply_damage()


func _apply_damage() -> void:
	var covered : Array = _covered_points()
	if covered.is_empty():
		return
	var venom_count : int = 0
	for t in get_tree().get_nodes_in_group("towers"):
		if is_instance_valid(t) and t.tower_data.get("effect", "") == "poison_cloud":
			venom_count += 1
	var total_dmg : float = TICK_DAMAGE * max(1, venom_count)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		for pt in covered:
			if (enemy.position - pt).length() <= CLOUD_RADIUS:
				enemy.take_damage(total_dmg)
				break   # one hit per tick per enemy


func _covered_points() -> Array:
	var n : int = _sampled.size()
	if n == 0:
		return []
	var half : int = int(_coverage * (n / 2.0))
	var pts  : Array = []
	for i in range(half + 1):
		var l : int = (_start_idx - i + n) % n
		var r : int = (_start_idx + i) % n
		pts.append(_sampled[l])
		if r != l:
			pts.append(_sampled[r])
	return pts


func _draw() -> void:
	if _sampled.is_empty() or _coverage <= 0.001:
		return
	if _noise.size() != _sampled.size():
		return

	var n    : int = _sampled.size()
	var half : int = int(_coverage * (n / 2.0))
	if half == 0:
		return

	# Draw one blob cluster every STEP samples (~48 px apart).
	# This ensures blobs barely overlap so alphas don't compound into a wall.
	const STEP : int = 6

	for i in range(0, half + 1, STEP):
		# Smooth fade-in at the coverage frontier (new fog fades in over 2×STEP)
		var fade : float = clampf(float(half - i) / float(STEP * 2), 0.0, 1.0)
		if fade <= 0.0:
			continue

		# One index on each side of the expansion origin
		var idxs : Array
		if i == 0:
			idxs = [_start_idx]
		else:
			idxs = [(_start_idx - i + n) % n, (_start_idx + i) % n]

		for idx in idxs:
			var nd : Dictionary = _noise[idx]
			if nd["skip"]:
				continue   # deliberate gap — makes the cloud look organic

			var pt    : Vector2 = _sampled[idx]
			var phase : float   = nd["phase"]
			var spd   : float   = nd["spd"]
			var rmul  : float   = nd["r"]

			# Primary drift — slow sinusoidal swirl
			var drift : Vector2 = Vector2(
				nd["dx"] + sin(_anim_time * spd        + phase      ) * 11.0,
				nd["dy"] + cos(_anim_time * spd * 0.75 + phase + 1.2) * 11.0
			)

			# Secondary drift — independent motion for the detail blob
			var drift2 : Vector2 = Vector2(
				sin(_anim_time * spd * 1.40 + phase + 2.3) * 13.0,
				cos(_anim_time * spd * 1.10 + phase + 0.6) * 13.0
			)

			# Gentle breathing pulse
			var pulse : float = 0.78 + 0.22 * sin(_anim_time * 1.15 + phase)
			var base  : float = fade * pulse

			# ── Blob A: large, soft outer haze ────────────────────────────
			# Anchored loosely to path, creates the overall cloud shape.
			draw_circle(pt + drift * 0.4, 40.0 * rmul,
				Color(0.65, 0.45, 0.90, 0.12 * base))

			# ── Blob B: medium drifting body ──────────────────────────────
			# Offset by full drift, slightly brighter purple.
			draw_circle(pt + drift, 27.0 * rmul,
				Color(0.75, 0.55, 0.95, 0.14 * base))

			# ── Blob C: small independent secondary ───────────────────────
			# Uses drift2 for irregular, wispy edge detail.
			draw_circle(pt + drift2, 20.0 * rmul,
				Color(0.70, 0.50, 0.92, 0.10 * base))
