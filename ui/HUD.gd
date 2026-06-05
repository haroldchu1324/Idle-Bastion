extends Control

# ── Signals ───────────────────────────────────────────────────────────────────
signal wave_pressed
signal speed_toggled(factor: float)
signal start_battle_pressed
signal upgrade_purchased(idx: int, cost: int)
signal prestige_confirmed
signal roll_turret_requested
signal roll_rare_requested
signal roll_epic_requested
signal roll_upgrade_requested
signal recipe_fusion_requested(result_id: String)
signal upgrade_merge_requested
signal debug_gold_requested

# ── Palette ───────────────────────────────────────────────────────────────────
const C_BG       := Color(0.10, 0.07, 0.04, 0.94)
const C_PANEL    := Color(0.12, 0.10, 0.08, 0.97)
const C_CARD     := Color(0.18, 0.15, 0.12, 1.00)
const C_BTN      := Color(0.22, 0.52, 0.18)
const C_BTN_HOV  := Color(0.28, 0.60, 0.22)
const C_BTN_OFF  := Color(0.28, 0.28, 0.24)
const C_BASE_BTN := Color(0.18, 0.36, 0.62)
const C_TAB_ACT  := Color(0.22, 0.42, 0.72)
const C_TAB_IDLE := Color(0.14, 0.14, 0.18)
const C_WHITE    := Color(1.00, 1.00, 1.00)
const C_GOLD     := Color(1.00, 0.82, 0.22)
const C_RED      := Color(0.95, 0.30, 0.30)
const C_DIM      := Color(0.75, 0.75, 0.75)
const RADIUS     := 10

# ── Nodes ─────────────────────────────────────────────────────────────────────
var wave_btn  : Button
var speed_btn : Button
var _speed_factor : float = 1.0

var _gold_lbl       : Label
var _lives_lbl      : Label
var _gem_hud_lbl    : Label
var _stage_lbl      : Label
var _wave_lbl       : Label
var _boss_bar       : Panel
var _boss_lbl       : Label
var _boss_hp_fill   : ColorRect
var _boss_hp_lbl    : Label
var _boss_timer_lbl : Label
var _notify_lbl     : Label
var _notify_tween   : Tween = null

var _base_panel  : Control
var _active_tab  : int   = 0
var _tab_btns    : Array = []
var _tab_pages   : Array = []

# Gacha result state
var _turret_result_card  : Control = null
var _roll_turret_btn     : Button  = null
var _roll_rare_btn       : Button  = null
var _roll_epic_btn       : Button  = null
var _upgrade_result_card : Control = null
var _roll_status_lbl     : Label   = null
var _upg_roll_status_lbl : Label   = null
var _current_gold        : int     = 0

# Rarity info modal (centered overlay)
var _rarity_modal      : Control = null
var _modal_odds_lbls   : Array   = []   # [pool][rarity] — 3 pools × 4 rarities

# Tower info panel
var _info_panel         : Control
var _info_panel_style   : StyleBoxFlat
var _info_preview       : Node2D
var _info_rarity_lbl    : Label
var _info_name_lbl      : Label
var _info_desc_lbl      : Label
var _info_dmg_lbl       : Label
var _info_rng_lbl       : Label
var _info_rate_lbl      : Label
var _info_effect_lbl    : Label
var _info_upgrade_btn   : Button

# Screens
var _game_over_screen   : Control
var _run_results_screen : Control
var _upgrades_screen    : Control
var _shop_screen        : Control
var _world_map_screen   : Control
var _heroes_screen      : Control
var _towers_screen      : Control
# Heroes page refs
var _hero_sel_container : Control  = null   # "Hero Selected" inner box
var _hero_det_panel     : Panel    = null   # detail popup
var _hero_det_style     : StyleBoxFlat = null
var _hero_det_preview   : Node2D   = null
var _hero_det_name      : Label    = null
var _hero_det_rarity    : Label    = null
var _hero_det_dmg       : Label    = null
var _hero_det_rng       : Label    = null
var _hero_det_rate      : Label    = null
var _hero_det_eff       : Label    = null
var _hero_det_desc      : Label    = null
var _hero_det_ability   : Label    = null
var _hero_det_select    : Button   = null
var _hero_sel_preview   : Node2D   = null
var _hero_sel_name      : Label    = null
var _hero_sel_stats     : Label    = null
var _hero_card_refs     : Array    = []   # [{id, style, badge, rcol}]
# Towers page — detail panel refs
var _tw_detail_panel    : Control = null
var _tw_detail_style    : StyleBoxFlat = null
var _tw_preview_node    : Node2D  = null
var _tw_name_lbl        : Label   = null
var _tw_rarity_lbl      : Label   = null
var _tw_desc_lbl        : Label   = null
var _tw_dmg_lbl         : Label   = null
var _tw_rng_lbl         : Label   = null
var _tw_rate_lbl        : Label   = null
var _tw_effect_lbl      : Label   = null
var _tw_level_lbl       : Label   = null
var _tw_xp_bar_fill     : ColorRect = null
var _tw_xp_bar_lbl      : Label   = null
var _tw_lvl_rows        : Array   = []   # [{lv_lbl, buff_lbl, bg}] x10
var _victory_screen     : Control
var _upg_gold_lbl       : Label
var _upg_rows           : Array = []
var _go_stage_lbl       : Label
var _go_flavour_lbl     : Label
var _go_title_lbl       : Label

var _btn_tweens : Dictionary = {}
var _font_reg   : FontFile
var _font_bold  : FontFile

# Floating in-world upgrade button
var _upgrade_popup_btn : Button = null

# Recipe notification panel (right side of track)
var _recipe_panel        : Control = null
var _recipe_notif_cards  : Array   = []
var _recipe_scroll_offset: int     = 0
var _cached_fusions      : Array   = []
var _recipe_scroll_up    : Button  = null
var _recipe_scroll_dn    : Button  = null

# Recipe book modal
var _recipe_modal        : Control = null
var _gear_btn            : Button  = null
var _gear_menu           : Panel   = null
var _recipe_btn_badge    : Label   = null
var _recipe_row_refs     : Array   = []   # [{result_id, badge_lbl, craft_btn, mat_refs:[{panel,id}]}]

const _UPG_DATA : Array = [
	["⚔  Tower Damage", "Increase all tower damage by 15%.", 100],
	["🎯  Tower Range",  "Increase all tower range by 10%.",   80],
	["⚡  Attack Speed", "Increase fire rate by 10%.",         90],
	["🛡  Extra Life",   "Gain one extra life.",               150],
]


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_load_fonts()
	_build_ui()


func _load_fonts() -> void:
	_font_reg  = load("res://assets/fonts/Rajdhani-Regular.ttf")
	_font_bold = load("res://assets/fonts/Rajdhani-Bold.ttf")
	var emoji  : FontFile = load("res://assets/fonts/NotoColorEmoji-Regular.ttf")
	var noto   : FontFile = load("res://assets/fonts/NotoSans-Regular.ttf")
	_font_reg.set_fallbacks([noto, emoji])
	_font_bold.set_fallbacks([noto, emoji])


func setup(_main) -> void:
	pass


func refresh_gems() -> void:
	if is_instance_valid(_gem_hud_lbl):
		_gem_hud_lbl.text = "🔷 %d" % GameData.blue_gems


# ── Public refresh ────────────────────────────────────────────────────────────

func refresh(gold: int, lives: int, stage: int, wave_in_stage: int, total_waves: int,
			 wave_active: bool, boss_active: bool, boss_timer: float,
			 can_next_wave: bool = false,
			 boss_hp: float = 0.0, boss_max_hp: float = 1.0) -> void:
	_current_gold = gold
	_gold_lbl.text  = "  💰 %d" % gold
	_lives_lbl.text = "  ❤️ %d" % lives

	if stage > 10:
		_stage_lbl.text = "⚔  All Stages Complete!"
		_wave_lbl.text  = "Victory!"
		wave_btn.text   = "ok  Victory!"
		_set_btn_color(C_BTN_OFF)
		_boss_bar.visible = false
		return

	_stage_lbl.text = "Stage %d / 10" % stage
	_wave_lbl.text  = "Wave %d / %d" % [wave_in_stage, total_waves]

	if boss_active:
		_boss_bar.visible = true
		var frac : float = clampf(boss_hp / boss_max_hp, 0.0, 1.0)
		_boss_hp_fill.size.x = 430.0 * frac
		var fill_col : Color
		if frac > 0.5:
			fill_col = Color(0.72, 0.15, 0.88)
		elif frac > 0.25:
			fill_col = Color(0.95, 0.52, 0.10)
		else:
			fill_col = Color(0.95, 0.15, 0.15)
		_boss_hp_fill.color = fill_col
		_boss_hp_lbl.text   = "%d / %d" % [int(boss_hp), int(boss_max_hp)]
		_boss_timer_lbl.text = "⏱  %d s" % ceili(boss_timer)
		wave_btn.text = "⏳  Boss Active..."
		_set_btn_color(C_BTN_OFF)
	elif wave_active:
		_boss_bar.visible = false
		if can_next_wave:
			wave_btn.text = ">  Send Next Wave  [Space]"
			_set_btn_color(C_BTN)
		else:
			wave_btn.text = "⏳  Spawning..."
			_set_btn_color(C_BTN_OFF)
	elif wave_in_stage >= total_waves:
		_boss_bar.visible = false
		wave_btn.text = "⚔  Start Boss Wave!  [Space]"
		_set_btn_color(Color(0.62, 0.12, 0.12))
	else:
		_boss_bar.visible = false
		wave_btn.text = ">  Start Wave %d  [Space]" % (wave_in_stage + 1)
		_set_btn_color(C_BTN)


func _set_btn_color(c: Color) -> void:
	wave_btn.add_theme_stylebox_override("normal",   _btn_style(c))
	wave_btn.add_theme_stylebox_override("hover",    _btn_style(c.lightened(0.08) if c != C_BTN_OFF else c))
	wave_btn.add_theme_stylebox_override("pressed",  _btn_style(c))
	wave_btn.add_theme_stylebox_override("focus",    _btn_style(c))
	wave_btn.add_theme_stylebox_override("disabled", _btn_style(c))


func on_wave_pressed() -> void:
	_tween_scale(wave_btn, Vector2(0.92, 0.92), 0.07)
	_show_notification("Wave Started!")


func show_boss_notification() -> void:
	_show_notification("⚔  BOSS!")


# ── Gacha result display ──────────────────────────────────────────────────────

func show_turret_result(_data: Dictionary) -> void:
	pass


func show_upgrade_result(upg_idx: int, new_level: int) -> void:
	if _upgrade_result_card == null or _upg_roll_status_lbl == null:
		return
	for child in _upgrade_result_card.get_children():
		child.queue_free()

	_upg_roll_status_lbl.text = ""
	var def : Array = _UPG_DATA[upg_idx]

	var cw2 := 248
	var name_lbl := _label(def[0], _font_bold, 22, C_GOLD)
	name_lbl.position             = Vector2(0, 16)
	name_lbl.size                 = Vector2(cw2, 36)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upgrade_result_card.add_child(name_lbl)

	var desc_lbl := _label(def[1], _font_reg, 14, C_DIM)
	desc_lbl.position             = Vector2(10, 58)
	desc_lbl.size                 = Vector2(cw2 - 20, 26)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upgrade_result_card.add_child(desc_lbl)

	var lvl_lbl := _label("Level %d / %d" % [new_level, GameData.MAX_LEVEL], _font_bold, 18, C_WHITE)
	lvl_lbl.position             = Vector2(0, 92)
	lvl_lbl.size                 = Vector2(cw2, 28)
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upgrade_result_card.add_child(lvl_lbl)

	var bonus_pct : float = new_level * _upg_bonus_pct(upg_idx)
	var bonus_lbl := _label("+%.0f%% %s" % [bonus_pct, _upg_bonus_name(upg_idx)], _font_bold, 16, C_BTN.lightened(0.15))
	bonus_lbl.position             = Vector2(0, 126)
	bonus_lbl.size                 = Vector2(cw2, 26)
	bonus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upgrade_result_card.add_child(bonus_lbl)

	var applied_lbl := _label("✅  Applied!", _font_bold, 15, C_BTN.lightened(0.2))
	applied_lbl.position             = Vector2(0, 162)
	applied_lbl.size                 = Vector2(cw2, 26)
	applied_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upgrade_result_card.add_child(applied_lbl)


func _upg_bonus_pct(idx: int) -> float:
	match idx:
		0: return 15.0
		1: return 10.0
		2: return 10.0
		3: return 0.0
	return 0.0


func _upg_bonus_name(idx: int) -> String:
	match idx:
		0: return "Tower Damage"
		1: return "Tower Range"
		2: return "Attack Speed"
		3: return "(+1 Life each level)"
	return ""


func update_pull_cost(cost: int) -> void:
	if is_instance_valid(_roll_turret_btn):
		_roll_turret_btn.text = "🎲  Common Summon  (%dg)" % cost


func update_rare_cost(cost: int) -> void:
	if is_instance_valid(_roll_rare_btn):
		_roll_rare_btn.text = "🎲  Rare Summon  (%dg)" % cost


func update_epic_cost(cost: int) -> void:
	if is_instance_valid(_roll_epic_btn):
		_roll_epic_btn.text = "🎲  Epic Summon  (%dg)" % cost


func show_roll_error(msg: String) -> void:
	_show_notification(msg)


func _get_upg_level(idx: int) -> int:
	match idx:
		0: return GameData.upg_damage
		1: return GameData.upg_range
		2: return GameData.upg_fire_rate
		3: return GameData.upg_lives
	return 0


func _apply_upgrade(idx: int) -> void:
	match idx:
		0: GameData.upg_damage    += 1
		1: GameData.upg_range     += 1
		2: GameData.upg_fire_rate += 1
		3: GameData.upg_lives     += 1


func _refresh_upgrade_rows() -> void:
	_refresh_upg_row_set(_upg_rows, false)
	if is_instance_valid(_upg_gold_lbl):
		_upg_gold_lbl.text = "💰 %d  available" % GameData.run_gold


func _refresh_upg_row_set(rows: Array, _ingame: bool) -> void:
	for r in rows:
		var i    : int   = r["upg_idx"]
		var lvl  : int   = _get_upg_level(i)
		var maxed : bool = lvl >= GameData.MAX_LEVEL
		var cost : int   = GameData.cost_for(_UPG_DATA[i][2], lvl)
		r["lvl_lbl"].text  = "Lv %d / %d" % [lvl, GameData.MAX_LEVEL]
		if maxed:
			r["cost_lbl"].text    = ""
			r["buy_btn"].text     = "Maxed ✓"
			r["buy_btn"].disabled = true
		else:
			r["cost_lbl"].text    = "💰 %d" % cost
			r["buy_btn"].text     = "Buy"
			r["buy_btn"].disabled = false


# ── Build all UI ──────────────────────────────────────────────────────────────

func _build_ui() -> void:
	_build_upgrade_popup()
	_build_rarity_modal()       # build modal before right panel so info_btn can reference it
	_build_right_panel()
	_build_wave_label()
	_build_hud_bar()
	_build_gem_hud()
	_build_tower_info_panel()
	_build_notification()
	_build_game_over_screen()
	_build_run_results_screen()
	_build_upgrades_screen()
	_build_shop_screen()
	_build_world_map_screen()
	_build_heroes_screen()
	_build_towers_screen()
	_build_victory_screen()
	_build_recipe_panel()
	_build_recipe_modal()
	_build_settings_gear()


# ── Top labels ────────────────────────────────────────────────────────────────

func _build_gem_hud() -> void:
	var bg := Panel.new()
	var bg_s := StyleBoxFlat.new()
	bg_s.bg_color = Color(0.06, 0.06, 0.12, 0.88)
	bg_s.corner_radius_top_left = 8; bg_s.corner_radius_top_right = 8
	bg_s.corner_radius_bottom_left = 8; bg_s.corner_radius_bottom_right = 8
	bg_s.border_width_left = 1; bg_s.border_width_right = 1
	bg_s.border_width_top  = 1; bg_s.border_width_bottom = 1
	bg_s.border_color = Color(0.35, 0.60, 0.90, 0.50)
	bg.add_theme_stylebox_override("panel", bg_s)
	bg.position     = Vector2(8, 8)
	bg.size         = Vector2(148, 38)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	_gem_hud_lbl = _label("🔷  0", _font_bold, 20, Color(0.45, 0.75, 1.0))
	_gem_hud_lbl.position           = Vector2(0, 0)
	_gem_hud_lbl.size               = Vector2(148, 38)
	_gem_hud_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gem_hud_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gem_hud_lbl.mouse_filter       = MOUSE_FILTER_IGNORE
	bg.add_child(_gem_hud_lbl)
	_gem_hud_lbl.text = "🔷  %d" % GameData.blue_gems


func _build_wave_label() -> void:
	# Stage label — centered in the play area (0–1020)
	var stage_panel := Panel.new()
	stage_panel.position     = Vector2(390, 6)
	stage_panel.size         = Vector2(240, 46)
	stage_panel.mouse_filter = MOUSE_FILTER_IGNORE
	stage_panel.add_theme_stylebox_override("panel", _rounded(C_PANEL))
	add_child(stage_panel)

	_stage_lbl = _label("Stage 1 / 10", _font_bold, 20, C_WHITE)
	_stage_lbl.position             = Vector2(0, 0)
	_stage_lbl.size                 = Vector2(240, 46)
	_stage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	stage_panel.add_child(_stage_lbl)

	# Wave label — right side, just left of base panel (x=1020)
	var wave_panel := Panel.new()
	wave_panel.position     = Vector2(775, 6)
	wave_panel.size         = Vector2(235, 46)
	wave_panel.mouse_filter = MOUSE_FILTER_IGNORE
	wave_panel.add_theme_stylebox_override("panel", _rounded(C_PANEL))
	add_child(wave_panel)

	_wave_lbl = _label("Wave 0 / 3", _font_bold, 18, C_DIM)
	_wave_lbl.position             = Vector2(0, 0)
	_wave_lbl.size                 = Vector2(235, 46)
	_wave_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	wave_panel.add_child(_wave_lbl)

	# Boss bar — centered in play area, moderately wide
	_boss_bar = Panel.new()
	_boss_bar.position     = Vector2(200, 58)
	_boss_bar.size         = Vector2(616, 40)
	_boss_bar.mouse_filter = MOUSE_FILTER_IGNORE
	_boss_bar.add_theme_stylebox_override("panel", _rounded(Color(0.22, 0.04, 0.04, 0.96)))
	_boss_bar.visible = false
	add_child(_boss_bar)

	_boss_lbl = _label("⚔  BOSS", _font_bold, 14, Color(1.0, 0.38, 0.28))
	_boss_lbl.position           = Vector2(6, 0)
	_boss_lbl.size               = Vector2(72, 40)
	_boss_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_bar.add_child(_boss_lbl)

	var hp_bg := Panel.new()
	hp_bg.position     = Vector2(82, 9)
	hp_bg.size         = Vector2(430, 22)
	hp_bg.mouse_filter = MOUSE_FILTER_IGNORE
	hp_bg.add_theme_stylebox_override("panel", _flat(Color(0.12, 0.05, 0.05), 6))
	_boss_bar.add_child(hp_bg)

	_boss_hp_fill = ColorRect.new()
	_boss_hp_fill.position     = Vector2(82, 9)
	_boss_hp_fill.size         = Vector2(430, 22)
	_boss_hp_fill.color        = Color(0.75, 0.15, 0.85)
	_boss_hp_fill.mouse_filter = MOUSE_FILTER_IGNORE
	_boss_bar.add_child(_boss_hp_fill)

	_boss_hp_lbl = _label("", _font_bold, 14, C_WHITE)
	_boss_hp_lbl.position             = Vector2(82, 9)
	_boss_hp_lbl.size                 = Vector2(430, 22)
	_boss_hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_hp_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_boss_hp_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	_boss_bar.add_child(_boss_hp_lbl)

	_boss_timer_lbl = _label("60 s", _font_bold, 14, Color(1.0, 0.65, 0.30))
	_boss_timer_lbl.position             = Vector2(518, 0)
	_boss_timer_lbl.size                 = Vector2(92, 40)
	_boss_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_timer_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_boss_timer_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	_boss_bar.add_child(_boss_timer_lbl)


# ── Bottom HUD bar ────────────────────────────────────────────────────────────

func _build_hud_bar() -> void:
	var bar := Panel.new()
	bar.position     = Vector2(0, 650)
	bar.size         = Vector2(1280, 70)
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", _flat(C_BG, 0))
	add_child(bar)

	_gold_lbl = _label("  💰 100", _font_bold, 22, C_GOLD)
	_gold_lbl.position           = Vector2(8, 0)
	_gold_lbl.size               = Vector2(170, 70)
	_gold_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(_gold_lbl)

	_lives_lbl = _label("  ❤️ 20", _font_bold, 22, C_RED)
	_lives_lbl.position           = Vector2(182, 0)
	_lives_lbl.size               = Vector2(150, 70)
	_lives_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(_lives_lbl)

	speed_btn = Button.new()
	speed_btn.text         = "1× Speed"
	speed_btn.position     = Vector2(340, 10)
	speed_btn.size         = Vector2(150, 50)
	speed_btn.pivot_offset = Vector2(75, 25)
	speed_btn.focus_mode   = FOCUS_NONE
	speed_btn.add_theme_font_override("font",           _font_bold)
	speed_btn.add_theme_font_size_override("font_size", 16)
	speed_btn.add_theme_color_override("font_color",    C_WHITE)
	var C_SPEED := Color(0.18, 0.42, 0.58)
	speed_btn.add_theme_stylebox_override("normal",  _btn_style(C_SPEED))
	speed_btn.add_theme_stylebox_override("hover",   _btn_style(C_SPEED.lightened(0.10)))
	speed_btn.add_theme_stylebox_override("pressed", _btn_style(C_SPEED.darkened(0.10)))
	speed_btn.add_theme_stylebox_override("focus",   _btn_style(C_SPEED))
	speed_btn.pressed.connect(_on_speed_btn_pressed)
	bar.add_child(speed_btn)

	# Recipe button — center of bar
	var C_RECIPE := Color(0.18, 0.42, 0.38)
	var recipe_btn := Button.new()
	recipe_btn.text         = "📖  Recipe"
	recipe_btn.position     = Vector2(493, 10)
	recipe_btn.size         = Vector2(165, 50)
	recipe_btn.pivot_offset = Vector2(82, 25)
	recipe_btn.focus_mode   = FOCUS_NONE
	recipe_btn.add_theme_font_override("font",           _font_bold)
	recipe_btn.add_theme_font_size_override("font_size", 15)
	recipe_btn.add_theme_color_override("font_color",    C_WHITE)
	recipe_btn.add_theme_stylebox_override("normal",  _btn_style(C_RECIPE))
	recipe_btn.add_theme_stylebox_override("hover",   _btn_style(C_RECIPE.lightened(0.12)))
	recipe_btn.add_theme_stylebox_override("pressed", _btn_style(C_RECIPE.darkened(0.12)))
	recipe_btn.add_theme_stylebox_override("focus",   _btn_style(C_RECIPE))
	recipe_btn.pressed.connect(func():
		_tween_scale(recipe_btn, Vector2(0.92, 0.92), 0.07)
		if is_instance_valid(_recipe_modal):
			_refresh_recipe_modal()
			_recipe_modal.visible = true
	)
	bar.add_child(recipe_btn)

	# Badge showing number of available crafts
	var badge_bg := StyleBoxFlat.new()
	badge_bg.bg_color                   = Color(0.90, 0.15, 0.15)
	badge_bg.corner_radius_top_left     = 11
	badge_bg.corner_radius_top_right    = 11
	badge_bg.corner_radius_bottom_left  = 11
	badge_bg.corner_radius_bottom_right = 11
	var badge_panel := Panel.new()
	badge_panel.position     = Vector2(493 + 138, 2)
	badge_panel.size         = Vector2(22, 22)
	badge_panel.mouse_filter = MOUSE_FILTER_IGNORE
	badge_panel.visible      = false
	badge_panel.add_theme_stylebox_override("panel", badge_bg)
	bar.add_child(badge_panel)
	_recipe_btn_badge = _label("0", _font_bold, 14, C_WHITE)
	_recipe_btn_badge.position             = Vector2(0, 0)
	_recipe_btn_badge.size                 = Vector2(22, 22)
	_recipe_btn_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_recipe_btn_badge.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_recipe_btn_badge.mouse_filter         = MOUSE_FILTER_IGNORE
	badge_panel.add_child(_recipe_btn_badge)
	# Store badge_panel ref on the label's metadata so update_recipe_notifications can show/hide it
	_recipe_btn_badge.set_meta("panel", badge_panel)

	wave_btn = Button.new()
	wave_btn.text         = ">  Start Wave 1  [Space]"
	wave_btn.position     = Vector2(738, 10)
	wave_btn.size         = Vector2(207, 50)
	wave_btn.pivot_offset = Vector2(103, 25)
	wave_btn.focus_mode   = FOCUS_NONE
	wave_btn.add_theme_font_override("font",           _font_bold)
	wave_btn.add_theme_font_size_override("font_size", 17)
	wave_btn.add_theme_color_override("font_color",    C_WHITE)
	wave_btn.add_theme_stylebox_override("normal",   _btn_style(C_BTN))
	wave_btn.add_theme_stylebox_override("hover",    _btn_style(C_BTN_HOV))
	wave_btn.add_theme_stylebox_override("pressed",  _btn_style(C_BTN))
	wave_btn.add_theme_stylebox_override("focus",    _btn_style(C_BTN))
	wave_btn.add_theme_stylebox_override("disabled", _btn_style(C_BTN))
	wave_btn.pressed.connect(func():
		on_wave_pressed()
		wave_pressed.emit()
	)
	bar.add_child(wave_btn)


func _build_upgrade_popup() -> void:
	var C_UPG := Color(0.42, 0.24, 0.06)
	_upgrade_popup_btn = Button.new()
	_upgrade_popup_btn.text       = "^  Upgrade"
	_upgrade_popup_btn.size       = Vector2(88, 26)
	_upgrade_popup_btn.focus_mode = FOCUS_NONE
	_upgrade_popup_btn.visible    = false
	_upgrade_popup_btn.z_index    = 20
	_upgrade_popup_btn.add_theme_font_override("font",           _font_bold)
	_upgrade_popup_btn.add_theme_font_size_override("font_size", 14)
	_upgrade_popup_btn.add_theme_color_override("font_color",    C_WHITE)
	_upgrade_popup_btn.add_theme_stylebox_override("normal",  _btn_style(C_UPG))
	_upgrade_popup_btn.add_theme_stylebox_override("hover",   _btn_style(C_UPG.lightened(0.18)))
	_upgrade_popup_btn.add_theme_stylebox_override("pressed", _btn_style(C_UPG.darkened(0.15)))
	_upgrade_popup_btn.add_theme_stylebox_override("focus",   _btn_style(C_UPG))
	_upgrade_popup_btn.pressed.connect(func(): upgrade_merge_requested.emit())
	add_child(_upgrade_popup_btn)


