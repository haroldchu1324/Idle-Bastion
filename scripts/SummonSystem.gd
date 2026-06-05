# scripts/SummonSystem.gd  (AutoLoad singleton)
# ─────────────────────────────────────────────────────────────────────────────
# Manages the random summon system, bench inventory, and fusion recipes.
extends Node

# ── Bench ─────────────────────────────────────────────────────────────────────
var bench : Array = []   # Array[Dictionary] – turret data for each bench slot
const BENCH_SIZE : int = 5

# ── Summon Level (per-run, resets each run) ───────────────────────────────────
var summon_level : int = 1
const SUMMON_LEVEL_MAX   : int   = 5
const SUMMON_LEVEL_COSTS : Array = [100, 250, 500, 1000, 2000]  # cost to go from lvl n → n+1

var total_summons : int = 0

# ── Summon costs ──────────────────────────────────────────────────────────────
const BASIC_COST    : int = 20
const ADVANCED_COST : int = 75
const RITUAL_COST   : int = 200

# ── New pool costs (flat; common increases per-pull in Main.gd) ───────────────
const COMMON_SUMMON_COST_BASE : int = 40
const RARE_SUMMON_COST        : int = 100
const EPIC_SUMMON_COST        : int = 250

# ── New pool odds [common, rare, epic, legendary] ─────────────────────────────
const COMMON_POOL_ODDS : Array = [75, 22,  3,  0]
const RARE_POOL_ODDS   : Array = [ 0, 75, 22,  3]
const EPIC_POOL_ODDS   : Array = [ 0, 15, 75, 10]

# ── Sell values per rarity ────────────────────────────────────────────────────
const SELL_VALUES : Dictionary = {
	"common": 5, "rare": 15, "epic": 40, "legendary": 100
}

# ── Rarity colours ────────────────────────────────────────────────────────────
const RARITY_COLORS : Dictionary = {
	"common":    Color(0.75, 0.75, 0.75),
	"rare":      Color(0.25, 0.55, 1.00),
	"epic":      Color(0.72, 0.25, 0.90),
	"legendary": Color(1.00, 0.72, 0.10),
	"fusion":    Color(0.20, 1.00, 0.85),
}

# ── Summon odds per level [common, rare, epic, legendary] ────────────────────
# LEVEL_ODDS[level-1][type: 0=basic 1=advanced 2=ritual]
const LEVEL_ODDS : Array = [
	# Level 1 (base)
	[[75, 22,  3,  0], [40, 45, 14,  1], [ 0, 55, 40,  5]],
	# Level 2
	[[65, 28,  7,  0], [35, 45, 18,  2], [ 0, 50, 43,  7]],
	# Level 3
	[[55, 35,  9,  1], [30, 44, 22,  4], [ 0, 44, 46, 10]],
	# Level 4
	[[45, 40, 13,  2], [25, 42, 27,  6], [ 0, 38, 48, 14]],
	# Level 5
	[[30, 45, 20,  5], [18, 38, 34, 10], [ 0, 30, 52, 18]],
]

# Convenience aliases for Level-1 odds (backward compat)
const BASIC_ODDS    : Array = [75, 22,  3,  0]
const ADVANCED_ODDS : Array = [40, 45, 14,  1]
const RITUAL_ODDS   : Array = [ 0, 55, 40,  5]

# ── Rarity pools ──────────────────────────────────────────────────────────────
const COMMON_IDS    : Array = ["archer", "crossbow", "mage", "catapult", "spearman", "rogue"]
const RARE_IDS      : Array = ["flame_tower", "frost_spire", "poison_tower", "sniper_tower", "elite_knight", "iron_guard"]
const EPIC_IDS      : Array = ["tesla_tower", "infernal_core", "ballista", "arcane_cannon"]
const LEGENDARY_IDS : Array = ["sun_dragon", "storm_lord", "chrono_mage", "world_tree"]

