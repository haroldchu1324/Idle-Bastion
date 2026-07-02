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
var _poison_sources  : Dictionary = {}   # {source_node: {timer, bonus}} — one slot per tower
var damage_taken_mult: float = 1.0
var melee_resist     : float = 0.0
var hits_taken       : int   = 0
var is_taunted       : bool  = false
var _taunt_timer     : float = 0.0

var _path          : Array   = []
var _current_wp    : int     = 1
var _anim_time     : float   = 0.0
var _slow_sources    : Dictionary = {}  # {source_node: {timer, factor}} — per-source, stacks multiplicatively

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


func is_slowed() -> bool:
	return not _slow_sources.is_empty()

func apply_slow(source: Node, duration: float, factor: float) -> void:
	if _base_speed <= 0.0:
		return
	var existing : Dictionary = _slow_sources.get(source, {})
	_slow_sources[source] = {
		"timer": max(existing.get("timer", 0.0), duration),
		"factor": factor
	}
	_recalc_speed()

func _recalc_speed() -> void:
	if _base_speed <= 0.0:
		return
	if is_taunted:
		speed = 0.0
		return
	var s := _base_speed
	for _src in _slow_sources:
		var _f : float = _slow_sources[_src]["factor"] * (0.5 if is_boss else 1.0)
		s *= (1.0 - _f)
	speed = s

func _recalc_damage_mult() -> void:
	var mult := 1.0
	for _src in _poison_sources:
		var _b : float = _poison_sources[_src]["bonus"]
		mult += _b * (0.5 if is_boss else 1.0)
	var taunt_bonus : float = 0.20 if not is_boss else 0.10
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


func apply_poison_source(source_id: String, duration: float, bonus: float) -> void:
	var existing : Dictionary = _poison_sources.get(source_id, {})
	_poison_sources[source_id] = {
		"timer": max(existing.get("timer", 0.0), duration),
		"bonus": bonus
	}
	is_poisoned = true
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

	if not _slow_sources.is_empty():
		var _slow_expired : Array = []
		for _src in _slow_sources:
			_slow_sources[_src]["timer"] -= delta
			if _slow_sources[_src]["timer"] <= 0.0:
				_slow_expired.append(_src)
		if not _slow_expired.is_empty():
			for _src in _slow_expired:
				_slow_sources.erase(_src)
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
	if not _poison_sources.is_empty():
		var _to_erase : Array = []
		var _changed  := false
		for _src in _poison_sources:
			var _entry : Dictionary = _poison_sources[_src]
			if _entry.get("fading", false):
				_entry["bonus"] -= 0.01 * delta
				if _entry["bonus"] <= 0.0:
					_to_erase.append(_src)
				_changed = true
			else:
				_entry["timer"] -= delta
				if _entry["timer"] <= 0.0:
					if _src == "poison_tower" and GameData.turret_has_special("poison_tower"):
						_entry["fading"] = true
					else:
						_to_erase.append(_src)
					_changed = true
		if not _to_erase.is_empty():
			for _src in _to_erase:
				_poison_sources.erase(_src)
			is_poisoned = not _poison_sources.is_empty()
		if _changed:
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
		var _sa_max : float = 0.0
		for _src in _slow_sources:
			_sa_max = maxf(_sa_max, _slow_sources[_src]["timer"])
		var sa := clampf(_sa_max, 0.0, 1.0)
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
	var col  : Color
	var dark : Color
	var lite : Color
	if boss_stage <= 1:
		col  = Color(0.18, 0.78, 0.25); dark = Color(0.08, 0.46, 0.14); lite = Color(0.40, 0.95, 0.48)
	else:
		col  = Color(0.18, 0.55, 0.72); dark = Color(0.08, 0.30, 0.46); lite = Color(0.40, 0.72, 0.90)
	# Drop shadow
	draw_circle(Vector2(1, 19), 13, Color(0, 0, 0, 0.18))
	# Body layers for depth — dark uses same center as main body so border is always gap-free
	draw_circle(Vector2(0, 2 + w * 0.10), 19 + w * 0.4, dark)
	draw_circle(Vector2(0, 2 + w * 0.10), 17 + w * 0.4, col)
	# Inner glow (pre-multiplied opaque)
	draw_circle(Vector2(0, 2), 13, col.lerp(lite, 0.22))
	# Internal bubbles (pre-multiplied opaque)
	draw_circle(Vector2( 6, 5), 4.5, col.lerp(lite, 0.30))
	draw_circle(Vector2(-5, 7), 3.0, col.lerp(lite, 0.22))
	draw_circle(Vector2( 5, 7), 2.0, col.lerp(lite, 0.18))
	# Primary specular highlight (pre-multiplied opaque)
	draw_circle(Vector2(-5, -7), 6.5, col.lerp(Color(1, 1, 1), 0.50))
	draw_circle(Vector2(-4, -9), 3.0, col.lerp(Color(1, 1, 1), 0.75))
	# Sclera
	draw_circle(Vector2(-6, -1), 5.5, Color(0.96, 0.98, 0.94))
	draw_circle(Vector2( 6, -1), 5.5, Color(0.96, 0.98, 0.94))
	# Iris
	var iris := Color(0.05, 0.48, 0.14) if boss_stage <= 1 else Color(0.05, 0.28, 0.62)
	draw_circle(Vector2(-5.5, -1), 3.5, iris)
	draw_circle(Vector2( 6.5, -1), 3.5, iris)
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
	var skin    : Color
	var skin_d  : Color
	var skin_l  : Color
	if boss_stage <= 3:
		skin = Color(0.32, 0.56, 0.16); skin_d = Color(0.18, 0.34, 0.08); skin_l = Color(0.48, 0.72, 0.26)
	else:
		skin = Color(0.46, 0.26, 0.50); skin_d = Color(0.28, 0.14, 0.30); skin_l = Color(0.62, 0.40, 0.66)
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
	var t      := _anim_time
	var bob    := sin(t * 2.8) * 0.75
	var gp     := 0.6 + sin(t * 3.5) * 0.4
	var bone   := Color(0.86, 0.84, 0.74)
	var bone_d := Color(0.55, 0.54, 0.44)
	var bone_l := Color(0.96, 0.95, 0.91)
	var dark   := Color(0.10, 0.08, 0.06)
	var glow   := Color(0.12, 1.00, 0.47) if boss_stage <= 5 else Color(0.90, 0.55, 0.05)
	var cloak  := Color(0.094, 0.063, 0.165)   # #18102a
	var cowl   := Color(0.047, 0.039, 0.102)   # #0c0a1a
	var rune_a := 0.4 + sin(t * 4.0) * 0.3

	# Shadow
	draw_circle(Vector2(1, 22 + bob), 12, Color(0, 0, 0, 0.22))

	# Dark cloak body
	draw_colored_polygon(PackedVector2Array([
		Vector2(-16, -8 + bob), Vector2(16, -8 + bob),
		Vector2(18,  22 + bob), Vector2(14, 18 + bob),
		Vector2(12,  22 + bob), Vector2( 8, 20 + bob),
		Vector2( 4,  24 + bob), Vector2( 0, 21 + bob),
		Vector2(-4,  24 + bob), Vector2(-8, 20 + bob),
		Vector2(-12, 18 + bob), Vector2(-14, 22 + bob),
		Vector2(-18, 22 + bob)
	]), cloak)
	# Cloak left-face highlight
	draw_colored_polygon(PackedVector2Array([
		Vector2(-16, -8 + bob), Vector2(-3, -8 + bob),
		Vector2( -3, 22 + bob), Vector2(-12, 18 + bob),
		Vector2(-14, 22 + bob), Vector2(-18, 22 + bob)
	]), Color(0.31, 0.20, 0.47, 0.28))

	# Spine vertebrae (peek above cloak)
	for i in range(4):
		var sy := -6.0 + i * 4.0 + bob
		draw_circle(Vector2(0, sy), 3.0, bone)
		draw_circle(Vector2(0, sy), 3.0, bone_d, false, 1.0)

	# Collar bone
	draw_line(Vector2(-10, -8 + bob), Vector2(10, -8 + bob), bone, 4.0)
	draw_line(Vector2(-10, -8 + bob), Vector2(10, -8 + bob), bone_l, 1.5)
	draw_circle(Vector2(-10, -8 + bob), 3.5, bone)
	draw_circle(Vector2( 10, -8 + bob), 3.5, bone)

	# Arms
	draw_line(Vector2(-10, -8 + bob), Vector2(-20,  2 + bob), bone, 4.5)
	draw_line(Vector2( 10, -8 + bob), Vector2( 20,  2 + bob), bone, 4.5)
	draw_line(Vector2(-10, -8 + bob), Vector2(-20,  2 + bob), bone_l, 1.5)
	draw_line(Vector2( 10, -8 + bob), Vector2( 20,  2 + bob), bone_l, 1.5)
	draw_circle(Vector2(-20, 2 + bob), 3.5, bone)
	draw_circle(Vector2( 20, 2 + bob), 3.5, bone)
	draw_line(Vector2(-20, 2 + bob), Vector2(-22, 12 + bob), bone, 3.5)
	draw_line(Vector2( 20, 2 + bob), Vector2( 22, 12 + bob), bone, 3.5)

	# Magical rune sword (rotated -0.5 rad at right hand)
	draw_set_transform(_wobble_offset + Vector2(22, 12 + bob + _knockback_arc_y), -0.5, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2, 0), Vector2(-1.5, -22), Vector2(0, -26),
		Vector2(1.5, -22), Vector2(2, 0)
	]), Color(0.35, 0.35, 0.44))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-1.5, 0), Vector2(-1, -22), Vector2(0, -24), Vector2(-0.5, 0)
	]), Color(0.59, 0.59, 0.71, 0.45))
	for ri in range(3):
		draw_rect(Rect2(-1, -8.0 - ri * 6.0, 2, 2), Color(glow.r, glow.g, glow.b, rune_a))
	draw_rect(Rect2(-8, -2, 16, 3), bone_d)
	draw_rect(Rect2(-7, -2, 14, 1.5), bone_l)
	draw_set_transform(_wobble_offset + Vector2(0.0, _knockback_arc_y), 0.0, Vector2.ONE)

	# Dark cowl behind skull (polygon approximation of bezier)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-16, -12 + bob), Vector2(-17, -20 + bob),
		Vector2(-15, -30 + bob), Vector2(-9,  -36 + bob),
		Vector2(  0, -37 + bob), Vector2( 5,  -37 + bob),
		Vector2( 10, -35 + bob), Vector2(14,  -29 + bob),
		Vector2( 16, -12 + bob)
	]), cowl)
	# Cowl left highlight
	draw_colored_polygon(PackedVector2Array([
		Vector2(-16, -12 + bob), Vector2(-17, -20 + bob),
		Vector2(-12, -34 + bob), Vector2( -4, -37 + bob),
		Vector2(  0, -37 + bob), Vector2(-10, -12 + bob)
	]), Color(0.27, 0.16, 0.43, 0.38))

	# SKULL
	draw_circle(Vector2(1,  -18 + bob), 12, bone_d)
	draw_circle(Vector2(0,  -19 + bob), 12, bone)
	draw_circle(Vector2(-4, -24 + bob),  6, Color(bone_l.r, bone_l.g, bone_l.b, 0.55))
	draw_circle(Vector2(0,  -19 + bob), 12, bone_d, false, 1.5)
	draw_circle(Vector2(-10, -17 + bob), 4, bone)
	draw_circle(Vector2( 10, -17 + bob), 4, bone)

	# Eye sockets
	draw_circle(Vector2(-4.5, -21 + bob), 5, dark)
	draw_circle(Vector2( 4.5, -21 + bob), 5, dark)
	# Soul fire
	var gr := 3.0 + sin(t * 5.0) * 0.5
	draw_circle(Vector2(-4.5, -21 + bob), gr + 0.5, Color(glow.r, glow.g, glow.b, gp))
	draw_circle(Vector2( 4.5, -21 + bob), gr + 0.5, Color(glow.r, glow.g, glow.b, gp))
	draw_circle(Vector2(-4.5, -21 + bob), 1.8, Color(1, 1, 1, gp * 0.8))
	draw_circle(Vector2( 4.5, -21 + bob), 1.8, Color(1, 1, 1, gp * 0.8))

	# Floating soul particles
	for i in range(4):
		var pt := fmod(t * 0.8 + i * 0.9, PI * 2.0)
		var px := cos(pt + i * 1.2) * (16.0 + i * 3.0)
		var py := sin(pt * 1.5 + i) * 8.0 - 16.0 + bob
		var pa := (sin(t * 3.0 + i) + 1.0) * 0.3
		draw_circle(Vector2(px, py), 1.5, Color(glow.r, glow.g, glow.b, pa))

	# Nasal cavity
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2, -16 + bob), Vector2(2, -16 + bob),
		Vector2( 3, -12 + bob), Vector2(-3, -12 + bob)
	]), dark)
	# Upper teeth
	draw_rect(Rect2(-7, -12 + bob, 14, 4), bone)
	draw_rect(Rect2(-7, -12 + bob, 14, 4), bone_d, false, 0.8)
	for i in range(4):
		draw_rect(Rect2(-6 + i * 4, -12 + bob, 3, 4), dark)
	# Lower jaw (slightly open)
	draw_rect(Rect2(-6, -8 + bob, 12, 4), bone)
	for i in range(3):
		draw_rect(Rect2(-5 + i * 4, -8 + bob, 3, 3), dark)


