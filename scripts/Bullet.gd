# scripts/Bullet.gd
# ─────────────────────────────────────────────────────────────────────────────
# Homing projectile (normal) or straight-line sword (knight).
# ─────────────────────────────────────────────────────────────────────────────
extends Node2D

const _SLASH_SCRIPT : GDScript = preload("res://scripts/SlashEffect.gd")


var _target      : Node2D = null
var _damage      : float  = 3.0
var _speed       : float  = 480.0
var bullet_type  : String = "normal"
var bullet_color : Color  = Color(1.0, 0.85, 0.1)
var bullet_style : String = "orb"   # orb | bolt | spark | fireball

var _straight  : bool    = false
var _direction : Vector2 = Vector2.ZERO
var _dist      : float   = 0.0
const _MAX_DIST : float  = 1600.0

var _lifetime  : float = 0.0
const _MAX_LIFETIME : float = 4.0
var _prev_dist : float = INF

# Set true on knight 3rd-attack swords — pushback fires at the moment of impact
var pushback_on_hit : bool = false

# Ice-zone state
var _is_zone       : bool       = false
var _zone_timer    : float      = 3.0   # puddle lasts 3 seconds
var _zone_radius   : float      = 45.0
var _target_pos    : Vector2    = Vector2.ZERO
var _landed        : bool       = false
var _slowed_enemies: Dictionary = {}    # enemies already slowed by this puddle


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
		if bullet_type == "tw_slash":
			queue_free()
			return
		# Target died — redirect to nearest enemy, or vanish
		var nearest : Node2D = null
		var nearest_dist := INF
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy):
				continue
			var d := position.distance_to(enemy.position)
			if d < nearest_dist:
				nearest_dist = d
				nearest = enemy
		if nearest != null:
			_target = nearest
		else:
			queue_free()
			return

	var dir  : Vector2 = _target.position - position
	var dist : float   = dir.length()
	var hit_r : float  = 30.0 if bullet_type == "sword" else (25.0 if bullet_type == "tw_slash" else (15.0 if bullet_type == "sniper_dart" else 8.0))
	# Hit if close enough, or if we overshot (moving away after being very close)
	if dist < hit_r or (dist > _prev_dist and _prev_dist < hit_r * 3.0):
		if bullet_type == "tw_slash":
			if is_instance_valid(_target):
				_target.take_damage(_damage)
			_spawn_tw_cut_mark(_target)
			queue_free()
			return
		_target.take_damage(_damage)
		if pushback_on_hit and is_instance_valid(_target) and not _target.is_boss:
			_target.pushback()
		queue_free()
		return

	_prev_dist = dist
	position += dir.normalized() * _speed * delta
	queue_redraw()


func _process_ice_zone(delta: float) -> void:
	queue_redraw()
	if not _landed:
		_lifetime += delta
		if _lifetime > 1.0 or get_tree().get_nodes_in_group("enemies").is_empty():
			queue_free()
			return
		var dir  := _target_pos - position
		var dist := dir.length()
		if dist < 8.0:
			_landed  = true
			position = _target_pos
			add_to_group("ice_zones")
			# If an existing puddle already covers this spot, discard self instead
			for other in get_tree().get_nodes_in_group("ice_zones"):
				if other != self and is_instance_valid(other) and other._landed:
					if position.distance_to(other.position) < _zone_radius * 0.8:
						queue_free()
						return
		else:
			position += dir.normalized() * _speed * delta
	else:
		_zone_timer -= delta
		if _zone_timer <= 0.0:
			queue_free()
			return
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy):
				continue
			if position.distance_to(enemy.position) < _zone_radius:
				# Apply slow only once per enemy per puddle — never refresh while inside
				if not _slowed_enemies.has(enemy):
					enemy.apply_slow(3.0, 0.45)
					_slowed_enemies[enemy] = true


func _draw() -> void:
	match bullet_type:
		"sword":              _draw_hero_knight_sword()
		"arrow":              _draw_arrow_proj()
		"bomb":               _draw_bomb_proj()
		"ice_zone":           _draw_ice_zone_proj()
		"hero_dragon_fire":   _draw_hero_dragon_fire()
		"hero_shadow_dagger": _draw_hero_shadow_dagger()
		"hero_void_sphere":   _draw_hero_void_sphere()
		"hero_arcane_bolt":   _draw_hero_arcane_bolt()
		"hero_ranger_arrow":  _draw_hero_ranger_arrow()
		"hero_guardian_rock": _draw_hero_guardian_rock()
		"hero_blade_sword":   _draw_hero_blade_sword()
		"hero_frost_shard":   _draw_hero_frost_shard()
		"hero_venom_fang":    _draw_hero_venom_fang()
		"hero_storm_spear":   _draw_hero_storm_spear()
		"hero_phoenix_arrow": _draw_hero_phoenix_arrow()
		"tw_slash":           _draw_tw_slash()
		"sniper_dart":        _draw_sniper_dart()
		_:
			match bullet_style:
				"bolt":     _draw_bolt()
				"spark":    _draw_spark()
				"fireball": _draw_fireball()
				_:          _draw_orb()


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
		var a := clampf(_zone_timer / 3.0, 0.0, 1.0)
		draw_circle(Vector2.ZERO, _zone_radius, Color(0.20, 0.65, 1.00, 0.35 * a))
		draw_arc(Vector2.ZERO, _zone_radius, 0.0, TAU, 36,
			Color(0.40, 0.80, 1.00, 0.90 * a), 2.5)
		draw_arc(Vector2.ZERO, _zone_radius - 4, 0.0, TAU, 36,
			Color(0.70, 0.92, 1.00, 0.50 * a), 1.5)
		for i in range(6):
			var ang := i * TAU / 6.0
			var cp  := Vector2(cos(ang), sin(ang)) * 22.0
			draw_colored_polygon(PackedVector2Array([
				cp + Vector2(0, -7), cp + Vector2(-3, 2), cp + Vector2(3, 2)
			]), Color(0.50, 0.88, 1.00, 0.90 * a))
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, -18), Vector2(-8, 2), Vector2(0, 9), Vector2(8, 2)
		]), Color(0.70, 0.92, 1.00, 1.00 * a))
		draw_circle(Vector2(0, -8), 4.5, Color(1.00, 1.00, 1.00, 0.90 * a))