# ── All turret definitions ────────────────────────────────────────────────────
# "cost" field kept at 0 — turrets are obtained only through summons.
const TURRET_DEFS : Dictionary = {
	# ── Common ────────────────────────────────────────────────────────────────
	"archer": {
		"id": "archer", "name": "Archer", "rarity": "common", "idx": 0,
		"desc": "Focused shots — each\nconsecutive hit deals +50% dmg.",
		"cost": 0, "damage": 5.0, "range": 200.0, "fire_rate": 1.0,
		"color": Color(0.35, 0.75, 0.25), "effect": "focused_shot",
	},
	"crossbow": {
		"id": "crossbow", "name": "Crossbow", "rarity": "common", "idx": 1,
		"desc": "Fires 2 bolts at once,\nhitting 2 separate enemies.",
		"cost": 0, "damage": 5.0, "range": 200.0, "fire_rate": 1.2,
		"color": Color(0.35, 0.55, 0.90), "effect": "dual_shot",
	},
	"mage": {
		"id": "mage", "name": "Mage Tower", "rarity": "common", "idx": 3,
		"desc": "Hits 3 enemies — main target\ntakes full, others take 50%.",
		"cost": 0, "damage": 4.0, "range": 200.0, "fire_rate": 1.0,
		"color": Color(0.70, 0.28, 0.92), "effect": "chain",
	},
	"catapult": {
		"id": "catapult", "name": "Catapult", "rarity": "common", "idx": 2,
		"desc": "Slow AoE blast hits\nup to 5 enemies at once.",
		"cost": 0, "damage": 8.0, "range": 180.0, "fire_rate": 0.35,
		"color": Color(0.80, 0.50, 0.20), "effect": "aoe_burst",
	},
	"spearman": {
		"id": "spearman", "name": "Spearman", "rarity": "common", "idx": 26,
		"desc": "Melee fighter — every 3rd\nhit cleaves all nearby enemies.",
		"cost": 0, "damage": 8.0, "range": 120.0, "fire_rate": 1.0,
		"color": Color(0.72, 0.52, 0.28), "effect": "melee_cleave",
	},
	"rogue": {
		"id": "rogue", "name": "Rogue", "rarity": "common", "idx": 27,
		"desc": "Melee AoE — each hit bleeds\nenemies up to 3 stacks.",
		"cost": 0, "damage": 3.0, "range": 120.0, "fire_rate": 1.5,
		"color": Color(0.22, 0.22, 0.28), "effect": "bleed_aoe",
	},
	# ── Rare ──────────────────────────────────────────────────────────────────
	"flame_tower": {
		"id": "flame_tower", "name": "Flame Tower", "rarity": "rare", "idx": 5,
		"desc": "Burns enemies in a\nwide area of fire.",
		"cost": 0, "damage": 9.0, "range": 190.0, "fire_rate": 1.2,
		"color": Color(1.00, 0.38, 0.08), "effect": "aoe",
	},
	"frost_spire": {
		"id": "frost_spire", "name": "Frost Spire", "rarity": "rare", "idx": 6,
		"desc": "Icy shots slow enemies;\nevery 5th drops a slow zone.",
		"cost": 0, "damage": 12.0, "range": 200.0, "fire_rate": 1.2,
		"color": Color(0.50, 0.85, 1.00), "effect": "slow_zone",
	},
	"poison_tower": {
		"id": "poison_tower", "name": "Poison Tower", "rarity": "rare", "idx": 7,
		"desc": "Poisons enemies — 10% extra\ndmg taken for 5s. Prioritizes fresh targets.",
		"cost": 0, "damage": 12.0, "range": 200.0, "fire_rate": 1.0,
		"color": Color(0.30, 0.80, 0.20), "effect": "poison_debuff",
	},
	"sniper_tower": {
		"id": "sniper_tower", "name": "Sniper Tower", "rarity": "rare", "idx": 8,
		"desc": "Deals up to 2× damage\nbased on enemy's current HP%.",
		"cost": 0, "damage": 25.0, "range": 200.0, "fire_rate": 1.0,
		"color": Color(0.60, 0.55, 0.45), "effect": "execute_shot",
	},
	"iron_guard": {
		"id": "iron_guard", "name": "Iron Guard", "rarity": "rare", "idx": 29,
		"desc": "Melee — every 3rd swing is AoE\nand pushes enemies back 1 tile.",
		"cost": 0, "damage": 38.0, "range": 120.0, "fire_rate": 0.7,
		"color": Color(0.55, 0.60, 0.72), "effect": "knight_slam",
	},
	"elite_knight": {
		"id": "elite_knight", "name": "Elite Knight", "rarity": "rare", "idx": 28,
		"desc": "Heavy melee — every 3rd hit\ncleaves all enemies in range.",
		"cost": 0, "damage": 25.0, "range": 120.0, "fire_rate": 1.5,
		"color": Color(0.65, 0.70, 0.82), "effect": "melee_cleave",
	},
	# ── Epic ──────────────────────────────────────────────────────────────────
	"tesla_tower": {
		"id": "tesla_tower", "name": "Tesla Tower", "rarity": "epic", "idx": 9,
		"desc": "Chains lightning\nto 4 enemies at once.",
		"cost": 0, "damage": 12.5, "range": 230.0, "fire_rate": 1.0,
		"color": Color(0.40, 0.80, 1.00), "effect": "lightning",
	},
	"infernal_core": {
		"id": "infernal_core", "name": "Infernal Core", "rarity": "epic", "idx": 10,
		"desc": "Locks beam on one target.\nDamage ramps +50% over 5s.",
		"cost": 0, "damage": 27.0, "range": 200.0, "fire_rate": 1.0,
		"color": Color(1.00, 0.25, 0.10), "effect": "lock_beam",
	},
	"ballista": {
		"id": "ballista", "name": "Ballista", "rarity": "epic", "idx": 11,
		"desc": "Bolt deals base dmg + 1% of\nenemy's current HP (non-boss).",
		"cost": 0, "damage": 40.0, "range": 260.0, "fire_rate": 1.0,
		"color": Color(0.55, 0.42, 0.30), "effect": "hp_strike",
	},
	"arcane_cannon": {
		"id": "arcane_cannon", "name": "Arcane Cannon", "rarity": "epic", "idx": 12,
		"desc": "Charges over 20 hits — releases\na blue ray hitting all enemies.",
		"cost": 0, "damage": 40.0, "range": 220.0, "fire_rate": 1.0,
		"color": Color(0.80, 0.30, 0.90), "effect": "arcane_charge",
	},
	# ── Legendary ─────────────────────────────────────────────────────────────
	"sun_dragon": {
		"id": "sun_dragon", "name": "Sun Dragon", "rarity": "legendary", "idx": 13,
		"desc": "Devastating AoE fire.\nBurns all enemies in range.",
		"cost": 0, "damage": 60.0, "range": 240.0, "fire_rate": 0.7,
		"color": Color(1.00, 0.62, 0.05), "effect": "aoe",
	},
	"storm_lord": {
		"id": "storm_lord", "name": "Storm Lord", "rarity": "legendary", "idx": 14,
		"desc": "Chains lightning to\n5 enemies simultaneously.",
		"cost": 0, "damage": 35.0, "range": 250.0, "fire_rate": 0.9,
		"color": Color(0.60, 0.80, 1.00), "effect": "storm_chain",
	},
	"chrono_mage": {
		"id": "chrono_mage", "name": "Chrono Mage", "rarity": "legendary", "idx": 15,
		"desc": "Slows all enemies\nin a massive area.",
		"cost": 0, "damage": 17.5, "range": 260.0, "fire_rate": 1.1,
		"color": Color(0.20, 0.90, 0.75), "effect": "aoe",
	},
	"world_tree": {
		"id": "world_tree", "name": "World Tree", "rarity": "legendary", "idx": 16,
		"desc": "Buffs nearby towers.\nSpreads roots to enemies.",
		"cost": 0, "damage": 10.0, "range": 240.0, "fire_rate": 1.3,
		"color": Color(0.20, 0.75, 0.30), "effect": "chain",
	},
	# ── Fusion (special crafted turrets) ──────────────────────────────────────
	"venom_drake": {
		"id": "venom_drake", "name": "Venom Drake", "rarity": "fusion", "idx": 17,
		"desc": "Toxic storm rains\npoison on all nearby foes.",
		"cost": 0, "damage": 35.0, "range": 215.0, "fire_rate": 0.8,
		"color": Color(0.28, 0.78, 0.30), "effect": "aoe",
	},
	"frost_cannon": {
		"id": "frost_cannon", "name": "Frost Cannon", "rarity": "fusion", "idx": 18,
		"desc": "Penetrating icy bolt\nslows and pierces all enemies.",
		"cost": 0, "damage": 45.0, "range": 350.0, "fire_rate": 0.5,
		"color": Color(0.55, 0.90, 1.00), "effect": "pierce",
	},
	"arcane_overlord": {
		"id": "arcane_overlord", "name": "Arcane Overlord", "rarity": "fusion", "idx": 19,
		"desc": "Arcane inferno erupts\nin chains across the field.",
		"cost": 0, "damage": 55.0, "range": 230.0, "fire_rate": 0.65,
		"color": Color(0.90, 0.42, 0.12), "effect": "chain",
	},
	"dragon_lich": {
		"id": "dragon_lich", "name": "Dragon Lich", "rarity": "fusion", "idx": 20,
		"desc": "Soul-draining dragon fire\nchains to 5 enemies.",
		"cost": 0, "damage": 80.0, "range": 250.0, "fire_rate": 0.85,
		"color": Color(0.72, 0.55, 0.90), "effect": "storm_chain",
	},
	"tempest_warden": {
		"id": "tempest_warden", "name": "Tempest Warden", "rarity": "fusion", "idx": 21,
		"desc": "Storm lord's chosen:\nlightning slows and decimates.",
		"cost": 0, "damage": 60.0, "range": 250.0, "fire_rate": 1.1,
		"color": Color(0.45, 0.75, 1.00), "effect": "lightning",
	},
	"infernal_serpent": {
		"id": "infernal_serpent", "name": "Infernal Serpent", "rarity": "fusion", "idx": 22,
		"desc": "Erupts in a pillar of dragonfire,\nincinerating all nearby foes.",
		"cost": 0, "damage": 90.0, "range": 220.0, "fire_rate": 0.75,
		"color": Color(1.00, 0.30, 0.05), "effect": "aoe",
	},
	"shadow_weaver": {
		"id": "shadow_weaver", "name": "Shadow Weaver", "rarity": "fusion", "idx": 23,
		"desc": "Void bolts pierce all enemies\nand freeze them in place.",
		"cost": 0, "damage": 55.0, "range": 420.0, "fire_rate": 0.55,
		"color": Color(0.55, 0.20, 0.85), "effect": "pierce",
	},
	"natures_wrath": {
		"id": "natures_wrath", "name": "Nature's Wrath", "rarity": "fusion", "idx": 24,
		"desc": "Ancient roots chain poison\nthrough entire enemy groups.",
		"cost": 0, "damage": 40.0, "range": 250.0, "fire_rate": 1.3,
		"color": Color(0.22, 0.85, 0.35), "effect": "chain",
	},
	"void_titan": {
		"id": "void_titan", "name": "Void Titan", "rarity": "fusion", "idx": 25,
		"desc": "Collapses space around it,\npulling and annihilating all foes.",
		"cost": 0, "damage": 75.0, "range": 235.0, "fire_rate": 0.9,
		"color": Color(0.30, 0.15, 0.55), "effect": "aoe",
	},
}