func _draw_orc() -> void:
	var t       := _anim_time
	var bob     := sin(t * 2.5) * 1.0
	var skin    : Color
	var skin_d  : Color
	var skin_l  : Color
	if boss_stage <= 7:
		skin = Color(0.36, 0.52, 0.20); skin_d = Color(0.22, 0.34, 0.12); skin_l = Color(0.50, 0.66, 0.30)
	else:
		skin = Color(0.52, 0.22, 0.14); skin_d = Color(0.34, 0.12, 0.08); skin_l = Color(0.68, 0.36, 0.26)
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
	var eye_c := Color(0.15, 1.00, 0.80) if boss_stage <= 9 else Color(1.0, 0.20, 0.20)
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
	var bob  := sin(t * 1.5) * 4.0
	var bk   := bob * 0.70        # bob scaled to match 70% sprite size
	var w    := sin(t * 2.1) * 2.1
	var bw   := w * 0.5
	var col  := Color(0.059, 0.722, 0.180)
	var dark := Color(0.020, 0.169, 0.055)
	var gold_d := Color(0.478, 0.333, 0.0)
	var gold   := Color(0.769, 0.541, 0.0)

	# Toxic aura pulse (52 × 0.70 = 36.4)
	var ar := 0.10 + sin(t * 3.5) * 0.05
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.70, 0.616))
	draw_circle(Vector2.ZERO, 52, Color(0.353, 1.0, 0.416, ar))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Drop shadow
	draw_set_transform(Vector2(1.4, 32 + bk), 0.0, Vector2(0.70, 0.126))
	draw_circle(Vector2.ZERO, 32, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 4 asymmetric tendrils
	var tpos := [-20.0, -10.0, 4.0, 15.0]
	for i in range(4):
		var tx : float = tpos[i]
		var nb := sin(t * 1.9 + float(i) * 1.1) * 2.8
		draw_set_transform(Vector2(tx, 25 + nb + bk), 0.0, Vector2(0.70, 1.40))
		draw_circle(Vector2.ZERO, 5.0, dark)
		draw_set_transform(Vector2(tx, 25 + nb + bk), 0.0, Vector2(0.70, 1.47))
		draw_circle(Vector2.ZERO, 3.8, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Body (35 × 0.70 = 24.5, 33 × 0.70 = 23.1)
	draw_set_transform(Vector2(0.7, 1.4 + bk + w * 0.06), 0.0, Vector2(0.70 + bw * 0.011, 0.70 - bw * 0.011))
	draw_circle(Vector2.ZERO, 35, dark)
	draw_set_transform(Vector2(0.0, 0.7 + bk + w * 0.06), 0.0, Vector2(0.70 + bw * 0.011, 0.70 - bw * 0.011))
	draw_circle(Vector2.ZERO, 33, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Internal darker blobs
	draw_circle(Vector2(-7.0,  5.6 + bk), 4.9, Color(dark.r, dark.g, dark.b, 0.30))
	draw_circle(Vector2( 8.4,  2.8 + bk), 3.5, Color(dark.r, dark.g, dark.b, 0.28))
	draw_circle(Vector2(-2.1,  9.8 + bk), 2.8, Color(dark.r, dark.g, dark.b, 0.25))

	# Specular highlight
	draw_set_transform(Vector2(-5.6, -9.8 + bk), 0.0, Vector2(0.70, 0.315))
	draw_circle(Vector2.ZERO, 11, Color(1, 1, 1, 0.38))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Crown base
	draw_rect(Rect2(-12, -25 + bk, 24, 4), gold_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -25 + bk), Vector2(-12, -34 + bk),
		Vector2( -7, -29 + bk), Vector2( -1, -38 + bk),
		Vector2(  4, -29 + bk), Vector2( 10, -35 + bk),
		Vector2( 13, -25 + bk)
	]), gold)
	draw_polyline(PackedVector2Array([
		Vector2(-13, -25 + bk), Vector2(-12, -34 + bk),
		Vector2( -7, -29 + bk), Vector2( -1, -38 + bk),
		Vector2(  4, -29 + bk), Vector2( 10, -35 + bk),
		Vector2( 13, -25 + bk)
	]), Color(0.290, 0.188, 0.0), 1.2)

	# Toxic crown gems with animated drips
	var tgems : Array = [
		[Vector2(-8, -29 + bk), Color(0.125, 1.0, 0.502)],
		[Vector2(-1, -36 + bk), Color(0.753, 1.0, 0.0  )],
		[Vector2( 7, -33 + bk), Color(0.0,   1.0, 0.690)]
	]
	for g in tgems:
		var gpos : Vector2 = g[0]
		var gc   : Color   = g[1]
		draw_circle(gpos, 2.8, gc)
		draw_circle(Vector2(gpos.x - 0.6, gpos.y - 0.6), 0.9, Color(1, 1, 1, 0.65))
		var dp := maxf(0.0, sin(t * 1.5 + gpos.x) * 2.1)
		if dp > 0.1:
			draw_colored_polygon(PackedVector2Array([
				Vector2(gpos.x - 1.0, gpos.y + 2.8),
				Vector2(gpos.x,       gpos.y + 2.8 + dp),
				Vector2(gpos.x + 1.0, gpos.y + 2.8)
			]), gc)

	# 3 asymmetric eyes (radii 8/7/5 → 5.6/4.9/3.5)
	var eyes : Array = [
		[Vector2(-7.7, -5.6 + bk), 5.6],
		[Vector2( 6.3, -7.0 + bk), 4.9],
		[Vector2( 1.4,-14.0 + bk), 3.5]
	]
	var iris_c := Color(0.133, 0.867, 0.0)
	for e in eyes:
		var ep : Vector2 = e[0]
		var er : float   = e[1]
		draw_set_transform(ep, 0.0, Vector2(1.0, 0.76))
		draw_circle(Vector2.ZERO, er, Color(0.847, 0.941, 0.847))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(ep, er * 0.65, iris_c)
		draw_circle(ep, er * 0.34, Color(0.024, 0.059, 0.016))
		draw_circle(ep + Vector2(-er * 0.3, -er * 0.3), er * 0.18, Color(1, 1, 1, 0.85))

	# Jagged angry mouth
	draw_polyline(PackedVector2Array([
		Vector2(-8.4, 6.3 + bk), Vector2(-5.6, 9.1 + bk),
		Vector2(-2.8, 7.0 + bk), Vector2( 0.0, 9.8 + bk),
		Vector2( 2.8, 7.0 + bk), Vector2( 5.6, 9.1 + bk),
		Vector2( 8.4, 6.3 + bk)
	]), dark, 1.8)


