extends Node2D

signal died(reward: float)
signal reached_end()

var hp         : float = 10.0
var max_hp     : float = 10.0
var speed      : float = 220.0
var reward     : float = 5.0
var is_boss       : bool  = false
var is_taunt_tank : bool  = false
var is_dummy      : bool  = false
var enemy_type : int   = 0   # 0=slime 1=goblin 2=skeleton 3=orc 4=shadow
var boss_stage : int   = 1   # 1-10

var wave_id          : int   = -1
var is_poisoned      : bool  = false
var poison_stacks    : int   = 0
var poison_timer     : float = 0.0
var damage_taken_mult: float = 1.0
var melee_resist     : float = 0.0
var hits_taken       : int   = 0
var is_taunted       : bool  = false
var _taunt_timer     : float = 0.0

var _path          : Array   = []
var _current_wp    : int     = 1
var _anim_time     : float   = 0.0
var _slow_timer      : float   = 0.0
var _chrono_timer    : float   = 0.0   # chrono mage stackable 15% slow timer
var _mild_slow_timer : float   = 0.0   # dual debuff: 10% slow, 1s
var _frost_slow_timer: float   = 0.0   # frost herald: 5% slow, 2s

var brittle_bonus       : float   = 0.0   # stone guardian: next hit deals +20 extra damage
var _brittle_popin_t    : float   = 0.0   # 0→0.15 scale-in animation
var _brittle_shatter_t  : float   = 0.0   # 0→0.3 shatter animation when consumed
var _brittle_frags      : Array   = []    # [{x,y,vx,vy,t}] shatter fragments
var _base_speed    : float   = 0.0
var _travel_dir    : Vector2 = Vector2.RIGHT
var _wobble_offset : Vector2 = Vector2.ZERO

var _dot_timer          : float   = 0.0
var _dead               : bool    = false
var _dying              : bool    = false  # body hidden, waiting for floats to finish

var _dmg_floats         : Array   = []   # [{val, x, y, timer}] floating damage numbers

var is_bleeding         : bool    = false
var _bleed_trail        : Array   = []   # Array of {pos: Vector2, age: float}
var _bleed_trail_timer  : float   = 0.0
var _bleed_duration     : float   = 0.0   # seconds of bleed remaining

var _knockback_active   : bool    = false
var _knockback_timer    : float   = 0.0
var _knockback_duration : float   = 0.45
var _knockback_start    : Vector2 = Vector2.ZERO
var _knockback_end      : Vector2 = Vector2.ZERO
var _knockback_arc_y    : float   = 0.0   # visual elevation offset (negative = upward)
const _KNOCKBACK_HEIGHT : float   = 38.0


func setup(path: Array, enemy_hp: float, enemy_speed: float,
		   enemy_reward: float, boss: bool = false,
		   e_type: int = 0, b_stage: int = 1) -> void:
	_path       = path
	hp          = enemy_hp
	max_hp      = enemy_hp
	speed       = enemy_speed
	_base_speed = enemy_speed
	reward      = enemy_reward
	is_boss     = boss
	enemy_type  = e_type
	boss_stage  = b_stage
	position    = _path[0]
	_current_wp = 1
	add_to_group("enemies")


func apply_mild_slow(duration: float) -> void:
	_mild_slow_timer = max(_mild_slow_timer, duration)
	_recalc_speed()

func apply_frost_slow(duration: float) -> void:
	_frost_slow_timer = max(_frost_slow_timer, duration)
	_recalc_speed()

func is_slowed() -> bool:
	return _slow_timer > 0.0 or _chrono_timer > 0.0 or _mild_slow_timer > 0.0 or _frost_slow_timer > 0.0

func apply_slow(duration: float, factor: float = 0.5) -> void:
	if _base_speed > 0.0:
		_slow_timer = max(_slow_timer, duration)
		_recalc_speed()

func apply_chrono_slow(duration: float) -> void:
	# Chrono Mage: 15% slow, stacks multiplicatively with apply_slow
	_chrono_timer = max(_chrono_timer, duration)
	_recalc_speed()

func _recalc_speed() -> void:
	if _base_speed <= 0.0:
		return
	if is_taunted:
		speed = 0.0
		return
	var s := _base_speed
	if _slow_timer > 0.0:
		s *= 0.75 if is_boss else 0.5    # regular slow: 50% (25% on bosses)
	if _chrono_timer > 0.0:
		s *= 0.925 if is_boss else 0.85  # chrono slow: 15% (7.5% on bosses)
	if _mild_slow_timer > 0.0:
		s *= 0.90                        # dual debuff: 10% slow (no boss resistance)
	if _frost_slow_timer > 0.0:
		s *= 0.95                        # frost herald: 5% slow
	speed = s

func _recalc_damage_mult() -> void:
	var mult         := 1.0
	var poison_bonus : float = 0.10 if not is_boss else 0.05
	mult += poison_stacks * poison_bonus
	var taunt_bonus  : float = 0.20 if not is_boss else 0.10
	if is_taunted:
		mult += taunt_bonus
	damage_taken_mult = mult

func apply_taunt(duration: float) -> void:
	is_taunted   = true
	var eff_dur  : float = duration * (0.5 if is_boss else 1.0)
	_taunt_timer = max(_taunt_timer, eff_dur)
	_recalc_speed()
	_recalc_damage_mult()


func apply_bleed() -> void:
	is_bleeding      = true
	_bleed_duration  = max(_bleed_duration, 3.0)   # refresh/extend bleed to 3s


func apply_poison(duration: float) -> void:
	is_poisoned   = true
	poison_timer  = max(poison_timer, duration)   # refresh duration, don't shorten
	poison_stacks = min(poison_stacks + 1, 3)
	_recalc_damage_mult()


func pushback() -> void:
	if is_boss or _knockback_active:
		return
	_knockback_active   = true
	_knockback_timer    = 0.0
	_knockback_start    = position
	_knockback_end      = position - _travel_dir * 70.0
	_knockback_arc_y    = 0.0


func _process(delta: float) -> void:
	# Dying: only tick floats, then free
	if _dying:
		if not _dmg_floats.is_empty():
			for i in range(_dmg_floats.size() - 1, -1, -1):
				_dmg_floats[i]["timer"] -= delta
				_dmg_floats[i]["y"]     += delta * 38.0
				if _dmg_floats[i]["timer"] <= 0.0:
					_dmg_floats.remove_at(i)
			queue_redraw()
		else:
			queue_free()
		return
	_anim_time += delta
	if _knockback_active:
		_knockback_timer += delta
		var t := minf(_knockback_timer / _knockback_duration, 1.0)
		position        = _knockback_start.lerp(_knockback_end, t)
		_knockback_arc_y = -sin(t * PI) * _KNOCKBACK_HEIGHT
		queue_redraw()
		if t >= 1.0:
			_knockback_active = false
			_knockback_arc_y  = 0.0
		return
	# Bleed trail tracking
	if is_bleeding:
		_bleed_duration -= delta
		if _bleed_duration <= 0.0:
			is_bleeding = false
		else:
			_bleed_trail_timer -= delta
			if _bleed_trail_timer <= 0.0:
				_bleed_trail_timer = 0.12
				_bleed_trail.append({"pos": position, "age": 0.0})
	# Age and prune trail entries
	for i in range(_bleed_trail.size() - 1, -1, -1):
		_bleed_trail[i]["age"] += delta
		if _bleed_trail[i]["age"] >= 1.5:
			_bleed_trail.remove_at(i)

	var _speed_changed := false
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_timer = 0.0
			_speed_changed = true
	if _chrono_timer > 0.0:
		_chrono_timer -= delta
		if _chrono_timer <= 0.0:
			_chrono_timer = 0.0
			_speed_changed = true
	if _mild_slow_timer > 0.0:
		_mild_slow_timer -= delta
		if _mild_slow_timer <= 0.0:
			_mild_slow_timer = 0.0
			_speed_changed = true
	if _frost_slow_timer > 0.0:
		_frost_slow_timer -= delta
		if _frost_slow_timer <= 0.0:
			_frost_slow_timer = 0.0
			_speed_changed = true
	if _speed_changed:
		_recalc_speed()
	# Brittle icon pop-in
	if _brittle_popin_t > 0.0:
		_brittle_popin_t = max(0.0, _brittle_popin_t - delta)
	# Brittle shatter animation
	if _brittle_shatter_t > 0.0:
		_brittle_shatter_t = max(0.0, _brittle_shatter_t - delta)
		for _bf in _brittle_frags:
			_bf["x"] += _bf["vx"] * delta
			_bf["y"] += _bf["vy"] * delta
			_bf["vy"] += 180.0 * delta   # gravity
		if _brittle_shatter_t <= 0.0:
			_brittle_frags.clear()
	if _taunt_timer > 0.0:
		_taunt_timer -= delta
		if _taunt_timer <= 0.0:
			is_taunted = false
			_recalc_speed()
			_recalc_damage_mult()
	if poison_timer > 0.0:
		poison_timer -= delta
		if poison_timer <= 0.0:
			is_poisoned   = false
			poison_stacks = 0
			_recalc_damage_mult()
	if GameData.buff_dot_dps > 0.0:
		_dot_timer += delta
		if _dot_timer >= 1.0:
			_dot_timer -= 1.0
			take_damage(GameData.buff_dot_dps, true)
	if _current_wp >= _path.size():
		if not _dead:
			_dead = true
			remove_from_group("enemies")   # match the take_damage() path
			reached_end.emit()
			queue_free()
		return
	var target    := _path[_current_wp] as Vector2
	var to_target : Vector2 = target - position
	if to_target.length() < 6.0:
		_current_wp += 1
	else:
		var dir : Vector2 = to_target.normalized()
		_travel_dir = dir
		var _move_spd : float = speed
		if GameData.debuff_wounded_speed and hp < max_hp * 0.5:
			_move_spd *= 1.20
		position += dir * minf(_move_spd * delta, to_target.length())
	# Perpendicular wobble — oscillates sideways relative to travel direction
	var perp : Vector2 = Vector2(-_travel_dir.y, _travel_dir.x)
	var amp  : float   = 4.0 if not is_boss else 2.5
	_wobble_offset = perp * sin(_anim_time * 5.5) * amp
	# Tick floating damage numbers
	if not _dmg_floats.is_empty():
		for i in range(_dmg_floats.size() - 1, -1, -1):
			_dmg_floats[i]["timer"] -= delta
			_dmg_floats[i]["y"]     += delta * 38.0
			if _dmg_floats[i]["timer"] <= 0.0:
				_dmg_floats.remove_at(i)
	queue_redraw()


