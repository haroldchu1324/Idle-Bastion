# scripts/SlashEffect.gd
# Temporary slash-arc visual spawned at an enemy's position when the Axe Warrior attacks.
# Draws a red (bleed) arc and a green (poison) arc that fade out over ~0.3 seconds.
extends Node2D

var _life     : float = 0.30
var _max_life : float = 0.30
var _base_angle : float = 0.0   # randomised rotation per hit

func init(world_pos: Vector2) -> void:
	position    = world_pos
	z_index     = 8
	_base_angle = randf() * TAU

func _process(delta: float) -> void:
	_life -= delta
	queue_redraw()
	if _life <= 0.0:
		queue_free()

func _draw() -> void:
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
