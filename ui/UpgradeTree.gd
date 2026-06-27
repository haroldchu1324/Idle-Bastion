# ui/UpgradeTree.gd
extends Control

# ── Debug toggle ───────────────────────────────────────────────────────────────
const DEBUG := false

# ── Visual constants ───────────────────────────────────────────────────────────
const C_LOCKED     := Color(0.24, 0.23, 0.27)
const C_LOCKED_BDR := Color(0.333, 0.306, 0.255)
const C_AVAIL_BDR  := Color(0.847, 0.702, 0.365)
const C_READY_BDR  := Color(0.40, 0.95, 0.45)    # light green — prereqs met + can afford
const C_DONE_BDR   := Color(0.949, 0.851, 0.545)
const C_LINE_OFF   := Color(0.235, 0.216, 0.176, 0.55)
const C_LINE_ON    := Color(0.847, 0.702, 0.365)
const C_GEM        := Color(0.298, 0.608, 0.910)
const TIER_COSTS   : Array = [15, 25, 40]
const LEFT_W       := 240.0

# ── State ──────────────────────────────────────────────────────────────────────
var _font_bold  : Font
var _font_reg   : Font
var _active_tab := "towers"

var _towers_nodes : Array = []
var _heroes_nodes : Array = []
var _towers_links : Array = []
var _heroes_links : Array = []

var _tab_towers : Button
var _tab_heroes : Button
var _scroll     : ScrollContainer
var _canvas     : Control
var _gem_lbl    : Label
var _popup       : Control
var _hover_popup : Control = null
var _active_id   : String = ""

var _drag_active    := false
var _drag_confirmed := false
var _drag_origin    := Vector2.ZERO
var _scroll_origin  := Vector2.ZERO
var _skip_next_center : bool = false

var _tree_x_ofs       : float = 0.0
var _content_center_x : float = 0.0


# ── Entry ──────────────────────────────────────────────────────────────────────
func setup(bold: Font, reg: Font) -> void:
	_font_bold = bold
	_font_reg  = reg
	if is_instance_valid(_scroll):
		# Already built on a previous visit — just refresh the gem count
		_update_gem_display()
		return
	_define_nodes()
	_build_ui()
	_switch_tab("towers")


# ── Drag-to-pan ────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not is_instance_valid(_scroll):
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		# Only intercept left button — leave wheel events alone so scroll still works
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed and _scroll.get_global_rect().has_point(mb.global_position):
			_drag_active    = true
			_drag_confirmed = false
			_drag_origin    = mb.global_position
			_scroll_origin  = Vector2(_scroll.scroll_horizontal, _scroll.scroll_vertical)
		else:
			_drag_active    = false
			_drag_confirmed = false
	elif event is InputEventMouseMotion and _drag_active:
		var mm    := event as InputEventMouseMotion
		var delta := mm.global_position - _drag_origin
		if not _drag_confirmed and delta.length() > 6.0:
			_drag_confirmed = true
		if _drag_confirmed:
			_scroll.scroll_horizontal = int(_scroll_origin.x - delta.x)
			_scroll.scroll_vertical   = int(_scroll_origin.y - delta.y)