func _draw_boss_goblin_warchief() -> void:
	var t   := _anim_time
	var bob := sin(t * 1.5) * 4.0
	var sk  := Color(0.180, 0.376, 0.063)
	var skd := Color(0.086, 0.188, 0.031)
	var arm := Color(0.353, 0.220, 0.094)
	var arl := Color(0.545, 0.376, 0.125)
	var gld := Color(0.784, 0.659, 0.251)

	draw_set_transform(Vector2(1, 30+bob), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 18, Color(0,0,0,0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-15,-6+bob), Vector2(15,-6+bob), Vector2(18,20+bob), Vector2(-18,20+bob)
	]), arm)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14,-6+bob), Vector2(14,-6+bob), Vector2(17,20+bob), Vector2(-17,20+bob)
	]), arl)
	draw_rect(Rect2(-14,-6+bob,28,2), gld)
	draw_arc(Vector2(0,-2+bob), 12, 0.63, 2.51, 16, Color(0.565,0.439,0.251), 1.5)
	for tp in [Vector2(-8,4+bob), Vector2(-1,5+bob), Vector2(7,4+bob)]:
		draw_circle(tp, 3, Color(0.910,0.816,0.565))
	for sx in [-18.0, 18.0]:
		draw_circle(Vector2(sx,-4+bob), 12, arm)
		draw_circle(Vector2(sx,-4+bob), 11, arl)
		draw_arc(Vector2(sx,-4+bob), 11, -PI, 0, 8, gld, 1.5)
	draw_circle(Vector2(1,-18+bob), 15, skd)
	draw_circle(Vector2(0,-19+bob), 15, sk)
	for sx2 in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx2*13,-22+bob), Vector2(sx2*26,-17+bob),
			Vector2(sx2*24,-8+bob),  Vector2(sx2*13,-13+bob)
		]), sk)
	draw_rect(Rect2(-16,-28+bob, 5, 22), Color(0.784,0.196,0.039, 0.75))
	draw_rect(Rect2( 4, -28+bob, 5, 22), Color(0.784,0.196,0.039, 0.75))
	draw_rect(Rect2(-5, -28+bob, 3, 22), Color(0.784,0.196,0.039, 0.45))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14,-24+bob), Vector2(-2,-27+bob), Vector2(-1,-23+bob), Vector2(-12,-21+bob)
	]), skd)
	draw_colored_polygon(PackedVector2Array([
		Vector2(14,-24+bob), Vector2(2,-27+bob), Vector2(1,-23+bob), Vector2(12,-21+bob)
	]), skd)
	draw_circle(Vector2(-5,-21+bob), 4, Color(0.961,0.753,0.251))
	draw_circle(Vector2( 5,-21+bob), 4, Color(0.961,0.753,0.251))
	draw_circle(Vector2(-5,-21+bob), 2.5, Color(0.910,0.314,0.063))
	draw_circle(Vector2( 5,-21+bob), 2.5, Color(0.910,0.314,0.063))
	draw_circle(Vector2(-5,-21+bob), 1.4, Color(0.067,0.067,0.067))
	draw_circle(Vector2( 5,-21+bob), 1.4, Color(0.067,0.067,0.067))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7,-9+bob), Vector2(7,-9+bob), Vector2(6,-4+bob), Vector2(-6,-4+bob)
	]), Color(0.125,0.024,0.031))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4,-5+bob), Vector2(-2,-5+bob), Vector2(-3,-10+bob)
	]), Color(0.910,0.878,0.784))
	draw_colored_polygon(PackedVector2Array([
		Vector2(2,-5+bob), Vector2(4,-5+bob), Vector2(3,-10+bob)
	]), Color(0.910,0.878,0.784))
	var fc := [Color(0.878,0.125,0.125), Color(0.941,0.627,0.063), Color(0.125,0.753,0.251), Color(0.125,0.251,0.878), Color(0.753,0.125,0.753)]
	for i in range(5):
		var fa := -2.83 + i * 1.41
		var fr := 28.0 + sin(t * 1.5 + i) * 2.0
		draw_line(Vector2(cos(fa)*14, -19+bob+sin(fa)*14), Vector2(cos(fa)*fr, -19+bob+sin(fa)*fr), fc[i], 3.0)
	draw_arc(Vector2(0,-19+bob), 5, PI, TAU, 8, gld, 2.0)


