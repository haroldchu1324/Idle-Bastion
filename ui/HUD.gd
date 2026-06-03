extends Control

# ── Signals ───────────────────────────────────────────────────────────────────
signal wave_pressed
signal speed_toggled(factor: float)
signal start_battle_pressed
signal upgrade_purchased(idx: int, cost: int)
signal prestige_confirmed
signal roll_turret_requested
signal roll_upgrade_requested

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
var _upgrade_result_card : Control = null
var _roll_status_lbl     : Label   = null
var _upg_roll_status_lbl : Label   = null
var _current_gold        : int     = 0

# Rarity info modal (centered overlay)
var _rarity_modal      : Control = null
var _modal_odds_lbls   : Array   = []   # 4 labels, one per rarity for the 80g column

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

# Screens
var _game_over_screen   : Control
var _upgrades_screen    : Control
var _victory_screen     : Control
var _upg_gold_lbl       : Label
var _upg_rows           : Array = []
var _go_stage_lbl       : Label

var _btn_tweens : Dictionary = {}
var _font_reg   : FontFile
var _font_bold  : FontFile

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
	_font_reg  = FontFile.new()
	_font_bold = FontFile.new()
	_font_reg.load_dynamic_font("res://assets/fonts/Rajdhani-Regular.ttf")
	_font_bold.load_dynamic_font("res://assets/fonts/Rajdhani-Bold.ttf")


func setup(_main) -> void:
	pass


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
		wave_btn.text   = "✓  Victory!"
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
			wave_btn.text = "▶  Send Next Wave  [Space]"
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
		wave_btn.text = "▶  Start Wave %d  [Space]" % (wave_in_stage + 1)
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

func show_turret_result(data: Dictionary) -> void:
	if _turret_result_card == null or _roll_status_lbl == null:
		return
	for child in _turret_result_card.get_children():
		child.queue_free()

	_roll_status_lbl.text      = ""
	_roll_status_lbl.modulate  = C_WHITE

	var rarity : String = data.get("rarity", "")
	var rarity_cols := {"common": Color(0.7,0.7,0.7), "rare": Color(0.25,0.55,1.0),
						"epic": Color(0.72,0.25,0.90), "legendary": Color(1.0,0.72,0.10)}
	var rc : Color = rarity_cols.get(rarity, C_WHITE)

	# Background tint based on color
	var bg_col : Color = (data.get("color", Color(0.3,0.3,0.3)) as Color).darkened(0.55)
	_turret_result_card.add_theme_stylebox_override("panel", _rounded(bg_col))

	var cw := 248   # card width

	# Turret preview — left side of card, vertically centered
	var preview := _TurretPreview.new()
	preview.turret_data = data
	preview.position    = Vector2(4, 8)
	_turret_result_card.add_child(preview)

	# Rarity badge and name — right of preview
	var tx := 72
	if rarity != "":
		var rar_lbl := _label(rarity.capitalize(), _font_bold, 11, rc)
		rar_lbl.position = Vector2(tx, 10)
		rar_lbl.size     = Vector2(cw - tx - 4, 18)
		_turret_result_card.add_child(rar_lbl)

	var name_lbl := _label(data.get("name", "Tower"), _font_bold, 14, C_WHITE)
	name_lbl.position      = Vector2(tx, 28)
	name_lbl.size          = Vector2(cw - tx - 4, 22)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_turret_result_card.add_child(name_lbl)

	var stats := "⚔ %.1f  🎯 %.0f  ⚡ %.1f/s" % [data.get("damage",0.0), data.get("range",0.0), data.get("fire_rate",0.0)]
	var stat_lbl := _label(stats, _font_reg, 10, Color(0.85, 0.85, 0.85))
	stat_lbl.position = Vector2(tx, 52)
	stat_lbl.size     = Vector2(cw - tx - 4, 18)
	_turret_result_card.add_child(stat_lbl)

	if data.get("effect", "none") != "none":
		var eff_map := {"pierce": "🔵 Pierce", "aoe": "💥 AoE", "chain": "⚡ Chain",
						"lightning": "⚡ Lightning", "storm_chain": "🌩 Storm Chain",
						"slow_zone": "❄ Slow Zone"}
		var eff_lbl := _label(eff_map.get(data["effect"], ""), _font_bold, 10, C_GOLD)
		eff_lbl.position = Vector2(tx, 70)
		eff_lbl.size     = Vector2(cw - tx - 4, 16)
		_turret_result_card.add_child(eff_lbl)

	var placed_lbl := _label("✅  Placed on map!", _font_bold, 11, C_BTN.lightened(0.2))
	placed_lbl.position             = Vector2(0, 152)
	placed_lbl.size                 = Vector2(cw, 22)
	placed_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turret_result_card.add_child(placed_lbl)


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
	_build_rarity_modal()       # build modal before right panel so info_btn can reference it
	_build_right_panel()
	_build_wave_label()
	_build_hud_bar()
	_build_tower_info_panel()
	_build_notification()
	_build_game_over_screen()
	_build_upgrades_screen()
	_build_victory_screen()