# ── Node data ──────────────────────────────────────────────────────────────────
func _define_nodes() -> void:
	# ─── TOWERS ───────────────────────────────────────────────────────────────
	_towers_nodes.clear(); _towers_links.clear()

	var NW  := 60.0
	var BW  := 60.0
	var NH  := 60.0
	var SPH := 60.0

	# Type-based colors — the visual language of the tree
	var DMG_C := Color(0.85, 0.28, 0.28)   # red   — damage
	var SPD_C := Color(0.28, 0.75, 0.38)   # green — attack speed
	var RNG_C := Color(0.12, 0.40, 1.00)   # blue  — range
	var SPC_C := Color(0.90, 0.78, 0.22)   # gold  — tower specials
	var NC    := Color(0.80, 0.80, 0.86)   # white — root / all-towers buffs

	# ── SHARED ROOT ──────────────────────────────────────────────────────────
	_add_nd(_towers_nodes, "tower_mastery", "Tower\nMastery", 1, [5], [],
		Vector2(475, 20), Vector2(BW, NH), NC,
		"Unlocks both the Ranged and Melee upgrade paths.")

	# ── RANGED BRANCH — trunk zigzags down, then forks west+east, merges ────────
	_add_nd(_towers_nodes, "ranged_dmg_1", "Common Ranged\n+1% Damage", 1, [5], ["tower_mastery"],
		Vector2(165, 115), Vector2(NW, NH), DMG_C,
		"All common ranged towers deal +1% damage.")
	_towers_links.append({"from":"tower_mastery","to":"ranged_dmg_1"})
	_add_nd(_towers_nodes, "ranged_rng_1", "Common Ranged\n+5px Range", 1, [5], ["ranged_dmg_1"],
		Vector2(98, 210), Vector2(NW, NH), RNG_C,
		"All common ranged towers gain +5 attack range.")
	_towers_links.append({"from":"ranged_dmg_1","to":"ranged_rng_1"})
	_add_nd(_towers_nodes, "ranged_spd_1", "Common Ranged\n+1% Atk Spd", 1, [5], ["ranged_rng_1"],
		Vector2(178, 305), Vector2(NW, NH), SPD_C,
		"All common ranged towers gain +1% attack speed.")
	_towers_links.append({"from":"ranged_rng_1","to":"ranged_spd_1"})
	_add_nd(_towers_nodes, "archer_special", "Archer Special", 1, [40], ["ranged_spd_1"],
		Vector2(105, 400), Vector2(NW, SPH), SPC_C,
		"Archer Tower: Relentless Focus\nRaises the stack cap from 2 to 3 (max 2.5× damage). Consecutive hits still add +50% each. Every hit beyond the cap adds cumulative +1 flat damage with no cap.")
	_towers_links.append({"from":"ranged_spd_1","to":"archer_special"})

	# Ranged west fork
	_add_nd(_towers_nodes, "ranged_dmg_2", "Common Ranged\n+1% Damage", 1, [7], ["archer_special"],
		Vector2(5, 510), Vector2(NW, NH), DMG_C,
		"All common ranged towers deal +1% damage.")
	_towers_links.append({"from":"archer_special","to":"ranged_dmg_2"})
	_add_nd(_towers_nodes, "ranged_spd_2", "Common Ranged\n+1% Atk Spd", 1, [7], ["ranged_dmg_2"],
		Vector2(10, 625), Vector2(NW, NH), SPD_C,
		"All common ranged towers gain +1% attack speed.")
	_towers_links.append({"from":"ranged_dmg_2","to":"ranged_spd_2"})

	# Ranged east fork
	_add_nd(_towers_nodes, "ranged_rng_2", "Common Ranged\n+5px Range", 1, [7], ["archer_special"],
		Vector2(255, 510), Vector2(NW, NH), RNG_C,
		"All common ranged towers gain +5 attack range.")
	_towers_links.append({"from":"archer_special","to":"ranged_rng_2"})
	_add_nd(_towers_nodes, "ranged_dmg_3", "Common Ranged\n+2% Damage", 1, [10], ["ranged_rng_2"],
		Vector2(248, 625), Vector2(NW, NH), DMG_C,
		"All common ranged towers deal +2% damage.")
	_towers_links.append({"from":"ranged_rng_2","to":"ranged_dmg_3"})

	# Ranged merge
	_add_nd(_towers_nodes, "crossbow_special", "Crossbow Special", 1, [40],
		["ranged_spd_2","ranged_dmg_3"],
		Vector2(105, 740), Vector2(NW, SPH), SPC_C,
		"Crossbow Tower: Triple Bolt\nFires 3 bolts instead of 2.")
	_towers_links.append({"from":"ranged_spd_2","to":"crossbow_special"})
	_towers_links.append({"from":"ranged_dmg_3","to":"crossbow_special"})

	# ── MELEE BRANCH — trunk zigzags down, then forks west+east, merges ──────
	_add_nd(_towers_nodes, "melee_dmg_1", "Common Melee\n+1% Damage", 1, [5], ["tower_mastery"],
		Vector2(757, 115), Vector2(NW, NH), DMG_C,
		"All common melee towers deal +1% damage.")
	_towers_links.append({"from":"tower_mastery","to":"melee_dmg_1"})
	_add_nd(_towers_nodes, "melee_rng_1", "Common Melee\n+3px Range", 1, [5], ["melee_dmg_1"],
		Vector2(822, 210), Vector2(NW, NH), RNG_C,
		"All common melee towers gain +3 attack range.")
	_towers_links.append({"from":"melee_dmg_1","to":"melee_rng_1"})
	_add_nd(_towers_nodes, "melee_spd_1", "Common Melee\n+1% Atk Spd", 1, [5], ["melee_rng_1"],
		Vector2(742, 305), Vector2(NW, NH), SPD_C,
		"All common melee towers gain +1% attack speed.")
	_towers_links.append({"from":"melee_rng_1","to":"melee_spd_1"})
	_add_nd(_towers_nodes, "spearman_special", "Spearman Special", 1, [40], ["melee_spd_1"],
		Vector2(815, 400), Vector2(NW, SPH), SPC_C,
		"Spearman Tower: War Cry\nEvery 3rd hit stuns enemies for 0.5s.")
	_towers_links.append({"from":"melee_spd_1","to":"spearman_special"})

	# Melee west fork
	_add_nd(_towers_nodes, "melee_dmg_2", "Common Melee\n+1% Damage", 1, [7], ["spearman_special"],
		Vector2(692, 510), Vector2(NW, NH), DMG_C,
		"All common melee towers deal +1% damage.")
	_towers_links.append({"from":"spearman_special","to":"melee_dmg_2"})
	_add_nd(_towers_nodes, "melee_rng_2", "Common Melee\n+3px Range", 1, [7], ["melee_dmg_2"],
		Vector2(698, 625), Vector2(NW, NH), RNG_C,
		"All common melee towers gain +3 attack range.")
	_towers_links.append({"from":"melee_dmg_2","to":"melee_rng_2"})

	# Melee east fork
	_add_nd(_towers_nodes, "melee_spd_2", "Common Melee\n+1% Atk Spd", 1, [7], ["spearman_special"],
		Vector2(916, 510), Vector2(NW, NH), SPD_C,
		"All common melee towers gain +1% attack speed.")
	_towers_links.append({"from":"spearman_special","to":"melee_spd_2"})
	_add_nd(_towers_nodes, "melee_dmg_3", "Common Melee\n+2% Damage", 1, [10], ["melee_spd_2"],
		Vector2(908, 625), Vector2(NW, NH), DMG_C,
		"All common melee towers deal +2% damage.")
	_towers_links.append({"from":"melee_spd_2","to":"melee_dmg_3"})

	# Melee merge
	_add_nd(_towers_nodes, "rogue_special", "Rogue Special", 1, [40],
		["melee_rng_2","melee_dmg_3"],
		Vector2(788, 740), Vector2(NW, SPH), SPC_C,
		"Rogue Tower: Hemorrhage\nBleed cap raised to 4. Enemies at max stacks are slowed by 5%.")
	_towers_links.append({"from":"melee_rng_2","to":"rogue_special"})
	_towers_links.append({"from":"melee_dmg_3","to":"rogue_special"})

	# ── MERGED CHAIN — both branches required; gentle trunk down center ───────
	var MY := 840.0
	var MS := 95.0

	_add_nd(_towers_nodes, "all_dmg_1", "+1% Damage\n(All Towers)", 1, [15],
		["crossbow_special","rogue_special"],
		Vector2(445, MY), Vector2(BW, NH), DMG_C,
		"All towers deal +1% damage. Requires completing both Ranged and Melee paths.")
	_towers_links.append({"from":"crossbow_special","to":"all_dmg_1"})
	_towers_links.append({"from":"rogue_special","to":"all_dmg_1"})
	_add_nd(_towers_nodes, "ranged_rng_3", "Common Ranged\n+5px Range", 1, [8], ["all_dmg_1"],
		Vector2(452, MY+MS), Vector2(NW, NH), RNG_C,
		"All common ranged towers gain +5 attack range.")
	_towers_links.append({"from":"all_dmg_1","to":"ranged_rng_3"})
	_add_nd(_towers_nodes, "melee_rng_3", "Common Melee\n+3px Range", 1, [8], ["ranged_rng_3"],
		Vector2(466, MY+MS*2), Vector2(NW, NH), RNG_C,
		"All common melee towers gain +3 attack range.")
	_towers_links.append({"from":"ranged_rng_3","to":"melee_rng_3"})
	_add_nd(_towers_nodes, "ranged_spd_3", "Common Ranged\n+1% Atk Spd", 1, [8], ["melee_rng_3"],
		Vector2(448, MY+MS*3), Vector2(NW, NH), SPD_C,
		"All common ranged towers gain +1% attack speed.")
	_towers_links.append({"from":"melee_rng_3","to":"ranged_spd_3"})
	_add_nd(_towers_nodes, "melee_dmg_4", "Common Melee\n+1% Damage", 1, [8], ["ranged_spd_3"],
		Vector2(468, MY+MS*4), Vector2(NW, NH), DMG_C,
		"All common melee towers deal +1% damage.")
	_towers_links.append({"from":"ranged_spd_3","to":"melee_dmg_4"})
	_add_nd(_towers_nodes, "mage_special", "Mage Special", 1, [50], ["melee_dmg_4"],
		Vector2(450, MY+MS*5), Vector2(NW, SPH), SPC_C,
		"Mage Tower: Arcane Chain\nChain hits 5 enemies (up from 3).")
	_towers_links.append({"from":"melee_dmg_4","to":"mage_special"})
	_add_nd(_towers_nodes, "ranged_dmg_4", "Common Ranged\n+1% Damage", 1, [9], ["mage_special"],
		Vector2(462, MY+MS*6), Vector2(NW, NH), DMG_C,
		"All common ranged towers deal +1% damage.")
	_towers_links.append({"from":"mage_special","to":"ranged_dmg_4"})
	_add_nd(_towers_nodes, "melee_spd_3", "Common Melee\n+1% Atk Spd", 1, [9], ["ranged_dmg_4"],
		Vector2(454, MY+MS*7), Vector2(NW, NH), SPD_C,
		"All common melee towers gain +1% attack speed.")
	_towers_links.append({"from":"ranged_dmg_4","to":"melee_spd_3"})
	_add_nd(_towers_nodes, "ranged_spd_4", "Common Ranged\n+1% Atk Spd", 1, [9], ["melee_spd_3"],
		Vector2(466, MY+MS*8), Vector2(NW, NH), SPD_C,
		"All common ranged towers gain +1% attack speed.")
	_towers_links.append({"from":"melee_spd_3","to":"ranged_spd_4"})
	_add_nd(_towers_nodes, "catapult_special", "Catapult Special", 1, [55], ["ranged_spd_4"],
		Vector2(456, MY+MS*9), Vector2(NW, SPH), SPC_C,
		"Catapult Tower: Barrage\nFires 2 shots per attack.")
	_towers_links.append({"from":"ranged_spd_4","to":"catapult_special"})
	_add_nd(_towers_nodes, "all_spd_1", "+1% Atk Spd\n(All Towers)", 1, [20], ["catapult_special"],
		Vector2(445, MY+MS*10), Vector2(BW, NH), SPD_C,
		"All towers gain +1% attack speed.")
	_towers_links.append({"from":"catapult_special","to":"all_spd_1"})

	# ─── HEROES ───────────────────────────────────────────────────────────────
	_heroes_nodes.clear(); _heroes_links.clear()

	_add_nd(_heroes_nodes, "hero_mastery", "Hero\nMastery", 1, [1], [],
		Vector2(490, 20), Vector2(60, 60), Color(0.90, 0.78, 0.22),
		"Unlocks hero upgrade branches.")

	# 4 heroes: column pitch 260px, centers at 130, 390, 650, 910
	var hw := [
		["knight",        "Knight",   Color(0.72, 0.76, 0.90)],
		["ranger",        "Ranger",   Color(0.32, 0.68, 0.30)],
		["guardian",      "Guardian", Color(0.58, 0.52, 0.46)],
		["arcane_scholar","Scholar",  Color(0.65, 0.25, 0.95)],
	]
	for i in range(4):
		var hid := hw[i][0] as String; var hn := hw[i][1] as String
		var hcl := hw[i][2] as Color
		_hero_branch(130.0 + i * 260.0, hid, hn, hcl)


