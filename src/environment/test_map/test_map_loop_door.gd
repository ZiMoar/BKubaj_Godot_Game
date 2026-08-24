class_name TestMapLoopDoor
extends Area2D

## A test-room door that loads a target scene while KEEPING the character's
## progression (captures the run snapshot so the destination scene's player
## restores it). Used to move between the Armory and the training / dummy-range
## rooms without wiping stats, weapons or gold.

@export var target_path: String = ""
@export var door_width: float = 72.0
@export var door_height: float = 104.0
## Short caption drawn under the door (e.g. "TRAIN", "DUMMIES").
@export var caption: String = "ENTER"
@export var frame_color: Color = Color(0.45, 0.6, 0.95)

var is_open: bool = true
var _advancing: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _draw() -> void:
	var half_w: float = door_width * 0.5
	var top: float = -door_height * 0.5
	# Always-open green-tinted frame (test doors are never locked).
	draw_rect(Rect2(-half_w - 7, top - 7, door_width + 14, door_height + 14), frame_color * Color(1, 1, 1, 0.25))
	draw_rect(Rect2(-half_w - 6, top - 6, door_width + 12, 10), frame_color)
	draw_rect(Rect2(-half_w - 6, top, 8, door_height), frame_color)
	draw_rect(Rect2(half_w - 2, top, 8, door_height), frame_color)
	draw_rect(Rect2(-half_w + 4, top + 8, door_width - 8, door_height - 16), Color(0.6, 0.85, 1.0))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, top - 2), Vector2(-9, top - 13), Vector2(9, top - 13),
	]), Color(0.9, 1.0, 1.0, 1.0))
	# Caption under the door.
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-half_w, door_height * 0.5 + 14), caption, HORIZONTAL_ALIGNMENT_LEFT, door_width, 13, frame_color.lightened(0.4))


func _on_body_entered(body: Node2D) -> void:
	if _advancing:
		return
	if not body.is_in_group("player"):
		return
	if target_path.is_empty():
		return
	# Changing the scene inside a physics callback tears down this door (a
	# CollisionObject) mid-step, which Godot forbids. Defer the transition.
	_advancing = true
	call_deferred("_do_transition")


func _do_transition() -> void:
	if not is_instance_valid(self):
		return
	# Preserve the character's progression so the next room's player is restored.
	var run_state: Node = get_node_or_null("/root/GameState")
	if run_state and run_state.has_method("capture_loop_state"):
		var player: Node = get_tree().get_first_node_in_group("player") as Node
		var xp_mgr: Node = get_tree().get_first_node_in_group("team_xp_manager") as Node
		run_state.capture_loop_state(player, xp_mgr)
	if not target_path.is_empty():
		get_tree().change_scene_to_file(target_path)
