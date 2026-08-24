class_name Weapon
extends Node2D

const ExplosionEffectScript: Script = preload("res://src/effects/explosion_effect/explosion_effect.gd")

signal cooldown_started(duration: float)
signal cooldown_ended()

enum TriggerType {
	PRIMARY,   # Left Click
	SECONDARY, # Right Click / Space
	AUTOMATIC  # Fires on cooldown continuously
}

@export var weapon_name: String = "Base Weapon"
@export var trigger_type: TriggerType = TriggerType.AUTOMATIC
@export var cooldown: float = 1.0
@export var icon_texture: Texture2D
## Elemental type of the damage this weapon deals. Defaults to PHYSICAL; elemental
## weapons (fire aura, lightning, frost nova, arcane bolts) override this in _ready().
## A future ailment system will key status effects off this type.
@export var damage_type: DamageType.Type = DamageType.Type.PHYSICAL

var cooldown_timer: Timer
var can_fire: bool = true
var base_cooldown: float = 1.0

## The Player that owns this weapon, resolved at _ready by walking up the tree.
## Used to gate firing in co-op: only the player that actually OWNS the weapon
## (the network authority) may fire it — otherwise every machine's copy of a
## remote player's weapons would sneak out one stray volley from their initial
## deferred try_fire and then sit silent, looking like "automatic weapons fire
## once then stop."
var autofire_owner: Player = null

# Per-weapon stat bonuses granted by the Anvil. These are independent of the
# player's global stats, so each weapon scales on its own.
var projectile_count_bonus: int = 0
## Extra-projectile chance granted by anvil "Projectile Count" upgrades (each
## adds +25%). Repeat-style: every full 100% is one guaranteed extra projectile,
## the leftover percent is a chance of one more.
var projectile_extra_chance: float = 0.0
var pierce_bonus: int = 0
var chain_count_bonus: int = 0
var area_bonus: float = 0.0
## Repeat chance (anvil upgrades add +25% each). Each full 100% guarantees one
## extra volley; the leftover percent is a chance to fire one more. E.g. 125%
## = 100% chance of 1 extra volley + 25% chance of a 2nd extra.
var repeat_chance: float = 0.0
## Number of anvil upgrades this weapon has taken this run. Drives the anvil's
## anti-stacking gate: a weapon may only be upgraded past a multiple of 3 once
## EVERY weapon the player owns has at least that many upgrades.
var anvil_upgrade_count: int = 0
var projectile_speed_bonus: float = 0.0  # fractional (+0.5 = +50% speed)
var duration_bonus: float = 0.0          # fractional; negative = shorter durations (-0.2 = 20% shorter)
var close_range_damage_bonus: float = 0.0  # dmg mult in the closest third of reach
var far_range_damage_bonus: float = 0.0    # dmg mult beyond two-thirds of reach
var explosion_on_kill_chance: float = 0.0  # chance a kill triggers an AOE
var explosion_radius: float = 95.0
var explosion_damage_ratio: float = 0.6    # as a fraction of the killing hit
## Flat multiplicative damage bonus (e.g. inverted anvil "Fewer Projectiles"
## compensates with +25% damage each projectile removed).
var damage_percent_bonus: float = 0.0
## Pushback applied to enemies on this weapon's hits (+0.5 = +50% knockback).
var knockback_bonus: float = 0.0
## Boosts the potency of the ailments this weapon's hits inflict (burn/poison/
## impale damage, slow strength, shock bounce), independent of ailment CHANCE.
var ailment_effect_bonus: float = 0.0

## Signature upgrades this weapon has taken this run (each once). Signatures are
## transformative per-weapon upgrades granted by the (rare) golden anvil, and can
## also rarely roll from normal anvils at a reduced weight.
var signature_ids: Array[String] = []

func _ready() -> void:
	base_cooldown = cooldown
	# Check if a CooldownTimer child already exists; if not, create one safely
	cooldown_timer = get_node_or_null("CooldownTimer") as Timer
	if cooldown_timer == null:
		cooldown_timer = Timer.new()
		cooldown_timer.name = "CooldownTimer"
		add_child(cooldown_timer)
		
	cooldown_timer.wait_time = base_cooldown
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(_on_cooldown_finished)
	autofire_owner = _find_owner_player()