func _hero_branch(cx: float, hid: String, hname: String, col: Color) -> void:
	_add_nd(_heroes_nodes, "hero_"+hid+"_intro", hname, 1, [10], ["hero_mastery"],
		Vector2(cx-30, 105), Vector2(60, 60), col,
		"Unlock %s hero upgrades." % hname)
	_heroes_links.append({"from": "hero_mastery", "to": "hero_"+hid+"_intro"})
	_add_nd(_heroes_nodes, "hero_"+hid+"_dmg", "Damage", 3, TIER_COSTS.duplicate(),
		["hero_"+hid+"_intro"], Vector2(cx-73, 225), Vector2(60, 60), col,
		"+15%% %s hero damage per tier." % hname)
	_heroes_links.append({"from": "hero_"+hid+"_intro", "to": "hero_"+hid+"_dmg"})
	_add_nd(_heroes_nodes, "hero_"+hid+"_spd", "Atk Speed", 3, TIER_COSTS.duplicate(),
		["hero_"+hid+"_intro"], Vector2(cx+13, 225), Vector2(60, 60), col,
		"+15%% %s hero attack speed per tier." % hname)
	_heroes_links.append({"from": "hero_"+hid+"_intro", "to": "hero_"+hid+"_spd"})


func _add_nd(nodes: Array, id: String, label: String, max_t: int, costs: Array,
			 prereqs: Array, pos: Vector2, sz: Vector2, col: Color, desc: String) -> void:
	nodes.append({"id": id, "label": label, "max_tiers": max_t, "costs": costs,
		"prereqs": prereqs, "pos": pos, "size": sz, "color": col, "desc": desc})


# ── UI construction ────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color        = Color(0.04, 0.04, 0.09)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build_left_panel()
	_build_right_panel()
	_build_gem_display()


func _build_left_panel() -> void:
	var panel := Panel.new()
	panel.position = Vector2.ZERO
	panel.size     = Vector2(LEFT_W, 720)
	var ps := StyleBoxFlat.new()
	ps.bg_color          = Color(0.07, 0.07, 0.12)
	ps.border_width_right = 2
	ps.border_color      = Color(0.22, 0.20, 0.16)
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)

	# Back button from HUD occupies y:[14,60] so start content below it
	var div := ColorRect.new()
	div.color    = Color(0.30, 0.26, 0.20, 0.55)
	div.position = Vector2(12, 68)
	div.size     = Vector2(216, 2)
	panel.add_child(div)

	_tab_towers = _mk_tab_btn("Towers", Vector2(12, 78),  panel, "towers")
	_tab_heroes = _mk_tab_btn("Heroes", Vector2(12, 134), panel, "heroes")

	if DEBUG:
		var rb := _mk_left_btn("Reset Upgrades", Vector2(12, 660), panel)
		rb.pressed.connect(_on_reset_pressed)
		var ab := _mk_left_btn("+1000 Gems", Vector2(12, 612), panel)
		ab.pressed.connect(func():
			GameData.blue_gems += 1000
			GameData.save_game()
			_update_gem_display()
		)


