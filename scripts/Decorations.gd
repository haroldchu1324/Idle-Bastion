extends Node2D
# Decorative layer: trees, rocks, flowers.
# All coordinates are for 1280×720. Road geometry matches MapRenderer.gd.

const C_TREE_DARK := Color(0.13, 0.38, 0.07)
const C_TREE_MID  := Color(0.22, 0.52, 0.13)
const C_TREE_LITE := Color(0.34, 0.65, 0.22)
const C_ROCK_MID  := Color(0.50, 0.48, 0.42)
const C_ROCK_LITE := Color(0.66, 0.63, 0.56)
const C_ROCK_DARK := Color(0.36, 0.34, 0.29)


func _draw() -> void:
	if GameData.selected_world != 1:
		return
	_draw_grass_patches()
	_draw_trees()
	_draw_rocks()
	_draw_flowers()


# ── Subtle grass texture patches ──────────────────────────────────────────────
func _draw_grass_patches() -> void:
	# Slightly lighter oval patches scattered in outer margins and inside island
	var lighter := Color(0.32, 0.65, 0.20, 0.30)
	var darker  := Color(0.18, 0.44, 0.10, 0.22)
	# Outer top strip
	for patch in [[100,35,60,18,lighter],[400,28,70,16,lighter],[750,40,55,14,darker],
	              [1050,30,65,18,lighter],[1200,38,50,15,darker]]:
		draw_ellipse_patch(patch)
	# Outer bottom strip (y 540-650)
	for patch in [[180,600,65,18,lighter],[500,590,70,16,darker],[820,605,60,18,lighter],
	              [1080,595,55,15,darker]]:
		draw_ellipse_patch(patch)
	# Left strip
	for patch in [[65,200,40,60,lighter],[55,380,35,55,darker],[70,490,42,50,lighter]]:
		draw_ellipse_patch(patch)
	# Right strip
	for patch in [[1215,200,40,60,lighter],[1225,380,35,55,darker],[1210,490,42,50,lighter]]:
		draw_ellipse_patch(patch)
	# Island interior variation
	for patch in [[400,260,80,40,lighter],[700,200,70,35,darker],[900,320,75,38,lighter],
	              [550,380,65,32,darker],[800,280,60,30,lighter]]:
		draw_ellipse_patch(patch)


func draw_ellipse_patch(p: Array) -> void:
	# p = [cx, cy, rx, ry, color]
	var pts := PackedVector2Array()
	var steps : int = 24
	for i in range(steps):
		var a : float = TAU * i / steps
		pts.append(Vector2(p[0] + cos(a) * p[2], p[1] + sin(a) * p[3]))
	draw_colored_polygon(pts, p[4] as Color)


# ── Trees ─────────────────────────────────────────────────────────────────────
func _draw_trees() -> void:
	# [x, y, radius] — placed outside the road rectangle
	var positions : Array = [
		# Top margin (y 0–60)
		[58,  38, 22], [200, 28, 18], [360, 44, 24], [550, 25, 20],
		[720, 40, 22], [900, 26, 18], [1070, 42, 20], [1225, 32, 18],

		# Bottom margin (y 540–650, above HUD)
		[90,  600, 20], [270, 588, 18], [470, 604, 22], [660, 592, 18],
		[850, 602, 20], [1040, 590, 20], [1200, 600, 18],

		# Left margin (x 0–130, between top & bottom road)
		[62,  210, 22], [55,  360, 20], [68,  470, 18],

		# Right margin (x 1150–1280, between top & bottom road)
		[1218, 210, 22], [1228, 360, 20], [1212, 470, 18],
	]

	for t in positions:
		var pos : Vector2 = Vector2(float(t[0]), float(t[1]))
		var r   : float   = float(t[2])
		# Shadow
		draw_circle(pos + Vector2(3, 4), r * 0.90, Color(0, 0, 0, 0.18))
		# Trunk
		draw_rect(Rect2(pos.x - 3, pos.y + r * 0.4, 6, r * 0.5), Color(0.35, 0.22, 0.08))
		# Foliage — 3 layered circles for roundness
		draw_circle(pos,                               r,        C_TREE_DARK)
		draw_circle(pos,                               r * 0.70, C_TREE_MID)
		draw_circle(pos + Vector2(-r*0.18, -r*0.20),  r * 0.32, C_TREE_LITE)


# ── Rocks ─────────────────────────────────────────────────────────────────────
func _draw_rocks() -> void:
	# Only in the outer grass margins — never on or touching the road.
	# Road occupies x=130-1150, y=60-540 (+ entry x=0-190, y=60-120).
	var rocks : Array = [
		[90,  44],  [115, 30],    # top margin (y < 60)
		[980, 38],  [1060, 22],
		[90,  570], [115, 584],   # bottom margin (y > 540)
		[960, 558], [1060, 572],
		[60,  280], [50,  430],   # left margin (x < 130, y 120-540)
		[1195, 280],[1200, 430],  # right margin (x > 1150, y 120-540)
	]
	for rk in rocks:
		var p : Vector2 = Vector2(float(rk[0]), float(rk[1]))
		draw_circle(p + Vector2(2, 3),        10.0, Color(0, 0, 0, 0.18))
		draw_circle(p,                         11.0, C_ROCK_MID)
		draw_circle(p + Vector2( 3, -3),        7.0, C_ROCK_LITE)
		draw_circle(p + Vector2(-2,  4),        5.0, C_ROCK_DARK)


# ── Flowers ───────────────────────────────────────────────────────────────────
func _draw_flowers() -> void:
	var yellow := Color(1.0, 0.92, 0.20)
	var white  := Color(1.0, 1.00, 1.00)
	var pink   := Color(1.0, 0.70, 0.80)
	var flowers : Array = [
		# Top margin (y < 55, clear of road at y=60)
		[80,  44, yellow], [310, 32, white], [600, 46, pink],
		[900, 28, yellow], [1180,42, white],
		# Bottom margin (y > 548, clear of road at y=540)
		[80,  560, white],  [340, 550, yellow], [640, 562, pink],
		[940, 552, white],  [1180,558, yellow],
		# Left margin (x < 115, clear of road/entry)
		[80, 240, pink],  [72, 430, yellow],
		# Right margin (x > 1160)
		[1192, 240, yellow], [1196, 420, white],
	]
	for fl in flowers:
		var p : Vector2 = Vector2(float(fl[0]), float(fl[1]))
		var c : Color   = fl[2] as Color
		# 4 petals
		for i in range(4):
			var angle : float = TAU * i / 4.0
			draw_circle(p + Vector2(cos(angle), sin(angle)) * 4.5, 3.5, c)
		# Centre
		draw_circle(p, 2.5, Color(1.0, 0.85, 0.10))



