extends Weapon

## DEPRECATED. The Pistol is not offered anywhere (it's a generic starter-class
## primary that predates the three specialized class builds). The class + scene
## are kept for future weapon ideas, but no live gameplay path picks this weapon.
## Do not wire it back in without a reason.

@export var bullet_scene: PackedScene
@export var knockback_force: float = 14.0
@export var damage: int = 6

func _ready() -> void:
	weapon_name = "Pistol"
	trigger_type = TriggerType.PRIMARY
	cooldown = 0.15
	super._ready()

func fire() -> void:
	if bullet_scene == null:
		return
		
	var bullet = bullet_scene.instantiate()
	var bullet_damage = get_attack_damage(damage)
	var bullet_is_critical = roll_critical_hit()
	if bullet_is_critical:
		bullet_damage = int(round(float(bullet_damage) * get_critical_multiplier()))
		
	bullet.global_position = global_position
	bullet.direction = (get_global_mouse_position() - global_position).normalized()
	bullet.rotation = bullet.direction.angle()
	bullet.damage = bullet_damage
	bullet.is_critical = bullet_is_critical
	bullet.knockback_force = knockback_force
	bullet.source_player = get_player()
	
	get_tree().current_scene.add_child(bullet)