func _mk_tab_btn(label: String, pos: Vector2, parent: Control, tab: String) -> Button:
	var btn := Button.new()
	btn.text       = label
	btn.position   = pos
	btn.size       = Vector2(216, 46)
	btn.focus_mode = FOCUS_NONE
	btn.add_theme_font_override("font", _font_bold)
	btn.add_theme_font_size_override("font_size", 16)
	parent.add_child(btn)
	btn.pressed.connect(func(): _switch_tab(tab))
	return btn


func _mk_left_btn(label: String, pos: Vector2, parent: Control) -> Button:
	var btn := Button.new()
	btn.text       = label
	btn.position   = pos
	btn.size       = Vector2(216, 36)
	btn.focus_mode = FOCUS_NONE
	btn.add_theme_font_override("font", _font_bold)
	btn.add_theme_font_size_override("font_size", 13)
	parent.add_child(btn)
	return btn


func _build_right_panel() -> void:
	_scroll = ScrollContainer.new()
	_scroll.position             = Vector2(LEFT_W, 0)
	_scroll.size                 = Vector2(1280.0 - LEFT_W, 720)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.mouse_filter           = MOUSE_FILTER_STOP
	add_child(_scroll)

	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(1280.0 - LEFT_W, 720)
	_canvas.mouse_filter        = MOUSE_FILTER_PASS
	_scroll.add_child(_canvas)


func _build_gem_display() -> void:
	var hbox := HBoxContainer.new()
	hbox.position   = Vector2(1280 - 220, 8)
	hbox.size       = Vector2(210, 36)
	hbox.alignment  = BoxContainer.ALIGNMENT_END
	hbox.z_index    = 10
	hbox.mouse_filter = MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 5)
	add_child(hbox)
	hbox.add_child(_mk_blue_gem_icon(24.0))
	_gem_lbl = Label.new()
	_gem_lbl.add_theme_font_override("font", _font_bold)
	_gem_lbl.add_theme_font_size_override("font_size", 20)
	_gem_lbl.add_theme_color_override("font_color", C_GEM)
	_gem_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	hbox.add_child(_gem_lbl)
	_update_gem_display()


# ── Tab switching ──────────────────────────────────────────────────────────────
func _switch_tab(tab: String) -> void:
	_active_tab = tab
	_active_id  = ""
	_close_popup()
	_apply_tab_styles(_tab_towers, tab == "towers")
	_apply_tab_styles(_tab_heroes, tab == "heroes")
	_rebuild_tree()


func _apply_tab_styles(btn: Button, active: bool) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color    = Color(0.18, 0.36, 0.60) if active else Color(0.10, 0.10, 0.16)
	s.border_color = Color(0.40, 0.70, 1.0, 0.8) if active else Color(0.25, 0.25, 0.35, 0.5)
	s.corner_radius_top_left    = 6; s.corner_radius_top_right    = 6
	s.corner_radius_bottom_left = 6; s.corner_radius_bottom_right = 6
	s.border_width_left = 1; s.border_width_right  = 1
	s.border_width_top  = 1; s.border_width_bottom = 1
	var sh := s.duplicate() as StyleBoxFlat
	sh.bg_color = sh.bg_color.lightened(0.08)
	var sp := s.duplicate() as StyleBoxFlat
	sp.bg_color = sp.bg_color.darkened(0.06)
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sp)
	btn.add_theme_stylebox_override("focus",   s)
	btn.add_theme_color_override("font_color",
		Color(1.0, 1.0, 1.0) if active else Color(0.65, 0.65, 0.75))


# ── Tree building ──────────────────────────────────────────────────────────────
func _get_current_nodes() -> Array:
	return _towers_nodes if _active_tab == "towers" else _heroes_nodes

func _get_current_links() -> Array:
	return _towers_links if _active_tab == "towers" else _heroes_links


func _rebuild_tree() -> void:
	_hide_hover_popup()
	for ch in _canvas.get_children():
		ch.queue_free()

	var nodes := _get_current_nodes()
	var links := _get_current_links()

	# Recalculate canvas size from node extents
	const RIBBON_DIST := 220.0
	var min_x    := 9999.0
	var max_right := 0.0
	var max_y    := 720.0
	for nd in nodes:
		var p : Vector2 = nd["pos"]; var s : Vector2 = nd["size"]
		min_x     = minf(min_x,     p.x)
		max_right = maxf(max_right, p.x + s.x)
		max_y     = maxf(max_y,     p.y + s.y + 30.0)

	# Shift the whole tree right so the left ribbon fits inside the canvas (x >= 0)
	var left_ribbon_raw := min_x - RIBBON_DIST
	_tree_x_ofs = maxf(0.0, -left_ribbon_raw + 10.0)

	var left_ribbon_x  := left_ribbon_raw + _tree_x_ofs
	var right_ribbon_x := max_right + _tree_x_ofs + RIBBON_DIST
	_canvas.custom_minimum_size = Vector2(right_ribbon_x + 20.0, max_y)

	# Remember where the content is horizontally so we can center the scroll after layout
	_content_center_x = (min_x + max_right) * 0.5 + _tree_x_ofs

	# Canvas background
	var cbg := ColorRect.new()
	cbg.color        = Color(0.04, 0.05, 0.10)
	cbg.mouse_filter = MOUSE_FILTER_IGNORE
	cbg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(cbg)

	# Ribbon columns scroll with the canvas, appear above background but behind nodes
	_canvas.add_child(_mk_ribbon_column(left_ribbon_x,  max_y))
	_canvas.add_child(_mk_ribbon_column(right_ribbon_x, max_y))

	# Subtle grid
	var grid_draw := _mk_grid_overlay()
	_canvas.add_child(grid_draw)

	_build_connections(nodes, links)

	for nd in nodes:
		_build_node_panel(nd, nodes)

	_center_scroll.call_deferred()


func _center_scroll() -> void:
	if _skip_next_center:
		_skip_next_center = false
		return
	if not is_instance_valid(_scroll):
		return
	var target_x := _content_center_x - _scroll.size.x * 0.5
	_scroll.scroll_horizontal = int(maxf(0.0, target_x))
	_scroll.scroll_vertical   = 0