func try_fire() -> void:
	if not _may_autofire():
		return
	if can_fire:
		_fire_with_repeat()
		can_fire = false
		var effective_cooldown = get_effective_cooldown()
		cooldown_timer.start(effective_cooldown)
		cooldown_started.emit(effective_cooldown)
		# Blood Mage (mage ascension): casting during Mana Overload costs HP.
		var owner_plr: Node = _find_owner_player()
		if owner_plr and owner_plr.has_method("is_subclass") and owner_plr.is_subclass("blood_mage") and owner_plr.has_method("is_overload_active") and owner_plr.is_overload_active():
			owner_plr.drain_overload_cost()

## The Player ancestor of this weapon (walks up the tree). Null when the weapon
## isn't parented under a Player (e.g. developer/isolated scenes).
func _find_owner_player() -> Player:
	var n: Node = get_parent()
	while n != null:
		if n is Player:
			return n as Player
		n = n.get_parent()
	return null

## True when this weapon is allowed to fire. Single-player (no live network peer)
## always fires; in co-op only the owning player may fire, so remote players'
## weapon copies on this machine never shoot.
func _may_autofire() -> bool:
	if autofire_owner == null:
		return true
	if not autofire_owner.multiplayer.has_multiplayer_peer():
		return true
	return autofire_owner.is_multiplayer_authority()


# Fires once, then (for Repeat) fires again a few times in quick succession.
func _fire_with_repeat() -> void:
	var reps: int = get_fire_repeat_count()
	fire()
	for i in range(1, reps):
		await get_tree().create_timer(0.08 * float(i)).timeout
		if not is_instance_valid(self):
			return
		fire()

# Virtual function — overridden by specific weapons
func fire() -> void:
	pass

# --- Co-op synchronization (FUTURE-PROOF) -------------------------------------
# Every weapon that spawns a travel projectile or a standalone visual effect
# must broadcast a collision-disabled copy to the other machine(s) so teammates
# can SEE it (each machine only simulates its OWN player's projectiles). Route
# EVERY such spawn through the two helpers below instead of talking to Net
# directly: they centralize the null/active checks and are inherited by any new
# weapon built on Weapon, so a future weapon gets correct co-op sync for free by
# just calling sync_projectile() / sync_effect() after adding its node.
#
#   var proj: Node = MyScene.instantiate()
#   get_tree().current_scene.add_child(proj)
#   sync_projectile(proj, MyScene)          # <-- teammates now see it
#
#   var fx: Node = FxScene.instantiate()
#   get_tree().current_scene.add_child(fx)
#   sync_effect(fx, FxScene, {"radius": r})  # extra carries render params

## Broadcast a travel projectile to the other machine(s) as a visual copy.
func sync_projectile(proj: Node, scene: PackedScene) -> void:
	if proj == null or scene == null:
		return
	var net: Node = get_node_or_null("/root/Net")
	if net and net.has_method("sync_player_projectile"):
		net.sync_player_projectile(proj, scene)

## Broadcast a standalone effect (AoE / beam / ground telegraph / aura) to the
## other machine(s) as an inert visual copy. `extra` carries the effect's render
## params (radius, fuse, polygon, direction...).
func sync_effect(effect: Node, scene: PackedScene, extra: Dictionary = {}) -> void:
	if effect == null or scene == null:
		return
	var net: Node = get_node_or_null("/root/Net")
	if net and net.has_method("sync_player_effect"):
		net.sync_player_effect(effect, scene, extra)

func get_player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player

func get_effective_cooldown() -> float:
	var player = get_player()
	if player == null:
		return maxf(0.05, base_cooldown)

	# Mana Overload (mage secondary) can halve all cooldowns temporarily.
	var mult: float = 1.0
	if player.has_method("get_cooldown_multiplier"):
		mult = maxf(0.05, float(player.get_cooldown_multiplier()))

	# Wild Mage (mage ascension): each cast randomizes the cooldown 0.5x-1.2x.
	if player.has_method("is_subclass") and player.is_subclass("wild_mage"):
		mult *= randf_range(0.5, 1.2)

	return maxf(0.05, base_cooldown * player.get_attack_speed_multiplier() * mult)

# Area stat: scales the radius of AOE skills and the size of projectiles.
# Now a per-weapon stat (moved out of the level-up pool into the anvil).
func get_area_multiplier() -> float:
	return maxf(0.25, 1.0 + area_bonus)

# Knockback stat: scales the push force of this weapon's hits. Multiplies the
# base force a weapon already applies via enemy.apply_knockback().
func get_knockback(base_force: float) -> float:
	return base_force * (1.0 + knockback_bonus)