func show_upgrade_popup(world_pos: Vector2) -> void:
	if not is_instance_valid(_upgrade_popup_btn):
		return
	_upgrade_popup_btn.position = world_pos + Vector2(-44, -52)
	_upgrade_popup_btn.visible  = true


func hide_upgrade_popup() -> void:
	if is_instance_valid(_upgrade_popup_btn):
		_upgrade_popup_btn.visible = false


func is_upgrade_popup_clicked(click_pos: Vector2) -> bool:
	if not is_instance_valid(_upgrade_popup_btn) or not _upgrade_popup_btn.visible:
		return false
	return Rect2(_upgrade_popup_btn.position, _upgrade_popup_btn.size).has_point(click_pos)


func _build_rarity_modal() -> void:
	var overlay := ColorRect.new()
	overlay.color        = Color(0, 0, 0, 0.75)
	overlay.position     = Vector2.ZERO
	overlay.size         = Vector2(1280, 720)
	overlay.mouse_filter = MOUSE_FILTER_STOP
	overlay.visible      = false
	add_child(overlay)
	_rarity_modal = overlay

	const CW : int = 500
	const CH : int = 300
	var card := Panel.new()
	card.position = Vector2((1280 - CW) / 2, (720 - CH) / 2)
	card.size     = Vector2(CW, CH)
	card.add_theme_stylebox_override("panel", _rounded(C_PANEL))
	overlay.add_child(card)

	# Title bar
	var title_bar := Panel.new()
	title_bar.position = Vector2.ZERO
	title_bar.size     = Vector2(CW, 52)
	title_bar.add_theme_stylebox_override("panel", _flat(Color(0.14, 0.22, 0.44), 10))
	card.add_child(title_bar)

	var title_lbl := _label("🎲  Turret Rarity Odds", _font_bold, 20, C_WHITE)
	title_lbl.position             = Vector2(0, 0)
	title_lbl.size                 = Vector2(CW, 52)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title_bar.add_child(title_lbl)

	var xbtn := Button.new()
	xbtn.text       = "X"
	xbtn.position   = Vector2(CW - 44, 8)
	xbtn.size       = Vector2(36, 36)
	xbtn.focus_mode = FOCUS_NONE
	xbtn.add_theme_font_override("font",           _font_bold)
	xbtn.add_theme_font_size_override("font_size", 16)
	xbtn.add_theme_color_override("font_color",    C_WHITE)
	xbtn.add_theme_stylebox_override("normal",  _btn_style(Color(0.55,0.12,0.12)))
	xbtn.add_theme_stylebox_override("hover",   _btn_style(Color(0.75,0.18,0.18)))
	xbtn.add_theme_stylebox_override("pressed", _btn_style(Color(0.40,0.08,0.08)))
	xbtn.add_theme_stylebox_override("focus",   _btn_style(Color(0.55,0.12,0.12)))
	xbtn.pressed.connect(func(): overlay.visible = false)
	title_bar.add_child(xbtn)

	# Column positions: [rarity label, common col, rare col, epic col]
	var col_x := [14, 148, 260, 372]
	const COL_W : int = 108

	# Column headers — colored to match each summon type
	var h0 := _label("Rarity", _font_bold, 14, C_DIM)
	h0.position = Vector2(col_x[0], 62); h0.size = Vector2(150, 20)
	card.add_child(h0)

	var h1 := _label("Common Summon", _font_bold, 14, Color(0.78, 0.78, 0.78))
	h1.position = Vector2(col_x[1] - 20, 62); h1.size = Vector2(COL_W, 20)
	h1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(h1)

	var h2 := _label("Rare Summon", _font_bold, 14, Color(0.25, 0.55, 1.00))
	h2.position = Vector2(col_x[2], 62); h2.size = Vector2(COL_W, 20)
	h2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(h2)

	var h3 := _label("Epic Summon", _font_bold, 14, Color(0.80, 0.35, 1.00))
	h3.position = Vector2(col_x[3], 62); h3.size = Vector2(COL_W, 20)
	h3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(h3)

	var hdiv := ColorRect.new()
	hdiv.color = Color(1,1,1,0.1); hdiv.position = Vector2(10, 84); hdiv.size = Vector2(CW - 20, 2)
	card.add_child(hdiv)

	var rarity_defs := [
		["⚪  Common",    Color(0.80, 0.80, 0.80)],
		["🔵  Rare",      Color(0.25, 0.55, 1.00)],
		["🟣  Epic",      Color(0.72, 0.25, 0.90)],
		["🟡  Legendary", Color(1.00, 0.72, 0.10)],
	]
	var all_pool_odds := [
		SummonSystem.COMMON_POOL_ODDS,
		SummonSystem.RARE_POOL_ODDS,
		SummonSystem.EPIC_POOL_ODDS,
	]
	# _modal_odds_lbls[pool][rarity] — only common pool is dynamic (per-level)
	_modal_odds_lbls.clear()
	for pi in range(3):
		var pool_lbls : Array = []
		_modal_odds_lbls.append(pool_lbls)

	for ri in range(rarity_defs.size()):
		var ry := 92 + ri * 42
		var row_bg := ColorRect.new()
		row_bg.color    = Color(1, 1, 1, 0.04 if ri % 2 == 0 else 0.0)
		row_bg.position = Vector2(8, ry - 4)
		row_bg.size     = Vector2(CW - 16, 38)
		card.add_child(row_bg)

		var rlbl := _label(rarity_defs[ri][0], _font_bold, 14, rarity_defs[ri][1] as Color)
		rlbl.position = Vector2(col_x[0], ry); rlbl.size = Vector2(150, 28)
		card.add_child(rlbl)

		for pi in range(3):
			var val : int = (all_pool_odds[pi] as Array)[ri]
			var txt : String = "%d%%" % val if val > 0 else "—"
			var pct := _label(txt, _font_bold, 14, C_WHITE)
			pct.position             = Vector2(col_x[pi + 1], ry)
			pct.size                 = Vector2(COL_W, 28)
			pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card.add_child(pct)
			(_modal_odds_lbls[pi] as Array).append(pct)

	overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if not card.get_rect().has_point(card.get_parent().get_local_mouse_position()):
				overlay.visible = false
	)


func _refresh_rarity_modal() -> void:
	if _modal_odds_lbls.is_empty():
		return
	# Only the common pool odds are level-dependent; refresh all 3 for consistency
	var pools := [SummonSystem.COMMON_POOL_ODDS, SummonSystem.RARE_POOL_ODDS, SummonSystem.EPIC_POOL_ODDS]
	for pi in range(3):
		var pool_lbls := _modal_odds_lbls[pi] as Array
		for ri in range(pool_lbls.size()):
			var lbl := pool_lbls[ri] as Label
			if is_instance_valid(lbl):
				var val : int = (pools[pi] as Array)[ri]
				lbl.text = "%d%%" % val if val > 0 else "—"


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if is_instance_valid(_rarity_modal) and _rarity_modal.visible:
			_rarity_modal.visible = false
			get_viewport().set_input_as_handled()


func _on_speed_btn_pressed() -> void:
	_tween_scale(speed_btn, Vector2(0.92, 0.92), 0.07)
	if _speed_factor == 1.0:
		_speed_factor = 2.0
	elif _speed_factor == 2.0:
		_speed_factor = 4.0
	else:
		_speed_factor = 1.0
	match _speed_factor:
		1.0:
			speed_btn.text = "1× Speed"
			var c1 := Color(0.18, 0.42, 0.58)
			speed_btn.add_theme_stylebox_override("normal", _btn_style(c1))
			speed_btn.add_theme_stylebox_override("hover",  _btn_style(c1.lightened(0.10)))
			speed_btn.add_theme_stylebox_override("focus",  _btn_style(c1))
		2.0:
			speed_btn.text = "2× Speed"
			var c2 := Color(0.58, 0.38, 0.10)
			speed_btn.add_theme_stylebox_override("normal", _btn_style(c2))
			speed_btn.add_theme_stylebox_override("hover",  _btn_style(c2.lightened(0.10)))
			speed_btn.add_theme_stylebox_override("focus",  _btn_style(c2))
		4.0:
			speed_btn.text = "4× Speed"
			var c4 := Color(0.58, 0.14, 0.14)
			speed_btn.add_theme_stylebox_override("normal", _btn_style(c4))
			speed_btn.add_theme_stylebox_override("hover",  _btn_style(c4.lightened(0.10)))
			speed_btn.add_theme_stylebox_override("focus",  _btn_style(c4))
	Engine.time_scale = _speed_factor
	speed_toggled.emit(_speed_factor)


# ══════════════════════════════════════════════════════════════════════════════
# RIGHT PANEL  (permanent — replaces the old modal base panel)
# ══════════════════════════════════════════════════════════════════════════════

func _build_right_panel() -> void:
	# Outer container
	var panel := Panel.new()
	panel.position     = Vector2(1020, 0)
	panel.size         = Vector2(260, 650)
	panel.mouse_filter = MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _flat(C_PANEL, 0))
	add_child(panel)
	_base_panel = panel   # keep reference for victory-screen compat

	# Title bar
	var title := _label("🏰  Base", _font_bold, 16, C_GOLD)
	title.position             = Vector2(0, 8)
	title.size                 = Vector2(260, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	# Tab buttons
	var tab_names := ["🗡  Turrets", "⚔  Upgrades"]
	var tab_bar   := Control.new()
	tab_bar.position = Vector2(6, 44)
	tab_bar.size     = Vector2(248, 38)
	panel.add_child(tab_bar)

	_tab_btns.clear()
	for i in range(tab_names.size()):
		var tb := Button.new()
		tb.text       = tab_names[i]
		tb.position   = Vector2(i * 124, 0)
		tb.size       = Vector2(122, 38)
		tb.focus_mode = FOCUS_NONE
		tb.add_theme_font_override("font",           _font_bold)
		tb.add_theme_font_size_override("font_size", 14)
		tb.add_theme_color_override("font_color",    C_WHITE)
		tb.add_theme_stylebox_override("normal",  _btn_style(C_TAB_ACT if i == 0 else C_TAB_IDLE))
		tb.add_theme_stylebox_override("hover",   _btn_style(C_TAB_ACT.lightened(0.10)))
		tb.add_theme_stylebox_override("pressed", _btn_style(C_TAB_ACT))
		tb.add_theme_stylebox_override("focus",   _btn_style(C_TAB_ACT if i == 0 else C_TAB_IDLE))
		var idx := i
		tb.pressed.connect(func(): _switch_tab(idx))
		tab_bar.add_child(tb)
		_tab_btns.append(tb)

	# Tab pages
	_tab_pages.clear()
	for i in range(tab_names.size()):
		var page := Control.new()
		page.position = Vector2(6, 88)
		page.size     = Vector2(248, 554)
		page.visible  = (i == 0)
		panel.add_child(page)
		_tab_pages.append(page)
		_fill_tab(page, i)


func _switch_tab(idx: int) -> void:
	_active_tab = idx
	for i in range(_tab_btns.size()):
		var c := C_TAB_ACT if i == idx else C_TAB_IDLE
		_tab_btns[i].add_theme_stylebox_override("normal", _btn_style(c))
		_tab_btns[i].add_theme_stylebox_override("focus",  _btn_style(c))
		_tab_pages[i].visible = (i == idx)


func _fill_tab(page: Control, idx: int) -> void:
	match idx:
		0: _fill_turrets_tab(page)
		1: _fill_upgrades_tab(page)


# ── Turrets Tab (Gacha) ───────────────────────────────────────────────────────

func _fill_turrets_tab(page: Control) -> void:
	var w := 248   # page inner width

	var gacha_title := _label("🎲  Turret Gacha", _font_bold, 18, C_GOLD)
	gacha_title.position             = Vector2(0, 8)
	gacha_title.size                 = Vector2(w - 32, 30)
	gacha_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(gacha_title)

	# Small circular ℹ — Panel+Label to avoid Button padding breaking the circle
	var circle_s := StyleBoxFlat.new()
	circle_s.bg_color = Color(0.08, 0.18, 0.32, 0.90)
	circle_s.corner_radius_top_left     = 11
	circle_s.corner_radius_top_right    = 11
	circle_s.corner_radius_bottom_left  = 11
	circle_s.corner_radius_bottom_right = 11
	circle_s.border_width_left   = 1; circle_s.border_width_right  = 1
	circle_s.border_width_top    = 1; circle_s.border_width_bottom = 1
	circle_s.border_color        = Color(0.20, 0.70, 1.00, 0.80)
	circle_s.content_margin_left = 0; circle_s.content_margin_right  = 0
	circle_s.content_margin_top  = 0; circle_s.content_margin_bottom = 0
	var circle_h := circle_s.duplicate() as StyleBoxFlat
	circle_h.bg_color = Color(0.14, 0.32, 0.55, 0.95)
	var info_btn := Panel.new()
	info_btn.position            = Vector2(w - 28, 9)
	info_btn.custom_minimum_size = Vector2(22, 22)
	info_btn.size                = Vector2(22, 22)
	info_btn.mouse_filter        = MOUSE_FILTER_STOP
	info_btn.add_theme_stylebox_override("panel", circle_s)
	var info_lbl := _label("i", _font_bold, 14, Color(0.20, 0.85, 1.00))
	info_lbl.position             = Vector2(0, 0)
	info_lbl.size                 = Vector2(22, 22)
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	info_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	info_btn.add_child(info_lbl)
	info_btn.mouse_entered.connect(func(): info_btn.add_theme_stylebox_override("panel", circle_h))
	info_btn.mouse_exited.connect(func():  info_btn.add_theme_stylebox_override("panel", circle_s))
	page.add_child(info_btn)

	# ── Common Summon ──────────────────────────────────────────────────────────
	const C_COMMON_CLR := Color(0.78, 0.78, 0.78)   # gray
	var common_hdr := _label("⚪  Common Summon", _font_bold, 14, C_COMMON_CLR)
	common_hdr.position             = Vector2(0, 44)
	common_hdr.size                 = Vector2(w, 20)
	common_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(common_hdr)

	var common_odds_lbl := _label("75% Common · 22% Rare · 3% Epic", _font_reg, 11, C_DIM)
	common_odds_lbl.position             = Vector2(0, 66)
	common_odds_lbl.size                 = Vector2(w, 16)
	common_odds_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(common_odds_lbl)

	var C_COMMON_BTN := Color(0.30, 0.30, 0.26)
	var common_btn := Button.new()
	common_btn.text         = "🎲  Common Summon  (40g)"
	common_btn.position     = Vector2(8, 84)
	common_btn.size         = Vector2(w - 16, 46)
	common_btn.pivot_offset = Vector2((w - 16) * 0.5, 23)
	common_btn.focus_mode   = FOCUS_NONE
	common_btn.add_theme_font_override("font",           _font_bold)
	common_btn.add_theme_font_size_override("font_size", 14)
	common_btn.add_theme_color_override("font_color",    C_WHITE)
	common_btn.add_theme_stylebox_override("normal",  _btn_style(C_COMMON_BTN))
	common_btn.add_theme_stylebox_override("hover",   _btn_style(C_COMMON_BTN.lightened(0.12)))
	common_btn.add_theme_stylebox_override("pressed", _btn_style(C_COMMON_BTN.darkened(0.12)))
	common_btn.add_theme_stylebox_override("focus",   _btn_style(C_COMMON_BTN))
	common_btn.pressed.connect(func():
		_tween_scale(common_btn, Vector2(0.92, 0.92), 0.08)
		roll_turret_requested.emit()
	)
	page.add_child(common_btn)
	_roll_turret_btn = common_btn

	# ── Rare Summon ────────────────────────────────────────────────────────────
	const C_RARE_CLR := Color(0.25, 0.55, 1.00)   # blue
	var rare_hdr := _label("🔵  Rare Summon", _font_bold, 14, C_RARE_CLR)
	rare_hdr.position             = Vector2(0, 146)
	rare_hdr.size                 = Vector2(w, 20)
	rare_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(rare_hdr)

	var rare_odds_lbl := _label("75% Rare · 22% Epic · 3% Legendary", _font_reg, 11, C_DIM)
	rare_odds_lbl.position             = Vector2(0, 168)
	rare_odds_lbl.size                 = Vector2(w, 16)
	rare_odds_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(rare_odds_lbl)

	var C_RARE_BTN := Color(0.12, 0.28, 0.58)
	var rare_btn := Button.new()
	rare_btn.text         = "🎲  Rare Summon  (100g)"
	rare_btn.position     = Vector2(8, 186)
	rare_btn.size         = Vector2(w - 16, 46)
	rare_btn.pivot_offset = Vector2((w - 16) * 0.5, 23)
	rare_btn.focus_mode   = FOCUS_NONE
	rare_btn.add_theme_font_override("font",           _font_bold)
	rare_btn.add_theme_font_size_override("font_size", 14)
	rare_btn.add_theme_color_override("font_color",    C_WHITE)
	rare_btn.add_theme_stylebox_override("normal",  _btn_style(C_RARE_BTN))
	rare_btn.add_theme_stylebox_override("hover",   _btn_style(C_RARE_BTN.lightened(0.12)))
	rare_btn.add_theme_stylebox_override("pressed", _btn_style(C_RARE_BTN.darkened(0.12)))
	rare_btn.add_theme_stylebox_override("focus",   _btn_style(C_RARE_BTN))
	rare_btn.pressed.connect(func():
		_tween_scale(rare_btn, Vector2(0.92, 0.92), 0.08)
		roll_rare_requested.emit()
	)
	page.add_child(rare_btn)
	_roll_rare_btn = rare_btn

	# ── Epic Summon ────────────────────────────────────────────────────────────
	const C_EPIC_CLR := Color(0.80, 0.35, 1.00)   # purple
	var epic_hdr := _label("🟣  Epic Summon", _font_bold, 14, C_EPIC_CLR)
	epic_hdr.position             = Vector2(0, 248)
	epic_hdr.size                 = Vector2(w, 20)
	epic_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(epic_hdr)

	var epic_odds_lbl := _label("15% Rare · 75% Epic · 10% Legendary", _font_reg, 11, C_DIM)
	epic_odds_lbl.position             = Vector2(0, 270)
	epic_odds_lbl.size                 = Vector2(w, 16)
	epic_odds_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(epic_odds_lbl)

	var C_EPIC_BTN := Color(0.35, 0.12, 0.55)
	var epic_btn := Button.new()
	epic_btn.text         = "🎲  Epic Summon  (250g)"
	epic_btn.position     = Vector2(8, 288)
	epic_btn.size         = Vector2(w - 16, 46)
	epic_btn.pivot_offset = Vector2((w - 16) * 0.5, 23)
	epic_btn.focus_mode   = FOCUS_NONE
	epic_btn.add_theme_font_override("font",           _font_bold)
	epic_btn.add_theme_font_size_override("font_size", 14)
	epic_btn.add_theme_color_override("font_color",    C_WHITE)
	epic_btn.add_theme_stylebox_override("normal",  _btn_style(C_EPIC_BTN))
	epic_btn.add_theme_stylebox_override("hover",   _btn_style(C_EPIC_BTN.lightened(0.12)))
	epic_btn.add_theme_stylebox_override("pressed", _btn_style(C_EPIC_BTN.darkened(0.12)))
	epic_btn.add_theme_stylebox_override("focus",   _btn_style(C_EPIC_BTN))
	epic_btn.pressed.connect(func():
		_tween_scale(epic_btn, Vector2(0.92, 0.92), 0.08)
		roll_epic_requested.emit()
	)
	page.add_child(epic_btn)
	_roll_epic_btn = epic_btn

	# ── Debug: +10 000 Gold ────────────────────────────────────────────────────
	var dbg_btn := Button.new()
	dbg_btn.text         = "🐛  +10 000 Gold (Debug)"
	dbg_btn.position     = Vector2(8, 348)
	dbg_btn.size         = Vector2(w - 16, 36)
	dbg_btn.pivot_offset = Vector2((w - 16) * 0.5, 18)
	dbg_btn.focus_mode   = FOCUS_NONE
	dbg_btn.add_theme_font_override("font",           _font_reg)
	dbg_btn.add_theme_font_size_override("font_size", 14)
	dbg_btn.add_theme_color_override("font_color",    Color(0.55, 0.90, 0.55))
	dbg_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.10, 0.22, 0.10)))
	dbg_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.14, 0.30, 0.14)))
	dbg_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.08, 0.16, 0.08)))
	dbg_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.10, 0.22, 0.10)))
	dbg_btn.pressed.connect(func():
		_tween_scale(dbg_btn, Vector2(0.95, 0.95), 0.06)
		debug_gold_requested.emit()
	)
	page.add_child(dbg_btn)

	# Connect ℹ to open the centered rarity modal
	info_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if is_instance_valid(_rarity_modal):
				_rarity_modal.visible = true
				_refresh_rarity_modal()
	)



# ── Upgrades Tab (Gacha) ──────────────────────────────────────────────────────

func _fill_upgrades_tab(page: Control) -> void:
	var w := 248
	var lbl := _label("Coming soon…", _font_bold, 16, C_DIM)
	lbl.position             = Vector2(0, 220)
	lbl.size                 = Vector2(w, 30)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(lbl)


# ── Tower info panel ──────────────────────────────────────────────────────────

