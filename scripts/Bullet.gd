# scripts/Bullet.gd
# ─────────────────────────────────────────────────────────────────────────────
# Homing projectile (normal) or straight-line sword (knight).
# ─────────────────────────────────────────────────────────────────────────────
extends Node2D


var _target     : Node2D = null
var _damage     : float  = 3.0
var _speed      : float  = 480.0
var bullet_type : String = "normal"

var _straight  : bool    = false
var _direction : Vector2 = Vector2.ZERO
var _dist      : float   = 0.0
const _MAX_DIST : float  = 1600.0

var _lifetime  : float = 0.0
const _MAX_LIFETIME : float = 4.0
var _prev_dist : float = INF

# Ice-zone state
var _is_zone    : bool    = false
var _zone_timer : float   = 5.0   # zone stays on ground for 5 seconds
var _zone_radius: float   = 45.0
var _target_pos : Vector2 = Vector2.ZERO
var _landed     : bool    = false


func setup(target: Node2D, damage: float) -> void:
	_target = target
	_damage = damage


func set_straight(dir: Vector2) -> void:
	_straight  = true
	_direction = dir.normalized()


func _process(delta: float) -> void:
	if _is_zone:
		_process_ice_zone(delta)
		return

	if _straight:
		position += _direction * _speed * delta
		_dist    += _speed * delta
		queue_redraw()
		if _dist >= _MAX_DIST:
			queue_free()
			return
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if position.distance_to(enemy.position) < 20.0:
				enemy.take_damage(_damage)
				queue_free()
				return
		return

	_lifetime += delta
	if _lifetime > _MAX_LIFETIME:
		queue_free()
		return

	if not is_instance_valid(_target):
		queue_free()
		return

	var dir  : Vector2 = _target.position - position
	var dist : float   = dir.length()
	var hit_r : float  = 30.0 if bullet_type == "sword" else 8.0
	# Hit if close enough, or if we overshot (moving away after being very close)
	if dist < hit_r or (dist > _prev_dist and _prev_dist < hit_r * 3.0):
		_target.take_damage(_damage)
		queue_free()
		return

	_prev_dist = dist
	position += dir.normalized() * _speed * delta
	queue_redraw()


func _process_ice_zone(delta: float) -> void:
	queue_redraw()
	if not _landed:
		var dir  := _target_pos - position
		var dist := dir.length()
		if dist < 8.0:
			_landed  = true
			position = _target_pos
			add_to_group("ice_zones")
			# Remove any overlapping landed zones to prevent flickering pileup
			for other in get_tree().get_nodes_in_group("ice_zones"):
				if other != self and is_instance_valid(other) and other._landed:
					if position.distance_to(other.position) < _zone_radius * 0.8:
						other.queue_free()
		else:
			position += dir.normalized() * _speed * delta
	else:
		_zone_timer -= delta
		if _zone_timer <= 0.0:
			queue_free()
			return
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if position.distance_to(enemy.position) < _zone_radius:
				enemy.apply_slow(3.0, 0.45)


func _draw() -> void:
	match bullet_type:
		"sword":
			var angle := _direction.angle() + PI * 0.5 if _straight else \
						 ((_target.position - position).angle() + PI * 0.5 if is_instance_valid(_target) else 0.0)
			draw_set_transform(Vector2.ZERO, angle)
			draw_rect(Rect2(-3, -16, 6, 22), Color(0.85, 0.88, 0.96))
			draw_rect(Rect2(-3, -16, 6, 22), Color(0.55, 0.58, 0.68), false, 1.2)
			draw_rect(Rect2(-8,  4, 16,  4), Color(0.82, 0.70, 0.22))
			draw_rect(Rect2(-2,  8,  4,  8), Color(0.50, 0.30, 0.12))
			draw_set_transform(Vector2.ZERO, 0.0)
		"arrow":
			_draw_arrow_proj()
		"bomb":
			_draw_bomb_proj()
		"ice_zone":
			_draw_ice_zone_proj()
		_:
			draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.85, 0.1))
			draw_circle(Vector2.ZERO, 3.5, Color(1.0, 1.0, 0.7))