# ── Top labels ────────────────────────────────────────────────────────────────

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

	_boss_lbl = _label("⚔  BOSS", _font_bold, 13, Color(1.0, 0.38, 0.28))
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

	_boss_hp_lbl = _label("", _font_bold, 12, C_WHITE)
	_boss_hp_lbl.position             = Vector2(82, 9)
	_boss_hp_lbl.size                 = Vector2(430, 22)
	_boss_hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_hp_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_boss_hp_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	_boss_bar.add_child(_boss_hp_lbl)

	_boss_timer_lbl = _label("60 s", _font_bold, 13, Color(1.0, 0.65, 0.30))
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

	wave_btn = Button.new()
	wave_btn.text         = "▶  Start Wave 1  [Space]"
	wave_btn.position     = Vector2(500, 10)
	wave_btn.size         = Vector2(280, 50)
	wave_btn.pivot_offset = Vector2(140, 25)
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


func _build_rarity_modal() -> void:
	var overlay := ColorRect.new()
	overlay.color        = Color(0, 0, 0, 0.75)
	overlay.position     = Vector2.ZERO
	overlay.size         = Vector2(1280, 720)
	overlay.mouse_filter = MOUSE_FILTER_STOP
	overlay.visible      = false
	add_child(overlay)
	_rarity_modal = overlay

	const CW : int = 340
	const CH : int = 290
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
	xbtn.text       = "✕"
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

	# Table header
	var col_x := [16, 230]
	var h0 := _label("Rarity", _font_bold, 12, C_DIM)
	h0.position = Vector2(col_x[0], 62); h0.size = Vector2(180, 20)
	card.add_child(h0)
	var h1 := _label("80g Summon", _font_bold, 12, C_DIM)
	h1.position = Vector2(col_x[1], 62); h1.size = Vector2(95, 20)
	h1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(h1)

	var hdiv := ColorRect.new()
	hdiv.color = Color(1,1,1,0.1); hdiv.position = Vector2(12, 84); hdiv.size = Vector2(CW-24, 2)
	card.add_child(hdiv)

	var rarity_defs := [
		["⚪  Common",    Color(0.80, 0.80, 0.80)],
		["🔵  Rare",      Color(0.25, 0.55, 1.00)],
		["🟣  Epic",      Color(0.72, 0.25, 0.90)],
		["🟡  Legendary", Color(1.00, 0.72, 0.10)],
	]
	_modal_odds_lbls.clear()
	for ri in range(rarity_defs.size()):
		var ry := 92 + ri * 42
		var row_bg := ColorRect.new()
		row_bg.color    = Color(1, 1, 1, 0.04 if ri % 2 == 0 else 0.0)
		row_bg.position = Vector2(8, ry - 4)
		row_bg.size     = Vector2(CW - 16, 38)
		card.add_child(row_bg)

		var rlbl := _label(rarity_defs[ri][0], _font_bold, 14, rarity_defs[ri][1] as Color)
		rlbl.position = Vector2(col_x[0], ry); rlbl.size = Vector2(200, 28)
		card.add_child(rlbl)

		var pct := _label("—", _font_bold, 14, C_WHITE)
		pct.position             = Vector2(col_x[1], ry)
		pct.size                 = Vector2(95, 28)
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(pct)
		_modal_odds_lbls.append(pct)

	overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if not card.get_rect().has_point(card.get_parent().get_local_mouse_position()):
				overlay.visible = false
	)


