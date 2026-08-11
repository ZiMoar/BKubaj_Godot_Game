class_name BossArrow
extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 260.0
var damage: int = 10
var _lifetime: float = 5.0


func _ready() -> void:
	add_to_group("enemy_projectile")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func setup(start_pos: Vector2, dir: Vector2, arrow_speed: float, arrow_damage: int) -> void:
	global_position = start_pos
	direction = dir
	speed = arrow_speed
	damage = arrow_damage
	rotation = dir.angle()


func _physics_process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return
	global_position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var parent: Node = area.get_parent()
	if parent and parent.is_in_group("player") and parent.has_method("take_damage"):
		parent.take_damage(damage)
		queue_free()