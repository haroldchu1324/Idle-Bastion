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

# ── Enemy path ────────────────────────────────────────────────────────────────
# Road centerlines: CY_TOP=140, CY_BOT=500, CX_LEFT=250, CX_RIGHT=1030
const PATH : Array = [
	Vector2(-40, 140),
	Vector2(850, 140),
	Vector2(850, 500),
	Vector2(250, 500),
	Vector2(250, 140),
	Vector2(850, 140),
	Vector2(850, 500),
	Vector2(250, 500),
	Vector2(250, 140),
	Vector2(-40, 140),
]

# ── Stage definitions ─────────────────────────────────────────────────────────
const STAGES : Array = [
	# Stage 1  (old totals: 15 / 21 / 36g)
	{ "waves": [
		[8,  12.0,  80.0,  2],
		[10, 17.0,  85.0,  2],
		[13, 22.0,  90.0,  3],
	], "boss": [250.0,  50.0, 100] },
	# Stage 2  (old totals: 28 / 36 / 55g)
	{ "waves": [
		[10, 26.0,  90.0,  3],
		[13, 34.0,  95.0,  3],
		[15, 43.0, 100.0,  4],
	], "boss": [500.0,  48.0, 150] },
	# Stage 3  (old totals: 40 / 50 / 72 / 60g)
	{ "waves": [
		[11,  53.0,  95.0,  4],
		[14,  66.0, 100.0,  4],
		[17,  82.0, 105.0,  4],
		[15,  96.0, 108.0,  4],
	], "boss": [950.0,  46.0, 200] },
	# Stage 4  (old totals: 60 / 84 / 98 / 96g)
	{ "waves": [
		[15, 108.0, 100.0,  4],
		[17, 130.0, 105.0,  5],
		[20, 154.0, 110.0,  5],
		[17, 180.0, 113.0,  6],
	], "boss": [1600.0, 44.0, 250] },
	# Stage 5  (old totals: 96 / 112 / 144 / 126 / 180g)
	{ "waves": [
		[18, 198.0, 108.0,  5],
		[20, 228.0, 112.0,  6],
		[23, 264.0, 116.0,  6],
		[20, 300.0, 119.0,  6],
		[26, 342.0, 122.0,  7],
	], "boss": [2600.0, 42.0, 300] },
	# Stage 6  (old totals: 126 / 160 / 180 / 176 / 220g)
	{ "waves": [
		[21, 360.0, 115.0,  6],
		[23, 414.0, 119.0,  7],
		[26, 474.0, 123.0,  7],
		[23, 540.0, 126.0,  8],
		[28, 612.0, 129.0,  8],
	], "boss": [4000.0, 40.0, 350] },
	# Stage 7  (old totals: 176 / 216 / 240 / 234 / 286g)
	{ "waves": [
		[23,  648.0, 122.0,  8],
		[26,  738.0, 126.0,  8],
		[28,  840.0, 130.0,  9],
		[26,  954.0, 133.0,  9],
		[30, 1080.0, 136.0, 10],
	], "boss": [6200.0, 38.0, 400] },
	# Stage 8  (old totals: 234 / 280 / 308 / 300 / 360 / 352g)
	{ "waves": [
		[26, 1140.0, 128.0,  9],
		[28, 1296.0, 132.0, 10],
		[30, 1464.0, 136.0, 10],
		[28, 1656.0, 139.0, 11],
		[32, 1872.0, 142.0, 11],
		[30, 2112.0, 144.0, 12],
	], "boss": [9000.0, 36.0, 450] },
	# Stage 9  (old totals: 300 / 352 / 384 / 374 / 442 / 432g)
	{ "waves": [
		[28, 2220.0, 135.0, 11],
		[30, 2520.0, 139.0, 12],
		[32, 2856.0, 143.0, 12],
		[30, 3240.0, 146.0, 12],
		[34, 3672.0, 149.0, 13],
		[32, 4152.0, 151.0, 13],
	], "boss": [13000.0, 34.0, 500] },
	# Stage 10 — Final  (old totals: 374 / 432 / 468 / 456 / 532 / 520g)
	{ "waves": [
		[30, 4320.0, 142.0, 12],
		[32, 4920.0, 146.0, 13],
		[34, 5580.0, 150.0, 14],
		[32, 6360.0, 153.0, 14],
		[36, 7200.0, 156.0, 15],
		[34, 8160.0, 158.0, 15],
	], "boss": [22000.0, 30.0, 600] },
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
var _enemies_killed    : int   = 0
var _bosses_killed     : int   = 0
var _gems_this_run     : int   = 0
var _spawn_queue   : Array = []
var _spawn_timer   : float = 0.0

var _boss_active          : bool  = false
var _boss_timer           : float = 0.0
var _boss_ref             : Node2D = null
var _spawning_done        : bool  = false
var _pending_boss_reward  : bool  = false
var _game_over     : bool  = false

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
	_hud.sell_tower_requested.connect(_on_sell_tower_requested)
	_hud.debug_summon_requested.connect(_on_debug_summon_requested)
	GameData.current_run_highest_stage = 0
	GameData.reset_run_buffs()
	_hud.buff_chosen.connect(_on_buff_chosen)
	_gold  = 100
	_lives = 20
	_refresh_hud()
	_spawn_knight()


func _spawn_knight() -> void:
	var tile := Vector2i(4, 2)
	_build_grid.place(tile)
	var tower : Node2D = TOWER_SCENE.instantiate()
	add_child(tower)
	var hero_base : Dictionary = GameData.HERO_DEFS.get(GameData.selected_hero_id, KNIGHT_DATA)
	var h_data := hero_base.duplicate()
	var h_idx  : int = hero_base.get("idx", 4)
	h_data["damage"]    = hero_base.get("damage",    20.0) * GameData.final_damage_mult(h_idx)
	h_data["range"]     = hero_base.get("range",  1500.0) * GameData.final_range_mult(h_idx)
	h_data["fire_rate"] = hero_base.get("fire_rate", 0.9) * GameData.final_fire_rate_mult(h_idx)
	tower.init_type(h_data)
	tower.gold_proc.connect(func(amount: float): _gold += amount; _refresh_hud())
	tower.serpent_summon.connect(func(dmg: float): _spawn_infernal_serpent(dmg))
	tower.drop_from_sky(_build_grid.tile_center(tile), 2.0)
	_tower_map[tile] = tower


func _process(delta: float) -> void:
	if _game_over:
		return
	var mp := get_viewport().get_mouse_position()

	if _drag_pending_tile != Vector2i(-1, -1) and not is_instance_valid(_held_tower):
		if mp.distance_to(_press_position) > BuildGrid.TILE_SIZE * 0.5:
			_pick_up_tower(_drag_pending_tile)
			_drag_pending_tile = Vector2i(-1, -1)

	if is_instance_valid(_held_tower):
		_held_tower.position = mp + Vector2(0, -12)

	# Refresh selected tower stats panel so World Tree buffs stay current
	if is_instance_valid(_selected_tower):
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
		for _i in range(def[0]):
			_spawn_queue.append({"def": def, "wave_id": wid})
		_spawn_timer = 0.0
	else:
		_start_boss_wave(stage_data["boss"])

	_refresh_hud()


func _start_boss_wave(boss_def: Array) -> void:
	_boss_active = true
	_boss_timer  = 60.0
	_wave_active = true
	var enemy : Node2D = ENEMY_SCENE.instantiate()
	add_child(enemy)
	var spd  : float = boss_def[1] * GameData.relic_enemy_slow_mult()
	var gold : float = boss_def[2] * GameData.total_gold_drop_mult()
	enemy.setup(PATH, boss_def[0], spd, gold, true, 0, _stage)
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
	var etype : int = int((_stage - 1) / 2.0)
	var spd  : float = def[2] * GameData.relic_enemy_slow_mult()
	var gold : float = def[3] * GameData.total_gold_drop_mult()
	enemy.setup(PATH, def[1], spd, gold, false, etype, _stage)
	enemy.wave_id = wid
	_wave_remaining[wid] = _wave_remaining.get(wid, 0) + 1   # safe: key may have been erased if tower one-shotted earlier spawns
	enemy.died.connect(func(r: float): _on_enemy_died(r); _on_wave_enemy_removed(wid))
	enemy.reached_end.connect(func(): _on_enemy_reached_end(); _on_wave_enemy_removed(wid))
	_enemies_alive += 1
	if _spawn_queue.is_empty():
		_spawning_done = true
		_refresh_hud()


func _on_enemy_died(reward: float) -> void:
	_gold          += reward
	_enemies_alive -= 1
	_enemies_killed += 1
	GameData.blue_gems += 1
	_gems_this_run     += 1
	_hud.refresh_gems()
	_check_wave_done()
	_refresh_hud()
	_try_show_boss_reward()


func _on_enemy_reached_end() -> void:
	_lives         -= 1
	_enemies_alive -= 1
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
	add_child(serpent)
	serpent.setup(dmg)


func _on_wave_enemy_removed(wid: int) -> void:
	if not _wave_remaining.has(wid):
		return
	_wave_remaining[wid] -= 1
	if _wave_remaining[wid] <= 0:
		_wave_remaining.erase(wid)
		# Hercules: grant +5 damage for this wave being cleared
		for tile in _tower_map:
			var tw = _tower_map[tile]
			if is_instance_valid(tw) and tw.tower_data.get("id", "") == "hercules":
				tw._hercules_wave_bonus += 5.0


func _check_wave_done() -> void:
	if _boss_active:
		return
	if _spawn_queue.is_empty() and _enemies_alive <= 0:
		_wave_active   = false
		_spawning_done = false
		_clear_ice_zones()
		_refresh_hud()


func _on_boss_died(reward: float) -> void:
	if not _boss_active:
		return
	_gold          += reward
	_bosses_killed += 1
	var boss_gems  : int = 10 + (_bosses_killed - 1) * 12
	GameData.blue_gems += boss_gems
	_gems_this_run     += boss_gems
	_hud.refresh_gems()
	_boss_active           = false
	_boss_ref              = null
	_wave_active           = false
	_spawning_done         = false
	_pending_boss_reward   = true
	_clear_ice_zones()
	_hud.hide_wave_btn()
	_refresh_hud()
	_try_show_boss_reward()


var _pre_reward_time_scale : float = 1.0

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
	_clear_poison_cloud()
	_pre_reward_time_scale     = Engine.time_scale
	Engine.time_scale          = 1.0
	_cancel_hold()
	_deselect_tower()
	_hud.hide_wave_btn()
	# Final stage — no buff cards, go straight to victory
	if _stage >= STAGES.size():
		_advance_stage()
		return
	var rarity : String = GameData.roll_rarity(_stage)
	var buffs  : Array  = GameData.pick_buffs(rarity, 3)
	_hud.show_boss_buff_cards(buffs, _stage)


func _on_buff_chosen(buff_id: String) -> void:
	Engine.time_scale = _pre_reward_time_scale
	GameData.apply_buff(buff_id)
	_hud.refresh_buff_history()
	if GameData.buff_pending_lives > 0:
		_lives += GameData.buff_pending_lives
		GameData.buff_pending_lives = 0
	if buff_id == "summon_cost_10g":
		_turret_roll_cost = maxi(1, _turret_roll_cost - 5)
		_rare_roll_cost   = maxi(1, _rare_roll_cost   - 5)
		_epic_roll_cost   = maxi(1, _epic_roll_cost   - 5)
		_hud.update_pull_cost(_turret_roll_cost)
		_hud.update_rare_cost(_rare_roll_cost)
		_hud.update_epic_cost(_epic_roll_cost)
	_advance_stage()
	_hud.show_wave_btn()
	if not _game_over:
		_refresh_hud()


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
	if _lives <= 0 and not _game_over:
		_trigger_game_over()


func _calc_gems() -> int:
	return _gems_this_run


func _trigger_game_over() -> void:
	_game_over = true
	_lives      = 0
	Engine.time_scale = 0.0
	GameData.run_gold = int(_gold)
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
	_hud.show_run_results(_stage, _enemies_killed, _bosses_killed, gems_earned, turrets)


func _on_start_battle_pressed() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _trigger_victory() -> void:
	_game_over = true
	Engine.time_scale = 0.0
	GameData.run_gold = int(_gold)
	GameData.current_run_highest_stage = 10
	if 10 > GameData.all_time_highest_stage:
		GameData.all_time_highest_stage = 10
	var gems_earned : int = _calc_gems()
	GameData.save_game()
	var turrets : Array = []
	for tower in _tower_map.values():
		if is_instance_valid(tower) and not tower.tower_data.is_empty():
			turrets.append(tower.tower_data)
	_hud.show_run_results(_stage, _enemies_killed, _bosses_killed, gems_earned, turrets, true)


func _advance_stage() -> void:
	_wave_in_stage = 0
	if _stage <= STAGES.size():
		_stage += 1
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
	for tile in _tower_map:
		var tw = _tower_map[tile]
		if not is_instance_valid(tw):
			continue
		var id     : String = tw.tower_data.get("id", "")
		var rarity : String = tw.tower_data.get("rarity", "")
		tw.can_upgrade = counts.get(id, 0) >= 3 and rarity != "legendary" and rarity != "fusion"


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
	_hud.refresh(int(_gold), _lives, _stage, _wave_in_stage, total_waves,
				 _wave_active, _boss_active, _boss_timer, can_next,
				 boss_hp, boss_max_hp)
	_hud.update_recipe_notifications(SummonSystem.get_available_recipe_fusions(_tower_map), _get_all_owned_turret_ids())
	_update_upgrade_indicators()


# ── Gacha roll system ─────────────────────────────────────────────────────────

const TURRET_ROLL_COST_BASE : int = 40
var   _turret_roll_cost     : int = 40
var   _rare_roll_cost       : int = SummonSystem.RARE_SUMMON_COST
var   _epic_roll_cost       : int = SummonSystem.EPIC_SUMMON_COST

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
	if _gold < _rare_roll_cost:
		_hud.show_roll_error("Not enough gold! (need %dg)" % _rare_roll_cost)
		return
	var free : Array = _get_free_tiles()
	if free.is_empty():
		_hud.show_roll_error("Map is full! Move or wait.")
		return
	_gold -= _rare_roll_cost
	_rare_roll_cost += 3
	_hud.update_rare_cost(_rare_roll_cost)
	var raw : Dictionary = SummonSystem.roll_by_pool("rare")
	_place_turret_random(raw)
	_hud.show_turret_result(raw)
	_refresh_hud()


func _on_roll_epic_requested() -> void:
	if _gold < _epic_roll_cost:
		_hud.show_roll_error("Not enough gold! (need %dg)" % _epic_roll_cost)
		return
	var free : Array = _get_free_tiles()
	if free.is_empty():
		_hud.show_roll_error("Map is full! Move or wait.")
		return
	_gold -= _epic_roll_cost
	_epic_roll_cost += 5
	_hud.update_epic_cost(_epic_roll_cost)
	var raw : Dictionary = SummonSystem.roll_by_pool("epic")
	_place_turret_random(raw)
	_hud.show_turret_result(raw)
	_refresh_hud()


func _on_roll_turret_requested() -> void:
	if _gold < _turret_roll_cost:
		_hud.show_roll_error("Not enough gold! (need %d)" % _turret_roll_cost)
		return
	var free : Array = _get_free_tiles()
	if free.is_empty():
		_hud.show_roll_error("Map is full! Move or wait.")
		return
	_gold -= _turret_roll_cost
	_turret_roll_cost += 1
	_hud.update_pull_cost(_turret_roll_cost)
	var raw : Dictionary = SummonSystem.roll_by_pool("common")
	_place_turret_random(raw)
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
	tower.init_type(data)
	tower.gold_proc.connect(func(amount: float): _gold += amount; _refresh_hud())
	tower.serpent_summon.connect(func(dmg: float): _spawn_infernal_serpent(dmg))
	tower.drop_from_sky(_build_grid.tile_center(tile))
	_tower_map[tile] = tower
	# If a Venom Drake is placed mid-stage, start the cloud immediately.
	if data.get("effect", "") == "poison_cloud" and _wave_in_stage > 0:
		_spawn_or_reset_poison_cloud(_build_grid.tile_center(tile))


func _get_free_tiles() -> Array:
	var tiles : Array = []
	for c in range(BuildGrid.COLS):
		for r in range(BuildGrid.ROWS):
			var t := Vector2i(c, r)
			if _build_grid.can_place(t):
				tiles.append(t)
	return tiles


# ── Tower placement (click-select) ────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not _hud.is_upgrade_popup_clicked(event.position):
			_hud.hide_upgrade_popup()
		if not _hud.is_sell_btn_clicked(event.position):
			_hud.hide_sell_btn()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_on_wave_btn_pressed()
		return

	if not (event is InputEventMouseButton and
			event.button_index == MOUSE_BUTTON_LEFT):
		return

	var mp : Vector2 = get_viewport().get_mouse_position()

	if event.pressed:
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
			_hud.show_tower_info(_selected_tower, _merge_cnt)
			var _is_hero : bool = GameData.HERO_DEFS.has(_selected_tower.tower_data.get("id", ""))
			if not _is_hero or _hud.DEBUG:
				_hud.show_sell_btn(_selected_tower.position)
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
	_tower_map.erase(tile)
	_build_grid.unplace(tile)
	_held_from_tile = tile
	_held_tower     = tower
	tower.is_held   = true
	tower.z_index   = 10


func _place_held_tower(tile: Vector2i) -> void:
	_build_grid.place(tile)
	_tower_map[tile] = _held_tower
	_held_tower.move_to(_build_grid.tile_center(tile))
	_held_tower = null
	_held_from_tile = Vector2i(-1, -1)
	_hud.update_recipe_notifications(SummonSystem.get_available_recipe_fusions(_tower_map), _get_all_owned_turret_ids())


func _swap_towers(other_tile: Vector2i) -> void:
	var other_tower : Node2D = _tower_map[other_tile]
	_build_grid.place(_held_from_tile)
	_tower_map[_held_from_tile] = other_tower
	other_tower.move_to(_build_grid.tile_center(_held_from_tile))
	_tower_map[other_tile] = _held_tower
	_held_tower.move_to(_build_grid.tile_center(other_tile))
	_held_tower     = null
	_held_from_tile = Vector2i(-1, -1)
	_hud.update_recipe_notifications(SummonSystem.get_available_recipe_fusions(_tower_map), _get_all_owned_turret_ids())


func _cancel_hold() -> void:
	if not is_instance_valid(_held_tower):
		return
	_build_grid.place(_held_from_tile)
	_tower_map[_held_from_tile] = _held_tower
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


func _on_wave_btn_pressed() -> void:
	if _boss_active:
		return
	_hud.on_wave_pressed()
	start_wave()
