# ui/UpgradeTree.gd
extends Control

# ── Debug toggle — set false before exporting ─────────────────────────────────
const DEBUG : bool = false

const NODE_R     : float = 36.0
const CENTER_R   : float = 48.0
const SPECIAL_R  : float = 42.0
const LINE_W     : float = 3.5
const C_LOCKED     := Color(0.137, 0.125, 0.102)   # dark stone
const C_LOCKED_BDR := Color(0.333, 0.306, 0.255)   # worn stone border
const C_AVAIL_BDR  := Color(0.847, 0.702, 0.365)   # royal gold #D8B35D
const C_DONE_BDR   := Color(0.949, 0.851, 0.545)   # highlight gold #F2D98B
const C_LINE_OFF   := Color(0.235, 0.216, 0.176)   # dim stone line
const C_LINE_ON    := Color(0.847, 0.702, 0.365)   # royal gold line
const C_GEM        := Color(0.298, 0.608, 0.910)   # arcane blue #4C9BE8
const TIER_COSTS   : Array = [15, 25, 40]

var _nodes       : Array      = []
var _canvas_off  : Vector2    = Vector2.ZERO
var _drag_start  : Vector2    = Vector2.ZERO
var _dragging    : bool       = false
var _drag_moved  : bool       = false
var _font_bold   : Font       = null
var _font_reg    : Font       = null
var _gem_lbl     : Label      = null
var _popup       : Control    = null
var _active_id   : String     = ""


func setup(bold: Font, reg: Font) -> void:
	_font_bold = bold
	_font_reg  = reg
	if _nodes.is_empty():
		_build_node_data()
	_build_gem_label()
	_build_reset_btn()
	queue_redraw()


func _build_gem_label() -> void:
	if is_instance_valid(_gem_lbl):
		_gem_lbl.text = "%d gems" % GameData.blue_gems
		return
	var hbox := HBoxContainer.new()
	hbox.position = Vector2(1280 - 260, 8)
	hbox.size     = Vector2(242, 38)
	hbox.alignment = BoxContainer.ALIGNMENT_END
	hbox.add_theme_constant_override("separation", 5)
	hbox.z_index = 5
	hbox.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(hbox)
	hbox.add_child(_mk_blue_gem_icon(24.0))
	_gem_lbl = Label.new()
	_gem_lbl.add_theme_font_override("font", _font_bold)
	_gem_lbl.add_theme_font_size_override("font_size", 20)
	_gem_lbl.add_theme_color_override("font_color", C_GEM)
	_gem_lbl.z_index = 5
	_gem_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	hbox.add_child(_gem_lbl)
	_gem_lbl.text = "%d gems" % GameData.blue_gems


