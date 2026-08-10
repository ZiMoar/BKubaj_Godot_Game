extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_radius: float = 400.0  # Distance away from the player to spawn

@onready var timer: Timer = $Timer

var player: Node2D = null

func _ready() -> void:
	timer.timeout.connect(_on_timer_timeout)

func _on_timer_timeout() -> void:
	if enemy_scene == null:
		print("EnemySpawner ERROR: No enemy_scene assigned in Inspector!")
		return
		
	# Find player if not cached yet
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return # No player alive to spawn near
			
	spawn_enemy()

func spawn_enemy() -> void:
	# Pick a random angle around the player (0 to 360 degrees in radians)
	var random_angle = randf() * TAU
	
	# Calculate offset vector at spawn_radius distance
	var spawn_offset = Vector2(cos(random_angle), sin(random_angle)) * spawn_radius
	var spawn_position = player.global_position + spawn_offset

	# Instantiate enemy and place it in current scene
	var enemy = enemy_scene.instantiate()
	enemy.global_position = spawn_position
	
	get_tree().current_scene.add_child(enemy)
