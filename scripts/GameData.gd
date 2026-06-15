# scripts/GameData.gd  (AutoLoad singleton — persists across scene reloads)
# ─────────────────────────────────────────────────────────────────────────────
extends Node

# ── Stub constant kept for HUD compatibility until upgrade UI is replaced ─────
const MAX_LEVEL : int = 5

# ── Visual settings (toggled from gear menu) ──────────────────────────────────
var show_damage_numbers : bool = true
var show_projectiles    : bool = true

# ── Run state ─────────────────────────────────────────────────────────────────
var run_gold                  : int = 0
var current_run_highest_stage : int = 0
var all_time_highest_stage    : int = 0
var max_world_unlocked        : int = 1
var blue_gems                 : int = 0
var quest_tokens              : int = 0
var upgrade_purchases         : Dictionary = {}  # {node_id: tiers_bought}
var tower_levels              : Dictionary = {}  # {tower_id: {level:int, xp:int}}
var hero_talent_points        : Dictionary = {}  # {hero_id: int}  — unspent talent points
var hero_talent_alloc         : Dictionary = {}  # {hero_id: {dmg:int, rng:int, fr:int}}
var selected_hero_id          : String    = ""
var tutorial_complete         : bool      = false
var merge_tutorial_seen       : bool      = false
var special_tiles_seen        : bool      = false
var recipe_tutorial_seen      : bool      = false
var selected_world            : int       = 1     # in-memory only; set by HUD before scene reload
var launching_into_game       : bool      = false # true only when Start World triggers reload

# ── Daily Quests ──────────────────────────────────────────────────────────────
const DQ_KILL_TARGET  : int = 200
const DQ_SELL_TARGET  : int = 10
var dq_last_reset_date  : String = ""     # "YYYY-MM-DD"; when it changes, reset progress
var dq_kills_progress   : int    = 0      # Quest 1 — accumulates across all runs today
var dq_kills_complete   : bool   = false
var dq_mutated_complete : bool   = false  # Quest 2 — clear W1 in mutated mode
var dq_sell_complete    : bool   = false  # Quest 3 — sell ≥10 towers and clear W1 normal
var dq_kills_claimed    : bool   = false
var dq_mutated_claimed  : bool   = false
var dq_sell_claimed     : bool   = false
var dq_mode             : String = ""     # in-memory: "" | "mutated_w1" | "sell_w1"
var dq_sell_run_count   : int    = 0      # in-memory: tower sells in current sell_w1 run
var dq_unlocked         : bool   = false  # true after first defeat (unlocks Daily Quests tab)

# ── Relics ────────────────────────────────────────────────────────────────────
const RELIC_DEFS : Array = [
	{"id": "gold_rush",       "name": "Gold Rush",        "icon": "★",  "color": Color(1.00, 0.85, 0.15)},
	{"id": "power_surge",     "name": "Power Surge",      "icon": "⚔",  "color": Color(1.00, 0.38, 0.08)},
	{"id": "swift_wind",      "name": "Swift Wind",       "icon": "▲",  "color": Color(0.30, 0.88, 0.85)},
	{"id": "war_spoils",      "name": "War Spoils",       "icon": "◆",  "color": Color(0.25, 0.82, 0.45)},
	{"id": "merchants_deal",  "name": "Merchant's Deal",  "icon": "●",  "color": Color(0.95, 0.72, 0.10)},
	{"id": "rite_of_five",    "name": "Rite of Five",     "icon": "✦",  "color": Color(0.75, 0.35, 1.00)},
	{"id": "treasury",        "name": "Treasury",         "icon": "■",  "color": Color(0.50, 0.85, 0.35)},
	{"id": "bloodlust_tide",  "name": "Bloodlust Tide",   "icon": "♦",  "color": Color(0.90, 0.12, 0.18)},
	{"id": "castle_tax",      "name": "Castle Tax",       "icon": "◉",  "color": Color(0.45, 0.65, 0.90)},
	{"id": "founders_pledge", "name": "Founder's Pledge", "icon": "◎",  "color": Color(1.00, 0.60, 0.15)},
]
var relics_collected : Array     = []
var relic_levels     : Dictionary = {}   # {relic_id: int}  starts at 1 on first collect

