# scripts/Tower.gd
# ─────────────────────────────────────────────────────────────────────────────
# Tower placed on the build grid. Supports character visuals, shoot animation,
# idle bob, and a "held" state for drag-to-move.
# ─────────────────────────────────────────────────────────────────────────────
extends Node2D

signal gold_proc(amount: float)      # emitted by Nature's Wrath on gold-proc hits
signal serpent_summon(dmg: float)    # emitted by Infernal Serpent on 5% proc

const TILE_SIZE : int = 60
const _NW_COIN_FONT : Font = preload("res://assets/fonts/Rajdhani-Bold.ttf")

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
var _hit_counter   : int     = 0
var _last_target   : Node2D  = null
var _bleed_stacks  : Dictionary = {}
var _bleed_tick_timer : float = 0.0
var _arcane_charge : int = 0   # persistent hit counter for arcane_cannon, never resets
var _arcane_laser_targets : Array = []
var _arcane_laser_timer   : float = 0.0
var _arcane_laser_alpha   : float = 0.0
var _alt_hand             : bool  = false   # rogue / shadow blade alternating hand tracker
var _dual_swing           : bool  = false   # shadow blade: both hands strike simultaneously on hit 3
var _spear_spin_timer     : float = 0.0     # spearman: counts down from 1.0 over one full spin
var _lightning_bolts      : Array = []      # tesla: [{pts, life, max_life, delay, thick}]
var _bullet_scene  : PackedScene
const _SLASH_SCRIPT : GDScript = preload("res://scripts/SlashEffect.gd")
var _landing       : bool    = false
var _beam_target      : Node2D  = null
var _beam_timer       : float   = 0.0
var _beam_tick_timer  : float   = 0.0
var _beam_lock_time   : float   = 0.0   # continuous lock duration for ramp damage
var _beam_target2     : Node2D  = null
var _beam_timer2      : float   = 0.0
var _beam_tick_timer2 : float   = 0.0
var _beam_lock_time2  : float   = 0.0
var _impact_radius : float   = 0.0
var _impact_alpha  : float   = 0.0
var _throw_timer   : float   = 0.0
var _throw_dir     : Vector2 = Vector2.RIGHT
var _shoot_anim    : float   = 0.0   # counts down from 0.35 on each shot
var _anim_time     : float   = 0.0   # ever-increasing, drives idle bob
var _blade_angle   : float   = 0.0   # blade assassin: current orbit angle (radians)
var _blade_timer   : float   = 0.0   # blade assassin: seconds remaining on active spin
var _blade_dmg_tick: float   = 0.0   # blade assassin: contact damage tick countdown
var _blade_hit_set : Dictionary = {}  # enemies already hit this spin proc (hit-once logic)
var _hercules_wave_bonus : float = 0.0  # hercules: accumulated +5 dmg per wave cleared
var _wt_dmg_bonus  : float = 0.0     # world tree: flat damage bonus (summed from all sources)
var _wt_rate_bonus : float = 0.0     # world tree: fire rate multiplier bonus (summed from all sources)
var _wt_buffs      : Dictionary = {} # instance_id → {dmg, rate, timer} — one entry per buffing tower
var _nw_coins      : Array = []      # natures_wrath gold proc coins: [{y, alpha}]
var _ranger_rate_bonus : float = 0.0  # ranger hero: +10% fire rate buff from nearby ranger
var _ranger_rate_timer : float = 0.0  # seconds until ranger fire rate buff expires
var _rock_zones        : Array = []   # stone guardian: active brittle zones [{pos,timer,hit_dict}]
var _debuff_cd         : Dictionary = {}  # dual debuff: per-enemy cooldown {enemy:{type:timer}}
var _frost_speed_bonus : float = 0.0      # frost herald: accumulated +5% atk speed per slowed hit (max 50%)
var _frost_idle_timer  : float = 0.0      # frost herald: seconds since last attack; resets bonus at 3s
var _sw_stacks         : int   = 0        # shadow weaver: shadow-phase hit counter (0-10)
var _sw_light_timer    : float = 0.0      # shadow weaver: seconds remaining in light phase
var _sw_beam_tick      : float = 0.0      # shadow weaver: countdown to next light-phase beam pulse
var _sw_beam_targets   : Array = []       # shadow weaver: current light-phase beam targets (for drawing)
var _sw_beam_alpha     : float = 0.0      # shadow weaver: beam visual fade
var _sw_base_color     : Color = Color(0.55, 0.20, 0.85)  # shadow weaver: original purple saved on init
var _wt_passive_tick : float = 0.0   # world tree: timer for passive buff pulse
var _chrono_pulse  : float = 0.0     # chrono mage: attack pulse visual timer
var _fc_impacts    : Array = []      # frost cannon: [{pos, t, max_t, boss}] impact flashes


func _ready() -> void:
	_bullet_scene = load("res://scenes/Bullet.tscn")
	add_to_group("towers")


func init_type(data: Dictionary) -> void:
	# Remap legacy effect keys so old saved towers get the correct effect
	const _EFFECT_REMAP : Dictionary = {
		# chrono_mage was "aoe", world_tree was "chain" — remap by tower id
	}
	# Per-tower id remap (more reliable than effect key alone)
	var _tid_remap : Dictionary = {
		"chrono_mage":   "chrono_aoe",
		"world_tree":    "world_tree_buff",
		"storm_lord":    "storm_chain",
		"sun_dragon":    "aoe_burst",
		"natures_wrath": "natures_wrath_buff",
	}
	var _tower_id : String = data.get("id", "")
	if _tid_remap.has(_tower_id):
		data = data.duplicate()
		data["effect"] = _tid_remap[_tower_id]

	tower_data   = data
	attack_range = data.get("range",     200.0)
	damage       = data.get("damage",    3.0)
	fire_rate    = data.get("fire_rate", 1.0)

	# Bake range level buff into attack_range (used for targeting, not recalculated at fire time).
	# damage and fire_rate stay at base — combined mult applied additively in _fire/_cooldown.
	var _tid : String = data.get("id", "")
	if _tid != "":
		attack_range *= GameData.tower_level_range_mult(_tid)
		tower_data = tower_data.duplicate()
		tower_data["range"] = attack_range

	tower_color     = data.get("color",     Color(0.50, 0.55, 0.70))
	_sw_base_color  = tower_color   # save for shadow weaver phase swap
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
		if _shoot_anim <= 0.0:
			_dual_swing = false
	if _beam_timer > 0.0:
		_beam_timer -= delta
		_beam_lock_time += delta
		if not is_instance_valid(_beam_target):
			_beam_target     = null
			_beam_timer      = 0.0
			_beam_tick_timer = 0.0
			_beam_lock_time  = 0.0
		elif position.distance_to(_beam_target.position) > attack_range:
			# Target walked out of range — cancel beam immediately
			_beam_target     = null
			_beam_timer      = 0.0
			_beam_tick_timer = 0.0
			_beam_lock_time  = 0.0
		else:
			_beam_tick_timer -= delta
			if _beam_tick_timer <= 0.0:
				_beam_tick_timer = 0.25
				var lock_mult := 1.0 + minf(_beam_lock_time / 5.0, 1.0) * 0.5
				var tick_dmg := damage * fire_rate * 0.25 * lock_mult * \
					(GameData.relic_boss_dmg_mult() if _beam_target.is_boss else 1.0)
				_beam_target.take_damage(tick_dmg)
		if _beam_timer <= 0.0:
			_beam_timer      = 0.0
			_beam_tick_timer = 0.0
			# lock_beam keeps _beam_target so _try_shoot can prefer it next cycle
			if tower_effect != "lock_beam":
				_beam_target    = null
				_beam_lock_time = 0.0
	if _beam_timer2 > 0.0:
		_beam_timer2 -= delta
		_beam_lock_time2 += delta
		if not is_instance_valid(_beam_target2):
			_beam_target2     = null
			_beam_timer2      = 0.0
			_beam_tick_timer2 = 0.0
			_beam_lock_time2  = 0.0
		elif position.distance_to(_beam_target2.position) > attack_range:
			_beam_target2     = null
			_beam_timer2      = 0.0
			_beam_tick_timer2 = 0.0
			_beam_lock_time2  = 0.0
		else:
			_beam_tick_timer2 -= delta
			if _beam_tick_timer2 <= 0.0:
				_beam_tick_timer2 = 0.25
				var lock_mult2 := 1.0 + minf(_beam_lock_time2 / 5.0, 1.0) * 0.5
				var tick_dmg2 := damage * fire_rate * 0.25 * lock_mult2 * \
					(GameData.relic_boss_dmg_mult() if _beam_target2.is_boss else 1.0)
				_beam_target2.take_damage(tick_dmg2)
		if _beam_timer2 <= 0.0:
			_beam_timer2      = 0.0
			_beam_tick_timer2 = 0.0
			if tower_effect != "lock_beam":
				_beam_target2    = null
				_beam_lock_time2 = 0.0
	if _spear_spin_timer > 0.0:
		_spear_spin_timer -= delta
	if _arcane_laser_timer > 0.0:
		_arcane_laser_timer -= delta
		_arcane_laser_alpha = clampf(_arcane_laser_timer, 0.0, 1.0)
		if _arcane_laser_timer <= 0.0:
			_arcane_laser_targets.clear()
	if _blade_timer > 0.0:
		_blade_timer -= delta
		_blade_angle -= delta * TAU * 0.5    # 1 full orbit per 2 seconds, counter-clockwise
		const ORBIT_R  : float = 65.0
		const HIT_R    : float = 36.0        # larger blade hit radius
		var tid_b : String = tower_data.get("id", "")
		var _in_range_now : Dictionary = {}
		for blade_i in range(2):
			var ba_off := _blade_angle + blade_i * PI
			var blade_pos := position + Vector2(cos(ba_off), sin(ba_off)) * ORBIT_R
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(enemy):
					continue
				if enemy.position.distance_to(blade_pos) <= HIT_R:
					_in_range_now[enemy] = true
					if not _blade_hit_set.has(enemy):
						# First contact — deal damage once
						_blade_hit_set[enemy] = true
						var bdmg := (damage * 0.5 + GameData.buff_damage_flat) \
							* GameData.turret_damage_mult(tid_b) \
							* (GameData.relic_boss_dmg_mult() if enemy.is_boss else 1.0)
						enemy.take_damage(bdmg)
		# Remove enemies that left contact so they can be hit again next pass
		var _leave : Array = []
		for _he in _blade_hit_set.keys():
			if not _in_range_now.has(_he):
				_leave.append(_he)
		for _hl in _leave:
			_blade_hit_set.erase(_hl)
		if _blade_timer <= 0.0:
			_blade_timer = 0.0
			_blade_hit_set.clear()
	if not _lightning_bolts.is_empty():
		var bi := _lightning_bolts.size() - 1
		while bi >= 0:
			if _lightning_bolts[bi]["delay"] > 0.0:
				_lightning_bolts[bi]["delay"] -= delta
			else:
				_lightning_bolts[bi]["life"] -= delta
				if _lightning_bolts[bi]["life"] <= 0.0:
					_lightning_bolts.remove_at(bi)
			bi -= 1
	if not _wt_buffs.is_empty():
		var _wt_expired := []
		for _wt_src in _wt_buffs:
			_wt_buffs[_wt_src]["timer"] -= delta
			if _wt_buffs[_wt_src]["timer"] <= 0.0:
				_wt_expired.append(_wt_src)
		for _wt_e in _wt_expired:
			_wt_buffs.erase(_wt_e)
		_wt_dmg_bonus  = 0.0
		_wt_rate_bonus = 0.0
		for _wt_src in _wt_buffs:
			_wt_dmg_bonus  += _wt_buffs[_wt_src]["dmg"]
			_wt_rate_bonus += _wt_buffs[_wt_src]["rate"]
	if _ranger_rate_timer > 0.0:
		_ranger_rate_timer -= delta
		if _ranger_rate_timer <= 0.0:
			_ranger_rate_bonus = 0.0
	if _frost_speed_bonus > 0.0:
		_frost_idle_timer += delta
		if _frost_idle_timer >= 3.0:
			_frost_speed_bonus = 0.0
			_frost_idle_timer  = 0.0
	# Shadow Weaver: light-phase beam tick + colour swap
	if _sw_light_timer > 0.0:
		tower_color = Color(0.93, 0.92, 0.98)   # white-cloth during light phase
		_sw_light_timer -= delta
		_sw_beam_tick   -= delta
		if _sw_beam_alpha > 0.0:
			_sw_beam_alpha = maxf(0.0, _sw_beam_alpha - delta * 3.0)
		if _sw_beam_tick <= 0.0:
			_sw_beam_tick = 0.5   # pulse every 0.5s
			# Grab nearest 5 enemies in range
			var _sw_all : Array = []
			for _sw_e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(_sw_e) and not _sw_e._dead \
						and position.distance_to(_sw_e.position) <= attack_range:
					_sw_all.append(_sw_e)
			_sw_all.sort_custom(func(a, b): return a._current_wp > b._current_wp)
			_sw_beam_targets = _sw_all.slice(0, 5)
			_sw_beam_alpha   = 1.0
			for _sw_t in _sw_beam_targets:
				var _sw_hp_bonus : float = _sw_t.max_hp * (0.005 if _sw_t.is_boss else 0.01)
				_sw_t.take_damage(damage * 0.5 + _sw_hp_bonus)
		if _sw_light_timer <= 0.0:
			_sw_light_timer  = 0.0
			_sw_beam_targets = []
			tower_color      = _sw_base_color   # restore purple on phase end
		queue_redraw()
	# Stone Guardian: tick brittle rock zones — phased animation
	if not _rock_zones.is_empty():
		const _ROCK_RADIUS  : float = 38.0
		const _PHASE_DUR    : Array = [0.15, 0.25, 0.15, 2.0, 0.2]
		var   _rz_finished  : Array = []
		for _rz in _rock_zones:
			_rz["phase_t"] += delta
			var _ph     : int   = _rz["phase"]
			var _pt     : float = _rz["phase_t"]
			var _pdur   : float = _PHASE_DUR[_ph]
			var _pf     : float = clampf(_pt / _pdur, 0.0, 1.0)   # 0→1 within phase

			# ── Phase 0: Warning ─────────────────────────────────────────────
			if _ph == 0:
				# Spawn inward-swirling dust particles
				if randi() % 4 == 0:
					var _da : float = randf_range(0.0, TAU)
					var _dr : float = randf_range(28.0, 50.0)
					_rz["particles"].append({
						"x": (_rz["pos"] as Vector2).x + cos(_da) * _dr,
						"y": (_rz["pos"] as Vector2).y + sin(_da) * _dr,
						"vx": -cos(_da) * 18.0, "vy": -sin(_da) * 18.0,
						"t": 0.0, "life": 0.15, "r": randf_range(1.5, 3.0), "col": 0
					})

			# ── Phase 1: Falling slab ────────────────────────────────────────
			elif _ph == 1:
				# Ease-in fall: starts slow, accelerates
				var _fall_ease : float = _pf * _pf
				_rz["slab_y"] = lerpf(-90.0, 0.0, _fall_ease)
				_rz["slab_rot"] = _rz["slab_rot"] * (1.0 - _pf * 0.5)
				# Trailing dirt particles
				if randi() % 3 == 0:
					var _sp : Vector2 = _rz["pos"] as Vector2
					_rz["particles"].append({
						"x": _sp.x + randf_range(-8.0, 8.0),
						"y": _sp.y + _rz["slab_y"] + randf_range(0.0, 10.0),
						"vx": randf_range(-15.0, 15.0), "vy": randf_range(-8.0, 8.0),
						"t": 0.0, "life": 0.2, "r": randf_range(2.0, 4.5), "col": 1
					})

			# ── Phase 2: Impact ──────────────────────────────────────────────
			elif _ph == 2:
				_rz["slab_y"] = 0.0
				if _pt < delta * 2.0:
					# First frame of impact: spawn shockwave + fragments
					_rz["shock_r"] = 0.0
					_rz["shock_a"] = 1.0
					for _fi in range(14):
						var _fa  : float = _fi * TAU / 14.0 + randf_range(-0.15, 0.15)
						var _fspd: float = randf_range(40.0, 110.0)
						_rz["particles"].append({
							"x": (_rz["pos"] as Vector2).x, "y": (_rz["pos"] as Vector2).y,
							"vx": cos(_fa) * _fspd, "vy": sin(_fa) * _fspd - randf_range(10.0, 40.0),
							"t": 0.0, "life": randf_range(0.25, 0.55),
							"r": randf_range(2.5, 6.0), "col": 2
						})
				_rz["shock_r"] += delta * 200.0
				_rz["shock_a"] = clampf(1.0 - _pf * 1.2, 0.0, 1.0)

			# ── Phase 3: Active zone ─────────────────────────────────────────
			elif _ph == 3:
				_rz["shock_a"] = 0.0
				_rz["pulse_t"] += delta
				# Occasional rising dust motes
				if randi() % 18 == 0:
					var _pa : float = randf_range(0.0, TAU)
					var _pr : float = randf_range(0.0, _ROCK_RADIUS - 6.0)
					_rz["particles"].append({
						"x": (_rz["pos"] as Vector2).x + cos(_pa) * _pr,
						"y": (_rz["pos"] as Vector2).y + sin(_pa) * _pr,
						"vx": randf_range(-4.0, 4.0), "vy": randf_range(-22.0, -10.0),
						"t": 0.0, "life": 0.6, "r": randf_range(1.0, 2.5), "col": 0
					})
				# Apply brittle to enemies in zone
				for _rze in get_tree().get_nodes_in_group("enemies"):
					if not is_instance_valid(_rze):
						continue
					if _rz["hit_dict"].has(_rze):
						continue
					if (_rze.position as Vector2).distance_to(_rz["pos"] as Vector2) <= _ROCK_RADIUS:
						_rz["hit_dict"][_rze] = true
						_rze.brittle_bonus    = 20.0
						_rze._brittle_popin_t = 0.15
						_rze.queue_redraw()

			# ── Phase 4: Expire ──────────────────────────────────────────────
			elif _ph == 4:
				if randi() % 6 == 0:
					var _ea : float = randf_range(0.0, TAU)
					var _er : float = randf_range(0.0, _ROCK_RADIUS)
					_rz["particles"].append({
						"x": (_rz["pos"] as Vector2).x + cos(_ea) * _er,
						"y": (_rz["pos"] as Vector2).y + sin(_ea) * _er,
						"vx": randf_range(-10.0, 10.0), "vy": randf_range(-18.0, -6.0),
						"t": 0.0, "life": 0.25, "r": randf_range(1.5, 3.5), "col": 0
					})

			# Advance phase
			if _pt >= _pdur:
				if _ph >= 4:
					_rz_finished.append(_rz)
				else:
					_rz["phase"]   = _ph + 1
					_rz["phase_t"] = 0.0

			# Tick particles
			for i in range(_rz["particles"].size() - 1, -1, -1):
				var _p : Dictionary = _rz["particles"][i]
				_p["t"]  += delta
				_p["x"]  += _p["vx"] * delta
				_p["y"]  += _p["vy"] * delta
				_p["vy"] += 60.0 * delta   # gentle gravity on most particles
				if _p["t"] >= _p["life"]:
					_rz["particles"].remove_at(i)

		for _rzr in _rz_finished:
			_rock_zones.erase(_rzr)
		queue_redraw()
	# Dual Debuff: tick per-enemy debuff cooldowns
	if not _debuff_cd.is_empty():
		var _dc_remove : Array = []
		for _dc_e in _debuff_cd.keys():
			if not is_instance_valid(_dc_e):
				_dc_remove.append(_dc_e)
				continue
			var _dc_entry : Dictionary = _debuff_cd[_dc_e]
			var _dc_expired : Array = []
			for _dc_k in _dc_entry.keys():
				_dc_entry[_dc_k] -= delta
				if _dc_entry[_dc_k] <= 0.0:
					_dc_expired.append(_dc_k)
			for _dk in _dc_expired:
				_dc_entry.erase(_dk)
			if _dc_entry.is_empty():
				_dc_remove.append(_dc_e)
		for _dc_rem in _dc_remove:
			_debuff_cd.erase(_dc_rem)
	if tower_data.get("effect", "") == "world_tree_buff":
		_wt_passive_tick -= delta
		if _wt_passive_tick <= 0.0:
			_wt_passive_tick = 0.5
			const WT_TILE_RANGE : float = 90.0  # 1 tile away including diagonals (tile=60px)
			for _wt_t in get_tree().get_nodes_in_group("towers"):
				if not is_instance_valid(_wt_t) or _wt_t == self:
					continue
				if _wt_t.position.distance_to(position) <= WT_TILE_RANGE:
					_wt_t._wt_buffs[get_instance_id()] = {"dmg": tower_data.get("damage", 10.0), "rate": 0.5, "timer": 0.75}
	# Nature's Wrath aura — same timer/variable infrastructure as World Tree
	if tower_data.get("effect", "") == "natures_wrath_buff":
		_wt_passive_tick -= delta
		if _wt_passive_tick <= 0.0:
			_wt_passive_tick = 0.5
			const NW_TILE_RANGE : float = 90.0  # 1 tile away including diagonals
			for _nw_t in get_tree().get_nodes_in_group("towers"):
				if not is_instance_valid(_nw_t) or _nw_t == self:
					continue
				if _nw_t.position.distance_to(position) <= NW_TILE_RANGE:
					_nw_t._wt_buffs[get_instance_id()] = {"dmg": 15.0, "rate": 0.75, "timer": 0.75}
	if not _nw_coins.is_empty():
		for _nc in _nw_coins:
			_nc["y"] -= delta * 40.0
			_nc["alpha"] = clampf(_nc["alpha"] - delta * 1.5, 0.0, 1.0)
		_nw_coins = _nw_coins.filter(func(_nc): return _nc["alpha"] > 0.0)
		queue_redraw()
	if _chrono_pulse > 0.0:
		_chrono_pulse -= delta
		queue_redraw()
	if not _fc_impacts.is_empty():
		for _fci in range(_fc_impacts.size() - 1, -1, -1):
			_fc_impacts[_fci]["t"] -= delta
			if _fc_impacts[_fci]["t"] <= 0.0:
				_fc_impacts.remove_at(_fci)
		queue_redraw()
	if not _bleed_stacks.is_empty():
		_bleed_tick_timer -= delta
		# Decrement per-enemy timers and collect expired entries
		var _expired : Array = []
		for _be in _bleed_stacks.keys():
			if not is_instance_valid(_be):
				_expired.append(_be)
				continue
			_bleed_stacks[_be]["timer"] -= delta
			if _bleed_stacks[_be]["timer"] <= 0.0:
				_expired.append(_be)
		for _bk in _expired:
			_bleed_stacks.erase(_bk)
		# Tick damage once per second — (tower_damage / 3) × stacks [× Hemorrhage bonus]
		if _bleed_tick_timer <= 0.0:
			_bleed_tick_timer = 1.0
			var _btid : String = tower_data.get("id", "")
			var _hemorrhage : bool = _btid == "rogue" and GameData.turret_has_special("rogue")
			for _be2 in _bleed_stacks.keys():
				if not is_instance_valid(_be2):
					continue
				var _bentry : Dictionary = _bleed_stacks[_be2]
				var _stacks : int = _bentry["stacks"]
				# Hemorrhage: multiply total output by (1 + stacks × 0.12)
				var _hmult : float = (1.0 + _stacks * 0.12) if _hemorrhage else 1.0
				# Custom dmg_per_tick overrides the default formula (e.g. Shadow Blade combo bleed)
				var _base_tick : float = _bentry["dmg_per_tick"] if _bentry.has("dmg_per_tick") \
					else (damage / 3.0) * _stacks * _hmult
				var _bdmg : float = _base_tick \
					* GameData.turret_damage_mult(_btid) \
					* (GameData.relic_boss_dmg_mult() if _be2.is_boss else 1.0) \
					* (0.5 if _be2.is_boss else 1.0)
				_be2.take_damage(_bdmg)
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
		"lock_beam":
			# Beam 1 — prefer existing lock
			var lock_target : Node2D = primary
			if is_instance_valid(_beam_target) and position.distance_to(_beam_target.position) <= attack_range:
				lock_target = _beam_target
			else:
				_beam_lock_time = 0.0
			if lock_target != _beam_target:
				_beam_lock_time = 0.0
			_beam_target     = lock_target
			_beam_timer      = 1.0 / fire_rate
			_beam_tick_timer = 0.0

			# Beam 2 — prefer existing lock, else pick 2nd closest in-range enemy
			var lock_target2 : Node2D = null
			if is_instance_valid(_beam_target2) and _beam_target2 != _beam_target \
					and position.distance_to(_beam_target2.position) <= attack_range:
				lock_target2 = _beam_target2
			else:
				for _e in in_range:
					if _e != lock_target:
						lock_target2 = _e
						break
				_beam_lock_time2 = 0.0
			if lock_target2 != null:
				if lock_target2 != _beam_target2:
					_beam_lock_time2 = 0.0
				_beam_target2     = lock_target2
				_beam_timer2      = 1.0 / fire_rate
				_beam_tick_timer2 = 0.0
			_shoot_anim = 0.35
		"focused_shot":
			# +50% damage when hitting the same target consecutively
			var bonus_dmg := damage * 1.5 if (is_instance_valid(_last_target) and _last_target == primary) else damage
			_last_target = primary
			_fire(primary, bonus_dmg)
		"dual_shot":
			# Fire at up to 2 separate enemies
			for i in range(min(2, in_range.size())):
				_fire(in_range[i], damage)
		"slow_zone":
			_hit_counter += 1
			_fire(primary, damage)
			if _hit_counter % 4 == 0:
				var _zone_radius := 45.0
				var _has_active_zone := false
				for z in get_tree().get_nodes_in_group("ice_zones"):
					if is_instance_valid(z) and z._landed and primary.position.distance_to(z.position) < _zone_radius * 0.8:
						_has_active_zone = true
						break
				if not _has_active_zone:
					_fire(primary, 0.0)
		"pierce":
			for i in range(min(3, in_range.size())):
				_fire(in_range[i], damage)
		"aoe", "poison_cloud":
			for enemy in in_range:
				_fire(enemy, damage)
		"infernal_serpent_summon":
			# Single-target fire attack. 10% chance to summon a battlefield serpent.
			_fire(primary, damage)
			if randf() < 0.10:
				serpent_summon.emit(100.0)
		"aoe_burst":
			# AoE capped at 5 enemies
			for i in range(min(5, in_range.size())):
				_fire(in_range[i], damage)
		"melee_cleave":
			# Direct melee; every 3rd hit also strikes all in range
			_hit_counter += 1
			_fire(primary, damage)
			if _hit_counter >= 3:
				_hit_counter = 0
				if tower_type == 26:
					_spear_spin_timer = 1.0   # spin only on special cleave hit
				for enemy in in_range:
					if enemy == primary:
						continue
					_fire(enemy, damage)
		"bleed_aoe":
			# Hits all enemies in range; applies a bleed stack to each
			# Hemorrhage (rogue special) raises cap from 3 → 6
			_alt_hand = !_alt_hand
			var _bleed_cap : int = 6 if (tower_data.get("id","") == "rogue" \
				and GameData.turret_has_special("rogue")) else 3
			for enemy in in_range:
				_fire(enemy, damage)
				var _bentry : Dictionary = _bleed_stacks.get(enemy, {"stacks": 0, "timer": 0.0})
				_bentry["stacks"] = min(_bentry["stacks"] + 1, _bleed_cap)
				_bentry["timer"]  = 3.0   # refresh duration
				_bleed_stacks[enemy] = _bentry
				enemy.apply_bleed()   # visual trail only
		"poison_debuff":
			# Prioritise un-poisoned enemies; apply poison on hit
			var sorted := in_range.duplicate()
			sorted.sort_custom(func(a, b): return int(a.is_poisoned) < int(b.is_poisoned))
			var target_enemy : Node2D = sorted[0]
			_fire(target_enemy, damage)
			target_enemy.apply_poison(5.0)
		"execute_shot":
			# Scales up to 2× damage based on enemy's current HP fraction
			var hp_frac := clampf(primary.hp / primary.max_hp, 0.0, 1.0)
			_fire(primary, damage * (1.0 + hp_frac))
		"hp_strike":
			# Base damage + 1% of current HP on non-boss enemies
			var hp_bonus : float = primary.hp * 0.01 if not primary.is_boss else 0.0
			_fire(primary, damage + hp_bonus)
		"arcane_charge":
			# Persistent charge — every 20th hit releases a blue ray at double damage
			_arcane_charge += 1
			_fire(primary, damage)
			if _arcane_charge % 15 == 0:
				_arcane_laser_targets = in_range.duplicate()
				_arcane_laser_timer   = 2.0   # 1s full + 1s fade
				_arcane_laser_alpha   = 1.0
				for enemy in in_range:
					_fire(enemy, damage * 2.0)
		"knight_slam":
			# Direct melee; every 3rd hit is AoE + pushback (non-bosses, up to 5)
			_hit_counter += 1
			_fire(primary, damage)
			if _hit_counter >= 3:
				_hit_counter = 0
				for i in range(min(5, in_range.size())):
					var enemy : Node2D = in_range[i]
					if enemy == primary:
						continue
					_fire(enemy, damage)
				# Pushback non-boss enemies in range (up to 2)
				var pushed := 0
				for enemy in in_range:
					if pushed >= 2:
						break
					if not enemy.is_boss:
						enemy.pushback()
						pushed += 1
		"taunt_slam":
			# Taunt Tank: hits up to 5 enemies; every 5th hit taunts all in range (stun 2s + 20% dmg taken)
			_hit_counter += 1
			var taunt_hit : int = min(5, in_range.size())
			for i in range(taunt_hit):
				_fire(in_range[i], damage)
			if _hit_counter >= 5:
				_hit_counter = 0
				for enemy in in_range:
					enemy.apply_taunt(2.0)
		"hercules_cleave":
			# Hercules: strikes primary + 1 additional enemy; damage grows +5 per wave
			var herc_dmg := damage + _hercules_wave_bonus
			_fire(primary, herc_dmg)
			var herc_hit := 0
			for enemy in in_range:
				if enemy == primary:
					continue
				_fire(enemy, herc_dmg)
				herc_hit += 1
				if herc_hit >= 1:
					break
		"ranger_fire_aura":
			# Ranger: fires at primary; every 5th hit grants towers 1 tile away +10% fire rate for 3s
			_fire(primary, damage)
			_hit_counter += 1
			if _hit_counter >= 5:
				_hit_counter = 0
				const RANGER_TILE_RANGE : float = 90.0
				for _rt in get_tree().get_nodes_in_group("towers"):
					if not is_instance_valid(_rt) or _rt == self:
						continue
					if _rt.position.distance_to(position) <= RANGER_TILE_RANGE:
						_rt._ranger_rate_bonus = 0.1
						_rt._ranger_rate_timer = 3.0
		"rock_drop":
			# Stone Guardian: fires at primary; every 3rd hit drops a brittle rock zone for 2s
			_fire(primary, damage)
			_hit_counter += 1
			if _hit_counter >= 3:
				_hit_counter = 0
				_rock_zones.append({
					"pos":       primary.position,
					"hit_dict":  {},
					"phase":     0,
					"phase_t":   0.0,
					"particles": [],
					"slab_y":    -90.0,
					"slab_rot":  randf_range(-0.3, 0.3),
					"shock_r":   0.0,
					"shock_a":   0.0,
					"pulse_t":   0.0,
				})
				queue_redraw()
		"dual_debuff":
			# Arcane Scholar: fires 2 projectiles per attack; every other attack both targets get a random debuff (1s)
			_hit_counter += 1
			_fire(primary, damage)
			var _dd_second : Node2D = null
			for _dd_e in in_range:
				if _dd_e != primary:
					_dd_second = _dd_e
					break
			if is_instance_valid(_dd_second):
				_fire(_dd_second, damage)
			if _hit_counter >= 2:
				_hit_counter = 0
				_apply_dual_debuff(primary)
				if is_instance_valid(_dd_second):
					_apply_dual_debuff(_dd_second)
		"shadow_blade_combo":
			# Shadow Blade: 3-hit combo.
			# Hits 1 & 2: one strike, alternate hands. Hit 3: both hands strike at once for 2× damage
			# + applies a bleed (2× damage/s, max 1 stack, 3s).
			_hit_counter += 1
			if _hit_counter >= 3:
				_hit_counter = 0
				_dual_swing  = true          # both blades swing simultaneously
				_fire(primary, damage * 2.0)
				# Apply bleed — max 1 stack, 2× damage per tick, 3s duration
				var _sb_be : Dictionary = _bleed_stacks.get(primary, {"stacks": 0, "timer": 0.0})
				_sb_be["stacks"]       = 1
				_sb_be["timer"]        = max(_sb_be.get("timer", 0.0), 3.0)
				_sb_be["dmg_per_tick"] = damage * 2.0
				_bleed_stacks[primary] = _sb_be
				primary.apply_bleed()
			else:
				_alt_hand = not _alt_hand    # alternate which blade swings on hits 1 & 2
				_fire(primary, damage)
		"frost_shatter":
			# Frost Herald: fires 2 projectiles; all hits apply 5% slow for 2s.
			# Attack speed bonus = 3% per currently-slowed enemy on map (max 10 enemies = +30%).
			# Bonus resets after 3s of not attacking.
			_frost_idle_timer = 0.0   # reset falloff timer on every attack
			var _fs_targets : Array = [primary]
			for _fs_e in in_range:
				if _fs_e != primary:
					_fs_targets.append(_fs_e)
					break
			for _fs_t in _fs_targets:
				_fire(_fs_t, damage)
				_fs_t.apply_frost_slow(2.0)
			# Count slowed enemies on the map and recalculate bonus
			var _slowed_count : int = 0
			for _fm_e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(_fm_e) and not _fm_e._dead and _fm_e.is_slowed():
					_slowed_count += 1
					if _slowed_count >= 10:
						break
			_frost_speed_bonus = _slowed_count * 0.03
		"shadow_weaver_phase":
			if _sw_light_timer > 0.0:
				# ── Light phase: beam tick handled in _process; skip normal fire ──
				pass
			else:
				# ── Shadow phase: single-target hit, count to 10 ──
				_fire(primary, damage)
				_sw_stacks += 1
				if _sw_stacks >= 10:
					_sw_stacks     = 0
					_sw_light_timer = 5.0
					_sw_beam_tick   = 0.0   # fire first pulse immediately
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
		"tempest_strike":
			# Normal shot every hit. Every 10th hit also deals 5% of target's max HP as bonus damage.
			_hit_counter += 1
			_fire(primary, damage)
			if _hit_counter >= 10:
				_hit_counter = 0
				var bonus_dmg : float = primary.max_hp * 0.05
				primary.take_damage(bonus_dmg)
				_lightning_bolts.append({
					"pts":      _gen_lightning(Vector2.ZERO, primary.position - position, 4),
					"life":     0.40, "max_life": 0.40, "delay": 0.0, "thick": true
				})
				_chrono_pulse = 0.25
		"axe_warrior":
			# AoE melee — hits up to 5 enemies; applies bleed + poison stacks to each
			_shoot_anim = 0.35
			var hit_count := 0
			for enemy in in_range:
				if hit_count >= 2:
					break
				_fire(enemy, damage)
				# Bleed: cap at 1 stack, always refresh 3s duration
				var _axe_bentry : Dictionary = _bleed_stacks.get(enemy, {"stacks": 0, "timer": 0.0})
				_axe_bentry["stacks"] = 1
				_axe_bentry["timer"]  = 3.0
				_bleed_stacks[enemy] = _axe_bentry
				enemy.apply_bleed()   # visual trail only
				# Poison: refresh duration if already poisoned, apply 1 stack if not
				if enemy.is_poisoned:
					enemy.poison_timer = max(enemy.poison_timer, 5.0)
				else:
					enemy.apply_poison(5.0)
				# Spawn slash visual at enemy position
				_spawn_slash(enemy.position)
				hit_count += 1
		"blade_spin":
			# Dual shot — fire at up to 2 enemies simultaneously
			for i in range(min(2, in_range.size())):
				_fire(in_range[i], damage)
			# 10% chance per volley to proc spinning blades (3s duration)
			if randf() < 0.10:
				_blade_timer = 3.0
				_blade_hit_set.clear()
		"lightning":
			# Tesla Tower: hits primary + chains to 3 more enemies globally (4 total)
			var _lt_tid : String = tower_data.get("id", "")
			var _lt_pdmg := (damage + GameData.buff_damage_flat + _wt_dmg_bonus) \
				* GameData.turret_damage_mult(_lt_tid) \
				* (GameData.relic_boss_dmg_mult() if primary.is_boss else 1.0)
			primary.take_damage(_lt_pdmg)
			_lightning_bolts.append({
				"pts":      _gen_lightning(Vector2.ZERO, primary.position - position, 3),
				"life":     0.30, "max_life": 0.30, "delay": 0.0, "thick": true
			})
			_shoot_anim = 0.30
			# Chain to 3 nearest enemies globally
			var _lt_all : Array = get_tree().get_nodes_in_group("enemies")
			_lt_all = _lt_all.filter(func(e): return is_instance_valid(e) and not e._dead and e != primary)
			_lt_all.sort_custom(func(a, b): return a.position.distance_to(primary.position) < b.position.distance_to(primary.position))
			var _lt_chained := 0
			var _lt_prev : Node2D = primary
			for _lt_ce in _lt_all:
				var _lt_cdmg := (damage + GameData.buff_damage_flat + _wt_dmg_bonus) \
					* GameData.turret_damage_mult(_lt_tid) \
					* (GameData.relic_boss_dmg_mult() if _lt_ce.is_boss else 1.0)
				_lt_ce.take_damage(_lt_cdmg)
				_lightning_bolts.append({
					"pts":      _gen_lightning(_lt_prev.position - position, _lt_ce.position - position, 2),
					"life":     0.22, "max_life": 0.22, "delay": 0.10 * (_lt_chained + 1), "thick": false
				})
				_lt_prev = _lt_ce
				_lt_chained += 1
				if _lt_chained >= 3:
					break

		"storm_chain":
			# Storm Lord: primary at full damage (instant, no bullet), nearest 4 globally at 150%
			var _sc_tid : String = tower_data.get("id", "")
			var _sc_pdmg := (damage + GameData.buff_damage_flat + _wt_dmg_bonus) \
				* GameData.turret_damage_mult(_sc_tid) \
				* (GameData.relic_boss_dmg_mult() if primary.is_boss else 1.0)
			primary.take_damage(_sc_pdmg)
			_lightning_bolts.append({
				"pts":      _gen_lightning(Vector2.ZERO, primary.position - position, 3),
				"life":     0.30, "max_life": 0.30, "delay": 0.0, "thick": true
			})
			_shoot_anim = 0.35
			# Chain to 4 nearest enemies globally at 150% damage
			var _sc_all : Array = get_tree().get_nodes_in_group("enemies")
			_sc_all = _sc_all.filter(func(e): return is_instance_valid(e) and not e._dead and e != primary)
			_sc_all.sort_custom(func(a, b): return a.position.distance_to(primary.position) < b.position.distance_to(primary.position))
			var _sc_chained := 0
			for _ce in _sc_all:
				var _sc_cdmg := (damage * 1.5 + GameData.buff_damage_flat + _wt_dmg_bonus) \
					* GameData.turret_damage_mult(_sc_tid) \
					* (GameData.relic_boss_dmg_mult() if _ce.is_boss else 1.0)
				_ce.take_damage(_sc_cdmg)
				_lightning_bolts.append({
					"pts":      _gen_lightning(primary.position - position, _ce.position - position, 2),
					"life":     0.22, "max_life": 0.22, "delay": 0.12, "thick": false
				})
				_sc_chained += 1
				if _sc_chained >= 4:
					break

		"chrono_aoe":
			# Chrono Mage: hits all enemies in range, applies 15% slow for 2s (stacks with other slows)
			_chrono_pulse = 0.45
			for _ce2 in in_range:
				_fire(_ce2, damage)
				_ce2.apply_chrono_slow(2.0)
		"world_tree_buff":
			# World Tree: passive buff handled in _process; still fires at primary enemy
			_fire(primary, damage)

		"natures_wrath_buff":
			# Nature's Wrath: single-target shot; passive aura handled in _process.
			# 5% chance per hit to generate 2 gold (signal caught by Main.gd).
			_fire(primary, damage)
			if randf() < 0.05:
				gold_proc.emit(2.0)
				_nw_coins.append({"y": 0.0, "alpha": 1.0})

		"arcane_overload":
			# Arcane Overlord: normal fireball attack every shot.
			# Every 5th attack triggers Arcane Overload — instant lasers at ALL enemies in range,
			# guaranteed minimum of 5 lasers (extras distributed round-robin to existing targets).
			_fire(primary, damage)
			_arcane_charge += 1
			if _arcane_charge % 5 == 0:
				const AO_MIN_LASERS : int   = 5
				const AO_LASER_DMG  : float = 45.0
				# Build target list: one entry per enemy in range, then pad to min 5
				var _ao_list : Array = in_range.duplicate()
				var _ao_pad  : int   = AO_MIN_LASERS - _ao_list.size()
				if _ao_pad > 0:
					for _ao_k in range(_ao_pad):
						_ao_list.append(in_range[_ao_k % in_range.size()])
				# Store for visual rendering (includes duplicates for multi-hit)
				_arcane_laser_targets = _ao_list.duplicate()
				_arcane_laser_timer   = 2.0
				_arcane_laser_alpha   = 1.0
				# Instant damage — one call per list entry (duplicates each deal full damage)
				var _ao_tid : String = tower_data.get("id", "")
				for _ao_e in _ao_list:
					if is_instance_valid(_ao_e):
						var _ao_dmg : float = (AO_LASER_DMG + GameData.buff_damage_flat + _wt_dmg_bonus) \
							* GameData.turret_damage_mult(_ao_tid) \
							* (GameData.relic_boss_dmg_mult() if _ao_e.is_boss else 1.0)
						_ao_e.take_damage(_ao_dmg)

		"frost_cannon_tri":
			# Frost Cannon: hits up to 3 separate targets.
			# Boss targets take +50% damage and receive a 10% slow (refreshes on repeat hits).
			const FC_MAX_TARGETS   : int   = 3
			const FC_BOSS_MULT     : float = 1.5
			const FC_BOSS_SLOW_DUR : float = 3.0
			const FC_NORMAL_DUR    : float = 0.30   # impact flash duration (normal hit)
			const FC_BOSS_DUR      : float = 0.50   # impact flash duration (boss hit)
			for _fc_i in range(min(FC_MAX_TARGETS, in_range.size())):
				var _fc_t : Node2D = in_range[_fc_i]
				var _fc_dmg : float = damage * FC_BOSS_MULT if _fc_t.is_boss else damage
				_fire(_fc_t, _fc_dmg)
				if _fc_t.is_boss:
					_fc_t.apply_mild_slow(FC_BOSS_SLOW_DUR)
				_fc_impacts.append({
					"pos":   _fc_t.position,
					"t":     FC_BOSS_DUR if _fc_t.is_boss else FC_NORMAL_DUR,
					"max_t": FC_BOSS_DUR if _fc_t.is_boss else FC_NORMAL_DUR,
					"boss":  _fc_t.is_boss,
				})

	var tid : String = tower_data.get("id", "")
	var effective_rate : float = tower_data.get("fire_rate", fire_rate) * (GameData.tower_total_fire_rate_mult(tid) + GameData.buff_fire_rate_pct + _wt_rate_bonus + _ranger_rate_bonus + _frost_speed_bonus)
	_cooldown = 1.0 / effective_rate


