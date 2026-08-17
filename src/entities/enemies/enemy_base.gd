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
@export var engage_radius: float = 16.0  # stop closing beyond this distance to the player; orbit instead of jamming into them
@export var orbit_speed_ratio: float = 0.55  # fraction of normal speed used while orbiting the player
## Whether this enemy PHYSICALLY collides with the player. Most mobs are set to
## false so the player walks through enemies (only the Hitbox deals contact
## damage). Keep true for the few that should body-block (skeleton general, brute).
@export var collide_with_player: bool = false

var xp_orb_scene: PackedScene = preload("res://src/pickups/xp_orb/xp_orb.tscn")
var gold_pickup_scene: PackedScene = preload("res://src/pickups/gold_pickup/gold_pickup.tscn")
var soul_pickup_scene: PackedScene = preload("res://src/pickups/soul_pickup/soul_pickup.tscn")

const StatusIconScript: Script = preload("res://src/ui/status_icons/status_icon_overlay.gd")
## Short-lived expanding-ring visual reused for the Corrosive Burst relic so the
## poison-expiry explosion is actually visible.
const PoisonBurstFxScript: Script = preload("res://src/effects/explosion_effect/explosion_effect.gd")

# Scatter drops in a small ring around the enemy so gold and XP land next to
# each other instead of stacking on top of one another.
const DROP_SCATTER_RADIUS: float = 14.0

# The player's collision body is a 16x16 rectangle, so its half-extent is 8.
# Used to compute how close an enemy must be for its melee contact to register.
const PLAYER_BODY_HALF: float = 8.0

# Team XP scales with combat progress (room_number/2 skips non-combat rooms):
# room 1 is baseline, and each later combat room adds XP_ROOM_SCALE more.
const XP_ROOM_SCALE: float = 0.25
# Late-game gold nerf: gold per kill is divided down as combat progresses so
# total gold doesn't balloon as enemy counts grow. Room 1 is untouched.
const GOLD_ROOM_DECAY: float = 0.12

var current_health: int
var can_deal_damage: bool = true
var target_player: Node2D = null

## Set by EnemyNet when this enemy was network-spawned by the HOST (>= 0).
## -1 means a normal single-player enemy (or a boss/event enemy that isn't
## replicated), which is never treated as a network node.
var _enemy_net_id: int = -1

## Host/EnemyNet stamps each replicated enemy with its shared network id.
func set_enemy_net_id(id: int) -> void:
	_enemy_net_id = id
var knockback_velocity: Vector2 = Vector2.ZERO
## FROZEN (Deep Freeze signature): enemy is frozen solid — can't move and takes
## bonus damage for the duration. Applied only to enemies ALREADY slowed, and
## only at a chance (rolled by the Frost Nova signature).
var frozen_timer: float = 0.0
const FROZEN_DURATION: float = 1.2
const FROZEN_DAMAGE_MULT: float = 2.0
var hp_value_label: Label = null
var slow_timer: float = 0.0
var slow_factor: float = 1.0

# Reused across physics frames to avoid per-frame allocations.
var _sep_shape: CircleShape2D = CircleShape2D.new()
var _sep_params: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()

# Set the moment the enemy dies (before queue_free takes effect at end of frame).
# Lets kill-triggered effects (e.g. explosion-on-kill) detect death immediately.
var _is_dead: bool = false
## Type of the most recent damaging hit received (PHYSICAL by default). Hook for
## a future ailment system that keys effects off the damage type dealt.
var _last_damage_type: DamageType.Type = DamageType.Type.PHYSICAL

# --- Ailments (status effects keyed off damage type) ----------------------
# Each damaging hit rolls "ailment chance" (player stat); on success the alemment
# matching the DAMAGE TYPE of that hit is applied via _apply_ailment().

# FIRE -> Burn: discrete ticks every BURN_TICK_INTERVAL, each dealing a fixed
# fraction (BURN_TICK_PCT) of the hit that applied it. Re-applying keeps the
# strongest per-tick damage and extends duration (does NOT stack per upgrade).
var burn_dps: float = 0.0          # per-tick damage (also the icon active flag)
var burn_ticks_remaining: int = 0
var burn_timer: float = 0.0        # time until next burn tick
const BURN_TICK_INTERVAL: float = 0.5
const BURN_TICKS: int = 5          # 5 ticks = 2.0 s total duration
const BURN_TICK_PCT: float = 0.30  # each tick deals 30% of the inflicting hit
const BURN_MAX_TICKS: int = 30