func _mk_grid_overlay() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var gs := 60
		for gx in range(int(c.size.x) / gs + 2):
			for gy in range(int(c.size.y) / gs + 2):
				c.draw_circle(Vector2(gx * gs, gy * gs), 1.2, Color(1, 1, 1, 0.04))
	)
	return c


func _mk_ribbon_column(cx: float, h: float) -> Control:
	var c := Control.new()
	c.position    = Vector2(cx - 8.0, 0.0)
	c.size        = Vector2(20.0, h)
	c.mouse_filter = MOUSE_FILTER_IGNORE
	c.z_index     = 0

	var amp    := 5.0
	var period := 56.0
	var freq   := TAU / period
	var half   := int(period * 0.5)
	var lx     := 10.0   # local center within this narrow Control

	var SHADOW := Color(0.10, 0.00, 0.00, 0.80)
	var DARK   := Color(0.52, 0.04, 0.04)
	var MID    := Color(0.85, 0.10, 0.10)
	var SHINE  := Color(1.00, 0.42, 0.42, 0.55)

	c.draw.connect(func():
		var steps := int(h) + 1
		var pts_a := PackedVector2Array()
		var pts_b := PackedVector2Array()
		for i in range(steps):
			var y := float(i)
			pts_a.append(Vector2(lx + amp * sin(y * freq),       y))
			pts_b.append(Vector2(lx + amp * sin(y * freq + PI),  y))

		for i in range(steps - 1):
			c.draw_line(pts_a[i] + Vector2(1.2, 1.2), pts_a[i+1] + Vector2(1.2, 1.2), SHADOW, 4.8, true)
			c.draw_line(pts_b[i] + Vector2(1.2, 1.2), pts_b[i+1] + Vector2(1.2, 1.2), SHADOW, 4.8, true)

		for i in range(steps - 1):
			var a_top : bool = (i / half) % 2 == 0
			if a_top:
				c.draw_line(pts_b[i], pts_b[i+1], DARK, 3.6, true)
				c.draw_line(pts_a[i], pts_a[i+1], MID,  3.6, true)
			else:
				c.draw_line(pts_a[i], pts_a[i+1], DARK, 3.6, true)
				c.draw_line(pts_b[i], pts_b[i+1], MID,  3.6, true)

		for i in range(steps - 1):
			var a_top : bool = (i / half) % 2 == 0
			if a_top:
				c.draw_line(pts_a[i], pts_a[i+1], SHINE, 1.2, true)
			else:
				c.draw_line(pts_b[i], pts_b[i+1], SHINE, 1.2, true)
	)
	c.queue_redraw()
	return c


