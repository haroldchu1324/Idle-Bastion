extends Node2D
# Per-world battlefield road renderer.
# World 1 uses the original polygon road ring. Worlds 2-10 use a themed
# thick-polyline road following the same waypoints as the enemy PATH.

const FLOORS_TEX       := preload("res://assets/Pixel Crawler - Free Pack/Environment/Tilesets/Floors_Tiles.png")
const TREES_TEX        := preload("res://assets/Harvest Sumer Free Ver. Pack/Vegetation/Trees 3.png")
const ROCKS_TEX        := preload("res://assets/Pixel Crawler - Free Pack/Environment/Props/Static/Rocks.png")
const HARVEST_TILES_TEX := preload("res://assets/Harvest Sumer Free Ver. Pack/tilesets/Set 1.0.png")

var _road_atlas:      AtlasTexture    = null
var _grass_atlas:     AtlasTexture    = null
var _grass_tile_map:  PackedByteArray = PackedByteArray()
var _road_tiles:      Array           = []   # [[tx, ty, src_idx], ...]

func _ready() -> void:
	_road_atlas = AtlasTexture.new()
	_road_atlas.atlas  = FLOORS_TEX
	_road_atlas.region = Rect2(160, 0, 80, 80)
	_grass_atlas = AtlasTexture.new()
	_grass_atlas.atlas  = FLOORS_TEX
	_grass_atlas.region = Rect2(0, 0, 80, 80)
	# Precompute dirt tile grid for road — check each tile center against road polygon
	var road_poly := _road_outer_poly()
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 54321
	var pool2 : Array[int] = [0, 0, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3]
	for ty in range(110, 531, 16):
		for tx in range(0, 881, 16):
			# Inset corners 1px: straight edges always pass, rounded arc corners get excluded.
			var inside := true
			for ox in [1, 15]:
				for oy in [1, 15]:
					if not Geometry2D.is_point_in_polygon(Vector2(tx + ox, ty + oy), road_poly):
						inside = false
			if inside:
				_road_tiles.append([tx, ty, pool2[rng2.randi_range(0, pool2.size() - 1)]])
	# Pre-compute mixed grass tile map (80×45 = 3600 tiles) with fixed seed.
	# Weighted pool: r1c11~8%, r1c12~2%, r2c11~45%, r2c12~45%
	var pool : Array[int] = [0, 0, 1, 2,2,2,2,2,2,2,2,2, 3,3,3,3,3,3,3,3,3,3]
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	_grass_tile_map.resize(80 * 45)
	for i in range(80 * 45):
		_grass_tile_map[i] = pool[rng.randi_range(0, pool.size() - 1)]

# ── Colors — World 1 (kept exactly as before) ────────────────────────────────
const C_ROAD    := Color(0.99, 0.59, 0.23)
const C_SHADOW  := Color(0.00, 0.00, 0.00, 0.22)
const C_ISLAND  := Color(0.30, 0.62, 0.18)

# ── Road geometry (World 1 polygon approach) ──────────────────────────────────
const ROAD_W  : int   = 60
const R_LEFT  : float = 220.0
const R_RIGHT : float = 880.0
const R_TOP   : float = 110.0
const R_BOT   : float = 530.0

const I_LEFT  : float = 280.0
const I_RIGHT : float = 820.0
const I_TOP   : float = 170.0
const I_BOT   : float = 470.0

const ISLAND    := Rect2(280, 170, 540, 300)
const TILE_SIZE : int  = 60

const OUTER_R  : float = 20.0
const INNER_R  : float = 10.0
const STEPS    : int   = 12

const CY_TOP   : float = R_TOP   + ROAD_W * 0.5
const CY_BOT   : float = I_BOT   + ROAD_W * 0.5
const CX_LEFT  : float = R_LEFT  + ROAD_W * 0.5
const CX_RIGHT : float = I_RIGHT + ROAD_W * 0.5

# ── Per-world themed road colors ──────────────────────────────────────────────
const WORLD_ROAD_COLORS : Array = [
	Color(0.60, 0.42, 0.18),   # W1  Garden Plains — warm dirt brown (kept)
	Color(0.22, 0.16, 0.08),   # W2  Deep Forest — dark earthy trail
	Color(0.74, 0.62, 0.32),   # W3  Desert Ruins — sandy stone
	Color(0.65, 0.75, 0.85),   # W4  Frost Peaks — icy pale stone
	Color(0.28, 0.18, 0.14),   # W5  Volcanic Wastes — scorched dark rock
	Color(0.24, 0.20, 0.10),   # W6  Swamplands — murky mud
	Color(0.35, 0.22, 0.52),   # W7  Crystal Highlands — purple-tinted stone
	Color(0.10, 0.06, 0.22),   # W8  Shadow Realm — near-black void stone
	Color(0.82, 0.75, 0.48),   # W9  Celestial Kingdom — golden marble
	Color(0.72, 0.74, 0.82),   # W10 Eternal Citadel — silver marble
]

const WORLD_BORDER_COLORS : Array = [
	Color(0.38, 0.26, 0.10),   # W1
	Color(0.08, 0.10, 0.04),   # W2
	Color(0.52, 0.42, 0.18),   # W3
	Color(0.45, 0.58, 0.72),   # W4
	Color(0.55, 0.15, 0.05),   # W5
	Color(0.12, 0.14, 0.06),   # W6
	Color(0.22, 0.10, 0.38),   # W7
	Color(0.35, 0.20, 0.55),   # W8
	Color(0.60, 0.52, 0.22),   # W9
	Color(0.52, 0.55, 0.65),   # W10
]

const WORLD_ISLAND_COLORS : Array = [
	Color(0.30, 0.62, 0.18),   # W1  lush grass
	Color(0.10, 0.30, 0.06),   # W2  dark forest floor
	Color(0.58, 0.48, 0.22),   # W3  desert sand
	Color(0.72, 0.82, 0.90),   # W4  frost-dusted stone
	Color(0.18, 0.12, 0.08),   # W5  scorched earth
	Color(0.14, 0.26, 0.10),   # W6  swamp mud
	Color(0.24, 0.14, 0.38),   # W7  crystal plateau
	Color(0.05, 0.03, 0.12),   # W8  void plane
	Color(0.75, 0.68, 0.40),   # W9  golden cloud platform
	Color(0.60, 0.62, 0.72),   # W10 marble floor
]