func _refresh_rarity_modal() -> void:
	if _modal_odds_lbls.is_empty():
		return
	var odds : Array = SummonSystem.BASIC_ODDS
	for ri in range(4):
		var lbl := _modal_odds_lbls[ri] as Label
		if is_instance_valid(lbl):
			lbl.text = "%d%%" % odds[ri]


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
	panel.add_theme_stylebox_override("panel", _rounded(C_PANEL))
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
		tb.add_theme_font_size_override("font_size", 13)
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

	# Small circular ℹ button — top-right of title row
	var circle_s := StyleBoxFlat.new()
	circle_s.bg_color = Color(0.18, 0.30, 0.55)
	circle_s.corner_radius_top_left     = 11
	circle_s.corner_radius_top_right    = 11
	circle_s.corner_radius_bottom_left  = 11
	circle_s.corner_radius_bottom_right = 11
	var circle_h := circle_s.duplicate() as StyleBoxFlat
	circle_h.bg_color = Color(0.26, 0.42, 0.72)
	var info_btn := Button.new()
	info_btn.text         = "ℹ"
	info_btn.position     = Vector2(w - 28, 9)
	info_btn.size         = Vector2(22, 22)
	info_btn.focus_mode   = FOCUS_NONE
	info_btn.add_theme_font_override("font",           _font_bold)
	info_btn.add_theme_font_size_override("font_size", 12)
	info_btn.add_theme_color_override("font_color",    C_WHITE)
	info_btn.add_theme_stylebox_override("normal",  circle_s)
	info_btn.add_theme_stylebox_override("hover",   circle_h)
	info_btn.add_theme_stylebox_override("pressed", circle_s)
	info_btn.add_theme_stylebox_override("focus",   circle_s)
	page.add_child(info_btn)

	var desc := _label("Pull a random turret — placed\ninstantly on the map!", _font_reg, 12, C_DIM)
	desc.position             = Vector2(8, 42)
	desc.size                 = Vector2(w - 16, 38)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode        = TextServer.AUTOWRAP_WORD
	page.add_child(desc)

	var cost_lbl := _label("💰 80 gold · any rarity!", _font_bold, 13, C_GOLD)
	cost_lbl.position             = Vector2(0, 84)
	cost_lbl.size                 = Vector2(w, 22)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(cost_lbl)

	var C_ROLL := Color(0.55, 0.28, 0.08)
	var roll_btn := Button.new()
	roll_btn.text         = "🎲  Pull Turret  (80g)"
	roll_btn.position     = Vector2(8, 128)
	roll_btn.size         = Vector2(w - 16, 50)
	roll_btn.pivot_offset = Vector2((w - 16) * 0.5, 25)
	roll_btn.focus_mode   = FOCUS_NONE
	roll_btn.add_theme_font_override("font",           _font_bold)
	roll_btn.add_theme_font_size_override("font_size", 14)
	roll_btn.add_theme_color_override("font_color",    C_WHITE)
	roll_btn.add_theme_stylebox_override("normal",  _btn_style(C_ROLL))
	roll_btn.add_theme_stylebox_override("hover",   _btn_style(C_ROLL.lightened(0.12)))
	roll_btn.add_theme_stylebox_override("pressed", _btn_style(C_ROLL.darkened(0.12)))
	roll_btn.add_theme_stylebox_override("focus",   _btn_style(C_ROLL))
	roll_btn.pressed.connect(func():
		_tween_scale(roll_btn, Vector2(0.92, 0.92), 0.08)
		roll_turret_requested.emit()
	)
	page.add_child(roll_btn)

	# Connect ℹ to open the centered rarity modal
	info_btn.pressed.connect(func():
		if is_instance_valid(_rarity_modal):
			_rarity_modal.visible = true
			_refresh_rarity_modal()
	)


# ── Upgrades Tab (Gacha) ──────────────────────────────────────────────────────