# COLD -> Slow (reuses slow_timer / slow_factor; see apply_slow).

# LIGHTNING -> Shock: brief "shocked" flag set on the bounced target. Powers
# the Static Conduit relic (extra crit damage vs shocked enemies).
var shock_timer: float = 0.0
const SHOCK_DURATION: float = 1.5

# ARCANE -> Crit vulnerability: while active the player's crit chance is rolled
# MULTIPLE times (lucky effect — take the better result) instead of a flat
# upgrade chance. Ailment Effect lengthens the window and adds a re-roll per
# full +100% bonus. CRIT_VULN_TIMER also serves as the icon active flag.
var crit_vuln_timer: float = 0.0
const CRIT_VULN_DURATION: float = 3.0

# NECROTIC -> Decay: while active, the enemy deals less damage.
var decay_timer: float = 0.0
const DECAY_DURATION: float = 3.0
const DECAY_DAMAGE_MULT: float = 0.8  # enemy deals 20% less damage

# HOLY -> Brand: while active, this enemy takes increased damage from all sources.
var brand_timer: float = 0.0
const BRAND_DURATION: float = 3.0
const BRAND_DAMAGE_MULT: float = 1.5

# POISON -> Stackable DoT: long duration, slow ticks, scaled from the hit but
# smaller than burn because it stacks. Each stack adds its own per-tick damage.
var poison_stacks: int = 0
var poison_tick_dps: float = 0.0   # per-tick damage from ALL stacks
var poison_timer: float = 0.0      # time until next poison tick
var poison_duration: float = 0.0   # time left before poison ends entirely
const POISON_TICK_INTERVAL: float = 1.5   # slow ticks
const POISON_DURATION_MAX: float = 8.0    # long duration
const POISON_TICK_PCT: float = 0.10       # per-stack per-tick (less than burn)
const MAX_POISON_STACKS: int = 10

# PHYSICAL -> Impale: stores a % of the hit that applied it, and releases that
# stored damage on the NEXT hit the enemy takes.
var impale_pool: float = 0.0
const IMPALE_PCT: float = 0.30  # store 30% of the inflicting hit
# Crimson Echo relic: impale is released over TWO hits instead of one lump.
var _impale_echo_hits_left: int = 0
var _impale_echo_per_hit: float = 0.0

@onready var hp_bar: Control = get_node_or_null("HPBar")

# --- Procedural doodle ----------------------------------------------------
# Every enemy shares the same placeholder icon texture today, so they only differ
# by a tint — genuinely hard to tell apart mid-swarm. Each subclass sets a small
# doodle (distinct shape + color) which is drawn here with _draw() primitives so
# each type reads clearly at a glance. doodle_kind: 0=circle 1=square 2=diamond
# 3=triangle 4=bomb(fuse) 5=star 6=hexagon.
var doodle_kind: int = 0
var doodle_color: Color = Color(0.9, 0.9, 0.95)
var doodle_size: float = 6.0

func _ready() -> void:
	add_to_group("enemies")
	# Every enemy type uses the same placeholder icon; the per-type procedural
	# doodle (drawn in _draw) is their real visual, so hide the shared sprite.
	if has_node("Sprite2D"):
		($Sprite2D as Sprite2D).visible = false
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

	# Most mobs don't physically collide with the player (contact damage comes
	# from the Hitbox area). Only body-blocked mobs (general, brute) keep the
	# player bit (layer 2 = bit value 2) in their collision mask.
	if not collide_with_player:
		collision_mask &= ~2

	_apply_difficulty_scaling()

	_setup_status_icon_overlay()

	# Configure the reused separation query shape (radius is final after scaling).
	_sep_shape.radius = separation_radius
	_sep_params.shape = _sep_shape
	_sep_params.collision_mask = collision_layer
	_sep_params.collide_with_bodies = true
	_sep_params.collide_with_areas = false

	_apply_network_role()


# --- Network role (host-authoritative enemies) -------------------------------
#
# In co-op, enemies are spawned ONLY by the host (peer 1) and replicated to
# clients. The HOST's copy runs the full AI/physics and owns hp/death. A CLIENT's
# copy is a frozen "replica": it must not simulate (it just renders the host's
# position/hp, synced via MultiplayerSynchronizer) and any damage it takes is
# forwarded to the host (this enemy's authoritative copy) as an RPC instead of
# being committed locally.