# Sky/background colours per world (fills the whole viewport before road)
const WORLD_SKY_COLORS : Array = [
	Color(0.42, 0.72, 0.28),   # W1
	Color(0.08, 0.20, 0.05),   # W2  dark green forest
	Color(0.80, 0.70, 0.40),   # W3  sandy desert
	Color(0.78, 0.88, 0.96),   # W4  snowy sky
	Color(0.12, 0.08, 0.06),   # W5  volcanic dark
	Color(0.16, 0.22, 0.08),   # W6  swamp green
	Color(0.20, 0.12, 0.32),   # W7  purple highland
	Color(0.04, 0.02, 0.10),   # W8  void black
	Color(0.88, 0.84, 0.60),   # W9  golden heaven
	Color(0.68, 0.70, 0.80),   # W10 silver citadel
]


func _draw() -> void:
	var world : int = clamp(GameData.selected_world, 1, 10)
	if world == 1:
		_draw_world1()
	else:
		_draw_world_n(world)


# ── World 1 — original polygon road ring ─────────────────────────────────────
func _draw_world1() -> void:
	_draw_grass_bg()
	_draw_w1_trees()

	var road   := _road_outer_poly()
	var island := _island_poly(ISLAND)

	var shadow := road.duplicate()
	for i in range(shadow.size()):
		shadow[i] += Vector2(5, 7)
	draw_colored_polygon(shadow, C_SHADOW)

	# Solid base gives rounded corners; tiles drawn on top fill the interior
	draw_colored_polygon(road, C_ROAD)

	# Draw dirt tiles inside road polygon — precomputed in _ready()
	var dirt_srcs := [
		Rect2(16, 16, 16, 16),
		Rect2(32, 16, 16, 16),
		Rect2(16, 32, 16, 16),
		Rect2(32, 32, 16, 16),
	]
	for t in _road_tiles:
		draw_texture_rect_region(HARVEST_TILES_TEX,
			Rect2(t[0], t[1], 16, 16), dirt_srcs[t[2]])

	# Island — solid green base + tiled grass texture overlay
	draw_colored_polygon(island, C_ISLAND)
	var grass_colors := PackedColorArray()
	var grass_uvs    := PackedVector2Array()
	for pt in island:
		grass_colors.append(Color(1.0, 1.0, 1.0, 0.30))
		grass_uvs.append(Vector2(pt.x / 80.0, pt.y / 80.0))
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	draw_polygon(island, grass_colors, grass_uvs, _grass_atlas)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED


func _draw_grass_bg() -> void:
	# Tile the background with 4 mixed Harvest Sumer grass tiles (16×16 each).
	# 1280÷16=80 cols, 720÷16=45 rows. Pattern pre-seeded in _ready().
	var srcs := [
		Rect2(176, 16, 16, 16),  # r1c11 — blobs
		Rect2(192, 16, 16, 16),  # r1c12 — blobs variant
		Rect2(176, 32, 16, 16),  # r2c11 — grass tufts
		Rect2(192, 32, 16, 16),  # r2c12 — grass tufts variant
	]
	for row in range(45):
		for col in range(80):
			draw_texture_rect_region(HARVEST_TILES_TEX,
				Rect2(col * 16, row * 16, 16, 16),
				srcs[_grass_tile_map[row * 80 + col]])


func _draw_grass_bg_dark() -> void:
	# Same tile layout/weights as World 1 but using dark green variants.
	var srcs := [
		Rect2(176, 144, 16, 16),  # dark blob A
		Rect2(192, 144, 16, 16),  # dark blob B
		Rect2(176, 160, 16, 16),  # dark tuft A
		Rect2(192, 160, 16, 16),  # dark tuft B
	]
	for row in range(45):
		for col in range(80):
			draw_texture_rect_region(HARVEST_TILES_TEX,
				Rect2(col * 16, row * 16, 16, 16),
				srcs[_grass_tile_map[row * 80 + col]])


func _draw_w1_trees() -> void:
	# Asset regions from Trees 3.png (160×80, 16×16 grid):
	#   T0  Rect2(  0, 0,48,54) sz(55,62)  T1  Rect2( 48, 0,48,54) sz(55,62)
	#   T2a Rect2( 96, 0,32,64) sz(38,76)  T2b Rect2(128, 0,32,64) sz(38,76)
	#   S0  Rect2(  0,54,48,26) sz(55,30)  S1  Rect2( 48,54,48,26) sz(55,30)
	#   S2  Rect2( 96,64,32,16) sz(38,19)  S3  Rect2(128,64,32,16) sz(38,19)
	#
	# Road: R_TOP=110 R_BOT=530 R_LEFT=220 R_RIGHT=880 entry y=110-170 x=0-220
	# Safe (half-extent + 10px buffer):
	#   T0/T1 half(27,31): TOP cy≤69 BOT cy≥571 LEFT cx≤182,cy≥211 RIGHT cx≥918
	#   T2a/b half(19,38): TOP cy≤62 BOT cy≥578 LEFT cx≤191,cy≥218 RIGHT cx≥909
	#   S0/S1 half(27,15): TOP cy≤85 BOT cy≥555 LEFT cx≤182,cy≥195 RIGHT cx≥918
	#   S2/S3 half(19, 9): TOP cy≤90 BOT cy≥549                     RIGHT cx≥909
	var T0  := Rect2(  0, 0, 48, 54); var SZ0  := Vector2(55, 62)
	var T1  := Rect2( 48, 0, 48, 54); var SZ1  := Vector2(55, 62)
	var T2a := Rect2( 96, 0, 32, 64); var SZ2a := Vector2(38, 76)
	var T2b := Rect2(128, 0, 32, 64); var SZ2b := Vector2(38, 76)
	var S0  := Rect2(  0,54, 48, 26); var SS0  := Vector2(55, 30)
	var S1  := Rect2( 48,54, 48, 26); var SS1  := Vector2(55, 30)
	var S2  := Rect2( 96,64, 32, 16); var SS2  := Vector2(38, 19)
	var S3  := Rect2(128,64, 32, 16); var SS3  := Vector2(38, 19)

	# [cx, cy, src, sz]
	# T0×6  T1×6  T2a×6  T2b×6  |  S0×2  S1×2  S2×2  S3×2
	var sprites := [
		# ── TOP strip — round cy=65, tall cy=58, stumps cy=88 ──────────────
		[ 80,  65, T0,  SZ0 ],   # T0 #1
		[280,  58, T2a, SZ2a],   # T2a #1
		[480,  65, T1,  SZ1 ],   # T1 #1
		[680,  58, T2b, SZ2b],   # T2b #1
		[890,  65, T0,  SZ0 ],   # T0 #2
		[1080, 58, T2a, SZ2a],   # T2a #2
		[200,  88, S0,  SS0 ],   # S0 #1
		[780,  88, S1,  SS1 ],   # S1 #1

		# ── BOTTOM strip — round cy=575, tall cy=582, stumps cy=600 ────────
		[120,  575, T1,  SZ1 ],  # T1 #2
		[320,  582, T2b, SZ2b],  # T2b #2
		[520,  575, T0,  SZ0 ],  # T0 #3
		[720,  582, T2a, SZ2a],  # T2a #3
		[920,  575, T1,  SZ1 ],  # T1 #3
		[1100, 582, T2b, SZ2b],  # T2b #3
		[450,  600, S0,  SS0 ],  # S0 #2
		[660,  598, S2,  SS2 ],  # S2 #1
		[1050, 596, S3,  SS3 ],  # S3 #1

		# ── LEFT strip — cx≤182, round cy≥211, tall cy≥218 ─────────────────
		[90,  250, T0,  SZ0 ],   # T0 #4
		[75,  380, T1,  SZ1 ],   # T1 #4
		[92,  480, T2b, SZ2b],   # T2b #4
		[65,  320, S1,  SS1 ],   # S1 #2

		# ── RIGHT strip — round cx≥918, tall cx≥909; no road at x>880 ──────
		# Row 1 (cy=200)
		[935,  200, T0,  SZ0 ],  # T0 #5
		[1090, 200, T2a, SZ2a],  # T2a #4
		[1240, 200, T1,  SZ1 ],  # T1 #5
		# Row 2 (cy=340)
		[918,  340, T2b, SZ2b],  # T2b #5
		[1090, 340, T2a, SZ2a],  # T2a #5
		[1240, 340, T0,  SZ0 ],  # T0 #6
		# Row 3 (cy=480)
		[935,  480, T1,  SZ1 ],  # T1 #6
		[1090, 480, T2a, SZ2a],  # T2a #6
		[1240, 480, T2b, SZ2b],  # T2b #6
		[960,  270, S2,  SS2 ],  # S2 #2
		[1120, 415, S3,  SS3 ],  # S3 #2
	]
	for s in sprites:
		var src : Rect2   = s[2]
		var sz  : Vector2 = s[3]
		draw_texture_rect_region(TREES_TEX,
			Rect2(s[0] - sz.x * 0.5, s[1] - sz.y * 0.5, sz.x, sz.y), src)