func _fill_upgrades_tab(page: Control) -> void:
	var w := 248

	var gacha_title := _label("⚔  Upgrade Gacha", _font_bold, 18, C_GOLD)
	gacha_title.position             = Vector2(0, 8)
	gacha_title.size                 = Vector2(w, 30)
	gacha_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(gacha_title)

	var desc := _label("Pull a random upgrade — applied\nto all towers for this run!", _font_reg, 12, C_DIM)
	desc.position             = Vector2(8, 42)
	desc.size                 = Vector2(w - 16, 38)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode        = TextServer.AUTOWRAP_WORD
	page.add_child(desc)

	var pool_lbl := _label("💰 60 gold · Dmg · Rng · Spd · Life", _font_bold, 13, C_GOLD)
	pool_lbl.position             = Vector2(0, 84)
	pool_lbl.size                 = Vector2(w, 22)
	pool_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(pool_lbl)

	var C_ROLL2 := Color(0.18, 0.38, 0.68)
	var roll_btn := Button.new()
	roll_btn.text         = "🎲  Pull Upgrade  (60g)"
	roll_btn.position     = Vector2(8, 128)
	roll_btn.size         = Vector2(w - 16, 50)
	roll_btn.pivot_offset = Vector2((w - 16) * 0.5, 25)
	roll_btn.focus_mode   = FOCUS_NONE
	roll_btn.add_theme_font_override("font",           _font_bold)
	roll_btn.add_theme_font_size_override("font_size", 14)
	roll_btn.add_theme_color_override("font_color",    C_WHITE)
	roll_btn.add_theme_stylebox_override("normal",  _btn_style(C_ROLL2))
	roll_btn.add_theme_stylebox_override("hover",   _btn_style(C_ROLL2.lightened(0.12)))
	roll_btn.add_theme_stylebox_override("pressed", _btn_style(C_ROLL2.darkened(0.12)))
	roll_btn.add_theme_stylebox_override("focus",   _btn_style(C_ROLL2))
	roll_btn.pressed.connect(func():
		_tween_scale(roll_btn, Vector2(0.92, 0.92), 0.08)
		roll_upgrade_requested.emit()
	)
	page.add_child(roll_btn)

	_upg_roll_status_lbl = _label("", _font_reg, 12, C_DIM)
	_upg_roll_status_lbl.position             = Vector2(0, 186)
	_upg_roll_status_lbl.size                 = Vector2(w, 20)
	_upg_roll_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(_upg_roll_status_lbl)

	var sep := ColorRect.new()
	sep.color    = Color(1, 1, 1, 0.08)
	sep.position = Vector2(8, 210)
	sep.size     = Vector2(w - 16, 2)
	page.add_child(sep)

	_upgrade_result_card = Panel.new()
	_upgrade_result_card.position = Vector2(0, 216)
	_upgrade_result_card.size     = Vector2(w, 320)
	_upgrade_result_card.add_theme_stylebox_override("panel", _rounded(C_CARD))
	page.add_child(_upgrade_result_card)

	var placeholder := _label("Pull to see your upgrade!", _font_bold, 17, C_DIM)
	placeholder.position             = Vector2(0, 130)
	placeholder.size                 = Vector2(w, 30)
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upgrade_result_card.add_child(placeholder)


# ── Tower info panel ──────────────────────────────────────────────────────────