# ── Styled bullet draw functions ──────────────────────────────────────────────

func _draw_orb() -> void:
	# Soft outer glow
	draw_circle(Vector2.ZERO, 9.0, Color(bullet_color.r, bullet_color.g, bullet_color.b, 0.22))
	# Main body
	draw_circle(Vector2.ZERO, 5.5, bullet_color)
	# Bright highlight
	draw_circle(Vector2(-2.0, -2.0), 2.2, bullet_color.lightened(0.55))


func _draw_bolt() -> void:
	var angle := 0.0
	if _straight:
		angle = _direction.angle() + PI * 0.5
	elif is_instance_valid(_target):
		angle = (_target.position - position).angle() + PI * 0.5
	draw_set_transform(Vector2.ZERO, angle)
	# Shadow
	draw_colored_polygon(PackedVector2Array([
		Vector2(1, -9), Vector2(-3, -1), Vector2(1, 6), Vector2(5, -1)
	]), Color(0, 0, 0, 0.25))
	# Body — elongated diamond
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -10), Vector2(-4, -1), Vector2(0, 6), Vector2(4, -1)
	]), bullet_color)
	# Bright rim
	draw_polyline(PackedVector2Array([
		Vector2(0, -10), Vector2(-4, -1), Vector2(0, 6), Vector2(4, -1), Vector2(0, -10)
	]), bullet_color.lightened(0.45), 1.2)
	# Tip highlight
	draw_circle(Vector2(0, -9), 2.0, bullet_color.lightened(0.6))
	draw_set_transform(Vector2.ZERO, 0.0)


func _draw_spark() -> void:
	var c := bullet_color
	# Four angled spikes
	var spike_pts : Array = [
		[Vector2(0, -4),  Vector2(2, -11), Vector2(-2, -8)],
		[Vector2(4,  0),  Vector2(11, -2), Vector2(8,   2)],
		[Vector2(0,  4),  Vector2(-2, 11), Vector2(2,   8)],
		[Vector2(-4, 0),  Vector2(-11, 2), Vector2(-8, -2)],
	]
	for pts in spike_pts:
		draw_colored_polygon(PackedVector2Array(pts as Array),
			Color(c.r, c.g, c.b, 0.75))
	# Core glow
	draw_circle(Vector2.ZERO, 5.0, Color(c.r, c.g, c.b, 0.40))
	draw_circle(Vector2.ZERO, 3.5, c)
	# White hot center
	draw_circle(Vector2.ZERO, 1.8, Color(1.0, 1.0, 1.0, 0.92))


func _draw_fireball() -> void:
	var c := bullet_color
	# Outer haze
	draw_circle(Vector2.ZERO, 11.0, Color(c.r, c.g, c.b, 0.15))
	# Mid glow
	draw_circle(Vector2.ZERO, 8.0,  Color(c.r, c.g, c.b, 0.40))
	# Core
	draw_circle(Vector2.ZERO, 5.5,  c)
	# Bright inner core (yellow-white)
	var hot := Color(minf(c.r + 0.45, 1.0), minf(c.g + 0.35, 1.0), minf(c.b + 0.1, 1.0))
	draw_circle(Vector2.ZERO, 2.8,  hot)
	# Small specular highlight
	draw_circle(Vector2(-2.0, -2.0), 1.2, Color(1.0, 1.0, 1.0, 0.80))


# ══════════════════════════════════════════════════════════════════════════════
# HERO PROJECTILE DRAW FUNCTIONS
# ══════════════════════════════════════════════════════════════════════════════