func _fire(target: Node2D, dmg: float) -> void:
	var tid       : String = tower_data.get("id", "")
	var final_dmg := (dmg * GameData.tower_total_damage_mult(tid) + GameData.buff_damage_flat + _wt_dmg_bonus) * (GameData.relic_boss_dmg_mult() if target.is_boss else 1.0)

	# Melee towers — instant direct damage, no projectile
	if tower_type in [26, 27, 28, 29, 30, 31, 32, 33]:
		if dmg > 0.0:
			target.take_damage(final_dmg)
		_shoot_anim = 0.35
		return

	# Infernal Core — persistent beam, damage dealt via ticks in _process
	if tower_type == 10:
		if target != _beam_target:
			_beam_lock_time = 0.0   # reset ramp when switching targets
		_beam_target     = target
		_beam_timer      = 1.0 / fire_rate
		_beam_tick_timer = 0.0
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
		6:  # Frost Spire — ice zone on 5th shot, normal bullet otherwise
			if dmg == 0.0:
				b.setup(target, 0.0)
				b.bullet_type = "ice_zone"
				b._is_zone    = true
				b._target_pos = target.position
				b._speed      = 520.0
			else:
				b.setup(target, final_dmg)
				b.bullet_color = tower_color
				b.bullet_style = "orb"
		_:  # All other tower types — styled homing bullet
			b.setup(target, final_dmg)
			b.bullet_color = tower_color
			# Assign bullet style based on tower type
			const _BOLT_TYPES  : Array = [0, 1, 11, 18, 23]   # archer, crossbow, ballista, frost_cannon, shadow_weaver
			const _SPARK_TYPES : Array = [9, 21]                 # tesla, tempest_warden
			const _FIRE_TYPES  : Array = [5, 13, 19, 22]        # flame, sun_dragon, arcane_overlord, infernal_serpent
			if tower_type in _BOLT_TYPES:
				b.bullet_style = "bolt"
			elif tower_type in _SPARK_TYPES:
				b.bullet_style = "spark"
			elif tower_type in _FIRE_TYPES:
				b.bullet_style = "fireball"
			else:
				b.bullet_style = "orb"

	_shoot_anim = 0.35
	# If projectiles are disabled, deal damage instantly (skip visual bullet).
	# Ice-zone bullets must still spawn — they apply a persistent slow zone.
	if not GameData.show_projectiles and not b._is_zone:
		if is_instance_valid(b._target):
			b._target.take_damage(b._damage)
		b.queue_free()
		return
	get_parent().add_child(b)