func _draw_boss_lich() -> void:
	var t    := _anim_time
	var bob  := sin(t * 1.5) * 4.0
	var ap   := 0.12 + sin(t * 2.0) * 0.05
	var bone := Color(0.847, 0.835, 0.753)
	var dark := Color(0.039, 0.008, 0.094)
	var gv   := 0.65 + sin(t * 3.5) * 0.35
	var op   := 0.7 + sin(t * 4.0) * 0.3

	draw_circle(Vector2.ZERO, 38, Color(0.439, 0.063, 0.816, ap))
	draw_set_transform(Vector2(1, 30 + bob), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 18, Color(0,0,0,0.25))
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)
	# Tattered robe outer (dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14,-14), Vector2(14,-14), Vector2(16,10), Vector2(13,22),
		Vector2(9,18), Vector2(5,26), Vector2(1,20), Vector2(-3,28),
		Vector2(-7,22), Vector2(-11,28), Vector2(-13,20), Vector2(-16,10)
	]), Color(0.039,0.008,0.094))
	# Robe inner (lighter purple)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13,-14), Vector2(13,-14), Vector2(15,10), Vector2(12,22),
		Vector2(8,18), Vector2(4,26), Vector2(0,20), Vector2(-4,28),
		Vector2(-8,22), Vector2(-12,28), Vector2(-12,20), Vector2(-15,10)
	]), Color(0.118,0.016,0.220))
	# Staff
	draw_line(Vector2(-18,18), Vector2(-20,-16), Color(0.290,0.188,0.063), 3.0)
	draw_circle(Vector2(-20,-20), 9, Color(0.439,0.063,0.816, op))
	draw_circle(Vector2(-20,-20), 6, Color(0.784,0.392,1.0, op))
	draw_circle(Vector2(-22,-22), 1.5, Color(1,1,1,0.8))
	var oa := t * 3.0
	draw_circle(Vector2(-20 + cos(oa)*9, -20 + sin(oa)*6), 2.5, Color(0.784,0.392,1.0,0.9))
	# Arms / hands
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13,-8), Vector2(-21,-2), Vector2(-19,10), Vector2(-13,10)
	]), Color(0.118,0.016,0.220))
	draw_colored_polygon(PackedVector2Array([
		Vector2(13,-8), Vector2(21,-2), Vector2(19,10), Vector2(13,10)
	]), Color(0.118,0.016,0.220))
	draw_line(Vector2(-19,8), Vector2(-22,14), Color(0.847,0.835,0.753), 2.5)
	draw_line(Vector2(-19,8), Vector2(-24,12), Color(0.847,0.835,0.753), 2.5)
	draw_line(Vector2(19,8),  Vector2(22,14),  Color(0.847,0.835,0.753), 2.5)
	draw_line(Vector2(19,8),  Vector2(24,12),  Color(0.847,0.835,0.753), 2.5)
	# Skull
	draw_circle(Vector2(1,-22), 13, Color(0.416,0.408,0.345))
	draw_circle(Vector2(0,-23), 13, bone)
	# Eye sockets + purple glow
	draw_circle(Vector2(-5,-25), 5.5, Color(0.039,0.031,0.031))
	draw_circle(Vector2( 5,-25), 5.5, Color(0.039,0.031,0.031))
	draw_circle(Vector2(-5,-25), 4, Color(0.510,0.157,0.863, gv))
	draw_circle(Vector2( 5,-25), 4, Color(0.510,0.157,0.863, gv))
	draw_circle(Vector2(-5,-25), 2, Color(0.863,0.627,1.0, gv))
	draw_circle(Vector2( 5,-25), 2, Color(0.863,0.627,1.0, gv))
	# Floating bone fragments
	for i in range(4):
		var fa := fmod(t * 0.7 + i * 1.57, TAU)
		var fp := 22.0 + i * 5.0
		var falpha := 0.4 + sin(t * 2.0 + i) * 0.3
		draw_set_transform(Vector2(cos(fa)*fp, sin(fa*0.6)*fp*0.55-14 + bob), fa*2, Vector2.ONE)
		draw_rect(Rect2(-3,-1,6,2), Color(0.847,0.835,0.753, falpha))
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)
	# Jaw + teeth
	draw_rect(Rect2(-7,-14,14,4), bone)
	for i in range(3):
		draw_rect(Rect2(-5+i*4,-14,3,4), dark)
	draw_rect(Rect2(-6,-10,12,4), bone)
	# Dark crown + glow outline
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13,-34), Vector2(-13,-40), Vector2(-7,-36),
		Vector2(-2,-44),  Vector2(3,-36),   Vector2(8,-44),
		Vector2(13,-36),  Vector2(13,-34)
	]), Color(0.039,0.008,0.094))
	draw_polyline(PackedVector2Array([
		Vector2(-13,-34), Vector2(-13,-40), Vector2(-7,-36),
		Vector2(-2,-44),  Vector2(3,-36),   Vector2(8,-44),
		Vector2(13,-36),  Vector2(13,-34)
	]), Color(0.510,0.157,0.863, 0.8), 1.5)
	var cg := 0.6 + sin(t * 4.0) * 0.3
	draw_circle(Vector2(-2,-44), 3, Color(0.706,0.314,1.0, cg))
	draw_circle(Vector2( 8,-44), 2.5, Color(0.706,0.314,1.0, cg))