func get_relic_def(id: String) -> Dictionary:
	for r in RELIC_DEFS:
		if r["id"] == id:
			return r
	return {}

func get_relic_pool() -> Array:
	var pool : Array = []
	for r in RELIC_DEFS:
		if not relics_collected.has(r["id"]):
			pool.append(r["id"])
	return pool

func get_relic_level(id: String) -> int:
	return int(relic_levels.get(id, 1))

func get_relic_upgrade_cost(id: String) -> int:
	return 200 + (get_relic_level(id) - 1) * 100

func get_relic_effect_text(id: String, level: int) -> String:
	match id:
		"gold_rush":
			return "Every 10 enemies killed: +%d gold." % level
		"power_surge":
			return "Every 10 enemies killed: a random owned\ntower gains +%d base attack." % level
		"swift_wind":
			return "Every 10 enemies killed: a random owned\ntower gains +%d%% attack speed." % (level * 5)
		"war_spoils":
			return "End of each stage: gain a random Common tower.\nIf your grid is full, gain %dg instead." % (20 + level * 5)
		"merchants_deal":
			return "All tower summon costs reduced by %d gold." % level
		"rite_of_five":
			match level:
				1: return "At stage 5, automatically summon\na random Rare tower."
				2: return "At stages 5 and 10, automatically\nsummon a random Rare tower."
				3: return "At stages 5, 10, and 15, automatically\nsummon a random Rare tower."
				_: return "At every 5th stage, automatically\nsummon a random Rare tower."
		"treasury":
			return "At the start of each new stage,\ngain %d%% of your current gold." % (level * 5)
		"bloodlust_tide":
			return "Every 5th wave, all towers gain\n+%d%% attack speed for 10 seconds." % (level * 20)
		"castle_tax":
			return "Enemies that reach the castle drop\n%d gold per hit taken (minimum %d gold)." % [level, level]
		"founders_pledge":
			return "The first tower placed each stage costs\n%d fewer gold (minimum 1)." % level
		_:
			return ""

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
	if not tower_levels.has(tower_id):
		return 0 if HERO_DEFS.has(tower_id) else 1
	return int(tower_levels[tower_id].get("level", 1))

func get_tower_xp(tower_id: String) -> int:
	return int(tower_levels.get(tower_id, {}).get("xp", 0))

# Copies needed to go from level N to N+1 (index 0 = Lv1→Lv2)
const COPIES_PER_LEVEL : Array = [2, 4, 6, 8, 12, 16, 20, 24, 30]

func copies_needed_for_level(lvl: int) -> int:
	if lvl == 0:
		return 1   # 1 copy unlocks the hero (level 0 → 1)
	var idx : int = clampi(lvl - 1, 0, COPIES_PER_LEVEL.size() - 1)
	return COPIES_PER_LEVEL[idx]

func add_tower_xp(tower_id: String, amount: int) -> void:
	if not tower_levels.has(tower_id):
		var start_lv : int = 0 if HERO_DEFS.has(tower_id) else 1
		tower_levels[tower_id] = {"level": start_lv, "xp": 0}
	tower_levels[tower_id]["xp"] += amount
	while tower_levels[tower_id]["level"] < TOWER_MAX_LEVEL:
		var needed : int = copies_needed_for_level(tower_levels[tower_id]["level"])
		if tower_levels[tower_id]["xp"] >= needed:
			tower_levels[tower_id]["xp"] -= needed
			tower_levels[tower_id]["level"] += 1
			if HERO_DEFS.has(tower_id):
				hero_talent_points[tower_id] = hero_talent_points.get(tower_id, 0) + 1
		else:
			break
	save_game()

func add_tower_copy(tower_id: String) -> void:
	add_tower_xp(tower_id, 1)

func get_hero_talent_points(hero_id: String) -> int:
	return int(hero_talent_points.get(hero_id, 0))

func get_hero_talent_alloc(hero_id: String) -> Dictionary:
	var a : Dictionary = hero_talent_alloc.get(hero_id, {})
	return {"dmg": int(a.get("dmg", 0)), "rng": int(a.get("rng", 0)), "fr": int(a.get("fr", 0))}