# ── Knight — spinning silver sword with golden crossguard ─────────────────────
func _draw_hero_knight_sword() -> void:
	var fly_ang := (_direction.angle() + PI * 0.5) if _straight else \
				   ((_target.position - position).angle() + PI * 0.5 if is_instance_valid(_target) else 0.0)
	var spin    := _lifetime * 14.0
	var is_sp   := pushback_on_hit   # 3rd-hit special sword

	# Trail ghost copies (3 faded blades at previous spin angles)
	for i in range(1, 4):
		var ta := 0.28 - float(i) * 0.08
		draw_set_transform(Vector2.ZERO, fly_ang + spin - float(i) * 0.42)
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, -18), Vector2(-2.5, -10), Vector2(-2, 4), Vector2(2, 4), Vector2(2.5, -10)
		]), Color(0.72, 0.82, 1.00, ta))
	draw_set_transform(Vector2.ZERO, fly_ang + spin)

	# Glow halo
	var glow_r := 9.0 if is_sp else 7.0
	var glow_c := Color(1.00, 0.88, 0.22, 0.45) if is_sp else Color(0.75, 0.85, 1.00, 0.30)
	draw_circle(Vector2(0, -4), glow_r, glow_c)

	# Blade body
	var blade_c := Color(1.00, 0.97, 0.78) if is_sp else Color(0.88, 0.92, 1.00)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -20), Vector2(-3, -11), Vector2(-2.5, 5), Vector2(2.5, 5), Vector2(3, -11)
	]), blade_c)
	# Center shine
	draw_rect(Rect2(-0.8, -18, 1.6, 22), Color(1.00, 1.00, 1.00, 0.55))
	# Rim outline
	draw_polyline(PackedVector2Array([
		Vector2(0, -20), Vector2(-2.5, 5)
	]), Color(0.60, 0.72, 1.00, 0.80), 0.8)
	draw_polyline(PackedVector2Array([
		Vector2(0, -20), Vector2(2.5, 5)
	]), Color(0.60, 0.72, 1.00, 0.60), 0.7)
	# Tip gleam
	draw_circle(Vector2(0, -20), 2.0, Color(1.00, 1.00, 1.00, 0.95))

	# Crossguard
	var gold := Color(0.95, 0.78, 0.18)
	draw_rect(Rect2(-9, 3, 18, 4), gold)
	draw_rect(Rect2(-9, 3, 18, 4), Color(1.00, 0.96, 0.55, 0.55), false, 0.8)

	# Grip
	draw_rect(Rect2(-2, 7, 4, 10), Color(0.22, 0.14, 0.08))

	# Special golden ring
	if is_sp:
		draw_arc(Vector2.ZERO, 15, 0.0, TAU, 14, Color(1.00, 0.82, 0.15, 0.45), 1.8)

	draw_set_transform(Vector2.ZERO, 0.0)


# ── Ranger — emerald arrow with leaf trail ────────────────────────────────────
func _draw_hero_ranger_arrow() -> void:
	var fly_ang := ((_target.position - position).angle() + PI * 0.5 if is_instance_valid(_target) else 0.0)
	draw_set_transform(Vector2.ZERO, fly_ang)

	# Emerald glow aura behind head
	draw_circle(Vector2(0, -14), 7.0, Color(0.12, 0.88, 0.30, 0.20))

	# Shaft
	draw_rect(Rect2(-1.5, -12, 3, 24), Color(0.92, 0.90, 0.80))
	draw_rect(Rect2(-0.6, -12, 1.2, 24), Color(1.00, 1.00, 0.95, 0.55))

	# Emerald arrowhead
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -24), Vector2(-6, -13), Vector2(6, -13)
	]), Color(0.10, 0.90, 0.30))
	draw_polyline(PackedVector2Array([
		Vector2(0, -24), Vector2(-6, -13), Vector2(6, -13), Vector2(0, -24)
	]), Color(0.55, 1.00, 0.60, 0.50), 1.0)
	draw_circle(Vector2(0, -23), 1.8, Color(0.80, 1.00, 0.80, 0.92))

	# Feather fletching
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, 8), Vector2(0, 8), Vector2(-1, 17)
	]), Color(0.18, 0.72, 0.28, 0.90))
	draw_colored_polygon(PackedVector2Array([
		Vector2(6, 8), Vector2(0, 8), Vector2(1, 17)
	]), Color(0.18, 0.72, 0.28, 0.90))

	# Leaf trail particles (3 small leaf diamonds trailing behind)
	for i in range(3):
		var lx := float(i - 1) * 4.5
		var ly := 22.0 + float(i) * 7.0
		var la := 0.45 - float(i) * 0.12
		draw_colored_polygon(PackedVector2Array([
			Vector2(lx, ly - 4), Vector2(lx - 3, ly + 1),
			Vector2(lx, ly + 6), Vector2(lx + 3, ly + 1)
		]), Color(0.20, 0.82, 0.32, la))

	draw_set_transform(Vector2.ZERO, 0.0)