func _draw_boss_golem() -> void:
	var t   := _anim_time
	var bob := sin(t * 1.5) * 4.0
	var lg  := 0.15 + sin(t * 2.2) * 0.06
	var cv  := 0.7 + sin(t * 3.0) * 0.3
	var eg  := 0.6 + sin(t * 3.0) * 0.4
	var st  := Color(0.345, 0.329, 0.314)
	var std := Color(0.188, 0.180, 0.165)
	var stl := Color(0.502, 0.490, 0.471)

	draw_circle(Vector2(0,4), 40, Color(1.0,0.392,0.039, lg))
	draw_set_transform(Vector2(2, 32 + bob), 0.0, Vector2(1.0, 0.27))
	draw_circle(Vector2.ZERO, 22, Color(0,0,0,0.28))
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)
	# Body
	draw_colored_polygon(PackedVector2Array([
		Vector2(-19,-16), Vector2(-22,-6), Vector2(-20,10), Vector2(-15,18),
		Vector2(15,18), Vector2(20,10), Vector2(22,-6), Vector2(18,-18), Vector2(0,-22)
	]), std)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-18,-16), Vector2(-21,-6), Vector2(-19,10), Vector2(-14,18),
		Vector2(14,18), Vector2(19,10), Vector2(21,-6), Vector2(17,-18), Vector2(0,-22)
	]), st)
	# Seams
	draw_line(Vector2(-20,-4), Vector2(20,-4), std, 1.0)
	draw_line(Vector2(-7,-16),  Vector2(-7,18),  std, 1.0)
	draw_line(Vector2(9,-16),   Vector2(9,18),   std, 1.0)
	# Glowing cracks
	draw_line(Vector2(-15,-10), Vector2(-5,2),   Color(1.0,0.471,0.039, cv), 2.5)
	draw_line(Vector2(-5,2),    Vector2(-10,14), Color(1.0,0.471,0.039, cv), 2.5)
	draw_line(Vector2(6,-8),    Vector2(16,6),   Color(1.0,0.471,0.039, cv), 2.5)
	draw_line(Vector2(-15,-10), Vector2(-5,2),   Color(1.0,0.863,0.235, cv*0.8), 1.0)
	# Boulder fists
	for bx in [-32.0, 18.0]:
		draw_circle(Vector2(bx+2,-2), 10, std)
		draw_circle(Vector2(bx,-4), 10, st)
		draw_circle(Vector2(bx-3,-6), 5, stl)
	# Head
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14,-32), Vector2(-15,-20), Vector2(15,-20),
		Vector2(14,-32), Vector2(0,-36)
	]), std)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13,-32), Vector2(-14,-20), Vector2(14,-20),
		Vector2(13,-32), Vector2(0,-36)
	]), st)
	# Glowing eyes
	draw_rect(Rect2(-11,-30,9,8),  Color(0.102,0.102,0.031))
	draw_rect(Rect2(2,-30,9,8),    Color(0.102,0.102,0.031))
	draw_rect(Rect2(-10,-29,7,6),  Color(1.0,0.471,0.039, eg))
	draw_rect(Rect2(3,-29,7,6),    Color(1.0,0.471,0.039, eg))
	draw_rect(Rect2(-9,-28,5,4),   Color(1.0,0.902,0.314, eg*0.8))
	draw_rect(Rect2(4,-28,5,4),    Color(1.0,0.902,0.314, eg*0.8))
	# Stone crown
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13,-36), Vector2(-13,-44), Vector2(-7,-40),
		Vector2(0,-48), Vector2(7,-40), Vector2(13,-44), Vector2(13,-36)
	]), std)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12,-36), Vector2(-12,-43), Vector2(-6,-39),
		Vector2(0,-47), Vector2(6,-39), Vector2(12,-43), Vector2(12,-36)
	]), st)
	draw_circle(Vector2(0,-47), 3.5, Color(1.0,0.471,0.039, eg))
	draw_circle(Vector2(-11,-43), 2.5, Color(1.0,0.471,0.039, eg))
	draw_circle(Vector2(11,-43),  2.5, Color(1.0,0.471,0.039, eg))


func _draw_boss_werewolf() -> void:
	var t   := _anim_time
	var bob := sin(t * 1.5) * 4.0
	var hw  := sin(t * 2.2) * 2.0
	var fur := Color(0.353, 0.259, 0.157)
	var frd := Color(0.180, 0.125, 0.078)
	var clw := Color(0.847, 0.847, 0.784)

	draw_circle(Vector2(4,-24), 34, Color(0.784,0.784,0.627,0.10))
	draw_set_transform(Vector2(1, 30 + bob), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 18, Color(0,0,0,0.25))
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)
	# Body
	draw_colored_polygon(PackedVector2Array([
		Vector2(-15,-8), Vector2(15,-8), Vector2(19,18), Vector2(-19,18)
	]), frd)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14,-8), Vector2(14,-8), Vector2(18,18), Vector2(-18,18)
	]), fur)
	# Fur bumps top
	for i in range(6):
		var bx := -12.0 + i * 5.0
		draw_arc(Vector2(bx,-8), 4, -PI, 0, 6, frd, 4.0)
		draw_arc(Vector2(bx,-8), 3.5, -PI, 0, 6, fur, 3.0)
	# Arms
	draw_rect(Rect2(-24,-4,10,18), frd); draw_rect(Rect2(14,-4,10,18), frd)
	draw_rect(Rect2(-23,-4,9,18), fur);  draw_rect(Rect2(15,-4,9,18), fur)
	# Claws (4 per arm)
	for ci in range(4):
		draw_colored_polygon(PackedVector2Array([
			Vector2(-24+ci*2.5,14), Vector2(-23+ci*2.5,14), Vector2(-23.5+ci*2.5,22)
		]), clw)
		draw_colored_polygon(PackedVector2Array([
			Vector2(15+ci*2.5,14), Vector2(16+ci*2.5,14), Vector2(15.5+ci*2.5,22)
		]), clw)
	# Armor fragment
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8,-4), Vector2(8,-4), Vector2(10,6), Vector2(-10,6)
	]), Color(0.251,0.251,0.282))
	draw_polyline(PackedVector2Array([
		Vector2(-8,-4), Vector2(8,-4), Vector2(10,6), Vector2(-10,6), Vector2(-8,-4)
	]), Color(0.376,0.376,0.408), 1.0)
	# Head
	draw_circle(Vector2(5,-20), 14, frd)
	draw_circle(Vector2(4,-21), 14, fur)
	# Snout
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2,-16), Vector2(12,-16), Vector2(16,-11), Vector2(-1,-11)
	]), frd)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-1,-16), Vector2(11,-16), Vector2(15,-11), Vector2(0,-11)
	]), fur)
	# Snarling teeth
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2,-11), Vector2(14,-11), Vector2(13,-6), Vector2(-1,-6)
	]), Color(0.102,0.055,0.031))
	for i in range(4):
		draw_rect(Rect2(-1+i*3.5,-11, 2.5,3), clw)
	# Ears (animated)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4,-30), Vector2(-10,-44+hw), Vector2(2,-30)
	]), fur)
	draw_colored_polygon(PackedVector2Array([
		Vector2(8,-30), Vector2(16,-42+hw), Vector2(18,-28)
	]), fur)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4,-30), Vector2(-8,-40+hw), Vector2(1,-30)
	]), Color(0.478,0.188,0.188))
	# Eyes (golden, slit pupils)
	draw_circle(Vector2(-2,-23), 5, Color(0.071,0.039,0.016))
	draw_circle(Vector2( 7,-23), 5, Color(0.071,0.039,0.016))
	draw_circle(Vector2(-2,-23), 4, Color(0.941,0.722,0.125))
	draw_circle(Vector2( 7,-23), 4, Color(0.941,0.722,0.125))
	draw_set_transform(Vector2(-2, -23 + bob), 0.0, Vector2(0.45, 1.0))
	draw_circle(Vector2.ZERO, 2.2, Color(0.067,0.067,0.067))
	draw_set_transform(Vector2(7, -23 + bob), 0.0, Vector2(0.45, 1.0))
	draw_circle(Vector2.ZERO, 2.2, Color(0.067,0.067,0.067))
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)
	draw_circle(Vector2(-3.5,-24.5), 1, Color(1,1,1,0.8))
	draw_circle(Vector2(5.5,-24.5),  1, Color(1,1,1,0.8))


