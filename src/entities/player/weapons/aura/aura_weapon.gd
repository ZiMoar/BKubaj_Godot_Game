extends Weapon

@export var aura_radius: float = 72.0
@export var base_damage: int = 6

@onready var aura_area: Area2D = $AuraArea
@onready var aura_shape: CollisionShape2D = $AuraArea/CollisionShape2D
@onready var aura_visual: AuraVisual = $AuraVisual

var _pulse_timer: float = 0.0
var _pulse_interval: float = 0.4


func _ready() -> void:
	weapon_name = "Fire Aura"
	trigger_type = TriggerType.AUTOMATIC
	cooldown = 1.0
	damage_type = DamageType.Type.FIRE
	super._ready()

	aura_area.body_entered.connect(_on_body_entered)
	aura_area.area_entered.connect(_on_area_entered)
	_apply_area_radius()


func _physics_process(delta: float) -> void:
	# Keep aura centered on the player's world position
	aura_area.global_position = global_position

	# Area stat can change mid-run (upgrades), so refresh the radius each frame.
	_apply_area_radius()

	_pulse_timer -= delta
	if _pulse_timer <= 0.0:
		_pulse_timer = _pulse_interval
		_apply_pulse_damage()


func _apply_area_radius() -> void:
	var eff_radius: float = aura_radius * get_area_multiplier()
	if aura_shape and aura_shape.shape is CircleShape2D:
		(aura_shape.shape as CircleShape2D).radius = eff_radius
	if aura_visual and aura_visual.has_method("set_radius"):
		aura_visual.set_radius(eff_radius)


func supports_range_damage() -> bool:
	return true


## Fire Aura's signature upgrades (granted by the rare golden anvil).
func get_signature_pool() -> Array[Dictionary]:
	return [
		{
			"id": "righteous_fire",
			"title": "Righteous Fire",
			"description": "Aura deals extra damage equal to 5% of your max HP, but burns you with each pulse.",
			"value": 5,
			"apply": func(_w: Weapon) -> void: pass,
		},
	]


func _apply_pulse_damage() -> void:
	if aura_visual:
		aura_visual.pulse()

	var final_damage: int = get_attack_damage(base_damage)
	var is_crit: bool = roll_critical_hit()
	if is_crit:
		final_damage = int(round(float(final_damage) * get_critical_multiplier()))

	# Righteous Fire: the aura deals extra damage equal to a % of the player's
	# max HP, but burns the player too with each pulse.
	if has_signature("righteous_fire"):
		var player: Node = get_player()
		if player and player.has_method("current_max_health"):
			var extra: int = int(round(float(player.current_max_health()) * 0.05))
			final_damage += extra
			# Self-burn: the player eats the same amount each pulse (channeled
			# through the player's own take_damage, so their armor/shield mitigate
			# it like any other damage). Skip while invincible.
			if not (player.get("is_invincible") == true):
				player.take_damage(maxi(1, extra), self)

	# Deduplicate so each enemy only gets hit once per pulse (bodies + hitbox areas overlap)
	var hit_this_pulse: Dictionary = {}  # enemy instance_id -> true

	for body: Node2D in aura_area.get_overlapping_bodies():
		if body.is_in_group("enemies") or (body.is_in_group("destructibles") and body.has_method("take_damage")):
			var body_id: int = body.get_instance_id()
			if hit_this_pulse.has(body_id):
				continue
			hit_this_pulse[body_id] = true
			body.take_damage(final_damage, false, damage_type)
			apply_lifesteal()
			if body.is_in_group("enemies"):
				if body.has_method("has_died") and body.has_died():
					apply_explosion_on_kill(body.global_position, final_damage)

	for area: Area2D in aura_area.get_overlapping_areas():
		var parent: Node = area.get_parent()
		if parent and (parent.is_in_group("enemies") or parent.is_in_group("destructibles")) and parent.has_method("take_damage"):
			var parent_id: int = parent.get_instance_id()
			if hit_this_pulse.has(parent_id):
				continue
			hit_this_pulse[parent_id] = true
			parent.take_damage(final_damage, false, damage_type)
			apply_lifesteal()
			if parent.is_in_group("enemies"):
				if parent.has_method("has_died") and parent.has_died():
					apply_explosion_on_kill(parent.global_position, final_damage)


func _on_body_entered(_body: Node2D) -> void:
	pass


func _on_area_entered(_area: Area2D) -> void:
	pass


func fire() -> void:
	# Aura pulses continuously via _physics_process. Repeat works by firing an
	# extra immediate burst here each time the weapon's volley triggers (one
	# extra full-radius pulse per repeat), so a repeat-upgraded aura clearly
	# dishes out more damage alongside its steady ticking.
	_apply_pulse_damage()