# ── Stone Guardian — heavy enchanted boulder ──────────────────────────────────
func _draw_hero_guardian_rock() -> void:
	var spin := _lifetime * 2.5
	draw_set_transform(Vector2.ZERO, spin)

	# Shadow
	draw_circle(Vector2(2, 2), 13, Color(0, 0, 0, 0.22))

	# Boulder body (irregular octagon)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -15), Vector2(9, -11), Vector2(14, 0), Vector2(9, 11),
		Vector2(0, 15), Vector2(-9, 11), Vector2(-14, 0), Vector2(-9, -11)
	]), Color(0.52, 0.48, 0.42))

	# Inner dark face
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -11), Vector2(7, -8), Vector2(10, 0), Vector2(7, 8),
		Vector2(0, 11), Vector2(-7, 8), Vector2(-10, 0), Vector2(-7, -8)
	]), Color(0.44, 0.40, 0.34))

	# Surface cracks
	draw_line(Vector2(-6, -8), Vector2(4, 3), Color(0.28, 0.26, 0.22, 0.65), 1.0)
	draw_line(Vector2(5, -6), Vector2(-4, 7), Color(0.28, 0.26, 0.22, 0.50), 0.8)

	# Ancient glowing rune marks
	var rc := Color(0.45, 0.72, 1.00, 0.75)
	draw_line(Vector2(-5, -4), Vector2(-5, 4), rc, 1.5)
	draw_line(Vector2(-8, 0), Vector2(-2, 0), rc, 1.5)
	draw_line(Vector2(3, -6), Vector2(7, 0),  Color(0.45, 0.72, 1.00, 0.60), 1.2)
	draw_line(Vector2(7, 0),  Vector2(3, 5),  Color(0.45, 0.72, 1.00, 0.60), 1.2)

	# Highlight
	draw_circle(Vector2(-5, -6), 3.5, Color(0.72, 0.68, 0.62, 0.45))

	draw_set_transform(Vector2.ZERO, 0.0)


# ── Arcane Scholar — crystal bolt with rotating rune orbits ──────────────────
func _draw_hero_arcane_bolt() -> void:
	var fly_ang  := ((_target.position - position).angle() + PI * 0.5 if is_instance_valid(_target) else 0.0)
	var rune_rot := _lifetime * 9.0

	# Outer glow
	draw_circle(Vector2.ZERO, 12.0, Color(0.55, 0.18, 0.90, 0.14))
	draw_circle(Vector2.ZERO,  8.0, Color(0.35, 0.22, 0.85, 0.28))

	# Crystal body aligned to flight direction
	draw_set_transform(Vector2.ZERO, fly_ang)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -16), Vector2(-5, -4), Vector2(-4, 9), Vector2(4, 9), Vector2(5, -4)
	]), Color(0.30, 0.12, 0.80))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -16), Vector2(-2.5, -4), Vector2(-2, 7), Vector2(2, 7), Vector2(2.5, -4)
	]), Color(0.65, 0.30, 1.00, 0.85))
	# Crimson edge highlight
	draw_polyline(PackedVector2Array([
		Vector2(0, -16), Vector2(-5, -4), Vector2(-4, 9)
	]), Color(0.92, 0.15, 0.48, 0.80), 1.2)
	draw_polyline(PackedVector2Array([
		Vector2(0, -16), Vector2(5, -4), Vector2(4, 9)
	]), Color(0.92, 0.15, 0.48, 0.60), 0.9)
	draw_circle(Vector2(0, -15), 2.5, Color(1.00, 0.88, 1.00, 0.95))
	draw_set_transform(Vector2.ZERO, 0.0)

	# Orbiting rune marks (4 at 90 deg intervals, rotate in world space)
	for r in range(4):
		var ra := rune_rot + r * PI * 0.5
		var rx := cos(ra) * 11.0
		var ry := sin(ra) * 11.0
		draw_circle(Vector2(rx, ry), 2.2, Color(0.88, 0.38, 1.00, 0.80))
		draw_line(Vector2(rx - 2.2, ry), Vector2(rx + 2.2, ry),
			Color(1.00, 0.72, 1.00, 0.90), 1.0)
		draw_line(Vector2(rx, ry - 2.2), Vector2(rx, ry + 2.2),
			Color(1.00, 0.72, 1.00, 0.90), 1.0)


# ── Shadow Blade — dark dagger with crimson glow, shadow afterimages ──────────
func _draw_hero_shadow_dagger() -> void:
	var fly_ang := ((_target.position - position).angle() + PI * 0.5 if is_instance_valid(_target) else 0.0)
	draw_set_transform(Vector2.ZERO, fly_ang)

	# Shadow glow
	draw_circle(Vector2(0, -4), 8.0, Color(0.55, 0.05, 0.12, 0.32))

	# Afterimage trail (3 faded blades trailing behind)
	for i in range(1, 4):
		var off := float(i) * 8.0
		var af  := 0.22 - float(i) * 0.06
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, off - 20), Vector2(-2, off - 8), Vector2(-1.5, off + 5),
			Vector2(1.5, off + 5), Vector2(2, off - 8)
		]), Color(0.10, 0.03, 0.06, af))

	# Blade body (near-black with crimson edge)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -22), Vector2(-3, -9), Vector2(-2, 7), Vector2(2, 7), Vector2(3, -9)
	]), Color(0.07, 0.03, 0.05))
	draw_polyline(PackedVector2Array([
		Vector2(0, -22), Vector2(-3, -9), Vector2(-2, 7)
	]), Color(0.92, 0.10, 0.16, 0.92), 1.3)
	draw_polyline(PackedVector2Array([
		Vector2(0, -22), Vector2(3, -9), Vector2(2, 7)
	]), Color(0.92, 0.10, 0.16, 0.68), 1.0)
	# Tip glow
	draw_circle(Vector2(0, -22), 2.0, Color(0.95, 0.42, 0.52, 0.88))

	# Crossguard + grip
	draw_rect(Rect2(-6, 5, 12, 3), Color(0.22, 0.05, 0.08))
	draw_rect(Rect2(-6, 5, 12, 3), Color(0.72, 0.08, 0.12, 0.65), false, 0.8)
	draw_rect(Rect2(-1.5, 8, 3, 8), Color(0.10, 0.05, 0.08))

	draw_set_transform(Vector2.ZERO, 0.0)


