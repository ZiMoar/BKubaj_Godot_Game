class_name TargetPointer
extends Node2D

## Base class for on-screen edge pointers that point toward an off-screen target.
## Subclasses override _get_target_world_pos() to supply the target location.
## Place this node inside a CanvasLayer so it renders in screen space.

@export var pointer_color: Color = Color(1.0, 0.85, 0.3)
@export var screen_margin: float = 46.0
@export var pointer_len: float = 34.0
@export var arrow_size: float = 12.0
@export var hide_when_on_screen: bool = true
@export var on_screen_padding: float = 24.0


func _get_target_world_pos() -> Vector2:
	# Override in subclasses. Return Vector2.INF when there is no target.
	return Vector2.INF


func _process(_delta: float) -> void:
	_update_pointer()


func _update_pointer() -> void:
	var world_pos: Vector2 = _get_target_world_pos()
	if world_pos == Vector2.INF:
		visible = false
		return

	var viewport: Viewport = get_viewport()
	var screen_size: Vector2 = viewport.get_visible_rect().size
	var center: Vector2 = screen_size * 0.5
	var target_screen: Vector2 = viewport.get_canvas_transform() * world_pos
	var rel: Vector2 = target_screen - center

	# Hide when the target is close enough to being on screen.
	var half: Vector2 = screen_size * 0.5 - Vector2(on_screen_padding, on_screen_padding)
	if hide_when_on_screen and absf(target_screen.x - center.x) < half.x and absf(target_screen.y - center.y) < half.y:
		visible = false
		return
	visible = true

	var dist: float = rel.length()
	if dist < 1.0:
		position = center
		rotation = 0.0
		return

	var dir: Vector2 = rel / dist
	# Slide the pointer to the nearest screen edge (with margin), keeping it visible.
	var t_x: float = (center.x - screen_margin) / maxf(absf(dir.x), 0.0001)
	var t_y: float = (center.y - screen_margin) / maxf(absf(dir.y), 0.0001)
	position = center + dir * minf(t_x, t_y)
	rotation = dir.angle()

	queue_redraw()


func _draw() -> void:
	var tip: Vector2 = Vector2(pointer_len, 0.0)
	# Shaft
	draw_line(Vector2.ZERO, tip - Vector2(arrow_size, 0.0), pointer_color, 3.0)
	# Arrowhead
	draw_line(tip, tip + Vector2(-arrow_size, -arrow_size), pointer_color, 3.0)
	draw_line(tip, tip + Vector2(-arrow_size, arrow_size), pointer_color, 3.0)