extends Node2D

const ENEMY_SCENE   : PackedScene = preload("res://scenes/Enemy.tscn")
const TOWER_SCENE   : PackedScene = preload("res://scenes/Tower.tscn")
const SERPENT_SCENE : GDScript    = preload("res://scripts/InfernalSerpent.gd")

# ── Turret catalogue ──────────────────────────────────────────────────────────
const TURRET_TYPES : Array = [
	{
		"id":        "archer",
		"name":      "Archer",
		"desc":      "Fast, accurate shots.\nTargets nearest enemy.",
		"cost":      50,
		"damage":    2.5,
		"range":     180.0,
		"fire_rate": 2.0,
		"color":     Color(0.35, 0.75, 0.25),
		"effect":    "none",
		"idx":       0,
	},
	{
		"id":        "crossbow",
		"name":      "Crossbow",
		"desc":      "Heavy bolt pierces\nthrough multiple enemies.",
		"cost":      100,
		"damage":    7.0,
		"range":     230.0,
		"fire_rate": 0.9,
		"color":     Color(0.35, 0.55, 0.90),
		"effect":    "pierce",
		"idx":       1,
	},
	{
		"id":        "catapult",
		"name":      "Catapult",
		"desc":      "Slow but massive\narea-of-effect damage.",
		"cost":      150,
		"damage":    15.0,
		"range":     160.0,
		"fire_rate": 0.35,
		"color":     Color(0.80, 0.50, 0.20),
		"effect":    "aoe",
		"idx":       2,
	},
	{
		"id":        "mage",
		"name":      "Mage Tower",
		"desc":      "Magic bolt chains\nto 2 nearby enemies.",
		"cost":      200,
		"damage":    4.0,
		"range":     200.0,
		"fire_rate": 1.2,
		"color":     Color(0.70, 0.28, 0.92),
		"effect":    "chain",
		"idx":       3,
	},
]

const KNIGHT_DATA : Dictionary = {
	"id":        "knight",
	"name":      "Knight Hero",
	"desc":      "Hurls a sword across the entire battlefield.",
	"cost":      0,
	"damage":    20.0,
	"range":     1500.0,
	"fire_rate": 0.9,
	"color":     Color(0.72, 0.76, 0.90),
	"effect":    "none",
	"idx":       4,
}

# Rarity-based costs for rolled summon turrets
const RARITY_COSTS : Dictionary = {
	"common":    80,
	"rare":      180,
	"epic":      350,
	"legendary": 600,
}

# ── Enemy path (set in _ready() based on selected world) ─────────────────────
var PATH : Array = []

# ── Stage definitions ─────────────────────────────────────────────────────────
const STAGES : Array = [
	# Stage 1  — 80 px/s
	{ "waves": [
		[8,  12.0,  80.0,  2],
		[10, 17.0,  80.0,  2],
		[13, 22.0,  80.0,  3],
	], "boss": [250.0,   50.0, 100] },
	# Stage 2  — 90 px/s
	{ "waves": [
		[10, 26.0,  90.0,  3],
		[13, 34.0,  90.0,  3],
		[15, 43.0,  90.0,  4],
	], "boss": [500.0,   48.0, 150] },
	# Stage 3  — 95 px/s
	{ "waves": [
		[11,  53.0,  95.0,  4],
		[14,  66.0,  95.0,  4],
		[17,  82.0,  95.0,  4],
		[15,  96.0,  95.0,  4],
	], "boss": [950.0,   46.0, 200] },
	# Stage 4  — 100 px/s
	{ "waves": [
		[15, 108.0, 100.0,  4],
		[17, 130.0, 100.0,  5],
		[20, 154.0, 100.0,  5],
		[17, 180.0, 100.0,  6],
	], "boss": [1600.0,  44.0, 250] },
	# Stage 5  — 108 px/s
	{ "waves": [
		[18, 198.0, 108.0,  5],
		[20, 228.0, 108.0,  6],
		[23, 264.0, 108.0,  6],
		[20, 300.0, 108.0,  6],
		[26, 342.0, 108.0,  7],
	], "boss": [2600.0,  42.0, 300] },
	# Stage 6  — 115 px/s
	{ "waves": [
		[21, 360.0, 115.0,  6],
		[23, 414.0, 115.0,  7],
		[26, 474.0, 115.0,  7],
		[23, 540.0, 115.0,  8],
		[28, 612.0, 115.0,  8],
	], "boss": [4000.0,  40.0, 350] },
	# Stage 7  — 122 px/s
	{ "waves": [
		[23,  648.0, 122.0,  8],
		[26,  738.0, 122.0,  8],
		[28,  840.0, 122.0,  9],
		[26,  954.0, 122.0,  9],
		[30, 1080.0, 122.0, 10],
	], "boss": [6200.0,  38.0, 400] },
	# Stage 8  — 128 px/s
	{ "waves": [
		[26, 1140.0, 128.0,  9],
		[28, 1296.0, 128.0, 10],
		[30, 1464.0, 128.0, 10],
		[28, 1656.0, 128.0, 11],
		[32, 1872.0, 128.0, 11],
		[30, 2112.0, 128.0, 12],
	], "boss": [9000.0,  36.0, 450] },
	# Stage 9  — 135 px/s  (1.5× S8 HP)
	{ "waves": [
		[28, 1710.0, 135.0, 11],
		[30, 1944.0, 135.0, 12],
		[32, 2196.0, 135.0, 12],
		[30, 2484.0, 135.0, 12],
		[34, 2808.0, 135.0, 13],
		[32, 3168.0, 135.0, 13],
	], "boss": [13500.0, 34.0, 500] },
	# Stage 10 — Final — 142 px/s  (1.4× S9 HP)
	{ "waves": [
		[30, 2394.0, 142.0, 12],
		[32, 2721.6, 142.0, 13],
		[34, 3074.4, 142.0, 14],
		[32, 3477.6, 142.0, 14],
		[36, 3931.2, 142.0, 15],
		[34, 4435.2, 142.0, 15],
	], "boss": [18900.0, 30.0, 600] },
]

@onready var _terrain    : TileMapLayer = $TerrainLayer
@onready var _hud                       = $UI/HUD
@onready var _build_grid                = $BuildGrid

var _gold              : float = 100.0
var _lives             : int   = 20
var _stage             : int   = 1
var _wave_in_stage     : int   = 0
var _wave_active       : bool  = false
var _enemies_alive     : int   = 0
var _next_wave_id      : int   = 0
var _wave_remaining    : Dictionary = {}   # wave_id → remaining enemy count
var _wave_id_to_num   : Dictionary = {}   # wave_id → wave number within stage
var _last_cleared_wave : int = 0          # last wave in current stage where all enemies were killed
var _enemies_killed    : int   = 0
var _bosses_killed     : int   = 0
var _gems_this_run     : int   = 0
var _relic_wave_count       : int  = 0    # total waves started this run (for bloodlust_tide every-5)
var _relic_first_place_done : bool = false  # founders_pledge: first tower placed this stage?
var _spawn_queue   : Array = []
var _spawn_timer   : float = 0.0
var _wave_start_lives : Dictionary = {}  # wid → lives at wave start (for hercules perfect-clear check)

var _boss_active          : bool  = false
var _boss_timer           : float = 0.0
var _boss_ref             : Node2D = null
var _spawning_done        : bool  = false
var _pending_boss_reward  : bool  = false
var _pending_card_anim    : Array = []
var _game_over     : bool  = false
var _game_left     : bool  = false
var _debug_dummy_mode : bool = false

# ── Hard mode debuff timers ───────────────────────────────────────────────────
var _rot_cursed_towers  : Array = []   # towers currently penalized by curse_tower_rot
var _rot_timer          : float = 10.0
var _regen_timer        : float = 1.0
var _boss_minion_timer  : float = 1.0
var _taunt_tank_timer      : float = -1.0  # counts down to 0 then spawns; -1 = inactive
var _taunt_tank_ref        : Node2D = null

# ── Poison Cloud (Venom Drake) ────────────────────────────────────────────────
var _poison_cloud : Node2D = null
const POISON_CLOUD_SCENE := preload("res://scripts/PoisonCloud.gd")

# ── Tower movement & selection ────────────────────────────────────────────────
var _tower_map           : Dictionary = {}
var _held_tower          : Node2D     = null
var _held_from_tile      : Vector2i   = Vector2i(-1, -1)
var _selected_tower      : Node2D     = null
var _drag_pending_tile   : Vector2i   = Vector2i(-1, -1)
var _press_position      : Vector2    = Vector2.ZERO
const _CLICK_MAX_DIST    : float      = 6.0
var _info_refresh_timer  : float      = 0.0