func take_melee_damage(amount: float) -> void:
	take_damage(amount * (1.0 - melee_resist))


func heal(amount: float) -> void:
	if _dead:
		return
	hp = min(max_hp, hp + amount)
	if GameData.show_damage_numbers:
		_dmg_floats.append({"val": amount, "x": randf_range(-6.0, 6.0), "y": 0.0, "timer": 1.0, "heal": true})
	queue_redraw()


func take_damage(amount: float, from_dot: bool = false) -> void:
	if _dead:
		return
	if GameData.debuff_armor and not from_dot:
		amount = max(0.0, amount - 3.0)
	var _brittle := brittle_bonus
	if _brittle > 0.0:
		brittle_bonus      = 0.0
		_brittle_shatter_t = 0.3
		_brittle_frags.clear()
		# Spawn 6 small rock fragments flying outward from icon position
		var _icon_x : float = (35.0 if not is_boss else 50.0)
		var _icon_y : float = -46.0 if is_boss else -30.0
		for _fi in range(6):
			var _fa : float = _fi * TAU / 6.0 + randf_range(-0.3, 0.3)
			var _fspd : float = randf_range(30.0, 70.0)
			_brittle_frags.append({
				"x": _icon_x, "y": _icon_y,
				"vx": cos(_fa) * _fspd, "vy": sin(_fa) * _fspd - 20.0,
				"t": randf_range(0.05, 0.12)
			})
	else:
		brittle_bonus = 0.0
	var _actual : float = (amount + _brittle) * damage_taken_mult
	hits_taken += 1
	hp = max(0.0, hp - _actual)
	if is_dummy:
		hp = maxf(1.0, hp)
	# Spawn floating damage number (only if enabled in settings)
	if GameData.show_damage_numbers:
		var _x_jitter : float = randf_range(-6.0, 6.0)
		_dmg_floats.append({"val": _actual, "x": _x_jitter, "y": 0.0, "timer": 1.0})
	queue_redraw()
	if hp <= 0.0:
		_dead  = true
		_dying = true
		remove_from_group("enemies")   # stop towers targeting this enemy
		died.emit(reward)
		# Don't queue_free yet — let floats finish (_process will free when done)