func _build_reset_btn() -> void:
	# Only add once
	for ch in get_children():
		if ch.name == "ResetBtn":
			return

	var btn := Button.new()
	btn.name       = "ResetBtn"
	btn.text       = "🔄  Reset Upgrades (Debug)"
	btn.position   = Vector2(14, 720 - 62)
	btn.size       = Vector2(260, 42)
	btn.z_index    = 10
	btn.focus_mode = FOCUS_NONE
	btn.add_theme_font_override("font", _font_bold)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(1, 0.6, 0.6))
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.28, 0.10, 0.10, 0.92)
	s.corner_radius_top_left = 7; s.corner_radius_top_right = 7
	s.corner_radius_bottom_left = 7; s.corner_radius_bottom_right = 7
	s.border_width_left = 1; s.border_width_right = 1
	s.border_width_top  = 1; s.border_width_bottom = 1
	s.border_color = Color(0.7, 0.25, 0.25)
	var sh := s.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.42, 0.14, 0.14, 0.95)
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_stylebox_override("focus",   s)
	btn.pressed.connect(_on_reset_pressed)
	btn.visible = DEBUG
	add_child(btn)

	var add_btn := Button.new()
	add_btn.name       = "AddGemsBtn"
	add_btn.text       = "💎  +1000 Gems (Debug)"
	add_btn.position   = Vector2(14, 720 - 110)
	add_btn.size       = Vector2(260, 42)
	add_btn.z_index    = 10
	add_btn.focus_mode = FOCUS_NONE
	add_btn.add_theme_font_override("font", _font_bold)
	add_btn.add_theme_font_size_override("font_size", 14)
	add_btn.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	var as_ := StyleBoxFlat.new()
	as_.bg_color = Color(0.10, 0.28, 0.14, 0.92)
	as_.corner_radius_top_left = 7; as_.corner_radius_top_right = 7
	as_.corner_radius_bottom_left = 7; as_.corner_radius_bottom_right = 7
	as_.border_width_left = 1; as_.border_width_right = 1
	as_.border_width_top  = 1; as_.border_width_bottom = 1
	as_.border_color = Color(0.25, 0.65, 0.35)
	var ash := as_.duplicate() as StyleBoxFlat
	ash.bg_color = Color(0.14, 0.40, 0.20, 0.95)
	add_btn.add_theme_stylebox_override("normal",  as_)
	add_btn.add_theme_stylebox_override("hover",   ash)
	add_btn.add_theme_stylebox_override("pressed", as_)
	add_btn.add_theme_stylebox_override("focus",   as_)
	add_btn.pressed.connect(func():
		GameData.blue_gems += 1000
		GameData.save_game()
		if is_instance_valid(_gem_lbl):
			_gem_lbl.text = "%d gems" % GameData.blue_gems
		if is_instance_valid(_popup):
			var nd := _get_active_node()
			if not nd.is_empty():
				_open_popup(nd)
	)
	add_btn.visible = DEBUG
	add_child(add_btn)


func _on_reset_pressed() -> void:
	# Refund all spent gems and clear all purchases
	var refund : int = 0
	for nd in _nodes:
		var t := GameData.get_upgrade_tiers(nd["id"])
		for i in range(t):
			refund += nd["costs"][i]
	GameData.blue_gems += refund
	GameData.upgrade_purchases = {}
	GameData.save_game()
	if is_instance_valid(_gem_lbl):
		_gem_lbl.text = "%d gems" % GameData.blue_gems
	_close_popup()
	_active_id = ""
	queue_redraw()


# ── Node definitions ───────────────────────────────────────────────────────────
func _build_node_data() -> void:
	_nodes.clear()

	_add_node({"id": "core", "label": "Core", "max_tiers": 1,
		"costs": [1], "effect_key": "core", "prereqs": [],
		"world_pos": Vector2(0, 0), "color": Color(0.90, 0.78, 0.22),
		"desc": "The heart of the bastion.\nUnlocks all upgrade branches."})

	_branch("archer",   "Archer",    Color(0.35, 0.75, 0.25),
		Vector2(215, -45),  Vector2(400, -130), Vector2(410, 75),   Vector2(610, -25),
		"Focused Shot+\nEvery hit permanently\nstacks +8% damage (max 10×).")

	_branch("crossbow", "Crossbow",  Color(0.35, 0.55, 0.90),
		Vector2(165, 215),  Vector2(340, 155),  Vector2(255, 375),  Vector2(490, 300),
		"Triple Bolt\nFires 3 bolts instead of 2.")

	_branch("mage",     "Mage",      Color(0.70, 0.28, 0.92),
		Vector2(-165, 215), Vector2(-255, 375), Vector2(-340, 155), Vector2(-490, 300),
		"Arcane Chain\nChain hits 5 enemies (up from 3).")

	_branch("catapult", "Catapult",  Color(0.80, 0.50, 0.20),
		Vector2(-215, 45),  Vector2(-410, -55), Vector2(-400, 150), Vector2(-610, 45),
		"Barrage\nFires 2 shots per attack.")

	_branch("spearman", "Spearman",  Color(0.72, 0.52, 0.28),
		Vector2(-140, -235), Vector2(-55, -405), Vector2(-305, -345), Vector2(-220, -530),
		"War Cry\nEvery 5th hit stuns\nenemies for 0.5s.")

	_branch("rogue",    "Rogue",     Color(0.62, 0.62, 0.72),
		Vector2(140, -235),  Vector2(305, -345), Vector2(55, -405),  Vector2(220, -530),
		"Hemorrhage\nBleed cap raised to 6.\nEach stack deals +12% damage.")