## True when this enemy is a co-op REPLICA: exists on a client, owned by the
## host, so it must not simulate or commit damage locally.
func _is_network_replica() -> bool:
	if _enemy_net_id < 0:
		return false
	var net: Node = get_node_or_null("/root/Net")
	if net == null or not net.active():
		return false
	return not is_multiplayer_authority()


## Runs at the end of _ready. For a network-synced enemy, claims host authority
## (called while the node is already in the tree, per the pattern that binds
## correctly) and, on a client, turns the node into a frozen replica.
func _apply_network_role() -> void:
	var net: Node = get_node_or_null("/root/Net")
	if _enemy_net_id < 0 or net == null or not net.active():
		return  # single-player / non-replicated enemy: behave as normal
	set_multiplayer_authority(1)
	if not is_multiplayer_authority():
		# Client replica: stop AI/physics/status ticks. Position, max_health and
		# current_health arrive via the synchronizer; _process refreshes the bar.
		set_physics_process(false)


## Lightweight per-frame refresh used by replicas (their physics is off) to show
## the health bar from the host-authoritative replicated hp. It returns
## immediately everywhere else, so single-player and host behavior are unchanged.
func _process(_delta: float) -> void:
	if not _is_network_replica():
		return
	if hp_bar:
		hp_bar.max_value = max_health
		hp_bar.value = current_health
		hp_bar.visible = current_health < max_health


## A client's replica took a hit: tell the HOST (peer 1) to commit it to the
## authoritative copy, and show cosmetic feedback so the attacker feels it land.
func _forward_client_hit(amount: int, is_critical: bool, damage_type: DamageType.Type, suppress_ailment: bool, ailment_multiplier: float) -> void:
	var n: Node = get_tree().get_first_node_in_group("enemy_net")
	if n and multiplayer.has_multiplayer_peer():
		n.rpc_id(1, "apply_enemy_hit", _enemy_net_id, maxi(1, amount), is_critical, int(damage_type), suppress_ailment, ailment_multiplier)
	_spawn_damage_number(maxi(1, amount), is_critical)
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color.RED, 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.05)


## Deals damage to a target on this machine, OR — in co-op — forwards the hit to
## the peer that OWNS a player when this enemy (on the host) contacts a client
## player's ghost. The owner is the health authority for its own player, so a
## host enemy must NOT mutate the ghost's local (replicated) health — that would
## be a non-authoritative change that gets overwritten by the next sync. Instead
## it tells the owner to commit the damage (Player.apply_network_damage), and the
## owner's resulting HP replicates back out to everyone. Single-player and host's
## own player are applied locally, exactly as before.
func _deal_player_damage(target: Node, amount: int, source: Node) -> void:
	var ghost: bool = _is_coop_ghost(target)
	forward_player_damage(target, amount, source)
	# Thorns reflect damage back to the attacker — but only for a locally-simmed
	# hit. A ghost's thorns value isn't the real player's, so skip it there.
	if not ghost:
		_apply_thorns_to_attacker(target)


## True when `target` is a co-op CLIENT player's ghost on this (host) machine —
## i.e. a player this machine does NOT simulate. Its health is owned by its peer.
func _is_coop_ghost(target: Node) -> bool:
	var net: Node = get_node_or_null("/root/Net")
	return net != null and net.active() and target.is_in_group("player") and not target.is_multiplayer_authority()


## Shared by enemies and their projectiles: apply damage locally, or in co-op
## forward the hit to the peer that owns the player so it commits the damage to
## its authoritative health (the resulting HP replicates back out to everyone).
static func forward_player_damage(target: Node, amount: int, source: Node) -> void:
	if amount <= 0 or target == null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var net: Node = tree.root.get_node_or_null("Net")
	if net != null and net.active() and target.is_in_group("player") and not target.is_multiplayer_authority():
		# Co-op: a client player's ghost on our (host) machine. Forward to owner.
		if target.has_method("apply_network_damage"):
			target.rpc_id(target.get_multiplayer_authority(), "apply_network_damage", amount)
		return
	if target.has_method("take_damage"):
		target.take_damage(amount, source)


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