# ── Frost Herald — crystalline ice spear with frost mist ─────────────────────
func _draw_hero_frost_shard() -> void:
	var fly_ang := ((_target.position - position).angle() + PI * 0.5 if is_instance_valid(_target) else 0.0)
	draw_set_transform(Vector2.ZERO, fly_ang)

	# Frost mist aura
	draw_circle(Vector2(0,  0), 10.0, Color(0.65, 0.92, 1.00, 0.12))
	draw_circle(Vector2(0, -6),  8.0, Color(0.80, 0.96, 1.00, 0.18))

	# Main spear body
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -24), Vector2(-5, -9), Vector2(-5, 7), Vector2(5, 7), Vector2(5, -9)
	]), Color(0.55, 0.88, 1.00, 0.95))
	# Bright inner core
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -24), Vector2(-2, -9), Vector2(-2, 5), Vector2(2, 5), Vector2(2, -9)
	]), Color(0.88, 0.98, 1.00, 0.90))
	# Rim lines
	draw_polyline(PackedVector2Array([
		Vector2(0, -24), Vector2(-5, -9), Vector2(-5, 7)
	]), Color(0.90, 1.00, 1.00, 0.38), 0.7)
	draw_polyline(PackedVector2Array([
		Vector2(0, -24), Vector2(5, -9), Vector2(5, 7)
	]), Color(0.90, 1.00, 1.00, 0.28), 0.6)
	# Tip gleam
	draw_circle(Vector2(0, -24), 2.8, Color(1.00, 1.00, 1.00, 0.95))

	# Side crystal shards
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -12), Vector2(-4, -16), Vector2(-6, -4)
	]), Color(0.55, 0.88, 1.00, 0.72))
	draw_colored_polygon(PackedVector2Array([
		Vector2(7, -12), Vector2(4, -16), Vector2(6, -4)
	]), Color(0.55, 0.88, 1.00, 0.72))

	draw_set_transform(Vector2.ZERO, 0.0)


# ── Storm Knight — electric lightning spear ───────────────────────────────────
func _draw_hero_storm_spear() -> void:
	var fly_ang := ((_target.position - position).angle() + PI * 0.5 if is_instance_valid(_target) else 0.0)
	draw_set_transform(Vector2.ZERO, fly_ang)

	# Electric outer haze
	draw_circle(Vector2(0, -4), 9.0, Color(0.50, 0.80, 1.00, 0.15))

	# Spear shaft
	draw_rect(Rect2(-2.5, -18, 5, 32), Color(0.40, 0.68, 1.00))
	draw_rect(Rect2(-1.0, -18, 2, 32), Color(0.88, 0.96, 1.00, 0.88))

	# Spear head
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -28), Vector2(-6, -17), Vector2(6, -17)
	]), Color(0.88, 0.96, 1.00))
	draw_polyline(PackedVector2Array([
		Vector2(0, -28), Vector2(-6, -17), Vector2(6, -17), Vector2(0, -28)
	]), Color(0.65, 0.90, 1.00, 0.55), 1.0)
	draw_circle(Vector2(0, -27), 2.8, Color(1.00, 1.00, 1.00, 0.95))
	draw_circle(Vector2(0, -27), 5.0, Color(0.65, 0.88, 1.00, 0.38))

	# Animated lightning zigzag along shaft
	var jitter := sin(_lifetime * 22.0) * 2.2
	var lc := Color(0.80, 0.96, 1.00, 0.88)
	draw_line(Vector2(-2, -13), Vector2(jitter + 2, -5), lc, 0.9)
	draw_line(Vector2(jitter + 2, -5), Vector2(-jitter - 1, 4), lc, 0.9)
	draw_line(Vector2(-jitter - 1, 4), Vector2(jitter * 0.8, 11), lc, 0.9)
	draw_line(Vector2(jitter * 0.8, 11), Vector2(0, 14), lc, 0.9)

	# Wing fins (two small triangles on shaft sides)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2.5, -6), Vector2(-9, -2), Vector2(-2.5, 4)
	]), Color(0.40, 0.68, 1.00, 0.55))
	draw_colored_polygon(PackedVector2Array([
		Vector2(2.5, -6), Vector2(9, -2), Vector2(2.5, 4)
	]), Color(0.40, 0.68, 1.00, 0.55))

	draw_set_transform(Vector2.ZERO, 0.0)