func _ready() -> void:
	PATH = GameData.get_world_path(GameData.selected_world)
	_build_grid.setup_world(GameData.selected_world, PATH)
	MapBuilder.new().build(_terrain)
	_hud.setup(self)
	_hud.wave_pressed.connect(_on_wave_btn_pressed)
	_hud.start_battle_pressed.connect(_on_start_battle_pressed)
	_hud.roll_turret_requested.connect(_on_roll_turret_requested)
	_hud.roll_rare_requested.connect(_on_roll_rare_requested)
	_hud.roll_epic_requested.connect(_on_roll_epic_requested)
	_hud.recipe_fusion_requested.connect(_on_recipe_fusion_requested)
	_hud.upgrade_merge_requested.connect(_on_upgrade_merge_requested)
	_hud.debug_gold_requested.connect(func(): _gold += 10000; _refresh_hud())
	_hud.debug_skip_stage_requested.connect(_on_debug_skip_stage)
	_hud.sell_tower_requested.connect(_on_sell_tower_requested)
	_hud.debug_summon_requested.connect(_on_debug_summon_requested)
	_hud.debug_spawn_dummy.connect(_on_debug_spawn_dummy)
	GameData.current_run_highest_stage = 0
	GameData.reset_run_buffs()
	# Reset per-run daily quest counters
	GameData.dq_sell_run_count = 0
	_hud.buff_chosen.connect(_on_buff_chosen)
	_hud.debuff_chosen.connect(_on_debuff_chosen)
	_hud.game_left.connect(_on_game_left)
	_gold  = 100
	_lives = 20
	_refresh_hud()
	_spawn_knight()
	if GameData.debug_dummy_mode:
		_debug_dummy_mode          = true
		GameData.debug_dummy_mode  = false
		_hud.show_debug_dummy_ui()
	elif not GameData.launching_into_game:
		_hud.show_main_menu()
	elif not GameData.tutorial_complete and GameData.selected_world == 1:
		_hud.start_tutorial()
	GameData.launching_into_game = false


func _spawn_knight() -> void:
	if GameData.selected_hero_id == "" or not GameData.HERO_DEFS.has(GameData.selected_hero_id):
		return
	# Prefer centre of island; fall back to first open tile if that one is path-blocked.
	var tile := Vector2i(4, 2)
	if not _build_grid.can_place(tile):
		tile = _find_hero_spawn()
	_build_grid.place(tile)
	var tower : Node2D = TOWER_SCENE.instantiate()
	add_child(tower)
	tower.z_index = 7
	var hero_base : Dictionary = GameData.HERO_DEFS.get(GameData.selected_hero_id, KNIGHT_DATA)
	var h_data := hero_base.duplicate()
	var h_idx  : int = hero_base.get("idx", 4)
	h_data["damage"]    = hero_base.get("damage",    20.0) * GameData.final_damage_mult(h_idx)
	h_data["range"]     = hero_base.get("range",  1500.0) * GameData.final_range_mult(h_idx)
	h_data["fire_rate"] = hero_base.get("fire_rate", 0.9) * GameData.final_fire_rate_mult(h_idx)
	var _h_alloc := GameData.get_hero_talent_alloc(GameData.selected_hero_id)
	h_data["damage"]    = h_data["damage"]    + float(_h_alloc.get("dmg", 0))
	h_data["range"]     = h_data["range"]     + float(_h_alloc.get("rng", 0)) * 15.0
	h_data["fire_rate"] = h_data["fire_rate"] * (1.0 + float(_h_alloc.get("fr", 0)) * 0.05)
	tower.init_type(h_data)
	tower.gold_proc.connect(func(amount: float): _gold += amount; _refresh_hud())
	tower.serpent_summon.connect(func(dmg: float): _spawn_infernal_serpent(dmg))
	tower.drop_from_sky(_build_grid.tile_center(tile), 2.0)
	_tower_map[tile] = tower


func _find_hero_spawn() -> Vector2i:
	# Simple scan: prefer rows nearest the vertical centre.
	var cols : int = _build_grid._cols
	var rows : int = _build_grid._rows
	for r in range(rows):
		var row : int = (rows / 2) + (r / 2 + 1) * (1 if r % 2 == 0 else -1)
		row = clamp(row, 0, rows - 1)
		for c in range(cols):
			var t := Vector2i(c, row)
			if _build_grid.can_place(t):
				return t
	return Vector2i(0, 0)


func _process(delta: float) -> void:
	if _game_over or _game_left:
		return
	GameData.active_tower_count = _tower_map.size()
	var mp := get_viewport().get_mouse_position()

	if _drag_pending_tile != Vector2i(-1, -1) and not is_instance_valid(_held_tower):
		if mp.distance_to(_press_position) > BuildGrid.TILE_SIZE * 0.5:
			if not _hud.tutorial_block_drag:
				_pick_up_tower(_drag_pending_tile)
			_drag_pending_tile = Vector2i(-1, -1)

	if is_instance_valid(_held_tower):
		_held_tower.position = mp + Vector2(0, -12)

	# Refresh selected tower stats panel only when already open (user clicked i)
	if is_instance_valid(_selected_tower) and _hud.is_tower_info_visible():
		_info_refresh_timer -= delta
		if _info_refresh_timer <= 0.0:
			_info_refresh_timer = 0.25
			var _merge_cnt := _count_same_type_on_map(_selected_tower.tower_data.get("id", ""))
			_hud.show_tower_info(_selected_tower, _merge_cnt)

	if is_instance_valid(_held_tower) and _build_grid.is_in_grid(mp):
		var t : Vector2i = _build_grid.world_to_tile(mp)
		_build_grid.hovered_tile = t if _build_grid.can_place(t) else Vector2i(-1, -1)
	else:
		_build_grid.hovered_tile = Vector2i(-1, -1)

	if _boss_active:
		_boss_timer -= delta
		if _boss_timer <= 0.0:
			_on_boss_timer_expired()
			return
		_refresh_hud()

	# Sync disabled_tiles so BuildGrid can draw the visual overlay
	# Includes both Curse of Silence (disabled_timer) and Vampiric Surge (vampiric_timer)
	_build_grid.disabled_tiles.clear()
	for _dt in _tower_map:
		var _dtw : Node2D = _tower_map[_dt]
		if is_instance_valid(_dtw) and (_dtw._disabled_timer > 0.0 or _dtw._vampiric_timer > 0.0):
			_build_grid.disabled_tiles[_dt] = true

	if GameData.debuff_regen:
		_regen_timer -= delta
		if _regen_timer <= 0.0:
			_regen_timer = 1.0
			for _e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(_e):
					_e.hp = min(_e.max_hp, _e.hp + 2.0)
	if GameData.debuff_tower_rot:
		_rot_timer -= delta
		if _rot_timer <= 0.0:
			_rot_timer = 10.0
			_apply_tower_rot()
	if GameData.debuff_boss_minions and _boss_active and is_instance_valid(_boss_ref):
		_boss_minion_timer -= delta
		if _boss_minion_timer <= 0.0:
			_boss_minion_timer = 1.0
			_spawn_boss_minion()
	if GameData.debuff_taunt_tank and _taunt_tank_timer > 0.0 and _wave_active and not _boss_active:
		_taunt_tank_timer -= delta
		if _taunt_tank_timer <= 0.0:
			_taunt_tank_timer = -1.0
			_spawn_taunt_tank()

	if _spawn_queue.is_empty():
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = 0.55
		_spawn_next_enemy()


# ── Wave / stage control ──────────────────────────────────────────────────────

