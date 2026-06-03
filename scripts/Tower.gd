# scripts/Tower.gd
# ─────────────────────────────────────────────────────────────────────────────
# Tower placed on the build grid. Supports character visuals, shoot animation,
# idle bob, and a "held" state for drag-to-move.
# ─────────────────────────────────────────────────────────────────────────────
extends Node2D

const TILE_SIZE : int = 60

var attack_range : float      = 200.0
var damage       : float      = 3.0
var fire_rate    : float      = 1.0
var tower_color  : Color      = Color(0.50, 0.55, 0.70)
var tower_type   : int        = 0
var tower_effect : String     = "none"
var tower_data   : Dictionary = {}
var is_held      : bool       = false
var selected     : bool       = false
var can_upgrade  : bool       = false

var _cooldown      : float   = 0.0
var _bullet_scene  : PackedScene
var _landing       : bool    = false
var _beam_target      : Node2D  = null
var _beam_timer       : float   = 0.0
var _beam_tick_timer  : float   = 0.0
var _impact_radius : float   = 0.0
var _impact_alpha  : float   = 0.0
var _throw_timer   : float   = 0.0
var _throw_dir     : Vector2 = Vector2.RIGHT
var _shoot_anim    : float   = 0.0   # counts down from 0.35 on each shot
var _anim_time     : float   = 0.0   # ever-increasing, drives idle bob


func _ready() -> void:
	_bullet_scene = load("res://scenes/Bullet.tscn")


func init_type(data: Dictionary) -> void:
	tower_data   = data
	attack_range = data.get("range",     200.0)
	damage       = data.get("damage",    3.0)
	fire_rate    = data.get("fire_rate", 1.0)
	tower_color  = data.get("color",     Color(0.50, 0.55, 0.70))
	tower_type   = data.get("idx",       0)
	tower_effect = data.get("effect",    "none")
	queue_redraw()


# ── Placement animations ──────────────────────────────────────────────────────

func drop_from_sky(final_pos: Vector2, duration: float = 0.65) -> void:
	_landing = true
	position  = Vector2(final_pos.x, -120)
	var tw := create_tween()
	tw.tween_property(self, "position", final_pos, duration) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_on_landed)


func move_to(final_pos: Vector2) -> void:
	_landing  = true
	is_held   = false
	z_index   = 0
	var tw := create_tween()
	tw.tween_property(self, "position", final_pos, 0.25) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_on_landed)


func _on_landed() -> void:
	_landing       = false
	is_held        = false
	z_index        = 0
	_impact_radius = 0.0
	_impact_alpha  = 0.85
	var tw := create_tween()
	tw.tween_property(self, "_impact_radius", 72.0, 0.45).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "_impact_alpha", 0.0, 0.45).set_ease(Tween.EASE_IN)


# ── Process ───────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_anim_time += delta
	queue_redraw()
	if _throw_timer > 0.0:
		_throw_timer -= delta
	if _shoot_anim > 0.0:
		_shoot_anim -= delta
	if _beam_timer > 0.0:
		_beam_timer -= delta
		if not is_instance_valid(_beam_target):
			_beam_target     = null
			_beam_timer      = 0.0
			_beam_tick_timer = 0.0
		else:
			_beam_tick_timer -= delta
			if _beam_tick_timer <= 0.0:
				_beam_tick_timer = 0.25
				var tick_dmg := damage * fire_rate * 0.25 * \
					(GameData.relic_boss_dmg_mult() if _beam_target.is_boss else 1.0)
				_beam_target.take_damage(tick_dmg)
		if _beam_timer <= 0.0:
			_beam_target     = null
			_beam_timer      = 0.0
			_beam_tick_timer = 0.0
	if is_held or _landing:
		return
	_cooldown -= delta
	if _cooldown <= 0.0:
		_try_shoot()


func _try_shoot() -> void:
	var in_range : Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if position.distance_to(enemy.position) <= attack_range:
			in_range.append(enemy)
	if in_range.is_empty():
		return
	in_range.sort_custom(func(a, b): return a._current_wp > b._current_wp)
	var primary : Node2D = in_range[0]

	match tower_effect:
		"none":
			_fire(primary, damage)
		"slow_zone":
			_fire(primary, 0.0)   # ice zone drop — no direct damage
		"pierce":
			for i in range(min(3, in_range.size())):
				_fire(in_range[i], damage)
		"aoe":
			for enemy in in_range:
				_fire(enemy, damage)
		"chain":
			_fire(primary, damage)
			var chained := 0
			for enemy in in_range:
				if enemy == primary:
					continue
				_fire(enemy, damage * 0.5)
				chained += 1
				if chained >= 2:
					break
		"lightning":
			# Chain lightning: primary + up to 3 more at 80% damage
			_fire(primary, damage)
			var chained := 0
			for enemy in in_range:
				if enemy == primary:
					continue
				_fire(enemy, damage * 0.8)
				chained += 1
				if chained >= 3:
					break
		"storm_chain":
			# Storm Lord: primary + up to 4 more at 85% damage
			_fire(primary, damage)
			var chained := 0
			for enemy in in_range:
				if enemy == primary:
					continue
				_fire(enemy, damage * 0.85)
				chained += 1
				if chained >= 4:
					break

	_cooldown = 1.0 / fire_rate


func _fire(target: Node2D, dmg: float) -> void:
	var final_dmg := dmg * (GameData.relic_boss_dmg_mult() if target.is_boss else 1.0)

	# Infernal Core — persistent beam, damage dealt via ticks in _process
	if tower_type == 10:
		_beam_target     = target
		_beam_timer      = 1.0 / fire_rate   # beam lasts the full attack interval
		_beam_tick_timer = 0.0               # fire first tick immediately
		_shoot_anim      = 0.35
		return

	var b : Node2D = _bullet_scene.instantiate()
	b.position = position

	match tower_type:
		4:  # Knight — sword
			b.setup(target, final_dmg)
			b.bullet_type = "sword"
			b._speed      = 900.0
			_throw_dir    = position.direction_to(target.position)
			_throw_timer  = 0.35
		8:  # Sniper — white arrow, fast straight shot
			b.setup(target, final_dmg)
			b.bullet_type = "arrow"
			b._speed      = 1200.0
			b.set_straight(position.direction_to(target.position))
		2:  # Catapult — bomb projectile
			b.setup(target, final_dmg)
			b.bullet_type = "bomb"
		6:  # Frost Spire — ice zone drop
			b.setup(target, 0.0)
			b.bullet_type = "ice_zone"
			b._is_zone    = true
			b._target_pos = target.position
			b._speed      = 520.0
		_:  # All other tower types — default homing bullet
			b.setup(target, final_dmg)

	_shoot_anim = 0.35
	get_parent().add_child(b)


# ══════════════════════════════════════════════════════════════════════════════
# DRAWING
# ══════════════════════════════════════════════════════════════════════════════