## Draws this enemy's procedural doodle so each type is visually distinct.
func _draw() -> void:
	var c: Color = doodle_color
	var s: float = doodle_size
	match doodle_kind:
		0:  # circle (grunt)
			draw_circle(Vector2.ZERO, s, c)
		1:  # square (tank)
			var half: float = s
			draw_rect(Rect2(-half, -half, s * 2.0, s * 2.0), c)
			draw_rect(Rect2(-half * 0.55, -half * 0.55, s * 1.1, s * 1.1), c.lightened(0.25))
		2:  # diamond (ranged)
			var dh: float = s
			draw_colored_polygon(PackedVector2Array([Vector2(0, -dh), Vector2(dh, 0), Vector2(0, dh), Vector2(-dh, 0)]), c)
		3:  # triangle (dasher)
			var th: float = s
			draw_colored_polygon(PackedVector2Array([Vector2(0, -th * 1.2), Vector2(th, th * 0.8), Vector2(-th, th * 0.8)]), c)
		4:  # bomb (fuse + bright spark)
			draw_circle(Vector2(0, 2), s * 0.8, c)
			draw_line(Vector2(0, 2 - s * 0.8), Vector2(0, 2 - s * 1.3), c.lightened(0.35), 1.5)
			draw_circle(Vector2(0, 2 - s * 1.4), 1.5, Color(1.0, 0.9, 0.3))
		5:  # star (boss)
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(10):
				var ang: float = -PI / 2.0 + float(i) * PI / 5.0
				var r: float = s if i % 2 == 0 else s * 0.45
				pts.append(Vector2(cos(ang), sin(ang)) * r)
			draw_colored_polygon(pts, c)
			draw_polyline(pts, Color(0, 0, 0, 0.35), 1.0, true)
		6:  # hexagon (summoner)
			var pts2: PackedVector2Array = PackedVector2Array()
			for i in range(6):
				var ang2: float = PI / 6.0 + float(i) * PI / 3.0
				pts2.append(Vector2(cos(ang2), sin(ang2)) * s)
			draw_colored_polygon(pts2, c)
			draw_circle(Vector2.ZERO, s * 0.2, Color(0, 0, 0, 0.35))


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

	# Continuous melee contact: the swarm stops/orbits at engage_radius, so a
	# stationary player inside that ring must keep taking contact damage. The
	# Hitbox area only fires on ENTRY, not for a body that keeps overlapping, so
	# poll by distance here. It shares can_deal_damage with the area handlers,
	# which prevents double-hits on the same frame.
	if can_deal_damage and dist <= engage_radius + PLAYER_BODY_HALF:
		_deal_player_damage(target_player, _get_outgoing_contact_damage(), self)
		_start_damage_cooldown()


func apply_slow(duration: float, factor: float) -> void:
	slow_timer = maxf(slow_timer, duration)
	slow_factor = minf(slow_factor, clampf(factor, 0.05, 1.0))


## Freezes the enemy solid for the fixed FROZEN_DURATION (Deep Freeze).
func apply_freeze() -> void:
	frozen_timer = FROZEN_DURATION


# --- Ailment application methods (called from _apply_ailment) --------------

# FIRE -> Burn: discrete ticks, each BURN_TICK_PCT of the hit that applied it.
# Keeps the strongest per-tick damage; re-applying extends duration.
func apply_burn(hit_damage: float) -> void:
	burn_dps = maxf(burn_dps, hit_damage * BURN_TICK_PCT)
	burn_ticks_remaining = mini(burn_ticks_remaining + BURN_TICKS, BURN_MAX_TICKS)
	if burn_timer <= 0.0:
		burn_timer = 0.0  # fire the first tick immediately (t=0)


# POISON -> Stackable DoT: long duration, slow ticks. Each stack adds its own
# per-tick damage (hit_damage * POISON_TICK_PCT), smaller than burn per stack.
func apply_poison(hit_damage: float) -> void:
	poison_stacks = mini(poison_stacks + 1, MAX_POISON_STACKS)
	poison_tick_dps += hit_damage * POISON_TICK_PCT
	poison_duration = POISON_DURATION_MAX
	if poison_timer <= 0.0:
		poison_timer = POISON_TICK_INTERVAL
	if poison_tick_dps > 0.0 and poison_timer > POISON_TICK_INTERVAL:
		poison_timer = POISON_TICK_INTERVAL


# PHYSICAL -> Impale: store a % of the hit; released on the NEXT hit taken.
func apply_impale(hit_damage: float) -> void:
	impale_pool += hit_damage * IMPALE_PCT
	# Reset the echo split so the next release re-divides the fresh pool.
	_impale_echo_hits_left = 0
	_impale_echo_per_hit = 0.0


