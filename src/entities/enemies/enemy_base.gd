class_name EnemyBase
extends CharacterBody2D

@export var max_health: int = 40
@export var speed: float = 70.0
@export var contact_damage: int = 10
@export var damage_cooldown: float = 1.0
@export var xp_value: int = 1
@export var xp_orb_tier: int = 1
@export var gold_value: int = -1  # -1 = auto-derive from xp_value on ready
@export var weight: float = 10.0
@export var max_knockback_speed: float = 120.0
@export var knockback_decay: float = 160.0
@export var stat_scale_per_difficulty: float = 0.0  # stat growth multiplier per difficulty point
@export var damage_scale_ratio: float = 1.0  # damage grows at this fraction of stat_scale_per_difficulty (1.0 = same as health)
@export var speed_scale_per_difficulty: float = 0.2  # movement speed grows at this rate per difficulty (nerfed, and can be 0 to disable)
@export var separation_radius: float = 42.0  # how close to another enemy before we push apart
@export var separation_strength: float = 240.0  # how hard enemies push each other apart
@export var engage_radius: float = 22.0  # stop closing beyond this distance to the player; orbit instead of jamming into them
@export var orbit_speed_ratio: float = 0.55  # fraction of normal speed used while orbiting the player

var xp_orb_scene: PackedScene = preload("res://src/pickups/xp_orb/xp_orb.tscn")
var gold_pickup_scene: PackedScene = preload("res://src/pickups/gold_pickup/gold_pickup.tscn")

const StatusIconScript: Script = preload("res://src/ui/status_icons/status_icon_overlay.gd")

# Scatter drops in a small ring around the enemy so gold and XP land next to
# each other instead of stacking on top of one another.
const DROP_SCATTER_RADIUS: float = 14.0

var current_health: int
var can_deal_damage: bool = true
var target_player: Node2D = null
var knockback_velocity: Vector2 = Vector2.ZERO
var hp_value_label: Label = null
var slow_timer: float = 0.0
var slow_factor: float = 1.0

# Reused across physics frames to avoid per-frame allocations.
var _sep_shape: CircleShape2D = CircleShape2D.new()
var _sep_params: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()

# Set the moment the enemy dies (before queue_free takes effect at end of frame).
# Lets kill-triggered effects (e.g. explosion-on-kill) detect death immediately.
var _is_dead: bool = false

# --- Damage over time / status effects ------------------------------------
# Burn: discrete ticks every BURN_TICK_INTERVAL. Each tick deals a fixed
# fraction (BURN_TICK_PCT) of the damage of the hit that applied it. A fresh
# burn lasts BURN_TICKS ticks; re-applying adds more ticks (extends duration)
# without raising per-tick damage. The first tick fires immediately (t=0).
var burn_dps: float = 0.0          # per-tick damage (also the icon active flag)
var burn_ticks_remaining: int = 0
var burn_timer: float = 0.0        # time until next burn tick
const BURN_TICK_INTERVAL: float = 0.5
const BURN_TICKS: int = 5          # 5 ticks = 2.0 s total duration
const BURN_TICK_PCT: float = 0.30  # each tick deals 30% of the inflicting hit
const BURN_MAX_TICKS: int = 30

# Bleed: flat DoT, stackable. Each stack adds its own flat DPS (continuous).
var bleed_stacks: int = 0
var bleed_dps_per_stack: float = 0.0
var bleed_timer: float = 0.0

# Poison: discrete ticks every POISON_TICK_INTERVAL. Each tick deals the full
# max-health fraction (POISON_TICK_COUNT ticks total), halved on bosses.
var poison_dps: float = 0.0        # per-tick damage (also the icon active flag)
var poison_ticks_remaining: int = 0
var poison_timer: float = 0.0      # time until next poison tick
const POISON_TICK_INTERVAL: float = 1.0
const POISON_TICK_COUNT: int = 3   # 3 ticks over 3 seconds

const MAX_BLEED_STACKS: int = 10

@onready var hp_bar: Control = get_node_or_null("HPBar")

func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health
	if gold_value <= 0:
		gold_value = max(1, xp_value)
	
	if hp_bar:
		hp_bar.max_value = max_health
		hp_bar.value = current_health
		hp_bar.visible = false # Hide until taking first hit
		_ensure_hp_value_label()
		_update_hp_value_label()
		
	target_player = get_tree().get_first_node_in_group("player") as Node2D
	
	if has_node("Hitbox"):
		$Hitbox.body_entered.connect(_on_hitbox_touch)
		$Hitbox.area_entered.connect(_on_hitbox_touch)

	_apply_difficulty_scaling()

	_setup_status_icon_overlay()

	# Configure the reused separation query shape (radius is final after scaling).
	_sep_shape.radius = separation_radius
	_sep_params.shape = _sep_shape
	_sep_params.collision_mask = collision_layer
	_sep_params.collide_with_bodies = true
	_sep_params.collide_with_areas = false