func _draw() -> void:
	var bob := sin(_anim_time * 2.5) * 1.5 if not is_held else 0.0
	var s   := _shoot_anim > 0.0

	# Rarity glow ring drawn first so it sits behind the tower art
	var _rar := tower_data.get("rarity", "") as String
	if _rar != "":
		var _rar_cols := {
			"common":    Color(0.75, 0.75, 0.75),
			"rare":      Color(0.25, 0.55, 1.00),
			"epic":      Color(0.72, 0.25, 0.90),
			"legendary": Color(1.00, 0.72, 0.10),
			"fusion":    Color(0.20, 1.00, 0.85),
		}
		var rc : Color = _rar_cols.get(_rar, Color(0.75, 0.75, 0.75))
		draw_arc(Vector2.ZERO, 27.0, 0.0, TAU, 48, Color(rc.r, rc.g, rc.b, 0.90), 2.5)

	# Scale down only the towers that were sticking outside their tile
	var _tile_sc := 0.90 if tower_type in [0, 1, 2, 3, 4, 13, 16] else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_tile_sc, _tile_sc))
	match tower_type:
		0: _draw_archer(bob, s)
		1: _draw_crossbow(bob, s)
		2: _draw_cannon(bob, s)
		3: _draw_mage(bob, s)
		4: _draw_knight(bob)
		5:  _draw_flame_tower(bob, s)
		6:  _draw_frost_spire(bob, s)
		7:  _draw_poison_tower(bob, s)
		8:  _draw_sniper_tower(bob, s)
		9:  _draw_tesla_tower(bob, s)
		10: _draw_infernal_core(bob, s)
		11: _draw_ballista_tower(bob, s)
		12: _draw_arcane_cannon(bob, s)
		13: _draw_sun_dragon(bob, s)
		14: _draw_storm_lord(bob, s)
		15: _draw_chrono_mage(bob, s)
		16: _draw_world_tree(bob, s)
		17: _draw_venom_drake(bob, s)
		18: _draw_frost_cannon(bob, s)
		19: _draw_arcane_overlord(bob, s)
		20: _draw_dragon_lich(bob, s)
		21: _draw_tempest_warden(bob, s)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Upgrade-available badge — small arrow at top-right of the rarity ring
	if can_upgrade and not is_held:
		var bp := Vector2(20, -20)
		var ac := Color(0.28, 1.00, 0.42)
		draw_circle(bp, 9.0, Color(0.06, 0.06, 0.06, 0.92))
		draw_circle(bp, 9.0, Color(0.18, 0.88, 0.28), false, 1.5)
		# Arrowhead — filled triangle pointing up
		draw_colored_polygon(PackedVector2Array([
			bp + Vector2(0.0, -4.5),
			bp + Vector2(-3.5,  0.5),
			bp + Vector2( 3.5,  0.5),
		]), ac)
		# Shaft — thin rectangle below the head
		draw_rect(Rect2(bp.x - 1.0, bp.y + 0.5, 2.0, 3.5), ac)

	# Selection highlight — range ring only
	if selected:
		draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 64, Color(1.0, 0.88, 0.25, 0.55), 1.5)

	# Landing shockwave
	if _impact_alpha > 0.0:
		draw_arc(Vector2.ZERO, _impact_radius, 0.0, TAU, 48,
			Color(tower_color.r, tower_color.g, tower_color.b, _impact_alpha), 4.0)

	# Held highlight ring
	if is_held:
		draw_arc(Vector2.ZERO, 24, 0.0, TAU, 32, Color(1.0, 0.95, 0.4, 0.75), 2.5)


# ── Archer (type 0) ───────────────────────────────────────────────────────────
# Green-cloaked forest ranger with a longbow.

func _draw_archer(bob: float, shooting: bool) -> void:
	var skin  := Color(0.94, 0.78, 0.60)
	var tunic := Color(0.22, 0.52, 0.18)
	var pants := Color(0.36, 0.22, 0.10)
	var boots := Color(0.22, 0.12, 0.05)
	var hair  := Color(0.28, 0.16, 0.06)
	var bow_c := Color(0.52, 0.33, 0.10)
	var str_c := Color(0.88, 0.84, 0.72)
	var arr_c := Color(0.72, 0.58, 0.22)
	var b     := bob

	# Ground shadow
	draw_circle(Vector2(0, 24), 11, Color(0, 0, 0, 0.15))

	# Boots
	draw_rect(Rect2(-9, 16 + b, 8, 8), boots)
	draw_rect(Rect2( 1, 16 + b, 8, 8), boots)

	# Legs
	draw_rect(Rect2(-9, 4 + b, 8, 14), pants)
	draw_rect(Rect2( 1, 4 + b, 8, 14), pants)

	# Tunic body
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -8 + b), Vector2(10, -8 + b),
		Vector2( 12,  8 + b), Vector2(-12,  8 + b)
	]), tunic)
	draw_line(Vector2(0, -2 + b), Vector2(0, 8 + b), tunic.darkened(0.25), 1.0)

	# Belt
	draw_rect(Rect2(-12, 3 + b, 24, 4), boots)

	# Left arm (extended to hold bow)
	draw_rect(Rect2(-18, -9 + b, 9, 5), skin)
	# Right arm (draw arm — pulled back or released)
	if shooting:
		draw_rect(Rect2(9, -12 + b, 6, 5), skin)
	else:
		draw_rect(Rect2(9, -6 + b, 6, 5), skin)

	# Head
	draw_circle(Vector2(0, -17 + b), 8, skin)
	draw_circle(Vector2(-6, -17 + b), 3, skin)  # ear

	# Hair & green cap
	draw_circle(Vector2(0, -24 + b), 7, hair)
	draw_rect(Rect2(-7, -24 + b, 14, 8), hair)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -21 + b), Vector2(7, -21 + b),
		Vector2( 4, -29 + b), Vector2(-3, -29 + b)
	]), tunic)
	draw_line(Vector2(4, -28 + b), Vector2(11, -24 + b), Color(1.0, 0.9, 0.5), 2.0)  # feather

	# Eye
	draw_circle(Vector2(3, -17 + b), 1.5, Color(0.12, 0.08, 0.02))

	# Bow (right side, vertical)
	var bx := 18.0
	if shooting:
		# Bow snapped forward, arrow already flying
		draw_line(Vector2(bx, -18 + b), Vector2(bx, 8 + b), bow_c, 3.5)
		draw_line(Vector2(bx, -18 + b), Vector2(bx, 8 + b), str_c, 1.2)
		if _shoot_anim > 0.12:
			# Arrow flash
			draw_line(Vector2(bx, -5 + b), Vector2(bx + 22, -5 + b), arr_c, 2.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(bx + 22, -5 + b),
				Vector2(bx + 16, -8 + b),
				Vector2(bx + 16, -2 + b)
			]), arr_c)
	else:
		# Drawn bow — slightly curved via arc
		draw_arc(Vector2(bx, -5 + b), 13, -PI * 0.55, PI * 0.55, 12, bow_c, 3.5)
		# Bowstring pulled back
		draw_line(Vector2(bx,     -18 + b), Vector2(bx - 6, -5 + b), str_c, 1.2)
		draw_line(Vector2(bx - 6, -5 + b),  Vector2(bx,      8 + b), str_c, 1.2)
		# Arrow nocked
		draw_line(Vector2(bx - 6, -5 + b), Vector2(bx + 8, -5 + b), arr_c, 2.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(bx + 8, -5 + b),
			Vector2(bx + 3, -8 + b),
			Vector2(bx + 3, -2 + b)
		]), arr_c)


# ── Crossbow (type 1) ─────────────────────────────────────────────────────────
# Navy-clad mercenary holding a steel crossbow levelled forward.

func _draw_crossbow(bob: float, shooting: bool) -> void:
	var skin   := Color(0.94, 0.78, 0.60)
	var jacket := Color(0.20, 0.35, 0.72)
	var pants  := Color(0.14, 0.20, 0.48)
	var boots  := Color(0.18, 0.12, 0.06)
	var hair   := Color(0.80, 0.65, 0.20)
	var steel  := Color(0.62, 0.65, 0.72)
	var wood_c := Color(0.52, 0.33, 0.12)
	var b      := bob

	draw_circle(Vector2(0, 24), 11, Color(0, 0, 0, 0.15))

	# Boots
	draw_rect(Rect2(-9, 16 + b, 8, 8), boots)
	draw_rect(Rect2( 1, 16 + b, 8, 8), boots)

	# Pants
	draw_rect(Rect2(-9, 4 + b, 8, 14), pants)
	draw_rect(Rect2( 1, 4 + b, 8, 14), pants)

	# Jacket body
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -8 + b), Vector2(10, -8 + b),
		Vector2( 11,  8 + b), Vector2(-11,  8 + b)
	]), jacket)
	# V-collar
	draw_line(Vector2(-10, -8 + b), Vector2(0, -3 + b), jacket.lightened(0.22), 1.5)
	draw_line(Vector2( 10, -8 + b), Vector2(0, -3 + b), jacket.lightened(0.22), 1.5)

	# Belt
	draw_rect(Rect2(-11, 3 + b, 22, 4), boots)

	# Arms
	draw_rect(Rect2(-14, -7 + b, 8, 5), skin)
	draw_rect(Rect2(  6, -7 + b, 8, 5), skin)

	# Head
	draw_circle(Vector2(0, -17 + b), 8, skin)
	# Blonde hair
	draw_circle(Vector2(0, -24 + b), 7, hair)
	draw_rect(Rect2(-7, -24 + b, 14, 8), hair)
	# Headband
	draw_rect(Rect2(-8, -21 + b, 16, 3), jacket.darkened(0.15))
	# Eyes (both visible for a forward-facing look)
	draw_circle(Vector2(-3, -17 + b), 1.5, Color(0.12, 0.08, 0.02))
	draw_circle(Vector2( 3, -17 + b), 1.5, Color(0.12, 0.08, 0.02))

	# Crossbow
	var recoil := 3.0 if shooting else 0.0
	# Wooden stock (extending from arms backward)
	draw_rect(Rect2(-14, -6 + b, 20 - recoil, 5), wood_c)
	# Prod (horizontal limbs — the T-piece)
	draw_rect(Rect2(4 - recoil, -15 + b, 5, 21), steel)
	# Fore-stock / rail (pointing forward from prod)
	draw_rect(Rect2(8 - recoil, -8 + b, 16, 4), steel.darkened(0.1))
	# Bolt in the groove
	if not shooting:
		draw_rect(Rect2(8, -7 + b, 12, 2), arr_color())
	else:
		# Bolt flying forward — flash
		if _shoot_anim > 0.1:
			draw_line(Vector2(20, -6 + b), Vector2(20 + 20, -6 + b), arr_color(), 2.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(40, -6 + b), Vector2(35, -9 + b), Vector2(35, -3 + b)
			]), arr_color())
	# Trigger
	draw_rect(Rect2(-2, -2 + b, 3, 6), steel.darkened(0.3))


