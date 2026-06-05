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
func total_gold_drop_mult()                -> float: return 1.0
func relic_boss_dmg_mult()                 -> float: return 1.0
func relic_enemy_slow_mult()               -> float: return 1.0

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
	return 1.0 + tiers * 0.15

func turret_has_special(turret_id: String) -> bool:
	return get_upgrade_tiers(turret_id + "_special") > 0

func reset_save() -> void:
	run_gold                  = 0
	all_time_highest_stage    = 0
	current_run_highest_stage = 0
	blue_gems                 = 0
	upgrade_purchases         = {}
	tower_levels              = {}
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

func _ready() -> void:
	load_game()