func _build_tower_info_panel() -> void:
	const PW : int = 210   # panel width
	const PH : int = 430   # taller to fit effect description

	var info_style := _rounded(C_PANEL)
	info_style.border_width_left   = 2
	info_style.border_width_right  = 2
	info_style.border_width_top    = 2
	info_style.border_width_bottom = 2
	info_style.border_color        = Color(0.5, 0.5, 0.5, 0.4)
	_info_panel_style = info_style

	var panel := Panel.new()
	panel.position     = Vector2(6, 182)
	panel.size         = Vector2(PW, PH)
	panel.mouse_filter = MOUSE_FILTER_STOP
	panel.visible      = false
	panel.add_theme_stylebox_override("panel", info_style)
	add_child(panel)
	_info_panel = panel

	var title := _label("Selected Tower", _font_bold, 14, C_DIM)
	title.position             = Vector2(0, 6)
	title.size                 = Vector2(PW, 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(title)

	var div := ColorRect.new()
	div.color = Color(1,1,1,0.08); div.position = Vector2(8,28); div.size = Vector2(PW-16,2)
	div.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(div)

	# Preview centered in panel
	var preview_bg := Panel.new()
	preview_bg.position     = Vector2((PW - 56) / 2, 34)
	preview_bg.size         = Vector2(56, 56)
	preview_bg.mouse_filter = MOUSE_FILTER_IGNORE
	preview_bg.add_theme_stylebox_override("panel", _rounded(C_CARD))
	panel.add_child(preview_bg)

	var preview := _TurretPreview.new()
	preview.position = Vector2((PW / 2) - 28, 34)
	panel.add_child(preview)
	_info_preview = preview

	# Rarity badge (colored, updated in show_tower_info)
	_info_rarity_lbl = _label("", _font_bold, 14, C_DIM)
	_info_rarity_lbl.position             = Vector2(0, 94)
	_info_rarity_lbl.size                 = Vector2(PW, 18)
	_info_rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_rarity_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(_info_rarity_lbl)

	_info_name_lbl = _label("", _font_bold, 16, C_WHITE)
	_info_name_lbl.position             = Vector2(6, 114)
	_info_name_lbl.size                 = Vector2(PW - 12, 26)
	_info_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_name_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(_info_name_lbl)

	# _info_desc_lbl kept as a variable but not shown in the panel
	_info_desc_lbl = _label("", _font_reg, 14, C_DIM)

	var div2 := ColorRect.new()
	div2.color = Color(1,1,1,0.08); div2.position = Vector2(8,142); div2.size = Vector2(PW-16,2)
	div2.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(div2)

	# Stat rows — label left, value right
	var stat_defs := [
		["⚔ Damage",    146],
		["🎯 Range",     168],
		["🏹 Fire Rate", 190],
	]
	for s in stat_defs:
		var lbl := _label(s[0], _font_reg, 14, C_DIM)
		lbl.position     = Vector2(8, s[1])
		lbl.size         = Vector2(110, 20)
		lbl.mouse_filter = MOUSE_FILTER_IGNORE
		panel.add_child(lbl)

	_info_dmg_lbl = _label("", _font_bold, 14, C_WHITE)
	_info_dmg_lbl.position             = Vector2(115, 146)
	_info_dmg_lbl.size                 = Vector2(PW - 123, 20)
	_info_dmg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info_dmg_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(_info_dmg_lbl)

	_info_rng_lbl = _label("", _font_bold, 14, C_WHITE)
	_info_rng_lbl.position             = Vector2(115, 168)
	_info_rng_lbl.size                 = Vector2(PW - 123, 20)
	_info_rng_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info_rng_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(_info_rng_lbl)

	_info_rate_lbl = _label("", _font_bold, 14, C_WHITE)
	_info_rate_lbl.position             = Vector2(115, 190)
	_info_rate_lbl.size                 = Vector2(PW - 123, 20)
	_info_rate_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info_rate_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(_info_rate_lbl)

	var div_eff := ColorRect.new()
	div_eff.color        = Color(1, 1, 1, 0.08)
	div_eff.position     = Vector2(8, 216)
	div_eff.size         = Vector2(PW - 16, 2)
	div_eff.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(div_eff)

	var eff_header := _label("Special Effect", _font_bold, 14, C_GOLD)
	eff_header.position     = Vector2(8, 222)
	eff_header.size         = Vector2(PW - 16, 18)
	eff_header.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(eff_header)

	# Multi-line effect description — scrollable so it never bleeds past the panel
	_info_effect_lbl = _label("", _font_reg, 14, Color(0.92, 0.88, 0.72))
	_info_effect_lbl.custom_minimum_size = Vector2(PW - 16, 0)
	_info_effect_lbl.autowrap_mode       = TextServer.AUTOWRAP_WORD
	_info_effect_lbl.mouse_filter        = MOUSE_FILTER_PASS
	_info_effect_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_effect_lbl.size_flags_vertical   = Control.SIZE_SHRINK_BEGIN
	var eff_scroll := ScrollContainer.new()
	eff_scroll.position               = Vector2(8, 242)
	eff_scroll.size                   = Vector2(PW - 16, 130)
	eff_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	eff_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(eff_scroll)
	eff_scroll.add_child(_info_effect_lbl)
	var div3 := ColorRect.new()
	div3.color = Color(1,1,1,0.08); div3.position = Vector2(8,378); div3.size = Vector2(PW-16,2)
	div3.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(div3)

	var C_UPG := Color(0.48, 0.28, 0.08)
	_info_upgrade_btn = Button.new()
	_info_upgrade_btn.text         = "^  Upgrade  (3x)"
	_info_upgrade_btn.position     = Vector2(8, 388)
	_info_upgrade_btn.size         = Vector2(PW - 16, 30)
	_info_upgrade_btn.focus_mode   = FOCUS_NONE
	_info_upgrade_btn.visible      = false
	_info_upgrade_btn.add_theme_font_override("font",           _font_bold)
	_info_upgrade_btn.add_theme_font_size_override("font_size", 14)
	_info_upgrade_btn.add_theme_color_override("font_color",    C_WHITE)
	_info_upgrade_btn.add_theme_stylebox_override("normal",  _btn_style(C_UPG))
	_info_upgrade_btn.add_theme_stylebox_override("hover",   _btn_style(C_UPG.lightened(0.15)))
	_info_upgrade_btn.add_theme_stylebox_override("pressed", _btn_style(C_UPG.darkened(0.15)))
	_info_upgrade_btn.add_theme_stylebox_override("focus",   _btn_style(C_UPG))
	_info_upgrade_btn.pressed.connect(func(): upgrade_merge_requested.emit())
	panel.add_child(_info_upgrade_btn)


func show_tower_info(tower, merge_count: int = 0) -> void:
	if not is_instance_valid(tower):
		return
	var d : Dictionary = tower.tower_data
	if d.is_empty():
		return

	var rarity_cols := {
		"common":    Color(0.75, 0.75, 0.75),
		"rare":      Color(0.25, 0.55, 1.00),
		"epic":      Color(0.72, 0.25, 0.90),
		"legendary": Color(1.00, 0.72, 0.10),
		"fusion":    Color(0.20, 1.00, 0.85),
	}
	var rarity : String = d.get("rarity", "")
	var rc     : Color  = rarity_cols.get(rarity, Color(0.5, 0.5, 0.5, 0.4))

	if _info_panel_style != null:
		_info_panel_style.border_color = rc if rarity != "" else Color(0.5, 0.5, 0.5, 0.3)

	if rarity != "":
		_info_rarity_lbl.text = rarity.capitalize()
		_info_rarity_lbl.add_theme_color_override("font_color", rc)
	else:
		_info_rarity_lbl.text = ""

	_info_preview.turret_data = d
	_info_preview.queue_redraw()
	_info_name_lbl.text  = d.get("name", "Tower")
	_info_desc_lbl.text  = d.get("desc", "")
	var tid         : String = d.get("id", "")
	var dmg_mult    : float  = GameData.turret_damage_mult(tid)
	var spd_mult    : float  = GameData.turret_fire_rate_mult(tid)
	var eff_dmg     : float  = tower.damage * dmg_mult
	var base_rate   : float  = d.get("fire_rate", tower.fire_rate)
	var eff_rate    : float  = base_rate * spd_mult
	_info_dmg_lbl.text   = "%.0f" % eff_dmg + (" (+%.0f%%)" % [(dmg_mult - 1.0) * 100] if dmg_mult > 1.0 else "")
	_info_rng_lbl.text   = "%.0f px" % tower.attack_range
	_info_rate_lbl.text  = "%.1f / s" % eff_rate + (" (+%.0f%%)" % [(spd_mult - 1.0) * 100] if spd_mult > 1.0 else "")
	var eff_map : Dictionary = {
		"none":          "Standard single-target shot. No bonus effect.",
		"focused_shot":  "Consecutive hits on the same target deal +50% damage. Resets when switching targets.",
		"dual_shot":     "Fires at 2 separate enemies simultaneously each attack.",
		"chain":         "Hits primary target at full damage, then chains to 2 nearby enemies at 50% damage.",
		"aoe":           "Hits all enemies currently in range with each shot.",
		"aoe_burst":     "Explosive shot hits up to 5 enemies in range.",
		"melee_cleave":  "Every 3rd hit strikes all enemies in range instead of just the primary target.",
		"bleed_aoe":     "Every hit damages all enemies in range and applies a bleed stack (max 3 stacks). Each stack deals base damage per second.",
		"slow_zone":     "Normal shots deal damage. Every 5th shot drops an ice zone that slows enemies by 55% for 3 seconds.",
		"poison_debuff": "Poisons the target — poisoned enemies take 10% more damage from all sources for 5s. Refreshes on re-hit. Prioritizes un-poisoned enemies.",
		"execute_shot":  "Damage scales with enemy's current HP. Full HP = 2× base damage. Scales down linearly to 1× at 0 HP.",
		"knight_slam":   "Every 3rd hit is AoE (up to 5 enemies) and knocks them back along the path. Knockback has no effect on bosses.",
		"hp_strike":     "Deals base damage plus 1% of the target's current HP as bonus damage. Bonus does not apply to boss enemies.",
		"arcane_charge": "Persistent charge counter — every 20th hit fires a blue ray hitting all enemies in range. Counter never resets.",
		"lock_beam":     "Locks onto one target until it dies or leaves range. Beam damage ramps from 1× to 1.5× over 5 seconds of continuous fire.",
		"lightning":     "Chains to the primary target and up to 3 additional enemies at 80% damage.",
		"storm_chain":   "Chains to the primary target and up to 4 additional enemies at 85% damage.",
		"pierce":        "Bolt pierces through up to 3 enemies in a line, hitting each for full damage.",
	}
	var base_effect_desc : String = eff_map.get(d.get("effect", "none"), "No special effect.")
	var special_map : Dictionary = {
		"archer":   "★ Focused Shot+: Every hit permanently stacks +8% damage (max 10×).",
		"crossbow": "★ Triple Bolt: Fires 3 bolts instead of 2.",
		"mage":     "★ Arcane Chain: Chain now hits 5 enemies.",
		"catapult": "★ Barrage: Fires 2 shots per attack.",
		"spearman": "★ War Cry: Every 5th hit stuns enemies for 0.5s.",
		"rogue":    "★ Hemorrhage: Bleed cap raised to 6; each stack deals +12% damage.",
	}
	if GameData.turret_has_special(tid) and special_map.has(tid):
		base_effect_desc += "\n" + special_map[tid]
	_info_effect_lbl.text = base_effect_desc
	var can_upgrade : bool = merge_count >= 3 and \
		rarity != "legendary" and rarity != "fusion" and rarity != ""
	if is_instance_valid(_info_upgrade_btn):
		_info_upgrade_btn.visible = can_upgrade
	_info_panel.visible = true


func hide_tower_info() -> void:
	_info_panel.visible = false
	if is_instance_valid(_info_upgrade_btn):
		_info_upgrade_btn.visible = false



# ── Notification ──────────────────────────────────────────────────────────────

func _build_notification() -> void:
	_notify_lbl = Label.new()
	_notify_lbl.text     = ""
	_notify_lbl.position = Vector2(350, 320)
	_notify_lbl.size     = Vector2(400, 60)
	_notify_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notify_lbl.add_theme_font_override("font",           _font_bold)
	_notify_lbl.add_theme_font_size_override("font_size", 38)
	_notify_lbl.add_theme_color_override("font_color",        Color(0.20, 0.90, 0.65))
	_notify_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.80))
	_notify_lbl.add_theme_constant_override("shadow_offset_x", 2)
	_notify_lbl.add_theme_constant_override("shadow_offset_y", 2)
	_notify_lbl.modulate.a = 0.0
	add_child(_notify_lbl)


func _show_notification(msg: String) -> void:
	_notify_lbl.text = msg
	if _notify_tween and is_instance_valid(_notify_tween):
		_notify_tween.kill()
	_notify_lbl.modulate.a = 1.0
	_notify_lbl.position   = Vector2(350, 320)
	_notify_tween = create_tween()
	_notify_tween.tween_property(_notify_lbl, "position:y", 270.0, 1.0) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_notify_tween.parallel().tween_property(_notify_lbl, "modulate:a", 0.0, 1.0) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


func show_notification(msg: String) -> void:
	_show_notification(msg)


# ══════════════════════════════════════════════════════════════════════════════
# GAME OVER SCREEN
# ══════════════════════════════════════════════════════════════════════════════

func show_run_results(stage: int, kills: int, bosses: int, gems: int, turrets: Array, victory: bool = false) -> void:
	_run_results_screen.visible = true
	var title_lbl  : Label = _run_results_screen.get_node("title")
	var stage_lbl  : Label = _run_results_screen.get_node("stage")
	var kills_lbl  : Label = _run_results_screen.get_node("kills")
	var gems_lbl   : Label = _run_results_screen.get_node("gems")
	var loot_box   : Control = _run_results_screen.get_node("loot_box")

	title_lbl.text = "🏆  Victory!" if victory else "💀  Defeated"
	title_lbl.add_theme_color_override("font_color", C_GOLD if victory else C_RED)
	stage_lbl.text = "Stage %d reached" % stage
	kills_lbl.text = "⚔  Enemies slain:  %d  (%d bosses)" % [kills, bosses]
	gems_lbl.text  = "🔷  Blue Gems earned:  +%d  (total: %d)" % [gems, GameData.blue_gems]

	for child in loot_box.get_children():
		child.queue_free()

	var rarity_colors := {
		"common": Color(0.75, 0.75, 0.75), "rare": Color(0.25, 0.55, 1.00),
		"epic": Color(0.72, 0.25, 0.90), "legendary": Color(1.00, 0.72, 0.10),
		"fusion": Color(0.20, 1.00, 0.85),
	}
	var col : int = 0
	var row : int = 0
	const COLS : int = 6
	const CARD_W : int = 160
	const CARD_H : int = 60
	const GAP    : int = 10
	for td in turrets:
		var name   : String = td.get("name", "?")
		var rarity : String = td.get("rarity", "common")
		var rc     : Color  = rarity_colors.get(rarity, C_WHITE)
		var card   := Panel.new()
		card.position = Vector2(col * (CARD_W + GAP), row * (CARD_H + GAP))
		card.size     = Vector2(CARD_W, CARD_H)
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color(rc.r * 0.18, rc.g * 0.18, rc.b * 0.18, 1.0)
		cs.corner_radius_top_left = 6; cs.corner_radius_top_right = 6
		cs.corner_radius_bottom_left = 6; cs.corner_radius_bottom_right = 6
		cs.border_width_left = 2; cs.border_width_right = 2
		cs.border_width_top  = 2; cs.border_width_bottom = 2
		cs.border_color = rc
		card.add_theme_stylebox_override("panel", cs)
		loot_box.add_child(card)
		var lbl := _label(name, _font_bold, 14, rc)
		lbl.position             = Vector2(0, 0)
		lbl.size                 = Vector2(CARD_W, CARD_H)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		card.add_child(lbl)
		col += 1
		if col >= COLS:
			col = 0
			row += 1


func _build_run_results_screen() -> void:
	var overlay := Panel.new()
	var bg_s := StyleBoxFlat.new()
	bg_s.bg_color = Color(0.04, 0.04, 0.10)
	bg_s.corner_radius_top_left = 0; bg_s.corner_radius_top_right = 0
	bg_s.corner_radius_bottom_left = 0; bg_s.corner_radius_bottom_right = 0
	overlay.add_theme_stylebox_override("panel", bg_s)
	overlay.position     = Vector2.ZERO
	overlay.size         = Vector2(1280, 720)
	overlay.mouse_filter = MOUSE_FILTER_STOP
	overlay.visible      = false
	add_child(overlay)
	_run_results_screen = overlay

	var title := _label("", _font_bold, 36, C_GOLD)
	title.name                 = "title"
	title.position             = Vector2(0, 30)
	title.size                 = Vector2(1280, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(title)

	var stage_lbl := _label("", _font_bold, 22, C_WHITE)
	stage_lbl.name                 = "stage"
	stage_lbl.position             = Vector2(0, 100)
	stage_lbl.size                 = Vector2(1280, 36)
	stage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(stage_lbl)

	var kills_lbl := _label("", _font_bold, 20, C_DIM)
	kills_lbl.name                 = "kills"
	kills_lbl.position             = Vector2(0, 148)
	kills_lbl.size                 = Vector2(1280, 32)
	kills_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(kills_lbl)

	var gems_lbl := _label("", _font_bold, 22, Color(0.45, 0.75, 1.0))
	gems_lbl.name                 = "gems"
	gems_lbl.position             = Vector2(0, 188)
	gems_lbl.size                 = Vector2(1280, 32)
	gems_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(gems_lbl)

	var loot_title := _label("🗼  Turrets on Field", _font_bold, 18, C_DIM)
	loot_title.position             = Vector2(80, 238)
	loot_title.size                 = Vector2(400, 28)
	overlay.add_child(loot_title)

	var loot_box := Control.new()
	loot_box.name     = "loot_box"
	loot_box.position = Vector2(80, 272)
	loot_box.size     = Vector2(1120, 340)
	overlay.add_child(loot_box)

	var cont_btn := Button.new()
	cont_btn.text         = "Continue  →"
	cont_btn.position     = Vector2(1280 - 230, 720 - 75)
	cont_btn.size         = Vector2(200, 54)
	cont_btn.focus_mode   = FOCUS_NONE
	cont_btn.add_theme_font_override("font",           _font_bold)
	cont_btn.add_theme_font_size_override("font_size", 20)
	cont_btn.add_theme_color_override("font_color",    C_WHITE)
	cont_btn.add_theme_stylebox_override("normal",  _btn_style(C_BTN))
	cont_btn.add_theme_stylebox_override("hover",   _btn_style(C_BTN_HOV))
	cont_btn.add_theme_stylebox_override("pressed", _btn_style(C_BTN.darkened(0.1)))
	cont_btn.add_theme_stylebox_override("focus",   _btn_style(C_BTN))
	cont_btn.pressed.connect(func():
		overlay.visible = false
		_game_over_screen.visible = true
	)
	overlay.add_child(cont_btn)


func _build_game_over_screen() -> void:
	# Full-screen main page shown on game over
	var overlay := Panel.new()
	var bg_s := StyleBoxFlat.new()
	bg_s.bg_color = Color(0.04, 0.04, 0.10)
	bg_s.corner_radius_top_left = 0; bg_s.corner_radius_top_right = 0
	bg_s.corner_radius_bottom_left = 0; bg_s.corner_radius_bottom_right = 0
	overlay.add_theme_stylebox_override("panel", bg_s)
	overlay.position     = Vector2.ZERO
	overlay.size         = Vector2(1280, 720)
	overlay.mouse_filter = MOUSE_FILTER_STOP
	overlay.visible      = false
	add_child(overlay)
	_game_over_screen = overlay

	# Dark vignette gradient bands for atmosphere
	var top_band := ColorRect.new()
	top_band.color    = Color(0.55, 0.08, 0.08, 0.35)
	top_band.position = Vector2.ZERO
	top_band.size     = Vector2(1280, 180)
	top_band.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(top_band)

	# Title
	_go_title_lbl = _label("💀  IDLE BASTION", _font_bold, 52, C_WHITE)
	var title : Label = _go_title_lbl
	title.position             = Vector2(0, 28)
	title.size                 = Vector2(1280, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter         = MOUSE_FILTER_IGNORE
	overlay.add_child(title)

	# Subtitle / stage info
	_go_stage_lbl = _label("Stage 1 reached", _font_bold, 22, Color(0.85, 0.55, 0.55))
	_go_stage_lbl.position             = Vector2(0, 106)
	_go_stage_lbl.size                 = Vector2(1280, 34)
	_go_stage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go_stage_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	overlay.add_child(_go_stage_lbl)

	_go_flavour_lbl = _label("Your kingdom has fallen…", _font_reg, 16, Color(0.55, 0.42, 0.42))
	_go_flavour_lbl.position             = Vector2(0, 140)
	_go_flavour_lbl.size                 = Vector2(1280, 26)
	_go_flavour_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go_flavour_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	overlay.add_child(_go_flavour_lbl)

	# Horizontal divider
	var hdiv := ColorRect.new()
	hdiv.color    = Color(1, 1, 1, 0.07)
	hdiv.position = Vector2(120, 178)
	hdiv.size     = Vector2(1040, 2)
	hdiv.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(hdiv)

	# Nav buttons — left-center column (Upgrades, Shop, World Map)
	const NAV_BTN_W : int = 260
	const NAV_BTN_H : int = 64
	const NAV_BTN_X : int = 100
	const NAV_BTN_GAP : int = 20
	var nav_data := [
		{"label": "⚔  Upgrades",  "color": Color(0.18, 0.28, 0.55), "hover": Color(0.25, 0.38, 0.72)},
		{"label": "🛒  Shop",      "color": Color(0.18, 0.38, 0.22), "hover": Color(0.24, 0.50, 0.30)},
		{"label": "🗺  World Map", "color": Color(0.30, 0.20, 0.45), "hover": Color(0.40, 0.28, 0.60)},
		{"label": "🦸  Heroes",    "color": Color(0.45, 0.18, 0.18), "hover": Color(0.60, 0.24, 0.24)},
		{"label": "🗼  Towers",    "color": Color(0.35, 0.28, 0.12), "hover": Color(0.50, 0.40, 0.18)},
	]
	var nav_start_y : int = 240
	for ni in range(nav_data.size()):
		var nd       : Dictionary = nav_data[ni]
		var btn_y    : int        = nav_start_y + ni * (NAV_BTN_H + NAV_BTN_GAP)
		var nav_btn  := Button.new()
		nav_btn.text         = nd["label"]
		nav_btn.position     = Vector2(NAV_BTN_X, btn_y)
		nav_btn.size         = Vector2(NAV_BTN_W, NAV_BTN_H)
		nav_btn.focus_mode   = FOCUS_NONE
		nav_btn.pivot_offset = Vector2(NAV_BTN_W / 2.0, NAV_BTN_H / 2.0)
		nav_btn.add_theme_font_override("font",           _font_bold)
		nav_btn.add_theme_font_size_override("font_size", 20)
		nav_btn.add_theme_color_override("font_color",    C_WHITE)
		nav_btn.add_theme_stylebox_override("normal",  _btn_style(nd["color"]))
		nav_btn.add_theme_stylebox_override("hover",   _btn_style(nd["hover"]))
		nav_btn.add_theme_stylebox_override("pressed", _btn_style((nd["color"] as Color).darkened(0.2)))
		nav_btn.add_theme_stylebox_override("focus",   _btn_style(nd["color"]))
		var cap_ni := ni
		nav_btn.pressed.connect(func(): _on_main_nav_pressed(cap_ni))
		overlay.add_child(nav_btn)

	# "Start Game" button — bottom right
	var start_btn := Button.new()
	start_btn.text         = ">  Start Game"
	start_btn.position     = Vector2(1280 - 260 - 40, 720 - 80 - 40)
	start_btn.size         = Vector2(260, 80)
	start_btn.pivot_offset = Vector2(130, 40)
	start_btn.focus_mode   = FOCUS_NONE
	start_btn.add_theme_font_override("font",           _font_bold)
	start_btn.add_theme_font_size_override("font_size", 26)
	start_btn.add_theme_color_override("font_color",    C_WHITE)
	start_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.55, 0.22, 0.05)))
	start_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.72, 0.30, 0.07)))
	start_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.40, 0.16, 0.03)))
	start_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.55, 0.22, 0.05)))
	start_btn.pressed.connect(func(): Engine.time_scale = 1.0; get_tree().reload_current_scene())
	overlay.add_child(start_btn)


func show_game_over(stage: int) -> void:
	_go_title_lbl.text      = "💀  IDLE BASTION"
	_go_stage_lbl.text      = "Stage %d reached" % stage
	_go_stage_lbl.visible   = true
	_go_flavour_lbl.visible = true
	_game_over_screen.visible = true


func show_main_menu() -> void:
	_go_title_lbl.text      = "🛡  IDLE BASTION"
	_go_stage_lbl.visible   = false
	_go_flavour_lbl.visible = false
	_game_over_screen.visible = true


func _on_main_nav_pressed(idx: int) -> void:
	match idx:
		0: # Upgrades
			_game_over_screen.visible = false
			_upgrades_screen.visible = true
		1: # Shop
			_game_over_screen.visible = false
			_shop_screen.visible = true
		2: # World Map
			_game_over_screen.visible = false
			_world_map_screen.visible = true
		3: # Heroes
			_game_over_screen.visible = false
			_heroes_screen.visible = true
		4: # Towers
			_game_over_screen.visible = false
			_towers_screen.visible = true


func _on_continue_pressed() -> void:
	_game_over_screen.visible = false
	_refresh_all_upg_rows_postbattle()
	_upgrades_screen.visible = true


# ══════════════════════════════════════════════════════════════════════════════
# PRE-BATTLE UPGRADES SCREEN
# ══════════════════════════════════════════════════════════════════════════════

func _build_upgrades_screen() -> void:
	var overlay := Control.new()
	overlay.position     = Vector2.ZERO
	overlay.size         = Vector2(1280, 720)
	overlay.mouse_filter = MOUSE_FILTER_STOP
	overlay.clip_contents = true
	overlay.visible      = false
	add_child(overlay)
	_upgrades_screen = overlay

	# Panning upgrade tree
	var tree : Control = load("res://ui/UpgradeTree.gd").new()
	tree.position     = Vector2.ZERO
	tree.size         = Vector2(1280, 720)
	tree.mouse_filter = MOUSE_FILTER_STOP
	overlay.add_child(tree)
	overlay.visibility_changed.connect(func():
		if overlay.visible:
			tree.setup(_font_bold, _font_reg)
	)

	# Back button on top
	var back_btn := Button.new()
	back_btn.text         = "<  Back"
	back_btn.position     = Vector2(14, 14)
	back_btn.size         = Vector2(130, 46)
	back_btn.z_index      = 10
	back_btn.focus_mode   = FOCUS_NONE
	back_btn.add_theme_font_override("font",           _font_bold)
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.add_theme_color_override("font_color",    C_WHITE)
	back_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.22, 0.22, 0.28)))
	back_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.30, 0.30, 0.38)))
	back_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.16, 0.16, 0.20)))
	back_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.22, 0.22, 0.28)))
	back_btn.pressed.connect(func():
		overlay.visible = false
		_game_over_screen.visible = true
	)
	overlay.add_child(back_btn)


func _build_placeholder_screen(var_ref: String, title_text: String) -> Control:
	var overlay := Panel.new()
	var bg_s := StyleBoxFlat.new()
	bg_s.bg_color = Color(0.04, 0.04, 0.10)
	bg_s.corner_radius_top_left = 0; bg_s.corner_radius_top_right = 0
	bg_s.corner_radius_bottom_left = 0; bg_s.corner_radius_bottom_right = 0
	overlay.add_theme_stylebox_override("panel", bg_s)
	overlay.position     = Vector2.ZERO
	overlay.size         = Vector2(1280, 720)
	overlay.mouse_filter = MOUSE_FILTER_STOP
	overlay.visible      = false
	add_child(overlay)

	var title := _label(title_text, _font_bold, 32, C_WHITE)
	title.position             = Vector2(0, 40)
	title.size                 = Vector2(1280, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(title)

	var back_btn := Button.new()
	back_btn.text         = "<  Back"
	back_btn.position     = Vector2(30, 720 - 80)
	back_btn.size         = Vector2(150, 54)
	back_btn.focus_mode   = FOCUS_NONE
	back_btn.add_theme_font_override("font",           _font_bold)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.add_theme_color_override("font_color",    C_WHITE)
	back_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.22, 0.22, 0.28)))
	back_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.30, 0.30, 0.38)))
	back_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.16, 0.16, 0.20)))
	back_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.22, 0.22, 0.28)))
	back_btn.pressed.connect(func():
		overlay.visible = false
		_game_over_screen.visible = true
	)
	overlay.add_child(back_btn)
	return overlay


func _build_shop_screen() -> void:
	_shop_screen = _build_placeholder_screen("_shop_screen", "🛒  Shop")


func _build_world_map_screen() -> void:
	_world_map_screen = _build_placeholder_screen("_world_map_screen", "🗺  World Map")


func _build_heroes_screen() -> void:
	# ── Outer overlay ──────────────────────────────────────────────────────────
	var overlay := Panel.new()
	var bg_s := StyleBoxFlat.new()
	bg_s.bg_color = Color(0.04, 0.04, 0.10)
	overlay.add_theme_stylebox_override("panel", bg_s)
	overlay.position     = Vector2.ZERO
	overlay.size         = Vector2(1280, 720)
	overlay.mouse_filter = MOUSE_FILTER_STOP
	overlay.visible      = false
	add_child(overlay)
	_heroes_screen = overlay

	_hero_card_refs.clear()

	# ── Title ──────────────────────────────────────────────────────────────────
	var title := _label("🦸  Heroes", _font_bold, 30, C_WHITE)
	title.position             = Vector2(0, 18)
	title.size                 = Vector2(1280, 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(title)

	# ── "Hero Selected" banner ─────────────────────────────────────────────────
	var sel_panel := Panel.new()
	var sel_style := StyleBoxFlat.new()
	sel_style.bg_color                  = Color(0.08, 0.08, 0.18, 1.0)
	sel_style.corner_radius_top_left    = 10; sel_style.corner_radius_top_right    = 10
	sel_style.corner_radius_bottom_left = 10; sel_style.corner_radius_bottom_right = 10
	sel_style.border_width_left = 2; sel_style.border_width_right  = 2
	sel_style.border_width_top  = 2; sel_style.border_width_bottom = 2
	sel_style.border_color = Color(0.40, 0.40, 0.55, 0.6)
	sel_panel.add_theme_stylebox_override("panel", sel_style)
	sel_panel.position     = Vector2(20, 70)
	sel_panel.size         = Vector2(1240, 110)
	sel_panel.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(sel_panel)

	var sel_hdr := _label("Hero Selected", _font_bold, 14, C_DIM)
	sel_hdr.position = Vector2(16, 8); sel_hdr.size = Vector2(200, 20)
	sel_hdr.mouse_filter = MOUSE_FILTER_IGNORE
	sel_panel.add_child(sel_hdr)

	# Inner container that gets rebuilt on selection change
	var sel_box := Control.new()
	sel_box.position     = Vector2(0, 28)
	sel_box.size         = Vector2(1240, 80)
	sel_box.mouse_filter = MOUSE_FILTER_IGNORE
	sel_panel.add_child(sel_box)
	_hero_sel_container = sel_box

	# Preview placeholder (replaced in _hero_refresh_selected)
	_hero_sel_preview = _TurretPreview.new()
	_hero_sel_preview.position = Vector2(16, 4)
	sel_box.add_child(_hero_sel_preview)

	_hero_sel_name = _label("", _font_bold, 18, C_WHITE)
	_hero_sel_name.position = Vector2(80, 6); _hero_sel_name.size = Vector2(350, 26)
	_hero_sel_name.mouse_filter = MOUSE_FILTER_IGNORE
	sel_box.add_child(_hero_sel_name)

	_hero_sel_stats = _label("", _font_reg, 14, C_DIM)
	_hero_sel_stats.position = Vector2(80, 36); _hero_sel_stats.size = Vector2(700, 20)
	_hero_sel_stats.mouse_filter = MOUSE_FILTER_IGNORE
	sel_box.add_child(_hero_sel_stats)

	var active_badge := _label("✓  Active", _font_bold, 14, Color(0.30, 0.90, 0.45))
	active_badge.position = Vector2(1140, 26); active_badge.size = Vector2(90, 20)
	active_badge.mouse_filter = MOUSE_FILTER_IGNORE
	sel_box.add_child(active_badge)

	_hero_refresh_selected()

	# ── Scroll area ────────────────────────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.position               = Vector2(20, 192)
	scroll.size                   = Vector2(1240, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	overlay.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	const H_RARITY_ORDER  : Array = ["common", "rare", "epic", "legendary"]
	const H_RARITY_LABELS : Dictionary = {
		"common":    "⬜  Common",
		"rare":      "🔵  Rare",
		"epic":      "🟣  Epic",
		"legendary": "🟡  Legendary",
	}
	const H_RARITY_COLS : Dictionary = {
		"common":    Color(0.75, 0.75, 0.75),
		"rare":      Color(0.25, 0.55, 1.00),
		"epic":      Color(0.72, 0.25, 0.90),
		"legendary": Color(1.00, 0.72, 0.10),
	}

	var by_rarity : Dictionary = {}
	for r in H_RARITY_ORDER:
		by_rarity[r] = []
	for hid in GameData.HERO_DEFS:
		var hd : Dictionary = GameData.HERO_DEFS[hid]
		var r  : String     = hd.get("rarity", "common")
		if by_rarity.has(r):
			by_rarity[r].append(hd)

	const H_CARDS_PER_ROW : int = 4
	const H_CARD_W        : int = 294
	const H_CARD_H        : int = 86

	for rarity in H_RARITY_ORDER:
		var defs : Array = by_rarity[rarity]
		if defs.is_empty():
			continue

		var hdr := _label(H_RARITY_LABELS.get(rarity, rarity), _font_bold, 16,
						  H_RARITY_COLS.get(rarity, C_WHITE))
		hdr.size = Vector2(1240, 26)
		var hdr_c := Control.new()
		hdr_c.custom_minimum_size = Vector2(1240, 32)
		hdr.position = Vector2(8, 4)
		hdr_c.add_child(hdr)
		vbox.add_child(hdr_c)

		var col : int = 0
		var row_box : HBoxContainer = null
		for def in defs:
			if col == 0:
				row_box = HBoxContainer.new()
				row_box.add_theme_constant_override("separation", 6)
				row_box.custom_minimum_size = Vector2(1240, H_CARD_H)
				vbox.add_child(row_box)
			_hero_make_card(row_box, def, H_CARD_W, H_CARD_H,
							H_RARITY_COLS.get(rarity, C_WHITE))
			col += 1
			if col >= H_CARDS_PER_ROW:
				col = 0

		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 10)
		vbox.add_child(spacer)

	# ── Back button ────────────────────────────────────────────────────────────
	var back_btn := Button.new()
	back_btn.text         = "<  Back"
	back_btn.position     = Vector2(30, 666)
	back_btn.size         = Vector2(150, 46)
	back_btn.focus_mode   = FOCUS_NONE
	back_btn.add_theme_font_override("font",           _font_bold)
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.add_theme_color_override("font_color",    C_WHITE)
	back_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.14, 0.14, 0.24)))
	back_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.22, 0.22, 0.36)))
	back_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.10, 0.10, 0.18)))
	back_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.14, 0.14, 0.24)))
	back_btn.pressed.connect(func():
		overlay.visible = false
		_game_over_screen.visible = true
	)
	overlay.add_child(back_btn)

	# ── Hero detail panel ──────────────────────────────────────────────────────
	_hero_build_detail_panel(overlay)