func arr_color() -> Color:
	return Color(0.72, 0.58, 0.22)


# ── Cannon (type 2) ───────────────────────────────────────────────────────────
# Heavy iron cannon on a wooden wheeled carriage.

func _draw_cannon(bob: float, shooting: bool) -> void:
	var iron   := Color(0.36, 0.36, 0.42)
	var iron_d := Color(0.20, 0.20, 0.25)
	var iron_l := Color(0.55, 0.58, 0.64)
	var wood   := Color(0.50, 0.32, 0.12)
	var wood_d := Color(0.36, 0.22, 0.08)
	var b      := bob

	draw_circle(Vector2(0, 24), 13, Color(0, 0, 0, 0.14))

	# Wheels (draw first, behind carriage)
	_draw_wheel(Vector2(-17, 16 + b), 10, wood, wood_d, iron_d)
	_draw_wheel(Vector2( 17, 16 + b), 10, wood, wood_d, iron_d)

	# Axle
	draw_line(Vector2(-17, 16 + b), Vector2(17, 16 + b), iron_d, 3.5)

	# Wooden carriage body
	draw_colored_polygon(PackedVector2Array([
		Vector2(-16,  0 + b), Vector2(16,  0 + b),
		Vector2( 18, 14 + b), Vector2(-18, 14 + b)
	]), wood)
	draw_polyline(PackedVector2Array([
		Vector2(-16,  0 + b), Vector2(16,  0 + b),
		Vector2( 18, 14 + b), Vector2(-18, 14 + b),
		Vector2(-16,  0 + b)
	]), wood_d, 1.8)
	# Plank lines
	draw_line(Vector2(-6,  0 + b), Vector2(-7, 14 + b), wood_d, 1.0)
	draw_line(Vector2( 6,  0 + b), Vector2( 7, 14 + b), wood_d, 1.0)

	# Breech block (pivot mount)
	draw_rect(Rect2(-8, -8 + b, 16, 10), iron)
	draw_rect(Rect2(-8, -8 + b, 16, 10), iron_d, false, 1.8)

	# Barrel (thick line = capsule, slight recoil when shooting)
	var recoil := Vector2(2.5, 1.5) if shooting else Vector2.ZERO
	var bs     := Vector2(-2 + recoil.x, -4 + b + recoil.y)
	var be     := Vector2(16 + recoil.x, -22 + b + recoil.y)
	draw_line(bs, be, iron_d, 19.0)   # outer shadow
	draw_line(bs, be, iron,   16.0)   # main body
	draw_line(bs, be, iron_l,  5.0)   # highlight streak
	# Muzzle cap
	draw_circle(be, 10.0, iron)
	draw_circle(be, 10.0, iron_d, false, 2.0)
	draw_circle(be,  5.0, iron_d)     # barrel bore
	# Breech end cap
	draw_circle(bs + Vector2(0, 2), 9.5, iron)
	draw_circle(bs + Vector2(0, 2), 9.5, iron_d, false, 2.0)
	# Reinforcing bands on barrel
	var seg := (be - bs) / 3.0
	for i in range(1, 3):
		var band_c := bs + seg * i
		draw_line(band_c - Vector2(0, 2), band_c + Vector2(0, 2), iron_d, 20.0)
		draw_line(band_c - Vector2(0, 2), band_c + Vector2(0, 2), iron_l,  4.0)

	# Muzzle smoke when firing
	if shooting:
		var a := _shoot_anim / 0.35
		draw_circle(be,                          12.0 + (1 - a) * 8, Color(0.85, 0.85, 0.85, a * 0.55))
		draw_circle(be + Vector2(6, -5),          8.0,                Color(0.90, 0.90, 0.90, a * 0.38))
		draw_circle(be + Vector2(-5, -8),         6.0,                Color(0.95, 0.95, 0.95, a * 0.25))


func _draw_wheel(center: Vector2, radius: float,
				 wood_c: Color, wood_d: Color, rim_c: Color) -> void:
	# Iron rim
	draw_circle(center, radius, rim_c)
	# Wood fill
	draw_circle(center, radius - 2, wood_c)
	# Spokes
	for i in range(4):
		var ang := i * (PI * 0.5)
		draw_line(center,
			center + Vector2(cos(ang), sin(ang)) * (radius - 2),
			wood_d, 1.5)
	# Hub
	draw_circle(center, 3, rim_c)


# ── Mage (type 3) ─────────────────────────────────────────────────────────────
# Purple-robed wizard with a tall pointy hat and glowing staff.

func _draw_mage(bob: float, shooting: bool) -> void:
	var robe   := Color(0.52, 0.18, 0.72)
	var robe_d := Color(0.34, 0.10, 0.50)
	var star_c := Color(0.88, 0.82, 0.30)    # gold star trim
	var skin   := Color(0.94, 0.78, 0.60)
	var hair   := Color(0.90, 0.90, 0.90)    # white/grey hair
	var staff  := Color(0.55, 0.35, 0.12)
	var orb_c  := Color(0.40, 0.90, 1.00) if shooting else Color(0.20, 0.60, 0.90)
	var b      := bob

	draw_circle(Vector2(0, 24), 11, Color(0, 0, 0, 0.15))

	# Robe (long trapezoid)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -10 + b), Vector2(8, -10 + b),
		Vector2(13,  22 + b), Vector2(-13, 22 + b)
	]), robe)
	# Robe shadow side
	draw_colored_polygon(PackedVector2Array([
		Vector2(4,  -10 + b), Vector2(8, -10 + b),
		Vector2(13,  22 + b), Vector2( 8,  22 + b)
	]), robe_d)
	# Star/moon trim at hem
	draw_line(Vector2(-13, 18 + b), Vector2(13, 18 + b), star_c, 1.5)
	draw_circle(Vector2(-8, 20 + b), 2, star_c)
	draw_circle(Vector2( 0, 20 + b), 2, star_c)
	draw_circle(Vector2( 8, 20 + b), 2, star_c)

	# Belt / sash
	draw_rect(Rect2(-9, -1 + b, 18, 4), star_c.darkened(0.2))

	# Head
	draw_circle(Vector2(0, -18 + b), 7, skin)
	# White beard
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, -13 + b), Vector2(5, -13 + b),
		Vector2( 6,  -4 + b), Vector2(-6,  -4 + b)
	]), hair)
	# Eyebrows
	draw_line(Vector2(-5, -21 + b), Vector2(-2, -22 + b), hair, 1.5)
	draw_line(Vector2( 5, -21 + b), Vector2( 2, -22 + b), hair, 1.5)
	# Eyes
	draw_circle(Vector2(-3, -19 + b), 1.5, Color(0.12, 0.08, 0.30))
	draw_circle(Vector2( 3, -19 + b), 1.5, Color(0.12, 0.08, 0.30))

	# Pointy hat (brim + cone)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -23 + b), Vector2(12, -23 + b),
		Vector2(  8, -25 + b), Vector2(-8, -25 + b)
	]), robe_d)  # brim underside
	draw_rect(Rect2(-11, -25 + b, 22, 3), robe)  # brim top
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -25 + b), Vector2(8, -25 + b),
		Vector2( 2, -38 + b), Vector2(-2, -38 + b)
	]), robe)
	# Hat shadow side
	draw_colored_polygon(PackedVector2Array([
		Vector2(2, -38 + b), Vector2(8, -25 + b), Vector2(4, -25 + b)
	]), robe_d)
	# Gold hat band
	draw_line(Vector2(-8, -25 + b), Vector2(8, -25 + b), star_c, 1.5)
	# Star on hat
	draw_circle(Vector2(0, -31 + b), 2.5, star_c)

	# Staff (left hand side)
	var sx := -16.0
	draw_line(Vector2(sx, -5 + b), Vector2(sx, 20 + b), staff, 4.0)
	draw_line(Vector2(sx, -5 + b), Vector2(sx, 20 + b), staff.lightened(0.2), 1.5)
	# Left arm holding staff
	draw_rect(Rect2(sx, -4 + b, 10, 5), skin)

	# Orb at staff top
	var orb_glow := orb_c if not shooting else Color(0.70, 1.0, 1.0)
	var orb_r    := 7.0 if shooting else 5.5
	if shooting:
		# Glow halo
		draw_circle(Vector2(sx, -12 + b), orb_r + 5, Color(orb_glow.r, orb_glow.g, orb_glow.b, 0.30))
		# Sparkles
		for i in range(4):
			var sang := i * PI * 0.5 + _anim_time * 3.0
			var sp   := Vector2(sx, -12 + b) + Vector2(cos(sang), sin(sang)) * 12.0
			draw_circle(sp, 2.0, Color(1, 1, 0.8, 0.7))
	draw_circle(Vector2(sx, -12 + b), orb_r, orb_glow)
	draw_circle(Vector2(sx - 2, -14 + b), orb_r * 0.35, Color(1, 1, 1, 0.5))  # glint


