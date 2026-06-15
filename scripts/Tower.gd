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
var _last_target        : Node2D  = null
var _focused_stacks     : int     = 0    # focused_shot stack count (0–4, 4 = 3×)
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
var _tile_dmg_bonus    : float = 0.0      # special tile (red): +30% damage multiplier
var _tile_range_bonus  : float = 0.0      # special tile (blue): flat px added to attack_range
var _tile_spd_bonus    : float = 0.0      # special tile (green): +25% fire rate
var _relic_dmg_bonus   : float = 0.0   # power_surge relic: accumulated flat damage bonus
var _relic_rate_bonus  : float = 0.0   # swift_wind / bloodlust_tide relic: stacking fire-rate bonus
var _sw_stacks         : int   = 0        # shadow weaver: shadow-phase hit counter (0-10)
var _sw_light_timer    : float = 0.0      # shadow weaver: seconds remaining in light phase
var _sw_beam_tick      : float = 0.0      # shadow weaver: countdown to next light-phase beam pulse
var _sw_beam_targets   : Array = []       # shadow weaver: current light-phase beam targets (for drawing)
var _sw_beam_alpha     : float = 0.0      # shadow weaver: beam visual fade
var _sw_base_color     : Color = Color(0.55, 0.20, 0.85)  # shadow weaver: original purple saved on init
var _wt_passive_tick : float = 0.0   # world tree: timer for passive buff pulse
var _chrono_pulse  : float = 0.0     # chrono mage: attack pulse visual timer
var _tw_slash_target   : Vector2 = Vector2.ZERO  # tempest warden: last special target direction (local space)
var _tw_slash_primary  : Node2D  = null           # tempest warden: last special target node (for projectile)
var _tw_slash_launched : bool    = false           # tempest warden: has the slash projectile been spawned this special
var _tw_slash_dmg      : float   = 0.0            # tempest warden: damage to deal when slash projectile hits
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
		if not is_instance_valid(_beam_target) or _beam_target._dying:
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
				var lock_mult := 1.0 + minf(_beam_lock_time / 5.0, 1.0)
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
		if not is_instance_valid(_beam_target2) or _beam_target2._dying:
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
				var lock_mult2 := 1.0 + minf(_beam_lock_time2 / 5.0, 1.0)
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
		if tower_effect == "tempest_strike" and not _tw_slash_launched:
			var _ct_now : float = 1.0 - (_chrono_pulse / 0.50)
			if _ct_now >= 0.58:
				_tw_slash_launched = true
				if is_instance_valid(_tw_slash_primary):
					_spawn_tw_slash(_tw_slash_primary, _tw_slash_dmg)
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
			if is_instance_valid(_last_target) and _last_target == primary:
				_focused_stacks = mini(_focused_stacks + 1, 2)
			else:
				_focused_stacks = 0
			_last_target = primary
			var mult : float = 1.0 + _focused_stacks * 0.5   # 1×, 1.5×, 2×
			_fire(primary, damage * mult)
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
			# Hits 1 & 2: single sword at primary, no knockback.
			# Hit 3: up to 3 swords at 3 DIFFERENT enemies (in-range order),
			# ALL with knockback on impact. Never hits the same enemy twice.
			_hit_counter += 1
			if _hit_counter >= 3:
				_hit_counter = 0
				var _thrown  := 0
				var _offsets := [Vector2(0, 0), Vector2(-14, 0), Vector2(14, 0)]
				for _kt in in_range:
					if _thrown >= 3:
						break
					_fire(_kt, damage, true, _offsets[_thrown])
					_thrown += 1
			else:
				_fire(primary, damage)
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
			_shoot_anim = 0.35
			_fire(primary, damage)
			if _hit_counter >= 10:
				_hit_counter = 0
				_tw_slash_dmg      = damage + primary.max_hp * 0.05
				_tw_slash_target   = primary.position - position
				_tw_slash_primary  = primary
				_tw_slash_launched = false
				_chrono_pulse = 0.50
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
	var effective_rate : float = tower_data.get("fire_rate", fire_rate) * (GameData.tower_total_fire_rate_mult(tid) + GameData.buff_fire_rate_pct + _wt_rate_bonus + _ranger_rate_bonus + _frost_speed_bonus + _tile_spd_bonus + _relic_rate_bonus)
	_cooldown = 1.0 / effective_rate


func _fire(target: Node2D, dmg: float, p_pushback: bool = false, spawn_offset: Vector2 = Vector2.ZERO) -> void:
	var tid       : String = tower_data.get("id", "")
	var boss_mult : float  = GameData.relic_boss_dmg_mult() if target.is_boss else 1.0
	var final_dmg : float
	if GameData.HERO_DEFS.has(tid):
		# Heroes use the talent system — damage matches stat page exactly (base + talents only)
		final_dmg = dmg * boss_mult
	else:
		final_dmg = (dmg * GameData.tower_total_damage_mult(tid) * (1.0 + _tile_dmg_bonus) + GameData.buff_damage_flat + _wt_dmg_bonus + _relic_dmg_bonus) * boss_mult

	# Melee towers — instant direct damage, no projectile
	if tower_type in [26, 27, 28, 29, 30, 31, 32, 33]:
		if dmg > 0.0:
			target.take_damage(final_dmg)
		if p_pushback and not target.is_boss:
			target.pushback()
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
	b.position = position + spawn_offset

	match tower_type:
		4:  # Knight — sword
			b.setup(target, final_dmg)
			b.bullet_type    = "sword"
			b._speed         = 900.0
			b.pushback_on_hit = p_pushback
			_throw_dir       = position.direction_to(target.position)
			_throw_timer     = 0.35
		8:  # Sniper — homing arrow (same as archer but faster)
			b.setup(target, final_dmg)
			b.bullet_type = "arrow"
			b._speed      = 1200.0
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
		# ── Hero projectiles ───────────────────────────────────────────────────────────────────────────
		50:
			b.setup(target, final_dmg)
			b.bullet_type = "hero_dragon_fire"
		51:
			b.setup(target, final_dmg)
			b.bullet_type = "hero_shadow_dagger"
		52:
			b.setup(target, final_dmg)
			b.bullet_type = "hero_void_sphere"
		53:
			b.setup(target, final_dmg)
			b.bullet_type = "hero_arcane_bolt"
		54:
			b.setup(target, final_dmg)
			b.bullet_type = "hero_ranger_arrow"
		55:
			b.setup(target, final_dmg)
			b.bullet_type = "hero_guardian_rock"
		56:
			b.setup(target, final_dmg)
			b.bullet_type = "hero_blade_sword"
		57:
			b.setup(target, final_dmg)
			b.bullet_type = "hero_frost_shard"
		58:
			b.setup(target, final_dmg)
			b.bullet_type = "hero_venom_fang"
		59:
			b.setup(target, final_dmg)
			b.bullet_type = "hero_storm_spear"
		60:
			b.setup(target, final_dmg)
			b.bullet_type = "hero_phoenix_arrow"
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


func _spawn_tw_slash(target: Node2D, dmg: float) -> void:
	var b : Node2D = _bullet_scene.instantiate()
	b.position = position + Vector2(0, -42)
	b.setup(target, dmg)
	b.bullet_type = "tw_slash"
	b._speed      = 350.0
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
	var _tile_sc := 0.90 if tower_type in [0, 1, 2, 3, 4, 13, 16, 26, 27, 28, 29, 30, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60] else 1.0
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
		50: _draw_hero_dragon_sovereign(bob, s)
		51: _draw_hero_dagger(bob, s)
		52: _draw_hero_void_walker(bob, s)
		53: _draw_hero_arcane_scholar(bob, s)
		54: _draw_hero_ranger(bob, s)
		55: _draw_hero_guardian(bob, s)
		56: _draw_hero_blade_dancer(bob, s)
		57: _draw_hero_frost_herald(bob, s)
		58: _draw_hero_venom_lord(bob, s)
		59: _draw_hero_storm_knight(bob, s)
		60: _draw_hero_phoenix_archer(bob, s)
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

	# ── Floating Royal Banners + Crest Symbols + Golden Rune Particles ────────
	var _t := _anim_time
	# Golden rune particles — 8 drifting in a wide orbit
	for _pi in range(8):
		var _pa := _t * 0.50 + _pi * (TAU / 8.0)
		var _pr := 28.0 + sin(_t * 1.2 + float(_pi)) * 3.5
		var _px := cos(_pa) * _pr
		var _py := -2.0 + b + sin(_pa * 0.55) * 14.0
		draw_circle(Vector2(_px, _py), 1.5,
			Color(gold.r, gold.g, gold.b, 0.30 + sin(_t * 2.0 + float(_pi)) * 0.12))
	# Rotating shield-crest symbols — 2, slowly turning on opposite sides
	for _ci in range(2):
		var _ca := _t * 0.32 + _ci * PI
		var _cr := 33.0
		var _cx := cos(_ca) * _cr
		var _cy := -4.0 + b + sin(_ca * 0.50) * 15.0
		var _calpha := 0.52 + sin(_t * 1.4 + float(_ci)) * 0.10
		draw_colored_polygon(PackedVector2Array([
			Vector2(_cx - 5, _cy - 6), Vector2(_cx + 5, _cy - 6),
			Vector2(_cx + 4, _cy + 2), Vector2(_cx,     _cy + 7),
			Vector2(_cx - 4, _cy + 2)
		]), Color(royal.r, royal.g, royal.b, _calpha))
		draw_polyline(PackedVector2Array([
			Vector2(_cx - 5, _cy - 6), Vector2(_cx + 5, _cy - 6),
			Vector2(_cx + 4, _cy + 2), Vector2(_cx,     _cy + 7),
			Vector2(_cx - 4, _cy + 2), Vector2(_cx - 5, _cy - 6)
		]), Color(gold.r, gold.g, gold.b, _calpha * 0.85), 1.0)
		draw_line(Vector2(_cx, _cy - 4), Vector2(_cx, _cy + 4),
			Color(gold.r, gold.g, gold.b, _calpha * 0.65), 1.0)
		draw_line(Vector2(_cx - 3, _cy), Vector2(_cx + 3, _cy),
			Color(gold.r, gold.g, gold.b, _calpha * 0.65), 1.0)
	# 2 Royal pennant banners — slowly orbiting and gently swaying
	for _bi in range(2):
		var _ba := _t * 0.26 + _bi * PI + PI * 0.5
		var _bx := cos(_ba) * 36.0
		var _by := -8.0 + b + sin(_ba * 0.48) * 13.0
		var _sway := sin(_t * 1.7 + float(_bi) * 2.1) * 4.0
		var _balpha := 0.68 + sin(_t * 1.3 + float(_bi)) * 0.10
		# Banner staff
		draw_line(Vector2(_bx, _by + 8), Vector2(_bx, _by - 14),
			Color(gold.r, gold.g, gold.b, _balpha * 0.70), 1.5)
		draw_circle(Vector2(_bx, _by + 8), 2.0,
			Color(gold.r, gold.g, gold.b, _balpha * 0.55))
		# Pennant body (parallelogram, sways at free end)
		draw_colored_polygon(PackedVector2Array([
			Vector2(_bx,              _by - 14),
			Vector2(_bx + 14 + _sway, _by - 14),
			Vector2(_bx + 11 + _sway, _by -  7),
			Vector2(_bx,              _by -  7)
		]), Color(royal.r, royal.g, royal.b, _balpha))
		# Gold trim on top edge
		draw_line(Vector2(_bx, _by - 14), Vector2(_bx + 14 + _sway, _by - 14),
			Color(gold.r, gold.g, gold.b, _balpha * 0.80), 1.5)
		# Crown motif (small dot + cross) on banner face
		draw_circle(Vector2(_bx + 7 + _sway * 0.5, _by - 10), 1.5,
			Color(gold.r, gold.g, gold.b, _balpha * 0.85))
		draw_line(Vector2(_bx + 5 + _sway * 0.5, _by - 10),
			Vector2(_bx + 9 + _sway * 0.5, _by - 10),
			Color(gold.r, gold.g, gold.b, _balpha * 0.60), 1.0)

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
	var jacket := Color(0.14, 0.16, 0.20)
	var jack_d := Color(0.08, 0.09, 0.12)
	var jack_l := Color(0.24, 0.27, 0.33)
	var pants  := Color(0.12, 0.14, 0.18)
	var boots  := Color(0.10, 0.08, 0.06)
	var belt   := Color(0.32, 0.22, 0.08)
	var teal   := Color(0.18, 0.78, 0.58)
	var teal_d := Color(0.08, 0.45, 0.32)
	var hair   := Color(0.18, 0.14, 0.10)
	var gun_c  := Color(0.28, 0.30, 0.36)
	var gun_l  := Color(0.48, 0.50, 0.58)
	var sf     := clampf(_shoot_anim / 0.35, 0.0, 1.0)
	var gx     := 18.0

	draw_circle(Vector2(0, 24), 11, Color(0, 0, 0, 0.15))

	# ── Dart gun at rest (behind body) ───────────────────────────────────────
	if not s:
		draw_line(Vector2(-2, -5 + b), Vector2(gx + 14, -5 + b), gun_c, 5.0)
		draw_line(Vector2(-2, -5 + b), Vector2(gx + 14, -5 + b), gun_l, 2.5)
		draw_line(Vector2(-2, -5 + b), Vector2(gx + 14, -5 + b), teal,  1.0)
		draw_circle(Vector2(gx + 14, -5 + b), 3.5, gun_c)
		draw_circle(Vector2(gx + 14, -5 + b), 2.0, teal_d)
		# Dart loaded in barrel
		draw_line(Vector2(gx + 4, -5 + b), Vector2(gx + 14, -5 + b), teal, 1.5)
		draw_colored_polygon(PackedVector2Array([
			Vector2(gx + 14, -5 + b), Vector2(gx + 11, -7 + b), Vector2(gx + 11, -3 + b)
		]), Color(0.80, 0.84, 0.90))

	# ── Boots ─────────────────────────────────────────────────────────────────
	draw_rect(Rect2(-9, 16 + b, 8, 8), boots)
	draw_rect(Rect2( 1, 16 + b, 8, 8), boots)
	draw_line(Vector2(-9, 19 + b), Vector2(-1, 19 + b), boots.lightened(0.2), 1.0)
	draw_line(Vector2( 1, 19 + b), Vector2( 9, 19 + b), boots.lightened(0.2), 1.0)

	# ── Pants ─────────────────────────────────────────────────────────────────
	draw_rect(Rect2(-9, 4 + b, 8, 14), pants)
	draw_rect(Rect2( 1, 4 + b, 8, 14), pants)

	# ── Jacket ────────────────────────────────────────────────────────────────
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
		Vector2( 5,  6 + b),  Vector2(-5,  6 + b)
	]), jack_l)
	draw_line(Vector2(-13, -10 + b), Vector2(13, -10 + b), teal, 1.5)
	draw_line(Vector2(-15,   3 + b), Vector2(15,  3 + b),  jack_d, 1.0)

	# ── Shoulder pauldrons ────────────────────────────────────────────────────
	draw_circle(Vector2(-17, -7 + b), 7, jack_d)
	draw_arc(Vector2(-17, -7 + b), 7, -PI * 0.9, PI * 0.1, 10, teal, 1.5)
	draw_circle(Vector2(-17, -11 + b), 4, jacket)
	draw_circle(Vector2( 17, -7 + b), 7, jack_d)
	draw_arc(Vector2( 17, -7 + b), 7, -PI * 0.1, PI * 0.9, 10, teal, 1.5)
	draw_circle(Vector2( 17, -11 + b), 4, jacket)

	# ── Belt + dart pouch ─────────────────────────────────────────────────────
	draw_rect(Rect2(-13, -1 + b, 26, 5), belt)
	draw_rect(Rect2(-13, -1 + b, 26, 2), belt.lightened(0.15))
	draw_rect(Rect2(-4, -2 + b, 8, 7), belt.darkened(0.15))
	draw_rect(Rect2(-2,  0 + b, 4, 3), belt)
	# Dart pouch on right hip
	draw_rect(Rect2(9, -9 + b, 6, 11), jack_d)
	draw_rect(Rect2(9, -9 + b, 6,  2), teal_d)
	for qi in range(3):
		draw_line(Vector2(10 + qi * 2, -9 + b), Vector2(10 + qi * 2, -14 + b), teal, 1.5)
		draw_colored_polygon(PackedVector2Array([
			Vector2(10 + qi * 2, -14 + b),
			Vector2( 9 + qi * 2, -12 + b),
			Vector2(11 + qi * 2, -12 + b)
		]), Color(0.80, 0.84, 0.90))

	# ── Arms ──────────────────────────────────────────────────────────────────
	draw_rect(Rect2(-20, -9 + b, 10, 5), skin)
	draw_rect(Rect2(  8, -9 + b,  8, 5), skin)

	# ── Head ──────────────────────────────────────────────────────────────────
	draw_circle(Vector2(0, -17 + b), 7, skin)
	draw_circle(Vector2(-5, -17 + b), 2.5, skin)
	draw_circle(Vector2(0, -23 + b), 6, hair)
	draw_rect(Rect2(-6, -23 + b, 12, 7), hair)
	# Dark scout cap (same shape as archer's ranger cap)
	draw_rect(Rect2(-9, -22 + b, 18, 3), jack_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -22 + b), Vector2(8, -22 + b),
		Vector2( 5, -30 + b), Vector2(-5, -30 + b)
	]), jacket)
	draw_colored_polygon(PackedVector2Array([
		Vector2(2, -30 + b), Vector2(8, -22 + b), Vector2(5, -22 + b)
	]), jack_d)
	draw_line(Vector2(-8, -22 + b), Vector2(8, -22 + b), teal, 1.5)
	# Red feather
	draw_line(Vector2(5, -29 + b), Vector2(14, -24 + b), Color(0.88, 0.12, 0.10), 2.0)
	draw_line(Vector2(6, -28 + b), Vector2(13, -24 + b), Color(1.00, 0.36, 0.32, 0.60), 1.0)
	draw_circle(Vector2(3, -17 + b), 1.5, Color(0.14, 0.08, 0.02))
	draw_line(Vector2(0, -20 + b), Vector2(5, -21 + b), hair, 1.5)

	# ── Dart gun when shooting ────────────────────────────────────────────────
	if s:
		draw_line(Vector2(-2, -5 + b), Vector2(gx + 14, -5 + b), gun_c, 5.0)
		draw_line(Vector2(-2, -5 + b), Vector2(gx + 14, -5 + b), gun_l, 2.5)
		draw_line(Vector2(-2, -5 + b), Vector2(gx + 14, -5 + b), teal,  1.0)
		draw_circle(Vector2(gx + 14, -5 + b), 3.5, gun_c)
		draw_circle(Vector2(gx + 14, -5 + b), 2.0, teal_d)
		# Dart exiting barrel
		if sf > 0.2:
			var dart_ext := (sf - 0.2) / 0.8 * 20.0
			draw_line(Vector2(gx + 14 + dart_ext, -5 + b),
					  Vector2(gx + 24 + dart_ext, -5 + b), Color(0.12, 0.14, 0.16), 2.5)
			draw_colored_polygon(PackedVector2Array([
				Vector2(gx + 24 + dart_ext, -5 + b),
				Vector2(gx + 21 + dart_ext, -7 + b),
				Vector2(gx + 21 + dart_ext, -3 + b)
			]), Color(0.80, 0.84, 0.90))
			draw_colored_polygon(PackedVector2Array([
				Vector2(gx + 24 + dart_ext, -5 + b),
				Vector2(gx + 22 + dart_ext, -6 + b),
				Vector2(gx + 22 + dart_ext, -4 + b)
			]), teal)
		# Teal muzzle puff
		if sf > 0.05:
			draw_circle(Vector2(gx + 16, -5 + b), 4.5 * (1.0 - sf),
					Color(0.25, 0.90, 0.65, sf * 0.72))


# ── Tesla Tower (type 9) ──────────────────────────────────────────────────────
func _draw_tesla_tower(b: float, s: bool) -> void:
	# Palette
	var steel   := Color(0.38, 0.43, 0.52)
	var steel_l := Color(0.58, 0.65, 0.74)
	var steel_d := Color(0.22, 0.26, 0.34)
	var copper  := Color(0.72, 0.44, 0.16)
	var copper_l:= Color(0.90, 0.62, 0.26)
	var elec    := Color(0.42, 0.80, 1.00)
	var elec_l  := Color(0.78, 0.96, 1.00)
	var rune_c  := Color(0.55, 0.88, 1.00, 0.80)

	# Animation helpers
	var pulse   := sin(_anim_time * 3.8)
	var arc_rot := _anim_time * 4.2
	var flicker := sin(_anim_time * 19.0)

	# ── Shadow ────────────────────────────────────────────────────────────────
	draw_circle(Vector2(0, 24), 16, Color(0, 0, 0, 0.18))

	# ── Base platform (3D slab) ───────────────────────────────────────────────
	# Front face
	draw_colored_polygon(PackedVector2Array([
		Vector2(-16, 14 + b), Vector2(16, 14 + b),
		Vector2(16,  20 + b), Vector2(-16, 20 + b)
	]), steel_d)
	# Top face
	draw_colored_polygon(PackedVector2Array([
		Vector2(-16, 14 + b), Vector2(16, 14 + b),
		Vector2(13,   8 + b), Vector2(-13,  8 + b)
	]), steel_l)
	# Right side shadow
	draw_colored_polygon(PackedVector2Array([
		Vector2(13, 8 + b), Vector2(16, 14 + b),
		Vector2(16, 20 + b), Vector2(13, 14 + b)
	]), steel_d)
	# Copper trim edges
	draw_line(Vector2(-16, 14 + b), Vector2(16, 14 + b), copper, 1.2)
	draw_line(Vector2(-16, 14 + b), Vector2(-13, 8 + b), copper, 1.0)
	draw_line(Vector2( 16, 14 + b), Vector2( 13, 8 + b), copper, 1.0)
	# Insulator mounts (3 copper bolts across top face)
	for ix: int in [-8, 0, 8]:
		draw_circle(Vector2(ix, 8 + b), 2.5, copper)
		draw_circle(Vector2(ix, 8 + b), 1.2, copper_l)

	# ── Energy conduits (copper pipes from side coils to central column) ──────
	draw_line(Vector2(-13, 3 + b), Vector2(-5, -1 + b),  copper,   2.0)
	draw_line(Vector2( 13, 3 + b), Vector2( 5, -1 + b),  copper,   2.0)
	draw_line(Vector2(-13, 3 + b), Vector2(-5, -1 + b),  copper_l, 0.7)
	draw_line(Vector2( 13, 3 + b), Vector2( 5, -1 + b),  copper_l, 0.7)
	# Idle conduit glow
	if not s:
		var ca := 0.18 + pulse * 0.08
		draw_line(Vector2(-13, 3 + b), Vector2(-5, -1 + b), Color(elec.r, elec.g, elec.b, ca), 1.0)
		draw_line(Vector2( 13, 3 + b), Vector2( 5, -1 + b), Color(elec.r, elec.g, elec.b, ca), 1.0)

	# ── Secondary coil — LEFT ─────────────────────────────────────────────────
	# Column body
	draw_colored_polygon(PackedVector2Array([
		Vector2(-17, 1 + b), Vector2(-11, 1 + b),
		Vector2(-11, 8 + b), Vector2(-17, 8 + b)
	]), steel)
	# Top cap face
	draw_colored_polygon(PackedVector2Array([
		Vector2(-18, 1 + b), Vector2(-10, 1 + b),
		Vector2(-11, -1 + b), Vector2(-17, -1 + b)
	]), steel_l)
	# Two copper coil rings
	draw_arc(Vector2(-14, 2 + b), 4.5, 0, TAU, 12, copper, 2.2)
	draw_arc(Vector2(-14, -1 + b), 3.8, 0, TAU, 12, copper, 2.0)
	# Angled lightning rod
	draw_line(Vector2(-14, -1 + b), Vector2(-17, -11 + b), steel_l, 2.2)
	draw_line(Vector2(-17, -11 + b), Vector2(-19, -15 + b), elec_l, 1.5)
	# Capacitor node
	var lc_r := 3.5 + (pulse * 0.6 if s else 0.0)
	draw_circle(Vector2(-17, -11 + b), lc_r + 2.5, Color(elec.r, elec.g, elec.b, 0.22))
	draw_circle(Vector2(-17, -11 + b), 3.5, steel_l)
	draw_circle(Vector2(-17, -11 + b), 2.0, Color(elec.r, elec.g, elec.b, 0.88))
	draw_circle(Vector2(-18, -12 + b), 0.9, Color(1, 1, 1, 0.70))

	# ── Secondary coil — RIGHT ────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(11, 1 + b), Vector2(17, 1 + b),
		Vector2(17, 8 + b), Vector2(11, 8 + b)
	]), steel)
	draw_colored_polygon(PackedVector2Array([
		Vector2(10, 1 + b), Vector2(18, 1 + b),
		Vector2(17, -1 + b), Vector2(11, -1 + b)
	]), steel_l)
	draw_arc(Vector2(14, 2 + b), 4.5, 0, TAU, 12, copper, 2.2)
	draw_arc(Vector2(14, -1 + b), 3.8, 0, TAU, 12, copper, 2.0)
	draw_line(Vector2(14, -1 + b), Vector2(17, -11 + b), steel_l, 2.2)
	draw_line(Vector2(17, -11 + b), Vector2(19, -15 + b), elec_l, 1.5)
	var rc_r := 3.5 + (pulse * 0.6 if s else 0.0)
	draw_circle(Vector2(17, -11 + b), rc_r + 2.5, Color(elec.r, elec.g, elec.b, 0.22))
	draw_circle(Vector2(17, -11 + b), 3.5, steel_l)
	draw_circle(Vector2(17, -11 + b), 2.0, Color(elec.r, elec.g, elec.b, 0.88))
	draw_circle(Vector2(18, -12 + b), 0.9, Color(1, 1, 1, 0.70))

	# ── Central main coil column ──────────────────────────────────────────────
	# Front face
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -4 + b), Vector2(6, -4 + b),
		Vector2(6,   8 + b), Vector2(-6, 8 + b)
	]), steel)
	# Top lit face
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -4 + b), Vector2(6, -4 + b),
		Vector2(5,  -7 + b), Vector2(-5, -7 + b)
	]), steel_l)
	# Right shadow face
	draw_colored_polygon(PackedVector2Array([
		Vector2(4, -4 + b), Vector2(6, -4 + b),
		Vector2(6,  8 + b), Vector2(4,  8 + b)
	]), steel_d)
	# 5 copper helix coil rings
	for i in range(5):
		var ry   := -2.0 + float(i) * 2.5 + b
		var ring_a := 0.80 + (pulse * 0.10 if s else 0.0)
		draw_arc(Vector2(0, ry), 7.5, 0, TAU, 14, Color(copper.r, copper.g, copper.b, ring_a), 2.0)
	# Glowing rune engravings on column face
	draw_line(Vector2(-4, 0 + b), Vector2(-4, 5 + b), rune_c, 1.0)
	draw_line(Vector2(-6, 2 + b), Vector2(-2, 2 + b), rune_c, 1.0)
	draw_line(Vector2( 3, 0 + b), Vector2( 5, 2 + b), rune_c, 0.9)
	draw_line(Vector2( 5, 2 + b), Vector2( 3, 5 + b), rune_c, 0.9)

	# ── Central discharge rod ─────────────────────────────────────────────────
	# Rod shaft
	draw_rect(Rect2(-2.5, -22 + b, 5.0, 18), steel_l)
	draw_rect(Rect2(-0.9, -22 + b, 1.8, 18), Color(elec_l.r, elec_l.g, elec_l.b, 0.38))
	# Copper band collars on rod
	draw_rect(Rect2(-3.5, -15 + b, 7, 2.5), copper)
	draw_rect(Rect2(-3.5, -11 + b, 7, 2.5), copper)
	# Side prong arms
	draw_line(Vector2(-2.5, -19 + b), Vector2(-8,  -17 + b), steel_l, 1.8)
	draw_line(Vector2( 2.5, -19 + b), Vector2( 8,  -17 + b), steel_l, 1.8)
	draw_line(Vector2(-2.5, -15 + b), Vector2(-7,  -13 + b), copper,  1.5)
	draw_line(Vector2( 2.5, -15 + b), Vector2( 7,  -13 + b), copper,  1.5)

	# ── Top discharge sphere (dominates the silhouette) ───────────────────────
	var cap_a := 0.55 + pulse * 0.18
	# Outer energy halo
	draw_circle(Vector2(0, -24 + b), 10.5, Color(elec.r, elec.g, elec.b, 0.15 + cap_a * 0.12))
	# Steel shell
	draw_circle(Vector2(0, -24 + b), 7.0, steel_l)
	# Copper equator ring
	draw_arc(Vector2(0, -24 + b), 7.5, 0, TAU, 18, copper, 1.5)
	# Energy core
	draw_circle(Vector2(0, -24 + b), 5.0, Color(elec.r, elec.g, elec.b, cap_a))
	draw_circle(Vector2(0, -24 + b), 2.8, Color(elec_l.r, elec_l.g, elec_l.b, 0.92))
	# Specular highlight
	draw_circle(Vector2(-2, -26 + b), 1.3, Color(1, 1, 1, 0.80))

	# ── Electrical effects ────────────────────────────────────────────────────
	if s:
		# Arcs from main cap to left capacitor node
		var lf := flicker * 2.0
		draw_line(Vector2(0, -24 + b),        Vector2(-8,  -17 + b),  Color(elec.r, elec.g, elec.b, 0.65), 1.5)
		draw_line(Vector2(-8, -17 + b),        Vector2(-17, -11 + b), Color(elec.r, elec.g, elec.b, 0.50), 1.2)
		draw_line(Vector2(0, -24 + b),         Vector2(-6 + lf, -17 + b), Color(1, 1, 1, 0.88), 0.8)
		draw_line(Vector2(-6 + lf, -17 + b),   Vector2(-17, -11 + b), Color(1, 1, 1, 0.72), 0.7)
		# Arcs from main cap to right capacitor node
		draw_line(Vector2(0, -24 + b),         Vector2(8,   -17 + b), Color(elec.r, elec.g, elec.b, 0.65), 1.5)
		draw_line(Vector2(8, -17 + b),          Vector2(17,  -11 + b), Color(elec.r, elec.g, elec.b, 0.50), 1.2)
		draw_line(Vector2(0, -24 + b),          Vector2(6 - lf, -17 + b), Color(1, 1, 1, 0.88), 0.8)
		draw_line(Vector2(6 - lf, -17 + b),     Vector2(17,  -11 + b), Color(1, 1, 1, 0.72), 0.7)
		# Radiating sparks from top cap
		for i in range(5):
			var ang := arc_rot + float(i) * TAU / 5.0
			var sp_len := 9.0 + sin(_anim_time * 11.0 + float(i) * 1.3) * 3.5
			var ep := Vector2(cos(ang), sin(ang)) * sp_len + Vector2(0, -24 + b)
			draw_line(Vector2(0, -24 + b), ep, Color(1, 1, 1, 0.82), 0.9)
		# Bright discharge glow
		var dg := 0.38 + pulse * 0.22
		draw_circle(Vector2(0, -24 + b), 12.0, Color(elec_l.r, elec_l.g, elec_l.b, dg * 0.32))
	else:
		# Idle: slow pulsing energy field around top cap
		var pa := 0.22 + pulse * 0.12
		draw_circle(Vector2(0, -24 + b), 10.0, Color(elec.r, elec.g, elec.b, pa))


# ── Infernal Core (type 10) ───────────────────────────────────────────────────
func _draw_infernal_core(b: float, s: bool) -> void:
	var stone   := Color(0.12, 0.08, 0.06)
	var stone_l := Color(0.22, 0.16, 0.11)
	var stone_d := Color(0.07, 0.04, 0.03)
	var lava    := Color(1.00, 0.40, 0.06)
	var molten  := Color(0.90, 0.15, 0.04)
	var yel     := Color(1.00, 0.82, 0.20)
	var wht     := Color(1.00, 0.98, 0.82)

	var pulse   := sin(_anim_time * 3.2)
	var flicker := sin(_anim_time * 11.0)

	# ── Shadow ────────────────────────────────────────────────────────────────
	draw_circle(Vector2(0, 24), 16, Color(0, 0, 0, 0.22))

	# ── Outer volcanic stone base ring (3D slab) ─────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-16, 12 + b), Vector2(16, 12 + b),
		Vector2(16,  20 + b), Vector2(-16, 20 + b)
	]), stone_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-16, 12 + b), Vector2(16, 12 + b),
		Vector2(13,   6 + b), Vector2(-13,  6 + b)
	]), stone_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(13, 6 + b), Vector2(16, 12 + b),
		Vector2(16, 20 + b), Vector2(13, 14 + b)
	]), stone_d)
	# Lava seeping through base cracks
	draw_line(Vector2(-10, 7 + b), Vector2(-4, 12 + b), Color(lava.r, lava.g, lava.b, 0.78), 1.5)
	draw_line(Vector2(  5, 7 + b), Vector2( 9, 13 + b), Color(lava.r, lava.g, lava.b, 0.68), 1.2)
	draw_line(Vector2( -2, 6 + b), Vector2( 2, 10 + b), Color(yel.r,  yel.g,  yel.b,  0.55), 1.0)

	# ── Left stone wall (containment ring) ───────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-16, -4 + b), Vector2(-8, -4 + b),
		Vector2(-8,   6 + b), Vector2(-16, 6 + b)
	]), stone)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-16, -4 + b), Vector2(-8, -4 + b),
		Vector2(-7,  -7 + b), Vector2(-15, -7 + b)
	]), stone_l)
	draw_line(Vector2(-14, -3 + b), Vector2(-10, 4 + b), Color(lava.r, lava.g, lava.b, 0.62), 1.2)

	# ── Right stone wall ──────────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(8, -4 + b), Vector2(16, -4 + b),
		Vector2(16,  6 + b), Vector2(8,   6 + b)
	]), stone)
	draw_colored_polygon(PackedVector2Array([
		Vector2(7,  -7 + b), Vector2(15, -7 + b),
		Vector2(16, -4 + b), Vector2( 8, -4 + b)
	]), stone_l)
	draw_line(Vector2(10, -3 + b), Vector2(13, 3 + b), Color(lava.r, lava.g, lava.b, 0.55), 1.0)

	# ── Lava pool (center floor) ──────────────────────────────────────────────
	var lp_a := 0.70 + pulse * 0.14
	draw_circle(Vector2(0, 4 + b), 8.0, Color(molten.r, molten.g, molten.b, lp_a * 0.50))
	draw_circle(Vector2(0, 4 + b), 5.5, Color(lava.r,   lava.g,   lava.b,   lp_a * 0.72))
	draw_circle(Vector2(0, 4 + b), 3.0, Color(yel.r,    yel.g,    yel.b,    lp_a * 0.60))

	# ── Magma vents around the rim ────────────────────────────────────────────
	for i in range(4):
		var va  := float(i) * TAU / 4.0 + PI * 0.25
		var vx  := cos(va) * 11.5
		var vy  := sin(va) * 3.5 + 6.0 + b
		var va2 := 0.55 + sin(_anim_time * 6.0 + float(i) * 1.5) * 0.20
		draw_circle(Vector2(vx, vy), 3.0, Color(molten.r, molten.g, molten.b, va2))
		draw_circle(Vector2(vx, vy), 1.6, Color(yel.r,    yel.g,    yel.b,    va2 + 0.15))

	# ── Central stone chimney column ──────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -6 + b), Vector2(6, -6 + b),
		Vector2(6,   4 + b), Vector2(-6, 4 + b)
	]), stone)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -6 + b), Vector2(6, -6 + b),
		Vector2(5,  -9 + b), Vector2(-5, -9 + b)
	]), stone_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(4, -6 + b), Vector2(6, -6 + b),
		Vector2(6,  4 + b), Vector2(4,  4 + b)
	]), stone_d)
	draw_line(Vector2(-4, -5 + b), Vector2(-2, 2 + b), Color(lava.r, lava.g, lava.b, 0.72), 1.3)
	draw_line(Vector2( 3, -4 + b), Vector2( 5, 1 + b), Color(lava.r, lava.g, lava.b, 0.62), 1.0)

	# ── Lava channels from walls into column ──────────────────────────────────
	draw_line(Vector2(-8, 0 + b), Vector2(-6, -1 + b), Color(lava.r, lava.g, lava.b, 0.70), 2.0)
	draw_line(Vector2( 8, 0 + b), Vector2( 6, -1 + b), Color(lava.r, lava.g, lava.b, 0.70), 2.0)
	draw_line(Vector2(-8, 0 + b), Vector2(-6, -1 + b), Color(yel.r,  yel.g,  yel.b,  0.30), 0.8)
	draw_line(Vector2( 8, 0 + b), Vector2( 6, -1 + b), Color(yel.r,  yel.g,  yel.b,  0.30), 0.8)

	# ── Molten crystal core (dominates upper silhouette) ─────────────────────
	var core_r := 8.5 + pulse * 1.2
	draw_circle(Vector2(0, -14 + b), core_r + 3.0, Color(molten.r, molten.g, molten.b, 0.18))
	draw_circle(Vector2(0, -14 + b), core_r + 1.0, Color(lava.r,   lava.g,   lava.b,   0.26))
	# Outer crystal facets
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -24 + b), Vector2(-7, -18 + b),
		Vector2(-8, -10 + b), Vector2(-4, -6 + b),
		Vector2( 4, -6 + b),  Vector2( 8, -10 + b),
		Vector2( 7, -18 + b)
	]), Color(molten.r, molten.g, molten.b, 0.90))
	# Inner hotter layer
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -22 + b), Vector2(-5, -16 + b),
		Vector2(-5, -10 + b), Vector2( 5, -10 + b),
		Vector2( 5, -16 + b)
	]), Color(lava.r, lava.g, lava.b, 0.94))
	# Yellow heat core
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -20 + b), Vector2(-3, -14 + b),
		Vector2(-2, -10 + b), Vector2( 2, -10 + b),
		Vector2( 3, -14 + b)
	]), Color(yel.r, yel.g, yel.b, 0.88))
	# White-hot inner point
	draw_circle(Vector2(0, -14 + b), 3.2, Color(wht.r, wht.g, wht.b, 0.90))
	draw_circle(Vector2(-1, -15 + b), 1.3, Color(1, 1, 1, 0.80))
	# Facet crack lines
	draw_line(Vector2(-7, -18 + b), Vector2(-4, -6 + b), Color(stone.r, stone.g, stone.b, 0.52), 0.8)
	draw_line(Vector2( 7, -18 + b), Vector2( 4, -6 + b), Color(stone.r, stone.g, stone.b, 0.52), 0.8)

	# ── Eruption when shooting ────────────────────────────────────────────────
	if s:
		var ef := 0.55 + flicker * 0.22
		for i in range(6):
			var ang  := float(i) * TAU / 6.0 + _anim_time * 2.5
			var dist := 14.0 + sin(_anim_time * 7.0 + float(i)) * 4.0
			var ep   := Vector2(cos(ang), sin(ang)) * dist + Vector2(0, -14 + b)
			var ea   := 0.68 + sin(_anim_time * 9.0 + float(i) * 1.2) * 0.20
			draw_circle(ep, 3.5, Color(lava.r, lava.g, lava.b, ea))
			draw_circle(ep, 2.0, Color(yel.r,  yel.g,  yel.b,  ea * 0.70))
		draw_circle(Vector2(0, -14 + b), core_r + 6.0, Color(lava.r, lava.g, lava.b, ef * 0.28))
		for i in range(3):
			var hx := float(i - 1) * 4.0
			draw_line(Vector2(hx, -24 + b), Vector2(hx + flicker, -30 + b),
				Color(yel.r, yel.g, yel.b, 0.52 - float(i) * 0.10), 1.0)
	else:
		var pa := 0.14 + pulse * 0.08
		draw_circle(Vector2(0, -14 + b), core_r + 4.0, Color(lava.r, lava.g, lava.b, pa))

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
	var wood_d  := Color(0.22, 0.14, 0.06)
	var wood    := Color(0.38, 0.24, 0.10)
	var wood_l  := Color(0.54, 0.38, 0.18)
	var iron    := Color(0.40, 0.40, 0.46)
	var iron_l  := Color(0.60, 0.62, 0.70)
	var bronze  := Color(0.68, 0.46, 0.16)
	var bolt_c  := Color(0.60, 0.46, 0.18)
	var bolt_t  := Color(0.62, 0.64, 0.72)
	var cord    := Color(0.82, 0.78, 0.60)

	var spread := 0.0 if s else 5.0

	# ── Shadow ────────────────────────────────────────────────────────────────
	draw_circle(Vector2(0, 24), 17, Color(0, 0, 0, 0.18))

	# ── A-frame support legs ──────────────────────────────────────────────────
	draw_line(Vector2(-17, 18 + b), Vector2(-4, 8 + b),  wood_d, 6.0)
	draw_line(Vector2(-17, 18 + b), Vector2(-4, 8 + b),  wood,   4.0)
	draw_line(Vector2( 17, 18 + b), Vector2( 4, 8 + b),  wood_d, 6.0)
	draw_line(Vector2( 17, 18 + b), Vector2( 4, 8 + b),  wood,   4.0)
	draw_line(Vector2(-11, 18 + b), Vector2(-3, 12 + b), wood_d, 4.5)
	draw_line(Vector2(-11, 18 + b), Vector2(-3, 12 + b), wood,   3.0)
	draw_line(Vector2( 11, 18 + b), Vector2( 3, 12 + b), wood_d, 4.5)
	draw_line(Vector2( 11, 18 + b), Vector2( 3, 12 + b), wood,   3.0)
	# Iron foot caps
	for fx: int in [-17, -11, 11, 17]:
		draw_circle(Vector2(fx, 18 + b), 3.2, iron)
		draw_circle(Vector2(fx, 18 + b), 1.8, iron_l)

	# ── Central pivot platform ────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, 8 + b), Vector2(8, 8 + b),
		Vector2(8, 14 + b), Vector2(-8, 14 + b)
	]), wood)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, 8 + b), Vector2(8, 8 + b),
		Vector2(6,  6 + b), Vector2(-6, 6 + b)
	]), wood_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(6, 8 + b), Vector2(8, 8 + b),
		Vector2(8, 14 + b), Vector2(6, 14 + b)
	]), wood_d)
	# Iron pivot ring
	draw_circle(Vector2(0, 10 + b), 4.5, iron)
	draw_circle(Vector2(0, 10 + b), 3.0, iron_l)
	draw_circle(Vector2(0, 10 + b), 1.5, wood)

	# ── Winch wheel (rear right) ──────────────────────────────────────────────
	draw_circle(Vector2(10, 11 + b), 5.5, wood_d)
	draw_circle(Vector2(10, 11 + b), 4.5, wood)
	for wi in range(4):
		var wa := float(wi) * PI * 0.5
		var wx := cos(wa) * 4.5 + 10.0
		var wy := sin(wa) * 4.5 + 11.0 + b
		draw_line(Vector2(10, 11 + b), Vector2(wx, wy), iron, 1.5)
	draw_circle(Vector2(10, 11 + b), 2.0, iron)
	draw_circle(Vector2(10, 11 + b), 1.0, iron_l)
	draw_line(Vector2(10, 6 + b), Vector2(0, 4 + b), Color(cord.r, cord.g, cord.b, 0.80), 1.2)

	# ── Spare bolt stack (left side) ──────────────────────────────────────────
	for i in range(3):
		var bx := -13.5 + float(i) * 0.6
		var by := 8.0 + float(i) * 2.2 + b
		draw_line(Vector2(bx, by - 5.0), Vector2(bx, by + 3.5), bolt_c, 2.8)
		draw_colored_polygon(PackedVector2Array([
			Vector2(bx, by - 5.0), Vector2(bx - 2.8, by - 2.2), Vector2(bx + 2.8, by - 2.2)
		]), bolt_t)

	# ── Main frame body (stock/trough) ────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, 2 + b), Vector2(5, 2 + b),
		Vector2(5,  8 + b), Vector2(-5, 8 + b)
	]), wood)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, 2 + b), Vector2(5, 2 + b),
		Vector2(4,  0 + b), Vector2(-4, 0 + b)
	]), wood_l)
	draw_line(Vector2(-5, 4 + b), Vector2(5, 4 + b), bronze, 1.5)
	draw_line(Vector2(-5, 7 + b), Vector2(5, 7 + b), bronze, 1.5)

	# ── Thick bow arms (dominant siege-weapon shape) ──────────────────────────
	# Left arm — 3D with shadow side
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5,  1 + b),          Vector2(-5,  5 + b),
		Vector2(-20, -5 + spread + b), Vector2(-18, -9 + spread + b)
	]), wood_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, -1 + b),           Vector2(-5,  3 + b),
		Vector2(-20, -7 + spread + b), Vector2(-18, -11 + spread + b)
	]), wood)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, -1 + b),           Vector2(-4,  0 + b),
		Vector2(-18, -7 + spread + b), Vector2(-19, -9 + spread + b)
	]), wood_l)
	# Right arm
	draw_colored_polygon(PackedVector2Array([
		Vector2(5,  1 + b),            Vector2(5,  5 + b),
		Vector2(20, -5 + spread + b),  Vector2(18, -9 + spread + b)
	]), wood_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(5, -1 + b),            Vector2(5,  3 + b),
		Vector2(20, -7 + spread + b),  Vector2(18, -11 + spread + b)
	]), wood)
	draw_colored_polygon(PackedVector2Array([
		Vector2(5, -1 + b),            Vector2(4,  0 + b),
		Vector2(18, -7 + spread + b),  Vector2(19, -9 + spread + b)
	]), wood_l)
	# Iron tip plates
	draw_rect(Rect2(-22, -12 + spread + b, 5, 4), iron)
	draw_rect(Rect2( 17, -12 + spread + b, 5, 4), iron)
	# Bronze joint brackets at arm roots
	draw_line(Vector2(-7, -1 + b), Vector2(-5, 3 + b), bronze, 3.5)
	draw_line(Vector2( 7, -1 + b), Vector2( 5, 3 + b), bronze, 3.5)

	# ── Bowstring ─────────────────────────────────────────────────────────────
	draw_line(Vector2(-19, -10 + spread + b), Vector2(0, -4 + b), cord, 1.8)
	draw_line(Vector2( 19, -10 + spread + b), Vector2(0, -4 + b), cord, 1.8)

	# ── Central iron rail ─────────────────────────────────────────────────────
	draw_rect(Rect2(-2.0, -22 + b, 4.0, 24), iron)
	draw_rect(Rect2(-0.8, -22 + b, 1.6, 24), Color(iron_l.r, iron_l.g, iron_l.b, 0.55))
	draw_line(Vector2(-4, -6 + b), Vector2(4, -6 + b), bronze, 1.8)
	draw_line(Vector2(-4, -1 + b), Vector2(4, -1 + b), bronze, 1.8)

	# ── Loaded bolt ───────────────────────────────────────────────────────────
	if not s:
		draw_rect(Rect2(-1.8, -22 + b, 3.6, 20), bolt_c)
		draw_rect(Rect2(-0.7, -22 + b, 1.4, 20), Color(0.78, 0.65, 0.32, 0.50))
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, -24 + b), Vector2(-4.5, -17 + b), Vector2(4.5, -17 + b)
		]), bolt_t)
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, -24 + b), Vector2(-1.8, -20 + b), Vector2(1.8, -20 + b)
		]), Color(1, 1, 1, 0.55))
		# Fletching
		draw_colored_polygon(PackedVector2Array([
			Vector2(-4.5, -5 + b), Vector2(-1.8, -5 + b), Vector2(-1.8, -12 + b)
		]), Color(0.65, 0.50, 0.28, 0.88))
		draw_colored_polygon(PackedVector2Array([
			Vector2( 4.5, -5 + b), Vector2( 1.8, -5 + b), Vector2( 1.8, -12 + b)
		]), Color(0.65, 0.50, 0.28, 0.88))
	else:
		if _shoot_anim > 0.05:
			draw_rect(Rect2(-1.8, -46 + b, 3.6, 20), bolt_c)
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, -48 + b), Vector2(-4.5, -41 + b), Vector2(4.5, -41 + b)
			]), bolt_t)


# ── Arcane Cannon (type 12) ───────────────────────────────────────────────────
func _draw_arcane_cannon(b: float, s: bool) -> void:
	var charge_frac := float(_arcane_charge % 15) / 15.0

	var stone   := Color(0.24, 0.18, 0.32)
	var stone_l := Color(0.38, 0.30, 0.50)
	var stone_d := Color(0.13, 0.09, 0.20)
	var silver  := Color(0.70, 0.72, 0.84)
	var silver_l:= Color(0.90, 0.94, 1.00)
	var pink    := Color(0.95, 0.40, 0.72)
	var crystal := pink.lerp(Color(0.52, 0.22, 0.98), charge_frac)
	var crys_l  := Color(minf(crystal.r + 0.25, 1.0), minf(crystal.g + 0.20, 1.0), minf(crystal.b + 0.08, 1.0))
	var blue_e  := Color(0.18, 0.58, 1.00)
	var rune_c  := Color(0.85, 0.52, 1.00, 0.85)

	var spin_sp := 1.8 + charge_frac * 3.5
	var pulse   := sin(_anim_time * 3.5)
	var core_r  := 8.5 + charge_frac * 2.5 + pulse * 0.8

	# ── Shadow ────────────────────────────────────────────────────────────────
	draw_circle(Vector2(0, 24), 14, Color(0, 0, 0, 0.18))

	# ── Heavy arcane machine base (3D box) ────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, 12 + b), Vector2(14, 12 + b),
		Vector2(14,  20 + b), Vector2(-14, 20 + b)
	]), stone_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, 12 + b), Vector2(14, 12 + b),
		Vector2(11,   6 + b), Vector2(-11,  6 + b)
	]), stone)
	draw_colored_polygon(PackedVector2Array([
		Vector2(11, 6 + b), Vector2(14, 12 + b),
		Vector2(14, 20 + b), Vector2(11, 14 + b)
	]), stone_d)
	draw_line(Vector2(-14, 12 + b), Vector2(14, 12 + b), silver, 1.0)
	for bx: int in [-9, 0, 9]:
		draw_circle(Vector2(bx, 8 + b), 2.0, silver)
		draw_circle(Vector2(bx, 8 + b), 1.0, silver_l)

	# ── Side machine housings ─────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -2 + b), Vector2(-7, -2 + b),
		Vector2(-7,   6 + b), Vector2(-14, 6 + b)
	]), stone)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -2 + b), Vector2(-7, -2 + b),
		Vector2(-6,  -5 + b), Vector2(-13, -5 + b)
	]), stone_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(7, -2 + b), Vector2(14, -2 + b),
		Vector2(14,  6 + b), Vector2(7,   6 + b)
	]), stone)
	draw_colored_polygon(PackedVector2Array([
		Vector2(6,  -5 + b), Vector2(13, -5 + b),
		Vector2(14, -2 + b), Vector2( 7, -2 + b)
	]), stone_l)
	draw_line(Vector2(-12, -1 + b), Vector2(-9, 4 + b), rune_c, 0.9)
	draw_line(Vector2(-12,  2 + b), Vector2(-8, 2 + b), rune_c, 0.9)
	draw_line(Vector2(  9, -1 + b), Vector2(11, 4 + b), rune_c, 0.9)

	# ── Crystal power conduits ────────────────────────────────────────────────
	var ca := 0.50 + charge_frac * 0.30
	draw_line(Vector2(-10, -3 + b), Vector2(-5, -8 + b), Color(crystal.r, crystal.g, crystal.b, ca), 2.2)
	draw_line(Vector2( 10, -3 + b), Vector2( 5, -8 + b), Color(crystal.r, crystal.g, crystal.b, ca), 2.2)
	draw_line(Vector2(-10, -3 + b), Vector2(-5, -8 + b), Color(crys_l.r,  crys_l.g,  crys_l.b,  0.30), 0.8)
	draw_line(Vector2( 10, -3 + b), Vector2( 5, -8 + b), Color(crys_l.r,  crys_l.g,  crys_l.b,  0.30), 0.8)

	# ── Cannon barrel (points forward / up) ───────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5.5, 6 + b), Vector2(5.5, 6 + b),
		Vector2(3.5, -8 + b), Vector2(-3.5, -8 + b)
	]), stone_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(2.5, 6 + b), Vector2(5.5, 6 + b),
		Vector2(3.5, -8 + b), Vector2(2.0, -6 + b)
	]), stone_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5.5, 6 + b), Vector2(5.5, 6 + b),
		Vector2( 4.5, 4 + b), Vector2(-4.5, 4 + b)
	]), stone)
	# Iron barrel bands
	draw_rect(Rect2(-5.5, 1 + b, 11, 2.5), silver)
	draw_rect(Rect2(-5.0, -2 + b, 10, 2.0), silver)
	# Arcane focusing lens at barrel tip
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4.5, -8 + b), Vector2(4.5, -8 + b),
		Vector2( 3.5, -6 + b), Vector2(-3.5, -6 + b)
	]), silver)
	draw_arc(Vector2(0, -8 + b), 4.5, PI, TAU, 10, Color(crystal.r, crystal.g, crystal.b, 0.78), 2.2)
	draw_circle(Vector2(0, -8 + b), 2.5, Color(crystal.r, crystal.g, crystal.b, 0.90))
	draw_circle(Vector2(-1, -9 + b), 1.0, Color(1, 1, 1, 0.80))

	# ── Orbiting energy collection rings (isometric ellipse path) ────────────
	for i in range(3):
		var ang := _anim_time * spin_sp + float(i) * TAU / 3.0
		var ring_pts := PackedVector2Array()
		for j in range(22):
			var ra := float(j) / 21.0 * TAU + ang
			ring_pts.append(Vector2(
				cos(ra) * (core_r + 5.0),
				sin(ra) * (core_r + 5.0) * 0.42 - 14.0 + b
			))
		var ra2 := 0.42 + charge_frac * 0.40
		draw_polyline(ring_pts, Color(crystal.r, crystal.g, crystal.b, ra2), 1.8)

	# ── Floating crystal core (dominates silhouette) ──────────────────────────
	draw_circle(Vector2(0, -14 + b), core_r + 3.5, Color(crystal.r, crystal.g, crystal.b, 0.14 + charge_frac * 0.12))
	# Outer facets
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -24 + b), Vector2(-7, -18 + b),
		Vector2(-8, -10 + b), Vector2(-4, -7 + b),
		Vector2( 4, -7 + b),  Vector2( 8, -10 + b),
		Vector2( 7, -18 + b)
	]), Color(crystal.r * 0.72, crystal.g * 0.72, crystal.b * 0.72))
	# Mid crystal
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -23 + b), Vector2(-5, -17 + b),
		Vector2(-5, -10 + b), Vector2( 5, -10 + b),
		Vector2( 5, -17 + b)
	]), crystal)
	# Inner bright layer
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -21 + b), Vector2(-3, -15 + b),
		Vector2(-2, -10 + b), Vector2( 2, -10 + b),
		Vector2( 3, -15 + b)
	]), crys_l)
	# Hot core + highlight
	draw_circle(Vector2(0, -15 + b), 3.2, Color(crys_l.r, crys_l.g, crys_l.b, 0.92))
	draw_circle(Vector2(-1, -16 + b), 1.3, Color(1, 1, 1, 0.82))
	# Facet edge lines
	draw_line(Vector2(-7, -18 + b), Vector2(-4, -7 + b), Color(stone_d.r, stone_d.g, stone_d.b, 0.38), 0.7)
	draw_line(Vector2( 7, -18 + b), Vector2( 4, -7 + b), Color(stone_d.r, stone_d.g, stone_d.b, 0.38), 0.7)
	# Silver rune trim ring
	draw_arc(Vector2(0, -14 + b), core_r + 0.5, 0, TAU, 20, Color(silver.r, silver.g, silver.b, 0.50), 1.2)

	# ── Charge arc indicator ──────────────────────────────────────────────────
	if charge_frac > 0.0:
		draw_arc(Vector2(0, -14 + b), core_r + 7.0,
			-PI * 0.5, -PI * 0.5 + TAU * charge_frac,
			32, Color(blue_e.r, blue_e.g, blue_e.b, 0.82), 2.5)

	# ── Shooting effects ──────────────────────────────────────────────────────
	if s:
		if _arcane_charge % 15 == 0 and _arcane_charge > 0:
			for i in range(8):
				var sa := float(i) * TAU / 8.0
				var sp := Vector2(cos(sa), sin(sa)) * (core_r + 10) + Vector2(0, -14 + b)
				draw_circle(sp, 4.5, Color(blue_e.r, blue_e.g, blue_e.b, 0.90))
			draw_circle(Vector2(0, -14 + b), core_r + 9.0, Color(blue_e.r, blue_e.g, blue_e.b, 0.28))
		else:
			for i in range(6):
				var sa := float(i) * TAU / 6.0 + _anim_time * 5.0
				var sp := Vector2(cos(sa), sin(sa)) * (core_r + 5) + Vector2(0, -14 + b)
				draw_circle(sp, 2.8, Color(crystal.r, crystal.g, crystal.b, 0.85))

	# ── Blue laser beams ──────────────────────────────────────────────────────
	if _arcane_laser_alpha > 0.0:
		var a := _arcane_laser_alpha
		for enemy in _arcane_laser_targets:
			if is_instance_valid(enemy):
				var laser_end : Vector2 = enemy.position - position
				draw_line(Vector2(0, -14 + b), laser_end, Color(0.10, 0.50, 1.0, a * 0.85), 5.0)
				draw_line(Vector2(0, -14 + b), laser_end, Color(0.55, 0.88, 1.0, a * 0.70), 2.0)
				draw_circle(laser_end, 5.0, Color(0.20, 0.65, 1.0, a * 0.80))
		draw_circle(Vector2(0, -14 + b), core_r + 10, Color(0.20, 0.65, 1.0, a * 0.30))


# ── Blade Assassin (type 30) ─────────────────────────────────────────────────
func _draw_blade_assassin(b: float, s: bool) -> void:
	var dark    := Color(0.06, 0.04, 0.08)
	var armor   := Color(0.13, 0.08, 0.18)
	var cloak   := Color(0.09, 0.06, 0.13)
	var steel   := Color(0.80, 0.86, 0.96)
	var edge    := Color(0.96, 0.98, 1.00)
	var crimson := Color(0.88, 0.10, 0.16)
	var crim_l  := Color(1.00, 0.38, 0.42)
	var shadow  := Color(0.08, 0.04, 0.14)

	var sf    := clampf(_shoot_anim / 0.35, 0.0, 1.0)
	var pulse := sin(_anim_time * 4.0)

	# ── Drop shadow ───────────────────────────────────────────────────────────
	draw_circle(Vector2(0, 24), 14, Color(0, 0, 0, 0.24))

	# ── Shadow smoke tendrils ─────────────────────────────────────────────────
	for i in range(3):
		var sa := _anim_time * 1.4 + float(i) * 2.1
		var sx := cos(sa) * (4.5 + float(i) * 2.2)
		var sy := 19.0 - float(i) * 6.0 + b
		draw_circle(Vector2(sx, sy), 4.2 - float(i) * 0.9,
			Color(shadow.r, shadow.g, shadow.b, 0.22 - float(i) * 0.06))

	# ── Base platform ─────────────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, 14 + b), Vector2(12, 14 + b),
		Vector2(12,  20 + b), Vector2(-12, 20 + b)
	]), dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, 14 + b), Vector2(12, 14 + b),
		Vector2(10,  10 + b), Vector2(-10, 10 + b)
	]), armor)
	# Crimson rune seals on base
	draw_line(Vector2(-8, 11 + b), Vector2(-5, 14 + b), Color(crimson.r, crimson.g, crimson.b, 0.58), 0.9)
	draw_line(Vector2( 5, 11 + b), Vector2( 8, 14 + b), Color(crimson.r, crimson.g, crimson.b, 0.58), 0.9)
	draw_line(Vector2(-3, 10 + b), Vector2( 3, 10 + b), Color(crimson.r, crimson.g, crimson.b, 0.48), 0.8)

	# ── Cloak body ────────────────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -20 + b), Vector2(-13, 12 + b), Vector2(13, 12 + b)
	]), cloak)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -14 + b), Vector2(-5, 8 + b), Vector2(5, 8 + b)
	]), dark)
	# Armor plating on chest
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -12 + b), Vector2(-6, -2 + b),
		Vector2(-4,  4 + b), Vector2( 4,  4 + b),
		Vector2( 6, -2 + b)
	]), armor)
	# Crimson chest rune cross
	draw_line(Vector2(0, -10 + b), Vector2(0, -3 + b), Color(crimson.r, crimson.g, crimson.b, 0.75), 1.2)
	draw_line(Vector2(-3, -7 + b), Vector2(3, -7 + b), Color(crimson.r, crimson.g, crimson.b, 0.65), 1.0)

	# ── Hood ──────────────────────────────────────────────────────────────────
	draw_circle(Vector2(0, -17 + b), 9.5, dark)
	draw_circle(Vector2(0, -18 + b), 8.5, cloak)
	draw_circle(Vector2(0, -17 + b), 6.0, dark)
	# Crimson glowing eyes
	var eye_a := 0.55 + sf * 0.50
	for ex in [-3.0, 3.0]:
		draw_circle(Vector2(ex, -17 + b), 2.8 + sf * 0.8, Color(crimson.r, crimson.g, crimson.b, eye_a * 0.45))
		draw_circle(Vector2(ex, -17 + b), 1.8 + sf * 0.4, Color(crimson.r, crimson.g, crimson.b, eye_a))
		draw_circle(Vector2(ex, -17 + b), 0.8,             Color(crim_l.r, crim_l.g, crim_l.b, eye_a))

	# ── Floating blade fragments (3 shards orbiting the figure) ──────────────
	var frag_rot := _anim_time * 2.0
	for i in range(3):
		var fa   := frag_rot + float(i) * TAU / 3.0
		var fx   := cos(fa) * 14.0
		var fy   := sin(fa) * 14.0 * 0.48 + b
		var fang := fa + PI * 0.5
		var fd   := Vector2(cos(fang), sin(fang)) * 5.5
		draw_line(Vector2(fx - fd.x, fy - fd.y), Vector2(fx + fd.x, fy + fd.y),
			Color(steel.r, steel.g, steel.b, 0.68), 1.5)
		draw_line(Vector2(fx - fd.x * 0.5, fy - fd.y * 0.5),
				  Vector2(fx + fd.x * 0.5, fy + fd.y * 0.5),
			Color(crimson.r, crimson.g, crimson.b, 0.55), 0.8)

	# ── Left longsword ────────────────────────────────────────────────────────
	var lg_base := Vector2(-8, 2 + b)
	var lg_tip  := Vector2(-18, -28 + b).lerp(Vector2(-34, 0 + b), sf)
	var lg_dir  := (lg_tip - lg_base).normalized()
	var lg_perp := Vector2(-lg_dir.y, lg_dir.x)
	draw_colored_polygon(PackedVector2Array([
		lg_base + lg_perp * 4.0,
		lg_base - lg_perp * 1.5,
		lg_tip  - lg_perp * 0.4,
		lg_tip  + lg_perp * 0.4,
	]), steel)
	draw_line(lg_base + lg_perp * 1.6, lg_tip, Color(crimson.r, crimson.g, crimson.b, 0.80), 1.1)
	draw_line(lg_base + lg_perp * 4.0, lg_tip + lg_perp * 0.4, edge, 0.9)
	draw_line(lg_base + lg_perp * 6.2, lg_base - lg_perp * 4.8, steel,   3.2)
	draw_line(lg_base + lg_perp * 6.2, lg_base - lg_perp * 4.8, Color(crimson.r, crimson.g, crimson.b, 0.48), 1.0)
	draw_line(lg_base, lg_base - lg_dir * 10.0, Color(0.10, 0.07, 0.05), 2.8)
	draw_line(lg_base, lg_base - lg_dir *  5.0, Color(crimson.r, crimson.g, crimson.b, 0.38), 1.0)

	# ── Right longsword (mirrored) ────────────────────────────────────────────
	var rg_base := Vector2(8, 2 + b)
	var rg_tip  := Vector2(18, -28 + b).lerp(Vector2(34, 0 + b), sf)
	var rg_dir  := (rg_tip - rg_base).normalized()
	var rg_perp := Vector2(-rg_dir.y, rg_dir.x)
	draw_colored_polygon(PackedVector2Array([
		rg_base - rg_perp * 4.0,
		rg_base + rg_perp * 1.5,
		rg_tip  + rg_perp * 0.4,
		rg_tip  - rg_perp * 0.4,
	]), steel)
	draw_line(rg_base - rg_perp * 1.6, rg_tip, Color(crimson.r, crimson.g, crimson.b, 0.80), 1.1)
	draw_line(rg_base - rg_perp * 4.0, rg_tip - rg_perp * 0.4, edge, 0.9)
	draw_line(rg_base - rg_perp * 6.2, rg_base + rg_perp * 4.8, steel,   3.2)
	draw_line(rg_base - rg_perp * 6.2, rg_base + rg_perp * 4.8, Color(crimson.r, crimson.g, crimson.b, 0.48), 1.0)
	draw_line(rg_base, rg_base - rg_dir * 10.0, Color(0.10, 0.07, 0.05), 2.8)
	draw_line(rg_base, rg_base - rg_dir *  5.0, Color(crimson.r, crimson.g, crimson.b, 0.38), 1.0)

	# ── Crimson slash flash on attack ─────────────────────────────────────────
	if sf > 0.1:
		draw_circle(Vector2(0, -17 + b), 11 + sf * 5.0, Color(crimson.r, crimson.g, crimson.b, 0.18 * sf))
		for i in range(2):
			var arc_a := (PI * 0.8 if i == 0 else PI * 1.2) + sf * PI * 0.4
			draw_arc(Vector2(0, -4 + b), 20 + sf * 4, arc_a, arc_a + PI * 0.35,
				12, Color(crimson.r, crimson.g, crimson.b, 0.65 * sf), 2.0)


# ── Axe Warrior (type 31) ────────────────────────────────────────────────────
func _draw_axe_warrior(b: float, s: bool) -> void:
	var steel   := Color(0.62, 0.66, 0.76)
	var steel_l := Color(0.82, 0.86, 0.96)
	var steel_d := Color(0.36, 0.38, 0.46)
	var bronze  := Color(0.70, 0.48, 0.16)
	var bronze_l:= Color(0.88, 0.66, 0.28)
	var leather := Color(0.38, 0.22, 0.10)
	var leather_d:=Color(0.22, 0.12, 0.05)
	var fur     := Color(0.52, 0.40, 0.26)
	var fur_d   := Color(0.34, 0.24, 0.12)
	var skin    := Color(0.75, 0.52, 0.32)
	var bone    := Color(0.88, 0.84, 0.74)

	var sf    := clampf(_shoot_anim / 0.35, 0.0, 1.0)
	var pulse := sin(_anim_time * 3.0)

	# Shadow
	draw_circle(Vector2(0, 24), 15, Color(0, 0, 0, 0.22))

	# Heavy boots
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, 14 + b), Vector2(-2, 14 + b),
		Vector2(-2, 20 + b),  Vector2(-12, 20 + b)
	]), leather_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(2, 14 + b),  Vector2(12, 14 + b),
		Vector2(12, 20 + b), Vector2(2, 20 + b)
	]), leather_d)
	draw_line(Vector2(-12, 16 + b), Vector2(-2, 16 + b), bronze, 1.2)
	draw_line(Vector2(2, 16 + b),   Vector2(12, 16 + b), bronze, 1.2)

	# Armored greaves
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, 4 + b), Vector2(-2, 4 + b),
		Vector2(-2, 14 + b), Vector2(-11, 14 + b)
	]), steel_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(2, 4 + b),  Vector2(11, 4 + b),
		Vector2(11, 14 + b), Vector2(2, 14 + b)
	]), steel_d)
	draw_line(Vector2(-10, 6 + b), Vector2(-3, 6 + b), steel, 1.0)
	draw_line(Vector2(3, 6 + b),   Vector2(10, 6 + b), steel, 1.0)

	# Fur loincloth with trophy bones
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, 4 + b), Vector2(12, 4 + b),
		Vector2(12, 8 + b),  Vector2(-12, 8 + b)
	]), fur)
	draw_line(Vector2(-12, 4 + b), Vector2(12, 4 + b), fur_d, 1.5)
	for _bx in [-8, -4, 0, 4, 8]:
		draw_line(Vector2(_bx, 4 + b), Vector2(_bx + 1, 8 + b), bone, 1.2)

	# Chest plate with battle scars and tribal rune
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -8 + b), Vector2(12, -8 + b),
		Vector2(11, 4 + b),   Vector2(-11, 4 + b)
	]), steel)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -8 + b), Vector2(12, -8 + b),
		Vector2(10, -6 + b),  Vector2(-10, -6 + b)
	]), steel_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(8, -8 + b), Vector2(12, -8 + b),
		Vector2(11, 4 + b), Vector2(8, 4 + b)
	]), steel_d)
	# Battle damage lines
	draw_line(Vector2(-6, -6 + b), Vector2(-2, -1 + b), steel_d, 0.8)
	draw_line(Vector2(2, -5 + b),  Vector2(5, 0 + b),   steel_d, 0.8)
	# Bronze tribal rune
	draw_line(Vector2(0, -7 + b),   Vector2(0, 2 + b),  bronze, 1.2)
	draw_line(Vector2(-4, -4 + b),  Vector2(4, -4 + b), bronze, 1.2)
	draw_line(Vector2(-3, -1 + b),  Vector2(3, -1 + b), bronze, 0.8)

	# Fur mantle across shoulders
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -8 + b), Vector2(14, -8 + b),
		Vector2(11, -14 + b), Vector2(-11, -14 + b)
	]), fur)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -8 + b), Vector2(12, -8 + b),
		Vector2(9, -13 + b),  Vector2(-9, -13 + b)
	]), fur_d)

	# Massive shoulder pauldrons — left
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -10 + b), Vector2(-22, -8 + b),
		Vector2(-24, -2 + b),  Vector2(-20, 2 + b),
		Vector2(-14, -2 + b)
	]), steel)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -10 + b), Vector2(-22, -8 + b),
		Vector2(-20, -6 + b),  Vector2(-14, -8 + b)
	]), steel_l)
	draw_line(Vector2(-22, -8 + b), Vector2(-24, -2 + b), steel_d, 1.5)
	draw_arc(Vector2(-19, -4 + b), 5.5, PI * 0.3, PI * 1.1, 8, bronze, 1.5)
	# Trophy skull on left pauldron
	draw_circle(Vector2(-20, -6 + b), 2.8, bone)
	draw_circle(Vector2(-20, -6 + b), 2.0, leather_d)
	draw_line(Vector2(-21.5, -5 + b), Vector2(-18.5, -5 + b), bone, 0.8)

	# Massive shoulder pauldrons — right
	draw_colored_polygon(PackedVector2Array([
		Vector2(14, -10 + b), Vector2(22, -8 + b),
		Vector2(24, -2 + b),  Vector2(20, 2 + b),
		Vector2(14, -2 + b)
	]), steel)
	draw_colored_polygon(PackedVector2Array([
		Vector2(14, -10 + b), Vector2(22, -8 + b),
		Vector2(20, -6 + b),  Vector2(14, -8 + b)
	]), steel_l)
	draw_line(Vector2(22, -8 + b), Vector2(24, -2 + b), steel_d, 1.5)
	draw_arc(Vector2(19, -4 + b), 5.5, PI * 1.9, PI * 2.7, 8, bronze, 1.5)
	draw_circle(Vector2(20, -6 + b), 2.8, bone)
	draw_circle(Vector2(20, -6 + b), 2.0, leather_d)
	draw_line(Vector2(18.5, -5 + b), Vector2(21.5, -5 + b), bone, 0.8)

	# Heavy helmet (layered steel skull cap)
	draw_circle(Vector2(0, -19 + b), 10, steel_d)
	draw_circle(Vector2(0, -20 + b), 9,  steel)
	draw_circle(Vector2(0, -21 + b), 7,  steel_l)
	draw_rect(Rect2(-10, -15 + b, 20, 3.5), steel_d)
	draw_rect(Rect2(-10, -15 + b, 20, 1.5), bronze)
	# Cheek guards
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -15 + b), Vector2(-8, -15 + b),
		Vector2(-6, -10 + b),  Vector2(-9, -10 + b)
	]), steel_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(8, -15 + b),  Vector2(10, -15 + b),
		Vector2(9, -10 + b),  Vector2(6, -10 + b)
	]), steel_d)
	draw_line(Vector2(0, -15 + b), Vector2(0, -10 + b), steel_d, 2.5)  # nose guard
	# Eyes
	draw_circle(Vector2(-3.5, -17 + b), 2.2, skin)
	draw_circle(Vector2( 3.5, -17 + b), 2.2, skin)
	draw_line(Vector2(-6, -19 + b), Vector2(-2, -18 + b), steel_d, 1.8)
	draw_line(Vector2( 2, -18 + b), Vector2( 6, -19 + b), steel_d, 1.8)
	draw_circle(Vector2(-3.5, -16.5 + b), 1.0, Color(0.12, 0.04, 0.04))
	draw_circle(Vector2( 3.5, -16.5 + b), 1.0, Color(0.12, 0.04, 0.04))
	# Bronze tribal mark on helm
	draw_line(Vector2(-3, -24 + b), Vector2(3, -24 + b), bronze, 1.5)
	draw_line(Vector2(0, -27 + b),  Vector2(0, -22 + b), bronze, 1.5)
	# Horns (large, curved backward)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9, -20 + b), Vector2(-7, -29 + b), Vector2(-15, -23 + b)
	]), steel_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9, -20 + b), Vector2(-7, -28 + b), Vector2(-14, -22 + b)
	]), steel)
	draw_colored_polygon(PackedVector2Array([
		Vector2(9, -20 + b), Vector2(7, -29 + b), Vector2(15, -23 + b)
	]), steel_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(9, -20 + b), Vector2(7, -28 + b), Vector2(14, -22 + b)
	]), steel)
	draw_line(Vector2(-9, -20 + b),  Vector2(-11, -22 + b), bronze, 1.5)
	draw_line(Vector2( 9, -20 + b),  Vector2( 11, -22 + b), bronze, 1.5)

	# Arms with bronze bracers
	var l_hand_rest   := Vector2(-18, -10 + b)
	var l_hand_attack := Vector2(-26,  10 + b)
	var l_hand := l_hand_rest.lerp(l_hand_attack, sf)
	var r_hand_rest   := Vector2(18, -10 + b)
	var r_hand_attack := Vector2(26,  10 + b)
	var r_hand := r_hand_rest.lerp(r_hand_attack, sf)
	draw_line(Vector2(-12, -5 + b), l_hand, skin, 6.0)
	draw_line(Vector2( 12, -5 + b), r_hand, skin, 6.0)
	var l_bracer := Vector2(-12, -5 + b).lerp(l_hand, 0.7)
	var r_bracer := Vector2( 12, -5 + b).lerp(r_hand, 0.7)
	draw_circle(l_bracer, 4.5, bronze)
	draw_circle(l_bracer, 3.0, bronze_l)
	draw_circle(r_bracer, 4.5, bronze)
	draw_circle(r_bracer, 3.0, bronze_l)

	# Massive dual war axes — left
	var l_handle_tip  := l_hand + Vector2(-2, -14).lerp(Vector2(-4, -12), sf)
	var l_handle_butt := l_hand + Vector2(1, 8).lerp(Vector2(2, 6), sf)
	draw_line(l_handle_tip, l_handle_butt, leather, 3.5)
	draw_line(l_handle_tip, l_handle_butt, Color(leather_d.r, leather_d.g, leather_d.b, 0.55), 1.2)
	var lb := l_hand + Vector2(-3, -10).lerp(Vector2(-5, -8), sf)
	draw_colored_polygon(PackedVector2Array([
		lb + Vector2(-15, -10), lb + Vector2(-5, -16),
		lb + Vector2(3, -6),    lb + Vector2(-4, 5),
		lb + Vector2(-15, 8)
	]), steel_d)
	draw_colored_polygon(PackedVector2Array([
		lb + Vector2(-13, -8), lb + Vector2(-5, -13),
		lb + Vector2(1, -5),   lb + Vector2(-4, 4),
		lb + Vector2(-13, 6)
	]), steel)
	draw_colored_polygon(PackedVector2Array([
		lb + Vector2(-11, -6), lb + Vector2(-5, -10),
		lb + Vector2(-1, -4),  lb + Vector2(-4, 2),
		lb + Vector2(-11, 4)
	]), steel_l)
	draw_line(lb + Vector2(-15, -10), lb + Vector2(-15, 8), Color(steel_l.r, steel_l.g, steel_l.b, 0.88), 1.5)
	draw_circle(lb + Vector2(-2, -1), 4.0, bronze)
	draw_circle(lb + Vector2(-2, -1), 2.5, bronze_l)

	# Massive dual war axes — right
	var r_handle_tip  := r_hand + Vector2(2, -14).lerp(Vector2(4, -12), sf)
	var r_handle_butt := r_hand + Vector2(-1, 8).lerp(Vector2(-2, 6), sf)
	draw_line(r_handle_tip, r_handle_butt, leather, 3.5)
	draw_line(r_handle_tip, r_handle_butt, Color(leather_d.r, leather_d.g, leather_d.b, 0.55), 1.2)
	var rb := r_hand + Vector2(3, -10).lerp(Vector2(5, -8), sf)
	draw_colored_polygon(PackedVector2Array([
		rb + Vector2(15, -10), rb + Vector2(5, -16),
		rb + Vector2(-3, -6),  rb + Vector2(4, 5),
		rb + Vector2(15, 8)
	]), steel_d)
	draw_colored_polygon(PackedVector2Array([
		rb + Vector2(13, -8), rb + Vector2(5, -13),
		rb + Vector2(-1, -5), rb + Vector2(4, 4),
		rb + Vector2(13, 6)
	]), steel)
	draw_colored_polygon(PackedVector2Array([
		rb + Vector2(11, -6), rb + Vector2(5, -10),
		rb + Vector2(1, -4),  rb + Vector2(4, 2),
		rb + Vector2(11, 4)
	]), steel_l)
	draw_line(rb + Vector2(15, -10), rb + Vector2(15, 8), Color(steel_l.r, steel_l.g, steel_l.b, 0.88), 1.5)
	draw_circle(rb + Vector2(2, -1), 4.0, bronze)
	draw_circle(rb + Vector2(2, -1), 2.5, bronze_l)

	# Battle aura on attack
	if sf > 0.1:
		draw_circle(Vector2(0, -2 + b), 32, Color(bronze.r, bronze.g, bronze.b, 0.12 * sf))
		draw_line(lb + Vector2(-15, -10), lb + Vector2(-20, -16), Color(1, 1, 1, 0.70 * sf), 1.5)
		draw_line(rb + Vector2(15, -10),  rb + Vector2(20, -16),  Color(1, 1, 1, 0.70 * sf), 1.5)


# ── Sun Dragon Tower (type 13) ────────────────────────────────────────────────
func _draw_sun_dragon(b: float, s: bool) -> void:
	var gold   := Color(1.00, 0.75, 0.08)
	var gold_l := Color(1.00, 0.95, 0.55)
	var gold_d := Color(0.70, 0.48, 0.04)
	var scale  := Color(0.72, 0.45, 0.06)
	var scl_l  := Color(0.88, 0.62, 0.18)
	var fire   := Color(1.00, 0.38, 0.05)
	var orange := Color(1.00, 0.62, 0.08)
	var wh_hot := Color(1.00, 0.98, 0.82)
	var eye_c  := Color(1.00, 0.96, 0.28)
	var pulse   := sin(_anim_time * 2.8)
	var orb_rot := _anim_time * 1.8
	var fa      := clampf(_shoot_anim / 0.35, 0.0, 1.0)

	draw_circle(Vector2(0, 24), 16, Color(0, 0, 0, 0.18))

	# Carved stone pedestal (3D box)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, 12 + b), Vector2(14, 12 + b),
		Vector2(14, 22 + b),  Vector2(-14, 22 + b)
	]), scale.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, 12 + b), Vector2(14, 12 + b),
		Vector2(11, 8 + b),   Vector2(-11, 8 + b)
	]), scale.darkened(0.1))
	draw_line(Vector2(-14, 12 + b), Vector2(14, 12 + b),   gold, 1.5)
	draw_line(Vector2(-14, 12 + b), Vector2(-11, 8 + b),   gold, 1.2)
	draw_line(Vector2( 14, 12 + b), Vector2( 11, 8 + b),   gold, 1.2)
	for _i in range(3):
		draw_arc(Vector2(float(_i - 1) * 8.0, 14 + b), 3.5, PI, TAU, 8, Color(gold_d.r, gold_d.g, gold_d.b, 0.50), 1.0)

	# Wing structures (left)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, 0 + b),    Vector2(-14, -4 + b),
		Vector2(-24, -14 + b), Vector2(-20, -4 + b),
		Vector2(-14, 2 + b)
	]), scale.darkened(0.1))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, 0 + b),    Vector2(-14, -4 + b),
		Vector2(-22, -12 + b), Vector2(-18, -4 + b)
	]), scl_l)
	draw_line(Vector2(-8, 0 + b),   Vector2(-22, -14 + b), Color(gold.r, gold.g, gold.b, 0.40), 0.8)
	draw_line(Vector2(-10, -2 + b), Vector2(-18, -12 + b), Color(gold.r, gold.g, gold.b, 0.30), 0.6)

	# Wing structures (right)
	draw_colored_polygon(PackedVector2Array([
		Vector2(8, 0 + b),    Vector2(14, -4 + b),
		Vector2(24, -14 + b), Vector2(20, -4 + b),
		Vector2(14, 2 + b)
	]), scale.darkened(0.1))
	draw_colored_polygon(PackedVector2Array([
		Vector2(8, 0 + b),    Vector2(14, -4 + b),
		Vector2(22, -12 + b), Vector2(18, -4 + b)
	]), scl_l)
	draw_line(Vector2(8, 0 + b),    Vector2(22, -14 + b),  Color(gold.r, gold.g, gold.b, 0.40), 0.8)
	draw_line(Vector2(10, -2 + b),  Vector2(18, -12 + b),  Color(gold.r, gold.g, gold.b, 0.30), 0.6)

	# Solar crystal core (glowing below neck)
	var cr := 7.0 + pulse * 1.0
	draw_circle(Vector2(0, 4 + b), cr + 4.0, Color(gold.r, gold.g, gold.b, 0.14 + pulse * 0.06))
	draw_circle(Vector2(0, 4 + b), cr,        Color(orange.r, orange.g, orange.b, 0.82))
	draw_circle(Vector2(0, 4 + b), cr - 2.5,  Color(gold_l.r, gold_l.g, gold_l.b, 0.88))
	draw_circle(Vector2(0, 4 + b), cr - 5.0,  Color(wh_hot.r, wh_hot.g, wh_hot.b, 0.85))
	draw_circle(Vector2(-1, 3 + b), 1.8, Color(1, 1, 1, 0.80))

	# Dragon neck
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -6 + b), Vector2(7, -6 + b),
		Vector2(8, 8 + b),   Vector2(-8, 8 + b)
	]), scale)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -6 + b), Vector2(7, -6 + b),
		Vector2(5, -4 + b),  Vector2(-5, -4 + b)
	]), scl_l)
	for _i in range(3):
		draw_arc(Vector2(-2 + float(_i) * 4, -1 + float(_i) * 3 + b), 3.5, -PI, 0, 8, Color(gold.r, gold.g, gold.b, 0.38), 1.2)

	# Dragon head
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -8 + b), Vector2(13, -8 + b),
		Vector2(14, -16 + b), Vector2(-14, -16 + b)
	]), scale)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -8 + b), Vector2(13, -8 + b),
		Vector2(10, -7 + b),  Vector2(-10, -7 + b)
	]), scl_l)
	draw_circle(Vector2(0, -20 + b), 8.5, scale.lightened(0.08))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -20 + b), Vector2(7, -20 + b),
		Vector2(7, -15 + b),  Vector2(-7, -15 + b)
	]), scale.darkened(0.08))
	draw_circle(Vector2(-4, -17 + b), 1.5, Color(orange.r, orange.g, orange.b, 0.68))
	draw_circle(Vector2( 4, -17 + b), 1.5, Color(orange.r, orange.g, orange.b, 0.68))
	draw_circle(Vector2(-5, -21 + b), 3.2, eye_c)
	draw_circle(Vector2( 5, -21 + b), 3.2, eye_c)
	draw_circle(Vector2(-5, -21 + b), 1.8, Color(0.72, 0.08, 0.04))
	draw_circle(Vector2( 5, -21 + b), 1.8, Color(0.72, 0.08, 0.04))
	draw_circle(Vector2(-4.5, -22 + b), 0.8, Color(1, 1, 1, 0.70))

	# Golden horns
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9, -27 + b), Vector2(-4, -27 + b), Vector2(-7, -38 + b)
	]), gold)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9, -27 + b), Vector2(-5, -27 + b), Vector2(-7, -37 + b)
	]), gold_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(4, -27 + b), Vector2(9, -27 + b), Vector2(7, -38 + b)
	]), gold)
	draw_colored_polygon(PackedVector2Array([
		Vector2(5, -27 + b), Vector2(9, -27 + b), Vector2(7, -37 + b)
	]), gold_l)

	# Orbiting solar crystals (4)
	for _i in range(4):
		var _oa := orb_rot + float(_i) * TAU / 4.0
		var _ox := cos(_oa) * 16.0
		var _oy := sin(_oa) * 7.0 + b
		var _oa2 := 0.52 + pulse * 0.14
		draw_circle(Vector2(_ox, _oy), 3.5, Color(gold.r, gold.g, gold.b, _oa2))
		draw_circle(Vector2(_ox, _oy), 2.0, Color(gold_l.r, gold_l.g, gold_l.b, _oa2 + 0.10))
		draw_circle(Vector2(_ox, _oy), 1.0, Color(1, 1, 1, 0.75))

	# Floating sun rune sigils (3)
	for _i in range(3):
		var _ra := -orb_rot * 0.5 + float(_i) * TAU / 3.0
		var _rx := cos(_ra) * 22.0
		var _ry := sin(_ra) * 10.0 + b
		var _rua := 0.28 + pulse * 0.10
		draw_circle(Vector2(_rx, _ry), 4.0, Color(gold.r, gold.g, gold.b, _rua * 0.50))
		draw_arc(Vector2(_rx, _ry), 3.5, 0, TAU, 8, Color(gold_l.r, gold_l.g, gold_l.b, _rua), 1.2)
		draw_line(Vector2(_rx - 2, _ry), Vector2(_rx + 2, _ry), Color(gold_l.r, gold_l.g, gold_l.b, _rua + 0.20), 0.8)
		draw_line(Vector2(_rx, _ry - 2), Vector2(_rx, _ry + 2), Color(gold_l.r, gold_l.g, gold_l.b, _rua + 0.20), 0.8)

	# Solar corona glow
	var ga := 0.14 + pulse * 0.05
	draw_arc(Vector2(0, -10 + b), 28, 0, TAU, 36, Color(gold.r, gold.g, gold.b, ga), 4.0)

	# Fire breath / solar blast
	if s and _shoot_anim > 0.05:
		for _i in range(5):
			var _off := Vector2(randi_range(-8, 8), -28 - _i * 8 + b)
			draw_circle(_off, 5.5 + float(_i) * 1.5, Color(fire.r, fire.g, fire.b, fa * (0.88 - float(_i) * 0.15)))
		draw_circle(Vector2(0, -32 + b), 11, Color(1, 0.92, 0.30, fa * 0.72))
		draw_circle(Vector2(0, -28 + b), 8,  Color(wh_hot.r, wh_hot.g, wh_hot.b, fa * 0.52))


# ── Storm Lord Tower (type 14) ────────────────────────────────────────────────
func _draw_storm_lord(b: float, s: bool) -> void:
	var dark    := Color(0.22, 0.26, 0.38)
	var armor   := Color(0.30, 0.34, 0.48)
	var armor_l := Color(0.45, 0.50, 0.65)
	var cloud   := Color(0.48, 0.58, 0.80)
	var cloud_l := Color(0.65, 0.76, 0.95)
	var elec    := Color(0.50, 0.82, 1.00)
	var elec_l  := Color(0.85, 0.96, 1.00)
	var pulse   := sin(_anim_time * 3.5)
	var arc_rot := _anim_time * 3.8

	draw_circle(Vector2(0, 24), 15, Color(0, 0, 0, 0.20))

	# Storm cloud base
	draw_circle(Vector2(-10, 13 + b), 9,  Color(dark.r, dark.g, dark.b, 0.70))
	draw_circle(Vector2(  0, 16 + b), 12, Color(dark.r, dark.g, dark.b, 0.70))
	draw_circle(Vector2( 10, 13 + b), 9,  Color(dark.r, dark.g, dark.b, 0.70))
	draw_circle(Vector2(-10, 13 + b), 8,  cloud)
	draw_circle(Vector2(  0, 16 + b), 11, cloud)
	draw_circle(Vector2( 10, 13 + b), 8,  cloud)
	draw_circle(Vector2( -5, 10 + b), 7,  cloud_l)
	draw_circle(Vector2(  5, 10 + b), 7,  cloud_l)
	draw_circle(Vector2(  0,  8 + b), 8,  cloud_l)
	# Base lightning bolts
	var ba := 0.55 + pulse * 0.20
	draw_line(Vector2(-5, 12 + b), Vector2(-8, 20 + b), Color(elec.r, elec.g, elec.b, ba),        1.8)
	draw_line(Vector2(-8, 20 + b), Vector2(-5, 25 + b), Color(elec.r, elec.g, elec.b, ba * 0.7),  1.5)
	draw_line(Vector2( 5, 12 + b), Vector2( 8, 20 + b), Color(elec.r, elec.g, elec.b, ba),        1.8)
	draw_line(Vector2( 8, 20 + b), Vector2( 5, 25 + b), Color(elec.r, elec.g, elec.b, ba * 0.7),  1.5)

	# Side storm cloud wisps
	draw_circle(Vector2(-18, 5 + b), 5.5, Color(dark.r, dark.g, dark.b, 0.55))
	draw_circle(Vector2(-18, 3 + b), 5.0, cloud)
	draw_circle(Vector2(-16, 2 + b), 4.0, cloud_l)
	draw_line(Vector2(-18, 8 + b), Vector2(-20, 14 + b), Color(elec.r, elec.g, elec.b, 0.58), 1.2)
	draw_line(Vector2(-20, 14 + b), Vector2(-17, 18 + b), Color(elec.r, elec.g, elec.b, 0.40), 1.0)
	draw_circle(Vector2(18, 5 + b), 5.5, Color(dark.r, dark.g, dark.b, 0.55))
	draw_circle(Vector2(18, 3 + b), 5.0, cloud)
	draw_circle(Vector2(16, 2 + b), 4.0, cloud_l)
	draw_line(Vector2(18, 8 + b), Vector2(20, 14 + b),   Color(elec.r, elec.g, elec.b, 0.58), 1.2)
	draw_line(Vector2(20, 14 + b), Vector2(17, 18 + b),  Color(elec.r, elec.g, elec.b, 0.40), 1.0)

	# Armored legs / lower body
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, 2 + b), Vector2(10, 2 + b),
		Vector2(10, 10 + b), Vector2(-10, 10 + b)
	]), dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, 2 + b), Vector2(10, 2 + b),
		Vector2(8, 0 + b),   Vector2(-8, 0 + b)
	]), armor)
	# Chest armor
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -10 + b), Vector2(11, -10 + b),
		Vector2(10, 2 + b),    Vector2(-10, 2 + b)
	]), armor)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -10 + b), Vector2(11, -10 + b),
		Vector2(9, -8 + b),    Vector2(-9, -8 + b)
	]), armor_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(8, -10 + b), Vector2(11, -10 + b),
		Vector2(10, 2 + b),  Vector2(8, 2 + b)
	]), dark)
	# Electric armor cracks
	draw_line(Vector2(-7, -8 + b), Vector2(-3, -2 + b), Color(elec.r, elec.g, elec.b, 0.62), 0.9)
	draw_line(Vector2(-3, -2 + b), Vector2(-5, 1 + b),  Color(elec.r, elec.g, elec.b, 0.48), 0.8)
	draw_line(Vector2(4, -7 + b),  Vector2(7, -1 + b),  Color(elec.r, elec.g, elec.b, 0.52), 0.8)

	# Thunder crystal core (chest)
	var tc_r := 4.5 + pulse * 0.8
	draw_circle(Vector2(0, -4 + b), tc_r + 2.5, Color(elec.r, elec.g, elec.b, 0.18))
	draw_circle(Vector2(0, -4 + b), tc_r,        Color(elec.r, elec.g, elec.b, 0.72))
	draw_circle(Vector2(0, -4 + b), tc_r - 2.0,  Color(elec_l.r, elec_l.g, elec_l.b, 0.85))
	draw_circle(Vector2(-1, -5 + b), 1.2, Color(1, 1, 1, 0.82))

	# Shoulder storm-armor — left
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -10 + b), Vector2(-18, -8 + b),
		Vector2(-20, -2 + b),  Vector2(-16, 2 + b),
		Vector2(-11, 0 + b)
	]), armor)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -10 + b), Vector2(-18, -8 + b),
		Vector2(-15, -7 + b),  Vector2(-11, -8 + b)
	]), armor_l)
	draw_line(Vector2(-18, -8 + b), Vector2(-20, -2 + b), Color(elec.r, elec.g, elec.b, 0.52), 1.0)
	draw_circle(Vector2(-18, -5 + b), 2.5, Color(elec.r, elec.g, elec.b, 0.58))
	# Shoulder storm-armor — right
	draw_colored_polygon(PackedVector2Array([
		Vector2(11, -10 + b), Vector2(18, -8 + b),
		Vector2(20, -2 + b),  Vector2(16, 2 + b),
		Vector2(11, 0 + b)
	]), armor)
	draw_colored_polygon(PackedVector2Array([
		Vector2(11, -10 + b), Vector2(18, -8 + b),
		Vector2(15, -7 + b),  Vector2(11, -8 + b)
	]), armor_l)
	draw_line(Vector2(18, -8 + b), Vector2(20, -2 + b), Color(elec.r, elec.g, elec.b, 0.52), 1.0)
	draw_circle(Vector2(18, -5 + b), 2.5, Color(elec.r, elec.g, elec.b, 0.58))

	# Head + lightning crown
	draw_circle(Vector2(0, -19 + b), 10, dark)
	draw_circle(Vector2(0, -20 + b), 8.5, armor)
	draw_circle(Vector2(0, -21 + b), 7.0, armor_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -21 + b), Vector2(7, -21 + b),
		Vector2(5, -17 + b),  Vector2(-5, -17 + b)
	]), Color(elec.r, elec.g, elec.b, 0.72 + pulse * 0.14))
	draw_line(Vector2(-7, -21 + b), Vector2(7, -21 + b), Color(elec_l.r, elec_l.g, elec_l.b, 0.55), 0.8)
	for _i in range(5):
		var _cx := float(_i - 2) * 4.5
		var _ch := 10.0 if abs(float(_i) - 2) < 0.5 else 6.0
		draw_line(Vector2(_cx, -27 + b), Vector2(_cx, -27 - _ch + b), Color(elec.r, elec.g, elec.b, 0.85), 1.5)
		draw_circle(Vector2(_cx, -27 - _ch + b), 1.2, Color(1, 1, 1, 0.90))

	# Rotating storm crystals (3)
	for _i in range(3):
		var _sa := arc_rot + float(_i) * TAU / 3.0
		var _sx := cos(_sa) * 15.0
		var _sy := sin(_sa) * 7.0 - 4.0 + b
		var _sa2 := 0.48 + pulse * 0.18
		draw_circle(Vector2(_sx, _sy), 4.0, Color(cloud_l.r, cloud_l.g, cloud_l.b, _sa2 * 0.45))
		draw_arc(Vector2(_sx, _sy), 3.5, 0, TAU, 6, Color(elec.r, elec.g, elec.b, _sa2), 1.8)
		draw_circle(Vector2(_sx, _sy), 1.5, Color(1, 1, 1, _sa2 + 0.10))

	# Floating lightning sigils (3)
	for _i in range(3):
		var _ra := -arc_rot * 0.6 + float(_i) * TAU / 3.0
		var _rx := cos(_ra) * 22.0
		var _ry := sin(_ra) * 9.0 - 4.0 + b
		var _rua := 0.28 + pulse * 0.12
		draw_line(Vector2(_rx - 2, _ry - 3), Vector2(_rx + 1, _ry),     Color(elec_l.r, elec_l.g, elec_l.b, _rua + 0.20), 1.2)
		draw_line(Vector2(_rx + 1, _ry),     Vector2(_rx - 1, _ry + 3), Color(elec_l.r, elec_l.g, elec_l.b, _rua + 0.10), 1.2)

	# Ambient storm glow
	var cga := 0.10 + pulse * 0.05
	draw_arc(Vector2(0, -8 + b), 26, 0, TAU, 30, Color(elec.r, elec.g, elec.b, cga), 4.0)

	# Active discharge
	if s:
		var _fl := 0.60 + sin(_anim_time * 17.0) * 0.30
		draw_arc(Vector2(0, -8 + b), 28, 0, TAU, 36, Color(elec_l.r, elec_l.g, elec_l.b, _fl * 0.45), 3.0)
		draw_line(Vector2(0, -19 + b), Vector2( 18, 8 + b), Color(1, 1, 1, _fl * 0.85), 1.2)
		draw_line(Vector2(0, -19 + b), Vector2(-18, 8 + b), Color(1, 1, 1, _fl * 0.85), 1.2)
		draw_circle(Vector2(0, -19 + b), 6, Color(1, 1, 1, _fl * 0.55))


# ── Chrono Mage Tower (type 15) ───────────────────────────────────────────────
func _draw_chrono_mage(b: float, s: bool) -> void:
	var gold    := Color(0.92, 0.80, 0.22)
	var gold_l  := Color(1.00, 0.96, 0.60)
	var gold_d  := Color(0.60, 0.50, 0.10)
	var robe    := Color(0.28, 0.32, 0.52)
	var robe_l  := Color(0.42, 0.48, 0.68)
	var robe_d  := Color(0.16, 0.18, 0.32)
	var blue    := Color(0.28, 0.65, 1.00)
	var teal    := Color(0.22, 0.92, 0.80)
	var skin    := Color(0.88, 0.72, 0.54)
	var white   := Color(0.92, 0.94, 1.00)
	var gear_rot  := _anim_time * 2.5
	var gear_rot2 := -_anim_time * 1.8
	var hour_ang  := _anim_time * 0.5
	var min_ang   := _anim_time * 2.5
	var pulse     := sin(_anim_time * 3.2)

	draw_circle(Vector2(0, 24), 12, Color(0, 0, 0, 0.18))

	# Time staff (left side, angled)
	draw_line(Vector2(-14, 22 + b), Vector2(-18, -26 + b), Color(gold_d.r, gold_d.g, gold_d.b, 0.80), 4.0)
	draw_line(Vector2(-14, 22 + b), Vector2(-18, -26 + b), gold, 2.0)
	for _ry in [-14, -4, 6, 16]:
		draw_line(Vector2(-15, float(_ry) + b), Vector2(-21, float(_ry) + b), gold_d, 1.0)
	# Staff crystal top
	draw_circle(Vector2(-18, -30 + b), 5.5, Color(blue.r, blue.g, blue.b, 0.78))
	draw_circle(Vector2(-18, -30 + b), 3.5, Color(teal.r, teal.g, teal.b, 0.88))
	draw_circle(Vector2(-18, -30 + b), 2.0, white)
	draw_circle(Vector2(-19.5, -31.5 + b), 0.9, Color(1, 1, 1, 0.78))
	draw_arc(Vector2(-18, -26 + b), 4.5, -PI, 0, 10, gold, 1.5)

	# Robe body (wide mage silhouette)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -10 + b), Vector2(13, -10 + b),
		Vector2(15, 24 + b),   Vector2(-15, 24 + b)
	]), robe)
	draw_colored_polygon(PackedVector2Array([
		Vector2(4, -10 + b),  Vector2(13, -10 + b),
		Vector2(15, 24 + b),  Vector2(6, 24 + b)
	]), robe_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4, -10 + b), Vector2(4, -10 + b),
		Vector2(5, 24 + b),   Vector2(-5, 24 + b)
	]), robe_l)
	draw_line(Vector2(-15, 20 + b), Vector2(15, 20 + b), gold, 1.8)
	draw_line(Vector2(-15, 23 + b), Vector2(15, 23 + b), gold_d, 1.0)
	draw_line(Vector2(-4, -10 + b), Vector2(-5, 24 + b), gold_d, 0.9)
	draw_line(Vector2( 4, -10 + b), Vector2( 5, 24 + b), gold_d, 0.9)

	# Belt with gold buckle and time rune
	draw_rect(Rect2(-12, -1 + b, 24, 4), gold_d)
	draw_rect(Rect2(-12, -1 + b, 24, 2), gold)
	draw_rect(Rect2(-3.5, -2 + b, 7, 6), gold)
	draw_rect(Rect2(-2, 0 + b, 4, 2), robe_d)
	draw_line(Vector2(-1, 0.5 + b), Vector2(1, 0.5 + b), white, 0.8)
	draw_line(Vector2(0, -0.5 + b), Vector2(0, 1.5 + b), white, 0.8)

	# Clockwork shoulder piece — left
	draw_circle(Vector2(-18, -8 + b), 7.5, robe_d)
	draw_circle(Vector2(-18, -9 + b), 6.5, robe)
	for _i in range(8):
		var _ga := float(_i) * TAU / 8.0 + gear_rot
		var _gx := cos(_ga) * 7.5 - 18.0
		var _gy := sin(_ga) * 7.5 - 8.0 + b
		draw_circle(Vector2(_gx, _gy), 1.5, gold)
	for _i in range(6):
		var _ga2 := float(_i) * TAU / 6.0 + gear_rot2
		var _gx2 := cos(_ga2) * 4.5 - 18.0
		var _gy2 := sin(_ga2) * 4.5 - 8.0 + b
		draw_circle(Vector2(_gx2, _gy2), 1.2, gold_l)
	draw_circle(Vector2(-18, -8 + b), 2.5, gold)
	draw_circle(Vector2(-18, -8 + b), 1.2, white)

	# Clockwork shoulder piece — right
	draw_circle(Vector2(18, -8 + b), 7.5, robe_d)
	draw_circle(Vector2(18, -9 + b), 6.5, robe)
	for _i in range(8):
		var _ga3 := float(_i) * TAU / 8.0 - gear_rot
		var _gx3 := cos(_ga3) * 7.5 + 18.0
		var _gy3 := sin(_ga3) * 7.5 - 8.0 + b
		draw_circle(Vector2(_gx3, _gy3), 1.5, gold)
	for _i in range(6):
		var _ga4 := float(_i) * TAU / 6.0 - gear_rot2
		var _gx4 := cos(_ga4) * 4.5 + 18.0
		var _gy4 := sin(_ga4) * 4.5 - 8.0 + b
		draw_circle(Vector2(_gx4, _gy4), 1.2, gold_l)
	draw_circle(Vector2(18, -8 + b), 2.5, gold)
	draw_circle(Vector2(18, -8 + b), 1.2, white)

	# Head + pointed hat
	draw_circle(Vector2(0, -16 + b), 7.5, skin)
	draw_circle(Vector2(-3, -17 + b), 1.5, Color(0.18, 0.12, 0.28))
	draw_circle(Vector2( 3, -17 + b), 1.5, Color(0.18, 0.12, 0.28))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4, -12 + b), Vector2(4, -12 + b),
		Vector2(3, -8 + b),   Vector2(-3, -8 + b)
	]), Color(0.72, 0.62, 0.50))
	# Hat (3 sections tapering to point)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -18 + b), Vector2(10, -18 + b),
		Vector2(8, -26 + b),   Vector2(-8, -26 + b)
	]), robe_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -26 + b), Vector2(8, -26 + b),
		Vector2(5, -34 + b),  Vector2(-5, -34 + b)
	]), robe)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, -34 + b), Vector2(5, -34 + b),
		Vector2(0, -42 + b)
	]), robe_l)
	draw_line(Vector2(-10, -18 + b), Vector2(10, -18 + b), gold, 1.8)
	draw_line(Vector2(-8, -26 + b),  Vector2(8, -26 + b),  gold, 1.5)
	draw_line(Vector2(-5, -34 + b),  Vector2(5, -34 + b),  gold, 1.2)

	# Floating hourglass (above hat, gently bobbing)
	var hg_cy := -50.0 + b + sin(_anim_time * 1.8) * 2.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, hg_cy - 5), Vector2(6, hg_cy - 5),
		Vector2(2, hg_cy - 1),  Vector2(-2, hg_cy - 1)
	]), Color(blue.r, blue.g, blue.b, 0.60))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2, hg_cy + 1), Vector2(2, hg_cy + 1),
		Vector2(6, hg_cy + 5),  Vector2(-6, hg_cy + 5)
	]), Color(blue.r, blue.g, blue.b, 0.60))
	draw_line(Vector2(-6, hg_cy - 5), Vector2(-2, hg_cy - 1), gold, 1.5)
	draw_line(Vector2( 6, hg_cy - 5), Vector2( 2, hg_cy - 1), gold, 1.5)
	draw_line(Vector2(-2, hg_cy + 1), Vector2(-6, hg_cy + 5), gold, 1.5)
	draw_line(Vector2( 2, hg_cy + 1), Vector2( 6, hg_cy + 5), gold, 1.5)
	draw_line(Vector2(-6, hg_cy - 5), Vector2(6, hg_cy - 5), gold, 2.0)
	draw_line(Vector2(-6, hg_cy + 5), Vector2(6, hg_cy + 5), gold, 2.0)
	draw_circle(Vector2(0, hg_cy), 1.8, Color(teal.r, teal.g, teal.b, 0.88))

	# Orbiting gear fragments (3)
	for _i in range(3):
		var _ga5 := gear_rot * 0.7 + float(_i) * TAU / 3.0
		var _gfx := cos(_ga5) * 20.0
		var _gfy := sin(_ga5) * 9.0 - 6.0 + b
		var _gfa := 0.42 + pulse * 0.14
		draw_circle(Vector2(_gfx, _gfy), 4.5, Color(robe_d.r, robe_d.g, robe_d.b, _gfa * 0.80))
		for _k in range(6):
			var _kk := float(_k) * TAU / 6.0 + gear_rot
			var _kx := cos(_kk) * 4.5 + _gfx
			var _ky := sin(_kk) * 4.5 + _gfy
			draw_circle(Vector2(_kx, _ky), 1.2, Color(gold.r, gold.g, gold.b, _gfa))
		draw_circle(Vector2(_gfx, _gfy), 2.0, gold)
		draw_circle(Vector2(_gfx, _gfy), 1.0, white)

	# Pulsing clock burst on attack — _chrono_pulse must be preserved
	if _chrono_pulse > 0.0:
		var _cp_t := clampf(_chrono_pulse / 0.45, 0.0, 1.0)
		var _cp_a := _cp_t * _cp_t
		var _cp_r := 14.0 + (1.0 - _cp_t) * 20.0
		draw_arc(Vector2(0, -14 + b), _cp_r, 0, TAU, 32,
			Color(teal.r, teal.g, teal.b, _cp_a * 0.7), 2.5)
		draw_arc(Vector2(0, -14 + b), _cp_r * 0.7, 0, TAU, 28,
			Color(0.55, 1.00, 0.85, _cp_a * 0.5), 1.5)
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
	var bark   := Color(0.38, 0.24, 0.10)
	var bark2  := Color(0.26, 0.14, 0.05)
	var bark_l := Color(0.52, 0.34, 0.16)
	var leaf   := Color(0.18, 0.72, 0.28)
	var leaf2  := Color(0.28, 0.92, 0.40)
	var leaf_d := Color(0.12, 0.50, 0.20)
	var gold   := Color(0.85, 0.75, 0.18)
	var glow   := Color(0.50, 1.00, 0.55)
	var vine   := Color(0.22, 0.55, 0.18)

	var pulse  := sin(_anim_time * 2.5)
	var leaf_t := _anim_time * 0.8

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.95, 0.95))
	draw_circle(Vector2(0, 24), 14, Color(0, 0, 0, 0.18))

	# Spreading ancient roots (5)
	draw_line(Vector2(-4, 18 + b), Vector2(-20, 26 + b), bark2, 4.5)
	draw_line(Vector2(-2, 20 + b), Vector2(-14, 28 + b), bark2, 3.0)
	draw_line(Vector2( 0, 20 + b), Vector2(  0, 28 + b), bark2, 3.5)
	draw_line(Vector2( 2, 20 + b), Vector2( 14, 28 + b), bark2, 3.0)
	draw_line(Vector2( 4, 18 + b), Vector2( 20, 26 + b), bark2, 4.5)
	draw_line(Vector2(-4, 18 + b), Vector2(-20, 26 + b), Color(bark_l.r, bark_l.g, bark_l.b, 0.45), 1.5)
	draw_line(Vector2( 4, 18 + b), Vector2( 20, 26 + b), Color(bark_l.r, bark_l.g, bark_l.b, 0.45), 1.5)

	# Trunk with bark cracking detail
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -10 + b), Vector2(8, -10 + b),
		Vector2(9, 22 + b),   Vector2(-9, 22 + b)
	]), bark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(3, -10 + b), Vector2(8, -10 + b),
		Vector2(9, 22 + b),  Vector2(4, 22 + b)
	]), bark2)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -10 + b), Vector2(-3, -10 + b),
		Vector2(-3, 22 + b),  Vector2(-8, 22 + b)
	]), Color(bark_l.r, bark_l.g, bark_l.b, 0.55))
	# Bark crack lines (golden sap)
	var ra := 0.55 + pulse * 0.22
	draw_line(Vector2(-4, -6 + b), Vector2(-6, 2 + b),  Color(gold.r, gold.g, gold.b, ra * 0.60), 1.0)
	draw_line(Vector2(-6, 2 + b),  Vector2(-4, 8 + b),  Color(gold.r, gold.g, gold.b, ra * 0.50), 1.0)
	draw_line(Vector2(3, -4 + b),  Vector2(5, 4 + b),   Color(gold.r, gold.g, gold.b, ra * 0.55), 1.0)

	# Sacred vines wrapping trunk
	draw_arc(Vector2(-2, 4 + b),  6.0, -PI * 0.5, PI * 0.6, 8, vine, 1.5)
	draw_arc(Vector2( 2, 12 + b), 6.0,  PI * 0.4, PI * 1.5, 8, vine, 1.5)

	# Tree spirit face on trunk
	# Brow ridge
	draw_line(Vector2(-6, -4 + b), Vector2(-2, -6 + b), bark2, 1.5)
	draw_line(Vector2( 2, -6 + b), Vector2( 6, -4 + b), bark2, 1.5)
	# Spirit eyes (glowing)
	draw_circle(Vector2(-4, -3 + b), 2.8, Color(glow.r, glow.g, glow.b, ra))
	draw_circle(Vector2( 4, -3 + b), 2.8, Color(glow.r, glow.g, glow.b, ra))
	draw_circle(Vector2(-4, -3 + b), 1.5, Color(1.0, 1.0, 1.0, ra + 0.10))
	draw_circle(Vector2( 4, -3 + b), 1.5, Color(1.0, 1.0, 1.0, ra + 0.10))
	# Bark mouth (carved curve)
	draw_arc(Vector2(0, 1 + b), 4.5, PI * 0.15, PI * 0.85, 8, bark2, 2.0)

	# Ancient rune glows on lower trunk
	draw_circle(Vector2(-4, 6 + b),  2.2, Color(glow.r, glow.g, glow.b, ra * 0.70))
	draw_circle(Vector2( 4, 10 + b), 2.2, Color(glow.r, glow.g, glow.b, ra * 0.60))
	draw_circle(Vector2(-2, 14 + b), 1.8, Color(glow.r, glow.g, glow.b, ra * 0.50))

	# Nature crystals embedded in trunk
	draw_colored_polygon(PackedVector2Array([
		Vector2(-1, -12 + b), Vector2(2, -12 + b),
		Vector2(3, -9 + b),   Vector2(-2, -9 + b)
	]), Color(leaf2.r, leaf2.g, leaf2.b, 0.82))
	draw_line(Vector2(-1, -12 + b), Vector2(2, -12 + b), Color(1, 1, 1, 0.55), 0.8)

	# Canopy — layered leaf clusters
	draw_circle(Vector2(0,   -16 + b), 14, leaf_d)
	draw_circle(Vector2(-12, -18 + b), 10, leaf)
	draw_circle(Vector2( 12, -18 + b), 10, leaf)
	draw_circle(Vector2(-5,  -26 + b), 11, leaf2)
	draw_circle(Vector2( 5,  -26 + b), 11, leaf2)
	draw_circle(Vector2(0,   -32 + b), 11, leaf2.lightened(0.05))
	draw_circle(Vector2(-8,  -34 + b),  7, leaf2.lightened(0.08))
	draw_circle(Vector2( 8,  -34 + b),  7, leaf2.lightened(0.08))
	draw_circle(Vector2(0,   -38 + b),  7, Color(leaf2.r, leaf2.g, leaf2.b, 0.85))

	# Glowing leaf particles (orbiting slowly)
	for _i in range(4):
		var _la  := leaf_t + float(_i) * TAU / 4.0
		var _lx  := cos(_la) * 18.0
		var _ly  := sin(_la) * 8.0 - 24.0 + b
		var _lpa := 0.45 + pulse * 0.20
		draw_circle(Vector2(_lx, _ly), 3.0, Color(leaf2.r, leaf2.g, leaf2.b, _lpa))
		draw_circle(Vector2(_lx, _ly), 1.5, Color(1, 1, 1, _lpa * 0.70))

	# Ancient nature aura
	var aa := 0.12 + pulse * 0.05
	draw_arc(Vector2(0, -8 + b), 28, 0, TAU, 32, Color(leaf2.r, leaf2.g, leaf2.b, aa), 3.5)

	# Sacred leaves burst when shooting
	if s:
		for _i in range(6):
			var _ang := float(_i) * TAU / 6.0 + _anim_time
			var _lp  := Vector2(cos(_ang), sin(_ang)) * 24.0 + Vector2(0, -20 + b)
			draw_circle(_lp, 4.5, Color(leaf2.r, leaf2.g, leaf2.b, 0.75))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ── Venom Drake (type 17) ─────────────────────────────────────────────────────

func _draw_venom_drake(b: float, s: bool) -> void:
	# ── Venom Drake Lord — Fusion-tier apex poison dragon ─────────────────────────
	var grn    := Color(0.14, 0.65, 0.20)    # toxic green
	var grn_l  := Color(0.38, 0.92, 0.44)    # bright acid green
	var grn_d  := Color(0.06, 0.28, 0.10)    # dark forest green
	var blk    := Color(0.08, 0.10, 0.08)    # black scales
	var purp   := Color(0.42, 0.10, 0.58)    # deep venom purple
	var purp_l := Color(0.68, 0.22, 0.88)    # bright purple
	var acid   := Color(0.78, 1.00, 0.08)    # acid yellow-green
	var acid_l := Color(0.94, 1.00, 0.55)    # bright acid highlight
	var scale  := Color(0.08, 0.22, 0.10)    # dark scale base

	var pulse    := sin(_anim_time * 3.2)
	var orb_rot  := _anim_time * 1.9
	var rune_rot := _anim_time * 0.75
	var drip_a : float = 0.65 + pulse * 0.25

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.95, 0.95))
	# ── 1. Shadow ────────────────────────────────────────────────────────────────
	draw_circle(Vector2(0, 24), 20, Color(0, 0, 0, 0.22))

	# ── 2. Toxic mist at base ─────────────────────────────────────────────────────
	for _i in range(4):
		var _mt : float = fmod(_anim_time * 0.5 + float(_i) * 0.25, 1.0)
		var _mr : float = 8.0 + _mt * 10.0
		var _ma : float = (1.0 - _mt) * 0.26
		draw_circle(Vector2(float(_i - 1) * 7.0, 18 + b), _mr, Color(acid.r, acid.g, acid.b, _ma))

	# ── 3. Crystal throne / plinth ────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, 4 + b),  Vector2(14, 4 + b),
		Vector2(16, 22 + b),  Vector2(-16, 22 + b)
	]), scale)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, 4 + b), Vector2(14, 4 + b),
		Vector2(12, 6 + b),  Vector2(-12, 6 + b)
	]), Color(grn_d.r, grn_d.g, grn_d.b, 0.82))
	# Right-face shadow for 3D look
	draw_colored_polygon(PackedVector2Array([
		Vector2(11, 6 + b), Vector2(14, 4 + b),
		Vector2(16, 22 + b), Vector2(12, 22 + b)
	]), Color(blk.r, blk.g, blk.b, 0.55))
	# 5 toxic crystal growths on plinth crown
	var p_xs : Array = [-11.0, -5.5, 0.0, 5.5, 11.0]
	var p_hs : Array = [3.5, 5.0, 6.5, 5.0, 3.5]
	for _i in range(5):
		var _px : float = p_xs[_i]
		var _ph : float = p_hs[_i]
		draw_colored_polygon(PackedVector2Array([
			Vector2(_px - 2, 4 + b), Vector2(_px + 2, 4 + b),
			Vector2(_px + 1, 4 - _ph + b), Vector2(_px - 1, 4 - _ph + b)
		]), Color(purp.r, purp.g, purp.b, 0.85))
		draw_colored_polygon(PackedVector2Array([
			Vector2(_px - 1, 4 + b), Vector2(_px + 1, 4 + b),
			Vector2(_px, 4 - _ph + 1.5 + b)
		]), Color(acid.r, acid.g, acid.b, 0.52))
		draw_circle(Vector2(_px, 4 - _ph + b), 1.4, Color(acid_l.r, acid_l.g, acid_l.b, 0.78))
	draw_line(Vector2(-14, 4 + b), Vector2(14, 4 + b), Color(acid.r, acid.g, acid.b, 0.42), 1.2)

	# ── 4. Wings — folded behind body ────────────────────────────────────────────
	# LEFT wing membrane (5-point, wide folded shape)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -6 + b),  Vector2(-28, -18 + b),
		Vector2(-30, -7 + b),  Vector2(-26, 6 + b),
		Vector2(-12, 6 + b)
	]), Color(purp.r, purp.g, purp.b, 0.82))
	# Inner highlight lobe
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -5 + b), Vector2(-24, -15 + b),
		Vector2(-26, -6 + b), Vector2(-22, 4 + b),
		Vector2(-13, 4 + b)
	]), Color(purp_l.r, purp_l.g, purp_l.b, 0.28))
	# Acid vein tint
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -4 + b), Vector2(-20, -11 + b),
		Vector2(-22, -4 + b), Vector2(-17, 2 + b)
	]), Color(acid.r, acid.g, acid.b, 0.14))
	# Wing bone spars
	draw_line(Vector2(-10, -6 + b), Vector2(-28, -18 + b), Color(grn_d.r, grn_d.g, grn_d.b, 0.72), 1.4)
	draw_line(Vector2(-10, -6 + b), Vector2(-30, -7 + b),  Color(grn_d.r, grn_d.g, grn_d.b, 0.62), 1.0)
	draw_line(Vector2(-10, -6 + b), Vector2(-24, 5 + b),   Color(grn_d.r, grn_d.g, grn_d.b, 0.55), 0.9)
	# Claw tips at spar ends
	draw_circle(Vector2(-28, -18 + b), 2.5, blk)
	draw_circle(Vector2(-30, -7 + b),  2.0, blk)

	# RIGHT wing membrane (mirrored)
	draw_colored_polygon(PackedVector2Array([
		Vector2(10, -6 + b),  Vector2(28, -18 + b),
		Vector2(30, -7 + b),  Vector2(26, 6 + b),
		Vector2(12, 6 + b)
	]), Color(purp.r, purp.g, purp.b, 0.82))
	draw_colored_polygon(PackedVector2Array([
		Vector2(11, -5 + b), Vector2(24, -15 + b),
		Vector2(26, -6 + b), Vector2(22, 4 + b),
		Vector2(13, 4 + b)
	]), Color(purp_l.r, purp_l.g, purp_l.b, 0.28))
	draw_colored_polygon(PackedVector2Array([
		Vector2(11, -4 + b), Vector2(20, -11 + b),
		Vector2(22, -4 + b), Vector2(17, 2 + b)
	]), Color(acid.r, acid.g, acid.b, 0.14))
	draw_line(Vector2(10, -6 + b), Vector2(28, -18 + b),  Color(grn_d.r, grn_d.g, grn_d.b, 0.72), 1.4)
	draw_line(Vector2(10, -6 + b), Vector2(30, -7 + b),   Color(grn_d.r, grn_d.g, grn_d.b, 0.62), 1.0)
	draw_line(Vector2(10, -6 + b), Vector2(24, 5 + b),    Color(grn_d.r, grn_d.g, grn_d.b, 0.55), 0.9)
	draw_circle(Vector2(28, -18 + b), 2.5, blk)
	draw_circle(Vector2(30, -7 + b),  2.0, blk)

	# ── 5. Lower haunches / perched stance ────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -4 + b), Vector2(13, -4 + b),
		Vector2(12, 4 + b),   Vector2(-12, 4 + b)
	]), scale)
	# Leg haunches (wide)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, 4 + b), Vector2(-5, 4 + b),
		Vector2(-6, 13 + b), Vector2(-14, 13 + b)
	]), grn_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(5, 4 + b),   Vector2(12, 4 + b),
		Vector2(14, 13 + b), Vector2(6, 13 + b)
	]), grn_d)
	# Knee scale arcs
	draw_arc(Vector2(-10, 8 + b), 4.5, PI * 0.1, PI * 0.9, 8, Color(blk.r, blk.g, blk.b, 0.52), 1.5)
	draw_arc(Vector2(10, 8 + b),  4.5, PI * 0.1, PI * 0.9, 8, Color(blk.r, blk.g, blk.b, 0.52), 1.5)

	# ── 6. Venom sacs (LEFT shoulder, RIGHT shoulder, tail) ──────────────────────
	# LEFT — bulging purple sac with acid core and vein lines
	var vs_pulse : float = 0.88 + pulse * 0.10
	draw_circle(Vector2(-14, -2 + b), 7.0 * vs_pulse, Color(purp.r, purp.g, purp.b, 0.88))
	draw_circle(Vector2(-14, -2 + b), 5.0 * vs_pulse, Color(purp_l.r, purp_l.g, purp_l.b, 0.62))
	draw_circle(Vector2(-14, -2 + b), 3.2 * vs_pulse, Color(acid.r, acid.g, acid.b, 0.58))
	draw_circle(Vector2(-15, -3 + b), 1.6,             Color(acid_l.r, acid_l.g, acid_l.b, 0.75))
	draw_line(Vector2(-14, -2 + b), Vector2(-18, 0 + b),  Color(acid.r, acid.g, acid.b, 0.42), 0.9)
	draw_line(Vector2(-14, -2 + b), Vector2(-17, -6 + b), Color(acid.r, acid.g, acid.b, 0.36), 0.9)
	draw_line(Vector2(-14, -2 + b), Vector2(-12, -6 + b), Color(acid.r, acid.g, acid.b, 0.30), 0.8)
	# RIGHT
	draw_circle(Vector2(14, -2 + b),  7.0 * vs_pulse, Color(purp.r, purp.g, purp.b, 0.88))
	draw_circle(Vector2(14, -2 + b),  5.0 * vs_pulse, Color(purp_l.r, purp_l.g, purp_l.b, 0.62))
	draw_circle(Vector2(14, -2 + b),  3.2 * vs_pulse, Color(acid.r, acid.g, acid.b, 0.58))
	draw_circle(Vector2(15, -3 + b),  1.6,             Color(acid_l.r, acid_l.g, acid_l.b, 0.75))
	draw_line(Vector2(14, -2 + b), Vector2(18, 0 + b),  Color(acid.r, acid.g, acid.b, 0.42), 0.9)
	draw_line(Vector2(14, -2 + b), Vector2(17, -6 + b), Color(acid.r, acid.g, acid.b, 0.36), 0.9)
	draw_line(Vector2(14, -2 + b), Vector2(12, -6 + b), Color(acid.r, acid.g, acid.b, 0.30), 0.8)
	# Tail sac (small, lower back)
	draw_circle(Vector2(0, 2 + b), 4.0, Color(purp.r, purp.g, purp.b, 0.72))
	draw_circle(Vector2(0, 2 + b), 2.5, Color(acid.r, acid.g, acid.b, 0.52))

	# ── 7. Torso / chest plate ────────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -4 + b), Vector2(12, -4 + b),
		Vector2(10, -14 + b), Vector2(-10, -14 + b)
	]), grn)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -4 + b), Vector2(12, -4 + b),
		Vector2(10, -5 + b),  Vector2(-10, -5 + b)
	]), grn_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(8, -14 + b), Vector2(12, -4 + b),
		Vector2(10, -5 + b), Vector2(7, -12 + b)
	]), grn_d)
	# Scale arc texture (2 rows × 3 cols)
	for _i in range(2):
		for _j in range(3):
			draw_arc(Vector2(float(_j - 1) * 7.0, -7.5 + float(_i) * 5.0 + b),
				3.0, PI * 0.1, PI * 0.9, 6, Color(blk.r, blk.g, blk.b, 0.46), 1.2)
	# Acid vein cracks
	draw_line(Vector2(-8, -10 + b), Vector2(-5, -5 + b), Color(acid.r, acid.g, acid.b, 0.52), 0.9)
	draw_line(Vector2(5, -11 + b),  Vector2(8, -6 + b),  Color(acid.r, acid.g, acid.b, 0.46), 0.9)
	draw_line(Vector2(-12, -4 + b), Vector2(12, -4 + b), Color(acid.r, acid.g, acid.b, 0.28), 1.0)

	# ── 8. Dorsal toxic spikes (7 along spine) ────────────────────────────────────
	var sp_xs : Array = [-12.0, -8.0, -4.0, 0.0, 4.0, 8.0, 12.0]
	var sp_hs : Array = [4.5, 6.0, 7.5, 10.0, 7.5, 6.0, 4.5]
	for _i in range(7):
		var _spx : float = sp_xs[_i]
		var _sph : float = sp_hs[_i]
		draw_colored_polygon(PackedVector2Array([
			Vector2(_spx - 2, -14 + b), Vector2(_spx + 2, -14 + b),
			Vector2(_spx + 1, -14 - _sph + b), Vector2(_spx - 1, -14 - _sph + b)
		]), grn_d)
		draw_colored_polygon(PackedVector2Array([
			Vector2(_spx - 1, -14 + b), Vector2(_spx + 1, -14 + b),
			Vector2(_spx, -14 - _sph + 1.5 + b)
		]), acid)
		draw_circle(Vector2(_spx, -14 - _sph + b), 1.5, Color(acid_l.r, acid_l.g, acid_l.b, 0.85))

	# ── 9. Neck ───────────────────────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -14 + b), Vector2(7, -14 + b),
		Vector2(5, -20 + b),  Vector2(-5, -20 + b)
	]), grn)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -14 + b), Vector2(7, -14 + b),
		Vector2(5, -15 + b),  Vector2(-5, -15 + b)
	]), grn_l)
	draw_arc(Vector2(-4, -17 + b), 2.0, PI * 0.2, PI * 0.85, 5, Color(blk.r, blk.g, blk.b, 0.42), 1.0)
	draw_arc(Vector2(4, -17 + b),  2.0, PI * 0.2, PI * 0.85, 5, Color(blk.r, blk.g, blk.b, 0.42), 1.0)

	# ── 10. Dragon skull ─────────────────────────────────────────────────────────
	draw_circle(Vector2(0, -24 + b), 11.0, scale)
	draw_circle(Vector2(0, -24 + b), 9.8,  grn)
	draw_circle(Vector2(-1, -25 + b), 7.8, grn.lightened(0.08))
	# Armored brow plate
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -25 + b), Vector2(11, -25 + b),
		Vector2(9, -20 + b),   Vector2(-9, -20 + b)
	]), grn_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -25 + b), Vector2(11, -25 + b),
		Vector2(9, -24 + b),   Vector2(-9, -24 + b)
	]), Color(grn_l.r, grn_l.g, grn_l.b, 0.38))
	draw_colored_polygon(PackedVector2Array([
		Vector2(7, -25 + b), Vector2(11, -25 + b),
		Vector2(9, -20 + b), Vector2(6, -20 + b)
	]), scale)
	# Scale arc details on skull
	draw_arc(Vector2(-5, -23 + b), 3.2, PI * 0.1, PI * 0.8, 6, Color(blk.r, blk.g, blk.b, 0.40), 1.2)
	draw_arc(Vector2(4, -22 + b),  2.6, PI * 0.2, PI * 0.8, 5, Color(blk.r, blk.g, blk.b, 0.38), 1.0)
	# Head acid crack
	draw_line(Vector2(-8, -23 + b), Vector2(-5, -19 + b), Color(acid.r, acid.g, acid.b, 0.48), 0.9)

	# ── 11. Toxic horns (swept, with inner secondary horn) ───────────────────────
	# Left main horn
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -29 + b), Vector2(-3, -29 + b),
		Vector2(-1, -36 + b), Vector2(-6, -40 + b), Vector2(-9, -34 + b)
	]), grn_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -29 + b), Vector2(-3, -29 + b),
		Vector2(-2, -35 + b), Vector2(-6, -39 + b), Vector2(-8, -33 + b)
	]), grn)
	draw_line(Vector2(-5, -29 + b), Vector2(-7, -34 + b), Color(acid.r, acid.g, acid.b, 0.40), 0.9)
	draw_circle(Vector2(-6, -39 + b), 2.0, Color(acid.r, acid.g, acid.b, 0.78))
	# Left inner horn (small secondary)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3, -28 + b), Vector2(-1, -28 + b), Vector2(-2, -33 + b)
	]), acid)
	draw_circle(Vector2(-2, -33 + b), 1.3, Color(acid_l.r, acid_l.g, acid_l.b, 0.72))

	# Right main horn
	draw_colored_polygon(PackedVector2Array([
		Vector2(3, -29 + b), Vector2(6, -29 + b),
		Vector2(9, -34 + b), Vector2(6, -40 + b), Vector2(1, -36 + b)
	]), grn_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(3, -29 + b), Vector2(6, -29 + b),
		Vector2(8, -33 + b), Vector2(6, -39 + b), Vector2(2, -35 + b)
	]), grn)
	draw_line(Vector2(5, -29 + b), Vector2(7, -34 + b), Color(acid.r, acid.g, acid.b, 0.40), 0.9)
	draw_circle(Vector2(6, -39 + b), 2.0, Color(acid.r, acid.g, acid.b, 0.78))
	# Right inner horn
	draw_colored_polygon(PackedVector2Array([
		Vector2(1, -28 + b), Vector2(3, -28 + b), Vector2(2, -33 + b)
	]), acid)
	draw_circle(Vector2(2, -33 + b), 1.3, Color(acid_l.r, acid_l.g, acid_l.b, 0.72))

	# ── 12. Snout + open jaw with fangs ──────────────────────────────────────────
	# Upper jaw plate
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -20 + b), Vector2(8, -20 + b),
		Vector2(7, -16 + b),  Vector2(-7, -16 + b)
	]), grn_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -20 + b), Vector2(8, -20 + b),
		Vector2(7, -19 + b),  Vector2(-7, -19 + b)
	]), Color(grn_l.r, grn_l.g, grn_l.b, 0.36))
	# Lower jaw (open, extended)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -16 + b), Vector2(7, -16 + b),
		Vector2(8, -13 + b),  Vector2(-8, -13 + b)
	]), scale)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -16 + b), Vector2(6, -16 + b),
		Vector2(7, -14 + b),  Vector2(-7, -14 + b)
	]), Color(grn_d.r * 0.7, grn_d.g * 0.7, grn_d.b * 0.7))
	# 3 fang pairs (upper + lower)
	for _fi in range(3):
		var _fx : float = float(_fi - 1) * 4.5
		# Upper fang (pointing down)
		draw_colored_polygon(PackedVector2Array([
			Vector2(_fx - 1.8, -16 + b), Vector2(_fx + 1.8, -16 + b),
			Vector2(_fx, -12.5 + b)
		]), Color(0.90, 1.0, 0.86, 0.95))
		draw_colored_polygon(PackedVector2Array([
			Vector2(_fx - 0.9, -16 + b), Vector2(_fx + 0.9, -16 + b),
			Vector2(_fx, -13.5 + b)
		]), Color(acid_l.r, acid_l.g, acid_l.b, 0.58))
	# Dripping venom (3 drips)
	draw_line(Vector2(-4.5, -12.5 + b), Vector2(-4.5, -9 + b),  Color(acid.r, acid.g, acid.b, drip_a), 1.3)
	draw_circle(Vector2(-4.5, -9 + b),  1.6, Color(acid.r, acid.g, acid.b, drip_a))
	draw_line(Vector2(0, -12.5 + b),    Vector2(0, -10 + b),     Color(acid.r, acid.g, acid.b, drip_a * 0.88), 1.1)
	draw_circle(Vector2(0, -10 + b),    1.3, Color(acid.r, acid.g, acid.b, drip_a * 0.82))
	draw_line(Vector2(4.5, -12.5 + b),  Vector2(4.5, -9.5 + b), Color(acid.r, acid.g, acid.b, drip_a * 0.72), 1.0)
	draw_circle(Vector2(4.5, -9.5 + b), 1.1, Color(acid.r, acid.g, acid.b, drip_a * 0.65))

	# ── 13. Eyes (large, glowing acid with slit pupils) ───────────────────────────
	draw_circle(Vector2(-5, -23 + b), 4.2, Color(acid.r, acid.g, acid.b, 0.32))
	draw_circle(Vector2(-5, -23 + b), 3.4, acid)
	draw_circle(Vector2(-5, -23 + b), 1.8, blk)
	draw_circle(Vector2( 5, -23 + b), 4.2, Color(acid.r, acid.g, acid.b, 0.32))
	draw_circle(Vector2( 5, -23 + b), 3.4, acid)
	draw_circle(Vector2( 5, -23 + b), 1.8, blk)
	draw_circle(Vector2(-5.6, -24 + b), 1.1, Color(1, 1, 1, 0.72))

	# ── 14. Toxic fume puffs rising from maw ─────────────────────────────────────
	for _i in range(3):
		var _ft : float = fmod(_anim_time * 0.8 + float(_i) * 0.33, 1.0)
		var _fy : float = -26 - _ft * 14 + b
		var _fa : float = (1.0 - _ft) * 0.42
		draw_circle(Vector2(float(_i - 1) * 4.5, _fy), 2.5 + _ft * 3.0, Color(acid.r, acid.g, acid.b, _fa))

	# ── 15. Floating poison globes orbiting (4, inner ring) ──────────────────────
	for _i in range(4):
		var _oa  : float = orb_rot + float(_i) * TAU / 4.0
		var _ox  : float = cos(_oa) * 20.0
		var _oy  : float = sin(_oa) * 9.0 - 6.0 + b
		var _oa2 : float = 0.52 + pulse * 0.18
		draw_circle(Vector2(_ox, _oy), 5.5, Color(purp.r, purp.g, purp.b, _oa2 * 0.52))
		draw_circle(Vector2(_ox, _oy), 3.8, Color(acid.r, acid.g, acid.b, _oa2))
		draw_circle(Vector2(_ox, _oy), 1.8, Color(acid_l.r, acid_l.g, acid_l.b, _oa2 * 0.85))
		draw_arc(Vector2(_ox, _oy), 3.8, 0, TAU, 6, Color(grn_d.r, grn_d.g, grn_d.b, _oa2 * 0.50), 0.9)

	# ── 16. Spectral venom snakes (2, outer ring) ─────────────────────────────────
	for _i in range(2):
		var _sa  : float = -rune_rot * 0.75 + float(_i) * PI
		var _scx : float = cos(_sa) * 27.0
		var _scy : float = sin(_sa) * 12.0 - 4.0 + b
		# 5 body circles in a sinusoidal wave
		for _j in range(5):
			var _sr  : float = 2.2 - float(_j) * 0.32
			var _sbx : float = _scx + float(_j) * 2.0
			var _sby : float = _scy + sin(float(_j) * 0.9 + _anim_time * 4.5 + float(_i) * PI) * 2.5
			draw_circle(Vector2(_sbx, _sby), maxf(0.5, _sr), Color(acid.r, acid.g, acid.b, 0.68 - float(_j) * 0.10))
		# Snake head
		draw_circle(Vector2(_scx, _scy), 2.8, grn_l)
		draw_circle(Vector2(_scx - 1.0, _scy - 0.8), 1.0, acid)

	# ── 17. Toxic crystals orbiting (3, outer ring) ───────────────────────────────
	for _i in range(3):
		var _ca  : float = rune_rot + float(_i) * TAU / 3.0
		var _ctx : float = cos(_ca) * 31.0
		var _cty : float = sin(_ca) * 13.0 - 4.0 + b
		var _ca2 : float = 0.44 + pulse * 0.16
		draw_colored_polygon(PackedVector2Array([
			Vector2(_ctx, _cty - 7),   Vector2(_ctx - 3, _cty + 1),
			Vector2(_ctx, _cty + 3),   Vector2(_ctx + 3, _cty + 1)
		]), Color(purp.r, purp.g, purp.b, _ca2))
		draw_colored_polygon(PackedVector2Array([
			Vector2(_ctx, _cty - 5.5), Vector2(_ctx - 2, _cty + 0),
			Vector2(_ctx, _cty + 2),   Vector2(_ctx + 2, _cty + 0)
		]), Color(acid.r, acid.g, acid.b, _ca2 + 0.14))
		draw_circle(Vector2(_ctx, _cty - 3.5), 1.8, Color(acid_l.r, acid_l.g, acid_l.b, _ca2 * 0.88))

	# ── 18. Toxic glow aura ───────────────────────────────────────────────────────
	var ga : float = 0.12 + pulse * 0.05
	draw_arc(Vector2(0, -10 + b), 32, 0, TAU, 36, Color(grn_l.r, grn_l.g, grn_l.b, ga), 3.5)

	# ── 19. Venom burst on attack ─────────────────────────────────────────────────
	if s:
		var _ba := 0.50 + sin(_anim_time * 9.0) * 0.42
		draw_arc(Vector2(0, -14 + b), 36, 0, TAU, 42, Color(acid.r, acid.g, acid.b, _ba * 0.35), 4.0)
		draw_circle(Vector2(0, -14 + b), 14, Color(acid.r, acid.g, acid.b, _ba * 0.18))
		for _vi in range(5):
			var _va := float(_vi) * TAU / 5.0 + _anim_time * 3.0
			draw_circle(Vector2(cos(_va) * 22, sin(_va) * 9 - 10 + b), 3.5,
				Color(acid.r, acid.g, acid.b, _ba * 0.45))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ── Frost Cannon (type 18) ────────────────────────────────────────────────────

func _draw_frost_cannon(b: float, s: bool) -> void:
	# ── Frozen Siege Artillery — Fusion-tier boss-hunter ─────────────────────────
	var ice    := Color(0.42, 0.78, 1.00)    # main ice blue
	var ice_l  := Color(0.76, 0.95, 1.00)    # light frost
	var ice_d  := Color(0.20, 0.46, 0.78)    # deep ice
	var cyan   := Color(0.18, 0.95, 1.00)    # glowing cyan energy
	var cyan_l := Color(0.68, 1.00, 1.00)    # bright cyan highlight
	var armor  := Color(0.28, 0.38, 0.54)    # frozen steel
	var armor_l:= Color(0.44, 0.56, 0.72)    # lighter frozen steel
	var armor_d:= Color(0.14, 0.22, 0.36)    # dark frozen steel
	var silver := Color(0.60, 0.72, 0.84)    # cold silver trim
	var rune   := Color(0.20, 0.78, 1.00)    # carved rune blue

	var pulse     := sin(_anim_time * 2.8)
	var shard_rot := _anim_time * 1.5
	var rune_rot  := _anim_time * 0.7
	var b_recoil  := 3.5 if s else 0.0

	# Pre-compute barrel geometry
	var b_left_base   := Vector2(-7, 2 + b)
	var b_left_tip    := Vector2(-24 + b_recoil * 0.8, -20 + b)
	var b_center_base := Vector2(0, -2 + b)
	var b_center_tip  := Vector2(0, -32 + b_recoil)  # straight up — boss-killer
	var b_right_base  := Vector2(7, 2 + b)
	var b_right_tip   := Vector2(24 - b_recoil * 0.8, -20 + b)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.90, 0.90))
	# ── 1. Shadow ────────────────────────────────────────────────────────────────
	draw_circle(Vector2(0, 24), 22, Color(0, 0, 0, 0.24))

	# ── 2. Frost crystal clusters — LEFT flank ────────────────────────────────────
	# Crystal A (tallest, outer)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-22, 8 + b), Vector2(-27, 6 + b),
		Vector2(-28, -2 + b), Vector2(-24, -12 + b), Vector2(-20, -2 + b)
	]), ice_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-22, 6 + b), Vector2(-26, 5 + b),
		Vector2(-27, -1 + b), Vector2(-24, -10 + b), Vector2(-21, -1 + b)
	]), ice)
	draw_line(Vector2(-25, 4 + b), Vector2(-24, -9 + b), Color(cyan_l.r, cyan_l.g, cyan_l.b, 0.55), 1.0)
	draw_circle(Vector2(-24, -8 + b), 1.8, Color(cyan.r, cyan.g, cyan.b, 0.75))

	# Crystal B (mid, inner)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-16, 10 + b), Vector2(-21, 8 + b),
		Vector2(-22, 0 + b), Vector2(-18, -10 + b), Vector2(-14, 0 + b)
	]), ice_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-16, 8 + b), Vector2(-20, 7 + b),
		Vector2(-21, 0 + b), Vector2(-18, -8 + b), Vector2(-15, 0 + b)
	]), ice)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-18, 5 + b), Vector2(-19, 1 + b), Vector2(-18, -5 + b)
	]), Color(cyan_l.r, cyan_l.g, cyan_l.b, 0.52))
	draw_circle(Vector2(-18, -7 + b), 1.5, Color(cyan.r, cyan.g, cyan.b, 0.72))

	# Crystal C (small, front)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, 10 + b), Vector2(-17, 9 + b),
		Vector2(-17, 3 + b), Vector2(-15, -5 + b), Vector2(-12, 3 + b)
	]), ice_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, 9 + b), Vector2(-16, 8 + b),
		Vector2(-16, 3 + b), Vector2(-15, -4 + b), Vector2(-12.5, 3 + b)
	]), ice.lightened(0.08))
	draw_circle(Vector2(-15, -3 + b), 1.2, Color(cyan.r, cyan.g, cyan.b, 0.65))

	# ── 3. Frost crystal clusters — RIGHT flank (mirrored) ────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(22, 8 + b), Vector2(27, 6 + b),
		Vector2(28, -2 + b), Vector2(24, -12 + b), Vector2(20, -2 + b)
	]), ice_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(22, 6 + b), Vector2(26, 5 + b),
		Vector2(27, -1 + b), Vector2(24, -10 + b), Vector2(21, -1 + b)
	]), ice)
	draw_line(Vector2(25, 4 + b), Vector2(24, -9 + b), Color(cyan_l.r, cyan_l.g, cyan_l.b, 0.55), 1.0)
	draw_circle(Vector2(24, -8 + b), 1.8, Color(cyan.r, cyan.g, cyan.b, 0.75))

	draw_colored_polygon(PackedVector2Array([
		Vector2(16, 10 + b), Vector2(21, 8 + b),
		Vector2(22, 0 + b), Vector2(18, -10 + b), Vector2(14, 0 + b)
	]), ice_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(16, 8 + b), Vector2(20, 7 + b),
		Vector2(21, 0 + b), Vector2(18, -8 + b), Vector2(15, 0 + b)
	]), ice)
	draw_colored_polygon(PackedVector2Array([
		Vector2(18, 5 + b), Vector2(19, 1 + b), Vector2(18, -5 + b)
	]), Color(cyan_l.r, cyan_l.g, cyan_l.b, 0.52))
	draw_circle(Vector2(18, -7 + b), 1.5, Color(cyan.r, cyan.g, cyan.b, 0.72))

	draw_colored_polygon(PackedVector2Array([
		Vector2(13, 10 + b), Vector2(17, 9 + b),
		Vector2(17, 3 + b), Vector2(15, -5 + b), Vector2(12, 3 + b)
	]), ice_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(13, 9 + b), Vector2(16, 8 + b),
		Vector2(16, 3 + b), Vector2(15, -4 + b), Vector2(12.5, 3 + b)
	]), ice.lightened(0.08))
	draw_circle(Vector2(15, -3 + b), 1.2, Color(cyan.r, cyan.g, cyan.b, 0.65))

	# ── 4. Heavy siege base (wide trapezoidal platform) ───────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20, 10 + b), Vector2(20, 10 + b),
		Vector2(22, 22 + b),  Vector2(-22, 22 + b)
	]), armor_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20, 10 + b), Vector2(20, 10 + b),
		Vector2(16, 7 + b),   Vector2(-16, 7 + b)
	]), armor)
	draw_colored_polygon(PackedVector2Array([
		Vector2(15, 10 + b), Vector2(20, 10 + b),
		Vector2(22, 22 + b), Vector2(17, 22 + b)
	]), Color(armor_d.r * 0.80, armor_d.g * 0.80, armor_d.b * 0.80))
	draw_line(Vector2(-20, 10 + b), Vector2(20, 10 + b), silver, 2.0)

	# Ice armour plating tiles on top of base
	for _i in range(5):
		var _bx := float(_i - 2) * 8.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(_bx - 3, 10 + b), Vector2(_bx + 3, 10 + b),
			Vector2(_bx + 2, 7 + b),  Vector2(_bx - 2, 7 + b)
		]), Color(ice_d.r, ice_d.g, ice_d.b, 0.72))
		draw_line(Vector2(_bx - 2.5, 10 + b), Vector2(_bx, 7.5 + b), Color(ice_l.r, ice_l.g, ice_l.b, 0.50), 0.8)

	# Corner support struts
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20, 10 + b), Vector2(-16, 10 + b),
		Vector2(-18, 22 + b), Vector2(-22, 22 + b)
	]), Color(armor_d.r, armor_d.g, armor_d.b, 0.90))
	draw_colored_polygon(PackedVector2Array([
		Vector2(16, 10 + b),  Vector2(20, 10 + b),
		Vector2(22, 22 + b),  Vector2(18, 22 + b)
	]), Color(armor_d.r, armor_d.g, armor_d.b, 0.90))
	draw_line(Vector2(-20, 10 + b), Vector2(-22, 22 + b), silver, 1.2)
	draw_line(Vector2( 20, 10 + b), Vector2( 22, 22 + b), silver, 1.2)

	# Frozen chains across front of base (5-link drape)
	var ch_a := 0.70
	draw_line(Vector2(-20, 12 + b), Vector2(-12, 10 + b), Color(silver.r, silver.g, silver.b, ch_a), 1.8)
	draw_line(Vector2(-12, 10 + b), Vector2(  0, 13 + b), Color(silver.r, silver.g, silver.b, ch_a), 1.8)
	draw_line(Vector2(  0, 13 + b), Vector2( 12, 10 + b), Color(silver.r, silver.g, silver.b, ch_a), 1.8)
	draw_line(Vector2( 12, 10 + b), Vector2( 20, 12 + b), Color(silver.r, silver.g, silver.b, ch_a), 1.8)
	# Chain link circles
	for _cx in [-16.0, -6.0, 6.0, 16.0]:
		draw_circle(Vector2(_cx, 11 + b), 1.5, Color(silver.r, silver.g, silver.b, ch_a + 0.10))

	# ── 5. Central turret housing (hexagonal) ─────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -6 + b), Vector2(14, -6 + b),
		Vector2(16, 2 + b),   Vector2(14, 10 + b),
		Vector2(-14, 10 + b), Vector2(-16, 2 + b)
	]), armor)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -6 + b), Vector2(14, -6 + b),
		Vector2(12, -4 + b),  Vector2(-12, -4 + b)
	]), armor_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(10, -6 + b), Vector2(14, -6 + b),
		Vector2(16, 2 + b),  Vector2(14, 10 + b),
		Vector2(10, 10 + b)
	]), armor_d)
	draw_line(Vector2(-14, -6 + b), Vector2(14, -6 + b), silver, 1.5)
	draw_line(Vector2(-14, 10 + b), Vector2(14, 10 + b), silver, 1.2)

	# Glowing blue runes carved on turret face (6 marks)
	for _i in range(6):
		var _ra := float(_i) * TAU / 6.0 + rune_rot
		var _rx := cos(_ra) * 9.0
		var _ry := sin(_ra) * 5.5 + 2.0 + b
		var _runa := 0.50 + pulse * 0.22
		draw_circle(Vector2(_rx, _ry), 1.8, Color(rune.r, rune.g, rune.b, _runa))
		draw_circle(Vector2(_rx, _ry), 0.9, Color(1.0, 1.0, 1.0, _runa * 0.75))

	# Exhaust vents with frost puffs
	draw_circle(Vector2(-15, 2 + b), 4.0, armor_d)
	draw_circle(Vector2(-15, 2 + b), 2.8, Color(ice.r, ice.g, ice.b, 0.72))
	draw_circle(Vector2( 15, 2 + b), 4.0, armor_d)
	draw_circle(Vector2( 15, 2 + b), 2.8, Color(ice.r, ice.g, ice.b, 0.72))
	var vent_a := 0.28 + pulse * 0.14
	draw_circle(Vector2(-20, 1 + b), 3.5, Color(ice_l.r, ice_l.g, ice_l.b, vent_a))
	draw_circle(Vector2(-23, 0 + b), 2.5, Color(ice_l.r, ice_l.g, ice_l.b, vent_a * 0.60))
	draw_circle(Vector2( 20, 1 + b), 3.5, Color(ice_l.r, ice_l.g, ice_l.b, vent_a))
	draw_circle(Vector2( 23, 0 + b), 2.5, Color(ice_l.r, ice_l.g, ice_l.b, vent_a * 0.60))

	# ── 6. Frost crystal reactor core ─────────────────────────────────────────────
	var cr := 7.5 + pulse * 1.2
	# Outer reactor glow
	draw_circle(Vector2(0, 2 + b), cr + 5.0, Color(cyan.r, cyan.g, cyan.b, 0.14 + pulse * 0.06))
	draw_circle(Vector2(0, 2 + b), cr + 2.0, Color(cyan.r, cyan.g, cyan.b, 0.30))
	# Reactor crystal body (diamond facets)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 2 - cr + b),  Vector2(-cr * 0.6, 2 + b),
		Vector2(0, 2 + cr + b),  Vector2(cr * 0.6, 2 + b)
	]), Color(ice_d.r, ice_d.g, ice_d.b, 0.90))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 2 - cr + b),  Vector2(-cr * 0.6, 2 + b),
		Vector2(0, 2 + cr + b),  Vector2(cr * 0.6, 2 + b)
	]), Color(ice.r, ice.g, ice.b, 0.82))
	# Left facet highlight
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 2 - cr + b), Vector2(-cr * 0.6, 2 + b),
		Vector2(0, 2 + cr * 0.4 + b)
	]), Color(cyan_l.r, cyan_l.g, cyan_l.b, 0.55))
	# Inner bright core
	draw_circle(Vector2(0, 2 + b), cr * 0.45, Color(cyan.r, cyan.g, cyan.b, 0.88))
	draw_circle(Vector2(0, 2 + b), cr * 0.25, Color(1.0, 1.0, 1.0, 0.90))
	draw_circle(Vector2(-1, 1 + b), cr * 0.12, Color(1.0, 1.0, 1.0, 0.95))

	# ── 7. LEFT barrel (flank, reinforced) ────────────────────────────────────────
	# Barrel socket/mount
	draw_circle(b_left_base, 7.0, armor_d)
	draw_circle(b_left_base, 5.5, armor)
	draw_circle(b_left_base, 4.0, ice_d)
	draw_circle(b_left_base, 2.5, Color(cyan.r, cyan.g, cyan.b, 0.70))
	# Barrel shaft
	draw_line(b_left_base, b_left_tip, armor_d, 11.0)
	draw_line(b_left_base, b_left_tip, ice_d,   8.0)
	draw_line(b_left_base, b_left_tip, ice,     5.0)
	draw_line(b_left_base, b_left_tip, Color(ice_l.r, ice_l.g, ice_l.b, 0.70), 1.8)
	# Reinforcement rings (3 bands)
	for _i in range(3):
		var _t := 0.25 + float(_i) * 0.22
		var _rp := b_left_base.lerp(b_left_tip, _t)
		draw_circle(_rp, 7.5, armor_d)
		draw_circle(_rp, 6.0, ice_d)
		draw_line(_rp + Vector2(-5, 0), _rp + Vector2(5, 0), Color(silver.r, silver.g, silver.b, 0.60), 1.2)
	# Oversized reinforced muzzle cap
	draw_circle(b_left_tip, 10.0, armor_d)
	draw_circle(b_left_tip, 8.0,  ice_d)
	draw_circle(b_left_tip, 6.5,  ice)
	draw_circle(b_left_tip, 4.5,  Color(cyan.r, cyan.g, cyan.b, 0.80 + pulse * 0.15))
	draw_circle(b_left_tip, 2.5,  Color(ice_l.r, ice_l.g, ice_l.b, 0.90))
	draw_circle(b_left_tip + Vector2(-1, -1), 1.2, Color(1, 1, 1, 0.88))
	draw_arc(b_left_tip, 8.5, 0, TAU, 16, Color(rune.r, rune.g, rune.b, 0.65), 1.5)

	# ── 8. RIGHT barrel (flank, reinforced, mirrored) ─────────────────────────────
	draw_circle(b_right_base, 7.0, armor_d)
	draw_circle(b_right_base, 5.5, armor)
	draw_circle(b_right_base, 4.0, ice_d)
	draw_circle(b_right_base, 2.5, Color(cyan.r, cyan.g, cyan.b, 0.70))
	draw_line(b_right_base, b_right_tip, armor_d, 11.0)
	draw_line(b_right_base, b_right_tip, ice_d,   8.0)
	draw_line(b_right_base, b_right_tip, ice,     5.0)
	draw_line(b_right_base, b_right_tip, Color(ice_l.r, ice_l.g, ice_l.b, 0.70), 1.8)
	for _i in range(3):
		var _t := 0.25 + float(_i) * 0.22
		var _rp := b_right_base.lerp(b_right_tip, _t)
		draw_circle(_rp, 7.5, armor_d)
		draw_circle(_rp, 6.0, ice_d)
		draw_line(_rp + Vector2(-5, 0), _rp + Vector2(5, 0), Color(silver.r, silver.g, silver.b, 0.60), 1.2)
	draw_circle(b_right_tip, 10.0, armor_d)
	draw_circle(b_right_tip, 8.0,  ice_d)
	draw_circle(b_right_tip, 6.5,  ice)
	draw_circle(b_right_tip, 4.5,  Color(cyan.r, cyan.g, cyan.b, 0.80 + pulse * 0.15))
	draw_circle(b_right_tip, 2.5,  Color(ice_l.r, ice_l.g, ice_l.b, 0.90))
	draw_circle(b_right_tip + Vector2(1, -1), 1.2, Color(1, 1, 1, 0.88))
	draw_arc(b_right_tip, 8.5, 0, TAU, 16, Color(rune.r, rune.g, rune.b, 0.65), 1.5)

	# ── 9. CENTER barrel (boss-killer — largest, drawn last/on top) ────────────────
	draw_circle(b_center_base, 9.0, armor_d)
	draw_circle(b_center_base, 7.5, armor)
	draw_circle(b_center_base, 5.5, ice_d)
	draw_circle(b_center_base, 3.5, Color(cyan.r, cyan.g, cyan.b, 0.80))
	draw_line(b_center_base, b_center_tip, armor_d, 15.0)
	draw_line(b_center_base, b_center_tip, ice_d,   11.0)
	draw_line(b_center_base, b_center_tip, ice,     7.5)
	draw_line(b_center_base, b_center_tip, Color(ice_l.r, ice_l.g, ice_l.b, 0.72), 2.5)
	# Reinforcement bands (4 on center barrel — longer barrel = more bands)
	for _i in range(4):
		var _t := 0.18 + float(_i) * 0.20
		var _rp := b_center_base.lerp(b_center_tip, _t)
		draw_circle(_rp, 9.0, armor_d)
		draw_circle(_rp, 7.5, ice_d)
		draw_line(_rp + Vector2(-6, 0), _rp + Vector2(6, 0), Color(silver.r, silver.g, silver.b, 0.65), 1.5)
	# Oversized reinforced muzzle — the boss-killer tip
	draw_circle(b_center_tip, 13.0, armor_d)
	draw_circle(b_center_tip, 11.0, ice_d)
	draw_circle(b_center_tip, 9.0,  ice)
	draw_circle(b_center_tip, 7.0,  Color(cyan.r, cyan.g, cyan.b, 0.82 + pulse * 0.14))
	draw_circle(b_center_tip, 4.5,  Color(ice_l.r, ice_l.g, ice_l.b, 0.92))
	draw_circle(b_center_tip, 2.5,  Color(1.0, 1.0, 1.0, 0.92))
	draw_circle(b_center_tip + Vector2(-1.5, -1.5), 1.5, Color(1, 1, 1, 0.95))
	draw_arc(b_center_tip, 11.5, 0, TAU, 20, Color(rune.r, rune.g, rune.b, 0.75), 2.0)
	draw_arc(b_center_tip, 8.0,  0, TAU, 16, Color(cyan.r,  cyan.g,  cyan.b,  0.45 + pulse * 0.20), 1.2)

	# ── 10. Floating ice shards orbiting (3) ──────────────────────────────────────
	for _i in range(3):
		var _sa  := shard_rot + float(_i) * TAU / 3.0
		var _sx  := cos(_sa) * 22.0
		var _sy  := sin(_sa) * 10.0 - 2.0 + b
		var _sca := 0.55 + pulse * 0.20
		draw_colored_polygon(PackedVector2Array([
			Vector2(_sx, _sy - 5), Vector2(_sx - 3, _sy + 1),
			Vector2(_sx, _sy + 3), Vector2(_sx + 3, _sy + 1)
		]), Color(ice_d.r, ice_d.g, ice_d.b, _sca))
		draw_colored_polygon(PackedVector2Array([
			Vector2(_sx, _sy - 4), Vector2(_sx - 2, _sy + 1),
			Vector2(_sx, _sy + 2), Vector2(_sx + 2, _sy + 1)
		]), Color(ice_l.r, ice_l.g, ice_l.b, _sca))
		draw_circle(Vector2(_sx, _sy - 2), 1.2, Color(cyan.r, cyan.g, cyan.b, _sca * 0.80))

	# ── 11. Rotating frost rune hexagons (3, outer ring) ──────────────────────────
	for _i in range(3):
		var _ra  := -rune_rot * 1.2 + float(_i) * TAU / 3.0
		var _rx  := cos(_ra) * 30.0
		var _ry  := sin(_ra) * 13.0 - 2.0 + b
		var _rua := 0.30 + pulse * 0.12
		draw_arc(Vector2(_rx, _ry), 4.5, 0, TAU, 6, Color(rune.r, rune.g, rune.b, _rua + 0.10), 1.5)
		draw_line(Vector2(_rx - 2.5, _ry), Vector2(_rx + 2.5, _ry), Color(ice_l.r, ice_l.g, ice_l.b, _rua + 0.20), 0.9)
		draw_line(Vector2(_rx, _ry - 2.5), Vector2(_rx, _ry + 2.5), Color(ice_l.r, ice_l.g, ice_l.b, _rua + 0.20), 0.9)
		draw_circle(Vector2(_rx, _ry), 1.5, Color(cyan.r, cyan.g, cyan.b, _rua + 0.15))

	# ── 12. Outer frost aura (subtle ambient) ─────────────────────────────────────
	var fa2 := 0.10 + pulse * 0.04
	draw_arc(Vector2(0, 0 + b), 34, 0, TAU, 40, Color(ice.r, ice.g, ice.b, fa2), 3.0)

	# ── 13. Fire — muzzle blast and freeze halo ────────────────────────────────────
	if s:
		var _te := 0.60 + sin(_anim_time * 12.0) * 0.35
		draw_circle(b_center_tip, 20.0, Color(cyan.r, cyan.g, cyan.b, _te * 0.30))
		draw_circle(b_center_tip, 14.0, Color(ice_l.r, ice_l.g, ice_l.b, _te * 0.45))
		draw_circle(b_left_tip,   14.0, Color(cyan.r, cyan.g, cyan.b, _te * 0.25))
		draw_circle(b_right_tip,  14.0, Color(cyan.r, cyan.g, cyan.b, _te * 0.25))
		draw_arc(b_center_tip, 16.0, 0, TAU, 24, Color(rune.r, rune.g, rune.b, _te * 0.55), 2.0)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ── Arcane Overlord (type 19) ─────────────────────────────────────────────────

func _draw_arcane_overlord(b: float, s: bool) -> void:
	var pink   := Color(1.00, 0.28, 0.72)
	var pink_l := Color(1.00, 0.70, 0.92)
	var purp   := Color(0.62, 0.12, 0.95)
	var purp_l := Color(0.82, 0.50, 1.00)
	var blue   := Color(0.28, 0.52, 1.00)
	var white  := Color(1.00, 0.95, 1.00)
	var gold   := Color(0.90, 0.72, 0.22)

	var pulse    := sin(_anim_time * 2.8)
	var ring_rot := _anim_time * 1.5
	var orb_rot  := _anim_time * 2.2

	draw_circle(Vector2(0, 24), 14, Color(0, 0, 0, 0.18))

	# Central pedestal / anchor column
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, 6 + b), Vector2(5, 6 + b),
		Vector2(6, 22 + b), Vector2(-6, 22 + b)
	]), Color(purp.r * 0.4, purp.g * 0.4, purp.b * 0.4))
	draw_rect(Rect2(-8, 4 + b, 16, 6), Color(purp.r * 0.5, purp.g * 0.5, purp.b * 0.5))
	draw_line(Vector2(-8, 4 + b), Vector2(8, 4 + b), Color(pink.r, pink.g, pink.b, 0.60), 1.2)

	# Arcane obelisks at four corners
	for _i in range(4):
		var _ox : float = ([-16.0, 16.0, -16.0, 16.0])[_i]
		var _oy : float = ([-4.0, -4.0, 8.0, 8.0])[_i]
		# Obelisk shaft
		draw_colored_polygon(PackedVector2Array([
			Vector2(_ox - 2.5, _oy - 14 + b), Vector2(_ox + 2.5, _oy - 14 + b),
			Vector2(_ox + 3.0, _oy + 4 + b),  Vector2(_ox - 3.0, _oy + 4 + b)
		]), Color(purp.r * 0.55, purp.g * 0.55, purp.b * 0.55))
		draw_colored_polygon(PackedVector2Array([
			Vector2(_ox - 2.5, _oy - 14 + b), Vector2(_ox + 2.5, _oy - 14 + b),
			Vector2(_ox + 1.5, _oy - 12 + b), Vector2(_ox - 1.5, _oy - 12 + b)
		]), Color(purp_l.r * 0.7, purp_l.g * 0.7, purp_l.b * 0.7))
		# Obelisk tip (pointed cap)
		draw_colored_polygon(PackedVector2Array([
			Vector2(_ox - 2.5, _oy - 14 + b), Vector2(_ox + 2.5, _oy - 14 + b),
			Vector2(_ox, _oy - 20 + b)
		]), purp_l)
		# Obelisk crystal (pulsing pink)
		var _opa := 0.62 + pulse * 0.20
		draw_circle(Vector2(_ox, _oy - 12 + b), 2.5, Color(pink.r, pink.g, pink.b, _opa))
		draw_circle(Vector2(_ox, _oy - 12 + b), 1.5, Color(1, 1, 1, _opa * 0.70))
		# Energy stream from obelisk to core
		draw_line(Vector2(_ox, _oy - 11 + b), Vector2(0, -6 + b), Color(pink.r, pink.g, pink.b, 0.28), 0.8)

	# Huge floating arcane core
	var cy := -6.0 + b + sin(_anim_time * 2.2) * 2.0
	var cr  := 13.0 + pulse * 1.0
	draw_circle(Vector2(0, cy), cr + 6.0, Color(purp.r, purp.g, purp.b, 0.16 + pulse * 0.06))
	draw_circle(Vector2(0, cy), cr,        Color(pink.r, pink.g, pink.b, 0.80))
	draw_circle(Vector2(0, cy), cr - 3.0,  Color(purp_l.r, purp_l.g, purp_l.b, 0.85))
	draw_circle(Vector2(0, cy), cr - 7.0,  Color(pink_l.r, pink_l.g, pink_l.b, 0.88))
	draw_circle(Vector2(0, cy), cr - 10.0, Color(1.00, 0.95, 1.00, 0.90))
	draw_circle(Vector2(-2, cy - 2), 3.5, Color(1, 1, 1, 0.85))

	# Rotating rings (3 concentric)
	draw_arc(Vector2(0, cy), cr + 4,       ring_rot,         ring_rot + TAU,         24, Color(pink.r, pink.g, pink.b, 0.70), 2.5)
	draw_arc(Vector2(0, cy), cr + 8,       ring_rot * 0.7,   ring_rot * 0.7 + TAU,   28, Color(purp.r, purp.g, purp.b, 0.55), 2.0)
	draw_arc(Vector2(0, cy), cr + 12,      -ring_rot * 0.5,  -ring_rot * 0.5 + TAU,  32, Color(blue.r, blue.g, blue.b, 0.40), 1.5)

	# 4 orbiting crystal nodes on outermost ring
	for _i in range(4):
		var _oa := orb_rot + float(_i) * TAU / 4.0
		var _nx := cos(_oa) * (cr + 12)
		var _ny := sin(_oa) * (cr + 12) + cy - b
		var _na := 0.55 + pulse * 0.18
		draw_circle(Vector2(_nx, _ny + b), 4.0, Color(purp_l.r, purp_l.g, purp_l.b, _na * 0.60))
		draw_circle(Vector2(_nx, _ny + b), 2.5, Color(pink.r, pink.g, pink.b, _na + 0.10))
		draw_circle(Vector2(_nx, _ny + b), 1.2, Color(1, 1, 1, _na + 0.20))

	# Floating arcane runes (4, outer orbit)
	for _i in range(4):
		var _ra := -orb_rot * 0.4 + float(_i) * TAU / 4.0
		var _rx := cos(_ra) * 28.0
		var _ry := sin(_ra) * 12.0 + b - 6.0
		var _rua := 0.28 + pulse * 0.10
		draw_arc(Vector2(_rx, _ry), 4.0, 0, TAU, 8, Color(pink_l.r, pink_l.g, pink_l.b, _rua), 1.2)
		draw_line(Vector2(_rx - 2, _ry), Vector2(_rx + 2, _ry), Color(white.r, white.g, white.b, _rua + 0.20), 0.8)
		draw_line(Vector2(_rx, _ry - 2), Vector2(_rx, _ry + 2), Color(white.r, white.g, white.b, _rua + 0.20), 0.8)

	# Ambient arcane corona
	var cga := 0.12 + pulse * 0.05
	draw_arc(Vector2(0, cy), 32, 0, TAU, 36, Color(pink.r, pink.g, pink.b, cga), 4.0)

	if s:
		draw_circle(Vector2(0, cy), cr + 18, Color(purp.r, purp.g, purp.b, 0.18))
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
	# ── Dragon Lich — Undead dragon king channeling necromantic storms ────────────
	var purp   := Color(0.35, 0.10, 0.52)
	var purp_l := Color(0.58, 0.28, 0.82)
	var blk    := Color(0.08, 0.06, 0.12)
	var bone   := Color(0.88, 0.84, 0.72)
	var bone_l := Color(1.00, 0.98, 0.88)
	var cyan   := Color(0.20, 0.92, 0.82)
	var cyan_l := Color(0.65, 1.00, 0.95)
	var ghost  := Color(0.42, 1.00, 0.78)

	var pulse  : float = sin(_anim_time * 3.5)
	var orb_t  : float = _anim_time * 1.8
	var ea     : float = 0.70 + pulse * 0.30

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.95, 0.95))
	# ── 1. Shadow ────────────────────────────────────────────────────────────────
	draw_circle(Vector2(0, 24), 18, Color(0, 0, 0, 0.22))

	# ── 2. Necromantic altar base ─────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, 2 + b), Vector2(12, 2 + b),
		Vector2(14, 22 + b), Vector2(-14, 22 + b)
	]), purp.darkened(0.15))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, 2 + b), Vector2(12, 2 + b),
		Vector2(10, 4 + b),  Vector2(-10, 4 + b)
	]), purp_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(8, 4 + b), Vector2(12, 2 + b),
		Vector2(14, 22 + b), Vector2(10, 22 + b)
	]), blk)
	# Bone rune bands with soul-fire center dot
	for _i in range(3):
		var _ry : float = 6.0 + float(_i) * 5.5
		draw_line(Vector2(-10, _ry + b), Vector2(-3, _ry + b), Color(bone.r, bone.g, bone.b, 0.68), 1.8)
		draw_line(Vector2(  3, _ry + b), Vector2(10, _ry + b), Color(bone.r, bone.g, bone.b, 0.68), 1.8)
		draw_circle(Vector2(0, _ry + b), 2.0, Color(cyan.r, cyan.g, cyan.b, 0.42))

	# ── 3. Tattered wing membranes (behind body) ──────────────────────────────────
	# LEFT wing
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -10 + b), Vector2(-24, -24 + b),
		Vector2(-28, -12 + b), Vector2(-24, -2 + b),
		Vector2(-16, 2 + b),   Vector2(-10, 2 + b)
	]), Color(purp.r, purp.g, purp.b, 0.78))
	# Inner void (darker hollow)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -9 + b),  Vector2(-20, -20 + b),
		Vector2(-24, -12 + b), Vector2(-20, -3 + b),
		Vector2(-14, 0 + b)
	]), Color(purp.r * 0.45, purp.g * 0.45, purp.b * 0.45, 0.58))
	# Tattered edge tears (ragged triangles)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-22, -18 + b), Vector2(-28, -14 + b), Vector2(-26, -10 + b)
	]), Color(purp_l.r, purp_l.g, purp_l.b, 0.32))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-16, -22 + b), Vector2(-20, -26 + b), Vector2(-13, -24 + b)
	]), Color(purp_l.r, purp_l.g, purp_l.b, 0.25))
	# Bone spars
	draw_line(Vector2(-10, -10 + b), Vector2(-24, -24 + b), Color(bone.r, bone.g, bone.b, 0.60), 1.4)
	draw_line(Vector2(-10, -7 + b),  Vector2(-22, -18 + b), Color(bone.r, bone.g, bone.b, 0.46), 1.0)
	draw_line(Vector2(-10, -3 + b),  Vector2(-20, -12 + b), Color(bone.r, bone.g, bone.b, 0.38), 0.8)
	draw_circle(Vector2(-24, -24 + b), 2.8, bone)

	# RIGHT wing (mirrored)
	draw_colored_polygon(PackedVector2Array([
		Vector2(10, -10 + b), Vector2(24, -24 + b),
		Vector2(28, -12 + b), Vector2(24, -2 + b),
		Vector2(16, 2 + b),   Vector2(10, 2 + b)
	]), Color(purp.r, purp.g, purp.b, 0.78))
	draw_colored_polygon(PackedVector2Array([
		Vector2(12, -9 + b),  Vector2(20, -20 + b),
		Vector2(24, -12 + b), Vector2(20, -3 + b),
		Vector2(14, 0 + b)
	]), Color(purp.r * 0.45, purp.g * 0.45, purp.b * 0.45, 0.58))
	draw_colored_polygon(PackedVector2Array([
		Vector2(22, -18 + b), Vector2(28, -14 + b), Vector2(26, -10 + b)
	]), Color(purp_l.r, purp_l.g, purp_l.b, 0.32))
	draw_colored_polygon(PackedVector2Array([
		Vector2(16, -22 + b), Vector2(20, -26 + b), Vector2(13, -24 + b)
	]), Color(purp_l.r, purp_l.g, purp_l.b, 0.25))
	draw_line(Vector2(10, -10 + b), Vector2(24, -24 + b), Color(bone.r, bone.g, bone.b, 0.60), 1.4)
	draw_line(Vector2(10, -7 + b),  Vector2(22, -18 + b), Color(bone.r, bone.g, bone.b, 0.46), 1.0)
	draw_line(Vector2(10, -3 + b),  Vector2(20, -12 + b), Color(bone.r, bone.g, bone.b, 0.38), 0.8)
	draw_circle(Vector2(24, -24 + b), 2.8, bone)

	# ── 4. Skeletal ribcage body ──────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -10 + b), Vector2(11, -10 + b),
		Vector2(13, 2 + b),    Vector2(-13, 2 + b)
	]), purp)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -10 + b), Vector2(11, -10 + b),
		Vector2(9, -8 + b),    Vector2(-9, -8 + b)
	]), purp_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(7, -10 + b), Vector2(11, -10 + b),
		Vector2(13, 2 + b),  Vector2(9, 2 + b)
	]), blk)
	# Exposed rib pairs (3 rows, more prominent, with cyan soul-glow)
	for _i in range(3):
		var _ry : float = -7.5 + float(_i) * 3.5
		draw_arc(Vector2(-2, _ry + b), 7.5, PI * 0.15, PI * 0.88, 7, Color(bone.r, bone.g, bone.b, 0.78), 2.0)
		draw_arc(Vector2(-2, _ry + b), 7.5, PI * 0.15, PI * 0.88, 7, Color(cyan.r, cyan.g, cyan.b, 0.24), 0.8)
		draw_arc(Vector2( 2, _ry + b), 7.5, PI * 0.12, PI * 0.85, 7, Color(bone.r, bone.g, bone.b, 0.78), 2.0)
		draw_arc(Vector2( 2, _ry + b), 7.5, PI * 0.12, PI * 0.85, 7, Color(cyan.r, cyan.g, cyan.b, 0.24), 0.8)
		draw_circle(Vector2(-8, _ry + b), 2.2, Color(bone_l.r, bone_l.g, bone_l.b, 0.68))
		draw_circle(Vector2( 8, _ry + b), 2.2, Color(bone_l.r, bone_l.g, bone_l.b, 0.68))

	# ── 5. Soul-fire crystal core (5-layer, pulsing) ──────────────────────────────
	var sc_r : float = 5.0 + pulse * 1.0
	draw_circle(Vector2(0, -3 + b), sc_r + 3.5, Color(cyan.r,   cyan.g,   cyan.b,   0.16))
	draw_circle(Vector2(0, -3 + b), sc_r + 1.5, Color(purp_l.r, purp_l.g, purp_l.b, 0.24))
	draw_circle(Vector2(0, -3 + b), sc_r,        Color(cyan.r,   cyan.g,   cyan.b,   0.82))
	draw_circle(Vector2(0, -3 + b), sc_r - 2.0,  Color(cyan_l.r, cyan_l.g, cyan_l.b, 0.90))
	draw_circle(Vector2(0, -3 + b), sc_r - 3.5,  Color(1.0, 1.0, 1.0, 0.85))
	draw_circle(Vector2(-1, -4 + b), 1.6, Color(1, 1, 1, 0.88))

	# ── 6. Purple soul lightning (core → skull eyes) ──────────────────────────────
	var lz : float = 0.38 + pulse * 0.28
	var _jx : float = sin(_anim_time * 13.0) * 4.0
	var _jy : float = -11.5 + cos(_anim_time * 10.5) * 2.5
	draw_line(Vector2(0, -3 + b),    Vector2(_jx, _jy + b),   Color(purp_l.r, purp_l.g, purp_l.b, lz * 0.82), 0.9)
	draw_line(Vector2(_jx, _jy + b), Vector2(-5, -22 + b),    Color(purp_l.r, purp_l.g, purp_l.b, lz * 0.82), 0.9)
	draw_line(Vector2(0, -3 + b),    Vector2(5, -22 + b),     Color(purp_l.r, purp_l.g, purp_l.b, lz * 0.62), 0.8)
	draw_line(Vector2(-2, -3 + b),   Vector2(-5, -22 + b),    Color(1.0, 0.88, 1.0, lz * 0.38), 0.7)
	draw_line(Vector2(2, -3 + b),    Vector2(5, -22 + b),     Color(1.0, 0.88, 1.0, lz * 0.38), 0.7)

	# ── 7. Dragon skull (dominant centerpiece, at y=-22) ─────────────────────────
	draw_circle(Vector2(0, -22 + b), 13.0, purp.darkened(0.30))
	draw_circle(Vector2(0, -22 + b), 12.0, purp.lightened(0.02))
	# Temporal bosses (cheekbone protrusions)
	draw_circle(Vector2(-11, -20 + b), 4.5, bone.darkened(0.12))
	draw_circle(Vector2( 11, -20 + b), 4.5, bone.darkened(0.12))
	# Skull dome (bone cap over the head)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -26 + b), Vector2(11, -26 + b),
		Vector2(13, -18 + b),  Vector2(-13, -18 + b)
	]), bone)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -26 + b), Vector2(11, -26 + b),
		Vector2(9, -25 + b),   Vector2(-9, -25 + b)
	]), bone_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(7, -26 + b), Vector2(11, -26 + b),
		Vector2(13, -18 + b), Vector2(9, -18 + b)
	]), Color(bone.r * 0.78, bone.g * 0.78, bone.b * 0.78))
	# Nasal cavity hollow
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3.5, -19 + b), Vector2(3.5, -19 + b),
		Vector2(2.5, -15 + b),  Vector2(-2.5, -15 + b)
	]), Color(blk.r, blk.g, blk.b, 0.82))
	# Upper snout plate
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -18 + b), Vector2(11, -18 + b),
		Vector2(10, -13 + b),  Vector2(-10, -13 + b)
	]), bone)
	# Lower jaw (extended, open)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -13 + b), Vector2(10, -13 + b),
		Vector2(9, -9 + b),    Vector2(-9, -9 + b)
	]), Color(bone.r * 0.88, bone.g * 0.88, bone.b * 0.88))
	# 5 jagged bone teeth
	for _i in range(5):
		var _tx : float = float(_i - 2) * 3.8
		draw_colored_polygon(PackedVector2Array([
			Vector2(_tx - 2, -9 + b), Vector2(_tx + 2, -9 + b),
			Vector2(_tx, -6 + b)
		]), bone_l)
		draw_circle(Vector2(_tx, -6.5 + b), 1.0, Color(cyan.r, cyan.g, cyan.b, 0.42))
	# Soul-fire eyes (large pulsing glow)
	draw_circle(Vector2(-5, -22 + b), 5.5, Color(cyan.r, cyan.g, cyan.b, 0.28))
	draw_circle(Vector2(-5, -22 + b), 4.2, Color(cyan.r, cyan.g, cyan.b, ea))
	draw_circle(Vector2(-5, -22 + b), 2.4, Color(1.0, 1.0, 1.0, ea))
	draw_circle(Vector2( 5, -22 + b), 5.5, Color(cyan.r, cyan.g, cyan.b, 0.28))
	draw_circle(Vector2( 5, -22 + b), 4.2, Color(cyan.r, cyan.g, cyan.b, ea))
	draw_circle(Vector2( 5, -22 + b), 2.4, Color(1.0, 1.0, 1.0, ea))
	# ── 8. Skull horns (thick, swept, with soul-glow tips) ───────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -30 + b), Vector2(-4, -30 + b),
		Vector2(-2, -37 + b), Vector2(-6, -42 + b), Vector2(-10, -36 + b)
	]), bone.darkened(0.12))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -30 + b), Vector2(-4, -30 + b),
		Vector2(-3, -36 + b), Vector2(-6, -41 + b), Vector2(-9, -35 + b)
	]), bone)
	draw_line(Vector2(-7, -31 + b), Vector2(-9, -36 + b), Color(cyan.r, cyan.g, cyan.b, 0.44), 0.9)
	draw_circle(Vector2(-6, -41 + b), 2.2, Color(cyan.r, cyan.g, cyan.b, ea * 0.88))
	draw_colored_polygon(PackedVector2Array([
		Vector2(4, -30 + b), Vector2(8, -30 + b),
		Vector2(10, -36 + b), Vector2(6, -42 + b), Vector2(2, -37 + b)
	]), bone.darkened(0.12))
	draw_colored_polygon(PackedVector2Array([
		Vector2(4, -30 + b), Vector2(8, -30 + b),
		Vector2(9, -35 + b), Vector2(6, -41 + b), Vector2(3, -36 + b)
	]), bone)
	draw_line(Vector2(7, -31 + b), Vector2(9, -36 + b), Color(cyan.r, cyan.g, cyan.b, 0.44), 0.9)
	draw_circle(Vector2(6, -41 + b), 2.2, Color(cyan.r, cyan.g, cyan.b, ea * 0.88))

	# ── 9. Ghost flame tendrils rising ────────────────────────────────────────────
	for _i in range(3):
		var _ft : float = fmod(_anim_time * 0.6 + float(_i) * 0.33, 1.0)
		var _fy : float = -30.0 - _ft * 18.0 + b
		var _fa : float = (1.0 - _ft) * 0.55
		draw_circle(Vector2(float(_i - 1) * 5.5, _fy), 2.5 + _ft * 2.2, Color(cyan.r, cyan.g, cyan.b, _fa))

	# ── 10. Floating rib bones orbiting (4, inner ring r=19) ─────────────────────
	for _i in range(4):
		var _oa    : float = orb_t + float(_i) * TAU / 4.0
		var _ox    : float = cos(_oa) * 19.0
		var _oy    : float = sin(_oa) * 8.0 - 8.0 + b
		var _oa2   : float = 0.55 + pulse * 0.18
		var _rstart: float = _oa + PI * 0.25
		var _rend  : float = _oa + PI * 1.05
		draw_arc(Vector2(_ox, _oy), 5.5, _rstart, _rend, 8, Color(bone.r, bone.g, bone.b, _oa2), 2.8)
		draw_arc(Vector2(_ox, _oy), 5.5, _rstart, _rend, 8, Color(cyan.r, cyan.g, cyan.b, _oa2 * 0.36), 1.0)
		draw_circle(Vector2(_ox + cos(_rstart) * 5.5, _oy + sin(_rstart) * 5.5),
			1.8, Color(bone_l.r, bone_l.g, bone_l.b, _oa2 * 0.85))

	# ── 11. Ancient rune hexagons orbiting (3, mid ring r=24) ────────────────────
	for _i in range(3):
		var _ra  : float = orb_t * 0.8 + float(_i) * TAU / 3.0
		var _rx  : float = cos(_ra) * 24.0
		var _ry  : float = sin(_ra) * 10.0 - 8.0 + b
		var _ra2 : float = 0.36 + pulse * 0.12
		draw_arc(Vector2(_rx, _ry), 4.5, 0, TAU, 6, Color(purp_l.r, purp_l.g, purp_l.b, _ra2 + 0.12), 1.8)
		draw_arc(Vector2(_rx, _ry), 2.8, 0, TAU, 6, Color(cyan.r,   cyan.g,   cyan.b,   _ra2 + 0.18), 1.2)
		draw_line(Vector2(_rx - 3, _ry), Vector2(_rx + 3, _ry), Color(bone.r, bone.g, bone.b, _ra2 + 0.22), 0.9)
		draw_line(Vector2(_rx, _ry - 3), Vector2(_rx, _ry + 3), Color(bone.r, bone.g, bone.b, _ra2 + 0.22), 0.9)
		draw_circle(Vector2(_rx, _ry), 1.5, Color(cyan_l.r, cyan_l.g, cyan_l.b, _ra2 * 0.78))

	# ── 12. Tombstone shards orbiting (3, outer ring r=28) ───────────────────────
	for _i in range(3):
		var _ta  : float = -orb_t * 0.55 + float(_i) * TAU / 3.0
		var _tsx : float = cos(_ta) * 28.0
		var _tsy : float = sin(_ta) * 12.0 - 8.0 + b
		var _ta2 : float = 0.42 + pulse * 0.14
		draw_colored_polygon(PackedVector2Array([
			Vector2(_tsx - 2.5, _tsy + 5),  Vector2(_tsx - 3.5, _tsy - 1),
			Vector2(_tsx, _tsy - 7),         Vector2(_tsx + 3.5, _tsy - 1),
			Vector2(_tsx + 2.5, _tsy + 5)
		]), Color(blk.r, blk.g, blk.b, _ta2 + 0.18))
		draw_colored_polygon(PackedVector2Array([
			Vector2(_tsx - 1.5, _tsy + 3), Vector2(_tsx - 2.5, _tsy - 0.5),
			Vector2(_tsx, _tsy - 5),        Vector2(_tsx + 2.5, _tsy - 0.5),
			Vector2(_tsx + 1.5, _tsy + 3)
		]), Color(purp.r, purp.g, purp.b, _ta2))
		draw_circle(Vector2(_tsx, _tsy - 4), 1.4, Color(cyan.r, cyan.g, cyan.b, _ta2 * 0.82))

	# ── 13. Necromantic aura ──────────────────────────────────────────────────────
	var aura_a : float = 0.16 + pulse * 0.07
	draw_arc(Vector2(0, -16 + b), 30, 0, TAU, 32, Color(cyan.r, cyan.g, cyan.b, aura_a), 3.5)

	# ── 14. Attack discharge ──────────────────────────────────────────────────────
	if s:
		var _ba := 0.50 + sin(_anim_time * 8.0) * 0.42
		draw_arc(Vector2(0, -16 + b), 34, 0, TAU, 38, Color(ghost.r, ghost.g, ghost.b, _ba * 0.32), 3.5)
		draw_circle(Vector2(0, -16 + b), 12, Color(cyan.r, cyan.g, cyan.b, _ba * 0.20))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ── Tempest Warden (type 21) ──────────────────────────────────────────────────

func _draw_tempest_warden(b: float, s: bool) -> void:
	# ── Tempest Warden — Fusion-tier storm warrior, fastest striker ───────────────
	var steel  := Color(0.48, 0.54, 0.68)
	var steel_l:= Color(0.72, 0.78, 0.92)
	var steel_d:= Color(0.24, 0.28, 0.40)
	var wind   := Color(0.40, 0.86, 1.00)
	var wind_l := Color(0.80, 0.96, 1.00)
	var elec   := Color(0.55, 0.82, 1.00)

	var pulse       : float = sin(_anim_time * 3.8)
	var cape_wave   : float = sin(_anim_time * 4.2) * 3.5
	var orb_rot     : float = _anim_time * 2.6
	var charge_frac : float = float(_hit_counter) / 10.0
	var _ct      : float = 0.0
	var _swing_t : float = 0.0
	var _jump_h  : float = 0.0
	if _chrono_pulse > 0.0:
		_ct = 1.0 - (_chrono_pulse / 0.50)
		if _ct < 0.15:
			b += sin((_ct / 0.15) * PI) * 5.0
		else:
			var _jt : float = clampf((_ct - 0.15) / 0.70, 0.0, 1.0)
			_jump_h = sin(_jt * PI)
			b -= _jump_h * 30.0
		_swing_t = clampf((_ct - 0.22) / 0.50, 0.0, 1.0)

	var sp_base_rest := Vector2(20, 9 + b)
	var sp_tip_rest  := Vector2(-5, -28 + b)
	var sp_base      := sp_base_rest
	var sp_tip       := sp_tip_rest
	if _swing_t > 0.0:
		var _pivot    := Vector2(11, -8 + b)
		var _sw_angle : float = lerp(-PI * 0.50, PI * 0.60, _swing_t)
		sp_base = _pivot + (sp_base_rest - _pivot).rotated(_sw_angle)
		sp_tip  = _pivot + (sp_tip_rest  - _pivot).rotated(_sw_angle)
	elif s and _chrono_pulse <= 0.0 and _shoot_anim > 0.0:
		var _pivot  := Vector2(11, -8 + b)
		var _ns_t   : float = 1.0 - (_shoot_anim / 0.35)
		var _ns_ang : float = sin(_ns_t * PI) * (PI * 0.25)
		sp_base = _pivot + (sp_base_rest - _pivot).rotated(_ns_ang)
		sp_tip  = _pivot + (sp_tip_rest  - _pivot).rotated(_ns_ang)

	# ── 1. Shadow ────────────────────────────────────────────────────────────────
	draw_circle(Vector2(0, 24), 16, Color(0, 0, 0, 0.20))

	# ── 2. Air currents swirling at feet (count scales with charge) ──────────────
	var _wp_count : int = 3 + int(charge_frac * 3.0)
	for _i in range(_wp_count):
		var _at : float = fmod(_anim_time * (1.8 + charge_frac * 1.8) + float(_i) / float(_wp_count), 1.0)
		var _ar : float = 7.0 + _at * 16.0
		var _aa : float = (1.0 - _at) * (0.26 + charge_frac * 0.22)
		var _as : float = _anim_time * (2.0 + charge_frac * 1.4) + float(_i) * TAU / float(_wp_count)
		draw_arc(Vector2(0, 18 + b), _ar, _as, _as + TAU * 0.65, 10, Color(wind.r, wind.g, wind.b, _aa), 1.4 + charge_frac * 0.5)

	# ── 3. Tornado spirals at feet (2) ────────────────────────────────────────────
	for _ti in range(2):
		var _tx : float = float(_ti * 2 - 1) * 7.0
		for _j in range(3):
			var _tr    : float = 2.2 + float(_j) * 1.8
			var _ta    : float = 0.36 + pulse * 0.14 - float(_j) * 0.10
			var _tstart: float = -_anim_time * 4.0 + float(_j) * 0.9
			draw_arc(Vector2(_tx, 17 + b), _tr, _tstart, _tstart + TAU * 0.72, 8,
				Color(wind.r, wind.g, wind.b, _ta), 1.2 - float(_j) * 0.25)

	# ── 4. Storm cape LEFT (large, dramatically billowing) ───────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -8 + b),
		Vector2(-22, -24 + b + cape_wave * 0.8),
		Vector2(-32, -10 + b + cape_wave * 1.4),
		Vector2(-30,  5 + b + cape_wave * 0.6),
		Vector2(-18, 10 + b),
		Vector2(-11,  4 + b)
	]), Color(wind.r * 0.30, wind.g * 0.30, wind.b * 0.38, 0.84))
	# Inner lighter layer
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -7 + b),
		Vector2(-19, -20 + b + cape_wave * 0.7),
		Vector2(-27,  -8 + b + cape_wave * 1.2),
		Vector2(-25,   4 + b + cape_wave * 0.5),
		Vector2(-16,   8 + b),
		Vector2(-11,   3 + b)
	]), Color(wind.r * 0.50, wind.g * 0.50, wind.b * 0.60, 0.40))
	# Electric trim on leading edge
	draw_line(Vector2(-11, -8 + b), Vector2(-22, -24 + b + cape_wave * 0.8), Color(wind.r, wind.g, wind.b, 0.55), 1.2)
	draw_line(Vector2(-11, -8 + b), Vector2(-32, -10 + b + cape_wave * 1.4), Color(elec.r, elec.g, elec.b, 0.42), 0.9)
	draw_line(Vector2(-11, -5 + b), Vector2(-24,  -4 + b + cape_wave),       Color(wind_l.r, wind_l.g, wind_l.b, 0.28), 0.8)
	# Small right cape (trailing side)
	draw_colored_polygon(PackedVector2Array([
		Vector2(11, -6 + b),
		Vector2(20, -16 + b + cape_wave * 0.6),
		Vector2(18,  0 + b),
		Vector2(11,  4 + b)
	]), Color(wind.r * 0.30, wind.g * 0.30, wind.b * 0.38, 0.65))
	draw_line(Vector2(11, -6 + b), Vector2(20, -16 + b + cape_wave * 0.6), Color(wind.r, wind.g, wind.b, 0.40), 0.9)

	# ── 5. Legs (asymmetric — right slightly forward for combat stance) ───────────
	# Left leg (back)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, 4 + b), Vector2(-3, 4 + b),
		Vector2(-3, 22 + b), Vector2(-11, 22 + b)
	]), steel_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, 4 + b), Vector2(-3, 4 + b),
		Vector2(-3,  7 + b), Vector2(-11, 7 + b)
	]), steel)
	# Right leg (forward — starts 2 px lower)
	draw_colored_polygon(PackedVector2Array([
		Vector2(2, 2 + b), Vector2(10, 2 + b),
		Vector2(10, 20 + b), Vector2(2, 20 + b)
	]), steel_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(2, 2 + b), Vector2(10, 2 + b),
		Vector2(10, 5 + b), Vector2(2, 5 + b)
	]), steel)
	# Storm energy lines on greaves
	draw_line(Vector2(-9, 8 + b),  Vector2(-9, 14 + b), Color(wind.r, wind.g, wind.b, 0.52), 0.9)
	draw_line(Vector2(-9, 14 + b), Vector2(-7, 18 + b), Color(wind.r, wind.g, wind.b, 0.38), 0.8)
	draw_line(Vector2(8,  6 + b),  Vector2(8,  12 + b), Color(wind.r, wind.g, wind.b, 0.52), 0.9)

	# ── 6. Torso (streamlined, slightly asymmetric lean) ─────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -12 + b), Vector2(11, -10 + b),
		Vector2(10,   4 + b),  Vector2(-12, 4 + b)
	]), steel)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -12 + b), Vector2(11, -10 + b),
		Vector2(9,   -9 + b),  Vector2(-12, -10 + b)
	]), steel_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(7, -10 + b), Vector2(11, -10 + b),
		Vector2(10,  4 + b), Vector2(6,   4 + b)
	]), steel_d)
	# Storm energy cracks
	draw_line(Vector2(-9, -10 + b), Vector2(-5, -3 + b), Color(wind.r, wind.g, wind.b, 0.65), 1.0)
	draw_line(Vector2(-5, -3 + b),  Vector2(-7,  2 + b), Color(wind.r, wind.g, wind.b, 0.48), 0.9)
	draw_line(Vector2(2,  -9 + b),  Vector2(5,  -3 + b), Color(wind.r, wind.g, wind.b, 0.55), 0.9)
	draw_line(Vector2(-12, 4 + b),  Vector2(10,  4 + b), Color(steel_l.r, steel_l.g, steel_l.b, 0.38), 1.0)

	# ── 7. Electric-blue energy core in chest ────────────────────────────────────
	var ec_r : float = 4.8 + pulse * 0.9
	draw_circle(Vector2(-1, -2 + b), ec_r + 3.0, Color(wind.r,  wind.g,  wind.b,  0.16))
	draw_circle(Vector2(-1, -2 + b), ec_r,        Color(elec.r,  elec.g,  elec.b,  0.80))
	draw_circle(Vector2(-1, -2 + b), ec_r - 2.0,  Color(wind_l.r, wind_l.g, wind_l.b, 0.90))
	draw_circle(Vector2(-2, -3 + b), 1.6,          Color(1, 1, 1, 0.88))

	# ── 8. Aerodynamic shoulder pauldrons ────────────────────────────────────────
	# Left pauldron (larger, swept back, leading edge)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -12 + b), Vector2(-18, -8 + b),
		Vector2(-20,  -2 + b), Vector2(-16,  0 + b),
		Vector2(-12,  -4 + b)
	]), steel_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -12 + b), Vector2(-17, -8 + b),
		Vector2(-19,  -3 + b), Vector2(-15, -1 + b),
		Vector2(-12,  -5 + b)
	]), steel)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -12 + b), Vector2(-15, -10 + b),
		Vector2(-14,  -5 + b), Vector2(-12,  -4 + b)
	]), steel_l)
	draw_circle(Vector2(-16, -6 + b), 2.5, Color(wind.r, wind.g, wind.b, 0.72))
	# Right pauldron (smaller, pointed toward spear arm)
	draw_colored_polygon(PackedVector2Array([
		Vector2(10, -10 + b), Vector2(16, -6 + b),
		Vector2(16,  0 + b),  Vector2(12,  0 + b),
		Vector2(10,  -4 + b)
	]), steel_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(10, -10 + b), Vector2(15, -6 + b),
		Vector2(15,  -1 + b), Vector2(11, -1 + b),
		Vector2(10,  -5 + b)
	]), steel)
	draw_circle(Vector2(14, -4 + b), 2.0, Color(wind.r, wind.g, wind.b, 0.62))

	# ── 9. Left arm ───────────────────────────────────────────────────────────────
	draw_line(Vector2(-13, -6 + b), Vector2(-18, 8 + b), steel,   5.0)
	draw_line(Vector2(-13, -6 + b), Vector2(-18, 8 + b), steel_l, 2.0)
	draw_circle(Vector2(-18, 8 + b), 4.0, steel_d)
	draw_circle(Vector2(-18, 8 + b), 2.5, steel)

	# ── 10. Lightning Spear (right arm — wind-forged weapon) ─────────────────────
	draw_line(Vector2(11, -8 + b), sp_base, steel,   5.0)
	draw_line(Vector2(11, -8 + b), sp_base, steel_l, 1.8)
	draw_circle(sp_base, 4.5, steel_d)
	draw_circle(sp_base, 3.0, steel)
	# Shaft — 3 layers
	draw_line(sp_base, sp_tip, Color(steel_d.r, steel_d.g, steel_d.b, 0.95), 5.0)
	draw_line(sp_base, sp_tip, Color(steel.r,   steel.g,   steel.b,   0.92), 3.5)
	draw_line(sp_base, sp_tip, Color(wind_l.r,  wind_l.g,  wind_l.b,  0.62), 1.2)
	# Shaft reinforcement rings (3)
	for _ri in range(3):
		var _rp : Vector2 = sp_base.lerp(sp_tip, 0.25 + float(_ri) * 0.22)
		draw_circle(_rp, 3.2, steel_d)
		draw_circle(_rp, 2.0, steel_l)
	# Electric arcs along shaft
	for _i in range(4):
		var _t  : float   = float(_i) * 0.22
		var _bp : Vector2 = sp_base.lerp(sp_tip, _t + 0.08)
		var _ep : Vector2 = sp_base.lerp(sp_tip, _t + 0.18)
		var _perp := Vector2(_ep.y - _bp.y, _bp.x - _ep.x).normalized() * 2.8
		draw_line(_bp + _perp, _ep - _perp, Color(1, 1, 1, 0.55 + pulse * 0.22), 0.8)
	# Crossguard
	var _sgp    : Vector2 = sp_base.lerp(sp_tip, 0.14)
	var _sgperp := Vector2(sp_tip.y - sp_base.y, sp_base.x - sp_tip.x).normalized() * 8.0
	draw_line(_sgp - _sgperp, _sgp + _sgperp, steel_d, 3.5)
	draw_line(_sgp - _sgperp, _sgp + _sgperp, steel_l, 1.5)
	# Spearhead
	draw_colored_polygon(PackedVector2Array([
		sp_tip + Vector2(-4, 7), sp_tip + Vector2(4, 7),
		sp_tip + Vector2(1.5, 0), sp_tip + Vector2(0, -10), sp_tip + Vector2(-1.5, 0)
	]), Color(wind.r, wind.g, wind.b, 0.95))
	draw_colored_polygon(PackedVector2Array([
		sp_tip + Vector2(-2, 5), sp_tip + Vector2(2, 5),
		sp_tip + Vector2(0, -8)
	]), Color(1, 1, 1, 0.88))
	draw_circle(sp_tip, 7.0, Color(wind.r, wind.g, wind.b, 0.38 + pulse * 0.12))
	draw_circle(sp_tip, 4.5, Color(wind.r, wind.g, wind.b, 0.65))
	draw_circle(sp_tip, 2.5, Color(1, 1, 1, 0.90))

	# ── 11. Head (streamlined combat helm) ───────────────────────────────────────
	draw_circle(Vector2(0, -20 + b), 9.5, steel_d)
	draw_circle(Vector2(0, -21 + b), 8.5, steel)
	draw_circle(Vector2(0, -22 + b), 7.0, steel_l)
	# Pointed visor
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -22 + b), Vector2(7, -22 + b),
		Vector2(4,  -16 + b), Vector2(-4, -16 + b)
	]), Color(wind.r, wind.g, wind.b, 0.72 + pulse * 0.14))
	draw_line(Vector2(-7, -22 + b), Vector2(7, -22 + b), Color(wind_l.r, wind_l.g, wind_l.b, 0.60), 0.9)
	# Helm crown band
	draw_rect(Rect2(-8, -27 + b, 16, 4), steel_d)
	draw_rect(Rect2(-8, -27 + b, 16, 2), steel_l)
	# Wind crest arcs sweeping back from apex
	for _ci in range(3):
		var _cr : float = 4.5 + float(_ci) * 2.2
		var _ca : float = 0.52 - float(_ci) * 0.13
		var _cx : float = float(_ci - 1) * 3.5
		draw_arc(Vector2(_cx, -28 + b), _cr, PI * 1.10, PI * 1.85, 7,
			Color(wind.r, wind.g, wind.b, _ca + pulse * 0.10), 1.6 - float(_ci) * 0.35)

	# ── 12. Wind blades orbiting (4, inner ring r=22) ────────────────────────────
	for _i in range(4):
		var _ba  : float   = orb_rot + float(_i) * TAU / 4.0
		var _bx  : float   = cos(_ba) * 22.0
		var _by  : float   = sin(_ba) * 9.0 - 4.0 + b
		var _tx  : float   = -sin(_ba)
		var _ty  : float   = cos(_ba) * 0.42
		var _fwd  := Vector2(_tx * 9.0, _ty * 9.0)
		var _side := Vector2(cos(_ba) * 2.8, sin(_ba) * 1.1)
		draw_colored_polygon(PackedVector2Array([
			Vector2(_bx, _by) + _fwd,  Vector2(_bx, _by) + _side,
			Vector2(_bx, _by) - _fwd,  Vector2(_bx, _by) - _side
		]), Color(wind.r, wind.g, wind.b, 0.74))
		draw_colored_polygon(PackedVector2Array([
			Vector2(_bx, _by) + _fwd * 0.55,  Vector2(_bx, _by) + _side * 0.45,
			Vector2(_bx, _by) - _fwd * 0.55,  Vector2(_bx, _by) - _side * 0.45
		]), Color(wind_l.r, wind_l.g, wind_l.b, 0.88))
		draw_circle(Vector2(_bx, _by), 1.5, Color(1, 1, 1, 0.70))

	# ── 13. Wind sigils rotating (3, outer ring r=28) ────────────────────────────
	for _i in range(3):
		var _wa  : float = -orb_rot * 0.6 + float(_i) * TAU / 3.0
		var _wx  : float = cos(_wa) * 28.0
		var _wy  : float = sin(_wa) * 12.0 - 4.0 + b
		var _wsa : float = 0.32 + pulse * 0.12
		draw_arc(Vector2(_wx, _wy), 4.2, 0, TAU, 8, Color(wind.r,  wind.g,  wind.b,  _wsa + 0.10), 1.5)
		draw_arc(Vector2(_wx, _wy), 2.6, _anim_time * 4.0, _anim_time * 4.0 + TAU * 0.7, 6,
			Color(wind_l.r, wind_l.g, wind_l.b, _wsa + 0.20), 1.0)
		draw_circle(Vector2(_wx, _wy), 1.4, Color(1, 1, 1, _wsa * 0.80))

	# ── 13b. Charge lightning arcs (appear at ≥50% charge) ──────────────────────
	if charge_frac > 0.5:
		var _cl_int   : float = (charge_frac - 0.5) * 2.0
		var _cl_count : int   = 2 + int(_cl_int * 3.0)
		for _li in range(_cl_count):
			var _la  : float = fmod(_anim_time * 5.0, TAU) + float(_li) * TAU / float(_cl_count)
			var _lx1 : float = cos(_la) * 18.0
			var _ly1 : float = sin(_la) * 7.5 - 4.0 + b
			var _jx  : float = sin(_anim_time * 13.0 + float(_li) * 2.7) * 3.5
			var _jy  : float = cos(_anim_time * 11.0 + float(_li)) * 1.5
			var _lx2 : float = cos(_la) * 28.0 + _jx
			var _ly2 : float = sin(_la) * 11.5 - 4.0 + b + _jy
			var _bolt_a : float = (0.40 + _cl_int * 0.45) * (0.70 + pulse * 0.30)
			draw_line(Vector2(_lx1, _ly1), Vector2(_lx2, _ly2), Color(1.0, 1.0, 1.0, _bolt_a), 1.2)
			draw_line(Vector2(_lx1, _ly1), Vector2(_lx2, _ly2), Color(wind_l.r, wind_l.g, wind_l.b, _bolt_a * 0.55), 0.6)

	# ── 14. Storm charge ring (clockwise fill — same system as Shadow Weaver) ─────
	if _hit_counter > 0 and _chrono_pulse <= 0.0:
		var ring_a : float = 0.30 + charge_frac * 0.55
		draw_arc(Vector2(0, -6 + b), 30, -PI * 0.5,
				-PI * 0.5 + TAU * charge_frac, 36,
				Color(wind.r, wind.g, wind.b, ring_a), 3.0)

	# ── 15. Attack discharge ──────────────────────────────────────────────────────
	if s and _chrono_pulse <= 0.0:
		var _ba : float = 0.60 + sin(_anim_time * 8.0) * 0.38
		draw_circle(sp_tip, 12, Color(elec.r, elec.g, elec.b, _ba * 0.38))
		draw_circle(sp_tip,  6, Color(1, 1, 1, _ba * 0.55))

	# ── 16. Special — sword swing trail and energy flash ─────────────────────────
	if _chrono_pulse > 0.0 and _swing_t > 0.0:
		var _pivot      := Vector2(11, -8 + b)
		var _swing_glow : float = sin(clampf(_swing_t, 0.0, 1.0) * PI)
		# Onion-skin trail — ghost copies at earlier swing angles
		for _ti in range(4):
			var _trail_frac : float = _swing_t - float(_ti + 1) * 0.14
			if _trail_frac < 0.0:
				break
			var _trail_ang : float = lerp(-PI * 0.50, PI * 0.60, _trail_frac)
			var _trail_a   : float = (0.28 - float(_ti) * 0.05) * _swing_glow
			var _tb        : Vector2 = _pivot + (sp_base_rest - _pivot).rotated(_trail_ang)
			var _tt        : Vector2 = _pivot + (sp_tip_rest  - _pivot).rotated(_trail_ang)
			draw_line(_tb, _tt, Color(0.65, 0.95, 1.00, _trail_a), 9.0 - float(_ti) * 1.8)
		# Bright white glow on current blade
		draw_line(sp_base, sp_tip, Color(0.80, 0.97, 1.00, _swing_glow * 0.55), 12.0)
		draw_line(sp_base, sp_tip, Color(1.00, 1.00, 1.00, _swing_glow * 0.90),  4.0)
		# Tip energy burst
		draw_circle(sp_tip, 14.0 * _swing_glow, Color(1.00, 1.00, 1.00, _swing_glow * 0.55))
		draw_circle(sp_tip,  7.0 * _swing_glow, Color(0.80, 0.97, 1.00, _swing_glow * 0.90))
		# Slash launch flash (bright pop at ct ~0.42)
		if _ct > 0.30 and _ct < 0.60:
			var _flash_a : float = sin((_ct - 0.30) / 0.30 * PI) * _jump_h
			draw_circle(sp_tip, 26.0 * _flash_a, Color(1.00, 1.00, 1.00, _flash_a * 0.22))
			draw_circle(sp_tip, 15.0 * _flash_a, Color(0.80, 0.97, 1.00, _flash_a * 0.50))


func _draw_infernal_serpent(b: float, s: bool) -> void:
	# ── Fire Serpent Lord — Fusion-tier infernal dragon commander ─────────────────
	var red    := Color(0.88, 0.18, 0.04)    # deep molten red
	var red_l  := Color(1.00, 0.38, 0.08)    # bright lava red
	var drk    := Color(0.28, 0.06, 0.02)    # volcanic dark
	var blk    := Color(0.14, 0.05, 0.02)    # volcanic black
	var orange := Color(1.00, 0.55, 0.05)    # lava orange
	var gold   := Color(1.00, 0.72, 0.10)    # hot gold
	var yel    := Color(1.00, 0.92, 0.22)    # heat yellow
	var wh_hot := Color(1.00, 0.98, 0.82)    # white-hot
	var scale  := Color(0.52, 0.10, 0.04)    # dark dragon scale
	var scale_l:= Color(0.72, 0.20, 0.06)    # lighter scale

	var pulse    := sin(_anim_time * 3.2)
	var orb_rot  := _anim_time * 1.8
	var rune_rot := _anim_time * 0.9
	var flame_t  := _anim_time * 4.0
	var fa       : float = abs(sin(flame_t))

	# ── 1. Shadow ────────────────────────────────────────────────────────────────
	draw_circle(Vector2(0, 24), 18, Color(0, 0, 0, 0.26))

	# ── 2. Fire wisps at feet ─────────────────────────────────────────────────────
	for _i in range(4):
		var _wt := fmod(_anim_time * 0.7 + float(_i) * 0.25, 1.0)
		var _wy := 18.0 - _wt * 16.0 + b
		var _wa := (1.0 - _wt) * 0.38
		var _wx := float(_i - 1) * 6.0
		draw_circle(Vector2(_wx, _wy), 2.5 + _wt * 2.0, Color(orange.r, orange.g, orange.b, _wa))

	# ── 3. Flame mantle / fire cape (behind body — drawn first) ───────────────────
	# Outer dark base
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -10 + b),  Vector2(8, -10 + b),
		Vector2(20, 2 + b),    Vector2(22, 14 + b),
		Vector2(0, 18 + b),    Vector2(-22, 14 + b),
		Vector2(-20, 2 + b)
	]), Color(drk.r, drk.g, drk.b, 0.88))
	# Orange mid-layer
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -8 + b),  Vector2(6, -8 + b),
		Vector2(16, 2 + b),   Vector2(18, 12 + b),
		Vector2(0, 16 + b),   Vector2(-18, 12 + b),
		Vector2(-16, 2 + b)
	]), Color(red.r, red.g, red.b, 0.75))
	# Bright inner fire (narrower)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4, -6 + b), Vector2(4, -6 + b),
		Vector2(10, 4 + b),  Vector2(8, 14 + b),
		Vector2(0, 16 + b),  Vector2(-8, 14 + b),
		Vector2(-10, 4 + b)
	]), Color(orange.r, orange.g, orange.b, 0.55))
	# Flame tongue tips on left edge
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20, 2 + b), Vector2(-24, -4 + b), Vector2(-18, 0 + b)
	]), Color(orange.r, orange.g, orange.b, 0.72))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-18, 8 + b), Vector2(-26, 4 + b), Vector2(-20, 6 + b)
	]), Color(red_l.r, red_l.g, red_l.b, 0.68))
	# Flame tongue tips on right edge
	draw_colored_polygon(PackedVector2Array([
		Vector2(20, 2 + b), Vector2(24, -4 + b), Vector2(18, 0 + b)
	]), Color(orange.r, orange.g, orange.b, 0.72))
	draw_colored_polygon(PackedVector2Array([
		Vector2(18, 8 + b), Vector2(26, 4 + b), Vector2(20, 6 + b)
	]), Color(red_l.r, red_l.g, red_l.b, 0.68))

	# ── 4. Legs (heavy dragon-scale greaves) ──────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, 4 + b), Vector2(-2, 4 + b),
		Vector2(-3, 22 + b), Vector2(-13, 22 + b)
	]), scale)
	draw_colored_polygon(PackedVector2Array([
		Vector2(2, 4 + b),  Vector2(12, 4 + b),
		Vector2(13, 22 + b), Vector2(3, 22 + b)
	]), scale)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, 4 + b), Vector2(-2, 4 + b),
		Vector2(-2, 7 + b),  Vector2(-12, 7 + b)
	]), scale_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(2, 4 + b),  Vector2(12, 4 + b),
		Vector2(12, 7 + b), Vector2(2, 7 + b)
	]), scale_l)
	# Lava crack on left greave
	draw_line(Vector2(-10, 8 + b), Vector2(-8, 14 + b), Color(orange.r, orange.g, orange.b, 0.72), 1.0)
	draw_line(Vector2(-8, 14 + b), Vector2(-10, 18 + b), Color(orange.r, orange.g, orange.b, 0.58), 0.9)
	# Lava crack on right greave
	draw_line(Vector2(8, 8 + b), Vector2(10, 14 + b),   Color(orange.r, orange.g, orange.b, 0.72), 1.0)
	draw_line(Vector2(10, 14 + b), Vector2(8, 18 + b),  Color(orange.r, orange.g, orange.b, 0.58), 0.9)
	# Ankle gold trim
	draw_line(Vector2(-13, 18 + b), Vector2(-3, 18 + b), gold, 1.5)
	draw_line(Vector2(3, 18 + b),   Vector2(13, 18 + b), gold, 1.5)

	# ── 5. Torso — dragon-scale plate armor ───────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -12 + b), Vector2(13, -12 + b),
		Vector2(12, 4 + b),    Vector2(-12, 4 + b)
	]), scale)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -12 + b), Vector2(13, -12 + b),
		Vector2(11, -10 + b),  Vector2(-11, -10 + b)
	]), scale_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(8, -12 + b), Vector2(13, -12 + b),
		Vector2(12, 4 + b),  Vector2(8, 4 + b)
	]), drk)
	# Dragon scale texture (arc rows)
	for _i in range(3):
		for _j in range(3):
			var _sx := float(_j - 1) * 7.0
			var _sy := -9.0 + float(_i) * 5.5 + b
			draw_arc(Vector2(_sx, _sy), 3.0, PI * 0.1, PI * 0.9, 6, Color(drk.r, drk.g, drk.b, 0.55), 1.2)
	# Lava cracks through torso
	draw_line(Vector2(-8, -10 + b), Vector2(-5, -4 + b), Color(orange.r, orange.g, orange.b, 0.78), 1.2)
	draw_line(Vector2(-5, -4 + b),  Vector2(-7, 2 + b),  Color(orange.r, orange.g, orange.b, 0.62), 1.0)
	draw_line(Vector2(4, -9 + b),   Vector2(7, -3 + b),  Color(orange.r, orange.g, orange.b, 0.72), 1.0)
	draw_line(Vector2(7, -3 + b),   Vector2(5, 2 + b),   Color(orange.r, orange.g, orange.b, 0.55), 0.9)
	# Central chest gem (molten crystal)
	var cg_r := 4.5 + pulse * 0.8
	draw_circle(Vector2(0, -4 + b), cg_r + 2.5, Color(orange.r, orange.g, orange.b, 0.20))
	draw_circle(Vector2(0, -4 + b), cg_r,        Color(red_l.r, red_l.g, red_l.b, 0.85))
	draw_circle(Vector2(0, -4 + b), cg_r - 2.0,  Color(gold.r, gold.g, gold.b, 0.88))
	draw_circle(Vector2(0, -4 + b), cg_r - 3.5,  Color(wh_hot.r, wh_hot.g, wh_hot.b, 0.90))
	draw_circle(Vector2(-1, -5 + b), 1.2, Color(1, 1, 1, 0.88))
	# Chest gold trim
	draw_line(Vector2(-13, -12 + b), Vector2(13, -12 + b), gold, 1.5)
	draw_line(Vector2(-12, 4 + b),   Vector2(12, 4 + b),   gold, 1.2)

	# ── 6. Serpent-head LEFT shoulder piece ───────────────────────────────────────
	# Skull / top of head
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -6 + b),  Vector2(-16, -8 + b),
		Vector2(-22, -6 + b),  Vector2(-26, -2 + b),
		Vector2(-22, 0 + b),   Vector2(-14, -2 + b)
	]), scale)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -6 + b), Vector2(-16, -8 + b),
		Vector2(-22, -6 + b), Vector2(-18, -5 + b),
		Vector2(-14, -4 + b)
	]), scale_l)
	# Lower jaw (open mouth)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, 0 + b), Vector2(-20, 2 + b),
		Vector2(-24, 4 + b), Vector2(-20, 5 + b),
		Vector2(-14, 3 + b)
	]), drk)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, 1 + b), Vector2(-19, 2 + b),
		Vector2(-22, 4 + b), Vector2(-19, 4.5 + b),
		Vector2(-14, 2.5 + b)
	]), Color(red.r * 0.7, red.g * 0.7, red.b * 0.7))
	# Fangs (2 inside the open jaw)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-16, -1 + b), Vector2(-18, -1 + b), Vector2(-17, 3 + b)
	]), Color(wh_hot.r, wh_hot.g, wh_hot.b, 0.90))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20, -1 + b), Vector2(-22, -1 + b), Vector2(-21, 3 + b)
	]), Color(wh_hot.r, wh_hot.g, wh_hot.b, 0.85))
	# Forked tongue flicker
	var tfa := 0.55 + pulse * 0.35
	draw_line(Vector2(-24, 1 + b), Vector2(-28, -1 + b), Color(red_l.r, red_l.g, red_l.b, tfa), 1.2)
	draw_line(Vector2(-24, 1 + b), Vector2(-28, 3 + b),  Color(red_l.r, red_l.g, red_l.b, tfa), 1.2)
	# Glowing serpent eye (LEFT)
	draw_circle(Vector2(-20, -5 + b), 3.2, yel)
	draw_circle(Vector2(-20, -5 + b), 1.8, Color(0.20, 0.04, 0.00))
	draw_circle(Vector2(-20.8, -5.8 + b), 0.8, Color(1, 1, 1, 0.72))
	# Scale ridge on top
	draw_arc(Vector2(-18, -7 + b), 5.0, -PI * 0.6, PI * 0.1, 8, Color(drk.r, drk.g, drk.b, 0.70), 1.2)
	# Gold rim trim on shoulder
	draw_line(Vector2(-12, -8 + b), Vector2(-22, -7 + b), gold, 1.2)

	# ── 7. Serpent-head RIGHT shoulder piece (mirrored) ───────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(12, -6 + b),  Vector2(16, -8 + b),
		Vector2(22, -6 + b),  Vector2(26, -2 + b),
		Vector2(22, 0 + b),   Vector2(14, -2 + b)
	]), scale)
	draw_colored_polygon(PackedVector2Array([
		Vector2(12, -6 + b), Vector2(16, -8 + b),
		Vector2(22, -6 + b), Vector2(18, -5 + b),
		Vector2(14, -4 + b)
	]), scale_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(14, 0 + b), Vector2(20, 2 + b),
		Vector2(24, 4 + b), Vector2(20, 5 + b),
		Vector2(14, 3 + b)
	]), drk)
	draw_colored_polygon(PackedVector2Array([
		Vector2(14, 1 + b), Vector2(19, 2 + b),
		Vector2(22, 4 + b), Vector2(19, 4.5 + b),
		Vector2(14, 2.5 + b)
	]), Color(red.r * 0.7, red.g * 0.7, red.b * 0.7))
	# Fangs
	draw_colored_polygon(PackedVector2Array([
		Vector2(16, -1 + b), Vector2(18, -1 + b), Vector2(17, 3 + b)
	]), Color(wh_hot.r, wh_hot.g, wh_hot.b, 0.90))
	draw_colored_polygon(PackedVector2Array([
		Vector2(20, -1 + b), Vector2(22, -1 + b), Vector2(21, 3 + b)
	]), Color(wh_hot.r, wh_hot.g, wh_hot.b, 0.85))
	# Forked tongue
	draw_line(Vector2(24, 1 + b), Vector2(28, -1 + b), Color(red_l.r, red_l.g, red_l.b, tfa), 1.2)
	draw_line(Vector2(24, 1 + b), Vector2(28, 3 + b),  Color(red_l.r, red_l.g, red_l.b, tfa), 1.2)
	# Glowing serpent eye (RIGHT)
	draw_circle(Vector2(20, -5 + b), 3.2, yel)
	draw_circle(Vector2(20, -5 + b), 1.8, Color(0.20, 0.04, 0.00))
	draw_circle(Vector2(20.8, -5.8 + b), 0.8, Color(1, 1, 1, 0.72))
	draw_arc(Vector2(18, -7 + b), 5.0, -PI * 0.1, PI * 0.6, 8, Color(drk.r, drk.g, drk.b, 0.70), 1.2)
	draw_line(Vector2(12, -8 + b), Vector2(22, -7 + b), gold, 1.2)

	# ── 8. Arms (thick, scale-armored, clawed) ────────────────────────────────────
	draw_line(Vector2(-12, -8 + b), Vector2(-18, 6 + b),  scale, 7.0)
	draw_line(Vector2( 12, -8 + b), Vector2( 18, 6 + b),  scale, 7.0)
	draw_line(Vector2(-12, -8 + b), Vector2(-18, 6 + b),  scale_l, 3.0)
	draw_line(Vector2( 12, -8 + b), Vector2( 18, 6 + b),  scale_l, 3.0)
	# Clawed fists
	draw_circle(Vector2(-18, 6 + b), 4.5, drk)
	draw_circle(Vector2( 18, 6 + b), 4.5, drk)
	draw_circle(Vector2(-18, 6 + b), 3.0, scale)
	draw_circle(Vector2( 18, 6 + b), 3.0, scale)
	# Claw tips
	for _c in [-1, 0, 1]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-18 + _c * 2.5 - 1, 9 + b),
			Vector2(-18 + _c * 2.5 + 1, 9 + b),
			Vector2(-18 + _c * 2.5, 13 + b)
		]), Color(drk.r, drk.g, drk.b, 0.90))
		draw_colored_polygon(PackedVector2Array([
			Vector2(18 + _c * 2.5 - 1, 9 + b),
			Vector2(18 + _c * 2.5 + 1, 9 + b),
			Vector2(18 + _c * 2.5, 13 + b)
		]), Color(drk.r, drk.g, drk.b, 0.90))
	# Gauntlet gold trim
	draw_arc(Vector2(-18, 6 + b), 4.5, -PI * 0.5, PI * 0.5, 8, gold, 1.2)
	draw_arc(Vector2( 18, 6 + b), 4.5, -PI * 0.5, PI * 0.5, 8, gold, 1.2)

	# ── 9. Head — armored dragon face ─────────────────────────────────────────────
	draw_circle(Vector2(0, -22 + b), 10, drk)
	draw_circle(Vector2(0, -23 + b), 9,  scale)
	draw_circle(Vector2(0, -24 + b), 7.5, scale_l)
	# Brow plate (heavy armored brow ridge)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -24 + b), Vector2(11, -24 + b),
		Vector2(9, -18 + b),   Vector2(-9, -18 + b)
	]), scale)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -24 + b), Vector2(11, -24 + b),
		Vector2(9, -23 + b),   Vector2(-9, -23 + b)
	]), scale_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(7, -24 + b), Vector2(11, -24 + b),
		Vector2(9, -18 + b), Vector2(6, -18 + b)
	]), drk)
	# Snout / lower face
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -18 + b), Vector2(7, -18 + b),
		Vector2(6, -14 + b),  Vector2(-6, -14 + b)
	]), drk.lightened(0.06))
	# Serpent eyes (vertical slit pupils)
	draw_circle(Vector2(-4, -21 + b), 3.5, yel)
	draw_circle(Vector2( 4, -21 + b), 3.5, yel)
	draw_circle(Vector2(-4, -21 + b), 2.0, Color(0.18, 0.04, 0.00))
	draw_circle(Vector2( 4, -21 + b), 2.0, Color(0.18, 0.04, 0.00))
	draw_circle(Vector2(-4.5, -22 + b), 0.9, Color(1, 1, 1, 0.72))
	# Lava crack on face plate
	draw_line(Vector2(-8, -22 + b), Vector2(-4, -18 + b), Color(orange.r, orange.g, orange.b, 0.68), 0.9)
	draw_line(Vector2(5, -22 + b),  Vector2(8, -18 + b),  Color(orange.r, orange.g, orange.b, 0.62), 0.9)
	# Gold face trim
	draw_line(Vector2(-11, -24 + b), Vector2(11, -24 + b), gold, 1.5)
	draw_line(Vector2(-9, -18 + b),  Vector2(9, -18 + b),  gold, 1.2)

	# ── 10. Molten crown (ring of lava spikes) ────────────────────────────────────
	draw_arc(Vector2(0, -28 + b), 8.0, 0, TAU, 16, Color(drk.r, drk.g, drk.b, 0.88), 3.5)
	draw_arc(Vector2(0, -28 + b), 8.0, 0, TAU, 16, Color(gold.r, gold.g, gold.b, 0.75), 1.5)
	# Crown spikes (5)
	for _i in range(5):
		var _ca  := float(_i) * TAU / 5.0 - PI * 0.5
		var _csx := cos(_ca) * 8.0
		var _csy := sin(_ca) * 5.0 - 28.0 + b
		var _cth := 5.0 if abs(_i - 0) == 0 else 3.5  # center spike taller
		draw_colored_polygon(PackedVector2Array([
			Vector2(_csx - 2, _csy), Vector2(_csx + 2, _csy),
			Vector2(_csx, _csy - _cth)
		]), Color(red_l.r, red_l.g, red_l.b, 0.90))
		draw_colored_polygon(PackedVector2Array([
			Vector2(_csx - 1, _csy), Vector2(_csx + 1, _csy),
			Vector2(_csx, _csy - _cth + 1)
		]), Color(orange.r, orange.g, orange.b, 0.80))
		draw_circle(Vector2(_csx, _csy - _cth), 1.5, Color(yel.r, yel.g, yel.b, 0.88))

	# ── 11. Dragon horns (sweeping back and upward) ───────────────────────────────
	# Left horn
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -27 + b), Vector2(-4, -27 + b),
		Vector2(-2, -34 + b), Vector2(-8, -42 + b), Vector2(-12, -36 + b)
	]), drk)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -27 + b), Vector2(-4, -27 + b),
		Vector2(-3, -33 + b), Vector2(-8, -40 + b), Vector2(-11, -35 + b)
	]), scale)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -27 + b), Vector2(-4.5, -27 + b),
		Vector2(-4, -32 + b), Vector2(-7, -36 + b)
	]), scale_l)
	draw_line(Vector2(-8, -27 + b), Vector2(-12, -36 + b), Color(gold.r, gold.g, gold.b, 0.45), 0.8)
	# Horn lava vein
	draw_line(Vector2(-6, -29 + b), Vector2(-7, -36 + b), Color(orange.r, orange.g, orange.b, 0.55), 0.8)

	# Right horn
	draw_colored_polygon(PackedVector2Array([
		Vector2(4, -27 + b), Vector2(8, -27 + b),
		Vector2(12, -36 + b), Vector2(8, -42 + b), Vector2(2, -34 + b)
	]), drk)
	draw_colored_polygon(PackedVector2Array([
		Vector2(4, -27 + b), Vector2(8, -27 + b),
		Vector2(11, -35 + b), Vector2(8, -40 + b), Vector2(3, -33 + b)
	]), scale)
	draw_colored_polygon(PackedVector2Array([
		Vector2(4.5, -27 + b), Vector2(7, -27 + b),
		Vector2(7, -36 + b), Vector2(4, -32 + b)
	]), scale_l)
	draw_line(Vector2(8, -27 + b), Vector2(12, -36 + b), Color(gold.r, gold.g, gold.b, 0.45), 0.8)
	draw_line(Vector2(6, -29 + b), Vector2(7, -36 + b), Color(orange.r, orange.g, orange.b, 0.55), 0.8)

	# ── 12. Floating fire crystals orbiting (3) ───────────────────────────────────
	for _i in range(3):
		var _oa  := orb_rot + float(_i) * TAU / 3.0
		var _ox  := cos(_oa) * 20.0
		var _oy  := sin(_oa) * 9.0 - 4.0 + b
		var _oa2 := 0.55 + pulse * 0.22
		# Crystal shard shape
		draw_colored_polygon(PackedVector2Array([
			Vector2(_ox, _oy - 6),   Vector2(_ox - 3, _oy + 1),
			Vector2(_ox, _oy + 3),   Vector2(_ox + 3, _oy + 1)
		]), Color(red.r, red.g, red.b, _oa2))
		draw_colored_polygon(PackedVector2Array([
			Vector2(_ox, _oy - 5),   Vector2(_ox - 2, _oy + 0),
			Vector2(_ox, _oy + 2),   Vector2(_ox + 2, _oy + 0)
		]), Color(orange.r, orange.g, orange.b, _oa2 + 0.10))
		draw_circle(Vector2(_ox, _oy - 3), 1.5, Color(yel.r, yel.g, yel.b, _oa2 * 0.80))

	# ── 13. Flame rune sigils orbiting (3, outer ring) ────────────────────────────
	for _i in range(3):
		var _ra  := -rune_rot + float(_i) * TAU / 3.0
		var _rx  := cos(_ra) * 28.0
		var _ry  := sin(_ra) * 12.0 - 4.0 + b
		var _rua := 0.32 + pulse * 0.14
		draw_circle(Vector2(_rx, _ry), 4.0, Color(red.r, red.g, red.b, _rua * 0.50))
		draw_arc(Vector2(_rx, _ry), 3.8, 0, TAU, 8, Color(gold.r, gold.g, gold.b, _rua + 0.10), 1.5)
		draw_line(Vector2(_rx - 2, _ry), Vector2(_rx + 2, _ry), Color(yel.r, yel.g, yel.b, _rua + 0.20), 0.9)
		draw_line(Vector2(_rx, _ry - 2), Vector2(_rx, _ry + 2), Color(yel.r, yel.g, yel.b, _rua + 0.20), 0.9)
		draw_circle(Vector2(_rx, _ry), 1.8, Color(orange.r, orange.g, orange.b, _rua + 0.15))

	# ── 14. Infernal aura (outer corona) ─────────────────────────────────────────
	var aura_a := 0.12 + pulse * 0.05
	draw_arc(Vector2(0, -4 + b), 32, 0, TAU, 36, Color(red_l.r, red_l.g, red_l.b, aura_a), 3.5)

	# ── 15. Attack effects ────────────────────────────────────────────────────────
	if s:
		var _ba := 0.50 + sin(_anim_time * 9.0) * 0.45
		draw_arc(Vector2(0, -4 + b), 34, 0, TAU, 40, Color(orange.r, orange.g, orange.b, _ba * 0.38), 4.0)
		draw_circle(Vector2(0, -4 + b), 12, Color(red_l.r, red_l.g, red_l.b, _ba * 0.22))
		# Fire breath surge from maw
		for _i in range(5):
			var _off := Vector2(randi_range(-10, 10), -14 - _i * 8 + b)
			draw_circle(_off, 5.0 + float(_i) * 1.5, Color(orange.r, orange.g, orange.b, _ba * (0.80 - float(_i) * 0.14)))
		draw_circle(Vector2(0, -40 + b), 10, Color(yel.r, yel.g, yel.b, _ba * 0.60))


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
	var emrld  := Color(0.12, 0.72, 0.32)
	var emrld_l:= Color(0.28, 0.95, 0.48)
	var emrld_d:= Color(0.06, 0.40, 0.18)
	var bark   := Color(0.36, 0.20, 0.08)
	var bark_l := Color(0.54, 0.34, 0.14)
	var bark_d := Color(0.22, 0.12, 0.04)
	var gold   := Color(0.88, 0.78, 0.18)
	var vine   := Color(0.20, 0.52, 0.16)
	var spirit := Color(0.45, 1.00, 0.58)

	var pulse  := sin(_anim_time * 2.5)
	var leaf_t := _anim_time * 0.9
	var spr_t  := _anim_time * 1.5

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.85, 0.85))
	draw_circle(Vector2(0, 24), 16, Color(0, 0, 0, 0.20))

	# Giant ancient roots (7 spreading far)
	draw_line(Vector2(-5, 18 + b), Vector2(-24, 28 + b), bark_d, 5.5)
	draw_line(Vector2(-3, 20 + b), Vector2(-18, 30 + b), bark_d, 4.0)
	draw_line(Vector2(-1, 20 + b), Vector2( -8, 30 + b), bark_d, 3.0)
	draw_line(Vector2( 1, 20 + b), Vector2(  8, 30 + b), bark_d, 3.0)
	draw_line(Vector2( 3, 20 + b), Vector2( 18, 30 + b), bark_d, 4.0)
	draw_line(Vector2( 5, 18 + b), Vector2( 24, 28 + b), bark_d, 5.5)
	draw_line(Vector2( 0, 22 + b), Vector2(  0, 30 + b), bark_d, 4.0)
	# Root highlight lines
	draw_line(Vector2(-5, 18 + b), Vector2(-24, 28 + b), Color(bark_l.r, bark_l.g, bark_l.b, 0.40), 1.5)
	draw_line(Vector2( 5, 18 + b), Vector2( 24, 28 + b), Color(bark_l.r, bark_l.g, bark_l.b, 0.40), 1.5)

	# Massive trunk (thick, ancient)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -12 + b), Vector2(11, -12 + b),
		Vector2(13, 22 + b),   Vector2(-13, 22 + b)
	]), bark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(4, -12 + b), Vector2(11, -12 + b),
		Vector2(13, 22 + b), Vector2(6, 22 + b)
	]), bark_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -12 + b), Vector2(-4, -12 + b),
		Vector2(-4, 22 + b),   Vector2(-11, 22 + b)
	]), Color(bark_l.r, bark_l.g, bark_l.b, 0.45))
	# Bark crack golden sap
	var ra := 0.52 + pulse * 0.22
	draw_line(Vector2(-6, -8 + b),  Vector2(-8, 0 + b),  Color(gold.r, gold.g, gold.b, ra * 0.65), 1.2)
	draw_line(Vector2(-8, 0 + b),   Vector2(-5, 6 + b),  Color(gold.r, gold.g, gold.b, ra * 0.55), 1.0)
	draw_line(Vector2(4, -6 + b),   Vector2(6, 2 + b),   Color(gold.r, gold.g, gold.b, ra * 0.60), 1.0)
	draw_line(Vector2(-2, 6 + b),   Vector2(3, 12 + b),  Color(gold.r, gold.g, gold.b, ra * 0.45), 0.9)

	# Sacred gold vines
	draw_arc(Vector2(-3, 2 + b),  8.0, -PI * 0.5, PI * 0.7, 10, vine, 2.0)
	draw_arc(Vector2( 3, 10 + b), 8.0,  PI * 0.3, PI * 1.6, 10, vine, 2.0)
	draw_arc(Vector2(-2, 16 + b), 6.0, -PI * 0.3, PI * 0.6, 8,  vine, 1.5)
	# Gold vine accents
	draw_arc(Vector2(-3, 2 + b),  8.0, -PI * 0.5, PI * 0.7, 10, Color(gold.r, gold.g, gold.b, 0.35), 0.7)

	# ANCIENT SPIRIT FACE (large and dramatic)
	# Brow ridges (heavy, furrowed)
	draw_line(Vector2(-9, -6 + b),  Vector2(-3, -9 + b), bark_d, 2.5)
	draw_line(Vector2( 3, -9 + b),  Vector2( 9, -6 + b), bark_d, 2.5)
	# Spirit eyes (large, blazing emerald)
	draw_circle(Vector2(-6, -5 + b), 4.5, Color(emrld.r, emrld.g, emrld.b, ra))
	draw_circle(Vector2( 6, -5 + b), 4.5, Color(emrld.r, emrld.g, emrld.b, ra))
	draw_circle(Vector2(-6, -5 + b), 2.8, Color(emrld_l.r, emrld_l.g, emrld_l.b, ra + 0.10))
	draw_circle(Vector2( 6, -5 + b), 2.8, Color(emrld_l.r, emrld_l.g, emrld_l.b, ra + 0.10))
	draw_circle(Vector2(-6, -5 + b), 1.5, Color(1, 1, 1, ra * 0.90))
	draw_circle(Vector2( 6, -5 + b), 1.5, Color(1, 1, 1, ra * 0.90))
	# Nose bridge
	draw_line(Vector2(-2, -4 + b), Vector2(-2, 0 + b), bark_d, 1.5)
	draw_line(Vector2( 2, -4 + b), Vector2( 2, 0 + b), bark_d, 1.5)
	# Ancient spirit mouth (carved arc)
	draw_arc(Vector2(0, 3 + b), 6.0, PI * 0.10, PI * 0.90, 10, bark_d, 2.5)
	draw_arc(Vector2(0, 3 + b), 5.5, PI * 0.15, PI * 0.85, 10, Color(gold.r, gold.g, gold.b, 0.50), 1.0)

	# Nature crystals embedded (3)
	for _i in range(3):
		var _cx := float(_i - 1) * 7.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(_cx - 2, -14 + b), Vector2(_cx + 2, -14 + b),
			Vector2(_cx + 1.5, -18 + b), Vector2(_cx - 1.5, -18 + b)
		]), Color(emrld_l.r, emrld_l.g, emrld_l.b, 0.82))
		draw_line(Vector2(_cx - 1, -14 + b), Vector2(_cx, -17 + b), Color(1, 1, 1, 0.45), 0.7)

	# Massive layered canopy
	draw_circle(Vector2( 0,  -22 + b), 16, emrld_d)
	draw_circle(Vector2(-14, -20 + b), 13, emrld)
	draw_circle(Vector2( 14, -20 + b), 13, emrld)
	draw_circle(Vector2( -7, -32 + b), 12, emrld_l)
	draw_circle(Vector2(  7, -32 + b), 12, emrld_l)
	draw_circle(Vector2(  0, -38 + b), 12, emrld_l.lightened(0.05))
	draw_circle(Vector2(-10, -40 + b),  8, Color(emrld_l.r, emrld_l.g, emrld_l.b, 0.88))
	draw_circle(Vector2( 10, -40 + b),  8, Color(emrld_l.r, emrld_l.g, emrld_l.b, 0.88))
	draw_circle(Vector2(  0, -44 + b),  7, Color(emrld_l.r, emrld_l.g, emrld_l.b, 0.80))

	# Floating leaf particles (6)
	for _i in range(6):
		var _la  := leaf_t + float(_i) * TAU / 6.0
		var _lx  := cos(_la) * 20.0
		var _ly  := sin(_la) * 9.0 - 28.0 + b
		var _lpa := 0.42 + pulse * 0.20
		draw_circle(Vector2(_lx, _ly), 3.5, Color(emrld_l.r, emrld_l.g, emrld_l.b, _lpa))
		draw_circle(Vector2(_lx, _ly), 2.0, Color(1, 1, 1, _lpa * 0.65))

	# Nature spirits orbiting (3 inner)
	for _i in range(3):
		var _sa  := spr_t + float(_i) * TAU / 3.0
		var _sx  := cos(_sa) * 26.0
		var _sy  := sin(_sa) * 11.0 - 10.0 + b
		var _spa := 0.38 + pulse * 0.16
		draw_circle(Vector2(_sx, _sy), 4.5, Color(spirit.r, spirit.g, spirit.b, _spa * 0.40))
		draw_circle(Vector2(_sx, _sy), 3.0, Color(spirit.r, spirit.g, spirit.b, _spa))
		draw_circle(Vector2(_sx, _sy), 1.5, Color(1, 1, 1, _spa + 0.10))

	# Sacred nature aura
	var aa := 0.14 + pulse * 0.06
	draw_arc(Vector2(0, -12 + b), 32, 0, TAU, 36, Color(emrld_l.r, emrld_l.g, emrld_l.b, aa), 4.0)

	if s:
		for _i in range(8):
			var _ang := float(_i) * TAU / 8.0 + _anim_time
			var _lp  := Vector2(cos(_ang), sin(_ang)) * 28.0 + Vector2(0, -22 + b)
			draw_circle(_lp, 5.0, Color(emrld_l.r, emrld_l.g, emrld_l.b, 0.72))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_void_titan(b: float, s: bool) -> void:
	var void2  := Color(0.14, 0.06, 0.28)
	var void_l := Color(0.28, 0.14, 0.52)
	var dark   := Color(0.06, 0.02, 0.12)
	var purp   := Color(0.50, 0.25, 0.90)
	var purp_l := Color(0.72, 0.50, 1.00)
	var vblue  := Color(0.22, 0.40, 1.00)
	var crys   := Color(0.72, 0.45, 1.00)
	var crys_l := Color(0.90, 0.72, 1.00)

	var pulse  := sin(_anim_time * 3.0)
	var orb_t  := _anim_time * 1.4
	var va     := 0.65 + pulse * 0.30

	draw_circle(Vector2(0, 24), 18, Color(0, 0, 0, 0.28))

	# Massive armored boots
	draw_colored_polygon(PackedVector2Array([
		Vector2(-15, 12 + b), Vector2(-3, 12 + b),
		Vector2(-4, 22 + b),  Vector2(-16, 22 + b)
	]), dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(3, 12 + b),  Vector2(15, 12 + b),
		Vector2(16, 22 + b), Vector2(4, 22 + b)
	]), dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-15, 12 + b), Vector2(-3, 12 + b),
		Vector2(-3, 14 + b),  Vector2(-15, 14 + b)
	]), void_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(3, 12 + b),  Vector2(15, 12 + b),
		Vector2(15, 14 + b), Vector2(3, 14 + b)
	]), void_l)

	# Heavy armored legs
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, 4 + b), Vector2(-3, 4 + b),
		Vector2(-3, 12 + b), Vector2(-14, 12 + b)
	]), void2)
	draw_colored_polygon(PackedVector2Array([
		Vector2(3, 4 + b),   Vector2(14, 4 + b),
		Vector2(14, 12 + b), Vector2(3, 12 + b)
	]), void2)
	draw_line(Vector2(-13, 6 + b), Vector2(-4, 6 + b), Color(purp.r, purp.g, purp.b, 0.45), 0.9)
	draw_line(Vector2( 4, 6 + b),  Vector2(13, 6 + b), Color(purp.r, purp.g, purp.b, 0.45), 0.9)

	# Massive torso (wide, imposing)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-17, -10 + b), Vector2(17, -10 + b),
		Vector2(15, 4 + b),    Vector2(-15, 4 + b)
	]), void2)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-17, -10 + b), Vector2(17, -10 + b),
		Vector2(14, -8 + b),   Vector2(-14, -8 + b)
	]), void_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(12, -10 + b), Vector2(17, -10 + b),
		Vector2(15, 4 + b),   Vector2(11, 4 + b)
	]), dark)
	# Void energy lines on torso
	draw_line(Vector2(-12, -8 + b), Vector2(-6, -2 + b), Color(vblue.r, vblue.g, vblue.b, 0.55), 1.0)
	draw_line(Vector2(-6, -2 + b),  Vector2(-8, 2 + b),  Color(vblue.r, vblue.g, vblue.b, 0.42), 0.9)
	draw_line(Vector2(5, -7 + b),   Vector2(9, -1 + b),  Color(vblue.r, vblue.g, vblue.b, 0.50), 1.0)

	# Giant void crystal in chest (diamond)
	var vc_s := 8.0 + pulse * 1.2
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -5 - vc_s * 0.6 + b), Vector2(-vc_s * 0.5, -3 + b),
		Vector2(0, -3 + vc_s * 0.6 + b), Vector2(vc_s * 0.5, -3 + b)
	]), crys)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -5 - vc_s * 0.6 + b), Vector2(-vc_s * 0.5, -3 + b),
		Vector2(0, -3 + vc_s * 0.5 + b), Vector2(vc_s * 0.45, -3 + b)
	]), Color(purp_l.r, purp_l.g, purp_l.b, 0.75))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2, -5 - vc_s * 0.3 + b), Vector2(-vc_s * 0.2, -3 + b),
		Vector2(-2, -3 + vc_s * 0.3 + b), Vector2(vc_s * 0.15, -3 + b)
	]), Color(crys_l.r, crys_l.g, crys_l.b, 0.70))
	draw_circle(Vector2(-1, -3 + b), 2.5, Color(1, 1, 1, 0.82))
	# Crystal glow aura
	draw_circle(Vector2(0, -3 + b), vc_s + 4.0, Color(crys.r, crys.g, crys.b, 0.16 + pulse * 0.08))

	# Massive spike shoulder armor — left
	draw_colored_polygon(PackedVector2Array([
		Vector2(-17, -10 + b), Vector2(-26, -6 + b),
		Vector2(-28, 2 + b),   Vector2(-24, 6 + b),
		Vector2(-17, 4 + b)
	]), void2)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-17, -10 + b), Vector2(-26, -6 + b),
		Vector2(-23, -5 + b),  Vector2(-17, -8 + b)
	]), void_l)
	draw_line(Vector2(-26, -6 + b), Vector2(-28, 2 + b), Color(purp.r, purp.g, purp.b, 0.52), 1.2)
	# Void spikes on shoulder
	draw_colored_polygon(PackedVector2Array([
		Vector2(-22, -10 + b), Vector2(-18, -10 + b), Vector2(-20, -18 + b)
	]), purp_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-27, -6 + b),  Vector2(-24, -8 + b),  Vector2(-28, -14 + b)
	]), purp_l)
	draw_circle(Vector2(-24, -5 + b), 3.0, Color(vblue.r, vblue.g, vblue.b, 0.62))

	# Massive spike shoulder armor — right
	draw_colored_polygon(PackedVector2Array([
		Vector2(17, -10 + b), Vector2(26, -6 + b),
		Vector2(28, 2 + b),   Vector2(24, 6 + b),
		Vector2(17, 4 + b)
	]), void2)
	draw_colored_polygon(PackedVector2Array([
		Vector2(17, -10 + b), Vector2(26, -6 + b),
		Vector2(23, -5 + b),  Vector2(17, -8 + b)
	]), void_l)
	draw_line(Vector2(26, -6 + b), Vector2(28, 2 + b), Color(purp.r, purp.g, purp.b, 0.52), 1.2)
	draw_colored_polygon(PackedVector2Array([
		Vector2(18, -10 + b), Vector2(22, -10 + b), Vector2(20, -18 + b)
	]), purp_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(24, -8 + b),  Vector2(27, -6 + b),  Vector2(28, -14 + b)
	]), purp_l)
	draw_circle(Vector2(24, -5 + b), 3.0, Color(vblue.r, vblue.g, vblue.b, 0.62))

	# Massive head
	draw_circle(Vector2(0, -22 + b), 12, dark)
	draw_circle(Vector2(0, -23 + b), 11, void2)
	draw_circle(Vector2(0, -24 + b), 9.5, void_l)
	# Face plate
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -24 + b), Vector2(11, -24 + b),
		Vector2(10, -14 + b),  Vector2(-10, -14 + b)
	]), void2.lightened(0.08))
	draw_colored_polygon(PackedVector2Array([
		Vector2(7, -24 + b), Vector2(11, -24 + b),
		Vector2(10, -14 + b), Vector2(6, -14 + b)
	]), dark)
	# Wide visor glow
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9, -24 + b), Vector2(9, -24 + b),
		Vector2(7, -19 + b),  Vector2(-7, -19 + b)
	]), Color(crys.r, crys.g, crys.b, va))
	draw_line(Vector2(-9, -24 + b), Vector2(9, -24 + b), Color(crys_l.r, crys_l.g, crys_l.b, va * 0.70), 0.9)
	# Helmet crown + void spines
	draw_rect(Rect2(-11, -31 + b, 22, 5), void2)
	draw_rect(Rect2(-11, -31 + b, 22, 2), void_l)
	for _i in range(3):
		var _sx := float(_i - 1) * 7.0
		var _sh := 8.0 if abs(float(_i) - 1) < 0.5 else 5.5
		draw_colored_polygon(PackedVector2Array([
			Vector2(_sx - 2, -31 + b), Vector2(_sx + 2, -31 + b),
			Vector2(_sx, -31 - _sh + b)
		]), purp_l)
		draw_circle(Vector2(_sx, -31 - _sh + b), 2.0, Color(crys_l.r, crys_l.g, crys_l.b, 0.88))

	# Floating gravity shards (6 orbiting)
	for _i in range(6):
		var _oa := orb_t + float(_i) * TAU / 6.0
		var _ox := cos(_oa) * 22.0
		var _oy := sin(_oa) * 10.0 - 6.0 + b
		var _oa2 := 0.48 + pulse * 0.20
		# Rock shard shape
		draw_colored_polygon(PackedVector2Array([
			Vector2(_ox - 3, _oy - 2), Vector2(_ox + 2, _oy - 3),
			Vector2(_ox + 3, _oy + 2), Vector2(_ox - 2, _oy + 3)
		]), Color(void_l.r, void_l.g, void_l.b, _oa2))
		draw_circle(Vector2(_ox, _oy), 2.0, Color(purp.r, purp.g, purp.b, _oa2 * 0.70))
		draw_circle(Vector2(_ox, _oy), 1.0, Color(crys.r, crys.g, crys.b, _oa2))

	# Reality distortion rings (outer halo)
	var rda := 0.12 + pulse * 0.05
	draw_arc(Vector2(0, -6 + b), 32, 0, TAU, 36, Color(purp.r, purp.g, purp.b, rda), 3.5)
	draw_arc(Vector2(0, -6 + b), 36, 0, TAU, 40, Color(vblue.r, vblue.g, vblue.b, rda * 0.65), 2.0)

	if s:
		var _ba := 0.50 + sin(_anim_time * 6.0) * 0.45
		draw_arc(Vector2(0, -6 + b), 38, 0, TAU, 44, Color(crys.r, crys.g, crys.b, _ba * 0.35), 4.0)
		draw_circle(Vector2(0, -3 + b), vc_s + 12, Color(purp.r, purp.g, purp.b, _ba * 0.22))


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


# ── Dragon Sovereign (type 50) ────────────────────────────────────────────
# Dragon champion — crimson scale armor, curved horns, folded wings,
# massive dragon blade, orbiting fire scales, ember particles.

func _draw_hero_dragon_sovereign(bob: float, shooting: bool) -> void:
	var b      := bob
	var crim   := Color(0.82, 0.12, 0.08)
	var crim_d := Color(0.42, 0.05, 0.03)
	var crim_l := Color(0.96, 0.38, 0.18)
	var gold   := Color(0.92, 0.68, 0.08)
	var gold_l := Color(1.00, 0.88, 0.45)
	var fire   := Color(0.98, 0.52, 0.05)
	var coal   := Color(0.10, 0.05, 0.02)
	var s      := shooting

	draw_circle(Vector2(0, 24), 15, Color(0, 0, 0, 0.26))

	# ── Orbiting dragon scales ────────────────────────────────────────────
	for _di in range(6):
		var _da  := _anim_time * 0.72 + _di * (TAU / 6.0)
		var _dr  := 30.0 + sin(_anim_time * 1.1 + float(_di)) * 4.0
		var _dx  := cos(_da) * _dr
		var _dy  := 0.0 + b + sin(_da * 0.55) * 14.0
		var _da2 := 0.55 + sin(_anim_time * 1.6 + float(_di)) * 0.14
		draw_colored_polygon(PackedVector2Array([
			Vector2(_dx,       _dy - 5.0),
			Vector2(_dx + 3.5, _dy - 1.0),
			Vector2(_dx + 2.5, _dy + 4.0),
			Vector2(_dx - 2.5, _dy + 4.0),
			Vector2(_dx - 3.5, _dy - 1.0)
		]), Color(crim.r, crim.g, crim.b, _da2))
		draw_circle(Vector2(_dx, _dy - 3.0), 1.5, Color(fire.r, fire.g, fire.b, _da2 * 0.65))
	for _ei in range(5):
		var _ea  := _anim_time * 2.3 + _ei * (TAU / 5.0)
		var _er  := 20.0 + sin(_anim_time * 2.8 + float(_ei)) * 5.0
		var _ea2 := 0.40 + sin(_anim_time * 4.0 + float(_ei)) * 0.18
		draw_circle(Vector2(cos(_ea) * _er, -4.0 + b + sin(_ea * 0.6) * 11.0),
			2.0, Color(fire.r, fire.g, fire.b, _ea2))

	# ── Folded dragon wings (behind torso) ────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -4 + b), Vector2(-12, 14 + b),
		Vector2(-30, 20 + b), Vector2(-36,  8 + b),
		Vector2(-28, -4 + b), Vector2(-18, -14 + b)
	]), coal)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, 0 + b), Vector2(-12, 12 + b),
		Vector2(-24, 15 + b), Vector2(-26, 6 + b), Vector2(-20, -4 + b)
	]), crim_d)
	draw_line(Vector2(-12, 4 + b), Vector2(-36, 10 + b), coal.lightened(0.18), 1.5)
	draw_colored_polygon(PackedVector2Array([
		Vector2(12, -4 + b), Vector2(12, 14 + b),
		Vector2(30, 20 + b), Vector2(36,  8 + b),
		Vector2(28, -4 + b), Vector2(18, -14 + b)
	]), coal)
	draw_colored_polygon(PackedVector2Array([
		Vector2(12, 0 + b), Vector2(12, 12 + b),
		Vector2(24, 15 + b), Vector2(26, 6 + b), Vector2(20, -4 + b)
	]), crim_d)
	draw_line(Vector2(12, 4 + b), Vector2(36, 10 + b), coal.lightened(0.18), 1.5)

	# ── Dragon-scale greaves ──────────────────────────────────────────────
	draw_rect(Rect2(-11, 12 + b, 10, 12), crim_d)
	draw_rect(Rect2(  1, 12 + b, 10, 12), crim_d)
	for _gsi in range(3):
		draw_arc(Vector2(-6, 14 + _gsi * 4 + b), 5, 0, PI, 6, crim, 1.5)
		draw_arc(Vector2( 6, 14 + _gsi * 4 + b), 5, 0, PI, 6, crim, 1.5)
	draw_line(Vector2(-11, 12 + b), Vector2(-1, 12 + b), gold, 1.5)
	draw_line(Vector2(  1, 12 + b), Vector2(11, 12 + b), gold, 1.5)

	# ── Dragon-scale breastplate ──────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -12 + b), Vector2(13, -12 + b),
		Vector2( 11,  14 + b), Vector2(-11, 14 + b)
	]), crim)
	for _ri in range(3):
		for _ci in range(3):
			draw_arc(Vector2(-8.0 + _ci * 8.0, -10.0 + _ri * 8.0 + b), 5, 0, PI, 6, crim_d, 1.5)
	draw_line(Vector2(0, -12 + b), Vector2(0, 14 + b), gold, 2.0)
	draw_circle(Vector2(0, -2 + b), 4.5, crim_d)
	draw_circle(Vector2(0, -2 + b), 3.0, fire)
	draw_circle(Vector2(0, -2 + b), 1.5, gold_l)
	draw_line(Vector2(-13, -12 + b), Vector2(13, -12 + b), gold, 2.5)
	draw_rect(Rect2(-12, 11 + b, 24, 4), crim_d)
	draw_line(Vector2(-12, 11 + b), Vector2(12, 11 + b), gold, 1.5)

	# ── Dragon pauldrons with forward spike ───────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -12 + b), Vector2(-8, -12 + b),
		Vector2(-8,  -2  + b), Vector2(-20, -2 + b), Vector2(-20, -8 + b)
	]), crim)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -12 + b), Vector2(-10, -12 + b), Vector2(-8, -22 + b)
	]), crim_l)
	draw_line(Vector2(-20, -8 + b), Vector2(-8, -12 + b), gold, 1.5)
	draw_colored_polygon(PackedVector2Array([
		Vector2( 8, -12 + b), Vector2(14, -12 + b),
		Vector2(20, -8  + b), Vector2(20, -2  + b), Vector2(8, -2 + b)
	]), crim)
	draw_colored_polygon(PackedVector2Array([
		Vector2(8, -12 + b), Vector2(14, -12 + b), Vector2(12, -22 + b)
	]), crim_l)
	draw_line(Vector2(8, -12 + b), Vector2(20, -8 + b), gold, 1.5)
	draw_rect(Rect2(-22, -8 + b, 10, 6), crim_d)
	draw_rect(Rect2( 12, -8 + b, 10, 6), crim_d)

	# ── Dragon helmet + curved horns ──────────────────────────────────────
	draw_circle(Vector2(0, -20 + b), 11, crim)
	draw_circle(Vector2(0, -20 + b), 11, crim_d, false, 2.5)
	draw_rect(Rect2(-9, -24 + b, 18, 5), crim_d)
	draw_rect(Rect2(-5, -23 + b, 10, 3), Color(0.06, 0.02, 0.01))
	draw_circle(Vector2(-3, -22 + b), 1.8, fire)
	draw_circle(Vector2( 3, -22 + b), 1.8, fire)
	if s:
		draw_circle(Vector2(-3, -22 + b), 4.5, Color(fire.r, fire.g, fire.b, 0.60))
		draw_circle(Vector2( 3, -22 + b), 4.5, Color(fire.r, fire.g, fire.b, 0.60))
	draw_line(Vector2(-9, -24 + b), Vector2(9, -24 + b), gold, 2.0)
	draw_line(Vector2(-9, -19 + b), Vector2(9, -19 + b), gold, 1.5)
	draw_rect(Rect2(-8, -30 + b, 16, 6), crim_d)
	draw_line(Vector2(-8, -30 + b), Vector2(8, -30 + b), gold_l, 2.0)
	draw_arc(Vector2(-8, -33 + b), 9, PI * 1.05, PI * 1.80, 10, coal, 5.0)
	draw_arc(Vector2(-8, -33 + b), 9, PI * 1.05, PI * 1.80, 10, crim_l, 1.5)
	draw_arc(Vector2( 8, -33 + b), 9, PI * 1.20, PI * 1.95, 10, coal, 5.0)
	draw_arc(Vector2( 8, -33 + b), 9, PI * 1.20, PI * 1.95, 10, crim_l, 1.5)

	# ── Massive dragon blade ──────────────────────────────────────────────
	if s:
		var sw   := _shoot_anim / 0.35
		var _ang := -PI * 0.35 + sw * PI * 0.85
		var _hx  := 14.0 + cos(_ang) * 36
		var _hy  := -4.0 + b + sin(_ang) * 36
		draw_line(Vector2(14, -4 + b), Vector2(_hx, _hy), Color(fire.r, fire.g, fire.b, 0.35), 16.0)
		draw_line(Vector2(14, -4 + b), Vector2(_hx, _hy), crim_d, 10.0)
		draw_line(Vector2(14, -4 + b), Vector2(_hx, _hy), crim,    7.0)
		draw_line(Vector2(14, -4 + b), Vector2(_hx, _hy), gold_l,  2.0)
		if sw > 0.25:
			draw_arc(Vector2(14, -4 + b), 36, _ang - 0.70, _ang, 10,
				Color(fire.r, fire.g, fire.b, sw * 0.68), 8.0)
	else:
		draw_line(Vector2(14, -2 + b), Vector2(18, -50 + b), crim_d, 10.0)
		draw_line(Vector2(14, -2 + b), Vector2(18, -50 + b), crim,    7.0)
		draw_line(Vector2(14, -2 + b), Vector2(18, -50 + b), gold_l,  2.0)
		draw_line(Vector2(15, -8 + b), Vector2(17, -44 + b), Color(gold.r, gold.g, gold.b, 0.50), 1.5)
		draw_colored_polygon(PackedVector2Array([
			Vector2( 5, -4 + b), Vector2(25, -4 + b),
			Vector2(27, -9 + b), Vector2( 3, -9 + b)
		]), gold)
		draw_circle(Vector2(13, 4 + b), 4.5, crim_d)
		draw_circle(Vector2(13, 4 + b), 3.0, fire)
		draw_circle(Vector2(13, 4 + b), 1.5, gold_l)



# ── Shadow Blade (type 51) ──────────────────────────────────────────
# Master assassin — absolute black armor, deep crimson cloth, twin rune-etched
# daggers, orbiting shadow blades, red void eyes, crimson wisps, smoke at feet.

func _draw_hero_dagger(bob: float, shooting: bool) -> void:
	var b      := bob
	var blk    := Color(0.05, 0.03, 0.08)   # near-black armor
	var blk_l  := Color(0.15, 0.09, 0.20)   # dark armor highlight
	var crim   := Color(0.68, 0.05, 0.09)   # dark crimson cloth
	var crim_l := Color(0.90, 0.12, 0.16)   # bright crimson glow
	var silver := Color(0.80, 0.82, 0.88)   # blade silver
	var silv_l := Color(0.95, 0.96, 1.00)   # blade highlight
	var red_e  := Color(0.90, 0.08, 0.12)   # void eye / rune red
	var rune_c := Color(0.88, 0.22, 0.26)   # rune etch glow
	var s      := shooting
	var blade_l := Color(0.92, 0.10, 0.14) if _hit_counter >= 1 else silver
	var blade_r := Color(0.92, 0.10, 0.14) if _hit_counter >= 2 else silver

	# Drop shadow (wide — imposing)
	draw_circle(Vector2(0, 24), 14, Color(0, 0, 0, 0.30))

	# ── Shadow smoke drifting from feet ────────────────────────────────
	for _si in range(5):
		var _sa := _anim_time * 0.55 + _si * (TAU / 5.0)
		var _sx := cos(_sa) * (9.0 + sin(_anim_time * 1.3 + float(_si)) * 4.0)
		var _sy := 17.0 + b + sin(_sa * 0.65) * 4.5
		var _sr := 4.5 + sin(_anim_time * 1.9 + float(_si)) * 1.8
		draw_circle(Vector2(_sx, _sy), _sr, Color(0.08, 0.00, 0.14, 0.26))

	# ── Red shadow wisps (inner orbit) ───────────────────────────────
	for _wi in range(5):
		var _wa := _anim_time * 1.90 + _wi * (TAU / 5.0)
		var _wr := 17.0 + sin(_anim_time * 2.5 + float(_wi)) * 3.5
		var _wx := cos(_wa) * _wr
		var _wy := 1.0 + b + sin(_wa * 0.60) * 13.0
		var _walpha := 0.18 + sin(_anim_time * 3.2 + float(_wi)) * 0.07
		draw_circle(Vector2(_wx, _wy), 2.5,
			Color(red_e.r, red_e.g, red_e.b, _walpha))

	# ── Orbiting shadow daggers (outer ring) ────────────────────────
	for _di in range(2):
		var _da    := _anim_time * 1.05 + _di * PI
		var _dr    := 29.0 + sin(_anim_time * 0.85 + float(_di)) * 3.0
		var _dx    := cos(_da) * _dr
		var _dy    := -2.0 + b + sin(_da * 0.50) * 15.0
		var _dalpha := 0.62 + sin(_anim_time * 1.7 + float(_di)) * 0.14
		var _ddir  := Vector2(-sin(_da), cos(_da) * 0.55).normalized()
		var _dperp := Vector2(-_ddir.y, _ddir.x)
		# Blade (shadow dagger)
		draw_line(Vector2(_dx, _dy) - _ddir * 10.0,
				  Vector2(_dx, _dy) + _ddir * 10.0,
				  Color(silver.r, silver.g, silver.b, _dalpha), 2.5)
		draw_line(Vector2(_dx, _dy) - _ddir * 10.0,
				  Vector2(_dx, _dy) + _ddir * 10.0,
				  Color(silv_l.r, silv_l.g, silv_l.b, _dalpha * 0.45), 1.0)
		# Blade tip
		draw_colored_polygon(PackedVector2Array([
			Vector2(_dx, _dy) + _ddir * 10.0,
			Vector2(_dx, _dy) + _ddir * 6.0 + _dperp * 2.5,
			Vector2(_dx, _dy) + _ddir * 6.0 - _dperp * 2.5
		]), Color(silver.r, silver.g, silver.b, _dalpha))
		# Rune glow on blade center
		draw_circle(Vector2(_dx, _dy), 2.5,
			Color(rune_c.r, rune_c.g, rune_c.b, _dalpha * 0.72))
		draw_circle(Vector2(_dx, _dy), 5.0,
			Color(rune_c.r, rune_c.g, rune_c.b, _dalpha * 0.20))
		# Crossguard bar
		draw_line(Vector2(_dx, _dy) + _ddir * 3.5 + _dperp * 4.0,
				  Vector2(_dx, _dy) + _ddir * 3.5 - _dperp * 4.0,
				  Color(crim.r, crim.g, crim.b, _dalpha * 0.85), 2.0)

	# ── Legs (lightweight black greaves) ─────────────────────────────
	draw_rect(Rect2(-9, 13 + b, 8, 11), blk)
	draw_rect(Rect2( 1, 13 + b, 8, 11), blk)
	draw_line(Vector2(-7, 14 + b), Vector2(-7, 22 + b), blk_l, 1.5)
	draw_line(Vector2( 5, 14 + b), Vector2( 5, 22 + b), blk_l, 1.5)
	# Crimson boot-trim
	draw_line(Vector2(-9, 21 + b), Vector2(-1, 21 + b), crim, 2.0)
	draw_line(Vector2( 1, 21 + b), Vector2( 9, 21 + b), crim, 2.0)

	# ── Shadow cloak / torso ────────────────────────────────────────
	# Cloak body (wide, angular, near-black)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -10 + b), Vector2(13, -10 + b),
		Vector2( 16,  24 + b), Vector2(-16, 24 + b)
	]), blk)
	# Cloak inner shadow panel
	draw_colored_polygon(PackedVector2Array([
		Vector2( 4, -10 + b), Vector2(13, -10 + b),
		Vector2(16,  24 + b), Vector2( 7,  24 + b)
	]), Color(0.02, 0.01, 0.04))
	# Crimson edge trim lines
	draw_line(Vector2(-13, -10 + b), Vector2(-16, 24 + b), crim, 2.0)
	draw_line(Vector2( 13, -10 + b), Vector2( 16, 24 + b), crim, 2.0)
	# Center crimson sash
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3, -2 + b), Vector2(3, -2 + b),
		Vector2(4,  12 + b), Vector2(-4, 12 + b)
	]), crim)
	draw_line(Vector2(-3, -2 + b), Vector2(3, -2 + b), crim_l, 1.0)

	# Chest plate (form-fitting, tight)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -10 + b), Vector2(11, -10 + b),
		Vector2( 10,   2 + b), Vector2(-10,  2 + b)
	]), blk)
	draw_line(Vector2(-11, -10 + b), Vector2(11, -10 + b), blk_l, 1.5)
	# Crimson chest rune (V-mark)
	draw_line(Vector2(-5, -8 + b), Vector2(0, -3 + b), crim_l, 1.5)
	draw_line(Vector2( 5, -8 + b), Vector2(0, -3 + b), crim_l, 1.5)
	draw_circle(Vector2(0, -3 + b), 1.5, Color(red_e.r, red_e.g, red_e.b, 0.70))

	# Sharp angular pauldrons
	draw_colored_polygon(PackedVector2Array([
		Vector2(-19,  -9 + b), Vector2(-10,  -9 + b),
		Vector2( -9,  -1 + b), Vector2(-20,  -1 + b)
	]), blk)
	draw_line(Vector2(-19, -9 + b), Vector2(-10, -9 + b), crim, 1.5)
	draw_colored_polygon(PackedVector2Array([
		Vector2(10, -9 + b), Vector2(19, -9 + b),
		Vector2(20, -1 + b), Vector2( 9, -1 + b)
	]), blk)
	draw_line(Vector2(10, -9 + b), Vector2(19, -9 + b), crim, 1.5)

	# Crimson sash belt + dagger sheaths
	draw_rect(Rect2(-12, 2 + b, 24, 4), crim)
	draw_rect(Rect2(-12, 2 + b, 24, 1), crim_l)
	draw_rect(Rect2(-6,  3 + b,  4, 7), blk)
	draw_rect(Rect2( 2,  3 + b,  4, 7), blk)
	draw_line(Vector2(-6, 9 + b), Vector2(-2, 9 + b), silver, 1.0)
	draw_line(Vector2( 2, 9 + b), Vector2( 6, 9 + b), silver, 1.0)

	# Arms (tight gauntlets with crimson edge)
	draw_rect(Rect2(-21, -6 + b, 9, 5), blk)
	draw_rect(Rect2( 12, -6 + b, 9, 5), blk)
	draw_line(Vector2(-21, -6 + b), Vector2(-12, -6 + b), crim, 1.5)
	draw_line(Vector2( 12, -6 + b), Vector2( 21, -6 + b), crim, 1.5)

	# ── Face — void black with glowing red eyes ─────────────────────────
	draw_circle(Vector2(0, -18 + b), 7, blk)
	draw_circle(Vector2(-3, -19 + b), 2.0, red_e)
	draw_circle(Vector2( 3, -19 + b), 2.0, red_e)
	draw_circle(Vector2(-3, -19 + b), 3.5, Color(red_e.r, red_e.g, red_e.b, 0.35))
	draw_circle(Vector2( 3, -19 + b), 3.5, Color(red_e.r, red_e.g, red_e.b, 0.35))
	if s:
		draw_circle(Vector2(-3, -19 + b), 5.5, Color(red_e.r, red_e.g, red_e.b, 0.62))
		draw_circle(Vector2( 3, -19 + b), 5.5, Color(red_e.r, red_e.g, red_e.b, 0.62))

	# ── Deep angular hood ──────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -13 + b), Vector2(14, -13 + b),
		Vector2( 11, -24 + b), Vector2(-11, -24 + b)
	]), blk)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9, -24 + b), Vector2(9, -24 + b),
		Vector2( 6, -36 + b), Vector2(-6, -36 + b)
	]), blk)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4, -36 + b), Vector2(4, -36 + b),
		Vector2( 1, -44 + b), Vector2(-1, -44 + b)
	]), blk)
	# Crimson glow arc at hood opening
	draw_arc(Vector2(0, -25 + b), 11, -PI * 0.80, PI * 0.80, 14, crim, 2.0)
	draw_arc(Vector2(0, -25 + b), 11, -PI * 0.80, PI * 0.80, 14,
		Color(crim.r, crim.g, crim.b, 0.28), 5.5)
	# Hood tip rune glow
	draw_circle(Vector2(0, -43 + b), 2.0, Color(red_e.r, red_e.g, red_e.b, 0.55))
	draw_circle(Vector2(0, -43 + b), 4.5, Color(red_e.r, red_e.g, red_e.b, 0.18))

	# ── Twin held daggers ────────────────────────────────────────────
	var r_swing := s and (not _alt_hand or _dual_swing)
	var l_swing := s and (_alt_hand or _dual_swing)

	# ─ Right dagger ─
	if r_swing:
		var sw    := _shoot_anim / 0.35
		var tip_r := Vector2(17 + sw * 18, -20 + b - sw * 22)
		var base  := Vector2(13, -2 + b)
		# Shadow afterimage (offset, fading trail)
		draw_line(base, tip_r + Vector2(4, 4),
			Color(red_e.r, red_e.g, red_e.b, sw * 0.30), 3.0)
		# Blade
		draw_line(base, tip_r, blade_r, 4.0)
		draw_line(base, tip_r,
			Color(silv_l.r, silv_l.g, silv_l.b, 0.55), 1.5)
		# Rune glow at blade midpoint
		var rmid := base.lerp(tip_r, 0.50)
		draw_circle(rmid, 3.0, Color(rune_c.r, rune_c.g, rune_c.b, sw * 0.85))
		draw_circle(rmid, 5.5, Color(rune_c.r, rune_c.g, rune_c.b, sw * 0.25))
		# Crossguard
		draw_rect(Rect2(8, -4 + b, 11, 2), crim)
		# Slash arc trail
		draw_arc(Vector2(11, -5 + b), 17, -PI * 0.55, PI * 0.05, 10,
			Color(crim_l.r, crim_l.g, crim_l.b, sw * 0.80), 5.0)
	else:
		# At rest — blade angled up-right, runes visible
		draw_line(Vector2(14, 8 + b), Vector2(20, -16 + b), blade_r, 4.0)
		draw_line(Vector2(14, 8 + b), Vector2(20, -16 + b),
			Color(silv_l.r, silv_l.g, silv_l.b, 0.30), 1.2)
		# Rune etchings (3 glowing marks)
		for _ri in range(3):
			var _ry := -2 + _ri * -6
			draw_line(Vector2(15, _ry + b), Vector2(19, _ry + b),
				Color(rune_c.r, rune_c.g, rune_c.b, 0.78), 1.2)
		# Crossguard
		draw_rect(Rect2(9, 6 + b, 11, 2), crim)
		# Grip
		draw_rect(Rect2(11, 7 + b, 7, 4), blk_l)

	# ─ Left dagger ─
	if l_swing:
		var sw    := _shoot_anim / 0.35
		var tip_l := Vector2(-17 - sw * 18, -20 + b - sw * 22)
		var base  := Vector2(-13, -2 + b)
		# Shadow afterimage
		draw_line(base, tip_l + Vector2(-4, 4),
			Color(red_e.r, red_e.g, red_e.b, sw * 0.30), 3.0)
		# Blade
		draw_line(base, tip_l, blade_l, 4.0)
		draw_line(base, tip_l,
			Color(silv_l.r, silv_l.g, silv_l.b, 0.55), 1.5)
		var lmid := base.lerp(tip_l, 0.50)
		draw_circle(lmid, 3.0, Color(rune_c.r, rune_c.g, rune_c.b, sw * 0.85))
		draw_circle(lmid, 5.5, Color(rune_c.r, rune_c.g, rune_c.b, sw * 0.25))
		draw_rect(Rect2(-19, -4 + b, 11, 2), crim)
		draw_arc(Vector2(-11, -5 + b), 17, PI * 0.95, PI * 1.55, 10,
			Color(crim_l.r, crim_l.g, crim_l.b, sw * 0.80), 5.0)
	else:
		# At rest — mirrored
		draw_line(Vector2(-14, 8 + b), Vector2(-20, -16 + b), blade_l, 4.0)
		draw_line(Vector2(-14, 8 + b), Vector2(-20, -16 + b),
			Color(silv_l.r, silv_l.g, silv_l.b, 0.30), 1.2)
		for _ri in range(3):
			var _ry := -2 + _ri * -6
			draw_line(Vector2(-16, _ry + b), Vector2(-20, _ry + b),
				Color(rune_c.r, rune_c.g, rune_c.b, 0.78), 1.2)
		draw_rect(Rect2(-20, 6 + b, 11, 2), crim)
		draw_rect(Rect2(-18, 7 + b, 7, 4), blk_l)

	# ── Attack flash — red pulse at moment of strike ────────────────────
	if s:
		var _sf := 1.0 - _shoot_anim / 0.35
		draw_circle(Vector2(0, -4 + b), 22.0,
			Color(red_e.r, red_e.g, red_e.b, _sf * 0.18))


# ── Void Walker (type 52) ─────────────────────────────────────────────────
# Cosmic horror mage — black void cloak, floating mask, pulsing energy core,
# orbiting void orbs and purple cosmic shards, reality-distortion rings.

func _draw_hero_void_walker(bob: float, shooting: bool) -> void:
	var b      := bob
	var tc     := tower_color              # deep purple
	var void_b := Color(0.04, 0.02, 0.08)  # near-black void
	var purp   := Color(0.38, 0.06, 0.68)  # deep purple
	var purp_l := Color(0.62, 0.18, 0.98)  # bright purple
	var mage   := Color(0.68, 0.05, 0.48)  # dark magenta
	var vblue  := Color(0.08, 0.14, 0.60)  # void blue
	var star   := Color(0.92, 0.88, 1.00)  # star white
	var s      := shooting

	draw_circle(Vector2(0, 24), 13, Color(0, 0, 0, 0.32))

	# ── Reality distortion rings ──────────────────────────────────────────
	var _dist_r := 22.0 + sin(_anim_time * 1.8) * 4.0
	draw_circle(Vector2(0, 0 + b), _dist_r, Color(purp.r, purp.g, purp.b, 0.10))
	draw_arc(Vector2(0, 0 + b), _dist_r, 0.0, TAU, 32,
		Color(purp.r, purp.g, purp.b, 0.25), 2.5)

	# ── Orbiting void orbs ────────────────────────────────────────────────
	for _vi in range(5):
		var _va  := _anim_time * 1.05 + _vi * (TAU / 5.0)
		var _vr  := 26.0 + sin(_anim_time * 1.4 + float(_vi)) * 4.0
		var _vx  := cos(_va) * _vr
		var _vy  := 0.0 + b + sin(_va * 0.58) * 14.0
		var _va2 := 0.70 + sin(_anim_time * 2.0 + float(_vi)) * 0.14
		draw_circle(Vector2(_vx, _vy), 4.5, Color(void_b.r, void_b.g, void_b.b, _va2))
		draw_circle(Vector2(_vx, _vy), 4.5, Color(purp.r, purp.g, purp.b, _va2 * 0.80), false, 2.0)
		draw_circle(Vector2(_vx, _vy), 7.0, Color(purp.r, purp.g, purp.b, _va2 * 0.18))

	# ── Orbiting cosmic fragments ─────────────────────────────────────────
	for _fi in range(4):
		var _fa  := _anim_time * 1.60 + _fi * (TAU / 4.0)
		var _fr  := 18.0 + sin(_anim_time * 2.2 + float(_fi)) * 3.0
		var _fx  := cos(_fa) * _fr
		var _fy  := -2.0 + b + sin(_fa * 0.52) * 12.0
		var _fa2 := 0.60 + sin(_anim_time * 3.0 + float(_fi)) * 0.18
		draw_colored_polygon(PackedVector2Array([
			Vector2(_fx,       _fy - 6.0),
			Vector2(_fx + 3.0, _fy + 0.0),
			Vector2(_fx,       _fy + 5.0),
			Vector2(_fx - 3.0, _fy + 0.0)
		]), Color(purp_l.r, purp_l.g, purp_l.b, _fa2))
		draw_circle(Vector2(_fx, _fy), 2.0, Color(mage.r, mage.g, mage.b, _fa2 * 0.55))

	# ── Void cloak (flowing, wide) ────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -10 + b), Vector2(14, -10 + b),
		Vector2( 18,  24 + b), Vector2(-18, 24 + b)
	]), void_b)
	# Shadow inner panel
	draw_colored_polygon(PackedVector2Array([
		Vector2( 3, -10 + b), Vector2(14, -10 + b),
		Vector2(18,  24 + b), Vector2( 8,  24 + b)
	]), Color(0.02, 0.01, 0.05))
	# Void edge glow (tendrils)
	draw_line(Vector2(-14, -10 + b), Vector2(-18, 24 + b), Color(purp.r, purp.g, purp.b, 0.50), 1.5)
	draw_line(Vector2( 14, -10 + b), Vector2( 18, 24 + b), Color(purp.r, purp.g, purp.b, 0.50), 1.5)
	# Cloak hem energy pulses
	var _hem_p := 0.5 + sin(_anim_time * 3.0) * 0.3
	draw_line(Vector2(-18, 20 + b), Vector2(18, 20 + b),
		Color(purp.r, purp.g, purp.b, _hem_p * 0.60), 2.0)
	# Void star dust particles on cloak
	for _si in range(5):
		var _sx := -10.0 + _si * 5.0
		var _sy := -6.0 + sin(_anim_time * 2.0 + _si * 1.3) * 12.0 + b
		draw_circle(Vector2(_sx, _sy), 1.0, Color(star.r, star.g, star.b, 0.40))

	# ── Cosmic energy core (visible through robes) ────────────────────────
	var _core_p := 0.6 + sin(_anim_time * 4.5) * 0.3
	draw_circle(Vector2(0, -2 + b), 9.0, Color(purp.r, purp.g, purp.b, _core_p * 0.20))
	draw_circle(Vector2(0, -2 + b), 5.5, Color(vblue.r, vblue.g, vblue.b, _core_p * 0.65))
	draw_circle(Vector2(0, -2 + b), 3.0, Color(purp_l.r, purp_l.g, purp_l.b, _core_p))
	draw_circle(Vector2(0, -2 + b), 1.5, Color(star.r, star.g, star.b, 0.90))
	# Void sigil ring around core
	for _si2 in range(6):
		var _sang := _anim_time * 1.20 + _si2 * (TAU / 6.0)
		draw_circle(
			Vector2(cos(_sang) * 8.0, -2.0 + b + sin(_sang) * 8.0),
			1.5, Color(purp_l.r, purp_l.g, purp_l.b, 0.55))

	# ── Void pauldrons (angular, floating) ───────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20, -8 + b), Vector2(-10, -8 + b),
		Vector2(-10, -1 + b), Vector2(-22, -1 + b)
	]), void_b)
	draw_line(Vector2(-20, -8 + b), Vector2(-10, -8 + b), Color(purp.r, purp.g, purp.b, 0.80), 2.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(10, -8 + b), Vector2(20, -8 + b),
		Vector2(22, -1 + b), Vector2(10, -1 + b)
	]), void_b)
	draw_line(Vector2(10, -8 + b), Vector2(20, -8 + b), Color(purp.r, purp.g, purp.b, 0.80), 2.0)

	# ── Floating void mask (detached, hovering before face) ───────────────
	var _mby := -24.0 + b + sin(_anim_time * 1.50) * 1.8
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, _mby), Vector2(8, _mby),
		Vector2(9, _mby + 10), Vector2(-9, _mby + 10)
	]), void_b)
	draw_polyline(PackedVector2Array([
		Vector2(-8, _mby), Vector2(8, _mby),
		Vector2(9, _mby + 10), Vector2(-9, _mby + 10), Vector2(-8, _mby)
	]), Color(purp.r, purp.g, purp.b, 0.80), 1.5)
	# Void eye slits on mask
	draw_rect(Rect2(-6, _mby + 3, 4, 2), Color(purp_l.r, purp_l.g, purp_l.b, 0.90))
	draw_rect(Rect2( 2, _mby + 3, 4, 2), Color(purp_l.r, purp_l.g, purp_l.b, 0.90))
	# Mask eye glow
	draw_circle(Vector2(-4, _mby + 4), 3.5, Color(purp_l.r, purp_l.g, purp_l.b, 0.30))
	draw_circle(Vector2( 4, _mby + 4), 3.5, Color(purp_l.r, purp_l.g, purp_l.b, 0.30))
	if s:
		draw_circle(Vector2(-4, _mby + 4), 5.5, Color(mage.r, mage.g, mage.b, 0.65))
		draw_circle(Vector2( 4, _mby + 4), 5.5, Color(mage.r, mage.g, mage.b, 0.65))

	# ── Void staff (left side, energy orb top) ───────────────────────────
	draw_line(Vector2(-18, 22 + b), Vector2(-22, -22 + b), void_b.lightened(0.15), 5.0)
	draw_line(Vector2(-18, 22 + b), Vector2(-22, -22 + b),
		Color(purp.r, purp.g, purp.b, 0.45), 2.0)
	draw_rect(Rect2(-18, -5 + b, 10, 5), void_b.lightened(0.12))  # hand
	var _orb_r := 8.5 if not s else 10.5
	var _opulse := 0.5 + sin(_anim_time * 5.0) * 0.3 if s else 0.7
	draw_circle(Vector2(-22, -30 + b), _orb_r + 8, Color(purp.r, purp.g, purp.b, _opulse * 0.20))
	draw_circle(Vector2(-22, -30 + b), _orb_r,     Color(void_b.r, void_b.g, void_b.b, 0.95))
	draw_circle(Vector2(-22, -30 + b), _orb_r,     Color(purp.r, purp.g, purp.b, 0.80), false, 2.0)
	draw_circle(Vector2(-22, -30 + b), _orb_r * 0.45, Color(purp_l.r, purp_l.g, purp_l.b, _opulse))
	draw_circle(Vector2(-22, -30 + b), _orb_r * 0.20, Color(star.r, star.g, star.b, 0.90))



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



# ── Hero Ranger (type 54) ──────────────────────────────────────────
# Forest ranger — hooded green cloak, longbow always visible, quiver with
# arrows, emerald-glowing bow tips and eyes, feather on hood.

func _draw_hero_ranger(bob: float, shooting: bool) -> void:
	var b        := bob
	var tc       := tower_color              # forest green
	var tc_d     := tc.darkened(0.38)
	var tc_l     := tc.lightened(0.28)
	var leather  := Color(0.52, 0.34, 0.16)
	var leath_d  := Color(0.32, 0.20, 0.08)
	var skin     := Color(0.90, 0.74, 0.58)
	var em       := Color(0.18, 0.90, 0.40)  # emerald glow
	var em_d     := Color(0.08, 0.55, 0.22)
	var arrow_c  := Color(0.72, 0.55, 0.28)
	var s        := shooting

	draw_circle(Vector2(0, 24), 12, Color(0, 0, 0, 0.16))

	# ── Floating Spirit Arrows + Nature Aura ────────────────────────────────
	var _rt := _anim_time
	# 4 spectral arrows slowly orbiting
	for _ai in range(4):
		var _aa := _rt * 0.50 + _ai * (TAU / 4.0)
		var _ar := 26.0 + sin(_rt * 1.5 + float(_ai)) * 3.0
		var _ax := cos(_aa) * _ar
		var _ay := -2.0 + b + sin(_aa * 0.65) * 14.0
		var _aalpha := 0.40 + sin(_rt * 2.0 + float(_ai)) * 0.14
		# Arrow direction tangent to orbit
		var _adir := Vector2(-sin(_aa), cos(_aa) * 0.55).normalized()
		draw_line(Vector2(_ax, _ay) - _adir * 7.0, Vector2(_ax, _ay) + _adir * 7.0,
			Color(em.r, em.g, em.b, _aalpha), 2.0)
		# Arrowhead (triangle in direction of travel)
		var _perp := Vector2(-_adir.y, _adir.x)
		draw_colored_polygon(PackedVector2Array([
			Vector2(_ax, _ay) + _adir * 7.0,
			Vector2(_ax, _ay) + _adir * 3.5 + _perp * 2.5,
			Vector2(_ax, _ay) + _adir * 3.5 - _perp * 2.5
		]), Color(em.r * 0.7, em.g, em.b * 0.5, _aalpha * 0.90))
		# Emerald glow trace
		draw_circle(Vector2(_ax, _ay) - _adir * 5.0, 1.5,
			Color(em.r, em.g, em.b, _aalpha * 0.50))
	# 5 drifting leaf shapes
	for _li in range(5):
		var _la := _rt * 0.28 + _li * (TAU / 5.0)
		var _lr := 20.0 + sin(_rt * 0.9 + float(_li) * 1.3) * 5.0
		var _lx := cos(_la) * _lr
		var _ly := -2.0 + b + sin(_la * 0.55) * 12.0
		var _lalpha := 0.30 + sin(_rt * 1.8 + float(_li)) * 0.12
		draw_colored_polygon(PackedVector2Array([
			Vector2(_lx,     _ly - 4.5),
			Vector2(_lx + 2.5, _ly),
			Vector2(_lx,     _ly + 4.5),
			Vector2(_lx - 2.5, _ly)
		]), Color(tc.r * 0.95, tc.g, tc.b * 0.45, _lalpha))
		draw_line(Vector2(_lx, _ly - 3.5), Vector2(_lx, _ly + 3.5),
			Color(tc_l.r, tc_l.g, tc_l.b, _lalpha * 0.55), 1.0)
	# 3 rotating emerald feathers (outer ring)
	for _fi in range(3):
		var _fa := _rt * 0.38 + _fi * (TAU / 3.0)
		var _fx := cos(_fa) * 31.0
		var _fy := -4.0 + b + sin(_fa * 0.48) * 13.0
		var _falpha := 0.48 + sin(_rt * 2.4 + float(_fi)) * 0.18
		draw_colored_polygon(PackedVector2Array([
			Vector2(_fx,     _fy - 7),
			Vector2(_fx + 2, _fy),
			Vector2(_fx,     _fy + 7),
			Vector2(_fx - 2, _fy)
		]), Color(em.r * 0.45, em.g, em.b * 0.65, _falpha))
		draw_line(Vector2(_fx, _fy - 6), Vector2(_fx, _fy + 6),
			Color(em.r, em.g, em.b, _falpha * 0.70), 1.0)
		# Small glow pulse at feather tip
		draw_circle(Vector2(_fx, _fy - 6), 2.0,
			Color(em.r, em.g, em.b, _falpha * 0.55))

	# Quiver (back left, always visible)
	draw_rect(Rect2(-28, -8 + b, 9, 24), leath_d)
	draw_rect(Rect2(-28, -8 + b, 9,  3), leather)
	draw_rect(Rect2(-28, -8 + b, 9, 24), leather, false, 1.5)
	for qi in range(3):
		var qx := -25 + qi * 3
		draw_line(Vector2(qx, -6 + b), Vector2(qx, -18 + b), arrow_c, 1.5)
		draw_colored_polygon(PackedVector2Array([
			Vector2(qx - 1, -18 + b), Vector2(qx + 1, -18 + b), Vector2(qx, -22 + b)
		]), Color(0.70, 0.22, 0.22))

	# Boots
	draw_rect(Rect2(-9, 14 + b, 8, 10), leath_d)
	draw_rect(Rect2( 1, 14 + b, 8, 10), leath_d)
	draw_line(Vector2(-9, 14 + b), Vector2(-1, 14 + b), leather, 1.5)
	draw_line(Vector2( 1, 14 + b), Vector2( 9, 14 + b), leather, 1.5)

	# Green cloak body
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -8 + b), Vector2(13, -8 + b),
		Vector2(16,  22 + b), Vector2(-16, 22 + b)
	]), tc)
	draw_colored_polygon(PackedVector2Array([
		Vector2(5, -8 + b), Vector2(13, -8 + b),
		Vector2(16, 22 + b), Vector2( 7, 22 + b)
	]), tc_d)

	# Leather chest harness
	draw_rect(Rect2(-12, -6 + b, 24, 10), leather.darkened(0.10))
	draw_rect(Rect2(-12, -6 + b, 24,  3), leather)
	draw_line(Vector2(-10, -6 + b), Vector2(8, 4 + b), leath_d, 2.0)  # cross-strap
	draw_rect(Rect2(-12,  4 + b, 24, 4), leath_d)                      # belt
	draw_rect(Rect2( -4,  3 + b,  8, 6), leather)                      # buckle
	draw_circle(Vector2(0, 6 + b), 2.0, em_d)                          # emerald gem

	# Arms + bracers
	draw_rect(Rect2(-20, -4 + b, 10, 5), skin)
	draw_rect(Rect2( 10, -4 + b, 10, 5), skin)
	draw_rect(Rect2(-21, -4 + b, 11, 3), leath_d)
	draw_rect(Rect2(  9, -4 + b, 11, 3), leath_d)

	# Face (partially shadowed by hood)
	draw_circle(Vector2(0, -17 + b), 7, skin)
	draw_circle(Vector2(-3, -18 + b), 1.5, em)
	draw_circle(Vector2( 3, -18 + b), 1.5, em)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -12 + b), Vector2(7, -12 + b),
		Vector2( 5,  -8 + b), Vector2(-5,  -8 + b)
	]), Color(0, 0, 0, 0.22))

	# Hood (layered deep cowl)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -14 + b), Vector2(14, -14 + b),
		Vector2( 11, -24 + b), Vector2(-11, -24 + b)
	]), tc)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -24 + b), Vector2(10, -24 + b),
		Vector2(  7, -34 + b), Vector2(-7, -34 + b)
	]), tc_d)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, -34 + b), Vector2(5, -34 + b),
		Vector2( 2, -42 + b), Vector2(-2, -42 + b)
	]), tc_d)
	draw_line(Vector2(-14, -14 + b), Vector2(14, -14 + b), tc_l, 1.5)
	# Hood feather
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -24 + b), Vector2(-8, -24 + b),
		Vector2(-6,  -37 + b), Vector2(-9, -35 + b)
	]), Color(0.80, 0.72, 0.52))
	draw_line(Vector2(-8, -24 + b), Vector2(-7, -37 + b), Color(0.55, 0.40, 0.18), 1.0)
	# Emerald hood clasp
	draw_circle(Vector2(0, -14 + b), 2.5, em)
	draw_circle(Vector2(0, -14 + b), 4.5, Color(em.r, em.g, em.b, 0.35))

	# Longbow (right side, always present)
	var bx  := 21.0
	var btop := Vector2(bx, -34 + b)
	var bbot := Vector2(bx,  22 + b)
	draw_arc(Vector2(bx - 4, -6 + b), 30, -PI * 0.55, PI * 0.55, 18, leather, 4.0)
	draw_circle(btop, 3.5, em)
	draw_circle(bbot, 3.5, em)
	if not s:
		draw_line(btop, bbot, Color(0.92, 0.88, 0.72, 0.85), 1.5)
	else:
		var sw  := minf(_shoot_anim / 0.35, 1.0)
		var pul := Vector2(bx - 5 - sw * 10, -6 + b)
		draw_line(btop, pul, Color(0.92, 0.88, 0.72, 0.90), 1.5)
		draw_line(bbot, pul, Color(0.92, 0.88, 0.72, 0.90), 1.5)
		draw_line(pul, Vector2(bx + 20, -6 + b), arrow_c, 2.5)
		draw_colored_polygon(PackedVector2Array([
			Vector2(bx + 22, -6 + b),
			Vector2(bx + 17, -8 + b),
			Vector2(bx + 17, -4 + b)
		]), Color(0.55, 0.20, 0.20))
		draw_circle(btop, 5.5, Color(em.r, em.g, em.b, sw * 0.45))
		draw_circle(bbot, 5.5, Color(em.r, em.g, em.b, sw * 0.45))


# ── Hero Stone Guardian (type 55) ───────────────────────────────────
# Ancient stone warrior — massive cracked-stone armor, glowing crystal-blue
# veins, carved runes, huge warhammer, crystal shoulder growths.

func _draw_hero_guardian(bob: float, shooting: bool) -> void:
	var b      := bob
	var tc     := tower_color              # stone gray
	var tc_d   := tc.darkened(0.40)
	var tc_l   := tc.lightened(0.22)
	var crys   := Color(0.40, 0.80, 0.95)  # crystal-blue glow
	var crys_l := Color(0.70, 0.95, 1.00)
	var moss   := Color(0.28, 0.50, 0.22)  # moss accent
	var s      := shooting

	draw_circle(Vector2(0, 24), 16, Color(0, 0, 0, 0.22))

	# ── Floating Stone Fragments + Crystal Shards + Dust ────────────────────
	var _gt := _anim_time
	# 4 ancient stone chunks — slow, heavy orbit
	for _si in range(4):
		var _sa := _gt * 0.22 + _si * (TAU / 4.0)   # very slow
		var _sr := 32.0 + sin(_gt * 0.7 + float(_si)) * 4.0
		var _sx := cos(_sa) * _sr
		var _sy := -2.0 + b + sin(_sa * 0.45) * 15.0
		var _sz := float(4 + (_si % 2) * 3)
		var _salpha := 0.62 + sin(_gt * 0.9 + float(_si)) * 0.10
		# Irregular stone chunk (quad with slight offset corners)
		draw_colored_polygon(PackedVector2Array([
			Vector2(_sx - _sz,       _sy - _sz * 0.75),
			Vector2(_sx + _sz,       _sy - _sz * 0.50),
			Vector2(_sx + _sz * 0.8, _sy + _sz),
			Vector2(_sx - _sz * 0.7, _sy + _sz * 0.85)
		]), Color(tc.r, tc.g, tc.b, _salpha))
		draw_polyline(PackedVector2Array([
			Vector2(_sx - _sz,       _sy - _sz * 0.75),
			Vector2(_sx + _sz,       _sy - _sz * 0.50),
			Vector2(_sx + _sz * 0.8, _sy + _sz),
			Vector2(_sx - _sz * 0.7, _sy + _sz * 0.85),
			Vector2(_sx - _sz,       _sy - _sz * 0.75)
		]), Color(tc.r * 0.5, tc.g * 0.5, tc.b * 0.5, _salpha * 0.55))
		# Rune etch (small glowing line)
		draw_line(Vector2(_sx - 2, _sy), Vector2(_sx + 2, _sy),
			Color(crys.r, crys.g, crys.b, _salpha * 0.55), 1.0)
		# Dust/rubble particle drifting below each chunk
		draw_circle(Vector2(_sx + sin(_gt * 2.0 + float(_si)) * 2.5, _sy + _sz + 5.0),
			1.5, Color(tc.r * 0.75, tc.g * 0.70, tc.b * 0.60, _salpha * 0.32))
	# 3 glowing crystal shards — inner orbit, pulse softly
	for _xi in range(3):
		var _xa := _gt * 0.34 + _xi * (TAU / 3.0) + PI * 0.25
		var _xr := 22.0 + sin(_gt * 1.1 + float(_xi)) * 3.0
		var _xx := cos(_xa) * _xr
		var _xy := -6.0 + b + sin(_xa * 0.55) * 12.0
		var _xpulse := 0.50 + sin(_gt * 2.5 + float(_xi)) * 0.28
		# Shard (tall thin triangle)
		draw_colored_polygon(PackedVector2Array([
			Vector2(_xx,      _xy - 8),
			Vector2(_xx + 3,  _xy + 5),
			Vector2(_xx - 3,  _xy + 5)
		]), Color(crys.r, crys.g, crys.b, 0.55 + _xpulse * 0.22))
		# Glow halo around shard
		draw_circle(Vector2(_xx, _xy), 6.0,
			Color(crys.r, crys.g, crys.b, _xpulse * 0.22))
		# Bright tip glint
		draw_circle(Vector2(_xx, _xy - 7), 1.5,
			Color(1.0, 1.0, 1.0, _xpulse * 0.55))

	# Legs — thick stone greaves
	draw_rect(Rect2(-13, 10 + b, 11, 14), tc_d)
	draw_rect(Rect2(  2, 10 + b, 11, 14), tc_d)
	draw_line(Vector2(-13, 10 + b), Vector2(-2, 10 + b), tc_l, 2.0)
	draw_line(Vector2(  2, 10 + b), Vector2(13, 10 + b), tc_l, 2.0)
	# Crystal vein in greaves
	draw_line(Vector2(-9, 10 + b), Vector2(-7, 22 + b), crys, 1.5)
	draw_line(Vector2( 6, 10 + b), Vector2( 8, 22 + b), crys, 1.5)

	# Wide stone torso
	draw_colored_polygon(PackedVector2Array([
		Vector2(-18, -12 + b), Vector2(18, -12 + b),
		Vector2(15,  12 + b),  Vector2(-15, 12 + b)
	]), tc)
	# Crack lines on torso
	draw_line(Vector2(-10, -12 + b), Vector2(-6, 0 + b), tc_d, 1.5)
	draw_line(Vector2(  5, -12 + b), Vector2( 9, 2 + b), tc_d, 1.5)
	draw_line(Vector2(-16,  -2 + b), Vector2(-8, 6 + b), tc_d, 1.0)
	# Crystal chest vein (central)
	draw_line(Vector2(0, -12 + b), Vector2( 4,  4 + b), crys, 2.0)
	draw_line(Vector2(4,  4 + b),  Vector2(-2, 10 + b), crys, 2.0)
	draw_circle(Vector2(2, 0 + b), 3.5, crys)
	draw_circle(Vector2(2, 0 + b), 6.0, Color(crys.r, crys.g, crys.b, 0.28))
	# Rune carvings
	draw_line(Vector2(-12, -4 + b), Vector2(-6, -4 + b), tc_l, 1.5)
	draw_line(Vector2(-9,  -7 + b), Vector2(-9, -1 + b), tc_l, 1.5)
	draw_line(Vector2( 8,  -6 + b), Vector2(14, -6 + b), tc_l, 1.5)
	# Moss patches (lower torso edges)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-15, 8 + b), Vector2(-10, 8 + b),
		Vector2(-10, 12 + b), Vector2(-15, 12 + b)
	]), moss)
	draw_colored_polygon(PackedVector2Array([
		Vector2(10, 8 + b), Vector2(15, 8 + b),
		Vector2(15, 12 + b), Vector2(10, 12 + b)
	]), moss)

	# Belt / waist plate
	draw_rect(Rect2(-16, 8 + b, 32, 5), tc_d)
	draw_line(Vector2(-16, 8 + b), Vector2(16, 8 + b), tc_l, 2.0)
	draw_circle(Vector2(0, 10 + b), 3.0, crys)

	# Massive stone pauldrons with crystal growths
	draw_circle(Vector2(-22, -10 + b), 13, tc_d)
	draw_circle(Vector2(-22, -10 + b), 13, tc_l, false, 2.0)
	draw_circle(Vector2(-22, -14 + b), 8, tc)
	# Crystal growths left shoulder
	draw_colored_polygon(PackedVector2Array([
		Vector2(-26, -18 + b), Vector2(-22, -18 + b), Vector2(-24, -26 + b)
	]), crys_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20, -20 + b), Vector2(-16, -20 + b), Vector2(-18, -28 + b)
	]), crys)
	draw_circle(Vector2(-24, -25 + b), 2.0, Color(1, 1, 1, 0.60))  # glint
	draw_circle(Vector2(22, -10 + b), 13, tc_d)
	draw_circle(Vector2(22, -10 + b), 13, tc_l, false, 2.0)
	draw_circle(Vector2(22, -14 + b), 8, tc)
	# Crystal growths right shoulder
	draw_colored_polygon(PackedVector2Array([
		Vector2(22, -18 + b), Vector2(26, -18 + b), Vector2(24, -26 + b)
	]), crys_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(16, -20 + b), Vector2(20, -20 + b), Vector2(18, -28 + b)
	]), crys)
	draw_circle(Vector2(24, -25 + b), 2.0, Color(1, 1, 1, 0.60))

	# Stone helmet (flat top, full face, carved brow)
	draw_circle(Vector2(0, -20 + b), 11, tc)
	draw_circle(Vector2(0, -20 + b), 11, tc_d, false, 2.0)
	draw_rect(Rect2(-10, -25 + b, 20, 7), tc_d)   # visor band
	draw_rect(Rect2(-7,  -24 + b, 14, 5), tc.darkened(0.65))
	draw_line(Vector2(-10, -25 + b), Vector2(10, -25 + b), tc_l, 2.0)
	draw_line(Vector2(-10, -18 + b), Vector2(10, -18 + b), tc_l, 1.5)
	# Crystal eye-slits
	draw_line(Vector2(-6, -22 + b), Vector2(-2, -22 + b), crys, 2.0)
	draw_line(Vector2( 2, -22 + b), Vector2( 6, -22 + b), crys, 2.0)
	draw_line(Vector2(-5, -22 + b), Vector2(-3, -22 + b), crys_l, 3.0)
	draw_line(Vector2( 3, -22 + b), Vector2( 5, -22 + b), crys_l, 3.0)
	# Helmet top stone cap
	draw_rect(Rect2(-10, -30 + b, 20, 5), tc_d)
	draw_line(Vector2(-10, -30 + b), Vector2(10, -30 + b), tc_l, 2.0)
	# Rune etched on forehead
	draw_line(Vector2(-3, -28 + b), Vector2(3, -28 + b), crys, 1.5)
	draw_line(Vector2(0,  -30 + b), Vector2(0, -26 + b), crys, 1.5)

	# Warhammer (right side) — enormous head, short thick haft
	if s:
		var sw  := _shoot_anim / 0.35
		var ang := -PI * 0.4 + sw * PI * 0.90
		var hx  := 16.0 + cos(ang) * 32
		var hy  := -4.0 + b + sin(ang) * 32
		draw_line(Vector2(16, -2 + b), Vector2(hx, hy), tc.darkened(0.15), 7.0)
		draw_rect(Rect2(hx - 12, hy - 11, 24, 16), tc)
		draw_rect(Rect2(hx - 12, hy - 11, 24, 16), tc_d, false, 2.0)
		draw_line(Vector2(hx - 12, hy - 11), Vector2(hx + 12, hy - 11), tc_l, 2.0)
		draw_line(Vector2(hx - 12, hy +  5), Vector2(hx + 12, hy +  5), tc_l, 1.5)
		# Crystal strike face
		draw_line(Vector2(hx - 6, hy - 6), Vector2(hx + 6, hy - 6), crys, 2.0)
		if sw > 0.35:
			draw_arc(Vector2(16, -2 + b), 32, ang - 0.6, ang, 8,
				Color(crys.r, crys.g, crys.b, sw * 0.60), 6.0)
	else:
		draw_line(Vector2(16, -2 + b), Vector2(20, -36 + b), tc.darkened(0.15), 7.0)
		draw_rect(Rect2(10, -44 + b, 24, 16), tc)
		draw_rect(Rect2(10, -44 + b, 24, 16), tc_d, false, 2.0)
		draw_line(Vector2(10, -44 + b), Vector2(34, -44 + b), tc_l, 2.0)
		draw_line(Vector2(10, -28 + b), Vector2(34, -28 + b), tc_l, 1.5)
		draw_line(Vector2(16, -40 + b), Vector2(28, -40 + b), crys, 2.0)

	# Crystal aura pulse when shooting
	if s:
		var pulse := 0.5 + sin(_anim_time * 4.0) * 0.3
		draw_circle(Vector2(0, -5 + b), 28.0, Color(crys.r, crys.g, crys.b, pulse * 0.12))


# ── Hero Blade Dancer (type 56) ──────────────────────────────────────────
# Legendary sword master — silver armor, white flowing cloth, gold trim,
# dual straight long swords, orbiting spectral blades, wind streaks.

func _draw_hero_blade_dancer(bob: float, shooting: bool) -> void:
	var b      := bob
	var silver := Color(0.80, 0.84, 0.92)   # armor silver
	var silv_d := Color(0.48, 0.50, 0.58)   # shadow
	var silv_l := Color(0.94, 0.96, 1.00)   # highlight
	var gold   := Color(0.92, 0.76, 0.20)   # gold trim
	var gold_l := Color(1.00, 0.92, 0.55)   # bright gold
	var cloth  := Color(0.96, 0.96, 0.98)   # white cloth
	var blue_a := Color(0.28, 0.60, 0.95)   # blue accent
	var rune_c := Color(0.45, 0.78, 1.00)   # blade rune glow
	var blade  := Color(0.88, 0.92, 0.98)   # longsword blade
	var s      := shooting

	draw_circle(Vector2(0, 24), 12, Color(0, 0, 0, 0.16))

	# ── Orbiting spectral blades ───────────────────────────────────────────
	for _bi in range(3):
		var _ba  := _anim_time * 1.20 + _bi * (TAU / 3.0)
		var _br  := 28.0 + sin(_anim_time * 1.5 + float(_bi)) * 4.0
		var _bx  := cos(_ba) * _br
		var _by  := -2.0 + b + sin(_ba * 0.58) * 14.0
		var _ba2 := 0.45 + sin(_anim_time * 2.0 + float(_bi)) * 0.15
		var _bdir := Vector2(-sin(_ba), cos(_ba) * 0.55).normalized()
		draw_line(Vector2(_bx, _by) - _bdir * 12.0, Vector2(_bx, _by) + _bdir * 12.0,
			Color(silv_l.r, silv_l.g, silv_l.b, _ba2), 2.5)
		draw_circle(Vector2(_bx, _by), 2.0, Color(rune_c.r, rune_c.g, rune_c.b, _ba2 * 0.70))
		draw_circle(Vector2(_bx, _by), 4.5, Color(blue_a.r, blue_a.g, blue_a.b, _ba2 * 0.20))

	# ── Wind streaks at feet ───────────────────────────────────────────────
	for _wi in range(4):
		var _woff := _anim_time * 2.5 + _wi * 0.8
		var _wx1  := -20.0 + fmod(_woff * 12.0, 40.0)
		var _wy   := 18.0 + b + (_wi - 1.5) * 3.0
		var _wa2  := 0.20 + sin(_woff) * 0.10
		draw_line(Vector2(_wx1, _wy), Vector2(_wx1 + 14.0, _wy),
			Color(blue_a.r, blue_a.g, blue_a.b, _wa2), 1.5)

	# ── Wide flowing white cloth sash (behind legs, dramatic) ─────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, 6 + b), Vector2(14, 6 + b),
		Vector2(20, 26 + b), Vector2(-20, 26 + b)
	]), cloth)
	draw_line(Vector2(-14, 6 + b), Vector2(14, 6 + b), gold, 2.0)
	draw_line(Vector2(-20, 26 + b), Vector2(20, 26 + b), gold, 1.5)
	# Cloth fold lines
	draw_line(Vector2(-6, 6 + b), Vector2(-8, 26 + b), Color(silv_d.r, silv_d.g, silv_d.b, 0.20), 1.0)
	draw_line(Vector2( 6, 6 + b), Vector2( 8, 26 + b), Color(silv_d.r, silv_d.g, silv_d.b, 0.20), 1.0)

	# ── Legs (under cloth) ────────────────────────────────────────────────
	draw_rect(Rect2(-9, 12 + b, 8, 12), silv_d)
	draw_rect(Rect2( 1, 12 + b, 8, 12), silv_d)
	draw_line(Vector2(-9, 12 + b), Vector2(-1, 12 + b), gold, 1.5)
	draw_line(Vector2( 1, 12 + b), Vector2( 9, 12 + b), gold, 1.5)

	# ── Silver torso armor ────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -10 + b), Vector2(12, -10 + b),
		Vector2( 11,  10 + b), Vector2(-11, 10 + b)
	]), silver)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4, -10 + b), Vector2(4, -10 + b),
		Vector2( 4,  10 + b), Vector2(-4, 10 + b)
	]), silv_l)
	draw_line(Vector2(-12, -10 + b), Vector2(12, -10 + b), gold, 2.0)
	draw_line(Vector2(-11,  10 + b), Vector2(11, 10 + b), gold, 1.5)
	# Blue rune on chest center
	draw_line(Vector2(-2, -8 + b), Vector2( 2, -8 + b), rune_c, 1.5)
	draw_line(Vector2( 0, -8 + b), Vector2( 0,  6 + b), rune_c, 1.5)
	draw_line(Vector2(-3, -2 + b), Vector2( 3, -2 + b), rune_c, 1.0)

	# ── Slim pauldrons ────────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20, -8 + b), Vector2(-10, -8 + b),
		Vector2(-10, -2 + b), Vector2(-20, -2 + b)
	]), silver)
	draw_line(Vector2(-20, -8 + b), Vector2(-10, -8 + b), gold, 1.5)
	draw_colored_polygon(PackedVector2Array([
		Vector2(10, -8 + b), Vector2(20, -8 + b),
		Vector2(20, -2 + b), Vector2(10, -2 + b)
	]), silver)
	draw_line(Vector2(10, -8 + b), Vector2(20, -8 + b), gold, 1.5)
	draw_rect(Rect2(-21, -6 + b, 9, 5), silver)
	draw_rect(Rect2( 12, -6 + b, 9, 5), silver)

	# ── Face + hair (confident master) ───────────────────────────────────
	draw_circle(Vector2(0, -18 + b), 7, Color(0.90, 0.78, 0.60))
	draw_circle(Vector2(-3, -19 + b), 1.5, Color(0.20, 0.35, 0.70))
	draw_circle(Vector2( 3, -19 + b), 1.5, Color(0.20, 0.35, 0.70))
	# Silver circlet
	draw_rect(Rect2(-8, -25 + b, 16, 3), silver)
	draw_line(Vector2(-8, -25 + b), Vector2(8, -25 + b), gold, 1.5)
	draw_circle(Vector2(0, -26 + b), 2.5, blue_a)
	draw_circle(Vector2(0, -26 + b), 4.0, Color(blue_a.r, blue_a.g, blue_a.b, 0.25))
	# Hair
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -25 + b), Vector2(7, -25 + b),
		Vector2(5,  -32 + b), Vector2(-5, -32 + b)
	]), Color(0.92, 0.88, 0.78))

	# ── Dual long swords ──────────────────────────────────────────────────
	if s:
		var sw := _shoot_anim / 0.35
		# Right: upward diagonal slash
		var _rbase := Vector2(13, -2 + b)
		var _rtip  := Vector2(22 + sw * 16, -22 + b - sw * 20)
		draw_line(_rbase, _rtip + Vector2(4, 4), Color(rune_c.r, rune_c.g, rune_c.b, sw * 0.28), 3.0)
		draw_line(_rbase, _rtip, blade, 4.5)
		draw_line(_rbase, _rtip, Color(silv_l.r, silv_l.g, silv_l.b, 0.55), 1.5)
		draw_circle(_rbase.lerp(_rtip, 0.5), 2.5, Color(rune_c.r, rune_c.g, rune_c.b, sw * 0.80))
		draw_arc(Vector2(12, -5 + b), 20, -PI * 0.55, PI * 0.05, 10,
			Color(gold.r, gold.g, gold.b, sw * 0.75), 5.0)
		# Left: counter-slash
		var _lbase := Vector2(-13, -2 + b)
		var _ltip  := Vector2(-22 - sw * 16, -22 + b - sw * 20)
		draw_line(_lbase, _ltip + Vector2(-4, 4), Color(rune_c.r, rune_c.g, rune_c.b, sw * 0.28), 3.0)
		draw_line(_lbase, _ltip, blade, 4.5)
		draw_line(_lbase, _ltip, Color(silv_l.r, silv_l.g, silv_l.b, 0.55), 1.5)
		draw_circle(_lbase.lerp(_ltip, 0.5), 2.5, Color(rune_c.r, rune_c.g, rune_c.b, sw * 0.80))
		draw_arc(Vector2(-12, -5 + b), 20, PI * 0.95, PI * 1.55, 10,
			Color(gold.r, gold.g, gold.b, sw * 0.75), 5.0)
	else:
		# Right sword at rest (angled up-right, rune etching visible)
		draw_line(Vector2(13, 8 + b), Vector2(22, -24 + b), blade, 4.5)
		draw_line(Vector2(13, 8 + b), Vector2(22, -24 + b), Color(silv_l.r, silv_l.g, silv_l.b, 0.30), 1.5)
		for _ri in range(3):
			var _ry := -4 + _ri * -6
			draw_line(Vector2(15, _ry + b), Vector2(20, _ry + b), Color(rune_c.r, rune_c.g, rune_c.b, 0.72), 1.2)
		draw_line(Vector2(9, 6 + b), Vector2(18, 6 + b), gold, 2.5)
		# Left sword at rest (mirrored)
		draw_line(Vector2(-13, 8 + b), Vector2(-22, -24 + b), blade, 4.5)
		draw_line(Vector2(-13, 8 + b), Vector2(-22, -24 + b), Color(silv_l.r, silv_l.g, silv_l.b, 0.30), 1.5)
		for _ri in range(3):
			var _ry := -4 + _ri * -6
			draw_line(Vector2(-16, _ry + b), Vector2(-21, _ry + b), Color(rune_c.r, rune_c.g, rune_c.b, 0.72), 1.2)
		draw_line(Vector2(-9, 6 + b), Vector2(-18, 6 + b), gold, 2.5)

	# Slash flash on attack
	if s:
		var _sf := 1.0 - _shoot_anim / 0.35
		draw_circle(Vector2(0, -4 + b), 24.0, Color(blue_a.r, blue_a.g, blue_a.b, _sf * 0.14))



# ── Hero Frost Herald (type 57) ────────────────────────────────────────────
# Ancient frost archmage — long icy robes, crystal shoulder armor, floating
# ice crown, tall frost staff, orbiting snowflakes and ice crystals.

func _draw_hero_frost_herald(bob: float, shooting: bool) -> void:
	var b      := bob
	var ice    := Color(0.85, 0.96, 1.00)   # near-white ice
	var frost  := Color(0.42, 0.82, 1.00)   # mid frost blue
	var deep   := Color(0.18, 0.48, 0.80)   # deep ice
	var cyan_l := Color(0.20, 0.92, 1.00)   # bright cyan
	var silver := Color(0.78, 0.84, 0.92)   # silver
	var snow   := Color(0.95, 0.98, 1.00)   # pure snow white
	var stf    := Color(0.20, 0.38, 0.58)   # staff dark ice
	var skin   := Color(0.88, 0.94, 1.00)   # pale ancient skin
	var s      := shooting

	draw_circle(Vector2(0, 24), 14, Color(0, 0, 0, 0.16))

	# ── Frost mist at feet ────────────────────────────────────────────────
	for _mi in range(5):
		var _ma := _anim_time * 0.50 + _mi * (TAU / 5.0)
		var _mx := cos(_ma) * (10.0 + sin(_anim_time * 1.4 + float(_mi)) * 5.0)
		var _my := 18.0 + b + sin(_ma * 0.70) * 4.0
		draw_circle(Vector2(_mx, _my), 5.0 + sin(_anim_time * 1.8 + float(_mi)) * 2.0,
			Color(ice.r, ice.g, ice.b, 0.22))

	# ── 6 orbiting snowflakes ─────────────────────────────────────────────
	for _si in range(6):
		var _sa  := _anim_time * 0.55 + _si * (TAU / 6.0)
		var _sr  := 30.0 + sin(_anim_time * 1.0 + float(_si)) * 4.0
		var _sx  := cos(_sa) * _sr
		var _sy  := -2.0 + b + sin(_sa * 0.50) * 14.0
		var _sa2 := 0.50 + sin(_anim_time * 1.8 + float(_si)) * 0.16
		# Snowflake 6-axis lines
		for _ax in range(3):
			var _aa := float(_ax) * (PI / 3.0) + _sa * 0.30
			draw_line(
				Vector2(_sx + cos(_aa) * 5.5, _sy + sin(_aa) * 5.5),
				Vector2(_sx - cos(_aa) * 5.5, _sy - sin(_aa) * 5.5),
				Color(ice.r, ice.g, ice.b, _sa2), 1.5)
		draw_circle(Vector2(_sx, _sy), 1.8, Color(snow.r, snow.g, snow.b, _sa2 * 0.90))

	# ── 4 rotating ice crystals (inner orbit) ─────────────────────────────
	for _ci in range(4):
		var _ca  := _anim_time * 1.10 + _ci * (TAU / 4.0)
		var _cr  := 22.0 + sin(_anim_time * 1.5 + float(_ci)) * 3.0
		var _cx  := cos(_ca) * _cr
		var _cy  := -2.0 + b + sin(_ca * 0.55) * 13.0
		var _ca2 := 0.60 + sin(_anim_time * 2.4 + float(_ci)) * 0.15
		# Tall ice shard (triangle)
		draw_colored_polygon(PackedVector2Array([
			Vector2(_cx,       _cy - 8.0),
			Vector2(_cx + 2.5, _cy + 3.0),
			Vector2(_cx,       _cy + 6.0),
			Vector2(_cx - 2.5, _cy + 3.0)
		]), Color(frost.r, frost.g, frost.b, _ca2))
		draw_circle(Vector2(_cx, _cy - 6.0), 2.0, Color(cyan_l.r, cyan_l.g, cyan_l.b, _ca2 * 0.70))
		draw_circle(Vector2(_cx, _cy - 6.0), 4.0, Color(ice.r, ice.g, ice.b, _ca2 * 0.25))

	# ── Long icy robes ────────────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9, -10 + b), Vector2(9, -10 + b),
		Vector2(13,  24 + b), Vector2(-13, 24 + b)
	]), deep)
	# Inner white panel
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, -10 + b), Vector2(5, -10 + b),
		Vector2(7,   24 + b), Vector2(-7, 24 + b)
	]), ice)
	# Frost rune hem pattern
	draw_line(Vector2(-13, 18 + b), Vector2(13, 18 + b), ice, 1.5)
	for _rx in range(6):
		var _rxx := -12.0 + _rx * 5.0
		draw_line(Vector2(_rxx, 18 + b), Vector2(_rxx, 22 + b), frost, 1.0)
		draw_line(Vector2(_rxx - 1.5, 20 + b), Vector2(_rxx + 1.5, 20 + b), frost, 1.0)

	# ── Large crystal shoulder armor ─────────────────────────────────────
	# Left: angular plate with 2 icicle spikes
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20, -8 + b), Vector2(-8, -8 + b),
		Vector2(-8,  -1 + b), Vector2(-20, -1 + b)
	]), frost)
	draw_line(Vector2(-20, -8 + b), Vector2(-8, -8 + b), ice, 2.5)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-18, -8 + b), Vector2(-15, -8 + b), Vector2(-16, -18 + b)
	]), ice)   # spike 1
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -8 + b), Vector2(-10, -8 + b), Vector2(-11, -15 + b)
	]), ice)   # spike 2
	# Right: mirrored
	draw_colored_polygon(PackedVector2Array([
		Vector2( 8, -8 + b), Vector2(20, -8 + b),
		Vector2(20, -1 + b), Vector2( 8, -1 + b)
	]), frost)
	draw_line(Vector2(8, -8 + b), Vector2(20, -8 + b), ice, 2.5)
	draw_colored_polygon(PackedVector2Array([
		Vector2(13, -8 + b), Vector2(16, -8 + b), Vector2(14, -18 + b)
	]), ice)
	draw_colored_polygon(PackedVector2Array([
		Vector2(10, -8 + b), Vector2(13, -8 + b), Vector2(11, -15 + b)
	]), ice)
	draw_rect(Rect2(-22, -6 + b, 10, 5), skin)   # arms
	draw_rect(Rect2( 12, -6 + b, 10, 5), skin)

	# ── Ancient pale face + white beard ───────────────────────────────────
	draw_circle(Vector2(0, -18 + b), 7, skin)
	var _eye_c := Color(cyan_l.r, cyan_l.g, cyan_l.b, 0.90) if not s else Color(1, 1, 1)
	draw_circle(Vector2(-3, -19 + b), 1.5, _eye_c)
	draw_circle(Vector2( 3, -19 + b), 1.5, _eye_c)
	if s:
		draw_circle(Vector2(-3, -19 + b), 3.5, Color(frost.r, frost.g, frost.b, 0.55))
		draw_circle(Vector2( 3, -19 + b), 3.5, Color(frost.r, frost.g, frost.b, 0.55))
	# Beard (long, flowing white)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, -13 + b), Vector2(5, -13 + b),
		Vector2(7,  -4  + b), Vector2(-7, -4 + b)
	]), snow)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4, -4 + b), Vector2(4, -4 + b),
		Vector2(5,  8  + b), Vector2(-5, 8 + b)
	]), snow)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3, 8 + b), Vector2(3, 8 + b), Vector2(2, 16 + b), Vector2(-2, 16 + b)
	]), snow)

	# ── Tall hood / robes top (deep ice-blue) ─────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -15 + b), Vector2(10, -15 + b),
		Vector2(8,   -26 + b), Vector2(-8, -26 + b)
	]), deep)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -26 + b), Vector2(6, -26 + b),
		Vector2(4,  -36 + b), Vector2(-4, -36 + b)
	]), deep)
	draw_line(Vector2(-10, -15 + b), Vector2(10, -15 + b), ice, 2.0)
	draw_circle(Vector2(0, -16 + b), 2.5, frost)

	# ── Floating ice crown (detached, hovering above) ─────────────────────
	var _cby := -44.0 + b + sin(_anim_time * 1.20) * 2.5
	draw_rect(Rect2(-9, _cby, 18, 4), deep)
	draw_line(Vector2(-9, _cby), Vector2(9, _cby), ice, 2.0)
	for _ci2 in range(5):
		var _cx2 := -8.0 + _ci2 * 4.0
		var _cht := 4 + (3 if _ci2 % 2 == 0 else 0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(_cx2, _cby),
			Vector2(_cx2 + 3.0, _cby),
			Vector2(_cx2 + 1.5, _cby - _cht)
		]), ice if _ci2 % 2 == 0 else frost)
	draw_circle(Vector2(-4, _cby + 2), 2.0, cyan_l)
	draw_circle(Vector2( 0, _cby + 2), 2.5, cyan_l)
	draw_circle(Vector2( 4, _cby + 2), 2.0, cyan_l)
	# Crown glow halo
	draw_circle(Vector2(0, _cby + 2), 14, Color(ice.r, ice.g, ice.b, 0.18))

	# ── Tall frost staff (left) ───────────────────────────────────────────
	draw_line(Vector2(-18, 22 + b), Vector2(-22, -28 + b), stf, 5.0)
	draw_line(Vector2(-18, 22 + b), Vector2(-22, -28 + b), ice, 1.5)
	draw_rect(Rect2(-20, -6 + b, 10, 5), skin)   # hand
	# Crystal cluster at staff top
	draw_colored_polygon(PackedVector2Array([
		Vector2(-26, -28 + b), Vector2(-18, -28 + b),
		Vector2(-20, -40 + b), Vector2(-24, -40 + b)
	]), frost)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-24, -40 + b), Vector2(-20, -40 + b), Vector2(-22, -48 + b)
	]), ice)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-26, -30 + b), Vector2(-30, -36 + b), Vector2(-26, -38 + b)
	]), ice)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-18, -30 + b), Vector2(-14, -36 + b), Vector2(-18, -38 + b)
	]), ice)
	var _orb_r := 7.0 if not s else 9.0
	if s:
		var _p := 0.5 + sin(_anim_time * 6.0) * 0.3
		draw_circle(Vector2(-22, -34 + b), _orb_r + 10, Color(ice.r, ice.g, ice.b, _p * 0.28))
	draw_circle(Vector2(-22, -34 + b), _orb_r, frost.lightened(0.30))
	draw_circle(Vector2(-22, -34 + b), _orb_r, deep, false, 2.0)
	draw_circle(Vector2(-25, -37 + b), _orb_r * 0.35, Color(1, 1, 1, 0.55))



# ── Hero Venom Lord (type 58) ─────────────────────────────────────────────
# Toxic ruler — regal serpentine scale armor, toxic crown, tall venom staff,
# floating poison globes, orbiting venom crystals, spectral snakes.

func _draw_hero_venom_lord(bob: float, shooting: bool) -> void:
	var b      := bob
	var tc     := tower_color              # toxic green
	var venom  := Color(0.12, 0.82, 0.18)  # bright venom
	var acid   := Color(0.65, 0.96, 0.08)  # acid yellow
	var dark   := Color(0.05, 0.12, 0.06)  # near-black dark
	var dark_l := Color(0.12, 0.24, 0.14)  # dark highlight
	var scale  := Color(0.08, 0.48, 0.14)  # scale green
	var s      := shooting

	draw_circle(Vector2(0, 24), 13, Color(0, 0, 0, 0.22))

	# ── Poison mist at feet ───────────────────────────────────────────────
	for _mi in range(5):
		var _ma := _anim_time * 0.50 + _mi * (TAU / 5.0)
		var _mx := cos(_ma) * (11.0 + sin(_anim_time * 1.3 + float(_mi)) * 4.0)
		var _my := 18.0 + b + sin(_ma * 0.65) * 4.0
		draw_circle(Vector2(_mx, _my), 5.5 + sin(_anim_time * 1.9 + float(_mi)) * 2.0,
			Color(venom.r, venom.g, venom.b, 0.20))

	# ── Floating poison globes (large, translucent) ───────────────────────
	for _gi in range(5):
		var _ga  := _anim_time * 0.85 + _gi * (TAU / 5.0)
		var _gr  := 28.0 + sin(_anim_time * 1.1 + float(_gi)) * 5.0
		var _gx  := cos(_ga) * _gr
		var _gy  := -2.0 + b + sin(_ga * 0.55) * 14.0
		var _ga2 := 0.28 + sin(_anim_time * 2.2 + float(_gi)) * 0.10
		# Translucent globe
		draw_circle(Vector2(_gx, _gy), 6.0 + sin(_anim_time * 2.0 + float(_gi)) * 1.5,
			Color(venom.r, venom.g, venom.b, _ga2))
		draw_circle(Vector2(_gx, _gy), 5.0, Color(venom.r, venom.g, venom.b, _ga2 * 0.50), false, 1.5)
		draw_circle(Vector2(_gx - 2, _gy - 2), 1.5, Color(acid.r, acid.g, acid.b, _ga2 * 0.80))

	# ── Orbiting venom crystals ───────────────────────────────────────────
	for _ci in range(4):
		var _ca  := _anim_time * 1.40 + _ci * (TAU / 4.0)
		var _cr  := 20.0 + sin(_anim_time * 1.8 + float(_ci)) * 3.0
		var _cx  := cos(_ca) * _cr
		var _cy  := -2.0 + b + sin(_ca * 0.52) * 12.0
		var _ca2 := 0.58 + sin(_anim_time * 2.8 + float(_ci)) * 0.16
		draw_colored_polygon(PackedVector2Array([
			Vector2(_cx,       _cy - 7.0),
			Vector2(_cx + 2.5, _cy + 0.0),
			Vector2(_cx,       _cy + 5.5),
			Vector2(_cx - 2.5, _cy + 0.0)
		]), Color(acid.r, acid.g, acid.b, _ca2))
		draw_circle(Vector2(_cx, _cy - 5), 1.5, Color(venom.r, venom.g, venom.b, _ca2 * 0.65))

	# ── Spectral snake silhouettes (sinuous orbit) ────────────────────────
	for _sni in range(2):
		var _snba := _anim_time * 1.0 + _sni * PI
		for _snp in range(5):
			var _snr := 24.0 + float(_snp) * 2.5
			var _sna := _snba - float(_snp) * 0.30
			draw_circle(
				Vector2(cos(_sna) * _snr, -2.0 + b + sin(_sna * 0.55) * 13.0),
				2.0 - float(_snp) * 0.25, Color(venom.r, venom.g, venom.b, 0.30))

	# ── Regal legs (armored scale greaves) ────────────────────────────────
	draw_rect(Rect2(-10, 12 + b, 9, 12), dark)
	draw_rect(Rect2(  1, 12 + b, 9, 12), dark)
	draw_line(Vector2(-10, 12 + b), Vector2(-1, 12 + b), scale, 1.5)
	draw_line(Vector2(  1, 12 + b), Vector2(10, 12 + b), scale, 1.5)
	for _li in range(3):
		draw_arc(Vector2(-5, 14 + _li * 4 + b), 5, 0, PI, 6, scale, 1.5)
		draw_arc(Vector2( 5, 14 + _li * 4 + b), 5, 0, PI, 6, scale, 1.5)

	# ── Scale-armored torso (regal, upright) ─────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -12 + b), Vector2(13, -12 + b),
		Vector2( 11,  14 + b), Vector2(-11, 14 + b)
	]), dark)
	for _row in range(3):
		for _col in range(3):
			draw_arc(Vector2(-8.0 + _col * 8.0, -10.0 + _row * 8.0 + b), 5, 0, PI, 6, scale, 1.5)
	# Venom gland sac (throat glow)
	draw_circle(Vector2(0, 0 + b), 5.5, tc)
	draw_circle(Vector2(0, 0 + b), 5.5, venom, false, 1.5)
	draw_circle(Vector2(0, 0 + b), 3.5, Color(venom.r, venom.g, venom.b, 0.45))
	draw_line(Vector2(-13, -12 + b), Vector2(13, -12 + b), acid, 2.0)
	draw_rect(Rect2(-12, 11 + b, 24, 4), dark)
	draw_line(Vector2(-12, 11 + b), Vector2(12, 11 + b), acid, 1.5)

	# ── Claw arms (dripping venom) ────────────────────────────────────────
	draw_rect(Rect2(-22, -6 + b, 10, 6), dark)
	draw_rect(Rect2( 12, -6 + b, 10, 6), dark)
	draw_line(Vector2(-22, -4 + b), Vector2(-12, -4 + b), scale, 1.5)
	draw_line(Vector2( 12, -4 + b), Vector2( 22, -4 + b), scale, 1.5)

	# ── Serpentine head (wide, regal) ────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -28 + b), Vector2(11, -28 + b),
		Vector2( 13, -14 + b), Vector2(-13, -14 + b)
	]), dark)
	draw_line(Vector2(-11, -24 + b), Vector2(11, -24 + b), scale, 1.5)
	draw_line(Vector2(-12, -18 + b), Vector2(12, -18 + b), dark_l, 1.0)
	draw_rect(Rect2(-8, -18 + b, 16, 4), dark_l)   # mouth
	draw_line(Vector2(-6, -18 + b), Vector2(-4, -14 + b), Color(0.90, 0.92, 0.72), 2.0)
	draw_line(Vector2( 4, -18 + b), Vector2( 6, -14 + b), Color(0.90, 0.92, 0.72), 2.0)
	draw_circle(Vector2(-5, -13 + b), 1.5, acid)
	draw_circle(Vector2( 6, -13 + b), 1.5, acid)
	# Slitted serpent eyes
	draw_circle(Vector2(-4, -24 + b), 2.5, acid)
	draw_circle(Vector2( 4, -24 + b), 2.5, acid)
	draw_line(Vector2(-4, -26 + b), Vector2(-4, -22 + b), dark, 1.5)
	draw_line(Vector2( 4, -26 + b), Vector2( 4, -22 + b), dark, 1.5)
	if s:
		draw_circle(Vector2(-4, -24 + b), 5.0, Color(venom.r, venom.g, venom.b, 0.55))
		draw_circle(Vector2( 4, -24 + b), 5.0, Color(venom.r, venom.g, venom.b, 0.55))

	# ── Toxic crown (serpent crown) ────────────────────────────────────────
	draw_rect(Rect2(-9, -30 + b, 18, 4), dark)
	draw_line(Vector2(-9, -30 + b), Vector2(9, -30 + b), acid, 2.0)
	# Serpent crest spikes with gem-eye centers
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, -30 + b), Vector2(-3, -30 + b), Vector2(-5, -38 + b)
	]), venom)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-1, -30 + b), Vector2( 1, -30 + b), Vector2( 0, -40 + b)
	]), acid)
	draw_colored_polygon(PackedVector2Array([
		Vector2( 3, -30 + b), Vector2( 7, -30 + b), Vector2( 5, -38 + b)
	]), venom)
	draw_circle(Vector2(-5, -36 + b), 2.0, acid)
	draw_circle(Vector2( 0, -38 + b), 2.5, venom)
	draw_circle(Vector2( 5, -36 + b), 2.0, acid)

	# ── Tall venom staff (right) ──────────────────────────────────────────
	draw_line(Vector2(18, 22 + b), Vector2(22, -28 + b), dark_l, 5.0)
	draw_line(Vector2(18, 22 + b), Vector2(22, -28 + b), venom,  1.5)
	draw_rect(Rect2(12, -6 + b, 10, 5), dark)   # hand
	# Snake head at staff top
	draw_colored_polygon(PackedVector2Array([
		Vector2(18, -28 + b), Vector2(26, -28 + b),
		Vector2(28, -22 + b), Vector2(16, -22 + b)
	]), dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(19, -28 + b), Vector2(25, -28 + b), Vector2(22, -34 + b)
	]), venom)
	# Venom drip from staff tip
	var _vd := sin(_anim_time * 2.5) * 0.5 + 0.5
	draw_circle(Vector2(22, -34 + b), 3.5 + _vd * 1.5,
		Color(venom.r, venom.g, venom.b, 0.70))
	draw_circle(Vector2(22, -34 + b), 2.0, Color(acid.r, acid.g, acid.b, 0.90))
	# Shooting: toxic burst
	if s:
		var _sf := 1.0 - _shoot_anim / 0.30
		draw_circle(Vector2(22, -28 + b), 12 * _sf, Color(venom.r, venom.g, venom.b, _sf * 0.45))



# ── Hero Storm Knight (type 59) ───────────────────────────────────────────
# Lightning champion — dark steel armor, electrified kite shield, storm
# sword, floating lightning sigils, rotating electric crystals.

func _draw_hero_storm_knight(bob: float, shooting: bool) -> void:
	var b      := bob
	var steel  := Color(0.35, 0.38, 0.44)   # dark steel
	var steel_l := Color(0.58, 0.62, 0.70)  # highlight
	var steel_d := Color(0.18, 0.20, 0.26)  # shadow
	var elec   := Color(0.28, 0.70, 1.00)   # electric blue
	var elec_l := Color(0.80, 0.96, 1.00)   # white lightning
	var elec_y := Color(0.92, 0.96, 0.20)   # lightning yellow
	var s      := shooting

	draw_circle(Vector2(0, 24), 14, Color(0, 0, 0, 0.22))

	# ── Floating lightning sigils ─────────────────────────────────────────
	for _li in range(4):
		var _la  := _anim_time * 1.80 + _li * (TAU / 4.0)
		var _lr  := 28.0 + sin(_anim_time * 2.4 + float(_li)) * 4.0
		var _lx  := cos(_la) * _lr
		var _ly  := -2.0 + b + sin(_la * 0.60) * 14.0
		var _la2 := 0.40 + sin(_anim_time * 3.0 + float(_li)) * 0.15
		# Jagged lightning rune mark
		draw_colored_polygon(PackedVector2Array([
			Vector2(_lx + 1, _ly - 5),
			Vector2(_lx - 3, _ly - 0),
			Vector2(_lx - 1, _ly - 0),
			Vector2(_lx - 2, _ly + 5),
			Vector2(_lx + 3, _ly + 0),
			Vector2(_lx + 1, _ly + 0)
		]), Color(elec_y.r, elec_y.g, elec_y.b, _la2))
		draw_circle(Vector2(_lx, _ly), 4.0, Color(elec.r, elec.g, elec.b, _la2 * 0.25))

	# ── Rotating electric crystals (inner) ────────────────────────────────
	for _ci in range(3):
		var _ca  := _anim_time * 2.20 + _ci * (TAU / 3.0)
		var _cr  := 20.0 + sin(_anim_time * 2.0 + float(_ci)) * 3.0
		var _cx  := cos(_ca) * _cr
		var _cy  := -2.0 + b + sin(_ca * 0.55) * 13.0
		var _ca2 := 0.55 + sin(_anim_time * 3.5 + float(_ci)) * 0.18
		draw_colored_polygon(PackedVector2Array([
			Vector2(_cx,       _cy - 7.0),
			Vector2(_cx + 2.5, _cy),
			Vector2(_cx,       _cy + 6.0),
			Vector2(_cx - 2.5, _cy)
		]), Color(elec.r, elec.g, elec.b, _ca2))
		draw_circle(Vector2(_cx, _cy - 5), 2.0, Color(elec_l.r, elec_l.g, elec_l.b, _ca2 * 0.75))
		# Arc between adjacent crystals if active
		if s and _ci < 2:
			var _ca_n := _anim_time * 2.20 + (_ci + 1) * (TAU / 3.0)
			var _cxn  := cos(_ca_n) * _cr
			var _cyn  := -2.0 + b + sin(_ca_n * 0.55) * 13.0
			draw_line(Vector2(_cx, _cy), Vector2(_cxn, _cyn),
				Color(elec_l.r, elec_l.g, elec_l.b, 0.45), 1.5)

	# ── Dark steel greaves ────────────────────────────────────────────────
	draw_rect(Rect2(-12, 12 + b, 10, 12), steel_d)
	draw_rect(Rect2(  2, 12 + b, 10, 12), steel_d)
	draw_rect(Rect2(-12, 12 + b, 10,  4), steel)
	draw_rect(Rect2(  2, 12 + b, 10,  4), steel)
	draw_line(Vector2(-12, 12 + b), Vector2(-2, 12 + b), steel_l, 2.0)
	draw_line(Vector2(  2, 12 + b), Vector2(12, 12 + b), steel_l, 2.0)
	draw_line(Vector2(-9, 12 + b), Vector2(-5, 22 + b), elec_y, 1.5)
	draw_line(Vector2( 4, 12 + b), Vector2( 8, 22 + b), elec_y, 1.5)

	# ── Dark steel breastplate ────────────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -12 + b), Vector2(14, -12 + b),
		Vector2(12,  12 + b),  Vector2(-12, 12 + b)
	]), steel)
	draw_colored_polygon(PackedVector2Array([
		Vector2(4, -12 + b), Vector2(14, -12 + b),
		Vector2(12,  12 + b), Vector2(4,   12 + b)
	]), steel_d)
	# Storm crest — electric blue lightning bolt on chest
	draw_colored_polygon(PackedVector2Array([
		Vector2(2, -10 + b), Vector2(-4, -2 + b), Vector2(-1, -2 + b),
		Vector2(-2, 8 + b), Vector2(4, 0 + b), Vector2(1, 0 + b)
	]), elec_y)
	draw_polyline(PackedVector2Array([
		Vector2(2, -10 + b), Vector2(-4, -2 + b), Vector2(-1, -2 + b),
		Vector2(-2, 8 + b), Vector2(4, 0 + b), Vector2(1, 0 + b), Vector2(2, -10 + b)
	]), elec_l, 1.0)
	draw_line(Vector2(-14, -12 + b), Vector2(14, -12 + b), steel_l, 2.0)
	draw_line(Vector2(-12,  12 + b), Vector2(12, 12 + b), elec_y, 1.5)
	draw_rect(Rect2(-13, 10 + b, 26, 4), steel_d)
	draw_circle(Vector2(0, 12 + b), 3.0, elec_y)

	# ── Large round storm pauldrons ───────────────────────────────────────
	draw_circle(Vector2(-19, -9 + b), 10, steel_d)
	draw_circle(Vector2(-19, -9 + b), 10, steel_l, false, 2.0)
	draw_arc(Vector2(-19, -9 + b), 10, -PI, 0, 12, elec, 2.0)
	draw_circle(Vector2(-19, -13 + b), 6, steel)
	draw_circle(Vector2( 19, -9 + b), 10, steel_d)
	draw_circle(Vector2( 19, -9 + b), 10, steel_l, false, 2.0)
	draw_arc(Vector2( 19, -9 + b), 10, -PI, 0, 12, elec, 2.0)
	draw_circle(Vector2( 19, -13 + b), 6, steel)

	# ── Great helm — dark steel, lightning crest ──────────────────────────
	draw_circle(Vector2(0, -20 + b), 11, steel)
	draw_circle(Vector2(0, -20 + b), 11, steel_d, false, 2.0)
	draw_rect(Rect2(-10, -25 + b, 20, 7), steel_d)
	draw_rect(Rect2(-6,  -24 + b, 12, 5), Color(0.08, 0.08, 0.12))
	draw_line(Vector2(-10, -25 + b), Vector2(10, -25 + b), steel_l, 2.0)
	draw_line(Vector2(-10, -18 + b), Vector2(10, -18 + b), steel_l, 1.5)
	draw_circle(Vector2(-3, -22 + b), 2.0, elec)
	draw_circle(Vector2( 3, -22 + b), 2.0, elec)
	if s:
		draw_circle(Vector2(-3, -22 + b), 4.0, Color(elec.r, elec.g, elec.b, 0.55))
		draw_circle(Vector2( 3, -22 + b), 4.0, Color(elec.r, elec.g, elec.b, 0.55))
	draw_rect(Rect2(-9, -30 + b, 18, 5), steel_d)
	draw_line(Vector2(-9, -30 + b), Vector2(9, -30 + b), steel_l, 2.0)
	# Lightning bolt crest fin
	draw_colored_polygon(PackedVector2Array([
		Vector2(1, -30 + b), Vector2(-3, -30 + b),
		Vector2(-5, -38 + b), Vector2(-1, -35 + b),
		Vector2(3, -40 + b), Vector2(1, -35 + b), Vector2(4, -32 + b)
	]), elec_y)
	draw_polyline(PackedVector2Array([
		Vector2(1, -30 + b), Vector2(-3, -30 + b),
		Vector2(-5, -38 + b), Vector2(-1, -35 + b),
		Vector2(3, -40 + b), Vector2(1, -35 + b), Vector2(4, -32 + b), Vector2(1, -30 + b)
	]), elec_l, 1.0)

	# ── Electrified kite shield (left) ────────────────────────────────────
	var _sh := PackedVector2Array([
		Vector2(-32, -16 + b), Vector2(-16, -16 + b),
		Vector2(-16,   8 + b), Vector2(-24, 20 + b), Vector2(-32, 8 + b)
	])
	draw_colored_polygon(_sh, steel_d)
	draw_polyline(_sh + PackedVector2Array([_sh[0]]), steel_l, 2.0)
	# Shield lightning bolt emblem
	draw_colored_polygon(PackedVector2Array([
		Vector2(-24, -14 + b), Vector2(-27, -6 + b), Vector2(-25, -6 + b),
		Vector2(-25, 6  + b),  Vector2(-22,  0 + b), Vector2(-24,  0 + b)
	]), elec_y)
	draw_polyline(PackedVector2Array([
		Vector2(-24, -14 + b), Vector2(-27, -6 + b), Vector2(-25, -6 + b),
		Vector2(-25, 6  + b),  Vector2(-22,  0 + b), Vector2(-24,  0 + b),
		Vector2(-24, -14 + b)
	]), elec_l, 1.0)
	# Shield rim electric arcs
	var _arc_p := 0.5 + sin(_anim_time * 4.0) * 0.4
	draw_arc(Vector2(-24, -4 + b), 14, -PI * 0.80, PI * 0.80, 14,
		Color(elec.r, elec.g, elec.b, _arc_p * 0.65), 2.0)

	# ── Storm sword (right) with electric glow ────────────────────────────
	if s:
		var sw   := _shoot_anim / 0.35
		var _ang := -PI * 0.4 + sw * PI * 0.90
		var _hx  := 14.0 + cos(_ang) * 30
		var _hy  := -4.0 + b + sin(_ang) * 30
		draw_line(Vector2(14, -2 + b), Vector2(_hx, _hy), Color(elec.r, elec.g, elec.b, 0.40), 10.0)
		draw_line(Vector2(14, -2 + b), Vector2(_hx, _hy), steel_d,  8.0)
		draw_line(Vector2(14, -2 + b), Vector2(_hx, _hy), steel,    5.0)
		draw_line(Vector2(14, -2 + b), Vector2(_hx, _hy), elec_l,   1.5)
		if sw > 0.3:
			draw_arc(Vector2(14, -2 + b), 30, _ang - 0.7, _ang, 10,
				Color(elec_y.r, elec_y.g, elec_y.b, sw * 0.75), 6.0)
			draw_line(Vector2(_hx, _hy), Vector2(_hx + 8, _hy - 10), elec_l, 2.0)
			draw_line(Vector2(_hx, _hy), Vector2(_hx - 6, _hy - 12), elec_l, 2.0)
	else:
		draw_line(Vector2(14, -4 + b), Vector2(16, -44 + b), steel_d,  8.0)
		draw_line(Vector2(14, -4 + b), Vector2(16, -44 + b), steel,    5.0)
		draw_line(Vector2(14, -4 + b), Vector2(16, -44 + b), elec_l,   1.5)
		draw_line(Vector2(7, -6 + b), Vector2(23, -6 + b), steel, 5.0)
		draw_line(Vector2(7, -6 + b), Vector2(23, -6 + b), elec_y, 1.5)
		draw_circle(Vector2(14, -1 + b), 4.5, steel_d)
		draw_circle(Vector2(14, -1 + b), 3.0, elec)
		# Rune on blade
		draw_line(Vector2(18, -18 + b), Vector2(14, -24 + b), elec_l, 1.5)
		draw_line(Vector2(14, -24 + b), Vector2(18, -30 + b), elec_l, 1.5)



# ── Hero Phoenix Archer (type 60) ─────────────────────────────────────────
# Legendary fire archer — crimson phoenix armor, fiery bow, burning energy
# wings, floating fire feathers, orbiting phoenix embers, flame crown.

func _draw_hero_phoenix_archer(bob: float, shooting: bool) -> void:
	var b      := bob
	var crim   := Color(0.88, 0.16, 0.05)   # crimson phoenix
	var crim_d := Color(0.45, 0.06, 0.02)   # shadow
	var crim_l := Color(0.98, 0.45, 0.20)   # bright highlight
	var gold   := Color(0.96, 0.72, 0.10)   # gold trim
	var gold_l := Color(1.00, 0.90, 0.50)   # bright gold
	var fire   := Color(0.98, 0.52, 0.05)   # orange fire
	var flame  := Color(1.00, 0.88, 0.30)   # yellow flame
	var skin   := Color(0.90, 0.72, 0.52)   # skin
	var s      := shooting

	draw_circle(Vector2(0, 24), 12, Color(0, 0, 0, 0.18))

	# ── Floating fire feathers (drifting upward) ──────────────────────────
	for _fi in range(6):
		var _fa  := _anim_time * 0.80 + _fi * (TAU / 6.0)
		var _fr  := 26.0 + sin(_anim_time * 1.2 + float(_fi)) * 5.0
		var _fx  := cos(_fa) * _fr
		var _fy  := -4.0 + b + sin(_fa * 0.55) * 14.0 - sin(_anim_time * 0.8 + float(_fi)) * 3.0
		var _fa2 := 0.45 + sin(_anim_time * 2.0 + float(_fi)) * 0.16
		# Flame feather (elongated teardrop)
		draw_colored_polygon(PackedVector2Array([
			Vector2(_fx,       _fy - 9.0),
			Vector2(_fx + 2.5, _fy - 2.0),
			Vector2(_fx + 1.5, _fy + 5.0),
			Vector2(_fx - 1.5, _fy + 5.0),
			Vector2(_fx - 2.5, _fy - 2.0)
		]), Color(fire.r, fire.g, fire.b, _fa2))
		draw_line(Vector2(_fx, _fy - 8), Vector2(_fx, _fy + 4),
			Color(gold_l.r, gold_l.g, gold_l.b, _fa2 * 0.55), 1.0)
		draw_circle(Vector2(_fx, _fy - 7), 2.0, Color(flame.r, flame.g, flame.b, _fa2 * 0.70))

	# ── Phoenix ember spirits (3 small wing-shapes) ───────────────────────
	for _pi in range(3):
		var _pa  := _anim_time * 1.30 + _pi * (TAU / 3.0)
		var _pr  := 20.0 + sin(_anim_time * 1.8 + float(_pi)) * 3.0
		var _px  := cos(_pa) * _pr
		var _py  := -2.0 + b + sin(_pa * 0.58) * 12.0
		var _pa2 := 0.50 + sin(_anim_time * 2.8 + float(_pi)) * 0.16
		# Mini wing pair
		draw_colored_polygon(PackedVector2Array([
			Vector2(_px, _py), Vector2(_px - 5, _py - 3), Vector2(_px - 3, _py + 2)
		]), Color(crim_l.r, crim_l.g, crim_l.b, _pa2))
		draw_colored_polygon(PackedVector2Array([
			Vector2(_px, _py), Vector2(_px + 5, _py - 3), Vector2(_px + 3, _py + 2)
		]), Color(fire.r, fire.g, fire.b, _pa2))
		draw_circle(Vector2(_px, _py), 1.5, Color(flame.r, flame.g, flame.b, _pa2 * 0.80))

	# ── Burning energy wings (behind torso) ───────────────────────────────
	var _wflicker := 0.7 + sin(_anim_time * 3.5) * 0.20
	# Left wing
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -8 + b), Vector2(-8, 10 + b),
		Vector2(-28, 18 + b), Vector2(-32, 0 + b),
		Vector2(-24, -14 + b)
	]), Color(crim.r, crim.g, crim.b, _wflicker * 0.42))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -4 + b), Vector2(-8, 8 + b),
		Vector2(-22, 12 + b), Vector2(-24, 0 + b), Vector2(-18, -10 + b)
	]), Color(fire.r, fire.g, fire.b, _wflicker * 0.30))
	draw_line(Vector2(-8, 0 + b), Vector2(-32, 0 + b),
		Color(flame.r, flame.g, flame.b, _wflicker * 0.45), 1.5)
	# Right wing
	draw_colored_polygon(PackedVector2Array([
		Vector2( 8, -8 + b), Vector2( 8, 10 + b),
		Vector2(28, 18 + b), Vector2(32,  0 + b),
		Vector2(24, -14 + b)
	]), Color(crim.r, crim.g, crim.b, _wflicker * 0.42))
	draw_colored_polygon(PackedVector2Array([
		Vector2( 8, -4 + b), Vector2( 8, 8 + b),
		Vector2(22, 12 + b), Vector2(24, 0 + b), Vector2(18, -10 + b)
	]), Color(fire.r, fire.g, fire.b, _wflicker * 0.30))
	draw_line(Vector2(8, 0 + b), Vector2(32, 0 + b),
		Color(flame.r, flame.g, flame.b, _wflicker * 0.45), 1.5)

	# ── Legs — phoenix armor ──────────────────────────────────────────────
	draw_rect(Rect2(-9, 13 + b, 8, 11), crim_d)
	draw_rect(Rect2( 1, 13 + b, 8, 11), crim_d)
	draw_line(Vector2(-9, 13 + b), Vector2(-1, 13 + b), gold, 1.5)
	draw_line(Vector2( 1, 13 + b), Vector2( 9, 13 + b), gold, 1.5)

	# ── Crimson phoenix torso armor ───────────────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -10 + b), Vector2(12, -10 + b),
		Vector2( 10,  12 + b), Vector2(-10, 12 + b)
	]), crim)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4, -10 + b), Vector2(4, -10 + b),
		Vector2(4,  12 + b), Vector2(-4, 12 + b)
	]), crim_l.darkened(0.15))
	draw_line(Vector2(-12, -10 + b), Vector2(12, -10 + b), gold, 2.0)
	draw_line(Vector2(-10, 12 + b), Vector2(10, 12 + b), gold, 1.5)
	# Flame rune on chest
	draw_line(Vector2(-3, -8 + b), Vector2(0, -2 + b), flame, 1.5)
	draw_line(Vector2( 3, -8 + b), Vector2(0, -2 + b), flame, 1.5)
	draw_line(Vector2(0, -2 + b), Vector2(0, 6 + b), fire, 1.5)
	draw_circle(Vector2(0, -2 + b), 2.0, Color(flame.r, flame.g, flame.b, 0.80))

	# ── Phoenix pauldrons (spiked feather) ───────────────────────────────
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20, -8 + b), Vector2(-10, -8 + b),
		Vector2(-10, -2 + b), Vector2(-20, -2 + b)
	]), crim)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-18, -8 + b), Vector2(-14, -8 + b), Vector2(-15, -16 + b)
	]), fire)
	draw_line(Vector2(-20, -8 + b), Vector2(-10, -8 + b), gold, 1.5)
	draw_colored_polygon(PackedVector2Array([
		Vector2(10, -8 + b), Vector2(20, -8 + b),
		Vector2(20, -2 + b), Vector2(10, -2 + b)
	]), crim)
	draw_colored_polygon(PackedVector2Array([
		Vector2(12, -8 + b), Vector2(16, -8 + b), Vector2(15, -16 + b)
	]), fire)
	draw_line(Vector2(10, -8 + b), Vector2(20, -8 + b), gold, 1.5)
	draw_rect(Rect2(-22, -6 + b, 10, 5), skin)
	draw_rect(Rect2( 12, -6 + b, 10, 5), skin)

	# ── Face + phoenix crown ──────────────────────────────────────────────
	draw_circle(Vector2(0, -18 + b), 7, skin)
	draw_circle(Vector2(-3, -19 + b), 1.5, Color(0.85, 0.35, 0.10))
	draw_circle(Vector2( 3, -19 + b), 1.5, Color(0.85, 0.35, 0.10))
	if s:
		draw_circle(Vector2(-3, -19 + b), 3.5, Color(fire.r, fire.g, fire.b, 0.50))
		draw_circle(Vector2( 3, -19 + b), 3.5, Color(fire.r, fire.g, fire.b, 0.50))
	# Phoenix crown (flame-shaped, floating slightly)
	var _cby := -32.0 + b + sin(_anim_time * 1.5) * 2.0
	draw_rect(Rect2(-8, _cby, 16, 4), crim_d)
	draw_line(Vector2(-8, _cby), Vector2(8, _cby), gold, 2.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, _cby), Vector2(-3, _cby), Vector2(-4, _cby - 7)
	]), crim_l)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-1, _cby), Vector2(1, _cby), Vector2(0, _cby - 10)
	]), flame)
	draw_colored_polygon(PackedVector2Array([
		Vector2(3, _cby), Vector2(6, _cby), Vector2(4, _cby - 7)
	]), crim_l)
	draw_circle(Vector2(0, _cby - 8), 2.5, Color(flame.r, flame.g, flame.b, 0.80))
	draw_circle(Vector2(0, _cby), 12, Color(fire.r, fire.g, fire.b, 0.14))

	# ── Fiery bow (right side, always present) ───────────────────────────
	var _bx  := 20.0
	var _btop := Vector2(_bx, -30 + b)
	var _bbot := Vector2(_bx,  20 + b)
	# Bow body (C-arc), glowing crimson-orange
	draw_arc(Vector2(_bx - 4, -5 + b), 26, -PI * 0.55, PI * 0.55, 18, crim, 4.5)
	draw_arc(Vector2(_bx - 4, -5 + b), 26, -PI * 0.55, PI * 0.55, 18,
		Color(fire.r, fire.g, fire.b, 0.60), 2.0)
	# Glowing tip orbs
	draw_circle(_btop, 3.5, fire)
	draw_circle(_bbot, 3.5, fire)
	draw_circle(_btop, 6.0, Color(fire.r, fire.g, fire.b, 0.30))
	draw_circle(_bbot, 6.0, Color(fire.r, fire.g, fire.b, 0.30))
	# Bowstring / fire arrow
	if not s:
		draw_line(_btop, _bbot, Color(flame.r, flame.g, flame.b, 0.85), 1.5)
	else:
		var sw   := minf(_shoot_anim / 0.35, 1.0)
		var _pul := Vector2(_bx - 5 - sw * 12, -5 + b)
		draw_line(_btop, _pul, Color(flame.r, flame.g, flame.b, 0.90), 1.5)
		draw_line(_bbot, _pul, Color(flame.r, flame.g, flame.b, 0.90), 1.5)
		# Fire arrow shaft
		draw_line(_pul, Vector2(_bx + 22, -5 + b), Color(fire.r, fire.g, fire.b, 0.95), 2.5)
		# Arrow flame tip
		draw_colored_polygon(PackedVector2Array([
			Vector2(_bx + 24, -5 + b),
			Vector2(_bx + 18, -9 + b),
			Vector2(_bx + 18, -1 + b)
		]), Color(flame.r, flame.g, flame.b, 0.95))
		draw_circle(Vector2(_bx + 24, -5 + b), 4.0, Color(fire.r, fire.g, fire.b, sw * 0.75))
		# Tip flame glow
		draw_circle(_btop, 6.5, Color(fire.r, fire.g, fire.b, sw * 0.50))
		draw_circle(_bbot, 6.5, Color(fire.r, fire.g, fire.b, sw * 0.50))

	# Attack flash
	if s:
		var _sf := 1.0 - _shoot_anim / 0.35
		draw_circle(Vector2(0, -4 + b), 24.0, Color(fire.r, fire.g, fire.b, _sf * 0.14))



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