# ── Worlds 2-10 — outer margin sprite decorations ────────────────────────────
# Sprites drawn at 40×50 (trees) or 30×38 (rocks) centered on (cx,cy).
# Positions are safe: every sprite bbox stays ≥30 px from the nearest road segment.
#
# Trees 3.png src rects (y=0-77):
#   T0 bright-green x=1-47 | T1 teal x=49-95 | T2 dark x=98-156
# Rocks.png src rects (y=19-61):
#   RA x=2-29 (28px)       | RB x=35-62 (28px)
func _draw_world_outer(world: int) -> void:
	var t_sz := Vector2(40, 50)
	var r_sz := Vector2(30, 38)
	var T0 := Rect2(1,0,47,77);  var T1 := Rect2(49,0,47,77); var T2 := Rect2(98,0,59,77)
	var RA := Rect2(2,19,28,43); var RB := Rect2(35,19,28,43)
	match world:
		2:  # Deep Forest — Tree B (T1)×8, Tree D (T2b)×8, stumps S1+S3×5
			var T1_r  := Rect2( 48,  0, 48, 54); var SZ_T1  := Vector2(55, 62)
			var T2b_r := Rect2(128,  0, 32, 64); var SZ_T2b := Vector2(38, 76)
			var S1_r  := Rect2( 48, 54, 48, 26); var SS1    := Vector2(55, 30)
			var S3_r  := Rect2(128, 64, 32, 16); var SS3    := Vector2(38, 19)
			var w2_sprites := [
				# T1 (Tree B wide) ×8 — TOP×3, LEFT×1, RIGHT col-A×2 col-B×2
				[  80,  55, T1_r,  SZ_T1], [ 380,  55, T1_r,  SZ_T1], [ 660,  55, T1_r,  SZ_T1],
				[  44, 270, T1_r,  SZ_T1],
				[ 945, 170, T1_r,  SZ_T1], [ 945, 490, T1_r,  SZ_T1],
				[1100, 395, T1_r,  SZ_T1], [1100, 695, T1_r,  SZ_T1],
				# T2b (Tree D slim) ×8 — TOP×3, LEFT×1, RIGHT col-A×2 col-B×2
				[ 210,  55, T2b_r, SZ_T2b], [ 500,  55, T2b_r, SZ_T2b], [ 800,  55, T2b_r, SZ_T2b],
				[  46, 440, T2b_r, SZ_T2b],
				[ 945, 330, T2b_r, SZ_T2b], [ 945, 640, T2b_r, SZ_T2b],
				[1100, 245, T2b_r, SZ_T2b], [1100, 545, T2b_r, SZ_T2b],
				# S1/S3 stumps ×5 — TOP×2, LEFT×1, RIGHT×2 (placed in gaps between trees)
				[ 150,  88, S1_r,  SS1], [ 550,  88, S3_r,  SS3],
				[  48, 350, S1_r,  SS1],
				[ 952, 245, S3_r,  SS3], [ 968, 430, S1_r,  SS1],
			]
			for s in w2_sprites:
				var src2 : Rect2   = s[2]
				var sz2  : Vector2 = s[3]
				draw_texture_rect_region(TREES_TEX,
					Rect2(s[0] - sz2.x * 0.5, s[1] - sz2.y * 0.5, sz2.x, sz2.y), src2)
		3:  # Desert Ruins — warm sandy rocks; sparse trees; right cx>920
			var tc := Color(0.88, 0.80, 0.50);  var rc := Color(1.00, 0.82, 0.44)
			_ospr(TREES_TEX, [60,60, 230,60, 420,60, 600,60, 790,60, 1000,60, 1170,60, 1250,60], t_sz, T2, tc)
			_ospr(ROCKS_TEX, [945,195, 1080,238, 1215,198, 950,332, 1108,362, 1238,330, 945,462, 1080,480, 1215,458], r_sz, RA, rc)
			_ospr(ROCKS_TEX, [80,560, 260,560, 448,560, 630,560, 818,560, 1008,560, 1188,560], r_sz, RB, rc)
			_ospr(ROCKS_TEX, [80,660, 260,660, 448,660, 630,660, 818,660, 1008,660, 1188,660], r_sz, RA, rc)
		4:  # Frost Peaks — ice-blue trees + pale rocks; right cx>890
			var tc := Color(0.70, 0.88, 0.98);  var rc := Color(0.72, 0.82, 0.96)
			_ospr(TREES_TEX, [60,60, 230,60, 420,60, 600,60, 790,60, 960,60, 1130,60, 1250,60], t_sz, T0, tc)
			_ospr(TREES_TEX, [910,188, 1055,228, 1205,192, 915,322, 1070,362, 1225,326, 910,455, 1060,476, 1212,455], t_sz, T1, tc)
			_ospr(ROCKS_TEX, [80,660, 260,660, 448,660, 630,660, 818,660, 1000,660, 1188,660], r_sz, RA, rc)
		5:  # Volcanic Wastes — charred rocks; right cx>1040 (path x reaches 990)
			var rc := Color(0.60, 0.26, 0.16);  var tc := Color(0.50, 0.30, 0.20)
			_ospr(TREES_TEX, [60,60, 230,60, 420,60, 600,60, 800,60, 1070,60, 1200,60, 1255,60], t_sz, T2, tc)
			_ospr(ROCKS_TEX, [1060,202, 1178,242, 1255,202, 1065,338, 1185,370, 1255,335, 1060,462, 1180,480, 1255,458], r_sz, RA, rc)
			_ospr(ROCKS_TEX, [80,660, 260,660, 448,660, 625,660, 812,660, 1008,660, 1188,660], r_sz, RB, rc)
		6:  # Swamplands — murky olive trees; right cx>920 (diagonal path stays inside)
			var tc := Color(0.56, 0.74, 0.44);  var rc := Color(0.52, 0.60, 0.36)
			_ospr(TREES_TEX, [60,60, 230,60, 420,60, 600,60, 790,60, 1000,60, 1170,60, 1250,60], t_sz, T0, tc)
			_ospr(TREES_TEX, [945,195, 1072,238, 1212,198, 950,332, 1108,365, 1238,330, 945,462, 1082,480, 1215,458], t_sz, T1, tc)
			_ospr(ROCKS_TEX, [80,660, 260,660, 448,660, 630,660, 818,660, 1008,660, 1188,660], r_sz, RB, rc)
		7:  # Crystal Highlands — purple rocks; right cx>1040; skip cx≈510 in top strip
			var rc := Color(0.65, 0.38, 1.00);  var tc := Color(0.56, 0.36, 0.88)
			_ospr(TREES_TEX, [60,60, 218,60, 390,60, 638,60, 808,60, 978,60, 1130,60, 1252,60], t_sz, T2, tc)
			_ospr(ROCKS_TEX, [1060,202, 1178,245, 1255,208, 1065,340, 1185,372, 1255,340, 1060,462, 1180,480, 1255,458], r_sz, RA, rc)
			_ospr(ROCKS_TEX, [80,660, 260,660, 448,660, 630,660, 818,660, 1008,660, 1188,660], r_sz, RB, rc)
		8:  # Shadow Realm — near-void dark; right cx>830 (path max x=780)
			var tc := Color(0.30, 0.18, 0.45);  var rc := Color(0.28, 0.16, 0.40)
			_ospr(TREES_TEX, [60,60, 230,60, 420,60, 600,60, 790,60, 1000,60, 1170,60, 1250,60], t_sz, T1, tc)
			_ospr(TREES_TEX, [850,198, 988,240, 1148,205, 855,335, 1002,368, 1158,330, 850,462, 992,480, 1158,458], t_sz, T0, tc)
			_ospr(ROCKS_TEX, [80,660, 260,660, 448,660, 630,660, 818,660, 1008,660, 1188,660], r_sz, RA, rc)
		9:  # Celestial Kingdom — golden sheen; right cx>950 (path max x=900)
			var tc := Color(1.00, 0.92, 0.60);  var rc := Color(1.00, 0.86, 0.50)
			_ospr(TREES_TEX, [60,60, 230,60, 420,60, 600,60, 790,60, 1010,60, 1175,60, 1255,60], t_sz, T0, tc)
			_ospr(TREES_TEX, [972,198, 1108,238, 1238,202, 975,335, 1112,368, 1238,335, 972,462, 1108,480, 1238,458], t_sz, T1, tc)
			_ospr(ROCKS_TEX, [80,660, 260,660, 448,660, 630,660, 818,660, 1008,660, 1188,660], r_sz, RB, rc)
		10: # Eternal Citadel — silver marble rocks; right cx>1040; skip cx≈880 in top
			var rc := Color(0.76, 0.78, 0.92);  var tc := Color(0.70, 0.74, 0.88)
			_ospr(TREES_TEX, [60,60, 220,60, 400,60, 570,60, 740,60, 862,60, 1035,60, 1188,60, 1256,60], t_sz, T2, tc)
			_ospr(ROCKS_TEX, [1060,202, 1178,242, 1256,206, 1065,338, 1185,370, 1256,338, 1060,462, 1180,480, 1256,458], r_sz, RA, rc)
			_ospr(ROCKS_TEX, [80,660, 260,660, 448,660, 630,660, 818,660, 1008,660, 1188,660], r_sz, RB, rc)