func _draw() -> void:
	# Dying: only draw the floating numbers, nothing else
	if _dying:
		if not _dmg_floats.is_empty():
			var _fnt  : Font  = ThemeDB.fallback_font
			var _fnsz : int   = 14
			var _by   : float = -38.0 if is_boss else -28.0
			for _df in _dmg_floats:
				var _t     : float   = _df["timer"] as float
				var _alpha : float   = _t * _t
				var _txt   : String  = "%.0f" % (_df["val"] as float)
				var _tw    : float   = _fnt.get_string_size(_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, _fnsz).x
				var _pos   : Vector2 = Vector2(_df["x"] - _tw * 0.5, _by - _df["y"])
				draw_string(_fnt, _pos + Vector2(1, 1), _txt,
					HORIZONTAL_ALIGNMENT_LEFT, -1, _fnsz, Color(0.0, 0.0, 0.0, _alpha * 0.80))
				draw_string(_fnt, _pos, _txt,
					HORIZONTAL_ALIGNMENT_LEFT, -1, _fnsz, Color(1.0, 0.95, 0.25, _alpha))
		return

	# Bleed trail — drawn in world-relative local coords before any transform
	for entry in _bleed_trail:
		var age_frac : float   = entry["age"]
		age_frac /= 1.5
		var alpha    : float   = (1.0 - age_frac) * 0.70
		var radius   : float   = 2.8 - age_frac * 1.2
		var drop     : Vector2 = (entry["pos"] as Vector2) - position
		draw_circle(drop, radius, Color(0.72, 0.06, 0.10, alpha))
		# Small drip streak
		draw_line(drop, drop + Vector2(0, radius * 1.2), Color(0.60, 0.04, 0.08, alpha * 0.6), 1.0)

	# Ground shadow while airborne — shrinks as enemy rises
	if _knockback_active and _knockback_arc_y < -4.0:
		var rise_frac := absf(_knockback_arc_y) / _KNOCKBACK_HEIGHT
		var shadow_r  := (22.0 if is_boss else 15.0) * (1.0 - rise_frac * 0.6)
		draw_circle(Vector2.ZERO, shadow_r, Color(0.0, 0.0, 0.0, 0.28 * (1.0 - rise_frac * 0.5)))

	# Body — wobble + arc elevation
	draw_set_transform(_wobble_offset + Vector2(0.0, _knockback_arc_y), 0.0, Vector2.ONE)
	if is_taunt_tank:
		_draw_taunt_tank()
	elif is_boss:
		_draw_boss()
	else:
		_draw_enemy()
	if is_slowed():
		# Use the longest remaining slow timer for alpha, so faint slows still show
		var sa := clampf(maxf(maxf(_slow_timer, _chrono_timer), maxf(_mild_slow_timer, _frost_slow_timer)), 0.0, 1.0)
		# Clamp to a visible minimum so short-duration slows (e.g. 5%) are always readable
		sa = maxf(sa, 0.35)
		var r  := 24.0 if is_boss else 18.0
		draw_circle(Vector2.ZERO, r, Color(0.45, 0.82, 1.0, 0.18 * sa))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(0.55, 0.90, 1.0, 0.60 * sa), 2.0)
		# Rotating accent tick marks so the ring looks like a frost effect
		var tick_angle := fmod(_anim_time * 1.2, TAU)
		for t in range(6):
			var a : float = tick_angle + t * (TAU / 6.0)
			var p : Vector2 = Vector2(cos(a), sin(a)) * r
			draw_line(p * 0.82, p, Color(0.75, 0.95, 1.0, 0.70 * sa), 1.5)
	if is_poisoned:
		var pa := 0.18 + sin(_anim_time * 5.0) * 0.08
		var pr  := 22.0 if is_boss else 16.0
		draw_circle(Vector2.ZERO, pr, Color(0.30, 0.88, 0.20, pa))
		draw_arc(Vector2.ZERO, pr, 0.0, TAU, 20, Color(0.42, 1.0, 0.28, pa * 2.5), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# HP bar stays fixed (no wobble)
	_draw_hp_bar()
	# Floating damage numbers
	if not _dmg_floats.is_empty():
		var _fnt  : Font  = ThemeDB.fallback_font
		var _fnsz : int   = 14
		var _by   : float = -38.0 if is_boss else -28.0
		for _df in _dmg_floats:
			var _t     : float   = _df["timer"] as float
			var _alpha : float   = _t * _t
			var _is_heal : bool  = _df.get("heal", false)
			var _txt   : String  = ("%s%.0f" % ["+" if _is_heal else "", _df["val"] as float])
			# Centre horizontally over the hit point
			var _tw    : float   = _fnt.get_string_size(_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, _fnsz).x
			var _pos   : Vector2 = Vector2(_df["x"] - _tw * 0.5, _by - _df["y"])
			# Dark shadow for readability
			draw_string(_fnt, _pos + Vector2(1, 1), _txt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, _fnsz, Color(0.0, 0.0, 0.0, _alpha * 0.80))
			# Heal = bright green, damage = bright yellow-white
			var _num_col : Color = Color(0.25, 1.0, 0.45, _alpha) if _is_heal else Color(1.0, 0.95, 0.25, _alpha)
			draw_string(_fnt, _pos, _txt, HORIZONTAL_ALIGNMENT_LEFT, -1, _fnsz, _num_col)


func _draw_hp_bar() -> void:
	var bar_w : float = 70.0 if is_boss else (60.0 if is_taunt_tank else 40.0)
	var bar_h : float = 6.0
	var by    : float = -46.0 if is_boss else (-44.0 if is_taunt_tank else -30.0)
	var bx    : float = -bar_w * 0.5
	var frac  : float = clampf(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(bx, by, bar_w, bar_h), Color(0.10, 0.08, 0.12))
	var col : Color
	if frac > 0.5: col = Color(0.20, 0.85, 0.35) if not is_boss else Color(0.72, 0.15, 0.88)
	else:          col = Color(0.95, 0.15, 0.15)
	draw_rect(Rect2(bx, by, bar_w * frac, bar_h), col)

	# Brittle debuff icon — cracked earth, drawn to the right of the HP bar
	var _icon_cx : float = bx + bar_w + 9.0
	var _icon_cy : float = by + bar_h * 0.5
	if brittle_bonus > 0.0:
		# Pop-in scale: 0.15s → goes from 0 to 1 with slight overshoot
		var _raw_t  : float = 1.0 - (_brittle_popin_t / 0.15)
		var _scale  : float = 1.1 - 0.1 * cos(_raw_t * PI) if _brittle_popin_t > 0.0 else 1.0
		var ir      : float = 5.0 * _scale
		draw_set_transform(Vector2(_icon_cx, _icon_cy), 0.0, Vector2.ONE)
		draw_circle(Vector2.ZERO, ir, Color(0.62, 0.42, 0.20))
		draw_arc(Vector2.ZERO, ir, 0.0, TAU, 20, Color(0.82, 0.60, 0.28), 1.0)
		for _ci in range(6):
			var _ca  : float = _ci * TAU / 6.0
			var _len : float = ir * (0.5 if _ci % 2 == 0 else 0.85)
			draw_line(Vector2.ZERO,
					  Vector2(cos(_ca) * _len, sin(_ca) * _len),
					  Color(0.20, 0.12, 0.06), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Shatter fragments when brittle is consumed
	if _brittle_shatter_t > 0.0:
		var _sf_alpha : float = _brittle_shatter_t / 0.3
		for _bf in _brittle_frags:
			draw_circle(Vector2(_bf["x"], _bf["y"]), _bf["t"] * 6.0,
						Color(0.58, 0.38, 0.18, _sf_alpha))


func _draw_taunt_tank() -> void:
	var pulse : float = 0.55 + sin(_anim_time * 3.0) * 0.20
	# Outer glow ring
	draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 32, Color(0.85, 0.12, 0.10, pulse * 0.55), 4.0)
	# Armored body
	draw_circle(Vector2.ZERO, 21.0, Color(0.30, 0.30, 0.34))
	draw_arc(Vector2.ZERO, 21.0, 0.0, TAU, 32, Color(0.58, 0.58, 0.64), 2.5)
	# Armor plate seams
	draw_line(Vector2(-15, 0), Vector2(15, 0), Color(0.16, 0.16, 0.20, 0.7), 2.0)
	draw_line(Vector2(0, -15), Vector2(0, 6), Color(0.16, 0.16, 0.20, 0.7), 2.0)
	# Shield (kite shape)
	var sh := PackedVector2Array([
		Vector2(0, -13), Vector2(10, -4), Vector2(10, 6), Vector2(0, 14), Vector2(-10, 6), Vector2(-10, -4)
	])
	draw_colored_polygon(sh, Color(0.62, 0.10, 0.10, 0.95))
	draw_polyline(PackedVector2Array([sh[0], sh[1], sh[2], sh[3], sh[4], sh[5], sh[0]]),
		Color(0.92, 0.22, 0.18), 1.5)
	# Shield center cross
	draw_line(Vector2(0, -10), Vector2(0, 10), Color(0.90, 0.80, 0.20, 0.8), 1.5)
	draw_line(Vector2(-7, 0), Vector2(7, 0), Color(0.90, 0.80, 0.20, 0.8), 1.5)
	# Eyes (visor slits)
	draw_line(Vector2(-7, -5), Vector2(-3, -5), Color(0.95, 0.35, 0.10), 2.0)
	draw_line(Vector2( 3, -5), Vector2( 7, -5), Color(0.95, 0.35, 0.10), 2.0)


func _draw_enemy() -> void:
	match enemy_type:
		0: _draw_slime()
		1: _draw_goblin()
		2: _draw_skeleton()
		3: _draw_orc()
		4: _draw_shadow()
		_: _draw_slime()


func _draw_boss() -> void:
	match boss_stage:
		1:  _draw_boss_slime_king()
		2:  _draw_boss_goblin_warchief()
		3:  _draw_boss_lich()
		4:  _draw_boss_golem()
		5:  _draw_boss_werewolf()
		6:  _draw_boss_dragon()
		7:  _draw_boss_ice_giant()
		8:  _draw_boss_shadow_demon()
		9:  _draw_boss_helldrake()
		10: _draw_boss_dark_lord()
		_:  _draw_boss_slime_king()


# ══════════════════════════════════════════════════════════════════════════════
# REGULAR ENEMIES
# ══════════════════════════════════════════════════════════════════════════════

func _draw_slime() -> void:
	var t    := _anim_time
	var w    := sin(t * 3.8) * 2.2
	var col  := Color(0.18, 0.78, 0.25)
	var dark := Color(0.08, 0.46, 0.14)
	var lite := Color(0.40, 0.95, 0.48)
	# Drop shadow
	draw_circle(Vector2(1, 19), 13, Color(0, 0, 0, 0.18))
	# Body layers for depth
	draw_circle(Vector2(0, 3 + w * 0.15), 18 + w * 0.4, dark)
	draw_circle(Vector2(0, 2 + w * 0.10), 17 + w * 0.4, col)
	# Translucent inner glow
	draw_circle(Vector2(0, 2), 13, Color(lite.r, lite.g, lite.b, 0.22))
	# Internal bubbles
	draw_circle(Vector2( 6, 5), 4.5, Color(lite.r, lite.g, lite.b, 0.30))
	draw_circle(Vector2(-5, 7), 3.0, Color(lite.r, lite.g, lite.b, 0.22))
	draw_circle(Vector2( 5, 7), 2.0, Color(lite.r, lite.g, lite.b, 0.18))
	# Primary specular highlight
	draw_circle(Vector2(-5, -7), 6.5, Color(1, 1, 1, 0.50))
	draw_circle(Vector2(-4, -9), 3.0, Color(1, 1, 1, 0.75))
	# Outline
	draw_circle(Vector2(0, 2), 18, dark, false, 2.0)
	# Sclera
	draw_circle(Vector2(-6, -1), 5.5, Color(0.96, 0.98, 0.94))
	draw_circle(Vector2( 6, -1), 5.5, Color(0.96, 0.98, 0.94))
	# Iris
	draw_circle(Vector2(-5.5, -1), 3.5, Color(0.05, 0.48, 0.14))
	draw_circle(Vector2( 6.5, -1), 3.5, Color(0.05, 0.48, 0.14))
	# Pupil
	draw_circle(Vector2(-5.5, -1), 2.0, Color(0.02, 0.02, 0.02))
	draw_circle(Vector2( 6.5, -1), 2.0, Color(0.02, 0.02, 0.02))
	# Eye shine
	draw_circle(Vector2(-7.0, -2.5), 1.1, Color(1, 1, 1, 0.90))
	draw_circle(Vector2( 5.0, -2.5), 1.1, Color(1, 1, 1, 0.90))
	# Mouth
	draw_arc(Vector2(0, 5), 5, 0.25, PI - 0.25, 10, dark, 2.0)
	# Tongue
	draw_circle(Vector2(0, 7), 2.5, Color(0.85, 0.28, 0.28))


func _draw_goblin() -> void:
	var t       := _anim_time
	var bob     := sin(t * 3.2) * 1.2
	var skin    := Color(0.32, 0.56, 0.16)
	var skin_d  := Color(0.18, 0.34, 0.08)
	var skin_l  := Color(0.48, 0.72, 0.26)
	var leather := Color(0.32, 0.20, 0.08)
	var leath_l := Color(0.50, 0.34, 0.16)
	var steel   := Color(0.52, 0.50, 0.46)
	var steel_l := Color(0.70, 0.68, 0.62)
	var eye_w   := Color(0.94, 0.90, 0.82)
	var eye_c   := Color(0.72, 0.32, 0.04)
	var bone_c  := Color(0.84, 0.80, 0.68)

	# Shadow
	draw_circle(Vector2(1, 21 + bob), 11, Color(0, 0, 0, 0.16))

	# Legs — bent/crouched stance
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, 6 + bob), Vector2(-3, 6 + bob),
		Vector2(-2, 20 + bob), Vector2(-11, 20 + bob)
	]), skin_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(3, 6 + bob), Vector2(10, 6 + bob),
		Vector2(11, 20 + bob), Vector2(2, 20 + bob)
	]), skin_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9, 6 + bob), Vector2(-3, 6 + bob),
		Vector2(-2, 20 + bob), Vector2(-10, 20 + bob)
	]), skin)
	draw_colored_polygon(PackedVector2Array([
		Vector2(3, 6 + bob), Vector2(9, 6 + bob),
		Vector2(10, 20 + bob), Vector2(2, 20 + bob)
	]), skin)
	# Foot wraps
	draw_rect(Rect2(-12, 18 + bob, 10, 4), leather)
	draw_rect(Rect2(  2, 18 + bob, 10, 4), leather)
	draw_line(Vector2(-12, 19 + bob), Vector2(-2, 19 + bob), leath_l, 1.0)
	draw_line(Vector2(  2, 19 + bob), Vector2(12, 19 + bob), leath_l, 1.0)

	# Torso — leather vest with shading
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -4 + bob), Vector2(10, -4 + bob),
		Vector2(11,  8 + bob),  Vector2(-11,  8 + bob)
	]), skin_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9, -4 + bob), Vector2(9, -4 + bob),
		Vector2(10,  8 + bob), Vector2(-10,  8 + bob)
	]), leather)
	# Left-side vest highlight
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9, -4 + bob), Vector2(-1, -4 + bob),
		Vector2(-1,  8 + bob), Vector2(-9,  8 + bob)
	]), leath_l)
	# Strap details
	draw_line(Vector2(0, -4 + bob), Vector2(0, 8 + bob), leath_l, 1.5)
	# Belt
	draw_rect(Rect2(-11, 5 + bob, 22, 5), Color(0.22, 0.14, 0.05))
	# Belt buckle
	draw_rect(Rect2(-3, 5 + bob, 6, 5), steel)
	draw_rect(Rect2(-2, 6 + bob, 4, 3), leather)
	# Rivet details on vest
	for rx in [-7, 7]:
		draw_circle(Vector2(rx, 0 + bob), 1.2, steel_l)

	# Arms — left holds weapon, right reaches forward
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -3 + bob), Vector2(-16, -1 + bob),
		Vector2(-18,  6 + bob), Vector2(-12,  6 + bob)
	]), skin_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9, -3 + bob), Vector2(-15, -1 + bob),
		Vector2(-17,  6 + bob), Vector2(-11,  6 + bob)
	]), skin)
	draw_colored_polygon(PackedVector2Array([
		Vector2(10, -3 + bob), Vector2(16, -1 + bob),
		Vector2(18,  6 + bob), Vector2(12,  6 + bob)
	]), skin_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(10, -3 + bob), Vector2(15, -1 + bob),
		Vector2(17,  6 + bob), Vector2(11,  6 + bob)
	]), skin)
	# Knuckles
	draw_circle(Vector2(-17, 5 + bob), 4, skin)
	draw_circle(Vector2( 17, 5 + bob), 4, skin)

	# Crude bone club weapon
	draw_line(Vector2(-17, 4 + bob), Vector2(-26, -12 + bob), Color(0.60, 0.50, 0.34), 4.0)
	draw_line(Vector2(-17, 4 + bob), Vector2(-26, -12 + bob), Color(0.44, 0.36, 0.22), 2.0)
	draw_circle(Vector2(-27, -14 + bob), 5.5, bone_c)
	draw_circle(Vector2(-30, -11 + bob), 4.0, bone_c)
	draw_circle(Vector2(-25, -18 + bob), 3.5, bone_c)
	draw_circle(Vector2(-27, -14 + bob), 3, Color(0.72, 0.68, 0.56))

	# HEAD — angular, menacing proportions
	# Shadow under jaw
	draw_circle(Vector2(1, -11 + bob), 13, skin_d)
	# Main head
	draw_circle(Vector2(0, -13 + bob), 13, skin)
	# Subtle light from top-left
	draw_circle(Vector2(-4, -18 + bob), 7, Color(skin_l.r, skin_l.g, skin_l.b, 0.38))

	# Large pointed ears
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -19 + bob), Vector2(-22, -15 + bob),
		Vector2(-20,  -7 + bob), Vector2(-11, -10 + bob)
	]), skin)
	draw_colored_polygon(PackedVector2Array([
		Vector2( 11, -19 + bob), Vector2( 22, -15 + bob),
		Vector2( 20,  -7 + bob), Vector2( 11, -10 + bob)
	]), skin)
	# Inner ear
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -17 + bob), Vector2(-19, -14 + bob),
		Vector2(-18, -10 + bob), Vector2(-13, -12 + bob)
	]), Color(0.68, 0.38, 0.38))
	draw_colored_polygon(PackedVector2Array([
		Vector2( 12, -17 + bob), Vector2( 19, -14 + bob),
		Vector2( 18, -10 + bob), Vector2( 13, -12 + bob)
	]), Color(0.68, 0.38, 0.38))
	# Ear shadow outline
	draw_polyline(PackedVector2Array([
		Vector2(-11, -19 + bob), Vector2(-22, -15 + bob),
		Vector2(-20,  -7 + bob)
	]), skin_d, 1.0)
	draw_polyline(PackedVector2Array([
		Vector2( 11, -19 + bob), Vector2( 22, -15 + bob),
		Vector2( 20,  -7 + bob)
	]), skin_d, 1.0)

	# Brow ridge — deeply furrowed, angry
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -21 + bob), Vector2(-2, -23 + bob),
		Vector2( -1, -20 + bob), Vector2(-10, -18 + bob)
	]), skin_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2( 12, -21 + bob), Vector2( 2, -23 + bob),
		Vector2(  1, -20 + bob), Vector2( 10, -18 + bob)
	]), skin_d)

	# Eyes — sunken, mean
	draw_circle(Vector2(-5, -18 + bob), 4.5, Color(0.12, 0.08, 0.06))
	draw_circle(Vector2( 5, -18 + bob), 4.5, Color(0.12, 0.08, 0.06))
	draw_circle(Vector2(-5, -18 + bob), 3.5, eye_w)
	draw_circle(Vector2( 5, -18 + bob), 3.5, eye_w)
	draw_circle(Vector2(-4.5, -18 + bob), 2.2, eye_c)
	draw_circle(Vector2( 5.5, -18 + bob), 2.2, eye_c)
	draw_circle(Vector2(-4.5, -18 + bob), 1.2, Color(0.04, 0.02, 0.01))
	draw_circle(Vector2( 5.5, -18 + bob), 1.2, Color(0.04, 0.02, 0.01))
	draw_circle(Vector2(-6.2, -19.5 + bob), 0.8, Color(1, 1, 1, 0.85))
	draw_circle(Vector2( 4.0, -19.5 + bob), 0.8, Color(1, 1, 1, 0.85))

	# Nose — broad flat snout
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, -14 + bob), Vector2(5, -14 + bob),
		Vector2(6, -9 + bob),  Vector2(-6, -9 + bob)
	]), skin_d)
	draw_circle(Vector2(-2.5, -10 + bob), 2.2, skin_d.darkened(0.35))
	draw_circle(Vector2( 2.5, -10 + bob), 2.2, skin_d.darkened(0.35))

	# Mouth — open sneer showing teeth and tusks
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -7 + bob), Vector2(6, -7 + bob),
		Vector2(5, -2 + bob),  Vector2(-5, -2 + bob)
	]), Color(0.18, 0.06, 0.04))
	# Upper lip line
	draw_line(Vector2(-6, -7 + bob), Vector2(6, -7 + bob), skin_d, 1.5)
	# Teeth row
	for i in range(3):
		draw_rect(Rect2(-3.5 + i * 3, -7 + bob, 2.5, 3), Color(0.90, 0.86, 0.76))
	# Lower tusks (longer)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3, -3 + bob), Vector2(-1, -3 + bob), Vector2(-2, -8 + bob)
	]), Color(0.90, 0.86, 0.76))
	draw_colored_polygon(PackedVector2Array([
		Vector2( 1, -3 + bob), Vector2( 3, -3 + bob), Vector2( 2, -8 + bob)
	]), Color(0.90, 0.86, 0.76))
	# Wart
	draw_circle(Vector2(4, -12 + bob), 1.5, skin_d.darkened(0.2))