func start_wave() -> void:
	if _boss_active or _stage > STAGES.size():
		return
	var stage_data : Dictionary = STAGES[_stage - 1]
	var total_waves : int = stage_data["waves"].size()

	if _wave_in_stage < total_waves:
		_wave_in_stage += 1
		# Relic: Bloodlust Tide — every 5th wave globally
		_relic_wave_count += 1
		if GameData.relics_collected.has("bloodlust_tide") and _relic_wave_count % 5 == 0:
			_trigger_bloodlust_tide()
		# First wave of a new stage: start the Poison Cloud if a Venom Drake exists.
		if _wave_in_stage == 1:
			var vd_pos : Vector2 = _get_venom_drake_pos()
			if vd_pos != Vector2.ZERO:
				_spawn_or_reset_poison_cloud(vd_pos)
		_wave_active = true
		_spawning_done = false
		_spawn_queue.clear()
		var def : Array = stage_data["waves"][_wave_in_stage - 1]
		var wid : int = _next_wave_id
		_next_wave_id += 1
		_wave_remaining[wid] = 0   # incremented as each enemy actually spawns
		_wave_start_lives[wid] = _lives
		_wave_id_to_num[wid] = _wave_in_stage
		for _i in range(def[0]):
			_spawn_queue.append({"def": def, "wave_id": wid})
		_spawn_timer = 0.0
		if GameData.debuff_taunt_tank:
			_taunt_tank_timer = 3.0
	else:
		_start_boss_wave(stage_data["boss"])

	_refresh_hud()


func _start_boss_wave(boss_def: Array) -> void:
	_boss_active = true
	_boss_timer  = 60.0
	_wave_active = true
	var enemy : Node2D = ENEMY_SCENE.instantiate()
	add_child(enemy)
	enemy.z_index = 6
	var w    : int   = GameData.selected_world
	var hp   : float = boss_def[0] * GameData.effective_world_hp_mult(w)
	var spd  : float = boss_def[1] * GameData.relic_enemy_slow_mult() * GameData.effective_world_spd_mult(w)
	var gold : float = boss_def[2] * GameData.total_gold_drop_mult() * GameData.effective_world_gold_mult(w)
	enemy.setup(PATH, hp, spd, gold, true, 0, _stage)
	enemy.melee_resist = GameData.effective_world_melee_resist(w)
	enemy.died.connect(_on_boss_died)
	enemy.reached_end.connect(_on_boss_reached_end)
	_boss_ref = enemy
	_hud.show_boss_notification()


func _spawn_next_enemy() -> void:
	if _spawn_queue.is_empty():
		return
	var entry : Dictionary = _spawn_queue.pop_front()
	var def   : Array      = entry["def"]
	var wid   : int        = entry["wave_id"]
	var enemy : Node2D = ENEMY_SCENE.instantiate()
	add_child(enemy)
	enemy.z_index = 6
	var w     : int   = GameData.selected_world
	var etype : int   = int((_stage - 1) / 2.0)
	var _tower_hp_mult : float = 1.0 + floorf(GameData.active_tower_count / 5.0) * 0.01 if GameData.debuff_tower_penalty else 1.0
	var hp    : float = def[1] * GameData.effective_world_hp_mult(w) * _tower_hp_mult
	var spd   : float = def[2] * GameData.relic_enemy_slow_mult() * GameData.effective_world_spd_mult(w)
	var gold  : float = def[3] * GameData.total_gold_drop_mult() * GameData.effective_world_gold_mult(w)
	enemy.setup(PATH, hp, spd, gold, false, etype, _stage)
	enemy.melee_resist = GameData.effective_world_melee_resist(w)
	enemy.wave_id = wid
	_wave_remaining[wid] = _wave_remaining.get(wid, 0) + 1   # safe: key may have been erased if tower one-shotted earlier spawns
	enemy.died.connect(func(r: float): _on_enemy_died(r, enemy); _on_wave_enemy_removed(wid))
	enemy.reached_end.connect(func(): _on_enemy_reached_end(enemy); _on_wave_enemy_removed(wid))
	_enemies_alive += 1
	if _spawn_queue.is_empty():
		_spawning_done = true
		_refresh_hud()


func _on_enemy_died(reward: float, dead_enemy: Node2D = null) -> void:
	var actual_reward : float = reward
	if GameData.debuff_gold_miss and reward > 0.0 and randf() < 0.05:
		actual_reward = 0.0
	_gold          += actual_reward
	_enemies_alive -= 1
	_enemies_killed += 1
	GameData.blue_gems += 1
	_gems_this_run     += 1
	_hud.refresh_gems(_gems_this_run)
	# Daily quest 1: kill progress
	if not GameData.dq_kills_complete:
		GameData.dq_kills_progress = mini(GameData.dq_kills_progress + 1, GameData.DQ_KILL_TARGET)
		if GameData.dq_kills_progress >= GameData.DQ_KILL_TARGET:
			GameData.dq_kills_complete = true
	# Skeleton respawn modifier (world modifier + mutated daily quest override)
	var skel_chance : float = maxf(
		GameData.effective_world_skeleton_chance(GameData.selected_world),
		0.20 if GameData.dq_mode == "mutated_w1" else 0.0
	)
	if skel_chance > 0.0 and is_instance_valid(dead_enemy) and not dead_enemy.is_boss and not dead_enemy.is_taunt_tank:
		if randf() < skel_chance:
			_spawn_skeleton_from(dead_enemy)
	if GameData.debuff_revive and is_instance_valid(dead_enemy) and not dead_enemy.is_boss and not dead_enemy.is_taunt_tank:
		if randf() < 0.05:
			_spawn_revived_from(dead_enemy)
	if GameData.debuff_tower_disable and not _tower_map.is_empty() and randf() < 0.20:
		var _tw_vals : Array = _tower_map.values().filter(func(t): return is_instance_valid(t))
		_tw_vals.shuffle()
		for _di in range(mini(2, _tw_vals.size())):
			_tw_vals[_di]._disabled_timer = 5.0
	if GameData.debuff_vampiric_surge and randf() < 0.03:
		var _vamp_pool : Array = _tower_map.values().filter(func(t): return is_instance_valid(t))
		_vamp_pool.shuffle()
		var _vamp_count : int = mini(8, _vamp_pool.size())
		for _vi in range(_vamp_count):
			_vamp_pool[_vi]._vampiric_timer = 5.0
		if _vamp_count > 0:
			_hud.show_notification("🩸  Vampiric Surge!  %d towers are healing enemies!" % _vamp_count)
	# ── Relic: every-10-kill procs ────────────────────────────────────────────
	if _enemies_killed % 10 == 0:
		_apply_relic_kill_procs()
	_check_wave_done()
	_refresh_hud()
	_try_show_boss_reward()


func _spawn_skeleton_from(src: Node2D) -> void:
	var skel : Node2D = ENEMY_SCENE.instantiate()
	add_child(skel)
	skel.z_index = 4
	var skel_hp  : float = src.max_hp * 0.5
	var skel_spd : float = src.speed
	skel.setup(PATH, skel_hp, skel_spd, 0.0, false, 2, src.boss_stage)  # type 2 = skeleton
	skel.position    = src.position
	skel._current_wp = src._current_wp
	skel.melee_resist = src.melee_resist
	_enemies_alive += 1
	skel.died.connect(func(r: float): _on_enemy_died(r))
	skel.reached_end.connect(func(): _on_enemy_reached_end(skel))


func _spawn_revived_from(src: Node2D) -> void:
	var rev : Node2D = ENEMY_SCENE.instantiate()
	add_child(rev)
	rev.z_index = 4
	var rev_hp  : float = src.max_hp * 0.20
	var rev_spd : float = src._base_speed * 3.0
	rev.setup(PATH, rev_hp, rev_spd, 0.0, false, src.enemy_type, src.boss_stage)
	rev.position    = src.position
	rev._current_wp = src._current_wp
	rev.melee_resist = src.melee_resist
	_enemies_alive += 1
	rev.died.connect(func(r: float): _on_enemy_died(r))
	rev.reached_end.connect(func(): _on_enemy_reached_end(rev))


func _apply_tower_rot() -> void:
	for tower in _rot_cursed_towers:
		if is_instance_valid(tower):
			tower._rot_dmg_penalty  = 0.0
			tower._rot_rate_penalty = 0.0
	_rot_cursed_towers.clear()
	var towers : Array = []
	for tw in _tower_map.values():
		if is_instance_valid(tw):
			towers.append(tw)
	towers.shuffle()
	var count : int = mini(2, towers.size())
	for i in range(count):
		towers[i]._rot_dmg_penalty  = 0.20
		towers[i]._rot_rate_penalty = 0.50
		_rot_cursed_towers.append(towers[i])


func _spawn_boss_minion() -> void:
	var minion : Node2D = ENEMY_SCENE.instantiate()
	add_child(minion)
	minion.z_index = 6
	var etype  : int   = int((_stage - 1) / 2.0)
	var min_hp : float = _boss_ref.max_hp * 0.05
	var min_spd: float = _boss_ref._base_speed * 2.0
	minion.setup(PATH, min_hp, min_spd, 0.0, false, etype, _stage)
	minion.melee_resist = GameData.effective_world_melee_resist(GameData.selected_world)
	_enemies_alive += 1
	minion.died.connect(func(r: float): _on_enemy_died(r))
	minion.reached_end.connect(func(): _on_enemy_reached_end(minion))


