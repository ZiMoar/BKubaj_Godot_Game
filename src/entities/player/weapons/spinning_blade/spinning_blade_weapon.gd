extends Weapon

## DEPRECATED. Spin Blade is not offered in the chest's weapon pool (it's been
## set aside, like the gun). The class + scene are kept for future weapon ideas,
## but no live gameplay path picks this weapon. Do not wire it back in without
## a reason — its orbit-aoe design was removed as un-fun / weak by design.

@export var blade_scene: PackedScene
@export var base_damage: int = 22
@export var orbit_speed: float = 3.6
@export var orbit_radius: float = 80.0

var active_blade: Area2D = null
var _current_angle: float = 0.0


func _ready() -> void:
	weapon_name = "Spin Blade"
	trigger_type = TriggerType.AUTOMATIC
	cooldown = 3.0
	super._ready()
	call_deferred("try_fire")


func _physics_process(delta: float) -> void:
	if is_instance_valid(active_blade):
		_current_angle += orbit_speed * delta
		if _current_angle >= TAU:
			_current_angle -= TAU

		var eff_radius: float = orbit_radius * get_area_multiplier()
		var target_pos: Vector2 = global_position + Vector2(cos(_current_angle), sin(_current_angle)) * eff_radius
		active_blade.global_position = target_pos
		active_blade.rotation = _current_angle + PI / 2.0


func fire() -> void:
	if blade_scene == null:
		return

	# Free the previous blade so it doesn't get abandoned / frozen in place
	if is_instance_valid(active_blade):
		active_blade.queue_free()
		active_blade = null

	var attack_damage: int = get_attack_damage(base_damage)
	var is_crit: bool = roll_critical_hit()
	if is_crit:
		attack_damage = int(round(float(attack_damage) * get_critical_multiplier()))

	active_blade = blade_scene.instantiate() as Area2D
	get_tree().current_scene.add_child(active_blade)

	if active_blade.has_method("setup"):
		active_blade.setup(attack_damage, is_crit, get_player(), self)
		active_blade.scale *= get_area_multiplier()