func _spawn_slash(world_pos: Vector2) -> void:
	var fx : Node2D = _SLASH_SCRIPT.new()
	get_parent().add_child(fx)
	fx.init(world_pos)


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
	var _tile_sc := 0.90 if tower_type in [0, 1, 2, 3, 4, 13, 16, 26, 27, 28, 29, 30, 50, 51, 52, 53] else 1.0
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
		30: _draw_blade_assassin(bob, s)
		31: _draw_axe_warrior(bob, s)
		32: _draw_hercules(bob, s)
		33: _draw_taunt_tank(bob, s)
		13: _draw_sun_dragon(bob, s)
		14: _draw_storm_lord(bob, s)
		15: _draw_chrono_mage(bob, s)
		16: _draw_world_tree(bob, s)
		17: _draw_venom_drake(bob, s)
		18: _draw_frost_cannon(bob, s)
		19: _draw_arcane_overlord(bob, s)
		20: _draw_dragon_lich(bob, s)
		21: _draw_tempest_warden(bob, s)
		22: _draw_infernal_serpent(bob, s)
		23: _draw_shadow_weaver(bob, s)
		24: _draw_natures_wrath(bob, s)
		25: _draw_void_titan(bob, s)
		26: _draw_spearman(bob, s)
		27: _draw_rogue(bob, s)
		28: _draw_elite_knight(bob, s)
		29: _draw_iron_guard(bob, s)
		50: _draw_hero_paladin(bob, s)
		51: _draw_hero_dagger(bob, s)
		52: _draw_hero_warlock(bob, s)
		53: _draw_hero_arcane_scholar(bob, s)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Nature's Wrath gold proc — coin floats upward
	for _nc in _nw_coins:
		var _nc_pos := Vector2(0.0, -20.0 + _nc["y"])
		var _nc_a   : float = _nc["alpha"]
		draw_circle(_nc_pos, 12.0, Color(1.00, 0.82, 0.08, _nc_a))
		draw_circle(_nc_pos + Vector2(-3.0, -3.0), 5.0, Color(1.00, 1.00, 0.65, _nc_a * 0.50))
		draw_arc(_nc_pos, 12.0, 0.0, TAU, 24, Color(0.75, 0.50, 0.00, _nc_a), 2.0)
		# Dollar sign centered on coin
		var _nc_sz  := _NW_COIN_FONT.get_string_size("$", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		var _nc_dp  := _nc_pos + Vector2(-_nc_sz.x * 0.5, _nc_sz.y * 0.35)
		draw_string(_NW_COIN_FONT, _nc_dp, "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.55, 0.30, 0.00, _nc_a))

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

	# Lightning bolts (Tesla / Tempest Warden)
	for bolt in _lightning_bolts:
		if bolt["delay"] > 0.0:
			continue
		var t : float = bolt["life"] / bolt["max_life"]   # 1.0 → 0.0
		var alpha : float = t * t                          # fast fade
		var w_glow  : float = 7.0 if bolt["thick"] else 4.0
		var w_core  : float = 2.5 if bolt["thick"] else 1.5
		draw_polyline(bolt["pts"], Color(0.35, 0.75, 1.0, alpha * 0.45), w_glow)
		draw_polyline(bolt["pts"], Color(0.80, 0.95, 1.0, alpha * 0.75), w_core + 1.0)
		draw_polyline(bolt["pts"], Color(1.00, 1.00, 1.00, alpha),        w_core)

	# Frost Cannon — icy impact flashes at hit positions
	for _fci_d in _fc_impacts:
		var _fci_off  : Vector2 = (_fci_d["pos"] as Vector2) - position
		var _fci_prog : float   = clampf(_fci_d["t"] / _fci_d["max_t"], 0.0, 1.0)  # 1→0 as it fades
		var _fci_r    : float   = (28.0 if _fci_d["boss"] else 16.0) * (1.0 - _fci_prog * 0.5)
		var _fci_a    : float   = _fci_prog * _fci_prog
		# Outer glow
		draw_circle(_fci_off, _fci_r * 1.4, Color(0.55, 0.90, 1.00, 0.18 * _fci_a))
		# Frost ring
		draw_arc(_fci_off, _fci_r, 0.0, TAU, 24, Color(0.70, 0.95, 1.00, 0.70 * _fci_a), 1.8)
		if _fci_d["boss"]:
			# Extra inner ring for boss hits
			draw_arc(_fci_off, _fci_r * 0.55, 0.0, TAU, 16, Color(0.90, 1.00, 1.00, 0.55 * _fci_a), 1.2)
			# Four ice spike lines
			for _sp in range(4):
				var _sa : float = _sp * TAU / 4.0
				draw_line(_fci_off + Vector2(cos(_sa), sin(_sa)) * (_fci_r * 0.3),
						  _fci_off + Vector2(cos(_sa), sin(_sa)) * (_fci_r * 1.0),
						  Color(0.85, 0.97, 1.00, 0.65 * _fci_a), 1.4)

	# Blade Assassin — two orbit blades (drawn unscaled after tower body)
	if tower_type == 30 and _blade_timer > 0.0:
		const _ORBIT_R : float = 65.0
		const _BLADE_L : float = 22.0   # tip distance from blade center (larger)
		const _BLADE_W : float = 6.0    # half-width at blade center (larger)
		var _fade : float = clampf(_blade_timer / 0.5, 0.0, 1.0)  # fade out last 0.5s
		for _blade_i in range(2):
			var _orbit_a := _blade_angle + _blade_i * PI
			var _bc := Vector2(cos(_orbit_a), sin(_orbit_a)) * _ORBIT_R
			var _spin := _blade_angle * 4.0 + _blade_i * PI * 0.5  # spins on own axis
			# Draw 4 sharp bladed wings (2 crossing blades = 4 tips)
			for _wing in range(4):
				var _wa  := _spin + _wing * PI * 0.5
				var _tip := _bc + Vector2(cos(_wa), sin(_wa)) * _BLADE_L
				var _perp := Vector2(cos(_wa + PI * 0.5), sin(_wa + PI * 0.5))
				var _b1  := _bc + _perp * _BLADE_W
				var _b2  := _bc - _perp * _BLADE_W
				draw_colored_polygon(PackedVector2Array([_tip, _b1, _b2]),
					Color(0.88, 0.92, 1.00, 0.95 * _fade))
				# Sharp edge highlight
				draw_line(_b1, _tip, Color(1.0, 1.0, 1.0, 0.55 * _fade), 0.8)
			# Center hub
			draw_circle(_bc, 4.0, Color(0.50, 0.60, 0.85, 0.90 * _fade))
			draw_circle(_bc, 2.0, Color(1.00, 1.00, 1.00, 0.95 * _fade))
			# Soft glow aura
			draw_circle(_bc, _BLADE_L * 0.65, Color(0.50, 0.65, 1.00, 0.12 * _fade))

	# Selection highlight — range ring only
	if selected:
		draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 64, Color(1.0, 0.88, 0.25, 0.55), 1.5)

	# Landing shockwave
	if _impact_alpha > 0.0:
		draw_arc(Vector2.ZERO, _impact_radius, 0.0, TAU, 48,
			Color(tower_color.r, tower_color.g, tower_color.b, _impact_alpha), 4.0)

	# Stone Guardian — brittle rock zones (drawn in world-offset local space)
	for _rz_d in _rock_zones:
		var _off   : Vector2 = (_rz_d["pos"] as Vector2) - position
		var _ph    : int     = _rz_d["phase"]
		var _pt    : float   = _rz_d["phase_t"]
		var _pdurs : Array   = [0.15, 0.25, 0.15, 2.0, 0.2]
		var _pf    : float   = clampf(_pt / _pdurs[_ph], 0.0, 1.0)

		# ── Particle colours: 0=dust/tan, 1=dark-dirt, 2=stone-gray ──────────
		var _pcols : Array = [
			Color(0.72, 0.58, 0.35),
			Color(0.38, 0.26, 0.14),
			Color(0.58, 0.52, 0.46),
		]

		# ── Phase 0: Warning marker ───────────────────────────────────────────
		if _ph == 0:
			var _warn_a : float = _pf * 0.7
			draw_circle(_off, 38.0, Color(0.45, 0.30, 0.15, _warn_a * 0.35))
			draw_arc(_off, 38.0, 0.0, TAU, 32, Color(0.65, 0.45, 0.22, _warn_a), 1.5)
			# Small crosshair cracks
			for _wi in range(4):
				var _wa : float = _wi * TAU / 4.0
				draw_line(_off, _off + Vector2(cos(_wa), sin(_wa)) * 14.0,
						  Color(0.55, 0.38, 0.18, _warn_a), 1.2)

		# ── Phase 1: Falling slab ─────────────────────────────────────────────
		elif _ph == 1:
			# Warning persists underneath
			draw_circle(_off, 38.0, Color(0.45, 0.30, 0.15, 0.3))
			draw_arc(_off, 38.0, 0.0, TAU, 32, Color(0.65, 0.45, 0.22, 0.55), 1.5)
			# Slab — jagged rock shape drawn as a polygon
			var _sy     : float  = _rz_d["slab_y"]
			var _slab_c : Vector2 = _off + Vector2(0.0, _sy)
			var _srot   : float  = _rz_d["slab_rot"]
			# 8-point jagged polygon
			var _spts   : PackedVector2Array = PackedVector2Array()
			var _sradii : Array = [18.0, 24.0, 16.0, 22.0, 20.0, 14.0, 22.0, 17.0]
			for _si in range(8):
				var _sa : float  = _si * TAU / 8.0 + _srot
				var _sr : float  = _sradii[_si]
				_spts.append(_slab_c + Vector2(cos(_sa), sin(_sa)) * _sr)
			draw_colored_polygon(_spts, Color(0.52, 0.38, 0.22))
			draw_polyline(_spts + PackedVector2Array([_spts[0]]),
						  Color(0.28, 0.18, 0.10), 1.5)
			# Interior crack lines on slab
			for _sci in range(3):
				var _sca : float = _sci * TAU / 3.0 + _srot + 0.5
				draw_line(_slab_c, _slab_c + Vector2(cos(_sca), sin(_sca)) * 12.0,
						  Color(0.20, 0.12, 0.06, 0.8), 1.2)

		# ── Phase 2: Impact ───────────────────────────────────────────────────
		elif _ph == 2:
			# Shockwave ring
			if _rz_d["shock_a"] > 0.0:
				draw_arc(_off, _rz_d["shock_r"], 0.0, TAU, 48,
						 Color(0.60, 0.44, 0.22, _rz_d["shock_a"]), 3.0)
			# Brief crater
			var _cr_a : float = (1.0 - _pf) * 0.6
			draw_circle(_off, 22.0, Color(0.28, 0.18, 0.10, _cr_a))
			draw_arc(_off, 22.0, 0.0, TAU, 24,
					 Color(0.50, 0.36, 0.18, _cr_a * 1.5), 2.0)

		# ── Phase 3: Active zone ──────────────────────────────────────────────
		elif _ph == 3:
			var _active_fade : float = clampf(_pt / 2.0, 0.0, 1.0)
			# Pulse: soft brightness ripple every 0.5s
			var _pulse : float = 0.5 + 0.5 * sin(_rz_d["pulse_t"] * TAU / 0.5)
			var _zone_a : float = 0.22 + 0.08 * _pulse
			draw_circle(_off, 38.0, Color(0.35, 0.24, 0.13, _zone_a))
			draw_arc(_off, 38.0, 0.0, TAU, 32,
					 Color(0.68, 0.48, 0.24, 0.55 + 0.15 * _pulse), 2.0)
			# Radial crack lines — 6 arms
			for _ci in range(6):
				var _ca  : float = _ci * TAU / 6.0 + 0.3
				var _clen: float = 14.0 + 10.0 * (1.0 if _ci % 2 == 0 else 0.6)
				var _c1  : Vector2 = _off + Vector2(cos(_ca), sin(_ca)) * 6.0
				var _c2  : Vector2 = _off + Vector2(cos(_ca), sin(_ca)) * _clen
				draw_line(_c1, _c2, Color(0.58, 0.40, 0.20, 0.65 + 0.20 * _pulse), 1.3)
				# Branch crack
				var _ba : float = _ca + 0.5
				draw_line(_c2, _c2 + Vector2(cos(_ba), sin(_ba)) * 6.0,
						  Color(0.48, 0.32, 0.16, 0.45), 1.0)
			# Rock chunks around perimeter
			for _ri in range(5):
				var _ra : float   = _ri * TAU / 5.0 + 0.4
				var _rp : Vector2 = _off + Vector2(cos(_ra), sin(_ra)) * 28.0
				draw_circle(_rp, 4.5, Color(0.48, 0.36, 0.22, 0.80))
				draw_arc(_rp, 4.5, 0.0, TAU, 12, Color(0.28, 0.18, 0.10, 0.60), 1.0)

		# ── Phase 4: Expire ───────────────────────────────────────────────────
		elif _ph == 4:
			var _exp_a : float = 1.0 - _pf
			draw_circle(_off, 38.0 * (0.8 + 0.2 * _exp_a), Color(0.35, 0.24, 0.13, _exp_a * 0.22))
			draw_arc(_off, 38.0, 0.0, TAU, 32,
					 Color(0.68, 0.48, 0.24, _exp_a * 0.55), 2.0)
			for _ci in range(6):
				var _ca  : float = _ci * TAU / 6.0 + 0.3
				var _clen: float = (14.0 + 10.0 * (1.0 if _ci % 2 == 0 else 0.6)) * _exp_a
				draw_line(_off, _off + Vector2(cos(_ca), sin(_ca)) * _clen,
						  Color(0.58, 0.40, 0.20, _exp_a * 0.65), 1.3)

		# ── Particles (all phases) ────────────────────────────────────────────
		for _p in _rz_d["particles"]:
			var _palpha : float = clampf(1.0 - _p["t"] / _p["life"], 0.0, 1.0)
			var _pcol   : Color = _pcols[_p["col"]]
			draw_circle(Vector2(_p["x"], _p["y"]) - position,
						_p["r"], Color(_pcol.r, _pcol.g, _pcol.b, _palpha * 0.85))

	# Held highlight ring
	if is_held:
		draw_arc(Vector2.ZERO, 24, 0.0, TAU, 32, Color(1.0, 0.95, 0.4, 0.75), 2.5)


# ── Dual Debuff helper ───────────────────────────────────────────────────────
# Picks a random debuff (bleed / slow / poison) the target doesn't have on 5s cooldown.
func _apply_dual_debuff(target: Node2D) -> void:
	var _all_debuffs : Array = ["bleed", "slow", "poison"]
	var _cd_entry    : Dictionary = _debuff_cd.get(target, {})
	var _available   : Array = []
	for _d in _all_debuffs:
		if _cd_entry.get(_d, 0.0) <= 0.0:
			_available.append(_d)
	if _available.is_empty():
		return
	_available.shuffle()
	var _chosen : String = _available[0]
	match _chosen:
		"bleed":
			var _be : Dictionary = _bleed_stacks.get(target, {"stacks": 0, "timer": 0.0})
			_be["stacks"] = min(_be.get("stacks", 0) + 1, 3)
			_be["timer"]  = max(_be.get("timer", 0.0), 1.0)
			_bleed_stacks[target] = _be
			target.apply_bleed()
		"slow":
			target.apply_mild_slow(1.0)
		"poison":
			target.apply_poison(1.0)
	if not _debuff_cd.has(target):
		_debuff_cd[target] = {}
	_debuff_cd[target][_chosen] = 5.0


# ── Lightning bolt geometry ───────────────────────────────────────────────────
# Iterative midpoint displacement — each subdivision doubles the point count.
func _gen_lightning(a: Vector2, b: Vector2, subdivs: int) -> PackedVector2Array:
	var pts := PackedVector2Array([a, b])
	for _s in range(subdivs):
		var next := PackedVector2Array()
		for j in range(pts.size() - 1):
			var p1 := pts[j]
			var p2 := pts[j + 1]
			next.append(p1)
			var mid := (p1 + p2) * 0.5
			var perp := (p2 - p1).rotated(PI * 0.5).normalized()
			mid += perp * randf_range(-0.32, 0.32) * p1.distance_to(p2)
			next.append(mid)
		next.append(pts[pts.size() - 1])
		pts = next
	return pts


# ── Archer (type 0) ───────────────────────────────────────────────────────────
# Green-cloaked forest ranger with a longbow.

func _draw_archer(bob: float, shooting: bool) -> void:
	var b      := bob
	var skin   := Color(0.94, 0.78, 0.60)
	var jacket := Color(0.18, 0.48, 0.14)
	var jack_d := Color(0.11, 0.30, 0.08)
	var jack_l := Color(0.28, 0.62, 0.22)
	var pants  := Color(0.30, 0.20, 0.10)
	var boots  := Color(0.20, 0.12, 0.05)
	var belt   := Color(0.40, 0.26, 0.08)
	var gold   := Color(0.74, 0.58, 0.14)
	var hair   := Color(0.34, 0.20, 0.08)
	var bow_c  := Color(0.50, 0.32, 0.10)
	var str_c  := Color(0.88, 0.84, 0.72)
	var arr_c  := Color(0.22, 0.80, 0.28)
	var sf     := clampf(_shoot_anim / 0.35, 0.0, 1.0)
	var bx     := 19.0

	draw_circle(Vector2(0, 24), 11, Color(0, 0, 0, 0.15))

	# ── Bow at rest (drawn behind body) ──────────────────────────────────────
	if not shooting:
		draw_arc(Vector2(bx, -5 + b), 14, -PI * 0.55, PI * 0.55, 12, bow_c, 4.0)
		draw_line(Vector2(bx, -19 + b), Vector2(bx - 7, -5 + b), str_c, 1.2)
		draw_line(Vector2(bx - 7, -5 + b), Vector2(bx, 9 + b),   str_c, 1.2)
		draw_line(Vector2(bx - 7, -5 + b), Vector2(bx + 10, -5 + b), arr_c, 2.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(bx + 10, -5 + b), Vector2(bx + 5, -8 + b), Vector2(bx + 5, -2 + b)
		]), arr_c)

	# ── Boots ─────────────────────────────────────────────────────────────────
	draw_rect(Rect2(-9, 16 + b, 8, 8), boots)
	draw_rect(Rect2( 1, 16 + b, 8, 8), boots)
	draw_line(Vector2(-9, 19 + b), Vector2(-1, 19 + b), boots.lightened(0.2), 1.0)
	draw_line(Vector2( 1, 19 + b), Vector2( 9, 19 + b), boots.lightened(0.2), 1.0)

	# ── Pants ─────────────────────────────────────────────────────────────────
	draw_rect(Rect2(-9, 4 + b, 8, 14), pants)
	draw_rect(Rect2( 1, 4 + b, 8, 14), pants)

	# ── Layered green leather jacket ──────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -10 + b), Vector2(13, -10 + b),
		Vector2(15,   6 + b),  Vector2(-15,  6 + b)
	]), jacket)
	draw_colored_polygon(PackedVector2Array([
		Vector2(4, -10 + b), Vector2(13, -10 + b),
		Vector2(15,  6 + b), Vector2( 7,  6 + b)
	]), jack_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4, -10 + b), Vector2(4, -10 + b),
		Vector2(5,   6 + b),  Vector2(-5,  6 + b)
	]), jack_l)
	draw_line(Vector2(-13, -10 + b), Vector2(13, -10 + b), gold, 1.5)
	draw_line(Vector2(-15,   3 + b), Vector2(15,  3 + b),  jack_d, 1.0)

	# ── Shoulder pauldrons (leather) ──────────────────────────────────────────
	draw_circle(Vector2(-17, -7 + b), 7, jack_d)
	draw_arc(Vector2(-17, -7 + b),    7, -PI * 0.9, PI * 0.1, 10, gold, 1.5)
	draw_circle(Vector2(-17, -11 + b), 4, jacket)
	draw_circle(Vector2( 17, -7 + b), 7, jack_d)
	draw_arc(Vector2( 17, -7 + b),    7, -PI * 0.1, PI * 0.9, 10, gold, 1.5)
	draw_circle(Vector2( 17, -11 + b), 4, jacket)

	# ── Belt + quiver ─────────────────────────────────────────────────────────
	draw_rect(Rect2(-13, -1 + b, 26, 5), belt)
	draw_rect(Rect2(-13, -1 + b, 26, 2), belt.lightened(0.15))
	draw_rect(Rect2(-4, -2 + b, 8, 7), gold.darkened(0.15))
	draw_rect(Rect2(-2,  0 + b, 4, 3), belt)
	draw_rect(Rect2(10, -10 + b, 6, 14), belt.darkened(0.1))
	draw_rect(Rect2(10, -10 + b, 6,  2), gold.darkened(0.15))
	for qi in range(3):
		draw_line(Vector2(11 + qi * 2, -10 + b), Vector2(11 + qi * 2, -14 + b), arr_c, 1.0)

	# ── Arms ──────────────────────────────────────────────────────────────────
	draw_rect(Rect2(-20, -9 + b, 10, 5), skin)
	draw_rect(Rect2(  8, -9 + b,  8, 5), skin)

	# ── Head ──────────────────────────────────────────────────────────────────
	draw_circle(Vector2(0, -17 + b), 7, skin)
	draw_circle(Vector2(-5, -17 + b), 2.5, skin)
	draw_circle(Vector2(0, -23 + b), 6, hair)
	draw_rect(Rect2(-6, -23 + b, 12, 7), hair)
	# Green ranger cap
	draw_rect(Rect2(-9, -22 + b, 18, 3), jack_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -22 + b), Vector2(8, -22 + b),
		Vector2( 5, -30 + b), Vector2(-4, -30 + b)
	]), jacket)
	draw_colored_polygon(PackedVector2Array([
		Vector2(2, -30 + b), Vector2(8, -22 + b), Vector2(5, -22 + b)
	]), jack_d)
	draw_line(Vector2(5, -29 + b), Vector2(14, -24 + b), Color(1.0, 0.90, 0.42), 2.0)
	draw_line(Vector2(6, -28 + b), Vector2(13, -24 + b), Color(1.0, 1.0, 0.65, 0.55), 1.0)
	draw_circle(Vector2(3, -17 + b), 1.5, Color(0.14, 0.08, 0.02))
	draw_line(Vector2(0, -20 + b), Vector2(5, -21 + b), hair, 1.5)

	# ── Bow when shooting ─────────────────────────────────────────────────────
	if shooting:
		draw_arc(Vector2(bx, -5 + b), 14, -PI * 0.55, PI * 0.55, 12, bow_c, 4.0)
		draw_line(Vector2(bx, -19 + b), Vector2(bx, 9 + b), str_c, 1.2)
		if sf > 0.25:
			draw_line(Vector2(bx, -5 + b), Vector2(bx + 26, -5 + b), arr_c, 2.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(bx + 26, -5 + b), Vector2(bx + 20, -8 + b), Vector2(bx + 20, -2 + b)
			]), arr_c)
			draw_line(Vector2(bx + 8, -8 + b), Vector2(bx + 20, -8 + b),
				Color(arr_c.r, arr_c.g, arr_c.b, sf * 0.5), 1.0)


# ── Crossbow (type 1) ─────────────────────────────────────────────────────────
# Navy-clad mercenary holding a steel crossbow levelled forward.

func _draw_crossbow(bob: float, shooting: bool) -> void:
	var b      := bob
	var skin   := Color(0.94, 0.78, 0.60)
	var jacket := Color(0.18, 0.32, 0.72)
	var jack_d := Color(0.10, 0.20, 0.52)
	var jack_l := Color(0.28, 0.46, 0.90)
	var pants  := Color(0.12, 0.18, 0.46)
	var boots  := Color(0.18, 0.12, 0.06)
	var belt   := Color(0.36, 0.22, 0.08)
	var gold   := Color(0.88, 0.72, 0.18)
	var hair   := Color(0.82, 0.68, 0.20)
	var steel  := Color(0.62, 0.65, 0.72)
	var steel_d:= Color(0.40, 0.42, 0.50)
	var wood_c := Color(0.50, 0.32, 0.12)
	var sf     := clampf(_shoot_anim / 0.35, 0.0, 1.0)
	var recoil := sf * 4.0

	draw_circle(Vector2(0, 24), 11, Color(0, 0, 0, 0.15))

	# ── Boots ─────────────────────────────────────────────────────────────────
	draw_rect(Rect2(-9, 16 + b, 8, 8), boots)
	draw_rect(Rect2( 1, 16 + b, 8, 8), boots)
	draw_line(Vector2(-9, 19 + b), Vector2(-1, 19 + b), boots.lightened(0.2), 1.0)
	draw_line(Vector2( 1, 19 + b), Vector2( 9, 19 + b), boots.lightened(0.2), 1.0)

	# ── Pants ─────────────────────────────────────────────────────────────────
	draw_rect(Rect2(-9, 4 + b, 8, 14), pants)
	draw_rect(Rect2( 1, 4 + b, 8, 14), pants)

	# ── Layered blue jacket ────────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -10 + b), Vector2(13, -10 + b),
		Vector2(15,   6 + b),  Vector2(-15,  6 + b)
	]), jacket)
	draw_colored_polygon(PackedVector2Array([
		Vector2(4, -10 + b), Vector2(13, -10 + b),
		Vector2(15,  6 + b), Vector2( 7,  6 + b)
	]), jack_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4, -10 + b), Vector2(4, -10 + b),
		Vector2(5,   6 + b),  Vector2(-5,  6 + b)
	]), jack_l)
	draw_line(Vector2(-13, -10 + b), Vector2(0, -4 + b), jack_l, 1.5)
	draw_line(Vector2( 13, -10 + b), Vector2(0, -4 + b), jack_l, 1.5)

	# ── Shoulder pauldrons ─────────────────────────────────────────────────────
	draw_circle(Vector2(-17, -7 + b), 7, jack_d)
	draw_arc(Vector2(-17, -7 + b),    7, -PI * 0.9, PI * 0.1, 10, gold, 1.5)
	draw_circle(Vector2(-17, -11 + b), 4, jacket)
	draw_circle(Vector2( 17, -7 + b), 7, jack_d)
	draw_arc(Vector2( 17, -7 + b),    7, -PI * 0.1, PI * 0.9, 10, gold, 1.5)
	draw_circle(Vector2( 17, -11 + b), 4, jacket)

	# ── Belt ──────────────────────────────────────────────────────────────────
	draw_rect(Rect2(-13, -1 + b, 26, 5), belt)
	draw_rect(Rect2(-13, -1 + b, 26, 2), belt.lightened(0.15))
	draw_rect(Rect2(-4, -2 + b, 8, 7), gold.darkened(0.15))
	draw_rect(Rect2(-2,  0 + b, 4, 3), belt)

	# ── Arms ──────────────────────────────────────────────────────────────────
	draw_rect(Rect2(-16, -7 + b, 9, 5), skin)
	draw_rect(Rect2(  7, -7 + b, 9, 5), skin)

	# ── Head + blonde hair ─────────────────────────────────────────────────────
	draw_circle(Vector2(0, -17 + b), 7, skin)
	draw_circle(Vector2(0, -23 + b), 6, hair)
	draw_rect(Rect2(-6, -23 + b, 12, 7), hair)
	draw_rect(Rect2(-8, -20 + b, 16, 3), jacket.darkened(0.1))
	draw_line(Vector2(-8, -20 + b), Vector2(8, -20 + b), gold, 1.0)
	draw_circle(Vector2(-3, -17 + b), 1.5, Color(0.12, 0.08, 0.02))
	draw_circle(Vector2( 3, -17 + b), 1.5, Color(0.12, 0.08, 0.02))

	# ── Crossbow ──────────────────────────────────────────────────────────────
	# Stock
	draw_rect(Rect2(-14, -6 + b, 22.0 - recoil, 5), wood_c)
	draw_line(Vector2(-14, -4 + b), Vector2(8.0 - recoil, -4 + b), wood_c.lightened(0.2), 1.0)
	# Prod (T-piece)
	draw_rect(Rect2(6.0 - recoil, -15 + b, 5, 21), steel)
	draw_rect(Rect2(6.0 - recoil, -15 + b, 5, 21), steel_d, false, 1.0)
	# Rail
	draw_rect(Rect2(10.0 - recoil, -8 + b, 16, 4), steel_d)
	draw_line(Vector2(10.0 - recoil, -7 + b), Vector2(26.0 - recoil, -7 + b), steel.lightened(0.2), 1.0)
	# Bolt nocked
	if not shooting:
		draw_rect(Rect2(10, -7 + b, 13, 2), arr_color())
	elif sf > 0.15:
		draw_line(Vector2(26, -6 + b), Vector2(48, -6 + b), arr_color(), 2.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(48, -6 + b), Vector2(43, -9 + b), Vector2(43, -3 + b)
		]), arr_color())
	# Trigger guard
	draw_rect(Rect2(-2, -2 + b, 3, 6), steel_d)
	# Muzzle flash
	if shooting and sf > 0.6:
		draw_circle(Vector2(26, -6 + b), 5.0 * (1.0 - sf),
			Color(1, 0.9, 0.5, (1.0 - sf) * 0.9))


func arr_color() -> Color:
	return Color(0.20, 0.55, 1.00)


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
	var b      := bob
	var robe   := Color(0.50, 0.16, 0.72)
	var robe_d := Color(0.30, 0.08, 0.48)
	var robe_l := Color(0.68, 0.28, 0.88)
	var star_c := Color(0.90, 0.82, 0.28)
	var skin   := Color(0.94, 0.78, 0.60)
	var hair   := Color(0.92, 0.92, 0.92)
	var staff  := Color(0.52, 0.34, 0.10)
	var orb_c  := Color(0.40, 0.90, 1.00) if not shooting else Color(0.70, 1.0, 1.0)
	var sx     := -17.0

	draw_circle(Vector2(0, 24), 11, Color(0, 0, 0, 0.15))

	# ── Staff behind body ─────────────────────────────────────────────────────
	draw_line(Vector2(sx, 20 + b), Vector2(sx, -8 + b), staff, 4.0)
	draw_line(Vector2(sx, 20 + b), Vector2(sx, -8 + b), staff.lightened(0.25), 1.5)

	# ── Layered gown ──────────────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -10 + b), Vector2(10, -10 + b),
		Vector2(15,  22 + b),  Vector2(-15, 22 + b)
	]), robe)
	draw_colored_polygon(PackedVector2Array([
		Vector2(3, -10 + b), Vector2(10, -10 + b),
		Vector2(15, 22 + b), Vector2( 9, 22 + b)
	]), robe_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3, -10 + b), Vector2(3, -10 + b),
		Vector2(4,  22 + b),  Vector2(-4, 22 + b)
	]), robe_l)
	draw_line(Vector2(-15, 18 + b), Vector2(15, 18 + b), star_c, 2.0)
	draw_circle(Vector2(-9, 20 + b), 1.5, star_c)
	draw_circle(Vector2( 0, 20 + b), 1.5, star_c)
	draw_circle(Vector2( 9, 20 + b), 1.5, star_c)

	# ── Shoulder pieces ───────────────────────────────────────────────────────
	draw_circle(Vector2(-16, -8 + b), 7, robe_d)
	draw_arc(Vector2(-16, -8 + b), 7, -PI * 0.9, PI * 0.1, 10, star_c, 1.5)
	draw_circle(Vector2(-16, -12 + b), 4, robe)
	draw_circle(Vector2( 16, -8 + b), 7, robe_d)
	draw_arc(Vector2( 16, -8 + b), 7, -PI * 0.1, PI * 0.9, 10, star_c, 1.5)
	draw_circle(Vector2( 16, -12 + b), 4, robe)

	# ── Belt sash ─────────────────────────────────────────────────────────────
	draw_rect(Rect2(-10, -2 + b, 20, 5), star_c.darkened(0.25))
	draw_rect(Rect2(-10, -2 + b, 20,  2), star_c.darkened(0.1))
	draw_circle(Vector2(0, 0 + b), 3, star_c.darkened(0.1))

	# ── Left arm ──────────────────────────────────────────────────────────────
	draw_rect(Rect2(sx, -5 + b, 10, 5), skin)

	# ── Orb at staff top ──────────────────────────────────────────────────────
	var orb_r := 7.0 if shooting else 5.5
	if shooting:
		var pulse := 0.5 + sin(_anim_time * 8.0) * 0.3
		draw_circle(Vector2(sx, -14 + b), orb_r + 6,
			Color(orb_c.r, orb_c.g, orb_c.b, 0.28 * pulse))
		for i in range(4):
			var sang := i * PI * 0.5 + _anim_time * 3.0
			var sp   := Vector2(sx, -14 + b) + Vector2(cos(sang), sin(sang)) * 12.0
			draw_circle(sp, 2.0, Color(1, 1, 0.8, 0.7))
	draw_circle(Vector2(sx, -14 + b), orb_r, orb_c)
	draw_circle(Vector2(sx - 2, -16 + b), orb_r * 0.35, Color(1, 1, 1, 0.50))

	# ── Head ──────────────────────────────────────────────────────────────────
	draw_circle(Vector2(0, -18 + b), 7, skin)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, -13 + b), Vector2(5, -13 + b),
		Vector2( 6,  -5 + b), Vector2(-6,  -5 + b)
	]), hair)
	draw_line(Vector2(-5, -21 + b), Vector2(-2, -22 + b), hair, 1.5)
	draw_line(Vector2( 5, -21 + b), Vector2( 2, -22 + b), hair, 1.5)
	draw_circle(Vector2(-3, -19 + b), 1.5, Color(0.12, 0.08, 0.30))
	draw_circle(Vector2( 3, -19 + b), 1.5, Color(0.12, 0.08, 0.30))

	# ── Pointy hat ────────────────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -23 + b), Vector2(12, -23 + b),
		Vector2(  8, -25 + b), Vector2(-8, -25 + b)
	]), robe_d)
	draw_rect(Rect2(-11, -25 + b, 22, 3), robe)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -25 + b), Vector2(8, -25 + b),
		Vector2( 2, -40 + b), Vector2(-2, -40 + b)
	]), robe)
	draw_colored_polygon(PackedVector2Array([
		Vector2(2, -40 + b), Vector2(8, -25 + b), Vector2(4, -25 + b)
	]), robe_d)
	draw_line(Vector2(-8, -25 + b), Vector2(8, -25 + b), star_c, 1.5)
	draw_circle(Vector2(0, -32 + b), 2.5, star_c)
	if shooting:
		draw_circle(Vector2(0, -32 + b), 5, Color(star_c.r, star_c.g, star_c.b, 0.35))


# ── Knight Hero (type 4) ──────────────────────────────────────────────────────
# Hero knight — elite plate look using the tower's own colour.