func spend_hero_talent(hero_id: String, stat: String) -> bool:
	if get_hero_talent_points(hero_id) <= 0:
		return false
	if not hero_talent_alloc.has(hero_id):
		hero_talent_alloc[hero_id] = {"dmg": 0, "rng": 0, "fr": 0}
	hero_talent_alloc[hero_id][stat] = int(hero_talent_alloc[hero_id].get(stat, 0)) + 1
	hero_talent_points[hero_id] = get_hero_talent_points(hero_id) - 1
	save_game()
	return true

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
var run_pending_cards      : Array = []   # [{type,id,rarity}] earned from boss drops this run

func apply_run_cards() -> void:
	for card in run_pending_cards:
		add_tower_copy(card["id"])  # heroes use same XP/level system
	run_pending_cards.clear()
	save_game()

func heroes_of_rarity(rarity: String) -> Array:
	var result : Array = []
	for hero_id in HERO_DEFS:
		if HERO_DEFS[hero_id].get("rarity", "") == rarity:
			result.append(hero_id)
	return result

func reset_run_buffs() -> void:
	buff_damage_flat    = 0.0
	buff_fire_rate_pct  = 0.0
	buff_boss_dmg_pct   = 0.0
	buff_enemy_slow_pct = 0.0
	buff_dot_dps        = 0.0
	buff_gold_pct       = 0.0
	buff_pending_lives  = 0
	chosen_buffs        = []
	run_pending_cards   = []

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
		"quest_tokens":           quest_tokens,
		"upgrade_purchases":      upgrade_purchases,
		"tower_levels":           tower_levels,
		"hero_talent_points":     hero_talent_points,
		"hero_talent_alloc":      hero_talent_alloc,
		"selected_hero_id":       selected_hero_id,
		"tutorial_complete":      tutorial_complete,
		"merge_tutorial_seen":    merge_tutorial_seen,
		"special_tiles_seen":     special_tiles_seen,
		"recipe_tutorial_seen":   recipe_tutorial_seen,
		"dq_last_reset_date":     dq_last_reset_date,
		"dq_kills_progress":      dq_kills_progress,
		"dq_kills_complete":      dq_kills_complete,
		"dq_mutated_complete":    dq_mutated_complete,
		"dq_sell_complete":       dq_sell_complete,
		"dq_kills_claimed":       dq_kills_claimed,
		"dq_mutated_claimed":     dq_mutated_claimed,
		"dq_sell_claimed":        dq_sell_claimed,
		"dq_unlocked":            dq_unlocked,
		"relics_collected":       relics_collected,
		"relic_levels":           relic_levels,
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
	quest_tokens           = int(d.get("quest_tokens",           0))
	var up = d.get("upgrade_purchases", {})
	if up is Dictionary:
		upgrade_purchases = up
	var tl = d.get("tower_levels", {})
	if tl is Dictionary:
		tower_levels = tl
	var htp = d.get("hero_talent_points", {})
	if htp is Dictionary:
		hero_talent_points = htp
	var hta = d.get("hero_talent_alloc", {})
	if hta is Dictionary:
		hero_talent_alloc = hta
		# Normalize: re-run the level-up loop on every entry so any accumulated XP
		# from older save formats is correctly converted into levels.
		for tid in tower_levels.keys():
			add_tower_xp(tid, 0)
	var shi = d.get("selected_hero_id", "")
	if shi is String and (shi == "" or HERO_DEFS.has(shi)):
		selected_hero_id = shi
	tutorial_complete      = bool(d.get("tutorial_complete",    false))
	merge_tutorial_seen    = bool(d.get("merge_tutorial_seen",  false))
	special_tiles_seen     = bool(d.get("special_tiles_seen",   false))
	recipe_tutorial_seen   = bool(d.get("recipe_tutorial_seen", false))
	dq_last_reset_date     = str(d.get("dq_last_reset_date",    ""))
	dq_kills_progress      = int(d.get("dq_kills_progress",     0))
	dq_kills_complete      = bool(d.get("dq_kills_complete",    false))
	dq_mutated_complete    = bool(d.get("dq_mutated_complete",  false))
	dq_sell_complete       = bool(d.get("dq_sell_complete",     false))
	dq_kills_claimed       = bool(d.get("dq_kills_claimed",     false))
	dq_mutated_claimed     = bool(d.get("dq_mutated_claimed",   false))
	dq_sell_claimed        = bool(d.get("dq_sell_claimed",      false))
	dq_unlocked            = bool(d.get("dq_unlocked",          false))
	var rc = d.get("relics_collected", [])
	if rc is Array:
		relics_collected = rc
	var rl = d.get("relic_levels", {})
	if rl is Dictionary:
		relic_levels = rl
	_reconcile_hero_talents()

