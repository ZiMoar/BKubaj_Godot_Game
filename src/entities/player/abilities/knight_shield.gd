class_name KnightShield
extends Weapon

## Knight secondary ability: a Tower Shield raised towards the cursor while
## RMB is held. It blocks enemy projectiles (absorbing their damage into its
## own HP) and pushes back + reflects thorns at enemies that touch it.
##
## The shield has its OWN health, armor, and thorns, derived from the player:
##   - shield HP   = player max HP * shield_hp_ratio  (lower than the player)
##   - shield armor= player armor   * armor_ratio      (lower than the player)
##   - thorns      = player's thorns (kept EQUAL)

@export var offset: float = 54.0
@export var shield_width: float = 30.0
@export var shield_height: float = 66.0
@export var shield_hp_ratio: float = 0.5
@export var armor_ratio: float = 0.6
@export var recharge_time: float = 2.5
@export var push_force: float = 320.0

var shield_hp: float = 0.0
var max_shield_hp: float = 0.0
var shield_armor: float = 0.0
var thorns_damage: float = 0.0
var active: bool = false
var _recharge_remaining: float = 0.0

var _block_zone: Area2D = null
@onready var _hp_bar: ProgressBar = $ShieldHPBar


func _ready() -> void:
	weapon_name = "Tower Shield"
	trigger_type = TriggerType.SECONDARY
	cooldown = recharge_time
	super._ready()

	_block_zone = get_node_or_null("BlockZone") as Area2D
	if _block_zone:
		_block_zone.body_entered.connect(_on_block_body)
		_block_zone.area_entered.connect(_on_block_area)
		_block_zone.monitoring = false
		_block_zone.monitorable = false
		_block_zone.hide()


func get_shield_hp() -> float:
	return shield_hp


func get_max_shield_hp() -> float:
	return max_shield_hp


func _process(delta: float) -> void:
	if _recharge_remaining > 0.0:
		_recharge_remaining = maxf(0.0, _recharge_remaining - delta)
		if _recharge_remaining <= 0.0:
			_repair_shield()

	var p = get_player()
	if p == null:
		return

	var held: bool = Input.is_action_pressed("secondary_attack")
	if held and _recharge_remaining <= 0.0:
		if not active:
			_raise(p)
		_update_position(p)
	else:
		if active:
			_drop(p)


func _raise(p: Node2D) -> void:
	active = true
	max_shield_hp = maxf(10.0, float(p.current_max_health()) * shield_hp_ratio)
	shield_armor = maxf(0.0, p.current_armor() * armor_ratio)
	thorns_damage = maxf(0.0, p.get_thorns_damage())
	# NOTE: shield_hp is NOT reset here — it persists across uses. Only a full
	# break + recharge (see _repair_shield) restores it to full.
	if shield_hp <= 0.0:
		shield_hp = max_shield_hp
	if _block_zone:
		_block_zone.monitoring = true
		_block_zone.monitorable = true
		_block_zone.show()
	_update_hp_bar()


func _update_position(p: Node2D) -> void:
	var aim: Vector2 = get_global_mouse_position() - p.global_position
	if aim.length() < 1.0:
		aim = Vector2.RIGHT
	aim = aim.normalized()
	global_position = p.global_position + aim * offset
	rotation = aim.angle()

	# Keep pushing enemies that touch the barrier while it's held up.
	if _block_zone:
		for body in _block_zone.get_overlapping_bodies():
			if body.is_in_group("enemies") and body.has_method("apply_knockback"):
				body.apply_knockback(global_position, push_force * 0.6)


func _drop(_p: Node2D) -> void:
	active = false
	if _block_zone:
		_block_zone.monitoring = false
		_block_zone.monitorable = false
		_block_zone.hide()
	if _hp_bar:
		_hp_bar.hide()


func shield_is_broken() -> bool:
	return shield_hp <= 0.0


## Applies raw damage to the shield, mitigated by its armor. Breaks the shield
## (and starts the recharge) when HP reaches 0.
func _damage_shield(raw: int) -> void:
	if not active:
		return
	var mitigated: float = float(maxi(0, raw)) * (100.0 / (100.0 + shield_armor))
	shield_hp -= mitigated
	if shield_hp <= 0.0:
		shield_hp = 0.0
		_break()
	else:
		_update_hp_bar()


func _break() -> void:
	active = false
	_recharge_remaining = recharge_time
	if _block_zone:
		_block_zone.monitoring = false
		_block_zone.monitorable = false
		_block_zone.hide()
	if _hp_bar:
		_hp_bar.hide()


## After the recharge elapses, the broken shield is repaired to full HP.
func _repair_shield() -> void:
	shield_hp = max_shield_hp


func _update_hp_bar() -> void:
	if _hp_bar == null:
		return
	_hp_bar.max_value = maxf(1.0, max_shield_hp)
	_hp_bar.value = shield_hp
	_hp_bar.show()


## Called by the BlockZone when an enemy projectile hits the barrier.
func absorb_projectile(damage: int) -> void:
	if not active:
		return
	_damage_shield(damage)


func _on_block_area(area: Area2D) -> void:
	if area == null:
		return
	if area.is_in_group("enemy_projectile"):
		var dmg: int = 1
		if area.has_method("get") and area.get("damage") != null:
			dmg = maxi(1, int(area.get("damage")))
		elif "damage" in area:
			dmg = maxi(1, int(area.damage))
		_damage_shield(dmg)
		if is_instance_valid(area):
			area.queue_free()


func _on_block_body(body: Node2D) -> void:
	if body and body.is_in_group("enemies"):
		if body.has_method("apply_knockback"):
			body.apply_knockback(global_position, push_force)
		if thorns_damage > 0.0 and body.has_method("take_damage"):
			body.take_damage(max(1, int(round(thorns_damage))))
		# Enemies pushing against the shield also drain its HP (so it breaks).
		var cd: float = 10.0
		if body.get("contact_damage") != null:
			cd = float(body.get("contact_damage"))
		_damage_shield(maxi(1, int(round(cd))))
