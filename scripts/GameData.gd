# scripts/GameData.gd  (AutoLoad singleton — persists across scene reloads)
# ─────────────────────────────────────────────────────────────────────────────
extends Node

# ── Permanent gold upgrades ───────────────────────────────────────────────────
var run_gold      : int = 0   # gold from run, spent on permanent upgrades between runs

var upg_damage    : int = 0   # +15% tower damage per level
var upg_range     : int = 0   # +10% tower range per level
var upg_fire_rate : int = 0   # +10% fire rate per level
var upg_lives     : int = 0   # +1 starting life per level

const MAX_LEVEL     : int = 5
const COST_DAMAGE   : int = 100   # actual cost = base * (current_level + 1)
const COST_RANGE    : int = 80
const COST_FIRERATE : int = 90
const COST_LIVES    : int = 150

# ── Prestige system ───────────────────────────────────────────────────────────
var prestige_shards        : int = 0   # old currency → spent on prestige upgrades
var prestige_tokens        : int = 0   # new currency → spent on relics
var total_prestiges        : int = 0
var all_time_highest_stage : int = 0
var relic_discover_cost    : int = 5   # shard-based legacy cost (kept for backward compat)

# 6 prestige upgrade levels: [ancient_power, veteran_tactician, fortified_bastion,
#                              golden_start, hero_training, wave_knowledge]
var prestige_upg_levels : Array = [0, 0, 0, 0, 0, 0]
const PRESTIGE_MAX_LEVEL : int  = 20

const PRESTIGE_UPGRADES : Array = [
	{ "name": "Ancient Power",     "icon": "⚔",  "desc": "+5% all tower damage per level",      "base_cost": 3 },
	{ "name": "Veteran Tactician", "icon": "⚡", "desc": "+3% attack speed per level",           "base_cost": 3 },
	{ "name": "Fortified Bastion", "icon": "🛡", "desc": "+2 starting lives per level",          "base_cost": 2 },
	{ "name": "Golden Start",      "icon": "💰", "desc": "+25 starting gold per level",          "base_cost": 2 },
	{ "name": "Hero Training",     "icon": "🦸", "desc": "+5% Knight Hero stats per level",      "base_cost": 3 },
	{ "name": "Wave Knowledge",    "icon": "📜", "desc": "+3% enemy gold drops per level",       "base_cost": 2 },
]

# ── Relics ────────────────────────────────────────────────────────────────────
var unlocked_relics  : Array      = []   # list of relic IDs (int) the player owns
var relic_upg_levels : Dictionary = {}   # { relic_id: upgrade_level }

const RELICS : Array = [
	# Original 10 (ids 0–9) — each upgrade adds +50% of the base bonus
	{ "id": 0,  "name": "Archer's Emblem",   "icon": "🏹", "effect": "+10% Archer damage (+5%/upg)",          "type": "archer_dmg",    "base": 0.10 },
	{ "id": 1,  "name": "Crossbow Gear",     "icon": "⚙",  "effect": "+10% Crossbow speed (+5%/upg)",          "type": "crossbow_spd",  "base": 0.10 },
	{ "id": 2,  "name": "Catapult Core",     "icon": "💣", "effect": "+15% Catapult damage (+7%/upg)",          "type": "catapult_dmg",  "base": 0.15 },
	{ "id": 3,  "name": "Mage Crystal",      "icon": "🔮", "effect": "+10% Mage damage (+5%/upg)",              "type": "mage_dmg",      "base": 0.10 },
	{ "id": 4,  "name": "Knight's Banner",   "icon": "⚔",  "effect": "+15% Knight stats (+7%/upg)",             "type": "knight_stats",  "base": 0.15 },
	{ "id": 5,  "name": "Golden Idol",       "icon": "🪙", "effect": "+10% gold drops (+5%/upg)",               "type": "gold_drop",     "base": 0.10 },
	{ "id": 6,  "name": "Bastion Heart",     "icon": "💖", "effect": "+5 starting lives (+2/upg)",              "type": "start_lives",   "base": 0.0  },
	{ "id": 7,  "name": "Ancient Telescope", "icon": "🔭", "effect": "+8% tower range (+4%/upg)",               "type": "tower_range",   "base": 0.08 },
	{ "id": 8,  "name": "Boss Hunter Charm", "icon": "🎯", "effect": "+15% boss damage (+7%/upg)",              "type": "boss_dmg",      "base": 0.15 },
	{ "id": 9,  "name": "Wavebreaker Rune",  "icon": "🌀", "effect": "-5% enemy speed (-2%/upg)",               "type": "enemy_slow",    "base": 0.05 },
	# New relics (ids 10–13) — discovered via prestige tokens
	{ "id": 10, "name": "Frost Core",        "icon": "❄",  "effect": "+10% Frost/Chrono dmg (+5%/upg)",         "type": "frost_dmg",     "base": 0.10 },
	{ "id": 11, "name": "Summoner's Dice",   "icon": "🎲", "effect": "+3% better summon odds/upg",              "type": "summon_odds",   "base": 0.0  },
	{ "id": 12, "name": "Fusion Hammer",     "icon": "🔨", "effect": "+10% Legendary tower damage (+5%/upg)",   "type": "legendary_dmg", "base": 0.10 },
	{ "id": 13, "name": "Merchant's Coin",   "icon": "🪙", "effect": "-5% summon costs per level",              "type": "summon_cost",   "base": 0.0  },
]