# Helper: draw sprites at [cx,cy, cx,cy, ...] flat array, centered on each position.
func _ospr(tex: Texture2D, xy: Array, sz: Vector2, src: Rect2, tint: Color) -> void:
	var i := 0
	while i < xy.size() - 1:
		var cx : float = xy[i];  var cy : float = xy[i + 1]
		draw_texture_rect_region(tex, Rect2(cx - sz.x*0.5, cy - sz.y*0.5, sz.x, sz.y), src, tint)
		i += 2


# ── Worlds 2-10 — polyline road following world-specific path ─────────────────
func _draw_world_n(world: int) -> void:
	var w_idx    : int   = clamp(world - 1, 0, WORLD_ROAD_COLORS.size() - 1)
	var road_c   : Color = WORLD_ROAD_COLORS[w_idx]
	var border_c : Color = WORLD_BORDER_COLORS[w_idx]
	var island_c : Color = WORLD_ISLAND_COLORS[w_idx]
	var sky_c    : Color = WORLD_SKY_COLORS[w_idx]

	var wi     : Rect2 = GameData.get_world_island(world)
	var pts    := _path_to_pv2(GameData.get_world_path(world))

	# 0 — full-map background (terrain colour) — cover full viewport so no clear-color shows
	if world == 2:
		_draw_grass_bg_dark()
	else:
		draw_rect(Rect2(0, 0, 1280, 720), sky_c)

	# 0b — outer margin sprite decorations (trees/rocks) in safe zones outside the road
	_draw_world_outer(world)

	# 1 — island ground slab (tower placement area)
	if world != 2:
		draw_colored_polygon(_island_poly(wi), island_c)

	# 2 — biome decorations drawn on the ground, below the road
	_draw_world_decorations(world, wi)

	# 3 — road shadow
	var shadow_pts := PackedVector2Array()
	for p in pts:
		shadow_pts.append(p + Vector2(5, 7))
	draw_polyline(shadow_pts, Color(0, 0, 0, 0.35), float(ROAD_W) + 8.0, true)

	# 4 — road border (slightly wider, darker)
	draw_polyline(pts, border_c, float(ROAD_W) + 8.0, true)

	# 5 — road surface
	draw_polyline(pts, road_c, float(ROAD_W), true)

	# 6 — bright centre stripe
	draw_polyline(pts, Color(road_c.r + 0.12, road_c.g + 0.08, road_c.b + 0.06, 0.35),
		float(ROAD_W) * 0.28, true)

	# 7 — themed road edge glow
	_draw_world_edge_details(world, pts)



