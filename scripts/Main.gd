extends Node2D

const ENEMY_SCENE : PackedScene = preload("res://scenes/Enemy.tscn")
const TOWER_SCENE : PackedScene = preload("res://scenes/Tower.tscn")

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
	# Stage 1
	{ "waves": [
		[5,  10.0,  80.0,  5],
		[7,  14.0,  85.0,  6],
		[9,  18.0,  90.0,  7],
	], "boss": [250.0,  50.0, 120] },
	# Stage 2
	{ "waves": [
		[7,  22.0,  90.0,  7],
		[9,  28.0,  95.0,  8],
		[11, 36.0, 100.0,  9],
	], "boss": [500.0,  48.0, 180] },
	# Stage 3
	{ "waves": [
		[8,  44.0,  95.0,  9],
		[10, 55.0, 100.0, 10],
		[12, 68.0, 105.0, 11],
		[10, 80.0, 108.0, 12],
	], "boss": [950.0,  46.0, 260] },
	# Stage 4
	{ "waves": [
		[10,  90.0, 100.0, 11],
		[12, 108.0, 105.0, 12],
		[14, 128.0, 110.0, 13],
		[12, 150.0, 113.0, 14],
	], "boss": [1600.0, 44.0, 360] },
	# Stage 5
	{ "waves": [
		[12, 165.0, 108.0, 13],
		[14, 190.0, 112.0, 14],
		[16, 220.0, 116.0, 16],
		[14, 250.0, 119.0, 17],
		[18, 285.0, 122.0, 19],
	], "boss": [2600.0, 42.0, 480] },
	# Stage 6
	{ "waves": [
		[14, 300.0, 115.0, 17],
		[16, 345.0, 119.0, 18],
		[18, 395.0, 123.0, 20],
		[16, 450.0, 126.0, 22],
		[20, 510.0, 129.0, 24],
	], "boss": [4000.0, 40.0, 640] },
	# Stage 7
	{ "waves": [
		[16, 540.0, 122.0, 21],
		[18, 615.0, 126.0, 23],
		[20, 700.0, 130.0, 25],
		[18, 795.0, 133.0, 27],
		[22, 900.0, 136.0, 30],
	], "boss": [6200.0, 38.0, 850] },
	# Stage 8
	{ "waves": [
		[18,  950.0, 128.0, 26],
		[20, 1080.0, 132.0, 28],
		[22, 1220.0, 136.0, 31],
		[20, 1380.0, 139.0, 34],
		[24, 1560.0, 142.0, 37],
		[22, 1760.0, 144.0, 40],
	], "boss": [9000.0, 36.0, 1100] },
	# Stage 9
	{ "waves": [
		[20, 1850.0, 135.0, 34],
		[22, 2100.0, 139.0, 37],
		[24, 2380.0, 143.0, 41],
		[22, 2700.0, 146.0, 45],
		[26, 3060.0, 149.0, 50],
		[24, 3460.0, 151.0, 55],
	], "boss": [13000.0, 34.0, 1500] },
	# Stage 10 — Final
	{ "waves": [
		[22, 3600.0, 142.0, 45],
		[24, 4100.0, 146.0, 50],
		[26, 4650.0, 150.0, 55],
		[24, 5300.0, 153.0, 61],
		[28, 6000.0, 156.0, 68],
		[26, 6800.0, 158.0, 75],
	], "boss": [22000.0, 30.0, 2800] },
]

@onready var _terrain    : TileMapLayer = $TerrainLayer
@onready var _hud                       = $UI/HUD
@onready var _build_grid                = $BuildGrid

var _gold          : int   = 100
var _lives         : int   = 20
var _stage         : int   = 1
var _wave_in_stage : int   = 0
var _wave_active   : bool  = false
var _enemies_alive : int   = 0
var _spawn_queue   : Array = []
var _spawn_timer   : float = 0.0

var _boss_active   : bool  = false
var _boss_timer    : float = 0.0
var _boss_ref      : Node2D = null
var _spawning_done : bool  = false
var _game_over     : bool  = false

# ── Tower movement & selection ────────────────────────────────────────────────
var _tower_map           : Dictionary = {}
var _held_tower          : Node2D     = null
var _held_from_tile      : Vector2i   = Vector2i(-1, -1)
var _selected_tower      : Node2D     = null
var _drag_pending_tile   : Vector2i   = Vector2i(-1, -1)
var _press_position      : Vector2    = Vector2.ZERO
const _CLICK_MAX_DIST    : float      = 6.0


