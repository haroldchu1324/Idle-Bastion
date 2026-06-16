# ui/TutorialOverlay.gd
# Spotlight tutorial overlay shown on first game run.
# Add as child of HUD, then call setup(font_b, font_r).
#
# Input strategy:
#   The Control itself is MOUSE_FILTER_IGNORE (draw-only).
#   Invisible ColorRect "blockers" cover the non-highlighted areas.
#   A 5th blocker covers the highlighted area itself on steps where
#   the player should not be able to click it.
#   On interactive steps the highlight blocker is hidden so the
#   underlying UI element is truly clickable.
extends Control

const OVERLAY_CLR := Color(0.04, 0.04, 0.10, 0.82)
const BORDER_CLR  := Color(1.00, 0.88, 0.28, 1.00)
const HINT_CLR    := Color(1.00, 0.88, 0.28, 0.85)

const PRESS_COMMON_STEP : int = 2
const MOVE_TOWER_STEP   : int = 3
const CLICK_TOWER_STEP  : int = 4
const CLICK_INFO_STEP   : int = 5
# Steps where the highlighted area is left interactive (no hl blocker)
const SEND_WAVE_STEP    : int   = 8
const INTERACTIVE_STEPS : Array = [2, 3, 4, 5, 8]

var _step     : int   = 0
var _panel    : Panel = null
var _text_lbl : Label = null
var _time     : float = 0.0

# World 1 target tile for the move step: col=1, row=0 → Rect2(340, 170, 60, 60)
const MOVE_TARGET_RECT := Rect2(340.0, 170.0, 60.0, 60.0)

# Input blockers — invisible ColorRects that eat mouse events
var _blocker_top    : ColorRect = null
var _blocker_bot    : ColorRect = null
var _blocker_left   : ColorRect = null
var _blocker_right  : ColorRect = null
var _blocker_hl     : ColorRect = null   # covers highlight rect on non-interactive steps

# ── Tutorial steps ─────────────────────────────────────────────────────────────
# "hint" key: shown instead of Next button; step auto-advances via signal
var _steps : Array = [
	# 0 — right panel overview
	{
		"rect": Rect2(1018, 0, 258, 660),
		"text": "This is where you summon turrets to defend the onslaught of enemies.",
		"px": 645.0, "py": 265.0
	},
	# 1 — common button explanation
	{
		"rect": Rect2(1018, 118, 258, 96),
		"text": "This button will summon a random tower from the common rarity.",
		"px": 645.0, "py": 112.0
	},
	# 2 — INTERACTIVE: player must press Common Summon
	{
		"rect": Rect2(1018, 118, 258, 96),
		"text": "Press the Common Summon button to summon your first tower!",
		"px": 645.0, "py": 112.0,
		"hint": "↑  Press the highlighted button to continue"
	},
	# 3 — INTERACTIVE: move a tower to a different tile
	{
		"rect": Rect2(275, 165, 550, 310),
		"text": "You can move your towers!\n\nClick and hold a tower, then drag it to the highlighted tile (↑ top-left area).",
		"px": 20.0, "py": 505.0,
		"hint": "Drag the tower to the highlighted tile to continue"
	},
	# 4 — INTERACTIVE: click the tower to select it (rect updated to MOVE_TARGET_RECT on advance)
	{
		"rect": Rect2(340.0, 170.0, 60.0, 60.0),
		"text": "Now click on the highlighted tower to select it.",
		"px": 20.0, "py": 505.0,
		"hint": "Click on the tower to continue"
	},
	# 5 — INTERACTIVE: click ⓘ button (rect updated dynamically via signal)
	{
		"rect": Rect2(900, 300, 120, 60),
		"text": "Click the ⓘ button to see detailed stats.",
		"px": 20.0, "py": 505.0,
		"hint": "Click the ⓘ button to continue"
	},
	# 6 — stat page (Selected Tower panel: pos 6,182 size 210x430)
	{
		"rect": Rect2(6, 182, 210, 430),
		"text": "This is the stat page showing your tower's detailed information.",
		"px": 228.0, "py": 300.0
	},
	# 7 — rare + epic buttons
	{
		"rect": Rect2(1018, 206, 258, 176),
		"text": "These have a higher chance of summoning higher rarities.",
		"px": 645.0, "py": 240.0
	},
	# 8 — INTERACTIVE: wave button (last step)
	{
		"rect": Rect2(726, 648, 230, 72),
		"text": "Press this button to send the first wave.",
		"px": 376.0, "py": 468.0,
		"hint": "↑  Press the wave button to begin!"
	},
]


