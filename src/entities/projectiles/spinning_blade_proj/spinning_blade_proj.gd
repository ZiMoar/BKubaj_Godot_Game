class_name SpinningBladeProj
extends Area2D

var damage: int = 18
var is_critical: bool = false
var source_player: Player = null
var _lifetime: float = 5.0

var _recently_hit: Dictionary = {}  # enemy instance_id -> time remaining
const HIT_COOLDOWN: float = 0.3


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func setup(blade_damage: int, crit: bool, player: Player) -> void:
	damage = blade_damage
	is_critical = crit
	source_player = player


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
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		var id: int = body.get_instance_id()
		if _recently_hit.has(id):
			return
		_recently_hit[id] = HIT_COOLDOWN
		body.take_damage(damage)
		if source_player and source_player.has_method("apply_lifesteal"):
			source_player.apply_lifesteal()
		if body.has_method("apply_knockback"):
			body.apply_knockback(global_position, 80.0)


func _on_area_entered(area: Area2D) -> void:
	var parent: Node = area.get_parent()
	if parent and parent.is_in_group("enemies") and parent.has_method("take_damage"):
		var id: int = parent.get_instance_id()
		if _recently_hit.has(id):
			return
		_recently_hit[id] = HIT_COOLDOWN
		parent.take_damage(damage)
		if source_player and source_player.has_method("apply_lifesteal"):
			source_player.apply_lifesteal()