func _ready() -> void:
	MapBuilder.new().build(_terrain)
	_hud.setup(self)
	_hud.wave_pressed.connect(_on_wave_btn_pressed)
	_hud.start_battle_pressed.connect(_on_start_battle_pressed)
	_hud.upgrade_purchased.connect(_on_upgrade_purchased)
	_hud.prestige_confirmed.connect(_do_prestige)
	_hud.roll_turret_requested.connect(_on_roll_turret_requested)
	_hud.roll_upgrade_requested.connect(_on_roll_upgrade_requested)
	_hud.recipe_fusion_requested.connect(_on_recipe_fusion_requested)
	_hud.upgrade_merge_requested.connect(_on_upgrade_merge_requested)
	GameData.run_upg_damage    = 0
	GameData.run_upg_range     = 0
	GameData.run_upg_fire_rate = 0
	GameData.run_upg_lives     = 0
	GameData.current_run_highest_stage = 0
	_gold  = 100 + GameData.total_bonus_gold()
	_lives = 20  + GameData.total_bonus_lives()
	_refresh_hud()
	_spawn_knight()


func _spawn_knight() -> void:
	var tile := Vector2i(4, 2)
	_build_grid.place(tile)
	var tower : Node2D = TOWER_SCENE.instantiate()
	add_child(tower)
	var k_data := KNIGHT_DATA.duplicate()
	k_data["damage"]    = KNIGHT_DATA["damage"]    * GameData.final_damage_mult(4)
	k_data["range"]     = KNIGHT_DATA["range"]     * GameData.final_range_mult(4)
	k_data["fire_rate"] = KNIGHT_DATA["fire_rate"] * GameData.final_fire_rate_mult(4)
	tower.init_type(k_data)
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
		_wave_active = true
		_spawning_done = false
		_spawn_queue.clear()
		var def : Array = stage_data["waves"][_wave_in_stage - 1]
		for _i in range(def[0]):
			_spawn_queue.append(def)
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
	var gold : int   = int(ceil(boss_def[2] * GameData.total_gold_drop_mult()))
	enemy.setup(PATH, boss_def[0], spd, gold, true, 0, _stage)
	enemy.died.connect(_on_boss_died)
	enemy.reached_end.connect(_on_boss_reached_end)
	_boss_ref = enemy
	_hud.show_boss_notification()


func _spawn_next_enemy() -> void:
	if _spawn_queue.is_empty():
		return
	var def   : Array  = _spawn_queue.pop_front()
	var enemy : Node2D = ENEMY_SCENE.instantiate()
	add_child(enemy)
	var etype : int = (_stage - 1) / 2
	var spd  : float = def[2] * GameData.relic_enemy_slow_mult()
	var gold : int   = int(ceil(def[3] * GameData.total_gold_drop_mult()))
	enemy.setup(PATH, def[1], spd, gold, false, etype, _stage)
	enemy.died.connect(_on_enemy_died)
	enemy.reached_end.connect(_on_enemy_reached_end)
	_enemies_alive += 1
	if _spawn_queue.is_empty():
		_spawning_done = true
		_refresh_hud()


func _on_enemy_died(reward: int) -> void:
	_gold          += reward
	_enemies_alive -= 1
	_check_wave_done()
	_refresh_hud()


func _on_enemy_reached_end() -> void:
	_lives         -= 1
	_enemies_alive -= 1
	_check_lives()
	_check_wave_done()
	_refresh_hud()


func _clear_ice_zones() -> void:
	for z in get_tree().get_nodes_in_group("ice_zones"):
		if is_instance_valid(z):
			z.queue_free()


func _check_wave_done() -> void:
	if _boss_active:
		return
	if _spawn_queue.is_empty() and _enemies_alive <= 0:
		_wave_active   = false
		_spawning_done = false
		_clear_ice_zones()
		_refresh_hud()


func _on_boss_died(reward: int) -> void:
	if not _boss_active:
		return
	_gold          += reward
	_boss_active    = false
	_boss_ref       = null
	_wave_active    = false
	_spawning_done  = false
	_clear_ice_zones()
	_advance_stage()
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


func _trigger_game_over() -> void:
	_game_over = true
	_lives      = 0
	Engine.time_scale = 0.0
	GameData.run_gold = _gold
	if _stage > GameData.current_run_highest_stage:
		GameData.current_run_highest_stage = _stage
	if GameData.current_run_highest_stage > GameData.all_time_highest_stage:
		GameData.all_time_highest_stage = GameData.current_run_highest_stage
	GameData.save_game()
	_hud.show_game_over(_stage)