func _draw_world_edge_details(world: int, pts: PackedVector2Array) -> void:
	match world:
		2:  draw_polyline(pts, Color(0.08, 0.35, 0.05, 0.22), float(ROAD_W) + 12.0, true)
		3:  draw_polyline(pts, Color(0.88, 0.72, 0.35, 0.18), float(ROAD_W) + 14.0, true)
		4:  draw_polyline(pts, Color(0.55, 0.80, 1.00, 0.20), float(ROAD_W) + 14.0, true)
		5:  draw_polyline(pts, Color(1.00, 0.40, 0.05, 0.22), float(ROAD_W) + 14.0, true)
		6:  draw_polyline(pts, Color(0.20, 0.48, 0.10, 0.20), float(ROAD_W) + 14.0, true)
		7:  draw_polyline(pts, Color(0.68, 0.22, 0.95, 0.25), float(ROAD_W) + 14.0, true)
		8:  draw_polyline(pts, Color(0.45, 0.10, 0.80, 0.28), float(ROAD_W) + 16.0, true)
		9:  draw_polyline(pts, Color(1.00, 0.90, 0.40, 0.22), float(ROAD_W) + 14.0, true)
		10: draw_polyline(pts, Color(0.90, 0.92, 1.00, 0.25), float(ROAD_W) + 14.0, true)


# ── Per-world biome decorations ───────────────────────────────────────────────
func _draw_world_decorations(world: int, wi: Rect2) -> void:
	match world:
		2:  _deco_deep_forest(wi)
		3:  _deco_desert_ruins(wi)
		4:  _deco_frost_peaks(wi)
		5:  _deco_volcanic_wastes(wi)
		6:  _deco_swamplands(wi)
		7:  _deco_crystal_highlands(wi)
		8:  _deco_shadow_realm(wi)
		9:  _deco_celestial_kingdom(wi)


func _deco_deep_forest(wi: Rect2) -> void:
	var dark_green  := Color(0.05, 0.22, 0.03, 0.90)
	var mid_green   := Color(0.10, 0.35, 0.06, 0.85)
	var stump       := Color(0.28, 0.18, 0.08, 0.90)
	var rock_col    := Color(0.20, 0.22, 0.14, 0.85)
	# Corner tree clusters
	_draw_tree_cluster(Vector2(wi.position.x + 40,  wi.position.y + 40),  5, 18.0, dark_green, mid_green)
	_draw_tree_cluster(Vector2(wi.end.x     - 40,  wi.position.y + 40),  5, 18.0, dark_green, mid_green)
	_draw_tree_cluster(Vector2(wi.position.x + 40,  wi.end.y     - 40),  4, 16.0, dark_green, mid_green)
	_draw_tree_cluster(Vector2(wi.end.x     - 40,  wi.end.y     - 40),  4, 16.0, dark_green, mid_green)
	# Mid-map tree clusters (safe areas between rails)
	_draw_tree_cluster(Vector2(wi.position.x + 200, wi.position.y + 180), 3, 14.0, dark_green, mid_green)
	_draw_tree_cluster(Vector2(wi.end.x     - 200, wi.position.y + 180), 3, 14.0, dark_green, mid_green)
	_draw_tree_cluster(Vector2(wi.position.x + 200, wi.end.y     - 180), 3, 14.0, dark_green, mid_green)
	_draw_tree_cluster(Vector2(wi.end.x     - 200, wi.end.y     - 180), 3, 14.0, dark_green, mid_green)
	# Stumps and rocks scattered near island edges
	for pos in [Vector2(wi.position.x + 120, wi.position.y + 260),
				Vector2(wi.end.x - 120, wi.position.y + 260),
				Vector2(wi.position.x + 120, wi.end.y - 260),
				Vector2(wi.end.x - 120, wi.end.y - 260)]:
		draw_circle(pos, 7.0, stump)
		draw_circle(pos, 7.0, Color(0,0,0,0.3), false, 1.5)
		draw_circle(pos + Vector2(22, 8), 5.0, rock_col)


func _deco_desert_ruins(wi: Rect2) -> void:
	var sand_lite := Color(0.88, 0.78, 0.44, 0.50)
	var pillar_c  := Color(0.55, 0.46, 0.24, 0.90)
	var ruin_c    := Color(0.48, 0.38, 0.18, 0.85)
	var cactus_c  := Color(0.22, 0.42, 0.14, 0.90)
	# Sand dunes (subtle highlight patches)
	for offset in [Vector2(120,80), Vector2(wi.size.x - 160, 80),
				   Vector2(120, wi.size.y - 100), Vector2(wi.size.x - 160, wi.size.y - 100)]:
		var p : Vector2 = wi.position + offset
		draw_circle(p, 40.0, sand_lite)
	# Central altar / ruin block
	var cx := wi.position.x + wi.size.x * 0.5
	var cy := wi.position.y + wi.size.y * 0.5
	draw_rect(Rect2(cx - 28, cy - 18, 56, 36), ruin_c)
	draw_rect(Rect2(cx - 28, cy - 18, 56, 36), Color(0,0,0,0.30), false, 2.0)
	# Broken pillars (4 corners of figure-8 loops)
	for pos in [Vector2(wi.position.x + 100, wi.position.y + 90),
				Vector2(wi.end.x     - 100, wi.position.y + 90),
				Vector2(wi.position.x + 100, wi.end.y     - 90),
				Vector2(wi.end.x     - 100, wi.end.y     - 90)]:
		draw_rect(Rect2(pos.x - 8, pos.y - 20, 16, 34), pillar_c)
		draw_rect(Rect2(pos.x - 8, pos.y - 20, 16, 34), Color(0,0,0,0.25), false, 1.5)
	# Cacti near corners
	for pos in [Vector2(wi.position.x + 50, wi.position.y + 220),
				Vector2(wi.end.x     - 50, wi.position.y + 220),
				Vector2(wi.position.x + 50, wi.end.y     - 220),
				Vector2(wi.end.x     - 50, wi.end.y     - 220)]:
		_draw_cactus(pos, cactus_c)