# ── Knight Hero (type 4) ──────────────────────────────────────────────────────
# Full heroic plate armour with kite shield and longsword.

func _draw_knight(bob: float) -> void:
	var b       := bob
	var steel   := tower_color
	var outline := tower_color.darkened(0.35)
	var light   := tower_color.lightened(0.25)
	var gold    := Color(0.90, 0.78, 0.22)
	var crimson := Color(0.78, 0.14, 0.14)
	var leather := Color(0.42, 0.24, 0.10)

	# Cape
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9, -5 + b), Vector2(9, -5 + b),
		Vector2(13, 22 + b), Vector2(-13, 22 + b)
	]), crimson)

	# Boots
	draw_rect(Rect2(-11, 14 + b, 10, 12), outline)
	draw_rect(Rect2(  1, 14 + b, 10, 12), outline)

	# Greaves
	draw_rect(Rect2(-11, 4 + b, 10, 12), steel)
	draw_rect(Rect2(-11, 4 + b, 10, 12), outline, false, 1.5)
	draw_rect(Rect2(  1, 4 + b, 10, 12), steel)
	draw_rect(Rect2(  1, 4 + b, 10, 12), outline, false, 1.5)

	# Tassets
	draw_rect(Rect2(-13, 2 + b, 11, 6), steel)
	draw_rect(Rect2(  2, 2 + b, 11, 6), steel)

	# Breastplate
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -8 + b), Vector2(12, -8 + b),
		Vector2( 10,  6 + b), Vector2(-10,  6 + b)
	]), steel)
	draw_polyline(PackedVector2Array([
		Vector2(-12, -8 + b), Vector2(12, -8 + b),
		Vector2( 10,  6 + b), Vector2(-10,  6 + b), Vector2(-12, -8 + b)
	]), outline, 2.0)
	draw_line(Vector2(0, -8 + b), Vector2(0, 6 + b), outline, 1.5)
	draw_line(Vector2(-12, -8 + b), Vector2(12, -8 + b), gold, 2.5)

	# Pauldrons
	draw_circle(Vector2(-15, -6 + b), 8, steel)
	draw_circle(Vector2(-15, -6 + b), 8, outline, false, 2.0)
	draw_circle(Vector2( 15, -6 + b), 8, steel)
	draw_circle(Vector2( 15, -6 + b), 8, outline, false, 2.0)
	draw_arc(Vector2(-15, -6 + b), 8, -PI * 0.8, PI * 0.2, 10, gold, 1.5)
	draw_arc(Vector2( 15, -6 + b), 8, -PI * 0.2, PI * 0.8, 10, gold, 1.5)

	# Helmet
	draw_circle(Vector2(0, -18 + b), 10, steel)
	draw_circle(Vector2(0, -18 + b), 10, outline, false, 2.0)
	draw_rect(Rect2(-9, -22 + b, 18, 6), outline)
	draw_rect(Rect2(-8, -21 + b, 6, 4), steel.darkened(0.5))
	draw_rect(Rect2( 2, -21 + b, 6, 4), steel.darkened(0.5))
	draw_rect(Rect2(-2, -30 + b, 4, 13), steel)
	draw_rect(Rect2(-2, -30 + b, 4, 13), outline, false, 1.5)
	draw_rect(Rect2(-3, -36 + b, 6, 10), crimson)
	draw_rect(Rect2(-2, -38 + b, 4,  6), crimson.lightened(0.3))

	# Kite shield (left)
	var sh := PackedVector2Array([
		Vector2(-26, -12 + b), Vector2(-12, -12 + b),
		Vector2(-12,  10 + b), Vector2(-19,  20 + b), Vector2(-26, 10 + b)
	])
	draw_colored_polygon(sh, steel)
	draw_polyline(sh + PackedVector2Array([sh[0]]), outline, 2.0)
	draw_line(Vector2(-19, -8 + b), Vector2(-19, 17 + b), gold, 2.0)
	draw_line(Vector2(-26,  2 + b), Vector2(-12,  2 + b), gold, 2.0)

	# Sword arm (throw or idle)
	if _throw_timer > 0.0:
		var arm_end := _throw_dir * 24.0 + Vector2(0, b)
		draw_line(Vector2(10, -4 + b), arm_end, steel, 9.0)
		draw_line(Vector2(10, -4 + b), arm_end, outline, 2.0)
	else:
		draw_rect(Rect2(15, -32 + b, 5, 36), light)
		draw_rect(Rect2(15, -32 + b, 5, 36), outline, false, 1.5)
		draw_line(Vector2(17, -32 + b), Vector2(17, 4 + b),
			Color(0.75, 0.82, 0.96, 0.7), 1.5)
		draw_rect(Rect2(8, -2 + b, 20, 5), gold)
		draw_rect(Rect2(16, 3 + b, 4, 11), leather)
		draw_circle(Vector2(18, 14 + b), 4, gold)


# ── Flame Tower (type 5) ──────────────────────────────────────────────────────
func _draw_flame_tower(b: float, s: bool) -> void:
	var stone := Color(0.40, 0.35, 0.30)
	var hot   := Color(1.00, 0.38, 0.08)
	var yel   := Color(1.00, 0.85, 0.20)
	draw_circle(Vector2(0, 24), 12, Color(0, 0, 0, 0.15))
	# Base brazier platform
	draw_rect(Rect2(-14, 8 + b, 28, 16), stone)
	draw_rect(Rect2(-16, 6 + b, 32, 6), stone.lightened(0.15))
	# Legs
	draw_line(Vector2(-10, 8 + b), Vector2(-12, 24 + b), stone, 4.0)
	draw_line(Vector2( 10, 8 + b), Vector2( 12, 24 + b), stone, 4.0)
	# Bowl
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10,  2 + b), Vector2(10,  2 + b),
		Vector2( 12,  8 + b), Vector2(-12,  8 + b)
	]), stone.darkened(0.2))
	# Flames (layered)
	var fa := 0.85 if not s else 1.0
	var fh := 16 + (sin(_anim_time * 6.0) * 3.0 if not s else 20.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, 2 + b), Vector2(10, 2 + b),
		Vector2(5, 2 - fh + b), Vector2(-5, 2 - fh + b)
	]), Color(hot.r, hot.g, hot.b, fa))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, 2 + b), Vector2(6, 2 + b),
		Vector2(2, 2 - fh * 0.75 + b), Vector2(-2, 2 - fh * 0.75 + b)
	]), Color(yel.r, yel.g, yel.b, fa))
	# Core glow
	draw_circle(Vector2(0, 2 + b), 4, Color(1.0, 1.0, 0.8, 0.9))