func _hero_refresh_selected() -> void:
	if not is_instance_valid(_hero_sel_preview):
		return
	var def : Dictionary = GameData.HERO_DEFS.get(GameData.selected_hero_id, {})
	if def.is_empty():
		return
	_hero_sel_preview.turret_data = def
	_hero_sel_preview.queue_redraw()
	_hero_sel_name.text  = def.get("name", "")
	var rcol : Color = _hero_rarity_color(def.get("rarity", "common"))
	_hero_sel_name.add_theme_color_override("font_color", rcol)
	_hero_sel_stats.text = "⚔ %.0f  ·  🎯 %.0f px  ·  🏹 %.1f/s  ·  %s" % [
		def.get("damage", 0.0), def.get("range", 0.0), def.get("fire_rate", 0.0),
		def.get("effect", "none").replace("_", " ").capitalize()
	]


func _hero_rarity_color(rarity: String) -> Color:
	match rarity:
		"rare":      return Color(0.25, 0.55, 1.00)
		"epic":      return Color(0.72, 0.25, 0.90)
		"legendary": return Color(1.00, 0.72, 0.10)
		_:           return Color(0.75, 0.75, 0.75)


func _hero_make_card(parent: Control, def: Dictionary,
					  cw: int, ch: int, rcol: Color) -> void:
	var hero_id     : String = def.get("id", "")
	var is_selected : bool   = (hero_id == GameData.selected_hero_id)
	var card := Panel.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color                   = Color(0.10, 0.18, 0.10) if is_selected else Color(0.10, 0.10, 0.18)
	cs.corner_radius_top_left     = 8; cs.corner_radius_top_right    = 8
	cs.corner_radius_bottom_left  = 8; cs.corner_radius_bottom_right = 8
	cs.border_width_left = 2; cs.border_width_right  = 2
	cs.border_width_top  = 2; cs.border_width_bottom = 2
	cs.border_color = Color(0.30, 0.90, 0.45) if is_selected else rcol
	card.add_theme_stylebox_override("panel", cs)
	card.custom_minimum_size = Vector2(cw, ch)
	card.mouse_filter        = MOUSE_FILTER_STOP
	parent.add_child(card)

	# Preview
	var prev := _TurretPreview.new()
	prev.turret_data = def
	prev.position    = Vector2(6, (ch - 56) / 2)
	card.add_child(prev)

	# Name
	var name_lbl := _label(def.get("name", ""), _font_bold, 15, C_WHITE)
	name_lbl.position     = Vector2(66, 10)
	name_lbl.size         = Vector2(cw - 120, 22)
	name_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)

	# Rarity
	var rar_lbl := _label(def.get("rarity", "").capitalize(), _font_reg, 14, rcol)
	rar_lbl.position     = Vector2(66, 32)
	rar_lbl.size         = Vector2(cw - 84, 16)
	rar_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(rar_lbl)

	# Stat line
	var stat_str := "⚔ %.0f  ·  🎯 %.0f  ·  🏹 %.1f/s" % [
		def.get("damage", 0.0), def.get("range", 0.0), def.get("fire_rate", 0.0)]
	var stat_lbl := _label(stat_str, _font_reg, 13, C_DIM)
	stat_lbl.position     = Vector2(66, 52)
	stat_lbl.size         = Vector2(cw - 84, 18)
	stat_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(stat_lbl)

	# ✓ badge (always present, visibility toggled on select)
	var badge := _label("✓", _font_bold, 16, Color(0.30, 0.90, 0.45))
	badge.position             = Vector2(cw - 28, 8)
	badge.size                 = Vector2(22, 22)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.mouse_filter         = MOUSE_FILTER_IGNORE
	badge.visible              = is_selected
	card.add_child(badge)

	# Store ref for live highlight updates
	_hero_card_refs.append({"id": hero_id, "style": cs, "badge": badge, "rcol": rcol})

	# Click → open detail
	var cap_def := def
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			_hero_show_detail(cap_def)
	)


func _hero_build_detail_panel(parent: Control) -> void:
	const PW : int = 580
	const PH : int = 430

	var panel := Panel.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color                   = Color(0.07, 0.06, 0.13, 0.98)
	ps.corner_radius_top_left     = 12; ps.corner_radius_top_right    = 12
	ps.corner_radius_bottom_left  = 12; ps.corner_radius_bottom_right = 12
	ps.border_width_left = 2; ps.border_width_right  = 2
	ps.border_width_top  = 2; ps.border_width_bottom = 2
	ps.border_color = Color(0.5, 0.5, 0.6, 0.5)
	ps.shadow_color = Color(0, 0, 0, 0.65); ps.shadow_size = 14
	panel.add_theme_stylebox_override("panel", ps)
	panel.position     = Vector2((1280 - PW) / 2, (720 - PH) / 2)
	panel.size         = Vector2(PW, PH)
	panel.mouse_filter = MOUSE_FILTER_STOP
	panel.visible      = false
	panel.z_index      = 20
	parent.add_child(panel)
	_hero_det_panel  = panel
	_hero_det_style  = ps

	# Dim backdrop
	var dim := ColorRect.new()
	dim.color        = Color(0, 0, 0, 0.55)
	dim.position     = Vector2(-(1280 - PW) / 2, -(720 - PH) / 2)
	dim.size         = Vector2(1280, 720)
	dim.mouse_filter = MOUSE_FILTER_STOP
	dim.z_index      = -1
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			panel.visible = false
	)
	panel.add_child(dim)

	# Header
	var hdr_bg := Panel.new()
	var hdr_sty := StyleBoxFlat.new()
	hdr_sty.bg_color                   = Color(0.05, 0.16, 0.28, 1.0)
	hdr_sty.corner_radius_top_left     = 12; hdr_sty.corner_radius_top_right  = 12
	hdr_sty.corner_radius_bottom_left  = 0;  hdr_sty.corner_radius_bottom_right = 0
	hdr_bg.add_theme_stylebox_override("panel", hdr_sty)
	hdr_bg.position = Vector2(2, 2); hdr_bg.size = Vector2(PW - 4, 50)
	hdr_bg.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(hdr_bg)

	_hero_det_name = _label("", _font_bold, 20, C_WHITE)
	_hero_det_name.position             = Vector2(0, 12)
	_hero_det_name.size                 = Vector2(PW - 60, 28)
	_hero_det_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_det_name.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(_hero_det_name)

	var close_btn := Button.new()
	close_btn.text       = "X"
	close_btn.position   = Vector2(PW - 46, 8)
	close_btn.size       = Vector2(36, 36)
	close_btn.focus_mode = FOCUS_NONE
	close_btn.add_theme_font_override("font",           _font_bold)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.add_theme_color_override("font_color",    C_WHITE)
	close_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.55, 0.12, 0.12)))
	close_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.72, 0.18, 0.18)))
	close_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.40, 0.08, 0.08)))
	close_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.55, 0.12, 0.12)))
	close_btn.pressed.connect(func(): panel.visible = false)
	panel.add_child(close_btn)

	# Vertical divider
	const LW : int = 268
	const RX : int = 280
	const RW : int = PW - RX - 12
	var vdiv := ColorRect.new()
	vdiv.color = Color(1,1,1,0.10); vdiv.position = Vector2(LW, 56); vdiv.size = Vector2(2, PH - 64)
	vdiv.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(vdiv)

	# ── LEFT COLUMN ────────────────────────────────────────────────────────────
	# Preview
	_hero_det_preview = _TurretPreview.new()
	_hero_det_preview.position = Vector2((LW - 56) / 2, 62)
	panel.add_child(_hero_det_preview)

	# Rarity
	_hero_det_rarity = _label("", _font_bold, 14, C_DIM)
	_hero_det_rarity.position             = Vector2(0, 156)
	_hero_det_rarity.size                 = Vector2(LW, 20)
	_hero_det_rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_det_rarity.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(_hero_det_rarity)

	var div1 := ColorRect.new()
	div1.color = Color(1,1,1,0.08); div1.position = Vector2(12,180); div1.size = Vector2(LW-20,1)
	div1.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(div1)

	# Stat rows
	for sr in [["⚔ Damage", 188, "_hero_det_dmg"], ["🎯 Range", 212, "_hero_det_rng"],
			   ["🏹 Fire Rate", 236, "_hero_det_rate"], ["Effect", 260, "_hero_det_eff"]]:
		var kl := _label(sr[0], _font_reg, 14, C_DIM)
		kl.position = Vector2(12, sr[1]); kl.size = Vector2(112, 20)
		kl.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(kl)

	_hero_det_dmg = _label("", _font_bold, 14, C_WHITE)
	_hero_det_dmg.position = Vector2(128, 188); _hero_det_dmg.size = Vector2(LW - 136, 20)
	_hero_det_dmg.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(_hero_det_dmg)

	_hero_det_rng = _label("", _font_bold, 14, C_WHITE)
	_hero_det_rng.position = Vector2(128, 212); _hero_det_rng.size = Vector2(LW - 136, 20)
	_hero_det_rng.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(_hero_det_rng)

	_hero_det_rate = _label("", _font_bold, 14, C_WHITE)
	_hero_det_rate.position = Vector2(128, 236); _hero_det_rate.size = Vector2(LW - 136, 20)
	_hero_det_rate.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(_hero_det_rate)

	_hero_det_eff = _label("", _font_bold, 14, C_WHITE)
	_hero_det_eff.position = Vector2(128, 260); _hero_det_eff.size = Vector2(LW - 136, 20)
	_hero_det_eff.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(_hero_det_eff)

	var div2 := ColorRect.new()
	div2.color = Color(1,1,1,0.08); div2.position = Vector2(12,286); div2.size = Vector2(LW-20,1)
	div2.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(div2)

	var desc_hdr := _label("Description", _font_bold, 14, C_GOLD)
	desc_hdr.position = Vector2(12, 292); desc_hdr.size = Vector2(LW - 20, 18)
	desc_hdr.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(desc_hdr)

	var desc_scroll := ScrollContainer.new()
	desc_scroll.position              = Vector2(12, 314)
	desc_scroll.size                  = Vector2(LW - 16, 100)
	desc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	desc_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(desc_scroll)
	_hero_det_desc = _label("", _font_reg, 14, C_DIM)
	_hero_det_desc.custom_minimum_size    = Vector2(LW - 16, 0)
	_hero_det_desc.autowrap_mode          = TextServer.AUTOWRAP_WORD
	_hero_det_desc.mouse_filter           = MOUSE_FILTER_PASS
	_hero_det_desc.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	_hero_det_desc.size_flags_vertical    = Control.SIZE_SHRINK_BEGIN
	desc_scroll.add_child(_hero_det_desc)

	# ── RIGHT COLUMN ───────────────────────────────────────────────────────────
	var eff_hdr := _label("Special Ability", _font_bold, 14, C_GOLD)
	eff_hdr.position = Vector2(RX, 62); eff_hdr.size = Vector2(RW, 18)
	eff_hdr.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(eff_hdr)

	var abil_scroll := ScrollContainer.new()
	abil_scroll.position               = Vector2(RX, 84)
	abil_scroll.size                   = Vector2(RW, 220)
	abil_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	abil_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(abil_scroll)
	_hero_det_ability = _label("", _font_reg, 14, Color(0.92, 0.88, 0.72))
	_hero_det_ability.custom_minimum_size   = Vector2(RW, 0)
	_hero_det_ability.autowrap_mode         = TextServer.AUTOWRAP_WORD
	_hero_det_ability.mouse_filter          = MOUSE_FILTER_PASS
	_hero_det_ability.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_det_ability.size_flags_vertical   = Control.SIZE_SHRINK_BEGIN
	abil_scroll.add_child(_hero_det_ability)

	# Select Hero button
	_hero_det_select = Button.new()
	_hero_det_select.position   = Vector2(RX, 324)
	_hero_det_select.size       = Vector2(RW, 52)
	_hero_det_select.focus_mode = FOCUS_NONE
	_hero_det_select.add_theme_font_override("font",           _font_bold)
	_hero_det_select.add_theme_font_size_override("font_size", 16)
	_hero_det_select.add_theme_color_override("font_color",    C_WHITE)
	_hero_det_select.add_theme_stylebox_override("normal",  _btn_style(Color(0.12, 0.42, 0.18)))
	_hero_det_select.add_theme_stylebox_override("hover",   _btn_style(Color(0.18, 0.58, 0.25)))
	_hero_det_select.add_theme_stylebox_override("pressed", _btn_style(Color(0.08, 0.30, 0.12)))
	_hero_det_select.add_theme_stylebox_override("focus",   _btn_style(Color(0.12, 0.42, 0.18)))
	panel.add_child(_hero_det_select)

	var note_lbl := _label("Takes effect on next game start", _font_reg, 12, C_DIM)
	note_lbl.position             = Vector2(RX, 382)
	note_lbl.size                 = Vector2(RW, 18)
	note_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(note_lbl)


func _hero_show_detail(def: Dictionary) -> void:
	if not is_instance_valid(_hero_det_panel):
		return
	var eff_map : Dictionary = {
		"none":          "Standard single-target shot. No bonus effect.",
		"focused_shot":  "Consecutive hits on the same target deal +50% damage.",
		"dual_shot":     "Fires at 2 separate enemies simultaneously.",
		"chain":         "Chains to 2 nearby enemies at 50% damage.",
		"aoe":           "Hits all enemies currently in range.",
		"aoe_burst":     "Explosive shot hits up to 5 enemies in range.",
		"melee_cleave":  "Every 3rd hit strikes all enemies in range.",
		"bleed_aoe":     "Hits all in range; applies bleed (max 3 stacks, 1 dmg/s each).",
		"slow_zone":     "Every 5th shot drops an ice zone slowing enemies 55% for 3s.",
		"poison_debuff": "Poisons targets — +10% damage taken for 5s.",
		"execute_shot":  "Up to 2× damage based on enemy current HP%.",
		"knight_slam":   "Every 3rd hit is AoE and knocks enemies back.",
		"hp_strike":     "Deals base dmg + 1% of target's current HP.",
		"arcane_charge": "Every 20th hit fires a blue laser for 2× damage to all in range.",
		"lightning":     "Chains to primary + 3 more at 80% damage.",
		"pierce":        "Bolt pierces up to 3 enemies in a line.",
	}

	var hero_id : String = def.get("id", "")
	var rarity  : String = def.get("rarity", "common")
	var rcol    : Color  = _hero_rarity_color(rarity)

	_hero_det_name.text = def.get("name", "")
	_hero_det_rarity.text = rarity.capitalize()
	_hero_det_rarity.add_theme_color_override("font_color", rcol)
	_hero_det_style.border_color = rcol.lerp(Color(0.5, 0.5, 0.6, 0.5), 0.5)

	_hero_det_preview.turret_data = def
	_hero_det_preview.queue_redraw()

	_hero_det_dmg.text  = "%.0f" % def.get("damage", 0.0)
	_hero_det_rng.text  = "%d px" % int(def.get("range", 0.0))
	_hero_det_rate.text = "%.1f / s" % def.get("fire_rate", 0.0)
	var eff_key : String = def.get("effect", "none")
	_hero_det_eff.text  = eff_key.replace("_", " ").capitalize()
	_hero_det_desc.text    = def.get("desc", "")
	_hero_det_ability.text = eff_map.get(eff_key, "No special effect.")

	var is_selected : bool = (hero_id == GameData.selected_hero_id)
	if is_selected:
		_hero_det_select.text = "✓  Already Selected"
		_hero_det_select.add_theme_stylebox_override("normal",  _btn_style(Color(0.12, 0.26, 0.14)))
		_hero_det_select.add_theme_stylebox_override("hover",   _btn_style(Color(0.12, 0.26, 0.14)))
	else:
		_hero_det_select.text = "⚔  Select Hero"
		_hero_det_select.add_theme_stylebox_override("normal",  _btn_style(Color(0.12, 0.42, 0.18)))
		_hero_det_select.add_theme_stylebox_override("hover",   _btn_style(Color(0.18, 0.58, 0.25)))

	# Disconnect all previous connections then reconnect
	for conn in _hero_det_select.pressed.get_connections():
		_hero_det_select.pressed.disconnect(conn["callable"])
	var cap_id := hero_id
	_hero_det_select.pressed.connect(_hero_on_select.bind(cap_id))

	_hero_det_panel.visible = true


func _hero_on_select(hero_id: String) -> void:
	GameData.set_selected_hero(hero_id)
	_hero_det_panel.visible = false
	_hero_refresh_selected()
	# Update all card highlights without rebuilding the screen
	for ref in _hero_card_refs:
		var sel : bool = (ref["id"] == hero_id)
		var cs  : StyleBoxFlat = ref["style"]
		cs.bg_color    = Color(0.10, 0.18, 0.10) if sel else Color(0.10, 0.10, 0.18)
		cs.border_color = Color(0.30, 0.90, 0.45) if sel else ref["rcol"]
		(ref["badge"] as Label).visible = sel
	# Re-open detail with updated button state
	var def : Dictionary = GameData.HERO_DEFS.get(hero_id, {})
	if not def.is_empty():
		_hero_show_detail(def)


func _build_towers_screen() -> void:
	# ── Outer overlay ──────────────────────────────────────────────────────────
	var overlay := Panel.new()
	var bg_s := StyleBoxFlat.new()
	bg_s.bg_color = Color(0.04, 0.04, 0.10)
	overlay.add_theme_stylebox_override("panel", bg_s)
	overlay.position     = Vector2.ZERO
	overlay.size         = Vector2(1280, 720)
	overlay.mouse_filter = MOUSE_FILTER_STOP
	overlay.visible      = false
	add_child(overlay)
	_towers_screen = overlay

	# ── Title ──────────────────────────────────────────────────────────────────
	var title := _label("🗼  Towers", _font_bold, 30, C_WHITE)
	title.position             = Vector2(0, 18)
	title.size                 = Vector2(1280, 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(title)

	# ── Scroll area (card list) ────────────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.position                = Vector2(20, 72)
	scroll.size                    = Vector2(1240, 568)
	scroll.horizontal_scroll_mode  = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode    = ScrollContainer.SCROLL_MODE_AUTO
	overlay.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	# Rarity order
	const RARITY_ORDER : Array = ["common", "rare", "epic", "legendary", "fusion"]
	const RARITY_LABELS : Dictionary = {
		"common":    "⬜  Common",
		"rare":      "🔵  Rare",
		"epic":      "🟣  Epic",
		"legendary": "🟡  Legendary",
		"fusion":    "🟢  Fusion",
	}
	const RARITY_COLS : Dictionary = {
		"common":    Color(0.75, 0.75, 0.75),
		"rare":      Color(0.25, 0.55, 1.00),
		"epic":      Color(0.72, 0.25, 0.90),
		"legendary": Color(1.00, 0.72, 0.10),
		"fusion":    Color(0.20, 1.00, 0.85),
	}

	# Full effect description map (same as in show_tower_info)
	var eff_map : Dictionary = {
		"none":          "Standard single-target shot.",
		"focused_shot":  "Consecutive hits on the same target deal +50% damage.",
		"dual_shot":     "Fires at 2 separate enemies simultaneously.",
		"chain":         "Chains to 2 nearby enemies at 50% damage.",
		"aoe":           "Hits all enemies currently in range.",
		"aoe_burst":     "Explosive shot hits up to 5 enemies in range.",
		"melee_cleave":  "Every 3rd hit strikes all enemies in range.",
		"bleed_aoe":     "Hits all in range; applies bleed (max 3 stacks, 1 dmg/s each).",
		"slow_zone":     "Every 5th shot drops an ice zone slowing enemies 55% for 3s.",
		"poison_debuff": "Poisons targets — +10% damage taken for 5s.",
		"execute_shot":  "Up to 2× damage based on enemy current HP%.",
		"knight_slam":   "Every 3rd hit is AoE and knocks enemies back.",
		"hp_strike":     "Deals base dmg + 1% of target's current HP.",
		"arcane_charge": "Every 20th hit fires a blue laser for 2× damage to all in range.",
		"lock_beam":     "Locks beam on one target; damage ramps to 1.5× over 5s.",
		"lightning":     "Chains to primary + 3 more at 80% damage.",
		"storm_chain":   "Chains to primary + 4 more at 85% damage.",
		"pierce":        "Bolt pierces up to 3 enemies in a line.",
	}

	# Group defs by rarity in order
	var by_rarity : Dictionary = {}
	for r in RARITY_ORDER:
		by_rarity[r] = []
	for tid in SummonSystem.TURRET_DEFS:
		var d : Dictionary = SummonSystem.TURRET_DEFS[tid]
		var r : String = d.get("rarity", "common")
		if by_rarity.has(r):
			by_rarity[r].append(d)

	const CARDS_PER_ROW : int = 4
	const CARD_W        : int = 294
	const CARD_H        : int = 86

	for rarity in RARITY_ORDER:
		var defs : Array = by_rarity[rarity]
		if defs.is_empty():
			continue

		# Section header
		var hdr := _label(RARITY_LABELS.get(rarity, rarity), _font_bold, 16,
						  RARITY_COLS.get(rarity, C_WHITE))
		hdr.size = Vector2(1240, 26)
		var hdr_container := Control.new()
		hdr_container.custom_minimum_size = Vector2(1240, 32)
		hdr.position = Vector2(8, 4)
		hdr_container.add_child(hdr)
		vbox.add_child(hdr_container)

		# Row flow — 4 cards per row
		var col : int = 0
		var row_box : HBoxContainer = null
		for def in defs:
			if col == 0:
				row_box = HBoxContainer.new()
				row_box.add_theme_constant_override("separation", 6)
				row_box.custom_minimum_size = Vector2(1240, CARD_H)
				vbox.add_child(row_box)
			_tw_make_card(row_box, def, CARD_W, CARD_H, RARITY_COLS.get(rarity, C_WHITE),
						  eff_map, RARITY_COLS)
			col += 1
			if col >= CARDS_PER_ROW:
				col = 0

		# Spacing after each section
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 10)
		vbox.add_child(spacer)

	# ── Back button ────────────────────────────────────────────────────────────
	var back_btn := Button.new()
	back_btn.text         = "<  Back"
	back_btn.position     = Vector2(30, 666)
	back_btn.size         = Vector2(150, 46)
	back_btn.focus_mode   = FOCUS_NONE
	back_btn.add_theme_font_override("font",           _font_bold)
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.add_theme_color_override("font_color",    C_WHITE)
	back_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.22, 0.22, 0.28)))
	back_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.30, 0.30, 0.38)))
	back_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.16, 0.16, 0.20)))
	back_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.22, 0.22, 0.28)))
	back_btn.pressed.connect(func():
		overlay.visible = false
		_game_over_screen.visible = true
	)
	overlay.add_child(back_btn)

	# ── Detail panel (right-side slide-in) ────────────────────────────────────
	_tw_build_detail_panel(overlay)