func _branch(tid: String, tname: String, col: Color,
			 intro_pos: Vector2, dmg_pos: Vector2, spd_pos: Vector2,
			 special_pos: Vector2, special_desc: String) -> void:
	_add_node({"id": tid + "_intro", "label": tname, "max_tiers": 1,
		"costs": [10], "effect_key": tid + "_intro", "prereqs": ["core"],
		"world_pos": intro_pos, "color": col,
		"desc": "Begin the %s upgrade path." % tname})

	_add_node({"id": tid + "_dmg", "label": "Damage", "max_tiers": 3,
		"costs": TIER_COSTS, "effect_key": tid + "_dmg", "prereqs": [tid + "_intro"],
		"world_pos": dmg_pos, "color": col,
		"desc": "+15%% %s damage per tier.\nMax +45%% at tier 3." % tname})

	_add_node({"id": tid + "_spd", "label": "Atk Speed", "max_tiers": 3,
		"costs": TIER_COSTS, "effect_key": tid + "_spd", "prereqs": [tid + "_intro"],
		"world_pos": spd_pos, "color": col,
		"desc": "+15%% %s attack speed per tier.\nMax +45%% at tier 3." % tname})

	_add_node({"id": tid + "_special", "label": "★ " + tname, "max_tiers": 1,
		"costs": [80], "effect_key": tid + "_special",
		"prereqs": [tid + "_dmg", tid + "_spd"],
		"world_pos": special_pos, "color": col.lightened(0.2),
		"desc": special_desc})


func _add_node(d: Dictionary) -> void:
	_nodes.append(d)


# ── State helpers ──────────────────────────────────────────────────────────────
func _tiers(nd: Dictionary) -> int:
	return GameData.get_upgrade_tiers(nd["id"])

func _maxed(nd: Dictionary) -> bool:
	return _tiers(nd) >= nd["max_tiers"]

func _prereqs_met(nd: Dictionary) -> bool:
	for pid in nd["prereqs"]:
		for pn in _nodes:
			if pn["id"] == pid:
				if not _maxed(pn):
					return false
				break
	return true

func _available(nd: Dictionary) -> bool:
	return not _maxed(nd) and _prereqs_met(nd)

func _next_cost(nd: Dictionary) -> int:
	var t := _tiers(nd)
	if t >= nd["max_tiers"]: return 0
	return nd["costs"][t]


# ── Canvas transform ───────────────────────────────────────────────────────────
func _to_screen(wp: Vector2) -> Vector2:
	return wp + Vector2(640, 360) + _canvas_off

func _to_world(sp: Vector2) -> Vector2:
	return sp - Vector2(640, 360) - _canvas_off


# ── Drawing ────────────────────────────────────────────────────────────────────
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.04, 0.09))

	# Subtle grid dots
	var gs := 60
	var ox := int(_canvas_off.x) % gs
	var oy := int(_canvas_off.y) % gs
	for gx in range(-1, int(size.x) / gs + 2):
		for gy in range(-1, int(size.y) / gs + 2):
			draw_circle(Vector2(gx * gs + ox, gy * gs + oy), 1.2, Color(1, 1, 1, 0.06))

	# Connections
	for nd in _nodes:
		var to := _to_screen(nd["world_pos"])
		for pid in nd["prereqs"]:
			for pn in _nodes:
				if pn["id"] == pid:
					var frm := _to_screen(pn["world_pos"])
					var lit := _maxed(pn) and _prereqs_met(nd)
					draw_line(frm, to, Color(C_LINE_OFF.r, C_LINE_OFF.g, C_LINE_OFF.b, 0.4), LINE_W + 3)
					draw_line(frm, to, C_LINE_ON if lit else C_LINE_OFF, LINE_W)
					break

	for nd in _nodes:
		_draw_node(nd)


