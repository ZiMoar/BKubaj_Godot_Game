extends Weapon

## Radiant Barrier — automatic. Grants the player a holy barrier that absorbs the
## next hit taken (reducing it to 0) and, when struck, releases a local wave of
## HOLY damage. Re-arms on its cooldown. The barrier registers itself in the
## "radiant_barrier" group so the player's take_damage can hand it the hit.

const ExplosionEffectScene: PackedScene = preload("res://src/effects/explosion_effect/explosion_effect.tscn")

const BLOCK_FULL: bool = true   # barrier fully absorbs the next hit

const COOLDOWN: float = 7.0
const BARRIER_DURATION: float = 3.0   # how long the barrier waits for a hit
const WAVE_DAMAGE: int = 40
const WAVE_RADIUS: float = 130.0
const WAVE_KNOCKBACK: float = 120.0

var _barrier_active: bool = false
var _barrier_timer: float = 0.0
var _wave_pulse: float = 0.0   # cosmetic expanding flash after a block


func _ready() -> void:
	weapon_name = "Radiant Barrier"
	trigger_type = TriggerType.AUTOMATIC
	cooldown = COOLDOWN
	damage_type = DamageType.Type.HOLY
	super._ready()
	add_to_group("radiant_barrier")
	call_deferred("try_fire")

func supports_area() -> bool:
	return true


## Radiant Barrier's signature upgrades (granted by the rare golden anvil).
func get_signature_pool() -> Array[Dictionary]:
	return [
		{
			"id": "righteous_rebound",
			"title": "Righteous Rebound",
			"description": "The holy wave's damage scales with the damage the barrier blocked.",
			"value": 100,
			"apply": func(_w: Weapon) -> void: pass,
		},
		{
			"id": "condemn",
			"title": "Condemn",
			"description": "Your holy wave always brands enemies, and deals +20% damage if it is holy-aligned.",
			"value": 20,
			"apply": func(_w: Weapon) -> void: pass,
		},
		{
			"id": "blessed_shield",
			"title": "Blessed Shield",
			"description": "While the barrier is active you deal +25% damage.",
			"value": 25,
			"apply": func(_w: Weapon) -> void: pass,
		},
	]


const REBOUND_BLOCK_MULT: float = 1.5   # Righteous Rebound: +150% of blocked dmg to the wave


func fire() -> void:
	_activate_barrier()


func _activate_barrier() -> void:
	_barrier_active = true
	_barrier_timer = get_effective_duration(BARRIER_DURATION)
	queue_redraw()


func _physics_process(delta: float) -> void:
	# Blessed Shield: keep the player's damage buff in sync while the barrier is up.
	var blessed: bool = has_signature("blessed_shield")
	var player: Node = get_player()
	if player != null:
		player.blessed_shield_mult = 1.25 if (blessed and _barrier_active) else 1.0
	if _barrier_active:
		_barrier_timer -= delta
		if _barrier_timer <= 0.0:
			_barrier_active = false
			queue_redraw()
	if _wave_pulse > 0.0:
		_wave_pulse = maxf(0.0, _wave_pulse - delta)
		queue_redraw()


## Called by the player's take_damage when this barrier is in the group. Returns
## the damage that still gets through (0 when blocked). Any hit while active is
## consumed — including a 0-damage "ghost" hit (e.g. the test dummy), so the
## shield drops on the first contact, not the second. Only the first active
## barrier that blocks consumes the hit.
func block_hit(amount: int) -> int:
	if not _barrier_active:
		return amount
	# Absorb this hit fully (even a 0-damage ghost hit) and release a holy wave.
	_barrier_active = false
	_wave_pulse = 0.35
	_release_holy_wave(amount)
	return 0


func _release_holy_wave(blocked_damage: int) -> void:
	var wave_dmg: int = get_attack_damage(WAVE_DAMAGE)
	# Righteous Rebound: amplify the wave with the blocked amount much harder.
	if has_signature("righteous_rebound"):
		wave_dmg += int(round(float(blocked_damage) * REBOUND_BLOCK_MULT))
	else:
		# Stronger barriers scale the wave a bit with the blocked amount too.
		wave_dmg += int(round(float(blocked_damage) * 0.25))
	# Condemn: bonus damage if the barrier is holy-aligned.
	if has_signature("condemn") and damage_type == DamageType.Type.HOLY:
		wave_dmg = int(round(float(wave_dmg) * 1.2))
	var origin: Vector2 = global_position
	var eff_radius: float = WAVE_RADIUS * get_area_multiplier()

	var targets: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for d: Node in get_tree().get_nodes_in_group("destructibles"):
		targets.append(d)
	for e: Node in targets:
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if origin.distance_to(en.global_position) <= eff_radius:
			en.take_damage(wave_dmg, false, damage_type, false, get_ailment_effect_multiplier())
			# Condemn: always brand enemies, regardless of element.
			if has_signature("condemn") and en.has_method("apply_brand"):
				en.apply_brand()
			apply_lifesteal()
			if en.has_method("apply_knockback"):
				en.apply_knockback(origin, get_knockback(WAVE_KNOCKBACK))
			if en.is_in_group("enemies") and en.has_method("has_died") and en.has_died():
				apply_explosion_on_kill(en.global_position, wave_dmg)

	# Expanding-ring explosion visual so the block is unmistakable (bigger +
	# brighter than the base explosion so it reads clearly on the grid floor).
	if is_instance_valid(self) and get_tree() and get_tree().current_scene:
		var fx: Node2D = ExplosionEffectScript.new()
		fx.name = "RadiantWaveFX"
		fx.global_position = origin
		fx.set("max_radius", eff_radius * 1.2)
		fx.set("color", Color(1.0, 0.9, 0.5, 1.0))
		fx.set("_duration", 0.5)
		get_tree().current_scene.add_child(fx)
		# Co-op: broadcast the wave so the other player sees the barrier pop.
		var net: Node = get_node_or_null("/root/Net")
		if net and net.has_method("sync_player_effect"):
			net.sync_player_effect(fx, ExplosionEffectScene, {
				"max_radius": eff_radius * 1.2,
				"color": Color(1.0, 0.9, 0.5, 1.0),
				"_duration": 0.5,
			})
		# Second, inner bright flash that fills and fades even faster.
		var fx2: Node2D = ExplosionEffectScript.new()
		fx2.name = "RadiantFlashFX"
		fx2.global_position = origin
		fx2.set("max_radius", eff_radius * 0.7)
		fx2.set("color", Color(1.0, 1.0, 0.85, 1.0))
		fx2.set("_duration", 0.25)
		get_tree().current_scene.add_child(fx2)
		if net and net.has_method("sync_player_effect"):
			net.sync_player_effect(fx2, ExplosionEffectScene, {
				"max_radius": eff_radius * 0.7,
				"color": Color(1.0, 1.0, 0.85, 1.0),
				"_duration": 0.25,
			})


func _draw() -> void:
	if _barrier_active:
		# Holy glow ring around the player while the barrier is up.
		var a: float = 0.75
		var pulse_a: float = 0.5 + 0.3 * sin(Time.get_ticks_msec() * 0.01)
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 40, Color(1.0, 0.95, 0.7, a), 3.0)
		draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 40, Color(1.0, 0.95, 0.7, pulse_a), 1.5)
	if _wave_pulse > 0.0:
		var t: float = 1.0 - (_wave_pulse / 0.35)
		draw_arc(Vector2.ZERO, 22.0 + t * 60.0, 0.0, TAU, 40, Color(1.0, 0.9, 0.6, (1.0 - t) * 0.8), 3.0)
