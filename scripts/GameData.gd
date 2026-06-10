# scripts/GameData.gd  (AutoLoad singleton — persists across scene reloads)
# ─────────────────────────────────────────────────────────────────────────────
extends Node

# ── Stub constant kept for HUD compatibility until upgrade UI is replaced ─────
const MAX_LEVEL : int = 5

# ── Visual settings (toggled from gear menu) ──────────────────────────────────
var show_damage_numbers : bool = false
var show_projectiles    : bool = false

# ── Run state ─────────────────────────────────────────────────────────────────
var run_gold                  : int = 0
var current_run_highest_stage : int = 0
var all_time_highest_stage    : int = 0
var max_world_unlocked        : int = 1
var blue_gems                 : int = 0
var upgrade_purchases         : Dictionary = {}  # {node_id: tiers_bought}
var tower_levels              : Dictionary = {}  # {tower_id: {level:int, xp:int}}
var selected_hero_id          : String    = "knight"

# ── Hero definitions ──────────────────────────────────────────────────────────
const HERO_DEFS : Dictionary = {
	# Common
	"knight": {
		"id": "knight", "name": "Knight Hero", "rarity": "common",
		"desc": "Every 3rd hit throws up to 3 swords at different enemies and knocks them back.\nFewer swords are thrown if fewer enemies are in range.\nKnockback has no effect on bosses.",
		"damage": 15.0, "range": 1500.0, "fire_rate": 1.0,
		"color": Color(0.72, 0.76, 0.90), "effect": "knight_slam", "idx": 4,
	},
	"ranger": {
		"id": "ranger", "name": "Ranger", "rarity": "common",
		"desc": "A swift archer who supports nearby towers.\nEvery 5th hit grants towers 1 tile away +10% fire rate for 3s.",
		"damage": 10.0, "range": 1500.0, "fire_rate": 1.0,
		"color": Color(0.32, 0.68, 0.30), "effect": "ranger_fire_aura", "idx": 54,
	},
	"guardian": {
		"id": "guardian", "name": "Stone Guardian", "rarity": "common",
		"desc": "Every 3rd hit drops a brittle zone for 2s.\nEnemies entering take +20 damage on their next hit from any source (once per enemy per zone).",
		"damage": 25.0, "range": 200.0, "fire_rate": 0.8,
		"color": Color(0.58, 0.52, 0.46), "effect": "rock_drop", "idx": 55,
	},
	# Rare
	"arcane_scholar": {
		"id": "arcane_scholar", "name": "Arcane Scholar", "rarity": "rare",
		"desc": "Hits 2 targets per attack.\nEvery other attack inflicts a random debuff on each target for 1 second.\n(Bleed, 10% Slow, or +10% damage taken — 5s cooldown per debuff per target.)",
		"damage": 18.0, "range": 1500.0, "fire_rate": 1.2,
		"color": Color(0.65, 0.25, 0.95), "effect": "dual_debuff", "idx": 53,
	},
	"shadow_blade": {
		"id": "shadow_blade", "name": "Shadow Blade", "rarity": "rare",
		"desc": "Dual-wielding melee hero. Each swing glows red as the combo charges.\nEvery 3rd hit strikes with both blades at 2× damage and applies a bleed stack dealing 2× damage/s for 3s.\nMax 1 bleed stack per target.",
		"damage": 25.0, "range": 200.0, "fire_rate": 1.5,
		"color": Color(0.55, 0.08, 0.18), "effect": "shadow_blade_combo", "idx": 51,
	},
	"frost_herald": {
		"id": "frost_herald", "name": "Frost Herald", "rarity": "rare",
		"desc": "Fires 2 projectiles per attack. Every hit slows the target by 5% for 2s.\nGains +3% attack speed for each slowed enemy currently on the map (max 10 enemies = +30%).\nBonus resets after 3s without attacking.",
		"damage": 20.0, "range": 1500.0, "fire_rate": 1.5,
		"color": Color(0.55, 0.90, 0.98), "effect": "frost_shatter", "idx": 57,
	},
	# Epic
	"storm_knight": {
		"id": "storm_knight", "name": "Storm Knight", "rarity": "epic",
		"desc": "Each strike chains to the primary target, then arcs to 3 additional enemies at 80% damage.",
		"damage": 28.0, "range": 1350.0, "fire_rate": 1.1,
		"color": Color(0.88, 0.92, 0.20), "effect": "lightning", "idx": 59,
	},
	"blade_dancer": {
		"id": "blade_dancer", "name": "Blade Dancer", "rarity": "epic",
		"desc": "Each shot pierces through up to 3 enemies in a line at full damage.",
		"damage": 24.0, "range": 1150.0, "fire_rate": 1.9,
		"color": Color(0.90, 0.60, 0.10), "effect": "pierce", "idx": 56,
	},
	"venom_lord": {
		"id": "venom_lord", "name": "Venom Lord", "rarity": "epic",
		"desc": "Poisons targets on hit — each stack increases damage taken by 10% for 5s.\nStacks up to 3 times per target.",
		"damage": 20.0, "range": 1200.0, "fire_rate": 1.2,
		"color": Color(0.15, 0.82, 0.22), "effect": "poison_debuff", "idx": 58,
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
		"desc": "A void entity who accumulates arcane power and unleashes devastating lasers every 15th hit.",
		"damage": 38.0, "range": 1500.0, "fire_rate": 1.0,
		"color": Color(0.50, 0.08, 0.92), "effect": "arcane_charge", "idx": 52,
	},
	"phoenix_archer": {
		"id": "phoenix_archer", "name": "Phoenix Archer", "rarity": "legendary",
		"desc": "Burning arrows scale with the target's current HP — 2× damage at full HP, down to 1× at 0 HP.",
		"damage": 34.0, "range": 1450.0, "fire_rate": 1.3,
		"color": Color(0.98, 0.48, 0.10), "effect": "execute_shot", "idx": 60,
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

# Copies needed to go from level N to N+1 (index 0 = Lv1→Lv2)
const COPIES_PER_LEVEL : Array = [2, 4, 6, 8, 12, 16, 20, 24, 30]

func copies_needed_for_level(lvl: int) -> int:
	var idx : int = clampi(lvl - 1, 0, COPIES_PER_LEVEL.size() - 1)
	return COPIES_PER_LEVEL[idx]

func add_tower_xp(tower_id: String, amount: int) -> void:
	if not tower_levels.has(tower_id):
		tower_levels[tower_id] = {"level": 1, "xp": 0}
	tower_levels[tower_id]["xp"] += amount
	while tower_levels[tower_id]["level"] < TOWER_MAX_LEVEL:
		var needed : int = copies_needed_for_level(tower_levels[tower_id]["level"])
		if tower_levels[tower_id]["xp"] >= needed:
			tower_levels[tower_id]["xp"] -= needed
			tower_levels[tower_id]["level"] += 1
		else:
			break
	save_game()

func add_tower_copy(tower_id: String) -> void:
	add_tower_xp(tower_id, 1)

# ── Stub multipliers (used for heroes, idx-based) — kept for compatibility ────
func final_damage_mult(_tower_idx: int)    -> float: return 1.0
func final_fire_rate_mult(_tower_idx: int) -> float: return 1.0
func final_range_mult(_tower_idx: int)     -> float: return 1.0

# ── Tower level multipliers ───────────────────────────────────────────────────
# Additive bonuses per level (index 0 = Lv.1, index 9 = Lv.10).
# Each entry is the TOTAL bonus accumulated up to that level (1.0 = base).
# Matches the additive convention of turret_damage_mult (1.0 + tiers * 0.15).
# Lv2+15%dmg, Lv3+10%rng, Lv4+15%rate, Lv5+20%dmg, Lv6+10%rng+10%rate,
# Lv7+25%dmg, Lv8+15%rng, Lv9+20%rate, Lv10+30%dmg.
const LEVEL_DMG_MULTS  : Array = [1.0, 1.15, 1.15, 1.15, 1.35, 1.35, 1.60, 1.60, 1.60, 1.90]
const LEVEL_RNG_MULTS  : Array = [1.0, 1.0,  1.10, 1.10, 1.10, 1.20, 1.20, 1.35, 1.35, 1.35]
const LEVEL_RATE_MULTS : Array = [1.0, 1.0,  1.0,  1.15, 1.15, 1.25, 1.25, 1.25, 1.45, 1.45]

func tower_level_damage_mult(tower_id: String) -> float:
	var idx : int = clampi(get_tower_level(tower_id) - 1, 0, LEVEL_DMG_MULTS.size() - 1)
	return LEVEL_DMG_MULTS[idx]

func tower_level_range_mult(tower_id: String) -> float:
	var idx : int = clampi(get_tower_level(tower_id) - 1, 0, LEVEL_RNG_MULTS.size() - 1)
	return LEVEL_RNG_MULTS[idx]

func tower_level_fire_rate_mult(tower_id: String) -> float:
	var idx : int = clampi(get_tower_level(tower_id) - 1, 0, LEVEL_RATE_MULTS.size() - 1)
	return LEVEL_RATE_MULTS[idx]

# Combined additive multipliers — level bonus + upgrade bonus, both from original base.
# Formula: 1.0 + (level_bonus) + (upgrade_bonus). Matches turret_damage_mult convention.
func tower_total_damage_mult(tower_id: String) -> float:
	return 1.0 + (tower_level_damage_mult(tower_id) - 1.0) + (get_upgrade_tiers(tower_id + "_dmg") * 0.15)

func tower_total_fire_rate_mult(tower_id: String) -> float:
	return 1.0 + (tower_level_fire_rate_mult(tower_id) - 1.0) + (get_upgrade_tiers(tower_id + "_spd") * 0.15)

func tower_total_range_mult(tower_id: String) -> float:
	return tower_level_range_mult(tower_id)  # no range upgrade tiers
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
	  "desc": "All turrets deal +1 damage per shot." },
	{ "id": "fire_rate_5",     "rarity": "common", "name": "Oiled Mechanisms",
	  "desc": "All turrets fire 5% faster." },
	{ "id": "gold_10",         "rarity": "common", "name": "Looter's Instinct",
	  "desc": "Enemies drop 10% more gold." },
	{ "id": "summon_cost_10g", "rarity": "common", "name": "Bulk Discount",
	  "desc": "All summon rolls cost 5g less." },
	{ "id": "lives_5",         "rarity": "common", "name": "Reinforcements",
	  "desc": "Gain 5 lives." },
	# Rare
	{ "id": "dmg_5",           "rarity": "rare",   "name": "Sharpened Blades",
	  "desc": "All turrets deal +3 damage per shot." },
	{ "id": "fire_rate_15",    "rarity": "rare",   "name": "Rapid Assembly",
	  "desc": "All turrets fire 15% faster." },
	{ "id": "boss_dmg_25",     "rarity": "rare",   "name": "Giant Slayer",
	  "desc": "All turrets deal 10% more damage to bosses." },
	{ "id": "enemy_slow_10",   "rarity": "rare",   "name": "Heavy Terrain",
	  "desc": "All enemies move 10% slower. Stacks with frost." },
	{ "id": "dot_1",           "rarity": "rare",   "name": "Caustic Field",
	  "desc": "All enemies take 1 damage every second." },
	# Epic
	{ "id": "dmg_8",           "rarity": "epic",   "name": "Blessed Armaments",
	  "desc": "All turrets deal +5 damage per shot." },
	{ "id": "fire_rate_30",    "rarity": "epic",   "name": "War Machine",
	  "desc": "All turrets fire 30% faster." },
	{ "id": "boss_dmg_50",     "rarity": "epic",   "name": "Bane of Giants",
	  "desc": "All turrets deal 25% more damage to bosses." },
	{ "id": "enemy_slow_25",   "rarity": "epic",   "name": "Cursed Ground",
	  "desc": "All enemies move 20% slower. Stacks with frost." },
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
		"dmg_2":           buff_damage_flat    += 1.0   # Combat Training: +1
		"dmg_5":           buff_damage_flat    += 3.0   # Sharpened Blades: +3
		"dmg_8":           buff_damage_flat    += 5.0   # Blessed Armaments: +5
		"fire_rate_5":     buff_fire_rate_pct  += 0.05
		"fire_rate_15":    buff_fire_rate_pct  += 0.15
		"fire_rate_30":    buff_fire_rate_pct  += 0.30
		"gold_10":         buff_gold_pct       += 0.10
		"boss_dmg_25":     buff_boss_dmg_pct   += 0.10  # Giant Slayer: 10%
		"boss_dmg_50":     buff_boss_dmg_pct   += 0.25  # Bane of Giants: 25%
		"enemy_slow_10":   buff_enemy_slow_pct += 0.10
		"enemy_slow_25":   buff_enemy_slow_pct += 0.20  # Cursed Ground: 20%
		"dot_1":           buff_dot_dps        += 1.0
		"dot_3":           buff_dot_dps        += 3.0
		"lives_5":         buff_pending_lives  += 5
		"summon_cost_10g": pass  # handled in Main (now 5g less)

# ── Save / Load ───────────────────────────────────────────────────────────────
const SAVE_PATH    := "user://savegame.dat"
const SAVE_KEY     := "1b9f3c7e2a084d56"  # 16-char AES-256 key — do not change after shipping

func save_game() -> void:
	var data := {
		"run_gold":               run_gold,
		"all_time_highest_stage": all_time_highest_stage,
		"max_world_unlocked":      max_world_unlocked,
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
	max_world_unlocked     = int(d.get("max_world_unlocked",      1))
	blue_gems              = int(d.get("blue_gems",              0))
	var up = d.get("upgrade_purchases", {})
	if up is Dictionary:
		upgrade_purchases = up
	var tl = d.get("tower_levels", {})
	if tl is Dictionary:
		tower_levels = tl
		# Normalize: re-run the level-up loop on every entry so any accumulated XP
		# from older save formats is correctly converted into levels.
		for tid in tower_levels.keys():
			add_tower_xp(tid, 0)
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
	max_world_unlocked        = 1
	current_run_highest_stage = 0
	blue_gems                 = 0
	upgrade_purchases         = {}
	tower_levels              = {}
	reset_run_buffs()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

func _ready() -> void:
	load_game()