func _draw_skeleton() -> void:
	var t    := _anim_time
	var bob  := sin(t * 2.8) * 1.5
	var bone := Color(0.86, 0.84, 0.74)
	var bone_d:= Color(0.58, 0.55, 0.44)
	var bone_l:= Color(0.96, 0.94, 0.88)
	var dark := Color(0.12, 0.10, 0.08)
	var glow := Color(0.05, 0.90, 0.58)
	var rust := Color(0.55, 0.32, 0.12)

	# Shadow
	draw_circle(Vector2(1, 21 + bob), 11, Color(0, 0, 0, 0.16))

	# Pelvis / hip bones
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, 4 + bob), Vector2(8, 4 + bob),
		Vector2(10, 16 + bob), Vector2(-10, 16 + bob)
	]), bone)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, 4 + bob), Vector2(8, 4 + bob),
		Vector2(10, 16 + bob), Vector2(-10, 16 + bob)
	]), bone_d)
	draw_polyline(PackedVector2Array([
		Vector2(-8, 4 + bob), Vector2(8, 4 + bob),
		Vector2(10, 16 + bob), Vector2(-10, 16 + bob),
		Vector2(-8, 4 + bob)
	]), bone_d, 1.2)
	# Hip line detail
	draw_line(Vector2(-8, 10 + bob), Vector2(8, 10 + bob), bone_d, 1.5)

	# Leg bones
	draw_line(Vector2(-5, 16 + bob), Vector2(-6, 22 + bob), bone, 4.0)
	draw_line(Vector2( 5, 16 + bob), Vector2( 6, 22 + bob), bone, 4.0)
	draw_circle(Vector2(-5, 16 + bob), 3.5, bone)
	draw_circle(Vector2( 5, 16 + bob), 3.5, bone)

	# Spine
	for i in range(4):
		var sy := -6.0 + i * 4.0 + bob
		draw_circle(Vector2(0, sy), 3.0, bone)
		draw_circle(Vector2(0, sy), 3.0, bone_d, false, 1.0)
		if i < 3:
			draw_line(Vector2(0, sy + 2), Vector2(0, sy + 4), bone_d, 1.5)

	# Ribcage — individual ribs with shading
	for i in range(4):
		var ry := -4.0 + i * 4.0 + bob
		var rw := 9.0 - i * 0.8
		# Left rib
		draw_arc(Vector2(-rw * 0.2, ry), rw, -PI * 0.9, -PI * 0.1, 8, bone, 3.0)
		draw_arc(Vector2(-rw * 0.2, ry), rw, -PI * 0.9, -PI * 0.1, 8, bone_l, 1.0)
		# Right rib
		draw_arc(Vector2( rw * 0.2, ry), rw, -PI * 0.9, -PI * 0.1, 8, bone, 3.0)
		draw_arc(Vector2( rw * 0.2, ry), rw * 0.95, -PI * 0.9, -PI * 0.1, 8, bone_d, 1.0)

	# Shoulder blades and collar bone
	draw_line(Vector2(-10, -8 + bob), Vector2(10, -8 + bob), bone, 4.0)
	draw_line(Vector2(-10, -8 + bob), Vector2(10, -8 + bob), bone_l, 1.5)
	draw_circle(Vector2(-10, -8 + bob), 4, bone)
	draw_circle(Vector2( 10, -8 + bob), 4, bone)

	# Upper arms
	draw_line(Vector2(-10, -8 + bob), Vector2(-20,  2 + bob), bone, 4.5)
	draw_line(Vector2( 10, -8 + bob), Vector2( 20,  2 + bob), bone, 4.5)
	draw_line(Vector2(-10, -8 + bob), Vector2(-20,  2 + bob), bone_l, 1.5)
	draw_line(Vector2( 10, -8 + bob), Vector2( 20,  2 + bob), bone_l, 1.5)
	# Elbow joints
	draw_circle(Vector2(-20, 2 + bob), 3.5, bone)
	draw_circle(Vector2( 20, 2 + bob), 3.5, bone)
	# Forearms
	draw_line(Vector2(-20, 2 + bob), Vector2(-22, 12 + bob), bone, 3.5)
	draw_line(Vector2( 20, 2 + bob), Vector2( 22, 12 + bob), bone, 3.5)

	# Rusted sword in right hand
	draw_line(Vector2(22, 12 + bob), Vector2(30, -8 + bob), rust, 3.5)
	draw_line(Vector2(22, 12 + bob), Vector2(30, -8 + bob), Color(0.72, 0.46, 0.20), 1.5)
	draw_line(Vector2(24, 4 + bob), Vector2(32, 4 + bob), bone, 3.0)  # crossguard
	draw_circle(Vector2(22, 12 + bob), 3, bone)  # grip wrap

	# SKULL
	# Back of skull (shadow)
	draw_circle(Vector2(1, -18 + bob), 12, bone_d)
	# Main skull dome
	draw_circle(Vector2(0, -19 + bob), 12, bone)
	# Highlight on upper-left
	draw_circle(Vector2(-4, -24 + bob), 6, Color(bone_l.r, bone_l.g, bone_l.b, 0.55))
	# Outline
	draw_circle(Vector2(0, -19 + bob), 12, bone_d, false, 1.5)

	# Zygomatic arch / cheekbones
	draw_circle(Vector2(-10, -17 + bob), 4, bone)
	draw_circle(Vector2( 10, -17 + bob), 4, bone)

	# Deep eye sockets
	draw_circle(Vector2(-4.5, -21 + bob), 5, dark)
	draw_circle(Vector2( 4.5, -21 + bob), 5, dark)
	# Glowing soul fire in sockets (pulses)
	var gp := 0.6 + sin(t * 3.5) * 0.4
	draw_circle(Vector2(-4.5, -21 + bob), 3.5, Color(glow.r, glow.g, glow.b, gp))
	draw_circle(Vector2( 4.5, -21 + bob), 3.5, Color(glow.r, glow.g, glow.b, gp))
	draw_circle(Vector2(-4.5, -21 + bob), 1.5, Color(1, 1, 1, gp * 0.8))
	draw_circle(Vector2( 4.5, -21 + bob), 1.5, Color(1, 1, 1, gp * 0.8))

	# Nasal cavity
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2, -16 + bob), Vector2(2, -16 + bob),
		Vector2(3, -12 + bob),  Vector2(-3, -12 + bob)
	]), dark)

	# Teeth (upper jaw)
	draw_rect(Rect2(-7, -12 + bob, 14, 4), bone)
	draw_rect(Rect2(-7, -12 + bob, 14, 4), bone_d, false, 1.0)
	for i in range(4):
		draw_rect(Rect2(-6 + i * 4, -12 + bob, 3, 4), dark)
	# Detached lower jaw (slightly open)
	draw_rect(Rect2(-6, -8 + bob, 12, 4), bone)
	draw_rect(Rect2(-6, -8 + bob, 12, 4), bone_d, false, 1.0)
	for i in range(3):
		draw_rect(Rect2(-5 + i * 4, -8 + bob, 3, 3), dark)


