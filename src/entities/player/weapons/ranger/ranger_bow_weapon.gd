extends Weapon

## Ranger primary weapon: a Longbow. Slower than the Pistol but fires a
## piercing arrow (up to piertotal enemies) for roughly the same DPS.
@export var arrow_scene: PackedScene
@export var damage: int = 18
@export var arrow_speed: float = 540.0
@export var pierce_total: int = 6


func _ready() -> void:
	weapon_name = "Longbow"
	trigger_type = TriggerType.PRIMARY
	cooldown = 0.45
	super._ready()


func fire() -> void:
	if arrow_scene == null:
		return

	var arrow = arrow_scene.instantiate()
	var arrow_damage: int = get_attack_damage(damage)
	var arrow_is_critical: bool = roll_critical_hit()
	if arrow_is_critical:
		arrow_damage = int(round(float(arrow_damage) * get_critical_multiplier()))

	var dir: Vector2 = (get_global_mouse_position() - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	if arrow.has_method("setup"):
		arrow.setup(global_position, dir, arrow_speed, arrow_damage, arrow_is_critical, get_player(), pierce_total)
	get_tree().current_scene.add_child(arrow)