func _draw_boss_dragon() -> void:
	var t    := _anim_time
	var bob  := sin(t * 1.5) * 4.0
	var flap := sin(t * 5.0) * 8.0
	var sc   := Color(0.102, 0.439, 0.063)
	var scd  := Color(0.039, 0.220, 0.031)
	var ft   := (sin(t * 3.0) + 1.0) * 0.5
	var fs   := 8.0 + sin(t * 6.0) * 4.0

	draw_set_transform(Vector2(1, 28 + bob), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 20, Color(0,0,0,0.25))
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)
	# Wings
	for sx in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx*10,-10), Vector2(sx*34,-22-flap),
			Vector2(sx*40,-4-flap*0.5), Vector2(sx*20,8)
		]), scd)
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx*10,-10), Vector2(sx*33,-21-flap),
			Vector2(sx*39,-4-flap*0.5), Vector2(sx*19,8)
		]), Color(0.082,0.353,0.047))
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx*10,-10), Vector2(sx*28,-16-flap*0.6),
			Vector2(sx*32,-2-flap*0.3), Vector2(sx*18,6)
		]), Color(0.145,0.376,0.125,0.35))
	# Body + belly
	draw_circle(Vector2(0,4), 19, scd); draw_circle(Vector2(0,4), 18, sc)
	draw_circle(Vector2(0,6), 12, Color(0.722,0.816,0.376))
	# Neck
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8,-10), Vector2(8,-10), Vector2(11,-5), Vector2(-11,-5)
	]), scd)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7,-10), Vector2(7,-10), Vector2(10,-5), Vector2(-10,-5)
	]), sc)
	# Head
	draw_circle(Vector2(1,-16), 15, scd); draw_circle(Vector2(0,-17), 15, sc)
	# Curved horns (bezier approximated as polygon)
	for sx2 in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx2*7,-28), Vector2(sx2*8,-36), Vector2(sx2*9,-40),
			Vector2(sx2*10,-28), Vector2(sx2*8,-26)
		]), scd)
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx2*7,-28), Vector2(sx2*7.5,-35), Vector2(sx2*8.5,-39),
			Vector2(sx2*9.5,-28), Vector2(sx2*7.5,-26)
		]), Color(0.157,0.627,0.125))
	# Nostrils
	draw_circle(Vector2(-4,-12), 2.5, scd); draw_circle(Vector2(4,-12), 2.5, scd)
	# Eyes
	draw_circle(Vector2(-5,-21), 5, Color(0.102,0.063,0.031))
	draw_circle(Vector2( 5,-21), 5, Color(0.102,0.063,0.031))
	draw_circle(Vector2(-5,-21), 4, Color(0.941,0.753,0.063))
	draw_circle(Vector2( 5,-21), 4, Color(0.941,0.753,0.063))
	draw_set_transform(Vector2(-5, -21 + bob), 0.0, Vector2(0.48,1.0))
	draw_circle(Vector2.ZERO, 2.5, Color(0.067,0.067,0.067))
	draw_set_transform(Vector2(5, -21 + bob), 0.0, Vector2(0.48,1.0))
	draw_circle(Vector2.ZERO, 2.5, Color(0.067,0.067,0.067))
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)
	draw_circle(Vector2(-6.5,-22.5), 1.2, Color(1,1,1,0.8))
	draw_circle(Vector2(3.5,-22.5),  1.2, Color(1,1,1,0.8))
	# Fire breath (animated)
	draw_circle(Vector2(0,-7), fs+2, Color(0.941,0.471,0.039, ft*0.9))
	draw_circle(Vector2(0,-7), fs,   Color(1.0,0.784,0.039,   ft*0.85))
	draw_circle(Vector2(0,-7), fs*0.5, Color(1.0,0.980,0.314, ft*0.7))


func _draw_boss_ice_giant() -> void:
	var t   := _anim_time
	var bob := sin(t * 1.5) * 4.0
	var ic  := Color(0.416, 0.690, 0.847)
	var icd := Color(0.165, 0.376, 0.565)
	var wh  := Color(0.847, 0.941, 1.0)
	var cg  := 0.5 + sin(t * 4.0) * 0.3

	draw_circle(Vector2(0,4), 42, Color(0.392,0.706,0.863,0.12))
	draw_set_transform(Vector2(1, 30 + bob), 0.0, Vector2(1.0, 0.23))
	draw_circle(Vector2.ZERO, 22, Color(0,0,0,0.25))
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)
	# Body
	draw_colored_polygon(PackedVector2Array([
		Vector2(-18,-14), Vector2(-22,-4), Vector2(-18,20),
		Vector2(18,20), Vector2(22,-4), Vector2(18,-14)
	]), icd)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-17,-14), Vector2(-21,-4), Vector2(-17,20),
		Vector2(17,20), Vector2(21,-4), Vector2(17,-14)
	]), ic)
	# Seams
	draw_line(Vector2(-20,-4), Vector2(20,-4), icd, 1.0)
	draw_line(Vector2(-7,-14), Vector2(-7,20), icd, 1.0)
	draw_line(Vector2(9,-14),  Vector2(9,20),  icd, 1.0)
	# Crystal inner highlight
	draw_colored_polygon(PackedVector2Array([
		Vector2(-17,-14), Vector2(-3,-14), Vector2(-3,20), Vector2(-17,20)
	]), Color(0.784,0.941,1.0, 0.25))
	# Crystal chest emblem
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8,-8), Vector2(0,-16), Vector2(8,-8),
		Vector2(8,6), Vector2(0,12), Vector2(-8,6)
	]), wh)
	draw_polyline(PackedVector2Array([
		Vector2(-8,-8), Vector2(0,-16), Vector2(8,-8),
		Vector2(8,6), Vector2(0,12), Vector2(-8,6), Vector2(-8,-8)
	]), icd, 1.5)
	draw_circle(Vector2(0,-2), 5, Color(0.392,0.706,0.863, cg))
	# Crystal arms
	for ax in [-34.0, 17.0]:
		draw_rect(Rect2(ax,-10,16,20), icd)
		draw_rect(Rect2(ax+1,-10,14,20), ic)
		draw_rect(Rect2(ax+1,-10,6,20), Color(0.784,0.941,1.0, 0.28))
	# Head
	draw_circle(Vector2(1,-24), 14, icd); draw_circle(Vector2(0,-25), 14, ic)
	draw_circle(Vector2(-5,-30), 7, Color(0.784,0.941,1.0, 0.35))
	# Eyes
	draw_circle(Vector2(-4,-27), 4.5, icd); draw_circle(Vector2(4,-27), 4.5, icd)
	draw_circle(Vector2(-4,-27), 3.5, Color(0.063,0.565,0.878))
	draw_circle(Vector2( 4,-27), 3.5, Color(0.063,0.565,0.878))
	draw_circle(Vector2(-4,-27), 2, wh); draw_circle(Vector2(4,-27), 2, wh)
	# Ice crown (7 spikes)
	draw_rect(Rect2(-13,-38,26,5), icd); draw_rect(Rect2(-12,-38,24,4), ic)
	var spike_heights := [10.0, 13.0, 13.0, 16.0, 13.0, 13.0, 10.0]
	for ci in range(7):
		var cx := -12.0 + ci * 4.0
		var ch : float = spike_heights[ci]
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx,-38), Vector2(cx+4,-38), Vector2(cx+2,-38-ch)
		]), icd)
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx+0.5,-38), Vector2(cx+3.5,-38), Vector2(cx+2,-38-ch+2)
		]), Color(0.753,0.910,0.973))
	# Frost particles
	for fi in range(5):
		var fa := fmod(t * 0.5 + fi * 1.257, TAU)
		var fd := 30.0 + fi * 3.0
		var fa2 := (sin(t * 2.5 + fi) + 1.0) * 0.22
		draw_circle(Vector2(cos(fa)*fd, sin(fa*0.7)*fd*0.6-8), 2, Color(0.784,0.941,1.0, fa2))


