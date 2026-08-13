class_name SpinningBladeProj
extends Area2D

var damage: int = 18
var is_critical: bool = false
var source_player: Player = null
var source_weapon: Node = null
var _lifetime: float = 5.0

var _recently_hit: Dictionary = {}  # enemy instance_id -> time remaining
const HIT_COOLDOWN: float = 0.3


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func setup(blade_damage: int, crit: bool, player: Player, weapon: Node = null) -> void:
	damage = blade_damage
	is_critical = crit
	source_player = player
	source_weapon = weapon


func _physics_process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return

	# Decrement hit cooldowns
	var expired: Array = []
	for id: int in _recently_hit:
		_recently_hit[id] = _recently_hit[id] - delta
		if _recently_hit[id] <= 0.0:
			expired.append(id)
	for id: int in expired:
		_recently_hit.erase(id)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") or (body.is_in_group("destructibles") and body.has_method("take_damage")):
		var id: int = body.get_instance_id()
		if _recently_hit.has(id):
			return
		_recently_hit[id] = HIT_COOLDOWN
		body.take_damage(damage)
		if source_player and source_player.has_method("apply_lifesteal"):
			source_player.apply_lifesteal()
		if body.has_method("apply_knockback"):
			body.apply_knockback(global_position, 80.0)
		if source_weapon and body.is_in_group("enemies"):
			source_weapon.apply_status_on_hit(body, damage)
			if body.has_method("has_died") and body.has_died():
				source_weapon.apply_explosion_on_kill(global_position, damage)


func _on_area_entered(area: Area2D) -> void:
	var parent: Node = area.get_parent()
	if parent and (parent.is_in_group("enemies") or parent.is_in_group("destructibles")) and parent.has_method("take_damage"):
		var id: int = parent.get_instance_id()
		if _recently_hit.has(id):
			return
		_recently_hit[id] = HIT_COOLDOWN
		parent.take_damage(damage)
		if source_player and source_player.has_method("apply_lifesteal"):
			source_player.apply_lifesteal()
		if source_weapon and parent.is_in_group("enemies"):
			source_weapon.apply_status_on_hit(parent, damage)
			if parent.has_method("has_died") and parent.has_died():
				source_weapon.apply_explosion_on_kill(global_position, damage)