# ── Special fusion recipes ────────────────────────────────────────────────────
# Each requires exactly the listed material IDs (bench or placed), produces result.
const FUSION_RECIPES : Array = [
	# Venom Drake — no legendary (4 materials: 2 common + 1 rare + 1 epic)
	{ "materials": ["catapult", "mage", "poison_tower", "tesla_tower"],
	  "result": "venom_drake" },
	# Frost Cannon — no legendary (4 materials: 1 common + 2 rare + 1 epic)
	{ "materials": ["archer", "frost_spire", "sniper_tower", "ballista"],
	  "result": "frost_cannon" },
	# Arcane Overlord — no legendary (5 materials: 2 common + 1 rare + 2 epic)
	{ "materials": ["crossbow", "catapult", "flame_tower", "arcane_cannon", "infernal_core"],
	  "result": "arcane_overlord" },
	# Dragon Lich — 1 legendary (4 materials: 1 common + 1 rare + 1 epic + 1 legendary)
	{ "materials": ["mage", "poison_tower", "arcane_cannon", "sun_dragon"],
	  "result": "dragon_lich" },
	# Tempest Warden — 1 legendary (5 materials: 2 common + 1 rare + 1 epic + 1 legendary)
	{ "materials": ["archer", "crossbow", "frost_spire", "tesla_tower", "storm_lord"],
	  "result": "tempest_warden" },
	# Infernal Serpent — 1 legendary (4 materials: 1 common + 1 rare + 1 epic + 1 legendary)
	{ "materials": ["catapult", "flame_tower", "infernal_core", "sun_dragon"],
	  "result": "infernal_serpent" },
	# Shadow Weaver — 1 legendary (4 materials: 1 common + 2 rare + 1 legendary)
	{ "materials": ["crossbow", "sniper_tower", "ballista", "chrono_mage"],
	  "result": "shadow_weaver" },
	# Nature's Wrath — 1 legendary (5 materials: 1 common + 1 rare + 2 epic + 1 legendary)
	{ "materials": ["mage", "poison_tower", "tesla_tower", "arcane_cannon", "world_tree"],
	  "result": "natures_wrath" },
	# Void Titan — 1 legendary (4 materials: 1 common + 1 epic + 2 legendary)
	{ "materials": ["catapult", "arcane_cannon", "storm_lord", "chrono_mage"],
	  "result": "void_titan" },
]