func _tw_make_card(parent: Control, def: Dictionary, cw: int, ch: int,
				   rarity_col: Color, eff_map: Dictionary,
				   rarity_cols: Dictionary) -> void:
	var card := Panel.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color              = Color(0.10, 0.10, 0.16)
	cs.corner_radius_top_left     = 8
	cs.corner_radius_top_right    = 8
	cs.corner_radius_bottom_left  = 8
	cs.corner_radius_bottom_right = 8
	cs.border_width_left   = 2
	cs.border_width_right  = 2
	cs.border_width_top    = 2
	cs.border_width_bottom = 2
	cs.border_color = Color(rarity_col.r, rarity_col.g, rarity_col.b, 0.45)
	card.add_theme_stylebox_override("panel", cs)
	card.custom_minimum_size = Vector2(cw, ch)
	card.mouse_filter        = MOUSE_FILTER_STOP
	parent.add_child(card)

	# Hover highlight
	var hs := cs.duplicate() as StyleBoxFlat
	hs.bg_color     = Color(0.16, 0.16, 0.24)
	hs.border_color = rarity_col
	var is_hover := false
	card.mouse_entered.connect(func():
		card.add_theme_stylebox_override("panel", hs)
	)
	card.mouse_exited.connect(func():
		card.add_theme_stylebox_override("panel", cs)
	)

	# Tower preview (56×56 centered vertically)
	var preview_bg := Panel.new()
	var pbs := StyleBoxFlat.new()
	pbs.bg_color                  = Color(0.06, 0.06, 0.12)
	pbs.corner_radius_top_left    = 6
	pbs.corner_radius_top_right   = 6
	pbs.corner_radius_bottom_left = 6
	pbs.corner_radius_bottom_right= 6
	preview_bg.add_theme_stylebox_override("panel", pbs)
	preview_bg.position     = Vector2(8, (ch - 60) / 2)
	preview_bg.size         = Vector2(60, 60)
	preview_bg.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(preview_bg)

	var prev := _TurretPreview.new()
	prev.turret_data = def
	prev.position    = Vector2(8 + 2, (ch - 60) / 2 + 2)
	card.add_child(prev)

	# Tower name
	var name_lbl := _label(def.get("name", ""), _font_bold, 15, C_WHITE)
	name_lbl.position     = Vector2(76, 10)
	name_lbl.size         = Vector2(cw - 84, 22)
	name_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)

	# Rarity tag
	var r     : String = def.get("rarity", "common")
	var rcol  : Color  = rarity_cols.get(r, C_WHITE)
	var rar_lbl := _label(r.capitalize(), _font_reg, 14, rcol)
	rar_lbl.position     = Vector2(76, 32)
	rar_lbl.size         = Vector2(cw - 84, 16)
	rar_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(rar_lbl)

	# Short stat line
	var stat_str := "⚔ %.0f  ·  🎯 %.0f  ·  🏹 %.1f/s" % [
		def.get("damage", 0.0), def.get("range", 0.0), def.get("fire_rate", 0.0)]
	var stat_lbl := _label(stat_str, _font_reg, 13, C_DIM)
	stat_lbl.position     = Vector2(76, 48)
	stat_lbl.size         = Vector2(cw - 84, 18)
	stat_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(stat_lbl)

	# Level badge (top-right corner)
	var tower_id  : String = def.get("id", "")
	var lvl       : int    = GameData.get_tower_level(tower_id)
	var lvl_lbl   := _label("Lv.%d" % lvl, _font_bold, 14, C_GOLD)
	lvl_lbl.position             = Vector2(cw - 52, 8)
	lvl_lbl.size                 = Vector2(46, 18)
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lvl_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	card.add_child(lvl_lbl)

	# Click → open detail
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_tw_show_detail(def, eff_map, rarity_cols)
	)


func _tw_build_detail_panel(parent: Control) -> void:
	const PW : int = 660   # wide two-column panel
	const PH : int = 520

	# ── Panel ─────────────────────────────────────────────────────────────────
	var panel := Panel.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color                   = Color(0.07, 0.06, 0.13, 0.98)
	ps.corner_radius_top_left     = 12; ps.corner_radius_top_right    = 12
	ps.corner_radius_bottom_left  = 12; ps.corner_radius_bottom_right = 12
	ps.border_width_left = 2; ps.border_width_right  = 2
	ps.border_width_top  = 2; ps.border_width_bottom = 2
	ps.border_color = Color(0.5, 0.5, 0.6, 0.5)
	ps.shadow_color = Color(0, 0, 0, 0.65); ps.shadow_size = 14
	panel.add_theme_stylebox_override("panel", ps)
	panel.position     = Vector2((1280 - PW) / 2, (720 - PH) / 2)
	panel.size         = Vector2(PW, PH)
	panel.mouse_filter = MOUSE_FILTER_STOP
	panel.visible      = false
	panel.z_index      = 20
	parent.add_child(panel)
	_tw_detail_panel = panel
	_tw_detail_style = ps

	# Dim backdrop (click outside to close)
	var dim := ColorRect.new()
	dim.color        = Color(0, 0, 0, 0.55)
	dim.position     = Vector2(-(1280 - PW) / 2, -(720 - PH) / 2)
	dim.size         = Vector2(1280, 720)
	dim.mouse_filter = MOUSE_FILTER_STOP
	dim.z_index      = -1
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			panel.visible = false
	)
	panel.add_child(dim)

	# ── Header bar ─────────────────────────────────────────────────────────────
	var hdr_bg := Panel.new()
	var hdr_style := StyleBoxFlat.new()
	hdr_style.bg_color                 = Color(0.05, 0.16, 0.28, 1.0)
	hdr_style.corner_radius_top_left   = 12; hdr_style.corner_radius_top_right  = 12
	hdr_style.corner_radius_bottom_left = 0; hdr_style.corner_radius_bottom_right = 0
	hdr_bg.add_theme_stylebox_override("panel", hdr_style)
	hdr_bg.position     = Vector2(2, 2); hdr_bg.size = Vector2(PW - 4, 50)
	hdr_bg.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(hdr_bg)

	_tw_name_lbl = _label("", _font_bold, 20, C_WHITE)
	_tw_name_lbl.position             = Vector2(0, 12)
	_tw_name_lbl.size                 = Vector2(PW - 60, 28)
	_tw_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tw_name_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(_tw_name_lbl)

	# [X] close button in header
	var close_btn := Button.new()
	close_btn.text         = "X"
	close_btn.position     = Vector2(PW - 46, 8)
	close_btn.size         = Vector2(36, 36)
	close_btn.focus_mode   = FOCUS_NONE
	close_btn.add_theme_font_override("font",           _font_bold)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.add_theme_color_override("font_color",    C_WHITE)
	close_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.55, 0.12, 0.12)))
	close_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.72, 0.18, 0.18)))
	close_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.40, 0.08, 0.08)))
	close_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.55, 0.12, 0.12)))
	close_btn.pressed.connect(func(): panel.visible = false)
	panel.add_child(close_btn)

	# ── Vertical divider between columns ───────────────────────────────────────
	const LW : int = 310   # left column width
	const RX : int = 320   # right column start x
	const RW : int = PW - RX - 10  # right column width = 330
	var col_div := ColorRect.new()
	col_div.color        = Color(1, 1, 1, 0.10)
	col_div.position     = Vector2(LW, 52); col_div.size = Vector2(2, PH - 60)
	col_div.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(col_div)

	# ── LEFT COLUMN ────────────────────────────────────────────────────────────
	# Preview box (centered in left column, below header)
	const PREV_SZ : int = 96
	var prev_bx : int = (LW - PREV_SZ) / 2   # = 107
	var prev_bg := Panel.new()
	var pbs := StyleBoxFlat.new()
	pbs.bg_color = Color(0.04, 0.04, 0.10)
	pbs.corner_radius_top_left = 8; pbs.corner_radius_top_right = 8
	pbs.corner_radius_bottom_left = 8; pbs.corner_radius_bottom_right = 8
	prev_bg.add_theme_stylebox_override("panel", pbs)
	prev_bg.position     = Vector2(prev_bx, 62); prev_bg.size = Vector2(PREV_SZ, PREV_SZ)
	prev_bg.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(prev_bg)

	# _TurretPreview internal center: draw_set_transform(Vector2(28,32),...)
	# To center in box: node.pos = (box_center_x - 28, box_center_y - 32) scaled by node scale
	# Using scale 1.5: effective center offset = (28*1.5, 32*1.5) = (42, 48)
	# node.pos = (prev_bx + PREV_SZ/2 - 42, 62 + PREV_SZ/2 - 48) = (prev_bx+6, 62)
	var prev := _TurretPreview.new()
	prev.scale    = Vector2(1.5, 1.5)
	prev.position = Vector2(prev_bx + PREV_SZ / 2 - 42, 62 + PREV_SZ / 2 - 48)
	panel.add_child(prev)
	_tw_preview_node = prev

	# Rarity label (below preview)
	_tw_rarity_lbl = _label("", _font_bold, 14, C_DIM)
	_tw_rarity_lbl.position             = Vector2(0, 166)
	_tw_rarity_lbl.size                 = Vector2(LW, 20)
	_tw_rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tw_rarity_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(_tw_rarity_lbl)

	# Thin divider
	var div1 := ColorRect.new()
	div1.color = Color(1,1,1,0.08); div1.position = Vector2(14,192); div1.size = Vector2(LW-24,1)
	div1.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(div1)

	# Stat rows  [label  |  value]
	const STAT_ROWS : Array = [
		["⚔ Damage",    200, "_tw_dmg_lbl"],
		["🎯 Range",     224, "_tw_rng_lbl"],
		["🏹 Fire Rate", 248, "_tw_rate_lbl"],
		["Effect",    272, "_tw_eff_key_lbl"],
	]
	for sr in STAT_ROWS:
		var kl := _label(sr[0], _font_reg, 14, C_DIM)
		kl.position     = Vector2(16, sr[1])
		kl.size         = Vector2(90, 20)
		kl.mouse_filter = MOUSE_FILTER_IGNORE
		panel.add_child(kl)

	_tw_dmg_lbl = _label("", _font_bold, 14, C_WHITE)
	_tw_dmg_lbl.position = Vector2(110, 200); _tw_dmg_lbl.size = Vector2(LW - 124, 20)
	_tw_dmg_lbl.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(_tw_dmg_lbl)

	_tw_rng_lbl = _label("", _font_bold, 14, C_WHITE)
	_tw_rng_lbl.position = Vector2(110, 224); _tw_rng_lbl.size = Vector2(LW - 124, 20)
	_tw_rng_lbl.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(_tw_rng_lbl)

	_tw_rate_lbl = _label("", _font_bold, 14, C_WHITE)
	_tw_rate_lbl.position = Vector2(110, 248); _tw_rate_lbl.size = Vector2(LW - 124, 20)
	_tw_rate_lbl.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(_tw_rate_lbl)

	# effect key — re-use _tw_effect_lbl for the value (short name)
	_tw_effect_lbl = _label("", _font_bold, 14, C_WHITE)
	_tw_effect_lbl.position = Vector2(110, 272); _tw_effect_lbl.size = Vector2(LW - 124, 20)
	_tw_effect_lbl.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(_tw_effect_lbl)

	var div2 := ColorRect.new()
	div2.color = Color(1,1,1,0.08); div2.position = Vector2(14,298); div2.size = Vector2(LW-24,1)
	div2.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(div2)

	# Description
	var desc_hdr := _label("Description", _font_bold, 14, C_GOLD)
	desc_hdr.position = Vector2(16, 306); desc_hdr.size = Vector2(LW - 24, 18)
	desc_hdr.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(desc_hdr)

	_tw_desc_lbl = _label("", _font_reg, 14, C_DIM)
	_tw_desc_lbl.position      = Vector2(16, 326)
	_tw_desc_lbl.size          = Vector2(LW - 24, 80)
	_tw_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_tw_desc_lbl.mouse_filter  = MOUSE_FILTER_IGNORE; panel.add_child(_tw_desc_lbl)

	# Special effect description
	var eff_hdr := _label("Special Effect", _font_bold, 14, C_GOLD)
	eff_hdr.position = Vector2(16, 410); eff_hdr.size = Vector2(LW - 24, 18)
	eff_hdr.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(eff_hdr)

	# reuse _tw_xp_bar_lbl as the special-effect detail text (inside a scroll container)
	var eff_scroll := ScrollContainer.new()
	eff_scroll.position                                    = Vector2(16, 430)
	eff_scroll.size                                        = Vector2(LW - 24, 72)
	eff_scroll.horizontal_scroll_mode                      = ScrollContainer.SCROLL_MODE_DISABLED
	eff_scroll.vertical_scroll_mode                        = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(eff_scroll)
	_tw_xp_bar_lbl = _label("", _font_reg, 14, Color(0.92, 0.88, 0.72))
	_tw_xp_bar_lbl.custom_minimum_size = Vector2(LW - 24, 0)
	_tw_xp_bar_lbl.autowrap_mode       = TextServer.AUTOWRAP_WORD
	_tw_xp_bar_lbl.mouse_filter        = MOUSE_FILTER_PASS
	_tw_xp_bar_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tw_xp_bar_lbl.size_flags_vertical   = Control.SIZE_SHRINK_BEGIN
	eff_scroll.add_child(_tw_xp_bar_lbl)

	# ── RIGHT COLUMN ───────────────────────────────────────────────────────────
	# "Turret Level" header
	var lvl_hdr := _label("Turret Level", _font_reg, 14, C_DIM)
	lvl_hdr.position = Vector2(RX, 62); lvl_hdr.size = Vector2(RW, 20)
	lvl_hdr.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(lvl_hdr)

	# Big "Lv. X"
	_tw_level_lbl = _label("Lv. 1", _font_bold, 32, C_GOLD)
	_tw_level_lbl.position     = Vector2(RX, 82); _tw_level_lbl.size = Vector2(RW, 44)
	_tw_level_lbl.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(_tw_level_lbl)

	# XP bar bg + fill
	var xp_bg := ColorRect.new()
	xp_bg.color    = Color(0.12, 0.12, 0.20)
	xp_bg.position = Vector2(RX, 130); xp_bg.size = Vector2(RW, 10)
	xp_bg.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(xp_bg)

	_tw_xp_bar_fill = ColorRect.new()
	_tw_xp_bar_fill.color    = Color(0.30, 0.70, 1.00)
	_tw_xp_bar_fill.position = Vector2(RX, 130); _tw_xp_bar_fill.size = Vector2(0, 10)
	_tw_xp_bar_fill.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(_tw_xp_bar_fill)

	var div3 := ColorRect.new()
	div3.color = Color(1,1,1,0.08); div3.position = Vector2(RX,150); div3.size = Vector2(RW,1)
	div3.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(div3)

	# "Level Buffs" header
	var buff_hdr := _label("Level Buffs", _font_bold, 14, C_WHITE)
	buff_hdr.position = Vector2(RX, 158); buff_hdr.size = Vector2(RW, 22)
	buff_hdr.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(buff_hdr)

	# Scrollable level buff list
	var scroll := ScrollContainer.new()
	scroll.position               = Vector2(RX, 184)
	scroll.size                   = Vector2(RW, PH - 194)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	scroll.add_child(vbox)

	# Level buff text for each level 1-10
	const BUFF_TEXT : Array = [
		"Unlocked",
		"+15% Damage",
		"+10% Attack Range",
		"+15% Fire Rate",
		"+20% Damage",
		"+10% Range  ·  +10% Fire Rate",
		"+25% Damage",
		"+15% Attack Range",
		"+20% Fire Rate",
		"+30% Damage  (MAX)",
	]

	_tw_lvl_rows.clear()
	for i in range(10):
		var row := Panel.new()
		var row_s := StyleBoxFlat.new()
		row_s.bg_color = Color(0.10, 0.10, 0.18)
		row_s.corner_radius_top_left = 5; row_s.corner_radius_top_right = 5
		row_s.corner_radius_bottom_left = 5; row_s.corner_radius_bottom_right = 5
		row.add_theme_stylebox_override("panel", row_s)
		row.custom_minimum_size = Vector2(RW - 8, 44)
		row.mouse_filter        = MOUSE_FILTER_IGNORE
		vbox.add_child(row)

		var lv_lbl := _label("Lv. %d" % (i + 1), _font_bold, 14, C_DIM)
		lv_lbl.position = Vector2(8, 4); lv_lbl.size = Vector2(52, 36)
		lv_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lv_lbl.mouse_filter = MOUSE_FILTER_IGNORE; row.add_child(lv_lbl)

		var buff_lbl := _label(BUFF_TEXT[i], _font_reg, 14, C_DIM)
		buff_lbl.position      = Vector2(64, 4); buff_lbl.size = Vector2(RW - 80, 36)
		buff_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		buff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		buff_lbl.mouse_filter  = MOUSE_FILTER_IGNORE; row.add_child(buff_lbl)

		_tw_lvl_rows.append({"row": row, "row_s": row_s, "lv_lbl": lv_lbl, "buff_lbl": buff_lbl})


func _tw_show_detail(def: Dictionary, eff_map: Dictionary,
					 rarity_cols: Dictionary) -> void:
	if not is_instance_valid(_tw_detail_panel):
		return

	var tower_id : String = def.get("id", "")
	var rarity   : String = def.get("rarity", "common")
	var rcol     : Color  = rarity_cols.get(rarity, C_WHITE)

	# Update panel border colour to match rarity
	if _tw_detail_style != null:
		_tw_detail_style.border_color = rcol

	# Header name + rarity suffix
	var rar_icons : Dictionary = {
		"common": "⬜", "rare": "🔵", "epic": "🟣", "legendary": "🟡", "fusion": "✨"
	}
	_tw_name_lbl.text = def.get("name", "")

	# Rarity sub-label
	_tw_rarity_lbl.text = rarity.capitalize()
	_tw_rarity_lbl.add_theme_color_override("font_color", rcol)

	# Preview
	if is_instance_valid(_tw_preview_node):
		_tw_preview_node.turret_data = def
		_tw_preview_node.queue_redraw()

	# Left column stats
	_tw_dmg_lbl.text    = "%.0f" % def.get("damage", 0.0)
	_tw_rng_lbl.text    = "%.0f px" % def.get("range", 0.0)
	_tw_rate_lbl.text   = "%.1f / s" % def.get("fire_rate", 0.0)
	# Effect short name (title-case the key)
	var eff_key : String = def.get("effect", "none")
	_tw_effect_lbl.text = eff_key.replace("_", " ").capitalize()

	# Description + Special Effect detail (including upgrade bonus if unlocked)
	_tw_desc_lbl.text = def.get("desc", "")
	var special_map : Dictionary = {
		"archer":   "★ Focused Shot+: Every hit permanently stacks +8% damage (max 10×).",
		"crossbow": "★ Triple Bolt: Fires 3 bolts instead of 2.",
		"mage":     "★ Arcane Chain: Chain now hits 5 enemies.",
		"catapult": "★ Barrage: Fires 2 shots per attack.",
		"spearman": "★ War Cry: Every 5th hit stuns enemies for 0.5s.",
		"rogue":    "★ Hemorrhage: Bleed cap raised to 6; each stack deals +12% damage.",
	}
	var eff_text : String = eff_map.get(eff_key, "No special effect.")
	if GameData.turret_has_special(tower_id) and special_map.has(tower_id):
		eff_text += "\n" + special_map[tower_id]
	_tw_xp_bar_lbl.text = eff_text

	# Right column — level & XP bar
	var lvl     : int   = GameData.get_tower_level(tower_id)
	var xp      : int   = GameData.get_tower_xp(tower_id)
	var xp_need : int   = GameData.TOWER_XP_PER_LVL
	var max_lvl : int   = GameData.TOWER_MAX_LEVEL
	const RW    : int   = 320   # must match RW in build function

	_tw_level_lbl.text = "Lv. %d" % lvl
	if lvl >= max_lvl:
		_tw_xp_bar_fill.size  = Vector2(RW, 10)
		_tw_xp_bar_fill.color = C_GOLD
	else:
		var frac : float      = clampf(float(xp) / xp_need, 0.0, 1.0)
		_tw_xp_bar_fill.size  = Vector2(int(RW * frac), 10)
		_tw_xp_bar_fill.color = Color(0.30, 0.70, 1.00)

	# Highlight unlocked level rows
	for i in range(_tw_lvl_rows.size()):
		var row_data  : Dictionary = _tw_lvl_rows[i]
		var unlocked  : bool       = (i + 1) <= lvl
		var is_cur    : bool       = (i + 1) == lvl
		var row_s     : StyleBoxFlat = row_data["row_s"]
		var lv_lbl    : Label        = row_data["lv_lbl"]
		var buff_lbl  : Label        = row_data["buff_lbl"]
		if is_cur:
			row_s.bg_color = Color(0.12, 0.22, 0.38)
			lv_lbl.add_theme_color_override("font_color",   C_GOLD)
			buff_lbl.add_theme_color_override("font_color", C_WHITE)
		elif unlocked:
			row_s.bg_color = Color(0.10, 0.14, 0.22)
			lv_lbl.add_theme_color_override("font_color",   Color(0.60, 0.75, 1.00))
			buff_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		else:
			row_s.bg_color = Color(0.08, 0.08, 0.14)
			lv_lbl.add_theme_color_override("font_color",   Color(0.35, 0.35, 0.42))
			buff_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.42))

	_tw_detail_panel.visible = true


func _refresh_all_upg_rows_postbattle() -> void:
	pass


# ══════════════════════════════════════════════════════════════════════════════
# VICTORY SCREEN
# ══════════════════════════════════════════════════════════════════════════════

func _build_victory_screen() -> void:
	var overlay := ColorRect.new()
	overlay.color        = Color(0, 0, 0, 0.85)
	overlay.position     = Vector2.ZERO
	overlay.size         = Vector2(1280, 720)
	overlay.mouse_filter = MOUSE_FILTER_STOP
	overlay.visible      = false
	add_child(overlay)
	_victory_screen = overlay

	var card := Panel.new()
	card.position = Vector2(340, 100)
	card.size     = Vector2(600, 460)
	card.add_theme_stylebox_override("panel", _rounded(Color(0.06, 0.10, 0.06, 0.98)))
	overlay.add_child(card)

	var top := Panel.new()
	top.position = Vector2(0, 0)
	top.size     = Vector2(600, 90)
	top.add_theme_stylebox_override("panel", _flat(Color(0.10, 0.42, 0.10), 10))
	card.add_child(top)

	var title := _label("⚔  Bastion Defended!", _font_bold, 34, C_WHITE)
	title.position             = Vector2(0, 0)
	title.size                 = Vector2(600, 90)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	top.add_child(title)

	var sub := _label("All 10 Stages Cleared!  🏆", _font_bold, 22, C_GOLD)
	sub.position             = Vector2(0, 102)
	sub.size                 = Vector2(600, 36)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(sub)

	var div := ColorRect.new()
	div.color    = Color(1, 1, 1, 0.08)
	div.position = Vector2(40, 150)
	div.size     = Vector2(520, 2)
	card.add_child(div)

	var btn_defs := [
		[">  Continue Farming",  Color(0.20, 0.20, 0.55)],
		["🏰  Go to Upgrades",   C_BASE_BTN             ],
		["🔄  New Run",          Color(0.45, 0.22, 0.08)],
	]
	for i in range(btn_defs.size()):
		var btn := Button.new()
		btn.text         = btn_defs[i][0]
		btn.position     = Vector2(60, 165 + i * 90)
		btn.size         = Vector2(480, 68)
		btn.pivot_offset = Vector2(240, 34)
		btn.focus_mode   = FOCUS_NONE
		btn.add_theme_font_override("font",           _font_bold)
		btn.add_theme_font_size_override("font_size", 20)
		btn.add_theme_color_override("font_color",    C_WHITE)
		var c := btn_defs[i][1] as Color
		btn.add_theme_stylebox_override("normal",  _btn_style(c))
		btn.add_theme_stylebox_override("hover",   _btn_style(c.lightened(0.10)))
		btn.add_theme_stylebox_override("pressed", _btn_style(c.darkened(0.10)))
		btn.add_theme_stylebox_override("focus",   _btn_style(c))
		var capture_i := i
		btn.pressed.connect(func(): _on_victory_btn(capture_i))
		card.add_child(btn)


func show_victory_screen() -> void:
	_victory_screen.visible = true


func _on_victory_btn(idx: int) -> void:
	_victory_screen.visible = false
	match idx:
		0:  # Continue Farming
			_refresh_all_upg_rows_postbattle()
			_upgrades_screen.visible = true
		1:  # Go to Upgrades tab (right panel is always visible)
			_switch_tab(1)
		2:  # New Run
			prestige_confirmed.emit()


# ══════════════════════════════════════════════════════════════════════════════
# RECIPE NOTIFICATION PANEL  (right side of track, x=865–1012)
# ══════════════════════════════════════════════════════════════════════════════

func _build_recipe_panel() -> void:
	# Right-side panel replaced by modal + Recipe button badge — keep node but hide it
	var panel := Control.new()
	panel.position     = Vector2(862, 68)
	panel.size         = Vector2(152, 576)
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	panel.visible      = false
	add_child(panel)
	_recipe_panel = panel

	# Scroll up button
	_recipe_scroll_up = Button.new()
	_recipe_scroll_up.text         = "^"
	_recipe_scroll_up.position     = Vector2(0, 0)
	_recipe_scroll_up.size         = Vector2(152, 28)
	_recipe_scroll_up.focus_mode   = FOCUS_NONE
	_recipe_scroll_up.visible      = false
	_recipe_scroll_up.add_theme_font_override("font",           _font_bold)
	_recipe_scroll_up.add_theme_font_size_override("font_size", 14)
	_recipe_scroll_up.add_theme_color_override("font_color",    C_WHITE)
	_recipe_scroll_up.add_theme_stylebox_override("normal",  _btn_style(Color(0.18, 0.28, 0.38, 0.9)))
	_recipe_scroll_up.add_theme_stylebox_override("hover",   _btn_style(Color(0.25, 0.38, 0.50, 0.9)))
	_recipe_scroll_up.add_theme_stylebox_override("pressed", _btn_style(Color(0.12, 0.20, 0.28, 0.9)))
	_recipe_scroll_up.add_theme_stylebox_override("focus",   _btn_style(Color(0.18, 0.28, 0.38, 0.9)))
	_recipe_scroll_up.pressed.connect(func():
		_recipe_scroll_offset = maxi(0, _recipe_scroll_offset - 1)
		_rebuild_recipe_cards()
	)
	panel.add_child(_recipe_scroll_up)

	# Scroll down button
	_recipe_scroll_dn = Button.new()
	_recipe_scroll_dn.text         = "▼"
	_recipe_scroll_dn.position     = Vector2(0, 548)
	_recipe_scroll_dn.size         = Vector2(152, 28)
	_recipe_scroll_dn.focus_mode   = FOCUS_NONE
	_recipe_scroll_dn.visible      = false
	_recipe_scroll_dn.add_theme_font_override("font",           _font_bold)
	_recipe_scroll_dn.add_theme_font_size_override("font_size", 14)
	_recipe_scroll_dn.add_theme_color_override("font_color",    C_WHITE)
	_recipe_scroll_dn.add_theme_stylebox_override("normal",  _btn_style(Color(0.18, 0.28, 0.38, 0.9)))
	_recipe_scroll_dn.add_theme_stylebox_override("hover",   _btn_style(Color(0.25, 0.38, 0.50, 0.9)))
	_recipe_scroll_dn.add_theme_stylebox_override("pressed", _btn_style(Color(0.12, 0.20, 0.28, 0.9)))
	_recipe_scroll_dn.add_theme_stylebox_override("focus",   _btn_style(Color(0.18, 0.28, 0.38, 0.9)))
	_recipe_scroll_dn.pressed.connect(func():
		_recipe_scroll_offset += 1
		_rebuild_recipe_cards()
	)
	panel.add_child(_recipe_scroll_dn)