## Simple enemy-enemy separation so a swarm fans out around the player instead
## of stacking into a single point on top of them ("stick like glue"). Applies
## a gentle repulsion force away from any other enemy that gets too close.
func _compute_separation() -> Vector2:
	if separation_radius <= 0.0 or separation_strength <= 0.0:
		return Vector2.ZERO
	_sep_params.transform = Transform2D(0.0, global_position)
	_sep_params.exclude = [get_rid()]
	var hits: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(_sep_params, 8) as Array[Dictionary]
	var push := Vector2.ZERO
	for hit in hits:
		var other: Object = hit.get("collider")
		if other == null or not is_instance_valid(other) or other == self:
			continue
		if not other.is_in_group("enemies"):
			continue
		var to_other: Vector2 = global_position - other.global_position
		var dist: float = to_other.length()
		if dist <= 0.001:
			continue
		var influence: float = clampf(1.0 - dist / separation_radius, 0.0, 1.0)
		push += to_other.normalized() * influence
	return push * separation_strength


## Adds a small child node that draws badges above the enemy for whichever
## status effects (burn / bleed / poison / slow) are currently active.
func _setup_status_icon_overlay() -> void:
	if has_node("StatusIcons"):
		return
	# Instantiate via preload to decouple from the global class cache.
	var overlay: Node2D = StatusIconScript.new()
	overlay.name = "StatusIcons"
	overlay.z_index = 12
	add_child(overlay)

func _physics_process(delta: float) -> void:
	_process_status_dots(delta)
	if target_player == null:
		target_player = get_tree().get_first_node_in_group("player") as Node2D
		return
		
	var to_player: Vector2 = target_player.global_position - global_position
	var dist: float = to_player.length()
	var move_dir: Vector2
	if dist > engage_radius:
		# Chase the player directly.
		move_dir = to_player.normalized()
	else:
		# Within strike range: stop closing and orbit sideways so the swarm forms
		# a live ring around the player instead of pressing into the player body
		# (which reads as enemies "sticking" / glued to the player).
		if dist > 0.001:
			var side: float = 1.0 if fmod(global_position.x + global_position.y, 2.0) < 1.0 else -1.0
			var orbit: Vector2 = Vector2(-to_player.y, to_player.x).normalized() * side
			# Push outward the closer they get, so the swarm settles into a clean
			# ring right at engage_radius instead of hugging the player body.
			var closeness: float = clampf(1.0 - dist / engage_radius, 0.0, 1.0)
			var outward: Vector2 = -to_player.normalized() * closeness * 1.5
			move_dir = (orbit * orbit_speed_ratio + outward).normalized()
		else:
			move_dir = Vector2.ZERO
	velocity = (move_dir * get_effective_speed(delta)) + knockback_velocity + _compute_separation()
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)
	_process_body_contacts()


func apply_slow(duration: float, factor: float) -> void:
	slow_timer = maxf(slow_timer, duration)
	slow_factor = minf(slow_factor, clampf(factor, 0.05, 1.0))


# --- Reusable status effects -----------------------------------------------
# Burn: discrete ticks. Each tick deals BURN_TICK_PCT of the hit that applied
# it. A fresh application starts BURN_TICKS ticks (first tick at t=0); further
# applications add more ticks (extending duration) without raising the
# per-tick damage, per design.
func apply_burn(hit_damage: float, _duration: float, _pct_per_sec: float) -> void:
	var tick_dmg: float = hit_damage * BURN_TICK_PCT
	# Keep the strongest per-tick damage seen; extra applications extend duration.
	burn_dps = maxf(burn_dps, tick_dmg)
	burn_ticks_remaining = mini(burn_ticks_remaining + BURN_TICKS, BURN_MAX_TICKS)
	if burn_timer <= 0.0:
		burn_timer = 0.0  # fire the first tick immediately (t=0)


# Bleed: flat DoT that stacks. Each stack adds bleed_dps for the duration.
func apply_bleed(flat_dps_per_stack: float, duration: float) -> void:
	bleed_stacks = mini(bleed_stacks + 1, MAX_BLEED_STACKS)
	bleed_dps_per_stack = maxf(bleed_dps_per_stack, flat_dps_per_stack)
	bleed_timer = maxf(bleed_timer, duration)


