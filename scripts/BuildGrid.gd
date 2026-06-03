extends Node2D
class_name BuildGrid

const ISLAND    := Rect2(280, 170, 540, 300)
const TILE_SIZE : int = 60
const COLS      : int = 9    # 540 / 60
const ROWS      : int = 5    # 300 / 60

var _occupied    : Dictionary = {}   # Vector2i → true
var hovered_tile : Vector2i   = Vector2i(-1, -1)
var _time        : float      = 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func world_to_tile(p: Vector2) -> Vector2i:
	return Vector2i(
		int((p.x - ISLAND.position.x) / TILE_SIZE),
		int((p.y - ISLAND.position.y) / TILE_SIZE)
	)


func tile_center(t: Vector2i) -> Vector2:
	return Vector2(
		ISLAND.position.x + t.x * TILE_SIZE + TILE_SIZE * 0.5,
		ISLAND.position.y + t.y * TILE_SIZE + TILE_SIZE * 0.5
	)


func is_in_grid(p: Vector2) -> bool:
	return ISLAND.has_point(p)


func can_place(t: Vector2i) -> bool:
	if t.x < 0 or t.x >= COLS or t.y < 0 or t.y >= ROWS:
		return false
	return not _occupied.has(t)


func place(t: Vector2i) -> void:
	_occupied[t] = true


func unplace(t: Vector2i) -> void:
	_occupied.erase(t)


func _draw() -> void:
	if hovered_tile.x < 0 or not can_place(hovered_tile):
		return

	var center := tile_center(hovered_tile)
	var half   := TILE_SIZE * 0.5

	# Tile highlight
	draw_rect(
		Rect2(center.x - half, center.y - half, TILE_SIZE, TILE_SIZE),
		Color(1.0, 1.0, 1.0, 0.12)
	)
	draw_rect(
		Rect2(center.x - half, center.y - half, TILE_SIZE, TILE_SIZE),
		Color(1.0, 1.0, 1.0, 0.35), false, 1.5
	)

	# Ghost turret that bobs up and down
	var bob := sin(_time * 5.0) * 4.0
	var gp  := center + Vector2(0.0, bob - 6.0)
	var col := Color(1.0, 1.0, 1.0, 0.40)
	var rim := Color(1.0, 1.0, 1.0, 0.60)

	# Base circle
	draw_circle(gp, 14.0, col)
	draw_circle(gp, 14.0, rim, false, 1.5)
	# Barrel pointing up
	draw_rect(Rect2(gp.x - 4.0, gp.y - 22.0, 8.0, 12.0), col)
	draw_rect(Rect2(gp.x - 4.0, gp.y - 22.0, 8.0, 12.0), rim, false, 1.5)
	# Small drop shadow that fades as the ghost bobs higher
	var shadow_alpha : float = 0.18 - abs(bob) * 0.012
	draw_circle(
		center + Vector2(0.0, half - 6.0),
		10.0 - abs(bob) * 0.5,
		Color(0.0, 0.0, 0.0, max(0.0, shadow_alpha))
	)
