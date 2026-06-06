# scripts/GameData.gd  (AutoLoad singleton — persists across scene reloads)
# ─────────────────────────────────────────────────────────────────────────────
extends Node

# ── Stub constant kept for HUD compatibility until upgrade UI is replaced ─────
const MAX_LEVEL : int = 5

# ── Run state ─────────────────────────────────────────────────────────────────
var run_gold                  : int = 0
var current_run_highest_stage : int = 0
var all_time_highest_stage    : int = 0
var blue_gems                 : int = 0
var upgrade_purchases         : Dictionary = {}  # {node_id: tiers_bought}
var tower_levels              : Dictionary = {}  # {tower_id: {level:int, xp:int}}
var selected_hero_id          : String    = "knight"

# ── Hero definitions ──────────────────────────────────────────────────────────
const HERO_DEFS : Dictionary = {
	# Common
	"knight": {
		"id": "knight", "name": "Knight Hero", "rarity": "common",
		"desc": "A stalwart warrior who hurls enchanted swords across the entire battlefield.",
		"damage": 20.0, "range": 1500.0, "fire_rate": 0.9,
		"color": Color(0.72, 0.76, 0.90), "effect": "knight_slam", "idx": 4,
	},
	"ranger": {
		"id": "ranger", "name": "Ranger", "rarity": "common",
		"desc": "A seasoned archer who focuses fire on priority targets, hitting harder with each consecutive hit.",
		"damage": 14.0, "range": 1200.0, "fire_rate": 1.6,
		"color": Color(0.32, 0.68, 0.30), "effect": "focused_shot", "idx": 0,
	},
	"guardian": {
		"id": "guardian", "name": "Stone Guardian", "rarity": "common",
		"desc": "A heavily armored defender whose wide sweeps cleave through entire enemy ranks.",
		"damage": 32.0, "range": 700.0, "fire_rate": 0.6,
		"color": Color(0.58, 0.52, 0.46), "effect": "melee_cleave", "idx": 50,
	},
	# Rare
	"arcane_scholar": {
		"id": "arcane_scholar", "name": "Arcane Scholar", "rarity": "rare",
		"desc": "A wielder of arcane arts who chains magical bolts between multiple enemies.",
		"damage": 18.0, "range": 1300.0, "fire_rate": 1.2,
		"color": Color(0.65, 0.25, 0.95), "effect": "chain", "idx": 3,
	},
	"shadow_blade": {
		"id": "shadow_blade", "name": "Shadow Blade", "rarity": "rare",
		"desc": "A dual-wielding assassin who strikes two separate targets simultaneously.",
		"damage": 22.0, "range": 1000.0, "fire_rate": 1.5,
		"color": Color(0.55, 0.08, 0.18), "effect": "dual_shot", "idx": 51,
	},
	"frost_herald": {
		"id": "frost_herald", "name": "Frost Herald", "rarity": "rare",
		"desc": "A master of ice who periodically drops freezing zones that slow all enemies inside.",
		"damage": 16.0, "range": 1100.0, "fire_rate": 1.0,
		"color": Color(0.55, 0.90, 0.98), "effect": "slow_zone", "idx": 52,
	},
	# Epic
	"storm_knight": {
		"id": "storm_knight", "name": "Storm Knight", "rarity": "epic",
		"desc": "A knight wreathed in lightning whose strikes arc through multiple foes in sequence.",
		"damage": 28.0, "range": 1350.0, "fire_rate": 1.1,
		"color": Color(0.88, 0.92, 0.20), "effect": "lightning", "idx": 4,
	},
	"blade_dancer": {
		"id": "blade_dancer", "name": "Blade Dancer", "rarity": "epic",
		"desc": "An agile warrior whose spinning blades pierce through entire lines of enemies.",
		"damage": 24.0, "range": 1150.0, "fire_rate": 1.9,
		"color": Color(0.90, 0.60, 0.10), "effect": "pierce", "idx": 51,
	},
	"venom_lord": {
		"id": "venom_lord", "name": "Venom Lord", "rarity": "epic",
		"desc": "A toxic master who poisons targets, amplifying all damage they receive from every source.",
		"damage": 20.0, "range": 1200.0, "fire_rate": 1.2,
		"color": Color(0.15, 0.82, 0.22), "effect": "poison_debuff", "idx": 52,
	},
	# Legendary
	"dragon_sovereign": {
		"id": "dragon_sovereign", "name": "Dragon Sovereign", "rarity": "legendary",
		"desc": "An ancient dragon lord who unleashes explosive bursts that devastate up to 5 nearby enemies.",
		"damage": 48.0, "range": 1600.0, "fire_rate": 0.8,
		"color": Color(0.95, 0.20, 0.15), "effect": "aoe_burst", "idx": 50,
	},
	"void_walker": {
		"id": "void_walker", "name": "Void Walker", "rarity": "legendary",
		"desc": "A void entity who accumulates arcane power and unleashes devastating lasers every 20th hit.",
		"damage": 38.0, "range": 1500.0, "fire_rate": 1.0,
		"color": Color(0.50, 0.08, 0.92), "effect": "arcane_charge", "idx": 52,
	},
	"phoenix_archer": {
		"id": "phoenix_archer", "name": "Phoenix Archer", "rarity": "legendary",
		"desc": "A reborn phoenix warrior whose burning arrows deal up to 2× damage based on the target's remaining HP.",
		"damage": 34.0, "range": 1450.0, "fire_rate": 1.3,
		"color": Color(0.98, 0.48, 0.10), "effect": "execute_shot", "idx": 0,
	},
}