func _draw_boss_shadow_demon() -> void:
	var t   := _anim_time
	var bob := sin(t * 1.5) * 4.0
	var wa  := sin(t * 2.5) * 8.0
	var dk  := Color(0.118, 0.016, 0.188)
	var mid := Color(0.188, 0.031, 0.314)

	draw_circle(Vector2.ZERO, 40, Color(0.392,0.031,0.549,0.15))
	draw_set_transform(Vector2(1, 28 + bob), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 18, Color(0,0,0,0.30))
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)
	# Body layers (3 circles)
	draw_circle(Vector2(0,2), 26, Color(0.118,0.016,0.188))
	draw_circle(Vector2(0,2), 24, mid)
	draw_circle(Vector2(0,2), 18, dk)
	# Demonic horns (bezier approximated)
	for sx in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx*10,-18), Vector2(sx*12,-26), Vector2(sx*16,-36),
			Vector2(sx*18,-28+sx*2), Vector2(sx*14,-14)
		]), Color(0.102,0.016,0.157))
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx*10,-18), Vector2(sx*11.5,-25), Vector2(sx*15,-35),
			Vector2(sx*17,-27+sx*2), Vector2(sx*13,-14)
		]), Color(0.627,0.157,0.784,0.4))
	# Tentacle tendrils bottom
	var ta := [3.46, 3.84, 4.40, 4.78]
	for i in range(4):
		var tangle : float = ta[i]
		var tw := sin(t * 2.2 + i * 0.8) * 6.0
		var p1 := Vector2(cos(tangle)*14, 2+sin(tangle)*14)
		var p2 := Vector2(cos(tangle)*26+tw, 2+sin(tangle)*26)
		draw_line(p1, p2, mid, 5.0)
	# Wavy arms
	draw_colored_polygon(PackedVector2Array([
		Vector2(-22,-4), Vector2(-30,2+wa), Vector2(-32,14), Vector2(-26,12), Vector2(-18,6)
	]), mid)
	draw_colored_polygon(PackedVector2Array([
		Vector2(22,-4), Vector2(30,2-wa), Vector2(32,14), Vector2(26,12), Vector2(18,6)
	]), mid)
	# 4 eyes: 2 large red (bottom), 2 smaller orange (top)
	var eye_data := [
		[Vector2(-9,-10), 7.0, Color(1.0,0.098,0.059)],
		[Vector2(9,-10),  7.0, Color(1.0,0.098,0.059)],
		[Vector2(-5,-18), 5.0, Color(0.863,0.706,0.039)],
		[Vector2(5,-18),  5.0, Color(0.863,0.706,0.039)],
	]
	for i in range(4):
		var eg := 0.7 + sin(t * 4.0 + i * 0.8) * 0.3
		var ec : Color = eye_data[i][2]
		draw_circle(eye_data[i][0], eye_data[i][1]+2, Color(ec.r,ec.g,ec.b,eg*0.4))
		draw_circle(eye_data[i][0], eye_data[i][1],   Color(ec.r,ec.g,ec.b,eg))
		draw_circle(eye_data[i][0], eye_data[i][1]*0.4, Color(1,1,0.784,eg*0.9))
	# Wide grin + fangs
	draw_arc(Vector2(0,4), 12, 0.3, PI-0.3, 16, Color(1.0,0.098,0.059,0.8), 2.5)
	for fi in range(4):
		draw_colored_polygon(PackedVector2Array([
			Vector2(-7+fi*5,8), Vector2(-5+fi*5,8), Vector2(-6+fi*5,14)
		]), Color(0.941,0.941,0.973,0.85))
	# Orbiting void particles
	for pi2 in range(6):
		var pa := fmod(t * 0.7 + pi2 * 1.047, TAU)
		var a2 := (sin(t * 2.0 + pi2) + 1.0) * 0.2
		draw_circle(Vector2(cos(pa)*26, 2+sin(pa*0.8)*26*0.7), 1.8, Color(0.706,0.157,0.863,a2))


func _draw_boss_helldrake() -> void:
	var t    := _anim_time
	var bob  := sin(t * 1.5) * 4.0
	var flap := sin(t * 5.0) * 8.0
	var sc   := Color(0.690, 0.094, 0.031)
	var scd  := Color(0.345, 0.031, 0.031)
	var fs   := 9.0 + sin(t * 6.0) * 5.0

	draw_circle(Vector2(0,4), 44, Color(1.0,0.314,0.039, 0.16))
	draw_set_transform(Vector2(1, 30 + bob), 0.0, Vector2(1.0, 0.27))
	draw_circle(Vector2.ZERO, 22, Color(0,0,0,0.28))
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)
	# Wings (wider than dragon)
	for sx in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx*10,-8), Vector2(sx*38,-24-flap),
			Vector2(sx*44,0-flap*0.5), Vector2(sx*22,10)
		]), scd)
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx*10,-8), Vector2(sx*37,-23-flap),
			Vector2(sx*43,0-flap*0.5), Vector2(sx*21,10)
		]), Color(0.502,0.031,0.031))
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx*10,-8), Vector2(sx*30,-16-flap*0.6),
			Vector2(sx*34,-2-flap*0.3), Vector2(sx*20,8)
		]), Color(0.471,0.031,0.031,0.35))
	# Body + belly
	draw_circle(Vector2(0,4), 21, scd); draw_circle(Vector2(0,4), 20, sc)
	draw_circle(Vector2(0,6), 13, Color(0.847,0.596,0.125))
	# Inferno crown ring
	for fi in range(6):
		var fa := -2.51 + fi * 1.047
		var fr := 19.0 + sin(t * 4.0 + fi) * 4.0
		var fglow := 0.6 + sin(t * 5.0 + fi * 0.9) * 0.3
		draw_circle(Vector2(cos(fa)*14, -16+sin(fa)*10), fr*0.22, Color(1.0,0.471,0.039, fglow))
		draw_circle(Vector2(cos(fa)*14, -16+sin(fa)*10), fr*0.12, Color(1.0,0.863,0.196, fglow*0.7))
	# Neck
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9,-8), Vector2(9,-8), Vector2(13,-4), Vector2(-13,-4)
	]), scd)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8,-8), Vector2(8,-8), Vector2(12,-5), Vector2(-12,-5)
	]), sc)
	# Head
	draw_circle(Vector2(1,-18), 16, scd); draw_circle(Vector2(0,-19), 16, sc)
	# 4 horn pairs + center horn
	var hd := [
		[Vector2(-8,-30), Vector2(-14,-46)], [Vector2(8,-30), Vector2(14,-46)],
		[Vector2(-4,-30), Vector2(-6,-44)],  [Vector2(4,-30),  Vector2(6,-44)]
	]
	for h in hd:
		draw_colored_polygon(PackedVector2Array([h[0], h[1], h[1]+Vector2(3,4)]), scd)
		draw_colored_polygon(PackedVector2Array([h[0]+Vector2(1,0), h[1]+Vector2(1,0), h[1]+Vector2(3,4)]), Color(0.878,0.157,0.094))
	draw_colored_polygon(PackedVector2Array([Vector2(-2,-30), Vector2(0,-46), Vector2(3,-30)]), scd)
	draw_colored_polygon(PackedVector2Array([Vector2(-1.5,-30), Vector2(0,-45), Vector2(2.5,-30)]), Color(0.878,0.157,0.094))
	# Nostrils
	draw_circle(Vector2(-5,-18), 3, scd); draw_circle(Vector2(5,-18), 3, scd)
	# Eyes
	draw_circle(Vector2(-6,-21), 5.5, Color(0.102,0.031,0.031))
	draw_circle(Vector2( 6,-21), 5.5, Color(0.102,0.031,0.031))
	draw_circle(Vector2(-6,-21), 4.5, Color(0.941,0.753,0.063))
	draw_circle(Vector2( 6,-21), 4.5, Color(0.941,0.753,0.063))
	draw_set_transform(Vector2(-6, -21 + bob), 0.0, Vector2(0.53,1.0))
	draw_circle(Vector2.ZERO, 2.8, Color(0.067,0.067,0.067))
	draw_set_transform(Vector2(6, -21 + bob), 0.0, Vector2(0.53,1.0))
	draw_circle(Vector2.ZERO, 2.8, Color(0.067,0.067,0.067))
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)
	# Always-on fire breath (3 layers)
	draw_circle(Vector2(0,-7), fs+3, Color(1.0,0.392,0.039, 0.85))
	draw_circle(Vector2(0,-7), fs,   Color(1.0,0.745,0.078, 0.85))
	draw_circle(Vector2(0,-7), fs*0.55, Color(1.0,0.941,0.314, 0.7))
	draw_circle(Vector2(0,-7), fs*0.25, Color(1.0,1.0,0.784,   0.6))