func _bezier_points(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, steps: int = 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var u := 1.0 - t
		pts.append(u*u*u*p0 + 3.0*u*u*t*p1 + 3.0*u*t*t*p2 + t*t*t*p3)
	return pts


func _draw_dashed_path(node: Node2D, pts: PackedVector2Array, clr: Color,
		width: float, dash: float, gap: float, ofs: Vector2) -> void:
	var drawing := true
	var budget  := dash
	for i in range(pts.size() - 1):
		var a : Vector2 = pts[i]   + ofs
		var b : Vector2 = pts[i+1] + ofs
		var slen : float = a.distance_to(b)
		if slen < 0.001:
			continue
		var walked := 0.0
		while walked < slen:
			var take : float = minf(budget, slen - walked)
			if drawing:
				var pa : Vector2 = a.lerp(b, walked / slen)
				var pb : Vector2 = a.lerp(b, (walked + take) / slen)
				node.draw_line(pa, pb, clr, width, true)
			walked += take
			budget -= take
			if budget < 0.001:
				drawing = !drawing
				budget = gap if not drawing else dash


func _build_connections(nodes: Array, links: Array) -> void:
	var by_id : Dictionary = {}
	var bot_c : Dictionary = {}
	var top_c : Dictionary = {}
	for nd in nodes:
		by_id[nd["id"]] = nd
		var p : Vector2 = nd["pos"] + Vector2(_tree_x_ofs, 0.0)
		var s : Vector2 = nd["size"]
		bot_c[nd["id"]] = p + Vector2(s.x * 0.5, s.y)
		top_c[nd["id"]] = p + Vector2(s.x * 0.5, 0.0)

	var connections : Array = []
	for lnk in links:
		var fid : String = lnk["from"]
		var tid : String = lnk["to"]
		if not bot_c.has(fid) or not top_c.has(tid):
			continue
		var lit : bool   = by_id.has(fid) and _maxed(by_id[fid])
		var p0  : Vector2 = bot_c[fid]
		var p3  : Vector2 = top_c[tid]
		var dy  : float   = abs(p3.y - p0.y)
		var ctrl : float  = clamp(dy * 0.48, 40.0, 120.0)
		var p1  : Vector2 = p0 + Vector2(0.0,  ctrl)
		var p2  : Vector2 = p3 + Vector2(0.0, -ctrl)
		connections.append({"pts": _bezier_points(p0, p1, p2, p3), "lit": lit})

	var draw_node := Node2D.new()
	draw_node.z_index = 1
	_canvas.add_child(draw_node)
	draw_node.draw.connect(func():
		for cd in connections:
			var pts : PackedVector2Array = cd["pts"]
			var clr : Color = C_LINE_ON if cd["lit"] else C_LINE_OFF
			_draw_dashed_path(draw_node, pts, Color(0.0, 0.0, 0.0, 0.45), 3.2, 12.0, 8.0, Vector2(1.5, 1.5))
			_draw_dashed_path(draw_node, pts, clr, 2.2, 12.0, 8.0, Vector2.ZERO)
	)
	draw_node.queue_redraw()


func _build_node_panel(nd: Dictionary, all_nodes: Array) -> void:
	var pos  : Vector2 = nd["pos"]
	var sz   : Vector2 = nd["size"]
	var col  : Color   = nd["color"]
	var id   : String  = nd["id"]
	var t    := _tiers(nd)
	var mt   : int = nd["max_tiers"]
	var done  := t >= mt
	var avail := _prereqs_met(nd, all_nodes) and not done
	var ready := avail and GameData.blue_gems >= _next_cost(nd)

	var panel := Panel.new()
	panel.position     = pos + Vector2(_tree_x_ofs, 0.0)
	panel.size         = sz
	panel.z_index      = 2
	panel.mouse_filter = MOUSE_FILTER_STOP

	var ps := StyleBoxFlat.new()
	ps.corner_radius_top_left    = 8; ps.corner_radius_top_right    = 8
	ps.corner_radius_bottom_left = 8; ps.corner_radius_bottom_right = 8

	ps.border_width_left = 2; ps.border_width_right  = 2
	ps.border_width_top  = 2; ps.border_width_bottom = 2
	if done:
		ps.bg_color    = Color(0.32, 0.31, 0.34).lerp(col, 0.22)
		ps.border_color = C_DONE_BDR
	elif avail:
		ps.bg_color    = C_LOCKED
		ps.border_color = C_READY_BDR
	else:
		ps.bg_color    = C_LOCKED
		ps.border_color = C_LOCKED_BDR

	# Hover highlight
	var ph := ps.duplicate() as StyleBoxFlat
	ph.bg_color = ph.bg_color.lightened(0.10)
	panel.add_theme_stylebox_override("panel", ps)

	_canvas.add_child(panel)

	var tc : Color
	if done: tc = C_DONE_BDR
	else:    tc = Color(0.50, 0.50, 0.55)

	# Stat nodes get a big icon; others get the text label
	var stat_icon : String = ""
	if "_special" in id:                             stat_icon = "★"
	elif "_dmg" in id or id.begins_with("all_dmg"): stat_icon = "⚔"
	elif "_spd" in id or id.begins_with("all_spd"): stat_icon = "⚡"
	elif "_rng" in id or id.begins_with("all_rng"): stat_icon = "◎"

	if stat_icon != "":
		var icon_lbl := Label.new()
		icon_lbl.text = stat_icon
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 22)
		icon_lbl.add_theme_color_override("font_color", tc)
		icon_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_lbl.mouse_filter = MOUSE_FILTER_IGNORE
		panel.add_child(icon_lbl)
		if mt > 1:
			var tier_lbl := Label.new()
			tier_lbl.text = "%d/%d" % [t, mt]
			tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tier_lbl.add_theme_font_override("font", _font_bold)
			tier_lbl.add_theme_font_size_override("font_size", 9)
			tier_lbl.add_theme_color_override("font_color", tc)
			tier_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			tier_lbl.offset_top   = -12.0
			tier_lbl.mouse_filter = MOUSE_FILTER_IGNORE
			panel.add_child(tier_lbl)
	else:
		var lbl := Label.new()
		var lbl_text := nd["label"] as String
		if mt > 1:
			lbl_text += "\n%d / %d" % [t, mt]
		lbl.text                 = lbl_text
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.autowrap_mode        = TextServer.AUTOWRAP_OFF
		lbl.add_theme_font_override("font", _font_bold)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", tc)
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.mouse_filter = MOUSE_FILTER_IGNORE
		panel.add_child(lbl)

	# Lock icon on all non-maxed nodes
	if not done:
		var lock := Label.new()
		lock.text         = "🔒"
		lock.position     = Vector2(sz.x - 20, 0)
		lock.size         = Vector2(20, 18)
		lock.add_theme_font_size_override("font_size", 9)
		lock.mouse_filter = MOUSE_FILTER_IGNORE
		panel.add_child(lock)

	# Hover — instant info popup + scale pop
	panel.mouse_entered.connect(func():
		panel.pivot_offset = sz * 0.5
		panel.scale = Vector2(1.08, 1.08)
		_show_hover_popup(nd, panel)
	)
	panel.mouse_exited.connect(func():
		panel.scale = Vector2(1.0, 1.0)
		_hide_hover_popup()
	)

	# Click — buy immediately if affordable, otherwise open info popup
	panel.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				_hide_hover_popup()
				_active_id = id
				var cur_nodes := _get_current_nodes()
				var t_now    := _tiers(nd)
				var can_buy  : bool = _prereqs_met(nd, cur_nodes) and t_now < int(nd["max_tiers"])
				var cost_now := _next_cost(nd)
				if can_buy and GameData.blue_gems >= cost_now:
					if GameData.try_buy_upgrade(nd["id"], nd["max_tiers"], cost_now):
						_update_gem_display()
						_close_popup()
						_notify_towers_upgrade()
						_skip_next_center = true
						_rebuild_tree()
						return
				_open_popup(nd, cur_nodes)
	)


func _notify_towers_upgrade() -> void:
	for tower in get_tree().get_nodes_in_group("towers"):
		if tower.has_method("recalc_upgrades"):
			tower.recalc_upgrades()


# ── State helpers ──────────────────────────────────────────────────────────────
func _tiers(nd: Dictionary) -> int:
	return GameData.get_upgrade_tiers(nd["id"])

func _maxed(nd: Dictionary) -> bool:
	return _tiers(nd) >= nd["max_tiers"]

func _prereqs_met(nd: Dictionary, all_nodes: Array) -> bool:
	for pid in nd["prereqs"]:
		for pn in all_nodes:
			if pn["id"] == pid:
				if not _maxed(pn):
					return false
				break
	return true

func _next_cost(nd: Dictionary) -> int:
	var t := _tiers(nd)
	if t >= nd["max_tiers"]: return 0
	return nd["costs"][t]