func _deco_frost_peaks(wi: Rect2) -> void:
	var ice_c   := Color(0.72, 0.88, 0.98, 0.80)
	var snow_c  := Color(0.90, 0.94, 1.00, 0.70)
	var pine_c  := Color(0.14, 0.32, 0.18, 0.88)
	var rock_c  := Color(0.52, 0.60, 0.70, 0.85)
	# Ice crystal clusters at corners
	for pos in [Vector2(wi.position.x + 60, wi.position.y + 60),
				Vector2(wi.end.x     - 60, wi.position.y + 60),
				Vector2(wi.position.x + 60, wi.end.y     - 60),
				Vector2(wi.end.x     - 60, wi.end.y     - 60)]:
		_draw_ice_cluster(pos, ice_c, snow_c)
	# Pine trees between spiral rings
	for pos in [Vector2(wi.position.x + 160, wi.position.y + 230),
				Vector2(wi.end.x     - 160, wi.position.y + 230),
				Vector2(wi.position.x + 160, wi.end.y     - 230),
				Vector2(wi.end.x     - 160, wi.end.y     - 230)]:
		_draw_pine(pos, pine_c, snow_c)
	# Frozen boulders near inner ring turns
	for pos in [Vector2(wi.position.x + 250, wi.position.y + 130),
				Vector2(wi.end.x     - 250, wi.end.y     - 130)]:
		draw_circle(pos, 14.0, rock_c)
		draw_circle(pos + Vector2(10,6), 9.0, Color(rock_c.r+0.15,rock_c.g+0.15,rock_c.b+0.15,0.7))
		draw_circle(pos, 14.0, Color(0,0,0,0.2), false, 1.5)


func _deco_volcanic_wastes(wi: Rect2) -> void:
	var lava_c   := Color(0.95, 0.35, 0.02, 0.90)
	var glow_c   := Color(1.00, 0.60, 0.10, 0.40)
	var rock_c   := Color(0.18, 0.12, 0.10, 0.90)
	var ash_c    := Color(0.25, 0.22, 0.20, 0.65)
	# Lava craters inside the oval path
	var cx := wi.position.x + wi.size.x * 0.5
	var cy := wi.position.y + wi.size.y * 0.5
	for offset in [Vector2(-130, 0), Vector2(130, 0)]:
		var cp : Vector2 = Vector2(cx, cy) + offset
		draw_circle(cp, 38.0, Color(0.10,0.06,0.04))
		draw_circle(cp, 30.0, lava_c)
		draw_circle(cp, 22.0, Color(1.00,0.75,0.20,0.85))
		draw_circle(cp, 14.0, Color(1.00,0.95,0.60,0.90))
		draw_circle(cp, 38.0, glow_c, false, 3.0)
	# Black rock clusters on the edges
	for pos in [Vector2(wi.position.x + 60, cy - 100),
				Vector2(wi.end.x     - 60, cy - 100),
				Vector2(wi.position.x + 60, cy + 100),
				Vector2(wi.end.x     - 60, cy + 100)]:
		draw_circle(pos, 18.0, rock_c)
		draw_circle(pos + Vector2(12,8), 11.0, ash_c)
	# Ash patches
	for pos in [Vector2(cx - 240, wi.position.y + 80),
				Vector2(cx + 240, wi.position.y + 80),
				Vector2(cx - 240, wi.end.y     - 80),
				Vector2(cx + 240, wi.end.y     - 80)]:
		draw_circle(pos, 25.0, ash_c)


func _deco_swamplands(wi: Rect2) -> void:
	var water_c := Color(0.12, 0.28, 0.10, 0.85)
	var mud_c   := Color(0.18, 0.22, 0.10, 0.80)
	var dead_c  := Color(0.22, 0.18, 0.10, 0.88)
	var mush_c  := Color(0.60, 0.18, 0.08, 0.85)
	# Swamp water pools in open areas between rails
	for pos in [Vector2(wi.position.x + 140, wi.position.y + 220),
				Vector2(wi.end.x     - 140, wi.position.y + 220),
				Vector2(wi.position.x + 350, wi.position.y + 220),
				Vector2(wi.end.x     - 350, wi.position.y + 220),
				Vector2(wi.position.x + 140, wi.end.y     - 220),
				Vector2(wi.end.x     - 140, wi.end.y     - 220)]:
		draw_circle(pos, 26.0, water_c)
		draw_circle(pos, 26.0, Color(0.08,0.35,0.06,0.25), false, 2.0)
		draw_circle(pos + Vector2(8,6), 10.0, Color(water_c.r+0.05, water_c.g+0.08, water_c.b, 0.70))
	# Dead trees
	for pos in [Vector2(wi.position.x + 80, wi.position.y + 100),
				Vector2(wi.end.x     - 80, wi.position.y + 100),
				Vector2(wi.position.x + 80, wi.end.y     - 100),
				Vector2(wi.end.x     - 80, wi.end.y     - 100)]:
		_draw_dead_tree(pos, dead_c)
	# Mushrooms
	for pos in [Vector2(wi.position.x + 260, wi.end.y - 150),
				Vector2(wi.end.x     - 260, wi.end.y - 150)]:
		_draw_mushroom(pos, mush_c)


func _deco_crystal_highlands(wi: Rect2) -> void:
	var crys_c  := Color(0.65, 0.18, 0.95, 0.90)
	var glow_c  := Color(0.80, 0.50, 1.00, 0.35)
	var rock_c  := Color(0.30, 0.18, 0.40, 0.80)
	# Central crystal field (inside the diamond path)
	var cx := wi.position.x + wi.size.x * 0.5
	var cy := wi.position.y + wi.size.y * 0.5
	_draw_crystal_cluster(Vector2(cx, cy),       crys_c, glow_c, 32.0)
	_draw_crystal_cluster(Vector2(cx-80, cy+30), crys_c, glow_c, 22.0)
	_draw_crystal_cluster(Vector2(cx+80, cy-30), crys_c, glow_c, 22.0)
	# Corner crystal formations (outside the diamond)
	for pos in [Vector2(wi.position.x + 60, cy),
				Vector2(wi.end.x     - 60, cy),
				Vector2(cx, wi.position.y + 50),
				Vector2(cx, wi.end.y     - 50)]:
		_draw_crystal_cluster(pos, Color(0.30,0.60,0.95,0.85), Color(0.50,0.80,1.00,0.30), 16.0)
	# Rocky cliffs at map edges
	for pos in [Vector2(wi.position.x + 100, wi.position.y + 90),
				Vector2(wi.end.x     - 100, wi.position.y + 90),
				Vector2(wi.position.x + 100, wi.end.y     - 90),
				Vector2(wi.end.x     - 100, wi.end.y     - 90)]:
		draw_circle(pos, 20.0, rock_c)
		draw_circle(pos, 20.0, Color(0,0,0,0.2), false, 1.5)