# ARCANE -> Crit vulnerability: raise the chance incoming hits become crits.
# Ailment Effect lengthens the vulnerable window (longer uptime to exploit it).
func apply_crit_vulnerability(effect_multiplier: float = 1.0) -> void:
	crit_vuln_timer = maxf(crit_vuln_timer, CRIT_VULN_DURATION * maxf(0.25, effect_multiplier))


# NECROTIC -> Decay: enemy deals less damage.
func apply_decay() -> void:
	decay_timer = maxf(decay_timer, DECAY_DURATION)


# HOLY -> Brand: enemy takes increased damage from all sources.
func apply_brand() -> void:
	brand_timer = maxf(brand_timer, BRAND_DURATION)


# LIGHTNING -> Shock: mark this enemy as briefly Shocked (Static Conduit relic).
func mark_shocked() -> void:
	shock_timer = SHOCK_DURATION


## Counts how many DISTINCT ailments are currently active on this enemy.
## Used by the Chromatic Bolt "Ailment Resonance" signature (bonus damage per
## ailment) and any future synergy effects.
func count_active_ailments() -> int:
	var count: int = 0
	if burn_dps > 0.0 or burn_ticks_remaining > 0:
		count += 1
	if poison_stacks > 0 or poison_duration > 0.0:
		count += 1
	if slow_timer > 0.0:
		count += 1
	if shock_timer > 0.0:
		count += 1
	if crit_vuln_timer > 0.0:
		count += 1
	if decay_timer > 0.0:
		count += 1
	if brand_timer > 0.0:
		count += 1
	if impale_pool > 0.0:
		count += 1
	return count


# Rolls the player's ailment chance. Returns true if the current hit's damage
# type should also inflict its matching ailment.
func _roll_ailment() -> bool:
	var pl: Node = get_tree().get_first_node_in_group("player")
	if pl == null or not pl.has_method("roll_ailment"):
		return false
	var chance: float = clampf(float(pl.roll_ailment_result()), 0.0, 1.0)
	var rolled: bool = randf() < chance
	# Unstable Mind relic: against Critically Vulnerable enemies, ailment chance
	# benefits from a LUCKY re-roll (roll twice, take the best) — mirroring the
	# reworked crit-vulnerability mechanic.
	if not rolled and crit_vuln_timer > 0.0 and pl.has_method("has_artefact") and pl.has_artefact("unstable_mind"):
		rolled = randf() < chance
	return rolled


# Applies the ailment matching the given damage type to this enemy (and, for
# shock, to a nearby different enemy). `effect_multiplier` (>1) boosts the
# POTENCY of the ailment (Ailment Effect anvil stat): burn/poison/impale deal
# more, slow is stronger, shock bounces harder. It does NOT affect ailment
# chance — that stays the player's ailment_chance stat.
func _apply_ailment(damage_type: DamageType.Type, hit_damage: int, effect_multiplier: float = 1.0) -> void:
	match damage_type:
		DamageType.Type.FIRE:
			apply_burn(float(hit_damage) * effect_multiplier)
		DamageType.Type.LIGHTNING:
			_apply_shock(float(hit_damage) * effect_multiplier)
		DamageType.Type.COLD:
			# Stronger slow: scale the slow factor (0.45 base) toward a hard cap.
			apply_slow(2.0, clampf(0.45 * effect_multiplier, 0.05, 0.95))
		DamageType.Type.ARCANE:
			apply_crit_vulnerability(effect_multiplier)
		DamageType.Type.NECROTIC:
			apply_decay()
		DamageType.Type.HOLY:
			apply_brand()
		DamageType.Type.POISON:
			apply_poison(float(hit_damage) * effect_multiplier)
		DamageType.Type.PHYSICAL:
			apply_impale(float(hit_damage) * effect_multiplier)


