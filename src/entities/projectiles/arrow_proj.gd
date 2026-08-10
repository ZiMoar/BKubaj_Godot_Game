class_name ArrowProj
extends Area2D

## Ranger's primary arrow. Fast, high single-target damage, pierces through
## several enemies before expiring (pierce_total => hits up to pierce_total).
var speed: float = 540.0
var damage: int = 18
var is_critical: bool = false
var source_player: Player = null
var dir: Vector2 = Vector2.RIGHT
var pierce_left: int = 0
var _lifetime: float = 2.0
var _already_hit: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func setup(pos: Vector2, direction: Vector2, arrow_speed: float, dmg: int, crit: bool, player: Player, pierce_total: int = 1) -> void:
	global_position = pos
	dir = direction.normalized()
	speed = arrow_speed
	damage = dmg
	is_critical = crit
	source_player = player
	pierce_left = maxi(0, pierce_total - 1)
	rotation = dir.angle()


func _physics_process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return
	global_position += dir * speed * delta


func _on_body_entered(body: Node2D) -> void:
	_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_hit(area.get_parent())


func _hit(node: Node) -> void:
	if node and node.is_in_group("enemies") and node.has_method("take_damage"):
		var id: int = node.get_instance_id()
		if _already_hit.has(id):
			return
		_already_hit[id] = true
		node.take_damage(damage)
		if source_player and source_player.has_method("apply_lifesteal"):
			source_player.apply_lifesteal()
		if node.has_method("apply_knockback"):
			node.apply_knockback(global_position, 150.0)
		# Keep flying if it still has pierce left; otherwise it's spent.
		if pierce_left > 0:
			pierce_left -= 1
			return
	queue_free()