func _reconcile_hero_talents() -> void:
	for hero_id in tower_levels:
		if not HERO_DEFS.has(hero_id):
			continue
		var hero_lv       : int = int(tower_levels[hero_id].get("level", 0))
		var expected      : int = hero_lv
		var alloc         := get_hero_talent_alloc(hero_id)
		var spent         : int = alloc.dmg + alloc.rng + alloc.fr
		var available     : int = int(hero_talent_points.get(hero_id, 0))
		var missing       : int = expected - (available + spent)
		if missing > 0:
			hero_talent_points[hero_id] = available + missing

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

static func get_world_path(world: int) -> Array:
	match world:
		1: return [
			Vector2(-40,140),Vector2(850,140),Vector2(850,500),Vector2(250,500),Vector2(250,140),
			Vector2(850,140),Vector2(850,500),Vector2(250,500),Vector2(250,140),Vector2(-40,140),
		]
		2: return [  # Deep Forest — Z-snake (3 horizontal rails)
			Vector2(-10,140), Vector2(870,140),
			Vector2(870,320), Vector2(120,320),
			Vector2(120,500),  Vector2(870,500),
			Vector2(870,600), Vector2(-10,600),
		]
		3: return [  # Desert Ruins — figure-8 (two rectangular loops sharing a centre)
			Vector2(-10,320),
			Vector2(870,320), Vector2(870,140), Vector2(120,140),
			Vector2(120,320),
			Vector2(120,500),  Vector2(870,500), Vector2(870,320),
			Vector2(-10,320),
		]
		4: return [  # Frost Peaks — inward two-ring spiral
			Vector2(-10,140), Vector2(840,140),
			Vector2(840,500), Vector2(150,500),
			Vector2(150,200), Vector2(780,200),
			Vector2(780,440), Vector2(-10,440),
		]
		5: return [  # Volcanic Wastes — wide hexagonal oval × 2
			Vector2(-10,320),
			Vector2(150,140), Vector2(870,140),
			Vector2(990,320),
			Vector2(870,500), Vector2(150,500),
			Vector2(-10,320),
			Vector2(150,140), Vector2(870,140),
			Vector2(990,320),
			Vector2(870,500), Vector2(150,500),
			Vector2(-10,320),
		]
		6: return [  # Swamplands — X crossing × 2
			Vector2(-10,320),
			Vector2(150,140), Vector2(870,500),
			Vector2(870,140), Vector2(150,500),
			Vector2(-10,320),
			Vector2(150,140), Vector2(870,500),
			Vector2(870,140), Vector2(150,500),
			Vector2(-10,320),
		]
		7: return [  # Crystal Highlands — diamond loop × 2
			Vector2(-10,320),
			Vector2(510,110), Vector2(990,320),
			Vector2(510,530), Vector2(-10,320),
			Vector2(510,110), Vector2(990,320),
			Vector2(510,530), Vector2(-10,320),
		]
		8: return [  # Shadow Realm — figure-8 then large rectangle loop
			Vector2(-10,320),
			Vector2(780,320), Vector2(780,140), Vector2(210,140),
			Vector2(210,320),
			Vector2(210,500), Vector2(780,500), Vector2(780,320),
			Vector2(780,140), Vector2(210,140),
			Vector2(210,500), Vector2(780,500), Vector2(780,320),
			Vector2(-10,320),
		]
		9: return [  # Celestial Kingdom — grand oval loop × 2
			Vector2(-10,320),
			Vector2(270,140), Vector2(750,140),
			Vector2(900,320),
			Vector2(750,500), Vector2(270,500),
			Vector2(90,320),  Vector2(270,140),
			Vector2(750,140), Vector2(900,320),
			Vector2(750,500), Vector2(270,500),
			Vector2(-10,320),
		]
		10: return [  # Eternal Citadel — extended grand circuit
			Vector2(-10,140),Vector2(880,140),Vector2(985,310),Vector2(880,500),
			Vector2(280,500),Vector2(145,310),Vector2(280,140),
			Vector2(570,140),Vector2(880,72),Vector2(985,310),
			Vector2(880,565),Vector2(280,565),Vector2(145,310),Vector2(-10,310),
		]
		_: return get_world_path(1)