func _draw_orc() -> void:
	var t       := _anim_time
	var bob     := sin(t * 2.5) * 1.0
	var skin    := Color(0.36, 0.52, 0.20)
	var skin_d  := Color(0.22, 0.34, 0.12)
	var skin_l  := Color(0.50, 0.66, 0.30)
	var iron    := Color(0.40, 0.40, 0.46)
	var iron_d  := Color(0.24, 0.24, 0.30)
	var iron_l  := Color(0.60, 0.60, 0.66)
	var leather := Color(0.30, 0.20, 0.08)
	var gold    := Color(0.80, 0.66, 0.14)
	var blood   := Color(0.55, 0.08, 0.06)

	# Shadow
	draw_circle(Vector2(1, 22 + bob), 14, Color(0, 0, 0, 0.18))

	# Greaves / leg armor
	for sx in [-7, 3]:
		draw_rect(Rect2(sx, 6 + bob, 8, 16), iron_d)
		draw_rect(Rect2(sx, 6 + bob, 7, 16), iron)
		draw_rect(Rect2(sx, 6 + bob, 7, 16), iron_d, false, 1.0)
		draw_line(Vector2(sx + 1, 10 + bob), Vector2(sx + 5, 10 + bob), iron_l, 1.0)

	# Torso — heavy breastplate
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -5 + bob), Vector2(13, -5 + bob),
		Vector2(15, 10 + bob),  Vector2(-15, 10 + bob)
	]), iron_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -5 + bob), Vector2(12, -5 + bob),
		Vector2(14, 10 + bob),  Vector2(-14, 10 + bob)
	]), iron)
	# Breastplate left highlight
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -5 + bob), Vector2(-1, -5 + bob),
		Vector2(-1, 10 + bob),  Vector2(-12, 10 + bob)
	]), Color(iron_l.r, iron_l.g, iron_l.b, 0.45))
	# Chest plate center ridge
	draw_line(Vector2(0, -5 + bob), Vector2(0, 10 + bob), iron_l, 2.0)
	# Horizontal plate band
	draw_line(Vector2(-12, 2 + bob), Vector2(12, 2 + bob), iron_d, 1.5)
	# Rivets
	for rx in [-9, -3, 3, 9]:
		draw_circle(Vector2(rx, -2 + bob), 1.2, iron_l)
	# Belt with skull buckle
	draw_rect(Rect2(-14, 7 + bob, 28, 5), leather)
	draw_circle(Vector2(0, 9 + bob), 3.5, iron)
	draw_circle(Vector2(0, 9 + bob), 2.0, iron_d)

	# Large shoulder pauldrons
	draw_circle(Vector2(-17, -4 + bob), 11, iron_d)
	draw_circle(Vector2(-17, -4 + bob), 10, iron)
	draw_circle(Vector2( 17, -4 + bob), 11, iron_d)
	draw_circle(Vector2( 17, -4 + bob), 10, iron)
	draw_arc(Vector2(-17, -4 + bob), 10, -PI, 0, 8, iron_l, 1.5)
	draw_arc(Vector2( 17, -4 + bob), 10, -PI, 0, 8, iron_l, 1.5)
	# Shoulder spikes
	draw_colored_polygon(PackedVector2Array([
		Vector2(-21, -12 + bob), Vector2(-17, -22 + bob), Vector2(-13, -12 + bob)
	]), iron_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20, -12 + bob), Vector2(-17, -21 + bob), Vector2(-14, -12 + bob)
	]), iron_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(21, -12 + bob), Vector2(17, -22 + bob), Vector2(13, -12 + bob)
	]), iron_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(20, -12 + bob), Vector2(17, -21 + bob), Vector2(14, -12 + bob)
	]), iron_l)

	# Muscular arms
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -3 + bob), Vector2(-22, 0 + bob),
		Vector2(-24, 10 + bob), Vector2(-16, 10 + bob)
	]), skin_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -3 + bob), Vector2(-21, 0 + bob),
		Vector2(-23, 10 + bob), Vector2(-15, 10 + bob)
	]), skin)
	draw_colored_polygon(PackedVector2Array([
		Vector2(14, -3 + bob), Vector2(22, 0 + bob),
		Vector2(24, 10 + bob), Vector2(16, 10 + bob)
	]), skin_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(13, -3 + bob), Vector2(21, 0 + bob),
		Vector2(23, 10 + bob), Vector2(15, 10 + bob)
	]), skin)
	# Fists
	draw_circle(Vector2(-22, 10 + bob), 5, skin)
	draw_circle(Vector2( 22, 10 + bob), 5, skin)
	draw_circle(Vector2(-22, 10 + bob), 5, skin_d, false, 1.0)
	draw_circle(Vector2( 22, 10 + bob), 5, skin_d, false, 1.0)
	# Battle axe in left hand
	draw_line(Vector2(-22, 8 + bob), Vector2(-30, -10 + bob), Color(0.40, 0.30, 0.12), 4.0)
	draw_line(Vector2(-22, 8 + bob), Vector2(-30, -10 + bob), Color(0.56, 0.44, 0.22), 1.5)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-26, -10 + bob), Vector2(-36, -18 + bob),
		Vector2(-34, -4 + bob)
	]), iron)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-26, -10 + bob), Vector2(-36, -18 + bob),
		Vector2(-34, -4 + bob)
	]), iron_d)
	draw_polyline(PackedVector2Array([
		Vector2(-26, -10 + bob), Vector2(-36, -18 + bob), Vector2(-34, -4 + bob)
	]), iron_l, 1.0)
	# Blood on axe
	draw_circle(Vector2(-34, -12 + bob), 2.5, blood)
	draw_circle(Vector2(-32, -6 + bob), 1.5, blood)

	# HEAD under heavy helmet
	draw_circle(Vector2(1, -15 + bob), 13, skin_d)
	draw_circle(Vector2(0, -16 + bob), 13, skin)
	draw_circle(Vector2(-4, -21 + bob), 7, Color(skin_l.r, skin_l.g, skin_l.b, 0.35))

	# Iron helmet
	draw_rect(Rect2(-13, -28 + bob, 26, 14), iron_d)
	draw_rect(Rect2(-12, -28 + bob, 24, 14), iron)
	draw_rect(Rect2(-12, -28 + bob, 24, 14), iron_d, false, 1.5)
	draw_line(Vector2(-12, -22 + bob), Vector2(12, -22 + bob), iron_l, 1.5)
	# Helmet horns
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -24 + bob), Vector2(-18, -36 + bob), Vector2(-8, -22 + bob)
	]), iron_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -24 + bob), Vector2(-17, -35 + bob), Vector2(-8, -22 + bob)
	]), iron_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2( 13, -24 + bob), Vector2( 18, -36 + bob), Vector2( 8, -22 + bob)
	]), iron_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2( 12, -24 + bob), Vector2( 17, -35 + bob), Vector2( 8, -22 + bob)
	]), iron_l)
	# Nose guard / visor slit
	draw_rect(Rect2(-1, -28 + bob, 2, 10), iron_d)
	# Angry eyes under visor
	draw_rect(Rect2(-11, -26 + bob, 8, 5), Color(0.10, 0.08, 0.06))
	draw_rect(Rect2(  3, -26 + bob, 8, 5), Color(0.10, 0.08, 0.06))
	draw_circle(Vector2(-7, -23.5 + bob), 2.5, Color(0.92, 0.22, 0.08))
	draw_circle(Vector2( 7, -23.5 + bob), 2.5, Color(0.92, 0.22, 0.08))
	# Exposed lower face — jaw with tusks
	draw_circle(Vector2(-6, -14 + bob), 4, skin)
	draw_circle(Vector2( 6, -14 + bob), 4, skin)
	# Tusks
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -12 + bob), Vector2(-3, -12 + bob), Vector2(-4, -6 + bob)
	]), Color(0.92, 0.88, 0.76))
	draw_colored_polygon(PackedVector2Array([
		Vector2( 6, -12 + bob), Vector2( 3, -12 + bob), Vector2( 4, -6 + bob)
	]), Color(0.92, 0.88, 0.76))
	# Battle scar on cheek
	draw_line(Vector2(7, -18 + bob), Vector2(10, -12 + bob), blood, 1.5)