func set_selected_hero(id: String) -> void:
	if HERO_DEFS.has(id):
		selected_hero_id = id
		save_game()

const TOWER_MAX_LEVEL  : int = 10
const TOWER_XP_PER_LVL : int = 100   # XP needed per level (flat for now)

func get_tower_level(tower_id: String) -> int:
	return int(tower_levels.get(tower_id, {}).get("level", 1))

func get_tower_xp(tower_id: String) -> int:
	return int(tower_levels.get(tower_id, {}).get("xp", 0))

func add_tower_xp(tower_id: String, amount: int) -> void:
	if not tower_levels.has(tower_id):
		tower_levels[tower_id] = {"level": 1, "xp": 0}
	tower_levels[tower_id]["xp"] += amount
	while tower_levels[tower_id]["xp"] >= TOWER_XP_PER_LVL and \
			tower_levels[tower_id]["level"] < TOWER_MAX_LEVEL:
		tower_levels[tower_id]["xp"] -= TOWER_XP_PER_LVL
		tower_levels[tower_id]["level"] += 1
	save_game()

# ── Stub multipliers — always 1.0 until new progression system is added ───────
func final_damage_mult(_tower_idx: int)    -> float: return 1.0
func final_fire_rate_mult(_tower_idx: int) -> float: return 1.0
func final_range_mult(_tower_idx: int)     -> float: return 1.0
func total_bonus_lives()                   -> int:   return 0
func total_bonus_gold()                    -> int:   return 0
func total_gold_drop_mult()                -> float: return 1.0 + buff_gold_pct
func relic_boss_dmg_mult()                 -> float: return 1.0 + buff_boss_dmg_pct
func relic_enemy_slow_mult()               -> float: return clampf(1.0 - buff_enemy_slow_pct, 0.1, 1.0)

# ── Run-scoped boss buff state (not saved — resets each run) ──────────────────
var buff_damage_flat       : float = 0.0   # added to every shot's base damage
var buff_fire_rate_pct     : float = 0.0   # multiplier bonus e.g. 0.15 = +15%
var buff_boss_dmg_pct      : float = 0.0   # stacks into relic_boss_dmg_mult
var buff_enemy_slow_pct    : float = 0.0   # stacks into relic_enemy_slow_mult
var buff_dot_dps           : float = 0.0   # damage per second on all enemies
var buff_gold_pct          : float = 0.0   # stacks into total_gold_drop_mult
var buff_pending_lives     : int   = 0     # consumed by Main after buff picked
var chosen_buffs           : Array = []   # list of buff dicts picked this run