# ── Helpers ───────────────────────────────────────────────────────────────────

func get_pool(rarity: String) -> Array:
	match rarity:
		"common":    return COMMON_IDS
		"rare":      return RARE_IDS
		"epic":      return EPIC_IDS
		"legendary": return LEGENDARY_IDS
	return COMMON_IDS


func get_random_turret_by_rarity(rarity: String) -> Dictionary:
	var pool := get_pool(rarity)
	var id : String = pool[randi() % pool.size()]
	return TURRET_DEFS[id].duplicate()


func _roll_rarity(odds: Array) -> String:
	var r := randi() % 100
	var cum := 0
	var names := ["common", "rare", "epic", "legendary"]
	for i in range(4):
		cum += odds[i]
		if r < cum:
			return names[i]
	return "common"


func roll_by_pool(pool_type: String) -> Dictionary:
	var odds : Array
	match pool_type:
		"common": odds = COMMON_POOL_ODDS
		"rare":   odds = RARE_POOL_ODDS
		"epic":   odds = EPIC_POOL_ODDS
		_:        odds = COMMON_POOL_ODDS
	var rarity : String = _roll_rarity(odds)
	total_summons += 1
	return get_random_turret_by_rarity(rarity)


func roll_summon(type: String) -> Dictionary:
	var li       : int = clamp(summon_level - 1, 0, LEVEL_ODDS.size() - 1)
	var ti       : int = {"basic": 0, "advanced": 1, "ritual": 2}.get(type, 0)
	var odds     := (LEVEL_ODDS[li][ti] as Array).duplicate()

	var rarity : String = _roll_rarity(odds)
	total_summons += 1
	return get_random_turret_by_rarity(rarity)


