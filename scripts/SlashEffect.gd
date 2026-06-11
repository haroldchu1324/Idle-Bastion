# scripts/SlashEffect.gd
# Temporary slash-arc visual spawned at an enemy's position when the Axe Warrior attacks.
# Draws a red (bleed) arc and a green (poison) arc that fade out over ~0.3 seconds.
extends Node2D

var _life     : float = 0.30
var _max_life : float = 0.30
var _base_angle : float = 0.0   # randomised rotation per hit
var _tw_mode    : bool  = false  # white sword-cut mark mode (Tempest Warden special)

func init(world_pos: Vector2) -> void:
	position    = world_pos
	z_index     = 8
	_base_angle = randf() * TAU

func init_tw_cut(local_pos: Vector2) -> void:
	position    = local_pos
	z_index     = 10
	_base_angle = randf_range(-PI * 0.25, PI * 0.25)
	_life       = 0.50
	_max_life   = 0.50
	_tw_mode    = true

func _process(delta: float) -> void:
	_life -= delta
	queue_redraw()
	if _life <= 0.0:
		queue_free()

func _draw() -> void:
	if _tw_mode:
		_draw_tw_cut_mark()
		return
	var t     : float = clampf(_life / _max_life, 0.0, 1.0)
	# Quadratic ease-in fade — bright flash then quick fade
	var alpha : float = t * t

	# Progress fraction: sweep the arc as it plays (1.0→0.0 over lifetime)
	# Arc start angle animates so it looks like a moving slash
	var sweep : float = (1.0 - t) * 0.8   # sweeps 0.8 radians over lifetime

	var R  : float = 24.0   # arc radius
	var AW : float = 0.70   # arc half-width in radians

	# ── Red slash (bleed) ──────────────────────────────────────────────────
	var ra : float = _base_angle + sweep
	var red_outer := Color(0.90, 0.08, 0.08, alpha * 0.35)
	var red_mid   := Color(0.95, 0.20, 0.20, alpha * 0.85)
	var red_inner := Color(1.00, 0.55, 0.55, alpha * 0.65)
	draw_arc(Vector2.ZERO, R + 4, ra - AW, ra + AW, 20, red_outer, 8.0)
	draw_arc(Vector2.ZERO, R,     ra - AW, ra + AW, 20, red_mid,   4.0)
	draw_arc(Vector2.ZERO, R - 5, ra - AW * 0.7, ra + AW * 0.7, 14, red_inner, 2.0)
	# Tip spark at the leading edge
	var tip_r := Vector2(cos(ra + AW), sin(ra + AW)) * R
	draw_circle(tip_r, 3.5 * alpha, Color(1.0, 0.4, 0.4, alpha * 0.80))

	# ── Green slash (poison) — opposite side, slight delay feel ────────────
	var ga    : float = _base_angle + PI + sweep * 0.8
	var g_alpha : float = clampf((t - 0.15) / 0.85, 0.0, 1.0)   # starts ~50ms later
	g_alpha = g_alpha * g_alpha
	var grn_outer := Color(0.10, 0.70, 0.18, g_alpha * 0.30)
	var grn_mid   := Color(0.20, 0.88, 0.30, g_alpha * 0.80)
	var grn_inner := Color(0.60, 1.00, 0.55, g_alpha * 0.60)
	draw_arc(Vector2.ZERO, R + 4, ga - AW, ga + AW, 20, grn_outer, 8.0)
	draw_arc(Vector2.ZERO, R,     ga - AW, ga + AW, 20, grn_mid,   4.0)
	draw_arc(Vector2.ZERO, R - 5, ga - AW * 0.7, ga + AW * 0.7, 14, grn_inner, 2.0)
	var tip_g := Vector2(cos(ga + AW), sin(ga + AW)) * R
	draw_circle(tip_g, 3.5 * g_alpha, Color(0.5, 1.0, 0.5, g_alpha * 0.80))


func _draw_tw_cut_mark() -> void:
	var t     : float = clampf(_life / _max_life, 0.0, 1.0)
	var alpha : float = t * t
	draw_set_transform(Vector2.ZERO, _base_angle)
	# Diagonal wound lines across the enemy body
	var A := Vector2(-17, -17)
	var B := Vector2( 17,  17)
	# Soft outer glow
	draw_line(A, B, Color(0.75, 0.97, 1.00, alpha * 0.30), 12.0)
	# Main white wound line
	draw_line(A, B, Color(1.00, 1.00, 1.00, alpha * 0.85),  4.0)
	# Bright core
	draw_line(A, B, Color(1.00, 1.00, 1.00, alpha * 0.95),  1.5)
	# Parallel nick for wound depth
	var A2 := Vector2(-10, -19)
	var B2 := Vector2( 19,  10)
	draw_line(A2, B2, Color(0.80, 0.97, 1.00, alpha * 0.38), 2.0)
	# Endpoint sparks
	draw_circle(A, 2.5 * alpha, Color(1.00, 1.00, 1.00, alpha * 0.85))
	draw_circle(B, 2.5 * alpha, Color(0.80, 0.97, 1.00, alpha * 0.65))
	draw_set_transform(Vector2.ZERO, 0.0)