static func get_world_island(world: int) -> Rect2:
	match world:
		1:  return Rect2(280, 170, 540, 300)   # original 9×5 island
		2:  return Rect2(120, 110, 780, 420)   # 13×7  Deep Forest
		3:  return Rect2(120, 110, 780, 420)   # 13×7  Desert Ruins
		4:  return Rect2(150, 110, 720, 420)   # 12×7  Frost Peaks
		5:  return Rect2(150, 110, 720, 420)   # 12×7  Volcanic Wastes
		6:  return Rect2(150, 110, 720, 420)   # 12×7  Swamplands
		7:  return Rect2(150, 110, 720, 420)   # 12×7  Crystal Highlands
		8:  return Rect2(210, 110, 600, 420)   # 10×7  Shadow Realm
		9:  return Rect2( 90, 110, 840, 420)   # 14×7  Celestial Kingdom
		10: return Rect2( 90, 110, 840, 420)   # 14×7  Eternal Citadel
		_:  return get_world_island(1)

# ── World modifiers ───────────────────────────────────────────────────────────
# Each modifier: { type, value, label, color }
# types: "hp_pct", "gold_pct", "spd_pct", "skeleton_pct", "melee_resist"
static func get_world_modifiers(world: int) -> Array:
	var data : Array = [
		[],  # World 1 — no modifiers
		[{"type":"hp_pct",      "value":5,  "label":"Enemies have +5% max health",         "color":Color(1.00,0.40,0.40)}],
		[{"type":"hp_pct",      "value":5,  "label":"Enemies have +5% max health",         "color":Color(1.00,0.40,0.40)},
		 {"type":"gold_pct",    "value":-5, "label":"Enemies drop 5% less gold",           "color":Color(1.00,0.72,0.12)}],
		[{"type":"hp_pct",      "value":10, "label":"Enemies have +10% max health",        "color":Color(1.00,0.40,0.40)},
		 {"type":"skeleton_pct","value":10, "label":"10% chance to respawn as a Skeleton", "color":Color(0.82,0.82,0.64)}],
		[{"type":"hp_pct",      "value":10, "label":"Enemies have +10% max health",        "color":Color(1.00,0.40,0.40)},
		 {"type":"gold_pct",    "value":-10,"label":"Enemies drop 10% less gold",          "color":Color(1.00,0.72,0.12)},
		 {"type":"spd_pct",     "value":5,  "label":"Enemies move 5% faster",              "color":Color(1.00,0.55,0.15)}],
		[{"type":"hp_pct",      "value":15, "label":"Enemies have +15% max health",        "color":Color(1.00,0.40,0.40)},
		 {"type":"gold_pct",    "value":-10,"label":"Enemies drop 10% less gold",          "color":Color(1.00,0.72,0.12)},
		 {"type":"skeleton_pct","value":15, "label":"15% chance to respawn as a Skeleton", "color":Color(0.82,0.82,0.64)}],
		[{"type":"hp_pct",      "value":20, "label":"Enemies have +20% max health",        "color":Color(1.00,0.40,0.40)},
		 {"type":"gold_pct",    "value":-15,"label":"Enemies drop 15% less gold",          "color":Color(1.00,0.72,0.12)},
		 {"type":"spd_pct",     "value":10, "label":"Enemies move 10% faster",             "color":Color(1.00,0.55,0.15)},
		 {"type":"melee_resist","value":25, "label":"Enemies take 25% less melee damage",  "color":Color(0.45,0.75,1.00)}],
		[{"type":"hp_pct",      "value":25, "label":"Enemies have +25% max health",        "color":Color(1.00,0.40,0.40)},
		 {"type":"gold_pct",    "value":-15,"label":"Enemies drop 15% less gold",          "color":Color(1.00,0.72,0.12)},
		 {"type":"spd_pct",     "value":10, "label":"Enemies move 10% faster",             "color":Color(1.00,0.55,0.15)},
		 {"type":"skeleton_pct","value":20, "label":"20% chance to respawn as a Skeleton", "color":Color(0.82,0.82,0.64)}],
		[{"type":"hp_pct",      "value":30, "label":"Enemies have +30% max health",        "color":Color(1.00,0.40,0.40)},
		 {"type":"gold_pct",    "value":-20,"label":"Enemies drop 20% less gold",          "color":Color(1.00,0.72,0.12)},
		 {"type":"spd_pct",     "value":15, "label":"Enemies move 15% faster",             "color":Color(1.00,0.55,0.15)},
		 {"type":"skeleton_pct","value":25, "label":"25% chance to respawn as a Skeleton", "color":Color(0.82,0.82,0.64)},
		 {"type":"melee_resist","value":25, "label":"Enemies take 25% less melee damage",  "color":Color(0.45,0.75,1.00)}],
		[{"type":"hp_pct",      "value":40, "label":"Enemies have +40% max health",        "color":Color(1.00,0.40,0.40)},
		 {"type":"gold_pct",    "value":-25,"label":"Enemies drop 25% less gold",          "color":Color(1.00,0.72,0.12)},
		 {"type":"spd_pct",     "value":20, "label":"Enemies move 20% faster",             "color":Color(1.00,0.55,0.15)},
		 {"type":"skeleton_pct","value":30, "label":"30% chance to respawn as a Skeleton", "color":Color(0.82,0.82,0.64)},
		 {"type":"melee_resist","value":50, "label":"Enemies take 50% less melee damage",  "color":Color(0.45,0.75,1.00)}],
	]
	if world < 1 or world > data.size():
		return []
	return data[world - 1]

