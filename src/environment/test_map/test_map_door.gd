class_name TestStageDoor
extends Area2D

## A test-map door that is open from the very start (no boss needed) and, when the
## player walks into it, reloads a fresh instance of the same map — handy for
## testing stage-carry-over / loop behavior without waiting for a boss.

@export var self_path: String = "res://src/environment/test_map/test_map_arena.tscn"
@export var door_width: float = 72.0
@export var door_height: float = 104.0

var is_open: bool = true
var _advancing: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	_set_collision_enabled(true)
	queue_redraw()


func _set_collision_enabled(enabled: bool) -> void:
	var shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape:
		shape.disabled = not enabled


func _draw() -> void:
	var half_w: float = door_width * 0.5
	var top: float = -door_height * 0.5
	var frame := Color(0.3, 0.85, 0.4)
	draw_rect(Rect2(-half_w - 7, top - 7, door_width + 14, door_height + 14), Color(0.3, 0.85, 0.4, 0.25))
	draw_rect(Rect2(-half_w - 6, top - 6, door_width + 12, 10), frame)
	draw_rect(Rect2(-half_w - 6, top, 8, door_height), frame)
	draw_rect(Rect2(half_w - 2, top, 8, door_height), frame)
	draw_rect(Rect2(-half_w + 4, top + 8, door_width - 8, door_height - 16), Color(0.6, 0.95, 0.5))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, top - 2), Vector2(-9, top - 13), Vector2(9, top - 13),
	]), Color(0.9, 1.0, 0.8, 1.0))
	# "LOOP" hint text under the door.
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-30, door_height * 0.5 + 14), "LOOP", HORIZONTAL_ALIGNMENT_LEFT, 60, 13, Color(0.9, 1.0, 0.8))


func _on_body_entered(body: Node2D) -> void:
	if not is_open or _advancing:
		return
	if not body.is_in_group("player"):
		return
	if self_path.is_empty():
		return
	# Changing the scene inside a physics callback would tear down this door (a
	# CollisionObject) mid-step, which Godot forbids. Defer the whole transition.
	_advancing = true
	call_deferred("_do_advance")


func _do_advance() -> void:
	# Carry over progression (level, weapons, gold, XP, artefacts) so the fresh
	# instance of the map does NOT reset the character — same as real maps.
	var run_state: Node = get_node_or_null("/root/GameState")
	if run_state and run_state.has_method("capture_loop_state"):
		var player: Node = get_tree().get_first_node_in_group("player")
		var xp_mgr: Node = get_tree().get_first_node_in_group("team_xp_manager")
		run_state.capture_loop_state(player, xp_mgr)
	if not self_path.is_empty():
		get_tree().change_scene_to_file(self_path)