func _on_upgrade_purchased(idx: int, cost: int) -> void:
	if _gold < cost:
		return
	_gold -= cost
	_hud._apply_upgrade(idx)
	_hud._refresh_upgrade_rows()  # refreshes pre-battle rows only now
	GameData.save_game()
	_refresh_hud()


func _on_start_battle_pressed() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _trigger_victory() -> void:
	_game_over = true
	Engine.time_scale = 0.0
	GameData.run_gold = _gold
	GameData.current_run_highest_stage = 10
	if 10 > GameData.all_time_highest_stage:
		GameData.all_time_highest_stage = 10
	GameData.save_game()
	_hud.show_victory_screen()


func _do_prestige() -> void:
	GameData.current_run_highest_stage = 0
	GameData.run_gold = 0
	GameData.total_prestiges += 1
	GameData.save_game()
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


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
	_hud.refresh(_gold, _lives, _stage, _wave_in_stage, total_waves,
				 _wave_active, _boss_active, _boss_timer, can_next,
				 boss_hp, boss_max_hp)
	_hud.update_recipe_notifications(SummonSystem.get_available_recipe_fusions(_tower_map), _get_all_owned_turret_ids())
	_update_upgrade_indicators()


# ── Gacha roll system ─────────────────────────────────────────────────────────

const TURRET_ROLL_COST_BASE : int = 80
var   _turret_roll_cost     : int = 80
const UPGRADE_ROLL_COST     : int = 60

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
	var raw : Dictionary = SummonSystem.roll_summon("basic")
	var idx : int = raw.get("idx", 0)
	raw["damage"]    = raw["damage"]    * GameData.final_damage_mult(idx)
	raw["range"]     = raw["range"]     * GameData.final_range_mult(idx)
	raw["fire_rate"] = raw["fire_rate"] * GameData.final_fire_rate_mult(idx)
	_place_turret_random(raw)
	_hud.show_turret_result(raw)
	_refresh_hud()


func _on_roll_upgrade_requested() -> void:
	if _gold < UPGRADE_ROLL_COST:
		_hud.show_roll_error("Not enough gold! (need %d)" % UPGRADE_ROLL_COST)
		return
	# Gather non-maxed upgrades
	var available : Array = []
	for i in range(4):
		if _get_upg_level_main(i) < GameData.MAX_LEVEL:
			available.append(i)
	if available.is_empty():
		_hud.show_roll_error("All upgrades are maxed!")
		return
	_gold -= UPGRADE_ROLL_COST
	available.shuffle()
	var chosen_idx : int = available[0]
	_apply_upgrade_direct(chosen_idx)
	_hud.show_upgrade_result(chosen_idx, _get_upg_level_main(chosen_idx))
	_refresh_hud()


func _get_upg_level_main(idx: int) -> int:
	match idx:
		0: return GameData.run_upg_damage
		1: return GameData.run_upg_range
		2: return GameData.run_upg_fire_rate
		3: return GameData.run_upg_lives
	return 0


func _apply_upgrade_direct(idx: int) -> void:
	match idx:
		0: GameData.run_upg_damage    += 1
		1: GameData.run_upg_range     += 1
		2: GameData.run_upg_fire_rate += 1
		3: GameData.run_upg_lives     += 1


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
	tower.drop_from_sky(_build_grid.tile_center(tile))
	_tower_map[tile] = tower


func _get_free_tiles() -> Array:
	var tiles : Array = []
	for c in range(BuildGrid.COLS):
		for r in range(BuildGrid.ROWS):
			var t := Vector2i(c, r)
			if _build_grid.can_place(t):
				tiles.append(t)
	return tiles


# ── Tower placement (click-select) ────────────────────────────────────────────

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
			if _selected_tower.can_upgrade:
				_hud.show_upgrade_popup(_selected_tower.position)
			else:
				_hud.hide_upgrade_popup()
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
	_selected_tower = tower
	tower.selected  = true


func _deselect_tower() -> void:
	if is_instance_valid(_selected_tower):
		_selected_tower.selected = false
	_selected_tower = null
	_hud.hide_tower_info()
	_hud.hide_upgrade_popup()


func _on_wave_btn_pressed() -> void:
	if _boss_active:
		return
	_hud.on_wave_pressed()
	start_wave()