var _all_owned_ids : Dictionary = {}

func update_recipe_notifications(available_fusions: Array, all_owned_ids: Dictionary = {}) -> void:
	_cached_fusions  = available_fusions
	_all_owned_ids   = all_owned_ids
	# Update Recipe button badge
	if is_instance_valid(_recipe_btn_badge):
		var count : int = available_fusions.size()
		var badge_panel = _recipe_btn_badge.get_meta("panel") as Panel
		if is_instance_valid(badge_panel):
			badge_panel.visible = count > 0
		_recipe_btn_badge.text = str(count)
	# Refresh modal if it's open
	if is_instance_valid(_recipe_modal) and _recipe_modal.visible:
		_refresh_recipe_modal()


func _rebuild_recipe_cards() -> void:
	# Clear old cards
	for c in _recipe_notif_cards:
		if is_instance_valid(c):
			c.queue_free()
	_recipe_notif_cards.clear()

	var total   : int  = _cached_fusions.size()
	var has_scroll_up : bool = _recipe_scroll_offset > 0
	var has_scroll_dn : bool = (_recipe_scroll_offset + 4) < total
	_recipe_scroll_up.visible = has_scroll_up
	_recipe_scroll_dn.visible = has_scroll_dn

	const CARD_H   : int = 134
	const CARD_GAP : int = 6
	var y_start    : int = 32 if has_scroll_up else 0

	for i in range(4):
		var fi : int = i + _recipe_scroll_offset
		if fi >= total:
			break
		var fusion    : Dictionary = _cached_fusions[fi]
		var recipe    : Dictionary = fusion["recipe"]
		var result_id : String     = recipe["result"]
		var result_def: Dictionary = SummonSystem.TURRET_DEFS.get(result_id, {})
		if result_def.is_empty():
			continue

		var card := Panel.new()
		card.position     = Vector2(0, y_start + i * (CARD_H + CARD_GAP))
		card.size         = Vector2(152, CARD_H)
		card.mouse_filter = MOUSE_FILTER_STOP

		var bg_col : Color = (result_def.get("color", Color(0.3, 0.6, 0.5)) as Color).darkened(0.55)
		var border_s := _rounded(bg_col)
		border_s.border_width_left   = 2
		border_s.border_width_right  = 2
		border_s.border_width_top    = 2
		border_s.border_width_bottom = 2
		border_s.border_color        = Color(0.20, 1.00, 0.85, 0.85)
		card.add_theme_stylebox_override("panel", border_s)
		_recipe_panel.add_child(card)
		_recipe_notif_cards.append(card)

		# Turret preview circle background
		var circle_bg := ColorRect.new()
		circle_bg.color        = Color(0.12, 0.18, 0.18, 0.95)
		circle_bg.position     = Vector2(10, 10)
		circle_bg.size         = Vector2(64, 64)
		circle_bg.mouse_filter = MOUSE_FILTER_IGNORE
		card.add_child(circle_bg)

		var preview := _TurretPreview.new()
		preview.turret_data = result_def
		preview.position    = Vector2(10, 10)
		card.add_child(preview)

		# Exclamation badge top-right of circle
		var badge := Panel.new()
		badge.position     = Vector2(58, 2)
		badge.size         = Vector2(22, 22)
		badge.mouse_filter = MOUSE_FILTER_IGNORE
		var badge_s := StyleBoxFlat.new()
		badge_s.bg_color                   = Color(0.95, 0.18, 0.18)
		badge_s.corner_radius_top_left     = 11
		badge_s.corner_radius_top_right    = 11
		badge_s.corner_radius_bottom_left  = 11
		badge_s.corner_radius_bottom_right = 11
		badge.add_theme_stylebox_override("panel", badge_s)
		card.add_child(badge)
		var badge_lbl := _label("!", _font_bold, 14, C_WHITE)
		badge_lbl.position             = Vector2(0, 0)
		badge_lbl.size                 = Vector2(22, 22)
		badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		badge_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
		badge.add_child(badge_lbl)

		# Name label
		var name_lbl := _label(result_def.get("name", "?"), _font_bold, 14, Color(0.20, 1.00, 0.85))
		name_lbl.position      = Vector2(4, 78)
		name_lbl.size          = Vector2(144, 20)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		name_lbl.mouse_filter  = MOUSE_FILTER_IGNORE
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(name_lbl)

		# "Craft!" button
		var C_CRAFT := Color(0.12, 0.50, 0.42)
		var craft_btn := Button.new()
		craft_btn.text         = "Craft!"
		craft_btn.position     = Vector2(6, 100)
		craft_btn.size         = Vector2(140, 28)
		craft_btn.focus_mode   = FOCUS_NONE
		craft_btn.add_theme_font_override("font",           _font_bold)
		craft_btn.add_theme_font_size_override("font_size", 14)
		craft_btn.add_theme_color_override("font_color",    C_WHITE)
		craft_btn.add_theme_stylebox_override("normal",  _btn_style(C_CRAFT))
		craft_btn.add_theme_stylebox_override("hover",   _btn_style(C_CRAFT.lightened(0.15)))
		craft_btn.add_theme_stylebox_override("pressed", _btn_style(C_CRAFT.darkened(0.15)))
		craft_btn.add_theme_stylebox_override("focus",   _btn_style(C_CRAFT))
		var capture_result_id := (_cached_fusions[fi]["recipe"]["result"]) as String
		craft_btn.pressed.connect(func():
			recipe_fusion_requested.emit(capture_result_id)
		)
		card.add_child(craft_btn)


# ══════════════════════════════════════════════════════════════════════════════
# RECIPE BOOK MODAL
# ══════════════════════════════════════════════════════════════════════════════

func _build_recipe_modal() -> void:
	_recipe_row_refs.clear()

	var overlay := ColorRect.new()
	overlay.color        = Color(0, 0, 0, 0.80)
	overlay.position     = Vector2.ZERO
	overlay.size         = Vector2(1280, 720)
	overlay.mouse_filter = MOUSE_FILTER_STOP
	overlay.visible      = false
	add_child(overlay)
	_recipe_modal = overlay

	const MW : int = 900
	const MH : int = 660
	var card := Panel.new()
	card.position = Vector2((1280 - MW) / 2, (720 - MH) / 2)
	card.size     = Vector2(MW, MH)
	card.add_theme_stylebox_override("panel", _rounded(C_PANEL))
	overlay.add_child(card)

	# Title bar
	var title_bar := Panel.new()
	title_bar.position = Vector2.ZERO
	title_bar.size     = Vector2(MW, 58)
	title_bar.add_theme_stylebox_override("panel", _flat(Color(0.08, 0.25, 0.22), 10))
	card.add_child(title_bar)

	var title_lbl := _label("📖  Recipe Book  —  Special Fusion Turrets", _font_bold, 20, Color(0.20, 1.00, 0.85))
	title_lbl.position             = Vector2(0, 0)
	title_lbl.size                 = Vector2(MW - 50, 58)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title_bar.add_child(title_lbl)

	var xbtn := Button.new()
	xbtn.text       = "X"
	xbtn.position   = Vector2(MW - 46, 11)
	xbtn.size       = Vector2(36, 36)
	xbtn.focus_mode = FOCUS_NONE
	xbtn.add_theme_font_override("font",           _font_bold)
	xbtn.add_theme_font_size_override("font_size", 16)
	xbtn.add_theme_color_override("font_color",    C_WHITE)
	xbtn.add_theme_stylebox_override("normal",  _btn_style(Color(0.55,0.12,0.12)))
	xbtn.add_theme_stylebox_override("hover",   _btn_style(Color(0.75,0.18,0.18)))
	xbtn.add_theme_stylebox_override("pressed", _btn_style(Color(0.40,0.08,0.08)))
	xbtn.add_theme_stylebox_override("focus",   _btn_style(Color(0.55,0.12,0.12)))
	xbtn.pressed.connect(func(): overlay.visible = false)
	title_bar.add_child(xbtn)

	var hdiv := ColorRect.new()
	hdiv.color = Color(1,1,1,0.08); hdiv.position = Vector2(12, 62); hdiv.size = Vector2(MW-24, 2)
	card.add_child(hdiv)

	# Scrollable area for rows
	var scroll := ScrollContainer.new()
	scroll.position                  = Vector2(0, 66)
	scroll.size                      = Vector2(MW, MH - 66)
	scroll.horizontal_scroll_mode    = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode      = ScrollContainer.SCROLL_MODE_AUTO
	scroll.get_v_scroll_bar().custom_minimum_size = Vector2(6, 0)
	card.add_child(scroll)

	const RECIPE_NAMES : Array = [
		"venom_drake", "frost_cannon", "arcane_overlord", "dragon_lich", "tempest_warden",
		"infernal_serpent", "shadow_weaver", "natures_wrath", "void_titan"
	]
	const RARITY_COLORS_MAP : Dictionary = {
		"common":    Color(0.78, 0.78, 0.78),
		"rare":      Color(0.25, 0.55, 1.00),
		"epic":      Color(0.72, 0.25, 0.90),
		"legendary": Color(1.00, 0.72, 0.10),
	}

	var inner := Control.new()
	inner.custom_minimum_size = Vector2(MW - 8, RECIPE_NAMES.size() * 116 + 8)
	scroll.add_child(inner)

	for ri in range(RECIPE_NAMES.size()):
		var result_id  : String     = RECIPE_NAMES[ri]
		var result_def : Dictionary = SummonSystem.TURRET_DEFS.get(result_id, {})
		if result_def.is_empty():
			continue

		var recipe_mats : Array = []
		for rec in SummonSystem.FUSION_RECIPES:
			if rec["result"] == result_id:
				recipe_mats = rec["materials"]
				break

		var row_y : int = 4 + ri * 116

		# Row hover bg (also used as craft-available highlight)
		var row_bg := ColorRect.new()
		row_bg.color        = Color(1,1,1, 0.03 if ri % 2 == 0 else 0.0)
		row_bg.position     = Vector2(8, row_y - 4)
		row_bg.size         = Vector2(MW - 16, 108)
		row_bg.mouse_filter = MOUSE_FILTER_IGNORE
		inner.add_child(row_bg)

		# Result preview
		var preview := _TurretPreview.new()
		preview.turret_data = result_def
		preview.position    = Vector2(16, row_y + 4)
		inner.add_child(preview)

		# "i" info — circular Panel+Label (avoids Button sizing quirks)
		var ibtn_bg := StyleBoxFlat.new()
		ibtn_bg.bg_color = Color(0.08, 0.18, 0.32, 0.90)
		ibtn_bg.corner_radius_top_left = 11; ibtn_bg.corner_radius_top_right = 11
		ibtn_bg.corner_radius_bottom_left = 11; ibtn_bg.corner_radius_bottom_right = 11
		ibtn_bg.border_width_left = 1; ibtn_bg.border_width_right = 1
		ibtn_bg.border_width_top  = 1; ibtn_bg.border_width_bottom = 1
		ibtn_bg.border_color = Color(0.20, 0.70, 1.00, 0.80)
		ibtn_bg.content_margin_left = 0; ibtn_bg.content_margin_right  = 0
		ibtn_bg.content_margin_top  = 0; ibtn_bg.content_margin_bottom = 0
		var ibtn_hov := ibtn_bg.duplicate() as StyleBoxFlat
		ibtn_hov.bg_color = Color(0.14, 0.32, 0.55, 0.95)
		var info_circle := Panel.new()
		info_circle.position            = Vector2(10, row_y - 2)
		info_circle.custom_minimum_size = Vector2(22, 22)
		info_circle.size                = Vector2(22, 22)
		info_circle.mouse_filter        = MOUSE_FILTER_STOP
		info_circle.add_theme_stylebox_override("panel", ibtn_bg)
		var ilbl := _label("i", _font_bold, 14, Color(0.20, 0.85, 1.00))
		ilbl.position             = Vector2(0, 0)
		ilbl.size                 = Vector2(22, 22)
		ilbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ilbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		ilbl.mouse_filter         = MOUSE_FILTER_IGNORE
		info_circle.add_child(ilbl)
		info_circle.mouse_entered.connect(func(): info_circle.add_theme_stylebox_override("panel", ibtn_hov))
		info_circle.mouse_exited.connect(func():  info_circle.add_theme_stylebox_override("panel", ibtn_bg))
		inner.add_child(info_circle)

		# Large centered stat panel — shown on click
		const SPW : int = 660
		const SPH : int = 480
		var stat_panel := Panel.new()
		stat_panel.visible  = false
		stat_panel.z_index  = 120
		stat_panel.position = Vector2((1280 - SPW) / 2, (720 - SPH) / 2)
		stat_panel.size     = Vector2(SPW, SPH)
		var sp_style := StyleBoxFlat.new()
		sp_style.bg_color = Color(0.07, 0.09, 0.15, 0.99)
		sp_style.corner_radius_top_left = 10; sp_style.corner_radius_top_right = 10
		sp_style.corner_radius_bottom_left = 10; sp_style.corner_radius_bottom_right = 10
		sp_style.border_width_left = 2; sp_style.border_width_right  = 2
		sp_style.border_width_top  = 2; sp_style.border_width_bottom = 2
		sp_style.border_color = Color(0.20, 0.85, 1.00, 0.60)
		stat_panel.add_theme_stylebox_override("panel", sp_style)
		overlay.add_child(stat_panel)

		# Click-outside catcher sits behind stat_panel to close it
		var sp_catcher := ColorRect.new()
		sp_catcher.color       = Color(0, 0, 0, 0.0)
		sp_catcher.position    = Vector2.ZERO
		sp_catcher.size        = Vector2(1280, 720)
		sp_catcher.z_index     = 119
		sp_catcher.visible     = false
		sp_catcher.mouse_filter = MOUSE_FILTER_STOP
		overlay.add_child(sp_catcher)
		sp_catcher.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed:
				stat_panel.visible = false
				sp_catcher.visible = false
		)

		# Header bar
		var sp_hdr := Panel.new()
		sp_hdr.position = Vector2(0, 0)
		sp_hdr.size     = Vector2(SPW, 56)
		var sp_hdr_s := StyleBoxFlat.new()
		sp_hdr_s.bg_color = Color(0.07, 0.26, 0.36, 1.0)
		sp_hdr_s.corner_radius_top_left = 10; sp_hdr_s.corner_radius_top_right = 10
		sp_hdr_s.corner_radius_bottom_left = 0; sp_hdr_s.corner_radius_bottom_right = 0
		sp_hdr.add_theme_stylebox_override("panel", sp_hdr_s)
		stat_panel.add_child(sp_hdr)

		var sp_title := _label(result_def.get("name", "?") + "  —  ✨ Fusion", _font_bold, 18, Color(0.20, 1.00, 0.85))
		sp_title.position             = Vector2(0, 0)
		sp_title.size                 = Vector2(SPW - 54, 56)
		sp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sp_title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		sp_title.mouse_filter         = MOUSE_FILTER_IGNORE
		sp_hdr.add_child(sp_title)

		var sp_close := Button.new()
		sp_close.text       = "X"
		sp_close.position   = Vector2(SPW - 46, 11)
		sp_close.size       = Vector2(34, 34)
		sp_close.focus_mode = FOCUS_NONE
		sp_close.add_theme_font_override("font",           _font_bold)
		sp_close.add_theme_font_size_override("font_size", 14)
		sp_close.add_theme_color_override("font_color",    C_WHITE)
		sp_close.add_theme_stylebox_override("normal",  _btn_style(Color(0.45,0.10,0.10)))
		sp_close.add_theme_stylebox_override("hover",   _btn_style(Color(0.65,0.16,0.16)))
		sp_close.add_theme_stylebox_override("pressed", _btn_style(Color(0.30,0.06,0.06)))
		sp_close.add_theme_stylebox_override("focus",   _btn_style(Color(0.45,0.10,0.10)))
		sp_close.pressed.connect(func():
			stat_panel.visible = false
			sp_catcher.visible = false
		)
		sp_hdr.add_child(sp_close)

		# ── Left half: turret preview (2× scale) + base stats ────────────────
		var left_w : int = SPW / 2 - 10
		var sp_pv := _TurretPreview.new()
		sp_pv.turret_data = result_def
		sp_pv.scale       = Vector2(2.0, 2.0)
		# _TurretPreview draws centered at (28,32); with scale=2, visual center = pos+(56,64)
		sp_pv.position    = Vector2(left_w / 2 - 56 + 14, 64)
		stat_panel.add_child(sp_pv)

		var eff_map3 := {"none":"—","aoe":"AoE","chain":"Chain","pierce":"Pierce",
						 "slow_zone":"Slow Zone","lightning":"Lightning","storm_chain":"Storm Chain"}
		var sp_reff : String = result_def.get("effect", "none")
		var stat_rows := [
			["Rarity",   "✨ Fusion"],
			["⚔ Damage",   "%.1f" % result_def.get("damage", 0.0)],
			["🎯 Range",    "%d" % int(result_def.get("range", 0.0))],
			["🏹 Fire Rate","%.1f/s" % result_def.get("fire_rate", 0.0)],
			["Effect",   eff_map3.get(sp_reff, sp_reff.capitalize())],
		]
		for si in range(stat_rows.size()):
			var rp  : Array = stat_rows[si]
			var sy  : int   = 200 + si * 38
			var kl  := _label(rp[0], _font_bold, 14, C_DIM)
			kl.position = Vector2(14, sy); kl.size = Vector2(100, 30)
			kl.mouse_filter = MOUSE_FILTER_IGNORE
			stat_panel.add_child(kl)
			var vl := _label(rp[1], _font_bold, 14, C_WHITE)
			vl.position = Vector2(118, sy); vl.size = Vector2(left_w - 122, 30)
			vl.mouse_filter = MOUSE_FILTER_IGNORE
			stat_panel.add_child(vl)

		var sp_desc := _label(result_def.get("desc", ""), _font_reg, 14, C_DIM)
		sp_desc.position      = Vector2(14, 396)
		sp_desc.size          = Vector2(left_w - 10, 70)
		sp_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		sp_desc.mouse_filter  = MOUSE_FILTER_IGNORE
		stat_panel.add_child(sp_desc)

		# Vertical divider
		var vdiv := ColorRect.new()
		vdiv.color    = Color(1,1,1,0.08)
		vdiv.position = Vector2(SPW / 2, 64)
		vdiv.size     = Vector2(2, SPH - 74)
		vdiv.mouse_filter = MOUSE_FILTER_IGNORE
		stat_panel.add_child(vdiv)

		# ── Right half: level + buffs ─────────────────────────────────────────
		var rx : int = SPW / 2 + 14
		var rw : int = SPW / 2 - 24

		var lv_lbl := _label("Turret Level", _font_bold, 14, C_DIM)
		lv_lbl.position = Vector2(rx, 66); lv_lbl.size = Vector2(rw, 24)
		lv_lbl.mouse_filter = MOUSE_FILTER_IGNORE
		stat_panel.add_child(lv_lbl)

		var lv_num := _label("Lv. 1", _font_bold, 34, C_GOLD)
		lv_num.position = Vector2(rx, 88); lv_num.size = Vector2(rw, 48)
		lv_num.mouse_filter = MOUSE_FILTER_IGNORE
		stat_panel.add_child(lv_num)

		var buff_div := ColorRect.new()
		buff_div.color    = Color(1,1,1,0.07)
		buff_div.position = Vector2(rx, 142)
		buff_div.size     = Vector2(rw, 1)
		buff_div.mouse_filter = MOUSE_FILTER_IGNORE
		stat_panel.add_child(buff_div)

		var buff_title := _label("Level Buffs", _font_bold, 14, Color(0.20, 1.00, 0.85))
		buff_title.position = Vector2(rx, 148); buff_title.size = Vector2(rw, 24)
		buff_title.mouse_filter = MOUSE_FILTER_IGNORE
		stat_panel.add_child(buff_title)

		var rdmg  : float = result_def.get("damage", 1.0)
		var rrng  : float = result_def.get("range",  1.0)
		var rrate2: float = result_def.get("fire_rate", 1.0)
		var buff_rows := [
			["Lv. 1", "Unlocked",                                              true],
			["Lv. 2", "+15% DMG  (%.1f → %.1f)" % [rdmg, rdmg*1.15],         false],
			["Lv. 3", "Special: " + eff_map3.get(sp_reff, sp_reff.capitalize()) + " +50% radius", false],
			["Lv. 4", "+20% Range  (%d → %d)" % [int(rrng), int(rrng*1.2)],  false],
			["Lv. 5", "+25% Fire Rate  (%.1f → %.1f/s)" % [rrate2, rrate2*1.25], false],
		]
		for bi in range(buff_rows.size()):
			var br      : Array = buff_rows[bi]
			var by      : int   = 178 + bi * 56
			var unlocked: bool  = br[2]
			var row_bg2 := ColorRect.new()
			row_bg2.color    = Color(0.20, 1.00, 0.85, 0.06) if unlocked else Color(1,1,1,0.02)
			row_bg2.position = Vector2(rx - 4, by - 2)
			row_bg2.size     = Vector2(rw + 4, 50)
			row_bg2.mouse_filter = MOUSE_FILTER_IGNORE
			stat_panel.add_child(row_bg2)
			var lv_tag := _label(br[0], _font_bold, 14, C_GOLD if unlocked else C_DIM)
			lv_tag.position = Vector2(rx, by); lv_tag.size = Vector2(50, 22)
			lv_tag.mouse_filter = MOUSE_FILTER_IGNORE
			stat_panel.add_child(lv_tag)
			var buff_lbl := _label(br[1], _font_reg, 14, C_WHITE if unlocked else C_DIM)
			buff_lbl.position      = Vector2(rx, by + 22)
			buff_lbl.size          = Vector2(rw, 24)
			buff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			buff_lbl.mouse_filter  = MOUSE_FILTER_IGNORE
			stat_panel.add_child(buff_lbl)

		info_circle.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				stat_panel.visible = not stat_panel.visible
				sp_catcher.visible = stat_panel.visible
		)
		overlay.connect("visibility_changed", func():
			stat_panel.visible = false
			sp_catcher.visible = false
		)

		# Result name — shortened to leave room for inline craft button
		var res_name := _label(result_def.get("name", "?"), _font_bold, 14, Color(0.20, 1.00, 0.85))
		res_name.position = Vector2(82, row_y + 8)
		res_name.size     = Vector2(96, 22)
		inner.add_child(res_name)

		# Compact craft button inline with name — hidden until craftable
		var craft_s := StyleBoxFlat.new()
		craft_s.bg_color                   = Color(0.14, 0.14, 0.10)
		craft_s.corner_radius_top_left     = 5
		craft_s.corner_radius_top_right    = 5
		craft_s.corner_radius_bottom_left  = 5
		craft_s.corner_radius_bottom_right = 5
		craft_s.border_width_left   = 2; craft_s.border_width_right  = 2
		craft_s.border_width_top    = 2; craft_s.border_width_bottom = 2
		craft_s.border_color        = C_GOLD
		var craft_h := craft_s.duplicate() as StyleBoxFlat
		craft_h.bg_color = Color(0.26, 0.24, 0.10)
		var craft_p := craft_s.duplicate() as StyleBoxFlat
		craft_p.bg_color = Color(0.08, 0.08, 0.06)
		var craft_btn := Button.new()
		craft_btn.text         = "Craft!"
		craft_btn.position     = Vector2(180, row_y + 18)
		craft_btn.size         = Vector2(74, 22)
		craft_btn.focus_mode   = FOCUS_NONE
		craft_btn.visible      = false
		craft_btn.add_theme_font_override("font",           _font_bold)
		craft_btn.add_theme_font_size_override("font_size", 14)
		craft_btn.add_theme_color_override("font_color",    C_GOLD)
		craft_btn.add_theme_stylebox_override("normal",  craft_s)
		craft_btn.add_theme_stylebox_override("hover",   craft_h)
		craft_btn.add_theme_stylebox_override("pressed", craft_p)
		craft_btn.add_theme_stylebox_override("focus",   craft_s)
		var cap_result_id := result_id
		craft_btn.pressed.connect(func():
			overlay.visible = false
			recipe_fusion_requested.emit(cap_result_id)
		)
		inner.add_child(craft_btn)

		var res_rar := _label("✨ Fusion", _font_bold, 14, Color(0.20, 1.00, 0.85))
		res_rar.position = Vector2(82, row_y + 32)
		res_rar.size     = Vector2(170, 18)
		inner.add_child(res_rar)


		# Hidden badge label (kept for _recipe_row_refs compat but invisible)
		var badge_lbl := _label("", _font_bold, 14, C_GOLD)
		badge_lbl.visible = false
		inner.add_child(badge_lbl)

		# Arrow
		var arrow := _label(">>", _font_bold, 22, C_GOLD)
		arrow.position = Vector2(260, row_y + 36)
		arrow.size     = Vector2(26, 36)
		arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(arrow)

		# Material cards
		var mat_refs : Array = []
		for mi in range(recipe_mats.size()):
			var mat_id  : String     = recipe_mats[mi]
			var mat_def : Dictionary = SummonSystem.TURRET_DEFS.get(mat_id, {})
			if mat_def.is_empty():
				continue

			var mat_rarity : String = mat_def.get("rarity", "common")
			var mat_col    : Color  = RARITY_COLORS_MAP.get(mat_rarity, C_WHITE)
			const RARITY_BG : Dictionary = {
				"common":    Color(0.26, 0.26, 0.28),
				"rare":      Color(0.10, 0.18, 0.42),
				"epic":      Color(0.22, 0.08, 0.36),
				"legendary": Color(0.38, 0.24, 0.04),
			}
			var mat_bg_col : Color = RARITY_BG.get(mat_rarity, Color(0.22, 0.22, 0.24))

			var mat_card := Panel.new()
			mat_card.position     = Vector2(292 + mi * 118, row_y + 4)
			mat_card.size         = Vector2(110, 100)
			mat_card.mouse_filter = MOUSE_FILTER_IGNORE
			var mat_style := _rounded(mat_bg_col)
			mat_style.border_width_left   = 2
			mat_style.border_width_right  = 2
			mat_style.border_width_top    = 2
			mat_style.border_width_bottom = 2
			mat_style.border_color        = Color(0.35, 0.35, 0.35, 0.5)
			mat_card.add_theme_stylebox_override("panel", mat_style)
			inner.add_child(mat_card)

			var mat_pv := _TurretPreview.new()
			mat_pv.turret_data = mat_def
			mat_pv.position    = Vector2(27, 2)
			mat_card.add_child(mat_pv)

			var mat_rar_lbl := _label(mat_rarity.capitalize(), _font_bold, 14, mat_col)
			mat_rar_lbl.position             = Vector2(0, 62)
			mat_rar_lbl.size                 = Vector2(110, 16)
			mat_rar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mat_rar_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
			mat_card.add_child(mat_rar_lbl)

			var mat_name_lbl := _label(mat_def.get("name", "?"), _font_bold, 14, C_WHITE)
			mat_name_lbl.position             = Vector2(0, 78)
			mat_name_lbl.size                 = Vector2(110, 20)
			mat_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mat_name_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD
			mat_name_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
			mat_card.add_child(mat_name_lbl)

			# Plus between cards
			if mi < recipe_mats.size() - 1:
				var plus := _label("+", _font_bold, 16, C_DIM)
				plus.position = Vector2(292 + mi * 118 + 112, row_y + 40)
				plus.size     = Vector2(14, 24)
				plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				inner.add_child(plus)

			mat_refs.append({"panel": mat_card, "id": mat_id, "style": mat_style,
							  "base_col": mat_bg_col, "rarity_col": mat_col})

		_recipe_row_refs.append({
			"result_id":  result_id,
			"badge_lbl":  badge_lbl,
			"craft_btn":  craft_btn,
			"row_bg":     row_bg,
			"mat_refs":   mat_refs,
		})

	overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if not card.get_rect().has_point(card.get_parent().get_local_mouse_position()):
				overlay.visible = false
	)


