class_name ChromaticBolt
extends Area2D

## A bolt launched by a Chromatic Orb. Flies in a fixed direction toward the
## enemy the orb targeted and deals damage of a random (per-bolt) damage type.

var damage: int = 14
var is_critical: bool = false
var speed: float = 340.0
var dir: Vector2 = Vector2.RIGHT
var source_player: Node = null
var source_weapon: Node = null
var damage_type: DamageType.Type = DamageType.Type.PHYSICAL
var _lifetime: float = 1.5


func _ready() -> void:
	body_entered.connect(_on_hit)
	area_entered.connect(_on_hit_area)


func setup(pos: Vector2, direction: Vector2, bolt_speed: float, dmg: int, crit: bool, player: Node, weapon: Node, dtype: DamageType.Type) -> void:
	global_position = pos
	dir = direction.normalized()
	speed = bolt_speed
	damage = dmg
	is_critical = crit
	source_player = player
	source_weapon = weapon
	damage_type = dtype
	rotation = dir.angle()


func _physics_process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return
	global_position += dir * speed * delta


func _on_hit(body: Node2D) -> void:
	_hit(body)


func _on_hit_area(area: Area2D) -> void:
	_hit(area.get_parent())


func _hit(node: Node) -> void:
	if node and (node.is_in_group("enemies") or node.is_in_group("destructibles")) and node.has_method("take_damage"):
		var dealt: int = damage
		# Ailment Resonance: the bolt deals extra damage for each distinct ailment
		# already active on the enemy (+20% each).
		if source_weapon and source_weapon.has_method("has_signature") and source_weapon.has_signature("ailment_resonance") \
				and node.has_method("count_active_ailments"):
			var ailments: int = node.count_active_ailments()
			if ailments > 0:
				dealt += int(round(float(dealt) * 0.20 * float(ailments)))
		node.take_damage(dealt, is_critical, damage_type)
		if source_player and source_player.has_method("apply_lifesteal"):
			source_player.apply_lifesteal()
		if source_weapon and node.is_in_group("enemies"):
			if node.has_method("has_died") and node.has_died():
				source_weapon.apply_explosion_on_kill(global_position, dealt)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.0, Color(1.0, 1.0, 1.0, 0.9))
	draw_line(Vector2.ZERO, -dir * 6.0, Color(0.9, 0.8, 1.0, 0.6), 1.5)
