extends Area2D

@export var speed: float = 500.0
@export var damage: int = 10
@export var lifetime: float = 3.0
@export var knockback_force: float = 12.0

var direction: Vector2 = Vector2.ZERO
var is_critical: bool = false
var source_player: Player = null

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

# Collides with environment walls (StaticBody2D)
func _on_body_entered(body: Node2D) -> void:
	if body is StaticBody2D:
		queue_free()

# Collides with Enemy Hurtbox (Area2D) or Enemy (Node)
func _on_area_entered(area: Area2D) -> void:
	var owner_node = area.get_parent()
	if owner_node.is_in_group("enemies") and owner_node.has_method("take_damage"):
		owner_node.take_damage(damage, is_critical)
		if owner_node.has_method("apply_knockback"):
			owner_node.apply_knockback(global_position, knockback_force)
		if source_player and source_player.has_method("apply_lifesteal"):
			source_player.apply_lifesteal()
		queue_free()
