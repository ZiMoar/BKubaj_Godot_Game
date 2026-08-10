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
	super._ready()

	if aura_shape and aura_shape.shape is CircleShape2D:
		(aura_shape.shape as CircleShape2D).radius = aura_radius

	if aura_visual:
		aura_visual.set_radius(aura_radius)

	aura_area.body_entered.connect(_on_body_entered)
	aura_area.area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	# Keep aura centered on the player's world position
	aura_area.global_position = global_position

	_pulse_timer -= delta
	if _pulse_timer <= 0.0:
		_pulse_timer = _pulse_interval
		_apply_pulse_damage()


func _apply_pulse_damage() -> void:
	if aura_visual:
		aura_visual.pulse()

	var final_damage: int = get_attack_damage(base_damage)
	var is_crit: bool = roll_critical_hit()
	if is_crit:
		final_damage = int(round(float(final_damage) * get_critical_multiplier()))

	# Deduplicate so each enemy only gets hit once per pulse (bodies + hitbox areas overlap)
	var hit_this_pulse: Dictionary = {}  # enemy instance_id -> true

	for body: Node2D in aura_area.get_overlapping_bodies():
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			var body_id: int = body.get_instance_id()
			if hit_this_pulse.has(body_id):
				continue
			hit_this_pulse[body_id] = true
			body.take_damage(final_damage)
			apply_lifesteal()

	for area: Area2D in aura_area.get_overlapping_areas():
		var parent: Node = area.get_parent()
		if parent and parent.is_in_group("enemies") and parent.has_method("take_damage"):
			var parent_id: int = parent.get_instance_id()
			if hit_this_pulse.has(parent_id):
				continue
			hit_this_pulse[parent_id] = true
			parent.take_damage(final_damage)
			apply_lifesteal()


func _on_body_entered(_body: Node2D) -> void:
	pass


func _on_area_entered(_area: Area2D) -> void:
	pass


func fire() -> void:
	# Aura is always active via _physics_process; fire is a no-op pulse
	pass
