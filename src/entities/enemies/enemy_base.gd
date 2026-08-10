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

var xp_orb_scene: PackedScene = preload("res://src/pickups/xp_orb.tscn")
var gold_pickup_scene: PackedScene = preload("res://src/pickups/gold_pickup.tscn")

var current_health: int
var can_deal_damage: bool = true
var target_player: Node2D = null
var knockback_velocity: Vector2 = Vector2.ZERO
var hp_value_label: Label = null
var slow_timer: float = 0.0
var slow_factor: float = 1.0

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

func _physics_process(_delta: float) -> void:
	if target_player == null:
		target_player = get_tree().get_first_node_in_group("player") as Node2D
		return
		
	var direction = (target_player.global_position - global_position).normalized()
	velocity = (direction * get_effective_speed(_delta)) + knockback_velocity
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * _delta)
	_process_body_contacts()


func apply_slow(duration: float, factor: float) -> void:
	slow_timer = maxf(slow_timer, duration)
	slow_factor = minf(slow_factor, clampf(factor, 0.05, 1.0))


func get_effective_speed(delta: float) -> float:
	if slow_timer > 0.0:
		slow_timer = maxf(0.0, slow_timer - delta)
		return speed * slow_factor
	return speed

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
	_drop_xp()
	_drop_gold()
	queue_free()

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
	contact_damage = max(0, int(round(float(contact_damage) * mult)))
	# Speed scales at half the rate so enemies don't get too fast late-game
	speed = speed * (1.0 + stat_scale_per_difficulty * 0.5 * difficulty)

	if hp_bar:
		hp_bar.max_value = max_health
		hp_bar.value = current_health

func _drop_xp() -> void:
	if xp_orb_scene:
		var orb = xp_orb_scene.instantiate() as XPOrb
		if orb:
			orb.global_position = global_position
			orb.setup(xp_value, xp_orb_tier)
			get_tree().current_scene.call_deferred("add_child", orb)

func _drop_gold() -> void:
	if gold_pickup_scene:
		var coin = gold_pickup_scene.instantiate() as GoldPickup
		if coin:
			coin.global_position = global_position
			coin.setup(gold_value)
			get_tree().current_scene.call_deferred("add_child", coin)

func _on_hitbox_touch(node: Node) -> void:
	var target = node.get_parent() if node is Area2D else node
	if target and (target.is_in_group("player") or target.has_method("take_damage")) and not target.is_in_group("enemies"):
		if can_deal_damage:
			target.take_damage(contact_damage)
			_apply_thorns_to_attacker(target)
			_start_damage_cooldown()

func _process_body_contacts() -> void:
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.is_in_group("player") and can_deal_damage:
			if collider.has_method("take_damage"):
				collider.take_damage(contact_damage)
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