func _draw_node(nd: Dictionary) -> void:
	var pos   := _to_screen(nd["world_pos"])
	var col   : Color = nd["color"]
	var t     := _tiers(nd)
	var mt    : int = nd["max_tiers"]
	var done  := t >= mt
	var avail := _available(nd)
	var locked := not done and not avail
	var id    : String = nd["id"]
	var r : float = CENTER_R if id == "core" else (SPECIAL_R if id.ends_with("_special") else NODE_R)

	# Glow on available
	if avail:
		draw_circle(pos, r + 9, Color(col.r, col.g, col.b, 0.10))
		draw_circle(pos, r + 5, Color(col.r, col.g, col.b, 0.18))

	# Active ring
	if _active_id == id:
		draw_circle(pos, r + 6, Color(1, 1, 1, 0.20))

	# Shadow
	draw_circle(pos + Vector2(3, 4), r, Color(0, 0, 0, 0.45))

	# Fill
	var fill : Color
	if done:   fill = Color(col.r * 0.50, col.g * 0.50, col.b * 0.22, 1.0)
	elif avail: fill = Color(col.r * 0.20, col.g * 0.20, col.b * 0.10, 1.0)
	else:       fill = C_LOCKED
	draw_circle(pos, r, fill)

	# Border
	var bdr := C_DONE_BDR if done else (C_AVAIL_BDR if avail else C_LOCKED_BDR)
	draw_arc(pos, r, 0, TAU, 64, bdr, 2.5)

	# Icon or lock
	if locked and id != "core":
		_draw_lock(pos)
		return

	var icon_col := bdr if done else (col.lightened(0.3) if avail else col)
	_draw_node_icon(pos, nd, icon_col)

	# Tier pips for multi-tier nodes
	if mt > 1:
		var pip_r   : float = 5.0
		var spacing : float = 13.0
		var sx      : float = pos.x - (mt - 1) * spacing * 0.5
		for i in range(mt):
			var pp := Vector2(sx + i * spacing, pos.y + r - 8)
			draw_circle(pp, pip_r, C_DONE_BDR if i < t else C_LOCKED_BDR)
		if t > 0 and t < mt:
			# Small tier counter below pips
			_draw_label(pos + Vector2(0, r - 20), "%d/%d" % [t, mt], 11, C_DONE_BDR)


# ── Icon drawing ───────────────────────────────────────────────────────────────
func _draw_node_icon(pos: Vector2, nd: Dictionary, col: Color) -> void:
	var id : String = nd["id"]
	var sc : float  = 10.0

	if id == "core":
		# Flame polygon
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(0, -sc * 1.3),
			pos + Vector2(sc * 0.65, -sc * 0.2),
			pos + Vector2(sc * 0.4,  sc * 0.9),
			pos + Vector2(0,          sc * 0.4),
			pos + Vector2(-sc * 0.4,  sc * 0.9),
			pos + Vector2(-sc * 0.65, -sc * 0.2),
		]), col)
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(0,          -sc * 0.6),
			pos + Vector2(sc * 0.30,   sc * 0.3),
			pos + Vector2(0,           sc * 0.5),
			pos + Vector2(-sc * 0.30,  sc * 0.3),
		]), Color(col.r, col.g * 0.6, col.b * 0.2, 0.7))
		return

	if id.ends_with("_dmg"):
		# Upward sword: pointed blade tip, narrow body, crossguard, short handle
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(0,           -sc),
			pos + Vector2(sc * 0.22,  -sc * 0.15),
			pos + Vector2(-sc * 0.22, -sc * 0.15),
		]), col)
		draw_line(pos + Vector2(0, -sc * 0.15), pos + Vector2(0, sc * 0.45), col, 3.0)
		draw_line(pos + Vector2(-sc * 0.6, sc * 0.15), pos + Vector2(sc * 0.6, sc * 0.15), col, 2.5)
		draw_line(pos + Vector2(0, sc * 0.45), pos + Vector2(0, sc * 0.9), col, 2.5)
		draw_circle(pos + Vector2(0, sc * 0.9), 2.5, col)
		return

	if id.ends_with("_spd"):
		# Lightning bolt
		draw_polyline(PackedVector2Array([
			pos + Vector2(sc * 0.3,  -sc),
			pos + Vector2(-sc * 0.1, -sc * 0.05),
			pos + Vector2(sc * 0.45, -sc * 0.05),
			pos + Vector2(-sc * 0.3,  sc),
		]), col, 3.5)
		return

	if id.ends_with("_special"):
		# 5-pointed star
		_draw_star(pos, sc * 1.1, sc * 0.45, 5, col)
		return

	# Intro nodes — turret-specific icon
	var tid := id.replace("_intro", "")
	_draw_turret_icon(pos, tid, col, sc)