func setup(font_b: Font, font_r: Font) -> void:
	position     = Vector2.ZERO
	size         = Vector2(1280, 720)
	mouse_filter = MOUSE_FILTER_IGNORE   # draw-only; input handled by blocker children
	z_index      = 200

	_build_blockers()
	_build_panel(font_b, font_r)

	var hud = get_parent()

	# Auto-advance step 2 when Common Summon is actually pressed
	if hud and hud.has_signal("roll_turret_requested"):
		hud.roll_turret_requested.connect(func():
			if _step == PRESS_COMMON_STEP:
				_step += 1
				_apply_step()
		)

	# Advance step 3 when the player moves a tower to a different tile
	if hud and hud.has_signal("tower_moved_tutorial"):
		hud.tower_moved_tutorial.connect(func():
			if _step == MOVE_TOWER_STEP:
				# Spotlight the tower's tile (1,0) for the click-tower step
				_steps[CLICK_TOWER_STEP]["rect"] = MOVE_TARGET_RECT
				_step += 1
				_apply_step()
		)

	# Advance step 4 when a tower is selected; also update step 5 rect dynamically
	if hud and hud.has_signal("tower_selected_tutorial"):
		hud.tower_selected_tutorial.connect(func(ib_rect: Rect2):
			if _step == CLICK_TOWER_STEP:
				_steps[CLICK_INFO_STEP]["rect"] = ib_rect
				_steps[CLICK_INFO_STEP]["px"]   = 20.0
				_steps[CLICK_INFO_STEP]["py"]   = 505.0
				_step += 1
				_apply_step()
		)

	# Advance step 5 when the tower detail panel opens
	if hud and hud.has_signal("tower_detail_opened_tutorial"):
		hud.tower_detail_opened_tutorial.connect(func():
			if _step == CLICK_INFO_STEP:
				_step += 1
				_apply_step()
		)

	# Finish tutorial when the wave button is pressed on the last step
	if hud and hud.has_signal("wave_pressed"):
		hud.wave_pressed.connect(func():
			if _step == SEND_WAVE_STEP:
				_step += 1
				_apply_step()
		)

	_apply_step()


# ── Blocker helpers ────────────────────────────────────────────────────────────
func _build_blockers() -> void:
	_blocker_top   = _make_blocker()
	_blocker_bot   = _make_blocker()
	_blocker_left  = _make_blocker()
	_blocker_right = _make_blocker()
	_blocker_hl    = _make_blocker()


func _make_blocker() -> ColorRect:
	var cr := ColorRect.new()
	cr.color        = Color(0, 0, 0, 0)   # transparent — visual is done in _draw()
	cr.mouse_filter = MOUSE_FILTER_STOP
	cr.z_index      = 200
	add_child(cr)
	return cr


func _update_blockers(r: Rect2, block_highlight: bool) -> void:
	var rx := r.position.x;  var ry := r.position.y
	var rw := r.size.x;      var rh := r.size.y

	_blocker_top.position  = Vector2(0, 0)
	_blocker_top.size      = Vector2(1280, ry)

	_blocker_bot.position  = Vector2(0, ry + rh)
	_blocker_bot.size      = Vector2(1280, 720 - ry - rh)

	_blocker_left.position = Vector2(0, ry)
	_blocker_left.size     = Vector2(rx, rh)

	_blocker_right.position = Vector2(rx + rw, ry)
	_blocker_right.size     = Vector2(1280 - rx - rw, rh)

	_blocker_hl.position = r.position
	_blocker_hl.size     = r.size
	_blocker_hl.visible  = block_highlight