# Ailment Effect stat: scales the potency of ailments this weapon inflicts
# (burn/poison/impale damage, slow strength, shock bounce). Independent of the
# chance-based ailment_chance stat; this only boosts how strong the effect is.
func get_ailment_effect_multiplier() -> float:
	return maxf(0.25, 1.0 + ailment_effect_bonus)

# Effective projectile count (base + guaranteed anvil bonus + repeat-style
# chance from anvil Projectile Count upgrades).
func get_effective_projectile_count(base: int) -> int:
	var count: int = maxi(1, base + projectile_count_bonus)
	var chance: float = maxf(0.0, projectile_extra_chance)
	count += int(floor(chance))
	if chance - float(floor(chance)) > 0.0 and randf() < chance - float(floor(chance)):
		count += 1
	return count

# Effective pierce count (base + anvil bonus).
func get_effective_pierce(base: int) -> int:
	return maxi(0, base + pierce_bonus)

# Effective chain count (base + anvil bonus).
func get_effective_chain_count(base: int) -> int:
	return maxi(0, base + chain_count_bonus)

# Effective projectile travel speed (base + anvil bonus).
func get_effective_projectile_speed(base_speed: float) -> float:
	return maxf(0.0, base_speed * (1.0 + projectile_speed_bonus))


# Effective ability/projectile duration (base + anvil bonus). A negative
# duration_bonus means things end sooner (e.g. shorter bomb fuze).
func get_effective_duration(base_duration: float) -> float:
	return maxf(0.05, base_duration * (1.0 + duration_bonus))

# Returns the number of times this weapon should fire per trigger (repeat).
func get_fire_repeat_count() -> int:
	# Repeat is a % chance to chain an extra volley. Each full 100% guarantees one
	# extra; the remainder is a percentile chance of one more.
	var chance: float = maxf(0.0, repeat_chance)
	var guaranteed: int = int(floor(chance))
	var frac: float = chance - float(guaranteed)
	var extra: int = 1 if frac > 0.0 and randf() < frac else 0
	return 1 + guaranteed + extra

# --- Anvil capability reporting -------------------------------------------
# Each weapon overrides the stats it can actually use, so the anvil only offers
# relevant upgrades. Area is available to every weapon by default.

func supports_projectile_count() -> bool:
	return false

func supports_pierce() -> bool:
	return false

func supports_chain() -> bool:
	return false

func supports_area() -> bool:
	return true

func supports_repeat() -> bool:
	return true

func supports_projectile_speed() -> bool:
	return false

func supports_duration() -> bool:
	return false

func supports_range_damage() -> bool:
	return true

func supports_explosion_on_kill() -> bool:
	return true

func supports_knockback() -> bool:
	return true

func supports_ailment_effect() -> bool:
	return true

# --- Signature upgrades ------------------------------------------------
# Each weapon defines its own signature upgrades by overriding get_signature_pool().
# A signature is a transformative, one-time-per-run upgrade (the golden anvil's
# special offering). They carry the same shape as anvil stat entries, but with a
# much-reduced weight so they roll rarely from normal anvils.

## Signature pool entries this weapon offers. Each entry:
## { "id", "title", "description", "value", "apply": Callable }
## Base returns empty; subclasses override with their own list.
func get_signature_pool() -> Array[Dictionary]:
	return []

func get_signature_ids_owned() -> Array[String]:
	return signature_ids

func has_signature(sig_id: String) -> bool:
	return signature_ids.has(sig_id)

## Weight signatures roll at on normal anvils (10x smaller than normal stats=1.0).
func get_signature_weight() -> float:
	return 0.1

## Applies one signature and records it as taken (once-per-run).
func apply_signature(entry: Dictionary) -> void:
	var id: String = entry.get("id", "")
	if id.is_empty() or has_signature(id):
		return
	signature_ids.append(id)
	var apply: Callable = entry.get("apply", Callable())
	if apply.is_valid():
		apply.call(self)

func get_attack_damage(base_damage: float) -> int:
	var player = get_player()
	if player == null:
		return max(0, int(round(base_damage * (1.0 + damage_percent_bonus))))

	var dmg: int = player.get_attack_damage(base_damage)
	return max(0, int(round(float(dmg) * (1.0 + damage_percent_bonus))))

func roll_critical_hit() -> bool:
	var player = get_player()
	if player == null:
		return false

	return player.roll_critical_hit()