func _draw_turret_icon(pos: Vector2, tid: String, col: Color, sc: float) -> void:
	match tid:
		"archer":
			# Bow arc + arrow
			draw_arc(pos + Vector2(-sc * 0.2, 0), sc * 0.9, -PI * 0.55, PI * 0.55, 20, col, 3.0)
			draw_line(pos + Vector2(-sc * 0.15, 0), pos + Vector2(sc * 0.85, 0), col, 2.5)
			draw_line(pos + Vector2(sc * 0.85, 0), pos + Vector2(sc * 0.55, -sc * 0.32), col, 2.5)
			draw_line(pos + Vector2(sc * 0.85, 0), pos + Vector2(sc * 0.55, sc * 0.32),  col, 2.5)
		"crossbow":
			# Stock (horizontal) + limbs (vertical) + bolt
			draw_line(pos + Vector2(-sc, 0),        pos + Vector2(sc, 0),         col, 4.0)
			draw_line(pos + Vector2(-sc * 0.15, -sc * 0.6), pos + Vector2(-sc * 0.15, sc * 0.6), col, 3.5)
			draw_line(pos + Vector2(-sc * 0.15, 0), pos + Vector2(sc * 0.85, 0),  Color(1, 1, 1, 0.65), 1.8)
			draw_circle(pos + Vector2(sc * 0.85, 0), 3.0, col)
		"mage":
			# Magic wand: diagonal handle + 4-point sparkle at tip
			var tip  := pos + Vector2(sc * 0.55, -sc * 0.85)
			var base := pos + Vector2(-sc * 0.55, sc * 0.85)
			draw_line(base, tip, col, 3.0)
			draw_circle(tip, 2.5, col)
			var sr := sc * 0.38
			draw_line(tip + Vector2(-sr, 0),   tip + Vector2(sr, 0),   col, 1.8)
			draw_line(tip + Vector2(0, -sr),   tip + Vector2(0, sr),   col, 1.8)
			draw_line(tip + Vector2(-sr * 0.7, -sr * 0.7), tip + Vector2(sr * 0.7, sr * 0.7), col, 1.2)
			draw_line(tip + Vector2(sr * 0.7, -sr * 0.7),  tip + Vector2(-sr * 0.7, sr * 0.7), col, 1.2)
		"catapult":
			# Boulder (circle) + launch arm + base
			draw_circle(pos + Vector2(sc * 0.25, -sc * 0.6), sc * 0.52, col)
			draw_line(pos + Vector2(-sc * 0.45, sc * 0.5), pos + Vector2(sc * 0.55, sc * 0.5), col, 3.5)
			draw_line(pos + Vector2(-sc * 0.1, sc * 0.5), pos + Vector2(sc * 0.25, -sc * 0.2), col, 3.0)
		"spearman":
			# Spearhead triangle + handle
			draw_colored_polygon(PackedVector2Array([
				pos + Vector2(0,          -sc),
				pos + Vector2(sc * 0.45,   sc * 0.1),
				pos + Vector2(0,          -sc * 0.15),
				pos + Vector2(-sc * 0.45,  sc * 0.1),
			]), col)
			draw_line(pos + Vector2(0, -sc * 0.15), pos + Vector2(0, sc), col, 2.8)
		"rogue":
			# Dagger: blade + guard + wrapped handle
			draw_colored_polygon(PackedVector2Array([
				pos + Vector2(0,           -sc),
				pos + Vector2(sc * 0.22,  -sc * 0.05),
				pos + Vector2(0,           sc * 0.45),
				pos + Vector2(-sc * 0.22, -sc * 0.05),
			]), col)
			draw_line(pos + Vector2(-sc * 0.45, sc * 0.2), pos + Vector2(sc * 0.45, sc * 0.2), col, 2.2)
			draw_line(pos + Vector2(0, sc * 0.45), pos + Vector2(0, sc * 0.9), col, 2.5)
			draw_line(pos + Vector2(-sc * 0.22, sc * 0.65), pos + Vector2(sc * 0.22, sc * 0.65), col, 1.8)


