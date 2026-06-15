extends Control
# Purple coin with gold rope ring and five-pointed star.
# Set `size` before adding to the scene; the coin fills the control.

func _draw() -> void:
	var r  : float  = minf(size.x, size.y) * 0.5
	var cx : float  = size.x * 0.5
	var cy : float  = size.y * 0.5
	var c  : Vector2 = Vector2(cx, cy)

	# ── Body ─────────────────────────────────────────────────────────────────────
	draw_circle(c, r,        Color(0.40, 0.14, 0.65))          # main purple
	draw_circle(c, r * 0.97, Color(0.46, 0.18, 0.74))          # inner lighter ring
	# Bottom shadow for coin depth
	draw_arc(c, r * 0.80, PI * 0.25, PI * 0.75, 24,
			Color(0.18, 0.04, 0.34, 0.50), r * 0.18)

	# ── Gold rope border ─────────────────────────────────────────────────────────
	const KNOTS : int = 22
	var rope_r : float = r * 0.86
	for i in range(KNOTS):
		var a0 : float = i       * TAU / KNOTS
		var a1 : float = (i + 1) * TAU / KNOTS
		var mid : float = (a0 + a1) * 0.5
		# Alternating dark/bright segments give a twisted-rope look
		var bright : bool = (i % 2 == 0)
		var col := Color(0.88, 0.65, 0.12) if bright else Color(0.62, 0.42, 0.04)
		draw_arc(c, rope_r, a0, a1, 3, col, r * 0.10)
	# Thin bright highlight line on top of rope
	draw_arc(c, rope_r, 0, TAU, 48, Color(1.00, 0.88, 0.40, 0.45), r * 0.04)

	# ── Five-pointed star ─────────────────────────────────────────────────────────
	var outer_r : float = r * 0.52
	var inner_r : float = r * 0.21
	var star_pts  := PackedVector2Array()
	var star_cols := PackedColorArray()
	for i in range(10):
		var a  : float  = -PI * 0.5 + i * TAU / 10.0
		var sr : float  = outer_r if (i % 2 == 0) else inner_r
		var pt : Vector2 = c + Vector2(cos(a), sin(a)) * sr
		star_pts.append(pt)
		# Top of star = lighter (highlight); bottom = darker (shadow)
		var shade : float = 1.0 - clampf(sin(a) * 0.30, -0.15, 0.30)
		star_cols.append(Color(0.96 * shade, 0.78 * shade, 0.16, 1.0))
	draw_polygon(star_pts, star_cols)
	# Star outline
	draw_polyline(star_pts, Color(0.62, 0.44, 0.04, 0.70), maxf(0.8, r * 0.04), true)
	# Specular spot (top-left highlight)
	draw_circle(c + Vector2(-outer_r * 0.28, -outer_r * 0.30),
				r * 0.10, Color(1.0, 0.96, 0.60, 0.55))