func reset_run_buffs() -> void:
	buff_damage_flat    = 0.0
	buff_fire_rate_pct  = 0.0
	buff_boss_dmg_pct   = 0.0
	buff_enemy_slow_pct = 0.0
	buff_dot_dps        = 0.0
	buff_gold_pct       = 0.0
	buff_pending_lives  = 0
	chosen_buffs        = []

# ── Boss buff definitions ─────────────────────────────────────────────────────
const BOSS_BUFFS : Array = [
	# Common
	{ "id": "dmg_2",           "rarity": "common", "name": "Combat Training",
	  "desc": "All turrets deal +2 damage per shot." },
	{ "id": "fire_rate_5",     "rarity": "common", "name": "Oiled Mechanisms",
	  "desc": "All turrets fire 5% faster." },
	{ "id": "gold_10",         "rarity": "common", "name": "Looter's Instinct",
	  "desc": "Enemies drop 10% more gold." },
	{ "id": "summon_cost_10g", "rarity": "common", "name": "Bulk Discount",
	  "desc": "All summon rolls cost 10g less." },
	{ "id": "lives_5",         "rarity": "common", "name": "Reinforcements",
	  "desc": "Gain 5 lives." },
	# Rare
	{ "id": "dmg_5",           "rarity": "rare",   "name": "Sharpened Blades",
	  "desc": "All turrets deal +5 damage per shot." },
	{ "id": "fire_rate_15",    "rarity": "rare",   "name": "Rapid Assembly",
	  "desc": "All turrets fire 15% faster." },
	{ "id": "boss_dmg_25",     "rarity": "rare",   "name": "Giant Slayer",
	  "desc": "All turrets deal 25% more damage to bosses." },
	{ "id": "enemy_slow_10",   "rarity": "rare",   "name": "Heavy Terrain",
	  "desc": "All enemies move 10% slower. Stacks with frost." },
	{ "id": "dot_1",           "rarity": "rare",   "name": "Caustic Field",
	  "desc": "All enemies take 1 damage every second." },
	# Epic
	{ "id": "dmg_8",           "rarity": "epic",   "name": "Blessed Armaments",
	  "desc": "All turrets deal +8 damage per shot." },
	{ "id": "fire_rate_30",    "rarity": "epic",   "name": "War Machine",
	  "desc": "All turrets fire 30% faster." },
	{ "id": "boss_dmg_50",     "rarity": "epic",   "name": "Bane of Giants",
	  "desc": "All turrets deal 50% more damage to bosses." },
	{ "id": "enemy_slow_25",   "rarity": "epic",   "name": "Cursed Ground",
	  "desc": "All enemies move 25% slower. Stacks with frost." },
	{ "id": "dot_3",           "rarity": "epic",   "name": "Plague Aura",
	  "desc": "All enemies take 3 damage every second." },
]

func roll_rarity(stage: int) -> String:
	# stage 1: common=80, rare=20, epic=0
	# each stage: common-3, rare+2, epic+1
	var s       : int   = stage - 1
	var common  : float = clampf(80.0 - s * 3.0, 0.0, 100.0)
	var rare    : float = clampf(20.0 + s * 2.0, 0.0, 100.0)
	var epic    : float = clampf(0.0  + s * 1.0, 0.0, 100.0)
	var roll    : float = randf() * (common + rare + epic)
	if roll < common:
		return "common"
	elif roll < common + rare:
		return "rare"
	return "epic"

func pick_buffs(rarity: String, count: int) -> Array:
	var pool : Array = []
	for b in BOSS_BUFFS:
		if b["rarity"] == rarity:
			pool.append(b)
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))

