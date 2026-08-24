class_name TrainingGround
extends Node2D

## The "Training Ground" test room. Spawns enemies with NO time-based difficulty
## ramp and NO automatic boss. A row of interactable buttons on the floor lets
## the tester raise the difficulty (+1 / +10 / +100), spawn a boss on demand, and
## toggle enemy spawning on/off. A door at the top returns to the Armory.

const BOSS_SCENE: PackedScene = preload("res://src/entities/enemies/bosses/skeleton_general/skeleton_general.tscn")

@onready var diff_1_button: TestControlButton = get_node_or_null("ControlPanel/Diff1") as TestControlButton
@onready var diff_10_button: TestControlButton = get_node_or_null("ControlPanel/Diff10") as TestControlButton
@onready var diff_100_button: TestControlButton = get_node_or_null("ControlPanel/Diff100") as TestControlButton
@onready var boss_button: TestControlButton = get_node_or_null("ControlPanel/BossButton") as TestControlButton
@onready var toggle_button: TestControlButton = get_node_or_null("ControlPanel/ToggleButton") as TestControlButton
@onready var status_label: Label = get_node_or_null("ControlPanel/StatusLabel") as Label

var _spawns_enabled: bool = true


func _ready() -> void:
	# This room must NOT ramp difficulty over time — the buttons are the only
	# source of difficulty here. The player is a child, so it is already ready
	# (and restored from the previous room's snapshot) by the time we run.
	_freeze_time_scaling()
	_connect_buttons()
	_update_status()


func _freeze_time_scaling() -> void:
	var player: Node = _player()
	if player == null:
		return
	# Zero the per-minute ramp rate AND any bonus that accumulated elsewhere, so
	# difficulty reads exactly the button-set base value.
	player.set("difficulty_runtime_per_minute", 0.0)
	player.set("difficulty_runtime_bonus", 0.0)


func _connect_buttons() -> void:
	if diff_1_button:
		diff_1_button.pressed.connect(_on_diff_pressed.bind(1))
	if diff_10_button:
		diff_10_button.pressed.connect(_on_diff_pressed.bind(10))
	if diff_100_button:
		diff_100_button.pressed.connect(_on_diff_pressed.bind(100))
	if boss_button:
		boss_button.pressed.connect(_on_boss_pressed)
	if toggle_button:
		toggle_button.pressed.connect(_on_toggle_pressed)


func _player() -> Node:
	return get_tree().get_first_node_in_group("player") as Node


func _on_diff_pressed(_button: TestControlButton, amount: int) -> void:
	var player: Node = _player()
	if player == null:
		return
	player.set("difficulty", float(player.get("difficulty")) + float(amount))
	_update_status()


func _on_boss_pressed(_button: TestControlButton) -> void:
	_spawn_boss()


func _on_toggle_pressed(_button: TestControlButton) -> void:
	_spawns_enabled = not _spawns_enabled
	for s: Node in get_tree().get_nodes_in_group("regular_spawner"):
		if not is_instance_valid(s):
			continue
		s.set("is_spawning", _spawns_enabled)
		if s.has_node("Timer"):
			var t: Node = s.get_node("Timer")
			if t is Timer:
				if _spawns_enabled:
					t.start()
				else:
					t.stop()
	_update_status()


func _update_status() -> void:
	if status_label == null:
		return
	var diff: float = 0.0
	var player: Node = _player()
	if player and player.has_method("get_map_difficulty"):
		diff = float(player.get_map_difficulty())
	var spawn_state: String = "ON" if _spawns_enabled else "OFF"
	status_label.text = "Difficulty: %d   Enemy spawns: %s" % [int(diff), spawn_state]


func _spawn_boss() -> void:
	var player: Node = _player()
	var pos: Vector2 = (player.global_position + Vector2(0, -320)) if player else Vector2(1100, 300)
	var floor_node := _find_floor_node()
	if floor_node:
		var arena_rect := Rect2(floor_node.arena_center - floor_node.arena_size * 0.5, floor_node.arena_size)
		var margin: float = 60.0
		pos = pos.clamp(arena_rect.position + Vector2(margin, margin), arena_rect.position + arena_rect.size - Vector2(margin, margin))
	# Co-op: spawn the boss through EnemyNet so it is host-authoritative.
	var net: Node = get_node_or_null("/root/Net")
	if net and net.active():
		var enemy_net: Node = get_tree().get_first_node_in_group("enemy_net")
		if enemy_net and enemy_net.has_method("request_spawn"):
			enemy_net.request_spawn(BOSS_SCENE.resource_path, pos)
			return
	var boss: Node2D = BOSS_SCENE.instantiate()
	if get_tree().current_scene != null:
		get_tree().current_scene.add_child(boss)
	elif get_parent() != null:
		get_parent().add_child(boss)
	else:
		add_child(boss)
	boss.global_position = pos


# Walk up from this node to find the arena "Floor" (GridBackground).
func _find_floor_node() -> GridBackground:
	var node: Node = self
	while node != null:
		var floor_node := node.get_node_or_null("Floor") as GridBackground
		if floor_node != null:
			return floor_node
		node = node.get_parent()
	return null
