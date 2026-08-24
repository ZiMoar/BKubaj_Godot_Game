class_name TestControlButton
extends Area2D

## A test-room interactable button. Walk up to it and press E (the "interact"
## action) to trigger it. Emits `pressed` so an arena controller script decides
## what the button actually does. Draws a small glowing panel with a caption and
## shows an "E" hint while a player is standing on it.

signal pressed(button: TestControlButton)

@export var label_text: String = "Button"
@export var color: Color = Color(0.55, 0.75, 1.0)

var _player_present: bool = false

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
	if not _player_present:
		return
	if event.is_action_pressed("interact"):
		pressed.emit(self)
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_present = true
		if hint_label:
			hint_label.visible = true
		queue_redraw()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_present = false
		if hint_label:
			hint_label.visible = false
		queue_redraw()


func _draw() -> void:
	var half_w: float = 58.0
	var half_h: float = 22.0
	var flash: float = 1.0 if not _player_present else (0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.01))
	draw_rect(Rect2(-half_w, -half_h, half_w * 2.0, half_h * 2.0), Color(0.18, 0.18, 0.22))
	draw_rect(Rect2(-half_w + 3, -half_h + 3, half_w * 2.0 - 6, half_h * 2.0 - 6), color * flash)
	draw_rect(Rect2(-half_w + 3, -half_h + 3, half_w * 2.0 - 6, half_h * 2.0 - 6), Color(0, 0, 0, 0.25), false, 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-half_w + 6, 4), label_text, HORIZONTAL_ALIGNMENT_LEFT, half_w * 2.0 - 12, 13, Color.WHITE)