func _draw_arrow_proj() -> void:
	var angle := _direction.angle() + PI * 0.5 if _straight else \
				 ((_target.position - position).angle() + PI * 0.5 if is_instance_valid(_target) else 0.0)
	draw_set_transform(Vector2.ZERO, angle)
	# Shaft
	draw_rect(Rect2(-1.5, -12, 3, 18), Color(0.90, 0.94, 1.00))
	# Head
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -18), Vector2(-5, -10), Vector2(5, -10)
	]), Color(1.00, 1.00, 1.00))
	# Fletching
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4, 4), Vector2(0, 4), Vector2(-1, 10)
	]), Color(0.78, 0.84, 1.00))
	draw_colored_polygon(PackedVector2Array([
		Vector2(4, 4), Vector2(0, 4), Vector2(1, 10)
	]), Color(0.78, 0.84, 1.00))
	draw_set_transform(Vector2.ZERO, 0.0)


func _draw_bomb_proj() -> void:
	# Shadow
	draw_circle(Vector2(2, 2), 8, Color(0, 0, 0, 0.28))
	# Body
	draw_circle(Vector2.ZERO, 9, Color(0.10, 0.10, 0.12))
	draw_circle(Vector2.ZERO, 9, Color(0.30, 0.30, 0.32), false, 1.5)
	# Highlight
	draw_circle(Vector2(-3, -3), 3, Color(0.38, 0.38, 0.40, 0.65))
	# Fuse cord
	draw_line(Vector2(0, -9), Vector2(3, -15), Color(0.42, 0.28, 0.10), 2.0)
	draw_line(Vector2(3, -15), Vector2(6, -12), Color(0.42, 0.28, 0.10), 2.0)
	# Spark
	draw_circle(Vector2(6, -12), 3.5, Color(1.00, 0.68, 0.10, 0.95))
	draw_circle(Vector2(6, -12), 1.8, Color(1.00, 1.00, 0.55))


func _draw_ice_zone_proj() -> void:
	if not _landed:
		# Flying shard
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, -13), Vector2(-5, 0), Vector2(0, 7), Vector2(5, 0)
		]), Color(0.70, 0.92, 1.00, 0.92))
		draw_polyline(PackedVector2Array([
			Vector2(0, -13), Vector2(-5, 0), Vector2(0, 7), Vector2(5, 0), Vector2(0, -13)
		]), Color(1.00, 1.00, 1.00, 0.45), 1.2)
		draw_circle(Vector2(0, -4), 3, Color(1.00, 1.00, 1.00, 0.75))
	else:
		var a := clampf(_zone_timer / 5.0, 0.0, 1.0)
		# Slow zone ground area
		draw_circle(Vector2.ZERO, _zone_radius, Color(0.50, 0.82, 1.00, 0.12 * a))
		draw_arc(Vector2.ZERO, _zone_radius, 0.0, TAU, 36,
			Color(0.60, 0.88, 1.00, 0.50 * a), 2.0)
		# Outer ring
		draw_arc(Vector2.ZERO, _zone_radius - 4, 0.0, TAU, 36,
			Color(0.80, 0.95, 1.00, 0.25 * a), 1.0)
		# Mini crystals around edge
		for i in range(6):
			var ang := i * TAU / 6.0
			var cp  := Vector2(cos(ang), sin(ang)) * 22.0
			draw_colored_polygon(PackedVector2Array([
				cp + Vector2(0, -7), cp + Vector2(-3, 2), cp + Vector2(3, 2)
			]), Color(0.72, 0.92, 1.00, 0.72 * a))
		# Centre shard
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, -18), Vector2(-8, 2), Vector2(0, 9), Vector2(8, 2)
		]), Color(0.82, 0.96, 1.00, 0.88 * a))
		draw_circle(Vector2(0, -8), 4.5, Color(1.00, 1.00, 1.00, 0.65 * a))