# ── Popup ──────────────────────────────────────────────────────────────────────
func _open_popup(nd: Dictionary, all_nodes: Array) -> void:
	_hide_hover_popup()
	_close_popup()

	var col   : Color = nd["color"]
	var t     := _tiers(nd)
	var mt    : int   = nd["max_tiers"]
	var done  := t >= mt
	var avail := _prereqs_met(nd, all_nodes) and not done
	var cost  := _next_cost(nd)

	var panel := Panel.new()
	panel.size         = Vector2(340, 260)
	panel.position     = Vector2(LEFT_W + (1040.0 - 340.0) * 0.5, 720 - 274)
	panel.z_index      = 20
	panel.mouse_filter = MOUSE_FILTER_STOP
	var ps := StyleBoxFlat.new()
	ps.bg_color                  = Color(0.07, 0.07, 0.13, 0.98)
	ps.corner_radius_top_left    = 10; ps.corner_radius_top_right    = 10
	ps.corner_radius_bottom_left = 10; ps.corner_radius_bottom_right = 10
	ps.border_width_left = 2; ps.border_width_right  = 2
	ps.border_width_top  = 2; ps.border_width_bottom = 2
	ps.border_color = col
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)
	_popup = panel

	# Header tint
	var bar := ColorRect.new()
	bar.color    = Color(col.r, col.g, col.b, 0.22)
	bar.position = Vector2.ZERO; bar.size = Vector2(340, 42)
	panel.add_child(bar)

	# Close button
	var xbtn := Button.new()
	xbtn.text       = "✕"
	xbtn.position   = Vector2(308, 6)
	xbtn.size       = Vector2(26, 26)
	xbtn.focus_mode = FOCUS_NONE
	xbtn.add_theme_font_size_override("font_size", 12)
	var xs := StyleBoxFlat.new()
	xs.bg_color = Color(0, 0, 0, 0)
	xbtn.add_theme_stylebox_override("normal",  xs)
	xbtn.add_theme_stylebox_override("hover",   xs)
	xbtn.add_theme_stylebox_override("pressed", xs)
	xbtn.add_theme_stylebox_override("focus",   xs)
	xbtn.add_theme_color_override("font_color", Color(0.70, 0.70, 0.75))
	xbtn.pressed.connect(_close_popup)
	panel.add_child(xbtn)

	# Title
	var tier_str : String
	if mt == 1:
		tier_str = "  (%s)" % ("Done" if done else "Not purchased")
	else:
		tier_str = "  %d / %d" % [t, mt]
	var title := Label.new()
	title.text     = (nd["label"] as String).replace("\n", " ") + tier_str
	title.position = Vector2(12, 8); title.size = Vector2(290, 26)
	title.add_theme_font_override("font", _font_bold)
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", col.lightened(0.35))
	panel.add_child(title)

	# Description
	var desc := Label.new()
	desc.text          = nd["desc"]
	desc.anchor_right  = 1.0
	desc.offset_left   = 12; desc.offset_right  = -12
	desc.offset_top    = 50; desc.offset_bottom = 168
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_override("font", _font_reg)
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	desc.mouse_filter  = MOUSE_FILTER_IGNORE
	panel.add_child(desc)

	# Cost row
	var cost_col : Color
	if done:
		cost_col = Color(0.45, 0.85, 0.45)
	elif not avail:
		cost_col = Color(0.80, 0.60, 0.60)
	elif GameData.blue_gems >= cost:
		cost_col = Color(0.40, 0.92, 0.55)
	else:
		cost_col = Color(0.92, 0.50, 0.40)

	var cost_row := HBoxContainer.new()
	cost_row.position     = Vector2(12, 172)
	cost_row.size         = Vector2(316, 36)
	cost_row.alignment    = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 6)
	cost_row.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(cost_row)

	if done or not avail:
		var cost_lbl := Label.new()
		cost_lbl.text = "Fully upgraded" if done else "Complete prerequisites first"
		cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_font_override("font", _font_bold)
		cost_lbl.add_theme_font_size_override("font_size", 15)
		cost_lbl.add_theme_color_override("font_color", cost_col)
		cost_lbl.mouse_filter = MOUSE_FILTER_IGNORE
		cost_row.add_child(cost_lbl)
	else:
		var pre := Label.new()
		pre.text = "Cost: " if GameData.blue_gems >= cost else "Need "
		pre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pre.add_theme_font_override("font", _font_bold)
		pre.add_theme_font_size_override("font_size", 15)
		pre.add_theme_color_override("font_color", cost_col)
		pre.mouse_filter = MOUSE_FILTER_IGNORE
		cost_row.add_child(pre)
		cost_row.add_child(_mk_blue_gem_icon(22.0))
		var post := Label.new()
		if GameData.blue_gems >= cost:
			post.text = " %d  (have %d)" % [cost, GameData.blue_gems]
		else:
			post.text = " %d  (have %d, need %d more)" % [cost, GameData.blue_gems, cost - GameData.blue_gems]
		post.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		post.add_theme_font_override("font", _font_bold)
		post.add_theme_font_size_override("font_size", 15)
		post.add_theme_color_override("font_color", cost_col)
		post.mouse_filter = MOUSE_FILTER_IGNORE
		cost_row.add_child(post)

	# Buy button
	var btn := Button.new()
	btn.position   = Vector2(12, 216); btn.size = Vector2(316, 36)
	btn.focus_mode = FOCUS_NONE
	btn.add_theme_font_override("font", _font_bold)
	btn.add_theme_font_size_override("font_size", 14)

	var bs := StyleBoxFlat.new()
	bs.corner_radius_top_left    = 6; bs.corner_radius_top_right    = 6
	bs.corner_radius_bottom_left = 6; bs.corner_radius_bottom_right = 6

	if done:
		btn.text = "✅  Maxed"
		btn.disabled = true
		bs.bg_color  = Color(0.18, 0.32, 0.18)
	elif not avail:
		btn.text = "🔒  Complete prerequisites first"
		btn.disabled = true
		bs.bg_color  = Color(0.20, 0.20, 0.26)
	elif GameData.blue_gems < cost:
		btn.disabled = true
		bs.bg_color  = Color(0.35, 0.14, 0.14)
		_add_gem_content_to_btn(btn, "Need ", " %d  (have %d)" % [cost, GameData.blue_gems], 16.0)
		btn.add_theme_color_override("font_color_disabled", Color(0.80, 0.60, 0.60))
	else:
		btn.disabled = false
		bs.bg_color  = Color(0.18, 0.38, 0.60)
		_add_gem_content_to_btn(btn, "⬆  Upgrade — ", " %d gems" % cost, 16.0)
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
		btn.pressed.connect(func():
			if GameData.try_buy_upgrade(nd["id"], nd["max_tiers"], cost):
				_update_gem_display()
				_notify_towers_upgrade()
				_open_popup(nd, _get_current_nodes())
				_skip_next_center = true
				_rebuild_tree()
		)

	btn.add_theme_stylebox_override("normal",   bs)
	btn.add_theme_stylebox_override("hover",    bs)
	btn.add_theme_stylebox_override("pressed",  bs)
	btn.add_theme_stylebox_override("disabled", bs)
	if not btn.disabled:
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
	else:
		btn.add_theme_color_override("font_color_disabled", Color(0.60, 0.60, 0.60))
	panel.add_child(btn)


func _close_popup() -> void:
	if is_instance_valid(_popup):
		_popup.queue_free()
		_popup = null
	_active_id = ""