func _draw_star(center: Vector2, outer_r: float, inner_r: float, pts: int, col: Color) -> void:
	var verts := PackedVector2Array()
	for i in range(pts * 2):
		var a := (i * PI / pts) - PI * 0.5
		var r := outer_r if i % 2 == 0 else inner_r
		verts.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(verts, col)


func _draw_lock(pos: Vector2) -> void:
	var c := Color(0.45, 0.45, 0.52)
	draw_rect(Rect2(pos + Vector2(-8, -3), Vector2(16, 13)), c)
	draw_arc(pos + Vector2(0, -3), 8, PI, TAU, 20, c, 3.5)


func _draw_label(pos: Vector2, text: String, font_size: int, col: Color) -> void:
	if not _font_bold: return
	var tf := Transform2D(0, pos - Vector2(30, font_size * 0.5))
	draw_set_transform_matrix(tf)
	draw_string(_font_bold, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_CENTER, 60, font_size, col)
	draw_set_transform_matrix(Transform2D.IDENTITY)


# ── Input ──────────────────────────────────────────────────────────────────────
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_start = mb.position
				_dragging   = true
				_drag_moved = false
			else:
				_dragging = false
				if not _drag_moved:
					_on_click(mb.position)
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		if mm.relative.length() > 3.0:
			_drag_moved = true
		_canvas_off += mm.relative
		_canvas_off.x = clamp(_canvas_off.x, -950, 950)
		_canvas_off.y = clamp(_canvas_off.y, -750, 750)
		queue_redraw()


func _on_click(screen_pos: Vector2) -> void:
	var wp := _to_world(screen_pos)
	for nd in _nodes:
		var r := CENTER_R if nd["id"] == "core" else (SPECIAL_R if nd["id"].ends_with("_special") else NODE_R)
		if wp.distance_to(nd["world_pos"]) <= r:
			_active_id = nd["id"]
			_open_popup(nd)
			queue_redraw()
			return
	_active_id = ""
	_close_popup()
	queue_redraw()