func _draw_knight(bob: float) -> void:
	var b        := bob
	var silver   := tower_color                      # polished silver base
	var silver_d := tower_color.darkened(0.38)       # deep shadow
	var silver_l := tower_color.lightened(0.32)      # highlight
	var gold     := Color(0.96, 0.80, 0.18)          # rich gold trim
	var gold_d   := Color(0.66, 0.52, 0.08)          # shadowed gold
	var royal    := Color(0.08, 0.16, 0.52)          # royal blue cape
	var royal_l  := Color(0.22, 0.40, 0.80)          # cape highlight
	var glow     := Color(0.28, 0.68, 1.00)          # glowing blue accent
	var glow_l   := Color(0.70, 0.92, 1.00)          # bright glow core
	var leather  := Color(0.48, 0.30, 0.12)          # grip leather
	var shooting := _shoot_anim > 0.0

	# ── Ground shadow ─────────────────────────────────────────────────────────
	draw_circle(Vector2(0, 25), 16, Color(0, 0, 0, 0.24))

	# ── Cape (drawn first — behind everything) ────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -6 + b), Vector2(12, -6 + b),
		Vector2(17,  22 + b), Vector2(-17, 22 + b)
	]), royal)
	# Left-side cape highlight
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -6 + b), Vector2(-5, -6 + b),
		Vector2(-7,  22 + b), Vector2(-17, 22 + b)
	]), royal_l)
	# Cape fold crease
	draw_line(Vector2(-1, -4 + b), Vector2(-3, 22 + b), royal_l, 1.5)
	# Gold hem
	draw_line(Vector2(-17, 22 + b), Vector2(17, 22 + b), gold_d, 2.0)
	# Cape collar trim
	draw_polyline(PackedVector2Array([
		Vector2(-12, -6 + b), Vector2(12, -6 + b),
		Vector2(17, 22 + b), Vector2(-17, 22 + b)
	]), Color(gold.r, gold.g, gold.b, 0.45), 1.5)

	# ── Legs ──────────────────────────────────────────────────────────────────
	# Thigh armor plates
	draw_rect(Rect2(-12, 4 + b, 11, 10), silver)
	draw_rect(Rect2(  1, 4 + b, 11, 10), silver)
	draw_rect(Rect2(-12, 4 + b, 11, 10), silver_d, false, 1.5)
	draw_rect(Rect2(  1, 4 + b, 11, 10), silver_d, false, 1.5)
	# Thigh highlight
	draw_line(Vector2(-8, 5 + b), Vector2(-8, 13 + b), silver_l, 1.5)
	draw_line(Vector2(5,  5 + b), Vector2(5,  13 + b), silver_l, 1.5)
	# Gold knee cop
	draw_line(Vector2(-12, 14 + b), Vector2(-1, 14 + b), gold, 2.5)
	draw_line(Vector2(  1, 14 + b), Vector2(12, 14 + b), gold, 2.5)
	# Greaves (lower leg)
	draw_rect(Rect2(-12, 14 + b, 11, 9), silver_d)
	draw_rect(Rect2(  1, 14 + b, 11, 9), silver_d)
	# Greave highlight stripe
	draw_line(Vector2(-7, 15 + b), Vector2(-7, 22 + b), silver_l, 1.5)
	draw_line(Vector2( 6, 15 + b), Vector2( 6, 22 + b), silver_l, 1.5)
	# Sabaton (gold foot) with knee glow
	draw_rect(Rect2(-13, 23 + b, 12, 4), gold_d)
	draw_rect(Rect2(  1, 23 + b, 12, 4), gold_d)
	draw_circle(Vector2(-7, 14 + b), 2, Color(glow.r, glow.g, glow.b, 0.70))
	draw_circle(Vector2( 6, 14 + b), 2, Color(glow.r, glow.g, glow.b, 0.70))

	# ── Waist armor / battle skirt ────────────────────────────────────────────
	draw_rect(Rect2(-13, 3 + b, 26, 4), silver_d)
	draw_line(Vector2(-13, 3 + b), Vector2(13, 3 + b), gold, 2.5)
	draw_line(Vector2(-13, 7 + b), Vector2(13, 7 + b), gold_d, 1.5)
	# Central buckle with glow gem
	draw_rect(Rect2(-4, 3 + b, 8, 4), gold)
	draw_circle(Vector2(0, 5 + b), 2, glow)
	draw_circle(Vector2(0, 5 + b), 1, glow_l)

	# ── Breastplate ───────────────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -12 + b), Vector2(14, -12 + b),
		Vector2( 12,   4 + b), Vector2(-12,   4 + b)
	]), silver)
	# Left-face lighting
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -12 + b), Vector2(0, -12 + b),
		Vector2(  0,   4 + b), Vector2(-14,  4 + b)
	]), silver_l.lerp(silver, 0.72))
	# Breastplate outline
	draw_polyline(PackedVector2Array([
		Vector2(-14, -12 + b), Vector2(14, -12 + b),
		Vector2( 12,   4 + b), Vector2(-12,   4 + b), Vector2(-14, -12 + b)
	]), silver_d, 2.0)
	# Center ridge
	draw_line(Vector2(0, -12 + b), Vector2(0, 4 + b), silver_d, 1.5)
	# Gold collar band
	draw_line(Vector2(-14, -12 + b), Vector2(14, -12 + b), gold, 4.0)
	# Heraldic cross crest
	draw_rect(Rect2(-2, -10 + b, 4, 13), gold_d)
	draw_rect(Rect2(-7, -6 + b, 14, 4),  gold_d)
	draw_rect(Rect2(-1, -10 + b, 2, 13), gold)
	draw_rect(Rect2(-7, -5 + b, 14, 2),  gold)
	# Medal ribbon (left breast — noble insignia)
	draw_rect(Rect2(-12, -2 + b, 4, 3), Color(0.72, 0.10, 0.10))
	draw_line(Vector2(-12, -2 + b), Vector2(-8, -2 + b), Color(0.95, 0.78, 0.10), 1.0)

	# ── Pauldrons — large layered shoulder armor ───────────────────────────────
	# Outer pauldron cap
	draw_circle(Vector2(-19, -9 + b), 11, silver)
	draw_circle(Vector2( 19, -9 + b), 11, silver)
	draw_circle(Vector2(-19, -9 + b), 11, silver_d, false, 2.5)
	draw_circle(Vector2( 19, -9 + b), 11, silver_d, false, 2.5)
	# Pauldron highlight
	draw_circle(Vector2(-21, -12 + b), 4, silver_l)
	draw_circle(Vector2( 17, -12 + b), 4, silver_l)
	# Gold trim arcs
	draw_arc(Vector2(-19, -9 + b), 11, -PI * 0.95, PI * 0.1, 14, gold, 2.5)
	draw_arc(Vector2( 19, -9 + b), 11, -PI * 0.1, PI * 0.95, 14, gold, 2.5)
	# Lower pauldron hanging plate
	draw_colored_polygon(PackedVector2Array([
		Vector2(-30, -7 + b), Vector2(-10, -7 + b),
		Vector2(-10,  1 + b), Vector2(-30,  1 + b)
	]), silver_d)
	draw_line(Vector2(-30, -7 + b), Vector2(-10, -7 + b), gold, 2.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(10, -7 + b), Vector2(30, -7 + b),
		Vector2(30,  1 + b), Vector2(10,  1 + b)
	]), silver_d)
	draw_line(Vector2(10, -7 + b), Vector2(30, -7 + b), gold, 2.0)
	# Shoulder joint glow
	draw_circle(Vector2(-19, -9 + b), 5, Color(glow.r, glow.g, glow.b, 0.40))
	draw_circle(Vector2( 19, -9 + b), 5, Color(glow.r, glow.g, glow.b, 0.40))
	draw_circle(Vector2(-19, -9 + b), 2, glow_l)
	draw_circle(Vector2( 19, -9 + b), 2, glow_l)

	# ── Ornate Tower Shield (left) ────────────────────────────────────────────
	# Shield body — royal blue field
	var sh := PackedVector2Array([
		Vector2(-36, -16 + b), Vector2(-14, -16 + b),
		Vector2(-12,  10 + b), Vector2(-21,  24 + b), Vector2(-34,  10 + b)
	])
	draw_colored_polygon(sh, royal)
	# Inner shield field (slightly inset)
	var sh2 := PackedVector2Array([
		Vector2(-34, -13 + b), Vector2(-16, -13 + b),
		Vector2(-14,   8 + b), Vector2(-21,  20 + b), Vector2(-32,  8 + b)
	])
	draw_colored_polygon(sh2, Color(0.10, 0.20, 0.58))
	# Gold shield border
	draw_polyline(sh + PackedVector2Array([sh[0]]), gold, 3.5)
	draw_polyline(sh2 + PackedVector2Array([sh2[0]]), gold_d, 1.5)
	# Shield cross (heraldic crest)
	draw_line(Vector2(-25, -10 + b), Vector2(-25, 16 + b), gold, 3.5)
	draw_line(Vector2(-34,  3 + b),  Vector2(-14,  3 + b), gold, 3.5)
	draw_line(Vector2(-25, -10 + b), Vector2(-25, 16 + b), Color(1.0, 0.95, 0.60), 1.4)
	draw_line(Vector2(-34,  3 + b),  Vector2(-14,  3 + b), Color(1.0, 0.95, 0.60), 1.4)
	# Central gem glow
	draw_circle(Vector2(-25, 3 + b), 7, Color(glow.r, glow.g, glow.b, 0.30))
	draw_circle(Vector2(-25, 3 + b), 5, glow)
	draw_circle(Vector2(-25, 3 + b), 2, glow_l)
	# Corner orbs
	draw_circle(Vector2(-36, -16 + b), 3, gold)
	draw_circle(Vector2(-14, -16 + b), 3, gold)
	draw_circle(Vector2(-36, -16 + b), 1, Color(1.0, 0.95, 0.70))
	draw_circle(Vector2(-14, -16 + b), 1, Color(1.0, 0.95, 0.70))

	# ── Royal Crowned Helmet ──────────────────────────────────────────────────
	# Helmet dome
	draw_circle(Vector2(0, -22 + b), 11, silver)
	draw_circle(Vector2(0, -22 + b), 11, silver_d, false, 2.5)
	# Highlight
	draw_circle(Vector2(-3, -26 + b), 4, silver_l)
	# Visor plate
	draw_rect(Rect2(-11, -26 + b, 22, 8), silver_d)
	draw_rect(Rect2(-11, -26 + b, 22, 2), silver)
	# Eye visor slits
	draw_rect(Rect2(-10, -24 + b, 7, 3), Color(0.04, 0.06, 0.18))
	draw_rect(Rect2(  3, -24 + b, 7, 3), Color(0.04, 0.06, 0.18))
	# Glowing eyes
	draw_rect(Rect2(-10, -24 + b, 7, 3), Color(glow.r, glow.g, glow.b, 0.80), false, 1.0)
	draw_rect(Rect2(  3, -24 + b, 7, 3), Color(glow.r, glow.g, glow.b, 0.80), false, 1.0)
	draw_line(Vector2(-7, -23 + b), Vector2(-5, -23 + b), glow_l, 1.5)
	draw_line(Vector2( 6, -23 + b), Vector2( 8, -23 + b), glow_l, 1.5)
	# Gold brow band
	draw_line(Vector2(-11, -19 + b), Vector2(11, -19 + b), gold, 3.0)
	# Crown stem
	draw_rect(Rect2(-3, -33 + b, 6, 12), silver)
	draw_rect(Rect2(-3, -33 + b, 6, 12), silver_d, false, 1.5)
	# Three crown points (gold)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -33 + b), Vector2(-3, -33 + b), Vector2(-5, -40 + b)
	]), gold)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2, -33 + b), Vector2( 2, -33 + b), Vector2(0, -42 + b)
	]), gold)
	draw_colored_polygon(PackedVector2Array([
		Vector2( 3, -33 + b), Vector2( 6, -33 + b), Vector2(5, -40 + b)
	]), gold)
	# Crown gem tips
	draw_circle(Vector2(-5, -40 + b), 2, glow)
	draw_circle(Vector2( 0, -42 + b), 2, glow)
	draw_circle(Vector2( 5, -40 + b), 2, glow)
	# Royal blue plume
	draw_rect(Rect2(-5, -41 + b, 10, 13), Color(0.18, 0.48, 0.90, 0.88))
	draw_rect(Rect2(-4, -43 + b,  8, 10), Color(0.32, 0.65, 1.00, 0.92))
	draw_rect(Rect2(-2, -44 + b,  4,  6), Color(0.58, 0.82, 1.00, 0.80))

	# ── Legendary Sword (right arm) ───────────────────────────────────────────
	if shooting:
		var sw  := _shoot_anim / 0.35
		var ang := -PI * 0.5 + sw * PI * 0.75
		var tip := Vector2(cos(ang), sin(ang)) * 34 + Vector2(16, -8 + b)
		# Grip
		draw_rect(Rect2(12, -9 + b, 8, 6), leather)
		# Blade glow aura
		draw_line(Vector2(16, -6 + b), tip, Color(glow.r, glow.g, glow.b, 0.35), 9.0)
		# Blade
		draw_line(Vector2(16, -6 + b), tip, silver, 5.0)
		draw_line(Vector2(16, -6 + b), tip, silver_l, 2.0)
		# Crossguard
		draw_rect(Rect2(7, -12 + b, 20, 5), gold)
		draw_rect(Rect2(7, -12 + b, 20, 5), gold_d, false, 1.5)
		# Swing arc
		if _shoot_anim / 0.35 > 0.55:
			draw_arc(Vector2.ZERO, 26 + sw * 8, -PI * 0.65, PI * 0.05, 16,
				Color(glow.r, glow.g, glow.b, sw * 0.70), 4.5)
	else:
		# Grip
		draw_rect(Rect2(13, -7 + b, 8, 6), leather)
		# Blade glow aura (idle)
		draw_rect(Rect2(13, -34 + b, 9, 42), Color(glow.r, glow.g, glow.b, 0.18))
		# Blade body
		draw_rect(Rect2(14, -34 + b, 7, 40), silver)
		draw_rect(Rect2(14, -34 + b, 7, 40), silver_d, false, 1.5)
		# Blade center fuller
		draw_line(Vector2(17, -33 + b), Vector2(17, 5 + b), silver_l, 2.0)
		# Blade rune glyphs (glow)
		draw_line(Vector2(15, -26 + b), Vector2(20, -26 + b), Color(glow.r, glow.g, glow.b, 0.85), 1.8)
		draw_line(Vector2(15, -20 + b), Vector2(20, -20 + b), Color(glow.r, glow.g, glow.b, 0.85), 1.8)
		draw_line(Vector2(15, -14 + b), Vector2(20, -14 + b), Color(glow.r, glow.g, glow.b, 0.85), 1.8)
		# Wide ornate crossguard
		draw_rect(Rect2(6, -6 + b, 22, 5), gold)
		draw_rect(Rect2(6, -6 + b, 22, 5), gold_d, false, 1.5)
		draw_circle(Vector2(6,  -4 + b), 3, gold_d)
		draw_circle(Vector2(28, -4 + b), 3, gold_d)
		# Pommel
		draw_circle(Vector2(17, 8 + b), 5, gold)
		draw_circle(Vector2(17, 8 + b), 3, Color(1.0, 0.95, 0.62))
		draw_circle(Vector2(17, 8 + b), 1, glow_l)


# ── Flame Tower (type 5) ──────────────────────────────────────────────────────
func _draw_flame_tower(b: float, s: bool) -> void:
	var stone  := Color(0.38, 0.33, 0.28)
	var stone_l:= Color(0.52, 0.46, 0.40)
	var stone_d:= Color(0.24, 0.20, 0.17)
	var hot    := Color(1.00, 0.35, 0.05)
	var yel    := Color(1.00, 0.82, 0.18)
	var wht    := Color(1.00, 0.96, 0.78)

	draw_circle(Vector2(0, 24), 13, Color(0, 0, 0, 0.16))

	# ── Stone box front face ───────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14,  0 + b), Vector2(14,  0 + b),
		Vector2(14,  22 + b), Vector2(-14, 22 + b)
	]), stone)
	# 3D top face
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14,  0 + b), Vector2(14,  0 + b),
		Vector2(11, -5 + b),  Vector2(-11, -5 + b)
	]), stone_l)
	# Shadow right side
	draw_colored_polygon(PackedVector2Array([
		Vector2(8,  0 + b), Vector2(14,  0 + b),
		Vector2(14, 22 + b), Vector2(8, 22 + b)
	]), stone_d)
	# Stone block joints
	draw_line(Vector2(-14,  8 + b), Vector2(14,  8 + b), stone_d, 1.0)
	draw_line(Vector2(-14, 15 + b), Vector2(14, 15 + b), stone_d, 1.0)
	draw_line(Vector2(-5,   0 + b), Vector2(-5, 22 + b), stone_d, 1.0)
	draw_line(Vector2( 5,   0 + b), Vector2( 5, 22 + b), stone_d, 1.0)
	draw_rect(Rect2(-14, 0 + b, 28, 22), stone_d, false, 1.5)

	# ── Battlements ───────────────────────────────────────────────────────────
	for i in range(4):
		var bx2 := -13 + i * 8
		draw_rect(Rect2(bx2, -9 + b, 5, 10), stone_l)
		draw_rect(Rect2(bx2, -9 + b, 5, 10), stone_d, false, 1.0)

	# ── Flames on top ─────────────────────────────────────────────────────────
	var fa  := 0.85 if not s else 1.0
	var fh  := 14.0 + sin(_anim_time * 5.0) * 3.0 + (8.0 if s else 0.0)
	var fh2 := fh * 0.70
	var fh3 := fh * 0.45
	# Outer orange flame
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -5 + b), Vector2(12, -5 + b),
		Vector2( 7, -5 - fh + b), Vector2(-7, -5 - fh + b)
	]), Color(hot.r, hot.g, hot.b, fa))
	# Mid yellow flame
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -5 + b), Vector2(7, -5 + b),
		Vector2( 4, -5 - fh2 + b), Vector2(-4, -5 - fh2 + b)
	]), Color(yel.r, yel.g, yel.b, fa))
	# Core white-hot
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3, -5 + b), Vector2(3, -5 + b),
		Vector2( 1, -5 - fh3 + b), Vector2(-1, -5 - fh3 + b)
	]), Color(wht.r, wht.g, wht.b, fa * 0.9))
	draw_circle(Vector2(0, -5 + b), 4, Color(1.0, 1.0, 0.85, 0.92))
	# Side flicker
	var flick := sin(_anim_time * 7.0) * 0.5 + 0.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -3 + b), Vector2(-6, -3 + b),
		Vector2(-8, -3 - fh * 0.5 * flick + b), Vector2(-13, -3 - fh * 0.3 * flick + b)
	]), Color(hot.r, hot.g, hot.b, 0.65))
	draw_colored_polygon(PackedVector2Array([
		Vector2(6, -3 + b), Vector2(12, -3 + b),
		Vector2(13, -3 - fh * 0.3 * flick + b), Vector2(8, -3 - fh * 0.5 * flick + b)
	]), Color(hot.r, hot.g, hot.b, 0.65))


# ── Frost Spire (type 6) ──────────────────────────────────────────────────────
func _draw_frost_spire(b: float, s: bool) -> void:
	var stone  := Color(0.35, 0.50, 0.65)
	var stone_l:= Color(0.50, 0.65, 0.80)
	var stone_d:= Color(0.22, 0.34, 0.48)
	var ice    := Color(0.55, 0.88, 1.00)
	var ice_l  := Color(0.80, 0.96, 1.00)
	var ice_d  := Color(0.35, 0.68, 0.90)

	draw_circle(Vector2(0, 24), 11, Color(0, 0, 0, 0.15))

	# ── Stone base (3D box) ────────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12,  8 + b), Vector2(12,  8 + b),
		Vector2(12,  22 + b), Vector2(-12, 22 + b)
	]), stone)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, 8 + b), Vector2(12, 8 + b),
		Vector2( 9,  4 + b), Vector2(-9,  4 + b)
	]), stone_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(6, 8 + b), Vector2(12,  8 + b),
		Vector2(12, 22 + b), Vector2(6, 22 + b)
	]), stone_d)
	draw_line(Vector2(-12, 14 + b), Vector2(12, 14 + b), stone_d, 1.0)
	draw_line(Vector2(-3,   8 + b), Vector2(-3, 22 + b), stone_d, 1.0)
	draw_line(Vector2( 3,   8 + b), Vector2( 3, 22 + b), stone_d, 1.0)
	draw_rect(Rect2(-12, 8 + b, 24, 14), stone_d, false, 1.5)

	# ── Side ice crystals ─────────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13,  6 + b), Vector2(-7,  6 + b),
		Vector2( -5, -6 + b), Vector2(-10, -6 + b)
	]), ice_d)
	draw_line(Vector2(-9, -6 + b), Vector2(-6, 4 + b), ice_l, 1.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(7,  6 + b), Vector2(13,  6 + b),
		Vector2(10, -6 + b), Vector2(5, -6 + b)
	]), ice_d)
	draw_line(Vector2(7, -5 + b), Vector2(10, 4 + b), ice_l, 1.0)

	# ── Central spire ─────────────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, 6 + b), Vector2(7, 6 + b),
		Vector2( 4, -8 + b), Vector2(-4, -8 + b)
	]), ice)
	draw_line(Vector2(-2, -8 + b), Vector2(0, 4 + b), ice_l, 2.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3, -8 + b), Vector2(3, -8 + b),
		Vector2( 1, -22 + b), Vector2(-1, -22 + b)
	]), ice)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-1, -22 + b), Vector2(1, -22 + b),
		Vector2(0, -30 + b)
	]), ice_l)
	draw_line(Vector2(-1, -22 + b), Vector2(0, -30 + b), ice_l, 1.0)

	# ── Shimmer + glow ─────────────────────────────────────────────────────────
	var shine_a := 0.35 + sin(_anim_time * 3.0) * 0.15
	draw_arc(Vector2(0, -16 + b), 16, -PI * 0.4, PI * 0.4, 12,
		Color(ice_l.r, ice_l.g, ice_l.b, shine_a), 1.5)
	if s:
		draw_circle(Vector2(0, -26 + b), 5, Color(1, 1, 1, 0.85))
		draw_circle(Vector2(0, -26 + b), 9, Color(ice_l.r, ice_l.g, ice_l.b, 0.45))


# ── Poison Tower (type 7) ─────────────────────────────────────────────────────
func _draw_poison_tower(b: float, s: bool) -> void:
	var stone  := Color(0.30, 0.36, 0.28)
	var stone_l:= Color(0.42, 0.50, 0.38)
	var stone_d:= Color(0.18, 0.22, 0.16)
	var grn    := Color(0.25, 0.80, 0.15)
	var grn_l  := Color(0.50, 0.95, 0.28)
	var grn_d  := Color(0.12, 0.48, 0.08)

	draw_circle(Vector2(0, 24), 11, Color(0, 0, 0, 0.15))

	# ── Stone tower body ───────────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -8 + b), Vector2(10, -8 + b),
		Vector2(11,  22 + b), Vector2(-11, 22 + b)
	]), stone)
	draw_colored_polygon(PackedVector2Array([
		Vector2(4,  -8 + b), Vector2(10, -8 + b),
		Vector2(11, 22 + b), Vector2(5,  22 + b)
	]), stone_d)
	draw_line(Vector2(-10, -8 + b), Vector2(10, -8 + b), stone_l, 2.0)
	draw_line(Vector2(-10,  4 + b), Vector2(10,  4 + b), stone_d, 1.0)
	draw_line(Vector2(-10, 14 + b), Vector2(10, 14 + b), stone_d, 1.0)
	# Battlements
	for i in range(3):
		draw_rect(Rect2(-9 + i * 7, -14 + b, 5, 8), stone_l)
		draw_rect(Rect2(-9 + i * 7, -14 + b, 5, 8), stone_d, false, 1.0)

	# ── Poison vat on top ─────────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -10 + b), Vector2(7, -10 + b),
		Vector2( 8,  -4 + b), Vector2(-8,  -4 + b)
	]), grn_d)
	draw_rect(Rect2(-7, -14 + b, 14, 5), grn_d)
	draw_circle(Vector2(0, -11 + b), 5, grn)
	draw_circle(Vector2(-2, -12 + b), 2, grn_l)

	# ── Drip pipes ────────────────────────────────────────────────────────────
	draw_rect(Rect2(-8, -4 + b, 3, 8), stone_d)
	draw_rect(Rect2( 5, -4 + b, 3, 8), stone_d)
	var drip_a := 0.6 + sin(_anim_time * 4.0) * 0.3
	draw_circle(Vector2(-6, 6 + b), 2.5, Color(grn.r, grn.g, grn.b, drip_a))
	draw_circle(Vector2( 7, 4 + b), 2.0, Color(grn.r, grn.g, grn.b, drip_a * 0.8))
	if s:
		for i in range(3):
			var da := _anim_time * 3.0 + i * TAU / 3.0
			var dp := Vector2(cos(da) * 12, sin(da) * 6 + b)
			draw_circle(dp, 2.5, Color(grn_l.r, grn_l.g, grn_l.b, 0.7))
	# Bubble anim
	var ba : float = abs(sin(_anim_time * 3.5))
	draw_circle(Vector2(-3, -10.0 - ba * 5.0 + b), 1.5, Color(grn_l.r, grn_l.g, grn_l.b, 0.8))
	draw_circle(Vector2( 3, -10.0 - ba * 3.0 + b), 1.0, Color(grn_l.r, grn_l.g, grn_l.b, 0.6))


# ── Sniper Tower (type 8) ─────────────────────────────────────────────────────
func _draw_sniper_tower(b: float, s: bool) -> void:
	var skin   := Color(0.94, 0.78, 0.60)
	var cloak  := Color(0.42, 0.46, 0.36)
	var cloak_d:= Color(0.28, 0.30, 0.22)
	var cloak_l:= Color(0.58, 0.62, 0.48)
	var wood   := Color(0.45, 0.30, 0.14)
	var wood_d := Color(0.30, 0.20, 0.08)
	var steel  := Color(0.58, 0.60, 0.68)
	var steel_d:= Color(0.38, 0.40, 0.48)
	var sf     := clampf(_shoot_anim / 0.35, 0.0, 1.0)
	var recoil := sf * 4.0

	draw_circle(Vector2(0, 24), 11, Color(0, 0, 0, 0.15))

	# ── Elevated wooden platform ──────────────────────────────────────────────
	draw_line(Vector2(-13, 22 + b), Vector2(-13, 2 + b), wood, 4.0)
	draw_line(Vector2( 13, 22 + b), Vector2( 13, 2 + b), wood, 4.0)
	draw_line(Vector2(-13, 12 + b), Vector2( 13, 12 + b), wood, 3.5)
	draw_line(Vector2(-13,  4 + b), Vector2( 13,  4 + b), wood, 3.5)
	draw_rect(Rect2(-14, 0 + b, 28, 5), wood.lightened(0.12))
	draw_rect(Rect2(-14, 0 + b, 28, 5), wood_d, false, 1.0)
	for px in [-7, 0, 7]:
		draw_line(Vector2(px, 0 + b), Vector2(px, 5 + b), wood_d, 1.0)

	# ── Ghillie cloak body ────────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -4 + b), Vector2(10, -4 + b),
		Vector2(12,   4 + b), Vector2(-12,  4 + b)
	]), cloak)
	draw_colored_polygon(PackedVector2Array([
		Vector2(3, -4 + b), Vector2(10, -4 + b),
		Vector2(12, 4 + b), Vector2( 5,  4 + b)
	]), cloak_d)
	draw_line(Vector2(-8, -2 + b), Vector2(-4, 2 + b), cloak_l, 1.0)
	draw_line(Vector2(-2, -3 + b), Vector2( 2, 1 + b), cloak_l, 1.0)
	draw_line(Vector2( 4, -2 + b), Vector2( 8, 2 + b), cloak_l, 1.0)

	# ── Head + hood ───────────────────────────────────────────────────────────
	draw_circle(Vector2(0, -10 + b), 7, skin)
	draw_circle(Vector2(0, -16 + b), 5, cloak.darkened(0.1))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -12 + b), Vector2(8, -12 + b),
		Vector2( 6,  -5 + b), Vector2(-6,  -5 + b)
	]), cloak)
	draw_circle(Vector2(4, -10 + b), 1.5, Color(0.14, 0.08, 0.04))
	draw_line(Vector2(-5, -14 + b), Vector2(-2, -12 + b), cloak_l, 1.0)
	draw_line(Vector2( 2, -14 + b), Vector2( 5, -12 + b), cloak_l, 1.0)

	# ── Sniper rifle ──────────────────────────────────────────────────────────
	draw_line(Vector2(-4, 0 + b), Vector2(-8, 5 + b), steel_d, 2.0)
	draw_line(Vector2(-4, 0 + b), Vector2( 0, 5 + b), steel_d, 2.0)
	# Barrel
	draw_line(Vector2(-6, -2 + b), Vector2(22.0 - recoil, -6 + b), steel_d, 5.0)
	draw_line(Vector2(-6, -2 + b), Vector2(22.0 - recoil, -6 + b), steel,    4.0)
	draw_line(Vector2(-6, -2 + b), Vector2(22.0 - recoil, -6 + b), Color(0.78, 0.80, 0.88), 1.5)
	# Wooden stock
	draw_rect(Rect2(-16, -4 + b, 12, 5), wood)
	draw_line(Vector2(-16, -3 + b), Vector2(-4, -3 + b), wood.lightened(0.2), 1.0)
	# Scope
	draw_rect(Rect2(4.0 - recoil, -10 + b, 10, 5), steel_d)
	draw_circle(Vector2(4.0 - recoil,  -8 + b), 3, steel_d.darkened(0.3))
	draw_circle(Vector2(14.0 - recoil, -8 + b), 3, steel_d.darkened(0.3))
	draw_rect(Rect2(3.0 - recoil, -9 + b, 12, 3), steel_d)
	# Muzzle flash
	if s and sf > 0.2:
		draw_circle(Vector2(22, -6 + b), 6.0 * sf, Color(1, 0.88, 0.45, sf * 0.9))
		draw_circle(Vector2(22, -6 + b), 3.0 * sf, Color(1.0, 1.0, 0.85, sf))


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

	# Beams — drawn in world-relative local coords
	for _bi in range(2):
		var _bt  : Node2D = _beam_target      if _bi == 0 else _beam_target2
		var _bti : float  = _beam_timer       if _bi == 0 else _beam_timer2
		var _blt : float  = _beam_lock_time   if _bi == 0 else _beam_lock_time2
		if _bt == null or not is_instance_valid(_bt) or _bti <= 0.0:
			continue
		var beam_end := _bt.position - position

		# Heat 0→1 over 5 seconds on this target
		var heat := clampf(_blt / 5.0, 0.0, 1.0)
		# Slow pulse that intensifies with heat (±10% alpha oscillation)
		var pulse_a := 1.0 + sin(_anim_time * 4.0 + float(_bi) * PI) * 0.10 * (0.4 + heat * 0.6)

		# Outer glow: pale pink-red (cold) → deep crimson (hot)
		var glow_col := Color(1.00, 0.55, 0.55).lerp(Color(0.85, 0.02, 0.02), heat)
		var glow_a   := clampf((0.45 + heat * 0.45) * pulse_a, 0.0, 1.0)
		var glow_w   := 4.0 + heat * 2.5  # thickens as it heats up

		# Mid beam: light rose → bright red
		var mid_col  := Color(1.00, 0.70, 0.70).lerp(Color(1.00, 0.12, 0.05), heat)
		var mid_a    := clampf((0.55 + heat * 0.35) * pulse_a, 0.0, 1.0)

		# Hot core (visible only when warm): white-pink → orange-red
		var core_col := Color(1.00, 0.90, 0.90).lerp(Color(1.00, 0.40, 0.10), heat)
		var core_a   := clampf(heat * 0.75 * pulse_a, 0.0, 1.0)

		# Fade-in on beam refresh (avoids pop when re-acquiring target)
		var ba := clampf(_bti / 0.10, 0.0, 1.0)

		draw_line(Vector2.ZERO, beam_end, Color(glow_col.r, glow_col.g, glow_col.b, glow_a * ba), glow_w)
		draw_line(Vector2.ZERO, beam_end, Color(mid_col.r,  mid_col.g,  mid_col.b,  mid_a  * ba), 2.0)
		draw_line(Vector2.ZERO, beam_end, Color(core_col.r, core_col.g, core_col.b, core_a * ba), 1.0)

		# Impact dot at target — grows and deepens with heat
		var dot_r := 4.5 + heat * 2.5
		var dot_col := Color(1.00, 0.60, 0.60).lerp(Color(1.00, 0.10, 0.02), heat)
		draw_circle(Vector2.ZERO, 5.0 + heat * 1.5, Color(glow_col.r, glow_col.g, glow_col.b, 0.70 * ba))
		draw_circle(beam_end, dot_r, Color(dot_col.r, dot_col.g, dot_col.b, 0.80 * ba))


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
	# Charge fraction 0.0 (empty) → 1.0 (ready to fire)
	var charge_frac := float(_arcane_charge % 15) / 15.0
	var purple := Color(0.80, 0.30, 0.90)
	var blue   := Color(0.20, 0.65, 1.00)
	var orb_c  := purple.lerp(blue, charge_frac)
	var ring   := Color(0.60, 0.20, 0.72).lerp(Color(0.15, 0.50, 0.90), charge_frac)
	var gold   := Color(0.90, 0.78, 0.22)
	draw_circle(Vector2(0, 24), 11, Color(0, 0, 0, 0.15))
	# Floating orbit rings — spin faster and glow bluer as charged
	var spin_speed := 2.0 + charge_frac * 3.0
	for i in range(3):
		var ang := _anim_time * spin_speed + i * TAU / 3.0
		var ex  := cos(ang) * 14.0
		var ey  := sin(ang) * 6.0 + b
		draw_arc(Vector2(ex * 0.3, ey), 12 - i * 2, -PI * 0.6 + ang, PI * 0.6 + ang, 10, Color(ring.r, ring.g, ring.b, 0.6 + charge_frac * 0.3), 2.0)
	# Central arcane orb — grows slightly when fully charged
	var os := 10.0 + sin(_anim_time * 4.0) * 2.0 + charge_frac * 3.0
	draw_circle(Vector2(0, -2 + b), os, orb_c)
	draw_circle(Vector2(0, -2 + b), os - 3, Color(orb_c.r + 0.15, orb_c.g + 0.15, orb_c.b + 0.1, 1.0))
	draw_circle(Vector2(-2, -4 + b), 3, Color(1, 1, 1, 0.5))
	# Charge ring — arc that fills up as charge_frac increases
	if charge_frac > 0.0:
		draw_arc(Vector2(0, -2 + b), os + 4, -PI * 0.5, -PI * 0.5 + TAU * charge_frac, 32,
			Color(blue.r, blue.g, blue.b, 0.75), 2.5)
	# Gold trim
	draw_arc(Vector2(0, -2 + b), os, 0, TAU, 20, Color(gold.r, gold.g, gold.b, 0.7), 1.5)
	# Sparks — rune sparks when shooting normally, blue ray burst when fully charged
	if s:
		if _arcane_charge % 15 == 0 and _arcane_charge > 0:
			# Blue ray discharge flash
			for i in range(8):
				var sa := i * TAU / 8.0
				var sp := Vector2(cos(sa), sin(sa)) * (os + 10) + Vector2(0, -2 + b)
				draw_circle(sp, 4.0, Color(blue.r, blue.g, blue.b, 0.9))
			draw_circle(Vector2(0, -2 + b), os + 8, Color(blue.r, blue.g, blue.b, 0.25))
		else:
			for i in range(6):
				var sa := i * TAU / 6.0
				var sp := Vector2(cos(sa), sin(sa)) * (os + 6) + Vector2(0, -2 + b)
				draw_circle(sp, 2.5, Color(orb_c.r + 0.2, orb_c.g + 0.1, orb_c.b + 0.1, 0.85))
	# Blue laser beams — visible for 1s, fade over 1s after arcane discharge
	if _arcane_laser_alpha > 0.0:
		var a := _arcane_laser_alpha
		for enemy in _arcane_laser_targets:
			if is_instance_valid(enemy):
				var laser_end : Vector2 = enemy.position - position
				draw_line(Vector2(0, -2 + b), laser_end, Color(0.10, 0.50, 1.0, a * 0.85), 5.0)
				draw_line(Vector2(0, -2 + b), laser_end, Color(0.55, 0.88, 1.0, a * 0.70), 2.0)
				draw_circle(laser_end, 5.0, Color(0.20, 0.65, 1.0, a * 0.80))
		draw_circle(Vector2(0, -2 + b), os + 10, Color(0.20, 0.65, 1.0, a * 0.30))

	# Chain cable down to ground
	for i in range(4):
		var cy := 10 + i * 5 + b
		draw_circle(Vector2(0, cy), 1.5, Color(ring.r, ring.g, ring.b, 0.5))