func _spawn_taunt_tank() -> void:
	var tank : Node2D = ENEMY_SCENE.instantiate()
	add_child(tank)
	tank.z_index = 7
	var tank_hp : float = 5000.0 + (_stage - 1) * 200.0
	tank.setup(PATH, tank_hp, 50.0, 0.0, false, 0, _stage)
	tank.is_taunt_tank = true
	_taunt_tank_ref    = tank
	_enemies_alive += 1
	tank.died.connect(func(r: float): _taunt_tank_ref = null; _on_enemy_died(r, tank))
	tank.reached_end.connect(func(): _taunt_tank_ref = null; _on_enemy_reached_end(tank))


func _force_remove_towers(count: int) -> void:
	var tiles : Array = _tower_map.keys()
	tiles.shuffle()
	var to_remove : int = mini(count, tiles.size())
	for i in range(to_remove):
		var tile : Vector2i = tiles[i]
		var tw   : Node2D   = _tower_map.get(tile)
		if is_instance_valid(tw):
			if tw == _selected_tower:
				_selected_tower = null
				_hud.hide_tower_info()
				_hud.hide_upgrade_popup()
				_hud.hide_sell_btn()
			_rot_cursed_towers.erase(tw)
			tw.queue_free()
		_tower_map.erase(tile)
		_build_grid.unplace(tile)


func _apply_null_zones() -> void:
	# Collect buildable tiles
	var free : Array = []
	var free_set : Dictionary = {}
	for c in range(_build_grid._cols):
		for r in range(_build_grid._rows):
			var t := Vector2i(c, r)
			if not _build_grid._path_blocked.has(t):
				free.append(t)
				free_set[t] = true
	# Find all adjacent pairs
	var pairs : Array = []
	for t in free:
		for nb in [Vector2i(t.x + 1, t.y), Vector2i(t.x, t.y + 1)]:
			if free_set.has(nb):
				pairs.append([t, nb])
	pairs.shuffle()
	# Pick 2 non-overlapping pairs, avoiding already-marked null tiles
	var chosen : Array = []
	var used   : Dictionary = {}
	for pair in pairs:
		if chosen.size() >= 2:
			break
		var a : Vector2i = pair[0]; var b : Vector2i = pair[1]
		if not used.has(a) and not used.has(b) \
				and not _build_grid.null_zone_tiles.has(a) \
				and not _build_grid.null_zone_tiles.has(b):
			chosen.append(pair)
			used[a] = true; used[b] = true
	# Mark tiles and penalise any tower already standing on them
	for pair in chosen:
		for tile in pair:
			_build_grid.null_zone_tiles[tile] = true
			if _tower_map.has(tile) and is_instance_valid(_tower_map[tile]):
				var tw : Node2D = _tower_map[tile]
				tw._tile_null_penalty  = tw.attack_range * 0.5
				tw.attack_range       -= tw._tile_null_penalty


func _on_enemy_reached_end(enemy: Node2D = null) -> void:
	if _debug_dummy_mode:
		_enemies_alive -= 1
		_check_wave_done()
		_refresh_hud()
		return
	_lives         -= 1
	_enemies_alive -= 1
	# Relic: Castle Tax — bonus gold per hit the escaping enemy absorbed
	if enemy != null and GameData.relics_collected.has("castle_tax"):
		var lv        : int = GameData.get_relic_level("castle_tax")
		var ct_amount : int = maxi(lv, enemy.hits_taken * lv)
		_gold += ct_amount
		_hud.show_relic_gold_popup(ct_amount)
	_check_lives()
	_check_wave_done()
	_refresh_hud()
	_try_show_boss_reward()


func _clear_ice_zones() -> void:
	for z in get_tree().get_nodes_in_group("ice_zones"):
		if is_instance_valid(z):
			z.queue_free()


func _spawn_or_reset_poison_cloud(tower_pos: Vector2) -> void:
	if is_instance_valid(_poison_cloud):
		_poison_cloud.reset_cloud()
	else:
		var cloud : Node2D = POISON_CLOUD_SCENE.new()
		cloud.z_index = 0
		add_child(cloud)
		cloud.setup(PATH, tower_pos)
		_poison_cloud = cloud


func _check_venom_drake_exists() -> bool:
	for tile in _tower_map:
		var tw = _tower_map[tile]
		if is_instance_valid(tw) and tw.tower_data.get("effect", "") == "poison_cloud":
			return true
	return false


func _get_venom_drake_pos() -> Vector2:
	for tile in _tower_map:
		var tw = _tower_map[tile]
		if is_instance_valid(tw) and tw.tower_data.get("effect", "") == "poison_cloud":
			return _build_grid.tile_center(tile)
	return Vector2.ZERO


func _clear_poison_cloud() -> void:
	if is_instance_valid(_poison_cloud):
		_poison_cloud.queue_free()
	_poison_cloud = null


func _spawn_infernal_serpent(dmg: float) -> void:
	var serpent : Node2D = SERPENT_SCENE.new()
	serpent.setup(dmg, PATH)   # must be before add_child so _ready() sees the path
	add_child(serpent)


func _on_wave_enemy_removed(wid: int) -> void:
	if not _wave_remaining.has(wid):
		return
	_wave_remaining[wid] -= 1
	if _wave_remaining[wid] <= 0:
		_wave_remaining.erase(wid)
		var wave_num : int = _wave_id_to_num.get(wid, 0)
		_wave_id_to_num.erase(wid)
		if wave_num > _last_cleared_wave:
			_last_cleared_wave = wave_num
		var no_lives_lost : bool = (_lives >= _wave_start_lives.get(wid, _lives))
		_wave_start_lives.erase(wid)
		# Hercules: +5 permanent damage only on a perfect wave clear (no lives lost)
		if no_lives_lost:
			for tile in _tower_map:
				var tw = _tower_map[tile]
				if is_instance_valid(tw) and tw.tower_data.get("id", "") == "hercules":
					tw._hercules_wave_bonus += 5.0


func _get_all_towers() -> Array:
	var result : Array = []
	for tile in _tower_map:
		var tw = _tower_map[tile]
		if is_instance_valid(tw):
			result.append(tw)
	return result


func _apply_relic_kill_procs() -> void:
	var towers : Array = _get_all_towers()
	if GameData.relics_collected.has("gold_rush"):
		var gr_amount : int = GameData.get_relic_level("gold_rush")
		_gold += gr_amount
		_hud.show_relic_gold_popup(gr_amount)
	if GameData.relics_collected.has("power_surge") and not towers.is_empty():
		towers[randi() % towers.size()]._relic_dmg_bonus += float(GameData.get_relic_level("power_surge"))
	if GameData.relics_collected.has("swift_wind") and not towers.is_empty():
		towers[randi() % towers.size()]._relic_rate_bonus += GameData.get_relic_level("swift_wind") * 0.05


func _trigger_bloodlust_tide() -> void:
	var bonus : float = GameData.get_relic_level("bloodlust_tide") * 0.20
	for tw in _get_all_towers():
		tw._relic_rate_bonus += bonus
	_refresh_hud()
	await get_tree().create_timer(10.0, true).timeout
	for tw in _get_all_towers():
		tw._relic_rate_bonus = maxf(0.0, tw._relic_rate_bonus - bonus)


func _check_wave_done() -> void:
	if _boss_active:
		return
	if _spawn_queue.is_empty() and _enemies_alive <= 0:
		_wave_active   = false
		_spawning_done = false
		_clear_ice_zones()
		_refresh_hud()
		GameData.save_game()   # persist kill progress after every wave


func _on_boss_died(reward: float) -> void:
	if not _boss_active:
		return
	_gold          += reward
	_bosses_killed += 1
	var boss_gems  : int = 10 + (_bosses_killed - 1) * 12
	GameData.blue_gems += boss_gems
	_gems_this_run     += boss_gems
	_hud.refresh_gems(_gems_this_run)
	# Store card drops for stages 8, 9, 10 — animation fires after buff is chosen
	var boss_pos : Vector2 = _boss_ref.global_position if is_instance_valid(_boss_ref) else Vector2(512, 325)
	var cards    : Array   = _roll_boss_cards(_stage)
	for card in cards:
		GameData.run_pending_cards.append(card)
		_pending_card_anim.append(card)
	if not cards.is_empty():
		_hud.show_boss_card_idle(cards, boss_pos)
	_boss_active           = false
	_boss_ref              = null
	_wave_active           = false
	_spawning_done         = false
	_pending_boss_reward   = true
	_clear_ice_zones()
	_hud.hide_wave_btn()
	_refresh_hud()
	_try_show_boss_reward()


