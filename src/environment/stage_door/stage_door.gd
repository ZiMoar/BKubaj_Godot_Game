class_name StageDoor
extends Area2D

## The exit door on the top wall of an arena. It stays closed (drawn dimmed,
## no collision) until the room is completed. Once opened by the StageController,
## the player can walk into it to advance to the next stage.

@export var door_width: float = 72.0
@export var door_height: float = 104.0

var is_open: bool = false


func _ready() -> void:
	# The door is an Area2D that must DETECT the player body. The player is on
	# physics layer 2. With the default collision_mask (1 = World) the area would
	# never report the player, so body_entered would never fire and the door would
	# open graphically but never transition. Set the mask to monitor the player.
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	_collision_enabled(false)
	queue_redraw()


func open_door() -> void:
	is_open = true
	_collision_enabled(true)
	queue_redraw()


func _collision_enabled(enabled: bool) -> void:
	var shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape:
		shape.disabled = not enabled


func _draw() -> void:
	# A doorway: two jambs and a lintel, plus a swing panel that lights up green
	# once the room is cleared (open) vs a dark barred panel while closed.
	var half_w: float = door_width * 0.5
	var top: float = -door_height * 0.5
	if is_open:
		# Open: green frame + glow + up-arrow to signal it can be entered.
		var frame: Color = Color(0.3, 0.85, 0.4)
		draw_rect(Rect2(-half_w - 7, top - 7, door_width + 14, door_height + 14), Color(0.3, 0.85, 0.4, 0.25))
		draw_rect(Rect2(-half_w - 6, top - 6, door_width + 12, 10), frame)
		draw_rect(Rect2(-half_w - 6, top, 8, door_height), frame)
		draw_rect(Rect2(half_w - 2, top, 8, door_height), frame)
		draw_rect(Rect2(-half_w + 4, top + 8, door_width - 8, door_height - 16), Color(0.6, 0.95, 0.5))
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, top - 2), Vector2(-9, top - 13), Vector2(9, top - 13),
		]), Color(0.9, 1.0, 0.8, 1.0))
	else:
		# Closed: lighter stone frame + X bars so it clearly reads as a locked door.
		var stone: Color = Color(0.65, 0.5, 0.32)
		var bars: Color = Color(0.9, 0.25, 0.2)
		draw_rect(Rect2(-half_w - 6, top - 6, door_width + 12, 10), stone)
		draw_rect(Rect2(-half_w - 6, top, 8, door_height), stone)
		draw_rect(Rect2(half_w - 2, top, 8, door_height), stone)
		# Panel + crossing bars (X = locked).
		draw_rect(Rect2(-half_w + 4, top + 8, door_width - 8, door_height - 16), Color(0.4, 0.3, 0.16))
		draw_line(Vector2(-half_w + 6, top + 10), Vector2(half_w - 4, top + door_height - 10), bars, 5.0)
		draw_line(Vector2(half_w - 4, top + 10), Vector2(-half_w + 6, top + door_height - 10), bars, 5.0)


func _on_body_entered(body: Node2D) -> void:
	if not is_open:
		return
	if not body.is_in_group("player"):
		return
	_advance_stage()


func _advance_stage() -> void:
	var run_state: Node = get_node_or_null("/root/GameState")
	if run_state == null:
		return
	var player: Node = get_tree().get_first_node_in_group("player") as Node
	var xp_mgr: Node = get_tree().get_first_node_in_group("team_xp_manager") as Node
	if run_state.has_method("advance_stage"):
		run_state.advance_stage(player, xp_mgr)
		var next_path: String = run_state.get_next_arena_path()
		if not next_path.is_empty():
			get_tree().change_scene_to_file(next_path)