# ── Blade Assassin (type 30) ─────────────────────────────────────────────────
func _draw_blade_assassin(b: float, s: bool) -> void:
	var dark   := Color(0.07, 0.05, 0.12)
	var cloak  := Color(0.16, 0.10, 0.26)
	var steel  := Color(0.75, 0.80, 0.95)
	var edge   := Color(0.95, 0.97, 1.00)
	var fuller := Color(0.60, 0.70, 0.95)
	var eye_c  := Color(0.85, 0.15, 0.90)

	# Swing fraction — blades physically move between positions
	var sf := clampf(_shoot_anim / 0.35, 0.0, 1.0)

	# Drop shadow
	draw_circle(Vector2(0, 24), 13, Color(0, 0, 0, 0.22))

	# Base platform
	draw_rect(Rect2(-12, 14 + b, 24, 10), dark)
	draw_rect(Rect2(-10, 12 + b, 20, 4), cloak.lightened(0.06))

	# Cloak body
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -18 + b), Vector2(-12, 14 + b), Vector2(12, 14 + b)
	]), cloak)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -12 + b), Vector2(-4, 10 + b), Vector2(4, 10 + b)
	]), dark)

	# Hood
	draw_circle(Vector2(0, -15 + b), 9, dark)
	draw_circle(Vector2(0, -16 + b), 8, cloak)

	# Glowing eyes (flare on attack)
	var eye_a := 0.50 + sf * 0.50
	for ex in [-3.0, 3.0]:
		draw_circle(Vector2(ex, -16 + b), 2.0 + sf, Color(eye_c.r, eye_c.g, eye_c.b, eye_a))
		draw_circle(Vector2(ex, -16 + b), 0.9,       Color(1.0, 0.85, 1.0, eye_a))

	# ── Left blade ──
	# Resting: tip up-left; Attacking: thrust far out-left at waist height
	var lg_base := Vector2(-7, 4 + b)
	var lg_tip  := Vector2(-16, -26 + b).lerp(Vector2(-32, 2 + b), sf)
	var lg_dir  := (lg_tip - lg_base).normalized()
	var lg_perp := Vector2(-lg_dir.y, lg_dir.x)
	draw_colored_polygon(PackedVector2Array([
		lg_base + lg_perp * 3.5,
		lg_base - lg_perp * 1.5,
		lg_tip  - lg_perp * 0.4,
		lg_tip  + lg_perp * 0.4,
	]), steel)
	draw_line(lg_base + lg_perp * 3.5, lg_tip + lg_perp * 0.4, edge, 1.0)
	draw_line(lg_base + lg_perp * 1.0, lg_tip, fuller, 1.0)
	draw_line(lg_base + lg_perp * 5.5, lg_base - lg_perp * 4.0, steel, 3.0)  # crossguard
	draw_line(lg_base, lg_base - lg_dir * 9.0, Color(0.35, 0.22, 0.10), 2.5) # handle

	# ── Right blade (mirrored) ──
	var rg_base := Vector2(7, 4 + b)
	var rg_tip  := Vector2(16, -26 + b).lerp(Vector2(32, 2 + b), sf)
	var rg_dir  := (rg_tip - rg_base).normalized()
	var rg_perp := Vector2(-rg_dir.y, rg_dir.x)
	draw_colored_polygon(PackedVector2Array([
		rg_base - rg_perp * 3.5,
		rg_base + rg_perp * 1.5,
		rg_tip  + rg_perp * 0.4,
		rg_tip  - rg_perp * 0.4,
	]), steel)
	draw_line(rg_base - rg_perp * 3.5, rg_tip - rg_perp * 0.4, edge, 1.0)
	draw_line(rg_base - rg_perp * 1.0, rg_tip, fuller, 1.0)
	draw_line(rg_base - rg_perp * 5.5, rg_base + rg_perp * 4.0, steel, 3.0)
	draw_line(rg_base, rg_base - rg_dir * 9.0, Color(0.35, 0.22, 0.10), 2.5)

	# Purple eye-glow flash on attack
	if sf > 0.1:
		draw_circle(Vector2(0, -16 + b), 10 + sf * 4.0, Color(eye_c.r, eye_c.g, eye_c.b, 0.18 * sf))


# ── Axe Warrior (type 31) ────────────────────────────────────────────────────
func _draw_axe_warrior(b: float, s: bool) -> void:
	var iron   := Color(0.42, 0.40, 0.45)
	var steel  := Color(0.70, 0.72, 0.80)
	var wood   := Color(0.48, 0.28, 0.10)
	var skin   := Color(0.78, 0.55, 0.35)
	var skin_d := Color(0.62, 0.42, 0.26)
	var fur    := Color(0.55, 0.42, 0.28)
	var fur_d  := Color(0.38, 0.28, 0.16)

	# Swing fraction — arm+axe positions lerp between resting and attack
	var sf := clampf(_shoot_anim / 0.35, 0.0, 1.0)

	# Drop shadow
	draw_circle(Vector2(0, 24), 14, Color(0, 0, 0, 0.22))

	# Boots — dark leather
	draw_rect(Rect2(-10, 14 + b, 8, 10), fur_d)
	draw_rect(Rect2(  2, 14 + b, 8, 10), fur_d)

	# Fur-trimmed pants / legs
	draw_rect(Rect2(-9, 5 + b, 7, 11), fur)
	draw_rect(Rect2( 2, 5 + b, 7, 11), fur)
	draw_line(Vector2(-9, 10 + b), Vector2(-2, 10 + b), fur_d, 1.5)
	draw_line(Vector2( 2, 10 + b), Vector2( 9, 10 + b), fur_d, 1.5)

	# Bare chest — broad and muscular
	draw_rect(Rect2(-11, -8 + b, 22, 14), skin)
	# Chest muscle line
	draw_line(Vector2(0, -7 + b), Vector2(0, 5 + b), skin_d, 1.5)
	draw_line(Vector2(-8, -2 + b), Vector2(8, -2 + b), skin_d, 1.0)
	# Belly
	draw_rect(Rect2(-9, 5 + b, 18, 2), skin_d)

	# Fur mantle over shoulders (rough neck piece)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -8 + b), Vector2(13, -8 + b),
		Vector2(10,  -14 + b), Vector2(-10, -14 + b)
	]), fur)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -8 + b), Vector2(11, -8 + b),
		Vector2(8,   -13 + b), Vector2(-8, -13 + b)
	]), fur_d)

	# ── Barbarian Helmet ──
	# Iron skull cap
	draw_circle(Vector2(0, -18 + b), 9, iron)
	draw_circle(Vector2(0, -19 + b), 8, steel)
	# Helmet brow band
	draw_line(Vector2(-9, -14 + b), Vector2(9, -14 + b), iron, 3.0)
	# Nose guard
	draw_line(Vector2(0, -14 + b), Vector2(0, -10 + b), iron, 2.5)
	# Face (narrow gap on each side of nose guard)
	draw_circle(Vector2(-3, -16 + b), 2.5, skin)  # left cheek
	draw_circle(Vector2( 3, -16 + b), 2.5, skin)  # right cheek
	# Eyes — fierce dark brow + glowing pupils
	draw_line(Vector2(-6, -18 + b), Vector2(-2, -17 + b), iron, 1.5)  # left brow
	draw_line(Vector2( 2, -17 + b), Vector2( 6, -18 + b), iron, 1.5)  # right brow
	draw_circle(Vector2(-3.5, -15.5 + b), 1.2, Color(0.15, 0.05, 0.05))
	draw_circle(Vector2( 3.5, -15.5 + b), 1.2, Color(0.15, 0.05, 0.05))
	# Left horn
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9,  -18 + b),
		Vector2(-8,  -25 + b),
		Vector2(-14, -20 + b),
	]), steel)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9,  -18 + b),
		Vector2(-8,  -24 + b),
		Vector2(-13, -20 + b),
	]), Color(0.85, 0.85, 0.90))
	# Right horn
	draw_colored_polygon(PackedVector2Array([
		Vector2(9,  -18 + b),
		Vector2(8,  -25 + b),
		Vector2(14, -20 + b),
	]), steel)
	draw_colored_polygon(PackedVector2Array([
		Vector2(9,  -18 + b),
		Vector2(8,  -24 + b),
		Vector2(13, -20 + b),
	]), Color(0.85, 0.85, 0.90))

	# ── Arms & Axes ──
	# Resting: arms raised, axes up high
	# Attacking: arms sweeping outward and downward — wide barbaric swing
	var l_hand_rest   := Vector2(-18, -10 + b)
	var l_hand_attack := Vector2(-26,  10 + b)
	var l_hand := l_hand_rest.lerp(l_hand_attack, sf)

	var r_hand_rest   := Vector2(18, -10 + b)
	var r_hand_attack := Vector2(26,  10 + b)
	var r_hand := r_hand_rest.lerp(r_hand_attack, sf)

	# Arms (thick, skin colored)
	draw_line(Vector2(-11, -5 + b), l_hand, skin, 5.0)
	draw_line(Vector2( 11, -5 + b), r_hand, skin, 5.0)

	# ── Left Axe ──
	# Handle direction follows the arm swing
	var l_handle_tip  := l_hand + Vector2(-2, -14).lerp(Vector2(-4, -12), sf)
	var l_handle_butt := l_hand + Vector2(1,  8).lerp(Vector2(2, 6), sf)
	draw_line(l_handle_tip, l_handle_butt, wood, 3.0)
	# Axe blade (large crescent, left-facing)
	var lb := l_hand + Vector2(-3, -10).lerp(Vector2(-5, -8), sf)
	draw_colored_polygon(PackedVector2Array([
		lb + Vector2(-13, -8),
		lb + Vector2(-4,  -14),
		lb + Vector2(2,   -5),
		lb + Vector2(-4,  4),
		lb + Vector2(-13, 6),
	]), iron)
	draw_colored_polygon(PackedVector2Array([
		lb + Vector2(-11, -6),
		lb + Vector2(-4,  -11),
		lb + Vector2(0,   -4),
		lb + Vector2(-4,  3),
		lb + Vector2(-11, 4),
	]), steel)
	draw_line(lb + Vector2(-13, -8), lb + Vector2(-13, 6), Color(0.88, 0.90, 0.95, 0.90), 1.5)

	# ── Right Axe (mirrored) ──
	var r_handle_tip  := r_hand + Vector2(2, -14).lerp(Vector2(4, -12), sf)
	var r_handle_butt := r_hand + Vector2(-1, 8).lerp(Vector2(-2, 6), sf)
	draw_line(r_handle_tip, r_handle_butt, wood, 3.0)
	var rb := r_hand + Vector2(3, -10).lerp(Vector2(5, -8), sf)
	draw_colored_polygon(PackedVector2Array([
		rb + Vector2(13,  -8),
		rb + Vector2(4,   -14),
		rb + Vector2(-2,  -5),
		rb + Vector2(4,   4),
		rb + Vector2(13,  6),
	]), iron)
	draw_colored_polygon(PackedVector2Array([
		rb + Vector2(11,  -6),
		rb + Vector2(4,   -11),
		rb + Vector2(0,   -4),
		rb + Vector2(4,   3),
		rb + Vector2(11,  4),
	]), steel)
	draw_line(rb + Vector2(13, -8), rb + Vector2(13, 6), Color(0.88, 0.90, 0.95, 0.90), 1.5)

	# War cry flash on attack — red+green aura (blood + poison)
	if sf > 0.1:
		draw_circle(Vector2(0, -2 + b), 30, Color(0.65, 0.12, 0.12, 0.10 * sf))
		draw_circle(Vector2(0, -2 + b), 30, Color(0.15, 0.65, 0.15, 0.10 * sf))


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
	# Pulsing clock burst on attack
	if _chrono_pulse > 0.0:
		var _cp_t := clampf(_chrono_pulse / 0.45, 0.0, 1.0)
		var _cp_a := _cp_t * _cp_t   # ease-in fade
		var _cp_r := 14.0 + (1.0 - _cp_t) * 20.0   # ring expands outward
		# Outer expanding ring
		draw_arc(Vector2(0, -14 + b), _cp_r, 0, TAU, 32,
			Color(teal.r, teal.g, teal.b, _cp_a * 0.7), 2.5)
		# Inner bright ring
		draw_arc(Vector2(0, -14 + b), _cp_r * 0.7, 0, TAU, 28,
			Color(0.55, 1.00, 0.85, _cp_a * 0.5), 1.5)
		# Tick marks radiating outward like a clock burst
		for _ti in range(12):
			var _ta := _ti * TAU / 12.0
			var _tp := Vector2(cos(_ta), sin(_ta))
			draw_line(
				_tp * _cp_r + Vector2(0, -14 + b),
				_tp * (_cp_r + 6.0 * _cp_t) + Vector2(0, -14 + b),
				Color(0.60, 1.00, 0.80, _cp_a * 0.9), 1.5)
	elif s:
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
	# Arcane Overload lasers — blue + pink/magenta recolor of the arcane laser system
	if _arcane_laser_alpha > 0.0:
		var _aoa : float   = _arcane_laser_alpha
		var _src : Vector2 = Vector2(0, -6 + b)
		for _aoe in _arcane_laser_targets:
			if is_instance_valid(_aoe):
				var _le : Vector2 = _aoe.position - position
				# Outer blue-purple glow
				draw_line(_src, _le, Color(0.30, 0.15, 1.00, _aoa * 0.70), 6.5)
				# Inner hot-pink core
				draw_line(_src, _le, Color(1.00, 0.20, 0.82, _aoa * 0.90), 2.2)
				# Bright white-pink centre streak
				draw_line(_src, _le, Color(1.00, 0.75, 1.00, _aoa * 0.55), 0.8)
				# Impact circle at target
				draw_circle(_le, 7.0, Color(0.90, 0.25, 1.00, _aoa * 0.80))
		# Central burst halo at source
		draw_circle(_src, 20.0 + (1.0 - _aoa) * 10.0, Color(0.55, 0.15, 1.00, _aoa * 0.40))


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


func _draw_infernal_serpent(b: float, s: bool) -> void:
	var red  := Color(1.00, 0.30, 0.05); var drk  := Color(0.45, 0.10, 0.02)
	var gold := Color(1.00, 0.72, 0.10); var yel  := Color(1.00, 0.90, 0.20)
	# Body
	draw_colored_polygon(PackedVector2Array([Vector2(-11,-6+b),Vector2(11,-6+b),Vector2(12,10+b),Vector2(-12,10+b)]),drk)
	draw_colored_polygon(PackedVector2Array([Vector2(-9,10+b),Vector2(9,10+b),Vector2(10,22+b),Vector2(-10,22+b)]),drk.darkened(0.1))
	# Chest scales
	draw_colored_polygon(PackedVector2Array([Vector2(-8,-6+b),Vector2(8,-6+b),Vector2(7,4+b),Vector2(-7,4+b)]),red)
	# Head
	draw_circle(Vector2(0,-17+b),10,drk)
	draw_colored_polygon(PackedVector2Array([Vector2(-10,-20+b),Vector2(10,-20+b),Vector2(7,-14+b),Vector2(-7,-14+b)]),drk.lightened(0.05))
	# Horns
	draw_colored_polygon(PackedVector2Array([Vector2(-5,-26+b),Vector2(-8,-36+b),Vector2(-3,-26+b)]),gold)
	draw_colored_polygon(PackedVector2Array([Vector2(5,-26+b),Vector2(8,-36+b),Vector2(3,-26+b)]),gold)
	# Eyes
	draw_circle(Vector2(-4,-18+b),2.5,yel); draw_circle(Vector2(4,-18+b),2.5,yel)
	# Fire breath anim
	var fa : float = abs(sin(_anim_time * 5.0))
	draw_colored_polygon(PackedVector2Array([Vector2(-6,-12+b),Vector2(6,-12+b),Vector2(10+fa*8,-4+b),Vector2(-10-fa*8,-4+b)]),Color(1.0,0.55,0.05,0.85))
	if s:
		var ba := 0.5 + sin(_anim_time * 9.0) * 0.5
		draw_arc(Vector2(0,-6+b),28,0,TAU,32,Color(red.r,red.g,red.b,ba),3.5)


func _draw_shadow_weaver(bob: float, shooting: bool) -> void:
	var b        := bob
	var s        := shooting
	var in_light : bool = _sw_light_timer > 0.0

	# ── Colour palette — purple (shadow) or white (light phase) ─────────────────
	var robe   : Color = Color(0.92, 0.90, 0.98) if in_light else Color(0.28, 0.10, 0.48)
	var robe_d : Color = Color(0.72, 0.70, 0.82) if in_light else Color(0.16, 0.05, 0.30)
	var robe_l : Color = Color(1.00, 1.00, 1.00) if in_light else Color(0.45, 0.18, 0.72)
	var gold   : Color = Color(0.95, 0.92, 0.80) if in_light else Color(0.72, 0.52, 0.95)  # silver-white vs purple-trim
	var gold_d : Color = Color(0.70, 0.68, 0.58) if in_light else Color(0.48, 0.32, 0.70)
	var skin   := Color(0.94, 0.80, 0.62)
	var stf    : Color = Color(0.70, 0.68, 0.80) if in_light else Color(0.22, 0.12, 0.38)  # staff colour
	var cx     : Color = Color(0.90, 0.88, 1.00) if in_light else Color(0.72, 0.25, 1.00)  # crystal

	# ── Light-phase: outer radiant glow behind tower ─────────────────────────────
	if in_light:
		var pulse := 0.55 + sin(_anim_time * 10.0) * 0.45
		draw_circle(Vector2(0, 4 + b), 36, Color(1.0, 1.0, 0.98, 0.16 * pulse))
		draw_circle(Vector2(0, 4 + b), 22, Color(1.0, 1.0, 0.96, 0.26 * pulse))
		draw_arc(Vector2(0, 4 + b), 32, 0, TAU, 32, Color(1.0, 0.98, 0.85, 0.50 * pulse), 2.5)

	# ── Ground shadow ─────────────────────────────────────────────────────────────
	draw_circle(Vector2(0, 24), 13, Color(0, 0, 0, 0.16))

	# ── Single staff (right side) ─────────────────────────────────────────────────
	draw_line(Vector2(16, 22 + b), Vector2(19, -28 + b), stf, 4.0)
	draw_line(Vector2(16, 22 + b), Vector2(19, -28 + b), stf.lightened(0.28), 1.5)
	# Rune notches on shaft
	for ry in [-18, -8, 2, 12]:
		draw_line(Vector2(16, ry + b), Vector2(22, ry + b), gold_d, 1.0)
	# Orbiting ring on staff
	var ra1 := _anim_time * 1.5
	draw_arc(Vector2(19, -20 + b), 5, ra1, ra1 + TAU * 0.70, 12, cx, 1.5)
	# Crystal cluster at staff top
	var cg := 7.5 if not in_light else 10.0
	if in_light:
		var lp := 0.5 + sin(_anim_time * 8.0) * 0.5
		draw_circle(Vector2(19, -33 + b), cg + 8, Color(cx.r, cx.g, cx.b, 0.22 * lp))
		draw_circle(Vector2(19, -33 + b), cg + 4, Color(cx.r, cx.g, cx.b, 0.18 * lp))
	elif s:
		draw_circle(Vector2(19, -33 + b), cg + 5, Color(cx.r, cx.g, cx.b, 0.25))
	draw_circle(Vector2(19, -33 + b), cg, cx)
	draw_circle(Vector2(22, -36 + b), 3.5, cx.lightened(0.30))
	draw_circle(Vector2(16, -36 + b), 2.5, cx.lightened(0.25))
	draw_circle(Vector2(19, -28 + b), 2.0, cx.lightened(0.15))
	draw_circle(Vector2(21, -35 + b), 2.0, Color(1, 1, 1, 0.50))   # glint

	# ── Outer robe (wide, layered) ────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -10 + b), Vector2(14, -10 + b),
		Vector2(17,   24 + b), Vector2(-17, 24 + b)
	]), robe)
	# Shadow side panel
	draw_colored_polygon(PackedVector2Array([
		Vector2(5, -10 + b), Vector2(14, -10 + b),
		Vector2(17, 24 + b), Vector2( 8,  24 + b)
	]), robe_d)
	# Inner lighter front panel
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, -10 + b), Vector2(5, -10 + b),
		Vector2(6,   24 + b), Vector2(-6, 24 + b)
	]), robe_l)
	# Hem trim line
	draw_line(Vector2(-17, 19 + b), Vector2(17, 19 + b), gold, 2.0)
	draw_line(Vector2(-17, 22 + b), Vector2(17, 22 + b), gold_d, 1.0)
	# Vertical trim
	draw_line(Vector2(-5, -10 + b), Vector2(-6, 24 + b), gold_d, 1.0)
	draw_line(Vector2( 5, -10 + b), Vector2( 6, 24 + b), gold_d, 1.0)

	# ── Shoulder pauldrons ────────────────────────────────────────────────────────
	draw_circle(Vector2(-19, -7 + b), 8, robe_d)
	draw_arc(Vector2(-19, -7 + b),    8, -PI * 0.9, PI * 0.1, 10, gold, 1.5)
	draw_circle(Vector2(-19, -11 + b), 5, robe)
	draw_arc(Vector2(-19, -11 + b),    5, -PI, 0, 8, gold, 1.0)

	draw_circle(Vector2(19, -7 + b), 8, robe_d)
	draw_arc(Vector2(19, -7 + b),    8, -PI * 0.1, PI * 0.9, 10, gold, 1.5)
	draw_circle(Vector2(19, -11 + b), 5, robe)
	draw_arc(Vector2(19, -11 + b),    5, -PI, 0, 8, gold, 1.0)

	# ── Belt & accessories ────────────────────────────────────────────────────────
	draw_rect(Rect2(-13, -2 + b, 26, 5), gold_d)
	draw_rect(Rect2(-13, -2 + b, 26, 2), gold)
	draw_rect(Rect2(-4, -3 + b, 8, 7), gold)
	draw_rect(Rect2(-2, -1 + b, 4, 3), robe_d)
	# Left pouch
	draw_rect(Rect2(-17, 2 + b, 5, 7), robe_d)
	draw_line(Vector2(-17, 4 + b), Vector2(-12, 4 + b), gold_d, 1.0)
	# Right scroll case
	draw_rect(Rect2(12, 2 + b, 4, 9), Color(0.48, 0.32, 0.60) if not in_light else Color(0.72, 0.68, 0.78))
	draw_rect(Rect2(12, 2 + b, 4, 2), gold)

	# ── Arms ──────────────────────────────────────────────────────────────────────
	draw_rect(Rect2(-22, -7 + b, 10, 5), skin)   # free left arm
	draw_rect(Rect2( 12, -7 + b, 10, 5), skin)   # right arm holding staff

	# ── Head ──────────────────────────────────────────────────────────────────────
	draw_circle(Vector2(0, -17 + b), 7, skin)
	# Eyes — purple glow (shadow) or bright white-gold (light phase)
	var ge     := 0.70 + sin(_anim_time * 6.0) * 0.30
	var eye_c  : Color = Color(1.0, 0.96, 0.65, ge) if in_light else Color(0.72, 0.25, 1.00, ge)
	draw_circle(Vector2(-3, -18 + b), 1.5, eye_c)
	draw_circle(Vector2( 3, -18 + b), 1.5, eye_c)
	if in_light or s:
		draw_circle(Vector2(-3, -18 + b), 3.0, Color(eye_c.r, eye_c.g, eye_c.b, 0.40))
		draw_circle(Vector2( 3, -18 + b), 3.0, Color(eye_c.r, eye_c.g, eye_c.b, 0.40))
	# Short beard / chin
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4, -13 + b), Vector2(4, -13 + b),
		Vector2( 3,  -9 + b), Vector2(-3,  -9 + b)
	]), Color(0.80, 0.70, 0.56))

	# ── Scholar crown (flat-top, 3 points) ───────────────────────────────────────
	# Hood back piece
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -16 + b), Vector2(11, -16 + b),
		Vector2(  9, -26 + b), Vector2(-9, -26 + b)
	]), robe_d)
	# Crown band
	draw_rect(Rect2(-10, -28 + b, 20, 6), robe)
	draw_line(Vector2(-10, -28 + b), Vector2(10, -28 + b), gold, 1.5)
	draw_line(Vector2(-10, -22 + b), Vector2(10, -22 + b), gold, 1.5)
	# Crown top plate
	draw_rect(Rect2(-9, -35 + b, 18, 8), robe_d)
	draw_line(Vector2(-9, -35 + b), Vector2(9, -35 + b), gold, 2.0)
	# Three upward points
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -35 + b), Vector2(-4, -35 + b), Vector2(-6, -41 + b)
	]), gold)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2, -35 + b), Vector2( 2, -35 + b), Vector2( 0, -42 + b)
	]), gold)
	draw_colored_polygon(PackedVector2Array([
		Vector2( 4, -35 + b), Vector2( 8, -35 + b), Vector2( 6, -41 + b)
	]), gold)
	# Crystal gems in crown band — purple (shadow) or glowing white (light phase)
	draw_circle(Vector2(-6, -31 + b), 2.0, cx)
	draw_circle(Vector2( 0, -31 + b), 2.5, cx)
	draw_circle(Vector2( 6, -31 + b), 2.0, cx)
	if in_light:
		var lp2 := 0.5 + sin(_anim_time * 9.0) * 0.5
		draw_circle(Vector2(0, -31 + b), 5.5, Color(cx.r, cx.g, cx.b, 0.45 * lp2))
	for rx in [-7, -3, 3, 7]:
		draw_line(Vector2(rx, -28 + b), Vector2(rx, -26 + b), gold_d, 1.0)

	# ── Floating books (2, orbiting slowly) ──────────────────────────────────────
	for bi in range(2):
		var bang := _anim_time * 0.75 + bi * PI
		var bx   := cos(bang) * 24
		var by   := -3.0 + b + sin(bang) * 7
		var ba   := 0.92 if in_light else 0.72
		var bc   : Color = Color(0.70, 0.68, 0.80, ba) if in_light else Color(0.30, 0.14, 0.48, ba)
		draw_colored_polygon(PackedVector2Array([
			Vector2(bx - 5, by - 4), Vector2(bx + 5, by - 4),
			Vector2(bx + 5, by + 4), Vector2(bx - 5, by + 4)
		]), bc)
		draw_line(Vector2(bx - 5, by - 4), Vector2(bx - 5, by + 4),
			bc.darkened(0.3), 1.5)
		draw_circle(Vector2(bx + 3, by), 1.5, Color(gold.r, gold.g, gold.b, ba))
		if in_light or s:
			draw_rect(Rect2(bx - 4, by - 3, 8, 6), Color(cx.r, cx.g, cx.b, 0.28))
			draw_line(Vector2(bx - 3, by - 1), Vector2(bx + 3, by - 1),
				Color(cx.r, cx.g, cx.b, 0.65), 1.0)
			draw_line(Vector2(bx - 3, by + 1), Vector2(bx + 3, by + 1),
				Color(cx.r, cx.g, cx.b, 0.45), 1.0)

	# ── Orbiting runes ────────────────────────────────────────────────────────────
	var rune_spd := 2.5 if in_light else (1.2 if s else 0.8)
	for ri in range(3):
		var rang := _anim_time * rune_spd + ri * (TAU / 3.0)
		var rrx  := cos(rang) * 28
		var rry  := -1.0 + b + sin(rang) * 11
		var ra   := 0.85 if in_light else (0.70 if s else 0.40)
		var rc   := Color(cx.r, cx.g, cx.b, ra)
		draw_circle(Vector2(rrx, rry), 4.5, Color(rc.r, rc.g, rc.b, ra * 0.25))
		draw_line(Vector2(rrx - 3, rry),     Vector2(rrx + 3, rry),     rc, 1.5)
		draw_line(Vector2(rrx,     rry - 3), Vector2(rrx,     rry + 3), rc, 1.5)
		draw_line(Vector2(rrx - 2, rry - 2), Vector2(rrx + 2, rry + 2), rc, 1.0)

	# ── Shadow stack charge ring (grows toward transform) ─────────────────────────
	if not in_light and _sw_stacks > 0:
		var charge_f := float(_sw_stacks) / 10.0
		var charge_a := 0.30 + charge_f * 0.50
		draw_arc(Vector2(0, -4 + b), 26, -PI * 0.5,
				 -PI * 0.5 + TAU * charge_f, 32,
				 Color(cx.r, cx.g, cx.b, charge_a), 3.0)

	# ── Shoot burst glow on crystal ───────────────────────────────────────────────
	if s and not in_light:
		var sf := clampf(_shoot_anim / 0.25, 0.0, 1.0)
		draw_circle(Vector2(19, -33 + b), 12 * sf, Color(cx.r, cx.g, cx.b, sf * 0.45))

	# ── Light-phase: white laser beams to each target ─────────────────────────────
	if in_light and _sw_beam_alpha > 0.0:
		var ba := _sw_beam_alpha
		for _sw_bt in _sw_beam_targets:
			if not is_instance_valid(_sw_bt):
				continue
			var target_local : Vector2 = _sw_bt.position - position
			draw_line(Vector2(19, -31 + b), target_local, Color(1.0, 1.0, 0.92, ba * 0.90), 3.0)
			draw_line(Vector2(19, -31 + b), target_local, Color(0.88, 0.92, 1.0,  ba * 0.40), 7.0)
			draw_circle(target_local, 6.0 * ba, Color(1.0, 1.0, 0.82, ba * 0.70))