func _refresh_recipe_modal() -> void:
	if _recipe_row_refs.is_empty():
		return

	var craftable_ids : Dictionary = {}
	for fusion in _cached_fusions:
		craftable_ids[fusion["recipe"]["result"]] = true

	for row in _recipe_row_refs:
		var result_id    : String     = row["result_id"]
		var is_craftable : bool       = craftable_ids.has(result_id)
		var badge_lbl    : Label      = row["badge_lbl"]
		var craft_btn    : Button     = row["craft_btn"]
		var row_bg       : ColorRect  = row["row_bg"]

		badge_lbl.visible = false
		craft_btn.visible = is_craftable

		# Yellow highlight on the row bg when craftable
		row_bg.color = Color(1.00, 0.85, 0.10, 0.07) if is_craftable else Color(1,1,1,0.03)

		# Update material card borders: yellow if owned, gray/dark if not
		for mat_ref in row["mat_refs"]:
			var mat_id    : String        = mat_ref["id"]
			var mat_style : StyleBoxFlat  = mat_ref["style"]
			var base_col  : Color         = mat_ref["base_col"]
			var panel     : Panel         = mat_ref["panel"]
			var owned     : bool          = _all_owned_ids.has(mat_id)
			if owned:
				mat_style.bg_color     = base_col.lightened(0.10)
				mat_style.border_color = C_GOLD
				mat_style.border_width_left   = 2
				mat_style.border_width_right  = 2
				mat_style.border_width_top    = 2
				mat_style.border_width_bottom = 2
				panel.modulate = Color(1, 1, 1, 1)
			else:
				mat_style.bg_color     = base_col.darkened(0.45)
				mat_style.border_color = Color(0.28, 0.28, 0.28, 0.5)
				mat_style.border_width_left   = 2
				mat_style.border_width_right  = 2
				mat_style.border_width_top    = 2
				mat_style.border_width_bottom = 2
				panel.modulate = Color(0.55, 0.55, 0.55, 1)


# ── Button helpers ────────────────────────────────────────────────────────────

func _tween_scale(node: Control, target: Vector2, dur: float) -> void:
	if _btn_tweens.has(node) and is_instance_valid(_btn_tweens[node]):
		_btn_tweens[node].kill()
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", target, dur)
	_btn_tweens[node] = tw


# ══════════════════════════════════════════════════════════════════════════════
# SETTINGS GEAR
# ══════════════════════════════════════════════════════════════════════════════

func _build_settings_gear() -> void:
	# Gear button — bottom-right corner, always on top
	_gear_btn  = Button.new()
	var gear_btn : Button = _gear_btn
	gear_btn.text       = "⚙"
	gear_btn.position   = Vector2(1280 - 52, 720 - 52)
	gear_btn.size       = Vector2(42, 42)
	gear_btn.z_index    = 90
	gear_btn.focus_mode = FOCUS_NONE
	gear_btn.add_theme_font_override("font",           _font_bold)
	gear_btn.add_theme_font_size_override("font_size", 20)
	gear_btn.add_theme_color_override("font_color",    Color(0.80, 0.80, 0.85))
	var gs := StyleBoxFlat.new()
	gs.bg_color = Color(0.12, 0.12, 0.16, 0.88)
	gs.corner_radius_top_left = 8; gs.corner_radius_top_right = 8
	gs.corner_radius_bottom_left = 8; gs.corner_radius_bottom_right = 8
	gs.border_width_left = 1; gs.border_width_right  = 1
	gs.border_width_top  = 1; gs.border_width_bottom = 1
	gs.border_color = Color(0.40, 0.40, 0.50, 0.50)
	var gs_h := gs.duplicate() as StyleBoxFlat; gs_h.bg_color = Color(0.20, 0.20, 0.28, 0.95)
	gear_btn.add_theme_stylebox_override("normal",  gs)
	gear_btn.add_theme_stylebox_override("hover",   gs_h)
	gear_btn.add_theme_stylebox_override("pressed", gs)
	gear_btn.add_theme_stylebox_override("focus",   gs)
	add_child(gear_btn)

	# Transparent click-catcher to dismiss gear menu on outside click
	var catcher := ColorRect.new()
	catcher.color        = Color(0, 0, 0, 0)
	catcher.position     = Vector2.ZERO
	catcher.size         = Vector2(1280, 720)
	catcher.z_index      = 90
	catcher.mouse_filter = MOUSE_FILTER_PASS
	catcher.visible      = false
	add_child(catcher)

	# Settings popup menu
	_gear_menu = Panel.new()
	var menu : Panel = _gear_menu
	menu.visible  = false
	menu.z_index  = 91
	menu.position = Vector2(1280 - 200, 720 - 110)
	menu.size     = Vector2(188, 96)
	var ms := StyleBoxFlat.new()
	ms.bg_color = Color(0.10, 0.10, 0.16, 0.97)
	ms.corner_radius_top_left = 8; ms.corner_radius_top_right = 8
	ms.corner_radius_bottom_left = 8; ms.corner_radius_bottom_right = 8
	ms.border_width_left = 1; ms.border_width_right  = 1
	ms.border_width_top  = 1; ms.border_width_bottom = 1
	ms.border_color = Color(0.40, 0.40, 0.55, 0.60)
	menu.add_theme_stylebox_override("panel", ms)
	add_child(menu)

	var menu_title := _label("Settings", _font_bold, 14, C_DIM)
	menu_title.position             = Vector2(0, 6)
	menu_title.size                 = Vector2(188, 20)
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title.mouse_filter         = MOUSE_FILTER_IGNORE
	menu.add_child(menu_title)

	var hdiv2 := ColorRect.new()
	hdiv2.color    = Color(1,1,1,0.07)
	hdiv2.position = Vector2(8, 28); hdiv2.size = Vector2(172, 1)
	hdiv2.mouse_filter = MOUSE_FILTER_IGNORE
	menu.add_child(hdiv2)

	var leave_btn := Button.new()
	leave_btn.text         = "🚪  Leave Game"
	leave_btn.position     = Vector2(8, 36)
	leave_btn.size         = Vector2(172, 50)
	leave_btn.focus_mode   = FOCUS_NONE
	leave_btn.add_theme_font_override("font",           _font_bold)
	leave_btn.add_theme_font_size_override("font_size", 15)
	leave_btn.add_theme_color_override("font_color",    C_WHITE)
	leave_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.45, 0.10, 0.10)))
	leave_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.62, 0.15, 0.15)))
	leave_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.32, 0.07, 0.07)))
	leave_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.45, 0.10, 0.10)))
	leave_btn.pressed.connect(func():
		menu.visible = false
		show_main_menu()
	)
	menu.add_child(leave_btn)

	catcher.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			menu.visible = false
			catcher.visible = false
	)
	menu.visibility_changed.connect(func(): catcher.visible = menu.visible)

	gear_btn.visible = true   # game starts in active gameplay; signals hide it when overlays open
	gear_btn.pressed.connect(func(): menu.visible = not menu.visible)

	# Helper: show gear only when no full-screen overlay is open
	var _update_gear_vis := func():
		var any_overlay : bool = (
			_game_over_screen.visible or
			_upgrades_screen.visible  or
			_victory_screen.visible
		)
		gear_btn.visible = not any_overlay
		if any_overlay: menu.visible = false

	_game_over_screen.visibility_changed.connect(_update_gear_vis)
	_upgrades_screen.visibility_changed.connect(_update_gear_vis)
	_victory_screen.visibility_changed.connect(_update_gear_vis)


# ══════════════════════════════════════════════════════════════════════════════
# STYLE HELPERS
# ══════════════════════════════════════════════════════════════════════════════

func _flat(bg: Color, corner: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color                   = bg
	s.corner_radius_top_left     = corner
	s.corner_radius_top_right    = corner
	s.corner_radius_bottom_left  = corner
	s.corner_radius_bottom_right = corner
	return s


func _rounded(bg: Color) -> StyleBoxFlat:
	return _flat(bg, RADIUS)


func _make_arrow_icon() -> Control:
	var c := Control.new()
	c.size = Vector2(16, 16)
	c.draw.connect(func():
		var ac := Color(0.28, 1.00, 0.42)
		var bp := Vector2(8, 8)
		c.draw_circle(bp, 8.0, Color(0.06, 0.06, 0.06, 0.92))
		c.draw_arc(bp, 8.0, 0, TAU, 32, Color(0.18, 0.88, 0.28), 1.5)
		c.draw_colored_polygon(PackedVector2Array([
			bp + Vector2(0.0, -4.0),
			bp + Vector2(-3.0, 0.5),
			bp + Vector2(3.0,  0.5),
		]), ac)
		c.draw_rect(Rect2(bp.x - 1.0, bp.y + 0.5, 2.0, 3.0), ac)
	)
	return c


func _btn_style(bg: Color) -> StyleBoxFlat:
	var s := _rounded(bg)
	s.content_margin_left   = 14
	s.content_margin_right  = 14
	s.content_margin_top    = 8
	s.content_margin_bottom = 8
	# Top border brighter (highlight edge), bottom slightly thicker (shadow edge)
	s.border_width_left     = 1
	s.border_width_right    = 1
	s.border_width_top      = 2
	s.border_width_bottom   = 2
	s.border_color          = Color(1.0, 1.0, 1.0, 0.30)
	# Drop shadow to give a raised / 3D feel
	s.shadow_color          = Color(0.0, 0.0, 0.0, 0.50)
	s.shadow_size           = 3
	return s


func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font",           font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color",    color)
	return l


# ══════════════════════════════════════════════════════════════════════════════
# INNER CLASS — draws the turret icon inside cards
# ══════════════════════════════════════════════════════════════════════════════

