class_name Turret
extends Node2D

## The Engineer's placed turret. For its lifetime it periodically lobs a grenade
## at the nearest enemy, and that grenade explodes at the spot where the enemy was
## when the turret fired (it homes onto that fixed point, not the moving enemy).
## It inherits the Grenade Launcher's stats (damage, area, crit, projectile count,
## explosion) by reading them off the source grenade weapon each shot.

var grenade_scene: PackedScene
var fire_interval: float = 0.9
var lifetime: float = 6.0
var source_player: Node = null
## The grenade weapon whose stats this turret inherits.
var source_grenade_weapon: Weapon = null
var throw_speed: float = 360.0

var _time: float = 0.0
var _fire_t: float = 0.0
## Sapper: counts shots so every 3rd is a charged double-damage grenade.
var _shots: int = 0


func setup(gscene: PackedScene, interval: float, life: float, player: Node, grenade_weapon: Weapon, speed: float) -> void:
	grenade_scene = gscene
	fire_interval = maxf(0.1, interval)
	lifetime = life
	source_player = player
	source_grenade_weapon = grenade_weapon
	throw_speed = speed
	_fire_t = 0.4
	add_to_group("turrets")


func _physics_process(delta: float) -> void:
	_time += delta
	if _time >= lifetime:
		queue_free()
		return
	_fire_t -= delta
	if _fire_t <= 0.0:
		_fire_t = fire_interval
		_fire_at_nearest()


func _fire_at_nearest() -> void:
	var target: Node2D = _nearest_enemy()
	if target == null or source_grenade_weapon == null:
		return
	var dir: Vector2 = (target.global_position - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	# The grenade's target is the enemy's position AT THE MOMENT OF FIRING — the
	# grenade explodes at that fixed spot even if the enemy has moved.
	var aim_pos: Vector2 = target.global_position

	# Inherit the grenade launcher's computed stats.
	var dmg: int = source_grenade_weapon.get_attack_damage(source_grenade_weapon.damage)
	var crit: bool = source_grenade_weapon.roll_critical_hit()
	if crit:
		dmg = int(round(float(dmg) * source_grenade_weapon.get_critical_multiplier()))
	var radius: float = source_grenade_weapon.blast_radius * source_grenade_weapon.get_area_multiplier()

	# Fire a volley matching the Grenade Launcher's projectile-count upgrade. Each
	# grenade targets the enemy's position at the moment of firing.
	var volley: int = source_grenade_weapon.get_effective_projectile_count(1)
	# Sapper (engineer ascension): every 3rd shot is a charged double-damage grenade.
	var sapper: bool = source_player != null and source_player.has_method("is_subclass") and source_player.is_subclass("sapper")
	if sapper:
		_shots += 1
	var shot_dmg: int = dmg
	if sapper and _shots % 3 == 0:
		shot_dmg = int(round(float(dmg) * 2.0))
	for i in range(volley):
		var grenade: Node = grenade_scene.instantiate()
		grenade.name = "TurretGrenade"
		grenade.global_position = global_position + dir * 8.0
		if grenade.has_method("setup"):
			grenade.setup(grenade.global_position, aim_pos, throw_speed, shot_dmg, crit, radius, source_player, source_grenade_weapon)
		get_tree().current_scene.add_child(grenade)


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		var d: float = global_position.distance_squared_to(en.global_position)
		if d < best_d:
			best_d = d
			best = en
	return best


func _draw() -> void:
	# A small turret: a base, a body, and a barrel.
	draw_circle(Vector2(0, 3), 7.0, Color(0.3, 0.3, 0.34))
	draw_circle(Vector2(0, 3), 5.0, Color(0.45, 0.45, 0.5))
	draw_rect(Rect2(-2.0, -6.0, 4.0, 10.0), Color(0.35, 0.35, 0.4))
	# Little red target light that blinks as it aims.
	var blink: float = 0.5 + 0.5 * sin(_time * 8.0)
	draw_circle(Vector2(0, 1), 1.8, Color(1.0, 0.2, 0.2, 0.5 + blink * 0.5))
