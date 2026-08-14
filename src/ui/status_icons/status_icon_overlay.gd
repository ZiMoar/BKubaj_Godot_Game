class_name StatusIconOverlay
extends Node2D

## Draws small colored status badges above an enemy so the player can see at a
## glance which effects (burn / bleed / poison / slow) are active. It sits as a
## child of the enemy and reads the enemy's status fields every frame, so it
## follows the enemy automatically. Drawn with _draw() to match the grid style.
##
## The parent is expected to be an EnemyBase (or expose the same status vars).

var burn_dps: float = 0.0
var poison_stacks: int = 0
var slow_active: bool = false
var impale_active: bool = false
var crit_vuln_active: bool = false
var decay_active: bool = false
var brand_active: bool = false

const ICON_GAP: float = 12.0
const ICON_RADIUS: float = 5.0
const ROW_Y: float = -34.0  # local offset above head (negative Y = up in 2D scene)


func _process(_delta: float) -> void:
	if not is_inside_tree():
		return
	var p: Object = get_parent()
	if p == null:
		return
	burn_dps = p.get("burn_dps")
	poison_stacks = p.get("poison_stacks")
	slow_active = (p.get("slow_timer") as float) > 0.0
	impale_active = (p.get("impale_pool") as float) > 0.0
	crit_vuln_active = (p.get("crit_vuln_timer") as float) > 0.0
	decay_active = (p.get("decay_timer") as float) > 0.0
	brand_active = (p.get("brand_timer") as float) > 0.0
	queue_redraw()


func _build_icons() -> Array:
	# Returns list of [color, label_char] for currently active statuses.
	var icons: Array = []
	if burn_dps > 0.0:
		icons.append([Color(1.0, 0.5, 0.15), "F"])  # fire / burn
	if poison_stacks > 0:
		icons.append([Color(0.35, 0.85, 0.2), "P"])  # poison
	if slow_active:
		icons.append([Color(0.3, 0.7, 1.0), "S"])  # slow
	if impale_active:
		icons.append([Color(0.8, 0.8, 0.85), "I"])  # impale
	if crit_vuln_active:
		icons.append([Color(0.9, 0.55, 0.9), "V"])  # crit vulnerability
	if decay_active:
		icons.append([Color(0.4, 0.55, 0.4), "D"])  # decay
	if brand_active:
		icons.append([Color(1.0, 0.95, 0.5), "B"])  # brand
	return icons


func _draw() -> void:
	var icons: Array = _build_icons()
	if icons.is_empty():
		return
	var total_w: float = float(icons.size()) * ICON_GAP
	var start_x: float = -total_w * 0.5 + ICON_GAP * 0.5
	for i in range(icons.size()):
		var icon: Array = icons[i]
		var color: Color = icon[0]
		var ch: String = icon[1]
		var cx: float = start_x + float(i) * ICON_GAP
		# Badge circle.
		draw_circle(Vector2(cx, ROW_Y), ICON_RADIUS, Color(0, 0, 0, 0.55))
		draw_circle(Vector2(cx, ROW_Y), ICON_RADIUS, Color(color, 0.85))
		draw_arc(Vector2(cx, ROW_Y), ICON_RADIUS, 0.0, TAU, 16, Color(0, 0, 0, 0.7), 1.0)
		# Letter.
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(cx - 3.2, ROW_Y + 3.6), ch,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 1))