# ── Frost Spire (type 6) ──────────────────────────────────────────────────────
func _draw_frost_spire(b: float, s: bool) -> void:
	var ice  := Color(0.50, 0.85, 1.00)
	var ice2 := Color(0.75, 0.95, 1.00)
	var base := Color(0.35, 0.55, 0.70)
	draw_circle(Vector2(0, 24), 11, Color(0, 0, 0, 0.15))
	# Stone base
	draw_rect(Rect2(-10, 10 + b, 20, 14), base)
	draw_rect(Rect2(-12, 8 + b, 24, 6), base.lightened(0.1))
	# Central spire
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, 8 + b), Vector2(6, 8 + b),
		Vector2(3, -10 + b), Vector2(-3, -10 + b)
	]), ice)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-1, -10 + b), Vector2(1, -10 + b),
		Vector2(0, -22 + b)
	]), ice2)
	# Side crystals
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, 4 + b), Vector2(-5, 4 + b),
		Vector2(-4, -6 + b), Vector2(-8, -6 + b)
	]), ice.darkened(0.1))
	draw_colored_polygon(PackedVector2Array([
		Vector2(5, 4 + b), Vector2(10, 4 + b),
		Vector2(8, -6 + b), Vector2(4, -6 + b)
	]), ice.darkened(0.1))
	# Glint when shooting
	if s:
		draw_circle(Vector2(0, -18 + b), 4, Color(1, 1, 1, 0.8))
	# Icy shimmer
	var shine_a := 0.4 + sin(_anim_time * 3.0) * 0.2
	draw_arc(Vector2(0, -12 + b), 14, -PI * 0.4, PI * 0.4, 12, Color(0.8, 0.95, 1.0, shine_a), 1.5)


# ── Poison Tower (type 7) ─────────────────────────────────────────────────────
func _draw_poison_tower(b: float, s: bool) -> void:
	var stone := Color(0.35, 0.40, 0.32)
	var grn   := Color(0.30, 0.80, 0.20)
	var grn2  := Color(0.55, 0.95, 0.30)
	draw_circle(Vector2(0, 24), 11, Color(0, 0, 0, 0.15))
	# Cylindrical tower
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9, -12 + b), Vector2(9, -12 + b),
		Vector2(10, 22 + b), Vector2(-10, 22 + b)
	]), stone)
	draw_colored_polygon(PackedVector2Array([
		Vector2(4, -12 + b), Vector2(9, -12 + b),
		Vector2(10, 22 + b), Vector2(6, 22 + b)
	]), stone.darkened(0.2))
	# Battlements
	for i in range(3):
		draw_rect(Rect2(-8 + i * 6, -18 + b, 4, 8), stone.lightened(0.1))
	# Poison vials on tower
	draw_rect(Rect2(-3, -4 + b, 6, 10), grn)
	draw_rect(Rect2(-2, -8 + b, 4, 6), grn2)
	draw_circle(Vector2(0, -9 + b), 3, grn2)
	# Drip effect
	if s:
		for i in range(3):
			var dp := Vector2(-4 + i * 4, 6 + b)
			draw_circle(dp, 1.5, grn)
	# Bubble anim
	var ba : float = abs(sin(_anim_time * 4.0 + 1.0))
	draw_circle(Vector2(-5, -3 + ba * 4 + b), 1.5, Color(grn2.r, grn2.g, grn2.b, 0.7))


# ── Sniper Tower (type 8) ─────────────────────────────────────────────────────
func _draw_sniper_tower(b: float, s: bool) -> void:
	var wood  := Color(0.45, 0.32, 0.18)
	var skin  := Color(0.94, 0.78, 0.60)
	var steel := Color(0.60, 0.60, 0.65)
	var cloak := Color(0.52, 0.48, 0.38)
	draw_circle(Vector2(0, 24), 10, Color(0, 0, 0, 0.15))
	# Platform / scaffolding
	draw_line(Vector2(-12, 22 + b), Vector2(-12, -2 + b), wood, 4.0)
	draw_line(Vector2( 12, 22 + b), Vector2( 12, -2 + b), wood, 4.0)
	draw_line(Vector2(-12, 10 + b), Vector2( 12, 10 + b), wood, 3.5)
	draw_line(Vector2(-12,  2 + b), Vector2( 12,  2 + b), wood, 3.5)
	draw_rect(Rect2(-14, -2 + b, 28, 6), wood.lightened(0.1))
	# Sniper figure
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -2 + b), Vector2(7, -2 + b),
		Vector2(8, 8 + b), Vector2(-8, 8 + b)
	]), cloak)
	draw_circle(Vector2(0, -8 + b), 6, skin)
	draw_circle(Vector2(0, -14 + b), 5, Color(0.28, 0.18, 0.08))
	# Rifle
	var recoil := 3.0 if s else 0.0
	draw_line(Vector2(-4, -4 + b), Vector2(22 - recoil, -4 + b), steel, 4.0)
	draw_line(Vector2(-4, -4 + b), Vector2(22 - recoil, -4 + b), Color(0.75, 0.75, 0.80), 1.5)
	# Scope
	draw_circle(Vector2(12 - recoil, -4 + b), 3.5, steel.darkened(0.3))
	# Muzzle flash
	if s and _shoot_anim > 0.2:
		draw_circle(Vector2(22, -4 + b), 5, Color(1, 0.9, 0.5, 0.8))


# ── Tesla Tower (type 9) ──────────────────────────────────────────────────────
func _draw_tesla_tower(b: float, s: bool) -> void:
	var metal := Color(0.40, 0.45, 0.55)
	var coil  := Color(0.55, 0.60, 0.70)
	var elec  := Color(0.40, 0.80, 1.00)
	draw_circle(Vector2(0, 24), 12, Color(0, 0, 0, 0.15))
	# Base pillar
	draw_rect(Rect2(-8, 0 + b, 16, 22), metal)
	draw_rect(Rect2(-10, -2 + b, 20, 6), metal.lightened(0.15))
	# Coil rings
	for i in range(4):
		var ry := -4 + i * 5 + b
		draw_arc(Vector2(0, ry), 10, 0, TAU, 16, coil, 2.5)
	# Central rod
	draw_line(Vector2(0, -4 + b), Vector2(0, -20 + b), coil.lightened(0.2), 4.0)
	# Top orb
	var glow := elec if not s else Color(0.8, 0.95, 1.0)
	draw_circle(Vector2(0, -22 + b), 8, glow)
	draw_circle(Vector2(-2, -24 + b), 2.5, Color(1, 1, 1, 0.6))
	# Electric arcs when active
	if s:
		for i in range(4):
			var ang := i * PI * 0.5 + _anim_time * 8.0
			var ep  := Vector2(cos(ang), sin(ang)) * 14.0 + Vector2(0, -22 + b)
			draw_line(Vector2(0, -22 + b), ep, Color(0.7, 0.95, 1.0, 0.9), 1.5)
	else:
		var pa := 0.3 + sin(_anim_time * 5.0) * 0.2
		draw_circle(Vector2(0, -22 + b), 10, Color(elec.r, elec.g, elec.b, pa))


# ── Infernal Core (type 10) ───────────────────────────────────────────────────
func _draw_infernal_core(b: float, s: bool) -> void:
	var dark := Color(0.20, 0.08, 0.05)
	var lava  := Color(1.00, 0.25, 0.05)
	var yel   := Color(1.00, 0.75, 0.10)
	draw_circle(Vector2(0, 24), 13, Color(0, 0, 0, 0.18))
	# Dark stone base
	draw_rect(Rect2(-13, 4 + b, 26, 20), dark)
	draw_rect(Rect2(-10, 1 + b, 20, 8), dark.lightened(0.1))
	# Lava cracks in base
	draw_line(Vector2(-8, 8 + b), Vector2(-2, 14 + b), lava, 1.5)
	draw_line(Vector2(3, 6 + b), Vector2(8, 16 + b), lava, 1.5)
	# Central molten core orb
	var pulse := 8.5 + sin(_anim_time * 3.0) * 1.5
	draw_circle(Vector2(0, -4 + b), pulse, dark.lightened(0.05))
	draw_circle(Vector2(0, -4 + b), pulse - 2, lava)
	draw_circle(Vector2(0, -4 + b), pulse - 5, yel)
	draw_circle(Vector2(-2, -6 + b), 2.5, Color(1, 1, 0.8, 0.8))
	# Eruption when shooting
	if s:
		for i in range(5):
			var ang := i * TAU / 5.0 + _anim_time
			var ep  := Vector2(cos(ang), sin(ang)) * 18.0 + Vector2(0, -4 + b)
			draw_circle(ep, 3.0, Color(lava.r, lava.g, lava.b, 0.75))

	# Beam — drawn in world-relative local coords
	if _beam_target != null and is_instance_valid(_beam_target):
		var beam_end := _beam_target.position - position
		# Flicker: full brightness, fades only in the last 0.1s
		var ba := clampf(_beam_timer / 0.10, 0.0, 1.0)
		draw_line(Vector2.ZERO, beam_end, Color(1.00, 0.08, 0.05, 0.88), 4.0)
		draw_line(Vector2.ZERO, beam_end, Color(1.00, 0.45, 0.20, 0.70), 2.0)
		draw_line(Vector2.ZERO, beam_end, Color(1.00, 0.95, 0.60, 0.45 * ba), 1.0)
		draw_circle(Vector2.ZERO, 6.0, Color(1.00, 0.25, 0.05, 0.80))
		draw_circle(beam_end, 5.0, Color(1.00, 0.25, 0.05, 0.75 * ba))