func add_turret_to_bench(turret: Dictionary) -> bool:
	if bench.size() >= BENCH_SIZE:
		return false
	bench.append(turret)
	return true


func remove_from_bench(idx: int) -> Dictionary:
	if idx < 0 or idx >= bench.size():
		return {}
	var t : Dictionary = bench[idx]
	bench.remove_at(idx)
	return t


func is_bench_full() -> bool:
	return bench.size() >= BENCH_SIZE


func get_rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)


func get_sell_value(rarity: String) -> int:
	return SELL_VALUES.get(rarity, 5)


func get_summon_cost(type: String) -> int:
	var base : int
	match type:
		"basic":    base = BASIC_COST
		"advanced": base = ADVANCED_COST
		"ritual":   base = RITUAL_COST
		_:          base = BASIC_COST
	return maxi(base, 1)


func get_summon_level_cost() -> int:
	if summon_level >= SUMMON_LEVEL_MAX:
		return -1
	return SUMMON_LEVEL_COSTS[summon_level - 1]


func upgrade_summon_level() -> void:
	if summon_level < SUMMON_LEVEL_MAX:
		summon_level += 1


func get_current_odds_text(type: String) -> String:
	var li  : int = clamp(summon_level - 1, 0, LEVEL_ODDS.size() - 1)
	var ti  : int = {"basic": 0, "advanced": 1, "ritual": 2}.get(type, 0)
	var o   := LEVEL_ODDS[li][ti] as Array
	return "C:%d  R:%d  E:%d  L:%d" % [o[0], o[1], o[2], o[3]]