func _draw_shadow() -> void:
	var t     := _anim_time
	var dark  := Color(0.12, 0.03, 0.22)
	var mid   := Color(0.28, 0.06, 0.45)
	var outer := Color(0.20, 0.04, 0.34)
	var eye_c := Color(0.15, 1.00, 0.80)
	var wa    := sin(t * 2.2) * 4.0
	var wb    := sin(t * 2.8 + 0.8) * 3.0
	var wc    := sin(t * 3.5 + 1.6) * 2.5

	# Outer ethereal glow
	draw_circle(Vector2(0, 0), 24, Color(mid.r, mid.g, mid.b, 0.20))
	draw_circle(Vector2(0, 0), 20, Color(mid.r, mid.g, mid.b, 0.15))

	# Wispy body — four animated outer wisps
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4, -16), Vector2(4, -16),
		Vector2(6 + wa, 0), Vector2(10, 14 + wb),
		Vector2(0, 20 + wc), Vector2(-10, 14 - wb),
		Vector2(-6 - wa, 0)
	]), outer)

	# Mid body layer
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -14), Vector2(6, -14),
		Vector2(8 + wa * 0.6, 2), Vector2(6, 16 + wb * 0.6),
		Vector2(-6, 16 - wb * 0.6), Vector2(-8 - wa * 0.6, 2)
	]), mid)

	# Dark core
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, -12), Vector2(5, -12),
		Vector2(7, 2), Vector2(4, 14),
		Vector2(-4, 14), Vector2(-7, 2)
	]), dark)

	# Void tendrils reaching down
	for i in range(3):
		var tx := -6.0 + i * 6.0
		var td := sin(t * 3.0 + i * 1.2) * 3.0
		draw_line(Vector2(tx, 14), Vector2(tx + td, 24), outer, 2.5)
		draw_circle(Vector2(tx + td, 24), 2, dark)

	# Eyes — bright teal glow
	var ep := 0.7 + sin(t * 4.0) * 0.3
	draw_circle(Vector2(-5, -8), 6, Color(eye_c.r, eye_c.g, eye_c.b, ep * 0.35))
	draw_circle(Vector2( 5, -8), 6, Color(eye_c.r, eye_c.g, eye_c.b, ep * 0.35))
	draw_circle(Vector2(-5, -8), 4.5, Color(eye_c.r, eye_c.g, eye_c.b, ep))
	draw_circle(Vector2( 5, -8), 4.5, Color(eye_c.r, eye_c.g, eye_c.b, ep))
	draw_circle(Vector2(-5, -8), 2.2, Color(1, 1, 1, ep))
	draw_circle(Vector2( 5, -8), 2.2, Color(1, 1, 1, ep))

	# Unsettling mouth slit
	draw_line(Vector2(-6, -2), Vector2(6, -2), Color(eye_c.r, eye_c.g, eye_c.b, 0.6), 1.5)
	# Small light particles floating off body
	for i in range(4):
		var px := sin(t * 1.8 + i * 1.57) * 14.0
		var py := cos(t * 2.2 + i * 1.57) * 12.0 - 4.0
		var pa := 0.4 + sin(t * 3.0 + i) * 0.3
		draw_circle(Vector2(px, py), 1.5, Color(eye_c.r, eye_c.g, eye_c.b, pa))


# ══════════════════════════════════════════════════════════════════════════════
# BOSS ENEMIES
# ══════════════════════════════════════════════════════════════════════════════

func _draw_boss_slime_king() -> void:
	var t    := _anim_time
	var w    := sin(t * 3.0) * 3.0
	var col  := Color(0.18, 0.78, 0.28)
	var dark := Color(0.08, 0.44, 0.14)
	var gold := Color(0.95, 0.80, 0.15)
	draw_circle(Vector2(0, 4), 28 + w * 0.5, col)
	draw_circle(Vector2(0, 4), 28 + w * 0.5, dark, false, 2.0)
	draw_circle(Vector2(-8, -6), 7, Color(0.45, 1.0, 0.55, 0.45))
	var crown := PackedVector2Array([
		Vector2(-14, -26), Vector2(-14, -36),
		Vector2(-7, -30),  Vector2(0, -40),
		Vector2(7, -30),   Vector2(14, -36), Vector2(14, -26)
	])
	draw_colored_polygon(crown, gold)
	draw_polyline(crown, Color(0.75, 0.55, 0.05), 1.5)
	draw_circle(Vector2(-10, -30), 3, Color(0.95, 0.15, 0.15))
	draw_circle(Vector2(  0, -36), 3, Color(0.15, 0.55, 0.95))
	draw_circle(Vector2( 10, -30), 3, Color(0.15, 0.95, 0.45))
	draw_circle(Vector2(-9, -2), 6, Color(1, 1, 1))
	draw_circle(Vector2( 9, -2), 6, Color(1, 1, 1))
	draw_circle(Vector2(-8, -2), 3.5, Color(0.05, 0.28, 0.05))
	draw_circle(Vector2(10, -2), 3.5, Color(0.05, 0.28, 0.05))
	draw_arc(Vector2(0, 8), 7, 0.3, PI - 0.3, 10, dark, 2.0)