# ── Runtime state (not persisted) ─────────────────────────────────────────────
var current_run_highest_stage : int = 0
# Per-run upgrade gacha counters (reset each new game, not saved)
var run_upg_damage    : int = 0
var run_upg_range     : int = 0
var run_upg_fire_rate : int = 0
var run_upg_lives     : int = 0

# ── Permanent-upgrade helpers ─────────────────────────────────────────────────
func cost_for(base: int, current_level: int) -> int:
	return base * (current_level + 1)

func damage_mult()    -> float: return 1.0 + (upg_damage    + run_upg_damage)    * 0.15
func range_mult()     -> float: return 1.0 + (upg_range     + run_upg_range)     * 0.10
func fire_rate_mult() -> float: return 1.0 + (upg_fire_rate + run_upg_fire_rate) * 0.10
func bonus_lives()    -> int:   return upg_lives + run_upg_lives

# ── Prestige upgrade cost ─────────────────────────────────────────────────────
func prestige_upg_cost(idx: int) -> int:
	return PRESTIGE_UPGRADES[idx]["base_cost"] + prestige_upg_levels[idx] * 2

# ── Prestige shard reward formula (legacy, for prestige upgrades) ─────────────
func shards_for_stage(stage: int) -> int:
	match stage:
		5:  return 1
		6:  return 2
		7:  return 4
		8:  return 7
		9:  return 11
		10: return 16
		_:  return 0

# ── Prestige Token reward formula (new, for relics) ───────────────────────────
func tokens_for_stage(stage: int) -> int:
	match stage:
		1:  return 0
		2:  return 25
		3:  return 60
		4:  return 110
		5:  return 180
		6:  return 275
		7:  return 400
		8:  return 560
		9:  return 760
		10: return 1000
		_:  return 0

# ── Relic helpers ─────────────────────────────────────────────────────────────

func relic_level(id: int) -> int:
	return relic_upg_levels.get(id, 0) as int

# Cost to discover next relic (token-based): floor(100 * 1.5^relicsUnlocked)
func relic_discover_token_cost() -> int:
	var n : int = unlocked_relics.size()
	return int(floor(100.0 * pow(1.5, n)))

# Cost to upgrade a relic from current level to next: floor(100 * 1.5^(level-1)); level 0 = free
func relic_upgrade_cost(id: int) -> int:
	var lvl : int = relic_level(id)
	if lvl == 0:
		return 0   # first "upgrade" is the discovery itself; upgrading starts at lvl 1
	return int(floor(100.0 * pow(1.5, lvl - 1)))

# Relic multiplier helper: bonus = base * (1 + 0.5 * upgrade_level)
func relic_mult(id: int, base: float) -> float:
	return base * (1.0 + 0.5 * relic_level(id))

# ── Prestige bonus multipliers / bonuses ──────────────────────────────────────
func prestige_damage_mult()    -> float: return 1.0 + prestige_upg_levels[0] * 0.05
func prestige_fire_rate_mult() -> float: return 1.0 + prestige_upg_levels[1] * 0.03
func prestige_bonus_lives()    -> int:   return prestige_upg_levels[2] * 2
func prestige_bonus_gold()     -> int:   return prestige_upg_levels[3] * 25
func prestige_knight_mult()    -> float: return 1.0 + prestige_upg_levels[4] * 0.05
func prestige_gold_drop_mult() -> float: return 1.0 + prestige_upg_levels[5] * 0.03

# ── Relic helpers ─────────────────────────────────────────────────────────────
func has_relic(id: int) -> bool:
	return unlocked_relics.has(id)

# ── Combined final multipliers (used when placing/spawning) ───────────────────
# tower_idx: 0=archer 1=crossbow 2=catapult 3=mage 4=knight

func final_damage_mult(tower_idx: int) -> float:
	var base := damage_mult() * prestige_damage_mult()
	match tower_idx:
		# Common towers
		0: return base * (1.0 + (relic_mult(0, 0.10) if has_relic(0) else 0.0))
		2: return base * (1.0 + (relic_mult(2, 0.15) if has_relic(2) else 0.0))
		3: return base * (1.0 + (relic_mult(3, 0.10) if has_relic(3) else 0.0))
		4: return base * prestige_knight_mult() * (1.0 + (relic_mult(4, 0.15) if has_relic(4) else 0.0))
		# Frost Spire (idx 6)
		6: return base * (1.0 + (relic_mult(10, 0.10) if has_relic(10) else 0.0))
		# Chrono Mage (idx 15)
		15: return base * (1.0 + (relic_mult(10, 0.10) if has_relic(10) else 0.0))
		# Legendary towers (idx 13–16)
		13, 14, 16: return base * (1.0 + (relic_mult(12, 0.10) if has_relic(12) else 0.0))
		_: return base