# ── Blade Dancer — fast-spinning longsword with blade trail ───────────────────
func _draw_hero_blade_sword() -> void:
	var fly_ang := ((_target.position - position).angle() + PI * 0.5 if is_instance_valid(_target) else 0.0)
	var spin    := _lifetime * 16.0
	draw_set_transform(Vector2.ZERO, fly_ang + spin)

	# Circular blade trail ring
	draw_arc(Vector2.ZERO, 14, 0, TAU, 20, Color(0.55, 0.78, 1.00, 0.20), 5.0)

	# Wind streaks
	for i in range(3):
		var wa := float(i) * TAU / 3.0
		var wx := cos(wa) * 10.0
		var wy := sin(wa) * 10.0
		draw_line(Vector2(wx, wy), Vector2(wx * 1.7, wy * 1.7),
			Color(0.75, 0.88, 1.00, 0.28), 1.0)

	# Sword blade (long)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -23), Vector2(-3, -12), Vector2(-2.5, 9), Vector2(2.5, 9), Vector2(3, -12)
	]), Color(0.86, 0.92, 1.00))
	# Blue energy edges
	draw_polyline(PackedVector2Array([
		Vector2(0, -23), Vector2(-2.5, 9)
	]), Color(0.32, 0.62, 1.00, 0.90), 1.6)
	draw_polyline(PackedVector2Array([
		Vector2(0, -23), Vector2(2.5, 9)
	]), Color(0.32, 0.62, 1.00, 0.70), 1.3)
	# Center shine
	draw_rect(Rect2(-0.8, -21, 1.6, 28), Color(1.00, 1.00, 1.00, 0.58))
	# Tip gleam
	draw_circle(Vector2(0, -23), 2.2, Color(1.00, 1.00, 1.00, 0.95))

	# Crossguard + grip
	draw_rect(Rect2(-10, 7, 20, 4), Color(0.70, 0.76, 0.92))
	draw_rect(Rect2(-10, 7, 20, 4), Color(0.38, 0.62, 1.00, 0.55), false, 0.8)
	draw_rect(Rect2(-2, 11, 4, 10), Color(0.20, 0.18, 0.32))

	draw_set_transform(Vector2.ZERO, 0.0)


# ── Venom Lord — poison fang with toxic crystal ───────────────────────────────
func _draw_hero_venom_fang() -> void:
	var fly_ang := ((_target.position - position).angle() + PI * 0.5 if is_instance_valid(_target) else 0.0)
	draw_set_transform(Vector2.ZERO, fly_ang)

	# Toxic mist aura
	draw_circle(Vector2(0, -2), 10.0, Color(0.15, 0.72, 0.20, 0.18))

	# Left fang
	draw_colored_polygon(PackedVector2Array([
		Vector2(-1, -20), Vector2(-6, -9), Vector2(-8, 3), Vector2(-3, 9), Vector2(0, 4)
	]), Color(0.08, 0.52, 0.14))
	# Right fang
	draw_colored_polygon(PackedVector2Array([
		Vector2(1, -20), Vector2(6, -9), Vector2(8, 3), Vector2(3, 9), Vector2(0, 4)
	]), Color(0.08, 0.52, 0.14))
	# Fang inner highlight
	draw_line(Vector2(-1, -20), Vector2(-4, -4), Color(0.22, 0.80, 0.28, 0.55), 0.8)
	draw_line(Vector2(1, -20), Vector2(4, -4), Color(0.22, 0.80, 0.28, 0.55), 0.8)

	# Venom crystal center
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -16), Vector2(-5, -7), Vector2(0, 1), Vector2(5, -7)
	]), Color(0.22, 0.92, 0.28, 0.95))
	draw_circle(Vector2(0, -8), 3.0, Color(0.55, 1.00, 0.42, 0.92))
	draw_circle(Vector2(0, -8), 1.5, Color(0.85, 1.00, 0.75, 0.95))

	# Venom drip trail
	for i in range(3):
		var dy := float(i) * 9.0 + 10.0
		var da := 0.48 - float(i) * 0.13
		draw_circle(Vector2(0, dy), 2.8 - float(i) * 0.5, Color(0.18, 0.85, 0.24, da))

	# Tip glows
	draw_circle(Vector2(-1, -20), 2.0, Color(0.55, 1.00, 0.50, 0.88))
	draw_circle(Vector2(1, -20),  2.0, Color(0.55, 1.00, 0.50, 0.88))

	draw_set_transform(Vector2.ZERO, 0.0)