func _draw_boss_goblin_warchief() -> void:
	var skin    := Color(0.25, 0.60, 0.12)
	var dark    := Color(0.12, 0.34, 0.06)
	var armor_c := Color(0.55, 0.38, 0.18)
	var wpaint  := Color(0.85, 0.20, 0.10)
	var gold    := Color(0.95, 0.78, 0.15)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -6), Vector2(14, -6),
		Vector2(18, 20), Vector2(-18, 20)
	]), armor_c)
	draw_line(Vector2(-14, -6), Vector2(14, -6), gold, 2.0)
	for sx in [-18, 18]:
		draw_circle(Vector2(sx, -4), 10, armor_c)
		draw_circle(Vector2(sx, -4), 10, dark, false, 1.5)
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx - 4, -12), Vector2(sx, -24), Vector2(sx + 4, -12)
		]), Color(0.65, 0.48, 0.22))
	draw_circle(Vector2(0, -18), 14, skin)
	draw_circle(Vector2(0, -18), 14, dark, false, 1.0)
	draw_circle(Vector2(-15, -18), 7, skin)
	draw_circle(Vector2( 15, -18), 7, skin)
	draw_line(Vector2(-8, -22), Vector2(-4, -16), wpaint, 2.5)
	draw_line(Vector2( 8, -22), Vector2( 4, -16), wpaint, 2.5)
	draw_line(Vector2(-6, -12), Vector2( 6, -12), wpaint, 2.0)
	draw_circle(Vector2(-5, -20), 4, Color(0.95, 0.80, 0.10))
	draw_circle(Vector2( 5, -20), 4, Color(0.95, 0.80, 0.10))
	draw_circle(Vector2(-5, -20), 2, Color(0.05, 0.05, 0.05))
	draw_circle(Vector2( 5, -20), 2, Color(0.05, 0.05, 0.05))
	draw_circle(Vector2(0, -16), 3, dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -10), Vector2(-3, -10), Vector2(-4, -4)
	]), Color(0.95, 0.92, 0.82))
	draw_colored_polygon(PackedVector2Array([
		Vector2( 7, -10), Vector2( 3, -10), Vector2( 4, -4)
	]), Color(0.95, 0.92, 0.82))
	draw_rect(Rect2(-14, -34, 28, 4), Color(0.88, 0.86, 0.76))
	for bx in [-10, -3, 4]:
		draw_rect(Rect2(bx, -42, 4, 10), Color(0.88, 0.86, 0.76))


func _draw_boss_lich() -> void:
	var t    := _anim_time
	var robe := Color(0.20, 0.05, 0.38)
	var bone := Color(0.85, 0.84, 0.74)
	var dark := Color(0.08, 0.02, 0.16)
	var glow := Color(0.45, 0.10, 0.85)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -14), Vector2(14, -14),
		Vector2(16, 10), Vector2(10, 22),
		Vector2(0, 18), Vector2(-10, 22), Vector2(-16, 10)
	]), robe)
	draw_circle(Vector2(0, 0), 26.0 + sin(t * 2.0) * 3.0, Color(glow.r, glow.g, glow.b, 0.14))
	draw_line(Vector2(-16, -8), Vector2(-16, 18), Color(0.55, 0.35, 0.12), 3.0)
	draw_circle(Vector2(-16, -14), 8, glow)
	draw_circle(Vector2(-16, -14), 8, Color(glow.r, glow.g, glow.b, 0.4), false, 2.0)
	draw_circle(Vector2(-18, -16), 3, Color(1, 1, 1, 0.7))
	draw_circle(Vector2(0, -22), 13, bone)
	draw_circle(Vector2(0, -22), 13, dark, false, 1.5)
	draw_circle(Vector2(-5, -24), 4.5, dark)
	draw_circle(Vector2( 5, -24), 4.5, dark)
	draw_circle(Vector2(-5, -24), 2.5, glow)
	draw_circle(Vector2( 5, -24), 2.5, glow)
	draw_rect(Rect2(-7, -14, 14, 5), bone)
	for i in range(3):
		draw_rect(Rect2(-5 + i * 4, -14, 2, 4), dark)
	for i in range(5):
		var cx := -8.0 + i * 4.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx, -34), Vector2(cx + 2, -42), Vector2(cx + 4, -34)
		]), dark)
	draw_rect(Rect2(-10, -36, 20, 4), dark)


func _draw_boss_golem() -> void:
	var stone := Color(0.52, 0.50, 0.46)
	var dark  := Color(0.28, 0.26, 0.22)
	var light := Color(0.72, 0.70, 0.64)
	var crack := Color(0.95, 0.65, 0.15)
	draw_rect(Rect2(-18, -16, 36, 34), stone)
	draw_rect(Rect2(-18, -16, 36, 34), dark, false, 2.0)
	draw_line(Vector2(-18, -4), Vector2(18, -4), dark, 1.0)
	draw_line(Vector2(-6, -16), Vector2(-6, 18), dark, 1.0)
	draw_line(Vector2( 8, -16), Vector2( 8, 18), dark, 1.0)
	draw_line(Vector2(-14, -10), Vector2(-4,  2), crack, 2.0)
	draw_line(Vector2(  6,  -8), Vector2(16,  6), crack, 2.0)
	draw_line(Vector2( -2,   2), Vector2(10, 14), crack, 1.5)
	draw_rect(Rect2(-13, -32, 26, 18), stone)
	draw_rect(Rect2(-13, -32, 26, 18), dark, false, 2.0)
	draw_rect(Rect2(-10, -28, 7, 7), crack)
	draw_rect(Rect2(  3, -28, 7, 7), crack)
	draw_rect(Rect2( -9, -27, 5, 5), Color(1.0, 0.90, 0.55))
	draw_rect(Rect2(  4, -27, 5, 5), Color(1.0, 0.90, 0.55))
	draw_rect(Rect2(-32, -8, 14, 16), stone)
	draw_rect(Rect2( 18, -8, 14, 16), stone)
	draw_rect(Rect2(-32, -8, 14, 16), dark, false, 1.5)
	draw_rect(Rect2( 18, -8, 14, 16), dark, false, 1.5)


func _draw_boss_werewolf() -> void:
	var fur   := Color(0.38, 0.28, 0.18)
	var dark  := Color(0.20, 0.14, 0.08)
	var claws := Color(0.85, 0.82, 0.72)
	var eye_c := Color(0.95, 0.72, 0.10)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -8), Vector2(14, -8),
		Vector2(18, 18), Vector2(-18, 18)
	]), fur)
	for i in range(5):
		draw_arc(Vector2(-10 + i * 5, -8), 4, -PI, 0, 6, dark, 1.0)
	draw_circle(Vector2(4, -20), 13, fur)
	draw_circle(Vector2(4, -20), 13, dark, false, 1.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2, -18), Vector2(10, -18),
		Vector2(14, -12), Vector2(-2, -12)
	]), fur.darkened(0.2))
	draw_circle(Vector2(12, -16), 3.5, dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -14), Vector2(3, -14), Vector2(1.5, -9)
	]), claws)
	draw_colored_polygon(PackedVector2Array([
		Vector2(5, -14), Vector2(8, -14), Vector2(6.5, -9)
	]), claws)
	draw_circle(Vector2(-2, -22), 4, eye_c)
	draw_circle(Vector2( 6, -22), 4, eye_c)
	draw_circle(Vector2(-2, -22), 2, Color(0.05, 0.05, 0.05))
	draw_circle(Vector2( 6, -22), 2, Color(0.05, 0.05, 0.05))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4, -30), Vector2(-10, -42), Vector2(2, -30)
	]), fur)
	draw_colored_polygon(PackedVector2Array([
		Vector2(8, -30), Vector2(16, -40), Vector2(18, -28)
	]), fur)
	draw_rect(Rect2(-24, -4, 10, 16), fur)
	draw_rect(Rect2( 14, -4, 10, 16), fur)
	for cx in [-24, -20, -16]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx, 12), Vector2(cx + 2, 12), Vector2(cx + 1, 18)
		]), claws)
	for cx in [14, 18, 22]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx, 12), Vector2(cx + 2, 12), Vector2(cx + 1, 18)
		]), claws)


func _draw_boss_dragon() -> void:
	var t      := _anim_time
	var scales := Color(0.22, 0.58, 0.18)
	var dark   := Color(0.10, 0.30, 0.08)
	var belly  := Color(0.72, 0.82, 0.42)
	var fire_c := Color(0.95, 0.55, 0.10)
	var wing_c := Color(0.18, 0.48, 0.14)
	var flap   := sin(t * 5.0) * 6.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -10), Vector2(-32, -20 - flap),
		Vector2(-38, -4 - flap * 0.5), Vector2(-20, 8)
	]), wing_c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(10, -10), Vector2(32, -20 - flap),
		Vector2(38, -4 - flap * 0.5), Vector2(20, 8)
	]), wing_c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -10), Vector2(-26, -15 - flap * 0.6),
		Vector2(-30, -2 - flap * 0.3), Vector2(-18, 6)
	]), Color(0.25, 0.60, 0.20, 0.55))
	draw_colored_polygon(PackedVector2Array([
		Vector2(10, -10), Vector2(26, -15 - flap * 0.6),
		Vector2(30, -2 - flap * 0.3), Vector2(18, 6)
	]), Color(0.25, 0.60, 0.20, 0.55))
	draw_circle(Vector2(0, 4), 18, scales)
	draw_circle(Vector2(0, 4), 18, dark, false, 1.5)
	draw_circle(Vector2(0, 6), 12, belly)
	draw_circle(Vector2(0, -16), 14, scales)
	draw_circle(Vector2(0, -16), 14, dark, false, 1.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -18), Vector2(7, -18),
		Vector2(10, -10), Vector2(-10, -10)
	]), scales.darkened(0.2))
	draw_circle(Vector2(-4, -12), 2, dark)
	draw_circle(Vector2( 4, -12), 2, dark)
	draw_circle(Vector2(-5, -20), 4, Color(0.95, 0.80, 0.10))
	draw_circle(Vector2( 5, -20), 4, Color(0.95, 0.80, 0.10))
	draw_circle(Vector2(-5, -20), 2, Color(0.05, 0.05, 0.05))
	draw_circle(Vector2( 5, -20), 2, Color(0.05, 0.05, 0.05))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -28), Vector2(-12, -40), Vector2(-4, -26)
	]), dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2( 8, -28), Vector2( 12, -40), Vector2( 4, -26)
	]), dark)
	if sin(t * 3.0) > 0.2:
		draw_circle(Vector2(0, -8), 6 + sin(t * 8) * 2, fire_c)
		draw_circle(Vector2(0, -8), 4, Color(1.0, 0.95, 0.20))