# ── Popup ──────────────────────────────────────────────────────────────────────
func _open_popup(nd: Dictionary) -> void:
	_close_popup()

	var col   : Color = nd["color"]
	var t     := _tiers(nd)
	var mt    : int = nd["max_tiers"]
	var done  := t >= mt
	var avail := _available(nd)
	var locked := not done and not avail
	var cost  := _next_cost(nd)

	var panel := Panel.new()
	panel.size         = Vector2(340, 190)
	panel.position     = Vector2(640 - 170, 720 - 208)
	panel.z_index      = 20
	panel.mouse_filter = MOUSE_FILTER_STOP
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.07, 0.07, 0.13, 0.98)
	ps.corner_radius_top_left = 10; ps.corner_radius_top_right = 10
	ps.corner_radius_bottom_left = 10; ps.corner_radius_bottom_right = 10
	ps.border_width_left = 2; ps.border_width_right = 2
	ps.border_width_top  = 2; ps.border_width_bottom = 2
	ps.border_color = col
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)
	_popup = panel

	# Color accent header bar
	var bar := ColorRect.new()
	bar.color    = Color(col.r, col.g, col.b, 0.22)
	bar.position = Vector2(0, 0); bar.size = Vector2(340, 40)
	panel.add_child(bar)

	# Title: name + tier progress
	var tier_str : String
	if mt == 1:
		tier_str = "  —  " + ("Purchased" if done else "Not purchased")
	else:
		tier_str = "  —  %d / %d" % [t, mt]
	var title := Label.new()
	title.text     = nd["label"] + tier_str
	title.position = Vector2(12, 7); title.size = Vector2(316, 28)
	title.add_theme_font_override("font", _font_bold)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", col.lightened(0.35))
	panel.add_child(title)

	# Description
	var desc := Label.new()
	desc.text          = nd["desc"]
	desc.position      = Vector2(12, 48); desc.size = Vector2(316, 88)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_override("font", _font_reg)
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	panel.add_child(desc)

	# Upgrade button
	var btn := Button.new()
	btn.position   = Vector2(12, 150); btn.size = Vector2(316, 34)
	btn.focus_mode = FOCUS_NONE
	btn.add_theme_font_override("font", _font_bold)
	btn.add_theme_font_size_override("font_size", 14)

	var bs := StyleBoxFlat.new()
	bs.corner_radius_top_left = 6; bs.corner_radius_top_right = 6
	bs.corner_radius_bottom_left = 6; bs.corner_radius_bottom_right = 6

	if done:
		btn.text = "✅  Maxed"
		btn.disabled = true
		bs.bg_color = Color(0.18, 0.32, 0.18)
	elif locked:
		btn.text = "🔒  Locked — complete prerequisites first"
		btn.disabled = true
		bs.bg_color = Color(0.20, 0.20, 0.26)
	elif GameData.blue_gems < cost:
		btn.disabled = true
		bs.bg_color = Color(0.35, 0.14, 0.14)
		_add_gem_content_to_btn(btn, "Need ", " %d  (you have %d)" % [cost, GameData.blue_gems], 16.0)
		btn.add_theme_color_override("font_color_disabled", Color(0.80, 0.60, 0.60))
	else:
		btn.disabled = false
		bs.bg_color = Color(0.18, 0.38, 0.60)
		_add_gem_content_to_btn(btn, "⬆  Upgrade  — ", " %d gems" % cost, 16.0)
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
		btn.pressed.connect(func():
			if GameData.try_buy_upgrade(nd["id"], nd["max_tiers"], cost):
				if is_instance_valid(_gem_lbl):
					_gem_lbl.text = "%d gems" % GameData.blue_gems
				queue_redraw()
				_open_popup(nd)
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


func _get_active_node() -> Dictionary:
	for nd in _nodes:
		if nd["id"] == _active_id:
			return nd
	return {}


func _close_popup() -> void:
	if is_instance_valid(_popup):
		_popup.queue_free()
		_popup = null


func _load_blue_gem_tex() -> Texture2D:
	var p := "res://assets/blue_gem.svg"
	if ResourceLoader.exists(p):
		return load(p) as Texture2D
	return null


func _mk_blue_gem_icon(sz: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(sz, sz)
	tr.size         = Vector2(sz, sz)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tr.mouse_filter = MOUSE_FILTER_IGNORE
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
	var lbl := Label.new()
	lbl.text = left_text
	lbl.add_theme_font_override("font", _font_bold)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.mouse_filter = MOUSE_FILTER_IGNORE
	hbox.add_child(lbl)
	hbox.add_child(_mk_blue_gem_icon(sz))
	var r_lbl := Label.new()
	r_lbl.text = right_text
	r_lbl.add_theme_font_override("font", _font_bold)
	r_lbl.add_theme_font_size_override("font_size", 14)
	r_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	hbox.add_child(r_lbl)
	btn.add_child(hbox)