# Poison: discrete ticks. Each tick deals the full max-health fraction
# (POISON_TICK_COUNT ticks total); halved effectiveness on bosses.
func apply_poison(pct_max_health_per_sec: float, _duration: float) -> void:
	var boss_mult: float = 0.5 if is_in_group("bosses") else 1.0
	# Base tick damage = full pct of max health on a tick, halved vs bosses.
	poison_dps = maxf(poison_dps, pct_max_health_per_sec * float(max_health) * boss_mult)
	poison_ticks_remaining = POISON_TICK_COUNT
	# Ticks at 1s / 2s / 3s so the poison spans a full 3 seconds.
	poison_timer = POISON_TICK_INTERVAL


func get_effective_speed(delta: float) -> float:
	if slow_timer > 0.0:
		slow_timer = maxf(0.0, slow_timer - delta)
		return speed * slow_factor
	return speed

func _process_status_dots(delta: float) -> void:
	if not is_instance_valid(self) or current_health <= 0:
		return

	# Burn: discrete ticks. First tick fires immediately, then every interval.
	if burn_ticks_remaining > 0 and burn_timer >= 0.0:
		burn_timer -= delta
		if burn_timer <= 0.0:
			take_damage(maxi(1, int(round(burn_dps))))
			burn_ticks_remaining -= 1
			burn_timer = BURN_TICK_INTERVAL

	# Bleed: continuous flat DoT per frame (behaviour unchanged).
	if bleed_timer > 0.0 and bleed_stacks > 0:
		take_damage(maxi(1, int(round(bleed_dps_per_stack * float(bleed_stacks) * delta))))
		bleed_timer = maxf(0.0, bleed_timer - delta)

	# Poison: discrete ticks once per second.
	if poison_ticks_remaining > 0 and poison_timer >= 0.0:
		poison_timer -= delta
		if poison_timer <= 0.0:
			take_damage(maxi(1, int(round(poison_dps))))
			poison_ticks_remaining -= 1
			poison_timer = POISON_TICK_INTERVAL

	# Cleanup so statuses that expire also reset their (possibly stale) strengths.
	if burn_timer <= 0.0 and burn_ticks_remaining <= 0:
		burn_dps = 0.0
	if bleed_timer <= 0.0:
		bleed_stacks = 0
		bleed_dps_per_stack = 0.0
	if poison_timer <= 0.0 and poison_ticks_remaining <= 0:
		poison_dps = 0.0


func take_damage(amount: int, is_critical: bool = false) -> void:
	current_health -= amount
	
	# Show HP bar on hit
	if hp_bar:
		hp_bar.value = current_health
		hp_bar.visible = true
		_update_hp_value_label()
		
	# Spawn Floating Damage Text
	_spawn_damage_number(amount, is_critical)
	
	# Red Flash
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.RED, 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.05)
	
	if current_health <= 0:
		die()

func _ensure_hp_value_label() -> void:
	if hp_bar == null or hp_value_label != null:
		return

	hp_value_label = hp_bar.get_node_or_null("ValueLabel") as Label
	if hp_value_label == null:
		hp_value_label = Label.new()
		hp_value_label.name = "ValueLabel"
		hp_value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hp_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hp_value_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		hp_value_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
		hp_value_label.add_theme_constant_override("shadow_offset_x", 1)
		hp_value_label.add_theme_constant_override("shadow_offset_y", 1)
		hp_value_label.add_theme_font_size_override("font_size", 9)
		hp_bar.add_child(hp_value_label)

func _update_hp_value_label() -> void:
	# Text is intentionally left empty: the foo HP bars are too small to read
	# "current / max" without overflowing and garbling. The bar color + the
	# floating damage numbers already convey remaining health.
	if hp_value_label:
		hp_value_label.text = ""

func _spawn_damage_number(amount: int, is_critical: bool = false) -> void:
	var label = Label.new()
	label.text = str(amount)
	label.global_position = global_position + Vector2(randf_range(-10, 10), -20)
	label.z_index = 20
	label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.2) if is_critical else Color.YELLOW)
	label.add_theme_font_size_override("font_size", 12)
	
	get_tree().current_scene.add_child(label)
	
	# Animate float up and fade out
	var tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 25, 0.4)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(label.queue_free)

func die() -> void:
	_is_dead = true
	_drop_xp()
	_drop_gold()
	queue_free()