# ── Text bubble ────────────────────────────────────────────────────────────────
func _build_panel(font_b: Font, font_r: Font) -> void:
	_panel = Panel.new()
	_panel.size    = Vector2(340, 195)
	_panel.z_index = 201   # above blockers so Next button is always clickable

	var ps := StyleBoxFlat.new()
	ps.bg_color                   = Color(0.06, 0.06, 0.14, 0.97)
	ps.corner_radius_top_left     = 10; ps.corner_radius_top_right    = 10
	ps.corner_radius_bottom_left  = 10; ps.corner_radius_bottom_right = 10
	ps.border_width_left = 2; ps.border_width_right  = 2
	ps.border_width_top  = 2; ps.border_width_bottom = 2
	ps.border_color = BORDER_CLR
	_panel.add_theme_stylebox_override("panel", ps)
	add_child(_panel)

	_text_lbl = Label.new()
	_text_lbl.position      = Vector2(14, 12)
	_text_lbl.size          = Vector2(312, 120)
	_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_lbl.add_theme_font_override("font", font_r)
	_text_lbl.add_theme_font_size_override("font_size", 15)
	_text_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.96))
	_panel.add_child(_text_lbl)

	var step_lbl := Label.new()
	step_lbl.name     = "StepLbl"
	step_lbl.position = Vector2(14, 148)
	step_lbl.size     = Vector2(120, 22)
	step_lbl.add_theme_font_override("font", font_b)
	step_lbl.add_theme_font_size_override("font_size", 12)
	step_lbl.add_theme_color_override("font_color", Color(0.50, 0.50, 0.62))
	_panel.add_child(step_lbl)

	var next_btn := Button.new()
	next_btn.name       = "NextBtn"
	next_btn.position   = Vector2(220, 144)
	next_btn.size       = Vector2(106, 38)
	next_btn.focus_mode = FOCUS_NONE
	next_btn.add_theme_font_override("font", font_b)
	next_btn.add_theme_font_size_override("font_size", 14)
	next_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	var bs := StyleBoxFlat.new()
	bs.bg_color                   = Color(0.18, 0.38, 0.62)
	bs.corner_radius_top_left     = 6; bs.corner_radius_top_right    = 6
	bs.corner_radius_bottom_left  = 6; bs.corner_radius_bottom_right = 6
	var bsh := bs.duplicate() as StyleBoxFlat
	bsh.bg_color = Color(0.26, 0.52, 0.84)
	next_btn.add_theme_stylebox_override("normal",  bs)
	next_btn.add_theme_stylebox_override("hover",   bsh)
	next_btn.add_theme_stylebox_override("pressed", bs)
	next_btn.add_theme_stylebox_override("focus",   bs)
	next_btn.pressed.connect(_on_next)
	_panel.add_child(next_btn)

	var hint_lbl := Label.new()
	hint_lbl.name     = "HintLbl"
	hint_lbl.position = Vector2(14, 148)
	hint_lbl.size     = Vector2(312, 38)
	hint_lbl.visible  = false
	hint_lbl.add_theme_font_override("font", font_b)
	hint_lbl.add_theme_font_size_override("font_size", 13)
	hint_lbl.add_theme_color_override("font_color", HINT_CLR)
	_panel.add_child(hint_lbl)


# ── Step logic ─────────────────────────────────────────────────────────────────
func _apply_step() -> void:
	if _step >= _steps.size():
		_finish()
		return

	var s          : Dictionary = _steps[_step]
	var hint_text  : String     = s.get("hint", "")
	var is_press   : bool       = hint_text != ""
	var is_interactive : bool   = (_step in INTERACTIVE_STEPS)

	_panel.position = Vector2(s["px"], s["py"])
	_text_lbl.text  = s["text"]

	_update_blockers(s["rect"], not is_interactive)

	var hud := get_parent()
	if hud and "tutorial_block_drag" in hud:
		hud.tutorial_block_drag     = (_step == CLICK_TOWER_STEP)
		hud.tutorial_block_info_btn = (_step == MOVE_TOWER_STEP)
		hud.tutorial_lock_unit_btns = (_step == CLICK_INFO_STEP)

	var step_lbl := _panel.get_node_or_null("StepLbl") as Label
	if step_lbl:
		step_lbl.text    = "%d / %d" % [_step + 1, _steps.size()]
		step_lbl.visible = not is_press

	var next_btn := _panel.get_node_or_null("NextBtn") as Button
	if next_btn:
		next_btn.visible = not is_press
		next_btn.text    = "Got it!" if _step == _steps.size() - 1 else "Next  →"

	var hint_lbl := _panel.get_node_or_null("HintLbl") as Label
	if hint_lbl:
		hint_lbl.text    = hint_text
		hint_lbl.visible = is_press

	queue_redraw()