func _draw_natures_wrath(b: float, s: bool) -> void:
	var grn  := Color(0.22, 0.85, 0.35); var drk  := Color(0.08, 0.35, 0.12)
	var bark := Color(0.38, 0.22, 0.10); var leaf := Color(0.18, 0.72, 0.28)
	# Trunk
	draw_colored_polygon(PackedVector2Array([Vector2(-8,22+b),Vector2(8,22+b),Vector2(6,-2+b),Vector2(-6,-2+b)]),bark)
	draw_colored_polygon(PackedVector2Array([Vector2(-5,-2+b),Vector2(5,-2+b),Vector2(4,-14+b),Vector2(-4,-14+b)]),bark.lightened(0.1))
	# Root tendrils
	draw_line(Vector2(-8,18+b),Vector2(-18,28+b),drk,3.0)
	draw_line(Vector2(8,18+b),Vector2(18,28+b),drk,3.0)
	draw_line(Vector2(-6,22+b),Vector2(-14,16+b),bark,2.0)
	draw_line(Vector2(6,22+b),Vector2(14,16+b),bark,2.0)
	# Canopy
	draw_circle(Vector2(0,-20+b),16,drk)
	draw_circle(Vector2(-10,-16+b),11,leaf)
	draw_circle(Vector2(10,-16+b),11,leaf)
	draw_circle(Vector2(0,-26+b),13,grn)
	# Vine pulse
	var vp : float = abs(sin(_anim_time * 4.0))
	draw_arc(Vector2(0,-20+b),18+vp*4,0,TAU,32,Color(grn.r,grn.g,grn.b,0.6+vp*0.4),2.0)
	if s:
		var ba := 0.5 + sin(_anim_time * 6.0) * 0.5
		draw_arc(Vector2(0,-4+b),26,0,TAU,32,Color(grn.r,grn.g,grn.b,ba),3.0)


func _draw_void_titan(b: float, s: bool) -> void:
	var void2 := Color(0.18, 0.08, 0.38); var purp := Color(0.50, 0.25, 0.90)
	var dark := Color(0.08, 0.04, 0.18); var crys := Color(0.72, 0.45, 1.00)
	# Legs
	draw_colored_polygon(PackedVector2Array([Vector2(-12,6+b),Vector2(-3,6+b),Vector2(-4,22+b),Vector2(-13,22+b)]),dark)
	draw_colored_polygon(PackedVector2Array([Vector2(3,6+b),Vector2(12,6+b),Vector2(13,22+b),Vector2(4,22+b)]),dark)
	# Torso — heavy armour
	draw_colored_polygon(PackedVector2Array([Vector2(-14,-8+b),Vector2(14,-8+b),Vector2(12,8+b),Vector2(-12,8+b)]),void2)
	draw_colored_polygon(PackedVector2Array([Vector2(-10,-8+b),Vector2(10,-8+b),Vector2(9,2+b),Vector2(-9,2+b)]),purp.darkened(0.25))
	# Shoulder pads
	draw_colored_polygon(PackedVector2Array([Vector2(-14,-8+b),Vector2(-20,-4+b),Vector2(-18,4+b),Vector2(-13,2+b)]),void2.lightened(0.1))
	draw_colored_polygon(PackedVector2Array([Vector2(14,-8+b),Vector2(20,-4+b),Vector2(18,4+b),Vector2(13,2+b)]),void2.lightened(0.1))
	# Head
	draw_circle(Vector2(0,-18+b),11,dark)
	draw_colored_polygon(PackedVector2Array([Vector2(-10,-20+b),Vector2(10,-20+b),Vector2(9,-12+b),Vector2(-9,-12+b)]),dark.lightened(0.08))
	# Visor glow
	var va := 0.6 + sin(_anim_time * 7.0) * 0.4
	draw_colored_polygon(PackedVector2Array([Vector2(-7,-20+b),Vector2(7,-20+b),Vector2(6,-16+b),Vector2(-6,-16+b)]),Color(crys.r,crys.g,crys.b,va))
	# Void crystal on chest
	draw_colored_polygon(PackedVector2Array([Vector2(0,-6+b),Vector2(-5,0+b),Vector2(0,6+b),Vector2(5,0+b)]),crys)
	var pa := 0.4 + sin(_anim_time * 5.0) * 0.4
	draw_colored_polygon(PackedVector2Array([Vector2(0,-5+b),Vector2(-4,0+b),Vector2(0,5+b),Vector2(4,0+b)]),Color(1,1,1,pa))
	if s:
		var ba := 0.5 + sin(_anim_time * 6.0) * 0.5
		draw_arc(Vector2(0,-6+b),30,0,TAU,32,Color(purp.r,purp.g,purp.b,ba),3.5)


# ── Spearman (type 26) ───────────────────────────────────────────────────────
# Light infantry holding a long spear.

func _draw_spearman(bob: float, shooting: bool) -> void:
	var b      := bob
	var skin   := Color(0.94, 0.78, 0.60)
	var iron   := Color(0.55, 0.58, 0.65)
	var iron_d := Color(0.32, 0.34, 0.40)
	var iron_l := Color(0.76, 0.78, 0.86)
	var tunic  := Color(0.72, 0.18, 0.18)
	var tunic_d:= Color(0.50, 0.10, 0.10)
	var tunic_l:= Color(0.88, 0.28, 0.28)
	var pants  := Color(0.28, 0.20, 0.10)
	var boots  := Color(0.18, 0.12, 0.06)
	var belt   := Color(0.38, 0.24, 0.08)
	var gold   := Color(0.80, 0.64, 0.16)
	var shaft  := Color(0.52, 0.33, 0.12)

	draw_circle(Vector2(0, 24), 11, Color(0, 0, 0, 0.15))

	# ── Boots ─────────────────────────────────────────────────────────────────
	draw_rect(Rect2(-9, 16 + b, 8, 8), boots)
	draw_rect(Rect2( 1, 16 + b, 8, 8), boots)
	draw_line(Vector2(-9, 19 + b), Vector2(-1, 19 + b), boots.lightened(0.18), 1.0)
	draw_line(Vector2( 1, 19 + b), Vector2( 9, 19 + b), boots.lightened(0.18), 1.0)

	# ── Pants ─────────────────────────────────────────────────────────────────
	draw_rect(Rect2(-9, 4 + b, 8, 14), pants)
	draw_rect(Rect2( 1, 4 + b, 8, 14), pants)

	# ── Layered chainmail + tabard body ───────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -10 + b), Vector2(13, -10 + b),
		Vector2( 15,   6 + b), Vector2(-15,   6 + b)
	]), iron.darkened(0.1))
	draw_colored_polygon(PackedVector2Array([
		Vector2(4, -10 + b), Vector2(13, -10 + b),
		Vector2(15,  6 + b), Vector2( 7,   6 + b)
	]), iron_d)
	# Red tabard front panel
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -10 + b), Vector2(7, -10 + b),
		Vector2( 8,   6 + b), Vector2(-8,   6 + b)
	]), tunic)
	draw_colored_polygon(PackedVector2Array([
		Vector2(2, -10 + b), Vector2(7, -10 + b),
		Vector2(8,   6 + b), Vector2(4,   6 + b)
	]), tunic_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -10 + b), Vector2(-1, -10 + b),
		Vector2(-2,   6 + b), Vector2(-8,   6 + b)
	]), tunic_l)
	draw_line(Vector2(-13, -10 + b), Vector2(13, -10 + b), gold, 1.5)

	# ── Shoulder pauldrons ────────────────────────────────────────────────────
	draw_circle(Vector2(-17, -7 + b), 8, iron_d)
	draw_arc(Vector2(-17, -7 + b),    8, -PI * 0.9, PI * 0.1, 10, gold, 2.0)
	draw_circle(Vector2(-17, -11 + b), 5, iron)
	draw_circle(Vector2( 17, -7 + b), 8, iron_d)
	draw_arc(Vector2( 17, -7 + b),    8, -PI * 0.1, PI * 0.9, 10, gold, 2.0)
	draw_circle(Vector2( 17, -11 + b), 5, iron)

	# ── Belt + buckle ─────────────────────────────────────────────────────────
	draw_rect(Rect2(-13, -1 + b, 26, 5), belt)
	draw_rect(Rect2(-13, -1 + b, 26, 2), belt.lightened(0.15))
	draw_rect(Rect2(-4, -2 + b, 8, 7), gold.darkened(0.15))
	draw_rect(Rect2(-2,  0 + b, 4, 3), belt)

	# ── Arms ──────────────────────────────────────────────────────────────────
	draw_rect(Rect2(-16, -8 + b, 9, 5), skin)
	draw_rect(Rect2(  7, -8 + b, 9, 5), skin)

	# ── Head + enclosed helmet ────────────────────────────────────────────────
	draw_circle(Vector2(0, -17 + b), 7, skin)
	# Helmet bowl
	draw_rect(Rect2(-10, -24 + b, 20, 8), iron)
	draw_rect(Rect2(-10, -24 + b, 20, 8), iron_d, false, 1.5)
	# Cheek guards
	draw_rect(Rect2(-10, -18 + b, 5, 8), iron.darkened(0.1))
	draw_rect(Rect2(  5, -18 + b, 5, 8), iron.darkened(0.1))
	# Nasal guard
	draw_rect(Rect2(-2, -24 + b, 4, 12), iron_d)
	draw_line(Vector2(-2, -24 + b), Vector2(2, -24 + b), iron_l, 1.0)
	# Eye slits
	draw_rect(Rect2(-9, -22 + b, 6, 3), iron.darkened(0.5))
	draw_rect(Rect2( 3, -22 + b, 6, 3), iron.darkened(0.5))
	# Crest / ridge on top
	draw_rect(Rect2(-2, -28 + b, 4, 5), tunic)
	draw_line(Vector2(-10, -24 + b), Vector2(10, -24 + b), gold, 1.5)

	# ── Spear ─────────────────────────────────────────────────────────────────
	if shooting:
		var sw   := _shoot_anim / 0.35
		var tip  := Vector2(20.0 + sw * 20.0, -28.0 + b - sw * 4.0)
		var butt := Vector2(-6.0, 22.0 + b)
		draw_rect(Rect2(-15, -4 + b, 9, 5), skin)
		draw_rect(Rect2(  7, -10 + b, 9, 5), skin)
		draw_line(butt, tip, shaft, 4.0)
		draw_line(butt, tip, shaft.lightened(0.22), 1.2)
		# Spearhead
		draw_colored_polygon(PackedVector2Array([
			tip, tip + Vector2(-5, 6), tip + Vector2(-2, 2),
			tip + Vector2(-8, 14),   tip + Vector2(0, 10), tip + Vector2(5, 6)
		]), iron)
		draw_colored_polygon(PackedVector2Array([
			tip, tip + Vector2(-2, 2), tip + Vector2(0, 10)
		]), iron_l)
		if _hit_counter == 0:
			var fa := sw * 0.7
			draw_arc(Vector2(12, -14 + b), 16, -PI * 0.7, PI * 0.0, 10,
				Color(1.0, 0.85, 0.3, fa), 3.0)
	else:
		var shaft_top := Vector2(16.0, -38.0 + b)
		var shaft_bot := Vector2(10.0,  24.0 + b)
		draw_rect(Rect2(-14, -4 + b, 9, 5), skin)
		draw_rect(Rect2(  7,  -8 + b, 9, 5), skin)
		draw_line(shaft_bot, shaft_top, shaft, 4.0)
		draw_line(shaft_bot, shaft_top, shaft.lightened(0.22), 1.2)
		# Spearhead at top
		draw_colored_polygon(PackedVector2Array([
			shaft_top, shaft_top + Vector2(-5, 10), shaft_top + Vector2(-2, 6),
			shaft_top + Vector2(-6, 18), shaft_top + Vector2(0, 14), shaft_top + Vector2(5, 10)
		]), iron)
		draw_colored_polygon(PackedVector2Array([
			shaft_top, shaft_top + Vector2(-2, 6), shaft_top + Vector2(0, 14)
		]), iron_l)
		draw_circle(shaft_bot, 3.0, iron_d)

	# ── Spinning sweep — one full rotation over 1 second ──────────────────────
	if _spear_spin_timer > 0.0:
		# progress 0→1 as timer counts down from 1→0
		var prog  : float = 1.0 - _spear_spin_timer
		var ang   : float = prog * TAU - PI * 0.5   # start pointing up, sweep clockwise
		var r     : float = attack_range             # spear reaches to the hit-zone edge
		var alpha : float = 1.0
		# Fade in for first 10%, fade out for last 20%
		if prog < 0.10:
			alpha = prog / 0.10
		elif prog > 0.80:
			alpha = (1.0 - prog) / 0.20

		var tip_dir  := Vector2(cos(ang), sin(ang))
		var butt_dir := -tip_dir
		var tip_pt   := tip_dir  * r
		var butt_pt  := butt_dir * (r * 0.30)   # butt end 30% back from center

		# Sweep trail arc behind the tip (quarter-circle ghost)
		var trail_col := Color(iron.r, iron.g, iron.b, alpha * 0.28)
		draw_arc(Vector2.ZERO, r, ang - PI * 0.45, ang, 16, trail_col, 8.0)

		# Shaft
		draw_line(butt_pt, tip_pt, Color(shaft.r, shaft.g, shaft.b, alpha), 5.0)
		draw_line(butt_pt, tip_pt, Color(shaft.lightened(0.25).r, shaft.lightened(0.25).g, shaft.lightened(0.25).b, alpha * 0.6), 1.8)

		# Spearhead at tip (triangle pointing along ang)
		var perp   := Vector2(-tip_dir.y, tip_dir.x)
		var head_l := r * 0.22   # head length
		var head_w := r * 0.06   # head half-width
		var h0 := tip_pt
		var h1 := tip_pt - tip_dir * head_l + perp * head_w
		var h2 := tip_pt - tip_dir * head_l * 0.55
		var h3 := tip_pt - tip_dir * head_l - perp * head_w
		draw_colored_polygon(PackedVector2Array([h0, h1, h2, h3]),
			Color(iron.r, iron.g, iron.b, alpha))
		var iron_l2 := Color(0.72, 0.76, 0.88, alpha * 0.7)
		draw_colored_polygon(PackedVector2Array([h0, h2 - perp * head_w * 0.5, h2 + perp * head_w * 0.5]),
			iron_l2)

		# Butt cap
		draw_circle(butt_pt, 4.0, Color(iron_d.r, iron_d.g, iron_d.b, alpha))


# ── Rogue (type 27) ───────────────────────────────────────────────────────────
# Swift thief with a black bandana and twin daggers.

func _draw_rogue(bob: float, shooting: bool) -> void:
	var b       := bob
	var skin    := Color(0.94, 0.78, 0.60)
	var dark    := Color(0.13, 0.13, 0.17)
	var dark_d  := Color(0.08, 0.08, 0.11)
	var dark_l  := Color(0.22, 0.22, 0.30)
	var leather := Color(0.34, 0.22, 0.09)
	var leather_l:= Color(0.48, 0.32, 0.14)
	var bandana := Color(0.10, 0.10, 0.12)
	var blade   := Color(0.75, 0.80, 0.88)
	var blood   := Color(0.85, 0.15, 0.22)
	var hair    := Color(0.16, 0.12, 0.10)

	draw_circle(Vector2(0, 24), 10, Color(0, 0, 0, 0.14))

	# ── Boots ─────────────────────────────────────────────────────────────────
	draw_rect(Rect2(-9, 14 + b, 8, 10), leather.darkened(0.25))
	draw_rect(Rect2( 1, 14 + b, 8, 10), leather.darkened(0.25))
	draw_line(Vector2(-9, 18 + b), Vector2(-1, 18 + b), leather_l, 1.0)
	draw_line(Vector2( 1, 18 + b), Vector2( 9, 18 + b), leather_l, 1.0)

	# ── Legs ──────────────────────────────────────────────────────────────────
	draw_rect(Rect2(-9, 4 + b, 8, 12), dark)
	draw_rect(Rect2( 1, 4 + b, 8, 12), dark)

	# ── Layered dark leather doublet ──────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -10 + b), Vector2(13, -10 + b),
		Vector2( 14,   6 + b), Vector2(-14,   6 + b)
	]), dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(4, -10 + b), Vector2(13, -10 + b),
		Vector2(14,  6 + b), Vector2( 6,  6 + b)
	]), dark_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4, -10 + b), Vector2(4, -10 + b),
		Vector2( 5,   6 + b), Vector2(-5,  6 + b)
	]), dark_l)
	# Chest strap buckles
	draw_line(Vector2(-12, -5 + b), Vector2(12, -3 + b), leather, 1.5)
	draw_line(Vector2(-12,  0 + b), Vector2(12,  2 + b), leather, 1.5)
	draw_rect(Rect2(-2, -6 + b, 4, 9), leather.darkened(0.1))  # centre strap

	# ── Leather shoulder pieces ────────────────────────────────────────────────
	draw_circle(Vector2(-16, -7 + b), 7, leather.darkened(0.15))
	draw_arc(Vector2(-16, -7 + b),    7, -PI * 0.9, PI * 0.1, 10, leather_l, 1.5)
	draw_circle(Vector2(-16, -11 + b), 4, leather)
	draw_circle(Vector2( 16, -7 + b), 7, leather.darkened(0.15))
	draw_arc(Vector2( 16, -7 + b),    7, -PI * 0.1, PI * 0.9, 10, leather_l, 1.5)
	draw_circle(Vector2( 16, -11 + b), 4, leather)

	# ── Belt + hip pouch ──────────────────────────────────────────────────────
	draw_rect(Rect2(-13, -1 + b, 26, 5), leather)
	draw_rect(Rect2(-13, -1 + b, 26, 2), leather_l)
	draw_rect(Rect2(-3, -2 + b, 6, 7), leather.darkened(0.1))   # buckle plate
	draw_rect(Rect2(-1,  0 + b, 2, 3), dark_l)
	draw_rect(Rect2( 5,  0 + b, 8, 7), leather.darkened(0.2))   # hip pouch
	draw_line(Vector2(5, 0 + b), Vector2(13, 0 + b), leather_l, 1.0)

	# ── Arms ──────────────────────────────────────────────────────────────────
	draw_rect(Rect2(-16, -7 + b, 9, 5), skin)
	draw_rect(Rect2(  7, -7 + b, 9, 5), skin)

	# ── Head + dark hood ──────────────────────────────────────────────────────
	draw_circle(Vector2(0, -17 + b), 7, skin)
	# Dark hair
	draw_circle(Vector2(0, -23 + b), 6, hair)
	draw_rect(Rect2(-6, -23 + b, 12, 7), hair)
	# Hood draped over head
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -22 + b), Vector2(10, -22 + b),
		Vector2( 8,  -14 + b), Vector2(-8, -14 + b)
	]), dark)
	draw_circle(Vector2(0, -23 + b), 7, dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(3, -23 + b), Vector2(10, -22 + b), Vector2(7, -14 + b)
	]), dark_d)
	# Bandana across lower face
	draw_rect(Rect2(-8, -19 + b, 16, 5), bandana)
	draw_line(Vector2(-8, -14 + b), Vector2(8, -14 + b), bandana.lightened(0.10), 1.0)
	draw_circle(Vector2(8, -17 + b), 2.5, bandana.lightened(0.08))
	# Eyes (narrow, intense)
	draw_circle(Vector2(-3, -21 + b), 1.5, Color(0.85, 0.55, 0.15))
	draw_circle(Vector2( 3, -21 + b), 1.5, Color(0.85, 0.55, 0.15))
	draw_circle(Vector2(-3, -21 + b), 0.8, Color(0.18, 0.10, 0.06))
	draw_circle(Vector2( 3, -21 + b), 0.8, Color(0.18, 0.10, 0.06))

	# ── Swords — alternate per attack (_alt_hand) ─────────────────────────────
	var right_swings := shooting and not _alt_hand
	var left_swings  := shooting and _alt_hand

	# Right-hand short blade
	if right_swings:
		var sw  := _shoot_anim / 0.35
		var tip := Vector2(14.0 + sw * 20.0, -18.0 + b - sw * 14.0)
		draw_rect(Rect2(7, -6 + b, 8, 4), skin)
		draw_line(Vector2(6, -8 + b), Vector2(20, -8 + b), leather, 3.0)  # crossguard
		draw_line(Vector2(13, -4 + b), tip, blade, 4.0)
		draw_line(Vector2(13, -4 + b), tip, Color(1, 1, 1, 0.55), 1.5)
		var ba := sw * 0.8
		draw_arc(Vector2(10, -8 + b), 14, -PI * 0.55, PI * 0.05, 10,
			Color(1.0, 1.0, 1.0, ba * 0.9), 4.0)
		draw_arc(Vector2(10, -8 + b), 14, -PI * 0.55, PI * 0.05, 10,
			Color(blood.r, blood.g, blood.b, ba * 0.45), 2.5)
	else:
		draw_rect(Rect2(7, -6 + b, 8, 4), skin)
		draw_line(Vector2(14, 8 + b), Vector2(18, -18 + b), blade, 4.0)
		draw_line(Vector2(14, 8 + b), Vector2(18, -18 + b), Color(1, 1, 1, 0.35), 1.5)
		draw_line(Vector2(8, 6 + b), Vector2(22, 6 + b), leather, 3.0)   # guard at hip

	# Left-hand short blade
	if left_swings:
		var sw  := _shoot_anim / 0.35
		var tip := Vector2(-14.0 - sw * 20.0, -18.0 + b - sw * 14.0)
		draw_rect(Rect2(-16, -2 + b, 8, 4), skin)
		draw_line(Vector2(-20, -5 + b), Vector2(-8, -5 + b), leather, 3.0)
		draw_line(Vector2(-14, 0 + b), tip, blade, 4.0)
		draw_line(Vector2(-14, 0 + b), tip, Color(1, 1, 1, 0.55), 1.5)
		var ba := sw * 0.8
		draw_arc(Vector2(-10, -8 + b), 14, PI - PI * 0.05, PI + PI * 0.55, 10,
			Color(1.0, 1.0, 1.0, ba * 0.9), 4.0)
		draw_arc(Vector2(-10, -8 + b), 14, PI - PI * 0.05, PI + PI * 0.55, 10,
			Color(blood.r, blood.g, blood.b, ba * 0.45), 2.5)
	else:
		draw_rect(Rect2(-16, -2 + b, 8, 4), skin)
		draw_line(Vector2(-14, 4 + b), Vector2(-18, -18 + b), blade, 4.0)
		draw_line(Vector2(-14, 4 + b), Vector2(-18, -18 + b), Color(1, 1, 1, 0.35), 1.5)
		draw_line(Vector2(-22, 2 + b), Vector2(-8, 2 + b), leather, 3.0)

	# ── Bleed stack indicator ─────────────────────────────────────────────────
	var stack_count : int = 0
	for e in _bleed_stacks.keys():
		if is_instance_valid(e):
			stack_count = max(stack_count, _bleed_stacks[e].get("stacks", 0))
	if stack_count > 0:
		var ga := 0.4 + sin(_anim_time * 6.0) * 0.2
		draw_circle(Vector2(16, -10 + b), 3.0 + stack_count * 1.2,
			Color(blood.r, blood.g, blood.b, ga))


# ── Elite Knight (type 28) ────────────────────────────────────────────────────
# Heavy plate champion with a great-sword and tower shield.