# ── Dragon Sovereign — dragon-shaped fire blast ───────────────────────────────
func _draw_hero_dragon_fire() -> void:
	var fly_ang := ((_target.position - position).angle() + PI * 0.5 if is_instance_valid(_target) else 0.0)
	var flicker := sin(_lifetime * 28.0) * 0.08
	draw_set_transform(Vector2.ZERO, fly_ang)

	# Fire trail (two elongated teardrops behind)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 20), Vector2(-7, 7), Vector2(-5, -3), Vector2(5, -3), Vector2(7, 7)
	]), Color(0.88, 0.30, 0.05, 0.55))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 25), Vector2(-4, 10), Vector2(-3, -1), Vector2(3, -1), Vector2(4, 10)
	]), Color(0.98, 0.58, 0.10, 0.32))

	# Dragon body (head forward)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -22), Vector2(-9, -8), Vector2(-8, 7), Vector2(8, 7), Vector2(9, -8)
	]), Color(0.98, 0.36, 0.08 + flicker))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -22), Vector2(-5, -8), Vector2(-4, 5), Vector2(4, 5), Vector2(5, -8)
	]), Color(1.00, 0.74, 0.16))

	# Horns
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, -18), Vector2(-9, -26), Vector2(-4, -22)
	]), Color(0.95, 0.58, 0.12, 0.80))
	draw_colored_polygon(PackedVector2Array([
		Vector2(5, -18), Vector2(9, -26), Vector2(4, -22)
	]), Color(0.95, 0.58, 0.12, 0.80))

	# Hot core
	draw_circle(Vector2(0, -6), 5.0, Color(1.00, 0.92, 0.42, 0.88))
	draw_circle(Vector2(0, -6), 2.8, Color(1.00, 1.00, 0.85, 0.95))

	# Dragon eyes
	draw_circle(Vector2(-4, -16), 2.0, Color(1.00, 0.88, 0.12, 0.95))
	draw_circle(Vector2(4, -16),  2.0, Color(1.00, 0.88, 0.12, 0.95))

	# Outer heat haze
	draw_circle(Vector2(0, -8), 12.0 + flicker * 12, Color(0.98, 0.40, 0.08, 0.13))

	draw_set_transform(Vector2.ZERO, 0.0)


# ── Void Walker — compressed void sphere with orbiting fragments ──────────────
func _draw_hero_void_sphere() -> void:
	var orbit_a := _lifetime * 7.0

	# Reality distortion outer ring
	draw_circle(Vector2.ZERO, 15.0, Color(0.10, 0.03, 0.20, 0.22))
	draw_arc(Vector2.ZERO, 14, 0, TAU, 26, Color(0.48, 0.10, 0.78, 0.32), 2.0)

	# Middle energy rings
	draw_arc(Vector2.ZERO, 10, 0, TAU * 0.72, 20, Color(0.62, 0.18, 0.95, 0.60), 1.5)
	draw_arc(Vector2.ZERO,  7, 0, TAU * 0.52, 16, Color(0.42, 0.10, 0.72, 0.50), 1.2)

	# Black void center
	draw_circle(Vector2.ZERO, 6.5, Color(0.04, 0.02, 0.08))
	draw_circle(Vector2.ZERO, 3.8, Color(0.00, 0.00, 0.03))
	# Cosmic shimmer
	draw_circle(Vector2(-2, -2), 1.6, Color(0.75, 0.45, 1.00, 0.70))

	# Orbiting void fragments (3 dark diamond shards)
	for i in range(3):
		var fa := orbit_a + float(i) * TAU / 3.0
		var fx := cos(fa) * 12.0
		var fy := sin(fa) * 12.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(fx, fy - 3.5), Vector2(fx - 2.5, fy + 1),
			Vector2(fx, fy + 3.5), Vector2(fx + 2.5, fy + 1)
		]), Color(0.52, 0.14, 0.82, 0.82))
		# Fragment inner glow
		draw_circle(Vector2(fx, fy), 1.2, Color(0.78, 0.48, 1.00, 0.65))


# ── Phoenix Archer — flaming phoenix arrow with fire feathers ─────────────────
func _draw_hero_phoenix_arrow() -> void:
	var fly_ang := ((_target.position - position).angle() + PI * 0.5 if is_instance_valid(_target) else 0.0)
	var flicker := sin(_lifetime * 24.0) * 0.07
	draw_set_transform(Vector2.ZERO, fly_ang)

	# Phoenix flame aura
	draw_circle(Vector2(0, -8), 10.0 + flicker * 14, Color(0.95, 0.35, 0.05, 0.17))

	# Fire feathers (3 elongated teardrops trailing behind)
	for i in range(3):
		var fx := float(i - 1) * 5.5
		var fy := 12.0 + float(i) * 7.0
		var fa := 0.52 - float(i) * 0.12
		var fr := 0.98
		var fg := 0.42 + float(i) * 0.06
		draw_colored_polygon(PackedVector2Array([
			Vector2(fx, fy - 5), Vector2(fx - 3.5, fy + 2),
			Vector2(fx, fy + 9), Vector2(fx + 3.5, fy + 2)
		]), Color(fr, fg, 0.05, fa))

	# Shaft — crimson fire
	draw_rect(Rect2(-1.8, -14, 3.6, 22), Color(0.92, 0.30, 0.05))
	draw_rect(Rect2(-0.8, -14, 1.6, 22), Color(1.00, 0.78, 0.22, 0.80))

	# Phoenix beak arrowhead
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -26), Vector2(-7, -15), Vector2(-2, -12), Vector2(2, -12), Vector2(7, -15)
	]), Color(0.98, 0.58, 0.12))
	draw_polyline(PackedVector2Array([
		Vector2(0, -26), Vector2(-7, -15), Vector2(-2, -12), Vector2(2, -12), Vector2(7, -15), Vector2(0, -26)
	]), Color(1.00, 0.92, 0.42, 0.55), 1.0)
	draw_circle(Vector2(0, -25), 2.5, Color(1.00, 0.96, 0.52, 0.92))

	# Small flame wings
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -10), Vector2(-13, -5), Vector2(-8, 1), Vector2(-4, -4)
	]), Color(0.98, 0.38, 0.05, 0.60))
	draw_colored_polygon(PackedVector2Array([
		Vector2(6, -10), Vector2(13, -5), Vector2(8, 1), Vector2(4, -4)
	]), Color(0.98, 0.38, 0.05, 0.60))

	# Fire fletching
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, 7), Vector2(0, 7), Vector2(-1, 16)
	]), Color(0.98, 0.48, 0.10, 0.88))
	draw_colored_polygon(PackedVector2Array([
		Vector2(5, 7), Vector2(0, 7), Vector2(1, 16)
	]), Color(0.98, 0.48, 0.10, 0.88))

	draw_set_transform(Vector2.ZERO, 0.0)