func _on_next() -> void:
	_step += 1
	_apply_step()


func _process(delta: float) -> void:
	_time += delta
	if _step == MOVE_TOWER_STEP:
		queue_redraw()


func _finish() -> void:
	GameData.tutorial_complete = true
	GameData.save_game()
	queue_free()


# ── Drawing (visual only — no input) ──────────────────────────────────────────
func _draw() -> void:
	if _step >= _steps.size():
		return
	var r  : Rect2 = _steps[_step]["rect"]
	var rx : float = r.position.x
	var ry : float = r.position.y
	var rw : float = r.size.x
	var rh : float = r.size.y

	# 4 dark panels surrounding the spotlight
	if ry > 0.0:
		draw_rect(Rect2(0.0, 0.0, 1280.0, ry), OVERLAY_CLR)
	if ry + rh < 720.0:
		draw_rect(Rect2(0.0, ry + rh, 1280.0, 720.0 - ry - rh), OVERLAY_CLR)
	if rx > 0.0:
		draw_rect(Rect2(0.0, ry, rx, rh), OVERLAY_CLR)
	if rx + rw < 1280.0:
		draw_rect(Rect2(rx + rw, ry, 1280.0 - rx - rw, rh), OVERLAY_CLR)

	# Target tile highlight during move step (pulsing gold fill + border)
	if _step == MOVE_TOWER_STEP:
		var pulse : float = sin(_time * 4.0) * 0.5 + 0.5
		draw_rect(MOVE_TARGET_RECT, Color(1.0, 0.88, 0.28, 0.12 + pulse * 0.18))
		draw_rect(MOVE_TARGET_RECT, Color(1.0, 0.88, 0.28, 0.65 + pulse * 0.35), false, 3.0)
		# Small arrow pointing down into the target tile
		var cx := MOVE_TARGET_RECT.position.x + MOVE_TARGET_RECT.size.x * 0.5
		var ty := MOVE_TARGET_RECT.position.y - 4.0
		draw_line(Vector2(cx, ty - 14.0), Vector2(cx, ty), BORDER_CLR, 2.5)
		draw_line(Vector2(cx - 7.0, ty - 8.0), Vector2(cx, ty), BORDER_CLR, 2.5)
		draw_line(Vector2(cx + 7.0, ty - 8.0), Vector2(cx, ty), BORDER_CLR, 2.5)

	# Golden highlight border
	draw_rect(r, BORDER_CLR, false, 2.5)

	# Corner bracket accents
	var ac : float = 16.0; var lw : float = 3.5
	draw_line(Vector2(rx,      ry),      Vector2(rx + ac,      ry),      BORDER_CLR, lw)
	draw_line(Vector2(rx,      ry),      Vector2(rx,      ry + ac),      BORDER_CLR, lw)
	draw_line(Vector2(rx + rw, ry),      Vector2(rx + rw - ac, ry),      BORDER_CLR, lw)
	draw_line(Vector2(rx + rw, ry),      Vector2(rx + rw, ry + ac),      BORDER_CLR, lw)
	draw_line(Vector2(rx,      ry + rh), Vector2(rx + ac,      ry + rh), BORDER_CLR, lw)
	draw_line(Vector2(rx,      ry + rh), Vector2(rx,      ry + rh - ac), BORDER_CLR, lw)
	draw_line(Vector2(rx + rw, ry + rh), Vector2(rx + rw - ac, ry + rh), BORDER_CLR, lw)
	draw_line(Vector2(rx + rw, ry + rh), Vector2(rx + rw, ry + rh - ac), BORDER_CLR, lw)