static func world_hp_mult(world: int) -> float:
	for m in get_world_modifiers(world):
		if m["type"] == "hp_pct": return 1.0 + float(m["value"]) / 100.0
	return 1.0

static func world_gold_mult(world: int) -> float:
	for m in get_world_modifiers(world):
		if m["type"] == "gold_pct": return 1.0 + float(m["value"]) / 100.0
	return 1.0

static func world_spd_mult(world: int) -> float:
	for m in get_world_modifiers(world):
		if m["type"] == "spd_pct": return 1.0 + float(m["value"]) / 100.0
	return 1.0

static func world_skeleton_chance(world: int) -> float:
	for m in get_world_modifiers(world):
		if m["type"] == "skeleton_pct": return float(m["value"]) / 100.0
	return 0.0

static func world_melee_resist(world: int) -> float:
	for m in get_world_modifiers(world):
		if m["type"] == "melee_resist": return float(m["value"]) / 100.0
	return 0.0


func reset_save() -> void:
	run_gold                  = 0
	all_time_highest_stage    = 0
	max_world_unlocked        = 1
	current_run_highest_stage = 0
	blue_gems                 = 0
	quest_tokens              = 0
	upgrade_purchases         = {}
	tower_levels              = {}
	hero_talent_points        = {}
	hero_talent_alloc         = {}
	selected_hero_id          = ""
	tutorial_complete         = false
	merge_tutorial_seen       = false
	special_tiles_seen        = false
	recipe_tutorial_seen      = false
	dq_last_reset_date        = ""
	dq_kills_progress         = 0
	dq_kills_complete         = false
	dq_mutated_complete       = false
	dq_sell_complete          = false
	dq_kills_claimed          = false
	dq_mutated_claimed        = false
	dq_sell_claimed           = false
	relics_collected          = []
	relic_levels              = {}
	reset_run_buffs()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	save_game()

func check_daily_reset() -> void:
	var today : String = Time.get_date_string_from_system()
	if dq_last_reset_date != today:
		dq_last_reset_date  = today
		dq_kills_progress   = 0
		dq_kills_complete   = false
		dq_mutated_complete = false
		dq_sell_complete    = false
		dq_kills_claimed    = false
		dq_mutated_claimed  = false
		dq_sell_claimed     = false
		save_game()

func _ready() -> void:
	load_game()
	check_daily_reset()