func _build_tower_info_panel() -> void:
	const PW : int = 210   # panel width
	const PH : int = 318   # panel height

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

	var title := _label("Selected Tower", _font_bold, 11, C_DIM)
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
	_info_rarity_lbl = _label("", _font_bold, 11, C_DIM)
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

	_info_desc_lbl = _label("", _font_reg, 13, C_DIM)
	_info_desc_lbl.position      = Vector2(8, 142)
	_info_desc_lbl.size          = Vector2(PW - 16, 40)
	_info_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info_desc_lbl.mouse_filter  = MOUSE_FILTER_IGNORE
	panel.add_child(_info_desc_lbl)

	var div2 := ColorRect.new()
	div2.color = Color(1,1,1,0.08); div2.position = Vector2(8,184); div2.size = Vector2(PW-16,2)
	div2.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(div2)

	var stat_defs := [
		["⚔  Damage",    192],
		["🎯  Range",    216],
		["⚡  Fire Rate", 240],
		["✨  Effect",   264],
	]
	for s in stat_defs:
		var lbl := _label(s[0], _font_reg, 13, C_DIM)
		lbl.position     = Vector2(8, s[1])
		lbl.size         = Vector2(105, 22)
		lbl.mouse_filter = MOUSE_FILTER_IGNORE
		panel.add_child(lbl)

	_info_dmg_lbl = _label("", _font_bold, 13, C_WHITE)
	_info_dmg_lbl.position = Vector2(110, 192); _info_dmg_lbl.size = Vector2(PW-118, 22)
	_info_dmg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info_dmg_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(_info_dmg_lbl)

	_info_rng_lbl = _label("", _font_bold, 13, C_WHITE)
	_info_rng_lbl.position = Vector2(110, 216); _info_rng_lbl.size = Vector2(PW-118, 22)
	_info_rng_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info_rng_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(_info_rng_lbl)

	_info_rate_lbl = _label("", _font_bold, 13, C_WHITE)
	_info_rate_lbl.position = Vector2(110, 240); _info_rate_lbl.size = Vector2(PW-118, 22)
	_info_rate_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info_rate_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(_info_rate_lbl)

	_info_effect_lbl = _label("", _font_bold, 13, C_GOLD)
	_info_effect_lbl.position = Vector2(110, 264); _info_effect_lbl.size = Vector2(PW-118, 22)
	_info_effect_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info_effect_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(_info_effect_lbl)

	var div3 := ColorRect.new()
	div3.color = Color(1,1,1,0.08); div3.position = Vector2(8,290); div3.size = Vector2(PW-16,2)
	div3.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(div3)

	var hint := _label("Click to deselect", _font_reg, 10, Color(0.40,0.40,0.40))
	hint.position = Vector2(0,294); hint.size = Vector2(PW, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(hint)


func show_tower_info(tower) -> void:
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
	_info_dmg_lbl.text   = "%.0f" % tower.damage
	_info_rng_lbl.text   = "%.0f px" % tower.attack_range
	_info_rate_lbl.text  = "%.1f / s" % tower.fire_rate
	var eff_map := {"pierce": "Pierce", "aoe": "AoE", "chain": "Chain",
					"lightning": "Lightning", "storm_chain": "Storm Chain",
					"slow_zone": "❄ Slow Zone"}
	_info_effect_lbl.text = eff_map.get(d.get("effect", "none"), "—")
	_info_panel.visible = true


func hide_tower_info() -> void:
	_info_panel.visible = false


# ── Notification ──────────────────────────────────────────────────────────────

func _build_notification() -> void:
	_notify_lbl = Label.new()
	_notify_lbl.text     = ""
	_notify_lbl.position = Vector2(310, 320)
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
	_notify_lbl.position   = Vector2(310, 320)
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

func _build_game_over_screen() -> void:
	var overlay := ColorRect.new()
	overlay.color        = Color(0, 0, 0, 0.82)
	overlay.position     = Vector2.ZERO
	overlay.size         = Vector2(1280, 720)
	overlay.mouse_filter = MOUSE_FILTER_STOP
	overlay.visible      = false
	add_child(overlay)
	_game_over_screen = overlay

	var card := Panel.new()
	card.position = Vector2(390, 140)
	card.size     = Vector2(500, 380)
	card.add_theme_stylebox_override("panel", _rounded(Color(0.12, 0.05, 0.05, 0.98)))
	overlay.add_child(card)

	var top_bar := Panel.new()
	top_bar.position = Vector2(0, 0)
	top_bar.size     = Vector2(500, 80)
	top_bar.add_theme_stylebox_override("panel", _flat(Color(0.55, 0.08, 0.08), 10))
	card.add_child(top_bar)

	var title := _label("💀  GAME OVER", _font_bold, 34, C_WHITE)
	title.position             = Vector2(0, 0)
	title.size                 = Vector2(500, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	_go_stage_lbl = _label("Stage 1 reached", _font_bold, 22, C_DIM)
	_go_stage_lbl.position             = Vector2(0, 100)
	_go_stage_lbl.size                 = Vector2(500, 40)
	_go_stage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(_go_stage_lbl)

	var flavour := _label("Your kingdom has fallen…", _font_reg, 18, Color(0.65, 0.50, 0.50))
	flavour.position             = Vector2(0, 146)
	flavour.size                 = Vector2(500, 32)
	flavour.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(flavour)

	var div := ColorRect.new()
	div.color    = Color(1, 1, 1, 0.08)
	div.position = Vector2(40, 192)
	div.size     = Vector2(420, 2)
	card.add_child(div)

	var cont := Button.new()
	cont.text         = "Continue  →"
	cont.position     = Vector2(100, 278)
	cont.size         = Vector2(300, 60)
	cont.pivot_offset = Vector2(150, 30)
	cont.focus_mode   = FOCUS_NONE
	cont.add_theme_font_override("font",           _font_bold)
	cont.add_theme_font_size_override("font_size", 22)
	cont.add_theme_color_override("font_color",    C_WHITE)
	cont.add_theme_stylebox_override("normal",  _btn_style(Color(0.20, 0.20, 0.55)))
	cont.add_theme_stylebox_override("hover",   _btn_style(Color(0.28, 0.28, 0.72)))
	cont.add_theme_stylebox_override("pressed", _btn_style(Color(0.15, 0.15, 0.45)))
	cont.add_theme_stylebox_override("focus",   _btn_style(Color(0.20, 0.20, 0.55)))
	cont.pressed.connect(_on_continue_pressed)
	card.add_child(cont)


func show_game_over(stage: int) -> void:
	_go_stage_lbl.text = "Stage %d reached" % stage
	_game_over_screen.visible = true


func _on_continue_pressed() -> void:
	_game_over_screen.visible = false
	_refresh_all_upg_rows_postbattle()
	_upgrades_screen.visible = true


# ══════════════════════════════════════════════════════════════════════════════
# PRE-BATTLE UPGRADES SCREEN
# ══════════════════════════════════════════════════════════════════════════════

func _build_upgrades_screen() -> void:
	var overlay := ColorRect.new()
	overlay.color        = Color(0, 0, 0, 0.88)
	overlay.position     = Vector2.ZERO
	overlay.size         = Vector2(1280, 720)
	overlay.mouse_filter = MOUSE_FILTER_STOP
	overlay.visible      = false
	add_child(overlay)
	_upgrades_screen = overlay

	var card := Panel.new()
	card.position = Vector2(40, 30)
	card.size     = Vector2(1200, 640)
	card.add_theme_stylebox_override("panel", _rounded(C_PANEL))
	overlay.add_child(card)

	var title := _label("⚔  Pre-Battle Upgrades", _font_bold, 28, C_WHITE)
	title.position             = Vector2(0, 16)
	title.size                 = Vector2(1200, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(title)

	_upg_gold_lbl = _label("💰 0  available", _font_bold, 20, C_GOLD)
	_upg_gold_lbl.position             = Vector2(0, 64)
	_upg_gold_lbl.size                 = Vector2(1200, 36)
	_upg_gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(_upg_gold_lbl)

	var page := Control.new()
	page.position = Vector2(20, 108)
	page.size     = Vector2(1160, 440)
	card.add_child(page)
	_upg_rows = _build_all_upgrade_rows(page)

	var start_btn := Button.new()
	start_btn.text         = "▶  Start Battle"
	start_btn.position     = Vector2(1200 - 290, 640 - 72)
	start_btn.size         = Vector2(270, 54)
	start_btn.pivot_offset = Vector2(135, 27)
	start_btn.focus_mode   = FOCUS_NONE
	start_btn.add_theme_font_override("font",           _font_bold)
	start_btn.add_theme_font_size_override("font_size", 22)
	start_btn.add_theme_color_override("font_color",    C_WHITE)
	start_btn.add_theme_stylebox_override("normal",  _btn_style(C_BTN))
	start_btn.add_theme_stylebox_override("hover",   _btn_style(C_BTN_HOV))
	start_btn.add_theme_stylebox_override("pressed", _btn_style(C_BTN.darkened(0.1)))
	start_btn.add_theme_stylebox_override("focus",   _btn_style(C_BTN))
	start_btn.pressed.connect(func():
		_upgrades_screen.visible = false
		start_battle_pressed.emit()
	)
	card.add_child(start_btn)


func _build_all_upgrade_rows(page: Control) -> Array:
	var result : Array = []
	for i in range(_UPG_DATA.size()):
		var def  : Array = _UPG_DATA[i]
		var row  := Panel.new()
		row.position = Vector2(0, i * 100)
		row.size     = Vector2(1160, 88)
		row.add_theme_stylebox_override("panel", _rounded(C_CARD))
		page.add_child(row)

		var name_lbl := _label(def[0], _font_bold, 20, C_WHITE)
		name_lbl.position           = Vector2(16, 8)
		name_lbl.size               = Vector2(420, 36)
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_lbl)

		var desc_lbl := _label(def[1], _font_reg, 16, C_DIM)
		desc_lbl.position           = Vector2(16, 44)
		desc_lbl.size               = Vector2(620, 36)
		desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(desc_lbl)

		var lvl_lbl := _label("Lv 0 / %d" % GameData.MAX_LEVEL, _font_bold, 16, C_GOLD)
		lvl_lbl.position             = Vector2(650, 0)
		lvl_lbl.size                 = Vector2(140, 88)
		lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lvl_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		row.add_child(lvl_lbl)

		var cost_lbl := _label("💰 %d" % def[2], _font_bold, 18, C_GOLD)
		cost_lbl.position             = Vector2(890, 0)
		cost_lbl.size                 = Vector2(130, 88)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		row.add_child(cost_lbl)

		var buy := Button.new()
		buy.text       = "Buy"
		buy.position   = Vector2(1030, 22)
		buy.size       = Vector2(110, 44)
		buy.focus_mode = FOCUS_NONE
		buy.add_theme_font_override("font",           _font_bold)
		buy.add_theme_font_size_override("font_size", 17)
		buy.add_theme_color_override("font_color",    C_WHITE)
		buy.add_theme_stylebox_override("normal",  _btn_style(C_BTN))
		buy.add_theme_stylebox_override("hover",   _btn_style(C_BTN_HOV))
		buy.add_theme_stylebox_override("focus",   _btn_style(C_BTN))
		buy.add_theme_stylebox_override("pressed", _btn_style(C_BTN))
		buy.add_theme_stylebox_override("disabled",_btn_style(C_BTN_OFF))
		var idx := i
		buy.pressed.connect(func(): _on_postbattle_upg_buy(idx))
		row.add_child(buy)

		result.append({ "lvl_lbl": lvl_lbl, "cost_lbl": cost_lbl, "buy_btn": buy, "upg_idx": i })
	return result


func _on_postbattle_upg_buy(idx: int) -> void:
	var lvl  : int = _get_upg_level(idx)
	if lvl >= GameData.MAX_LEVEL:
		return
	var cost : int = GameData.cost_for(_UPG_DATA[idx][2], lvl)
	if GameData.run_gold < cost:
		return
	GameData.run_gold -= cost
	_apply_upgrade(idx)
	_refresh_all_upg_rows_postbattle()
	GameData.save_game()


func _refresh_all_upg_rows_postbattle() -> void:
	_refresh_upg_row_set(_upg_rows, false)
	if is_instance_valid(_upg_gold_lbl):
		_upg_gold_lbl.text = "💰 %d  available" % GameData.run_gold


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
		["▶  Continue Farming",  Color(0.20, 0.20, 0.55)],
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


# ── Button helpers ────────────────────────────────────────────────────────────

func _tween_scale(node: Control, target: Vector2, dur: float) -> void:
	if _btn_tweens.has(node) and is_instance_valid(_btn_tweens[node]):
		_btn_tweens[node].kill()
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", target, dur)
	_btn_tweens[node] = tw


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


func _btn_style(bg: Color) -> StyleBoxFlat:
	var s := _rounded(bg)
	s.content_margin_left   = 14
	s.content_margin_right  = 14
	s.content_margin_top    = 8
	s.content_margin_bottom = 8
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
			6, 7, 8, 10, 12: sc = 0.67   # frost spire, poison, sniper, infernal core, arcane cannon
			_:               sc = 0.56   # all others stay at original size
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
		draw_circle(Vector2(0,-12),3,rc)