func reset_run_state() -> void:
	bench         = []
	summon_level  = 1
	total_summons = 0


func get_turret_def(id: String) -> Dictionary:
	return TURRET_DEFS.get(id, {}).duplicate()


func get_rarity_next(rarity: String) -> String:
	match rarity:
		"common": return "rare"
		"rare":   return "epic"
		"epic":   return "legendary"
	return "legendary"


# Returns merges where 3+ of the same non-legendary turret exist across bench + board.
# tower_map: Dictionary[Vector2i → Tower node]
func get_available_simple_merges(tower_map: Dictionary) -> Array:
	var counts    : Dictionary = {}
	var b_indices : Dictionary = {}
	var p_tiles   : Dictionary = {}

	for i in range(bench.size()):
		var t  : Dictionary = bench[i]
		var id := t.get("id", "") as String
		if id == "" or t.get("rarity", "") == "legendary":
			continue
		if not counts.has(id):
			counts[id]    = 0
			b_indices[id] = []
			p_tiles[id]   = []
		counts[id]    += 1
		b_indices[id].append(i)

	for tile in tower_map:
		var tower = tower_map[tile]
		if not is_instance_valid(tower):
			continue
		var td     := tower.tower_data as Dictionary
		var id     := td.get("id", "") as String
		var rarity := td.get("rarity", "") as String
		if id == "" or id == "knight" or rarity == "legendary":
			continue
		if not counts.has(id):
			counts[id]    = 0
			b_indices[id] = []
			p_tiles[id]   = []
		counts[id]    += 1
		p_tiles[id].append(tile)

	var result : Array = []
	for id in counts:
		if counts[id] >= 3:
			result.append({
				"id":            id,
				"count":         counts[id],
				"bench_indices": b_indices[id],
				"placed_tiles":  p_tiles[id],
			})
	return result


# Returns special recipe fusions available given current bench + board.
func get_available_recipe_fusions(tower_map: Dictionary) -> Array:
	var result : Array = []
	for recipe in FUSION_RECIPES:
		var mats : Array = recipe["materials"]
		var mat_bench : Array = []
		var mat_tiles : Array = []

		# Clone collections so we can "consume" candidates while checking
		var avail_bench : Array = []
		for i in range(bench.size()):
			avail_bench.append({"idx": i, "id": bench[i].get("id", "")})
		var avail_tiles : Array = []
		for tile in tower_map:
			var tw = tower_map[tile]
			if is_instance_valid(tw):
				avail_tiles.append({"tile": tile, "id": tw.tower_data.get("id", "")})

		var ok := true
		for mat_id in mats:
			var found := false
			for j in range(avail_bench.size()):
				if avail_bench[j]["id"] == mat_id:
					mat_bench.append(avail_bench[j]["idx"])
					avail_bench.remove_at(j)
					found = true
					break
			if found:
				continue
			for j in range(avail_tiles.size()):
				if avail_tiles[j]["id"] == mat_id:
					mat_tiles.append(avail_tiles[j]["tile"])
					avail_tiles.remove_at(j)
					found = true
					break
			if not found:
				ok = false
				break

		if ok:
			result.append({
				"recipe":        recipe,
				"bench_indices": mat_bench,
				"placed_tiles":  mat_tiles,
			})
	return result