func _draw_elite_knight(bob: float, shooting: bool) -> void:
	var b       := bob
	var steel   := Color(0.22, 0.38, 0.72)   # blue armour
	var steel_d := Color(0.12, 0.22, 0.48)
	var gold    := Color(0.95, 0.82, 0.22)
	var crimson := Color(0.80, 0.12, 0.14)
	var leather := Color(0.38, 0.22, 0.10)

	draw_circle(Vector2(0, 24), 13, Color(0, 0, 0, 0.18))

	# Cape
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -4 + b), Vector2(10, -4 + b),
		Vector2(14,  22 + b), Vector2(-14, 22 + b)
	]), crimson)

	# Greaves
	draw_rect(Rect2(-11, 12 + b, 10, 12), steel_d)
	draw_rect(Rect2(  1, 12 + b, 10, 12), steel_d)
	draw_rect(Rect2(-11, 4 + b, 10, 10), steel)
	draw_rect(Rect2(-11, 4 + b, 10, 10), steel_d, false, 1.5)
	draw_rect(Rect2(  1, 4 + b, 10, 10), steel)
	draw_rect(Rect2(  1, 4 + b, 10, 10), steel_d, false, 1.5)

	# Breastplate
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -10 + b), Vector2(13, -10 + b),
		Vector2( 11,   6 + b), Vector2(-11,   6 + b)
	]), steel)
	draw_polyline(PackedVector2Array([
		Vector2(-13, -10 + b), Vector2(13, -10 + b),
		Vector2( 11,   6 + b), Vector2(-11,   6 + b), Vector2(-13, -10 + b)
	]), steel_d, 2.5)
	draw_line(Vector2(0, -10 + b), Vector2(0, 6 + b), steel_d, 1.5)
	draw_line(Vector2(-13, -10 + b), Vector2(13, -10 + b), gold, 3.0)

	# Pauldrons
	draw_circle(Vector2(-17, -7 + b), 9, steel)
	draw_circle(Vector2(-17, -7 + b), 9, steel_d, false, 2.5)
	draw_circle(Vector2( 17, -7 + b), 9, steel)
	draw_circle(Vector2( 17, -7 + b), 9, steel_d, false, 2.5)
	draw_arc(Vector2(-17, -7 + b), 9, -PI * 0.9, PI * 0.1, 10, gold, 2.0)
	draw_arc(Vector2( 17, -7 + b), 9, -PI * 0.1, PI * 0.9, 10, gold, 2.0)

	# Plumed helmet
	draw_circle(Vector2(0, -20 + b), 10, steel)
	draw_circle(Vector2(0, -20 + b), 10, steel_d, false, 2.0)
	draw_rect(Rect2(-10, -24 + b, 20, 6), steel_d)
	draw_rect(Rect2(-8,  -23 + b,  6, 4), steel.darkened(0.6))
	draw_rect(Rect2( 2,  -23 + b,  6, 4), steel.darkened(0.6))
	draw_rect(Rect2(-3, -32 + b, 6, 14), steel)
	draw_rect(Rect2(-3, -32 + b, 6, 14), steel_d, false, 1.5)
	draw_rect(Rect2(-4, -38 + b, 8, 10), crimson)
	draw_rect(Rect2(-3, -40 + b, 6,  7), crimson.lightened(0.3))
	draw_line(Vector2(-10, -17 + b), Vector2(10, -17 + b), gold, 2.5)

	# Great-sword arm (right)
	if shooting:
		var sw := _shoot_anim / 0.35
		# Wide overhead slam sweep
		var sweep_ang := -PI * 0.5 + sw * PI * 0.8
		var tip := Vector2(cos(sweep_ang), sin(sweep_ang)) * 36 + Vector2(0, -10 + b)
		draw_rect(Rect2(14, -8 + b, 7, 6), steel)
		draw_line(Vector2(17, -6 + b), tip, steel, 6.0)
		draw_line(Vector2(17, -6 + b), tip, steel.lightened(0.35), 2.0)
		draw_rect(Rect2(10, -14 + b, 18, 5), gold)
		draw_circle(tip, 5, Color(gold.r, gold.g, gold.b, sw * 0.6))
		# Blue circle on cleave hit (3rd attack)
		if _hit_counter == 0:
			draw_arc(Vector2.ZERO, 28 + sw * 8, 0.0, TAU, 32,
				Color(0.35, 0.65, 1.0, sw * 0.85), 5.0)
	else:
		draw_rect(Rect2(14, -6 + b, 7, 6), steel)
		# Great-sword upright at rest
		draw_rect(Rect2(16, -38 + b, 7, 44), steel)
		draw_rect(Rect2(16, -38 + b, 7, 44), steel_d, false, 1.8)
		draw_line(Vector2(19, -38 + b), Vector2(19, 6 + b), Color(0.88, 0.92, 1.0, 0.55), 2.0)
		draw_rect(Rect2(8,  -4 + b, 22, 6), gold)
		draw_rect(Rect2(18,  2 + b,  6, 14), leather)
		draw_circle(Vector2(21, 16 + b), 5, gold)


# ── Iron Guard (type 29) ─────────────────────────────────────────────────────
# Shield (left) + Sword (right). 3-hit combo: hit1/3 sword swing, hit2 shield thrust, hit3 AOE.

func _draw_iron_guard(bob: float, shooting: bool) -> void:
	var b      := bob
	var steel  := Color(0.55, 0.58, 0.65)
	var steel_d:= Color(0.32, 0.34, 0.42)
	var steel_l:= Color(0.78, 0.80, 0.88)
	var boots  := Color(0.18, 0.12, 0.06)
	var leather:= Color(0.35, 0.22, 0.08)
	var gold   := Color(0.90, 0.76, 0.20)
	var red    := Color(0.88, 0.16, 0.10)
	var sh_dia := Color(0.82, 0.84, 0.92)    # shield diamond (neutral)

	var right_charged := _hit_counter >= 1
	var left_charged  := _hit_counter >= 2
	var anim        := clampf(_shoot_anim / 0.35, 0.0, 1.0) if shooting else 0.0
	var is_slam     := shooting and _hit_counter == 0
	var right_thrust := shooting and (_hit_counter == 1 or is_slam)
	var left_thrust  := shooting and (_hit_counter == 2 or is_slam)

	draw_circle(Vector2(0, 24), 13, Color(0, 0, 0, 0.18))

	# ── Boots ─────────────────────────────────────────────────────────────────
	draw_rect(Rect2(-11, 14 + b, 10, 10), steel_d)
	draw_rect(Rect2(  1, 14 + b, 10, 10), steel_d)
	draw_line(Vector2(-11, 18 + b), Vector2(-1, 18 + b), steel_l, 1.0)
	draw_line(Vector2(  1, 18 + b), Vector2(11, 18 + b), steel_l, 1.0)

	# ── Greaved legs ──────────────────────────────────────────────────────────
	draw_rect(Rect2(-11, 4 + b, 10, 12), steel)
	draw_rect(Rect2(-11, 4 + b, 10, 12), steel_d, false, 1.5)
	draw_rect(Rect2(  1, 4 + b, 10, 12), steel)
	draw_rect(Rect2(  1, 4 + b, 10, 12), steel_d, false, 1.5)

	# ── Plate body ────────────────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -10 + b), Vector2(13, -10 + b),
		Vector2( 14,   6 + b), Vector2(-14,   6 + b)
	]), steel)
	draw_colored_polygon(PackedVector2Array([
		Vector2(4, -10 + b), Vector2(13, -10 + b),
		Vector2(14,  6 + b), Vector2( 6,  6 + b)
	]), steel_d)
	draw_line(Vector2(0, -10 + b), Vector2(0, 5 + b), steel_l, 1.5)
	draw_line(Vector2(-13, -10 + b), Vector2(13, -10 + b), gold, 2.5)

	# ── Pauldrons ─────────────────────────────────────────────────────────────
	draw_circle(Vector2(-19, -7 + b), 9, steel_d)
	draw_arc(Vector2(-19, -7 + b),    9, -PI * 0.9, PI * 0.1, 10, gold, 2.0)
	draw_circle(Vector2(-19, -11 + b), 6, steel)
	draw_circle(Vector2( 19, -7 + b), 9, steel_d)
	draw_arc(Vector2( 19, -7 + b),    9, -PI * 0.1, PI * 0.9, 10, gold, 2.0)
	draw_circle(Vector2( 19, -11 + b), 6, steel)

	# ── Belt ──────────────────────────────────────────────────────────────────
	draw_rect(Rect2(-12, -1 + b, 24, 5), leather)
	draw_rect(Rect2(-12, -1 + b, 24, 2), leather.lightened(0.2))
	draw_rect(Rect2(-4, -2 + b, 8, 7), gold)
	draw_rect(Rect2(-2,  0 + b, 4, 3), leather)

	# ── Arms ──────────────────────────────────────────────────────────────────
	draw_rect(Rect2(-22, -8 + b, 10, 5), Color(0.88, 0.72, 0.56))
	draw_rect(Rect2( 12, -8 + b, 10, 5), Color(0.88, 0.72, 0.56))

	# ── Full-face helmet with gray plume ──────────────────────────────────────
	draw_circle(Vector2(0, -18 + b), 10, steel)
	draw_circle(Vector2(0, -18 + b), 10, steel_d, false, 2.0)
	draw_rect(Rect2(-10, -22 + b, 20, 7), steel_d)
	draw_rect(Rect2(-8, -22 + b, 5, 5), steel.darkened(0.55))
	draw_rect(Rect2( 3, -22 + b, 5, 5), steel.darkened(0.55))
	draw_rect(Rect2(-3, -30 + b, 6, 13), steel)
	draw_rect(Rect2(-3, -30 + b, 6, 13), steel_d, false, 1.5)
	draw_rect(Rect2(-4, -36 + b, 8,  9), steel_d)
	draw_rect(Rect2(-3, -38 + b, 6,  7), steel_l)
	draw_line(Vector2(-10, -22 + b), Vector2(10, -22 + b), gold, 2.0)

	# ── Left heater shield (thrusts on hit2 and AOE slam) ─────────────────────
	var left_off     := anim * 8.0 if left_thrust else 0.0
	var lx           := -left_off
	var sh_l_col     := red if left_charged else steel
	var sh_l_diamond := red.lightened(0.4) if left_charged else sh_dia
	var sh_l := PackedVector2Array([
		Vector2(-26 + lx, -10 + b), Vector2(-13 + lx, -10 + b),
		Vector2(-13 + lx,   6 + b), Vector2(-19 + lx,  14 + b), Vector2(-26 + lx,  6 + b)
	])
	draw_colored_polygon(sh_l, sh_l_col)
	draw_polyline(sh_l + PackedVector2Array([sh_l[0]]), steel_d, 2.0)
	draw_line(Vector2(-19 + lx, -6 + b), Vector2(-19 + lx, 12 + b), gold, 2.0)
	draw_line(Vector2(-26 + lx,  0 + b), Vector2(-13 + lx,  0 + b), gold, 2.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-19 + lx, -6 + b), Vector2(-16 + lx, -2 + b),
		Vector2(-19 + lx,  2 + b), Vector2(-22 + lx, -2 + b)
	]), sh_l_diamond)
	if left_charged:
		draw_polyline(sh_l + PackedVector2Array([sh_l[0]]), Color(red.r, red.g, red.b, 0.45), 4.0)

	# ── Right heater shield (thrusts on hit1 and AOE slam) ────────────────────
	var right_off    := anim * 8.0 if right_thrust else 0.0
	var rx           := right_off
	var sh_r_col     := red if right_charged else steel
	var sh_r_diamond := red.lightened(0.4) if right_charged else sh_dia
	var sh_r := PackedVector2Array([
		Vector2(13 + rx, -10 + b), Vector2(26 + rx, -10 + b),
		Vector2(26 + rx,   6 + b), Vector2(20 + rx,  14 + b), Vector2(13 + rx,  6 + b)
	])
	draw_colored_polygon(sh_r, sh_r_col)
	draw_polyline(sh_r + PackedVector2Array([sh_r[0]]), steel_d, 2.0)
	draw_line(Vector2(20 + rx, -6 + b), Vector2(20 + rx, 12 + b), gold, 2.0)
	draw_line(Vector2(13 + rx,  0 + b), Vector2(26 + rx,  0 + b), gold, 2.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(20 + rx, -6 + b), Vector2(23 + rx, -2 + b),
		Vector2(20 + rx,  2 + b), Vector2(17 + rx, -2 + b)
	]), sh_r_diamond)
	if right_charged:
		draw_polyline(sh_r + PackedVector2Array([sh_r[0]]), Color(red.r, red.g, red.b, 0.45), 4.0)

	# ── AOE slam flash (every 3rd hit) ────────────────────────────────────────
	if is_slam:
		draw_arc(Vector2.ZERO, attack_range * 0.75, -PI, PI, 48,
			Color(red.r, red.g, red.b, anim * 0.65), 5.0)


# ── Hero Paladin (type 50) ────────────────────────────────────────────────────
# Holy armored warrior — warhammer + kite shield, colour-shifted by tower_color.

func _draw_hero_paladin(bob: float, shooting: bool) -> void:
	var b      := bob
	var tc     := tower_color
	var tc_d   := tc.darkened(0.35)
	var tc_l   := tc.lightened(0.20)
	var gold   := Color(0.90, 0.78, 0.22)
	var white  := Color(0.95, 0.92, 0.85)
	var s      := shooting

	draw_circle(Vector2(0, 24), 13, Color(0, 0, 0, 0.18))

	# Legs (wide stance)
	draw_rect(Rect2(-12, 12 + b, 11, 12), tc_d)
	draw_rect(Rect2(  1, 12 + b, 11, 12), tc_d)

	# Holy tabard over torso
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -8 + b), Vector2(12, -8 + b),
		Vector2(14,  14 + b), Vector2(-14, 14 + b)
	]), white)
	draw_line(Vector2(0, -8 + b), Vector2(0, 14 + b), gold, 2.0)
	draw_line(Vector2(-14, 4 + b), Vector2(14, 4 + b), gold, 1.5)

	# Breastplate over tabard
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -10 + b), Vector2(14, -10 + b),
		Vector2(12,  -2 + b), Vector2(-12,  -2 + b)
	]), tc)
	draw_line(Vector2(-14, -10 + b), Vector2(14, -10 + b), gold, 2.5)

	# Pauldrons (bigger than knight's)
	draw_circle(Vector2(-18, -8 + b), 10, tc)
	draw_circle(Vector2(-18, -8 + b), 10, tc_d, false, 2.5)
	draw_arc(Vector2(-18, -8 + b), 10, -PI * 0.9, PI * 0.1, 10, gold, 2.0)
	draw_circle(Vector2( 18, -8 + b), 10, tc)
	draw_circle(Vector2( 18, -8 + b), 10, tc_d, false, 2.5)
	draw_arc(Vector2( 18, -8 + b), 10, -PI * 0.1, PI * 0.9, 10, gold, 2.0)

	# Full visor helm (no plume — distinguishes from knight)
	draw_circle(Vector2(0, -20 + b), 11, tc)
	draw_circle(Vector2(0, -20 + b), 11, tc_d, false, 2.0)
	draw_rect(Rect2(-10, -25 + b, 20, 7), tc_d)   # visor band
	draw_rect(Rect2(-6,  -24 + b, 12, 5), tc.darkened(0.65))  # visor slit dark
	draw_line(Vector2(-10, -25 + b), Vector2(10, -25 + b), gold, 2.0)
	draw_line(Vector2(-10, -18 + b), Vector2(10, -18 + b), gold, 1.5)
	# Cross on forehead
	draw_line(Vector2(0, -30 + b), Vector2(0, -24 + b), gold, 2.0)
	draw_line(Vector2(-4, -27 + b), Vector2(4, -27 + b), gold, 2.0)

	# Kite shield (left)
	var sh := PackedVector2Array([
		Vector2(-32, -16 + b), Vector2(-16, -16 + b),
		Vector2(-16,   8 + b), Vector2(-24,  20 + b), Vector2(-32,  8 + b)
	])
	draw_colored_polygon(sh, tc_l)
	draw_polyline(sh + PackedVector2Array([sh[0]]), gold, 2.0)
	draw_line(Vector2(-24, -16 + b), Vector2(-24, 20 + b), gold, 1.5)
	draw_line(Vector2(-32,  -4 + b), Vector2(-16, -4 + b), gold, 1.5)

	# Warhammer (right) — swings on attack
	if s:
		var sw  := _shoot_anim / 0.35
		var ang := -PI * 0.3 + sw * PI * 0.85
		var hx  := 14.0 + cos(ang) * 28
		var hy  := -6.0 + b + sin(ang) * 28
		draw_rect(Rect2(12, -6 + b, 5, 5), Color(0.88, 0.72, 0.56))   # hand
		draw_line(Vector2(14, -4 + b), Vector2(hx, hy), tc.darkened(0.1), 5.0)
		draw_rect(Rect2(hx - 8, hy - 9, 16, 12), tc)                  # head
		draw_rect(Rect2(hx - 8, hy - 9, 16, 12), tc_d, false, 1.5)
		draw_line(Vector2(hx - 8, hy - 9), Vector2(hx + 8, hy - 9), gold, 1.5)
		if sw > 0.4:
			draw_arc(Vector2(14, -4 + b), 28, ang - 0.6, ang, 8,
				Color(gold.r, gold.g, gold.b, sw * 0.65), 5.0)
	else:
		draw_rect(Rect2(12, -6 + b, 5, 5), Color(0.88, 0.72, 0.56))
		draw_line(Vector2(15, -4 + b), Vector2(19, -34 + b), tc.darkened(0.1), 5.0)
		draw_rect(Rect2(11, -38 + b, 17, 12), tc)   # hammerhead at rest
		draw_rect(Rect2(11, -38 + b, 17, 12), tc_d, false, 1.5)
		draw_line(Vector2(11, -38 + b), Vector2(28, -38 + b), gold, 1.5)
		draw_line(Vector2(11, -26 + b), Vector2(28, -26 + b), gold, 1.5)


# ── Hero Dagger (type 51) ─────────────────────────────────────────────────────
# Hooded dagger assassin — twin short blades, deep cowl, tower_color cloak.

func _draw_hero_dagger(bob: float, shooting: bool) -> void:
	var b      := bob
	var tc     := tower_color
	var tc_d   := tc.darkened(0.40)
	var silver := Color(0.80, 0.84, 0.90)
	var skin   := Color(0.94, 0.78, 0.60)
	var wrap   := tc.lightened(0.10)
	var s      := shooting
	# Blade glow: right blade red after 1st hit, left blade red after 2nd hit (combo buildup)
	# Left blade swings on hit 1 (alt_hand=true), right on hit 2 — glow matches the swinging blade
	var blade_l := Color(0.88, 0.10, 0.10) if _hit_counter >= 1 else silver
	var blade_r := Color(0.88, 0.10, 0.10) if _hit_counter >= 2 else silver

	draw_circle(Vector2(0, 24), 10, Color(0, 0, 0, 0.14))

	# Boots
	draw_rect(Rect2(-9, 14 + b, 8, 10), tc_d)
	draw_rect(Rect2( 1, 14 + b, 8, 10), tc_d)

	# Legs
	draw_rect(Rect2(-9, 4 + b, 8, 12), tc_d)
	draw_rect(Rect2( 1, 4 + b, 8, 12), tc_d)

	# Cloak body
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -8 + b), Vector2(12, -8 + b),
		Vector2(15,  22 + b), Vector2(-15, 22 + b)
	]), tc)
	draw_colored_polygon(PackedVector2Array([
		Vector2(4, -8 + b), Vector2(12, -8 + b),
		Vector2(15, 22 + b), Vector2( 7, 22 + b)
	]), tc_d)

	# Belt with dagger sheaths
	draw_rect(Rect2(-13, 4 + b, 26, 4), tc.darkened(0.2))
	draw_rect(Rect2(-7, 4 + b, 4, 8), silver.darkened(0.3))   # left sheath
	draw_rect(Rect2( 3, 4 + b, 4, 8), silver.darkened(0.3))   # right sheath

	# Arms
	draw_rect(Rect2(-17, -5 + b, 9, 5), skin)
	draw_rect(Rect2(  8, -5 + b, 9, 5), skin)

	# Face — partially hidden by deep hood
	draw_circle(Vector2(0, -17 + b), 7, skin)
	# Shadow inside hood
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -18 + b), Vector2(8, -18 + b),
		Vector2(6,  -12 + b), Vector2(-6, -12 + b)
	]), Color(0, 0, 0, 0.35))
	# Eyes only
	draw_circle(Vector2(-3, -18 + b), 1.5, Color(0.85, 0.15, 0.15))
	draw_circle(Vector2( 3, -18 + b), 1.5, Color(0.85, 0.15, 0.15))

	# Deep hood (cowl — wider and lower than rogue's)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -12 + b), Vector2(14, -12 + b),
		Vector2( 11, -24 + b), Vector2(-11, -24 + b)
	]), tc)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -24 + b), Vector2(10, -24 + b),
		Vector2(  6, -36 + b), Vector2(-6, -36 + b)
	]), tc)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, -36 + b), Vector2(5, -36 + b),
		Vector2( 1, -44 + b), Vector2(-1, -44 + b)
	]), tc)
	# Hood shadow crease
	draw_arc(Vector2(0, -20 + b), 9, -PI * 0.7, PI * 0.7, 12, tc_d, 2.5)

	# Daggers — short blades; alternate hands on attack
	var r_swing := s and (not _alt_hand or _dual_swing)
	var l_swing := s and (_alt_hand or _dual_swing)

	if r_swing:
		var sw  := _shoot_anim / 0.35
		var tip := Vector2(14 + sw * 14, -16 + b - sw * 18)
		draw_rect(Rect2(8, -4 + b, 7, 4), skin)
		draw_rect(Rect2(8, -6 + b, 10, 2), wrap)   # crossguard
		draw_line(Vector2(12, -2 + b), tip, blade_r, 3.5)
		draw_line(Vector2(12, -2 + b), tip, Color(1, 1, 1, 0.5), 1.0)
		draw_arc(Vector2(10, -6 + b), 12, -PI * 0.5, PI * 0.1, 8,
			Color(1, 1, 1, sw * 0.8), 3.0)
	else:
		draw_rect(Rect2(8, -4 + b, 7, 4), skin)
		draw_line(Vector2(13, 6 + b), Vector2(17, -14 + b), blade_r, 3.5)
		draw_line(Vector2(13, 6 + b), Vector2(17, -14 + b), Color(1, 1, 1, 0.3), 1.0)
		draw_rect(Rect2(8, 4 + b, 10, 3), wrap)

	if l_swing:
		var sw  := _shoot_anim / 0.35
		var tip := Vector2(-14 - sw * 14, -16 + b - sw * 18)
		draw_rect(Rect2(-16, -1 + b, 7, 4), skin)
		draw_rect(Rect2(-18, -3 + b, 10, 2), wrap)
		draw_line(Vector2(-12, 0 + b), tip, blade_l, 3.5)
		draw_line(Vector2(-12, 0 + b), tip, Color(1, 1, 1, 0.5), 1.0)
		draw_arc(Vector2(-10, -6 + b), 12, PI - PI * 0.1, PI + PI * 0.5, 8,
			Color(1, 1, 1, sw * 0.8), 3.0)
	else:
		draw_rect(Rect2(-16, -1 + b, 7, 4), skin)
		draw_line(Vector2(-14, 4 + b), Vector2(-18, -14 + b), blade_l, 3.5)
		draw_line(Vector2(-14, 4 + b), Vector2(-18, -14 + b), Color(1, 1, 1, 0.3), 1.0)
		draw_rect(Rect2(-19, 2 + b, 10, 3), wrap)


# ── Hero Warlock (type 52) ────────────────────────────────────────────────────
# Dark spellcaster — curved staff, large orb, tall hood with rune trim.

func _draw_hero_warlock(bob: float, shooting: bool) -> void:
	var b      := bob
	var tc     := tower_color
	var tc_d   := tc.darkened(0.45)
	var tc_l   := tc.lightened(0.35)
	var skin   := Color(0.80, 0.68, 0.55)
	var staff  := Color(0.20, 0.14, 0.08)
	var orb_c  := tc_l if not shooting else Color(1.0, 1.0, 1.0)
	var trim   := tc.lightened(0.18)
	var s      := shooting

	draw_circle(Vector2(0, 24), 11, Color(0, 0, 0, 0.15))

	# Long narrow robe (taller/thinner than mage)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -10 + b), Vector2(7, -10 + b),
		Vector2(11,  24 + b), Vector2(-11, 24 + b)
	]), tc_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(2, -10 + b), Vector2(7, -10 + b),
		Vector2(11, 24 + b), Vector2(5,  24 + b)
	]), tc.darkened(0.60))
	# Rune trim at hem
	draw_line(Vector2(-11, 18 + b), Vector2(11, 18 + b), trim, 1.5)
	for rx in [-8, -4, 0, 4, 8]:
		draw_line(Vector2(rx, 18 + b), Vector2(rx, 22 + b), trim, 1.0)

	# Belt sash
	draw_rect(Rect2(-8, -2 + b, 16, 4), tc.darkened(0.25))

	# Face (gaunt, sallow)
	draw_circle(Vector2(0, -18 + b), 7, skin)
	# Glowing eyes
	var eye_c := tc_l if not shooting else Color(1, 1, 0.8)
	draw_circle(Vector2(-3, -19 + b), 2.0, eye_c)
	draw_circle(Vector2( 3, -19 + b), 2.0, eye_c)
	if shooting:
		draw_circle(Vector2(-3, -19 + b), 3.5, Color(eye_c.r, eye_c.g, eye_c.b, 0.4))
		draw_circle(Vector2( 3, -19 + b), 3.5, Color(eye_c.r, eye_c.g, eye_c.b, 0.4))

	# Tall narrow hood with angular folds
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -22 + b), Vector2(10, -22 + b),
		Vector2(7,   -30 + b), Vector2(-7, -30 + b)
	]), tc_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -30 + b), Vector2(6, -30 + b),
		Vector2(3,  -42 + b), Vector2(-3, -42 + b)
	]), tc_d)
	# Angular hood sides
	draw_line(Vector2(-6, -30 + b), Vector2(-3, -42 + b), trim, 1.5)
	draw_line(Vector2( 6, -30 + b), Vector2( 3, -42 + b), trim, 1.5)
	draw_line(Vector2(-10, -22 + b), Vector2(10, -22 + b), trim, 1.5)
	# Rune mark on hood
	draw_circle(Vector2(0, -35 + b), 2.5, trim)
	draw_line(Vector2(-3, -35 + b), Vector2(3, -35 + b), trim, 1.0)

	# Right arm reaching out
	draw_rect(Rect2(8, -8 + b, 10, 5), skin)

	# Curved staff (left side, angled outward)
	draw_line(Vector2(-16, 20 + b), Vector2(-20, -18 + b), staff, 5.0)
	draw_line(Vector2(-16, 20 + b), Vector2(-20, -18 + b), staff.lightened(0.2), 1.5)
	draw_arc(Vector2(-25, -18 + b), 8, -PI * 0.5, PI * 0.25, 12, staff, 5.0)
	draw_rect(Rect2(-16, -8 + b, 10, 5), skin)   # hand on staff

	# Large orb at staff tip
	var orb_r := 8.5 if not s else 10.5
	if s:
		# Pulsing glow halo
		var pulse := 0.5 + sin(_anim_time * 8.0) * 0.3
		draw_circle(Vector2(-25, -26 + b), orb_r + 7, Color(tc.r, tc.g, tc.b, pulse * 0.35))
		draw_circle(Vector2(-25, -26 + b), orb_r + 3, Color(tc.r, tc.g, tc.b, pulse * 0.25))
		# Orbiting sparks
		for i in range(4):
			var ang := i * PI * 0.5 + _anim_time * 4.0
			var sp  := Vector2(-25 + cos(ang) * 14, -26 + b + sin(ang) * 14)
			draw_circle(sp, 2.5, Color(tc_l.r, tc_l.g, tc_l.b, 0.85))
	draw_circle(Vector2(-25, -26 + b), orb_r, tc)
	draw_circle(Vector2(-25, -26 + b), orb_r, tc_d, false, 1.5)
	draw_circle(Vector2(-27, -28 + b), orb_r * 0.35, Color(1, 1, 1, 0.45))   # glint

	# Floating rune shard (orbits at right side when shooting)
	if s:
		var fang := _anim_time * 2.5
		var fx   := 18 + cos(fang) * 10
		var fy   := -10 + b + sin(fang) * 10
		draw_colored_polygon(PackedVector2Array([
			Vector2(fx,     fy - 8), Vector2(fx + 6, fy - 2),
			Vector2(fx + 3, fy + 4), Vector2(fx - 3, fy + 4), Vector2(fx - 6, fy - 2)
		]), tc)
		draw_polyline(PackedVector2Array([
			Vector2(fx,     fy - 8), Vector2(fx + 6, fy - 2),
			Vector2(fx + 3, fy + 4), Vector2(fx - 3, fy + 4),
			Vector2(fx - 6, fy - 2), Vector2(fx, fy - 8)
		]), tc_l, 1.5)


# ── Hero Arcane Scholar (type 53) ────────────────────────────────────────────
# Crimson-robed dual-staff arcane master. Scholar crown, floating books,
# orbiting runes, gold trim, blue crystal staffs.