func apply_buff(buff_id: String) -> void:
	for b in BOSS_BUFFS:
		if b["id"] == buff_id:
			chosen_buffs.append(b)
			break
	match buff_id:
		"dmg_2":           buff_damage_flat    += 2.0
		"dmg_5":           buff_damage_flat    += 5.0
		"dmg_8":           buff_damage_flat    += 8.0
		"fire_rate_5":     buff_fire_rate_pct  += 0.05
		"fire_rate_15":    buff_fire_rate_pct  += 0.15
		"fire_rate_30":    buff_fire_rate_pct  += 0.30
		"gold_10":         buff_gold_pct       += 0.10
		"boss_dmg_25":     buff_boss_dmg_pct   += 0.25
		"boss_dmg_50":     buff_boss_dmg_pct   += 0.50
		"enemy_slow_10":   buff_enemy_slow_pct += 0.10
		"enemy_slow_25":   buff_enemy_slow_pct += 0.25
		"dot_1":           buff_dot_dps        += 1.0
		"dot_3":           buff_dot_dps        += 3.0
		"lives_5":         buff_pending_lives  += 5
		"summon_cost_10g": pass  # handled in Main

# ── Save / Load ───────────────────────────────────────────────────────────────
const SAVE_PATH    := "user://savegame.dat"
const SAVE_KEY     := "1b9f3c7e2a084d56"  # 16-char AES-256 key — do not change after shipping

func save_game() -> void:
	var data := {
		"run_gold":               run_gold,
		"all_time_highest_stage": all_time_highest_stage,
		"blue_gems":              blue_gems,
		"upgrade_purchases":      upgrade_purchases,
		"tower_levels":           tower_levels,
		"selected_hero_id":       selected_hero_id,
	}
	var file := FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.WRITE, SAVE_KEY)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.READ, SAVE_KEY)
	if not file:
		return
	var text := file.get_as_text()
	file.close()
	var result = JSON.parse_string(text)
	if result == null or not result is Dictionary:
		return
	var d : Dictionary = result
	run_gold               = int(d.get("run_gold",               0))
	all_time_highest_stage = int(d.get("all_time_highest_stage", 0))
	blue_gems              = int(d.get("blue_gems",              0))
	var up = d.get("upgrade_purchases", {})
	if up is Dictionary:
		upgrade_purchases = up
	var tl = d.get("tower_levels", {})
	if tl is Dictionary:
		tower_levels = tl
	var shi = d.get("selected_hero_id", "knight")
	if shi is String and HERO_DEFS.has(shi):
		selected_hero_id = shi

func get_upgrade_tiers(node_id: String) -> int:
	return int(upgrade_purchases.get(node_id, 0))

func try_buy_upgrade(node_id: String, max_tiers: int, cost: int) -> bool:
	var current := get_upgrade_tiers(node_id)
	if current >= max_tiers or blue_gems < cost:
		return false
	upgrade_purchases[node_id] = current + 1
	blue_gems -= cost
	save_game()
	return true

func turret_damage_mult(turret_id: String) -> float:
	var tiers := get_upgrade_tiers(turret_id + "_dmg")
	return 1.0 + tiers * 0.15

func turret_fire_rate_mult(turret_id: String) -> float:
	var tiers := get_upgrade_tiers(turret_id + "_spd")
	return (1.0 + tiers * 0.15) * (1.0 + buff_fire_rate_pct)

func turret_has_special(turret_id: String) -> bool:
	return get_upgrade_tiers(turret_id + "_special") > 0

func reset_save() -> void:
	run_gold                  = 0
	all_time_highest_stage    = 0
	current_run_highest_stage = 0
	blue_gems                 = 0
	upgrade_purchases         = {}
	tower_levels              = {}
	reset_run_buffs()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

func _ready() -> void:
	load_game()
