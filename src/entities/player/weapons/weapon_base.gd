class_name Weapon
extends Node2D

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

var cooldown_timer: Timer
var can_fire: bool = true
var base_cooldown: float = 1.0

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

func try_fire() -> void:
	if can_fire:
		fire()
		can_fire = false
		var effective_cooldown = get_effective_cooldown()
		cooldown_timer.start(effective_cooldown)
		cooldown_started.emit(effective_cooldown)

# Virtual function — overridden by specific weapons
func fire() -> void:
	pass

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

	return maxf(0.05, base_cooldown * player.get_attack_speed_multiplier() * mult)

# Area stat: scales the radius of AOE skills and the size of projectiles.
func get_area_multiplier() -> float:
	var player = get_player()
	if player == null:
		return 1.0
	if player.has_method("get_area_multiplier"):
		return float(player.get_area_multiplier())
	return 1.0

func get_attack_damage(base_damage: float) -> int:
	var player = get_player()
	if player == null:
		return max(0, int(round(base_damage)))

	return player.get_attack_damage(base_damage)

func roll_critical_hit() -> bool:
	var player = get_player()
	if player == null:
		return false

	return player.roll_critical_hit()

func get_critical_multiplier() -> float:
	var player = get_player()
	if player == null:
		return 2.0

	return player.get_critical_multiplier()

func apply_lifesteal() -> void:
	var player = get_player()
	if player:
		player.apply_lifesteal()

func _on_cooldown_finished() -> void:
	can_fire = true
	cooldown_ended.emit()
