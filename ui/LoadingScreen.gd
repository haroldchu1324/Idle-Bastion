extends Node2D

# Dice-roll gacha animation shown when "Start World" is pressed.
# Usage: create instance, call setup(font_bold, callback), add to a CanvasLayer.

const DURATION  : float = 1.0
const FADE_TIME : float = 1.5

const C_GRAY_DIE   := Color(0.52, 0.52, 0.55)
const C_BLUE_DIE   := Color(0.22, 0.48, 0.92)
const C_PURPLE_DIE := Color(0.55, 0.18, 0.88)
const C_GOLD_DIE   := Color(0.95, 0.78, 0.10)

var _t           : float    = 0.0
var _fade_t      : float    = 0.0
var _fading      : bool     = false
var _alpha       : float    = 1.0
var _on_ready_cb : Callable
var _on_done_cb  : Callable
var _dice        : Array    = []
var _font        : Font     = null

func setup(font_bold : Font, on_ready_cb : Callable, on_done_cb : Callable) -> void:
	_font        = font_bold
	_on_ready_cb = on_ready_cb
	_on_done_cb  = on_done_cb
	_init_dice()

func _init_dice() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# [color, size, pip_count]
	var cfgs : Array = [
		[C_GRAY_DIE,   36.0, 1],
		[C_GRAY_DIE,   30.0, 3],
		[C_GRAY_DIE,   40.0, 2],
		[C_BLUE_DIE,   38.0, 4],
		[C_BLUE_DIE,   34.0, 5],
		[C_PURPLE_DIE, 42.0, 6],
		[C_PURPLE_DIE, 36.0, 3],
		[C_GOLD_DIE,   48.0, 6],
	]

	for i in range(cfgs.size()):
		var cfg = cfgs[i]
		var sz  : float = cfg[1]
		_dice.append({
			"pos":      Vector2(-sz - rng.randf_range(20.0, 300.0),
								 rng.randf_range(50.0, 670.0)),
			"vel":      Vector2(rng.randf_range(750.0, 1300.0),
								rng.randf_range(-60.0, 80.0)),
			"rot":      rng.randf_range(0.0, TAU),
			"rot_spd":  rng.randf_range(3.5, 6.0) * TAU * (1.0 if rng.randf() > 0.5 else -1.0),
			"color":    cfg[0],
			"size":     sz,
			"sq_phase": rng.randf_range(0.0, TAU),
			"pips":     cfg[2],
			"trail":    [],
		})

func _process(delta: float) -> void:
	if _fading:
		_fade_t += delta
		_alpha = 1.0 - clamp(_fade_t / FADE_TIME, 0.0, 1.0)
		if _fade_t >= FADE_TIME:
			_on_done_cb.call()
			queue_free()
			return
	else:
		_t += delta
		if _t >= DURATION:
			_fading = true
			_on_ready_cb.call()

	for d in _dice:
		d["trail"].push_front(Vector2(d["pos"]))
		if d["trail"].size() > 5:
			d["trail"].pop_back()
		d["pos"] += d["vel"] * delta
		d["rot"] += d["rot_spd"] * delta

	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.04, 0.03, 0.10, 0.92 * _alpha))

	# Subtle scan lines
	for i in range(12):
		draw_line(Vector2(0.0, float(i) * 60.0 + 15.0),
				  Vector2(1280.0, float(i) * 60.0 + 15.0),
				  Color(1.0, 1.0, 1.0, 0.025 * _alpha), 1.0)

	for d in _dice:
		# Trail
		for ti in range(d["trail"].size()):
			var talpha : float = (1.0 - float(ti + 1) / float(d["trail"].size() + 1)) * 0.28 * _alpha
			_draw_die(d["trail"][ti],
					  d["rot"] - d["rot_spd"] * 0.014 * float(ti + 1),
					  d["size"] * 0.88, d["color"], d["pips"], 1.0, 1.0, talpha)
		# Die
		var sq : float = sin(_t * 9.0 + d["sq_phase"])
		_draw_die(d["pos"], d["rot"], d["size"], d["color"], d["pips"],
				  1.0 + sq * 0.07, 1.0 - sq * 0.07, _alpha)

	# Loading text
	if _font:
		draw_string(_font, Vector2(0.0, 648.0), "Rolling the Dice...",
					HORIZONTAL_ALIGNMENT_CENTER, 1280.0, 36,
					Color(1.0, 0.88, 0.40, _alpha))

func _draw_die(pos: Vector2, rot: float, sz: float, clr: Color,
			   pips: int, sx: float, sy: float, alpha: float) -> void:
	draw_set_transform(pos, rot, Vector2(sx, sy))
	var h := sz * 0.5

	draw_rect(Rect2(-h + 3.0, -h + 4.0, sz, sz), Color(0.0, 0.0, 0.0, 0.40 * alpha))
	draw_rect(Rect2(-h, -h, sz, sz),               Color(clr.r, clr.g, clr.b, alpha))
	draw_rect(Rect2(-h, -h, sz, sz * 0.22),        Color(1.0, 1.0, 1.0, 0.28 * alpha))
	draw_rect(Rect2(-h, -h, sz * 0.10, sz),        Color(1.0, 1.0, 1.0, 0.14 * alpha))
	draw_rect(Rect2(-h, -h, sz, sz),               Color(1.0, 1.0, 1.0, 0.26 * alpha), false, 1.5)

	var pr : float = sz * 0.09
	var o  : float = h * 0.52
	for pp : Vector2 in _pip_positions(pips, o):
		draw_circle(pp, pr, Color(1.0, 1.0, 1.0, 0.90 * alpha))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _pip_positions(count: int, o: float) -> Array:
	match count:
		1: return [Vector2.ZERO]
		2: return [Vector2(-o, -o), Vector2(o, o)]
		3: return [Vector2(-o, -o), Vector2.ZERO, Vector2(o, o)]
		4: return [Vector2(-o, -o), Vector2(o, -o), Vector2(-o, o), Vector2(o, o)]
		5: return [Vector2(-o, -o), Vector2(o, -o), Vector2.ZERO, Vector2(-o, o), Vector2(o, o)]
		6: return [Vector2(-o, -o), Vector2(o, -o), Vector2(-o, 0.0), Vector2(o, 0.0), Vector2(-o, o), Vector2(o, o)]
	return [Vector2.ZERO]