## Kills the enemy WITHOUT dropping any loot (XP or gold). Used when clearing a
## room after the boss dies: remaining mobs are removed, but the player already
## gets to sweep up the drops that were on the ground.
func die_without_drop() -> void:
	_is_dead = true
	queue_free()


## True once the enemy has entered its death state, even before queue_free()
## finishes at the end of the frame. Used to detect "just killed" for effects
## like explosion-on-kill, which can't rely on is_instance_valid() (the object
## is still valid until end of frame).
func has_died() -> bool:
	return _is_dead

func apply_knockback(source_position: Vector2, force: float) -> void:
	var push_force = force - weight
	if push_force <= 0.0:
		return

	push_force *= 0.35

	var push_direction = (global_position - source_position).normalized()
	knockback_velocity = push_direction * push_force
	knockback_velocity = knockback_velocity.limit_length(max_knockback_speed)

func _apply_difficulty_scaling() -> void:
	if stat_scale_per_difficulty <= 0.0:
		return

	var pl: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if pl == null:
		return

	var difficulty: float = 0.0
	if pl.has_method("get_map_difficulty"):
		difficulty = maxf(0.0, float(pl.get_map_difficulty()))
	elif pl.has_method("get"):
		difficulty = maxf(0.0, float(pl.get("difficulty")))

	if difficulty <= 0.0:
		return

	var mult: float = 1.0 + stat_scale_per_difficulty * difficulty
	max_health = max(1, int(round(float(max_health) * mult)))
	current_health = max_health
	# Damage scales at a FRACTION of the health scale (damage_scale_ratio) so
	# enemies get tougher without becoming one-shot meat-grinders late-game.
	var damage_mult: float = 1.0 + stat_scale_per_difficulty * damage_scale_ratio * difficulty
	contact_damage = max(0, int(round(float(contact_damage) * damage_mult)))
	# Speed scales at a reduced rate so enemies don't outpace the player and
	# pile up on them (the "stick like glue" feeling). speed_scale_per_difficulty
	# can be 0 on specific enemies (e.g. bomber) to disable the scaling entirely.
	speed = speed * (1.0 + stat_scale_per_difficulty * speed_scale_per_difficulty * difficulty)

	if hp_bar:
		hp_bar.max_value = max_health
		hp_bar.value = current_health

func _drop_xp() -> void:
	if xp_orb_scene:
		var orb = xp_orb_scene.instantiate() as XPOrb
		if orb:
			orb.global_position = global_position + _random_scatter()
			orb.setup(xp_value, xp_orb_tier)
			get_tree().current_scene.call_deferred("add_child", orb)

func _drop_gold() -> void:
	if gold_pickup_scene:
		var coin = gold_pickup_scene.instantiate() as GoldPickup
		if coin:
			coin.global_position = global_position + _random_scatter()
			coin.setup(gold_value)
			get_tree().current_scene.call_deferred("add_child", coin)

# Random offset within a small ring so individual drops don't stack together.
func _random_scatter() -> Vector2:
	var angle := randf() * TAU
	return Vector2(cos(angle), sin(angle)) * randf_range(6.0, DROP_SCATTER_RADIUS)

func _on_hitbox_touch(node: Node) -> void:
	var target = node.get_parent() if node is Area2D else node
	if target and (target.is_in_group("player") or target.has_method("take_damage")) and not target.is_in_group("enemies"):
		if can_deal_damage:
			target.take_damage(contact_damage, self)
			_apply_thorns_to_attacker(target)
			_start_damage_cooldown()

func _process_body_contacts() -> void:
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.is_in_group("player") and can_deal_damage:
			if collider.has_method("take_damage"):
				collider.take_damage(contact_damage, self)
				_apply_thorns_to_attacker(collider)
				_start_damage_cooldown()
				return

func _apply_thorns_to_attacker(attacker: Node) -> void:
	if attacker == null or not attacker.has_method("get"):
		return

	# Prefer the effective thorns getter so artefacts can scale thorns damage.
	var thorns_damage: float = 0.0
	if attacker.has_method("get_thorns_damage"):
		thorns_damage = float(attacker.get_thorns_damage())
	else:
		thorns_damage = float(attacker.get("thorns_flat"))
	if thorns_damage <= 0.0:
		return

	take_damage(max(1, int(round(thorns_damage))))

func _start_damage_cooldown() -> void:
	can_deal_damage = false
	await get_tree().create_timer(damage_cooldown).timeout
	can_deal_damage = true