func _draw_boss_dark_lord() -> void:
	var t   := _anim_time
	var bob := sin(t * 1.5) * 4.0
	var cb  := sin(t * 1.8) * 4.0
	var arm := Color(0.118, 0.094, 0.157)
	var arl := Color(0.204, 0.180, 0.282)
	var gld := Color(0.816, 0.690, 0.094)
	var eg  := 0.7 + sin(t * 3.0) * 0.3
	var og  := 0.7 + sin(t * 3.5) * 0.3

	draw_circle(Vector2.ZERO, 42, Color(0.706,0.039,0.706, 0.13))
	draw_set_transform(Vector2(1, 30 + bob), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 18, Color(0,0,0,0.28))
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)
	# Billowing void cape
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14,-10), Vector2(14,-10), Vector2(20+cb,24), Vector2(-20-cb,24)
	]), Color(0.227,0.024,0.024))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13,-10), Vector2(13,-10), Vector2(19+cb,24), Vector2(-19-cb,24)
	]), Color(0.353,0.031,0.031))
	# Void stars on cape
	for si in range(5):
		var sx2 := -8.0 + si * 5.0 + cb * 0.3 * (si - 2)
		var sy2 := 2.0 + si * 4.0
		var sa := (sin(t * 1.5 + si) + 1.0) * 0.5
		draw_circle(Vector2(sx2,sy2), 1.2, Color(0.784,0.588,1.0, sa*0.5))
	# Armor body
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13,-10), Vector2(13,-10), Vector2(13,8), Vector2(-13,8)
	]), Color(0.031,0.008,0.063))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12,-10), Vector2(12,-10), Vector2(12,8), Vector2(-12,8)
	]), arm)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10,-8), Vector2(10,-8), Vector2(9,8), Vector2(-9,8)
	]), arl)
	draw_rect(Rect2(-12,-8,24,2), gld)
	draw_line(Vector2(0,-8), Vector2(0,8), gld, 1.5)
	# Shoulder pauldrons
	for sx in [-16.0, 16.0]:
		draw_circle(Vector2(sx,-8), 11, Color(0.031,0.008,0.063))
		draw_circle(Vector2(sx,-8), 10, arm)
		draw_arc(Vector2(sx,-8), 10, -PI, 0, 8, gld, 1.5)
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx-3,-16), Vector2(sx,-28), Vector2(sx+3,-16)
		]), gld)
	# Arms
	draw_rect(Rect2(-26,-4,12,18), Color(0.031,0.008,0.063))
	draw_rect(Rect2(14,-4,12,18),  Color(0.031,0.008,0.063))
	draw_rect(Rect2(-25,-4,11,18), arm)
	draw_rect(Rect2(15,-4,11,18),  arm)
	# Scepter
	draw_set_transform(Vector2(-22, 12 + bob), 0.0, Vector2.ONE)
	draw_line(Vector2.ZERO, Vector2(0,-24), Color(0.102,0.055,0.188), 4.0)
	draw_rect(Rect2(-5,-26,10,4), gld)
	draw_circle(Vector2(0,-30), 7, Color(0.706,0.039,0.706, og))
	draw_circle(Vector2(0,-30), 4, Color(1.0,0.706,1.0, og))
	draw_circle(Vector2(-1.5,-31.5), 1.2, Color(1,1,1,0.8))
	var oa := t * 2.5
	draw_circle(Vector2(cos(oa)*7, -30+sin(oa)*5), 2, Color(0.863,0.392,0.863,0.7))
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)
	# Head
	draw_circle(Vector2(1,-22), 14, Color(0.031,0.008,0.063))
	draw_circle(Vector2(0,-23), 14, arm)
	draw_circle(Vector2(-4,-28), 7, Color(arl.r,arl.g,arl.b,1.0))
	draw_circle(Vector2(0,-23), 14, arl, false, 1.5)
	draw_rect(Rect2(-8,-26,16,4), Color(0.031,0.008,0.063))
	# Purple eye glow (3 layers)
	draw_circle(Vector2(-4,-24), 6, Color(0.863,0.063,0.863, eg*0.4))
	draw_circle(Vector2( 4,-24), 6, Color(0.863,0.063,0.863, eg*0.4))
	draw_circle(Vector2(-4,-24), 4, Color(0.863,0.063,0.863, eg))
	draw_circle(Vector2( 4,-24), 4, Color(0.863,0.063,0.863, eg))
	draw_circle(Vector2(-4,-24), 2, Color(1.0,0.784,1.0, eg))
	draw_circle(Vector2( 4,-24), 2, Color(1.0,0.784,1.0, eg))
	# Ornate crown
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14,-34), Vector2(-14,-40), Vector2(-8,-36),
		Vector2(-4,-46),  Vector2(0,-40),   Vector2(4,-46),
		Vector2(8,-36),   Vector2(14,-40),  Vector2(14,-34)
	]), Color(0.031,0.008,0.063))
	draw_polyline(PackedVector2Array([
		Vector2(-14,-34), Vector2(-14,-40), Vector2(-8,-36),
		Vector2(-4,-46),  Vector2(0,-40),   Vector2(4,-46),
		Vector2(8,-36),   Vector2(14,-40),  Vector2(14,-34)
	]), gld, 1.5)
	var cg2 := 0.7 + sin(t * 4.0) * 0.3
	draw_circle(Vector2(-4,-46), 3.5, Color(0.863,0.063,0.863, cg2))
	draw_circle(Vector2( 4,-46), 3.5, Color(0.863,0.063,0.863, cg2))
	# Big center crown gem (pulsing)
	var bg := 0.8 + sin(t * 3.0) * 0.2
	draw_circle(Vector2(0,-40), 5, Color(0.863,0.063,0.863, bg))
	draw_circle(Vector2(0,-40), 3, Color(1.0,0.784,1.0, 0.9))
	draw_circle(Vector2(-1,-41), 1.3, Color(1,1,1,0.9))
	# Orbiting particles
	for pi2 in range(5):
		var pa := fmod(t * 1.2 + pi2 * 1.257, TAU)
		var a2 := (sin(t * 2.0 + pi2) + 1.0) * 0.2
		draw_circle(Vector2(cos(pa)*34, sin(pa)*34*0.7-10), 1.8, Color(0.784,0.196,0.784,a2))
