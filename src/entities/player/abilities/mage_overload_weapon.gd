extends Weapon

## Mage secondary ability: Mana Overload. While active, every weapon's
## cooldowns are halved (player.cooldown_multiplier = 0.5). This ability's own
## recharge cooldown is unaffected: it only starts AFTER the buff ends.
@export var buff_duration: float = 4.0
@export var recharge: float = 8.0

var _buff_active: bool = false


func _ready() -> void:
	weapon_name = "Mana Overload"
	trigger_type = TriggerType.SECONDARY
	cooldown = recharge
	super._ready()


func try_fire() -> void:
	if not can_fire or _buff_active:
		return
	_activate()


func _activate() -> void:
	can_fire = false
	_buff_active = true
	var p = get_player()
	if p and p.has_method("set_cooldown_multiplier"):
		p.set_cooldown_multiplier(0.5)

	# Let the HUD show the full recharge as the "cooldown" bar.
	cooldown_started.emit(recharge)

	await get_tree().create_timer(buff_duration).timeout
	if not is_instance_valid(self):
		return

	_buff_active = false
	if is_instance_valid(p) and p.has_method("set_cooldown_multiplier"):
		p.set_cooldown_multiplier(1.0)

	# Recharge begins only after the buff ends, using the full cooldown
	# (not affected by the buff, since the multiplier is back to 1.0).
	if cooldown_timer:
		cooldown_timer.start(recharge)