# LIGHTNING -> Shock: zap a DIFFERENT nearby enemy for 50% of the hit damage.
func _apply_shock(hit_damage: float) -> void:
	var best: Node2D = null
	var best_d: float = INF
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e == self:
			continue
		var d: float = global_position.distance_squared_to((e as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = e as Node2D
	if best != null and best.has_method("take_damage"):
		best.take_damage(maxi(1, int(round(hit_damage * 0.5))), false, DamageType.Type.LIGHTNING, true)
		# Mark the bounced target as Shocked (brief flag for Static Conduit relic:
		# extra crit damage against enemies that were just shocked).
		if best.has_method("mark_shocked"):
			best.mark_shocked()


func get_effective_speed(delta: float) -> float:
	if frozen_timer > 0.0:
		frozen_timer = maxf(0.0, frozen_timer - delta)
		return 0.0
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
			take_damage(maxi(1, int(round(burn_dps))), false, DamageType.Type.FIRE, true)
			burn_ticks_remaining -= 1
			burn_timer = BURN_TICK_INTERVAL

	# Poison: slow ticks over a long duration.
	if poison_duration > 0.0:
		poison_duration = maxf(0.0, poison_duration - delta)
		if poison_stacks > 0 and poison_timer >= 0.0:
			poison_timer -= delta
			if poison_timer <= 0.0:
				take_damage(maxi(1, int(round(poison_tick_dps))), false, DamageType.Type.POISON, true)
				poison_timer = POISON_TICK_INTERVAL
		if poison_duration <= 0.0:
			if poison_stacks > 0 and _release_poison_burst():
				pass  # Corrosive Burst relic handled the expiry explosion.
			poison_stacks = 0
			poison_tick_dps = 0.0

	# Decay / brand / crit-vuln timers tick down.
	if decay_timer > 0.0:
		decay_timer = maxf(0.0, decay_timer - delta)
	if brand_timer > 0.0:
		brand_timer = maxf(0.0, brand_timer - delta)
	if crit_vuln_timer > 0.0:
		crit_vuln_timer = maxf(0.0, crit_vuln_timer - delta)
	if shock_timer > 0.0:
		shock_timer = maxf(0.0, shock_timer - delta)

	# Cleanup: burn reset when fully expired (impale has no timer / pool persists).
	if burn_timer <= 0.0 and burn_ticks_remaining <= 0:
		burn_dps = 0.0


func take_damage(amount: int, is_critical: bool = false, damage_type: DamageType.Type = DamageType.Type.PHYSICAL, suppress_ailment: bool = false, ailment_multiplier: float = 1.0) -> void:
	# Network replica: this machine does NOT own this enemy's hp. Forward the hit
	# to the host's authoritative copy and show cosmetic feedback instead of
	# committing the damage locally (the host's result replicates back out).
	if _is_network_replica():
		_forward_client_hit(amount, is_critical, damage_type, suppress_ailment, ailment_multiplier)
		return

	# IMPALE release: stored impale damage is added onto THIS next hit, then cleared.
	var dealt: float = float(amount)
	var plr: Node = get_tree().get_first_node_in_group("player")
	if impale_pool > 0.0:
		# Crimson Echo relic: impale is paid out over TWO hits, each half the pool.
		var echo: bool = plr != null and plr.has_method("has_artefact") and plr.has_artefact("crimson_echo")
		if echo and _impale_echo_hits_left <= 0 and impale_pool > 0.0:
			_impale_echo_hits_left = 2
			_impale_echo_per_hit = impale_pool / 2.0
		if _impale_echo_hits_left > 0:
			dealt += _impale_echo_per_hit
			_impale_echo_hits_left -= 1
			if _impale_echo_hits_left <= 0:
				impale_pool = 0.0
				_impale_echo_per_hit = 0.0
		else:
			dealt += impale_pool
			impale_pool = 0.0

	# BRAND (holy): while active, this enemy takes increased damage from all sources.
	if brand_timer > 0.0:
		dealt *= BRAND_DAMAGE_MULT

	# FROZEN (Deep Freeze): frozen enemies take bonus damage.
	if frozen_timer > 0.0:
		dealt *= FROZEN_DAMAGE_MULT

	# CRIT VULNERABILITY (arcane): LUCKY re-roll. A non-crit hit rolls the
	# player's crit chance a second time and, if it succeeds, upgrades into a
	# crit — effectively rolling crit chance twice and taking the best. Scales
	# with the player's crit build rather than a flat upgrade chance. Ailment
	# Effect grants EXTRA re-rolls: +1 per full +100% bonus (em >= 2.0, 3.0, ...).
	if not is_critical and crit_vuln_timer > 0.0:
		var crit_chance: float = float(plr.get("critical_hit_chance")) if plr != null and plr.get("critical_hit_chance") != null else 0.0
		var rerolls: int = maxi(1, int(floor(ailment_multiplier)))
		for i in rerolls:
			if randf() < crit_chance:
				is_critical = true
				if plr != null and plr.has_method("get_critical_multiplier"):
					dealt *= float(plr.get_critical_multiplier())
				break

	# Relic hooks: Cold Blooded (+30% vs slowed) and Static Conduit (+50% crit dmg
	# vs shocked). Both read the player's current artefact loadout live.
	if slow_timer > 0.0 and plr != null and plr.has_method("has_artefact") and plr.has_artefact("cold_blooded"):
		dealt *= 1.30
	if is_critical and shock_timer > 0.0 and plr != null and plr.has_method("has_artefact") and plr.has_artefact("static_conduit"):
		dealt *= 1.50

	# Wrath (Burning Ire): non-critical hits deal less. (Crit bonus is applied on
	# the player side via get_critical_multiplier().)
	if not is_critical and plr != null and plr.has_method("has_artefact") and plr.has_artefact("burning_ire"):
		dealt *= 0.70
	# Pride (Hubris): the player deals +30% damage to bosses.
	if is_in_group("bosses") and plr != null and plr.has_method("has_artefact") and plr.has_artefact("hubris"):
		dealt *= 1.30

	var final_amount: int = maxi(1, int(round(dealt)))
	current_health -= final_amount
	# Record the type of the most recent damaging hit.
	_last_damage_type = damage_type

	# Roll to inflict the ailment matching this hit's damage type (not for DoT
	# ticks / shock bounces, which pass suppress_ailment = true).
	if not suppress_ailment and not _is_dead:
		if _roll_ailment():
			_apply_ailment(damage_type, final_amount, ailment_multiplier)

	# Show HP bar on hit
	if hp_bar:
		hp_bar.value = current_health
		hp_bar.visible = true
		_update_hp_value_label()
		
	# Spawn Floating Damage Text
	_spawn_damage_number(final_amount, is_critical)
	
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
	_spread_ailments_on_death()
	_register_kill()
	# In co-op, a network-synced enemy dies on the HOST. Its drops are broadcast
	# to every machine (so each player collects their own copy) instead of being
	# spawned only here. Falls back to plain local drops otherwise.
	if _route_shared_drops():
		queue_free()
		return
	_drop_soul()
	_drop_xp()
	_drop_gold()
	queue_free()


## Co-op: this is a host-authoritative networked enemy and I am the host, so tell
## every machine (including myself via call_local) to spawn its own copy of the
## drops. Returns true if drops were routed this way (caller must NOT also drop
## locally, or the host would double-spawn).
func _route_shared_drops() -> bool:
	var net: Node = get_node_or_null("/root/Net")
	if _enemy_net_id < 0 or net == null or not net.active() or not multiplayer.is_server():
		return false
	var enemy_net: Node = get_tree().get_first_node_in_group("enemy_net")
	if enemy_net == null:
		return false
	# xp/gold values are computed here (host) so every machine agrees; the soul
	# pickup is decided per-machine inside spawn_shared_drops.
	enemy_net.rpc("spawn_shared_drops", global_position, _scaled_xp_value(), xp_orb_tier, _scaled_gold_value())
	return true


## Soul Harvest relic: drop a soul pickup that grants the player Shield.
func _drop_soul() -> void:
	var plr: Node = get_tree().get_first_node_in_group("player")
	if plr == null or not plr.has_method("has_artefact") or not plr.has_artefact("soul_harvest"):
		return
	if not is_instance_valid(get_tree()) or get_tree().current_scene == null:
		return
	var soul: Node2D = soul_pickup_scene.instantiate() as Node2D
	var ang: float = randf() * TAU
	soul.global_position = global_position + Vector2(cos(ang), sin(ang)) * DROP_SCATTER_RADIUS
	get_tree().current_scene.add_child(soul)


## Cinder Propagation + Brand of Ruin relics: spreading statuses to nearby
## enemies when an afflicted enemy dies. Player's live artefact loadout is read.
func _spread_ailments_on_death() -> void:
	var plr: Node = get_tree().get_first_node_in_group("player")
	if plr == null or not plr.has_method("has_artefact"):
		return
	var spread_burn: bool = burn_dps > 0.0 and plr.has_artefact("cinder_propagation")
	var spread_brand: bool = brand_timer > 0.0 and plr.has_artefact("brand_of_ruin")
	if not spread_burn and not spread_brand:
		return
	var origin: Vector2 = global_position
	var spread_radius: float = 90.0
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e == self:
			continue
		var en: Node2D = e as Node2D
		if origin.distance_to(en.global_position) <= spread_radius:
			if spread_burn and en.has_method("apply_burn"):
				en.apply_burn(burn_dps / BURN_TICK_PCT)
			if spread_brand and en.has_method("apply_brand"):
				en.apply_brand()


## Reports a player-caused kill to the run stats (GameState) for the summary.
func _register_kill() -> void:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and gs.has_method("register_enemy_kill"):
		gs.register_enemy_kill()


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


## Corrosive Burst relic: when this enemy's poison expires, deal the stored DoT
## as a one-time AOE burst around it. Returns true if the relic fired.
func _release_poison_burst() -> bool:
	var plr: Node = get_tree().get_first_node_in_group("player")
	if plr == null or not plr.has_method("has_artefact") or not plr.has_artefact("corrosive_burst"):
		return false
	var burst_dmg: int = maxi(1, int(round(poison_tick_dps * POISON_TICK_INTERVAL * 2.0)))
	var origin: Vector2 = global_position
	var burst_radius: float = 85.0
	_spawn_poison_burst_visual(origin, burst_radius)
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e == self:
			continue
		var en: Node2D = e as Node2D
		if origin.distance_to(en.global_position) <= burst_radius and en.has_method("take_damage"):
			en.take_damage(burst_dmg, false, DamageType.Type.POISON, true)
	return true


## Shows a brief green expanding ring so the Corrosive Burst relic's poison
## explosion is visible (matches the explosion-on-kill visual, tinted for poison).
func _spawn_poison_burst_visual(origin: Vector2, radius: float) -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var fx: Node2D = PoisonBurstFxScript.new()
	fx.name = "PoisonBurstFX"
	fx.global_position = origin
	fx.set("max_radius", radius)
	fx.set("color", Color(0.4, 0.9, 0.45))
	tree.current_scene.add_child(fx)

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
			orb.setup(_scaled_xp_value(), xp_orb_tier)
			get_tree().current_scene.call_deferred("add_child", orb)

func _drop_gold() -> void:
	if gold_pickup_scene:
		var coin = gold_pickup_scene.instantiate() as GoldPickup
		if coin:
			coin.global_position = global_position + _random_scatter()
			coin.setup(_scaled_gold_value())
			get_tree().current_scene.call_deferred("add_child", coin)

## 0-based index of the current COMBAT room. Rooms alternate combat/non-combat
## (odd stages are combat, even are shop/anvil/relic), so floor(stage/2) counts
## only combat rooms: stage 1 -> 0, 3 -> 1, 5 -> 2, etc.
func _combat_room_index() -> int:
	var gs: Node = get_tree().get_root().get_node_or_null("GameState")
	if gs == null or gs.get("stage") == null:
		return 0
	return int(floor(float(gs.get("stage")) / 2.0))


## XP per kill grows with combat room count (more XP the further you go).
func _scaled_xp_value() -> int:
	var idx: int = _combat_room_index()
	return max(1, int(round(float(xp_value) * (1.0 + XP_ROOM_SCALE * float(idx)))))


## Gold per kill shrinks as combat progresses so late-game gold drops don't run
## away. Room 1 (index 0) drops full gold_value.
func _scaled_gold_value() -> int:
	var idx: int = _combat_room_index()
	var reduced: float = float(gold_value) / (1.0 + GOLD_ROOM_DECAY * float(idx))
	return max(1, int(round(reduced)))

# Random offset within a small ring so individual drops don't stack together.
func _random_scatter() -> Vector2:
	var angle := randf() * TAU
	return Vector2(cos(angle), sin(angle)) * randf_range(6.0, DROP_SCATTER_RADIUS)

func _on_hitbox_touch(node: Node) -> void:
	var target = node.get_parent() if node is Area2D else node
	if target and (target.is_in_group("player") or target.has_method("take_damage")) and not target.is_in_group("enemies"):
		if can_deal_damage:
			_deal_player_damage(target, _get_outgoing_contact_damage(), self)
			_start_damage_cooldown()

func _process_body_contacts() -> void:
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.is_in_group("player") and can_deal_damage:
			_deal_player_damage(collider, _get_outgoing_contact_damage(), self)
			_start_damage_cooldown()
			return

# NECROTIC decay reduces the enemy's outgoing contact damage.
func _get_outgoing_contact_damage() -> int:
	if frozen_timer > 0.0:
		return 0
	var dmg: float = float(contact_damage)
	if decay_timer > 0.0:
		dmg *= DECAY_DAMAGE_MULT
	return max(0, int(round(dmg)))

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