func _roll_gacha_rarity() -> String:
	var r : int = randi() % 100
	if r < 1:   return "legendary"
	if r < 5:   return "epic"
	if r < 25:  return "rare"
	return "common"


func _roll_boss_cards(stage: int) -> Array:
	var cards : Array = []
	var n_towers : int = 0
	var n_heroes : int = 0
	if stage == 8:
		n_towers = randi_range(1, 2)
	elif stage == 9:
		n_towers = randi_range(2, 3)
	elif stage == 10:
		n_towers = randi_range(3, 4)
		n_heroes = 1
	for _i in n_towers:
		var rarity := _roll_gacha_rarity()
		var pool   := SummonSystem.get_pool(rarity)
		cards.append({"type": "tower", "id": pool[randi() % pool.size()], "rarity": rarity})
	for _i in n_heroes:
		var rarity := _roll_gacha_rarity()
		var pool   := GameData.heroes_of_rarity(rarity)
		if pool.is_empty():
			pool = GameData.heroes_of_rarity("common")
		cards.append({"type": "hero", "id": pool[randi() % pool.size()], "rarity": rarity})
	return cards


var _pre_reward_time_scale      : float = 1.0
var _special_tiles_tut_pending  : bool  = false

func _try_show_boss_reward() -> void:
	if not _pending_boss_reward:
		return
	if _enemies_alive > 0:
		return
	# Mark consumed immediately so re-entrant calls (e.g. DOT killing another
	# enemy this same frame) don't double-trigger.
	_pending_boss_reward = false
	# Wait one frame so every queue_free() from this frame is flushed and no
	# dying enemy is still visible on screen when the cards appear.
	await get_tree().process_frame
	if _game_left or _game_over:
		return
	_clear_poison_cloud()
	_pre_reward_time_scale     = Engine.time_scale
	Engine.time_scale          = 1.0
	_cancel_hold()
	_deselect_tower()
	_hud.hide_wave_btn()
	# Final stage — no buff cards.
	# Fly the boss-drop chips first, then show the victory screen.
	if _stage >= STAGES.size():
		_pending_card_anim.clear()
		await get_tree().create_timer(0.5, true).timeout
		if _game_left or _game_over:
			return
		_hud.fly_loot_cards_to_bag()
		# Wait long enough for all chips to land (up to 5 chips × 0.15s stagger + 1.0s flight)
		await get_tree().create_timer(2.0, true).timeout
		if _game_left:
			return
		_advance_stage()
		return
	var rarity : String = GameData.roll_rarity(_stage)
	var buffs  : Array  = GameData.pick_buffs(rarity, 3)
	_hud.show_boss_buff_cards(buffs, _stage)


func _on_game_left() -> void:
	_game_left           = true
	_pending_boss_reward = false
	_boss_active         = false
	_spawn_queue.clear()
	_wave_start_lives.clear()
	Engine.time_scale = 1.0
	GameData.apply_run_cards()
	GameData.save_game()   # persist kill progress when leaving mid-run
	# Kill every enemy node so their processes stop and no signals fire late
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.queue_free()
	if is_instance_valid(_boss_ref):
		_boss_ref.queue_free()
		_boss_ref = null
	_clear_ice_zones()
	_clear_poison_cloud()


func _on_buff_chosen(buff_id: String) -> void:
	GameData.apply_buff(buff_id)
	_hud.refresh_buff_history()
	if GameData.buff_pending_lives > 0:
		_lives += GameData.buff_pending_lives
		GameData.buff_pending_lives = 0
	if buff_id == "summon_cost_10g":
		_turret_roll_cost = maxi(1, _turret_roll_cost - 5)
		_rare_roll_cost   = maxi(1, _rare_roll_cost   - 5)
		_epic_roll_cost   = maxi(1, _epic_roll_cost   - 5)
		_refresh_roll_costs()
	if GameData.selected_difficulty == "hard" and _stage % 3 == 0:
		var debuffs : Array = GameData.pick_hard_debuffs(3)
		_hud.show_hard_debuff_cards(debuffs, _stage)
		return  # time scale restored in _on_debuff_chosen
	Engine.time_scale = _pre_reward_time_scale
	_complete_stage_advance()


func _on_debuff_chosen(debuff_id: String) -> void:
	Engine.time_scale = _pre_reward_time_scale
	GameData.apply_hard_debuff(debuff_id)
	if debuff_id == "curse_tower_rot":
		_rot_timer = 10.0
		_rot_cursed_towers.clear()
	elif debuff_id == "curse_boss_minions":
		_boss_minion_timer = 1.0
	elif debuff_id == "curse_remove_towers":
		_force_remove_towers(3)
	elif debuff_id == "curse_taunt_tank":
		_taunt_tank_timer = -1.0
	elif debuff_id == "curse_null_zones":
		_apply_null_zones()
	_refresh_hud()
	_complete_stage_advance()


func _complete_stage_advance() -> void:
	_advance_stage()
	_fire_card_anim_deferred()
	if _build_grid._tiles_animating:
		_hud.block_input_for_tile_anim()
		await _build_grid.tiles_animation_done
		_hud.unblock_input_tile_anim()
	if _special_tiles_tut_pending:
		_special_tiles_tut_pending = false
		var tile_rects : Dictionary = {}
		for tile in _build_grid.special_tiles:
			var kind : String = _build_grid.special_tiles[tile]
			tile_rects[kind] = Rect2(
				_build_grid._island.position.x + tile.x * _build_grid.TILE_SIZE,
				_build_grid._island.position.y + tile.y * _build_grid.TILE_SIZE,
				_build_grid.TILE_SIZE, _build_grid.TILE_SIZE)
		_hud.show_special_tiles_tutorial(tile_rects)
		await _hud.special_tiles_tutorial_closed
	_hud.show_wave_btn()
	if not _game_over:
		_refresh_hud()


func _fire_card_anim_deferred() -> void:
	if _pending_card_anim.is_empty():
		return
	_pending_card_anim.clear()
	await get_tree().create_timer(0.5, true).timeout
	if not _game_left and not _game_over:
		_hud.fly_loot_cards_to_bag()


func _on_boss_reached_end() -> void:
	if not _boss_active:
		return
	_lives         -= 5
	_boss_active    = false
	_boss_ref       = null
	_wave_active    = false
	_spawning_done  = false
	_clear_ice_zones()
	_check_lives()
	_advance_stage()
	_refresh_hud()


func _on_boss_timer_expired() -> void:
	if not _boss_active:
		return
	_boss_timer = 0.0
	if is_instance_valid(_boss_ref):
		_boss_ref.died.disconnect(_on_boss_died)
		_boss_ref.reached_end.disconnect(_on_boss_reached_end)
		_boss_ref.queue_free()
	_boss_ref      = null
	_boss_active   = false
	_wave_active   = false
	_spawning_done = false
	_clear_ice_zones()
	_trigger_game_over()


func _check_lives() -> void:
	if _lives <= 0 and not _game_over and not _game_left:
		_trigger_game_over()


func _calc_gems() -> int:
	return _gems_this_run


func _trigger_game_over() -> void:
	_game_over = true
	_lives      = 0
	Engine.time_scale = 0.0
	GameData.apply_run_cards()
	GameData.run_gold = int(_gold)
	GameData.dq_mode  = ""
	GameData.dq_unlocked = true
	if _stage > GameData.current_run_highest_stage:
		GameData.current_run_highest_stage = _stage
	if GameData.current_run_highest_stage > GameData.all_time_highest_stage:
		GameData.all_time_highest_stage = GameData.current_run_highest_stage
	var gems_earned : int = _calc_gems()
	GameData.save_game()
	var turrets : Array = []
	for tower in _tower_map.values():
		if is_instance_valid(tower) and not tower.tower_data.is_empty():
			turrets.append(tower.tower_data)
	_hud.hide_sell_btn()
	_hud.hide_upgrade_popup()
	_hud.flush_idle_chips_to_loot()
	_hud.show_run_results(_stage, _enemies_killed, _bosses_killed, gems_earned, turrets, false, _last_cleared_wave)


