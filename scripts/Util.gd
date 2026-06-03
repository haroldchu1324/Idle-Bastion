# scripts/Util.gd
# ─────────────────────────────────────────────────────────────────────────────
# Autoloaded as "Util" — available globally, no imports needed.
# ─────────────────────────────────────────────────────────────────────────────
extends Node


# Converts a large number into a short readable string.
# Examples:  500 → "500"   1500 → "1.5K"   2_500_000 → "2.5M"
func format_number(value: float) -> String:
	if value >= 1_000_000_000_000.0:
		return "%.1fT" % (value / 1_000_000_000_000.0)
	if value >= 1_000_000_000.0:
		return "%.1fB" % (value / 1_000_000_000.0)
	if value >= 1_000_000.0:
		return "%.1fM" % (value / 1_000_000.0)
	if value >= 1_000.0:
		return "%.1fK" % (value / 1_000.0)
	return str(int(value))