func _show_hover_popup(nd: Dictionary, source: Control) -> void:
	_hide_hover_popup()
	var col : Color = nd["color"]

	# Two sizes: large for long descriptions, small for short ones
	var _desc_str : String = nd["desc"] as String
	var _large : bool = _desc_str.length() > 80 or _desc_str.count("\n") >= 2
	var _pw  : float = 360.0 if _large else 290.0
	var _ph  : float = 170.0 if _large else 134.0
	var _desc_bottom : float = 130.0 if _large else 100.0
	var _sep_y  : float = _desc_bottom + 2.0
	var _cost_y : float = _sep_y + 6.0

	var hp := Panel.new()
	hp.z_index      = 25
	hp.mouse_filter = MOUSE_FILTER_IGNORE
	hp.size         = Vector2(_pw, _ph)
	var hs := StyleBoxFlat.new()
	hs.bg_color                  = Color(0.08, 0.08, 0.14, 0.97)
	hs.corner_radius_top_left    = 6; hs.corner_radius_top_right    = 6
	hs.corner_radius_bottom_left = 6; hs.corner_radius_bottom_right = 6
	hs.border_width_left = 1; hs.border_width_right  = 1
	hs.border_width_top  = 1; hs.border_width_bottom = 1
	hs.border_color = col
	hp.add_theme_stylebox_override("panel", hs)

	var title := Label.new()
	title.text = (nd["label"] as String).replace("\n", " ")
	title.anchor_right  = 1.0
	title.offset_left   = 8;  title.offset_right = -8
	title.offset_top    = 6;  title.offset_bottom = 28
	title.add_theme_font_override("font", _font_bold)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", col.lightened(0.35))
	title.mouse_filter = MOUSE_FILTER_IGNORE
	hp.add_child(title)

	var desc := Label.new()
	desc.text          = _desc_str
	desc.anchor_right  = 1.0
	desc.offset_left   = 8;  desc.offset_right = -8
	desc.offset_top    = 30; desc.offset_bottom = _desc_bottom
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_override("font", _font_reg)
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	desc.mouse_filter  = MOUSE_FILTER_IGNORE
	hp.add_child(desc)

	# Separator line
	var sep := ColorRect.new()
	sep.anchor_right = 1.0
	sep.offset_left  = 8; sep.offset_right = -8
	sep.offset_top   = _sep_y; sep.offset_bottom = _sep_y + 1.0
	sep.color    = col.darkened(0.3)
	sep.mouse_filter = MOUSE_FILTER_IGNORE
	hp.add_child(sep)

	# Cost row
	var cost_val := _next_cost(nd)
	var cost_row := HBoxContainer.new()
	cost_row.position    = Vector2(8, _cost_y)
	cost_row.size        = Vector2(_pw - 16.0, 24)
	cost_row.alignment   = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 4)
	cost_row.mouse_filter = MOUSE_FILTER_IGNORE
	if cost_val == 0:
		var mx := Label.new()
		mx.text = "✓  Maxed"
		mx.add_theme_font_override("font", _font_bold)
		mx.add_theme_font_size_override("font_size", 15)
		mx.add_theme_color_override("font_color", col.lightened(0.3))
		mx.mouse_filter = MOUSE_FILTER_IGNORE
		cost_row.add_child(mx)
	else:
		var cl := Label.new()
		cl.text = "Cost: "
		cl.add_theme_font_override("font", _font_bold)
		cl.add_theme_font_size_override("font_size", 15)
		cl.add_theme_color_override("font_color", col.lightened(0.2))
		cl.mouse_filter = MOUSE_FILTER_IGNORE
		cost_row.add_child(cl)
		cost_row.add_child(_mk_blue_gem_icon(28.0))
		var cr := Label.new()
		cr.text = "  %d" % cost_val
		cr.add_theme_font_override("font", _font_bold)
		cr.add_theme_font_size_override("font_size", 15)
		cr.add_theme_color_override("font_color", col.lightened(0.2))
		cr.mouse_filter = MOUSE_FILTER_IGNORE
		cost_row.add_child(cr)
	hp.add_child(cost_row)

	# Position to the right of the node; clamp within the panel
	var gpos : Vector2 = source.get_global_rect().position - get_global_position()
	var px   : float   = gpos.x + source.size.x + 8.0
	var py   : float   = gpos.y
	px = clampf(px, LEFT_W + 4.0, size.x - _pw - 4.0)
	py = clampf(py, 4.0, size.y - _ph - 4.0)
	hp.position = Vector2(px, py)

	add_child(hp)
	_hover_popup = hp


func _hide_hover_popup() -> void:
	if is_instance_valid(_hover_popup):
		_hover_popup.queue_free()
	_hover_popup = null


func _update_gem_display() -> void:
	if is_instance_valid(_gem_lbl):
		_gem_lbl.text = "%d gems" % GameData.blue_gems


func _on_reset_pressed() -> void:
	var refund := 0
	for nd in _towers_nodes + _heroes_nodes:
		var t := GameData.get_upgrade_tiers(nd["id"])
		for i in range(t):
			if i < nd["costs"].size():
				refund += nd["costs"][i]
	GameData.blue_gems += refund
	GameData.upgrade_purchases = {}
	GameData.save_game()
	_update_gem_display()
	_close_popup()
	_rebuild_tree()


# ── Gem icon helpers ───────────────────────────────────────────────────────────
func _load_blue_gem_tex() -> Texture2D:
	var p := "res://assets/blue_gem.svg"
	if ResourceLoader.exists(p):
		return load(p) as Texture2D
	return null


func _mk_blue_gem_icon(sz: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(sz, sz)
	tr.size                = Vector2(sz, sz)
	tr.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode         = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tr.mouse_filter        = MOUSE_FILTER_IGNORE
	var tex := _load_blue_gem_tex()
	if tex:
		tr.texture = tex
	return tr


func _add_gem_content_to_btn(btn: Button, left_text: String, right_text: String, sz: float) -> void:
	btn.text = ""
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 4)
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.mouse_filter = MOUSE_FILTER_IGNORE
	var ll := Label.new()
	ll.text = left_text
	ll.add_theme_font_override("font", _font_bold)
	ll.add_theme_font_size_override("font_size", 14)
	ll.mouse_filter = MOUSE_FILTER_IGNORE
	hbox.add_child(ll)
	hbox.add_child(_mk_blue_gem_icon(sz))
	var rl := Label.new()
	rl.text = right_text
	rl.add_theme_font_override("font", _font_bold)
	rl.add_theme_font_size_override("font_size", 14)
	rl.mouse_filter = MOUSE_FILTER_IGNORE
	hbox.add_child(rl)
	btn.add_child(hbox)