func _on_start_battle_pressed() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _trigger_victory() -> void:
	_game_over = true
	Engine.time_scale = 0.0
	GameData.apply_run_cards()
	GameData.run_gold = int(_gold)
	GameData.current_run_highest_stage = 10
	if 10 > GameData.all_time_highest_stage:
		GameData.all_time_highest_stage = 10
	if GameData.selected_difficulty == "easy":
		GameData.easy_mode_beaten = true
	# Daily quest completion on victory
	if GameData.dq_mode == "mutated_w1":
		GameData.dq_mutated_complete = true
	elif GameData.dq_mode == "sell_w1" and GameData.dq_sell_run_count >= GameData.DQ_SELL_TARGET:
		GameData.dq_sell_complete = true
	GameData.dq_mode = ""
	var gems_earned : int = _calc_gems()
	GameData.save_game()
	var turrets : Array = []
	for tower in _tower_map.values():
		if is_instance_valid(tower) and not tower.tower_data.is_empty():
			turrets.append(tower.tower_data)
	_hud.flush_idle_chips_to_loot()
	_hud.show_run_results(_stage, _enemies_killed, _bosses_killed, gems_earned, turrets, true, _wave_in_stage)


func _advance_stage() -> void:
	_wave_in_stage = 0
	_last_cleared_wave = 0
	# Relic: War Spoils — end of each stage, gain a random common tower (or gold if full)
	if GameData.relics_collected.has("war_spoils") and _stage <= STAGES.size():
		var free_tiles : Array = _get_free_tiles()
		if not free_tiles.is_empty():
			_place_turret_random(SummonSystem.roll_by_pool("common"))
		else:
			var ws_amount : int = 20 + GameData.get_relic_level("war_spoils") * 5
			_gold += ws_amount
			_hud.show_relic_gold_popup(ws_amount)
	if _stage <= STAGES.size():
		_stage += 1
	if _stage == 5:
		_setup_special_tiles()
	# Relic: Treasury — gain level×5% of current gold at the start of each new stage
	if GameData.relics_collected.has("treasury") and _stage <= STAGES.size():
		var tr_amount : int = int(_gold * GameData.get_relic_level("treasury") * 0.05)
		_gold += tr_amount
		if tr_amount > 0:
			get_tree().create_timer(1.0, true).timeout.connect(
				func(): _hud.show_relic_gold_popup(tr_amount), CONNECT_ONE_SHOT)
	# Relic: Rite of Five — auto-summon a rare tower at stage 5 (and multiples by level)
	if GameData.relics_collected.has("rite_of_five") and _stage <= STAGES.size():
		var lv  : int  = GameData.get_relic_level("rite_of_five")
		var trigger : bool = (lv >= 4 and _stage % 5 == 0) \
			or (lv == 3 and _stage in [5, 10, 15]) \
			or (lv == 2 and _stage in [5, 10]) \
			or (lv == 1 and _stage == 5)
		if trigger:
			_place_turret_random(SummonSystem.roll_by_pool("rare"))
	# Relic: Founder's Pledge — reset first-place flag each stage, refresh displayed costs
	_relic_first_place_done = false
	_refresh_roll_costs()
	var reached : int = min(_stage, 10)
	if reached > GameData.current_run_highest_stage:
		GameData.current_run_highest_stage = reached
		if reached > GameData.all_time_highest_stage:
			GameData.all_time_highest_stage = reached
			GameData.save_game()
	if _stage > STAGES.size():
		_trigger_victory()
		return


func _update_upgrade_indicators() -> void:
	var counts : Dictionary = {}
	for tile in _tower_map:
		var tw = _tower_map[tile]
		if not is_instance_valid(tw):
			continue
		var id     : String = tw.tower_data.get("id", "")
		var rarity : String = tw.tower_data.get("rarity", "")
		if id == "" or rarity == "legendary" or rarity == "fusion":
			continue
		counts[id] = counts.get(id, 0) + 1
	var first_upgradeable : Node2D = null
	for tile in _tower_map:
		var tw = _tower_map[tile]
		if not is_instance_valid(tw):
			continue
		var id     : String = tw.tower_data.get("id", "")
		var rarity : String = tw.tower_data.get("rarity", "")
		tw.can_upgrade = counts.get(id, 0) >= 3 and rarity != "legendary" and rarity != "fusion"
		if tw.can_upgrade and first_upgradeable == null:
			first_upgradeable = tw
	if first_upgradeable != null and not GameData.merge_tutorial_seen:
		GameData.merge_tutorial_seen = true
		_show_merge_tutorial_delayed(first_upgradeable)


func _show_merge_tutorial_delayed(tower: Node2D) -> void:
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(tower):
		_hud.show_merge_tutorial(tower.position)


func _count_same_type_on_map(id: String) -> int:
	if id == "":
		return 0
	var count := 0
	for tile in _tower_map:
		var tw = _tower_map[tile]
		if is_instance_valid(tw) and tw.tower_data.get("id", "") == id:
			count += 1
	return count


func _on_upgrade_merge_requested() -> void:
	if not is_instance_valid(_selected_tower):
		return
	var td      : Dictionary = _selected_tower.tower_data
	var id      : String     = td.get("id", "")
	var rarity  : String     = td.get("rarity", "")
	if id == "" or rarity == "legendary" or rarity == "fusion":
		return
	if _count_same_type_on_map(id) < 3:
		return

	var next_rarity : String = SummonSystem.get_rarity_next(rarity)

	# Find the selected tower's tile
	var sel_tile := Vector2i(-1, -1)
	for tile in _tower_map:
		if _tower_map[tile] == _selected_tower:
			sel_tile = tile
			break

	_hud.hide_tower_info()
	_hud.hide_upgrade_popup()
	_deselect_tower()

	# Remove 3 of this type from the map
	var removed := 0
	var tiles_to_remove : Array = []
	if sel_tile != Vector2i(-1, -1):
		tiles_to_remove.append(sel_tile)
		removed += 1
	for tile in _tower_map:
		if removed >= 3:
			break
		if tile == sel_tile:
			continue
		var tw = _tower_map[tile]
		if is_instance_valid(tw) and tw.tower_data.get("id", "") == id:
			tiles_to_remove.append(tile)
			removed += 1
	for tile in tiles_to_remove:
		var tw = _tower_map[tile]
		if is_instance_valid(tw):
			tw.queue_free()
		_tower_map.erase(tile)
		_build_grid.unplace(tile)

	# Place one random turret of the next rarity
	var raw : Dictionary = SummonSystem.get_random_turret_by_rarity(next_rarity)
	var tidx : int = raw.get("idx", 0)
	raw["damage"]    = raw["damage"]    * GameData.final_damage_mult(tidx)
	raw["range"]     = raw["range"]     * GameData.final_range_mult(tidx)
	raw["fire_rate"] = raw["fire_rate"] * GameData.final_fire_rate_mult(tidx)
	_place_turret_random(raw)
	_hud.show_notification("⬆  %s!" % raw.get("name", "Upgraded"))
	_refresh_hud()


func _get_all_owned_turret_ids() -> Dictionary:
	var ids : Dictionary = {}
	for tile in _tower_map:
		var tw = _tower_map[tile]
		if is_instance_valid(tw):
			var tid : String = tw.tower_data.get("id", "")
			if tid != "":
				ids[tid] = true
	for t in SummonSystem.bench:
		var tid : String = t.get("id", "")
		if tid != "":
			ids[tid] = true
	return ids


func _refresh_hud() -> void:
	var total_waves  : int  = STAGES[min(_stage, STAGES.size()) - 1]["waves"].size()
	var can_next     : bool = _wave_active and not _boss_active
	var boss_hp      : float = 0.0
	var boss_max_hp  : float = 1.0
	if _boss_active and is_instance_valid(_boss_ref):
		boss_hp     = _boss_ref.hp
		boss_max_hp = _boss_ref.max_hp
	# Once the last wave's spawn queue empties, show the boss button immediately
	# rather than waiting for every enemy to die.
	var display_wave_active : bool = _wave_active and not (_spawning_done and _wave_in_stage >= total_waves)
	_hud.refresh(int(_gold), _lives, _stage, _wave_in_stage, total_waves,
				 display_wave_active, _boss_active, _boss_timer, can_next,
				 boss_hp, boss_max_hp)
	_hud.update_recipe_notifications(SummonSystem.get_available_recipe_fusions(_tower_map), _get_all_owned_turret_ids())
	_update_upgrade_indicators()
	_refresh_roll_costs()