# ── Ballista (type 11) ────────────────────────────────────────────────────────
func _draw_ballista_tower(b: float, s: bool) -> void:
	var wood  := Color(0.45, 0.30, 0.12)
	var wood2 := Color(0.32, 0.20, 0.08)
	var steel := Color(0.55, 0.55, 0.62)
	var bolt  := Color(0.65, 0.52, 0.22)
	draw_circle(Vector2(0, 24), 13, Color(0, 0, 0, 0.15))
	# Wheeled platform
	draw_circle(Vector2(-14, 18 + b), 9, wood2)
	draw_circle(Vector2(-14, 18 + b), 7, wood)
	draw_circle(Vector2( 14, 18 + b), 9, wood2)
	draw_circle(Vector2( 14, 18 + b), 7, wood)
	draw_line(Vector2(-14, 18 + b), Vector2(14, 18 + b), wood2, 4.0)
	# Main body
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, 2 + b), Vector2(14, 2 + b),
		Vector2(16, 16 + b), Vector2(-16, 16 + b)
	]), wood)
	draw_polyline(PackedVector2Array([
		Vector2(-14, 2 + b), Vector2(14, 2 + b),
		Vector2(16, 16 + b), Vector2(-16, 16 + b), Vector2(-14, 2 + b)
	]), wood2, 1.8)
	# Bow arms (spread when not shooting)
	var spread := 0.0 if s else 4.0
	draw_line(Vector2(-6, 2 + b), Vector2(-16, -8 + spread + b), wood, 5.0)
	draw_line(Vector2( 6, 2 + b), Vector2( 16, -8 + spread + b), wood, 5.0)
	# String
	draw_line(Vector2(-16, -8 + spread + b), Vector2(0, -2 + b), Color(0.85, 0.82, 0.70), 1.5)
	draw_line(Vector2( 16, -8 + spread + b), Vector2(0, -2 + b), Color(0.85, 0.82, 0.70), 1.5)
	# Rail and bolt
	draw_rect(Rect2(-2, -18 + b, 4, 22), steel)
	if not s:
		draw_line(Vector2(0, -18 + b), Vector2(0, -1 + b), bolt, 3.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, -18 + b), Vector2(-4, -12 + b), Vector2(4, -12 + b)
		]), bolt)
	else:
		if _shoot_anim > 0.1:
			draw_line(Vector2(0, -18 + b), Vector2(0, -46 + b), bolt, 3.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, -46 + b), Vector2(-4, -40 + b), Vector2(4, -40 + b)
			]), bolt)


# ── Arcane Cannon (type 12) ───────────────────────────────────────────────────
func _draw_arcane_cannon(b: float, s: bool) -> void:
	var orb_c := Color(0.80, 0.30, 0.90)
	var ring  := Color(0.60, 0.20, 0.72)
	var gold  := Color(0.90, 0.78, 0.22)
	draw_circle(Vector2(0, 24), 11, Color(0, 0, 0, 0.15))
	# Floating orbit rings (3 rings in different axes)
	for i in range(3):
		var ang := _anim_time * 2.0 + i * TAU / 3.0
		var ex  := cos(ang) * 14.0
		var ey  := sin(ang) * 6.0 + b
		draw_arc(Vector2(ex * 0.3, ey), 12 - i * 2, -PI * 0.6 + ang, PI * 0.6 + ang, 10, Color(ring.r, ring.g, ring.b, 0.6), 2.0)
	# Central arcane orb
	var os := 10.0 + sin(_anim_time * 4.0) * 2.0
	draw_circle(Vector2(0, -2 + b), os, orb_c)
	draw_circle(Vector2(0, -2 + b), os - 3, Color(orb_c.r + 0.2, orb_c.g + 0.1, orb_c.b + 0.1, 1.0))
	draw_circle(Vector2(-2, -4 + b), 3, Color(1, 1, 1, 0.5))
	# Gold trim
	draw_arc(Vector2(0, -2 + b), os, 0, TAU, 20, Color(gold.r, gold.g, gold.b, 0.7), 1.5)
	# Rune sparks when shooting
	if s:
		for i in range(6):
			var sa := i * TAU / 6.0
			var sp := Vector2(cos(sa), sin(sa)) * (os + 6) + Vector2(0, -2 + b)
			draw_circle(sp, 2.5, Color(1, 0.8, 1, 0.85))
	# Chain cable down to ground
	for i in range(4):
		var cy := 10 + i * 5 + b
		draw_circle(Vector2(0, cy), 1.5, Color(ring.r, ring.g, ring.b, 0.5))


# ── Sun Dragon Tower (type 13) ────────────────────────────────────────────────
func _draw_sun_dragon(b: float, s: bool) -> void:
	var gold  := Color(1.00, 0.72, 0.05)
	var fire  := Color(1.00, 0.38, 0.05)
	var scale := Color(0.72, 0.45, 0.05)
	var eye_c := Color(1.00, 0.95, 0.30)
	draw_circle(Vector2(0, 24), 14, Color(0, 0, 0, 0.18))
	# Pedestal
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, 6 + b), Vector2(14, 6 + b),
		Vector2(12, 22 + b), Vector2(-12, 22 + b)
	]), scale.darkened(0.2))
	# Dragon neck
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -8 + b), Vector2(7, -8 + b),
		Vector2(9, 8 + b), Vector2(-9, 8 + b)
	]), scale)
	# Scale pattern on neck
	for i in range(3):
		draw_arc(Vector2(-2 + i * 4, -2 + i * 4 + b), 4, -PI, 0, 8, scale.lightened(0.15), 1.5)
	# Dragon head
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -8 + b), Vector2(12, -8 + b),
		Vector2(14, -18 + b), Vector2(-14, -18 + b)
	]), scale)
	draw_circle(Vector2(0, -22 + b), 8, scale.lightened(0.1))
	# Snout
	draw_rect(Rect2(-6, -22 + b, 12, 8), scale.darkened(0.1))
	# Eyes
	draw_circle(Vector2(-5, -20 + b), 3, eye_c)
	draw_circle(Vector2( 5, -20 + b), 3, eye_c)
	draw_circle(Vector2(-5, -20 + b), 1.5, Color(0.8, 0, 0))
	draw_circle(Vector2( 5, -20 + b), 1.5, Color(0.8, 0, 0))
	# Horns
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -26 + b), Vector2(-4, -26 + b), Vector2(-6, -36 + b)
	]), gold)
	draw_colored_polygon(PackedVector2Array([
		Vector2(4, -26 + b), Vector2(8, -26 + b), Vector2(6, -36 + b)
	]), gold)
	# Fire breath
	var fa := _shoot_anim / 0.35
	if s and _shoot_anim > 0.05:
		for i in range(4):
			var off := Vector2(randi_range(-8, 8), -28 - i * 8 + b)
			draw_circle(off, 5 + i * 1.5, Color(fire.r, fire.g, fire.b, fa * (0.9 - i * 0.18)))
		draw_circle(Vector2(0, -32 + b), 10, Color(1, 0.9, 0.3, fa * 0.7))
	# Gold glow aura
	var ga := 0.18 + sin(_anim_time * 2.0) * 0.08
	draw_arc(Vector2(0, -15 + b), 22, 0, TAU, 32, Color(gold.r, gold.g, gold.b, ga), 3.5)