func get_critical_multiplier() -> float:
	var player = get_player()
	if player == null:
		return 1.5

	return player.get_critical_multiplier()

func apply_lifesteal() -> void:
	var player = get_player()
	if player:
		player.apply_lifesteal()


# Multiplies damage by the close/far bonus depending on how far the hit is from
# the player. Reach = distance from the player (screen center) to the edge of
# the screen. Close = first third, far = beyond two-thirds, middle = neutral.
func get_range_damage_multiplier(distance_from_player: float) -> float:
	if close_range_damage_bonus <= 0.0 and far_range_damage_bonus <= 0.0:
		return 1.0
	var reach: float = _get_screen_reach()
	if reach <= 0.0:
		return 1.0
	if distance_from_player <= reach / 3.0:
		return 1.0 + close_range_damage_bonus
	if distance_from_player >= reach * 2.0 / 3.0:
		return 1.0 + far_range_damage_bonus
	return 1.0


## Returns `base` damage adjusted by the close/far range bonus at the given
## distance from the player. No-op (returns base) if neither range bonus is owned.
func apply_range_damage_multiplier(base: int, distance: float) -> int:
	if close_range_damage_bonus <= 0.0 and far_range_damage_bonus <= 0.0:
		return base
	return maxi(1, int(round(float(base) * get_range_damage_multiplier(distance))))


func _get_screen_reach() -> float:
	var vp := get_viewport()
	if vp == null:
		return 0.0
	var size := vp.get_visible_rect().size
	return size.length() * 0.5


# After scoring a kill (enemy died), possibly trigger an explosion AOE.
func apply_explosion_on_kill(origin: Vector2, kill_damage: int) -> void:
	var chance: float = maxf(0.0, explosion_on_kill_chance)
	if chance <= 0.0:
		return
	# Chance over 100% lets a kill explode multiple times: each full 100% is one
	# guaranteed explosion, the remainder is a percentile chance of one more.
	var guaranteed: int = int(floor(chance))
	var frac: float = chance - float(guaranteed)
	var count: int = guaranteed + (1 if frac > 0.0 and randf() < frac else 0)
	for i in range(count):
		_explode_at(origin, kill_damage)


func _explode_at(origin: Vector2, kill_damage: int) -> void:
	# Blast radius nerf: the area anvil stat inflates the explosion radius at a
	# reduced rate (60% of the normal area bonus) so AOE doesn't balloon as fast.
	# Base radius (area_bonus=0) is unchanged.
	var eff_radius: float = explosion_radius * (1.0 + maxf(0.0, area_bonus) * 0.6)
	var dmg: int = maxi(1, int(round(float(kill_damage) * explosion_damage_ratio)))
	_spawn_explosion_visual(origin, eff_radius)
	var targets: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for d: Node in get_tree().get_nodes_in_group("destructibles"):
		targets.append(d)
	for e: Node in targets:
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if origin.distance_to(en.global_position) <= eff_radius:
			en.take_damage(dmg, false, _resolve_damage_type(), false, get_ailment_effect_multiplier())


## CHROMATIC is the Chromatic Orb's display-only "random element" marker. It must
## never reach an enemy as a real damage type, so resolve it to a random real
## element here — matching the orb's random-element bolts. Any other type passes
## through unchanged.
func _resolve_damage_type() -> DamageType.Type:
	if damage_type != DamageType.Type.CHROMATIC:
		return damage_type
	var choices: Array[DamageType.Type] = [
		DamageType.Type.FIRE,
		DamageType.Type.LIGHTNING,
		DamageType.Type.COLD,
		DamageType.Type.ARCANE,
		DamageType.Type.NECROTIC,
		DamageType.Type.HOLY,
		DamageType.Type.POISON,
	]
	return choices[randi() % choices.size()]


## Spawns a short-lived expanding-ring visual so explosions are clearly visible.
func _spawn_explosion_visual(origin: Vector2, eff_radius: float) -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	# Instantiate via preload (not the registered class_name) so this base class
	# stays decoupled from the global class cache of a freshly-added effect.
	var fx: Node2D = ExplosionEffectScript.new()
	fx.name = "ExplosionFX"
	fx.global_position = origin
	fx.set("max_radius", eff_radius)
	tree.current_scene.add_child(fx)


func _on_cooldown_finished() -> void:
	can_fire = true
	cooldown_ended.emit()