# ── Gacha roll system ─────────────────────────────────────────────────────────

const TURRET_ROLL_COST_BASE : int = 40
var   _turret_roll_cost     : int = 40
var   _rare_roll_cost       : int = SummonSystem.RARE_SUMMON_COST
var   _epic_roll_cost       : int = SummonSystem.EPIC_SUMMON_COST

func _relic_roll_discount() -> int:
	var disc : int = 0
	# Merchant's Deal: every roll costs level fewer gold
	if GameData.relics_collected.has("merchants_deal"):
		disc += GameData.get_relic_level("merchants_deal")
	# Founder's Pledge: first tower placed each stage is additionally discounted
	if not _relic_first_place_done and GameData.relics_collected.has("founders_pledge"):
		disc += GameData.get_relic_level("founders_pledge")
	return disc


func _refresh_roll_costs() -> void:
	var disc : int = _relic_roll_discount()
	_hud.update_pull_cost(maxi(1, _turret_roll_cost - disc), disc)
	_hud.update_rare_cost(maxi(1, _rare_roll_cost   - disc), disc)
	_hud.update_epic_cost(maxi(1, _epic_roll_cost   - disc), disc)

func _get_turret_pool() -> Array:
	var pool : Array = []
	for t in TURRET_TYPES:
		pool.append(t.duplicate())
	for id in SummonSystem.TURRET_DEFS:
		var def : Dictionary = SummonSystem.TURRET_DEFS[id].duplicate()
		if def.get("rarity", "") == "fusion":
			continue   # fusion turrets are crafted only, never rolled
		if not def.has("cost"):
			var rar : String = def.get("rarity", "common")
			def["cost"] = RARITY_COSTS.get(rar, 100)
		pool.append(def)
	return pool


func _on_roll_rare_requested() -> void:
	var disc : int = _relic_roll_discount()
	var cost : int = maxi(1, _rare_roll_cost - disc)
	if _gold < cost:
		_hud.show_roll_error("Not enough gold! (need %dg)" % cost)
		return
	var free : Array = _get_free_tiles()
	if free.is_empty():
		_hud.show_roll_error("Map is full! Move or wait.")
		return
	_gold -= cost
	_rare_roll_cost += 3
	_relic_first_place_done = true
	_refresh_roll_costs()
	var raw : Dictionary = SummonSystem.roll_by_pool("rare")
	_place_turret_random(raw)
	_hud.show_turret_result(raw)
	_refresh_hud()


func _on_roll_epic_requested() -> void:
	var disc : int = _relic_roll_discount()
	var cost : int = maxi(1, _epic_roll_cost - disc)
	if _gold < cost:
		_hud.show_roll_error("Not enough gold! (need %dg)" % cost)
		return
	var free : Array = _get_free_tiles()
	if free.is_empty():
		_hud.show_roll_error("Map is full! Move or wait.")
		return
	_gold -= cost
	_epic_roll_cost += 5
	_relic_first_place_done = true
	_refresh_roll_costs()
	var raw : Dictionary = SummonSystem.roll_by_pool("epic")
	_place_turret_random(raw)
	_hud.show_turret_result(raw)
	_refresh_hud()


func _on_roll_turret_requested() -> void:
	var disc : int = _relic_roll_discount()
	var cost : int = maxi(1, _turret_roll_cost - disc)
	if _gold < cost:
		_hud.show_roll_error("Not enough gold! (need %d)" % cost)
		return
	var free : Array = _get_free_tiles()
	if free.is_empty():
		_hud.show_roll_error("Map is full! Move or wait.")
		return
	_gold -= cost
	_turret_roll_cost += 1
	_relic_first_place_done = true
	_refresh_roll_costs()
	var raw : Dictionary
	if not GameData.tutorial_complete and GameData.selected_world == 1:
		raw = SummonSystem.TURRET_DEFS["archer"].duplicate()
	else:
		raw = SummonSystem.roll_by_pool("common")
	_place_turret_random(raw)
	if not GameData.tutorial_complete and GameData.selected_world == 1:
		_build_grid.tutorial_lock_tile = Vector2i(1, 0)
	_hud.show_turret_result(raw)
	_refresh_hud()


func _on_recipe_fusion_requested(result_id: String) -> void:
	var available : Array = SummonSystem.get_available_recipe_fusions(_tower_map)
	var fusion    : Dictionary = {}
	for f in available:
		if f["recipe"]["result"] == result_id:
			fusion = f
			break
	if fusion.is_empty():
		return
	var result_def    : Dictionary = SummonSystem.TURRET_DEFS.get(result_id, {})
	if result_def.is_empty():
		return

	# Remove placed material towers from the board
	for tile in fusion["placed_tiles"]:
		if _tower_map.has(tile):
			var tw = _tower_map[tile]
			if is_instance_valid(tw):
				tw.queue_free()
			_tower_map.erase(tile)
			_build_grid.unplace(tile)

	# Remove bench material turrets (consume from bench)
	var sorted_bench_idxs : Array = fusion["bench_indices"].duplicate()
	sorted_bench_idxs.sort()
	sorted_bench_idxs.reverse()  # remove highest indices first to keep lower valid
	for bi in sorted_bench_idxs:
		SummonSystem.remove_from_bench(bi)

	# Apply global multipliers to the fusion turret
	var raw : Dictionary = result_def.duplicate()
	var tidx : int = raw.get("idx", 0)
	raw["damage"]    = raw["damage"]    * GameData.final_damage_mult(tidx)
	raw["range"]     = raw["range"]     * GameData.final_range_mult(tidx)
	raw["fire_rate"] = raw["fire_rate"] * GameData.final_fire_rate_mult(tidx)

	# Place the fusion turret on the map
	_place_turret_random(raw)
	_hud.show_turret_result(raw)
	_hud.show_notification("✨ Fusion! %s!" % result_def.get("name", ""))
	_refresh_hud()


func _place_turret_random(data: Dictionary) -> void:
	var free : Array = _get_free_tiles()
	if free.is_empty():
		return
	var tile : Vector2i = free[randi() % free.size()]
	_build_grid.place(tile)
	var tower : Node2D = TOWER_SCENE.instantiate()
	add_child(tower)
	tower.z_index = 7
	tower.init_type(data)
	tower.gold_proc.connect(func(amount: float): _gold += amount; _refresh_hud())
	tower.serpent_summon.connect(func(dmg: float): _spawn_infernal_serpent(dmg))
	tower.drop_from_sky(_build_grid.tile_center(tile))
	_tower_map[tile] = tower
	_apply_tile_bonus(tower, tile)
	# If a Venom Drake is placed mid-stage, start the cloud immediately.
	if data.get("effect", "") == "poison_cloud" and _wave_in_stage > 0:
		_spawn_or_reset_poison_cloud(_build_grid.tile_center(tile))


func _get_free_tiles() -> Array:
	var tiles : Array = []
	for c in range(_build_grid._cols):
		for r in range(_build_grid._rows):
			var t := Vector2i(c, r)
			if _build_grid.can_place(t):
				tiles.append(t)
	return tiles


# ── Special tile bonuses (World 2 Stage 5) ────────────────────────────────────

func _setup_special_tiles() -> void:
	if GameData.selected_world != 2 or not _build_grid.special_tiles.is_empty():
		return
	var buildable : Array = []
	for c in range(_build_grid._cols):
		for r in range(_build_grid._rows):
			var t := Vector2i(c, r)
			if not _build_grid._path_blocked.has(t):
				buildable.append(t)
	buildable.shuffle()
	if buildable.size() < 3:
		return
	_build_grid.special_tiles[buildable[0]] = "red"
	_build_grid.special_tiles[buildable[1]] = "blue"
	_build_grid.special_tiles[buildable[2]] = "green"
	if not GameData.special_tiles_seen:
		GameData.special_tiles_seen    = true
		_special_tiles_tut_pending     = true
		GameData.save_game()
		_build_grid.start_tile_animation()
	for tile in _build_grid.special_tiles:
		if _tower_map.has(tile) and is_instance_valid(_tower_map[tile]):
			_apply_tile_bonus(_tower_map[tile], tile)


func _apply_tile_bonus(tower: Node2D, tile: Vector2i) -> void:
	var bonus : String = _build_grid.special_tiles.get(tile, "")
	match bonus:
		"red":
			tower._tile_dmg_bonus = 0.30
		"blue":
			tower._tile_range_bonus = 35.0
			tower.attack_range     += 35.0
		"green":
			tower._tile_spd_bonus = 0.25
	if _build_grid.null_zone_tiles.has(tile):
		tower._tile_null_penalty = tower.attack_range * 0.5
		tower.attack_range      -= tower._tile_null_penalty