func _deco_shadow_realm(wi: Rect2) -> void:
	var void_c   := Color(0.22, 0.05, 0.40, 0.85)
	var crack_c  := Color(0.55, 0.10, 0.90, 0.60)
	var flame_c  := Color(0.40, 0.00, 0.70, 0.75)
	var rock_c   := Color(0.08, 0.04, 0.16, 0.90)
	# Shadow portal at centre
	var cx := wi.position.x + wi.size.x * 0.5
	var cy := wi.position.y + wi.size.y * 0.5
	draw_circle(Vector2(cx, cy), 38.0, Color(0.06,0.02,0.12))
	draw_circle(Vector2(cx, cy), 28.0, void_c)
	draw_circle(Vector2(cx, cy), 18.0, Color(0.30,0.00,0.55,0.85))
	draw_circle(Vector2(cx, cy), 10.0, Color(0.70,0.20,1.00,0.90))
	draw_circle(Vector2(cx, cy), 38.0, crack_c, false, 2.5)
	# Corruption cracks radiating from portal
	for angle in [0.0, 0.78, 1.57, 2.36, 3.14, 3.93, 4.71, 5.50]:
		var p1 := Vector2(cx, cy) + Vector2(cos(angle), sin(angle)) * 42.0
		var p2 := Vector2(cx, cy) + Vector2(cos(angle), sin(angle)) * 90.0
		draw_line(p1, p2, crack_c, 2.0)
	# Dark flame vents near maze turns
	for pos in [Vector2(wi.position.x + 90, wi.position.y + 100),
				Vector2(wi.end.x     - 90, wi.position.y + 100),
				Vector2(wi.position.x + 90, wi.end.y     - 100),
				Vector2(wi.end.x     - 90, wi.end.y     - 100)]:
		draw_circle(pos, 12.0, rock_c)
		draw_circle(pos, 8.0,  flame_c)
		draw_circle(pos, 4.0,  Color(0.80,0.40,1.00,0.80))
	# Corrupted rock clusters on maze walls
	for pos in [Vector2(wi.position.x + 200, cy - 60),
				Vector2(wi.end.x     - 200, cy - 60),
				Vector2(wi.position.x + 200, cy + 60),
				Vector2(wi.end.x     - 200, cy + 60)]:
		draw_circle(pos, 16.0, rock_c)
		draw_circle(pos + Vector2(10,5), 10.0, Color(rock_c.r+0.05,rock_c.g+0.02,rock_c.b+0.08,0.75))


func _deco_celestial_kingdom(wi: Rect2) -> void:
	var gold_c   := Color(0.95, 0.78, 0.20, 0.90)
	var marble_c := Color(0.95, 0.94, 0.90, 0.90)
	var pillar_c := Color(0.90, 0.86, 0.72, 0.88)
	var cloud_c  := Color(1.00, 1.00, 1.00, 0.35)
	# Central fountain
	var cx := wi.position.x + wi.size.x * 0.5
	var cy := wi.position.y + wi.size.y * 0.5
	draw_circle(Vector2(cx, cy), 42.0, Color(0.78,0.72,0.52))
	draw_circle(Vector2(cx, cy), 34.0, Color(0.65,0.82,0.92,0.90))
	draw_circle(Vector2(cx, cy), 20.0, Color(0.80,0.90,1.00,0.85))
	draw_circle(Vector2(cx, cy), 42.0, gold_c, false, 3.0)
	# Golden spire on fountain
	var pts_spire := PackedVector2Array([
		Vector2(cx, cy - 50), Vector2(cx - 8, cy - 22), Vector2(cx + 8, cy - 22)
	])
	draw_colored_polygon(pts_spire, gold_c)
	# Marble pillars ringing the fountain
	for i in range(6):
		var a := (i / 6.0) * TAU
		var pp := Vector2(cx + cos(a) * 70.0, cy + sin(a) * 70.0)
		draw_rect(Rect2(pp.x - 5, pp.y - 20, 10, 34), pillar_c)
		draw_rect(Rect2(pp.x - 5, pp.y - 20, 10, 34), gold_c, false, 1.5)
	# Cloud wisps at map edges
	for pos in [Vector2(wi.position.x + 60, wi.position.y + 60),
				Vector2(wi.end.x     - 60, wi.position.y + 60),
				Vector2(wi.position.x + 60, wi.end.y     - 60),
				Vector2(wi.end.x     - 60, wi.end.y     - 60),
				Vector2(cx - 200, wi.position.y + 40),
				Vector2(cx + 200, wi.position.y + 40),
				Vector2(cx - 200, wi.end.y     - 40),
				Vector2(cx + 200, wi.end.y     - 40)]:
		_draw_cloud(pos, cloud_c)
	# Golden statues at cardinal points
	for pos in [Vector2(wi.position.x + 110, cy),
				Vector2(wi.end.x     - 110, cy)]:
		_draw_statue(pos, gold_c, marble_c)


# ── Decoration helpers ────────────────────────────────────────────────────────
func _draw_tree_cluster(centre: Vector2, count: int, radius: float,
		dark: Color, mid: Color) -> void:
	for i in range(count):
		var a := (i / float(count)) * TAU + 0.3
		var r := radius * 0.55
		draw_circle(centre + Vector2(cos(a), sin(a)) * r, radius * 0.72, dark)
	draw_circle(centre, radius, mid)
	draw_circle(centre, radius, Color(0,0,0,0.18), false, 1.5)