func final_fire_rate_mult(tower_idx: int) -> float:
	var base := fire_rate_mult() * prestige_fire_rate_mult()
	match tower_idx:
		1: return base * (1.0 + (relic_mult(1, 0.10) if has_relic(1) else 0.0))
		4: return base * prestige_knight_mult() * (1.0 + (relic_mult(4, 0.15) if has_relic(4) else 0.0))
		_: return base

func final_range_mult(tower_idx: int) -> float:
	var base := range_mult() * (1.0 + (relic_mult(7, 0.08) if has_relic(7) else 0.0))
	match tower_idx:
		4: return base * prestige_knight_mult() * (1.0 + (relic_mult(4, 0.15) if has_relic(4) else 0.0))
		_: return base

func total_bonus_lives() -> int:
	var relic6_bonus : int = (5 + relic_level(6) * 2) if has_relic(6) else 0
	return bonus_lives() + prestige_bonus_lives() + relic6_bonus

func total_bonus_gold() -> int:
	return prestige_bonus_gold()

func total_gold_drop_mult() -> float:
	var r5 := (1.0 + relic_mult(5, 0.10)) if has_relic(5) else 1.0
	return prestige_gold_drop_mult() * r5

func relic_boss_dmg_mult() -> float:
	return (1.0 + relic_mult(8, 0.15)) if has_relic(8) else 1.0

func relic_enemy_slow_mult() -> float:
	return (1.0 - relic_mult(9, 0.05)) if has_relic(9) else 1.0

# ── Save / Load ───────────────────────────────────────────────────────────────
const SAVE_PATH := "user://savegame.json"

func save_game() -> void:
	# Convert relic_upg_levels dict keys to strings for JSON
	var relic_lvl_json : Dictionary = {}
	for k in relic_upg_levels:
		relic_lvl_json[str(k)] = relic_upg_levels[k]
	var data := {
		"run_gold":               run_gold,
		"upg_damage":             upg_damage,
		"upg_range":              upg_range,
		"upg_fire_rate":          upg_fire_rate,
		"upg_lives":              upg_lives,
		"prestige_shards":        prestige_shards,
		"prestige_tokens":        prestige_tokens,
		"total_prestiges":        total_prestiges,
		"all_time_highest_stage": all_time_highest_stage,
		"relic_discover_cost":    relic_discover_cost,
		"prestige_upg_levels":    prestige_upg_levels,
		"unlocked_relics":        unlocked_relics,
		"relic_upg_levels":       relic_lvl_json,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var text   := file.get_as_text()
	file.close()
	var result = JSON.parse_string(text)
	if result == null or not result is Dictionary:
		return
	var d : Dictionary = result
	run_gold               = int(d.get("run_gold",               0))
	upg_damage             = int(d.get("upg_damage",             0))
	upg_range              = int(d.get("upg_range",              0))
	upg_fire_rate          = int(d.get("upg_fire_rate",          0))
	upg_lives              = int(d.get("upg_lives",              0))
	prestige_shards        = int(d.get("prestige_shards",        0))
	prestige_tokens        = int(d.get("prestige_tokens",        0))
	total_prestiges        = int(d.get("total_prestiges",        0))
	all_time_highest_stage = int(d.get("all_time_highest_stage", 0))
	relic_discover_cost    = int(d.get("relic_discover_cost",    5))
	if d.has("prestige_upg_levels"):
		var arr = d["prestige_upg_levels"]
		prestige_upg_levels = [0, 0, 0, 0, 0, 0]
		for i in range(min(arr.size(), prestige_upg_levels.size())):
			prestige_upg_levels[i] = int(arr[i])
	if d.has("unlocked_relics"):
		unlocked_relics = []
		for r in d["unlocked_relics"]:
			unlocked_relics.append(int(r))
	if d.has("relic_upg_levels"):
		relic_upg_levels = {}
		var rld = d["relic_upg_levels"]
		for k in rld:
			relic_upg_levels[int(k)] = int(rld[k])

func reset_save() -> void:
	run_gold               = 0
	upg_damage             = 0
	upg_range              = 0
	upg_fire_rate          = 0
	upg_lives              = 0
	prestige_shards        = 0
	prestige_tokens        = 0
	total_prestiges        = 0
	all_time_highest_stage = 0
	relic_discover_cost    = 5
	prestige_upg_levels    = [0, 0, 0, 0, 0, 0]
	unlocked_relics        = []
	relic_upg_levels       = {}
	current_run_highest_stage = 0
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

func _ready() -> void:
	load_game()
