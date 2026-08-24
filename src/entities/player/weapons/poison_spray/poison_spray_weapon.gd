extends Weapon

## Poison Spray — automatic. Emits a continuous stream of poison over a short
## duration, then stops until the cooldown elapses. The stream deals NO direct
## damage; instead it inflicts the POISON ailment on enemies in the cone,
## guaranteed. Because infliction is guaranteed, the player's AILMENT CHANCE
## boosts the effective hit value (more chance = stronger poison, since the
## ailment can't miss anyway).

const PoisonSprayScene: PackedScene = preload("res://src/entities/projectiles/poison_spray/poison_spray.tscn")

const BASE_HIT_VALUE: int = 12
const SPRAY_DURATION: float = 2.4
const TICK_INTERVAL: float = 0.18
const SPRAY_RANGE: float = 270.0
const HALF_ANGLE: float = 0.22   # narrow cone (~12.6 deg each side)
const COOLDOWN: float = 3.2


func _ready() -> void:
	weapon_name = "Poison Spray"
	trigger_type = TriggerType.AUTOMATIC
	cooldown = COOLDOWN
	damage_type = DamageType.Type.POISON
	super._ready()
	call_deferred("try_fire")


func supports_area() -> bool:
	return true

func supports_duration() -> bool:
	return true

## Poison Spray deals no direct damage — it only inflicts the POISON ailment, and
## ailments "kill" on their own tick (not via this weapon's damage). An on-kill
## explosion would never fire, so it's excluded from the anvil's Explosion on Kill.
func supports_explosion_on_kill() -> bool:
	return false


## Poison Spray's signature upgrades (granted by the rare golden anvil).
func get_signature_pool() -> Array[Dictionary]:
	return [
		{
			"id": "twin_spray",
			"title": "Twin Spray",
			"description": "The spray also emits in the opposite direction, hitting enemies behind you.",
			"value": 1,
			"apply": func(_w: Weapon) -> void: pass,
		},
		{
			"id": "stinging_gas",
			"title": "Stinging Gas",
			"description": "The spray's waves now deal direct poison damage on top of applying the ailment.",
			"value": 1,
			"apply": func(_w: Weapon) -> void: pass,
		},
		{
			"id": "corrosive",
			"title": "Corrosive",
			"description": "Poisoned enemies take +15% damage from all sources.",
			"value": 15,
			"apply": func(_w: Weapon) -> void: pass,
		},
	]


func fire() -> void:
	var player := get_player()
	var hit_value: int = get_attack_damage(BASE_HIT_VALUE)
	if player and player.has_method("get"):
		# Ailment chance -> damage, since poison infliction is guaranteed.
		var chance: float = maxf(0.0, float(player.get("ailment_chance")))
		hit_value = maxi(1, int(round(float(hit_value) * (1.0 + chance))))

	var spray: Node = PoisonSprayScene.instantiate()
	spray.name = "PoisonSpray"
	spray.global_position = global_position
	if spray.has_method("setup"):
		spray.setup(
			self,
			hit_value,
			get_effective_duration(SPRAY_DURATION),
			TICK_INTERVAL,
			SPRAY_RANGE * get_area_multiplier(),
			HALF_ANGLE
		)
	get_tree().current_scene.add_child(spray)
	var _pl: Node = get_player()
	sync_effect(spray, PoisonSprayScene, {
		"dur": get_effective_duration(SPRAY_DURATION),
		"interval": TICK_INTERVAL,
		"rng": SPRAY_RANGE * get_area_multiplier(),
		"half_angle": HALF_ANGLE,
		"val": hit_value,
		"player_name": str(_pl.name) if _pl else "",
	})


func _nearest_enemy_dir() -> Vector2:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var best_d: float = INF
	for e: Node in enemies:
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		var d: float = global_position.distance_squared_to(en.global_position)
		if d < best_d:
			best_d = d
			nearest = en
	if nearest != null:
		return (nearest.global_position - global_position).normalized()
	return Vector2.RIGHT