func _draw_pine(pos: Vector2, green: Color, snow: Color) -> void:
	# Three stacked triangles tapering upward
	for i in range(3):
		var w := 22.0 - i * 6.0
		var y := pos.y + 10.0 - i * 14.0
		var tri := PackedVector2Array([
			Vector2(pos.x, y - 16.0 + i * 4.0),
			Vector2(pos.x - w, y), Vector2(pos.x + w, y)
		])
		draw_colored_polygon(tri, green)
		# Snow cap on top triangle
		if i == 2:
			var snow_tri := PackedVector2Array([
				Vector2(pos.x, y - 16.0 + i * 4.0),
				Vector2(pos.x - 6.0, y - 4.0), Vector2(pos.x + 6.0, y - 4.0)
			])
			draw_colored_polygon(snow_tri, snow)
	# Trunk
	draw_rect(Rect2(pos.x - 3, pos.y + 12, 6, 10), Color(0.32,0.22,0.12))


func _draw_ice_cluster(pos: Vector2, ice: Color, snow: Color) -> void:
	for i in range(5):
		var a    := (i / 5.0) * TAU
		var size := 8.0 + (i % 2) * 6.0
		var tip  := pos + Vector2(cos(a), sin(a)) * (18.0 + size)
		var base := pos + Vector2(cos(a + 0.35), sin(a + 0.35)) * 8.0
		var base2 := pos + Vector2(cos(a - 0.35), sin(a - 0.35)) * 8.0
		draw_colored_polygon(PackedVector2Array([tip, base, base2]), ice)
	draw_circle(pos, 8.0, snow)


func _draw_cactus(pos: Vector2, green: Color) -> void:
	# Trunk
	draw_rect(Rect2(pos.x - 5, pos.y - 24, 10, 28), green)
	# Arms
	draw_rect(Rect2(pos.x - 16, pos.y - 14, 12, 6), green)
	draw_rect(Rect2(pos.x +  4, pos.y - 18, 12, 6), green)
	draw_rect(Rect2(pos.x - 16, pos.y - 14, 5, 10), green)
	draw_rect(Rect2(pos.x + 11, pos.y - 18, 5, 10), green)
	draw_circle(pos, 5.0, Color(green.r+0.08,green.g+0.12,green.b,1.0))


func _draw_dead_tree(pos: Vector2, col: Color) -> void:
	draw_rect(Rect2(pos.x - 4, pos.y - 30, 8, 34), col)
	draw_line(Vector2(pos.x, pos.y - 20), Vector2(pos.x - 18, pos.y - 32), col, 3.0)
	draw_line(Vector2(pos.x, pos.y - 18), Vector2(pos.x + 16, pos.y - 28), col, 3.0)
	draw_line(Vector2(pos.x, pos.y - 10), Vector2(pos.x - 12, pos.y - 16), col, 2.5)


func _draw_mushroom(pos: Vector2, cap_c: Color) -> void:
	# Stem
	draw_rect(Rect2(pos.x - 4, pos.y - 8, 8, 12), Color(0.72,0.70,0.60))
	# Cap
	var cap := PackedVector2Array([
		Vector2(pos.x, pos.y - 24),
		Vector2(pos.x - 14, pos.y - 6),
		Vector2(pos.x + 14, pos.y - 6)
	])
	draw_colored_polygon(cap, cap_c)
	draw_circle(pos + Vector2(-5,-14), 3.0, Color(1,1,1,0.7))


func _draw_crystal_cluster(pos: Vector2, crys: Color, glow: Color, scale: float) -> void:
	draw_circle(pos, scale + 4.0, glow)
	for i in range(6):
		var a    := (i / 6.0) * TAU + 0.2
		var h    := scale * (0.8 + (i % 3) * 0.3)
		var w    := scale * 0.22
		var tip  := pos + Vector2(cos(a), sin(a)) * h
		var b1   := pos + Vector2(cos(a + 0.28), sin(a + 0.28)) * w
		var b2   := pos + Vector2(cos(a - 0.28), sin(a - 0.28)) * w
		draw_colored_polygon(PackedVector2Array([tip, b1, b2]), crys)
	draw_circle(pos, scale * 0.25, Color(crys.r + 0.20, crys.g + 0.15, crys.b + 0.10, 0.90))


func _draw_cloud(pos: Vector2, col: Color) -> void:
	for offset in [Vector2(0,0), Vector2(18,0), Vector2(-18,0),
				   Vector2(9,-10), Vector2(-9,-10)]:
		draw_circle(pos + offset, 16.0 + abs(offset.x) * 0.1, col)


func _draw_statue(pos: Vector2, gold: Color, base: Color) -> void:
	draw_rect(Rect2(pos.x - 10, pos.y + 12, 20, 10), base)  # pedestal
	draw_rect(Rect2(pos.x -  5, pos.y - 14, 10, 28), base)  # body
	draw_circle(Vector2(pos.x, pos.y - 20), 8.0, base)       # head
	draw_rect(Rect2(pos.x -  5, pos.y - 14, 10, 28), gold, false, 1.0)
	draw_circle(Vector2(pos.x, pos.y - 20), 8.0, gold, false, 1.0)


func _path_to_pv2(path: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in path:
		pts.append(p)
	return pts



# ── World 1 road polygon (original — untouched) ───────────────────────────────
func _road_outer_poly() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r   : float = OUTER_R

	pts.append(Vector2(0.0, R_TOP))
	pts.append(Vector2(R_RIGHT - r, R_TOP))
	_arc(pts, Vector2(R_RIGHT - r, R_TOP + r), r, -PI * 0.5, 0.0)
	pts.append(Vector2(R_RIGHT, R_BOT - r))
	_arc(pts, Vector2(R_RIGHT - r, R_BOT - r), r, 0.0, PI * 0.5)
	pts.append(Vector2(R_LEFT + r, R_BOT))
	_arc(pts, Vector2(R_LEFT + r, R_BOT - r), r, PI * 0.5, PI)
	pts.append(Vector2(R_LEFT, I_TOP))
	pts.append(Vector2(0.0, I_TOP))

	return pts


func _island_poly(rect: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r   : float = INNER_R
	var x0  : float = rect.position.x + r
	var y0  : float = rect.position.y + r
	var x1  : float = rect.end.x - r
	var y1  : float = rect.end.y - r

	_arc(pts, Vector2(x0, y0), r, -PI,       -PI * 0.5)
	_arc(pts, Vector2(x1, y0), r, -PI * 0.5,  0.0)
	_arc(pts, Vector2(x1, y1), r,  0.0,       PI * 0.5)
	_arc(pts, Vector2(x0, y1), r,  PI * 0.5,  PI)

	return pts


func _arc(pts: PackedVector2Array, centre: Vector2,
		  radius: float, a_from: float, a_to: float) -> void:
	for i in range(STEPS + 1):
		var t : float = float(i) / float(STEPS)
		var a : float = lerp(a_from, a_to, t)
		pts.append(centre + Vector2(cos(a), sin(a)) * radius)