func _draw_boss_ice_giant() -> void:
	var t     := _anim_time
	var ice   := Color(0.55, 0.78, 0.92)
	var dark  := Color(0.22, 0.45, 0.62)
	var white := Color(0.90, 0.96, 1.00)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-16, -12), Vector2(16, -12),
		Vector2(20, 20), Vector2(-20, 20)
	]), ice)
	draw_polyline(PackedVector2Array([
		Vector2(-16, -12), Vector2(16, -12),
		Vector2(20, 20), Vector2(-20, 20), Vector2(-16, -12)
	]), dark, 2.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -8), Vector2(0, -16), Vector2(8, -8),
		Vector2(8, 6), Vector2(0, 12), Vector2(-8, 6)
	]), white)
	draw_circle(Vector2(0, -24), 13, ice)
	draw_circle(Vector2(0, -24), 13, dark, false, 1.5)
	for i in range(5):
		var cx := -8.0 + i * 4.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx, -36), Vector2(cx + 2, -46), Vector2(cx + 4, -36)
		]), white)
	draw_rect(Rect2(-10, -38, 20, 4), ice)
	draw_circle(Vector2(-4, -26), 4, white)
	draw_circle(Vector2( 4, -26), 4, white)
	draw_circle(Vector2(-4, -26), 2.2, Color(0.15, 0.65, 0.95))
	draw_circle(Vector2( 4, -26), 2.2, Color(0.15, 0.65, 0.95))
	draw_rect(Rect2(-32, -10, 15, 18), ice)
	draw_rect(Rect2( 17, -10, 15, 18), ice)
	draw_rect(Rect2(-32, -10, 15, 18), dark, false, 1.5)
	draw_rect(Rect2( 17, -10, 15, 18), dark, false, 1.5)
	draw_circle(Vector2(0, -12), 10.0 + sin(t * 4.0) * 3.0, Color(0.75, 0.90, 1.0, 0.22))


func _draw_boss_shadow_demon() -> void:
	var t    := _anim_time
	var dark := Color(0.12, 0.02, 0.22)
	var mid  := Color(0.28, 0.05, 0.48)
	var eye_c:= Color(1.0, 0.15, 0.08)
	var glow := Color(0.65, 0.05, 0.85)
	var wa   := sin(t * 2.5) * 8.0
	draw_circle(Vector2(0, 0), 32 + sin(t * 2.5) * 3, Color(glow.r, glow.g, glow.b, 0.16))
	draw_circle(Vector2(0, 2), 24, mid)
	draw_circle(Vector2(0, 2), 24, dark, false, 2.5)
	draw_circle(Vector2(0, 2), 18, dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -22), Vector2(-18, -42), Vector2(-6, -24)
	]), dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2( 12, -22), Vector2( 18, -42), Vector2( 6, -24)
	]), dark)
	draw_circle(Vector2(-8, -8), 6, eye_c)
	draw_circle(Vector2( 8, -8), 6, eye_c)
	draw_circle(Vector2(-8, -8), 3, Color(1.0, 0.85, 0.10))
	draw_circle(Vector2( 8, -8), 3, Color(1.0, 0.85, 0.10))
	draw_arc(Vector2(0, 4), 12, 0.3, PI - 0.3, 16, eye_c, 2.5)
	for i in range(4):
		draw_colored_polygon(PackedVector2Array([
			Vector2(-7 + i * 5, 8), Vector2(-5 + i * 5, 8),
			Vector2(-6 + i * 5, 14)
		]), Color(0.85, 0.85, 0.95))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-22, -4), Vector2(-30, 2 + wa),
		Vector2(-32, 14), Vector2(-26, 12), Vector2(-18, 6)
	]), mid)
	draw_colored_polygon(PackedVector2Array([
		Vector2(22, -4), Vector2(30, 2 - wa),
		Vector2(32, 14), Vector2(26, 12), Vector2(18, 6)
	]), mid)


func _draw_boss_helldrake() -> void:
	var t      := _anim_time
	var scales := Color(0.72, 0.12, 0.08)
	var dark   := Color(0.38, 0.04, 0.04)
	var belly  := Color(0.88, 0.62, 0.18)
	var fire_c := Color(1.0, 0.60, 0.05)
	var wing_c := Color(0.55, 0.08, 0.08)
	var flap   := sin(t * 5.0) * 7.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -8), Vector2(-36, -22 - flap),
		Vector2(-42, 0 - flap * 0.5), Vector2(-22, 10)
	]), wing_c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(10, -8), Vector2(36, -22 - flap),
		Vector2(42, 0 - flap * 0.5), Vector2(22, 10)
	]), wing_c)
	draw_circle(Vector2(0, 4), 20, scales)
	draw_circle(Vector2(0, 4), 20, dark, false, 2.0)
	draw_circle(Vector2(0, 6), 13, belly)
	draw_circle(Vector2(0, -16), 15, scales)
	draw_circle(Vector2(0, -16), 15, dark, false, 1.5)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9, -16), Vector2(9, -16),
		Vector2(13, -6), Vector2(-13, -6)
	]), scales.darkened(0.25))
	for fx in [-8, -3, 3, 8]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(fx, -9), Vector2(fx + 3, -9), Vector2(fx + 1.5, -4)
		]), Color(0.92, 0.88, 0.80))
	draw_circle(Vector2(-6, -20), 4.5, Color(1.0, 0.85, 0.10))
	draw_circle(Vector2( 6, -20), 4.5, Color(1.0, 0.85, 0.10))
	draw_circle(Vector2(-6, -20), 2.2, Color(0.05, 0.05, 0.05))
	draw_circle(Vector2( 6, -20), 2.2, Color(0.05, 0.05, 0.05))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -28), Vector2(-15, -44), Vector2(-4, -26)
	]), dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2( 10, -28), Vector2( 15, -44), Vector2( 4, -26)
	]), dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, -28), Vector2(-8, -38), Vector2(0, -26)
	]), Color(0.55, 0.08, 0.08))
	draw_colored_polygon(PackedVector2Array([
		Vector2( 5, -28), Vector2( 8, -38), Vector2(0, -26)
	]), Color(0.55, 0.08, 0.08))
	var fs := 8.0 + sin(t * 6.0) * 4.0
	draw_circle(Vector2(0, -4), fs, fire_c)
	draw_circle(Vector2(0, -4), fs * 0.6, Color(1.0, 0.95, 0.30))
	draw_circle(Vector2(0, -4), fs * 0.3, Color(1.0, 1.0, 0.80))


func _draw_boss_dark_lord() -> void:
	var t       := _anim_time
	var armor_c := Color(0.15, 0.12, 0.20)
	var armor_l := Color(0.30, 0.25, 0.38)
	var gold    := Color(0.85, 0.68, 0.12)
	var cape_c  := Color(0.45, 0.04, 0.04)
	var eye_c   := Color(0.85, 0.08, 0.85)
	var dark    := Color(0.05, 0.02, 0.10)
	var cb      := sin(t * 1.8) * 4.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -10), Vector2(14, -10),
		Vector2(20 + cb, 24), Vector2(-20 - cb, 24)
	]), cape_c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -10), Vector2(14, -10),
		Vector2(14, 8), Vector2(-14, 8)
	]), armor_c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -8), Vector2(12, -8),
		Vector2(10, 8), Vector2(-10, 8)
	]), armor_l)
	draw_line(Vector2(-12, -8), Vector2(12, -8), gold, 2.0)
	draw_line(Vector2(0, -8), Vector2(0, 8), gold, 1.5)
	draw_circle(Vector2(-16, -8), 10, armor_c)
	draw_circle(Vector2( 16, -8), 10, armor_c)
	for sx in [-16, 16]:
		draw_arc(Vector2(sx, -8), 10, -PI, 0, 8, gold, 1.5)
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx - 3, -16), Vector2(sx, -26), Vector2(sx + 3, -16)
		]), gold)
	draw_circle(Vector2(0, -22), 13, armor_c)
	draw_circle(Vector2(0, -22), 13, armor_l, false, 1.5)
	var crown := PackedVector2Array([
		Vector2(-13, -32), Vector2(-13, -38),
		Vector2(-7, -34),  Vector2(0, -44),
		Vector2(7, -34),   Vector2(13, -38), Vector2(13, -32)
	])
	draw_colored_polygon(crown, gold)
	draw_polyline(crown, Color(0.65, 0.50, 0.08), 1.5)
	draw_circle(Vector2(0, -40), 3.5, eye_c)
	draw_circle(Vector2(0, -40), 2.0, Color(1, 0.85, 1.0))
	draw_rect(Rect2(-8, -26, 16, 4), dark)
	draw_circle(Vector2(-4, -24), 3, eye_c)
	draw_circle(Vector2( 4, -24), 3, eye_c)
	draw_circle(Vector2(0, 0), 32, Color(eye_c.r, eye_c.g, eye_c.b,
		0.12 + sin(t * 2.5) * 0.06))