# ── Storm Lord Tower (type 14) ────────────────────────────────────────────────
func _draw_storm_lord(b: float, s: bool) -> void:
	var cloud := Color(0.55, 0.65, 0.85)
	var dark  := Color(0.25, 0.30, 0.50)
	var bolt  := Color(0.85, 0.95, 1.00)
	draw_circle(Vector2(0, 24), 12, Color(0, 0, 0, 0.15))
	# Pillar
	draw_rect(Rect2(-6, 4 + b, 12, 20), dark)
	# Storm cloud (cluster of overlapping circles)
	draw_circle(Vector2(0,  -8 + b), 14, dark)
	draw_circle(Vector2(-10, -6 + b), 11, cloud.darkened(0.1))
	draw_circle(Vector2( 10, -6 + b), 11, cloud.darkened(0.1))
	draw_circle(Vector2( 0, -14 + b), 13, cloud)
	draw_circle(Vector2(-8, -14 + b),  9, cloud)
	draw_circle(Vector2( 8, -14 + b),  9, cloud)
	# Lightning bolts hanging from cloud
	var bolt_a := 0.6 + sin(_anim_time * 7.0) * 0.3 if not s else 1.0
	draw_line(Vector2(-4, -4 + b), Vector2(-8, 4 + b),   Color(bolt.r, bolt.g, bolt.b, bolt_a), 2.0)
	draw_line(Vector2(-8, 4 + b),  Vector2(-5, 10 + b),  Color(bolt.r, bolt.g, bolt.b, bolt_a), 2.0)
	draw_line(Vector2( 4, -4 + b), Vector2( 8, 4 + b),   Color(bolt.r, bolt.g, bolt.b, bolt_a), 2.0)
	draw_line(Vector2( 8, 4 + b),  Vector2( 5, 10 + b),  Color(bolt.r, bolt.g, bolt.b, bolt_a), 2.0)
	if s:
		# Extra arc discharge
		draw_line(Vector2(0, -4 + b), Vector2(16, 6 + b), Color(0.7, 0.9, 1, 0.9), 1.5)
		draw_line(Vector2(0, -4 + b), Vector2(-16, 6 + b), Color(0.7, 0.9, 1, 0.9), 1.5)
		draw_circle(Vector2(0, -4 + b), 5, Color(1, 1, 1, 0.7))
	# Dim glow
	var cga := 0.12 + sin(_anim_time * 2.5) * 0.06
	draw_arc(Vector2(0, -12 + b), 20, 0, TAU, 24, Color(bolt.r, bolt.g, bolt.b, cga), 4.0)


# ── Chrono Mage Tower (type 15) ───────────────────────────────────────────────
func _draw_chrono_mage(b: float, s: bool) -> void:
	var stone := Color(0.38, 0.42, 0.48)
	var teal  := Color(0.20, 0.90, 0.75)
	var gold  := Color(0.90, 0.78, 0.22)
	draw_circle(Vector2(0, 24), 11, Color(0, 0, 0, 0.15))
	# Tower base
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9, -4 + b), Vector2(9, -4 + b),
		Vector2(10, 22 + b), Vector2(-10, 22 + b)
	]), stone)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -6 + b), Vector2(11, -6 + b),
		Vector2(11, -2 + b), Vector2(-11, -2 + b)
	]), stone.lightened(0.1))
	# Clock face
	draw_circle(Vector2(0, -14 + b), 12, stone.lightened(0.08))
	draw_circle(Vector2(0, -14 + b), 12, teal, false, 2.0)
	# Hour marks
	for i in range(12):
		var ang := i * TAU / 12.0
		var ip  := Vector2(cos(ang), sin(ang))
		draw_line(ip * 9 + Vector2(0, -14 + b), ip * 12 + Vector2(0, -14 + b), teal, 1.5)
	# Clock hands (animate)
	var hour_ang := _anim_time * 0.5
	var min_ang  := _anim_time * 2.5
	draw_line(Vector2(0, -14 + b),
		Vector2(cos(hour_ang - PI * 0.5), sin(hour_ang - PI * 0.5)) * 6 + Vector2(0, -14 + b),
		gold, 2.5)
	draw_line(Vector2(0, -14 + b),
		Vector2(cos(min_ang - PI * 0.5), sin(min_ang - PI * 0.5)) * 9 + Vector2(0, -14 + b),
		teal, 1.5)
	draw_circle(Vector2(0, -14 + b), 2, gold)
	# Glow when shooting
	if s:
		draw_arc(Vector2(0, -14 + b), 14, 0, TAU, 24, Color(teal.r, teal.g, teal.b, 0.6), 2.5)


# ── World Tree Tower (type 16) ────────────────────────────────────────────────
func _draw_world_tree(b: float, s: bool) -> void:
	var bark  := Color(0.38, 0.24, 0.10)
	var bark2 := Color(0.28, 0.16, 0.06)
	var leaf  := Color(0.20, 0.75, 0.30)
	var leaf2 := Color(0.30, 0.92, 0.42)
	var glow  := Color(0.50, 1.00, 0.55)
	draw_circle(Vector2(0, 24), 13, Color(0, 0, 0, 0.16))
	# Roots (decorative)
	draw_line(Vector2(-6, 18 + b), Vector2(-18, 24 + b), bark2, 3.0)
	draw_line(Vector2( 6, 18 + b), Vector2( 18, 24 + b), bark2, 3.0)
	draw_line(Vector2( 0, 18 + b), Vector2(  0, 26 + b), bark2, 3.0)
	# Main trunk
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -8 + b), Vector2(7, -8 + b),
		Vector2(8, 22 + b), Vector2(-8, 22 + b)
	]), bark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(2, -8 + b), Vector2(7, -8 + b),
		Vector2(8, 22 + b), Vector2(4, 22 + b)
	]), bark2)
	# Branch canopy (overlapping leaf clusters)
	draw_circle(Vector2(0,  -16 + b), 14, leaf.darkened(0.15))
	draw_circle(Vector2(-10, -20 + b), 10, leaf)
	draw_circle(Vector2( 10, -20 + b), 10, leaf)
	draw_circle(Vector2(0,  -26 + b), 12, leaf2)
	draw_circle(Vector2(-6, -30 + b),  8, leaf2.lightened(0.05))
	draw_circle(Vector2( 6, -30 + b),  8, leaf2.lightened(0.05))
	# Glowing runes on trunk
	var ra := 0.55 + sin(_anim_time * 3.0) * 0.25
	draw_circle(Vector2(-2, 2 + b), 2.5, Color(glow.r, glow.g, glow.b, ra))
	draw_circle(Vector2( 3, 10 + b), 2.5, Color(glow.r, glow.g, glow.b, ra * 0.85))
	# Support aura
	var aa := 0.12 + sin(_anim_time * 1.8) * 0.05
	draw_arc(Vector2(0, 0 + b), 26, 0, TAU, 32, Color(leaf2.r, leaf2.g, leaf2.b, aa), 3.5)
	# Leaf burst when shooting
	if s:
		for i in range(5):
			var ang := i * TAU / 5.0 + _anim_time
			var lp  := Vector2(cos(ang), sin(ang)) * 22.0 + Vector2(0, -16 + b)
			draw_circle(lp, 4.0, Color(leaf2.r, leaf2.g, leaf2.b, 0.7))


# ── Venom Drake (type 17) ─────────────────────────────────────────────────────

func _draw_venom_drake(b: float, s: bool) -> void:
	var grn  := Color(0.20, 0.80, 0.28); var drk  := Color(0.10, 0.40, 0.14)
	var purp := Color(0.60, 0.20, 0.80); var yel  := Color(0.85, 0.95, 0.20)
	draw_colored_polygon(PackedVector2Array([Vector2(-10,2+b),Vector2(10,2+b),Vector2(12,22+b),Vector2(-12,22+b)]),drk)
	draw_colored_polygon(PackedVector2Array([Vector2(-8,-10+b),Vector2(8,-10+b),Vector2(10,2+b),Vector2(-10,2+b)]),grn)
	draw_circle(Vector2(0,-18+b),8,grn)
	draw_circle(Vector2(0,-18+b),6,drk.lightened(0.1))
	draw_colored_polygon(PackedVector2Array([Vector2(-5,-14+b),Vector2(-2,-14+b),Vector2(-3,-8+b)]),yel)
	draw_colored_polygon(PackedVector2Array([Vector2(2,-14+b),Vector2(5,-14+b),Vector2(3,-8+b)]),yel)
	draw_colored_polygon(PackedVector2Array([Vector2(-10,-6+b),Vector2(-22,-18+b),Vector2(-16,-2+b),Vector2(-10,2+b)]),purp.darkened(0.1))
	draw_colored_polygon(PackedVector2Array([Vector2(10,-6+b),Vector2(22,-18+b),Vector2(16,-2+b),Vector2(10,2+b)]),purp.darkened(0.1))
	var ga := 0.5 + sin(_anim_time * 4.0) * 0.25 if not s else 0.9
	draw_circle(Vector2(0,-18+b),4,Color(0.30,1.00,0.40,ga))
	draw_circle(Vector2(0,-18+b),2,Color(1,1,1,ga * 0.6))
	if s:
		for i in range(4):
			var ang := i * TAU / 4.0 + _anim_time * 2.0
			draw_circle(Vector2(cos(ang)*18,sin(ang)*12-10+b),3,Color(0.30,1.00,0.40,0.7))


# ── Frost Cannon (type 18) ────────────────────────────────────────────────────

