extends Control

# ── Debug toggle — set false before exporting ─────────────────────────────────
const DEBUG : bool = true

# ── Signals ───────────────────────────────────────────────────────────────────
signal wave_pressed
signal speed_toggled(factor: float)
signal start_battle_pressed
signal buff_chosen(buff_id: String)
signal upgrade_purchased(idx: int, cost: int)
signal prestige_confirmed
signal game_left
signal roll_turret_requested
signal roll_rare_requested
signal roll_epic_requested
signal roll_upgrade_requested
signal recipe_fusion_requested(result_id: String)
signal upgrade_merge_requested
signal debug_gold_requested
signal debug_skip_stage_requested(stage: int)
signal sell_tower_requested
signal debug_summon_requested(tower_id: String)
signal tower_selected_tutorial(info_btn_rect: Rect2)
signal tower_detail_opened_tutorial
signal tower_moved_tutorial
signal special_tiles_tutorial_closed

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

var tutorial_block_drag     : bool = false
var tutorial_block_info_btn : bool = false
var tutorial_lock_unit_btns : bool = false

var _gold_lbl       : Label
var _lives_lbl      : Label
var _gem_hud_lbl    : Label
var _loot_items          : Array   = []
var _loot_new_count      : int     = 0
var _idle_card_chips     : Array   = []   # [{chip, card_data, idle_tw}]
var _loot_badge_panel    : Control = null
var _loot_badge_lbl      : Label   = null
var _loot_panel          : Control = null
var _loot_catcher        : Control = null
var _loot_scroll_content : Control = null
var _stage_lbl      : Label
var _wave_lbl       : Label
var _boss_bar       : Panel
var _boss_lbl       : Label
var _boss_hp_fill   : ColorRect
var _boss_hp_lbl    : Label
var _boss_timer_lbl : Label
var _boss_timer_val : float = 0.0   # tracked each refresh for urgency animation
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

# Boss buff card overlay
var _boss_buff_overlay    : Control = null
# Tile drop animation input blocker
var _tile_anim_blocker    : Control = null
# Merge tutorial overlay
var _merge_tut_overlay    : Control    = null
var _merge_tut_timescale  : float      = 1.0
var _merge_tut_step       : int        = 0
var _mt_state             : Dictionary = {}
var _mt_update_blockers   : Callable
var _mt_canvas            : Control    = null
var _mt_panel             : Panel      = null
var _mt_body_lbl          : Label      = null
# Recipe tutorial overlay
var _recipe_tut_overlay   : Control    = null
var _recipe_tut_ts        : float      = 1.0

# Buff history (upgrades tab)
var _buff_history_scroll  : ScrollContainer = null
var _buff_history_flow    : HFlowContainer  = null
var _buff_empty_lbl       : Label           = null
var _buff_tooltip         : Panel           = null
var _buff_tooltip_name    : Label           = null
var _buff_tooltip_desc    : Label           = null

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
var _info_counter_lbl   : Label
var _info_counter_bg    : Panel

# Screens
var _tutorial_locked_btns   : Array   = []   # nav buttons hidden until dq_unlocked (first loss)
var _dq_main_btn            : Button  = null
var _game_over_screen       : Control
var _run_results_screen     : Control
var _run_results_loot_grid  : Control = null
var _upgrades_screen    : Control
var _shop_screen        : Control
var _world_map_screen   : Control
var _heroes_screen      : Control
var _towers_screen      : Control
var _daily_quests_screen : Control   = null
# Daily quests UI refs for live refresh
var _dq_bar1     : ColorRect = null   # progress fill for quest 1
var _dq_lbl1     : Label     = null   # "X / 200" text for quest 1
var _dq_status2  : Label     = null   # status text for quest 2
var _dq_status3  : Label     = null   # status text for quest 3
var _dq_check1   : Label     = null
var _dq_check2   : Label     = null
var _dq_check3   : Label     = null
var _dq_btn1     : Button    = null
var _dq_btn2     : Button    = null
var _dq_btn3     : Button    = null
# World Map page refs
var _world_node_panels  : Array          = []
var _wm_detail_screen     : Control = null
var _wm_detail_header     : ColorRect = null
var _wm_detail_name       : Label = null
var _wm_detail_status     : Label = null
var _wm_detail_stages     : Label = null
var _wm_detail_diff       : Label = null
var _wm_detail_desc       : Label = null
var _wm_detail_minimap    : Control = null
var _wm_detail_mod_box    : Control = null
var _wm_detail_start_btn  : Button = null
var _wm_selected_world  : int            = 0
var _wm_canvas          : Node2D          = null
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
var _hero_det_level_lbl      : Label     = null
var _hero_det_copies_lbl     : Label     = null
var _hero_det_xp_fill        : ColorRect = null
var _hero_det_talent_avail   : Label     = null
var _hero_det_talent_icons   : Control   = null
var _hero_det_allocate_btn   : Button    = null
var _hero_talent_panel       : Control   = null
var _hero_talent_hero_id     : String    = ""
var _hero_talent_dmg_count   : Label     = null
var _hero_talent_rng_count   : Label     = null
var _hero_talent_fr_count    : Label     = null
var _hero_talent_avail_count : Label     = null
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
var _tw_copies_lbl      : Label   = null
var _tw_buy_btn         : Button  = null
var _tw_buy_cost_lbl    : Label   = null
var _tw_current_def     : Dictionary = {}
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
# Floating in-world sell button
var _sell_btn          : Button = null
# Floating in-world hero info button
var _hero_info_btn        : Button = null
var _pending_hero_tower              = null
var _pending_hero_merge_cnt : int   = 0
# Debug tower-list panel
var _dbg_tower_panel   : Control = null

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
var _recipe_btn          : Button  = null
var _recipe_btn_badge    : Label   = null
var _recipe_row_refs     : Array   = []   # [{result_id, badge_lbl, craft_btn, mat_refs:[{panel,id}]}]

const TOKEN_ICON_SCR = preload("res://ui/TokenIcon.gd")

# ── Tower Gacha Shop ──────────────────────────────────────────────────────────
const GACHA_TOWER_SUMMON_COST    : int = 100
const GACHA_TOWER_SUMMON_10_COST : int = 950
const GACHA_HERO_SUMMON_COST     : int = 1000
const GACHA_HERO_SUMMON_10_COST  : int = 9500
const GACHA_SPIN_DURATION  : float = 2.5
const GACHA_CARD_W         : int   = 112
const GACHA_CARD_H         : int   = 160
const GACHA_CARD_SLOT      : int   = 120
const GACHA_STRIP_COUNT    : int   = 60
const GACHA_WIN_IDX        : int   = 48

const HERO_COMMON_IDS    : Array = ["knight", "ranger", "guardian"]
const HERO_RARE_IDS      : Array = ["arcane_scholar", "shadow_blade", "frost_herald"]
const HERO_EPIC_IDS      : Array = ["storm_knight", "blade_dancer", "venom_lord"]
const HERO_LEGENDARY_IDS : Array = ["dragon_sovereign", "void_walker", "phoenix_archer"]

var _gacha_spinning       : bool          = false
var _gacha_is_multi       : bool          = false
var _gacha_multi_results  : Array         = []
var _gacha_strip          : Control       = null
var _gacha_summon_btn     : Button        = null
var _gacha_summon_10_btn  : Button        = null
var _gacha_gem_lbl        : Label         = null
var _gacha_mode           : String        = "tower"
var _gacha_title_lbl      : Label         = null
var _gacha_tab_tower_btn  : Button        = null
var _gacha_tab_hero_btn   : Button        = null
var _gacha_tab_quest_btn  : Button        = null
var _quest_shop_panel     : Control       = null
var _dq_token_lbl         : Label         = null
var _relic_strip          : Control       = null
var _relic_tween          : Tween         = null
var _relic_spinning       : bool          = false
var _relic_spin_btn       : Button        = null
var _relic_pool_lbl       : Label         = null
var _relic_token_lbl      : Label         = null
var _relic_tok_coin       : Control       = null   # coin icon beside relic panel balance
var _gacha_relic_tok_lbl  : Label         = null   # shown in relic mode (replaces gem label)
var _gacha_relic_coin     : Control       = null   # coin icon in gacha header (relic mode)
var _relics_screen_tok_lbl : Label        = null   # token count shown top-right on My Relics screen
var _relics_screen_tok_coin: Control      = null
var _relic_result_pop     : Panel         = null
var _relic_screen         : Control       = null
var _relic_my_grid        : Control       = null
var _relic_unk_grid       : Control       = null
var _relic_info_popup     : Control       = null
var _relic_info_name      : Label         = null
var _relic_info_desc      : Label         = null
var _relic_detail_popup   : Panel         = null
var _relic_detail_backdrop: Control       = null
var _relic_detail_id      : String        = ""
var _relic_detail_icon    : Label         = null
var _relic_detail_name    : Label         = null
var _relic_detail_level   : Label         = null
var _relic_detail_cur     : Label         = null
var _relic_detail_next    : Label         = null
var _relic_detail_cost    : Label         = null
var _relic_detail_upg_btn : Button        = null
var _relic_detail_tok_lbl : Label         = null
var _gacha_result_panel   : Control       = null
var _gacha_result_inner   : Control       = null
var _gacha_result_title   : Label         = null
var _gacha_tween          : Tween         = null
var _gacha_result_prev    : Node          = null
var _gacha_result_name    : Label         = null
var _gacha_result_rar     : Label         = null
var _gacha_result_info    : Label         = null
var _gacha_result_lvlup   : Label         = null
var _gacha_result_card_s  : StyleBoxFlat  = null
var _gacha_result_ps      : StyleBoxFlat  = null
var _gacha_multi_panel    : Control       = null
var _gacha_wheel_glow     : ColorRect     = null

var _tower_card_refs      : Dictionary   = {}      # tower_id → {lvl_lbl, copies_lbl}

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
	# Wire hover after one frame so all button sizes are finalized
	call_deferred("_wire_all_button_hovers")


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

func hide_wave_btn() -> void:
	if is_instance_valid(wave_btn):
		wave_btn.visible = false

func show_wave_btn() -> void:
	if is_instance_valid(wave_btn):
		wave_btn.visible = true


func block_input_for_tile_anim() -> void:
	if is_instance_valid(_tile_anim_blocker):
		return
	_tile_anim_blocker              = ColorRect.new()
	_tile_anim_blocker.color        = Color.TRANSPARENT
	_tile_anim_blocker.size         = Vector2(1280, 720)
	_tile_anim_blocker.mouse_filter = MOUSE_FILTER_STOP
	_tile_anim_blocker.z_index      = 50
	add_child(_tile_anim_blocker)


func unblock_input_tile_anim() -> void:
	if is_instance_valid(_tile_anim_blocker):
		_tile_anim_blocker.queue_free()
		_tile_anim_blocker = null


func show_merge_tutorial(tower_screen_pos: Vector2) -> void:
	if is_instance_valid(_merge_tut_overlay):
		return
	_merge_tut_timescale = Engine.time_scale
	Engine.time_scale    = 0.0
	_merge_tut_step      = 1
	# Hide upgrade button so it can't be clicked before step 2 guides the player to it
	if is_instance_valid(_upgrade_popup_btn):
		_upgrade_popup_btn.visible = false

	const DARK := Color(0.04, 0.04, 0.10, 0.82)
	const GOLD := Color(1.0, 0.88, 0.28, 1.0)
	const TS   : int = 60

	var hl_pos  := tower_screen_pos - Vector2(TS * 0.5, TS * 0.5)
	var hl_rect := Rect2(hl_pos, Vector2(TS, TS))

	# Root — draw-only, no input blocking
	var ov := Control.new()
	ov.size         = Vector2(1280, 720)
	ov.mouse_filter = MOUSE_FILTER_IGNORE
	ov.z_index      = 200
	add_child(ov)
	_merge_tut_overlay = ov

	# Shared state for the lambdas so step 2 can update the spotlight
	_mt_state = {"hl": hl_rect}

	# Visual canvas — draws 4 dark panels + gold border + brackets
	var canvas := Control.new()
	canvas.size         = Vector2(1280, 720)
	canvas.mouse_filter = MOUSE_FILTER_IGNORE
	ov.add_child(canvas)
	_mt_canvas = canvas
	canvas.draw.connect(func():
		var r : Rect2 = _mt_state["hl"]
		if r.position.y > 0:
			canvas.draw_rect(Rect2(0.0, 0.0, 1280.0, r.position.y), DARK)
		if r.end.y < 720:
			canvas.draw_rect(Rect2(0.0, r.end.y, 1280.0, 720.0 - r.end.y), DARK)
		if r.position.x > 0:
			canvas.draw_rect(Rect2(0.0, r.position.y, r.position.x, r.size.y), DARK)
		if r.end.x < 1280:
			canvas.draw_rect(Rect2(r.end.x, r.position.y, 1280.0 - r.end.x, r.size.y), DARK)
		canvas.draw_rect(r, GOLD, false, 2.5)
		var ac := 14.0; var lw := 3.0
		canvas.draw_line(Vector2(r.position.x,  r.position.y), Vector2(r.position.x + ac, r.position.y), GOLD, lw)
		canvas.draw_line(Vector2(r.position.x,  r.position.y), Vector2(r.position.x, r.position.y + ac), GOLD, lw)
		canvas.draw_line(Vector2(r.end.x,        r.position.y), Vector2(r.end.x - ac,  r.position.y),    GOLD, lw)
		canvas.draw_line(Vector2(r.end.x,        r.position.y), Vector2(r.end.x,  r.position.y + ac),    GOLD, lw)
		canvas.draw_line(Vector2(r.position.x,  r.end.y),       Vector2(r.position.x + ac, r.end.y),     GOLD, lw)
		canvas.draw_line(Vector2(r.position.x,  r.end.y),       Vector2(r.position.x, r.end.y - ac),     GOLD, lw)
		canvas.draw_line(Vector2(r.end.x,        r.end.y),       Vector2(r.end.x - ac,  r.end.y),        GOLD, lw)
		canvas.draw_line(Vector2(r.end.x,        r.end.y),       Vector2(r.end.x,  r.end.y - ac),        GOLD, lw)
	)
	canvas.queue_redraw()

	# 4 transparent blockers surrounding the spotlight
	var b_top := ColorRect.new(); b_top.color = Color(0,0,0,0); b_top.mouse_filter = MOUSE_FILTER_STOP
	var b_bot := ColorRect.new(); b_bot.color = Color(0,0,0,0); b_bot.mouse_filter = MOUSE_FILTER_STOP
	var b_lft := ColorRect.new(); b_lft.color = Color(0,0,0,0); b_lft.mouse_filter = MOUSE_FILTER_STOP
	var b_rgt := ColorRect.new(); b_rgt.color = Color(0,0,0,0); b_rgt.mouse_filter = MOUSE_FILTER_STOP
	ov.add_child(b_top); ov.add_child(b_bot); ov.add_child(b_lft); ov.add_child(b_rgt)

	_mt_update_blockers = func(r: Rect2):
		b_top.position = Vector2(0.0, 0.0);      b_top.size = Vector2(1280.0, r.position.y)
		b_bot.position = Vector2(0.0, r.end.y);  b_bot.size = Vector2(1280.0, 720.0 - r.end.y)
		b_lft.position = Vector2(0.0, r.position.y); b_lft.size = Vector2(r.position.x, r.size.y)
		b_rgt.position = Vector2(r.end.x, r.position.y); b_rgt.size = Vector2(1280.0 - r.end.x, r.size.y)
	_mt_update_blockers.call(hl_rect)

	# Message panel — bottom-left, below the build grid
	var panel := Panel.new()
	panel.position = Vector2(20.0, 485.0)
	panel.size     = Vector2(390.0, 185.0)
	panel.z_index  = 202
	var ps := _rounded(Color(0.06, 0.06, 0.14, 0.97))
	ps.border_width_left  = 2; ps.border_width_right  = 2
	ps.border_width_top   = 2; ps.border_width_bottom = 2
	ps.border_color       = GOLD
	panel.add_theme_stylebox_override("panel", ps)
	ov.add_child(panel)
	_mt_panel = panel

	var title_lbl := _label("Upgrade — Combine 3 Copies", _font_bold, 16, GOLD)
	title_lbl.position = Vector2(14, 12); title_lbl.size = Vector2(362, 26)
	panel.add_child(title_lbl)

	var sep := ColorRect.new()
	sep.color = Color(1.0, 0.88, 0.28, 0.30); sep.position = Vector2(14, 42); sep.size = Vector2(362, 1)
	panel.add_child(sep)

	var body_lbl := _label(
		"You have 3 copies of the same tower!\n\nClick on the highlighted tower to select it.",
		_font_reg, 14, Color(0.92, 0.92, 0.96))
	body_lbl.position      = Vector2(14, 50)
	body_lbl.size          = Vector2(362, 130)
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(body_lbl)
	_mt_body_lbl = body_lbl


func _advance_merge_tutorial_step2() -> void:
	_merge_tut_step = 2
	tutorial_lock_unit_btns = true
	if not is_instance_valid(_upgrade_popup_btn):
		return
	# Reveal the button now that step 2 guides the player to it
	_upgrade_popup_btn.visible = true
	# Spotlight the floating "^ Upgrade" button above the tower with padding
	var pad      : float = 12.0
	var btn_pos  : Vector2 = _upgrade_popup_btn.position
	var btn_size : Vector2 = _upgrade_popup_btn.size
	var upg_rect := Rect2(btn_pos.x - pad, btn_pos.y - pad,
						  btn_size.x + pad * 2.0, btn_size.y + pad * 2.0)
	_mt_state["hl"] = upg_rect
	_mt_update_blockers.call(upg_rect)
	if is_instance_valid(_mt_canvas):
		_mt_canvas.queue_redraw()
	# Keep message panel at bottom-left, just update text
	if is_instance_valid(_mt_panel):
		_mt_panel.position = Vector2(20.0, 485.0)
		_mt_panel.size     = Vector2(390.0, 165.0)
	if is_instance_valid(_mt_body_lbl):
		_mt_body_lbl.text = "Click the [ ^ Upgrade ] button above the tower to combine all 3 copies into a random higher-rarity tower!"
		_mt_body_lbl.size = Vector2(362.0, 115.0)
	# Clicking the upgrade popup closes the tutorial
	if is_instance_valid(_upgrade_popup_btn):
		_upgrade_popup_btn.pressed.connect(_close_merge_tutorial, CONNECT_ONE_SHOT)


func show_special_tiles_tutorial(tile_rects: Dictionary) -> void:
	var ts : float = Engine.time_scale
	Engine.time_scale = 0.0

	const DARK := Color(0.04, 0.04, 0.10, 0.80)
	const TILE_COLORS := {
		"red":   Color(0.95, 0.06, 0.06, 1.0),
		"blue":  Color(0.08, 0.38, 1.0,  1.0),
		"green": Color(0.05, 0.88, 0.22, 1.0),
	}

	# Full-screen dark backdrop
	var ov := ColorRect.new()
	ov.color        = DARK
	ov.size         = Vector2(1280, 720)
	ov.mouse_filter = MOUSE_FILTER_STOP
	ov.z_index      = 200
	add_child(ov)

	# Colored tile highlights drawn over the backdrop
	var canvas := Control.new()
	canvas.size         = Vector2(1280, 720)
	canvas.mouse_filter = MOUSE_FILTER_IGNORE
	canvas.z_index      = 201
	ov.add_child(canvas)
	canvas.draw.connect(func():
		for kind in tile_rects:
			var r : Rect2  = tile_rects[kind]
			var c : Color  = TILE_COLORS.get(kind, Color.WHITE)
			canvas.draw_rect(r, Color(c.r, c.g, c.b, 0.18))
			canvas.draw_rect(r, c, false, 3.5)
			var ac := 10.0; var lw := 2.5
			canvas.draw_line(Vector2(r.position.x, r.position.y), Vector2(r.position.x + ac, r.position.y), c, lw)
			canvas.draw_line(Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.position.y + ac), c, lw)
			canvas.draw_line(Vector2(r.end.x,       r.position.y), Vector2(r.end.x - ac,  r.position.y),   c, lw)
			canvas.draw_line(Vector2(r.end.x,       r.position.y), Vector2(r.end.x, r.position.y + ac),    c, lw)
			canvas.draw_line(Vector2(r.position.x, r.end.y),       Vector2(r.position.x + ac, r.end.y),    c, lw)
			canvas.draw_line(Vector2(r.position.x, r.end.y),       Vector2(r.position.x, r.end.y - ac),    c, lw)
			canvas.draw_line(Vector2(r.end.x,       r.end.y),      Vector2(r.end.x - ac,  r.end.y),        c, lw)
			canvas.draw_line(Vector2(r.end.x,       r.end.y),      Vector2(r.end.x, r.end.y - ac),         c, lw)
	)
	canvas.queue_redraw()

	# Message panel — bottom-left
	var panel := Panel.new()
	panel.position = Vector2(20.0, 458.0)
	panel.size     = Vector2(430.0, 245.0)
	panel.z_index  = 202
	var ps := _rounded(Color(0.06, 0.06, 0.14, 0.97))
	ps.border_width_left  = 2; ps.border_width_right  = 2
	ps.border_width_top   = 2; ps.border_width_bottom = 2
	ps.border_color       = Color(1.0, 0.88, 0.28, 1.0)
	panel.add_theme_stylebox_override("panel", ps)
	ov.add_child(panel)

	var title := _label("Special Bonus Tiles Unlocked!", _font_bold, 17, Color(1.0, 0.88, 0.28))
	title.position = Vector2(14, 12); title.size = Vector2(402, 26)
	panel.add_child(title)

	var sep := ColorRect.new()
	sep.color = Color(1.0, 0.88, 0.28, 0.30); sep.position = Vector2(14, 42); sep.size = Vector2(402, 1)
	panel.add_child(sep)

	var sub := _label("Place a tower on a colored tile to gain its bonus:", _font_reg, 13, Color(0.75, 0.75, 0.85))
	sub.position = Vector2(14, 50); sub.size = Vector2(402, 20)
	panel.add_child(sub)

	var entries := [
		["🔴  Red Tile",   "+30%  Damage",       Color(1.0, 0.30, 0.30)],
		["🔵  Blue Tile",  "+35 px  Attack Range", Color(0.35, 0.60, 1.0)],
		["🟢  Green Tile", "+25%  Attack Speed",  Color(0.25, 0.90, 0.40)],
	]
	for i in entries.size():
		var name_lbl := _label(entries[i][0], _font_bold, 14, entries[i][2])
		name_lbl.position = Vector2(18, 78 + i * 44); name_lbl.size = Vector2(160, 22)
		panel.add_child(name_lbl)
		var stat_lbl := _label(entries[i][1], _font_reg, 14, Color(0.92, 0.92, 0.96))
		stat_lbl.position = Vector2(188, 78 + i * 44); stat_lbl.size = Vector2(230, 22)
		panel.add_child(stat_lbl)

	var got_it := Button.new()
	got_it.text       = "Got it!"
	got_it.position   = Vector2(310, 195)
	got_it.size       = Vector2(106, 38)
	got_it.focus_mode = FOCUS_NONE
	got_it.add_theme_font_override("font",           _font_bold)
	got_it.add_theme_font_size_override("font_size", 14)
	got_it.add_theme_color_override("font_color",    C_WHITE)
	var bs  := _rounded(Color(0.18, 0.38, 0.62))
	var bsh := _rounded(Color(0.26, 0.52, 0.84))
	got_it.add_theme_stylebox_override("normal",  bs)
	got_it.add_theme_stylebox_override("hover",   bsh)
	got_it.add_theme_stylebox_override("pressed", bs)
	got_it.add_theme_stylebox_override("focus",   bs)
	got_it.pressed.connect(func():
		Engine.time_scale = ts
		ov.queue_free()
		special_tiles_tutorial_closed.emit()
	)
	panel.add_child(got_it)


func _close_merge_tutorial() -> void:
	tutorial_lock_unit_btns = false
	Engine.time_scale = _merge_tut_timescale
	GameData.save_game()
	_mt_canvas   = null
	_mt_panel    = null
	_mt_body_lbl = null
	_mt_state.clear()
	if is_instance_valid(_merge_tut_overlay):
		_merge_tut_overlay.queue_free()
		_merge_tut_overlay = null


# ── Recipe tutorial ───────────────────────────────────────────────────────────

func show_recipe_tutorial() -> void:
	if is_instance_valid(_recipe_tut_overlay) or GameData.recipe_tutorial_seen:
		return
	if is_instance_valid(_merge_tut_overlay):
		return  # don't interrupt merge tutorial
	if not is_instance_valid(_recipe_btn):
		return

	_recipe_tut_ts   = Engine.time_scale
	Engine.time_scale = 0.0

	const DARK := Color(0.04, 0.04, 0.10, 0.82)
	const GOLD := Color(1.0, 0.88, 0.28, 1.0)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = MOUSE_FILTER_IGNORE
	root.z_index      = 150
	add_child(root)
	_recipe_tut_overlay = root

	# Build spotlight around recipe button
	var pad  : float  = 12.0
	var brect := Rect2(_recipe_btn.global_position, _recipe_btn.size)
	var hl    := Rect2(brect.position.x - pad, brect.position.y - pad,
					   brect.size.x + pad * 2.0, brect.size.y + pad * 2.0)

	# Canvas draws dark panels + gold border
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = MOUSE_FILTER_IGNORE
	root.add_child(canvas)
	canvas.draw.connect(func():
		canvas.draw_rect(Rect2(0, 0, 1280, hl.position.y), DARK)
		canvas.draw_rect(Rect2(0, hl.position.y, hl.position.x, hl.size.y), DARK)
		canvas.draw_rect(Rect2(hl.end.x, hl.position.y, 1280.0 - hl.end.x, hl.size.y), DARK)
		canvas.draw_rect(Rect2(0, hl.end.y, 1280, 720.0 - hl.end.y), DARK)
		canvas.draw_rect(hl, GOLD, false, 2.5)
	)

	# 4 input-blocking panels around spotlight
	var _mb := func(x: float, y: float, w: float, h: float):
		var c := ColorRect.new()
		c.color       = Color(0, 0, 0, 0)
		c.position    = Vector2(x, y)
		c.size        = Vector2(w, h)
		c.mouse_filter = MOUSE_FILTER_STOP
		root.add_child(c)
	_mb.call(0.0, 0.0, 1280.0, hl.position.y)
	_mb.call(0.0, hl.position.y, hl.position.x, hl.size.y)
	_mb.call(hl.end.x, hl.position.y, 1280.0 - hl.end.x, hl.size.y)
	_mb.call(0.0, hl.end.y, 1280.0, 720.0 - hl.end.y)

	# Message panel above the recipe button
	var C_PANEL_BG := Color(0.06, 0.08, 0.16, 0.97)
	var ps         := StyleBoxFlat.new()
	ps.bg_color    = C_PANEL_BG
	ps.corner_radius_top_left     = 8; ps.corner_radius_top_right    = 8
	ps.corner_radius_bottom_left  = 8; ps.corner_radius_bottom_right = 8
	ps.border_width_left = 2; ps.border_width_right  = 2
	ps.border_width_top  = 2; ps.border_width_bottom = 2
	ps.border_color = GOLD
	var msg_panel := Panel.new()
	msg_panel.position = Vector2(390.0, hl.position.y - 95.0)
	msg_panel.size     = Vector2(380.0, 82.0)
	msg_panel.add_theme_stylebox_override("panel", ps)
	msg_panel.mouse_filter = MOUSE_FILTER_IGNORE
	root.add_child(msg_panel)
	var msg_lbl := _label(
		"You can craft a Fusion Tower!\nClick the Recipe button to open the Recipe Book.",
		_font_bold, 15, Color(1.0, 0.95, 0.80))
	msg_lbl.position      = Vector2(10.0, 8.0)
	msg_lbl.size          = Vector2(360.0, 66.0)
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg_lbl.mouse_filter  = MOUSE_FILTER_IGNORE
	msg_panel.add_child(msg_lbl)

	# Advance to step 2 when recipe button is pressed
	_recipe_btn.pressed.connect(_advance_recipe_tutorial_step2, CONNECT_ONE_SHOT)


func _advance_recipe_tutorial_step2() -> void:
	# Modal just opened — wait one frame for layout
	await get_tree().process_frame

	if not is_instance_valid(_recipe_tut_overlay):
		return

	# Find first available craft button
	var craftable_ids : Dictionary = {}
	for f in _cached_fusions:
		craftable_ids[f["recipe"]["result"]] = true

	var first_craft_btn : Button = null
	for row in _recipe_row_refs:
		if craftable_ids.has(row["result_id"]) and is_instance_valid(row["craft_btn"]):
			first_craft_btn = row["craft_btn"]
			break

	if not is_instance_valid(first_craft_btn):
		_close_recipe_tutorial()
		return

	# Rebuild overlay for step 2 (spotlighting the craft button)
	if is_instance_valid(_recipe_tut_overlay):
		_recipe_tut_overlay.queue_free()
	_recipe_tut_overlay = null

	const DARK := Color(0.04, 0.04, 0.10, 0.82)
	const GOLD := Color(1.0, 0.88, 0.28, 1.0)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = MOUSE_FILTER_IGNORE
	root.z_index      = 200
	add_child(root)
	_recipe_tut_overlay = root

	var pad   : float  = 10.0
	var grect : Rect2  = first_craft_btn.get_global_rect()
	var hl    : Rect2  = Rect2(grect.position.x - pad, grect.position.y - pad,
							   grect.size.x + pad * 2.0, grect.size.y + pad * 2.0)

	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = MOUSE_FILTER_IGNORE
	root.add_child(canvas)
	canvas.draw.connect(func():
		canvas.draw_rect(Rect2(0, 0, 1280, hl.position.y), DARK)
		canvas.draw_rect(Rect2(0, hl.position.y, hl.position.x, hl.size.y), DARK)
		canvas.draw_rect(Rect2(hl.end.x, hl.position.y, 1280.0 - hl.end.x, hl.size.y), DARK)
		canvas.draw_rect(Rect2(0, hl.end.y, 1280, 720.0 - hl.end.y), DARK)
		canvas.draw_rect(hl, GOLD, false, 2.5)
	)

	var _mb := func(x: float, y: float, w: float, h: float):
		var c := ColorRect.new()
		c.color       = Color(0, 0, 0, 0)
		c.position    = Vector2(x, y)
		c.size        = Vector2(w, h)
		c.mouse_filter = MOUSE_FILTER_STOP
		root.add_child(c)
	_mb.call(0.0, 0.0, 1280.0, hl.position.y)
	_mb.call(0.0, hl.position.y, hl.position.x, hl.size.y)
	_mb.call(hl.end.x, hl.position.y, 1280.0 - hl.end.x, hl.size.y)
	_mb.call(0.0, hl.end.y, 1280.0, 720.0 - hl.end.y)

	# Message above the craft button
	var C_PANEL_BG := Color(0.06, 0.08, 0.16, 0.97)
	var ps         := StyleBoxFlat.new()
	ps.bg_color    = C_PANEL_BG
	ps.corner_radius_top_left     = 8; ps.corner_radius_top_right    = 8
	ps.corner_radius_bottom_left  = 8; ps.corner_radius_bottom_right = 8
	ps.border_width_left = 2; ps.border_width_right  = 2
	ps.border_width_top  = 2; ps.border_width_bottom = 2
	ps.border_color = GOLD
	var msg_panel := Panel.new()
	var mp_y      : float = maxf(hl.position.y - 80.0, 30.0)
	msg_panel.position = Vector2(clampf(hl.position.x - 80.0, 10.0, 900.0), mp_y)
	msg_panel.size     = Vector2(340.0, 68.0)
	msg_panel.add_theme_stylebox_override("panel", ps)
	msg_panel.mouse_filter = MOUSE_FILTER_IGNORE
	root.add_child(msg_panel)
	var msg_lbl := _label(
		"Click [ Craft! ] to fuse your towers into\na powerful Fusion Turret!",
		_font_bold, 15, Color(1.0, 0.95, 0.80))
	msg_lbl.position      = Vector2(10.0, 8.0)
	msg_lbl.size          = Vector2(320.0, 52.0)
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg_lbl.mouse_filter  = MOUSE_FILTER_IGNORE
	msg_panel.add_child(msg_lbl)

	first_craft_btn.pressed.connect(_close_recipe_tutorial, CONNECT_ONE_SHOT)


func _close_recipe_tutorial() -> void:
	GameData.recipe_tutorial_seen = true
	GameData.save_game()
	Engine.time_scale = _recipe_tut_ts
	if is_instance_valid(_recipe_tut_overlay):
		_recipe_tut_overlay.queue_free()
	_recipe_tut_overlay = null


# ── Public refresh ────────────────────────────────────────────────────────────

func refresh(gold: int, lives: int, stage: int, wave_in_stage: int, total_waves: int,
			 wave_active: bool, boss_active: bool, boss_timer: float,
			 can_next_wave: bool = false,
			 boss_hp: float = 0.0, boss_max_hp: float = 1.0) -> void:
	_current_gold = gold
	_gold_lbl.text  = "  💰 %d" % gold
	_lives_lbl.text = "  ❤️ %d" % lives
	if is_instance_valid(_recipe_btn):
		_recipe_btn.disabled = false
		_recipe_btn.text     = "📖  Recipe"

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
		_boss_timer_val   = boss_timer
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
		if boss_timer > 10.0:
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


func update_pull_cost(cost: int, discount: int = 0) -> void:
	if is_instance_valid(_roll_turret_btn):
		var suf : String = "  ★-%dg" % discount if discount > 0 else ""
		_roll_turret_btn.text = "🎲  Common Summon  (%dg%s)" % [cost, suf]


func update_rare_cost(cost: int, discount: int = 0) -> void:
	if is_instance_valid(_roll_rare_btn):
		var suf : String = "  ★-%dg" % discount if discount > 0 else ""
		_roll_rare_btn.text = "🎲  Rare Summon  (%dg%s)" % [cost, suf]


func update_epic_cost(cost: int, discount: int = 0) -> void:
	if is_instance_valid(_roll_epic_btn):
		var suf : String = "  ★-%dg" % discount if discount > 0 else ""
		_roll_epic_btn.text = "🎲  Epic Summon  (%dg%s)" % [cost, suf]


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
	_build_sell_btn()
	_build_rarity_modal()       # build modal before right panel so info_btn can reference it
	_build_right_panel()
	_build_wave_label()
	_build_hud_bar()
	_build_gem_hud()
	_build_loot_tab()
	_build_tower_info_panel()
	_build_notification()
	_build_game_over_screen()
	_build_run_results_screen()
	_build_upgrades_screen()
	_build_shop_screen()
	_build_world_map_screen()
	_build_heroes_screen()
	_build_towers_screen()
	_build_daily_quests_screen()
	_build_relics_screen()
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


func _build_loot_tab() -> void:
	const C_LOOT := Color(0.38, 0.22, 0.56)
	var btn := Button.new()
	btn.text       = "🎒  Loot"
	btn.position   = Vector2(1034, 602)
	btn.size       = Vector2(232, 46)
	btn.focus_mode = FOCUS_NONE
	btn.add_theme_font_override("font",           _font_bold)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color",    C_WHITE)
	btn.add_theme_stylebox_override("normal",  _btn_style(C_LOOT))
	btn.add_theme_stylebox_override("hover",   _btn_style(C_LOOT.lightened(0.12)))
	btn.add_theme_stylebox_override("pressed", _btn_style(C_LOOT.darkened(0.15)))
	btn.add_theme_stylebox_override("focus",   _btn_style(C_LOOT))
	btn.pressed.connect(_on_loot_btn_pressed)
	add_child(btn)

	# Red notification badge (top-right corner of the button)
	var badge_s := StyleBoxFlat.new()
	badge_s.bg_color = Color(0.90, 0.15, 0.15)
	badge_s.set_corner_radius_all(12)
	var badge_p := Panel.new()
	badge_p.add_theme_stylebox_override("panel", badge_s)
	badge_p.position     = Vector2(1034 + 232 - 13, 602 - 12)
	badge_p.size         = Vector2(26, 26)
	badge_p.mouse_filter = MOUSE_FILTER_IGNORE
	badge_p.visible      = false
	add_child(badge_p)
	_loot_badge_panel = badge_p

	var badge_lbl := _label("0", _font_bold, 13, C_WHITE)
	badge_lbl.position             = Vector2(0, 0)
	badge_lbl.size                 = Vector2(26, 26)
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	badge_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	badge_p.add_child(badge_lbl)
	_loot_badge_lbl = badge_lbl

	# Click-outside catcher — sits below the popup panel in z-order
	var catcher := ColorRect.new()
	catcher.color        = Color(0, 0, 0, 0)
	catcher.position     = Vector2.ZERO
	catcher.size         = Vector2(1280, 720)
	catcher.z_index      = 39
	catcher.mouse_filter = MOUSE_FILTER_STOP
	catcher.visible      = false
	add_child(catcher)
	_loot_catcher = catcher

	# Build the popup panel
	const PW : int = 484
	const PH : int = 566
	var panel := Panel.new()
	var ps    := StyleBoxFlat.new()
	ps.bg_color     = Color(0.07, 0.06, 0.13, 0.97)
	ps.border_color = Color(0.55, 0.35, 0.80, 0.65)
	ps.set_border_width_all(1)
	ps.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", ps)
	panel.position     = Vector2(1280 - PW - 8, 28)
	panel.size         = Vector2(PW, PH)
	panel.mouse_filter = MOUSE_FILTER_STOP
	panel.visible      = false
	panel.z_index      = 40
	add_child(panel)
	_loot_panel = panel

	catcher.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed \
				and ev.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN,
											MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			panel.visible  = false
			catcher.visible = false
	)

	var hdr_s := StyleBoxFlat.new()
	hdr_s.bg_color                   = Color(0.32, 0.16, 0.50)
	hdr_s.corner_radius_top_left     = 11
	hdr_s.corner_radius_top_right    = 11
	var hdr := Panel.new()
	hdr.add_theme_stylebox_override("panel", hdr_s)
	hdr.position     = Vector2(0, 0)
	hdr.size         = Vector2(PW, 52)
	hdr.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(hdr)

	var title := _label("🎒  Loot Bag", _font_bold, 22, C_WHITE)
	title.position             = Vector2(0, 10)
	title.size                 = Vector2(PW, 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(title)

	var close_btn := Button.new()
	close_btn.text       = "✕"
	close_btn.position   = Vector2(PW - 44, 8)
	close_btn.size       = Vector2(36, 36)
	close_btn.focus_mode = FOCUS_NONE
	close_btn.add_theme_font_override("font",           _font_bold)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color",    C_WHITE)
	close_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.28, 0.12, 0.42)))
	close_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.48, 0.18, 0.62)))
	close_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.18, 0.08, 0.28)))
	close_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.28, 0.12, 0.42)))
	close_btn.pressed.connect(func(): panel.visible = false)
	panel.add_child(close_btn)

	var empty_lbl := _label(
		"No cards yet.\nDefeat bosses at stage 8, 9, and 10\nto earn cards.",
		_font_reg, 15, Color(0.60, 0.58, 0.65))
	empty_lbl.position             = Vector2(0, PH / 2 - 40)
	empty_lbl.size                 = Vector2(PW, 80)
	empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	empty_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(empty_lbl)
	panel.set_meta("empty_lbl", empty_lbl)

	var scroll := ScrollContainer.new()
	scroll.position     = Vector2(10, 60)
	scroll.size         = Vector2(PW - 20, PH - 70)
	scroll.mouse_filter = MOUSE_FILTER_STOP
	scroll.visible      = false
	panel.add_child(scroll)
	panel.set_meta("scroll", scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	_loot_scroll_content = content


func _on_loot_btn_pressed() -> void:
	if not is_instance_valid(_loot_panel):
		return
	_loot_panel.visible = not _loot_panel.visible
	if is_instance_valid(_loot_catcher):
		_loot_catcher.visible = _loot_panel.visible
	if _loot_panel.visible:
		_loot_new_count = 0
		if is_instance_valid(_loot_badge_panel):
			_loot_badge_panel.visible = false


func show_boss_card_idle(cards: Array, boss_screen_pos: Vector2) -> void:
	const CHIP_W : float = 38.0
	# Chips are Node2D in the game scene (behind enemies) rather than HUD children.
	# get_parent() = CanvasLayer "UI", get_parent().get_parent() = Main scene root.
	var game_root : Node  = get_parent().get_parent()
	# Find the UI CanvasLayer index so chips can be inserted just before it —
	# same z_index=0 as enemies, but earlier in the tree means drawn behind them.
	var ui_node  : Node   = get_parent()           # the CanvasLayer "UI"
	var ui_idx   : int    = ui_node.get_index()

	var n := cards.size()
	for i in n:
		var card_data  : Dictionary = cards[i]
		var rarity     : String     = card_data["rarity"]
		var card_color : Color      = SummonSystem.RARITY_COLORS.get(rarity, Color.WHITE)

		var sym : String
		match rarity:
			"legendary": sym = "★"
			"epic":      sym = "✦"
			"rare":      sym = "◆"
			_:           sym = "●"

		var chip := _BossChip.new()
		chip.setup(card_color.darkened(0.55), card_color, sym, _font_bold)
		var spread_x : float = float(i - (n - 1) * 0.5) * (CHIP_W + 8)
		chip.position = boss_screen_pos + Vector2(spread_x, 0)
		chip.z_index  = 0
		game_root.add_child(chip)
		game_root.move_child(chip, ui_idx)   # render before enemies (behind them)

		# Idle float tween (gentle bob)
		var base_y  : float = chip.position.y
		var idle_tw := chip.create_tween().set_loops()
		idle_tw.tween_property(chip, "position:y", base_y - 9.0, 0.65) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		idle_tw.tween_property(chip, "position:y", base_y, 0.65) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		# Orbiting stars for epic and legendary
		var orbit_tws : Array = []
		if rarity in ["epic", "legendary"]:
			var num_stars : int    = 5 if rarity == "legendary" else 4
			var star_char : String = "★" if rarity == "legendary" else "✦"
			var star_clr  : Color  = Color(1.0, 0.95, 0.55, 0.95) if rarity == "legendary" \
				else Color(0.88, 0.72, 1.00, 0.90)
			var orbit_r : float = CHIP_W * 0.9
			for si in num_stars:
				var star := _StarNode.new()
				star.setup(star_char, star_clr, _font_bold)
				chip.add_child(star)
				var phase    : float = float(si) / float(num_stars) * TAU
				var star_ref := star
				var orb_tw   := chip.create_tween().set_loops()
				orb_tw.tween_method(func(a: float):
					if is_instance_valid(star_ref):
						star_ref.position = Vector2(cos(a) * orbit_r, sin(a) * orbit_r)
				, phase, phase + TAU, 2.4)
				orbit_tws.append(orb_tw)

		_idle_card_chips.append({"chip": chip, "card_data": card_data, "idle_tw": idle_tw, "orbit_tws": orbit_tws})


func fly_loot_cards_to_bag() -> void:
	const LOOT_CENTER := Vector2(1150, 625)
	var chips := _idle_card_chips.duplicate()
	_idle_card_chips.clear()
	for i in chips.size():
		var entry     : Dictionary = chips[i]
		var chip      : Node2D     = entry["chip"]
		var card_data : Dictionary = entry["card_data"]
		var idle_tw   : Tween      = entry["idle_tw"]
		if not is_instance_valid(chip):
			continue
		# Kill all looping tweens before starting the fly
		idle_tw.kill()
		for otw in entry.get("orbit_tws", []):
			if otw is Tween:
				otw.kill()
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_interval(i * 0.15)
		tw.tween_property(chip, "position", LOOT_CENTER, 1.0)
		tw.tween_callback(func():
			if is_instance_valid(chip):
				chip.queue_free()
			_loot_items.append(card_data)
			_loot_new_count += 1
			if is_instance_valid(_loot_badge_panel):
				_loot_badge_panel.visible = true
				_loot_badge_lbl.text      = str(_loot_new_count)
			_refresh_loot_panel()
		)


# Called on game-over/victory to immediately add all floating chips to loot
# without animation (process tweens are frozen when time_scale = 0).
func flush_idle_chips_to_loot() -> void:
	var chips := _idle_card_chips.duplicate()
	_idle_card_chips.clear()
	for entry in chips:
		var chip      : Node2D     = entry["chip"]
		var card_data : Dictionary = entry["card_data"]
		var idle_tw   : Tween      = entry["idle_tw"]
		idle_tw.kill()
		for otw in entry.get("orbit_tws", []):
			if otw is Tween:
				otw.kill()
		if is_instance_valid(chip):
			chip.queue_free()
		_loot_items.append(card_data)
		_loot_new_count += 1
	if _loot_new_count > 0 and is_instance_valid(_loot_badge_panel):
		_loot_badge_panel.visible = true
		_loot_badge_lbl.text      = str(_loot_new_count)
	_refresh_loot_panel()


func _refresh_loot_panel() -> void:
	if not is_instance_valid(_loot_scroll_content):
		return
	for child in _loot_scroll_content.get_children():
		child.queue_free()
	# Group items by id, keeping track of rarity and type
	var groups : Dictionary = {}
	for item in _loot_items:
		var id : String = item["id"]
		if not groups.has(id):
			groups[id] = {"type": item["type"], "id": id, "rarity": item["rarity"], "count": 0}
		groups[id]["count"] += 1
	var empty_lbl = _loot_panel.get_meta("empty_lbl") as Control
	var scroll    = _loot_panel.get_meta("scroll")    as Control
	if groups.is_empty():
		empty_lbl.visible = true
		scroll.visible    = false
		return
	empty_lbl.visible = false
	scroll.visible    = true
	for id in groups:
		_loot_scroll_content.add_child(_make_loot_card(groups[id]))


func _make_loot_card(entry: Dictionary) -> Control:
	const CW : int = 454; const CH : int = 84
	var id     : String     = entry["id"]
	var rarity : String     = entry["rarity"]
	var count  : int        = entry["count"]
	var is_hero: bool       = entry["type"] == "hero"
	var def    : Dictionary = SummonSystem.TURRET_DEFS.get(id, GameData.HERO_DEFS.get(id, {}))
	var rcol   : Color      = SummonSystem.RARITY_COLORS.get(rarity, C_WHITE)

	var card := Panel.new()
	var cs   := StyleBoxFlat.new()
	cs.bg_color     = Color(0.10, 0.09, 0.18)
	cs.border_color = Color(rcol.r, rcol.g, rcol.b, 0.72)
	cs.set_border_width_all(2)
	cs.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", cs)
	card.custom_minimum_size = Vector2(CW, CH)
	card.mouse_filter        = MOUSE_FILTER_IGNORE

	# Preview background + turret drawing
	var pbg := Panel.new()
	var pbs := StyleBoxFlat.new()
	pbs.bg_color = Color(0.06, 0.06, 0.12)
	pbs.set_corner_radius_all(6)
	pbg.add_theme_stylebox_override("panel", pbs)
	pbg.position     = Vector2(10, 10)
	pbg.size         = Vector2(62, 62)
	pbg.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(pbg)

	var prev := _TurretPreview.new()
	prev.turret_data = def
	prev.position    = Vector2(12, 8)
	card.add_child(prev)

	# Name
	var name_lbl := _label(def.get("name", id), _font_bold, 17, C_WHITE)
	name_lbl.position     = Vector2(84, 10)
	name_lbl.size         = Vector2(CW - 148, 26)
	name_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)

	# Rarity + type tag
	var tag   : String = "  (Hero)" if is_hero else "  (Tower)"
	var rar_lbl := _label(rarity.capitalize() + tag, _font_reg, 13, rcol)
	rar_lbl.position     = Vector2(84, 38)
	rar_lbl.size         = Vector2(CW - 148, 20)
	rar_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(rar_lbl)

	# Count badge (right side)
	var count_lbl := _label("x%d" % count, _font_bold, 28, C_GOLD)
	count_lbl.position             = Vector2(CW - 62, 22)
	count_lbl.size                 = Vector2(54, 40)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	card.add_child(count_lbl)

	# Bottom color stripe
	var stripe := ColorRect.new()
	stripe.color        = Color(rcol.r, rcol.g, rcol.b, 0.20)
	stripe.position     = Vector2(2, CH - 7)
	stripe.size         = Vector2(CW - 4, 5)
	stripe.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(stripe)

	return card


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
	_boss_timer_lbl.pivot_offset         = Vector2(46, 20)
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
	_recipe_btn = Button.new()
	_recipe_btn.text         = "📖  Recipe"
	_recipe_btn.position     = Vector2(507, 10)
	_recipe_btn.size         = Vector2(165, 50)
	_recipe_btn.pivot_offset = Vector2(82, 25)
	_recipe_btn.focus_mode   = FOCUS_NONE
	_recipe_btn.add_theme_font_override("font",           _font_bold)
	_recipe_btn.add_theme_font_size_override("font_size", 15)
	_recipe_btn.add_theme_color_override("font_color",    C_WHITE)
	_recipe_btn.add_theme_stylebox_override("normal",  _btn_style(C_RECIPE))
	_recipe_btn.add_theme_stylebox_override("hover",   _btn_style(C_RECIPE.lightened(0.12)))
	_recipe_btn.add_theme_stylebox_override("pressed", _btn_style(C_RECIPE.darkened(0.12)))
	_recipe_btn.add_theme_stylebox_override("focus",   _btn_style(C_RECIPE))
	_recipe_btn.pressed.connect(func():
		_tween_scale(_recipe_btn, Vector2(0.92, 0.92), 0.07)
		if is_instance_valid(_recipe_modal):
			_refresh_recipe_modal()
			_recipe_modal.visible = true
	)
	bar.add_child(_recipe_btn)

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
	var _ms := func(bg: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color                    = bg
		s.corner_radius_top_left      = 4
		s.corner_radius_top_right     = 4
		s.corner_radius_bottom_left   = 4
		s.corner_radius_bottom_right  = 4
		s.border_width_left           = 1
		s.border_width_right          = 1
		s.border_width_top            = 1
		s.border_width_bottom         = 1
		s.border_color                = Color(1.0, 1.0, 1.0, 0.18)
		s.content_margin_left         = 4
		s.content_margin_right        = 4
		s.content_margin_top          = 2
		s.content_margin_bottom       = 2
		return s
	var C_UPG := Color(0.42, 0.24, 0.06)
	_upgrade_popup_btn = Button.new()
	_upgrade_popup_btn.text       = "^ Upgrade"
	_upgrade_popup_btn.size       = Vector2(62, 20)
	_upgrade_popup_btn.focus_mode = FOCUS_NONE
	_upgrade_popup_btn.visible    = false
	_upgrade_popup_btn.z_index    = 20
	_upgrade_popup_btn.add_theme_font_override("font",           _font_bold)
	_upgrade_popup_btn.add_theme_font_size_override("font_size", 11)
	_upgrade_popup_btn.add_theme_color_override("font_color",    C_WHITE)
	_upgrade_popup_btn.add_theme_stylebox_override("normal",  _ms.call(C_UPG))
	_upgrade_popup_btn.add_theme_stylebox_override("hover",   _ms.call(C_UPG.lightened(0.18)))
	_upgrade_popup_btn.add_theme_stylebox_override("pressed", _ms.call(C_UPG.darkened(0.15)))
	_upgrade_popup_btn.add_theme_stylebox_override("focus",   _ms.call(C_UPG))
	_upgrade_popup_btn.pressed.connect(func(): upgrade_merge_requested.emit())
	add_child(_upgrade_popup_btn)


func show_upgrade_popup(world_pos: Vector2) -> void:
	if not is_instance_valid(_upgrade_popup_btn):
		return
	_upgrade_popup_btn.position = world_pos + Vector2(-43, -48)
	if is_instance_valid(_merge_tut_overlay) and _merge_tut_step == 1:
		# Keep button hidden until step 2 spotlights it
		_advance_merge_tutorial_step2()
		return
	_upgrade_popup_btn.visible = true


func hide_upgrade_popup() -> void:
	if tutorial_lock_unit_btns:
		return
	if is_instance_valid(_upgrade_popup_btn):
		_upgrade_popup_btn.visible = false


func is_upgrade_popup_clicked(click_pos: Vector2) -> bool:
	if not is_instance_valid(_upgrade_popup_btn) or not _upgrade_popup_btn.visible:
		return false
	return Rect2(_upgrade_popup_btn.position, _upgrade_popup_btn.size).has_point(click_pos)


func _build_sell_btn() -> void:
	var _ms := func(bg: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color                    = bg
		s.corner_radius_top_left      = 4
		s.corner_radius_top_right     = 4
		s.corner_radius_bottom_left   = 4
		s.corner_radius_bottom_right  = 4
		s.border_width_left           = 1
		s.border_width_right          = 1
		s.border_width_top            = 1
		s.border_width_bottom         = 1
		s.border_color                = Color(1.0, 1.0, 1.0, 0.18)
		s.content_margin_left         = 4
		s.content_margin_right        = 4
		s.content_margin_top          = 2
		s.content_margin_bottom       = 2
		return s

	_sell_btn = Button.new()
	_sell_btn.text       = "Sell +25g"
	_sell_btn.size       = Vector2(62, 20)
	_sell_btn.focus_mode = FOCUS_NONE
	_sell_btn.visible    = false
	_sell_btn.z_index    = 20
	_sell_btn.add_theme_font_override("font",           _font_bold)
	_sell_btn.add_theme_font_size_override("font_size", 11)
	_sell_btn.add_theme_color_override("font_color",    Color(0.20, 0.90, 0.35))
	_sell_btn.add_theme_stylebox_override("normal",  _ms.call(Color(0.08, 0.22, 0.10)))
	_sell_btn.add_theme_stylebox_override("hover",   _ms.call(Color(0.14, 0.34, 0.16)))
	_sell_btn.add_theme_stylebox_override("pressed", _ms.call(Color(0.05, 0.14, 0.07)))
	_sell_btn.add_theme_stylebox_override("focus",   _ms.call(Color(0.08, 0.22, 0.10)))
	_sell_btn.pressed.connect(func(): sell_tower_requested.emit())
	add_child(_sell_btn)

	_hero_info_btn = Button.new()
	_hero_info_btn.text       = "i"
	_hero_info_btn.size       = Vector2(20, 20)
	_hero_info_btn.focus_mode = FOCUS_NONE
	_hero_info_btn.visible    = false
	_hero_info_btn.z_index    = 20
	_hero_info_btn.add_theme_font_override("font",           _font_bold)
	_hero_info_btn.add_theme_font_size_override("font_size", 11)
	_hero_info_btn.add_theme_color_override("font_color",    Color(0.50, 0.85, 1.00))
	_hero_info_btn.add_theme_stylebox_override("normal",  _ms.call(Color(0.06, 0.14, 0.28)))
	_hero_info_btn.add_theme_stylebox_override("hover",   _ms.call(Color(0.12, 0.24, 0.42)))
	_hero_info_btn.add_theme_stylebox_override("pressed", _ms.call(Color(0.03, 0.08, 0.18)))
	_hero_info_btn.add_theme_stylebox_override("focus",   _ms.call(Color(0.06, 0.14, 0.28)))
	_hero_info_btn.pressed.connect(func():
		if is_instance_valid(_pending_hero_tower):
			show_tower_info(_pending_hero_tower, _pending_hero_merge_cnt)
			if not GameData.tutorial_complete:
				tower_detail_opened_tutorial.emit()
	)
	add_child(_hero_info_btn)


func show_unit_btns(world_pos: Vector2, tower, merge_cnt: int) -> void:
	if not is_instance_valid(_sell_btn) or not is_instance_valid(_hero_info_btn):
		return
	_pending_hero_tower     = tower
	_pending_hero_merge_cnt = merge_cnt
	const BH  : int = 20
	const SW  : int = 62
	const IW  : int = 20
	const GAP : int = 4
	var bx : float = world_pos.x - (SW + GAP + IW) / 2.0
	var by : float = world_pos.y + 22.0
	_sell_btn.size     = Vector2(SW, BH)
	_sell_btn.position = Vector2(bx, by)
	_sell_btn.visible  = true
	_sell_btn.disabled = not GameData.tutorial_complete
	_hero_info_btn.size     = Vector2(IW, BH)
	_hero_info_btn.position = Vector2(bx + SW + GAP, by)
	_hero_info_btn.visible  = true
	_hero_info_btn.disabled = tutorial_block_info_btn
	if not GameData.tutorial_complete:
		var ib_rect := Rect2(_hero_info_btn.position.x - 6, _hero_info_btn.position.y - 6, IW + 12, BH + 12)
		tower_selected_tutorial.emit(ib_rect)


func is_tower_info_visible() -> bool:
	return is_instance_valid(_info_panel) and _info_panel.visible


func show_sell_btn(world_pos: Vector2) -> void:
	if not is_instance_valid(_sell_btn):
		return
	_sell_btn.position = world_pos + Vector2(-_sell_btn.size.x / 2.0, 28)
	_sell_btn.visible  = true


func hide_sell_btn() -> void:
	if tutorial_lock_unit_btns:
		return
	if is_instance_valid(_sell_btn):
		_sell_btn.visible = false
	if is_instance_valid(_hero_info_btn):
		_hero_info_btn.visible = false


func is_sell_btn_clicked(click_pos: Vector2) -> bool:
	if is_instance_valid(_sell_btn) and _sell_btn.visible:
		if Rect2(_sell_btn.position, _sell_btn.size).has_point(click_pos):
			return true
	if is_instance_valid(_hero_info_btn) and _hero_info_btn.visible:
		if Rect2(_hero_info_btn.position, _hero_info_btn.size).has_point(click_pos):
			return true
	return false


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


func _process(delta: float) -> void:
	if is_instance_valid(_buff_tooltip) and _buff_tooltip.visible:
		var mp : Vector2 = get_global_mouse_position()
		var tx : float = clampf(mp.x + 14.0, 0.0, 1280.0 - _buff_tooltip.size.x)
		var ty : float = clampf(mp.y - _buff_tooltip.size.y - 6.0, 0.0, 720.0 - _buff_tooltip.size.y)
		_buff_tooltip.position = Vector2(tx, ty)

	# Boss timer urgency animation + smooth decimal countdown
	if is_instance_valid(_boss_timer_lbl) and _boss_bar.visible \
			and _boss_timer_val > 0.0 and _boss_timer_val <= 10.0:
		# Decrement locally each frame so the display is smooth between refresh() calls
		_boss_timer_val = maxf(_boss_timer_val - delta, 0.0)
		_boss_timer_lbl.text = "⏱  %.2f s" % _boss_timer_val

		var ms   : float = float(Time.get_ticks_msec())
		var t    : float = clampf(1.0 - _boss_timer_val / 10.0, 0.0, 1.0)
		var t_sq : float = t * t

		# Color: orange → intense red
		_boss_timer_lbl.add_theme_color_override("font_color",
				Color(1.0, 0.65, 0.30).lerp(Color(1.0, 0.10, 0.10), t))

		# Scale: base grows 1.0 → 1.5 as timer approaches 0, small pulse on top
		var pulse_raw  : float = sin(ms * lerp(0.0045, 0.0095, t))
		var pulse_ease : float = 0.5 + 0.5 * (pulse_raw * abs(pulse_raw))
		var pulse_s    : float = lerp(1.0, 1.5, t_sq) + lerp(0.0, 0.10, t_sq) * pulse_ease
		_boss_timer_lbl.scale = Vector2(pulse_s, pulse_s)

		# Shake: subtle, two overlapping sine waves, amplitude grows with t²
		var shake_amp : float = t_sq * 2.0
		var sx : float = sin(ms * 0.071) * shake_amp + sin(ms * 0.033) * shake_amp * 0.35
		var sy : float = cos(ms * 0.089) * shake_amp * 0.55
		_boss_timer_lbl.position = Vector2(518.0, 0.0) + Vector2(sx, sy)
	elif is_instance_valid(_boss_timer_lbl):
		_boss_timer_lbl.add_theme_color_override("font_color", Color(1.0, 0.65, 0.30))
		_boss_timer_lbl.scale    = Vector2.ONE
		_boss_timer_lbl.position = Vector2(518.0, 0.0)



func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if is_instance_valid(_rarity_modal) and _rarity_modal.visible:
			_rarity_modal.visible = false
			get_viewport().set_input_as_handled()


func _on_speed_btn_pressed() -> void:
	_tween_scale(speed_btn, Vector2(0.92, 0.92), 0.07)
	_speed_factor = 1.0 if _speed_factor == 2.0 else 2.0
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
		tb.position   = Vector2(i * 124, 4)
		tb.size       = Vector2(118, 30)
		tb.focus_mode = FOCUS_NONE
		tb.add_theme_font_override("font",           _font_bold)
		tb.add_theme_font_size_override("font_size", 12)
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

	var C_COMMON_BTN := Color(0.30, 0.30, 0.26)
	var common_btn := Button.new()
	common_btn.text         = "🎲  Common Summon  (40g)"
	common_btn.position     = Vector2(8, 66)
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
	rare_hdr.position             = Vector2(0, 128)
	rare_hdr.size                 = Vector2(w, 20)
	rare_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(rare_hdr)

	var C_RARE_BTN := Color(0.12, 0.28, 0.58)
	var rare_btn := Button.new()
	rare_btn.text         = "🎲  Rare Summon  (100g)"
	rare_btn.position     = Vector2(8, 150)
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
	epic_hdr.position             = Vector2(0, 212)
	epic_hdr.size                 = Vector2(w, 20)
	epic_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(epic_hdr)

	var C_EPIC_BTN := Color(0.35, 0.12, 0.55)
	var epic_btn := Button.new()
	epic_btn.text         = "🎲  Epic Summon  (250g)"
	epic_btn.position     = Vector2(8, 234)
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
	dbg_btn.visible = DEBUG
	page.add_child(dbg_btn)

	# ── Debug: Summon Tower panel toggle ──────────────────────────────────────
	var summon_btn := Button.new()
	summon_btn.text         = "🐛  Summon Tower (Debug)"
	summon_btn.position     = Vector2(8, 392)
	summon_btn.size         = Vector2(w - 16, 36)
	summon_btn.focus_mode   = FOCUS_NONE
	summon_btn.add_theme_font_override("font",           _font_reg)
	summon_btn.add_theme_font_size_override("font_size", 14)
	summon_btn.add_theme_color_override("font_color",    Color(0.55, 0.75, 1.00))
	summon_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.08, 0.12, 0.28)))
	summon_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.12, 0.18, 0.38)))
	summon_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.06, 0.08, 0.20)))
	summon_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.08, 0.12, 0.28)))
	summon_btn.pressed.connect(func(): _toggle_dbg_tower_panel())
	summon_btn.visible = DEBUG
	page.add_child(summon_btn)

	# ── Debug: Skip to Stage 8 ────────────────────────────────────────────────
	var skip_btn := Button.new()
	skip_btn.text         = "🐛  Skip to Stage 8 (Debug)"
	skip_btn.position     = Vector2(8, 436)
	skip_btn.size         = Vector2(w - 16, 36)
	skip_btn.focus_mode   = FOCUS_NONE
	skip_btn.add_theme_font_override("font",           _font_reg)
	skip_btn.add_theme_font_size_override("font_size", 14)
	skip_btn.add_theme_color_override("font_color",    Color(1.00, 0.75, 0.30))
	skip_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.24, 0.14, 0.04)))
	skip_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.32, 0.20, 0.06)))
	skip_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.18, 0.10, 0.02)))
	skip_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.24, 0.14, 0.04)))
	skip_btn.pressed.connect(func():
		_tween_scale(skip_btn, Vector2(0.95, 0.95), 0.06)
		debug_skip_stage_requested.emit(8)
	)
	skip_btn.visible = DEBUG
	page.add_child(skip_btn)

	# Connect ℹ to open the centered rarity modal
	info_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if is_instance_valid(_rarity_modal):
				_rarity_modal.visible = true
				_refresh_rarity_modal()
	)



# ── Debug tower-list panel ────────────────────────────────────────────────────

func _toggle_dbg_tower_panel() -> void:
	if is_instance_valid(_dbg_tower_panel):
		_dbg_tower_panel.visible = not _dbg_tower_panel.visible
		return
	_dbg_tower_panel = _build_dbg_tower_panel()
	add_child(_dbg_tower_panel)


func _build_dbg_tower_panel() -> Control:
	# Floating panel — positioned to the left of the sidebar
	var panel := Panel.new()
	panel.z_index = 50
	var vp := get_viewport_rect().size
	panel.position = Vector2(vp.x - 530, 60)
	panel.size     = Vector2(240, 500)
	var ps := StyleBoxFlat.new()
	ps.bg_color          = Color(0.08, 0.06, 0.12, 0.97)
	ps.border_color      = Color(0.40, 0.55, 1.00, 0.80)
	ps.border_width_left = 2; ps.border_width_right  = 2
	ps.border_width_top  = 2; ps.border_width_bottom = 2
	ps.corner_radius_top_left     = 6; ps.corner_radius_top_right    = 6
	ps.corner_radius_bottom_left  = 6; ps.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", ps)

	# Title bar
	var title_lbl := Label.new()
	title_lbl.text      = "🐛 Summon Tower"
	title_lbl.position  = Vector2(8, 8)
	title_lbl.size      = Vector2(180, 22)
	title_lbl.add_theme_font_override("font",           _font_bold)
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color",    Color(0.60, 0.80, 1.00))
	panel.add_child(title_lbl)

	# Close button
	var close_btn := Button.new()
	close_btn.text       = "✕"
	close_btn.position   = Vector2(204, 4)
	close_btn.size       = Vector2(30, 28)
	close_btn.focus_mode = FOCUS_NONE
	close_btn.add_theme_font_override("font",           _font_bold)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.add_theme_color_override("font_color",    Color(1.0, 0.4, 0.4))
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.22, 0.08, 0.08, 0.80)
	cs.corner_radius_top_left = 4; cs.corner_radius_top_right    = 4
	cs.corner_radius_bottom_left = 4; cs.corner_radius_bottom_right = 4
	close_btn.add_theme_stylebox_override("normal",  cs)
	close_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.40, 0.10, 0.10)))
	close_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.20, 0.05, 0.05)))
	close_btn.add_theme_stylebox_override("focus",   cs)
	close_btn.pressed.connect(func():
		if is_instance_valid(_dbg_tower_panel):
			_dbg_tower_panel.visible = false
	)
	panel.add_child(close_btn)

	# Separator
	var sep := HSeparator.new()
	sep.position = Vector2(4, 36)
	sep.size     = Vector2(232, 4)
	panel.add_child(sep)

	# Scroll container for tower list
	var scroll := ScrollContainer.new()
	scroll.position                    = Vector2(4, 44)
	scroll.size                        = Vector2(232, 448)
	scroll.horizontal_scroll_mode      = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(220, 0)
	vbox.add_theme_constant_override("separation", 3)
	scroll.add_child(vbox)

	# Rarity order for display grouping
	var rarity_order := ["common", "rare", "epic", "legendary", "fusion"]
	var rarity_colors := {
		"common":    Color(0.75, 0.75, 0.75),
		"rare":      Color(0.30, 0.65, 1.00),
		"epic":      Color(0.75, 0.35, 1.00),
		"legendary": Color(1.00, 0.78, 0.10),
		"fusion":    Color(0.20, 1.00, 0.85),
	}

	for rar in rarity_order:
		# Rarity header
		var hdr := Label.new()
		hdr.text = rar.to_upper()
		hdr.add_theme_font_override("font",           _font_bold)
		hdr.add_theme_font_size_override("font_size", 11)
		hdr.add_theme_color_override("font_color",    rarity_colors.get(rar, C_WHITE))
		hdr.custom_minimum_size = Vector2(220, 18)
		vbox.add_child(hdr)

		# One button per tower in this rarity
		for id in SummonSystem.TURRET_DEFS:
			var td : Dictionary = SummonSystem.TURRET_DEFS[id]
			if td.get("rarity", "") != rar:
				continue
			var btn := Button.new()
			btn.text            = td.get("name", id)
			btn.custom_minimum_size = Vector2(220, 28)
			btn.focus_mode      = FOCUS_NONE
			btn.add_theme_font_override("font",           _font_reg)
			btn.add_theme_font_size_override("font_size", 13)
			btn.add_theme_color_override("font_color",    C_WHITE)
			btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.12, 0.10, 0.18)))
			btn.add_theme_stylebox_override("hover",   _btn_style(rarity_colors.get(rar, C_WHITE).darkened(0.55)))
			btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.06, 0.05, 0.10)))
			btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.12, 0.10, 0.18)))
			var captured_id : String = id
			btn.pressed.connect(func(): debug_summon_requested.emit(captured_id))
			vbox.add_child(btn)

	return panel


# ── Upgrades Tab (Gacha) ──────────────────────────────────────────────────────

func _fill_upgrades_tab(page: Control) -> void:
	var w := 248
	var title := _label("✨  Boss Rewards", _font_bold, 16, C_GOLD)
	title.position             = Vector2(0, 6)
	title.size                 = Vector2(w, 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(title)

	var div := ColorRect.new()
	div.color = Color(1,1,1,0.08); div.position = Vector2(4, 34); div.size = Vector2(w - 8, 2)
	page.add_child(div)

	var empty_lbl := _label("No rewards yet.\nDefeat a boss to earn buffs.", _font_reg, 13, C_DIM)
	empty_lbl.position      = Vector2(0, 44)
	empty_lbl.size          = Vector2(w, 50)
	empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(empty_lbl)
	_buff_empty_lbl = empty_lbl

	var scroll := ScrollContainer.new()
	scroll.position               = Vector2(0, 46)
	scroll.size                   = Vector2(w, 502)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	page.add_child(scroll)
	_buff_history_scroll = scroll

	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	scroll.add_child(flow)
	_buff_history_flow = flow

	# Shared hover tooltip (added to root HUD so it floats above everything)
	if not is_instance_valid(_buff_tooltip):
		_build_buff_tooltip()


func _build_buff_tooltip() -> void:
	var tip := Panel.new()
	tip.z_index   = 200
	tip.visible   = false
	tip.size      = Vector2(200, 70)
	tip.mouse_filter = MOUSE_FILTER_IGNORE
	tip.add_theme_stylebox_override("panel", _rounded(Color(0.10, 0.08, 0.06, 0.97)))
	add_child(tip)
	_buff_tooltip = tip

	_buff_tooltip_name = _label("", _font_bold, 13, C_WHITE)
	_buff_tooltip_name.position      = Vector2(8, 6)
	_buff_tooltip_name.size          = Vector2(184, 22)
	_buff_tooltip_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_child(_buff_tooltip_name)

	_buff_tooltip_desc = _label("", _font_reg, 12, C_DIM)
	_buff_tooltip_desc.position      = Vector2(8, 28)
	_buff_tooltip_desc.size          = Vector2(184, 60)
	_buff_tooltip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_child(_buff_tooltip_desc)


func refresh_buff_history() -> void:
	if not is_instance_valid(_buff_history_flow):
		return
	for child in _buff_history_flow.get_children():
		child.queue_free()

	var has_buffs : bool = not GameData.chosen_buffs.is_empty()
	if is_instance_valid(_buff_empty_lbl):
		_buff_empty_lbl.visible = not has_buffs
	if not has_buffs:
		return

	var rarity_colors := {
		"common": Color(0.80, 0.80, 0.80),
		"rare":   Color(0.25, 0.55, 1.00),
		"epic":   Color(0.72, 0.25, 0.90),
	}
	const ICON_MAP : Dictionary = {
		"dmg_2":"⚔", "dmg_5":"⚔", "dmg_8":"⚔",
		"fire_rate_5":"⚡", "fire_rate_15":"⚡", "fire_rate_30":"⚡",
		"gold_10":"🪙", "summon_cost_10g":"💰", "lives_5":"❤️",
		"boss_dmg_25":"💀", "boss_dmg_50":"💀",
		"enemy_slow_10":"❄️", "enemy_slow_25":"❄️",
		"dot_1":"🧪", "dot_3":"🧪",
	}
	const SZ := 56

	# Group buffs by id+rarity key, count duplicates
	var groups : Dictionary = {}
	for buff in GameData.chosen_buffs:
		var key : String = buff.get("id", "") + "|" + buff.get("rarity", "common")
		if groups.has(key):
			groups[key]["count"] += 1
		else:
			groups[key] = {"buff": buff, "count": 1}

	for key in groups:
		var entry  = groups[key]
		var buff   = entry["buff"]
		var count  : int    = entry["count"]
		var bid    : String = buff.get("id", "")
		var rc     : Color  = rarity_colors.get(buff.get("rarity", "common"), C_WHITE)
		var icon   : String = ICON_MAP.get(bid, "✨")

		var cell_style := _rounded(Color(0.14, 0.12, 0.10, 1.0))
		cell_style.border_width_left   = 3
		cell_style.border_width_right  = 3
		cell_style.border_width_top    = 3
		cell_style.border_width_bottom = 3
		cell_style.border_color        = rc

		var cell := Panel.new()
		cell.custom_minimum_size = Vector2(SZ, SZ)
		cell.mouse_filter        = MOUSE_FILTER_STOP
		cell.add_theme_stylebox_override("panel", cell_style)
		_buff_history_flow.add_child(cell)

		# Emoji icon centred in the square
		var icon_lbl := _label(icon, _font_bold, 26, C_WHITE)
		icon_lbl.position             = Vector2(0, 4)
		icon_lbl.size                 = Vector2(SZ, SZ - 8)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		icon_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
		cell.add_child(icon_lbl)

		# Counter badge bottom-right when picked more than once
		if count > 1:
			var badge_style := _rounded(Color(0.05, 0.05, 0.05, 0.88))
			badge_style.border_width_left   = 1
			badge_style.border_width_right  = 1
			badge_style.border_width_top    = 1
			badge_style.border_width_bottom = 1
			badge_style.border_color        = rc
			var badge := Panel.new()
			badge.size         = Vector2(24, 18)
			badge.position     = Vector2(SZ - 24, SZ - 18)
			badge.mouse_filter = MOUSE_FILTER_IGNORE
			badge.add_theme_stylebox_override("panel", badge_style)
			cell.add_child(badge)
			var cnt_lbl := _label("%dx" % count, _font_bold, 11, C_WHITE)
			cnt_lbl.position             = Vector2(0, -1)
			cnt_lbl.size                 = Vector2(24, 18)
			cnt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cnt_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			cnt_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
			badge.add_child(cnt_lbl)

		# Hover tooltip
		var bname : String = buff.get("name", "")
		var bdesc : String = buff.get("desc", "")
		cell.mouse_entered.connect(func():
			if not is_instance_valid(_buff_tooltip):
				return
			_buff_tooltip_name.text = bname
			_buff_tooltip_desc.text = bdesc
			_buff_tooltip.size      = Vector2(200, 90)
			_buff_tooltip.visible   = true
		)
		cell.mouse_exited.connect(func():
			if is_instance_valid(_buff_tooltip):
				_buff_tooltip.visible = false
		)


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

	# Counter badge — top-right corner, hidden when not applicable
	var counter_bg_style := _rounded(Color(0.10, 0.10, 0.14, 0.90))
	counter_bg_style.border_width_left   = 1
	counter_bg_style.border_width_right  = 1
	counter_bg_style.border_width_top    = 1
	counter_bg_style.border_width_bottom = 1
	counter_bg_style.border_color        = Color(1.0, 0.75, 0.20, 0.80)
	_info_counter_bg = Panel.new()
	_info_counter_bg.position     = Vector2(PW - 74, 34)
	_info_counter_bg.size         = Vector2(68, 22)
	_info_counter_bg.mouse_filter = MOUSE_FILTER_IGNORE
	_info_counter_bg.visible      = false
	_info_counter_bg.add_theme_stylebox_override("panel", counter_bg_style)
	panel.add_child(_info_counter_bg)
	_info_counter_lbl = _label("", _font_bold, 12, Color(1.0, 0.85, 0.30))
	_info_counter_lbl.position             = Vector2(0, 4)
	_info_counter_lbl.size                 = Vector2(68, 14)
	_info_counter_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_counter_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	_info_counter_bg.add_child(_info_counter_lbl)

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
	_info_dmg_lbl.position             = Vector2(100, 146)
	_info_dmg_lbl.size                 = Vector2(PW - 108, 20)
	_info_dmg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info_dmg_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(_info_dmg_lbl)

	_info_rng_lbl = _label("", _font_bold, 14, C_WHITE)
	_info_rng_lbl.position             = Vector2(100, 168)
	_info_rng_lbl.size                 = Vector2(PW - 108, 20)
	_info_rng_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info_rng_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(_info_rng_lbl)

	_info_rate_lbl = _label("", _font_bold, 14, C_WHITE)
	_info_rate_lbl.position             = Vector2(100, 190)
	_info_rate_lbl.size                 = Vector2(PW - 108, 20)
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
	var wt_dmg      : float  = tower._wt_dmg_bonus
	var wt_rate     : float  = tower._wt_rate_bonus
	var herc_bonus  : float  = tower._hercules_wave_bonus
	var relic_dmg   : float  = tower._relic_dmg_bonus
	var relic_rate  : float  = tower._relic_rate_bonus
	var eff_dmg     : float  = (tower.damage + GameData.buff_damage_flat + wt_dmg + herc_bonus + relic_dmg) * dmg_mult * (1.0 + tower._tile_dmg_bonus)
	var base_rate   : float  = d.get("fire_rate", tower.fire_rate)
	var eff_rate    : float  = base_rate * spd_mult * (1.0 + wt_rate + tower._ranger_rate_bonus + tower._frost_speed_bonus + tower._tile_spd_bonus + relic_rate)
	var dmg_pct     : float  = (dmg_mult - 1.0 + tower._tile_dmg_bonus) * 100.0
	var dmg_suffix  : String = ""
	var dmg_tags    : Array  = []
	if dmg_pct > 0.0:           dmg_tags.append("+%.0f%%" % dmg_pct)
	if wt_dmg  > 0.0:           dmg_tags.append("🌳")
	if tower._tile_dmg_bonus > 0.0: dmg_tags.append("🔴")
	if relic_dmg > 0.0:         dmg_tags.append("★")
	if not dmg_tags.is_empty(): dmg_suffix = " (%s)" % ", ".join(dmg_tags)
	var spd_pct     : float  = (spd_mult - 1.0 + tower._tile_spd_bonus) * 100.0
	var rate_suffix : String = ""
	var rate_tags   : Array  = []
	if spd_pct > 0.0:               rate_tags.append("+%.0f%%" % spd_pct)
	if wt_rate  > 0.0:              rate_tags.append("🌳")
	if tower._tile_spd_bonus > 0.0: rate_tags.append("🟢")
	if relic_rate > 0.0:            rate_tags.append("★")
	if not rate_tags.is_empty():    rate_suffix = " (%s)" % ", ".join(rate_tags)
	_info_dmg_lbl.text   = "%.0f" % eff_dmg + dmg_suffix
	_info_rng_lbl.text   = "%.0f px" % tower.attack_range + (" (🔵)" if tower._tile_range_bonus > 0.0 else "")
	_info_rate_lbl.text  = "%.1f / s" % eff_rate + rate_suffix
	var eff_map : Dictionary = {
		"none":          "Standard single-target shot. No bonus effect.",
		"focused_shot":  "Consecutive hits on the same target stacks +50% damage up to 2x. Resets when switching targets.",
		"dual_shot":     "Fires at 2 separate enemies simultaneously each attack.",
		"chain":         "Hits primary target at full damage, then chains to 2 nearby enemies at 50% damage.",
		"aoe":           "Hits all enemies currently in range with each shot.",
		"aoe_burst":     "Explosive shot hits up to 5 enemies in range.",
		"melee_cleave":  "Every 3rd hit strikes all enemies in range instead of just the primary target.",
		"bleed_aoe":     "Every hit damages all enemies in range and applies a bleed stack (max 3 stacks). Each stack deals base damage per second.",
		"slow_zone":     "Normal shots deal damage. Every 4th shot drops an ice zone that slows enemies by 55% for 3 seconds.",
		"poison_debuff": "Poisons the target — poisoned enemies take 10% more damage from all sources for 5s. Refreshes on re-hit. Prioritizes un-poisoned enemies.",
		"execute_shot":  "Damage scales with enemy's current HP. Full HP = 2× base damage. Scales down linearly to 1× at 0 HP.",
		"knight_slam":   "Every 3rd hit throws 2 swords at nearby enemies and knocks them back. Knockback has no effect on bosses.",
		"ranger_fire_aura": "Every 5th hit grants towers 1 tile away +10% fire rate for 3 seconds.",
		"hp_strike":     "Deals base damage plus 1% of the target's current HP as bonus damage. Bonus does not apply to boss enemies.",
		"poison_cloud":  "Hits all enemies in range each shot. Spawns a persistent poison cloud that slowly expands along the path, dealing 2 damage/s to any enemy inside it.",
		"frost_cannon_tri": "Fires at up to 3 separate targets per shot. Boss targets take +50% damage and receive a 10% slow that refreshes on repeat hits.",
		"arcane_overload": "Every 5th attack triggers Arcane Overload — instant lasers hit ALL enemies in range (minimum 5 lasers). Counter never resets.",
		"arcane_charge": "Persistent charge counter — every 15th hit fires a blue ray hitting all enemies in range. Counter never resets.",
		"lock_beam":     "Locks onto one target until it dies or leaves range. Beam damage ramps from 1× to 2× over 5 seconds of continuous fire.",
		"tempest_strike":         "Every 10th hit launches a slash that deals base damage + 5% of the target's max HP on impact.",
		"infernal_serpent_summon":"Each hit has a 10% chance to summon a living fire serpent (100 damage per bite) that races around the battlefield once.",
		"lightning":     "Chains to the primary target and up to 3 additional enemies at 80% damage.",
		"storm_chain":   "Strikes the primary target for full damage, then chains to the 4 nearest enemies globally for 150% damage. Chain targets can be outside the tower's range.",
		"chrono_aoe":    "Hits all enemies in range each shot. Each hit applies a 15% slow for 2s that stacks with other slows (e.g. Frost Spire).",
		"world_tree_buff": "Passively buffs all towers one tile away with +10 flat damage and +50% attack speed.",
		"natures_wrath_buff": "Passively buffs all towers one tile away with +15 flat damage and +75% attack speed. Each hit has a 5% chance to generate 2 gold.",
		"taunt_slam":     "Strikes up to 5 enemies simultaneously. Every 5th hit taunts all enemies in range — stunning them for 2s and causing them to take +20% damage from all sources.",
		"hercules_cleave": "Strikes the primary target and one additional enemy simultaneously. Gains +5 permanent damage after every wave cleared. Boss waves do not count.",
		"pierce":        "Bolt pierces through up to 3 enemies in a line, hitting each for full damage.",
		"shadow_weaver_phase": "Shadow phase: single-target attack. After 10 hits transforms for 5s — white laser fires every 0.5s hitting 5 enemies for 50% tower damage + 1% max HP (0.5% on bosses).",
		"axe_warrior":   "Each swing hits up to 2 enemies in melee range, applying 1 Bleed stack and 1 Poison stack. Poisoned enemies take +10% damage from all sources for 5s.",
		"blade_spin":    "Dual melee strike hits 2 targets. Each attack has a 10% chance to summon 2 razor blades that orbit the tower for 3s, shredding any enemy they contact.",
		"rock_drop":          "Fires at target. Every 3rd hit drops a brittle zone at the target's location for 2s. Enemies entering the zone take +20 bonus damage on their very next hit from any source.",
		"dual_debuff":        "Hits 2 enemies per attack. Every other attack inflicts a random debuff on each target for 1 second. (Bleed, 10% Slow, or +10% damage taken — 5s cooldown per debuff per target.)",
		"shadow_blade_combo": "Every 3rd hit strikes with both blades at 2× damage and applies a bleed dealing 2× damage/s for 3s. Max 1 bleed stack per target.",
		"frost_shatter":      "Fires 2 projectiles per attack. Every hit slows the target by 5% for 2s. Gains +3% attack speed per slowed enemy on the map (max +30%). Resets after 3s without attacking.",
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

	# Counter badge — show for towers/heroes with hit counters or stack systems
	var counter_text : String = ""
	var eff : String = d.get("effect", "")
	match eff:
		"slow_zone":
			counter_text = "%d / 4" % (tower._hit_counter % 4)
		"melee_cleave", "knight_slam":
			counter_text = "%d / 3" % tower._hit_counter
		"taunt_slam":
			counter_text = "%d / 5" % tower._hit_counter
		"arcane_charge":
			counter_text = "%d / 15" % (tower._arcane_charge % 15)
		"arcane_overload":
			counter_text = "%d / 5" % (tower._arcane_charge % 5)
		"hercules_cleave":
			counter_text = "+%d dmg" % int(tower._hercules_wave_bonus)
		"frost_shatter":
			counter_text = "+%d%% spd" % int(tower._frost_speed_bonus * 100)
		"shadow_blade_combo":
			counter_text = "%d / 3" % tower._hit_counter
		"tempest_strike":
			counter_text = "%d / 10" % tower._hit_counter
		"dual_debuff":
			counter_text = "%d / 2" % (tower._hit_counter % 2)
		"ranger_fire_aura":
			counter_text = "%d / 5" % tower._hit_counter
		"rock_drop":
			counter_text = "%d / 3" % (tower._hit_counter % 3)
		"shadow_weaver_phase":
			if tower._sw_light_timer > 0.0:
				counter_text = "LIGHT %.1fs" % tower._sw_light_timer
			else:
				counter_text = "%d / 10" % tower._sw_stacks
		"blade_spin":
			if tower._blade_timer > 0.0:
				counter_text = "SPIN %.1fs" % tower._blade_timer
			else:
				counter_text = "10% proc"
		"dual_shot", "focused_shot":
			pass   # no meaningful counter
	if counter_text != "":
		_info_counter_lbl.text   = counter_text
		_info_counter_bg.visible = true
	else:
		_info_counter_bg.visible = false

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

func show_run_results(stage: int, kills: int, bosses: int, gems: int, turrets: Array, victory: bool = false, wave: int = 0) -> void:
	_run_results_screen.visible = true
	if is_instance_valid(_gear_btn):
		_gear_btn.visible = false

	var title_lbl     : Label   = _run_results_screen.get_node("title")
	var stage_lbl     : Label   = _run_results_screen.get_node("stage_info")
	var wave_lbl      : Label   = _run_results_screen.get_node("wave_info")
	var kills_lbl     : Label   = _run_results_screen.get_node("kills")
	var gems_earn_lbl : Label   = _run_results_screen.get_node("gems_earned")
	var gems_tot_lbl  : Label   = _run_results_screen.get_node("gems_total")
	var tower_grid    : Control = _run_results_screen.get_node("tower_grid")

	if victory:
		title_lbl.text = "🏆  Full Clear!"
		title_lbl.add_theme_color_override("font_color", C_GOLD)
		stage_lbl.text = ""
		wave_lbl.text  = ""
	else:
		title_lbl.text = "💀  Defeated"
		title_lbl.add_theme_color_override("font_color", C_RED)
		stage_lbl.text = ("Stage %d Clear" % (stage - 1)) if stage > 1 else ""
		wave_lbl.text  = "Wave %d" % wave if wave > 0 else ""
	kills_lbl.text     = "⚔  %d enemies slain  (%d bosses)" % [kills, bosses]
	gems_earn_lbl.text = "+%d  🔷  Blue Gems" % gems
	gems_tot_lbl.text  = "Total: %d" % GameData.blue_gems

	for child in tower_grid.get_children():
		child.queue_free()

	# Group towers by idx so duplicates show as a count
	var grouped : Dictionary = {}
	for td in turrets:
		var tidx : int = td.get("idx", -1)
		if grouped.has(tidx):
			grouped[tidx]["count"] += 1
		else:
			grouped[tidx] = {"data": td, "count": 1}

	# Sort fusion → legendary → epic → rare → common, then by idx
	var rarity_order := {"fusion": 0, "legendary": 1, "epic": 2, "rare": 3, "common": 4}
	var sorted_keys  : Array = grouped.keys()
	sorted_keys.sort_custom(func(a, b) -> bool:
		var ra : int = rarity_order.get(grouped[a]["data"].get("rarity", "common"), 4)
		var rb : int = rarity_order.get(grouped[b]["data"].get("rarity", "common"), 4)
		if ra != rb:
			return ra < rb
		return a < b
	)

	var rarity_colors := {
		"common": Color(0.75, 0.75, 0.75), "rare": Color(0.25, 0.55, 1.00),
		"epic": Color(0.72, 0.25, 0.90), "legendary": Color(1.00, 0.72, 0.10),
		"fusion": Color(0.20, 1.00, 0.85),
	}
	const CARD_W : int = 58
	const CARD_H : int = 76
	const GAP    : int = 4
	const COLS   : int = 10

	var col : int = 0
	var row : int = 0
	for tidx in sorted_keys:
		var entry  : Dictionary = grouped[tidx]
		var td     : Dictionary = entry["data"]
		var count  : int        = entry["count"]
		var rarity : String     = td.get("rarity", "common")
		var rc     : Color      = rarity_colors.get(rarity, C_WHITE)

		var card := Panel.new()
		card.position = Vector2(col * (CARD_W + GAP), row * (CARD_H + GAP))
		card.size     = Vector2(CARD_W, CARD_H)
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color(rc.r * 0.14, rc.g * 0.14, rc.b * 0.14, 1.0)
		cs.corner_radius_top_left = 5; cs.corner_radius_top_right = 5
		cs.corner_radius_bottom_left = 5; cs.corner_radius_bottom_right = 5
		cs.border_width_left = 2; cs.border_width_right = 2
		cs.border_width_top  = 2; cs.border_width_bottom = 2
		cs.border_color = rc
		card.add_theme_stylebox_override("panel", cs)
		tower_grid.add_child(card)

		var prev := _TurretPreview.new()
		prev.turret_data = td
		prev.position    = Vector2(1, 2)
		card.add_child(prev)

		var count_lbl := _label("×%d" % count, _font_bold, 11, rc)
		count_lbl.position             = Vector2(0, CARD_H - 16)
		count_lbl.size                 = Vector2(CARD_W, 16)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(count_lbl)

		col += 1
		if col >= COLS:
			col = 0
			row += 1

	# ── Loot grid ────────────────────────────────────────────────────────────
	if not is_instance_valid(_run_results_loot_grid):
		return
	for child in _run_results_loot_grid.get_children():
		child.queue_free()

	var loot_groups : Dictionary = {}
	for item in _loot_items:
		var lid : String = item["id"]
		if not loot_groups.has(lid):
			loot_groups[lid] = {"type": item["type"], "id": lid, "rarity": item["rarity"], "count": 0}
		loot_groups[lid]["count"] += 1

	var rarity_colors_loot := {
		"common": Color(0.75, 0.75, 0.75), "rare": Color(0.25, 0.55, 1.00),
		"epic": Color(0.72, 0.25, 0.90), "legendary": Color(1.00, 0.72, 0.10),
	}
	var lcol : int = 0; var lrow : int = 0
	for lid in loot_groups:
		var lentry : Dictionary = loot_groups[lid]
		var lrarity : String    = lentry["rarity"]
		var lcount  : int       = lentry["count"]
		var ldef    : Dictionary = SummonSystem.TURRET_DEFS.get(lid, GameData.HERO_DEFS.get(lid, {}))
		var lrc     : Color     = rarity_colors_loot.get(lrarity, C_WHITE)

		var lcard := Panel.new()
		lcard.position = Vector2(lcol * (CARD_W + GAP), lrow * (CARD_H + GAP))
		lcard.size     = Vector2(CARD_W, CARD_H)
		var lcs := StyleBoxFlat.new()
		lcs.bg_color = Color(lrc.r * 0.14, lrc.g * 0.14, lrc.b * 0.14, 1.0)
		lcs.corner_radius_top_left = 5; lcs.corner_radius_top_right = 5
		lcs.corner_radius_bottom_left = 5; lcs.corner_radius_bottom_right = 5
		lcs.border_width_left = 2; lcs.border_width_right = 2
		lcs.border_width_top  = 2; lcs.border_width_bottom = 2
		lcs.border_color = lrc
		lcard.add_theme_stylebox_override("panel", lcs)
		_run_results_loot_grid.add_child(lcard)

		var lprev := _TurretPreview.new()
		lprev.turret_data = ldef
		lprev.position    = Vector2(1, 2)
		lcard.add_child(lprev)

		var lcount_lbl := _label("×%d" % lcount, _font_bold, 11, lrc)
		lcount_lbl.position             = Vector2(0, CARD_H - 16)
		lcount_lbl.size                 = Vector2(CARD_W, 16)
		lcount_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lcard.add_child(lcount_lbl)

		lcol += 1
		if lcol >= COLS:
			lcol = 0
			lrow += 1


func _build_run_results_screen() -> void:
	const LW  : int = 640   # left column usable width
	const RX  : int = 662   # right column start x
	const RW  : int = 598   # right column width
	const PAD : int = 20

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

	# Vertical column divider
	var vdiv := ColorRect.new()
	vdiv.color        = Color(1, 1, 1, 0.07)
	vdiv.position     = Vector2(LW + PAD, 16)
	vdiv.size         = Vector2(2, 688)
	vdiv.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(vdiv)

	# ── Left column top half: tower grid ─────────────────────────────────────
	var left_hdr := _label("🗼  Towers on Field", _font_bold, 17, C_DIM)
	left_hdr.position             = Vector2(PAD + 8, 22)
	left_hdr.size                 = Vector2(LW - PAD - 8, 26)
	left_hdr.mouse_filter         = MOUSE_FILTER_IGNORE
	overlay.add_child(left_hdr)

	var hdiv_l := ColorRect.new()
	hdiv_l.color        = Color(1, 1, 1, 0.07)
	hdiv_l.position     = Vector2(PAD + 8, 52)
	hdiv_l.size         = Vector2(LW - PAD - 8, 2)
	hdiv_l.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(hdiv_l)

	var tower_grid := Control.new()
	tower_grid.name         = "tower_grid"
	tower_grid.position     = Vector2(PAD + 8, 62)
	tower_grid.size         = Vector2(LW - PAD - 8, 278)
	tower_grid.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(tower_grid)

	# ── Mid divider ───────────────────────────────────────────────────────────
	var hdiv_mid := ColorRect.new()
	hdiv_mid.color        = Color(1, 1, 1, 0.07)
	hdiv_mid.position     = Vector2(PAD, 352)
	hdiv_mid.size         = Vector2(LW, 2)
	hdiv_mid.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(hdiv_mid)

	# ── Left column bottom half: loot grid ────────────────────────────────────
	var loot_hdr := _label("🎒  Loot Earned", _font_bold, 17, C_DIM)
	loot_hdr.position             = Vector2(PAD + 8, 364)
	loot_hdr.size                 = Vector2(LW - PAD - 8, 26)
	loot_hdr.mouse_filter         = MOUSE_FILTER_IGNORE
	overlay.add_child(loot_hdr)

	var hdiv_loot := ColorRect.new()
	hdiv_loot.color        = Color(1, 1, 1, 0.07)
	hdiv_loot.position     = Vector2(PAD + 8, 394)
	hdiv_loot.size         = Vector2(LW - PAD - 8, 2)
	hdiv_loot.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(hdiv_loot)

	var loot_grid := Control.new()
	loot_grid.name         = "loot_grid"
	loot_grid.position     = Vector2(PAD + 8, 404)
	loot_grid.size         = Vector2(LW - PAD - 8, 290)
	loot_grid.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(loot_grid)
	_run_results_loot_grid = loot_grid

	# ── Right column: stats ───────────────────────────────────────────────────
	# Title
	var title := _label("", _font_bold, 42, C_GOLD)
	title.name                 = "title"
	title.position             = Vector2(RX, 28)
	title.size                 = Vector2(RW, 58)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter         = MOUSE_FILTER_IGNORE
	overlay.add_child(title)

	# Stage reached
	var stage_lbl := _label("", _font_bold, 34, C_WHITE)
	stage_lbl.name                 = "stage_info"
	stage_lbl.position             = Vector2(RX, 100)
	stage_lbl.size                 = Vector2(RW, 48)
	stage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	overlay.add_child(stage_lbl)

	# Wave
	var wave_lbl := _label("", _font_reg, 20, Color(0.72, 0.72, 0.85))
	wave_lbl.name                 = "wave_info"
	wave_lbl.position             = Vector2(RX, 152)
	wave_lbl.size                 = Vector2(RW, 28)
	wave_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	overlay.add_child(wave_lbl)

	# Kills
	var kills_lbl := _label("", _font_bold, 17, C_DIM)
	kills_lbl.name                 = "kills"
	kills_lbl.position             = Vector2(RX, 190)
	kills_lbl.size                 = Vector2(RW, 26)
	kills_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kills_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	overlay.add_child(kills_lbl)

	# Divider
	var hdiv_r := ColorRect.new()
	hdiv_r.color        = Color(1, 1, 1, 0.07)
	hdiv_r.position     = Vector2(RX, 232)
	hdiv_r.size         = Vector2(RW - PAD, 2)
	hdiv_r.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(hdiv_r)

	# Rewards header
	var rewards_hdr := _label("Rewards", _font_bold, 15, C_DIM)
	rewards_hdr.position     = Vector2(RX + PAD, 246)
	rewards_hdr.size         = Vector2(200, 22)
	rewards_hdr.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(rewards_hdr)

	# Gems earned this run
	var gems_earn_lbl := _label("", _font_bold, 26, Color(0.45, 0.75, 1.00))
	gems_earn_lbl.name         = "gems_earned"
	gems_earn_lbl.position     = Vector2(RX + PAD, 278)
	gems_earn_lbl.size         = Vector2(RW - PAD * 2, 36)
	gems_earn_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(gems_earn_lbl)

	# Total gems
	var gems_tot_lbl := _label("", _font_reg, 15, C_DIM)
	gems_tot_lbl.name         = "gems_total"
	gems_tot_lbl.position     = Vector2(RX + PAD, 320)
	gems_tot_lbl.size         = Vector2(RW - PAD * 2, 22)
	gems_tot_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(gems_tot_lbl)

	# Continue button
	var cont_btn := Button.new()
	cont_btn.text         = "Continue  →"
	cont_btn.position     = Vector2(1280 - PAD - 200, 720 - 75)
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
		if is_instance_valid(_gear_btn):
			_gear_btn.visible = true
		show_main_menu()
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
		if ni > 0:
			nav_btn.visible = GameData.tutorial_complete
			_tutorial_locked_btns.append(nav_btn)
		overlay.add_child(nav_btn)

	# "Daily Quests" button — top-right of black area
	var dq_btn := Button.new()
	dq_btn.text         = "📅  Daily Quests"
	dq_btn.position     = Vector2(920, 195)
	dq_btn.size         = Vector2(240, 58)
	dq_btn.focus_mode   = FOCUS_NONE
	dq_btn.pivot_offset = Vector2(120, 29)
	dq_btn.add_theme_font_override("font",           _font_bold)
	dq_btn.add_theme_font_size_override("font_size", 18)
	dq_btn.add_theme_color_override("font_color",    C_WHITE)
	dq_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.18, 0.32, 0.45)))
	dq_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.25, 0.44, 0.62)))
	dq_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.12, 0.22, 0.32)))
	dq_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.18, 0.32, 0.45)))
	dq_btn.visible = GameData.dq_unlocked
	dq_btn.pressed.connect(func():
		_game_over_screen.visible = false
		if is_instance_valid(_daily_quests_screen):
			_refresh_daily_quests_screen()
			_daily_quests_screen.visible = true
	)
	overlay.add_child(dq_btn)
	_dq_main_btn = dq_btn

	# "Relics" button — below Daily Quests
	var relics_btn := Button.new()
	relics_btn.text         = "💎  Relics"
	relics_btn.position     = Vector2(920, 268)
	relics_btn.size         = Vector2(240, 58)
	relics_btn.focus_mode   = FOCUS_NONE
	relics_btn.pivot_offset = Vector2(120, 29)
	relics_btn.add_theme_font_override("font",           _font_bold)
	relics_btn.add_theme_font_size_override("font_size", 18)
	relics_btn.add_theme_color_override("font_color",    C_WHITE)
	relics_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.24, 0.10, 0.44)))
	relics_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.34, 0.16, 0.62)))
	relics_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.16, 0.06, 0.30)))
	relics_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.24, 0.10, 0.44)))
	relics_btn.pressed.connect(func():
		_game_over_screen.visible = false
		if is_instance_valid(_relic_screen):
			_refresh_relics_screen()
			_relic_screen.visible = true
	)
	overlay.add_child(relics_btn)

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
	start_btn.pressed.connect(func(): _on_main_nav_pressed(2))
	overlay.add_child(start_btn)

	# DEBUG — Reset all saved progress
	var reset_btn := Button.new()
	reset_btn.text       = "🗑  Reset Progress (Debug)"
	reset_btn.position   = Vector2(14, 720 - 58 - 14)
	reset_btn.size       = Vector2(260, 46)
	reset_btn.focus_mode = FOCUS_NONE
	reset_btn.add_theme_font_override("font",           _font_bold)
	reset_btn.add_theme_font_size_override("font_size", 14)
	reset_btn.add_theme_color_override("font_color",    Color(1, 0.6, 0.6))
	reset_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.28, 0.10, 0.10)))
	reset_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.40, 0.14, 0.14)))
	reset_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.20, 0.07, 0.07)))
	reset_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.28, 0.10, 0.10)))
	var _reset_state := [false]  # array so lambda mutation persists across calls
	reset_btn.pressed.connect(func():
		if not _reset_state[0]:
			_reset_state[0] = true
			reset_btn.text = "⚠  CONFIRM RESET? (click again)"
			reset_btn.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
			reset_btn.add_theme_stylebox_override("normal", _btn_style(Color(0.55, 0.28, 0.04)))
			reset_btn.add_theme_stylebox_override("hover",  _btn_style(Color(0.72, 0.36, 0.06)))
		else:
			GameData.reset_save()
			get_tree().reload_current_scene()
	)
	overlay.add_child(reset_btn)

	# DEBUG — Add quest tokens
	var tok_btn := Button.new()
	tok_btn.text       = "★ +1000 Quest Tokens"
	tok_btn.position   = Vector2(920, 334)
	tok_btn.size       = Vector2(240, 44)
	tok_btn.focus_mode = FOCUS_NONE
	tok_btn.add_theme_font_override("font",           _font_bold)
	tok_btn.add_theme_font_size_override("font_size", 14)
	tok_btn.add_theme_color_override("font_color",    Color(0.88, 0.72, 1.00))
	tok_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.18, 0.10, 0.32)))
	tok_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.26, 0.14, 0.46)))
	tok_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.12, 0.06, 0.22)))
	tok_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.18, 0.10, 0.32)))
	tok_btn.pressed.connect(func():
		GameData.quest_tokens += 1000
		GameData.save_game()
	)
	overlay.add_child(tok_btn)

	call_deferred("_wire_hover_recursive", overlay)


func show_game_over(stage: int) -> void:
	_go_title_lbl.text      = "💀  IDLE BASTION"
	_go_stage_lbl.text      = "Stage %d reached" % stage
	_go_stage_lbl.visible   = true
	_go_flavour_lbl.visible = true
	_game_over_screen.visible = true


func start_tutorial() -> void:
	var overlay = load("res://ui/TutorialOverlay.gd").new()
	add_child(overlay)
	overlay.setup(_font_bold, _font_reg)


func show_main_menu() -> void:
	Engine.time_scale = 1.0
	_go_title_lbl.text      = "🛡  IDLE BASTION"
	_go_stage_lbl.visible   = false
	_go_flavour_lbl.visible = false
	for btn in _tutorial_locked_btns:
		if is_instance_valid(btn):
			btn.visible = GameData.dq_unlocked
	if is_instance_valid(_dq_main_btn):
		_dq_main_btn.visible = GameData.dq_unlocked
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
			_refresh_world_map()
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
	const CLIP_X : int = 220
	const CLIP_W : int = 840
	const CLIP_Y : int = 188
	const CLIP_H : int = 176

	# ── Outer overlay ────────────────────────────────────────────────────────────
	var overlay := Panel.new()
	var bg_s := StyleBoxFlat.new()
	bg_s.bg_color = Color(0.03, 0.03, 0.09)
	overlay.add_theme_stylebox_override("panel", bg_s)
	overlay.position     = Vector2.ZERO
	overlay.size         = Vector2(1280, 720)
	overlay.mouse_filter = MOUSE_FILTER_STOP
	overlay.visible      = false
	add_child(overlay)
	_shop_screen = overlay

	# ── Title ────────────────────────────────────────────────────────────────────
	var title := _label("Tower  Gacha", _font_bold, 32, C_WHITE)
	title.position             = Vector2(0, 10)
	title.size                 = Vector2(1280, 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(title)
	_gacha_title_lbl = title

	var uline := ColorRect.new()
	uline.color        = Color(0.55, 0.30, 0.90, 0.38)
	uline.position     = Vector2(490, 54)
	uline.size         = Vector2(300, 2)
	uline.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(uline)

	# ── Gem display (shown for tower/hero tabs) ──────────────────────────────────
	_gacha_gem_lbl = _label("🔷 0", _font_bold, 20, Color(0.50, 0.82, 1.0))
	_gacha_gem_lbl.position             = Vector2(0, 62)
	_gacha_gem_lbl.size                 = Vector2(1280, 28)
	_gacha_gem_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(_gacha_gem_lbl)

	# ── Relic token display (shown only for relic tab) ───────────────────────────
	const GH_D  : int = 22
	const GH_GAP: int = 6
	var _gh := _tok_center("00000 ★", 20, GH_D, GH_GAP, 1280)
	_gacha_relic_coin = _make_token_coin(GH_D)
	_gacha_relic_coin.position = Vector2(_gh[0], 65)
	_gacha_relic_coin.visible  = false
	overlay.add_child(_gacha_relic_coin)
	_gacha_relic_tok_lbl = _label("%d ★" % GameData.quest_tokens, _font_bold, 20, Color(0.88, 0.72, 1.00))
	_gacha_relic_tok_lbl.position             = Vector2(_gh[1], 62)
	_gacha_relic_tok_lbl.size                 = Vector2(_gh[2], 28)
	_gacha_relic_tok_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_gacha_relic_tok_lbl.visible              = false
	overlay.add_child(_gacha_relic_tok_lbl)

	# ── Mode tabs (3 tabs: Towers, Heroes, Quest Shop) ───────────────────────────
	const TAB_W : int = 180; const TAB_H : int = 32; const TAB_GAP : int = 12
	var tab_x0  : int = (1280 - 3 * TAB_W - 2 * TAB_GAP) / 2   # centres 3 tabs

	_gacha_tab_tower_btn = Button.new()
	_gacha_tab_tower_btn.text       = "⚔  Towers"
	_gacha_tab_tower_btn.position   = Vector2(tab_x0, 96)
	_gacha_tab_tower_btn.size       = Vector2(TAB_W, TAB_H)
	_gacha_tab_tower_btn.focus_mode = FOCUS_NONE
	_gacha_tab_tower_btn.add_theme_font_override("font",           _font_bold)
	_gacha_tab_tower_btn.add_theme_font_size_override("font_size", 15)
	_gacha_tab_tower_btn.add_theme_color_override("font_color",    C_WHITE)
	_gacha_tab_tower_btn.add_theme_stylebox_override("normal",  _btn_style(C_TAB_ACT))
	_gacha_tab_tower_btn.add_theme_stylebox_override("hover",   _btn_style(C_TAB_ACT.lightened(0.1)))
	_gacha_tab_tower_btn.add_theme_stylebox_override("pressed", _btn_style(C_TAB_ACT.darkened(0.15)))
	_gacha_tab_tower_btn.add_theme_stylebox_override("focus",   _btn_style(C_TAB_ACT))
	_gacha_tab_tower_btn.pressed.connect(func(): _gacha_switch_mode("tower"))
	overlay.add_child(_gacha_tab_tower_btn)

	_gacha_tab_hero_btn = Button.new()
	_gacha_tab_hero_btn.text       = "✦  Heroes"
	_gacha_tab_hero_btn.position   = Vector2(tab_x0 + TAB_W + TAB_GAP, 96)
	_gacha_tab_hero_btn.size       = Vector2(TAB_W, TAB_H)
	_gacha_tab_hero_btn.focus_mode = FOCUS_NONE
	_gacha_tab_hero_btn.add_theme_font_override("font",           _font_bold)
	_gacha_tab_hero_btn.add_theme_font_size_override("font_size", 15)
	_gacha_tab_hero_btn.add_theme_color_override("font_color",    C_DIM)
	_gacha_tab_hero_btn.add_theme_stylebox_override("normal",  _btn_style(C_TAB_IDLE))
	_gacha_tab_hero_btn.add_theme_stylebox_override("hover",   _btn_style(C_TAB_IDLE.lightened(0.1)))
	_gacha_tab_hero_btn.add_theme_stylebox_override("pressed", _btn_style(C_TAB_IDLE.darkened(0.15)))
	_gacha_tab_hero_btn.add_theme_stylebox_override("focus",   _btn_style(C_TAB_IDLE))
	_gacha_tab_hero_btn.pressed.connect(func(): _gacha_switch_mode("hero"))
	overlay.add_child(_gacha_tab_hero_btn)

	_gacha_tab_quest_btn = Button.new()
	_gacha_tab_quest_btn.text       = "💎  Relics"
	_gacha_tab_quest_btn.position   = Vector2(tab_x0 + (TAB_W + TAB_GAP) * 2, 96)
	_gacha_tab_quest_btn.size       = Vector2(TAB_W, TAB_H)
	_gacha_tab_quest_btn.focus_mode = FOCUS_NONE
	_gacha_tab_quest_btn.add_theme_font_override("font",           _font_bold)
	_gacha_tab_quest_btn.add_theme_font_size_override("font_size", 15)
	_gacha_tab_quest_btn.add_theme_color_override("font_color",    C_DIM)
	_gacha_tab_quest_btn.add_theme_stylebox_override("normal",  _btn_style(C_TAB_IDLE))
	_gacha_tab_quest_btn.add_theme_stylebox_override("hover",   _btn_style(C_TAB_IDLE.lightened(0.1)))
	_gacha_tab_quest_btn.add_theme_stylebox_override("pressed", _btn_style(C_TAB_IDLE.darkened(0.15)))
	_gacha_tab_quest_btn.add_theme_stylebox_override("focus",   _btn_style(C_TAB_IDLE))
	_gacha_tab_quest_btn.pressed.connect(func(): _gacha_switch_mode("relic"))
	overlay.add_child(_gacha_tab_quest_btn)

	# ── Rarity odds pills ─────────────────────────────────────────────────────────
	var odds_defs : Array = [
		["75%", Color(0.72, 0.72, 0.72), "Common"],
		["20%", Color(0.25, 0.55, 1.00), "Rare"],
		[ "4%", Color(0.72, 0.25, 0.90), "Epic"],
		[ "1%", Color(1.00, 0.72, 0.10), "Legendary"],
	]
	const PILL_W : int = 148; const PILL_H : int = 26; const PILL_GAP : int = 10
	var pill_total : int = 4 * PILL_W + 3 * PILL_GAP
	var pill_x0    : int = (1280 - pill_total) / 2
	for pi in range(odds_defs.size()):
		var od   : Array = odds_defs[pi]
		var pcol : Color = od[1]
		var pill := Panel.new()
		var ps2  := StyleBoxFlat.new()
		ps2.bg_color                   = Color(pcol.r, pcol.g, pcol.b, 0.09)
		ps2.corner_radius_top_left     = 13; ps2.corner_radius_top_right    = 13
		ps2.corner_radius_bottom_left  = 13; ps2.corner_radius_bottom_right = 13
		ps2.border_width_left  = 1; ps2.border_width_right  = 1
		ps2.border_width_top   = 1; ps2.border_width_bottom = 1
		ps2.border_color = Color(pcol.r, pcol.g, pcol.b, 0.38)
		pill.add_theme_stylebox_override("panel", ps2)
		pill.position     = Vector2(pill_x0 + pi * (PILL_W + PILL_GAP), 160)
		pill.size         = Vector2(PILL_W, PILL_H)
		pill.mouse_filter = MOUSE_FILTER_IGNORE
		overlay.add_child(pill)
		var pl := _label(od[0] + "  " + od[2], _font_bold, 13, pcol)
		pl.position             = Vector2(0, 4)
		pl.size                 = Vector2(PILL_W, 20)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pl.mouse_filter         = MOUSE_FILTER_IGNORE
		pill.add_child(pl)

	# ── Ambient glow behind wheel ─────────────────────────────────────────────────
	var glow := ColorRect.new()
	glow.color        = Color(0.24, 0.07, 0.55, 0.14)
	glow.position     = Vector2(CLIP_X - 54, CLIP_Y - 30)
	glow.size         = Vector2(CLIP_W + 108, CLIP_H + 60)
	glow.mouse_filter = MOUSE_FILTER_IGNORE
	glow.z_index      = 0
	overlay.add_child(glow)
	_gacha_wheel_glow = glow

	var glow2 := ColorRect.new()
	glow2.color        = Color(0.12, 0.04, 0.38, 0.09)
	glow2.position     = Vector2(CLIP_X - 100, CLIP_Y - 55)
	glow2.size         = Vector2(CLIP_W + 200, CLIP_H + 110)
	glow2.mouse_filter = MOUSE_FILTER_IGNORE
	glow2.z_index      = 0
	overlay.add_child(glow2)

	var glow_tw := create_tween()
	glow_tw.set_loops()
	glow_tw.tween_property(glow, "modulate:a", 0.42, 2.4)
	glow_tw.tween_property(glow, "modulate:a", 1.00, 2.4)

	# ── Red center arrow ──────────────────────────────────────────────────────────
	var arrow := _label("▼", _font_bold, 28, Color(0.95, 0.18, 0.18))
	arrow.position             = Vector2(CLIP_X, CLIP_Y - 36)
	arrow.size                 = Vector2(CLIP_W, 32)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(arrow)

	# ── Wheel clip container ──────────────────────────────────────────────────────
	var clip := Panel.new()
	var clip_s := StyleBoxFlat.new()
	clip_s.bg_color                   = Color(0.06, 0.06, 0.12)
	clip_s.corner_radius_top_left     = 12; clip_s.corner_radius_top_right    = 12
	clip_s.corner_radius_bottom_left  = 12; clip_s.corner_radius_bottom_right = 12
	clip_s.border_width_left  = 2; clip_s.border_width_right  = 2
	clip_s.border_width_top   = 2; clip_s.border_width_bottom = 2
	clip_s.border_color = Color(0.40, 0.25, 0.72, 0.60)
	clip_s.shadow_color = Color(0.18, 0.04, 0.40, 0.55)
	clip_s.shadow_size  = 12
	clip.add_theme_stylebox_override("panel", clip_s)
	clip.position      = Vector2(CLIP_X, CLIP_Y)
	clip.size          = Vector2(CLIP_W, CLIP_H)
	clip.clip_contents = true
	clip.mouse_filter  = MOUSE_FILTER_IGNORE
	clip.z_index       = 2
	overlay.add_child(clip)

	var cline := ColorRect.new()
	cline.color        = Color(0.95, 0.18, 0.18, 0.72)
	cline.position     = Vector2(CLIP_X + CLIP_W / 2 - 1, CLIP_Y - 6)
	cline.size         = Vector2(2, CLIP_H + 12)
	cline.mouse_filter = MOUSE_FILTER_IGNORE
	cline.z_index      = 6
	overlay.add_child(cline)

	var left_fade := ColorRect.new()
	left_fade.color        = Color(0.03, 0.03, 0.09, 0.76)
	left_fade.position     = Vector2(CLIP_X, CLIP_Y)
	left_fade.size         = Vector2(52, CLIP_H)
	left_fade.mouse_filter = MOUSE_FILTER_IGNORE
	left_fade.z_index      = 4
	overlay.add_child(left_fade)

	var right_fade := ColorRect.new()
	right_fade.color        = Color(0.03, 0.03, 0.09, 0.76)
	right_fade.position     = Vector2(CLIP_X + CLIP_W - 52, CLIP_Y)
	right_fade.size         = Vector2(52, CLIP_H)
	right_fade.mouse_filter = MOUSE_FILTER_IGNORE
	right_fade.z_index      = 4
	overlay.add_child(right_fade)

	# ── Card strip ────────────────────────────────────────────────────────────────
	var strip := Control.new()
	strip.position     = Vector2(4, (CLIP_H - GACHA_CARD_H) / 2)
	strip.mouse_filter = MOUSE_FILTER_IGNORE
	clip.add_child(strip)
	_gacha_strip = strip

	_gacha_rebuild_strip("")

	# ── Summon buttons (side-by-side) ─────────────────────────────────────────────
	const BTN_W   : int = 340
	const BTN_H   : int = 56
	const BTN_GAP : int = 24
	var btn_y     : int = CLIP_Y + CLIP_H + 20
	var btn_x0    : int = (1280 - 2 * BTN_W - BTN_GAP) / 2

	_gacha_summon_btn = Button.new()
	_gacha_summon_btn.text       = "✦  Summon x1    🔷 %d" % GACHA_TOWER_SUMMON_COST
	_gacha_summon_btn.position   = Vector2(btn_x0, btn_y)
	_gacha_summon_btn.size       = Vector2(BTN_W, BTN_H)
	_gacha_summon_btn.focus_mode = FOCUS_NONE
	_gacha_summon_btn.add_theme_font_override("font",           _font_bold)
	_gacha_summon_btn.add_theme_font_size_override("font_size", 19)
	_gacha_summon_btn.add_theme_color_override("font_color",    C_WHITE)
	_gacha_summon_btn.add_theme_stylebox_override("normal",   _btn_style(Color(0.52, 0.14, 0.06)))
	_gacha_summon_btn.add_theme_stylebox_override("hover",    _btn_style(Color(0.68, 0.20, 0.09)))
	_gacha_summon_btn.add_theme_stylebox_override("pressed",  _btn_style(Color(0.36, 0.09, 0.04)))
	_gacha_summon_btn.add_theme_stylebox_override("focus",    _btn_style(Color(0.52, 0.14, 0.06)))
	_gacha_summon_btn.add_theme_stylebox_override("disabled", _btn_style(Color(0.22, 0.22, 0.28)))
	_gacha_summon_btn.pressed.connect(_gacha_on_summon_pressed)
	overlay.add_child(_gacha_summon_btn)

	_gacha_summon_10_btn = Button.new()
	_gacha_summon_10_btn.text       = "✦✦  Summon x10  🔷 %d" % GACHA_TOWER_SUMMON_10_COST
	_gacha_summon_10_btn.position   = Vector2(btn_x0 + BTN_W + BTN_GAP, btn_y)
	_gacha_summon_10_btn.size       = Vector2(BTN_W, BTN_H)
	_gacha_summon_10_btn.focus_mode = FOCUS_NONE
	_gacha_summon_10_btn.add_theme_font_override("font",           _font_bold)
	_gacha_summon_10_btn.add_theme_font_size_override("font_size", 19)
	_gacha_summon_10_btn.add_theme_color_override("font_color",    C_WHITE)
	_gacha_summon_10_btn.add_theme_stylebox_override("normal",   _btn_style(Color(0.14, 0.36, 0.62)))
	_gacha_summon_10_btn.add_theme_stylebox_override("hover",    _btn_style(Color(0.20, 0.46, 0.76)))
	_gacha_summon_10_btn.add_theme_stylebox_override("pressed",  _btn_style(Color(0.09, 0.25, 0.46)))
	_gacha_summon_10_btn.add_theme_stylebox_override("focus",    _btn_style(Color(0.14, 0.36, 0.62)))
	_gacha_summon_10_btn.add_theme_stylebox_override("disabled", _btn_style(Color(0.22, 0.22, 0.28)))
	_gacha_summon_10_btn.pressed.connect(_gacha_on_summon_10_pressed)
	overlay.add_child(_gacha_summon_10_btn)

	# ── Popups (built hidden) ─────────────────────────────────────────────────────
	_gacha_build_result_popup(overlay)
	_gacha_build_multi_panel(overlay)

	# ── Back button ───────────────────────────────────────────────────────────────
	var back_btn := Button.new()
	back_btn.text       = "<  Back"
	back_btn.position   = Vector2(30, 662)
	back_btn.size       = Vector2(140, 44)
	back_btn.focus_mode = FOCUS_NONE
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

	# ── Relic panel (overlays gacha content when "relic" tab is active) ──────────
	var qp := Panel.new()
	var qp_s := StyleBoxFlat.new()
	qp_s.bg_color = Color(0.03, 0.03, 0.09)
	qp.add_theme_stylebox_override("panel", qp_s)
	qp.position     = Vector2(0, 134)
	qp.size         = Vector2(1280, 586)
	qp.mouse_filter = MOUSE_FILTER_STOP
	qp.visible      = false
	overlay.add_child(qp)
	_quest_shop_panel = qp

	# ── Back button inside relic panel ───────────────────────────────────────────
	var relic_back_btn := Button.new()
	relic_back_btn.text       = "<  Back"
	relic_back_btn.position   = Vector2(30, 528)
	relic_back_btn.size       = Vector2(140, 44)
	relic_back_btn.focus_mode = FOCUS_NONE
	relic_back_btn.add_theme_font_override("font",           _font_bold)
	relic_back_btn.add_theme_font_size_override("font_size", 16)
	relic_back_btn.add_theme_color_override("font_color",    C_WHITE)
	relic_back_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.22, 0.22, 0.28)))
	relic_back_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.30, 0.30, 0.38)))
	relic_back_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.16, 0.16, 0.20)))
	relic_back_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.22, 0.22, 0.28)))
	relic_back_btn.pressed.connect(func():
		overlay.visible = false
		_game_over_screen.visible = true
	)
	qp.add_child(relic_back_btn)

	# ── Relic token balance bar (coin icon + count) ───────────────────────────────
	const TC_D  : int = 22
	const TC_GAP: int = 6
	var _tc := _tok_center("00000 ★", 17, TC_D, TC_GAP, 1280)
	_relic_tok_coin = _make_token_coin(TC_D)
	_relic_tok_coin.position = Vector2(_tc[0], 4)
	qp.add_child(_relic_tok_coin)
	_relic_token_lbl = _label("%d ★" % GameData.quest_tokens, _font_bold, 17, Color(0.88, 0.72, 1.00))
	_relic_token_lbl.position             = Vector2(_tc[1], 6)
	_relic_token_lbl.size                 = Vector2(_tc[2], 22)
	_relic_token_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_relic_token_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	qp.add_child(_relic_token_lbl)

	# ── Relic wheel arrow ─────────────────────────────────────────────────────────
	var r_arrow := _label("▼", _font_bold, 28, Color(0.95, 0.18, 0.18))
	r_arrow.position             = Vector2(CLIP_X, 18)
	r_arrow.size                 = Vector2(CLIP_W, 32)
	r_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r_arrow.mouse_filter         = MOUSE_FILTER_IGNORE
	qp.add_child(r_arrow)

	# ── Relic wheel clip ──────────────────────────────────────────────────────────
	var r_clip := Panel.new()
	var r_clip_s := StyleBoxFlat.new()
	r_clip_s.bg_color                   = Color(0.06, 0.06, 0.12)
	r_clip_s.corner_radius_top_left     = 12; r_clip_s.corner_radius_top_right    = 12
	r_clip_s.corner_radius_bottom_left  = 12; r_clip_s.corner_radius_bottom_right = 12
	r_clip_s.border_width_left  = 2; r_clip_s.border_width_right  = 2
	r_clip_s.border_width_top   = 2; r_clip_s.border_width_bottom = 2
	r_clip_s.border_color = Color(0.50, 0.20, 0.82, 0.60)
	r_clip_s.shadow_color = Color(0.18, 0.04, 0.40, 0.55)
	r_clip_s.shadow_size  = 12
	r_clip.add_theme_stylebox_override("panel", r_clip_s)
	r_clip.position      = Vector2(CLIP_X, 54)
	r_clip.size          = Vector2(CLIP_W, CLIP_H)
	r_clip.clip_contents = true
	r_clip.mouse_filter  = MOUSE_FILTER_IGNORE
	r_clip.z_index       = 2
	qp.add_child(r_clip)

	var r_cline := ColorRect.new()
	r_cline.color        = Color(0.95, 0.18, 0.18, 0.72)
	r_cline.position     = Vector2(CLIP_X + CLIP_W / 2 - 1, 48)
	r_cline.size         = Vector2(2, CLIP_H + 12)
	r_cline.mouse_filter = MOUSE_FILTER_IGNORE
	r_cline.z_index      = 6
	qp.add_child(r_cline)

	var r_lfade := ColorRect.new()
	r_lfade.color        = Color(0.03, 0.03, 0.09, 0.76)
	r_lfade.position     = Vector2(CLIP_X, 54)
	r_lfade.size         = Vector2(52, CLIP_H)
	r_lfade.mouse_filter = MOUSE_FILTER_IGNORE
	r_lfade.z_index      = 4
	qp.add_child(r_lfade)

	var r_rfade := ColorRect.new()
	r_rfade.color        = Color(0.03, 0.03, 0.09, 0.76)
	r_rfade.position     = Vector2(CLIP_X + CLIP_W - 52, 54)
	r_rfade.size         = Vector2(52, CLIP_H)
	r_rfade.mouse_filter = MOUSE_FILTER_IGNORE
	r_rfade.z_index      = 4
	qp.add_child(r_rfade)

	var r_strip := Control.new()
	r_strip.position     = Vector2(4, (CLIP_H - GACHA_CARD_H) / 2)
	r_strip.mouse_filter = MOUSE_FILTER_IGNORE
	r_clip.add_child(r_strip)
	_relic_strip = r_strip

	_relic_rebuild_strip("")

	# ── Spin button ───────────────────────────────────────────────────────────────
	_relic_spin_btn = Button.new()
	_relic_spin_btn.text       = "💎  Spin  —  ★ 200"
	_relic_spin_btn.position   = Vector2((1280 - 340) / 2, 252)
	_relic_spin_btn.size       = Vector2(340, 56)
	_relic_spin_btn.focus_mode = FOCUS_NONE
	_relic_spin_btn.add_theme_font_override("font",           _font_bold)
	_relic_spin_btn.add_theme_font_size_override("font_size", 20)
	_relic_spin_btn.add_theme_color_override("font_color",    C_WHITE)
	_relic_spin_btn.add_theme_stylebox_override("normal",   _btn_style(Color(0.28, 0.10, 0.52)))
	_relic_spin_btn.add_theme_stylebox_override("hover",    _btn_style(Color(0.38, 0.16, 0.70)))
	_relic_spin_btn.add_theme_stylebox_override("pressed",  _btn_style(Color(0.18, 0.06, 0.36)))
	_relic_spin_btn.add_theme_stylebox_override("focus",    _btn_style(Color(0.28, 0.10, 0.52)))
	_relic_spin_btn.add_theme_stylebox_override("disabled", _btn_style(Color(0.22, 0.22, 0.28)))
	_relic_spin_btn.pressed.connect(_on_relic_spin_pressed)
	qp.add_child(_relic_spin_btn)

	# ── Pool remaining label ──────────────────────────────────────────────────────
	_relic_pool_lbl = _label("", _font_reg, 15, Color(0.60, 0.60, 0.70))
	_relic_pool_lbl.position             = Vector2(0, 318)
	_relic_pool_lbl.size                 = Vector2(1280, 24)
	_relic_pool_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_relic_pool_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	qp.add_child(_relic_pool_lbl)

	_relic_refresh_spin_state()

	# ── Result popup (built hidden, child of main overlay so it's on top) ─────────
	_relic_build_result_popup(overlay)

	overlay.visibility_changed.connect(func():
		if overlay.visible and is_instance_valid(_gacha_gem_lbl):
			_gacha_gem_lbl.text = "🔷 %d" % GameData.blue_gems
		if overlay.visible:
			_refresh_quest_token_labels()
			_relic_refresh_spin_state()
	)


# ─────────────────────────────────────────────────────────────────────────────
# GACHA HELPERS
# ─────────────────────────────────────────────────────────────────────────────

func _gacha_switch_mode(mode: String) -> void:
	if _gacha_spinning or _relic_spinning:
		return
	_gacha_mode = mode
	var is_hero  : bool = (mode == "hero")
	var is_relic : bool = (mode == "relic")
	if is_instance_valid(_gacha_title_lbl):
		if is_relic:
			_gacha_title_lbl.text = "💎  Relic  Gacha"
		else:
			_gacha_title_lbl.text = "Hero  Gacha" if is_hero else "Tower  Gacha"
	if is_instance_valid(_gacha_tab_tower_btn):
		var tc : Color = C_TAB_ACT if mode == "tower" else C_TAB_IDLE
		_gacha_tab_tower_btn.add_theme_color_override("font_color", C_WHITE if mode == "tower" else C_DIM)
		_gacha_tab_tower_btn.add_theme_stylebox_override("normal", _btn_style(tc))
		_gacha_tab_tower_btn.add_theme_stylebox_override("hover",  _btn_style(tc.lightened(0.1)))
	if is_instance_valid(_gacha_tab_hero_btn):
		var hc : Color = C_TAB_ACT if is_hero else C_TAB_IDLE
		_gacha_tab_hero_btn.add_theme_color_override("font_color", C_WHITE if is_hero else C_DIM)
		_gacha_tab_hero_btn.add_theme_stylebox_override("normal", _btn_style(hc))
		_gacha_tab_hero_btn.add_theme_stylebox_override("hover",  _btn_style(hc.lightened(0.1)))
	if is_instance_valid(_gacha_tab_quest_btn):
		var qc : Color = C_TAB_ACT if is_relic else C_TAB_IDLE
		_gacha_tab_quest_btn.add_theme_color_override("font_color", C_WHITE if is_relic else C_DIM)
		_gacha_tab_quest_btn.add_theme_stylebox_override("normal", _btn_style(qc))
		_gacha_tab_quest_btn.add_theme_stylebox_override("hover",  _btn_style(qc.lightened(0.1)))
	# Swap gem / relic token header
	if is_instance_valid(_gacha_gem_lbl):
		_gacha_gem_lbl.visible = not is_relic
		if not is_relic:
			_gacha_gem_lbl.text = "🔷 %d" % GameData.blue_gems
			_gacha_gem_lbl.add_theme_color_override("font_color", Color(0.50, 0.82, 1.00))
	if is_instance_valid(_gacha_relic_coin):
		_gacha_relic_coin.visible = is_relic
	if is_instance_valid(_gacha_relic_tok_lbl):
		_gacha_relic_tok_lbl.visible = is_relic
	if is_instance_valid(_quest_shop_panel):
		_quest_shop_panel.visible = is_relic
		if is_relic:
			_refresh_quest_token_labels()
			_relic_refresh_spin_state()
	if not is_relic:
		if is_instance_valid(_gacha_summon_btn):
			var c1 : int = GACHA_HERO_SUMMON_COST if is_hero else GACHA_TOWER_SUMMON_COST
			_gacha_summon_btn.text = "✦  Summon x1    🔷 %d" % c1
		if is_instance_valid(_gacha_summon_10_btn):
			var c10 : int = GACHA_HERO_SUMMON_10_COST if is_hero else GACHA_TOWER_SUMMON_10_COST
			_gacha_summon_10_btn.text = "✦✦  Summon x10  🔷 %d" % c10
		_gacha_rebuild_strip("")


func _gacha_rebuild_strip(winning_id: String) -> void:
	if not is_instance_valid(_gacha_strip):
		return
	for child in _gacha_strip.get_children():
		child.queue_free()
	for i in range(GACHA_STRIP_COUNT):
		var tid : String
		if i == GACHA_WIN_IDX and winning_id != "":
			tid = winning_id
		else:
			tid = _gacha_random_dummy()
		var card := _gacha_make_wheel_card(tid)
		card.position = Vector2(i * GACHA_CARD_SLOT, 0)
		_gacha_strip.add_child(card)


func _gacha_random_dummy() -> String:
	var r : int = randi() % 100
	var pool : Array
	if _gacha_mode == "hero":
		if r < 1:      pool = HERO_LEGENDARY_IDS
		elif r < 5:    pool = HERO_EPIC_IDS
		elif r < 25:   pool = HERO_RARE_IDS
		else:          pool = HERO_COMMON_IDS
	else:
		if r < 1:      pool = SummonSystem.LEGENDARY_IDS
		elif r < 5:    pool = SummonSystem.EPIC_IDS
		elif r < 25:   pool = SummonSystem.RARE_IDS
		else:          pool = SummonSystem.COMMON_IDS
	return pool[randi() % pool.size()]


func _gacha_roll_tower() -> String:
	var r : int = randi() % 100
	var pool : Array
	if _gacha_mode == "hero":
		if r < 1:      pool = HERO_LEGENDARY_IDS
		elif r < 5:    pool = HERO_EPIC_IDS
		elif r < 25:   pool = HERO_RARE_IDS
		else:          pool = HERO_COMMON_IDS
	else:
		if r < 1:      pool = SummonSystem.LEGENDARY_IDS
		elif r < 5:    pool = SummonSystem.EPIC_IDS
		elif r < 25:   pool = SummonSystem.RARE_IDS
		else:          pool = SummonSystem.COMMON_IDS
	return pool[randi() % pool.size()]


func _gacha_make_wheel_card(tower_id: String) -> Control:
	var def    : Dictionary = SummonSystem.TURRET_DEFS.get(tower_id, GameData.HERO_DEFS.get(tower_id, {}))
	var rarity : String     = def.get("rarity", "common")
	var rcol   : Color      = SummonSystem.RARITY_COLORS.get(rarity, C_WHITE)

	var card := Panel.new()
	var cs   := StyleBoxFlat.new()
	cs.bg_color                   = Color(0.10, 0.10, 0.17)
	cs.corner_radius_top_left     = 8; cs.corner_radius_top_right    = 8
	cs.corner_radius_bottom_left  = 8; cs.corner_radius_bottom_right = 8
	cs.border_width_left  = 2; cs.border_width_right  = 2
	cs.border_width_top   = 2; cs.border_width_bottom = 2
	cs.border_color       = Color(rcol.r, rcol.g, rcol.b, 0.55)
	card.add_theme_stylebox_override("panel", cs)
	card.custom_minimum_size = Vector2(GACHA_CARD_W, GACHA_CARD_H)
	card.mouse_filter        = MOUSE_FILTER_IGNORE
	card.set_meta("style", cs)

	var pbg := Panel.new()
	var pbs := StyleBoxFlat.new()
	pbs.bg_color                  = Color(0.06, 0.06, 0.12)
	pbs.corner_radius_top_left    = 6; pbs.corner_radius_top_right    = 6
	pbs.corner_radius_bottom_left = 6; pbs.corner_radius_bottom_right = 6
	pbg.add_theme_stylebox_override("panel", pbs)
	pbg.position     = Vector2((GACHA_CARD_W - 80) / 2, 8)
	pbg.size         = Vector2(80, 80)
	pbg.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(pbg)

	var prev := _TurretPreview.new()
	prev.turret_data = def
	prev.position    = Vector2(28, 16)
	card.add_child(prev)

	var name_lbl := _label(def.get("name", tower_id), _font_bold, 12, C_WHITE)
	name_lbl.position             = Vector2(2, 93)
	name_lbl.size                 = Vector2(GACHA_CARD_W - 4, 18)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)

	var rar_lbl := _label(rarity.capitalize(), _font_reg, 11, rcol)
	rar_lbl.position             = Vector2(2, 113)
	rar_lbl.size                 = Vector2(GACHA_CARD_W - 4, 16)
	rar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rar_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	card.add_child(rar_lbl)

	var stripe := ColorRect.new()
	stripe.color        = Color(rcol.r, rcol.g, rcol.b, 0.28)
	stripe.position     = Vector2(2, GACHA_CARD_H - 12)
	stripe.size         = Vector2(GACHA_CARD_W - 4, 10)
	stripe.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(stripe)

	return card


func _gacha_build_result_popup(parent: Control) -> void:
	const PW : int = 480
	const PH : int = 372

	var dim := ColorRect.new()
	dim.color        = Color(0, 0, 0, 0.76)
	dim.position     = Vector2.ZERO
	dim.size         = Vector2(1280, 720)
	dim.mouse_filter = MOUSE_FILTER_STOP
	dim.z_index      = 50
	dim.visible      = false
	parent.add_child(dim)
	_gacha_result_panel = dim

	var panel := Panel.new()
	var ps    := StyleBoxFlat.new()
	ps.bg_color                   = Color(0.07, 0.06, 0.14, 0.98)
	ps.corner_radius_top_left     = 14; ps.corner_radius_top_right    = 14
	ps.corner_radius_bottom_left  = 14; ps.corner_radius_bottom_right = 14
	ps.border_width_left  = 3; ps.border_width_right  = 3
	ps.border_width_top   = 3; ps.border_width_bottom = 3
	ps.border_color       = Color(0.50, 0.50, 0.60, 0.50)
	ps.shadow_color       = Color(0, 0, 0, 0.86)
	ps.shadow_size        = 24
	panel.add_theme_stylebox_override("panel", ps)
	panel.position     = Vector2((1280 - PW) / 2, (720 - PH) / 2)
	panel.size         = Vector2(PW, PH)
	panel.mouse_filter = MOUSE_FILTER_STOP
	panel.z_index      = 51
	dim.add_child(panel)
	_gacha_result_inner = panel
	_gacha_result_ps    = ps

	var hdr_s := StyleBoxFlat.new()
	hdr_s.bg_color                   = Color(0.12, 0.06, 0.26)
	hdr_s.corner_radius_top_left     = 12; hdr_s.corner_radius_top_right   = 12
	hdr_s.corner_radius_bottom_left  = 0;  hdr_s.corner_radius_bottom_right = 0
	var hdr := Panel.new()
	hdr.add_theme_stylebox_override("panel", hdr_s)
	hdr.position     = Vector2(3, 3)
	hdr.size         = Vector2(PW - 6, 54)
	hdr.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(hdr)

	_gacha_result_title = _label("Tower  Received!", _font_bold, 22, C_WHITE)
	_gacha_result_title.position             = Vector2(0, 14)
	_gacha_result_title.size                 = Vector2(PW, 30)
	_gacha_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gacha_result_title.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(_gacha_result_title)

	var glow_ring := ColorRect.new()
	glow_ring.color        = Color(0.50, 0.30, 1.0, 0.12)
	glow_ring.position     = Vector2((PW - 152) / 2, 62)
	glow_ring.size         = Vector2(152, 152)
	glow_ring.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(glow_ring)
	panel.set_meta("glow_ring", glow_ring)

	var card_bg := Panel.new()
	var cbs     := StyleBoxFlat.new()
	cbs.bg_color                  = Color(0.09, 0.09, 0.18)
	cbs.corner_radius_top_left    = 10; cbs.corner_radius_top_right    = 10
	cbs.corner_radius_bottom_left = 10; cbs.corner_radius_bottom_right = 10
	cbs.border_width_left  = 3; cbs.border_width_right  = 3
	cbs.border_width_top   = 3; cbs.border_width_bottom = 3
	cbs.border_color       = Color(0.50, 0.50, 0.60, 0.50)
	cbs.shadow_color       = Color(0, 0, 0, 0.60)
	cbs.shadow_size        = 10
	card_bg.add_theme_stylebox_override("panel", cbs)
	card_bg.position     = Vector2((PW - 130) / 2, 67)
	card_bg.size         = Vector2(130, 130)
	card_bg.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(card_bg)
	_gacha_result_card_s = cbs

	var prev := _TurretPreview.new()
	prev.turret_data = {}
	prev.scale       = Vector2(2.0, 2.0)
	prev.position    = Vector2(184, 68)
	panel.add_child(prev)
	_gacha_result_prev = prev

	_gacha_result_name = _label("", _font_bold, 23, C_WHITE)
	_gacha_result_name.position             = Vector2(0, 207)
	_gacha_result_name.size                 = Vector2(PW, 30)
	_gacha_result_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gacha_result_name.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(_gacha_result_name)

	_gacha_result_rar = _label("", _font_reg, 16, C_DIM)
	_gacha_result_rar.position             = Vector2(0, 239)
	_gacha_result_rar.size                 = Vector2(PW, 20)
	_gacha_result_rar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gacha_result_rar.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(_gacha_result_rar)

	_gacha_result_info = _label("", _font_bold, 15, Color(0.50, 0.82, 1.0))
	_gacha_result_info.position             = Vector2(0, 263)
	_gacha_result_info.size                 = Vector2(PW, 20)
	_gacha_result_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gacha_result_info.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(_gacha_result_info)

	_gacha_result_lvlup = _label("", _font_bold, 18, C_GOLD)
	_gacha_result_lvlup.position             = Vector2(0, 287)
	_gacha_result_lvlup.size                 = Vector2(PW, 24)
	_gacha_result_lvlup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gacha_result_lvlup.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(_gacha_result_lvlup)

	var ok_btn := Button.new()
	ok_btn.text       = "Collect"
	ok_btn.position   = Vector2((PW - 190) / 2, 322)
	ok_btn.size       = Vector2(190, 38)
	ok_btn.focus_mode = FOCUS_NONE
	ok_btn.add_theme_font_override("font",           _font_bold)
	ok_btn.add_theme_font_size_override("font_size", 17)
	ok_btn.add_theme_color_override("font_color",    C_WHITE)
	ok_btn.add_theme_stylebox_override("normal",  _btn_style(C_BTN))
	ok_btn.add_theme_stylebox_override("hover",   _btn_style(C_BTN_HOV))
	ok_btn.add_theme_stylebox_override("pressed", _btn_style(C_BTN.darkened(0.2)))
	ok_btn.add_theme_stylebox_override("focus",   _btn_style(C_BTN))
	ok_btn.pressed.connect(func():
		if is_instance_valid(_gacha_result_panel):
			_gacha_result_panel.visible = false
		_gacha_spinning = false
		_gacha_is_multi = false
		_gacha_enable_summon_btns()
		_refresh_tower_cards()
		_refresh_hero_cards()
	)
	panel.add_child(ok_btn)


func _gacha_build_multi_panel(parent: Control) -> void:
	const PW : int = 980
	const PH : int = 530

	var dim := ColorRect.new()
	dim.color        = Color(0, 0, 0, 0.76)
	dim.position     = Vector2.ZERO
	dim.size         = Vector2(1280, 720)
	dim.mouse_filter = MOUSE_FILTER_STOP
	dim.z_index      = 50
	dim.visible      = false
	parent.add_child(dim)
	_gacha_multi_panel = dim

	var panel := Panel.new()
	var ps    := StyleBoxFlat.new()
	ps.bg_color                   = Color(0.07, 0.06, 0.14, 0.98)
	ps.corner_radius_top_left     = 14; ps.corner_radius_top_right    = 14
	ps.corner_radius_bottom_left  = 14; ps.corner_radius_bottom_right = 14
	ps.border_width_left  = 3; ps.border_width_right  = 3
	ps.border_width_top   = 3; ps.border_width_bottom = 3
	ps.border_color       = Color(0.50, 0.50, 0.60, 0.50)
	ps.shadow_color       = Color(0, 0, 0, 0.86)
	ps.shadow_size        = 24
	panel.add_theme_stylebox_override("panel", ps)
	panel.position     = Vector2((1280 - PW) / 2, (720 - PH) / 2)
	panel.size         = Vector2(PW, PH)
	panel.mouse_filter = MOUSE_FILTER_STOP
	panel.z_index      = 51
	dim.add_child(panel)
	dim.set_meta("inner_panel", panel)

	var hdr_s := StyleBoxFlat.new()
	hdr_s.bg_color                   = Color(0.10, 0.05, 0.22)
	hdr_s.corner_radius_top_left     = 12; hdr_s.corner_radius_top_right   = 12
	hdr_s.corner_radius_bottom_left  = 0;  hdr_s.corner_radius_bottom_right = 0
	var hdr := Panel.new()
	hdr.add_theme_stylebox_override("panel", hdr_s)
	hdr.position     = Vector2(3, 3)
	hdr.size         = Vector2(PW - 6, 56)
	hdr.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(hdr)

	var title_lbl := _label("10x Summon Results", _font_bold, 24, C_WHITE)
	title_lbl.position             = Vector2(0, 14)
	title_lbl.size                 = Vector2(PW, 34)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(title_lbl)

	var grid := Control.new()
	grid.position     = Vector2(24, 68)
	grid.size         = Vector2(PW - 48, 224)
	grid.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(grid)
	dim.set_meta("grid", grid)

	var div := ColorRect.new()
	div.color        = Color(1, 1, 1, 0.07)
	div.position     = Vector2(20, 302)
	div.size         = Vector2(PW - 40, 1)
	div.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(div)

	var sum_lbl := _label("", _font_bold, 15, C_WHITE)
	sum_lbl.position             = Vector2(0, 310)
	sum_lbl.size                 = Vector2(PW, 26)
	sum_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sum_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(sum_lbl)
	dim.set_meta("sum_lbl", sum_lbl)

	var lvlup_lbl := _label("", _font_bold, 14, C_GOLD)
	lvlup_lbl.position             = Vector2(10, 342)
	lvlup_lbl.size                 = Vector2(PW - 20, 110)
	lvlup_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvlup_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	lvlup_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(lvlup_lbl)
	dim.set_meta("lvlup_lbl", lvlup_lbl)

	var collect_btn := Button.new()
	collect_btn.text       = "Collect All"
	collect_btn.position   = Vector2((PW - 240) / 2, 462)
	collect_btn.size       = Vector2(240, 50)
	collect_btn.focus_mode = FOCUS_NONE
	collect_btn.add_theme_font_override("font",           _font_bold)
	collect_btn.add_theme_font_size_override("font_size", 19)
	collect_btn.add_theme_color_override("font_color",    C_WHITE)
	collect_btn.add_theme_stylebox_override("normal",  _btn_style(C_BTN))
	collect_btn.add_theme_stylebox_override("hover",   _btn_style(C_BTN_HOV))
	collect_btn.add_theme_stylebox_override("pressed", _btn_style(C_BTN.darkened(0.2)))
	collect_btn.add_theme_stylebox_override("focus",   _btn_style(C_BTN))
	collect_btn.pressed.connect(func():
		if is_instance_valid(_gacha_multi_panel):
			_gacha_multi_panel.visible = false
		_gacha_spinning = false
		_gacha_is_multi = false
		_gacha_enable_summon_btns()
		_refresh_tower_cards()
		_refresh_hero_cards()
	)
	panel.add_child(collect_btn)


func _gacha_make_mini_card(tower_id: String) -> Control:
	const MCW : int = 180; const MCH : int = 104
	var def    : Dictionary = SummonSystem.TURRET_DEFS.get(tower_id, GameData.HERO_DEFS.get(tower_id, {}))
	var rarity : String     = def.get("rarity", "common")
	var rcol   : Color      = SummonSystem.RARITY_COLORS.get(rarity, C_WHITE)

	var card := Panel.new()
	var cs   := StyleBoxFlat.new()
	cs.bg_color                   = Color(0.10, 0.10, 0.17)
	cs.corner_radius_top_left     = 6; cs.corner_radius_top_right    = 6
	cs.corner_radius_bottom_left  = 6; cs.corner_radius_bottom_right = 6
	cs.border_width_left  = 2; cs.border_width_right  = 2
	cs.border_width_top   = 2; cs.border_width_bottom = 2
	cs.border_color       = Color(rcol.r, rcol.g, rcol.b, 0.72)
	card.add_theme_stylebox_override("panel", cs)
	card.custom_minimum_size = Vector2(MCW, MCH)
	card.mouse_filter        = MOUSE_FILTER_IGNORE

	var pbg := Panel.new()
	var pbs := StyleBoxFlat.new()
	pbs.bg_color                  = Color(0.06, 0.06, 0.12)
	pbs.corner_radius_top_left    = 5; pbs.corner_radius_top_right    = 5
	pbs.corner_radius_bottom_left = 5; pbs.corner_radius_bottom_right = 5
	pbg.add_theme_stylebox_override("panel", pbs)
	pbg.position     = Vector2(8, 14)
	pbg.size         = Vector2(60, 60)
	pbg.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(pbg)

	var prev := _TurretPreview.new()
	prev.turret_data = def
	prev.position    = Vector2(10, 12)
	card.add_child(prev)

	var name_lbl := _label(def.get("name", tower_id), _font_bold, 12, C_WHITE)
	name_lbl.position     = Vector2(74, 16)
	name_lbl.size         = Vector2(MCW - 80, 18)
	name_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)

	var rar_lbl := _label(rarity.capitalize(), _font_reg, 11, rcol)
	rar_lbl.position     = Vector2(74, 36)
	rar_lbl.size         = Vector2(MCW - 80, 16)
	rar_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(rar_lbl)

	var copy_lbl := _label("+1 Copy", _font_bold, 11, Color(0.50, 0.82, 1.0))
	copy_lbl.position     = Vector2(74, 54)
	copy_lbl.size         = Vector2(MCW - 80, 16)
	copy_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(copy_lbl)

	var stripe := ColorRect.new()
	stripe.color        = Color(rcol.r, rcol.g, rcol.b, 0.22)
	stripe.position     = Vector2(2, MCH - 8)
	stripe.size         = Vector2(MCW - 4, 6)
	stripe.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(stripe)

	return card


func _gacha_on_summon_pressed() -> void:
	if _gacha_spinning:
		return
	var cost : int = GACHA_HERO_SUMMON_COST if _gacha_mode == "hero" else GACHA_TOWER_SUMMON_COST
	if GameData.blue_gems < cost:
		_gacha_flash_gems_red()
		return
	GameData.blue_gems -= cost
	GameData.save_game()
	_gacha_refresh_gems()
	_gacha_spinning = true
	_gacha_is_multi = false
	_gacha_disable_summon_btns()
	var result_id : String = _gacha_roll_tower()
	_gacha_rebuild_strip(result_id)
	_gacha_spin(result_id)


func _gacha_on_summon_10_pressed() -> void:
	if _gacha_spinning:
		return
	var cost : int = GACHA_HERO_SUMMON_10_COST if _gacha_mode == "hero" else GACHA_TOWER_SUMMON_10_COST
	if GameData.blue_gems < cost:
		_gacha_flash_gems_red()
		return
	GameData.blue_gems -= cost
	GameData.save_game()
	_gacha_refresh_gems()
	_gacha_spinning = true
	_gacha_is_multi = true
	_gacha_disable_summon_btns()
	_gacha_multi_results.clear()
	for _i in range(10):
		_gacha_multi_results.append(_gacha_roll_tower())
	var display_id : String = _gacha_multi_results[randi() % 10]
	_gacha_rebuild_strip(display_id)
	_gacha_spin(display_id)


func _gacha_flash_gems_red() -> void:
	if not is_instance_valid(_gacha_gem_lbl):
		return
	_gacha_gem_lbl.add_theme_color_override("font_color", C_RED)
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(func():
		if is_instance_valid(_gacha_gem_lbl):
			_gacha_gem_lbl.add_theme_color_override("font_color", Color(0.50, 0.82, 1.0))
	)


func _gacha_disable_summon_btns() -> void:
	if is_instance_valid(_gacha_summon_btn):    _gacha_summon_btn.disabled    = true
	if is_instance_valid(_gacha_summon_10_btn): _gacha_summon_10_btn.disabled = true


func _gacha_enable_summon_btns() -> void:
	if is_instance_valid(_gacha_summon_btn):    _gacha_summon_btn.disabled    = false
	if is_instance_valid(_gacha_summon_10_btn): _gacha_summon_10_btn.disabled = false


func _gacha_refresh_gems() -> void:
	if is_instance_valid(_gacha_gem_lbl):
		_gacha_gem_lbl.text = "🔷 %d" % GameData.blue_gems


func _gacha_spin(result_id: String) -> void:
	if not is_instance_valid(_gacha_strip):
		return
	const START_X : float = 4.0
	const END_X   : float = 420.0 - GACHA_WIN_IDX * GACHA_CARD_SLOT - GACHA_CARD_W / 2.0
	_gacha_strip.position.x = START_X
	if is_instance_valid(_gacha_tween):
		_gacha_tween.kill()
	_gacha_tween = create_tween()
	_gacha_tween.set_trans(Tween.TRANS_EXPO)
	_gacha_tween.set_ease(Tween.EASE_OUT)
	_gacha_tween.tween_property(_gacha_strip, "position:x", END_X, GACHA_SPIN_DURATION)
	_gacha_tween.tween_callback(func():
		_gacha_highlight_win_card()
		var seq := create_tween()
		seq.tween_interval(0.92)
		seq.tween_callback(func():
			if _gacha_is_multi:
				_gacha_award_and_show_multi()
			else:
				_gacha_award_and_show_single(result_id)
		)
	)


func _gacha_highlight_win_card() -> void:
	if not is_instance_valid(_gacha_strip):
		return
	var children := _gacha_strip.get_children()

	for i in range(children.size()):
		if i != GACHA_WIN_IDX:
			var sib : Control = children[i]
			var dtw := create_tween()
			dtw.tween_property(sib, "modulate", Color(0.28, 0.28, 0.38, 1.0), 0.42)

	if GACHA_WIN_IDX >= children.size():
		return
	var wc     : Control      = children[GACHA_WIN_IDX]
	var wstyle : StyleBoxFlat = wc.get_meta("style", null)

	if wstyle != null:
		wstyle.border_width_left   = 3
		wstyle.border_width_right  = 3
		wstyle.border_width_top    = 3
		wstyle.border_width_bottom = 3
		var gold_tw := create_tween()
		gold_tw.set_loops(3)
		gold_tw.tween_method(func(a: float):
			wstyle.border_color = Color(0.95, 0.76, 0.10, a)
		, 0.20, 1.0, 0.22)
		gold_tw.tween_method(func(a: float):
			wstyle.border_color = Color(0.95, 0.76, 0.10, a)
		, 1.0, 0.42, 0.22)

	wc.pivot_offset = Vector2(GACHA_CARD_W / 2.0, GACHA_CARD_H / 2.0)
	var stw := create_tween()
	stw.set_ease(Tween.EASE_OUT)
	stw.set_trans(Tween.TRANS_BACK)
	stw.tween_property(wc, "scale", Vector2(1.08, 1.08), 0.30)

	var shine := ColorRect.new()
	shine.color        = Color(1.0, 0.95, 0.80, 0.44)
	shine.position     = Vector2(-38.0, 0.0)
	shine.size         = Vector2(30, GACHA_CARD_H)
	shine.rotation     = deg_to_rad(10.0)
	shine.mouse_filter = MOUSE_FILTER_IGNORE
	shine.z_index      = 10
	wc.clip_contents   = true
	wc.add_child(shine)
	var sh_tw := create_tween()
	sh_tw.tween_interval(0.08)
	sh_tw.tween_property(shine, "position:x", float(GACHA_CARD_W + 12), 0.30)
	sh_tw.tween_callback(func():
		if is_instance_valid(shine):
			shine.queue_free()
	)


func _gacha_award_and_show_single(tower_id: String) -> void:
	var old_level : int = GameData.get_tower_level(tower_id)
	GameData.add_tower_copy(tower_id)
	var new_level : int = GameData.get_tower_level(tower_id)
	_gacha_show_result(tower_id, old_level, new_level)


func _gacha_award_and_show_multi() -> void:
	var level_ups : Array = []
	for tid in _gacha_multi_results:
		var old_lv : int = GameData.get_tower_level(tid)
		GameData.add_tower_copy(tid)
		var new_lv : int = GameData.get_tower_level(tid)
		if new_lv > old_lv:
			level_ups.append({"id": tid, "old": old_lv, "new": new_lv})
	_gacha_show_multi_result(level_ups)


func _gacha_show_result(tower_id: String, old_level: int, new_level: int) -> void:
	var def    : Dictionary = SummonSystem.TURRET_DEFS.get(tower_id, GameData.HERO_DEFS.get(tower_id, {}))
	var rarity : String     = def.get("rarity", "common")
	var rcol   : Color      = SummonSystem.RARITY_COLORS.get(rarity, C_WHITE)

	if is_instance_valid(_gacha_result_title):
		var kind : String = "Hero" if _gacha_mode == "hero" else "Tower"
		match rarity:
			"legendary": _gacha_result_title.text = "** Legendary %s! **" % kind
			"epic":      _gacha_result_title.text = "*  Epic %s!" % kind
			"rare":      _gacha_result_title.text = "Rare %s!" % kind
			_:           _gacha_result_title.text = "%s  Received!" % kind

	if _gacha_result_ps    != null: _gacha_result_ps.border_color    = Color(rcol.r, rcol.g, rcol.b, 0.65)
	if _gacha_result_card_s != null: _gacha_result_card_s.border_color = Color(rcol.r, rcol.g, rcol.b, 0.80)

	if is_instance_valid(_gacha_result_inner):
		var gr : ColorRect = _gacha_result_inner.get_meta("glow_ring", null)
		if gr != null:
			gr.color = Color(rcol.r, rcol.g, rcol.b, 0.14)

	if is_instance_valid(_gacha_result_prev):
		_gacha_result_prev.turret_data = def
		_gacha_result_prev.queue_redraw()
	if is_instance_valid(_gacha_result_name):
		_gacha_result_name.text = def.get("name", tower_id)
	if is_instance_valid(_gacha_result_rar):
		_gacha_result_rar.text = rarity.capitalize()
		_gacha_result_rar.add_theme_color_override("font_color", rcol)

	var copies : int = GameData.get_tower_xp(tower_id)
	if is_instance_valid(_gacha_result_info):
		if new_level >= GameData.TOWER_MAX_LEVEL:
			_gacha_result_info.text = "+1 Copy  (Lv.%d MAX)" % new_level
		else:
			var needed : int = GameData.copies_needed_for_level(new_level)
			_gacha_result_info.text = "+1 Copy  ·  Lv.%d  (%d / %d)" % [new_level, copies, needed]

	if is_instance_valid(_gacha_result_lvlup):
		_gacha_result_lvlup.text = ("Level Up!  Lv.%d -> Lv.%d" % [old_level, new_level]) \
			if new_level > old_level else ""

	if is_instance_valid(_gacha_result_panel):
		_gacha_result_panel.visible = true
	if is_instance_valid(_gacha_result_inner):
		_gacha_result_inner.pivot_offset = _gacha_result_inner.size / 2.0
		_gacha_result_inner.scale        = Vector2(0.82, 0.82)
		var pop := create_tween()
		pop.set_ease(Tween.EASE_OUT)
		pop.set_trans(Tween.TRANS_BACK)
		pop.tween_property(_gacha_result_inner, "scale", Vector2(1.0, 1.0), 0.32)


func _gacha_show_multi_result(level_ups: Array) -> void:
	if not is_instance_valid(_gacha_multi_panel):
		return
	var dim     : Control = _gacha_multi_panel
	var panel   : Control = dim.get_meta("inner_panel")
	var grid    : Control = dim.get_meta("grid")
	var sum_lbl : Label   = dim.get_meta("sum_lbl")
	var lvl_lbl : Label   = dim.get_meta("lvlup_lbl")

	for child in grid.get_children():
		child.queue_free()
	const MCW : int = 180; const MCH : int = 104; const MCG : int = 8
	for i in range(_gacha_multi_results.size()):
		var mini := _gacha_make_mini_card(_gacha_multi_results[i])
		mini.position = Vector2((i % 5) * (MCW + MCG), (i / 5) * (MCH + MCG))
		grid.add_child(mini)

	var counts : Dictionary = {"common": 0, "rare": 0, "epic": 0, "legendary": 0}
	for tid in _gacha_multi_results:
		var r : String = SummonSystem.TURRET_DEFS.get(tid, GameData.HERO_DEFS.get(tid, {})).get("rarity", "common")
		if counts.has(r):
			counts[r] += 1
	var parts : Array = []
	if counts["legendary"] > 0: parts.append("%d Legendary" % counts["legendary"])
	if counts["epic"]      > 0: parts.append("%d Epic"      % counts["epic"])
	if counts["rare"]      > 0: parts.append("%d Rare"      % counts["rare"])
	if counts["common"]    > 0: parts.append("%d Common"    % counts["common"])
	sum_lbl.text = "  /  ".join(parts)

	if level_ups.size() > 0:
		var lup_parts : Array = []
		for lu in level_ups:
			var dname : String = SummonSystem.TURRET_DEFS.get(lu["id"], GameData.HERO_DEFS.get(lu["id"], {})).get("name", lu["id"])
			lup_parts.append("%s  Lv.%d->Lv.%d" % [dname, lu["old"], lu["new"]])
		lvl_lbl.text = "   ·   ".join(lup_parts)
	else:
		lvl_lbl.text = ""

	dim.visible = true
	panel.pivot_offset = panel.size / 2.0
	panel.scale        = Vector2(0.88, 0.88)
	var pop := create_tween()
	pop.set_ease(Tween.EASE_OUT)
	pop.set_trans(Tween.TRANS_BACK)
	pop.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.35)

# ══════════════════════════════════════════════════════════════════════════════
# RELIC WHEEL (shop tab)
# ══════════════════════════════════════════════════════════════════════════════

func _relic_make_wheel_card(relic_id: String, grayed: bool = false) -> Control:
	var def  : Dictionary = GameData.get_relic_def(relic_id)
	var rcol : Color      = def.get("color", C_WHITE) if not grayed else Color(0.35, 0.35, 0.40)

	var card := Panel.new()
	var cs   := StyleBoxFlat.new()
	cs.bg_color                   = Color(0.10, 0.10, 0.17) if not grayed else Color(0.08, 0.08, 0.12)
	cs.corner_radius_top_left     = 8; cs.corner_radius_top_right    = 8
	cs.corner_radius_bottom_left  = 8; cs.corner_radius_bottom_right = 8
	cs.border_width_left  = 2; cs.border_width_right  = 2
	cs.border_width_top   = 2; cs.border_width_bottom = 2
	cs.border_color       = Color(rcol.r, rcol.g, rcol.b, 0.55)
	card.add_theme_stylebox_override("panel", cs)
	card.custom_minimum_size = Vector2(GACHA_CARD_W, GACHA_CARD_H)
	card.mouse_filter        = MOUSE_FILTER_IGNORE
	card.set_meta("style", cs)

	# Icon circle background
	var ibg := Panel.new()
	var ibs := StyleBoxFlat.new()
	ibs.bg_color = Color(rcol.r * 0.18, rcol.g * 0.18, rcol.b * 0.18, 1.0)
	const ICR : int = 32
	ibs.corner_radius_top_left     = ICR; ibs.corner_radius_top_right    = ICR
	ibs.corner_radius_bottom_left  = ICR; ibs.corner_radius_bottom_right = ICR
	ibs.border_width_left = 2; ibs.border_width_right  = 2
	ibs.border_width_top  = 2; ibs.border_width_bottom = 2
	ibs.border_color = Color(rcol.r, rcol.g, rcol.b, 0.55)
	ibg.add_theme_stylebox_override("panel", ibs)
	ibg.position     = Vector2((GACHA_CARD_W - ICR * 2) / 2, 8)
	ibg.size         = Vector2(ICR * 2, ICR * 2)
	ibg.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(ibg)

	var icon_lbl := _label(def.get("icon", "?"), _font_bold, 34, rcol)
	icon_lbl.position             = Vector2(0, 4)
	icon_lbl.size                 = Vector2(ICR * 2, ICR * 2)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	ibg.add_child(icon_lbl)

	var name_lbl := _label(def.get("name", relic_id), _font_bold, 11, C_WHITE if not grayed else Color(0.45, 0.45, 0.50))
	name_lbl.position             = Vector2(2, 78)
	name_lbl.size                 = Vector2(GACHA_CARD_W - 4, 36)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)

	var stripe := ColorRect.new()
	stripe.color        = Color(rcol.r, rcol.g, rcol.b, 0.28)
	stripe.position     = Vector2(2, GACHA_CARD_H - 12)
	stripe.size         = Vector2(GACHA_CARD_W - 4, 10)
	stripe.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(stripe)

	return card


func _relic_random_dummy() -> String:
	var all_ids : Array = []
	for r in GameData.RELIC_DEFS:
		all_ids.append(r["id"])
	return all_ids[randi() % all_ids.size()]


func _relic_rebuild_strip(winning_id: String) -> void:
	if not is_instance_valid(_relic_strip):
		return
	for child in _relic_strip.get_children():
		child.queue_free()
	var pool : Array = GameData.get_relic_pool()
	for i in range(GACHA_STRIP_COUNT):
		var rid : String
		if i == GACHA_WIN_IDX and winning_id != "":
			rid = winning_id
		else:
			rid = _relic_random_dummy()
		var card := _relic_make_wheel_card(rid)
		card.position = Vector2(i * GACHA_CARD_SLOT, 0)
		_relic_strip.add_child(card)


func _relic_refresh_spin_state() -> void:
	var pool : Array = GameData.get_relic_pool()
	if not is_instance_valid(_relic_pool_lbl):
		return
	if pool.is_empty():
		_relic_pool_lbl.text = "✔  All 10 relics collected!"
		if is_instance_valid(_relic_spin_btn):
			_relic_spin_btn.disabled = true
			_relic_spin_btn.text     = "All Relics Collected"
	else:
		_relic_pool_lbl.text = "%d relic%s remaining in pool  —  Equal chance for each" % [pool.size(), "s" if pool.size() != 1 else ""]
		if is_instance_valid(_relic_spin_btn):
			var can_spin : bool = GameData.quest_tokens >= 200 and not _relic_spinning
			_relic_spin_btn.disabled = not can_spin
			_relic_spin_btn.text     = "💎  Spin  —  ★ 200"


func _on_relic_spin_pressed() -> void:
	if _relic_spinning:
		return
	var pool : Array = GameData.get_relic_pool()
	if pool.is_empty():
		return
	if GameData.quest_tokens < 200:
		return
	GameData.quest_tokens -= 200
	GameData.save_game()
	_refresh_quest_token_labels()
	_relic_spinning = true
	if is_instance_valid(_relic_spin_btn):
		_relic_spin_btn.disabled = true
	var result_id : String = pool[randi() % pool.size()]
	_relic_rebuild_strip(result_id)
	_relic_spin(result_id)


func _relic_spin(result_id: String) -> void:
	if not is_instance_valid(_relic_strip):
		return
	const START_X : float = 4.0
	const END_X   : float = 420.0 - GACHA_WIN_IDX * GACHA_CARD_SLOT - GACHA_CARD_W / 2.0
	_relic_strip.position.x = START_X
	if is_instance_valid(_relic_tween):
		_relic_tween.kill()
	_relic_tween = create_tween()
	_relic_tween.set_trans(Tween.TRANS_EXPO)
	_relic_tween.set_ease(Tween.EASE_OUT)
	_relic_tween.tween_property(_relic_strip, "position:x", END_X, GACHA_SPIN_DURATION)
	_relic_tween.tween_callback(func():
		_relic_highlight_win_card()
		var seq := create_tween()
		seq.tween_interval(0.92)
		seq.tween_callback(func():
			_relic_award_and_show(result_id)
		)
	)


func _relic_highlight_win_card() -> void:
	if not is_instance_valid(_relic_strip):
		return
	var children := _relic_strip.get_children()
	for i in range(children.size()):
		if i != GACHA_WIN_IDX:
			var dtw := create_tween()
			dtw.tween_property(children[i], "modulate", Color(0.28, 0.28, 0.38, 1.0), 0.42)
	if GACHA_WIN_IDX >= children.size():
		return
	var wc     : Control      = children[GACHA_WIN_IDX]
	var wstyle : StyleBoxFlat = wc.get_meta("style", null)
	if wstyle != null:
		wstyle.border_width_left   = 3; wstyle.border_width_right  = 3
		wstyle.border_width_top    = 3; wstyle.border_width_bottom = 3
		var gold_tw := create_tween()
		gold_tw.set_loops(3)
		gold_tw.tween_method(func(a: float): wstyle.border_color = Color(0.95, 0.76, 0.10, a), 0.20, 1.0, 0.22)
		gold_tw.tween_method(func(a: float): wstyle.border_color = Color(0.95, 0.76, 0.10, a), 1.0, 0.42, 0.22)
	wc.pivot_offset = Vector2(GACHA_CARD_W / 2.0, GACHA_CARD_H / 2.0)
	var stw := create_tween()
	stw.set_ease(Tween.EASE_OUT)
	stw.set_trans(Tween.TRANS_BACK)
	stw.tween_property(wc, "scale", Vector2(1.08, 1.08), 0.30)


func _relic_award_and_show(relic_id: String) -> void:
	if not GameData.relics_collected.has(relic_id):
		GameData.relics_collected.append(relic_id)
		GameData.relic_levels[relic_id] = 1
		GameData.save_game()
	_relic_show_result(relic_id)


func _relic_show_result(relic_id: String) -> void:
	var def  : Dictionary = GameData.get_relic_def(relic_id)
	if not is_instance_valid(_relic_result_pop):
		return
	var name_l : Label = _relic_result_pop.get_meta("name_lbl", null)
	var desc_l : Label = _relic_result_pop.get_meta("desc_lbl", null)
	var icon_l : Label = _relic_result_pop.get_meta("icon_lbl", null)
	var ibg_p  : Panel = _relic_result_pop.get_meta("icon_bg",  null)
	if name_l: name_l.text = def.get("name", relic_id)
	if desc_l: desc_l.text = GameData.get_relic_effect_text(relic_id, 1)
	if icon_l: icon_l.text = def.get("icon", "?")
	var rcol : Color = def.get("color", C_WHITE)
	if icon_l: icon_l.add_theme_color_override("font_color", rcol)
	if ibg_p:
		var ibs2 := StyleBoxFlat.new()
		ibs2.bg_color = Color(rcol.r * 0.20, rcol.g * 0.20, rcol.b * 0.20)
		const IBR : int = 52
		ibs2.corner_radius_top_left     = IBR; ibs2.corner_radius_top_right    = IBR
		ibs2.corner_radius_bottom_left  = IBR; ibs2.corner_radius_bottom_right = IBR
		ibs2.border_width_left = 3; ibs2.border_width_right  = 3
		ibs2.border_width_top  = 3; ibs2.border_width_bottom = 3
		ibs2.border_color = rcol
		ibg_p.add_theme_stylebox_override("panel", ibs2)
	_relic_result_pop.visible = true
	var pop := create_tween()
	pop.set_ease(Tween.EASE_OUT)
	pop.set_trans(Tween.TRANS_BACK)
	_relic_result_pop.scale = Vector2(0.8, 0.8)
	_relic_result_pop.pivot_offset = Vector2(240, 180)
	pop.tween_property(_relic_result_pop, "scale", Vector2(1.0, 1.0), 0.35)


func _relic_build_result_popup(parent: Control) -> void:
	const PW : int = 480; const PH : int = 360
	var panel := Panel.new()
	var ps    := StyleBoxFlat.new()
	ps.bg_color                   = Color(0.06, 0.04, 0.12, 0.97)
	ps.corner_radius_top_left     = 18; ps.corner_radius_top_right    = 18
	ps.corner_radius_bottom_left  = 18; ps.corner_radius_bottom_right = 18
	ps.border_width_left = 3; ps.border_width_right  = 3
	ps.border_width_top  = 3; ps.border_width_bottom = 3
	ps.border_color      = Color(0.65, 0.35, 1.00, 0.80)
	ps.shadow_color      = Color(0.30, 0.10, 0.60, 0.60)
	ps.shadow_size       = 24
	panel.add_theme_stylebox_override("panel", ps)
	panel.position      = Vector2((1280 - PW) / 2, (720 - PH) / 2)
	panel.size          = Vector2(PW, PH)
	panel.mouse_filter  = MOUSE_FILTER_STOP
	panel.visible       = false
	panel.z_index       = 20
	parent.add_child(panel)
	_relic_result_pop = panel

	var header := _label("✦  New Relic!", _font_bold, 22, Color(0.90, 0.75, 1.00))
	header.position             = Vector2(0, 18)
	header.size                 = Vector2(PW, 32)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(header)

	const IBR2 : int = 52
	var icon_bg := Panel.new()
	icon_bg.position     = Vector2(PW / 2 - IBR2, 58)
	icon_bg.size         = Vector2(IBR2 * 2, IBR2 * 2)
	icon_bg.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(icon_bg)
	panel.set_meta("icon_bg", icon_bg)

	var icon_lbl := _label("?", _font_bold, 58, C_WHITE)
	icon_lbl.position             = Vector2(0, 6)
	icon_lbl.size                 = Vector2(IBR2 * 2, IBR2 * 2)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	icon_bg.add_child(icon_lbl)
	panel.set_meta("icon_lbl", icon_lbl)

	var name_lbl := _label("", _font_bold, 24, C_WHITE)
	name_lbl.position             = Vector2(20, 174)
	name_lbl.size                 = Vector2(PW - 40, 36)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(name_lbl)
	panel.set_meta("name_lbl", name_lbl)

	var desc_lbl := _label("", _font_reg, 16, Color(0.75, 0.75, 0.80))
	desc_lbl.position      = Vector2(30, 218)
	desc_lbl.size          = Vector2(PW - 60, 52)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.mouse_filter  = MOUSE_FILTER_IGNORE
	panel.add_child(desc_lbl)
	panel.set_meta("desc_lbl", desc_lbl)

	var close_btn := Button.new()
	close_btn.text       = "Collect  ✔"
	close_btn.position   = Vector2((PW - 200) / 2, 284)
	close_btn.size       = Vector2(200, 52)
	close_btn.focus_mode = FOCUS_NONE
	close_btn.add_theme_font_override("font",           _font_bold)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color",    C_WHITE)
	close_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.18, 0.38, 0.18)))
	close_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.24, 0.50, 0.24)))
	close_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.12, 0.26, 0.12)))
	close_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.18, 0.38, 0.18)))
	close_btn.pressed.connect(func():
		panel.visible  = false
		_relic_spinning = false
		_relic_rebuild_strip("")
		_relic_refresh_spin_state()
		_refresh_quest_token_labels()
	)
	panel.add_child(close_btn)


# ══════════════════════════════════════════════════════════════════════════════
# MY RELICS SCREEN (main menu)
# ══════════════════════════════════════════════════════════════════════════════

func _build_relics_screen() -> void:
	var overlay := Panel.new()
	var bg_s := StyleBoxFlat.new()
	bg_s.bg_color = Color(0.03, 0.03, 0.09)
	overlay.add_theme_stylebox_override("panel", bg_s)
	overlay.position     = Vector2.ZERO
	overlay.size         = Vector2(1280, 720)
	overlay.mouse_filter = MOUSE_FILTER_STOP
	overlay.visible      = false
	add_child(overlay)
	_relic_screen = overlay

	# Top band
	var top_band := ColorRect.new()
	top_band.color    = Color(0.28, 0.10, 0.52, 0.45)
	top_band.position = Vector2.ZERO
	top_band.size     = Vector2(1280, 80)
	top_band.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(top_band)

	var title := _label("💎  My Relics", _font_bold, 34, C_WHITE)
	title.position             = Vector2(30, 16)
	title.size                 = Vector2(600, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.mouse_filter         = MOUSE_FILTER_IGNORE
	overlay.add_child(title)

	# Quest token balance — top-right of the header band
	const RS_D : int = 22; const RS_GAP : int = 6; const RS_FS : int = 18
	var rs_tw : float = _font_bold.get_string_size("00000 ★", HORIZONTAL_ALIGNMENT_LEFT, -1, RS_FS).x
	var rs_label_x : int = 1280 - 20 - int(rs_tw)   # 20px right margin
	var rs_coin_x  : int = rs_label_x - RS_GAP - RS_D
	_relics_screen_tok_coin = _make_token_coin(RS_D)
	_relics_screen_tok_coin.position = Vector2(rs_coin_x, 22)
	_relics_screen_tok_coin.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(_relics_screen_tok_coin)
	_relics_screen_tok_lbl = _label("%d ★" % GameData.quest_tokens, _font_bold, RS_FS, Color(0.88, 0.72, 1.00))
	_relics_screen_tok_lbl.position             = Vector2(rs_label_x, 20)
	_relics_screen_tok_lbl.size                 = Vector2(int(rs_tw) + 4, 28)
	_relics_screen_tok_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_relics_screen_tok_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	overlay.add_child(_relics_screen_tok_lbl)

	# "My Relics" section header
	var my_hdr := _label("My Relics", _font_bold, 18, Color(0.82, 0.65, 1.00))
	my_hdr.position     = Vector2(50, 90)
	my_hdr.size         = Vector2(400, 28)
	my_hdr.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(my_hdr)

	# My relics grid container (top half)
	var my_grid := Control.new()
	my_grid.position     = Vector2(0, 118)
	my_grid.size         = Vector2(1280, 220)
	my_grid.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(my_grid)
	_relic_my_grid = my_grid

	# Divider
	var div := ColorRect.new()
	div.color        = Color(0.50, 0.25, 0.80, 0.30)
	div.position     = Vector2(60, 348)
	div.size         = Vector2(1160, 2)
	div.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(div)

	# "Undiscovered Relics" section header
	var unk_hdr := _label("Undiscovered Relics", _font_bold, 18, Color(0.50, 0.50, 0.58))
	unk_hdr.position     = Vector2(50, 358)
	unk_hdr.size         = Vector2(500, 28)
	unk_hdr.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(unk_hdr)

	# Undiscovered grid container (bottom half)
	var unk_grid := Control.new()
	unk_grid.position     = Vector2(0, 386)
	unk_grid.size         = Vector2(1280, 230)
	unk_grid.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(unk_grid)
	_relic_unk_grid = unk_grid

	# Info popup (undiscovered relics)
	_relic_build_info_popup(overlay)

	# Detail popup (owned relics — shows level + upgrade)
	_build_relic_detail_popup(overlay)

	# Back button
	var back_btn := Button.new()
	back_btn.text       = "← Back"
	back_btn.position   = Vector2(30, 662)
	back_btn.size       = Vector2(140, 44)
	back_btn.focus_mode = FOCUS_NONE
	back_btn.add_theme_font_override("font",           _font_bold)
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.add_theme_color_override("font_color",    C_WHITE)
	back_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.22, 0.22, 0.28)))
	back_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.30, 0.30, 0.38)))
	back_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.16, 0.16, 0.20)))
	back_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.22, 0.22, 0.28)))
	back_btn.pressed.connect(func():
		overlay.visible           = false
		_game_over_screen.visible = true
	)
	overlay.add_child(back_btn)

	# Debug: Reset All Relics button
	var reset_relics_btn := Button.new()
	reset_relics_btn.text       = "⚠ Reset All Relics"
	reset_relics_btn.position   = Vector2(200, 662)
	reset_relics_btn.size       = Vector2(220, 44)
	reset_relics_btn.focus_mode = FOCUS_NONE
	reset_relics_btn.add_theme_font_override("font",           _font_bold)
	reset_relics_btn.add_theme_font_size_override("font_size", 15)
	reset_relics_btn.add_theme_color_override("font_color",    C_WHITE)
	reset_relics_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.55, 0.18, 0.18)))
	reset_relics_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.70, 0.22, 0.22)))
	reset_relics_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.40, 0.12, 0.12)))
	reset_relics_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.55, 0.18, 0.18)))
	reset_relics_btn.pressed.connect(func():
		GameData.relics_collected.clear()
		GameData.relic_levels.clear()
		GameData.save_game()
		_refresh_relics_screen()
	)
	overlay.add_child(reset_relics_btn)

	_refresh_relics_screen()


func _relic_build_info_popup(parent: Control) -> void:
	const PW : int = 420; const PH : int = 280

	# Container covers the full screen; hiding it hides backdrop + panel together.
	var container := Control.new()
	container.position     = Vector2.ZERO
	container.size         = Vector2(1280, 720)
	container.mouse_filter = MOUSE_FILTER_IGNORE
	container.visible      = false
	container.z_index      = 20
	parent.add_child(container)
	_relic_info_popup = container

	# Transparent backdrop — clicking anywhere outside the panel closes it.
	var backdrop := Button.new()
	var bd_s := StyleBoxFlat.new(); bd_s.bg_color = Color(0, 0, 0, 0)
	backdrop.add_theme_stylebox_override("normal",  bd_s)
	backdrop.add_theme_stylebox_override("hover",   bd_s)
	backdrop.add_theme_stylebox_override("pressed", bd_s)
	backdrop.add_theme_stylebox_override("focus",   bd_s)
	backdrop.position   = Vector2.ZERO
	backdrop.size       = Vector2(1280, 720)
	backdrop.focus_mode = FOCUS_NONE
	backdrop.pressed.connect(func(): container.visible = false)
	container.add_child(backdrop)

	var panel := Panel.new()
	var ps    := StyleBoxFlat.new()
	ps.bg_color                   = Color(0.06, 0.04, 0.12, 0.97)
	ps.corner_radius_top_left     = 14; ps.corner_radius_top_right    = 14
	ps.corner_radius_bottom_left  = 14; ps.corner_radius_bottom_right = 14
	ps.border_width_left = 2; ps.border_width_right  = 2
	ps.border_width_top  = 2; ps.border_width_bottom = 2
	ps.border_color      = Color(0.55, 0.25, 0.90, 0.70)
	ps.shadow_color      = Color(0.20, 0.05, 0.40, 0.55)
	ps.shadow_size       = 18
	panel.add_theme_stylebox_override("panel", ps)
	panel.position     = Vector2((1280 - PW) / 2, (720 - PH) / 2)
	panel.size         = Vector2(PW, PH)
	panel.mouse_filter = MOUSE_FILTER_STOP
	container.add_child(panel)

	# Icon clipped to its own panel so large emoji cannot overflow
	const ICON_SIZE : int = 68
	var icon_clip := Panel.new()
	var icon_clip_s := StyleBoxFlat.new()
	icon_clip_s.bg_color = Color(0, 0, 0, 0)
	icon_clip.add_theme_stylebox_override("panel", icon_clip_s)
	icon_clip.position       = Vector2((PW - ICON_SIZE) / 2, 16)
	icon_clip.size           = Vector2(ICON_SIZE, ICON_SIZE)
	icon_clip.clip_contents  = true
	icon_clip.mouse_filter   = MOUSE_FILTER_IGNORE
	panel.add_child(icon_clip)

	var icon_lbl := _label("?", _font_bold, 38, C_WHITE)
	icon_lbl.position             = Vector2(0, 0)
	icon_lbl.size                 = Vector2(ICON_SIZE, ICON_SIZE)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	icon_clip.add_child(icon_lbl)
	container.set_meta("icon_lbl", icon_lbl)

	var name_lbl := _label("", _font_bold, 20, C_WHITE)
	name_lbl.position             = Vector2(20, 94)
	name_lbl.size                 = Vector2(PW - 40, 28)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(name_lbl)
	_relic_info_name = name_lbl
	container.set_meta("name_lbl", name_lbl)

	var div2 := ColorRect.new()
	div2.color        = Color(0.50, 0.25, 0.80, 0.30)
	div2.position     = Vector2(20, 130)
	div2.size         = Vector2(PW - 40, 1)
	div2.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(div2)

	var desc_lbl := _label("", _font_reg, 15, Color(0.78, 0.78, 0.85))
	desc_lbl.position      = Vector2(20, 140)
	desc_lbl.size          = Vector2(PW - 40, 90)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.mouse_filter  = MOUSE_FILTER_IGNORE
	panel.add_child(desc_lbl)
	_relic_info_desc = desc_lbl
	container.set_meta("desc_lbl", desc_lbl)

	var close_btn := Button.new()
	close_btn.text       = "Close"
	close_btn.position   = Vector2((PW - 140) / 2, PH - 50)
	close_btn.size       = Vector2(140, 40)
	close_btn.focus_mode = FOCUS_NONE
	close_btn.add_theme_font_override("font",           _font_bold)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.add_theme_color_override("font_color",    C_WHITE)
	close_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.22, 0.22, 0.30)))
	close_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.30, 0.30, 0.40)))
	close_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.16, 0.16, 0.22)))
	close_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.22, 0.22, 0.30)))
	close_btn.pressed.connect(func(): container.visible = false)
	panel.add_child(close_btn)


func _relic_show_info(relic_id: String, collected: bool) -> void:
	var def  : Dictionary = GameData.get_relic_def(relic_id)
	if not is_instance_valid(_relic_info_popup):
		return
	var icon_l : Label = _relic_info_popup.get_meta("icon_lbl", null)
	var name_l : Label = _relic_info_popup.get_meta("name_lbl", null)
	var desc_l : Label = _relic_info_popup.get_meta("desc_lbl", null)
	var rcol   : Color = def.get("color", C_WHITE) if collected else Color(0.45, 0.45, 0.50)
	if icon_l:
		icon_l.text = def.get("icon", "?")
		icon_l.add_theme_color_override("font_color", rcol)
	if name_l:
		name_l.text = def.get("name", relic_id)
		name_l.add_theme_color_override("font_color", C_WHITE if collected else Color(0.65, 0.65, 0.70))
	if desc_l:
		var lv : int = GameData.get_relic_level(relic_id) if collected else 1
		desc_l.text = GameData.get_relic_effect_text(relic_id, lv)
		desc_l.add_theme_color_override("font_color",
			Color(0.78, 0.78, 0.85) if collected else Color(0.55, 0.55, 0.60))
	_relic_info_popup.visible = true


func _relic_make_grid_card(relic_id: String, collected: bool) -> Control:
	var def   : Dictionary = GameData.get_relic_def(relic_id)
	var rcol  : Color      = def.get("color", C_WHITE) if collected else Color(0.38, 0.38, 0.44)
	var level : int        = GameData.get_relic_level(relic_id) if collected else 0
	var card_h : int       = 158 if collected else 126

	var container := Control.new()
	container.mouse_filter = MOUSE_FILTER_IGNORE
	container.size         = Vector2(108, card_h)

	# Background
	var bg  := Panel.new()
	var bs  := StyleBoxFlat.new()
	bs.bg_color                   = Color(0.10, 0.10, 0.17) if collected else Color(0.07, 0.07, 0.11)
	bs.corner_radius_top_left     = 10; bs.corner_radius_top_right    = 10
	bs.corner_radius_bottom_left  = 10; bs.corner_radius_bottom_right = 10
	bs.border_width_left = 2; bs.border_width_right  = 2
	bs.border_width_top  = 2; bs.border_width_bottom = 2
	bs.border_color = Color(rcol.r, rcol.g, rcol.b, 0.55 if collected else 0.22)
	bg.add_theme_stylebox_override("panel", bs)
	bg.position     = Vector2(0, 0)
	bg.size         = Vector2(108, card_h)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	container.add_child(bg)

	# Icon circle
	const GCR : int = 28
	var ibg := Panel.new()
	var ibs := StyleBoxFlat.new()
	ibs.bg_color = Color(rcol.r * 0.20, rcol.g * 0.20, rcol.b * 0.20)
	ibs.corner_radius_top_left     = GCR; ibs.corner_radius_top_right    = GCR
	ibs.corner_radius_bottom_left  = GCR; ibs.corner_radius_bottom_right = GCR
	ibs.border_width_left = 2; ibs.border_width_right  = 2
	ibs.border_width_top  = 2; ibs.border_width_bottom = 2
	ibs.border_color = Color(rcol.r, rcol.g, rcol.b, 0.50)
	ibg.add_theme_stylebox_override("panel", ibs)
	ibg.position     = Vector2((108 - GCR * 2) / 2, 8)
	ibg.size         = Vector2(GCR * 2, GCR * 2)
	ibg.mouse_filter = MOUSE_FILTER_IGNORE
	container.add_child(ibg)

	var icon_l := _label(def.get("icon", "?"), _font_bold, 28, rcol)
	icon_l.position             = Vector2(0, 3)
	icon_l.size                 = Vector2(GCR * 2, GCR * 2)
	icon_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	icon_l.mouse_filter         = MOUSE_FILTER_IGNORE
	ibg.add_child(icon_l)

	# Name
	var name_l := _label(def.get("name", relic_id) if collected else "???", _font_bold, 10,
		C_WHITE if collected else Color(0.45, 0.45, 0.50))
	name_l.position      = Vector2(4, 64)
	name_l.size          = Vector2(100, 34)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.mouse_filter  = MOUSE_FILTER_IGNORE
	container.add_child(name_l)

	if collected:
		# Level badge
		var lv_l := _label("Lv %d" % level, _font_bold, 10, Color(rcol.r, rcol.g, rcol.b, 0.90))
		lv_l.position             = Vector2(0, 100)
		lv_l.size                 = Vector2(108, 14)
		lv_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lv_l.mouse_filter         = MOUSE_FILTER_IGNORE
		container.add_child(lv_l)

		# Transparent face button (top area → opens detail page)
		var face_s := StyleBoxFlat.new(); face_s.bg_color = Color(0, 0, 0, 0)
		var face_h := StyleBoxFlat.new(); face_h.bg_color = Color(1, 1, 1, 0.06)
		face_h.corner_radius_top_left = 10; face_h.corner_radius_top_right = 10
		var face_btn := Button.new()
		face_btn.position   = Vector2(0, 0)
		face_btn.size       = Vector2(108, 116)
		face_btn.focus_mode = FOCUS_NONE
		face_btn.add_theme_stylebox_override("normal",  face_s)
		face_btn.add_theme_stylebox_override("hover",   face_h)
		face_btn.add_theme_stylebox_override("pressed", face_s)
		face_btn.add_theme_stylebox_override("focus",   face_s)
		face_btn.pressed.connect(func(): _show_relic_detail(relic_id))
		container.add_child(face_btn)

		# Quick upgrade button (bottom)
		var cost       : int   = GameData.get_relic_upgrade_cost(relic_id)
		var affordable : bool  = GameData.quest_tokens >= cost
		var upg_col    : Color = Color(0.12, 0.36, 0.12) if affordable else Color(0.20, 0.20, 0.26)
		var upg_btn := Button.new()
		upg_btn.text       = "↑ Lv%d  ★%d" % [level + 1, cost]
		upg_btn.position   = Vector2(4, 120)
		upg_btn.size       = Vector2(100, 28)
		upg_btn.focus_mode = FOCUS_NONE
		upg_btn.disabled   = not affordable
		upg_btn.add_theme_font_override("font",           _font_bold)
		upg_btn.add_theme_font_size_override("font_size", 10)
		upg_btn.add_theme_color_override("font_color",    C_WHITE)
		upg_btn.add_theme_stylebox_override("normal",   _btn_style(upg_col))
		upg_btn.add_theme_stylebox_override("hover",    _btn_style(upg_col.lightened(0.15)))
		upg_btn.add_theme_stylebox_override("pressed",  _btn_style(upg_col.darkened(0.2)))
		upg_btn.add_theme_stylebox_override("focus",    _btn_style(upg_col))
		upg_btn.add_theme_stylebox_override("disabled", _btn_style(Color(0.16, 0.16, 0.20)))
		upg_btn.pressed.connect(func(): _relic_upgrade(relic_id))
		container.add_child(upg_btn)
	else:
		# Face click → info popup for undiscovered
		var face_s := StyleBoxFlat.new(); face_s.bg_color = Color(0, 0, 0, 0)
		var face_h := StyleBoxFlat.new(); face_h.bg_color = Color(1, 1, 1, 0.04)
		var face_btn := Button.new()
		face_btn.position   = Vector2(0, 0)
		face_btn.size       = Vector2(108, 126)
		face_btn.focus_mode = FOCUS_NONE
		face_btn.add_theme_stylebox_override("normal",  face_s)
		face_btn.add_theme_stylebox_override("hover",   face_h)
		face_btn.add_theme_stylebox_override("pressed", face_s)
		face_btn.add_theme_stylebox_override("focus",   face_s)
		face_btn.pressed.connect(func(): _relic_show_info(relic_id, false))
		container.add_child(face_btn)

	return container


func _refresh_relics_screen() -> void:
	if not is_instance_valid(_relic_my_grid) or not is_instance_valid(_relic_unk_grid):
		return
	for c in _relic_my_grid.get_children():
		c.queue_free()
	for c in _relic_unk_grid.get_children():
		c.queue_free()

	const CARD_W    : int = 108
	const CARD_H_OWN: int = 158   # collected card height (includes upgrade button)
	const CARD_H_UNK: int = 126   # undiscovered card height
	const CARD_GAP  : int = 12

	var my_ids  : Array = GameData.relics_collected
	var unk_ids : Array = []
	for r in GameData.RELIC_DEFS:
		if not GameData.relics_collected.has(r["id"]):
			unk_ids.append(r["id"])

	# My relics grid (up to 10 in one row, centered)
	var total_w_my : int = my_ids.size() * (CARD_W + CARD_GAP) - (CARD_GAP if my_ids.size() > 0 else 0)
	var x_start_my : int = maxi(40, (1280 - total_w_my) / 2) if my_ids.size() > 0 else 0
	if my_ids.is_empty():
		var no_lbl := _label("No relics yet — spin the Relic Gacha in the Shop!", _font_reg, 16, Color(0.45, 0.45, 0.52))
		no_lbl.position             = Vector2(0, 65)
		no_lbl.size                 = Vector2(1280, 30)
		no_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
		_relic_my_grid.add_child(no_lbl)
	else:
		for i in range(my_ids.size()):
			var card := _relic_make_grid_card(my_ids[i], true)
			card.position = Vector2(x_start_my + i * (CARD_W + CARD_GAP), (220 - CARD_H_OWN) / 2)
			_relic_my_grid.add_child(card)

	# Undiscovered grid
	var total_w_unk : int = unk_ids.size() * (CARD_W + CARD_GAP) - (CARD_GAP if unk_ids.size() > 0 else 0)
	var x_start_unk : int = (1280 - total_w_unk) / 2 if unk_ids.size() > 0 else 0
	if unk_ids.is_empty():
		var all_lbl := _label("✔  All relics discovered — upgrade them below!", _font_bold, 18, Color(0.25, 0.88, 0.55))
		all_lbl.position             = Vector2(0, 65)
		all_lbl.size                 = Vector2(1280, 30)
		all_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		all_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
		_relic_unk_grid.add_child(all_lbl)
	else:
		for i in range(unk_ids.size()):
			var card := _relic_make_grid_card(unk_ids[i], false)
			card.position = Vector2(x_start_unk + i * (CARD_W + CARD_GAP), (230 - CARD_H_UNK) / 2)
			_relic_unk_grid.add_child(card)


func _build_relic_detail_popup(parent: Control) -> void:
	var backdrop := ColorRect.new()
	backdrop.color        = Color(0, 0, 0, 0.55)
	backdrop.position     = Vector2.ZERO
	backdrop.size         = Vector2(1280, 720)
	backdrop.mouse_filter = MOUSE_FILTER_STOP
	backdrop.z_index      = 21
	backdrop.visible      = false
	backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			backdrop.visible = false
			if is_instance_valid(_relic_detail_popup):
				_relic_detail_popup.visible = false
	)
	parent.add_child(backdrop)
	_relic_detail_backdrop = backdrop

	const PW : int = 600; const PH : int = 452
	var panel := Panel.new()
	var ps    := StyleBoxFlat.new()
	ps.bg_color                   = Color(0.05, 0.04, 0.12, 0.97)
	ps.corner_radius_top_left     = 18; ps.corner_radius_top_right    = 18
	ps.corner_radius_bottom_left  = 18; ps.corner_radius_bottom_right = 18
	ps.border_width_left = 3; ps.border_width_right  = 3
	ps.border_width_top  = 3; ps.border_width_bottom = 3
	ps.border_color = Color(0.60, 0.30, 1.00, 0.80)
	ps.shadow_color = Color(0.25, 0.08, 0.55, 0.65)
	ps.shadow_size  = 28
	panel.add_theme_stylebox_override("panel", ps)
	panel.position     = Vector2((1280 - PW) / 2, (720 - PH) / 2)
	panel.size         = Vector2(PW, PH)
	panel.mouse_filter = MOUSE_FILTER_STOP
	panel.visible      = false
	panel.z_index      = 22
	parent.add_child(panel)
	_relic_detail_popup = panel

	# Icon circle (left column)
	const DR : int = 58
	var icon_bg := Panel.new()
	icon_bg.position     = Vector2(18, 18)
	icon_bg.size         = Vector2(DR * 2, DR * 2)
	icon_bg.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(icon_bg)
	panel.set_meta("icon_bg", icon_bg)

	_relic_detail_icon = _label("?", _font_bold, 60, C_WHITE)
	_relic_detail_icon.position             = Vector2(0, 6)
	_relic_detail_icon.size                 = Vector2(DR * 2, DR * 2)
	_relic_detail_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_relic_detail_icon.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_relic_detail_icon.mouse_filter         = MOUSE_FILTER_IGNORE
	icon_bg.add_child(_relic_detail_icon)

	# Right column: name + level + upgrade-to label
	_relic_detail_name = _label("", _font_bold, 24, C_WHITE)
	_relic_detail_name.position     = Vector2(DR * 2 + 30, 20)
	_relic_detail_name.size         = Vector2(PW - DR * 2 - 50, 34)
	_relic_detail_name.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(_relic_detail_name)

	_relic_detail_level = _label("", _font_bold, 16, Color(0.82, 0.65, 1.00))
	_relic_detail_level.position     = Vector2(DR * 2 + 30, 58)
	_relic_detail_level.size         = Vector2(PW - DR * 2 - 50, 24)
	_relic_detail_level.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(_relic_detail_level)

	_relic_detail_cost = _label("", _font_bold, 13, Color(0.55, 0.55, 0.62))
	_relic_detail_cost.position     = Vector2(DR * 2 + 30, 84)
	_relic_detail_cost.size         = Vector2(PW - DR * 2 - 50, 20)
	_relic_detail_cost.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(_relic_detail_cost)

	# Divider 1
	var div1 := ColorRect.new()
	div1.color    = Color(0.45, 0.22, 0.75, 0.30)
	div1.position = Vector2(18, 148)
	div1.size     = Vector2(PW - 36, 1)
	div1.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(div1)

	# Current effect
	var cur_hdr := _label("Current Effect:", _font_bold, 13, Color(0.60, 0.60, 0.68))
	cur_hdr.position     = Vector2(18, 158)
	cur_hdr.size         = Vector2(PW - 36, 20)
	cur_hdr.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(cur_hdr)

	_relic_detail_cur = _label("", _font_reg, 16, C_WHITE)
	_relic_detail_cur.position      = Vector2(18, 180)
	_relic_detail_cur.size          = Vector2(PW - 36, 58)
	_relic_detail_cur.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_relic_detail_cur.mouse_filter  = MOUSE_FILTER_IGNORE
	panel.add_child(_relic_detail_cur)

	# Divider 2
	var div2 := ColorRect.new()
	div2.color    = Color(0.45, 0.22, 0.75, 0.30)
	div2.position = Vector2(18, 246)
	div2.size     = Vector2(PW - 36, 1)
	div2.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(div2)

	# Next level effect
	var nxt_hdr := _label("Next Level:", _font_bold, 13, Color(0.40, 0.75, 0.40))
	nxt_hdr.position     = Vector2(18, 256)
	nxt_hdr.size         = Vector2(PW - 36, 20)
	nxt_hdr.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(nxt_hdr)

	_relic_detail_next = _label("", _font_reg, 15, Color(0.60, 0.82, 0.60))
	_relic_detail_next.position      = Vector2(18, 278)
	_relic_detail_next.size          = Vector2(PW - 36, 55)
	_relic_detail_next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_relic_detail_next.mouse_filter  = MOUSE_FILTER_IGNORE
	panel.add_child(_relic_detail_next)

	# Divider 3
	var div3 := ColorRect.new()
	div3.color    = Color(0.45, 0.22, 0.75, 0.30)
	div3.position = Vector2(18, 340)
	div3.size     = Vector2(PW - 36, 1)
	div3.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(div3)

	# Token balance (coin icon + count)
	var dtok_coin := _make_token_coin(18)
	dtok_coin.position     = Vector2(18, 352)
	dtok_coin.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(dtok_coin)
	_relic_detail_tok_lbl = _label("0 ★", _font_bold, 15, Color(0.88, 0.72, 1.00))
	_relic_detail_tok_lbl.position     = Vector2(40, 350)
	_relic_detail_tok_lbl.size         = Vector2(PW - 58, 24)
	_relic_detail_tok_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(_relic_detail_tok_lbl)

	# Upgrade button
	_relic_detail_upg_btn = Button.new()
	_relic_detail_upg_btn.text       = "↑ Upgrade  ★ 200"
	_relic_detail_upg_btn.position   = Vector2(18, 382)
	_relic_detail_upg_btn.size       = Vector2(240, 52)
	_relic_detail_upg_btn.focus_mode = FOCUS_NONE
	_relic_detail_upg_btn.add_theme_font_override("font",           _font_bold)
	_relic_detail_upg_btn.add_theme_font_size_override("font_size", 18)
	_relic_detail_upg_btn.add_theme_color_override("font_color",    C_WHITE)
	_relic_detail_upg_btn.add_theme_stylebox_override("normal",   _btn_style(Color(0.10, 0.36, 0.10)))
	_relic_detail_upg_btn.add_theme_stylebox_override("hover",    _btn_style(Color(0.16, 0.50, 0.16)))
	_relic_detail_upg_btn.add_theme_stylebox_override("pressed",  _btn_style(Color(0.06, 0.24, 0.06)))
	_relic_detail_upg_btn.add_theme_stylebox_override("focus",    _btn_style(Color(0.10, 0.36, 0.10)))
	_relic_detail_upg_btn.add_theme_stylebox_override("disabled", _btn_style(Color(0.18, 0.18, 0.22)))
	_relic_detail_upg_btn.pressed.connect(func():
		_relic_upgrade(_relic_detail_id)
		_relic_refresh_detail()
	)
	panel.add_child(_relic_detail_upg_btn)

	# Close button
	var close_btn := Button.new()
	close_btn.text       = "Close"
	close_btn.position   = Vector2(PW - 158, 382)
	close_btn.size       = Vector2(140, 52)
	close_btn.focus_mode = FOCUS_NONE
	close_btn.add_theme_font_override("font",           _font_bold)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color",    C_WHITE)
	close_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.22, 0.22, 0.28)))
	close_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.30, 0.30, 0.38)))
	close_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.16, 0.16, 0.20)))
	close_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.22, 0.22, 0.28)))
	close_btn.pressed.connect(func():
		panel.visible = false
		if is_instance_valid(_relic_detail_backdrop):
			_relic_detail_backdrop.visible = false
	)
	panel.add_child(close_btn)


func _show_relic_detail(relic_id: String) -> void:
	_relic_detail_id = relic_id
	_relic_refresh_detail()
	if is_instance_valid(_relic_detail_popup):
		_relic_detail_popup.visible = true
	if is_instance_valid(_relic_detail_backdrop):
		_relic_detail_backdrop.visible = true


func _relic_refresh_detail() -> void:
	if not is_instance_valid(_relic_detail_popup):
		return
	var id    : String     = _relic_detail_id
	var def   : Dictionary = GameData.get_relic_def(id)
	var level : int        = GameData.get_relic_level(id)
	var cost  : int        = GameData.get_relic_upgrade_cost(id)
	var rcol  : Color      = def.get("color", C_WHITE)

	# Icon background style
	var icon_bg : Panel = _relic_detail_popup.get_meta("icon_bg", null)
	if icon_bg:
		const DR2 : int = 58
		var ibs := StyleBoxFlat.new()
		ibs.bg_color = Color(rcol.r * 0.18, rcol.g * 0.18, rcol.b * 0.18)
		ibs.corner_radius_top_left     = DR2; ibs.corner_radius_top_right    = DR2
		ibs.corner_radius_bottom_left  = DR2; ibs.corner_radius_bottom_right = DR2
		ibs.border_width_left = 3; ibs.border_width_right  = 3
		ibs.border_width_top  = 3; ibs.border_width_bottom = 3
		ibs.border_color = rcol
		icon_bg.add_theme_stylebox_override("panel", ibs)

	if _relic_detail_icon:
		_relic_detail_icon.text = def.get("icon", "?")
		_relic_detail_icon.add_theme_color_override("font_color", rcol)
	if _relic_detail_name:
		_relic_detail_name.text = def.get("name", id)
	if _relic_detail_level:
		_relic_detail_level.text = "Level %d" % level
	if _relic_detail_cost:
		_relic_detail_cost.text = "Upgrade to Level %d" % (level + 1)
	if _relic_detail_cur:
		_relic_detail_cur.text = GameData.get_relic_effect_text(id, level)
	if _relic_detail_next:
		_relic_detail_next.text = GameData.get_relic_effect_text(id, level + 1)
	if _relic_detail_tok_lbl:
		_relic_detail_tok_lbl.text = "%d ★" % GameData.quest_tokens
	if _relic_detail_upg_btn:
		_relic_detail_upg_btn.text     = "↑ Upgrade  ★ %d" % cost
		_relic_detail_upg_btn.disabled = GameData.quest_tokens < cost


func _relic_upgrade(relic_id: String) -> void:
	var cost : int = GameData.get_relic_upgrade_cost(relic_id)
	if GameData.quest_tokens < cost:
		return
	GameData.quest_tokens -= cost
	if not GameData.relic_levels.has(relic_id):
		GameData.relic_levels[relic_id] = 1
	GameData.relic_levels[relic_id] += 1
	GameData.save_game()
	_refresh_relics_screen()
	if is_instance_valid(_relic_detail_tok_lbl):
		_relic_detail_tok_lbl.text = "%d ★" % GameData.quest_tokens
	_refresh_quest_token_labels()


func _build_world_map_screen() -> void:
	# ── Overlay ──────────────────────────────────────────────────────────────
	var overlay := Panel.new()
	var bg_s    := StyleBoxFlat.new()
	bg_s.bg_color = Color(0.04, 0.05, 0.12)
	overlay.add_theme_stylebox_override("panel", bg_s)
	overlay.position     = Vector2.ZERO
	overlay.size         = Vector2(1280, 720)
	overlay.mouse_filter = MOUSE_FILTER_STOP
	overlay.visible      = false
	add_child(overlay)
	_world_map_screen = overlay

	# ── Map canvas ───────────────────────────────────────────────────────────
	var canvas_script := load("res://ui/WorldMapCanvas.gd")
	_wm_canvas = canvas_script.new()
	overlay.add_child(_wm_canvas)

	# ── Title bar ────────────────────────────────────────────────────────────
	var title_bg := ColorRect.new()
	title_bg.color        = Color(0.02, 0.04, 0.12, 0.85)
	title_bg.size         = Vector2(1280, 52)
	title_bg.position     = Vector2.ZERO
	title_bg.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(title_bg)

	var title := _label("⚔⚔  Campaign World Map", _font_bold, 26, C_GOLD)
	title.position             = Vector2(0, 10)
	title.size                 = Vector2(1280, 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(title)

	# ── Debug buttons ────────────────────────────────────────────────────────
	if DEBUG:
		var dbg_btn := Button.new()
		dbg_btn.text       = "Unlock All (Debug)"
		dbg_btn.position   = Vector2(840, 12)
		dbg_btn.size       = Vector2(192, 30)
		dbg_btn.focus_mode = FOCUS_NONE
		dbg_btn.add_theme_font_override("font",           _font_bold)
		dbg_btn.add_theme_font_size_override("font_size", 11)
		dbg_btn.add_theme_color_override("font_color",    C_WHITE)
		dbg_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.40, 0.14, 0.06)))
		dbg_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.56, 0.20, 0.08)))
		dbg_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.30, 0.10, 0.04)))
		dbg_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.40, 0.14, 0.06)))
		dbg_btn.pressed.connect(func():
			GameData.max_world_unlocked     = 10
			GameData.all_time_highest_stage = 10
			GameData.save_game()
			_refresh_world_map()
		)
		overlay.add_child(dbg_btn)

		var rst_btn := Button.new()
		rst_btn.text       = "Reset Progress (Debug)"
		rst_btn.position   = Vector2(1042, 12)
		rst_btn.size       = Vector2(210, 30)
		rst_btn.focus_mode = FOCUS_NONE
		rst_btn.add_theme_font_override("font",           _font_bold)
		rst_btn.add_theme_font_size_override("font_size", 11)
		rst_btn.add_theme_color_override("font_color",    C_WHITE)
		rst_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.14, 0.06, 0.40)))
		rst_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.20, 0.08, 0.56)))
		rst_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.10, 0.04, 0.30)))
		rst_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.14, 0.06, 0.40)))
		rst_btn.pressed.connect(func():
			GameData.max_world_unlocked     = 1
			GameData.all_time_highest_stage = 0
			GameData.save_game()
			_refresh_world_map()
		)
		overlay.add_child(rst_btn)

	# ── Territory labels & click buttons ─────────────────────────────────────
	var WM_DATA : Array = [
		{"name": "Garden Plains",     "color": Color(0.22, 0.65, 0.16), "pos": Vector2(280, 583)},
		{"name": "Deep Forest",       "color": Color(0.06, 0.38, 0.10), "pos": Vector2(198, 413)},
		{"name": "Desert Ruins",      "color": Color(0.78, 0.58, 0.18), "pos": Vector2(348, 240)},
		{"name": "Frost Peaks",       "color": Color(0.55, 0.78, 0.96), "pos": Vector2(548, 123)},
		{"name": "Volcanic Wastes",   "color": Color(0.88, 0.18, 0.08), "pos": Vector2(798, 157)},
		{"name": "Swamplands",        "color": Color(0.12, 0.48, 0.22), "pos": Vector2(1028, 337)},
		{"name": "Crystal Highlands", "color": Color(0.68, 0.22, 0.95), "pos": Vector2(938, 513)},
		{"name": "Shadow Realm",      "color": Color(0.28, 0.08, 0.55), "pos": Vector2(698, 577)},
		{"name": "Celestial Kingdom", "color": Color(0.95, 0.85, 0.28), "pos": Vector2(522, 457)},
		{"name": "Eternal Citadel",   "color": Color(0.88, 0.88, 0.95), "pos": Vector2(668, 267)},
	]
	_world_node_panels.clear()
	for i in range(10):
		var w     := i + 1
		var wdat  : Dictionary = WM_DATA[i]
		var wpos  : Vector2    = wdat["pos"]
		var wname : String     = wdat["name"]

		# World number label (above circle)
		var num_lbl := _label("W%d" % w, _font_bold, 12, Color(0.95, 0.92, 0.75, 0.85))
		num_lbl.position             = wpos + Vector2(-28, -52)
		num_lbl.size                 = Vector2(56, 18)
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		overlay.add_child(num_lbl)

		# Territory name (below circle)
		var name_lbl := _label(wname, _font_bold, 11, Color(0.92, 0.88, 0.72))
		name_lbl.position             = wpos + Vector2(-55, 36)
		name_lbl.size                 = Vector2(110, 18)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		overlay.add_child(name_lbl)

		# Status icon centred on circle  (⚔ / ★ / 🔒)
		var icon_lbl := _label("🔒", _font_bold, 22, Color(1, 1, 1, 0.88))
		icon_lbl.position             = wpos + Vector2(-20, -16)
		icon_lbl.size                 = Vector2(40, 32)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		overlay.add_child(icon_lbl)

		# Progress text (W1 only)
		var prog_lbl := _label("", _font_reg, 10, Color(0.80, 0.80, 0.70, 0.85))
		prog_lbl.position             = wpos + Vector2(-52, 54)
		prog_lbl.size                 = Vector2(104, 16)
		prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prog_lbl.visible              = false
		overlay.add_child(prog_lbl)

		# Invisible 66×66 click button centred on circle
		var btn := Button.new()
		btn.position   = wpos + Vector2(-33, -33)
		btn.size       = Vector2(66, 66)
		btn.flat       = true
		btn.focus_mode = FOCUS_NONE
		var _bn := StyleBoxFlat.new()
		_bn.bg_color = Color(0, 0, 0, 0)
		_bn.set_corner_radius_all(33)
		var _bh := StyleBoxFlat.new()
		_bh.bg_color = Color(1, 1, 1, 0.12)
		_bh.set_corner_radius_all(33)
		var _bp := StyleBoxFlat.new()
		_bp.bg_color = Color(1, 1, 1, 0.22)
		_bp.set_corner_radius_all(33)
		btn.add_theme_stylebox_override("normal",  _bn)
		btn.add_theme_stylebox_override("hover",   _bh)
		btn.add_theme_stylebox_override("pressed", _bp)
		btn.add_theme_stylebox_override("focus",   _bn)
		btn.pressed.connect(_on_world_node_pressed.bind(w))
		btn.mouse_entered.connect(func():
			if is_instance_valid(_wm_canvas):
				_wm_canvas.set_hovered(i)
		)
		btn.mouse_exited.connect(func():
			if is_instance_valid(_wm_canvas) and _wm_canvas.hovered_world == i:
				_wm_canvas.set_hovered(-1)
		)
		overlay.add_child(btn)

		_world_node_panels.append({
			"icon_lbl": icon_lbl,
			"prog_lbl": prog_lbl,
			"btn":      btn,
		})

	# ── Back button (world map → main menu) ─────────────────────────────────
	var back_btn := Button.new()
	back_btn.text       = "← Back"
	back_btn.position   = Vector2(30, 666)
	back_btn.size       = Vector2(148, 44)
	back_btn.focus_mode = FOCUS_NONE
	back_btn.add_theme_font_override("font",           _font_bold)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.add_theme_color_override("font_color",    C_WHITE)
	back_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.20, 0.20, 0.26)))
	back_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.28, 0.28, 0.36)))
	back_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.14, 0.14, 0.18)))
	back_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.20, 0.20, 0.26)))
	back_btn.pressed.connect(func():
		overlay.visible           = false
		_game_over_screen.visible = true
	)
	overlay.add_child(back_btn)

	_build_world_detail_screen()

	_refresh_world_map()


func _build_world_detail_screen() -> void:
	# Full-screen dim backdrop — blocks input to world map behind it
	var ds := ColorRect.new()
	ds.color        = Color(0.0, 0.0, 0.0, 0.65)
	ds.position     = Vector2.ZERO
	ds.size         = Vector2(1280, 720)
	ds.mouse_filter = MOUSE_FILTER_STOP
	ds.visible      = false
	add_child(ds)
	_wm_detail_screen = ds

	# Centered content panel (1100 × 580)
	var cp   := Panel.new()
	var cp_s := StyleBoxFlat.new()
	cp_s.bg_color     = Color(0.04, 0.05, 0.12, 0.97)
	cp_s.border_color = Color(0.30, 0.42, 0.72, 0.60)
	cp_s.set_border_width_all(1)
	cp_s.set_corner_radius_all(12)
	cp.add_theme_stylebox_override("panel", cp_s)
	cp.position     = Vector2(90, 50)
	cp.size         = Vector2(1100, 640)
	cp.mouse_filter = MOUSE_FILTER_STOP
	ds.add_child(cp)

	# Biome-colored header strip
	var dh   := ColorRect.new()
	var dh_s := StyleBoxFlat.new()
	dh_s.bg_color = Color(0.1, 0.1, 0.2)
	dh_s.set_corner_radius_all(12)
	dh_s.corner_radius_bottom_left  = 0
	dh_s.corner_radius_bottom_right = 0
	dh.position = Vector2(0, 0)
	dh.size     = Vector2(1100, 68)
	cp.add_child(dh)
	_wm_detail_header = dh

	# World name (in header)
	var dname := _label("", _font_bold, 28, Color(1.0, 0.98, 0.88))
	dname.position             = Vector2(0, 14)
	dname.size                 = Vector2(1100, 42)
	dname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cp.add_child(dname)
	_wm_detail_name = dname

	# ── Left column: status + description ────────────────────────────────────
	var dstatus := _label("", _font_bold, 15, C_WHITE)
	dstatus.position = Vector2(60, 86)
	dstatus.size     = Vector2(480, 26)
	cp.add_child(dstatus)
	_wm_detail_status = dstatus

	var ddiff := _label("", _font_bold, 15, Color(1.0, 0.85, 0.25))
	ddiff.position = Vector2(60, 116)
	ddiff.size     = Vector2(480, 26)
	cp.add_child(ddiff)
	_wm_detail_diff = ddiff

	var dstages := _label("", _font_reg, 13, Color(0.72, 0.88, 0.72))
	dstages.position = Vector2(60, 148)
	dstages.size     = Vector2(480, 22)
	cp.add_child(dstages)
	_wm_detail_stages = dstages

	var sep1 := ColorRect.new()
	sep1.color    = Color(0.30, 0.40, 0.68, 0.35)
	sep1.position = Vector2(60, 182)
	sep1.size     = Vector2(460, 1)
	cp.add_child(sep1)

	var ddesc := _label("", _font_reg, 13, Color(0.80, 0.78, 0.72))
	ddesc.position      = Vector2(60, 194)
	ddesc.size          = Vector2(460, 220)
	ddesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cp.add_child(ddesc)
	_wm_detail_desc = ddesc

	# Vertical divider
	var vdiv := ColorRect.new()
	vdiv.color    = Color(0.30, 0.40, 0.68, 0.30)
	vdiv.position = Vector2(560, 80)
	vdiv.size     = Vector2(1, 476)
	cp.add_child(vdiv)

	# ── Right column: minimap + map modifiers ────────────────────────────────
	var mm_script = load("res://ui/WorldMinimap.gd")
	var mm : Control = mm_script.new()
	mm.position = Vector2(600, 84)
	mm.size     = Vector2(460, 185)
	cp.add_child(mm)
	_wm_detail_minimap = mm

	var mod_hdr := _label("Map Modifiers", _font_bold, 15, Color(0.72, 0.82, 1.0))
	mod_hdr.position = Vector2(600, 282)
	mod_hdr.size     = Vector2(460, 26)
	cp.add_child(mod_hdr)

	var sep2 := ColorRect.new()
	sep2.color    = Color(0.30, 0.40, 0.68, 0.35)
	sep2.position = Vector2(600, 312)
	sep2.size     = Vector2(460, 1)
	cp.add_child(sep2)

	var mod_box := Control.new()
	mod_box.position = Vector2(600, 320)
	mod_box.size     = Vector2(460, 180)
	cp.add_child(mod_box)
	_wm_detail_mod_box = mod_box

	# ── Bottom bar ────────────────────────────────────────────────────────────
	var bot := ColorRect.new()
	bot.color    = Color(0.04, 0.04, 0.12, 0.95)
	bot.position = Vector2(0, 568)
	bot.size     = Vector2(1100, 72)
	cp.add_child(bot)

	var bot_sep := ColorRect.new()
	bot_sep.color    = Color(0.30, 0.40, 0.68, 0.35)
	bot_sep.position = Vector2(0, 568)
	bot_sep.size     = Vector2(1100, 1)
	cp.add_child(bot_sep)

	# Back button (bottom left of panel)
	var ds_back := Button.new()
	ds_back.text       = "← Back"
	ds_back.position   = Vector2(24, 582)
	ds_back.size       = Vector2(148, 44)
	ds_back.focus_mode = FOCUS_NONE
	ds_back.add_theme_font_override("font",           _font_bold)
	ds_back.add_theme_font_size_override("font_size", 17)
	ds_back.add_theme_color_override("font_color",    C_WHITE)
	ds_back.add_theme_stylebox_override("normal",  _btn_style(Color(0.20, 0.20, 0.26)))
	ds_back.add_theme_stylebox_override("hover",   _btn_style(Color(0.28, 0.28, 0.36)))
	ds_back.add_theme_stylebox_override("pressed", _btn_style(Color(0.14, 0.14, 0.18)))
	ds_back.add_theme_stylebox_override("focus",   _btn_style(Color(0.20, 0.20, 0.26)))
	ds_back.pressed.connect(func():
		ds.visible = false
	)
	cp.add_child(ds_back)

	# Start World button (bottom right of panel)
	var ds_play := Button.new()
	ds_play.text       = "▶  Start World"
	ds_play.position   = Vector2(752, 580)
	ds_play.size       = Vector2(300, 48)
	ds_play.focus_mode = FOCUS_NONE
	ds_play.add_theme_font_override("font",           _font_bold)
	ds_play.add_theme_font_size_override("font_size", 20)
	ds_play.add_theme_color_override("font_color",    C_WHITE)
	ds_play.add_theme_stylebox_override("normal",  _btn_style(C_BTN))
	ds_play.add_theme_stylebox_override("hover",   _btn_style(C_BTN_HOV))
	ds_play.add_theme_stylebox_override("pressed", _btn_style(C_BTN.darkened(0.25)))
	ds_play.add_theme_stylebox_override("focus",   _btn_style(C_BTN))
	ds_play.pressed.connect(func():
		ds.visible = false
		var world_to_load : int = _wm_selected_world
		_show_loading_screen(func():
			GameData.selected_world      = world_to_load
			GameData.launching_into_game = true
			get_tree().reload_current_scene()
		)
	)
	cp.add_child(ds_play)
	_wm_detail_start_btn = ds_play


func _show_loading_screen(callback: Callable) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 100
	get_tree().root.add_child(cl)
	var ls : Node2D = load("res://ui/LoadingScreen.gd").new()
	ls.setup(_font_bold,
		func(): callback.call(),
		func(): cl.queue_free()
	)
	cl.add_child(ls)


func _on_world_node_pressed(world_num: int) -> void:
	var unlocked := (world_num == 1) or (GameData.max_world_unlocked >= world_num)
	if not unlocked:
		return

	# Restore previous selection's icon before changing
	if _wm_selected_world > 0 and _wm_selected_world <= _world_node_panels.size():
		var prev := _wm_selected_world - 1
		var prev_w := _wm_selected_world
		var prev_lbl : Label = _world_node_panels[prev]["icon_lbl"]
		if GameData.max_world_unlocked > prev_w:
			prev_lbl.text     = "★"
			prev_lbl.modulate = Color(0.28, 0.96, 0.32)
		elif GameData.max_world_unlocked == prev_w:
			prev_lbl.text     = ""
		else:
			prev_lbl.text     = "🔒"
			prev_lbl.modulate = Color(0.60, 0.58, 0.55)

	_wm_selected_world = world_num
	var idx := world_num - 1

	# Show sword on newly clicked world
	if idx < _world_node_panels.size():
		var lbl : Label = _world_node_panels[idx]["icon_lbl"]
		lbl.text     = "⚔"
		lbl.modulate = Color(1.0, 1.0, 1.0, 0.95)

	# Update canvas selection + click animation
	if is_instance_valid(_wm_canvas):
		_wm_canvas.selected_world = idx
		_wm_canvas.do_click(idx)

	# World metadata
	var WORLD_NAMES : Array = [
		"Garden Plains", "Deep Forest", "Desert Ruins", "Frost Peaks",
		"Volcanic Wastes", "Swamplands", "Crystal Highlands",
		"Shadow Realm", "Celestial Kingdom", "Eternal Citadel",
	]
	var WORLD_DIFF : Array = [
		"⭐", "⭐⭐", "⭐⭐⭐", "⭐⭐⭐", "⭐⭐⭐⭐",
		"⭐⭐⭐⭐", "⭐⭐⭐⭐⭐", "⭐⭐⭐⭐⭐", "⭐⭐⭐⭐⭐", "⭐⭐⭐⭐⭐",
	]
	var WORLD_DESC : Array = [
		"Rolling meadows dotted with ancient oaks and colorful wildflowers. The perfect proving ground for any aspiring defender.",
		"A dense, fog-shrouded wilderness where the canopy swallows all light. Ancient creatures stir in the undergrowth.",
		"Crumbling temples and half-buried obelisks rise from endless dunes. The desert guards its secrets jealously.",
		"Jagged peaks crowned with eternal ice. Howling blizzards and freezing ambushes await the unprepared.",
		"Ash-choked wastelands lit by rivers of molten rock. Every step burns — every wave burns harder.",
		"Twisted mangroves and toxic bogs stretch without end. The mists conceal horrors that have never seen daylight.",
		"Soaring crystal formations that refract light into lethal prisms. Reality feels thin here.",
		"A realm beyond the veil, where shadow is substance and nothing casts a true shadow.",
		"Floating citadels wreathed in golden clouds. The divine armies are vast — and wholly merciless.",
		"The final bastion of an ancient evil. Every world's darkness converges here.",
	]
	var WORLD_COLORS : Array = [
		Color(0.22, 0.65, 0.16), Color(0.06, 0.38, 0.10), Color(0.78, 0.58, 0.18),
		Color(0.55, 0.78, 0.96), Color(0.88, 0.18, 0.08), Color(0.12, 0.48, 0.22),
		Color(0.68, 0.22, 0.95), Color(0.28, 0.08, 0.55), Color(0.95, 0.85, 0.28),
		Color(0.88, 0.88, 0.95),
	]

	var wclr  : Color  = WORLD_COLORS[idx]
	var wname : String = WORLD_NAMES[idx]
	var wdiff : String = WORLD_DIFF[idx]
	var wdesc : String = WORLD_DESC[idx]

	# State info
	var state : String
	if GameData.max_world_unlocked > world_num:
		state = "cleared"
	elif GameData.max_world_unlocked == world_num:
		state = "active"
	else:
		state = "locked"

	# Populate detail screen
	_wm_detail_header.color = Color(wclr.r * 0.45, wclr.g * 0.45, wclr.b * 0.45, 0.95)
	_wm_detail_name.text    = "World %d  —  %s" % [world_num, wname]
	_wm_detail_diff.text    = "Difficulty:  %s" % wdiff

	match state:
		"cleared":
			_wm_detail_status.text     = "★  Cleared"
			_wm_detail_status.modulate = Color(0.32, 1.0, 0.36)
		"active":
			_wm_detail_status.text     = "⚔  Active"
			_wm_detail_status.modulate = Color(1.0, 0.92, 0.28)
		_:
			_wm_detail_status.text     = "🔒  Locked"
			_wm_detail_status.modulate = Color(0.65, 0.62, 0.58)

	if world_num == 1:
		var stg : int = GameData.all_time_highest_stage
		_wm_detail_stages.text = "Stages cleared:  %d / 10" % mini(stg, 10)
	else:
		_wm_detail_stages.text = "10 stages"

	_wm_detail_desc.text = wdesc

	# Minimap
	var wpath   : Array = GameData.get_world_path(world_num)
	var wisland : Rect2 = GameData.get_world_island(world_num)
	_wm_detail_minimap.call("setup", wpath, wclr, wisland)

	# Modifier rows
	for child in _wm_detail_mod_box.get_children():
		child.queue_free()
	var mods : Array = GameData.get_world_modifiers(world_num)
	if mods.is_empty():
		var no_mod := _label("No modifiers — standard difficulty", _font_reg, 13, Color(0.65, 0.70, 0.68))
		no_mod.position = Vector2(0, 4)
		no_mod.size     = Vector2(460, 24)
		_wm_detail_mod_box.add_child(no_mod)
	else:
		for mi in range(mods.size()):
			var m   : Dictionary = mods[mi]
			var row := _label("• " + m["label"], _font_reg, 13, m["color"])
			row.position = Vector2(0, mi * 26)
			row.size     = Vector2(460, 24)
			_wm_detail_mod_box.add_child(row)

	_wm_detail_start_btn.disabled = not unlocked

	# Show detail screen on top; world map stays visible (selection animation plays)
	_wm_detail_screen.visible = true


func _refresh_world_map() -> void:
	if _world_node_panels.is_empty() or _wm_canvas == null:
		return
	# Reset selection state when the map is refreshed (e.g. after debug unlock)
	if is_instance_valid(_wm_detail_screen) and _wm_detail_screen.visible:
		_wm_detail_screen.visible = false
	_wm_canvas.selected_world = -1
	# Auto-unlock world 2 when the player clears all 10 stages of world 1
	if GameData.all_time_highest_stage >= 10 and GameData.max_world_unlocked < 2:
		GameData.max_world_unlocked = 2
		GameData.save_game()

	var WM_DATA : Array = [
		{"color": Color(0.22, 0.65, 0.16), "pos": Vector2(280, 583)},
		{"color": Color(0.06, 0.38, 0.10), "pos": Vector2(198, 413)},
		{"color": Color(0.78, 0.58, 0.18), "pos": Vector2(348, 240)},
		{"color": Color(0.55, 0.78, 0.96), "pos": Vector2(548, 123)},
		{"color": Color(0.88, 0.18, 0.08), "pos": Vector2(798, 157)},
		{"color": Color(0.12, 0.48, 0.22), "pos": Vector2(1028, 337)},
		{"color": Color(0.68, 0.22, 0.95), "pos": Vector2(938, 513)},
		{"color": Color(0.28, 0.08, 0.55), "pos": Vector2(698, 577)},
		{"color": Color(0.95, 0.85, 0.28), "pos": Vector2(522, 457)},
		{"color": Color(0.88, 0.88, 0.95), "pos": Vector2(668, 267)},
	]

	# Push territory states to the canvas node
	_wm_canvas.territory_states = []
	for i in range(10):
		var w := i + 1
		var state : String
		if GameData.max_world_unlocked > w:
			state = "cleared"
		elif GameData.max_world_unlocked == w:
			state = "active"
		else:
			state = "locked"
		_wm_canvas.territory_states.append({
			"pos":   WM_DATA[i]["pos"],
			"color": WM_DATA[i]["color"],
			"state": state,
		})

	# Update overlay labels / buttons
	for i in range(_world_node_panels.size()):
		var w    := i + 1
		var refs : Dictionary = _world_node_panels[i]
		var state : String
		if GameData.max_world_unlocked > w:
			state = "cleared"
		elif GameData.max_world_unlocked == w:
			state = "active"
		else:
			state = "locked"

		var icon_lbl : Label  = refs["icon_lbl"]
		var prog_lbl : Label  = refs["prog_lbl"]
		var btn      : Button = refs["btn"]

		if w == _wm_selected_world:
			icon_lbl.text     = "⚔"
			icon_lbl.modulate = Color(1.0, 1.0, 1.0, 0.95)
			btn.disabled      = state == "locked"
		else:
			match state:
				"active":
					icon_lbl.text     = ""
					icon_lbl.modulate = Color(1.0, 0.92, 0.28)
					btn.disabled      = false
				"cleared":
					icon_lbl.text     = "★"
					icon_lbl.modulate = Color(0.28, 0.96, 0.32)
					btn.disabled      = false
				"locked":
					icon_lbl.text     = "🔒"
					icon_lbl.modulate = Color(0.60, 0.58, 0.55)
					btn.disabled      = true

		if w == 1 and state != "locked":
			if GameData.all_time_highest_stage >= 10:
				prog_lbl.text    = "★ Complete!"
				prog_lbl.visible = true
			else:
				prog_lbl.text    = "%d / 10" % GameData.all_time_highest_stage
				prog_lbl.visible = true
		else:
			prog_lbl.visible = false


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
	var _sel_alloc : Dictionary = GameData.get_hero_talent_alloc(GameData.selected_hero_id)
	var _sel_dmg   : float = def.get("damage",    0.0) + float(_sel_alloc.get("dmg", 0))
	var _sel_rng   : float = def.get("range",     0.0) + float(_sel_alloc.get("rng", 0)) * 15.0
	var _sel_fr    : float = def.get("fire_rate", 0.0) * (1.0 + float(_sel_alloc.get("fr", 0)) * 0.05)
	_hero_sel_stats.text = "⚔ %.0f  ·  🎯 %.0f px  ·  🏹 %.1f/s  ·  %s" % [
		_sel_dmg, _sel_rng, _sel_fr,
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

	# Stat line — show talent-boosted totals
	var _alloc   : Dictionary = GameData.get_hero_talent_alloc(hero_id)
	var _t_dmg   : float = def.get("damage",    0.0) + float(_alloc.get("dmg", 0))
	var _t_rng   : float = def.get("range",     0.0) + float(_alloc.get("rng", 0)) * 15.0
	var _t_fr    : float = def.get("fire_rate", 0.0) * (1.0 + float(_alloc.get("fr", 0)) * 0.05)
	var stat_str := "⚔ %.0f  ·  🎯 %.0f  ·  🏹 %.1f/s" % [_t_dmg, _t_rng, _t_fr]
	var stat_lbl := _label(stat_str, _font_reg, 13, C_DIM)
	stat_lbl.position     = Vector2(66, 52)
	stat_lbl.size         = Vector2(cw - 84, 18)
	stat_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(stat_lbl)

	# Level badge (top-right)
	var lvl      : int = GameData.get_tower_level(hero_id)
	var lvl_lbl  := _label("Lv.%d" % lvl, _font_bold, 14, C_GOLD)
	lvl_lbl.position             = Vector2(cw - 54, 8)
	lvl_lbl.size                 = Vector2(48, 18)
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lvl_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	card.add_child(lvl_lbl)

	# Copies badge (below level badge)
	var copies_str : String
	if lvl >= GameData.TOWER_MAX_LEVEL:
		copies_str = "MAX"
	else:
		copies_str = "%d/%d" % [GameData.get_tower_xp(hero_id), GameData.copies_needed_for_level(lvl)]
	var copies_lbl := _label(copies_str, _font_reg, 12, C_DIM)
	copies_lbl.position             = Vector2(cw - 54, 28)
	copies_lbl.size                 = Vector2(48, 16)
	copies_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	copies_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	card.add_child(copies_lbl)

	# ✓ badge (always present, visibility toggled on select)
	var badge := _label("✓", _font_bold, 16, Color(0.30, 0.90, 0.45))
	badge.position             = Vector2(cw - 28, ch - 28)
	badge.size                 = Vector2(22, 22)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.mouse_filter         = MOUSE_FILTER_IGNORE
	badge.visible              = is_selected
	card.add_child(badge)

	# Store ref for live highlight updates
	_hero_card_refs.append({"id": hero_id, "style": cs, "badge": badge, "rcol": rcol,
							"lvl_lbl": lvl_lbl, "copies_lbl": copies_lbl, "stat_lbl": stat_lbl,
							"def": def})

	# Click → open detail
	var cap_def := def
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			_hero_show_detail(cap_def)
	)


func _hero_build_detail_panel(parent: Control) -> void:
	const PW : int = 680
	const PH : int = 520
	const LW : int = 296
	const RX : int = 308
	const RW : int = PW - RX - 12   # = 360

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
	_hero_det_panel = panel
	_hero_det_style = ps

	# Dim backdrop
	var dim := ColorRect.new()
	dim.color        = Color(0, 0, 0, 0.55)
	dim.position     = Vector2(-(1280 - PW) / 2, -(720 - PH) / 2)
	dim.size         = Vector2(1280, 720)
	dim.mouse_filter = MOUSE_FILTER_STOP
	dim.z_index      = -1
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed \
				and ev.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
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
	var vdiv := ColorRect.new()
	vdiv.color = Color(1,1,1,0.10); vdiv.position = Vector2(LW, 52); vdiv.size = Vector2(2, PH - 60)
	vdiv.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(vdiv)

	# ── LEFT COLUMN — preview + stats + special effect ──────────────────────────
	const PREV_SZ : int = 80
	var prev_bx : int = (LW - PREV_SZ) / 2
	var prev_bg := Panel.new()
	var pbs := StyleBoxFlat.new()
	pbs.bg_color = Color(0.04, 0.04, 0.10)
	pbs.corner_radius_top_left = 8; pbs.corner_radius_top_right = 8
	pbs.corner_radius_bottom_left = 8; pbs.corner_radius_bottom_right = 8
	prev_bg.add_theme_stylebox_override("panel", pbs)
	prev_bg.position     = Vector2(prev_bx, 62); prev_bg.size = Vector2(PREV_SZ, PREV_SZ)
	prev_bg.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(prev_bg)

	_hero_det_preview = _TurretPreview.new()
	_hero_det_preview.scale    = Vector2(1.3, 1.3)
	_hero_det_preview.position = Vector2(prev_bx + PREV_SZ / 2 - 36, 62 + PREV_SZ / 2 - 42)
	panel.add_child(_hero_det_preview)

	_hero_det_rarity = _label("", _font_bold, 14, C_DIM)
	_hero_det_rarity.position             = Vector2(0, 150)
	_hero_det_rarity.size                 = Vector2(LW, 20)
	_hero_det_rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_det_rarity.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(_hero_det_rarity)

	var div1 := ColorRect.new()
	div1.color = Color(1,1,1,0.08); div1.position = Vector2(12,174); div1.size = Vector2(LW-20,1)
	div1.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(div1)

	for sr in [["⚔ Damage", 182, "d"], ["🎯 Range", 206, "r"], ["🏹 Fire Rate", 230, "f"], ["Effect", 254, "e"]]:
		var kl := _label(sr[0], _font_reg, 14, C_DIM)
		kl.position = Vector2(12, sr[1]); kl.size = Vector2(112, 20)
		kl.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(kl)

	_hero_det_dmg = _label("", _font_bold, 14, C_WHITE)
	_hero_det_dmg.position = Vector2(128, 182); _hero_det_dmg.size = Vector2(LW - 136, 20)
	_hero_det_dmg.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(_hero_det_dmg)

	_hero_det_rng = _label("", _font_bold, 14, C_WHITE)
	_hero_det_rng.position = Vector2(128, 206); _hero_det_rng.size = Vector2(LW - 136, 20)
	_hero_det_rng.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(_hero_det_rng)

	_hero_det_rate = _label("", _font_bold, 14, C_WHITE)
	_hero_det_rate.position = Vector2(128, 230); _hero_det_rate.size = Vector2(LW - 136, 20)
	_hero_det_rate.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(_hero_det_rate)

	_hero_det_eff = _label("", _font_bold, 14, C_WHITE)
	_hero_det_eff.position = Vector2(128, 254); _hero_det_eff.size = Vector2(LW - 136, 20)
	_hero_det_eff.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(_hero_det_eff)

	_hero_det_desc = _label("", _font_reg, 14, C_DIM)  # kept for data flow

	var div2 := ColorRect.new()
	div2.color = Color(1,1,1,0.08); div2.position = Vector2(12,278); div2.size = Vector2(LW-20,1)
	div2.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(div2)

	var eff_hdr_l := _label("Special Effect", _font_bold, 14, C_GOLD)
	eff_hdr_l.position = Vector2(12, 286); eff_hdr_l.size = Vector2(LW - 20, 18)
	eff_hdr_l.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(eff_hdr_l)

	var abil_scroll := ScrollContainer.new()
	abil_scroll.position               = Vector2(12, 308)
	abil_scroll.size                   = Vector2(LW - 20, PH - 316)
	abil_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	abil_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(abil_scroll)
	_hero_det_ability = _label("", _font_reg, 14, Color(0.92, 0.88, 0.72))
	_hero_det_ability.custom_minimum_size   = Vector2(LW - 20, 0)
	_hero_det_ability.autowrap_mode         = TextServer.AUTOWRAP_WORD
	_hero_det_ability.mouse_filter          = MOUSE_FILTER_PASS
	_hero_det_ability.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_det_ability.size_flags_vertical   = Control.SIZE_SHRINK_BEGIN
	abil_scroll.add_child(_hero_det_ability)

	# ── RIGHT COLUMN — level + copies + talents + select ───────────────────────
	var lvl_hdr := _label("Hero Level", _font_reg, 14, C_DIM)
	lvl_hdr.position = Vector2(RX, 62); lvl_hdr.size = Vector2(RW, 20)
	lvl_hdr.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(lvl_hdr)

	_hero_det_level_lbl = _label("Lv. 1", _font_bold, 32, C_GOLD)
	_hero_det_level_lbl.position     = Vector2(RX, 82); _hero_det_level_lbl.size = Vector2(RW, 44)
	_hero_det_level_lbl.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(_hero_det_level_lbl)

	_hero_det_copies_lbl = _label("0 / 2 copies", _font_bold, 12, Color(0.70, 0.85, 1.00))
	_hero_det_copies_lbl.position             = Vector2(RX, 116)
	_hero_det_copies_lbl.size                 = Vector2(RW, 14)
	_hero_det_copies_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hero_det_copies_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(_hero_det_copies_lbl)

	var xp_bg := ColorRect.new()
	xp_bg.color    = Color(0.12, 0.12, 0.20)
	xp_bg.position = Vector2(RX, 134); xp_bg.size = Vector2(RW, 10)
	xp_bg.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(xp_bg)

	_hero_det_xp_fill = ColorRect.new()
	_hero_det_xp_fill.color    = Color(0.30, 0.70, 1.00)
	_hero_det_xp_fill.position = Vector2(RX, 134); _hero_det_xp_fill.size = Vector2(0, 10)
	_hero_det_xp_fill.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(_hero_det_xp_fill)

	var div3 := ColorRect.new()
	div3.color = Color(1,1,1,0.08); div3.position = Vector2(RX, 152); div3.size = Vector2(RW, 1)
	div3.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(div3)

	var tal_hdr := _label("Talents", _font_bold, 14, C_WHITE)
	tal_hdr.position = Vector2(RX, 160); tal_hdr.size = Vector2(RW, 22)
	tal_hdr.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(tal_hdr)

	_hero_det_talent_avail = _label("0 available", _font_reg, 13, Color(0.60, 1.00, 0.60))
	_hero_det_talent_avail.position     = Vector2(RX, 185)
	_hero_det_talent_avail.size         = Vector2(RW, 18)
	_hero_det_talent_avail.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(_hero_det_talent_avail)

	_hero_det_allocate_btn = Button.new()
	_hero_det_allocate_btn.text       = "⚡  Allocate Talents  ►"
	_hero_det_allocate_btn.position   = Vector2(RX, 208)
	_hero_det_allocate_btn.size       = Vector2(RW, 36)
	_hero_det_allocate_btn.focus_mode = FOCUS_NONE
	_hero_det_allocate_btn.add_theme_font_override("font",           _font_bold)
	_hero_det_allocate_btn.add_theme_font_size_override("font_size", 14)
	_hero_det_allocate_btn.add_theme_color_override("font_color",    C_WHITE)
	_hero_det_allocate_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.20, 0.34, 0.52)))
	_hero_det_allocate_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.28, 0.44, 0.66)))
	_hero_det_allocate_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.14, 0.24, 0.38)))
	_hero_det_allocate_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.20, 0.34, 0.52)))
	_hero_det_allocate_btn.pressed.connect(func():
		if is_instance_valid(_hero_talent_panel):
			_hero_talent_panel.visible = true
	)
	panel.add_child(_hero_det_allocate_btn)

	var div4 := ColorRect.new()
	div4.color = Color(1,1,1,0.08); div4.position = Vector2(RX, 252); div4.size = Vector2(RW, 1)
	div4.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(div4)

	var inv_hdr := _label("Invested Talents", _font_bold, 13, C_DIM)
	inv_hdr.position = Vector2(RX, 260); inv_hdr.size = Vector2(RW, 18)
	inv_hdr.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(inv_hdr)

	var icons_scroll := ScrollContainer.new()
	icons_scroll.position               = Vector2(RX, 282)
	icons_scroll.size                   = Vector2(RW, 136)
	icons_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	icons_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(icons_scroll)
	var icons_grid := GridContainer.new()
	icons_grid.columns = 10
	icons_grid.add_theme_constant_override("h_separation", 4)
	icons_grid.add_theme_constant_override("v_separation", 4)
	icons_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icons_scroll.add_child(icons_grid)
	_hero_det_talent_icons = icons_grid

	_hero_det_select = Button.new()
	_hero_det_select.position   = Vector2(RX, 434)
	_hero_det_select.size       = Vector2(RW, 50)
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
	note_lbl.position             = Vector2(RX, 492)
	note_lbl.size                 = Vector2(RW, 18)
	note_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(note_lbl)

	# Talent allocation sub-panel (sits on top of detail panel, hidden until opened)
	_hero_build_talent_panel(panel, PW, PH)


func _hero_show_detail(def: Dictionary) -> void:
	if not is_instance_valid(_hero_det_panel):
		return
	# Always close the talent panel when opening a new hero detail
	if is_instance_valid(_hero_talent_panel):
		_hero_talent_panel.visible = false
	var eff_map : Dictionary = {
		"none":               "Standard single-target shot. No bonus effect.",
		"knight_slam":        "Every 3rd hit throws up to 3 swords at different enemies and knocks them back. Fewer swords are thrown if fewer enemies are in range. Knockback has no effect on bosses.",
		"ranger_fire_aura":   "Every 5th hit: towers 1 tile away get +10% fire rate for 3s.",
		"rock_drop":          "Every 3rd hit drops a brittle zone (2s). Enemies entering take +20 bonus damage on their next hit from any source (once per enemy per zone).",
		"dual_debuff":        "Hits 2 enemies per attack. Every other attack inflicts a random debuff on each target for 1 second. (Bleed, 10% Slow, or +10% damage taken — 5s cooldown per debuff per target.)",
		"shadow_blade_combo": "Every 3rd hit strikes with both blades at 2× damage and applies a bleed stack dealing 2× damage/s for 3s. Max 1 bleed stack per target.",
		"frost_shatter":      "Fires 2 projectiles per attack. Every hit slows the target by 5% for 2s. Gains +3% attack speed for each slowed enemy currently on the map (max +30%). Resets after 3s without attacking.",
		"lightning":          "Each strike chains to the primary target, then arcs to 3 additional enemies at 80% damage.",
		"pierce":             "Each shot pierces through up to 3 enemies in a line at full damage.",
		"poison_debuff":      "Poisons targets on hit — each stack increases damage taken by 10% for 5s. Stacks up to 3 times per target.",
		"aoe_burst":          "An ancient dragon lord who unleashes explosive bursts that devastate up to 5 nearby enemies.",
		"arcane_charge":      "Accumulates arcane power and unleashes devastating lasers every 15th hit.",
		"execute_shot":       "Burning arrows scale with the target's current HP — 2× damage at full HP, down to 1× at 0 HP.",
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

	var eff_key : String = def.get("effect", "none")
	_hero_det_eff.text     = eff_key.replace("_", " ").capitalize()
	_hero_det_desc.text    = def.get("desc", "")
	_hero_det_ability.text = eff_map.get(eff_key, def.get("desc", "No special effect."))

	# Right column — level & copies
	const RW : int = 360
	var lvl    : int   = GameData.get_tower_level(hero_id)
	var copies : int   = GameData.get_tower_xp(hero_id)
	var needed : int   = GameData.copies_needed_for_level(lvl)
	var max_lv : int   = GameData.TOWER_MAX_LEVEL
	_hero_det_level_lbl.text = "Lv. %d" % lvl
	if lvl >= max_lv:
		_hero_det_xp_fill.size  = Vector2(RW, 10)
		_hero_det_xp_fill.color = C_GOLD
		_hero_det_copies_lbl.text = "MAX"
	else:
		var frac : float = clampf(float(copies) / needed, 0.0, 1.0)
		_hero_det_xp_fill.size  = Vector2(int(RW * frac), 10)
		_hero_det_xp_fill.color = Color(0.30, 0.70, 1.00)
		_hero_det_copies_lbl.text = "%d / %d copies" % [copies, needed]

	# Talent display
	_hero_talent_hero_id = hero_id
	_hero_refresh_talent_display(hero_id)

	# Select button
	var is_selected : bool = (hero_id == GameData.selected_hero_id)
	for conn in _hero_det_select.pressed.get_connections():
		_hero_det_select.pressed.disconnect(conn["callable"])
	if lvl == 0:
		_hero_det_select.text     = "🔒  Get 1 Copy to Unlock"
		_hero_det_select.disabled = true
		_hero_det_select.add_theme_stylebox_override("normal",   _btn_style(Color(0.16, 0.16, 0.20)))
		_hero_det_select.add_theme_stylebox_override("hover",    _btn_style(Color(0.16, 0.16, 0.20)))
		_hero_det_select.add_theme_stylebox_override("disabled", _btn_style(Color(0.16, 0.16, 0.20)))
	elif is_selected:
		_hero_det_select.text     = "✓  Already Selected"
		_hero_det_select.disabled = false
		_hero_det_select.add_theme_stylebox_override("normal",   _btn_style(Color(0.12, 0.26, 0.14)))
		_hero_det_select.add_theme_stylebox_override("hover",    _btn_style(Color(0.12, 0.26, 0.14)))
		_hero_det_select.add_theme_stylebox_override("disabled", _btn_style(Color(0.12, 0.26, 0.14)))
	else:
		_hero_det_select.text     = "⚔  Select Hero"
		_hero_det_select.disabled = false
		_hero_det_select.add_theme_stylebox_override("normal",   _btn_style(Color(0.12, 0.42, 0.18)))
		_hero_det_select.add_theme_stylebox_override("hover",    _btn_style(Color(0.18, 0.58, 0.25)))
		_hero_det_select.add_theme_stylebox_override("disabled", _btn_style(Color(0.12, 0.42, 0.18)))
		_hero_det_select.pressed.connect(_hero_on_select.bind(hero_id))

	_hero_det_panel.visible = true


func _hero_on_select(hero_id: String) -> void:
	GameData.set_selected_hero(hero_id)
	_hero_det_panel.visible = false
	_hero_refresh_selected()
	for ref in _hero_card_refs:
		var sel : bool = (ref["id"] == hero_id)
		var cs  : StyleBoxFlat = ref["style"]
		cs.bg_color    = Color(0.10, 0.18, 0.10) if sel else Color(0.10, 0.10, 0.18)
		cs.border_color = Color(0.30, 0.90, 0.45) if sel else ref["rcol"]
		(ref["badge"] as Label).visible = sel
	var def : Dictionary = GameData.HERO_DEFS.get(hero_id, {})
	if not def.is_empty():
		_hero_show_detail(def)


func _hero_build_talent_panel(parent: Control, parent_pw: int, parent_ph: int) -> void:
	const TPW : int = 460
	const TPH : int = 284

	var dim := ColorRect.new()
	dim.color        = Color(0, 0, 0, 0.72)
	dim.position     = Vector2.ZERO
	dim.size         = Vector2(parent_pw, parent_ph)
	dim.mouse_filter = MOUSE_FILTER_STOP
	dim.z_index      = 25
	dim.visible      = false
	parent.add_child(dim)
	_hero_talent_panel = dim

	var panel := Panel.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color                   = Color(0.08, 0.07, 0.16, 0.98)
	ps.corner_radius_top_left     = 12; ps.corner_radius_top_right    = 12
	ps.corner_radius_bottom_left  = 12; ps.corner_radius_bottom_right = 12
	ps.border_width_left = 2; ps.border_width_right  = 2
	ps.border_width_top  = 2; ps.border_width_bottom = 2
	ps.border_color = Color(0.40, 0.30, 0.80, 0.60)
	ps.shadow_color = Color(0, 0, 0, 0.70); ps.shadow_size = 12
	panel.add_theme_stylebox_override("panel", ps)
	panel.position     = Vector2((parent_pw - TPW) / 2, (parent_ph - TPH) / 2)
	panel.size         = Vector2(TPW, TPH)
	panel.mouse_filter = MOUSE_FILTER_STOP
	dim.add_child(panel)

	var title := _label("Allocate Talents", _font_bold, 18, C_WHITE)
	title.position             = Vector2(0, 12)
	title.size                 = Vector2(TPW, 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(title)

	_hero_talent_avail_count = _label("0 points remaining", _font_reg, 13, Color(0.60, 1.00, 0.60))
	_hero_talent_avail_count.position             = Vector2(0, 44)
	_hero_talent_avail_count.size                 = Vector2(TPW, 20)
	_hero_talent_avail_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_talent_avail_count.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(_hero_talent_avail_count)

	var note := _label("Each point:  ⚔ +1 damage  ·  🎯 +15 range  ·  🏹 +5% fire rate",
						_font_reg, 11, C_DIM)
	note.position             = Vector2(0, 66)
	note.size                 = Vector2(TPW, 18)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(note)

	const COL_W  : int = 126; const COL_H  : int = 118; const COL_GAP : int = 10
	var cols_x0  : int = (TPW - 3 * COL_W - 2 * COL_GAP) / 2

	var col_defs : Array = [
		{"stat": "dmg", "icon": "⚔",  "label": "Damage",    "color": Color(1.0, 0.50, 0.30)},
		{"stat": "rng", "icon": "🎯", "label": "Range",     "color": Color(0.30, 0.80, 1.00)},
		{"stat": "fr",  "icon": "🏹", "label": "Fire Rate", "color": Color(0.40, 1.00, 0.50)},
	]

	for ci in range(3):
		var cd  : Dictionary = col_defs[ci]
		var cx  : int = cols_x0 + ci * (COL_W + COL_GAP)
		var bcol : Color = cd["color"]

		var col_panel := Panel.new()
		var col_s := StyleBoxFlat.new()
		col_s.bg_color                   = Color(0.10, 0.10, 0.20)
		col_s.corner_radius_top_left     = 8; col_s.corner_radius_top_right    = 8
		col_s.corner_radius_bottom_left  = 8; col_s.corner_radius_bottom_right = 8
		col_s.border_width_left = 1; col_s.border_width_right  = 1
		col_s.border_width_top  = 1; col_s.border_width_bottom = 1
		col_s.border_color = Color(bcol.r, bcol.g, bcol.b, 0.40)
		col_panel.add_theme_stylebox_override("panel", col_s)
		col_panel.position     = Vector2(cx, 90)
		col_panel.size         = Vector2(COL_W, COL_H)
		col_panel.mouse_filter = MOUSE_FILTER_IGNORE
		panel.add_child(col_panel)

		var icon_lbl := _label(cd["icon"], _font_bold, 22, bcol)
		icon_lbl.position             = Vector2(0, 6)
		icon_lbl.size                 = Vector2(COL_W, 30)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
		col_panel.add_child(icon_lbl)

		var stat_name := _label(cd["label"], _font_bold, 12, C_WHITE)
		stat_name.position             = Vector2(0, 36)
		stat_name.size                 = Vector2(COL_W, 18)
		stat_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_name.mouse_filter         = MOUSE_FILTER_IGNORE
		col_panel.add_child(stat_name)

		var count_lbl := _label("+0", _font_bold, 15, bcol)
		count_lbl.position             = Vector2(0, 54)
		count_lbl.size                 = Vector2(COL_W, 22)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
		col_panel.add_child(count_lbl)
		match cd["stat"]:
			"dmg": _hero_talent_dmg_count = count_lbl
			"rng": _hero_talent_rng_count = count_lbl
			"fr":  _hero_talent_fr_count  = count_lbl

		var plus_btn := Button.new()
		plus_btn.text       = "+"
		plus_btn.position   = Vector2((COL_W - 58) / 2, 80)
		plus_btn.size       = Vector2(58, 32)
		plus_btn.focus_mode = FOCUS_NONE
		plus_btn.add_theme_font_override("font",           _font_bold)
		plus_btn.add_theme_font_size_override("font_size", 18)
		plus_btn.add_theme_color_override("font_color",    C_WHITE)
		plus_btn.add_theme_stylebox_override("normal",  _btn_style(Color(bcol.r*0.45, bcol.g*0.45, bcol.b*0.45)))
		plus_btn.add_theme_stylebox_override("hover",   _btn_style(Color(bcol.r*0.65, bcol.g*0.65, bcol.b*0.65)))
		plus_btn.add_theme_stylebox_override("pressed", _btn_style(Color(bcol.r*0.28, bcol.g*0.28, bcol.b*0.28)))
		plus_btn.add_theme_stylebox_override("focus",   _btn_style(Color(bcol.r*0.45, bcol.g*0.45, bcol.b*0.45)))
		var cap_stat : String = cd["stat"]
		plus_btn.pressed.connect(func():
			if GameData.spend_hero_talent(_hero_talent_hero_id, cap_stat):
				_hero_refresh_talent_display(_hero_talent_hero_id)
				_refresh_hero_cards()
		)
		col_panel.add_child(plus_btn)

	var done_btn := Button.new()
	done_btn.text       = "Done"
	done_btn.position   = Vector2((TPW - 150) / 2, TPH - 46)
	done_btn.size       = Vector2(150, 36)
	done_btn.focus_mode = FOCUS_NONE
	done_btn.add_theme_font_override("font",           _font_bold)
	done_btn.add_theme_font_size_override("font_size", 15)
	done_btn.add_theme_color_override("font_color",    C_WHITE)
	done_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.22, 0.22, 0.28)))
	done_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.30, 0.30, 0.38)))
	done_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.16, 0.16, 0.20)))
	done_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.22, 0.22, 0.28)))
	done_btn.pressed.connect(func(): dim.visible = false)
	panel.add_child(done_btn)


func _hero_refresh_talent_display(hero_id: String) -> void:
	var alloc : Dictionary = GameData.get_hero_talent_alloc(hero_id)
	var avail : int        = GameData.get_hero_talent_points(hero_id)
	var def   : Dictionary = GameData.HERO_DEFS.get(hero_id, {})

	# Available count labels
	if is_instance_valid(_hero_det_talent_avail):
		_hero_det_talent_avail.text = "%d available" % avail
	if is_instance_valid(_hero_talent_avail_count):
		_hero_talent_avail_count.text = "%d points remaining" % avail

	# Talent column counts
	var dmg_pts : int = alloc.get("dmg", 0)
	var rng_pts : int = alloc.get("rng", 0)
	var fr_pts  : int = alloc.get("fr",  0)
	if is_instance_valid(_hero_talent_dmg_count): _hero_talent_dmg_count.text = "+%d"  % dmg_pts
	if is_instance_valid(_hero_talent_rng_count): _hero_talent_rng_count.text = "+%d"  % rng_pts
	if is_instance_valid(_hero_talent_fr_count):  _hero_talent_fr_count.text  = "+%d%%" % (fr_pts * 5)

	# Stat labels with talent bonuses applied
	var base_dmg : float = def.get("damage",    0.0)
	var base_rng : float = def.get("range",     0.0)
	var base_fr  : float = def.get("fire_rate", 0.0)
	var b_dmg    : float = base_dmg + float(dmg_pts)
	var b_rng    : float = base_rng + float(rng_pts) * 15.0
	var b_fr     : float = base_fr  * (1.0 + float(fr_pts) * 0.05)
	if is_instance_valid(_hero_det_dmg):
		_hero_det_dmg.text  = "%.0f%s"     % [b_dmg,     " (+%d)"   % dmg_pts      if dmg_pts > 0 else ""]
	if is_instance_valid(_hero_det_rng):
		_hero_det_rng.text  = "%d px%s"    % [int(b_rng), " (+%d)"  % (rng_pts*15) if rng_pts > 0 else ""]
	if is_instance_valid(_hero_det_rate):
		_hero_det_rate.text = "%.1f / s%s" % [b_fr,       " (+%d%%)" % (fr_pts*5)  if fr_pts  > 0 else ""]

	# Rebuild talent icon chips
	if not is_instance_valid(_hero_det_talent_icons):
		return
	for child in _hero_det_talent_icons.get_children():
		child.queue_free()

	var icon_defs : Array = [
		["dmg", "⚔",  Color(1.0, 0.50, 0.30), "+1 damage per point"],
		["rng", "🎯", Color(0.30, 0.80, 1.00), "+15 range per point"],
		["fr",  "🏹", Color(0.40, 1.00, 0.50), "+5% fire rate per point"],
	]
	for idef in icon_defs:
		var count : int = alloc.get(idef[0], 0)
		var ccol  : Color = idef[2]
		for _i in range(count):
			var chip := Panel.new()
			var chip_s := StyleBoxFlat.new()
			chip_s.bg_color                   = Color(ccol.r*0.18, ccol.g*0.18, ccol.b*0.18)
			chip_s.corner_radius_top_left     = 5; chip_s.corner_radius_top_right    = 5
			chip_s.corner_radius_bottom_left  = 5; chip_s.corner_radius_bottom_right = 5
			chip_s.border_width_left = 1; chip_s.border_width_right  = 1
			chip_s.border_width_top  = 1; chip_s.border_width_bottom = 1
			chip_s.border_color = Color(ccol.r, ccol.g, ccol.b, 0.55)
			chip.add_theme_stylebox_override("panel", chip_s)
			chip.custom_minimum_size = Vector2(30, 30)
			chip.mouse_filter        = MOUSE_FILTER_PASS
			chip.tooltip_text        = idef[3]
			_hero_det_talent_icons.add_child(chip)
			var chip_lbl := _label(idef[1], _font_bold, 14, ccol)
			chip_lbl.position             = Vector2(0, 0)
			chip_lbl.size                 = Vector2(30, 30)
			chip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			chip_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			chip_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
			chip.add_child(chip_lbl)


func _refresh_hero_cards() -> void:
	for ref in _hero_card_refs:
		var hero_id : String = ref.get("id", "")
		if hero_id == "":
			continue
		var lvl    : int = GameData.get_tower_level(hero_id)
		var copies : int = GameData.get_tower_xp(hero_id)
		if is_instance_valid(ref.get("lvl_lbl")):
			ref["lvl_lbl"].text = "Lv.%d" % lvl
		if is_instance_valid(ref.get("copies_lbl")):
			if lvl >= GameData.TOWER_MAX_LEVEL:
				ref["copies_lbl"].text = "MAX"
			else:
				ref["copies_lbl"].text = "%d/%d" % [copies, GameData.copies_needed_for_level(lvl)]
		if is_instance_valid(ref.get("stat_lbl")):
			var d   : Dictionary = ref.get("def", {})
			var al  : Dictionary = GameData.get_hero_talent_alloc(hero_id)
			var td  : float = d.get("damage",    0.0) + float(al.get("dmg", 0))
			var tr  : float = d.get("range",     0.0) + float(al.get("rng", 0)) * 15.0
			var tf  : float = d.get("fire_rate", 0.0) * (1.0 + float(al.get("fr", 0)) * 0.05)
			ref["stat_lbl"].text = "⚔ %.0f  ·  🎯 %.0f  ·  🏹 %.1f/s" % [td, tr, tf]


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
		"focused_shot":  "Consecutive hits on the same target stacks +50% damage up to 2x. Resets when switching targets.",
		"dual_shot":     "Fires at 2 separate enemies simultaneously.",
		"chain":         "Hits primary at full damage, then chains to 2 nearby enemies at 50% damage.",
		"aoe":           "Hits all enemies currently in range.",
		"aoe_burst":     "Explosive shot hits up to 5 enemies in range.",
		"melee_cleave":  "Every 3rd hit strikes all enemies in range.",
		"bleed_aoe":     "Hits all in range; applies bleed (max 3 stacks, 1 dmg/s each).",
		"slow_zone":     "Every 4th shot drops an ice zone slowing enemies 55% for 3s.",
		"poison_debuff": "Poisons targets — +10% damage taken for 5s.",
		"execute_shot":  "Up to 2× damage based on enemy current HP%.",
		"knight_slam":   "Every 3rd hit throws 2 swords and knocks enemies back.",
		"ranger_fire_aura": "Every 5th hit: towers 1 tile away get +10% fire rate for 3s.",
		"rock_drop":           "Every 3rd hit drops a brittle zone (2s). Enemies entering take +20 bonus damage on their next hit from any source (once per enemy per zone).",
		"dual_debuff":         "Hits 2 enemies per attack. Every other attack inflicts a random debuff on each target for 1 second. (Bleed, 10% Slow, or +10% damage taken — 5s cooldown per debuff per target.)",
		"shadow_blade_combo":  "Every 3rd hit strikes with both blades at 2× damage + bleed (2× dmg/s, 3s, max 1 stack).",
		"frost_shatter":       "2 shots per attack. Every hit slows by 5% for 2s. Gains +3% attack speed per slowed enemy on map (max +30%). Resets after 3s without attacking.",
		"hp_strike":     "Deals base dmg + 1% of target's current HP.",
		"poison_cloud":     "Hits all enemies in range each shot. Spawns a persistent poison cloud that slowly expands along the path, dealing 2 damage/s to any enemy inside it.",
		"frost_cannon_tri": "Fires at up to 3 separate targets per shot. Boss targets take +50% damage and receive a 10% slow that refreshes on repeat hits.",
		"arcane_overload":  "Every 5th attack triggers Arcane Overload — instant lasers hit ALL enemies in range (minimum 5 lasers). Counter never resets.",
		"arcane_charge": "Every 15th hit fires a blue laser for 2× damage to all in range.",
		"lock_beam":     "Locks beam on one target; damage ramps 1× to 2× over 5s.",
		"tempest_strike":          "Every 10th hit launches a slash that deals base damage + 5% of the target's max HP on impact.",
		"infernal_serpent_summon": "Each hit has a 10% chance to summon a fire serpent (100 damage per bite) that laps the battlefield once.",
		"lightning":     "Chains to primary + 3 more at 80% damage.",
		"storm_chain":   "Strikes primary for full damage, then chains to 4 nearest enemies globally for 150% damage.",
		"chrono_aoe":    "Hits all enemies in range each shot. Applies a 15% slow for 2s that stacks with other slows (e.g. Frost Spire).",
		"world_tree_buff": "Passively buffs towers one tile away with +10 flat damage and +50% attack speed.",
		"natures_wrath_buff": "Buffs towers one tile away with +15 flat damage and +75% attack speed. 5% chance per hit to earn 2 gold.",
		"taunt_slam":     "Hits up to 5 enemies at once. Every 5th hit stuns all in range for 2s and causes them to take +20% damage from all sources.",
		"hercules_cleave": "Strikes 2 enemies at once. Gains +5 permanent damage per wave cleared. Boss waves excluded.",
		"pierce":        "Bolt pierces up to 3 enemies in a line.",
		"axe_warrior":   "Each swing hits up to 2 enemies in melee range, applying 1 Bleed stack and 1 Poison stack.",
		"blade_spin":    "Dual melee strike hits 2 targets. 10% chance to summon 2 razor blades orbiting for 3s.",
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

	# Short stat line — apply level + upgrade multipliers so cards match the detail panel
	var tower_id  : String = def.get("id", "")
	var stat_str := "⚔ %.0f  ·  🎯 %.0f  ·  🏹 %.1f/s" % [
		def.get("damage",    0.0) * GameData.tower_total_damage_mult(tower_id),
		def.get("range",     0.0) * GameData.tower_total_range_mult(tower_id),
		def.get("fire_rate", 0.0) * GameData.tower_total_fire_rate_mult(tower_id)]
	var stat_lbl := _label(stat_str, _font_reg, 13, C_DIM)
	stat_lbl.position     = Vector2(76, 48)
	stat_lbl.size         = Vector2(cw - 84, 18)
	stat_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(stat_lbl)

	# Level badge (top-right corner)
	var lvl       : int    = GameData.get_tower_level(tower_id)
	var lvl_lbl   := _label("Lv.%d" % lvl, _font_bold, 14, C_GOLD)
	lvl_lbl.position             = Vector2(cw - 52, 8)
	lvl_lbl.size                 = Vector2(46, 18)
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lvl_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	card.add_child(lvl_lbl)

	# Copies badge (below level badge, top-right)
	var copies_str : String
	if lvl >= GameData.TOWER_MAX_LEVEL:
		copies_str = "MAX"
	else:
		var needed_c : int = GameData.copies_needed_for_level(lvl)
		copies_str = "%d/%d" % [GameData.get_tower_xp(tower_id), needed_c]
	var copies_lbl := _label(copies_str, _font_reg, 12, C_DIM)
	copies_lbl.position             = Vector2(cw - 52, 28)
	copies_lbl.size                 = Vector2(46, 16)
	copies_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	copies_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	card.add_child(copies_lbl)

	# Store live-refresh refs
	if tower_id != "":
		_tower_card_refs[tower_id] = {"lvl_lbl": lvl_lbl, "copies_lbl": copies_lbl}

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
		if ev is InputEventMouseButton and ev.pressed \
				and ev.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
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

	_tw_desc_lbl = _label("", _font_reg, 14, C_DIM)  # kept for data flow, not displayed

	# Special effect description
	var eff_hdr := _label("Special Effect", _font_bold, 14, C_GOLD)
	eff_hdr.position = Vector2(16, 306); eff_hdr.size = Vector2(LW - 24, 18)
	eff_hdr.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(eff_hdr)

	# reuse _tw_xp_bar_lbl as the special-effect detail text (inside a scroll container)
	var eff_scroll := ScrollContainer.new()
	eff_scroll.position                                    = Vector2(16, 326)
	eff_scroll.size                                        = Vector2(LW - 24, 176)
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

	# Copies counter label above the bar (right-aligned)
	_tw_copies_lbl = _label("0 / 2", _font_bold, 12, Color(0.70, 0.85, 1.00))
	_tw_copies_lbl.position             = Vector2(RX, 116)
	_tw_copies_lbl.size                 = Vector2(RW, 14)
	_tw_copies_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tw_copies_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	panel.add_child(_tw_copies_lbl)

	# (buy button removed — copies earned through gameplay only)
	_tw_buy_btn      = Button.new()   # kept as variable to avoid null refs
	_tw_buy_cost_lbl = _label("", _font_reg, 12, C_DIM)

	var div3 := ColorRect.new()
	div3.color = Color(1,1,1,0.08); div3.position = Vector2(RX,148); div3.size = Vector2(RW,1)
	div3.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(div3)

	# "Level Buffs" header
	var buff_hdr := _label("Level Buffs", _font_bold, 14, C_WHITE)
	buff_hdr.position = Vector2(RX, 156); buff_hdr.size = Vector2(RW, 22)
	buff_hdr.mouse_filter = MOUSE_FILTER_IGNORE; panel.add_child(buff_hdr)

	# Scrollable level buff list
	var scroll := ScrollContainer.new()
	scroll.position               = Vector2(RX, 182)
	scroll.size                   = Vector2(RW, PH - 192)
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

	# Left column stats — boosted value + total bonus %
	var _det_tid   : String = def.get("id", "")
	var _det_dmgm  : float  = GameData.tower_total_damage_mult(_det_tid)
	var _det_rngm  : float  = GameData.tower_total_range_mult(_det_tid)
	var _det_ratem : float  = GameData.tower_total_fire_rate_mult(_det_tid)
	var _det_dmg_pct  : int = roundi((_det_dmgm  - 1.0) * 100.0)
	var _det_rng_pct  : int = roundi((_det_rngm  - 1.0) * 100.0)
	var _det_rate_pct : int = roundi((_det_ratem - 1.0) * 100.0)
	_tw_dmg_lbl.text  = "%.0f%s" % [(def.get("damage",    0.0) * _det_dmgm)  + GameData.buff_damage_flat,
									 ("  +%d%%" % _det_dmg_pct)  if _det_dmg_pct  > 0 else ""]
	_tw_rng_lbl.text  = "%.0f px%s" % [def.get("range",   0.0) * _det_rngm,
									 ("  +%d%%" % _det_rng_pct)  if _det_rng_pct  > 0 else ""]
	_tw_rate_lbl.text = "%.1f / s%s" % [def.get("fire_rate", 0.0) * _det_ratem,
									 ("  +%d%%" % _det_rate_pct) if _det_rate_pct > 0 else ""]
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

	# Right column — level & copies bar
	_tw_current_def = def
	var lvl     : int   = GameData.get_tower_level(tower_id)
	var copies  : int   = GameData.get_tower_xp(tower_id)
	var needed  : int   = GameData.copies_needed_for_level(lvl)
	var max_lvl : int   = GameData.TOWER_MAX_LEVEL
	const RW    : int   = 320   # must match RW in build function

	_tw_level_lbl.text = "Lv. %d" % lvl
	if lvl >= max_lvl:
		_tw_xp_bar_fill.size  = Vector2(RW, 10)
		_tw_xp_bar_fill.color = C_GOLD
		_tw_copies_lbl.text   = "MAX"
	else:
		var frac : float      = clampf(float(copies) / needed, 0.0, 1.0)
		_tw_xp_bar_fill.size  = Vector2(int(RW * frac), 10)
		_tw_xp_bar_fill.color = Color(0.30, 0.70, 1.00)
		_tw_copies_lbl.text   = "%d / %d copies" % [copies, needed]

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


func _refresh_tower_cards() -> void:
	for tower_id in _tower_card_refs:
		var refs  : Dictionary = _tower_card_refs[tower_id]
		var lvl   : int        = GameData.get_tower_level(tower_id)
		var copies: int        = GameData.get_tower_xp(tower_id)
		if is_instance_valid(refs.get("lvl_lbl")):
			refs["lvl_lbl"].text = "Lv.%d" % lvl
		if is_instance_valid(refs.get("copies_lbl")):
			if lvl >= GameData.TOWER_MAX_LEVEL:
				refs["copies_lbl"].text = "MAX"
			else:
				var needed : int = GameData.copies_needed_for_level(lvl)
				refs["copies_lbl"].text = "%d/%d" % [copies, needed]


# ══════════════════════════════════════════════════════════════════════════════
# DAILY QUESTS SCREEN
# ══════════════════════════════════════════════════════════════════════════════

func _build_daily_quests_screen() -> void:
	var overlay := Panel.new()
	var bg_s := StyleBoxFlat.new()
	bg_s.bg_color = Color(0.04, 0.04, 0.10)
	overlay.add_theme_stylebox_override("panel", bg_s)
	overlay.position     = Vector2.ZERO
	overlay.size         = Vector2(1280, 720)
	overlay.mouse_filter = MOUSE_FILTER_STOP
	overlay.visible      = false
	add_child(overlay)
	_daily_quests_screen = overlay

	# Top red band
	var top_band := ColorRect.new()
	top_band.color        = Color(0.18, 0.10, 0.06, 0.90)
	top_band.position     = Vector2.ZERO
	top_band.size         = Vector2(1280, 138)
	top_band.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(top_band)

	var title := _label("📅  Daily Quests", _font_bold, 36, C_WHITE)
	title.position             = Vector2(0, 20)
	title.size                 = Vector2(1280, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter         = MOUSE_FILTER_IGNORE
	overlay.add_child(title)

	var sub := _label("Complete quests to earn Quest Tokens. Resets daily.", _font_reg, 15, Color(0.70, 0.65, 0.60))
	sub.position             = Vector2(0, 70)
	sub.size                 = Vector2(1280, 28)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.mouse_filter         = MOUSE_FILTER_IGNORE
	overlay.add_child(sub)

	# Token balance display (coin icon + count, centered pair)
	const DQ_D : int = 22; const DQ_GAP : int = 6
	var _dq := _tok_center("00000 ★", 18, DQ_D, DQ_GAP, 1280)
	var dq_coin := _make_token_coin(DQ_D)
	dq_coin.position     = Vector2(_dq[0], 108)
	dq_coin.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(dq_coin)
	_dq_token_lbl = _label("%d ★" % GameData.quest_tokens, _font_bold, 18, Color(0.88, 0.72, 1.00))
	_dq_token_lbl.position             = Vector2(_dq[1], 106)
	_dq_token_lbl.size                 = Vector2(_dq[2], 24)
	_dq_token_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_dq_token_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
	overlay.add_child(_dq_token_lbl)

	# Divider
	var hdiv := ColorRect.new()
	hdiv.color = Color(1, 1, 1, 0.08); hdiv.position = Vector2(60, 136); hdiv.size = Vector2(1160, 2)
	hdiv.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(hdiv)

	# ── Quest card builder helper ──────────────────────────────────────────────
	const CW : float = 1100.0
	const CH : float = 140.0
	const CX : float = 90.0
	var card_style := func(complete: bool) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.12, 0.14, 0.22, 0.95) if not complete else Color(0.08, 0.22, 0.10, 0.95)
		s.corner_radius_top_left = 8; s.corner_radius_top_right = 8
		s.corner_radius_bottom_left = 8; s.corner_radius_bottom_right = 8
		s.border_width_left = 2; s.border_width_right  = 2
		s.border_width_top  = 2; s.border_width_bottom = 2
		s.border_color = Color(0.18, 0.68, 0.32) if complete else Color(0.30, 0.38, 0.55)
		return s

	# ── Quest 1: Kill 200 enemies ──────────────────────────────────────────────
	var q1_y : float = 158.0
	var q1_card := Panel.new()
	q1_card.position = Vector2(CX, q1_y)
	q1_card.size     = Vector2(CW, CH)
	q1_card.add_theme_stylebox_override("panel", card_style.call(GameData.dq_kills_complete))
	q1_card.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(q1_card)

	_dq_check1 = _label("✔" if GameData.dq_kills_claimed else "", _font_bold, 32, Color(0.20, 0.90, 0.40))
	_dq_check1.position = Vector2(CW - 140, 40); _dq_check1.size = Vector2(120, 46)
	_dq_check1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dq_check1.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_dq_check1.visible      = GameData.dq_kills_claimed
	_dq_check1.mouse_filter = MOUSE_FILTER_IGNORE
	q1_card.add_child(_dq_check1)

	var q1_badge := _label("EASY", _font_bold, 12, Color(0.15, 0.90, 0.42))
	q1_badge.position = Vector2(20, 14); q1_badge.size = Vector2(50, 18)
	q1_badge.mouse_filter = MOUSE_FILTER_IGNORE
	q1_card.add_child(q1_badge)

	var q1_title := _label("⚔  Kill 200 Enemies", _font_bold, 20, Color(1.0, 0.88, 0.50))
	q1_title.position = Vector2(74, 10); q1_title.size = Vector2(650, 30)
	q1_title.mouse_filter = MOUSE_FILTER_IGNORE
	q1_card.add_child(q1_title)

	var q1_desc := _label("Defeat 200 enemies across any run today.", _font_reg, 15, Color(0.72, 0.72, 0.72))
	q1_desc.position = Vector2(20, 46); q1_desc.size = Vector2(700, 24)
	q1_desc.mouse_filter = MOUSE_FILTER_IGNORE
	q1_card.add_child(q1_desc)

	# Progress bar background
	var q1_bar_bg := ColorRect.new()
	q1_bar_bg.color    = Color(0.10, 0.10, 0.18)
	q1_bar_bg.position = Vector2(20, 82); q1_bar_bg.size = Vector2(CW - 300, 22)
	q1_bar_bg.mouse_filter = MOUSE_FILTER_IGNORE
	q1_card.add_child(q1_bar_bg)
	var q1_bar_fill := ColorRect.new()
	q1_bar_fill.color    = Color(0.22, 0.72, 0.38)
	q1_bar_fill.position = Vector2(0, 0)
	var q1_pct := clampf(float(GameData.dq_kills_progress) / float(GameData.DQ_KILL_TARGET), 0.0, 1.0)
	q1_bar_fill.size     = Vector2((CW - 300) * q1_pct, 22)
	q1_bar_fill.mouse_filter = MOUSE_FILTER_IGNORE
	q1_bar_bg.add_child(q1_bar_fill)
	_dq_bar1 = q1_bar_fill
	_dq_lbl1 = _label("%d / %d" % [GameData.dq_kills_progress, GameData.DQ_KILL_TARGET],
		_font_bold, 14, C_WHITE)
	_dq_lbl1.position = Vector2(20, 82 + 3); _dq_lbl1.size = Vector2(CW - 300, 18)
	_dq_lbl1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dq_lbl1.mouse_filter = MOUSE_FILTER_IGNORE
	q1_card.add_child(_dq_lbl1)

	var q1_reward := _label("Reward: ★ +100 Quest Tokens", _font_bold, 14, Color(0.82, 0.65, 1.00))
	q1_reward.position = Vector2(20, 110); q1_reward.size = Vector2(400, 22)
	q1_reward.mouse_filter = MOUSE_FILTER_IGNORE
	q1_card.add_child(q1_reward)

	_dq_btn1 = Button.new()
	_dq_btn1.text       = "✦  Claim"
	_dq_btn1.position   = Vector2(CW - 140, 40)
	_dq_btn1.size       = Vector2(120, 46)
	_dq_btn1.focus_mode = FOCUS_NONE
	_dq_btn1.visible    = GameData.dq_kills_complete and not GameData.dq_kills_claimed
	_dq_btn1.add_theme_font_override("font",           _font_bold)
	_dq_btn1.add_theme_font_size_override("font_size", 18)
	_dq_btn1.add_theme_color_override("font_color",    C_WHITE)
	_dq_btn1.add_theme_stylebox_override("normal",  _btn_style(Color(0.08, 0.38, 0.14)))
	_dq_btn1.add_theme_stylebox_override("hover",   _btn_style(Color(0.12, 0.52, 0.20)))
	_dq_btn1.add_theme_stylebox_override("pressed", _btn_style(Color(0.05, 0.26, 0.09)))
	_dq_btn1.add_theme_stylebox_override("focus",   _btn_style(Color(0.08, 0.38, 0.14)))
	_dq_btn1.pressed.connect(func():
		GameData.dq_kills_claimed = true
		GameData.quest_tokens    += 100
		GameData.save_game()
		_refresh_daily_quests_screen()
	)
	q1_card.add_child(_dq_btn1)

	# ── Quest 2: Clear Mutated World 1 ────────────────────────────────────────
	var q2_y : float = 318.0
	var q2_card := Panel.new()
	q2_card.position = Vector2(CX, q2_y)
	q2_card.size     = Vector2(CW, CH)
	q2_card.add_theme_stylebox_override("panel", card_style.call(GameData.dq_mutated_complete))
	q2_card.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(q2_card)

	_dq_check2 = _label("✔" if GameData.dq_mutated_claimed else "", _font_bold, 32, Color(0.20, 0.90, 0.40))
	_dq_check2.position = Vector2(CW - 140, 40); _dq_check2.size = Vector2(120, 46)
	_dq_check2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dq_check2.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_dq_check2.visible      = GameData.dq_mutated_claimed
	_dq_check2.mouse_filter = MOUSE_FILTER_IGNORE
	q2_card.add_child(_dq_check2)

	var q2_badge := _label("MEDIUM", _font_bold, 12, Color(0.30, 0.72, 1.00))
	q2_badge.position = Vector2(20, 14); q2_badge.size = Vector2(65, 18)
	q2_badge.mouse_filter = MOUSE_FILTER_IGNORE
	q2_card.add_child(q2_badge)

	var q2_title := _label("☠  Clear Mutated World 1", _font_bold, 20, Color(1.0, 0.55, 0.35))
	q2_title.position = Vector2(88, 10); q2_title.size = Vector2(640, 30)
	q2_title.mouse_filter = MOUSE_FILTER_IGNORE
	q2_card.add_child(q2_title)

	var q2_desc := _label("Clear all 10 stages of World 1 in Mutated mode (20% skeleton respawn).", _font_reg, 15, Color(0.72, 0.72, 0.72))
	q2_desc.position = Vector2(20, 46); q2_desc.size = Vector2(700, 24)
	q2_desc.mouse_filter = MOUSE_FILTER_IGNORE
	q2_card.add_child(q2_desc)

	_dq_status2 = _label(
		"✔ Completed!" if GameData.dq_mutated_complete else "Not started",
		_font_bold, 15,
		Color(0.20, 0.90, 0.40) if GameData.dq_mutated_complete else Color(0.55, 0.55, 0.55))
	_dq_status2.position = Vector2(20, 82); _dq_status2.size = Vector2(500, 24)
	_dq_status2.mouse_filter = MOUSE_FILTER_IGNORE
	q2_card.add_child(_dq_status2)

	var q2_reward := _label("Reward: ★ +300 Quest Tokens", _font_bold, 14, Color(0.82, 0.65, 1.00))
	q2_reward.position = Vector2(20, 110); q2_reward.size = Vector2(400, 22)
	q2_reward.mouse_filter = MOUSE_FILTER_IGNORE
	q2_card.add_child(q2_reward)

	var _q2_complete := GameData.dq_mutated_complete
	var _q2_claimed  := GameData.dq_mutated_claimed
	var _q2_col := Color(0.08, 0.38, 0.14) if _q2_complete else Color(0.48, 0.20, 0.06)
	_dq_btn2 = Button.new()
	_dq_btn2.text       = "✦  Claim" if _q2_complete else "▶  Start"
	_dq_btn2.position   = Vector2(CW - 140, 40)
	_dq_btn2.size       = Vector2(120, 46)
	_dq_btn2.focus_mode = FOCUS_NONE
	_dq_btn2.visible    = not _q2_claimed
	_dq_btn2.add_theme_font_override("font",           _font_bold)
	_dq_btn2.add_theme_font_size_override("font_size", 18)
	_dq_btn2.add_theme_color_override("font_color",    C_WHITE)
	_dq_btn2.add_theme_stylebox_override("normal",  _btn_style(_q2_col))
	_dq_btn2.add_theme_stylebox_override("hover",   _btn_style(_q2_col.lightened(0.15)))
	_dq_btn2.add_theme_stylebox_override("pressed", _btn_style(_q2_col.darkened(0.25)))
	_dq_btn2.add_theme_stylebox_override("focus",   _btn_style(_q2_col))
	_dq_btn2.pressed.connect(func():
		if GameData.dq_mutated_complete:
			GameData.dq_mutated_claimed = true
			GameData.quest_tokens      += 300
			GameData.save_game()
			_refresh_daily_quests_screen()
		else:
			_show_loading_screen(func():
				GameData.dq_mode             = "mutated_w1"
				GameData.selected_world      = 1
				GameData.launching_into_game = true
				get_tree().reload_current_scene()
			)
	)
	q2_card.add_child(_dq_btn2)

	# ── Quest 3: Sell 10 towers and clear World 1 ─────────────────────────────
	var q3_y : float = 478.0
	var q3_card := Panel.new()
	q3_card.position = Vector2(CX, q3_y)
	q3_card.size     = Vector2(CW, CH)
	q3_card.add_theme_stylebox_override("panel", card_style.call(GameData.dq_sell_complete))
	q3_card.mouse_filter = MOUSE_FILTER_IGNORE
	overlay.add_child(q3_card)

	_dq_check3 = _label("✔" if GameData.dq_sell_claimed else "", _font_bold, 32, Color(0.20, 0.90, 0.40))
	_dq_check3.position = Vector2(CW - 140, 40); _dq_check3.size = Vector2(120, 46)
	_dq_check3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dq_check3.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_dq_check3.visible      = GameData.dq_sell_claimed
	_dq_check3.mouse_filter = MOUSE_FILTER_IGNORE
	q3_card.add_child(_dq_check3)

	var q3_badge := _label("HARD", _font_bold, 12, Color(1.00, 0.35, 0.35))
	q3_badge.position = Vector2(20, 14); q3_badge.size = Vector2(50, 18)
	q3_badge.mouse_filter = MOUSE_FILTER_IGNORE
	q3_card.add_child(q3_badge)

	var q3_title := _label("💰  Sell 10 Towers & Clear World 1", _font_bold, 20, Color(0.90, 0.80, 0.30))
	q3_title.position = Vector2(74, 10); q3_title.size = Vector2(650, 30)
	q3_title.mouse_filter = MOUSE_FILTER_IGNORE
	q3_card.add_child(q3_title)

	var q3_desc := _label("Sell at least 10 towers during a World 1 normal run and clear all 10 stages.", _font_reg, 15, Color(0.72, 0.72, 0.72))
	q3_desc.position = Vector2(20, 46); q3_desc.size = Vector2(700, 24)
	q3_desc.mouse_filter = MOUSE_FILTER_IGNORE
	q3_card.add_child(q3_desc)

	_dq_status3 = _label(
		"✔ Completed!" if GameData.dq_sell_complete else "Not started",
		_font_bold, 15,
		Color(0.20, 0.90, 0.40) if GameData.dq_sell_complete else Color(0.55, 0.55, 0.55))
	_dq_status3.position = Vector2(20, 82); _dq_status3.size = Vector2(500, 24)
	_dq_status3.mouse_filter = MOUSE_FILTER_IGNORE
	q3_card.add_child(_dq_status3)

	var q3_reward := _label("Reward: ★ +500 Quest Tokens", _font_bold, 14, Color(0.82, 0.65, 1.00))
	q3_reward.position = Vector2(20, 110); q3_reward.size = Vector2(400, 22)
	q3_reward.mouse_filter = MOUSE_FILTER_IGNORE
	q3_card.add_child(q3_reward)

	var _q3_complete := GameData.dq_sell_complete
	var _q3_claimed  := GameData.dq_sell_claimed
	var _q3_col := Color(0.08, 0.38, 0.14) if _q3_complete else Color(0.48, 0.20, 0.06)
	_dq_btn3 = Button.new()
	_dq_btn3.text       = "✦  Claim" if _q3_complete else "▶  Start"
	_dq_btn3.position   = Vector2(CW - 140, 40)
	_dq_btn3.size       = Vector2(120, 46)
	_dq_btn3.focus_mode = FOCUS_NONE
	_dq_btn3.visible    = not _q3_claimed
	_dq_btn3.add_theme_font_override("font",           _font_bold)
	_dq_btn3.add_theme_font_size_override("font_size", 18)
	_dq_btn3.add_theme_color_override("font_color",    C_WHITE)
	_dq_btn3.add_theme_stylebox_override("normal",  _btn_style(_q3_col))
	_dq_btn3.add_theme_stylebox_override("hover",   _btn_style(_q3_col.lightened(0.15)))
	_dq_btn3.add_theme_stylebox_override("pressed", _btn_style(_q3_col.darkened(0.25)))
	_dq_btn3.add_theme_stylebox_override("focus",   _btn_style(_q3_col))
	_dq_btn3.pressed.connect(func():
		if GameData.dq_sell_complete:
			GameData.dq_sell_claimed = true
			GameData.quest_tokens   += 500
			GameData.save_game()
			_refresh_daily_quests_screen()
		else:
			_show_loading_screen(func():
				GameData.dq_mode             = "sell_w1"
				GameData.selected_world      = 1
				GameData.launching_into_game = true
				get_tree().reload_current_scene()
			)
	)
	q3_card.add_child(_dq_btn3)

	# ── Back button ───────────────────────────────────────────────────────────
	var back_btn := Button.new()
	back_btn.text         = "← Back"
	back_btn.position     = Vector2(20, 660)
	back_btn.size         = Vector2(160, 46)
	back_btn.focus_mode   = FOCUS_NONE
	back_btn.add_theme_font_override("font",           _font_bold)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.add_theme_color_override("font_color",    C_WHITE)
	back_btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.22, 0.22, 0.28)))
	back_btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.32, 0.32, 0.40)))
	back_btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.14, 0.14, 0.18)))
	back_btn.add_theme_stylebox_override("focus",   _btn_style(Color(0.22, 0.22, 0.28)))
	back_btn.pressed.connect(func():
		overlay.visible           = false
		_game_over_screen.visible = true
	)
	overlay.add_child(back_btn)

	call_deferred("_wire_hover_recursive", overlay)


func _refresh_daily_quests_screen() -> void:
	GameData.check_daily_reset()
	# Quest 1 — progress bar
	if is_instance_valid(_dq_bar1):
		var pct : float  = clampf(float(GameData.dq_kills_progress) / float(GameData.DQ_KILL_TARGET), 0.0, 1.0)
		var bg_w : float = (_dq_bar1.get_parent() as ColorRect).size.x
		_dq_bar1.size = Vector2(bg_w * pct, _dq_bar1.size.y)
	if is_instance_valid(_dq_lbl1):
		_dq_lbl1.text = "%d / %d" % [GameData.dq_kills_progress, GameData.DQ_KILL_TARGET]
	if is_instance_valid(_dq_btn1):
		_dq_btn1.visible = GameData.dq_kills_complete and not GameData.dq_kills_claimed
	if is_instance_valid(_dq_check1):
		_dq_check1.visible = GameData.dq_kills_claimed
		_dq_check1.text    = "✔" if GameData.dq_kills_claimed else ""
	# Quest 2 — status + button
	if is_instance_valid(_dq_status2):
		_dq_status2.text = "✔ Completed!" if GameData.dq_mutated_complete else "Not started"
		_dq_status2.add_theme_color_override("font_color",
			Color(0.20, 0.90, 0.40) if GameData.dq_mutated_complete else Color(0.55, 0.55, 0.55))
	if is_instance_valid(_dq_btn2):
		_dq_btn2.visible = not GameData.dq_mutated_claimed
		if not GameData.dq_mutated_claimed:
			var col2 := Color(0.08, 0.38, 0.14) if GameData.dq_mutated_complete else Color(0.48, 0.20, 0.06)
			_dq_btn2.text = "✦  Claim" if GameData.dq_mutated_complete else "▶  Start"
			_dq_btn2.add_theme_stylebox_override("normal",  _btn_style(col2))
			_dq_btn2.add_theme_stylebox_override("hover",   _btn_style(col2.lightened(0.15)))
			_dq_btn2.add_theme_stylebox_override("pressed", _btn_style(col2.darkened(0.25)))
			_dq_btn2.add_theme_stylebox_override("focus",   _btn_style(col2))
	if is_instance_valid(_dq_check2):
		_dq_check2.visible = GameData.dq_mutated_claimed
		_dq_check2.text    = "✔" if GameData.dq_mutated_claimed else ""
	# Quest 3 — status + button
	if is_instance_valid(_dq_status3):
		_dq_status3.text = "✔ Completed!" if GameData.dq_sell_complete else "Not started"
		_dq_status3.add_theme_color_override("font_color",
			Color(0.20, 0.90, 0.40) if GameData.dq_sell_complete else Color(0.55, 0.55, 0.55))
	if is_instance_valid(_dq_btn3):
		_dq_btn3.visible = not GameData.dq_sell_claimed
		if not GameData.dq_sell_claimed:
			var col3 := Color(0.08, 0.38, 0.14) if GameData.dq_sell_complete else Color(0.18, 0.38, 0.18)
			_dq_btn3.text = "✦  Claim" if GameData.dq_sell_complete else "▶  Start"
			_dq_btn3.add_theme_stylebox_override("normal",  _btn_style(col3))
			_dq_btn3.add_theme_stylebox_override("hover",   _btn_style(col3.lightened(0.15)))
			_dq_btn3.add_theme_stylebox_override("pressed", _btn_style(col3.darkened(0.25)))
			_dq_btn3.add_theme_stylebox_override("focus",   _btn_style(col3))
	if is_instance_valid(_dq_check3):
		_dq_check3.visible = GameData.dq_sell_claimed
		_dq_check3.text    = "✔" if GameData.dq_sell_claimed else ""
	_refresh_quest_token_labels()


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
	# First time a fusion becomes available → show recipe tutorial
	if not GameData.recipe_tutorial_seen and available_fusions.size() > 0:
		show_recipe_tutorial()


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
		const SPH : int = 580
		# Click-outside catcher — added FIRST so stat_panel (added after) gets input priority
		var sp_catcher := ColorRect.new()
		sp_catcher.color        = Color(0, 0, 0, 0.0)
		sp_catcher.position     = Vector2.ZERO
		sp_catcher.size         = Vector2(1280, 720)
		sp_catcher.z_index      = 119
		sp_catcher.visible      = false
		sp_catcher.mouse_filter = MOUSE_FILTER_STOP
		overlay.add_child(sp_catcher)

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
		sp_catcher.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed \
					and ev.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
				var click_pos : Vector2 = (ev as InputEventMouseButton).position
				if not Rect2(stat_panel.position, stat_panel.size).has_point(click_pos):
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

		var sp_effect_map : Dictionary = {
			"poison_cloud":      "Hits all enemies in range each shot. Spawns a persistent poison cloud that slowly expands along the path, dealing 2 damage/s to any enemy inside it.",
			"frost_cannon_tri":  "Fires at up to 3 separate targets per shot. Boss targets take +50% damage and receive a 10% slow that refreshes on repeat hits.",
			"arcane_overload":   "Every 5th attack triggers Arcane Overload — instant lasers hit ALL enemies in range (minimum 5 lasers). Counter never resets.",
			"tempest_strike":          "Every 10th hit launches a slash that deals base damage + 5% of the target's max HP on impact.",
			"infernal_serpent_summon": "Each hit has a 10% chance to summon a living fire serpent (100 damage per bite) that races around the battlefield once.",
			"storm_chain":       "Strikes the primary target for full damage, then chains to the 4 nearest enemies globally for 150% damage. Chain targets can be outside the tower's range.",
			"lightning":         "Chains to the primary target and up to 3 additional enemies at 80% damage.",
			"aoe":               "Hits all enemies currently in range.",
			"pierce":            "Bolt pierces through up to 3 enemies in a line, hitting each for full damage.",
			"shadow_weaver_phase": "Shadow phase: single-target attack. After 10 hits transforms for 5s — white laser fires every 0.5s hitting 5 enemies for 50% tower damage + 1% max HP (0.5% on bosses).",
			"natures_wrath_buff":"Passively buffs all towers one tile away with +15 flat damage and +75% attack speed. Each hit has a 5% chance to generate 2 gold.",
		}
		var sp_eff_div := ColorRect.new()
		sp_eff_div.color        = Color(1,1,1,0.08)
		sp_eff_div.position     = Vector2(14, 388)
		sp_eff_div.size         = Vector2(left_w - 18, 2)
		sp_eff_div.mouse_filter = MOUSE_FILTER_IGNORE
		stat_panel.add_child(sp_eff_div)
		var sp_eff_hdr := _label("Special Effect", _font_bold, 14, C_GOLD)
		sp_eff_hdr.position     = Vector2(14, 394)
		sp_eff_hdr.size         = Vector2(left_w - 18, 18)
		sp_eff_hdr.mouse_filter = MOUSE_FILTER_IGNORE
		stat_panel.add_child(sp_eff_hdr)
		var sp_desc := _label(sp_effect_map.get(sp_reff, result_def.get("desc", "")), _font_reg, 14, Color(0.92, 0.88, 0.72))
		sp_desc.custom_minimum_size   = Vector2(left_w - 18, 0)
		sp_desc.autowrap_mode         = TextServer.AUTOWRAP_WORD
		sp_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp_desc.size_flags_vertical   = Control.SIZE_SHRINK_BEGIN
		sp_desc.mouse_filter          = MOUSE_FILTER_PASS
		var sp_eff_scroll := ScrollContainer.new()
		sp_eff_scroll.position               = Vector2(14, 416)
		sp_eff_scroll.size                   = Vector2(left_w - 18, SPH - 430)
		sp_eff_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sp_eff_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
		stat_panel.add_child(sp_eff_scroll)
		sp_eff_scroll.add_child(sp_desc)

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
			["Lv. 2", "+15%% DMG  (%.1f → %.1f)" % [rdmg, rdmg*1.15],         false],
			["Lv. 3", "Special: " + eff_map3.get(sp_reff, sp_reff.capitalize()) + " +50% radius", false],
			["Lv. 4", "+20%% Range  (%d → %d)" % [int(rrng), int(rrng*1.2)],  false],
			["Lv. 5", "+25%% Fire Rate  (%.1f → %.1f/s)" % [rrate2, rrate2*1.25], false],
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

func _wire_all_button_hovers() -> void:
	_wire_hover_recursive(self)

func _wire_hover_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Button:
			_add_btn_hover(child)
		_wire_hover_recursive(child)

func _add_btn_hover(btn: Button) -> void:
	# Set pivot to center so scale animates from the middle
	btn.pivot_offset = btn.size / 2.0
	btn.mouse_entered.connect(func():
		if _btn_tweens.has(btn) and is_instance_valid(_btn_tweens[btn]):
			_btn_tweens[btn].kill()
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.12)
		_btn_tweens[btn] = tw
	)
	btn.mouse_exited.connect(func():
		if _btn_tweens.has(btn) and is_instance_valid(_btn_tweens[btn]):
			_btn_tweens[btn].kill()
		var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.10)
		_btn_tweens[btn] = tw
	)


func _tween_scale(node: Control, target: Vector2, dur: float) -> void:
	if _btn_tweens.has(node) and is_instance_valid(_btn_tweens[node]):
		_btn_tweens[node].kill()
	var tw := create_tween()
	tw.tween_property(node, "scale", target, dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(node, "scale", Vector2(1.0, 1.0), dur * 1.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
	menu.position = Vector2(1280 - 200, 720 - 210)
	menu.size     = Vector2(188, 196)
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

	# ── Toggle: Damage Numbers ────────────────────────────────────────────────
	var dmg_row := _make_settings_toggle(
		menu, "Damage Numbers", 36, GameData.show_damage_numbers,
		func(on: bool): GameData.show_damage_numbers = on
	)
	menu.add_child(dmg_row)

	# ── Toggle: Projectiles ───────────────────────────────────────────────────
	var proj_row := _make_settings_toggle(
		menu, "Projectiles", 76, GameData.show_projectiles,
		func(on: bool): GameData.show_projectiles = on
	)
	menu.add_child(proj_row)

	var hdiv3 := ColorRect.new()
	hdiv3.color        = Color(1, 1, 1, 0.07)
	hdiv3.position     = Vector2(8, 120); hdiv3.size = Vector2(172, 1)
	hdiv3.mouse_filter = MOUSE_FILTER_IGNORE
	menu.add_child(hdiv3)

	var leave_btn := Button.new()
	leave_btn.text         = "🚪  Leave Game"
	leave_btn.position     = Vector2(8, 128)
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
		if is_instance_valid(_loot_panel) and _loot_panel.visible:
			_loot_panel.visible = false
		if is_instance_valid(_loot_catcher) and _loot_catcher.visible:
			_loot_catcher.visible = false
		game_left.emit()
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
			_victory_screen.visible   or
			(is_instance_valid(_daily_quests_screen) and _daily_quests_screen.visible) or
			(is_instance_valid(_relic_screen) and _relic_screen.visible)
		)
		gear_btn.visible = not any_overlay
		if any_overlay: menu.visible = false

	_game_over_screen.visibility_changed.connect(_update_gear_vis)
	_upgrades_screen.visibility_changed.connect(_update_gear_vis)
	_victory_screen.visibility_changed.connect(_update_gear_vis)


# ══════════════════════════════════════════════════════════════════════════════
# SETTINGS HELPERS
# ══════════════════════════════════════════════════════════════════════════════

# Builds a labeled toggle row for the settings menu.
# Returns the container node (already populated, caller must add_child to menu).
func _make_settings_toggle(menu: Panel, label_text: String, y: float,
		initial: bool, on_toggle: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.position      = Vector2(8, y)
	row.size          = Vector2(172, 36)
	row.mouse_filter  = MOUSE_FILTER_PASS

	var lbl := Label.new()
	lbl.text          = label_text
	lbl.add_theme_font_override("font",           _font_bold)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color",    C_WHITE)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter          = MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	# Styled toggle button showing ON (green) / OFF (dark red)
	var chk := Button.new()
	chk.toggle_mode    = true
	chk.button_pressed = initial
	chk.focus_mode     = FOCUS_NONE
	chk.text           = "ON" if initial else "OFF"
	chk.size           = Vector2(52, 28)
	chk.custom_minimum_size = Vector2(52, 28)
	chk.add_theme_font_override("font",           _font_bold)
	chk.add_theme_font_size_override("font_size", 12)

	var _make_tog_style := func(bg: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = bg
		s.corner_radius_top_left     = 6
		s.corner_radius_top_right    = 6
		s.corner_radius_bottom_left  = 6
		s.corner_radius_bottom_right = 6
		s.border_width_left   = 1; s.border_width_right  = 1
		s.border_width_top    = 1; s.border_width_bottom = 1
		s.border_color = bg.lightened(0.25)
		return s

	var _refresh_chk := func(pressed: bool) -> void:
		chk.text = "ON" if pressed else "OFF"
		var col : Color = Color(0.15, 0.55, 0.20) if pressed else Color(0.40, 0.10, 0.10)
		chk.add_theme_stylebox_override("normal",   _make_tog_style.call(col))
		chk.add_theme_stylebox_override("hover",    _make_tog_style.call(col.lightened(0.15)))
		chk.add_theme_stylebox_override("pressed",  _make_tog_style.call(col.darkened(0.10)))
		chk.add_theme_stylebox_override("focus",    _make_tog_style.call(col))
		chk.add_theme_color_override("font_color",  C_WHITE)

	_refresh_chk.call(initial)
	chk.toggled.connect(func(pressed: bool) -> void:
		_refresh_chk.call(pressed)
		on_toggle.call(pressed)
	)
	row.add_child(chk)

	return row


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


func show_relic_gold_popup(amount: int) -> void:
	var lbl := Label.new()
	lbl.text                      = "★ +%d" % amount
	lbl.add_theme_font_override("font", _font_bold)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1.00, 0.88, 0.25))
	lbl.position              = Vector2(13, 618)   # centered over gold display (center x=93)
	lbl.size                  = Vector2(160, 28)
	lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter          = MOUSE_FILTER_IGNORE
	lbl.z_index               = 30
	add_child(lbl)
	var dur : float = 1.0 / maxf(1.0, Engine.time_scale)   # always 1 real-world second
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", 578.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0,   dur).set_trans(Tween.TRANS_LINEAR)
	tw.chain().tween_callback(lbl.queue_free)


func _refresh_quest_token_labels() -> void:
	var txt : String = "%d ★" % GameData.quest_tokens
	if is_instance_valid(_relic_token_lbl):       _relic_token_lbl.text       = txt
	if is_instance_valid(_gacha_relic_tok_lbl):   _gacha_relic_tok_lbl.text   = txt
	if is_instance_valid(_dq_token_lbl):          _dq_token_lbl.text          = txt
	if is_instance_valid(_relics_screen_tok_lbl): _relics_screen_tok_lbl.text = txt


func _make_token_coin(diameter: int) -> Control:
	var icon : Control = TOKEN_ICON_SCR.new()
	icon.size         = Vector2(diameter, diameter)
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	return icon


# Returns (coin_x, label_x, label_w) that perfectly centers [coin][gap][text] in parent_w.
# Uses the font's actual string metrics so centering is pixel-accurate regardless of digit count.
func _tok_center(ref_text: String, font_size: int, coin_d: int, gap: int, parent_w: int) -> Array:
	var tw : float = _font_bold.get_string_size(ref_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var cx : int   = int((parent_w - coin_d - gap - tw) / 2.0)
	return [cx, cx + coin_d + gap, int(tw) + 4]   # +4px slack for sub-pixel rounding


func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font",           font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color",    color)
	return l


func show_boss_buff_cards(buffs: Array, stage: int) -> void:
	if is_instance_valid(_boss_buff_overlay):
		_boss_buff_overlay.queue_free()

	var rarity_colors := {
		"common": Color(0.80, 0.80, 0.80),
		"rare":   Color(0.25, 0.55, 1.00),
		"epic":   Color(0.72, 0.25, 0.90),
	}
	var rarity_labels := {
		"common": "COMMON",
		"rare":   "RARE",
		"epic":   "EPIC",
	}
	# Emoji icons per buff id
	var buff_icons := {
		"dmg_2":           "⚔",  "dmg_5":       "⚔",  "dmg_8":       "⚔",
		"fire_rate_5":     "⚡",  "fire_rate_15": "⚡",  "fire_rate_30": "⚡",
		"gold_10":         "🪙",
		"summon_cost_10g": "💰",
		"lives_5":         "❤️",
		"boss_dmg_25":     "💀",  "boss_dmg_50":  "💀",
		"enemy_slow_10":   "❄️",  "enemy_slow_25": "❄️",
		"dot_1":           "🧪",  "dot_3":         "🧪",
	}

	# Overlay fades in
	var overlay := ColorRect.new()
	overlay.color        = Color(0, 0, 0, 0.0)
	overlay.position     = Vector2.ZERO
	overlay.size         = Vector2(1280, 720)
	overlay.mouse_filter = MOUSE_FILTER_STOP
	add_child(overlay)
	_boss_buff_overlay = overlay

	var fade_tw := create_tween()
	fade_tw.tween_property(overlay, "color", Color(0, 0, 0, 0.82), 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Title
	var title := _label("⚔  Boss Defeated! Choose a Reward  ⚔", _font_bold, 26, C_GOLD)
	title.position             = Vector2(0, 48)
	title.size                 = Vector2(1280, 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title.modulate             = Color(1, 1, 1, 0)
	overlay.add_child(title)
	fade_tw.parallel().tween_property(title, "modulate:a", 1.0, 0.35) \
		.set_delay(0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var rarity_str : String = buffs[0].get("rarity", "common") if buffs.size() > 0 else "common"
	var rc         : Color  = rarity_colors.get(rarity_str, C_WHITE)
	var rl         : String = rarity_labels.get(rarity_str, "COMMON")
	var sub := _label("Stage %d  —  %s Rewards" % [stage, rl], _font_bold, 18, rc)
	sub.position             = Vector2(0, 96)
	sub.size                 = Vector2(1280, 26)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate             = Color(1, 1, 1, 0)
	overlay.add_child(sub)
	fade_tw.parallel().tween_property(sub, "modulate:a", 1.0, 0.35) \
		.set_delay(0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Layout constants
	const CARD_W  : int = 260
	const CARD_H  : int = 380
	const CARD_Y  : int = 135
	const SPACING : int = 50
	var total_w   : int = buffs.size() * CARD_W + (buffs.size() - 1) * SPACING
	var start_x   : int = (1280 - total_w) / 2

	# Track all card refs so hover/click can lock all of them
	var all_cards : Array = []

	for i in buffs.size():
		var buff       : Dictionary = buffs[i]
		var bx         : int        = start_x + i * (CARD_W + SPACING)
		var flip_delay : float      = 0.28 + i * 0.18
		var icon_str   : String     = buff_icons.get(buff.get("id", ""), "✨")

		# Card container — starts invisible, input disabled until flip done
		var card := Panel.new()
		card.position     = Vector2(bx, CARD_Y)
		card.size         = Vector2(CARD_W, CARD_H)
		card.pivot_offset = Vector2(CARD_W / 2.0, CARD_H / 2.0)
		card.modulate     = Color(1, 1, 1, 0)
		card.mouse_filter = MOUSE_FILTER_IGNORE
		card.add_theme_stylebox_override("panel", _rounded(Color(0, 0, 0, 0)))
		overlay.add_child(card)
		all_cards.append(card)

		# ── Back face ────────────────────────────────────────────────────────────
		var back_style := _rounded(Color(0.10, 0.08, 0.14, 1.0))
		back_style.border_width_left   = 3; back_style.border_width_right  = 3
		back_style.border_width_top    = 3; back_style.border_width_bottom = 3
		back_style.border_color        = rc.darkened(0.4)
		var back := Panel.new()
		back.size         = Vector2(CARD_W, CARD_H)
		back.mouse_filter = MOUSE_FILTER_IGNORE
		back.add_theme_stylebox_override("panel", back_style)
		card.add_child(back)

		var q_lbl := _label("?", _font_bold, 80, rc.darkened(0.25))
		q_lbl.position             = Vector2(0, CARD_H / 2 - 56)
		q_lbl.size                 = Vector2(CARD_W, 88)
		q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
		back.add_child(q_lbl)

		var back_rl := _label(rl, _font_bold, 13, rc.darkened(0.3))
		back_rl.position             = Vector2(0, CARD_H - 52)
		back_rl.size                 = Vector2(CARD_W, 22)
		back_rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		back_rl.mouse_filter         = MOUSE_FILTER_IGNORE
		back.add_child(back_rl)

		# ── Front face (hidden until flip) ───────────────────────────────────────
		var front_style := _rounded(Color(0.14, 0.12, 0.10, 1.0))
		front_style.border_width_left   = 3; front_style.border_width_right  = 3
		front_style.border_width_top    = 3; front_style.border_width_bottom = 3
		front_style.border_color        = rc
		var front := Panel.new()
		front.size          = Vector2(CARD_W, CARD_H)
		front.visible       = false
		front.clip_contents = true
		front.mouse_filter  = MOUSE_FILTER_IGNORE
		front.add_theme_stylebox_override("panel", front_style)
		card.add_child(front)

		# Colored top bar
		var top_bar := ColorRect.new()
		top_bar.color = rc.darkened(0.3); top_bar.position = Vector2(0, 0)
		top_bar.size  = Vector2(CARD_W, 8); top_bar.mouse_filter = MOUSE_FILTER_IGNORE
		front.add_child(top_bar)

		# Rarity label
		var rar_lbl := _label(rl, _font_bold, 12, rc)
		rar_lbl.position             = Vector2(0, 12)
		rar_lbl.size                 = Vector2(CARD_W, 20)
		rar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rar_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
		front.add_child(rar_lbl)

		# Divider under rarity
		var div1 := ColorRect.new()
		div1.color = rc.darkened(0.5); div1.position = Vector2(16, 35)
		div1.size  = Vector2(CARD_W - 32, 2); div1.mouse_filter = MOUSE_FILTER_IGNORE
		front.add_child(div1)

		# Icon (emoji, large)
		var icon_lbl := _label(icon_str, _font_bold, 52, C_WHITE)
		icon_lbl.position             = Vector2(0, 44)
		icon_lbl.size                 = Vector2(CARD_W, 68)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		icon_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
		front.add_child(icon_lbl)

		# Divider under icon
		var div2 := ColorRect.new()
		div2.color = rc.darkened(0.5); div2.position = Vector2(16, 118)
		div2.size  = Vector2(CARD_W - 32, 2); div2.mouse_filter = MOUSE_FILTER_IGNORE
		front.add_child(div2)

		# Buff name
		var name_lbl := _label(buff.get("name", ""), _font_bold, 19, C_WHITE)
		name_lbl.position             = Vector2(10, 126)
		name_lbl.size                 = Vector2(CARD_W - 20, 54)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		name_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.mouse_filter         = MOUSE_FILTER_IGNORE
		front.add_child(name_lbl)

		# Description — wrapped in a ScrollContainer so autowrap is constrained correctly
		var desc_lbl := _label(buff.get("desc", ""), _font_bold, 16, C_DIM)
		desc_lbl.custom_minimum_size       = Vector2(CARD_W - 32, 0)
		desc_lbl.autowrap_mode             = TextServer.AUTOWRAP_WORD
		desc_lbl.horizontal_alignment      = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.size_flags_horizontal     = Control.SIZE_EXPAND_FILL
		desc_lbl.size_flags_vertical       = Control.SIZE_SHRINK_BEGIN
		desc_lbl.mouse_filter              = MOUSE_FILTER_IGNORE
		var desc_scroll := ScrollContainer.new()
		desc_scroll.position               = Vector2(16, 186)
		desc_scroll.size                   = Vector2(CARD_W - 32, 148)
		desc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		desc_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_DISABLED
		desc_scroll.mouse_filter           = MOUSE_FILTER_IGNORE
		desc_scroll.add_child(desc_lbl)
		front.add_child(desc_scroll)


		# Golden selection glow — invisible until card is clicked
		var glow_style := _rounded(Color(0, 0, 0, 0))
		glow_style.border_width_left   = 4; glow_style.border_width_right  = 4
		glow_style.border_width_top    = 4; glow_style.border_width_bottom = 4
		glow_style.border_color        = C_GOLD
		glow_style.shadow_color        = Color(1.0, 0.82, 0.22, 0.6)
		glow_style.shadow_size         = 8
		var glow_panel := Panel.new()
		glow_panel.size         = Vector2(CARD_W, CARD_H)
		glow_panel.modulate     = Color(1, 1, 1, 0)
		glow_panel.mouse_filter = MOUSE_FILTER_IGNORE
		glow_panel.add_theme_stylebox_override("panel", glow_style)
		front.add_child(glow_panel)

		# ── Flip animation ───────────────────────────────────────────────────────
		var back_ref  : Panel   = back
		var front_ref : Panel   = front
		var card_ref  : Panel   = card
		var glow_ref  : Panel   = glow_panel
		var flip_tw := create_tween()
		flip_tw.tween_property(card, "modulate:a", 1.0, 0.20) \
			.set_delay(flip_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		flip_tw.tween_property(card, "scale:x", 0.0, 0.18) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		flip_tw.tween_callback(func():
			back_ref.visible  = false
			front_ref.visible = true
		)
		flip_tw.tween_property(card, "scale:x", 1.0, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		# ── Enable hover + click after flip completes ────────────────────────────
		var bid         : String  = buff.get("id", "")
		var overlay_ref : Control = overlay
		var all_ref     : Array   = all_cards
		flip_tw.tween_callback(func():
			card_ref.mouse_filter = MOUSE_FILTER_STOP

			card_ref.mouse_entered.connect(func():
				if card_ref.mouse_filter == MOUSE_FILTER_IGNORE:
					return
				if _btn_tweens.has(card_ref) and is_instance_valid(_btn_tweens[card_ref]):
					_btn_tweens[card_ref].kill()
				var hw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				hw.tween_property(card_ref, "scale", Vector2(1.07, 1.07), 0.14)
				_btn_tweens[card_ref] = hw
			)
			card_ref.mouse_exited.connect(func():
				if _btn_tweens.has(card_ref) and is_instance_valid(_btn_tweens[card_ref]):
					_btn_tweens[card_ref].kill()
				var hw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				hw.tween_property(card_ref, "scale", Vector2(1.0, 1.0), 0.12)
				_btn_tweens[card_ref] = hw
			)
			card_ref.gui_input.connect(func(event: InputEvent):
				if not (event is InputEventMouseButton and \
						event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
					return
				# Lock all cards immediately
				for c in all_ref:
					if is_instance_valid(c):
						c.mouse_filter = MOUSE_FILTER_IGNORE
				# Golden border flash
				var glow_tw := create_tween().set_parallel(true)
				glow_tw.tween_property(glow_ref, "modulate:a", 1.0, 0.12) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				glow_tw.chain().tween_property(glow_ref, "modulate:a", 0.0, 0.22) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				# Punch-in on selected card
				var pick_tw := create_tween()
				pick_tw.tween_property(card_ref, "scale", Vector2(0.88, 0.88), 0.08) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				pick_tw.tween_property(card_ref, "scale", Vector2(1.15, 1.15), 0.16) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				pick_tw.tween_property(card_ref, "scale", Vector2(1.0, 1.0), 0.10)
				# Fade overlay out then fire signal
				var out_tw := create_tween()
				out_tw.tween_interval(0.36)
				out_tw.tween_property(overlay_ref, "modulate:a", 0.0, 0.20) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				out_tw.tween_callback(func():
					overlay_ref.queue_free()
					_boss_buff_overlay = null
					buff_chosen.emit(bid)
				)
			)
		)


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
			30, 31, 32, 33:                       sc = 0.56   # melee epics/legendaries
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
			30: _pv_blade_assassin()
			31: _pv_axe_warrior()
			32: _pv_hercules()
			33: _pv_taunt_tank()
			26: _pv_spearman()
			27: _pv_rogue()
			28: _pv_elite_knight()
			29: _pv_iron_guard()
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

	func _pv_blade_assassin() -> void:
		var dark  := Color(0.07, 0.05, 0.12); var cloak := Color(0.16, 0.10, 0.26)
		var steel := Color(0.75, 0.80, 0.95); var edge  := Color(0.95, 0.97, 1.00)
		var eye_c := Color(0.85, 0.15, 0.90)
		draw_rect(Rect2(-12,14,24,10),dark); draw_rect(Rect2(-10,12,20,4),cloak.lightened(0.06))
		draw_colored_polygon(PackedVector2Array([Vector2(0,-18),Vector2(-12,14),Vector2(12,14)]),cloak)
		draw_colored_polygon(PackedVector2Array([Vector2(0,-12),Vector2(-4,10),Vector2(4,10)]),dark)
		draw_circle(Vector2(0,-15),9,dark); draw_circle(Vector2(0,-16),8,cloak)
		draw_circle(Vector2(-3,-16),2,eye_c); draw_circle(Vector2(3,-16),2,eye_c)
		draw_circle(Vector2(-3,-16),0.9,Color(1,0.85,1,0.9)); draw_circle(Vector2(3,-16),0.9,Color(1,0.85,1,0.9))
		# Left blade at rest
		draw_colored_polygon(PackedVector2Array([Vector2(-7,4)+Vector2(2.5,0),Vector2(-7,4)+Vector2(-1,0),Vector2(-16,-26)+Vector2(-0.3,0),Vector2(-16,-26)+Vector2(0.3,0)]),steel)
		draw_line(Vector2(-7,4)+Vector2(5.5,0),Vector2(-7,4)+Vector2(-4,0),steel,3.0)
		# Right blade at rest
		draw_colored_polygon(PackedVector2Array([Vector2(7,4)+Vector2(-2.5,0),Vector2(7,4)+Vector2(1,0),Vector2(16,-26)+Vector2(0.3,0),Vector2(16,-26)+Vector2(-0.3,0)]),steel)
		draw_line(Vector2(7,4)+Vector2(-5.5,0),Vector2(7,4)+Vector2(4,0),steel,3.0)
		draw_arc(Vector2(0,-16),10,0,TAU,20,Color(eye_c.r,eye_c.g,eye_c.b,0.20),2.0)

	func _pv_axe_warrior() -> void:
		var iron   := Color(0.42, 0.40, 0.45); var steel  := Color(0.70, 0.72, 0.80)
		var wood   := Color(0.48, 0.28, 0.10); var skin   := Color(0.78, 0.55, 0.35)
		var fur    := Color(0.55, 0.42, 0.28); var fur_d  := Color(0.38, 0.28, 0.16)
		draw_rect(Rect2(-10,14,8,10),fur_d); draw_rect(Rect2(2,14,8,10),fur_d)
		draw_rect(Rect2(-9,5,7,11),fur); draw_rect(Rect2(2,5,7,11),fur)
		draw_rect(Rect2(-11,-8,22,14),skin)
		draw_colored_polygon(PackedVector2Array([Vector2(-13,-8),Vector2(13,-8),Vector2(10,-14),Vector2(-10,-14)]),fur)
		draw_colored_polygon(PackedVector2Array([Vector2(-11,-8),Vector2(11,-8),Vector2(8,-13),Vector2(-8,-13)]),fur_d)
		draw_circle(Vector2(0,-18),9,iron); draw_circle(Vector2(0,-19),8,steel)
		draw_line(Vector2(-9,-14),Vector2(9,-14),iron,3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-9,-18),Vector2(-8,-25),Vector2(-14,-20)]),steel)
		draw_colored_polygon(PackedVector2Array([Vector2(9,-18),Vector2(8,-25),Vector2(14,-20)]),steel)
		# Axe at rest — held right side
		draw_line(Vector2(14,10),Vector2(14,-24),wood,4.0)
		draw_colored_polygon(PackedVector2Array([Vector2(10,-24),Vector2(22,-24),Vector2(24,-16),Vector2(10,-14)]),iron)
		draw_colored_polygon(PackedVector2Array([Vector2(10,-24),Vector2(22,-24),Vector2(22,-20),Vector2(10,-18)]),steel)

	func _pv_hercules() -> void:
		var gold   := Color(0.85, 0.65, 0.10); var gold_d := Color(0.60, 0.44, 0.05)
		var steel  := Color(0.70, 0.72, 0.80); var steel_d:= Color(0.42, 0.40, 0.45)
		var skin   := Color(0.80, 0.58, 0.36); var tiger  := Color(0.85, 0.50, 0.10)
		var tiger_s:= Color(0.15, 0.10, 0.05); var leather:= Color(0.38, 0.22, 0.08)
		draw_rect(Rect2(-10,14,8,10),leather); draw_rect(Rect2(2,14,8,10),leather)
		draw_rect(Rect2(-10,5,20,10),gold_d); draw_line(Vector2(-10,9),Vector2(10,9),gold,1.5)
		draw_rect(Rect2(-12,-8,24,14),steel); draw_rect(Rect2(-10,-6,20,10),steel_d)
		draw_line(Vector2(-12,-8),Vector2(12,-8),gold,2.5)
		draw_circle(Vector2(0,-19),10,tiger); draw_circle(Vector2(0,-20),9,Color(tiger.r+0.05,tiger.g+0.03,tiger.b))
		draw_line(Vector2(-10,-14),Vector2(10,-14),gold,3.0)
		draw_line(Vector2(-6,-22),Vector2(-4,-16),tiger_s,1.5); draw_line(Vector2(6,-22),Vector2(4,-16),tiger_s,1.5)
		draw_colored_polygon(PackedVector2Array([Vector2(-10,-23),Vector2(-6,-29),Vector2(-3,-22)]),tiger)
		draw_colored_polygon(PackedVector2Array([Vector2(10,-23),Vector2(6,-29),Vector2(3,-22)]),tiger)
		draw_circle(Vector2(-3.5,-17),2.5,skin); draw_circle(Vector2(3.5,-17),2.5,skin)
		# Longsword at rest
		draw_line(Vector2(6,-30),Vector2(2,10),steel_d,18.0)
		draw_line(Vector2(6,-30),Vector2(2,10),steel,14.0)
		draw_line(Vector2(6,-30),Vector2(2,10),Color(0.88,0.92,1.0,0.55),4.0)
		draw_rect(Rect2(-4,-2,16,5),gold)

	func _pv_taunt_tank() -> void:
		var crimson  := Color(0.72, 0.10, 0.18); var crimson_d := Color(0.45, 0.05, 0.10)
		var purple   := Color(0.55, 0.10, 0.72); var steel     := Color(0.65, 0.65, 0.75)
		var gold     := Color(0.85, 0.65, 0.10)
		draw_arc(Vector2(0,0),28,0,TAU,32,Color(0.55,0.05,0.40,0.20),2.5)
		draw_rect(Rect2(-10,14,8,10),crimson_d); draw_rect(Rect2(2,14,8,10),crimson_d)
		draw_rect(Rect2(-10,5,20,10),crimson); draw_line(Vector2(-10,9),Vector2(10,9),crimson_d,1.5)
		draw_rect(Rect2(-13,-9,26,15),crimson); draw_rect(Rect2(-11,-7,22,11),crimson_d)
		draw_line(Vector2(-13,-9),Vector2(13,-9),purple,3.0)
		draw_line(Vector2(-13,-9),Vector2(-13,5),purple,2.0); draw_line(Vector2(13,-9),Vector2(13,5),purple,2.0)
		draw_circle(Vector2(-14,-7),7,crimson); draw_circle(Vector2(14,-7),7,crimson)
		draw_arc(Vector2(-14,-7),7,PI*0.5,PI*1.5,16,purple,2.0)
		draw_arc(Vector2(14,-7),7,-PI*0.5,PI*0.5,16,purple,2.0)
		draw_circle(Vector2(0,-19),11,crimson); draw_circle(Vector2(0,-20),10,crimson_d)
		draw_rect(Rect2(-8,-22,16,4),purple); draw_rect(Rect2(-2,-22,4,8),purple)
		draw_line(Vector2(-9,-26),Vector2(9,-26),gold,3.0)
		draw_line(Vector2(-6,-29),Vector2(-6,-26),gold,2.5)
		draw_line(Vector2(0,-31),Vector2(0,-26),gold,2.5)
		draw_line(Vector2(6,-29),Vector2(6,-26),gold,2.5)
		draw_circle(Vector2(-20,-4),5.5,crimson_d); draw_arc(Vector2(-20,-4),5.5,0,TAU,16,purple,1.5)
		draw_circle(Vector2(20,-4),5.5,crimson_d);  draw_arc(Vector2(20,-4),5.5,0,TAU,16,purple,1.5)

	func _pv_spearman() -> void:
		var skin   := Color(0.94, 0.78, 0.60); var iron   := Color(0.55, 0.58, 0.65)
		var iron_d := Color(0.32, 0.34, 0.40); var tunic  := Color(0.72, 0.18, 0.18)
		var pants  := Color(0.28, 0.20, 0.10); var shaft  := Color(0.52, 0.33, 0.12)
		draw_rect(Rect2(-9,4,8,14),pants); draw_rect(Rect2(1,4,8,14),pants)
		draw_colored_polygon(PackedVector2Array([Vector2(-11,-8),Vector2(11,-8),Vector2(13,6),Vector2(-13,6)]),iron.darkened(0.1))
		draw_colored_polygon(PackedVector2Array([Vector2(-8,-7),Vector2(8,-7),Vector2(9,5),Vector2(-9,5)]),tunic)
		draw_circle(Vector2(-14,-5),6,iron); draw_circle(Vector2(-14,-5),6,iron_d,false,1.5)
		draw_circle(Vector2(14,-5),6,iron);  draw_circle(Vector2(14,-5),6,iron_d,false,1.5)
		draw_circle(Vector2(0,-17),8,skin)
		draw_rect(Rect2(-9,-22,18,7),iron); draw_rect(Rect2(-2,-22,4,10),iron_d)
		# Spear shaft + head
		draw_line(Vector2(-6,22),Vector2(20,-28),shaft,3.5)
		draw_line(Vector2(-6,22),Vector2(20,-28),shaft.lightened(0.2),1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(20,-28),Vector2(16,-20),Vector2(24,-20)]),iron)

	func _pv_rogue() -> void:
		var skin    := Color(0.94, 0.78, 0.60); var dark    := Color(0.14, 0.14, 0.18)
		var dark_l  := Color(0.22, 0.22, 0.30); var leather := Color(0.30, 0.20, 0.10)
		var bandana := Color(0.10, 0.10, 0.12); var blade   := Color(0.75, 0.80, 0.88)
		draw_rect(Rect2(-9,4,8,12),dark); draw_rect(Rect2(1,4,8,12),dark)
		draw_colored_polygon(PackedVector2Array([Vector2(-10,-8),Vector2(10,-8),Vector2(12,6),Vector2(-12,6)]),dark)
		draw_colored_polygon(PackedVector2Array([Vector2(-10,-8),Vector2(10,-8),Vector2(9,-2),Vector2(-9,-2)]),dark_l)
		draw_line(Vector2(-10,-4),Vector2(10,-2),leather,1.5)
		draw_rect(Rect2(-12,4,24,4),leather)
		draw_rect(Rect2(-16,-7,9,5),skin); draw_rect(Rect2(7,-7,9,5),skin)
		draw_circle(Vector2(0,-17),8,skin)
		draw_circle(Vector2(0,-24),7,dark); draw_rect(Rect2(-7,-24,14,8),dark)
		draw_rect(Rect2(-9,-19,18,5),bandana)
		draw_circle(Vector2(-3,-21),1.5,Color(0.20,0.12,0.08)); draw_circle(Vector2(3,-21),1.5,Color(0.20,0.12,0.08))
		# Twin daggers at rest
		draw_line(Vector2(-18,-6),Vector2(-10,-18),blade,3.0); draw_line(Vector2(-18,-6),Vector2(-10,-18),Color(1,1,1,0.4),1.0)
		draw_line(Vector2(18,-6),Vector2(10,-18),blade,3.0);   draw_line(Vector2(18,-6),Vector2(10,-18),Color(1,1,1,0.4),1.0)

	func _pv_elite_knight() -> void:
		var steel   := Color(0.22, 0.38, 0.72); var steel_d := Color(0.12, 0.22, 0.48)
		var gold    := Color(0.95, 0.82, 0.22); var crimson := Color(0.80, 0.12, 0.14)
		var leather := Color(0.38, 0.22, 0.10)
		# Cape
		draw_colored_polygon(PackedVector2Array([Vector2(-10,-4),Vector2(10,-4),Vector2(14,22),Vector2(-14,22)]),crimson)
		# Greaves
		draw_rect(Rect2(-11,12,10,12),steel_d); draw_rect(Rect2(1,12,10,12),steel_d)
		draw_rect(Rect2(-11,4,10,10),steel);    draw_rect(Rect2(1,4,10,10),steel)
		# Breastplate
		draw_colored_polygon(PackedVector2Array([Vector2(-13,-10),Vector2(13,-10),Vector2(11,6),Vector2(-11,6)]),steel)
		draw_line(Vector2(-13,-10),Vector2(13,-10),gold,3.0)
		# Pauldrons
		draw_circle(Vector2(-17,-7),9,steel); draw_circle(Vector2(-17,-7),9,steel_d,false,2.5)
		draw_circle(Vector2(17,-7),9,steel);  draw_circle(Vector2(17,-7),9,steel_d,false,2.5)
		# Helmet + plume
		draw_circle(Vector2(0,-20),10,steel); draw_circle(Vector2(0,-20),10,steel_d,false,2.0)
		draw_rect(Rect2(-10,-24,20,6),steel_d)
		draw_rect(Rect2(-8,-23,6,4),steel.darkened(0.6)); draw_rect(Rect2(2,-23,6,4),steel.darkened(0.6))
		draw_rect(Rect2(-3,-32,6,14),steel); draw_rect(Rect2(-4,-38,8,10),crimson)
		draw_line(Vector2(-10,-17),Vector2(10,-17),gold,2.5)
		# Great-sword at rest
		draw_rect(Rect2(14,-6,7,6),steel)
		draw_rect(Rect2(16,-38,7,44),steel); draw_rect(Rect2(16,-38,7,44),steel_d,false,1.8)
		draw_rect(Rect2(8,-4,22,6),gold); draw_rect(Rect2(18,2,6,14),leather)

	func _pv_iron_guard() -> void:
		var iron   := Color(0.52, 0.56, 0.66); var iron_d := Color(0.30, 0.32, 0.42)
		var iron_l := Color(0.72, 0.76, 0.88); var tunic  := Color(0.18, 0.32, 0.72)
		var boots  := Color(0.18, 0.12, 0.06); var gold   := Color(0.90, 0.76, 0.20)
		draw_rect(Rect2(-10,16,9,8),boots); draw_rect(Rect2(1,16,9,8),boots)
		draw_rect(Rect2(-10,4,9,14),iron.darkened(0.1)); draw_rect(Rect2(-10,4,9,14),iron_d,false,1.5)
		draw_rect(Rect2(1,4,9,14),iron.darkened(0.1));   draw_rect(Rect2(1,4,9,14),iron_d,false,1.5)
		draw_colored_polygon(PackedVector2Array([Vector2(-12,-10),Vector2(12,-10),Vector2(14,6),Vector2(-14,6)]),iron)
		draw_polyline(PackedVector2Array([Vector2(-12,-10),Vector2(12,-10),Vector2(14,6),Vector2(-14,6),Vector2(-12,-10)]),iron_d,2.0)
		draw_line(Vector2(-12,-10),Vector2(12,-10),gold,3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-5,-10),Vector2(5,-10),Vector2(4,0),Vector2(-4,0)]),tunic)
		draw_circle(Vector2(-16,-6),9,iron); draw_circle(Vector2(-16,-6),9,iron_d,false,2.5)
		draw_circle(Vector2(16,-6),9,iron);  draw_circle(Vector2(16,-6),9,iron_d,false,2.5)
		draw_circle(Vector2(0,-20),10,iron); draw_circle(Vector2(0,-20),10,iron_d,false,2.0)
		draw_rect(Rect2(-10,-24,20,6),iron_d)
		draw_rect(Rect2(-8,-23,6,4),Color(0.08,0.08,0.12,0.9))
		draw_rect(Rect2(2,-23,6,4),Color(0.08,0.08,0.12,0.9))
		draw_line(Vector2(-10,-17),Vector2(10,-17),gold,2.5)
		# Left shield at rest
		draw_colored_polygon(PackedVector2Array([Vector2(-28,-14),Vector2(-16,-14),Vector2(-14,6),Vector2(-21,14),Vector2(-28,6)]),iron)
		draw_polyline(PackedVector2Array([Vector2(-28,-14),Vector2(-16,-14),Vector2(-14,6),Vector2(-21,14),Vector2(-28,6),Vector2(-28,-14)]),gold,2.0)
		draw_circle(Vector2(-21,-4),3,gold)
		# Right shield at rest
		draw_colored_polygon(PackedVector2Array([Vector2(16,-14),Vector2(28,-14),Vector2(28,6),Vector2(21,14),Vector2(14,6)]),iron)
		draw_polyline(PackedVector2Array([Vector2(16,-14),Vector2(28,-14),Vector2(28,6),Vector2(21,14),Vector2(14,6),Vector2(16,-14)]),gold,2.0)
		draw_circle(Vector2(21,-4),3,gold)

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


# ── Boss-drop chip (Node2D placed in game scene, behind enemies) ──────────────

class _BossChip extends Node2D:
	const W : float = 38.0
	const H : float = 54.0
	var _bg  : Color = Color(0.15, 0.10, 0.22)
	var _brd : Color = Color.WHITE
	var _sym : String = "●"
	var _fnt : Font   = null

	func setup(bg_clr: Color, brd_clr: Color, sym: String, fnt: Font) -> void:
		_bg  = bg_clr
		_brd = brd_clr
		_sym = sym
		_fnt = fnt

	func _draw() -> void:
		var r := Rect2(-W * 0.5, -H * 0.5, W, H)
		draw_rect(r, _bg)
		draw_rect(r, _brd, false, 2.0)
		# Tint strip at top
		draw_rect(Rect2(-W * 0.5 + 2, -H * 0.5 + 2, W - 4, H * 0.40),
			Color(_brd.r, _brd.g, _brd.b, 0.35))
		if _fnt:
			draw_string(_fnt, Vector2(-W * 0.5, H * 0.10), _sym,
				HORIZONTAL_ALIGNMENT_CENTER, W, 18, _brd)


class _StarNode extends Node2D:
	var _char : String = "★"
	var _clr  : Color  = Color.WHITE
	var _fnt  : Font   = null

	func setup(ch: String, clr: Color, fnt: Font) -> void:
		_char = ch; _clr = clr; _fnt = fnt

	func _draw() -> void:
		if _fnt:
			draw_string(_fnt, Vector2(-5, 5), _char,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, _clr)
