extends RefCounted
class_name MapBuilder

const TILE_SIZE   : int = 40
const MAP_COLS    : int = 32   # 32 * 40 = 1280
const MAP_ROWS    : int = 18   # 18 * 40 = 720
const SOURCE_ID   : int = 0
const ATLAS_COORD : Vector2i = Vector2i(0, 0)

func build(layer: TileMapLayer) -> void:
	layer.tile_set = _make_tileset()
	for col in range(MAP_COLS):
		for row in range(MAP_ROWS):
			layer.set_cell(Vector2i(col, row), SOURCE_ID, ATLAS_COORD)

func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var src := TileSetAtlasSource.new()
	src.texture             = _grass_texture()
	src.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	src.create_tile(ATLAS_COORD)
	ts.add_source(src, SOURCE_ID)
	return ts

func _grass_texture() -> ImageTexture:
	var img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var base := Color(0.25, 0.57, 0.14)
	img.fill(base)
	# Subtle variation: a few darker/lighter pixels for a painterly feel
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for _i in range(18):
		var px : int = rng.randi_range(0, TILE_SIZE - 1)
		var py : int = rng.randi_range(0, TILE_SIZE - 1)
		var v  : float = rng.randf_range(-0.04, 0.04)
		img.set_pixel(px, py, Color(base.r + v, base.g + v * 0.5, base.b + v * 0.3))
	return ImageTexture.create_from_image(img)