func _draw_frost_cannon(b: float, s: bool) -> void:
	var ice  := Color(0.55, 0.90, 1.00); var ice2 := Color(0.85, 0.97, 1.00)
	var dark := Color(0.25, 0.45, 0.65); var gold := Color(0.90, 0.78, 0.22)
	draw_circle(Vector2(-16,18+b),9,dark.darkened(0.2)); draw_circle(Vector2(-16,18+b),7,dark)
	draw_circle(Vector2(16,18+b),9,dark.darkened(0.2));  draw_circle(Vector2(16,18+b),7,dark)
	draw_line(Vector2(-16,18+b),Vector2(16,18+b),dark.darkened(0.2),3.5)
	draw_colored_polygon(PackedVector2Array([Vector2(-14,2+b),Vector2(14,2+b),Vector2(16,16+b),Vector2(-16,16+b)]),dark)
	var barrel_end := Vector2(20,-20+b) if not s else Vector2(18,-18+b)
	draw_line(Vector2(-4,-4+b),barrel_end,dark.darkened(0.2),18)
	draw_line(Vector2(-4,-4+b),barrel_end,ice,14)
	draw_line(Vector2(-4,-4+b),barrel_end,ice2,5)
	draw_circle(barrel_end,9,ice); draw_circle(barrel_end,4,ice2)
	for i in range(3):
		var t2 := 0.25 + i * 0.25
		var bp := Vector2(-4 + t2*24, -4 - t2*16 + b)
		draw_colored_polygon(PackedVector2Array([bp+Vector2(-3,0),bp+Vector2(0,-6),bp+Vector2(3,0)]),ice2)
	draw_arc(Vector2(-4,-4+b),7,-PI*0.6,PI*0.6,10,gold,2.0)
	if s:
		draw_circle(barrel_end,14,Color(ice.r,ice.g,ice.b,0.3))


# ── Arcane Overlord (type 19) ─────────────────────────────────────────────────

func _draw_arcane_overlord(b: float, s: bool) -> void:
	var orng := Color(0.90, 0.42, 0.12); var purp := Color(0.85, 0.30, 0.95)
	var gold := Color(0.90, 0.78, 0.22); var wht  := Color(1.00, 0.95, 0.85)
	draw_colored_polygon(PackedVector2Array([Vector2(-5,6+b),Vector2(5,6+b),Vector2(6,22+b),Vector2(-6,22+b)]),gold.darkened(0.3))
	draw_rect(Rect2(-8,4+b,16,6),gold.darkened(0.2))
	var cy := -6.0 + b + sin(_anim_time * 2.2) * 2.0
	draw_circle(Vector2(0,cy),13,orng.darkened(0.3))
	draw_circle(Vector2(0,cy),10,orng)
	draw_circle(Vector2(0,cy),6,Color(1,0.75,0.40))
	draw_circle(Vector2(-2,cy-2),3,wht)
	var ra2 := _anim_time * 1.5
	draw_arc(Vector2(0,cy),16,ra2,ra2+TAU,20,Color(purp.r,purp.g,purp.b,0.7),2.5)
	draw_arc(Vector2(0,cy),20,ra2*0.7,ra2*0.7+TAU*0.5,10,Color(gold.r,gold.g,gold.b,0.5),1.5)
	for i in range(4):
		var ang := i * TAU / 4.0 + ra2
		var ep  := Vector2(cos(ang)*18,sin(ang)*14+cy)
		draw_line(Vector2(0,cy),ep,Color(orng.r,orng.g,orng.b,0.8),2.5)
		draw_circle(ep,3,Color(purp.r,purp.g,purp.b,0.6))
	if s:
		draw_circle(Vector2(0,cy),22,Color(orng.r,orng.g,orng.b,0.20))


# ── Dragon Lich (type 20) ─────────────────────────────────────────────────────

func _draw_dragon_lich(b: float, s: bool) -> void:
	var dkpur := Color(0.30, 0.10, 0.45); var gold := Color(0.90, 0.78, 0.22)
	var grn   := Color(0.20, 0.90, 0.40); var bone := Color(0.88, 0.84, 0.72)
	draw_colored_polygon(PackedVector2Array([Vector2(-9,2+b),Vector2(9,2+b),Vector2(11,22+b),Vector2(-11,22+b)]),dkpur)
	draw_colored_polygon(PackedVector2Array([Vector2(-8,-10+b),Vector2(8,-10+b),Vector2(9,2+b),Vector2(-9,2+b)]),dkpur.lightened(0.1))
	for i in range(3):
		draw_line(Vector2(-8,4+i*5+b),Vector2(-2,4+i*5+b),bone,1.5)
		draw_line(Vector2(2,4+i*5+b),Vector2(8,4+i*5+b),bone,1.5)
	draw_circle(Vector2(0,-18+b),9,dkpur.lightened(0.05))
	var ea := 0.7 + sin(_anim_time * 3.5) * 0.3
	draw_circle(Vector2(-4,-17+b),3,grn); draw_circle(Vector2(4,-17+b),3,grn)
	draw_circle(Vector2(-4,-17+b),1.5,Color(0.80,1.00,0.10,ea)); draw_circle(Vector2(4,-17+b),1.5,Color(0.80,1.00,0.10,ea))
	draw_colored_polygon(PackedVector2Array([Vector2(-7,-12+b),Vector2(-4,-12+b),Vector2(-5,-8+b)]),bone)
	draw_colored_polygon(PackedVector2Array([Vector2(4,-12+b),Vector2(7,-12+b),Vector2(5,-8+b)]),bone)
	draw_colored_polygon(PackedVector2Array([Vector2(-6,-24+b),Vector2(-4,-24+b),Vector2(-8,-36+b)]),gold)
	draw_colored_polygon(PackedVector2Array([Vector2(4,-24+b),Vector2(6,-24+b),Vector2(8,-36+b)]),gold)
	var aura_a := 0.18 + sin(_anim_time * 2.0) * 0.07
	draw_arc(Vector2(0,-18+b),15,0,TAU,24,Color(grn.r,grn.g,grn.b,aura_a),3.5)
	if s:
		draw_arc(Vector2(0,-18+b),22,0,TAU,32,Color(grn.r,grn.g,grn.b,0.35),3.0)


# ── Tempest Warden (type 21) ──────────────────────────────────────────────────

func _draw_tempest_warden(b: float, s: bool) -> void:
	var storm := Color(0.45, 0.75, 1.00); var dark  := Color(0.20, 0.30, 0.55)
	var wht   := Color(0.90, 0.95, 1.00); var gold  := Color(0.90, 0.78, 0.22)
	draw_colored_polygon(PackedVector2Array([Vector2(-10,-8+b),Vector2(10,-8+b),Vector2(11,8+b),Vector2(-11,8+b)]),dark)
	draw_colored_polygon(PackedVector2Array([Vector2(-9,8+b),Vector2(9,8+b),Vector2(10,22+b),Vector2(-10,22+b)]),dark.darkened(0.1))
	draw_line(Vector2(-10,-8+b),Vector2(10,-8+b),storm,2.5)
	draw_line(Vector2(-10,8+b),Vector2(10,8+b),storm,2.0)
	draw_circle(Vector2(0,-18+b),9,dark.lightened(0.05))
	draw_rect(Rect2(-9,-22+b,18,5),dark.lightened(0.1))
	draw_rect(Rect2(-3,-28+b,6,10),storm)
	var wing_flap := sin(_anim_time * 4.0) * 3.0
	draw_colored_polygon(PackedVector2Array([Vector2(-10,-4+b),Vector2(-24,-16+b+wing_flap),Vector2(-20,-2+b),Vector2(-11,4+b)]),storm.darkened(0.15))
	draw_colored_polygon(PackedVector2Array([Vector2(10,-4+b),Vector2(24,-16+b+wing_flap),Vector2(20,-2+b),Vector2(11,4+b)]),storm.darkened(0.15))
	draw_line(Vector2(-14,-10+b),Vector2(-18,-2+b),wht,2.0)
	draw_line(Vector2(-18,-2+b),Vector2(-15,4+b),wht,2.0)
	draw_line(Vector2(14,-10+b),Vector2(18,-2+b),wht,2.0)
	draw_line(Vector2(18,-2+b),Vector2(15,4+b),wht,2.0)
	draw_circle(Vector2(-12,-4+b),5,gold.darkened(0.1))
	draw_circle(Vector2(12,-4+b),5,gold.darkened(0.1))
	if s:
		var ba := 0.6 + sin(_anim_time * 8.0) * 0.4
		draw_arc(Vector2(0,-8+b),26,0,TAU,32,Color(storm.r,storm.g,storm.b,ba),3.0)