func _draw_hero_arcane_scholar(bob: float, shooting: bool) -> void:
	var b      := bob
	var robe   := Color(0.62, 0.10, 0.14)   # deep crimson
	var robe_d := Color(0.38, 0.06, 0.08)   # crimson shadow
	var robe_l := Color(0.80, 0.22, 0.24)   # crimson highlight
	var gold   := Color(0.90, 0.72, 0.16)   # gold trim
	var gold_d := Color(0.60, 0.46, 0.08)   # darker gold
	var skin   := Color(0.94, 0.80, 0.62)
	var stf    := Color(0.28, 0.18, 0.07)   # dark staff wood
	var cx     := Color(0.28, 0.72, 1.00) if not shooting else Color(0.65, 0.92, 1.00)
	var s      := shooting

	# ── Shadow ───────────────────────────────────────────────────────────────────
	draw_circle(Vector2(0, 24), 14, Color(0, 0, 0, 0.18))

	# ── Left staff ───────────────────────────────────────────────────────────────
	draw_line(Vector2(-18, 22 + b), Vector2(-21, -28 + b), stf, 4.0)
	draw_line(Vector2(-18, 22 + b), Vector2(-21, -28 + b), stf.lightened(0.25), 1.5)
	# Rune notches on shaft
	for ry in [-18, -8, 2, 12]:
		draw_line(Vector2(-24, ry + b), Vector2(-18, ry + b), gold_d, 1.0)
	# Orbiting ring on left staff
	var ra1 := _anim_time * 1.5
	draw_arc(Vector2(-21, -20 + b), 5, ra1, ra1 + TAU * 0.70, 12, cx, 1.5)
	# Crystal cluster — left staff top
	var lg := 7.0 if not s else 9.5
	if s:
		draw_circle(Vector2(-21, -34 + b), lg + 6, Color(cx.r, cx.g, cx.b, 0.22))
	draw_circle(Vector2(-21, -34 + b), lg, cx)
	draw_circle(Vector2(-24, -37 + b), 3.5, cx.lightened(0.30))
	draw_circle(Vector2(-18, -37 + b), 2.5, cx.lightened(0.25))
	draw_circle(Vector2(-21, -29 + b), 2.0, cx.lightened(0.15))
	draw_circle(Vector2(-23, -36 + b), 2.0, Color(1, 1, 1, 0.50))   # glint

	# ── Right staff ──────────────────────────────────────────────────────────────
	draw_line(Vector2(18, 22 + b), Vector2(21, -28 + b), stf, 4.0)
	draw_line(Vector2(18, 22 + b), Vector2(21, -28 + b), stf.lightened(0.25), 1.5)
	for ry in [-18, -8, 2, 12]:
		draw_line(Vector2(18, ry + b), Vector2(24, ry + b), gold_d, 1.0)
	var ra2 := _anim_time * 1.5 + PI * 0.65
	draw_arc(Vector2(21, -20 + b), 5, ra2, ra2 + TAU * 0.70, 12, cx, 1.5)
	var rg := 6.0 if not s else 8.5
	if s:
		draw_circle(Vector2(21, -34 + b), rg + 5, Color(cx.r, cx.g, cx.b, 0.20))
	draw_circle(Vector2(21, -34 + b), rg, cx)
	draw_circle(Vector2(24, -37 + b), 3.0, cx.lightened(0.30))
	draw_circle(Vector2(18, -37 + b), 2.5, cx.lightened(0.25))
	draw_circle(Vector2(21, -29 + b), 2.0, cx.lightened(0.15))
	draw_circle(Vector2(23, -36 + b), 2.0, Color(1, 1, 1, 0.50))

	# ── Outer robe (wide, layered) ────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -10 + b), Vector2(14, -10 + b),
		Vector2(17,   24 + b), Vector2(-17, 24 + b)
	]), robe)
	# Shadow side panel
	draw_colored_polygon(PackedVector2Array([
		Vector2(5, -10 + b), Vector2(14, -10 + b),
		Vector2(17, 24 + b), Vector2( 8,  24 + b)
	]), robe_d)
	# Inner lighter front panel
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, -10 + b), Vector2(5, -10 + b),
		Vector2(6,   24 + b), Vector2(-6, 24 + b)
	]), robe_l)
	# Gold hem line
	draw_line(Vector2(-17, 19 + b), Vector2(17, 19 + b), gold, 2.0)
	draw_line(Vector2(-17, 22 + b), Vector2(17, 22 + b), gold_d, 1.0)
	# Gold trim verticals
	draw_line(Vector2(-5, -10 + b), Vector2(-6, 24 + b), gold_d, 1.0)
	draw_line(Vector2( 5, -10 + b), Vector2( 6, 24 + b), gold_d, 1.0)

	# ── Shoulder pauldrons ────────────────────────────────────────────────────────
	draw_circle(Vector2(-19, -7 + b), 8, robe_d)
	draw_arc(Vector2(-19, -7 + b),    8, -PI * 0.9, PI * 0.1, 10, gold, 1.5)
	draw_circle(Vector2(-19, -11 + b), 5, robe)
	draw_arc(Vector2(-19, -11 + b),    5, -PI, 0, 8, gold, 1.0)

	draw_circle(Vector2(19, -7 + b), 8, robe_d)
	draw_arc(Vector2(19, -7 + b),    8, -PI * 0.1, PI * 0.9, 10, gold, 1.5)
	draw_circle(Vector2(19, -11 + b), 5, robe)
	draw_arc(Vector2(19, -11 + b),    5, -PI, 0, 8, gold, 1.0)

	# ── Belt & accessories ────────────────────────────────────────────────────────
	draw_rect(Rect2(-13, -2 + b, 26, 5), gold_d)
	draw_rect(Rect2(-13, -2 + b, 26, 2), gold)    # top highlight
	# Central buckle
	draw_rect(Rect2(-4, -3 + b, 8, 7), gold)
	draw_rect(Rect2(-2, -1 + b, 4, 3), robe_d)
	# Left pouch
	draw_rect(Rect2(-17,  2 + b, 5, 7), robe_d)
	draw_line(Vector2(-17, 4 + b), Vector2(-12, 4 + b), gold_d, 1.0)
	# Right scroll case
	draw_rect(Rect2( 12,  2 + b, 4, 9), Color(0.55, 0.35, 0.12))
	draw_rect(Rect2( 12,  2 + b, 4, 2), gold)
	draw_circle(Vector2(14,  3 + b), 2, gold.darkened(0.1))

	# ── Arms ──────────────────────────────────────────────────────────────────────
	draw_rect(Rect2(-22, -7 + b, 10, 5), skin)   # left
	draw_rect(Rect2( 12, -7 + b, 10, 5), skin)   # right

	# ── Head ──────────────────────────────────────────────────────────────────────
	draw_circle(Vector2(0, -17 + b), 7, skin)
	# Glowing eyes (blue, brighter when shooting)
	var eye_c := Color(0.30, 0.58, 1.00) if not s else Color(0.65, 0.90, 1.00)
	draw_circle(Vector2(-3, -18 + b), 1.5, eye_c)
	draw_circle(Vector2( 3, -18 + b), 1.5, eye_c)
	if s:
		draw_circle(Vector2(-3, -18 + b), 3.0, Color(eye_c.r, eye_c.g, eye_c.b, 0.45))
		draw_circle(Vector2( 3, -18 + b), 3.0, Color(eye_c.r, eye_c.g, eye_c.b, 0.45))
	# Short beard
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4, -13 + b), Vector2(4, -13 + b),
		Vector2( 3,  -9 + b), Vector2(-3,  -9 + b)
	]), Color(0.80, 0.70, 0.56))

	# ── Scholar crown (flat-top, 3 gold points, NOT a pointy wizard hat) ──────────
	# Hood back piece
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -16 + b), Vector2(11, -16 + b),
		Vector2(  9, -26 + b), Vector2(-9, -26 + b)
	]), robe_d)
	# Crown band
	draw_rect(Rect2(-10, -28 + b, 20, 6), robe)
	draw_line(Vector2(-10, -28 + b), Vector2(10, -28 + b), gold, 1.5)
	draw_line(Vector2(-10, -22 + b), Vector2(10, -22 + b), gold, 1.5)
	# Crown top plate
	draw_rect(Rect2(-9, -35 + b, 18, 8), robe_d)
	draw_line(Vector2(-9, -35 + b), Vector2(9, -35 + b), gold, 2.0)
	# Three upward crown points
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -35 + b), Vector2(-4, -35 + b), Vector2(-6, -41 + b)
	]), gold)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2, -35 + b), Vector2( 2, -35 + b), Vector2( 0, -42 + b)
	]), gold)
	draw_colored_polygon(PackedVector2Array([
		Vector2( 4, -35 + b), Vector2( 8, -35 + b), Vector2( 6, -41 + b)
	]), gold)
	# Blue crystal gems in band
	draw_circle(Vector2(-6, -31 + b), 2.0, cx)
	draw_circle(Vector2( 0, -31 + b), 2.5, cx)
	draw_circle(Vector2( 6, -31 + b), 2.0, cx)
	if s:
		draw_circle(Vector2(0, -31 + b), 5.0, Color(cx.r, cx.g, cx.b, 0.40))
	# Fine rune marks on crown band
	for rx in [-7, -3, 3, 7]:
		draw_line(Vector2(rx, -28 + b), Vector2(rx, -26 + b), gold_d, 1.0)

	# ── Floating books (2, orbiting slowly) ──────────────────────────────────────
	for bi in range(2):
		var bang := _anim_time * 0.75 + bi * PI
		var bx   := cos(bang) * 24
		var by   := -3.0 + b + sin(bang) * 7
		var ba   := 0.92 if s else 0.72
		# Book cover
		draw_colored_polygon(PackedVector2Array([
			Vector2(bx - 5, by - 4), Vector2(bx + 5, by - 4),
			Vector2(bx + 5, by + 4), Vector2(bx - 5, by + 4)
		]), Color(0.48, 0.28, 0.10, ba))
		# Spine
		draw_line(Vector2(bx - 5, by - 4), Vector2(bx - 5, by + 4),
			Color(0.28, 0.16, 0.06, ba), 1.5)
		# Gold clasp dot
		draw_circle(Vector2(bx + 3, by), 1.5, Color(gold.r, gold.g, gold.b, ba))
		# Page glow when shooting
		if s:
			draw_rect(Rect2(bx - 4, by - 3, 8, 6), Color(cx.r, cx.g, cx.b, 0.25))
			# Page line detail
			draw_line(Vector2(bx - 3, by - 1), Vector2(bx + 3, by - 1),
				Color(cx.r, cx.g, cx.b, 0.60), 1.0)
			draw_line(Vector2(bx - 3, by + 1), Vector2(bx + 3, by + 1),
				Color(cx.r, cx.g, cx.b, 0.40), 1.0)

	# ── Orbiting arcane runes (3, gold at rest → blue when shooting) ─────────────
	var rune_spd := 2.0 if s else 0.9
	for ri in range(3):
		var rang := _anim_time * rune_spd + ri * (TAU / 3.0)
		var rrx  := cos(rang) * 28
		var rry  := -1.0 + b + sin(rang) * 11
		var ra   := 0.80 if s else 0.45
		var rc   := Color(cx.r, cx.g, cx.b, ra) if s else Color(gold.r, gold.g, gold.b, ra)
		draw_circle(Vector2(rrx, rry), 4.5, Color(rc.r, rc.g, rc.b, ra * 0.25))
		draw_line(Vector2(rrx - 3, rry),     Vector2(rrx + 3, rry),     rc, 1.5)
		draw_line(Vector2(rrx,     rry - 3), Vector2(rrx,     rry + 3), rc, 1.5)
		draw_line(Vector2(rrx - 2, rry - 2), Vector2(rrx + 2, rry + 2), rc, 1.0)

	# ── Shoot burst glow on both crystals ────────────────────────────────────────
	if s:
		var sf := clampf(_shoot_anim / 0.25, 0.0, 1.0)
		draw_circle(Vector2(-21, -34 + b), 13 * sf, Color(cx.r, cx.g, cx.b, sf * 0.45))
		draw_circle(Vector2( 21, -34 + b), 11 * sf, Color(cx.r, cx.g, cx.b, sf * 0.38))


# ── Taunt Tank (type 33) ─────────────────────────────────────────────────────
func _draw_taunt_tank(b: float, s: bool) -> void:
	var crimson  := Color(0.72, 0.10, 0.18)
	var crimson_d:= Color(0.45, 0.05, 0.10)
	var purple   := Color(0.55, 0.10, 0.72)
	var purple_d := Color(0.35, 0.05, 0.50)
	var steel    := Color(0.65, 0.65, 0.75)
	var steel_d  := Color(0.40, 0.38, 0.48)
	var skin     := Color(0.80, 0.58, 0.36)
	var gold     := Color(0.85, 0.65, 0.10)

	var sf := clampf(_shoot_anim / 0.35, 0.0, 1.0)

	# ── Pulsing aura (reddish-purple halo) ──
	var aura_t   := sin(_anim_time * 3.0) * 0.5 + 0.5
	var aura_r   := 28.0 + aura_t * 5.0
	var aura_col := Color(
		crimson.r * 0.7 + purple.r * 0.3,
		crimson.g * 0.1,
		crimson.b * 0.3 + purple.b * 0.7,
		0.18 + aura_t * 0.12
	)
	draw_circle(Vector2(0, 0), aura_r, aura_col)
	draw_arc(Vector2(0, 0), aura_r - 1.0, 0.0, TAU, 48,
		Color(aura_col.r + 0.2, aura_col.g, aura_col.b + 0.1, 0.55 + aura_t * 0.2), 2.0)

	# Drop shadow
	draw_circle(Vector2(0, 24), 15, Color(0, 0, 0, 0.25))

	# Boots — dark crimson
	draw_rect(Rect2(-10, 14 + b, 8, 10), crimson_d)
	draw_rect(Rect2(  2, 14 + b, 8, 10), crimson_d)

	# Legs — armoured crimson greaves
	draw_rect(Rect2(-10, 5 + b, 20, 10), crimson)
	draw_line(Vector2(-10, 9 + b), Vector2(10, 9 + b), crimson_d, 1.5)

	# Torso — heavy crimson plate with purple trim
	draw_rect(Rect2(-13, -9 + b, 26, 15), crimson)
	draw_rect(Rect2(-11, -7 + b, 22, 11), crimson_d)
	draw_line(Vector2(0, -9 + b), Vector2(0, 5 + b), crimson, 2.5)       # centre ridge
	draw_line(Vector2(-11, -3 + b), Vector2(11, -3 + b), crimson, 1.5)   # pec line
	# Purple trim edges
	draw_line(Vector2(-13, -9 + b), Vector2(13, -9 + b), purple, 3.0)
	draw_line(Vector2(-13, -9 + b), Vector2(-13, 5 + b), purple, 2.0)
	draw_line(Vector2( 13, -9 + b), Vector2( 13, 5 + b), purple, 2.0)

	# Shoulders — large pauldrons
	draw_circle(Vector2(-14, -7 + b), 7, crimson)
	draw_circle(Vector2( 14, -7 + b), 7, crimson)
	draw_arc(Vector2(-14, -7 + b), 7, PI * 0.5, PI * 1.5, 16, purple, 2.0)
	draw_arc(Vector2( 14, -7 + b), 7, -PI * 0.5, PI * 0.5, 16, purple, 2.0)

	# ── Full-face helmet (crimson + purple visor) ──
	draw_circle(Vector2(0, -19 + b), 11, crimson)
	draw_circle(Vector2(0, -20 + b), 10, crimson_d)
	# Visor — T-shaped purple slit
	draw_rect(Rect2(-8, -22 + b, 16, 4), purple)    # horizontal visor bar
	draw_rect(Rect2(-2, -22 + b,  4, 8), purple)    # vertical nose slit
	# Gold crown ridge on top
	draw_line(Vector2(-9, -26 + b), Vector2(9, -26 + b), gold, 3.0)
	draw_line(Vector2(-6, -29 + b), Vector2(-6, -26 + b), gold, 2.5)
	draw_line(Vector2( 0, -31 + b), Vector2( 0, -26 + b), gold, 2.5)
	draw_line(Vector2( 6, -29 + b), Vector2( 6, -26 + b), gold, 2.5)
	# Chin guard
	draw_rect(Rect2(-8, -14 + b, 16, 5), crimson_d)
	draw_line(Vector2(-8, -14 + b), Vector2(8, -14 + b), purple, 2.0)

	# ── Arms with gauntlets ──
	var l_hand_rest   := Vector2(-20, -4 + b)
	var l_hand_attack := Vector2(-24,  8 + b)
	var l_hand := l_hand_rest.lerp(l_hand_attack, sf)
	var r_hand_rest   := Vector2( 20, -4 + b)
	var r_hand_attack := Vector2( 24,  8 + b)
	var r_hand := r_hand_rest.lerp(r_hand_attack, sf)

	draw_line(Vector2(-13, -5 + b), l_hand, crimson, 6.0)
	draw_line(Vector2( 13, -5 + b), r_hand, crimson, 6.0)
	# Gauntlet fists
	draw_circle(l_hand, 5.5, crimson_d)
	draw_circle(r_hand, 5.5, crimson_d)
	draw_arc(l_hand, 5.5, 0.0, TAU, 16, purple, 1.5)
	draw_arc(r_hand, 5.5, 0.0, TAU, 16, purple, 1.5)

	# Taunt pulse ring when hitting (on attack animation)
	if sf > 0.1:
		var pulse_r := 20.0 + sf * 30.0
		draw_arc(Vector2(0, 0), pulse_r, 0.0, TAU, 48,
			Color(crimson.r, crimson.g, crimson.b, (1.0 - sf) * 0.7), 3.0)


# ── Hercules (type 32) ────────────────────────────────────────────────────────
func _draw_hercules(bob: float, s: bool) -> void:
	var b       := bob
	var gold    := Color(0.88, 0.68, 0.12)
	var gold_d  := Color(0.58, 0.42, 0.06)
	var steel   := Color(0.68, 0.70, 0.78)
	var steel_d := Color(0.40, 0.38, 0.46)
	var steel_l := Color(0.84, 0.86, 0.94)
	var skin    := Color(0.80, 0.58, 0.36)
	var leather := Color(0.36, 0.20, 0.08)
	var tiger   := Color(0.84, 0.48, 0.08)
	var tiger_d := Color(0.52, 0.28, 0.04)
	var tiger_s := Color(0.12, 0.08, 0.04)   # stripe black

	var sf := clampf(_shoot_anim / 0.35, 0.0, 1.0)

	# ── Wave-power aura (grows with _hercules_wave_bonus) ────────────────────────
	if _hercules_wave_bonus > 0.0:
		var power_f := minf(_hercules_wave_bonus / 5.0, 1.0)    # caps visually at +5 dmg (max stack)
		var pulse   := 0.4 + sin(_anim_time * 3.5) * 0.3
		draw_circle(Vector2(0, 4 + b), 28 + power_f * 8,
			Color(gold.r, gold.g, gold.b, 0.10 + power_f * 0.14 * pulse))
		draw_arc(Vector2(0, 4 + b), 26 + power_f * 8, 0, TAU, 32,
			Color(gold.r, gold.g, gold.b, (0.30 + power_f * 0.40) * pulse), 2.0)

	# ── Ground shadow ─────────────────────────────────────────────────────────────
	draw_circle(Vector2(0, 24), 15, Color(0, 0, 0, 0.22))

	# ── Long sword at rest (tip upper-right, behind body) ─────────────────────────
	# Sword positions — rest: diagonal upper-right; attack: sweeps down-left
	var sw_tip_rest   := Vector2(14,  -38 + b)
	var sw_tip_attack := Vector2(-22,  10 + b)
	var sw_bot_rest   := Vector2( 8,    6 + b)
	var sw_bot_attack := Vector2( 6,   20 + b)
	var sw_tip := sw_tip_rest.lerp(sw_tip_attack, sf)
	var sw_bot := sw_bot_rest.lerp(sw_bot_attack, sf)
	var sw_dir := (sw_tip - sw_bot).normalized()
	var sw_cg  := sw_bot + sw_dir * 18          # crossguard position
	var sw_cg_perp := sw_dir.rotated(PI * 0.5)

	# Blade (draw behind body so body overlaps handle)
	var blade_start := sw_cg + sw_dir * 2
	draw_line(blade_start, sw_tip, steel, 3.5)
	draw_line(blade_start, sw_tip, Color(steel_l.r, steel_l.g, steel_l.b, 0.65), 1.0)  # shine
	# Blade fuller (groove down centre)
	draw_line(blade_start + sw_cg_perp * 0.5, sw_tip - sw_dir * 4,
		Color(steel_d.r, steel_d.g, steel_d.b, 0.55), 1.0)
	# Swing trail on attack
	if sf > 0.2:
		draw_line(sw_tip, sw_tip_rest.lerp(sw_tip_attack, sf - 0.20),
			Color(steel_l.r, steel_l.g, steel_l.b, sf * 0.40), 5.0)

	# ── Greaves (lower legs) ──────────────────────────────────────────────────────
	draw_rect(Rect2(-10, 14 + b, 8, 10), steel_d)
	draw_rect(Rect2(  2, 14 + b, 8, 10), steel_d)
	draw_line(Vector2(-10, 17 + b), Vector2(-2, 17 + b), gold_d, 1.0)
	draw_line(Vector2(  2, 17 + b), Vector2(10, 17 + b), gold_d, 1.0)
	# Boot straps
	draw_line(Vector2(-10, 20 + b), Vector2(-2, 20 + b), leather, 1.0)
	draw_line(Vector2(  2, 20 + b), Vector2(10, 20 + b), leather, 1.0)

	# ── Battle skirt / tassets ────────────────────────────────────────────────────
	draw_rect(Rect2(-11, 5 + b, 22, 10), gold_d)
	draw_line(Vector2(-11, 8 + b), Vector2(11, 8 + b), gold, 1.5)
	# Skirt strips (vertical tasset lines)
	for tx in [-7, -3, 1, 5]:
		draw_line(Vector2(tx, 8 + b), Vector2(tx, 14 + b), gold_d.darkened(0.2), 1.0)

	# ── Plate torso ───────────────────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -10 + b), Vector2(13, -10 + b),
		Vector2(11,    6 + b), Vector2(-11,  6 + b)
	]), steel)
	# Shadow side
	draw_colored_polygon(PackedVector2Array([
		Vector2(4, -10 + b), Vector2(13, -10 + b),
		Vector2(11,  6 + b), Vector2( 6,   6 + b)
	]), steel_d)
	# Breastplate centre ridge
	draw_line(Vector2(0, -10 + b), Vector2(0, 5 + b), steel_l, 1.5)
	# Pectoral line
	draw_line(Vector2(-11, -3 + b), Vector2(11, -3 + b), steel_l, 1.0)
	# Gold shoulder trim
	draw_line(Vector2(-13, -10 + b), Vector2(13, -10 + b), gold, 2.5)

	# ── Shoulder pauldrons ────────────────────────────────────────────────────────
	draw_circle(Vector2(-19, -7 + b), 9, steel_d)
	draw_arc(Vector2(-19, -7 + b),    9, -PI * 0.9, PI * 0.1, 10, gold, 2.0)
	draw_circle(Vector2(-19, -11 + b), 6, steel)
	draw_arc(Vector2(-19, -11 + b),    6, -PI, 0, 8, gold_d, 1.5)

	draw_circle(Vector2(19, -7 + b), 9, steel_d)
	draw_arc(Vector2(19, -7 + b),    9, -PI * 0.1, PI * 0.9, 10, gold, 2.0)
	draw_circle(Vector2(19, -11 + b), 6, steel)
	draw_arc(Vector2(19, -11 + b),    6, -PI, 0, 8, gold_d, 1.5)

	# ── Belt ─────────────────────────────────────────────────────────────────────
	draw_rect(Rect2(-12, -1 + b, 24, 5), leather)
	draw_rect(Rect2(-12, -1 + b, 24, 2), leather.lightened(0.2))   # top highlight
	# Buckle
	draw_rect(Rect2(-4, -2 + b, 8, 7), gold)
	draw_rect(Rect2(-2,  0 + b, 4, 3), leather)
	# Side pouches
	draw_rect(Rect2(-18, 2 + b, 5, 7), leather.darkened(0.1))
	draw_line(Vector2(-18, 4 + b), Vector2(-13, 4 + b), gold_d, 1.0)
	draw_rect(Rect2( 13, 2 + b, 5, 7), leather.darkened(0.1))
	draw_line(Vector2( 13, 4 + b), Vector2( 18, 4 + b), gold_d, 1.0)

	# ── Arms ─────────────────────────────────────────────────────────────────────
	# Right arm (grips hilt — follows sword)
	var r_grip_rest   := Vector2( 9, -2 + b)
	var r_grip_attack := Vector2(-6, 10 + b)
	var r_grip        := r_grip_rest.lerp(r_grip_attack, sf)
	draw_line(Vector2(13, -8 + b), r_grip, skin, 6.0)
	# Left arm
	draw_line(Vector2(-13, -8 + b), Vector2(-16, 2 + b), skin, 6.0)

	# ── Hilt, crossguard, pommel (drawn over arms) ────────────────────────────────
	# Crossguard
	draw_line(sw_cg + sw_cg_perp * 11, sw_cg - sw_cg_perp * 11, gold, 4.0)
	draw_line(sw_cg + sw_cg_perp * 11, sw_cg - sw_cg_perp * 11, Color(1,1,0.7,0.5), 1.5)
	# Hilt wrap (leather between pommel and crossguard)
	draw_line(sw_bot, sw_cg, leather, 4.0)
	for i in range(4):
		var t  := float(i) / 3.0
		var hp := sw_bot.lerp(sw_cg, t + 0.1)
		draw_line(hp - sw_cg_perp * 3, hp + sw_cg_perp * 3, gold_d, 1.0)
	# Pommel (round, gold)
	draw_circle(sw_bot, 5.0, gold)
	draw_circle(sw_bot, 3.0, gold_d)
	draw_circle(sw_bot + Vector2(-1, -1), 1.5, Color(1, 1, 0.8, 0.55))   # glint
	# Right hand gripping hilt
	draw_circle(r_grip, 4.5, skin)

	# ── Tiger Helmet ──────────────────────────────────────────────────────────────
	# Cheek guards (drawn before skull cap so cap overlaps)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -14 + b), Vector2(-8, -14 + b),
		Vector2(-9,  -10 + b), Vector2(-13, -10 + b)
	]), tiger_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2( 12, -14 + b), Vector2( 8, -14 + b),
		Vector2( 9,  -10 + b), Vector2( 13, -10 + b)
	]), tiger_d)
	# Main skull cap
	draw_circle(Vector2(0, -20 + b), 10, tiger)
	draw_circle(Vector2(0, -21 + b),  9, Color(tiger.r + 0.06, tiger.g + 0.04, tiger.b))
	# Tiger stripe markings
	draw_line(Vector2(-7, -24 + b), Vector2(-4, -15 + b), tiger_s, 2.0)
	draw_line(Vector2( 7, -24 + b), Vector2( 4, -15 + b), tiger_s, 2.0)
	draw_line(Vector2(-3, -25 + b), Vector2(-2, -17 + b), tiger_s, 1.5)
	draw_line(Vector2( 3, -25 + b), Vector2( 2, -17 + b), tiger_s, 1.5)
	draw_line(Vector2( 0, -26 + b), Vector2( 0, -18 + b), tiger_s, 1.0)
	# Gold brow band
	draw_line(Vector2(-10, -15 + b), Vector2(10, -15 + b), gold, 3.0)
	draw_line(Vector2(-10, -15 + b), Vector2(10, -15 + b), Color(1, 1, 0.7, 0.4), 1.0)
	# Gold nose guard
	draw_line(Vector2(0, -15 + b), Vector2(0, -10 + b), gold, 3.0)
	draw_line(Vector2(-2, -12 + b), Vector2(2, -12 + b), gold, 1.5)
	# Tiger ears (prominent)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -25 + b), Vector2(-6, -33 + b), Vector2(-2, -23 + b)
	]), tiger)
	draw_colored_polygon(PackedVector2Array([
		Vector2( 11, -25 + b), Vector2( 6, -33 + b), Vector2( 2, -23 + b)
	]), tiger)
	# Inner ear (pink)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9, -25 + b), Vector2(-6, -30 + b), Vector2(-3, -24 + b)
	]), Color(0.92, 0.72, 0.62))
	draw_colored_polygon(PackedVector2Array([
		Vector2( 9, -25 + b), Vector2( 6, -30 + b), Vector2( 3, -24 + b)
	]), Color(0.92, 0.72, 0.62))
	# Ear stripe detail
	draw_line(Vector2(-7, -28 + b), Vector2(-6, -25 + b), tiger_s, 1.0)
	draw_line(Vector2( 7, -28 + b), Vector2( 6, -25 + b), tiger_s, 1.0)
	# Eyes — fierce amber
	draw_circle(Vector2(-3.5, -18 + b), 2.5, skin)
	draw_circle(Vector2( 3.5, -18 + b), 2.5, skin)
	draw_circle(Vector2(-3.5, -18 + b), 1.5, Color(0.70, 0.42, 0.05))
	draw_circle(Vector2( 3.5, -18 + b), 1.5, Color(0.70, 0.42, 0.05))
	draw_circle(Vector2(-3.5, -18 + b), 0.6, Color(0.05, 0.03, 0.01))
	draw_circle(Vector2( 3.5, -18 + b), 0.6, Color(0.05, 0.03, 0.01))
	# Fierce brow lines
	draw_line(Vector2(-6, -21 + b), Vector2(-2, -20 + b), tiger_s, 1.5)
	draw_line(Vector2( 2, -20 + b), Vector2( 6, -21 + b), tiger_s, 1.5)