func _draw_tw_slash() -> void:
	var dir : Vector2
	if is_instance_valid(_target):
		dir = (_target.position - position).normalized()
	elif _direction != Vector2.ZERO:
		dir = _direction.normalized()
	else:
		return
	draw_set_transform(Vector2.ZERO, dir.angle() + PI * 0.5)
	# Jagged zigzag slash — negative y points toward target
	var pts := PackedVector2Array([
		Vector2( 0, -30),
		Vector2( 8, -19),
		Vector2(-7, -10),
		Vector2( 9,  -1),
		Vector2(-5,   8),
		Vector2( 3,  17),
	])
	# Soft outer glow
	draw_polyline(pts, Color(0.65, 0.95, 1.00, 0.28), 14.0)
	# Mid glow
	draw_polyline(pts, Color(0.82, 0.97, 1.00, 0.65),  7.0)
	# Bright white core
	draw_polyline(pts, Color(1.00, 1.00, 1.00, 0.95),  2.5)
	# Tip glow
	draw_circle(Vector2(0, -30), 5.5, Color(1.00, 1.00, 1.00, 0.90))
	draw_circle(Vector2(0, -30), 9.0, Color(0.75, 0.97, 1.00, 0.40))
	# Fading trail behind tail
	draw_line(Vector2(3, 17), Vector2(1, 32), Color(0.65, 0.95, 1.00, 0.28), 5.0)
	draw_line(Vector2(3, 17), Vector2(0, 46), Color(0.65, 0.95, 1.00, 0.10), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0)


func _draw_sniper_dart() -> void:
	var fly_ang := ((_target.position - position).angle() + PI * 0.5 if is_instance_valid(_target) else 0.0)
	draw_set_transform(Vector2.ZERO, fly_ang)

	# Speed trail
	draw_line(Vector2(0, 8), Vector2(0, 20), Color(0.18, 0.78, 0.52, 0.22), 3.5)
	draw_line(Vector2(0, 8), Vector2(0, 15), Color(0.28, 0.90, 0.62, 0.42), 2.0)

	# Body — dark needle cylinder
	draw_rect(Rect2(-2.0, -8, 4, 17), Color(0.12, 0.14, 0.16))
	draw_rect(Rect2(-0.7, -8, 1.4, 17), Color(0.30, 0.32, 0.38, 0.50))

	# Metallic tip
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -18), Vector2(-2.5, -8), Vector2(2.5, -8)
	]), Color(0.80, 0.84, 0.90))
	draw_line(Vector2(-2.5, -8), Vector2(0, -18), Color(1.00, 1.00, 1.00, 0.50), 0.8)
	draw_circle(Vector2(0, -18), 1.5, Color(1.00, 1.00, 1.00, 0.90))

	# Teal poison coating near tip
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -18), Vector2(-1.8, -11), Vector2(1.8, -11)
	]), Color(0.18, 0.85, 0.58, 0.82))
	draw_circle(Vector2(0, -15), 1.0, Color(0.55, 1.00, 0.72, 0.90))

	# Tail fins — left, right, center
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2, 6), Vector2(-7, 12), Vector2(-2, 12)
	]), Color(0.25, 0.72, 0.50, 0.88))
	draw_colored_polygon(PackedVector2Array([
		Vector2(2, 6), Vector2(7, 12), Vector2(2, 12)
	]), Color(0.25, 0.72, 0.50, 0.88))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-1.5, 6), Vector2(0, 13), Vector2(1.5, 6)
	]), Color(0.18, 0.60, 0.42, 0.80))

	draw_set_transform(Vector2.ZERO, 0.0)


func _spawn_tw_cut_mark(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	var fx : Node2D = _SLASH_SCRIPT.new()
	enemy.add_child(fx)
	fx.init_tw_cut(Vector2.ZERO)