func _remove_tile_bonus(tower: Node2D) -> void:
	tower.attack_range     -= tower._tile_range_bonus
	tower.attack_range     += tower._tile_null_penalty
	tower._tile_dmg_bonus   = 0.0
	tower._tile_range_bonus = 0.0
	tower._tile_spd_bonus   = 0.0
	tower._tile_null_penalty = 0.0


# ── Tower placement (click-select) ────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not _hud.is_upgrade_popup_clicked(event.position):
			_hud.hide_upgrade_popup()
		if not _hud.is_sell_btn_clicked(event.position):
			_hud.hide_sell_btn()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE and not _debug_dummy_mode:
			_on_wave_btn_pressed()
		return

	if not (event is InputEventMouseButton and
			event.button_index == MOUSE_BUTTON_LEFT):
		return

	var mp : Vector2 = get_viewport().get_mouse_position()

	if event.pressed:
		if _hud.tutorial_lock_unit_btns:
			return

		var info_open : bool = is_instance_valid(_selected_tower)

		if not _build_grid.is_in_grid(mp):
			_deselect_tower()
			return

		var tile : Vector2i = _build_grid.world_to_tile(mp)

		if _tower_map.has(tile):
			var tower : Node2D = _tower_map[tile]
			if is_instance_valid(tower) and not tower._landing:
				if info_open:
					_hud.hide_tower_info()
				_select_tower(tower)
				_drag_pending_tile = tile
				_press_position    = mp
		elif info_open:
			_deselect_tower()
		else:
			_deselect_tower()
		return

	_drag_pending_tile = Vector2i(-1, -1)
	if not is_instance_valid(_held_tower):
		if is_instance_valid(_selected_tower) and mp.distance_to(_press_position) <= _CLICK_MAX_DIST:
			var _merge_cnt := _count_same_type_on_map(_selected_tower.tower_data.get("id", ""))
			_hud.show_unit_btns(_selected_tower.position, _selected_tower, _merge_cnt)
			if _selected_tower.can_upgrade:
				_hud.show_upgrade_popup(_selected_tower.position)
		return

	if _build_grid.is_in_grid(mp):
		var tile : Vector2i = _build_grid.world_to_tile(mp)
		if tile == _held_from_tile:
			_cancel_hold()
		elif _tower_map.has(tile) and is_instance_valid(_tower_map[tile]):
			_swap_towers(tile)
		elif _build_grid.can_place(tile):
			_place_held_tower(tile)
		else:
			_cancel_hold()
	else:
		_cancel_hold()


# ── Tower move helpers ────────────────────────────────────────────────────────

func _pick_up_tower(tile: Vector2i) -> void:
	var tower : Node2D = _tower_map[tile]
	_remove_tile_bonus(tower)
	_tower_map.erase(tile)
	_build_grid.unplace(tile)
	_held_from_tile = tile
	_held_tower     = tower
	tower.is_held   = true
	tower.z_index   = 10


func _place_held_tower(tile: Vector2i) -> void:
	_held_tower.z_index = 6
	var was_moved := tile != _held_from_tile
	_build_grid.place(tile)
	_tower_map[tile] = _held_tower
	_apply_tile_bonus(_held_tower, tile)
	_held_tower.move_to(_build_grid.tile_center(tile))
	_held_tower = null
	_held_from_tile = Vector2i(-1, -1)
	_hud.update_recipe_notifications(SummonSystem.get_available_recipe_fusions(_tower_map), _get_all_owned_turret_ids())
	if _build_grid.tutorial_lock_tile != Vector2i(-1, -1):
		_build_grid.tutorial_lock_tile = Vector2i(-1, -1)
		_hud.tower_moved_tutorial.emit()
	elif was_moved and not GameData.tutorial_complete and GameData.selected_world == 1:
		_hud.tower_moved_tutorial.emit()


func _swap_towers(other_tile: Vector2i) -> void:
	var other_tower : Node2D = _tower_map[other_tile]
	_remove_tile_bonus(other_tower)
	var from_tile : Vector2i = _held_from_tile
	_build_grid.place(from_tile)
	_tower_map[from_tile] = other_tower
	other_tower.move_to(_build_grid.tile_center(from_tile))
	_tower_map[other_tile] = _held_tower
	_held_tower.move_to(_build_grid.tile_center(other_tile))
	_apply_tile_bonus(other_tower, from_tile)
	_apply_tile_bonus(_held_tower, other_tile)
	_held_tower     = null
	_held_from_tile = Vector2i(-1, -1)
	_hud.update_recipe_notifications(SummonSystem.get_available_recipe_fusions(_tower_map), _get_all_owned_turret_ids())


func _cancel_hold() -> void:
	if not is_instance_valid(_held_tower):
		return
	_build_grid.place(_held_from_tile)
	_tower_map[_held_from_tile] = _held_tower
	_apply_tile_bonus(_held_tower, _held_from_tile)
	_held_tower.move_to(_build_grid.tile_center(_held_from_tile))
	_held_tower = null
	_held_from_tile = Vector2i(-1, -1)


func _select_tower(tower: Node2D) -> void:
	if is_instance_valid(_selected_tower) and _selected_tower != tower:
		_selected_tower.selected = false
		_hud.hide_upgrade_popup()
	_selected_tower = tower
	tower.selected  = true


func _deselect_tower() -> void:
	if is_instance_valid(_selected_tower):
		_selected_tower.selected = false
	_selected_tower = null
	_hud.hide_tower_info()
	_hud.hide_upgrade_popup()
	_hud.hide_sell_btn()


func _on_sell_tower_requested() -> void:
	if not is_instance_valid(_selected_tower):
		return
	# Find the tile this tower occupies
	var sell_tile := Vector2i(-1, -1)
	for tile in _tower_map:
		if _tower_map[tile] == _selected_tower:
			sell_tile = tile
			break
	if sell_tile == Vector2i(-1, -1):
		return
	var sold_effect : String = _selected_tower.tower_data.get("effect", "")
	_selected_tower.queue_free()
	_tower_map.erase(sell_tile)
	_build_grid.unplace(sell_tile)
	_selected_tower = null
	_gold += 25
	# Daily quest 3: count tower sells in sell_w1 mode
	if GameData.dq_mode == "sell_w1":
		GameData.dq_sell_run_count += 1
	if sold_effect == "poison_cloud" and not _check_venom_drake_exists():
		_clear_poison_cloud()
	_hud.hide_tower_info()
	_hud.hide_upgrade_popup()
	_hud.hide_sell_btn()
	_refresh_hud()


func _on_debug_summon_requested(tower_id: String) -> void:
	var td : Dictionary = SummonSystem.TURRET_DEFS.get(tower_id, {})
	if td.is_empty():
		return
	var raw := td.duplicate()
	var tidx : int = raw.get("idx", 0)
	raw["damage"]    = raw["damage"]    * GameData.final_damage_mult(tidx)
	raw["range"]     = raw["range"]     * GameData.final_range_mult(tidx)
	raw["fire_rate"] = raw["fire_rate"] * GameData.final_fire_rate_mult(tidx)
	_place_turret_random(raw)
	_hud.show_notification("🐛 Summoned %s" % raw.get("name", tower_id))
	_refresh_hud()


func _on_debug_skip_stage(target: int) -> void:
	if _game_over or _game_left:
		return
	_stage         = target
	_wave_in_stage = 0
	_wave_active   = false
	_gold          += 5000
	GameData.current_run_highest_stage = maxi(GameData.current_run_highest_stage, target - 1)
	if target >= 5:
		_setup_special_tiles()
	_hud.show_notification("🐛 Skipped to Stage %d" % target)
	_refresh_hud()


func _on_debug_spawn_dummy() -> void:
	if _game_over or _game_left or PATH.is_empty():
		return
	var dummy : Node2D = ENEMY_SCENE.instantiate()
	add_child(dummy)
	dummy.z_index = 6
	dummy.setup(PATH, 50000.0, 35.0, 0.0, false, 0, 1)
	dummy.is_dummy = true
	dummy.reached_end.connect(func(): dummy.queue_free())


func _on_wave_btn_pressed() -> void:
	if _boss_active:
		return
	_hud.on_wave_pressed()
	start_wave()