class _TurretPreview extends Node2D:
	var turret_data : Dictionary = {}

	func _draw() -> void:
		if turret_data.is_empty():
			return
		# Center in preview box; scale per-turret (only the ones that looked too small get bumped up)
		var cx  : float = 28.0
		var cy  : float = 32.0
		var idx : int   = turret_data.get("idx", -1)
		var sc  : float
		match idx:
			6, 7, 8, 10, 12:     sc = 0.67   # frost spire, poison, sniper, infernal core, arcane cannon
			17, 18, 19, 20, 21, 22, 23, 24, 25:  sc = 0.60   # fusion turrets
			_:                   sc = 0.56   # all others stay at original size
		draw_set_transform(Vector2(cx, cy), 0.0, Vector2(sc, sc))
		var tc := turret_data.get("color", Color(0.5, 0.5, 0.5)) as Color
		match turret_data.get("idx", -1):
			0:  _pv_archer()
			1:  _pv_crossbow()
			2:  _pv_cannon()
			3:  _pv_mage()
			4:  _pv_knight(tc)
			5:  _pv_flame()
			6:  _pv_frost()
			7:  _pv_poison()
			8:  _pv_sniper()
			9:  _pv_tesla()
			10: _pv_infernal()
			11: _pv_ballista()
			12: _pv_arcane()
			13: _pv_sun_dragon()
			14: _pv_storm_lord()
			15: _pv_chrono()
			16: _pv_world_tree()
			17: _pv_venom_drake()
			18: _pv_frost_cannon()
			19: _pv_arcane_overlord()
			20: _pv_dragon_lich()
			21: _pv_tempest_warden()
			22: _pv_infernal_serpent()
			23: _pv_shadow_weaver()
			24: _pv_natures_wrath()
			25: _pv_void_titan()
			50: _pv_hero_paladin(tc)
			51: _pv_hero_rogue(tc)
			52: _pv_hero_warlock(tc)
			_:  _pv_generic(tc)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# ── All draw functions use Tower.gd coordinate space (0,0 = character center, y down) ──

	func _pv_archer() -> void:
		var skin  := Color(0.94,0.78,0.60); var tunic := Color(0.22,0.52,0.18)
		var pants := Color(0.36,0.22,0.10); var bow_c := Color(0.52,0.33,0.10)
		var str_c := Color(0.88,0.84,0.72)
		draw_rect(Rect2(-9,4,8,14),pants); draw_rect(Rect2(1,4,8,14),pants)
		draw_colored_polygon(PackedVector2Array([Vector2(-10,-8),Vector2(10,-8),Vector2(12,8),Vector2(-12,8)]),tunic)
		draw_circle(Vector2(0,-17),8,skin)
		draw_circle(Vector2(0,-24),7,Color(0.28,0.16,0.06))
		draw_colored_polygon(PackedVector2Array([Vector2(-7,-21),Vector2(7,-21),Vector2(4,-29),Vector2(-3,-29)]),tunic)
		draw_arc(Vector2(18,-5),13,-PI*0.55,PI*0.55,12,bow_c,3.5)
		draw_line(Vector2(18,-18),Vector2(12,-5),str_c,1.2)
		draw_line(Vector2(12,-5),Vector2(18,8),str_c,1.2)

	func _pv_crossbow() -> void:
		var skin   := Color(0.94,0.78,0.60); var jacket := Color(0.20,0.35,0.72)
		var pants  := Color(0.14,0.20,0.48); var steel  := Color(0.62,0.65,0.72)
		var wood_c := Color(0.52,0.33,0.12)
		draw_rect(Rect2(-9,4,8,14),pants); draw_rect(Rect2(1,4,8,14),pants)
		draw_colored_polygon(PackedVector2Array([Vector2(-10,-8),Vector2(10,-8),Vector2(11,8),Vector2(-11,8)]),jacket)
		draw_circle(Vector2(0,-17),8,skin)
		draw_circle(Vector2(0,-24),7,Color(0.80,0.65,0.20))
		draw_rect(Rect2(-8,-21,16,3),jacket.darkened(0.15))
		draw_rect(Rect2(-14,-6,20,5),wood_c)
		draw_rect(Rect2(4,-15,5,21),steel)
		draw_rect(Rect2(8,-8,16,4),steel.darkened(0.1))

	func _pv_cannon() -> void:
		var iron   := Color(0.36,0.36,0.42); var iron_d := Color(0.20,0.20,0.25)
		var iron_l := Color(0.55,0.58,0.64); var wood   := Color(0.50,0.32,0.12)
		var wood_d := Color(0.36,0.22,0.08)
		draw_circle(Vector2(-17,16),10,wood_d); draw_circle(Vector2(-17,16),8,wood)
		draw_circle(Vector2(17,16),10,wood_d);  draw_circle(Vector2(17,16),8,wood)
		draw_line(Vector2(-17,16),Vector2(17,16),iron_d,3.5)
		draw_colored_polygon(PackedVector2Array([Vector2(-16,0),Vector2(16,0),Vector2(18,14),Vector2(-18,14)]),wood)
		draw_rect(Rect2(-8,-8,16,10),iron)
		var bs := Vector2(-2,-4); var be := Vector2(16,-22)
		draw_line(bs,be,iron_d,19.0); draw_line(bs,be,iron,16.0); draw_line(bs,be,iron_l,5.0)
		draw_circle(be,10.0,iron); draw_circle(be,5.0,iron_d)

	func _pv_mage() -> void:
		var robe  := Color(0.52,0.18,0.72); var robe_d := Color(0.34,0.10,0.50)
		var star_c := Color(0.88,0.82,0.30); var skin := Color(0.94,0.78,0.60)
		var orb_c := Color(0.20,0.60,0.90); var staff := Color(0.55,0.35,0.12)
		draw_colored_polygon(PackedVector2Array([Vector2(-8,-10),Vector2(8,-10),Vector2(13,22),Vector2(-13,22)]),robe)
		draw_colored_polygon(PackedVector2Array([Vector2(4,-10),Vector2(8,-10),Vector2(13,22),Vector2(8,22)]),robe_d)
		draw_line(Vector2(-13,18),Vector2(13,18),star_c,1.5)
		draw_circle(Vector2(0,-18),7,skin)
		draw_rect(Rect2(-11,-25,22,3),robe)
		draw_colored_polygon(PackedVector2Array([Vector2(-8,-25),Vector2(8,-25),Vector2(2,-38),Vector2(-2,-38)]),robe)
		draw_circle(Vector2(-16,-12),5,orb_c)
		draw_line(Vector2(-16,-5),Vector2(-16,20),staff,4.0)

	func _pv_knight(tc: Color) -> void:
		var crimson := Color(0.78,0.14,0.14); var gold := Color(0.90,0.78,0.22)
		draw_colored_polygon(PackedVector2Array([Vector2(-9,-5),Vector2(9,-5),Vector2(13,22),Vector2(-13,22)]),crimson)
		draw_colored_polygon(PackedVector2Array([Vector2(-12,-8),Vector2(12,-8),Vector2(10,6),Vector2(-10,6)]),tc)
		draw_line(Vector2(-12,-8),Vector2(12,-8),gold,2.5)
		draw_circle(Vector2(-15,-6),8,tc); draw_circle(Vector2(15,-6),8,tc)
		draw_circle(Vector2(0,-18),10,tc)
		draw_rect(Rect2(-9,-22,18,6),tc.darkened(0.3))
		draw_rect(Rect2(-2,-30,4,13),tc)
		draw_rect(Rect2(-3,-36,6,10),crimson)
		draw_colored_polygon(PackedVector2Array([Vector2(-26,-12),Vector2(-12,-12),Vector2(-12,10),Vector2(-19,20),Vector2(-26,10)]),tc.lightened(0.2))
		draw_line(Vector2(-19,-8),Vector2(-19,17),gold,2.0)
		draw_rect(Rect2(15,-32,5,36),tc.lightened(0.25))
		draw_rect(Rect2(8,-2,20,5),gold)

	func _pv_flame() -> void:
		var stone := Color(0.40,0.35,0.30); var hot := Color(1.00,0.38,0.08)
		var yel   := Color(1.00,0.85,0.20)
		draw_rect(Rect2(-14,8,28,16),stone); draw_rect(Rect2(-16,6,32,6),stone.lightened(0.15))
		draw_line(Vector2(-10,8),Vector2(-12,24),stone,4.0)
		draw_line(Vector2(10,8),Vector2(12,24),stone,4.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-10,2),Vector2(10,2),Vector2(12,8),Vector2(-12,8)]),stone.darkened(0.2))
		var fh := 20.0
		draw_colored_polygon(PackedVector2Array([Vector2(-10,2),Vector2(10,2),Vector2(5,2-fh),Vector2(-5,2-fh)]),hot)
		draw_colored_polygon(PackedVector2Array([Vector2(-6,2),Vector2(6,2),Vector2(2,2-fh*0.7),Vector2(-2,2-fh*0.7)]),yel)
		draw_circle(Vector2(0,2),4,Color(1.0,1.0,0.8,0.9))

	func _pv_frost() -> void:
		var ice  := Color(0.50,0.85,1.00); var ice2 := Color(0.75,0.95,1.00)
		var base := Color(0.35,0.55,0.70)
		draw_rect(Rect2(-10,10,20,14),base); draw_rect(Rect2(-12,8,24,6),base.lightened(0.1))
		draw_colored_polygon(PackedVector2Array([Vector2(-6,8),Vector2(6,8),Vector2(3,-10),Vector2(-3,-10)]),ice)
		draw_colored_polygon(PackedVector2Array([Vector2(-1,-10),Vector2(1,-10),Vector2(0,-22)]),ice2)
		draw_colored_polygon(PackedVector2Array([Vector2(-10,4),Vector2(-5,4),Vector2(-4,-6),Vector2(-8,-6)]),ice.darkened(0.1))
		draw_colored_polygon(PackedVector2Array([Vector2(5,4),Vector2(10,4),Vector2(8,-6),Vector2(4,-6)]),ice.darkened(0.1))
		draw_arc(Vector2(0,-12),14,-PI*0.4,PI*0.4,12,Color(0.8,0.95,1.0,0.5),1.5)

	func _pv_poison() -> void:
		var stone := Color(0.35,0.40,0.32); var grn  := Color(0.30,0.80,0.20)
		var grn2  := Color(0.55,0.95,0.30)
		draw_colored_polygon(PackedVector2Array([Vector2(-9,-12),Vector2(9,-12),Vector2(10,22),Vector2(-10,22)]),stone)
		draw_colored_polygon(PackedVector2Array([Vector2(4,-12),Vector2(9,-12),Vector2(10,22),Vector2(6,22)]),stone.darkened(0.2))
		for i in range(3):
			draw_rect(Rect2(-8+i*6,-18,4,8),stone.lightened(0.1))
		draw_rect(Rect2(-3,-4,6,10),grn)
		draw_rect(Rect2(-2,-8,4,6),grn2)
		draw_circle(Vector2(0,-9),3,grn2)

	func _pv_sniper() -> void:
		var wood  := Color(0.45,0.32,0.18); var skin  := Color(0.94,0.78,0.60)
		var steel := Color(0.60,0.60,0.65); var cloak := Color(0.52,0.48,0.38)
		draw_line(Vector2(-12,22),Vector2(-12,-2),wood,4.0)
		draw_line(Vector2(12,22),Vector2(12,-2),wood,4.0)
		draw_line(Vector2(-12,10),Vector2(12,10),wood,3.5)
		draw_line(Vector2(-12,2),Vector2(12,2),wood,3.5)
		draw_rect(Rect2(-14,-2,28,6),wood.lightened(0.1))
		draw_colored_polygon(PackedVector2Array([Vector2(-7,-2),Vector2(7,-2),Vector2(8,8),Vector2(-8,8)]),cloak)
		draw_circle(Vector2(0,-8),6,skin)
		draw_circle(Vector2(0,-14),5,Color(0.28,0.18,0.08))
		draw_line(Vector2(-4,-4),Vector2(22,-4),steel,4.0)
		draw_circle(Vector2(12,-4),3.5,steel.darkened(0.3))

	func _pv_tesla() -> void:
		var metal := Color(0.40,0.45,0.55); var coil := Color(0.55,0.60,0.70)
		var elec  := Color(0.40,0.80,1.00)
		draw_rect(Rect2(-8,0,16,22),metal); draw_rect(Rect2(-10,-2,20,6),metal.lightened(0.15))
		for i in range(4):
			draw_arc(Vector2(0,-4+i*5),10,0,TAU,16,coil,2.5)
		draw_line(Vector2(0,-4),Vector2(0,-20),coil.lightened(0.2),4.0)
		draw_circle(Vector2(0,-22),8,elec)
		draw_circle(Vector2(-2,-24),2.5,Color(1,1,1,0.6))
		draw_circle(Vector2(0,-22),12,Color(elec.r,elec.g,elec.b,0.25))

	func _pv_infernal() -> void:
		var dark := Color(0.20,0.08,0.05); var lava := Color(1.00,0.25,0.05)
		var yel  := Color(1.00,0.75,0.10)
		draw_rect(Rect2(-13,4,26,20),dark); draw_rect(Rect2(-10,1,20,8),dark.lightened(0.1))
		draw_line(Vector2(-8,8),Vector2(-2,14),lava,1.5)
		draw_line(Vector2(3,6),Vector2(8,16),lava,1.5)
		draw_circle(Vector2(0,-4),8.5,dark.lightened(0.05))
		draw_circle(Vector2(0,-4),6.5,lava)
		draw_circle(Vector2(0,-4),3.5,yel)
		draw_circle(Vector2(-2,-6),2.5,Color(1,1,0.8,0.8))

	func _pv_ballista() -> void:
		var wood  := Color(0.45,0.30,0.12); var wood2 := Color(0.32,0.20,0.08)
		var steel := Color(0.55,0.55,0.62); var bolt  := Color(0.65,0.52,0.22)
		draw_circle(Vector2(-14,18),9,wood2); draw_circle(Vector2(-14,18),7,wood)
		draw_circle(Vector2(14,18),9,wood2);  draw_circle(Vector2(14,18),7,wood)
		draw_line(Vector2(-14,18),Vector2(14,18),wood2,4.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-14,2),Vector2(14,2),Vector2(16,16),Vector2(-16,16)]),wood)
		draw_line(Vector2(-6,2),Vector2(-16,-8),wood,5.0)
		draw_line(Vector2(6,2),Vector2(16,-8),wood,5.0)
		draw_line(Vector2(-16,-8),Vector2(0,-2),Color(0.85,0.82,0.70),1.5)
		draw_line(Vector2(16,-8),Vector2(0,-2),Color(0.85,0.82,0.70),1.5)
		draw_rect(Rect2(-2,-18,4,22),steel)
		draw_line(Vector2(0,-18),Vector2(0,-1),bolt,3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(0,-18),Vector2(-4,-12),Vector2(4,-12)]),bolt)

	func _pv_arcane() -> void:
		var orb_c := Color(0.80,0.30,0.90); var gold := Color(0.90,0.78,0.22)
		var ring  := Color(0.60,0.20,0.72)
		for i in range(3):
			var ang := i * TAU / 3.0
			draw_arc(Vector2(cos(ang)*4,sin(ang)*2+(-2)),10-i*2,-PI*0.6+ang,PI*0.6+ang,10,Color(ring.r,ring.g,ring.b,0.6),2.0)
		var os := 10.0
		draw_circle(Vector2(0,-2),os,orb_c)
		draw_circle(Vector2(0,-2),os-3,Color(orb_c.r+0.2,orb_c.g+0.1,orb_c.b+0.1,1.0))
		draw_circle(Vector2(-2,-4),3,Color(1,1,1,0.5))
		draw_arc(Vector2(0,-2),os,0,TAU,20,Color(gold.r,gold.g,gold.b,0.7),1.5)
		for i in range(4):
			draw_circle(Vector2(0,10+i*5),1.5,Color(ring.r,ring.g,ring.b,0.5))

	func _pv_sun_dragon() -> void:
		var gold    := Color(1.00,0.72,0.05); var scale_c := Color(0.72,0.45,0.05)
		var eye_c   := Color(1.00,0.95,0.30)
		draw_colored_polygon(PackedVector2Array([Vector2(-14,6),Vector2(14,6),Vector2(12,22),Vector2(-12,22)]),scale_c.darkened(0.2))
		draw_colored_polygon(PackedVector2Array([Vector2(-7,-8),Vector2(7,-8),Vector2(9,8),Vector2(-9,8)]),scale_c)
		draw_colored_polygon(PackedVector2Array([Vector2(-12,-8),Vector2(12,-8),Vector2(14,-18),Vector2(-14,-18)]),scale_c)
		draw_circle(Vector2(0,-22),8,scale_c.lightened(0.1))
		draw_rect(Rect2(-6,-22,12,8),scale_c.darkened(0.1))
		draw_circle(Vector2(-5,-20),3,eye_c); draw_circle(Vector2(5,-20),3,eye_c)
		draw_circle(Vector2(-5,-20),1.5,Color(0.8,0,0)); draw_circle(Vector2(5,-20),1.5,Color(0.8,0,0))
		draw_colored_polygon(PackedVector2Array([Vector2(-8,-26),Vector2(-4,-26),Vector2(-6,-36)]),gold)
		draw_colored_polygon(PackedVector2Array([Vector2(4,-26),Vector2(8,-26),Vector2(6,-36)]),gold)
		draw_arc(Vector2(0,-15),22,0,TAU,32,Color(gold.r,gold.g,gold.b,0.18),3.5)

	func _pv_storm_lord() -> void:
		var cloud := Color(0.55,0.65,0.85); var dark  := Color(0.25,0.30,0.50)
		var bolt_c := Color(0.85,0.95,1.00)
		draw_rect(Rect2(-6,4,12,20),dark)
		draw_circle(Vector2(0,-8),14,dark)
		draw_circle(Vector2(-10,-6),11,cloud.darkened(0.1))
		draw_circle(Vector2(10,-6),11,cloud.darkened(0.1))
		draw_circle(Vector2(0,-14),13,cloud)
		draw_circle(Vector2(-8,-14),9,cloud); draw_circle(Vector2(8,-14),9,cloud)
		draw_line(Vector2(-4,-4),Vector2(-8,4),Color(bolt_c.r,bolt_c.g,bolt_c.b,0.8),2.0)
		draw_line(Vector2(-8,4),Vector2(-5,10),Color(bolt_c.r,bolt_c.g,bolt_c.b,0.8),2.0)
		draw_line(Vector2(4,-4),Vector2(8,4),Color(bolt_c.r,bolt_c.g,bolt_c.b,0.8),2.0)
		draw_line(Vector2(8,4),Vector2(5,10),Color(bolt_c.r,bolt_c.g,bolt_c.b,0.8),2.0)

	func _pv_chrono() -> void:
		var stone := Color(0.38,0.42,0.48); var teal := Color(0.20,0.90,0.75)
		var gold  := Color(0.90,0.78,0.22)
		draw_colored_polygon(PackedVector2Array([Vector2(-9,-4),Vector2(9,-4),Vector2(10,22),Vector2(-10,22)]),stone)
		draw_colored_polygon(PackedVector2Array([Vector2(-11,-6),Vector2(11,-6),Vector2(11,-2),Vector2(-11,-2)]),stone.lightened(0.1))
		draw_circle(Vector2(0,-14),12,stone.lightened(0.08))
		draw_circle(Vector2(0,-14),12,teal,false,2.0)
		for i in range(12):
			var ang := i * TAU / 12.0
			var ip  := Vector2(cos(ang),sin(ang))
			draw_line(ip*9+Vector2(0,-14),ip*12+Vector2(0,-14),teal,1.5)
		draw_line(Vector2(0,-14),Vector2(0,-20),gold,2.5)
		draw_line(Vector2(0,-14),Vector2(6,-14),teal,1.5)
		draw_circle(Vector2(0,-14),2,gold)

	func _pv_world_tree() -> void:
		var bark  := Color(0.38,0.24,0.10); var bark2 := Color(0.28,0.16,0.06)
		var leaf  := Color(0.20,0.75,0.30); var leaf2 := Color(0.30,0.92,0.42)
		draw_line(Vector2(-6,18),Vector2(-18,24),bark2,3.0)
		draw_line(Vector2(6,18),Vector2(18,24),bark2,3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-7,-8),Vector2(7,-8),Vector2(8,22),Vector2(-8,22)]),bark)
		draw_colored_polygon(PackedVector2Array([Vector2(2,-8),Vector2(7,-8),Vector2(8,22),Vector2(4,22)]),bark2)
		draw_circle(Vector2(0,-16),14,leaf.darkened(0.15))
		draw_circle(Vector2(-10,-20),10,leaf); draw_circle(Vector2(10,-20),10,leaf)
		draw_circle(Vector2(0,-26),12,leaf2)
		draw_circle(Vector2(-6,-30),8,leaf2.lightened(0.05))
		draw_circle(Vector2(6,-30),8,leaf2.lightened(0.05))
		draw_circle(Vector2(-2,2),2.5,Color(0.50,1.00,0.55,0.6))
		draw_circle(Vector2(3,10),2.5,Color(0.50,1.00,0.55,0.5))

	func _pv_venom_drake() -> void:
		var grn  := Color(0.20, 0.80, 0.28); var drk  := Color(0.10, 0.40, 0.14)
		var purp := Color(0.60, 0.20, 0.80); var yel  := Color(0.85, 0.95, 0.20)
		# Body
		draw_colored_polygon(PackedVector2Array([Vector2(-10,2),Vector2(10,2),Vector2(12,22),Vector2(-12,22)]),drk)
		draw_colored_polygon(PackedVector2Array([Vector2(-8,-10),Vector2(8,-10),Vector2(10,2),Vector2(-10,2)]),grn)
		# Neck/head
		draw_circle(Vector2(0,-18),8,grn)
		draw_circle(Vector2(0,-18),6,drk.lightened(0.1))
		# Fangs
		draw_colored_polygon(PackedVector2Array([Vector2(-5,-14),Vector2(-2,-14),Vector2(-3,-8)]),yel)
		draw_colored_polygon(PackedVector2Array([Vector2(2,-14),Vector2(5,-14),Vector2(3,-8)]),yel)
		# Wings
		draw_colored_polygon(PackedVector2Array([Vector2(-10,-6),Vector2(-22,-18),Vector2(-16,-2),Vector2(-10,2)]),purp.darkened(0.1))
		draw_colored_polygon(PackedVector2Array([Vector2(10,-6),Vector2(22,-18),Vector2(16,-2),Vector2(10,2)]),purp.darkened(0.1))
		# Toxic orb glow
		draw_circle(Vector2(0,-18),4,Color(0.30,1.00,0.40,0.7))
		draw_circle(Vector2(0,-18),2,Color(1,1,1,0.5))

	func _pv_frost_cannon() -> void:
		var ice  := Color(0.55, 0.90, 1.00); var ice2 := Color(0.85, 0.97, 1.00)
		var dark := Color(0.25, 0.45, 0.65); var gold := Color(0.90, 0.78, 0.22)
		# Wheels
		draw_circle(Vector2(-16,18),9,dark.darkened(0.2)); draw_circle(Vector2(-16,18),7,dark)
		draw_circle(Vector2(16,18),9,dark.darkened(0.2));  draw_circle(Vector2(16,18),7,dark)
		draw_line(Vector2(-16,18),Vector2(16,18),dark.darkened(0.2),3.5)
		# Carriage
		draw_colored_polygon(PackedVector2Array([Vector2(-14,2),Vector2(14,2),Vector2(16,16),Vector2(-16,16)]),dark)
		# Barrel
		draw_line(Vector2(-4,-4),Vector2(20,-20),dark.darkened(0.2),18)
		draw_line(Vector2(-4,-4),Vector2(20,-20),ice,14)
		draw_line(Vector2(-4,-4),Vector2(20,-20),ice2,5)
		draw_circle(Vector2(20,-20),9,ice)
		draw_circle(Vector2(20,-20),4,ice2)
		# Frost crystals on barrel
		for i in range(3):
			var t := 0.25 + i * 0.25
			var bp := Vector2(-4 + t*24, -4 - t*16)
			draw_colored_polygon(PackedVector2Array([bp+Vector2(-3,0),bp+Vector2(0,-6),bp+Vector2(3,0)]),ice2)
		# Gold ring
		draw_arc(Vector2(-4,-4),7,-PI*0.6,PI*0.6,10,gold,2.0)

	func _pv_arcane_overlord() -> void:
		var orng := Color(0.90, 0.42, 0.12); var purp := Color(0.85, 0.30, 0.95)
		var gold := Color(0.90, 0.78, 0.22); var wht  := Color(1.00, 0.95, 0.85)
		# Floating core
		draw_circle(Vector2(0,-6),13,orng.darkened(0.3))
		draw_circle(Vector2(0,-6),10,orng)
		draw_circle(Vector2(0,-6),6,Color(1,0.75,0.40))
		draw_circle(Vector2(-2,-8),3,wht)
		# Arcane rings
		draw_arc(Vector2(0,-6),16,0,TAU,20,Color(purp.r,purp.g,purp.b,0.7),2.5)
		draw_arc(Vector2(0,-6),20,-PI*0.4,PI*0.4,10,Color(gold.r,gold.g,gold.b,0.5),1.5)
		# Flame tendrils
		for i in range(4):
			var ang := i * TAU / 4.0 + PI * 0.25
			var ep  := Vector2(cos(ang)*18 + 0, sin(ang)*14 - 6)
			draw_line(Vector2(0,-6),ep,Color(orng.r,orng.g,orng.b,0.8),2.5)
			draw_circle(ep,3,Color(purp.r,purp.g,purp.b,0.6))
		# Base pillar
		draw_colored_polygon(PackedVector2Array([Vector2(-5,6),Vector2(5,6),Vector2(6,22),Vector2(-6,22)]),gold.darkened(0.3))
		draw_rect(Rect2(-8,4,16,6),gold.darkened(0.2))

	func _pv_dragon_lich() -> void:
		var dkpur := Color(0.30, 0.10, 0.45); var gold := Color(0.90, 0.78, 0.22)
		var grn   := Color(0.20, 0.90, 0.40); var bone := Color(0.88, 0.84, 0.72)
		# Skeletal body
		draw_colored_polygon(PackedVector2Array([Vector2(-9,2),Vector2(9,2),Vector2(11,22),Vector2(-11,22)]),dkpur)
		draw_colored_polygon(PackedVector2Array([Vector2(-8,-10),Vector2(8,-10),Vector2(9,2),Vector2(-9,2)]),dkpur.lightened(0.1))
		# Rib cage lines
		for i in range(3):
			draw_line(Vector2(-8,4+i*5),Vector2(-2,4+i*5),bone,1.5)
			draw_line(Vector2(2,4+i*5),Vector2(8,4+i*5),bone,1.5)
		# Dragon skull
		draw_circle(Vector2(0,-18),9,dkpur.lightened(0.05))
		draw_circle(Vector2(-4,-17),3,grn); draw_circle(Vector2(4,-17),3,grn)
		draw_circle(Vector2(-4,-17),1.5,Color(0.80,1.00,0.10)); draw_circle(Vector2(4,-17),1.5,Color(0.80,1.00,0.10))
		draw_colored_polygon(PackedVector2Array([Vector2(-7,-12),Vector2(-4,-12),Vector2(-5,-8)]),bone)
		draw_colored_polygon(PackedVector2Array([Vector2(4,-12),Vector2(7,-12),Vector2(5,-8)]),bone)
		# Horns
		draw_colored_polygon(PackedVector2Array([Vector2(-6,-24),Vector2(-4,-24),Vector2(-8,-36)]),gold)
		draw_colored_polygon(PackedVector2Array([Vector2(4,-24),Vector2(6,-24),Vector2(8,-36)]),gold)
		# Death aura
		draw_arc(Vector2(0,-18),14,0,TAU,20,Color(grn.r,grn.g,grn.b,0.25),3.0)

	func _pv_tempest_warden() -> void:
		var storm := Color(0.45, 0.75, 1.00); var dark  := Color(0.20, 0.30, 0.55)
		var wht   := Color(0.90, 0.95, 1.00); var gold  := Color(0.90, 0.78, 0.22)
		# Armored body
		draw_colored_polygon(PackedVector2Array([Vector2(-10,-8),Vector2(10,-8),Vector2(11,8),Vector2(-11,8)]),dark)
		draw_colored_polygon(PackedVector2Array([Vector2(-9,8),Vector2(9,8),Vector2(10,22),Vector2(-10,22)]),dark.darkened(0.1))
		draw_line(Vector2(-10,-8),Vector2(10,-8),storm,2.5)
		draw_line(Vector2(-10,8),Vector2(10,8),storm,2.0)
		# Helmet
		draw_circle(Vector2(0,-18),9,dark.lightened(0.05))
		draw_rect(Rect2(-9,-22,18,5),dark.lightened(0.1))
		draw_rect(Rect2(-3,-28,6,10),storm)
		# Storm wings
		draw_colored_polygon(PackedVector2Array([Vector2(-10,-4),Vector2(-24,-16),Vector2(-20,-2),Vector2(-11,4)]),storm.darkened(0.15))
		draw_colored_polygon(PackedVector2Array([Vector2(10,-4),Vector2(24,-16),Vector2(20,-2),Vector2(11,4)]),storm.darkened(0.15))
		# Lightning bolts on wings
		draw_line(Vector2(-14,-10),Vector2(-18,-2),wht,2.0)
		draw_line(Vector2(-18,-2),Vector2(-15,4),wht,2.0)
		draw_line(Vector2(14,-10),Vector2(18,-2),wht,2.0)
		draw_line(Vector2(18,-2),Vector2(15,4),wht,2.0)
		# Gold pauldrons
		draw_circle(Vector2(-12,-4),5,gold.darkened(0.1))
		draw_circle(Vector2(12,-4),5,gold.darkened(0.1))

	func _pv_infernal_serpent() -> void:
		var red  := Color(1.00, 0.30, 0.05); var drk  := Color(0.45, 0.10, 0.02)
		var gold := Color(1.00, 0.72, 0.10); var yel  := Color(1.00, 0.90, 0.20)
		draw_colored_polygon(PackedVector2Array([Vector2(-11,-6),Vector2(11,-6),Vector2(12,10),Vector2(-12,10)]),drk)
		draw_colored_polygon(PackedVector2Array([Vector2(-8,-6),Vector2(8,-6),Vector2(7,4),Vector2(-7,4)]),red)
		draw_circle(Vector2(0,-17),10,drk)
		draw_colored_polygon(PackedVector2Array([Vector2(-5,-26),Vector2(-8,-36),Vector2(-3,-26)]),gold)
		draw_colored_polygon(PackedVector2Array([Vector2(5,-26),Vector2(8,-36),Vector2(3,-26)]),gold)
		draw_circle(Vector2(-4,-18),2.5,yel); draw_circle(Vector2(4,-18),2.5,yel)
		draw_colored_polygon(PackedVector2Array([Vector2(-6,-12),Vector2(6,-12),Vector2(9,-4),Vector2(-9,-4)]),Color(1.0,0.55,0.05,0.85))

	func _pv_shadow_weaver() -> void:
		var voidc := Color(0.20, 0.08, 0.35); var purp := Color(0.55, 0.20, 0.85)
		var wht  := Color(0.92, 0.88, 1.00); var dark := Color(0.10, 0.05, 0.20)
		draw_colored_polygon(PackedVector2Array([Vector2(-12,-4),Vector2(12,-4),Vector2(14,22),Vector2(-14,22)]),voidc)
		draw_colored_polygon(PackedVector2Array([Vector2(-12,-4),Vector2(12,-4),Vector2(10,8),Vector2(-10,8)]),voidc.lightened(0.08))
		draw_circle(Vector2(0,-16),10,dark)
		draw_colored_polygon(PackedVector2Array([Vector2(-12,-14),Vector2(12,-14),Vector2(8,-4),Vector2(-8,-4)]),dark)
		draw_colored_polygon(PackedVector2Array([Vector2(-6,-24),Vector2(6,-24),Vector2(10,-14),Vector2(-10,-14)]),dark)
		draw_circle(Vector2(-3,-17),2,purp); draw_circle(Vector2(3,-17),2,purp)
		draw_line(Vector2(14,20),Vector2(14,-30),purp.darkened(0.2),4.0)
		draw_circle(Vector2(14,-30),7,dark); draw_circle(Vector2(14,-30),4,purp)

	func _pv_natures_wrath() -> void:
		var grn  := Color(0.22, 0.85, 0.35); var drk  := Color(0.08, 0.35, 0.12)
		var bark := Color(0.38, 0.22, 0.10); var leaf := Color(0.18, 0.72, 0.28)
		draw_colored_polygon(PackedVector2Array([Vector2(-8,22),Vector2(8,22),Vector2(6,-2),Vector2(-6,-2)]),bark)
		draw_colored_polygon(PackedVector2Array([Vector2(-5,-2),Vector2(5,-2),Vector2(4,-14),Vector2(-4,-14)]),bark.lightened(0.1))
		draw_line(Vector2(-8,18),Vector2(-18,28),drk,3.0); draw_line(Vector2(8,18),Vector2(18,28),drk,3.0)
		draw_circle(Vector2(0,-20),16,drk)
		draw_circle(Vector2(-10,-16),11,leaf); draw_circle(Vector2(10,-16),11,leaf)
		draw_circle(Vector2(0,-26),13,grn)

	func _pv_void_titan() -> void:
		var void2 := Color(0.18, 0.08, 0.38); var purp := Color(0.50, 0.25, 0.90)
		var dark := Color(0.08, 0.04, 0.18); var crys := Color(0.72, 0.45, 1.00)
		draw_colored_polygon(PackedVector2Array([Vector2(-12,6),Vector2(-3,6),Vector2(-4,22),Vector2(-13,22)]),dark)
		draw_colored_polygon(PackedVector2Array([Vector2(3,6),Vector2(12,6),Vector2(13,22),Vector2(4,22)]),dark)
		draw_colored_polygon(PackedVector2Array([Vector2(-14,-8),Vector2(14,-8),Vector2(12,8),Vector2(-12,8)]),void2)
		draw_colored_polygon(PackedVector2Array([Vector2(-10,-8),Vector2(10,-8),Vector2(9,2),Vector2(-9,2)]),purp.darkened(0.25))
		draw_colored_polygon(PackedVector2Array([Vector2(-14,-8),Vector2(-20,-4),Vector2(-18,4),Vector2(-13,2)]),void2.lightened(0.1))
		draw_colored_polygon(PackedVector2Array([Vector2(14,-8),Vector2(20,-4),Vector2(18,4),Vector2(13,2)]),void2.lightened(0.1))
		draw_circle(Vector2(0,-18),11,dark)
		draw_colored_polygon(PackedVector2Array([Vector2(-7,-20),Vector2(7,-20),Vector2(6,-16),Vector2(-6,-16)]),crys)
		draw_colored_polygon(PackedVector2Array([Vector2(0,-6),Vector2(-5,0),Vector2(0,6),Vector2(5,0)]),crys)

	# ── Hero-exclusive visuals (idx 50-52) ────────────────────────────────────

	func _pv_hero_paladin(tc: Color) -> void:
		# Heavyset holy warrior with a warhammer and kite shield
		var gold   := Color(0.90, 0.78, 0.22)
		var tc_d   := tc.darkened(0.35)
		var tc_l   := tc.lightened(0.25)
		var white  := Color(0.95, 0.92, 0.85)
		# Legs
		draw_rect(Rect2(-11, 10, 10, 14), tc_d)
		draw_rect(Rect2(1,   10, 10, 14), tc_d)
		# Tabard (holy cloth over chest)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-11, -6), Vector2(11, -6), Vector2(13, 12), Vector2(-13, 12)
		]), white)
		draw_line(Vector2(0, -6), Vector2(0, 12), gold, 2.0)
		draw_line(Vector2(-13, 4), Vector2(13, 4), gold, 1.5)
		# Breastplate shoulders
		draw_colored_polygon(PackedVector2Array([
			Vector2(-14, -10), Vector2(14, -10), Vector2(12, -2), Vector2(-12, -2)
		]), tc)
		draw_circle(Vector2(-16, -8), 7, tc); draw_circle(Vector2(16, -8), 7, tc)
		# Helm (full visor helm)
		draw_circle(Vector2(0, -20), 10, tc)
		draw_rect(Rect2(-8, -24, 16, 5), tc_d)
		draw_rect(Rect2(-5, -22, 10, 4), Color(0.10, 0.10, 0.12, 0.9))  # visor slit
		draw_line(Vector2(-8, -24), Vector2(8, -24), gold, 2.0)
		# Warhammer (right side)
		draw_rect(Rect2(16, -28, 6, 22), tc.darkened(0.2))   # handle
		draw_rect(Rect2(12, -32, 14, 12), tc)                 # hammerhead
		draw_line(Vector2(12, -32), Vector2(26, -32), gold, 1.5)
		draw_line(Vector2(12, -20), Vector2(26, -20), gold, 1.5)
		# Kite shield (left side)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-28, -18), Vector2(-14, -18),
			Vector2(-14,  4),  Vector2(-21, 14), Vector2(-28, 4)
		]), tc_l)
		draw_polyline(PackedVector2Array([
			Vector2(-28, -18), Vector2(-14, -18),
			Vector2(-14,  4),  Vector2(-21, 14), Vector2(-28, 4), Vector2(-28, -18)
		]), gold, 1.5)
		draw_line(Vector2(-21, -18), Vector2(-21, 14), gold, 1.0)
		draw_line(Vector2(-28, -7),  Vector2(-14, -7), gold, 1.0)

	func _pv_hero_rogue(tc: Color) -> void:
		# Hooded assassin with twin daggers
		var skin   := Color(0.94, 0.78, 0.60)
		var dark   := tc.darkened(0.30)
		var silver := Color(0.75, 0.78, 0.82)
		var wrap   := tc.lightened(0.10)
		# Legs (crouching stance — offset)
		draw_rect(Rect2(-10,  8,  9, 12), dark)
		draw_rect(Rect2(  1,  6,  9, 14), dark)
		# Cloak body
		draw_colored_polygon(PackedVector2Array([
			Vector2(-12, -8), Vector2(12, -8), Vector2(14, 20), Vector2(-14, 20)
		]), tc)
		draw_colored_polygon(PackedVector2Array([
			Vector2(4, -8), Vector2(12, -8), Vector2(14, 20), Vector2(6, 20)
		]), dark)
		# Belt
		draw_line(Vector2(-13, 6), Vector2(13, 6), silver, 2.0)
		draw_rect(Rect2(-3, 4, 6, 5), silver.darkened(0.1))
		# Neck & face (mostly hidden by hood)
		draw_circle(Vector2(0, -18), 7, skin)
		# Hood (deep cowl)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-13, -12), Vector2(13, -12),
			Vector2(10,  -22), Vector2(-10, -22)
		]), tc)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-8, -22), Vector2(8, -22),
			Vector2(5,  -33), Vector2(-5, -33)
		]), tc)
		draw_arc(Vector2(0, -20), 8, -PI * 0.7, PI * 0.7, 12, dark, 2.5)
		# Left dagger (held low)
		draw_rect(Rect2(-22, 2, 3, 14), wrap)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-22, 2), Vector2(-19, 2), Vector2(-20, -8)
		]), silver)
		draw_line(Vector2(-24, 2), Vector2(-17, 2), silver, 2.0)
		# Right dagger (raised)
		draw_rect(Rect2(18, -14, 3, 14), wrap)
		draw_colored_polygon(PackedVector2Array([
			Vector2(18, -14), Vector2(21, -14), Vector2(20, -24)
		]), silver)
		draw_line(Vector2(16, -14), Vector2(23, -14), silver, 2.0)

	func _pv_hero_warlock(tc: Color) -> void:
		# Dark-robed warlock with a curved staff and glowing orb
		var dark   := tc.darkened(0.40)
		var tc_l   := tc.lightened(0.30)
		var skin   := Color(0.80, 0.68, 0.55)   # slightly sallow
		var staff  := Color(0.25, 0.18, 0.10)
		var orb    := tc.lightened(0.50)
		var trim   := tc.lightened(0.15)
		# Robe — longer and narrower than mage
		draw_colored_polygon(PackedVector2Array([
			Vector2(-7, -8), Vector2(7, -8), Vector2(11, 24), Vector2(-11, 24)
		]), dark)
		draw_colored_polygon(PackedVector2Array([
			Vector2(3, -8), Vector2(7, -8), Vector2(11, 24), Vector2(6, 24)
		]), tc.darkened(0.55))
		# Rune trim on robe hem
		draw_line(Vector2(-11, 18), Vector2(11, 18), trim, 1.5)
		for rx in [-8, -4, 0, 4, 8]:
			draw_line(Vector2(rx, 18), Vector2(rx, 22), trim, 1.0)
		# Face
		draw_circle(Vector2(0, -18), 7, skin)
		# Tall pointed hood with side flares
		draw_colored_polygon(PackedVector2Array([
			Vector2(-10, -22), Vector2(10, -22),
			Vector2(6, -30), Vector2(-6, -30)
		]), dark)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-5, -30), Vector2(5, -30), Vector2(1, -42), Vector2(-1, -42)
		]), dark)
		draw_line(Vector2(-5, -30), Vector2(-1, -42), trim, 1.0)
		draw_line(Vector2(5, -30), Vector2(1, -42), trim, 1.0)
		# Curved staff (left side, angled)
		draw_line(Vector2(-15, 20), Vector2(-18, -20), staff, 4.0)
		draw_arc(Vector2(-22, -20), 8, -PI * 0.5, PI * 0.2, 10, staff, 4.0)
		# Glowing orb atop staff
		draw_circle(Vector2(-22, -28), 7, orb.darkened(0.2))
		draw_circle(Vector2(-22, -28), 5, orb)
		draw_circle(Vector2(-24, -30), 2, tc_l)
		# Floating rune shard (right side)
		draw_colored_polygon(PackedVector2Array([
			Vector2(14, -16), Vector2(20, -10), Vector2(16, -4), Vector2(10, -10)
		]), tc)
		draw_polyline(PackedVector2Array([
			Vector2(14, -16), Vector2(20, -10), Vector2(16, -4), Vector2(10, -10), Vector2(14, -16)
		]), tc_l, 1.5)

	func _pv_generic(tc: Color) -> void:
		var rar := turret_data.get("rarity","common") as String
		draw_colored_polygon(PackedVector2Array([Vector2(-10,2),Vector2(10,2),Vector2(12,14),Vector2(-12,14)]),tc.darkened(0.3))
		draw_colored_polygon(PackedVector2Array([Vector2(-7,-8),Vector2(7,-8),Vector2(9,2),Vector2(-9,2)]),tc)
		draw_circle(Vector2(0,-12),7,tc.lightened(0.15))
		draw_circle(Vector2(-2,-14),2.5,Color(1,1,1,0.5))
		var rc := Color(0.75,0.75,0.75)
		match rar:
			"rare":      rc = Color(0.25,0.55,1.0)
			"epic":      rc = Color(0.72,0.25,0.90)
			"legendary": rc = Color(1.0,0.72,0.10)
			"fusion":    rc = Color(0.20,1.00,0.85)
		draw_circle(Vector2(0,-12),3,rc)
