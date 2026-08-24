class_name TestDummySpawner
extends Area2D

## A test-room floor spot. Walk up to it and press E (interact) to spawn a target
## dummy exactly at that spot. Each spot holds at most one dummy; once filled it
## stops accepting input. Spots are laid out in a non-overlapping grid by the
## DummyRange arena.

const DUMMY_SCENE: PackedScene = preload("res://src/entities/enemies/dummy_enemy/dummy_enemy.tscn")

var _player_present: bool = false
var _filled: bool = false

@onready var hint_label: Label = get_node_or_null("HintLabel") as Label


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if hint_label:
		hint_label.visible = false
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _player_present or _filled:
		return
	if event.is_action_pressed("interact"):
		_spawn_dummy()
		get_viewport().set_input_as_handled()


func _spawn_dummy() -> void:
	if _filled:
		return
	var dummy: Node2D = DUMMY_SCENE.instantiate()
	if get_tree().current_scene != null:
		get_tree().current_scene.add_child(dummy)
	elif get_parent() != null:
		get_parent().add_child(dummy)
	dummy.global_position = global_position
	_filled = true
	if hint_label:
		hint_label.visible = false
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_present = true
		if hint_label and not _filled:
			hint_label.visible = true
		queue_redraw()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_present = false
		if hint_label:
			hint_label.visible = false
		queue_redraw()


func _draw() -> void:
	var color: Color = Color(0.4, 0.65, 1.0, 0.32) if not _filled else Color(0.45, 0.9, 0.5, 0.32)
	if _player_present and not _filled:
		var f: float = 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.01)
		color = color * Color(f, f, f, 1.0)
	draw_circle(Vector2.ZERO, 34.0, color)
	draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 32, color.lightened(0.35), 2.0)
	if not _filled:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(-6, 5), "+", HORIZONTAL_ALIGNMENT_LEFT, 12, 15, Color(1, 1, 1, 0.9))
