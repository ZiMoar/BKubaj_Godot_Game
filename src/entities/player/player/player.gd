class_name Player
extends CharacterBody2D

signal health_changed(current_hp: int, max_hp: int)
signal shield_changed(current_shield: float, max_shield: float)
signal weapons_changed()
signal artefacts_changed()
signal gold_changed(current_gold: int)

const ARTEFACTS: Script = preload("res://src/systems/artefact.gd")
const RadiusRingScene: PackedScene = preload("res://src/effects/radius_ring/radius_ring.tscn")

# --- Player Stats ---
@export_category("Offense")
@export var might_flat_bonus: float = 0.0
@export var might_percent_bonus: float = 0.0
@export var attack_speed_bonus: float = 0.0
@export var critical_hit_chance: float = 0.0
@export var critical_hit_damage_multiplier: float = 2.0
@export var area_bonus: float = 0.0
@export var projectile_speed_bonus: float = 0.0
@export var duration_bonus: float = 0.0
@export var amount_bonus: int = 0
@export var armor_penetration_flat_bonus: float = 0.0
@export var armor_penetration_percent_bonus: float = 0.0
## Chance (0..1) that a damaging hit also inflicts the ailment matching the
## damage type that dealt it (fire=burn, lightning=shock, cold=slow,
## arcane=crit vuln, necrotic=decay, holy=brand, poison=stack, physical=impale).
@export var ailment_chance: float = 0.0

@export_category("Survival & Defense")
@export var max_health: int = 100
@export var max_health_bonus: int = 0
@export var hp_regen_per_second: float = 0.0
@export var armor: float = 0.0
@export var evasion_chance: float = 0.0
## Temporary flat dodge-chance bonus (e.g. Rogue's Smoke Bomb). Added on top of
## the evasion-derived dodge chance; capped with it so dodge can never exceed 95%.
var dodge_chance_bonus: float = 0.0
## Rocketman (engineer ascension): remaining time of the post-Rocket-Jump buff.
var _rocketman_buff_timer: float = 0.0
## Phantom (rogue ascension): the next attack after reappearing deals double dmg.
var _phantom_bonus_attack: bool = false
## Phantom: while invisible, move faster.
var _phantom_invis_active: bool = false
@export var lifesteal_flat: float = 0.0
@export var revive_count: int = 0
@export var revive_health_percent: float = 0.25
@export var thorns_flat: float = 0.0
@export var shield_capacity: float = 0.0

@export_category("Utility & Movement")
@export var speed: float = 200.0
@export var move_speed_percent_bonus: float = 0.0
## True while the run's subclass is Stormchaser (ranger ascension): move speed
## bonuses also apply to damage. Set by StormchaserSubclass._apply_passive.
var stormchaser_active: bool = false
@export var magnet_enabled: bool = false
@export_range(0.0, 2000.0, 1.0) var magnet_range: float = 50.0
@export var dash_charges: int = 1
## Dash-cooldown reduction as a fraction (0.3 = 30% shorter refill). Reused by
## the Winged Boots dash-upgrade pickups. Stored/captured across stages.
@export_range(0.0, 0.8, 0.01) var dash_cooldown: float = 0.0
## Fractional dash-range multiplier (0.3 = +30% dash distance). Winged Boots.
@export var dash_range_bonus: float = 0.0
@export var invincibility_duration: float = 0.05
@export var invincibility_frame_bonus: float = 0.0

@export_category("Progression & Meta")
@export var growth_percent_bonus: float = 0.0
@export var greed_percent_bonus: float = 0.0
@export var luck: float = 0.0
@export var gold: int = 0
@export var rerolls: int = 0
@export var banish_count: int = 0
@export var difficulty: float = 0.0
# Difficulty grows ONCE PER MINUTE instead of per second, so the number ramps
# slowly. Enemy stat scaling is boosted to compensate (see enemies' *_per_difficulty).
@export var difficulty_runtime_per_minute: float = 1.0
@export var pierce_bonus: int = 0

@export_category("Reserved")
@export var shield_placeholder: float = 0.0

var current_health: int
## Co-op only: true when this player went down but a teammate is still alive.
## A ghost can drift around but can't attack and can't be damaged; it is revived
## at full HP when the room is cleared (or the run ends in defeat if everyone
## goes down). False (and unused) in single-player.
var is_ghost: bool = false
## Prevents the defeat flow from firing more than once on this machine.
var _defeat_triggered: bool = false
# Shield is a second HP bar that depletes before health. Fewer, dedicated
# sources grant it (e.g. necrotic soul pickups, regen overheal relic). It
# persists until depleted. Cap defaults to 50% of max health and can be raised
# by relic/source bonuses (shield_cap_ratio_bonus) in the future.
var current_shield: float = 0.0
var shield_cap_ratio_bonus: float = 0.0
const SHIELD_CAP_RATIO_BASE: float = 0.5
var is_invincible: bool = false
var current_move_input: Vector2 = Vector2.ZERO
var revive_remaining: int = 0
var hp_regen_bank: float = 0.0
var difficulty_runtime_bonus: float = 0.0
# Re-entrancy guard: Enlightened Greed (gold->XP) and Avarice (XP->gold) each
# trigger the other's conversion, which would otherwise cascade add_gold ->
# add_xp -> add_gold -> ... forever. When true, freshly-converted gold does not
# feed back into gold->XP again, breaking the loop after one pass.
var _in_gold_to_xp_conversion: bool = false
var _lifesteal_cooldown_remaining: float = 0.0
const LIFESTEAL_COOLDOWN: float = 0.3

# --- Class Mobility Ability (Space) ---
# Per-class movement tool config, keyed by ClassBase.class_ability_id.
const MOBILITY_CONFIG: Dictionary = {
	"shield_charge": {
		"type": "dash",
		"speed": 720.0,
		"duration": 0.30,
		"cooldown": 3.5,
		"invincible": true,
		"shove": 360.0,
	},
	"teleport": {
		"type": "teleport",
		"range": 260.0,
		"cooldown": 3.0,
		"invincible": true,
	},
	"dodge_roll": {
		"type": "dash",
		"speed": 520.0,
		"duration": 0.20,
		"cooldown": 1.5,
		"invincible": true,
	},
	"rocket_jump": {
		"type": "dash",
		"speed": 640.0,
		"duration": 0.34,
		"cooldown": 4.0,
		"invincible": true,
		"shove": 300.0,
	},
	"invisibility": {
		"type": "dash",
		"speed": 560.0,
		"duration": 0.55,
		"cooldown": 6.0,
		"invincible": false,
	},
	"spin_dash": {
		"type": "dash",
		"speed": 620.0,
		"duration": 0.42,
		"cooldown": 3.5,
		"invincible": true,
		"shove": 280.0,
	},
}
var _mobility_active: bool = false
var _mobility_velocity: Vector2 = Vector2.ZERO
var _mobility_time_left: float = 0.0
var _mobility_cd_remaining: float = 0.0
var _mobility_id: String = ""
# Launch position captured at dash start (Rocket Jump blasts around this point).
var _mobility_start_pos: Vector2 = Vector2.ZERO
# Cooldown between Berserker whirlwind damage ticks while the spin-dash is active.
var _whirl_timer: float = 0.0
# Dash charge bank: ready charges. The refill countdown reuses _mobility_cd_remaining.
var _dash_charges_ready: int = 1
# Momentum relic: window (s) of +50% damage after a dash/teleport.
var _momentum_timer: float = 0.0
const MOMENTUM_WINDOW: float = 1.0
const MOMENTUM_DAMAGE_MULT: float = 1.50

# --- Artefact system ---
const MAX_ARTEFACT_SLOTS: int = 5
# Artefact IDs (see Artefact class registry).
const ARTEFACT_ARMOR_TO_THORNS: String = "armor_to_thorns"
const ARTEFACT_LIFESTEAL_CRIT: String = "lifesteal_crit"
const ARTEFACT_LIFESTEAL_TO_DAMAGE: String = "lifesteal_to_damage"
const ARTEFACT_MAXHP_TO_ARMOR: String = "maxhp_to_armor"
const ARTEFACT_REGEN_TO_ATTACK_SPEED: String = "regen_to_attack_speed"
# --- Cursed relic IDs (the seven sins). ---
const ARTEFACT_HUBRIS: String = "hubris"
const ARTEFACT_AVARICE: String = "avarice"
const ARTEFACT_SUCCUBUS_EMBRACE: String = "succubus_embrace"
const ARTEFACT_GREEN_EYED_GAZE: String = "green_eyed_gaze"
const ARTEFACT_INSATIABLE_MAW: String = "insatiable_maw"
const ARTEFACT_BURNING_IRE: String = "burning_ire"
const ARTEFACT_IDLE_FORTITUDE: String = "idle_fortitude"
# Cross-interaction scaling factors for the artefact effects.
const IRON_HEART_ARMOR_RATIO: float = 0.20
const REGEN_TO_ATTACK_SPEED_FACTOR: float = 5.0
const LIFESTEAL_TO_DAMAGE_PER_UNIT: float = 0.03
const THORNS_TO_DAMAGE_PER_UNIT: float = 0.02
# --- Cursed relic (seven sins) scaling factors. ---
const HUBRIS_BOSS_DAMAGE_MULT: float = 1.30
const HUBRIS_BOSS_TAKEN_MULT: float = 1.20
const AVARICE_XP_TO_GOLD_RATIO: float = 0.25
const LUST_LIFESTEAL_MULT: float = 2.0
const LUST_HEAL_REDUCTION: float = 0.60
const ENVY_RADIUS: float = 600.0
const ENVY_DAMAGE_PER_ENEMY: float = 0.02
const ENVY_CRIT_PER_ENEMY: float = 0.01
const ENVY_DAMAGE_CAP: float = 0.60
const ENVY_CRIT_CAP: float = 0.30
const ENVY_NEARBY_TAKEN_MULT: float = 1.04
const GLUTTONY_CHANCE: float = 0.20
const GLUTTONY_FRACTION: float = 0.06
const WRATH_CRIT_DAMAGE_BONUS: float = 0.60
const WRATH_NONCRIT_PENALTY: float = 0.70
const SLOTH_SPEED_MULT: float = 0.80
const SLOTH_REGEN_MULT: float = 2.0
const SLOTH_SHIELD_CAP_BONUS: float = 0.25   # +50% of the 0.5 base shield cap
## Death Knight (knight ascension): damage multiplier while shielded.
const DEATH_KNIGHT_SHIELD_MULT: float = 1.25
## Blood Mage (mage ascension): damage multiplier during Mana Overload.
const BLOOD_MAGE_DAMAGE_MULT: float = 1.6
## Blood Mage: % of max HP drained per spell cast during Mana Overload.
const BLOOD_MAGE_CAST_COST_PCT: float = 0.04

## Sapper (engineer ascension): damage multiplier while a turret is deployed.
const SAPPER_TURRET_DAMAGE_MULT: float = 1.20
## Rocketman (engineer ascension): post-jump damage/speed buff.
const ROCKETMAN_BUFF_DAMAGE_MULT: float = 1.30
const ROCKETMAN_BUFF_SPEED_MULT: float = 1.15
const ROCKETMAN_BUFF_TIME: float = 3.0
## Bladedancer (rogue ascension): damage gain per point of evasion.
const BLADEDANCER_EVASION_DAMAGE: float = 0.004
## Phantom (rogue ascension): damage multiplier on the attack after reappearing.
const PHANTOM_NEXT_ATTACK_MULT: float = 2.0
const PHANTOM_INVIS_SPEED_MULT: float = 1.25
## Bloodrager (berserker ascension): attack-speed gain per max HP, low-HP damage.
const BLOODRAGER_HP_TO_ATTACK_SPEED: float = 0.10
const BLOODRAGER_LOWHP_MULT: float = 1.30

var artefact_ids: Array[String] = []
## Cursed relics occupy a separate pool so they don't crowd out normal relics.
var cursed_artefact_ids: Array[String] = []

# --- Node References ---
@onready var weapons_container: Node2D = $Weapons
@onready var hp_bar: Control = get_node_or_null("HPBar")
@onready var sprite: Sprite2D = $Sprite2D
@onready var magnet_area: Area2D = get_node_or_null("MagnetArea") as Area2D
@onready var magnet_shape: CollisionShape2D = get_node_or_null("MagnetArea/CollisionShape2D") as CollisionShape2D
@onready var hp_value_label: Label = null

func _ready() -> void:
	# The player travels through ALL enemies (both ground mobs and flying ones).
	# Contact damage is handled by the enemies' Hitbox areas, not physical
	# collision, so clear the Enemies (3) and Flying (6) layer bits from our
	# collision mask. This guarantees the player is never body-blocked regardless
	# of any individual enemy's mask.
	collision_mask &= ~(4 | 32)  # drop layer bits 3 (Enemies) and 6 (Flying)

	# Apply the chosen class's starting stat overrides BEFORE computing HP.
	_apply_class_starting_stats()
	# Apply the run's subclass passive (chosen at the Altar, room 10) so its stat
	# bonuses are set before HP is computed.
	_apply_subclass_passive()
	# Swap in this class's pixel-art sprite (defaults to a tinted placeholder).
	_apply_class_sprite()
	# Continuing a run? Restore the carried-over progression (stats, weapons,
	# artefacts, gold) captured from the previous stage's player.
	var run_state: Node = get_node_or_null("/root/GameState")
	var xp_mgr: Node = null
	if run_state and run_state.run_active:
		xp_mgr = get_tree().get_first_node_in_group("team_xp_manager") as Node
		run_state.apply_continue(self, xp_mgr)
	revive_remaining = revive_count
	current_health = max_health + max_health_bonus
	if hp_bar:
		hp_bar.max_value = current_max_health()
		hp_bar.value = current_health
		_ensure_hp_value_label()
		_update_hp_value_label()
		
	call_deferred("_emit_initial_health")
	
	# Fail-safe group registration for enemies
	if not is_in_group("player"):
		add_to_group("player")

	if magnet_area and not magnet_area.area_entered.is_connected(_on_magnet_area_entered):
		magnet_area.area_entered.connect(_on_magnet_area_entered)

	_apply_magnet_settings()

	# Give the player the Primary + Secondary weapons for the chosen class.
	_setup_class_starting_weapons()

func _emit_initial_health() -> void:
	health_changed.emit(current_health, current_max_health())
	_update_hp_value_label()

func get_might_multiplier() -> float:
	return maxf(0.0, 1.0 + might_percent_bonus)

func get_attack_speed_multiplier() -> float:
	# Diminishing returns: 100/(100+x). x=100 -> 0.5x cooldown, x=300 -> 0.25x
	var bonus: float = attack_speed_bonus
	if has_artefact(ARTEFACT_REGEN_TO_ATTACK_SPEED):
		bonus += hp_regen_per_second * REGEN_TO_ATTACK_SPEED_FACTOR
	# Bloodrager (berserker ascension): maximum health increases attack speed.
	if is_subclass("bloodrager"):
		bonus += float(current_max_health()) * BLOODRAGER_HP_TO_ATTACK_SPEED
	return 100.0 / (100.0 + maxf(0.0, bonus))

# Flat armor with the same diminishing-returns formula as attack speed.
# Subclasses/artefacts can inflate armor (the value returned here) without
# changing how the mitigation formula itself works.
func current_armor() -> float:
	var value: float = maxf(0.0, armor)
	if has_artefact(ARTEFACT_MAXHP_TO_ARMOR):
		value += float(current_max_health()) * IRON_HEART_ARMOR_RATIO
	return value

func get_damage_reduction_multiplier() -> float:
	return 100.0 / (100.0 + current_armor())

# Evasion is a FLAT stat with the same diminishing-returns shape as armor:
# chance to be hit = 100/(100+evasion), so this returns the chance to DODGE
# (= 1 - chance to be hit). evasion=100 -> 50% dodge, 300 -> 75%.
func get_evasion_dodge_chance() -> float:
	var ev: float = maxf(0.0, evasion_chance)
	return clampf(ev / (100.0 + ev), 0.0, 0.95)

# Thorns damage actually reflected to attackers. Artefacts can scale it off
# other defensive stats (e.g. armor).
func get_thorns_damage() -> float:
	var value: float = maxf(0.0, thorns_flat)
	if has_artefact(ARTEFACT_ARMOR_TO_THORNS):
		value += current_armor()
	# Retaliator (knight ascension): thorns scale with might.
	if is_subclass("retaliator"):
		value *= get_might_multiplier()
	return value

func get_critical_multiplier() -> float:
	var mult: float = critical_hit_damage_multiplier
	# Wrath (Burning Ire): critical hits deal +60% bonus critical damage.
	if has_artefact(ARTEFACT_BURNING_IRE):
		mult += WRATH_CRIT_DAMAGE_BONUS
	return maxf(1.0, mult)

func roll_critical_hit() -> bool:
	return randf() < clamp(critical_hit_chance + get_envy_crit_bonus(), 0.0, 1.0)

## Rolls whether a damaging hit also inflicts its damage-type's ailment.
func roll_ailment() -> bool:
	return randf() < clamp(ailment_chance, 0.0, 1.0)


## Returns the raw ailment chance (0..1) so callers can apply their own boosts.
func roll_ailment_result() -> float:
	return clamp(ailment_chance, 0.0, 1.0)

## True while the player isn't moving (used by Sloth's Idle Fortitude).
func _is_idle() -> bool:
	return current_move_input.length_squared() < 0.001


## Number of living enemies within the Envy relic's radius.
func nearby_enemy_count() -> int:
	var n: int = 0
	var pos: Vector2 = global_position
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e is Node2D and (e as Node2D).global_position.distance_to(pos) <= ENVY_RADIUS:
			n += 1
	return n


## Envy (Green-Eyed Gaze): bonus damage from nearby enemies, capped.
func get_envy_damage_bonus() -> float:
	if not has_artefact(ARTEFACT_GREEN_EYED_GAZE):
		return 0.0
	return minf(ENVY_DAMAGE_CAP, float(nearby_enemy_count()) * ENVY_DAMAGE_PER_ENEMY)


## Envy (Green-Eyed Gaze): bonus crit chance from nearby enemies, capped.
func get_envy_crit_bonus() -> float:
	if not has_artefact(ARTEFACT_GREEN_EYED_GAZE):
		return 0.0
	return minf(ENVY_CRIT_CAP, float(nearby_enemy_count()) * ENVY_CRIT_PER_ENEMY)


## Gluttony (Insatiable Maw): roll the heal/hurt chances on a picked-up pickup.
func roll_pickup_gluttony() -> void:
	if not has_artefact(ARTEFACT_INSATIABLE_MAW) or current_health <= 0:
		return
	if randf() < GLUTTONY_CHANCE:
		heal_percent(GLUTTONY_FRACTION)
	if randf() < GLUTTONY_CHANCE:
		take_damage(maxi(1, int(round(float(current_max_health()) * GLUTTONY_FRACTION))))


func get_attack_damage(base_damage: float) -> int:
	var flat_applied = maxf(0.0, base_damage + might_flat_bonus)
	var damage = flat_applied * get_might_multiplier()
	# Cross-stat artefacts scale outgoing damage off defensive/utility stats.
	if has_artefact(ARTEFACT_LIFESTEAL_TO_DAMAGE):
		damage *= 1.0 + lifesteal_flat * LIFESTEAL_TO_DAMAGE_PER_UNIT
	# Momentum relic: +50% damage while the post-dash window is active.
	if has_artefact("momentum") and _momentum_timer > 0.0:
		damage *= MOMENTUM_DAMAGE_MULT
	# Envy (Green-Eyed Gaze): bonus damage scaling with nearby enemies.
	var envy_bonus: float = get_envy_damage_bonus()
	if envy_bonus > 0.0:
		damage *= 1.0 + envy_bonus
	# Stormchaser (ranger ascension): move speed bonus also applies to damage.
	if stormchaser_active:
		damage *= 1.0 + maxf(0.0, move_speed_percent_bonus)
	# Death Knight (knight ascension): deal more damage while shielded.
	if is_subclass("death_knight") and current_shield > 0.0:
		damage *= DEATH_KNIGHT_SHIELD_MULT
	# Blood Mage (mage ascension): during Mana Overload, spells deal far more.
	if is_subclass("blood_mage") and is_overload_active():
		damage *= BLOOD_MAGE_DAMAGE_MULT
	# Bladedancer (rogue ascension): damage scales with evasion.
	if is_subclass("bladedancer"):
		damage *= 1.0 + maxf(0.0, evasion_chance) * BLADEDANCER_EVASION_DAMAGE
	# Phantom (rogue ascension): the attack after reappearing deals double damage.
	if is_subclass("phantom") and _phantom_bonus_attack:
		damage *= PHANTOM_NEXT_ATTACK_MULT
		_phantom_bonus_attack = false
	# Sapper (engineer ascension): +20% damage while a turret is deployed.
	if is_subclass("sapper") and not get_tree().get_nodes_in_group("turrets").is_empty():
		damage *= SAPPER_TURRET_DAMAGE_MULT
	# Rocketman (engineer ascension): brief damage buff right after a Rocket Jump.
	if is_subclass("rocketman") and _rocketman_buff_timer > 0.0:
		damage *= ROCKETMAN_BUFF_DAMAGE_MULT
	# Bloodrager (berserker ascension): +30% damage while below half health.
	if is_subclass("bloodrager") and current_health <= current_max_health() * 0.5:
		damage *= BLOODRAGER_LOWHP_MULT
	return max(0, int(round(damage)))

func get_map_difficulty() -> float:
	return maxf(0.0, difficulty + difficulty_runtime_bonus)

# Area stat: scales the radius of AOE skills and the size of projectiles.
# Linear multiplier (1.0 = base). "+50% area" means skills/projectiles are 50% bigger.
func get_area_multiplier() -> float:
	return maxf(0.25, 1.0 + area_bonus)

func advance_runtime_difficulty(amount: float) -> void:
	difficulty_runtime_bonus = maxf(0.0, difficulty_runtime_bonus + amount)


# Extra enemies piercing projectiles can pass through. Placeholder hook so a
# future stat or upgrade can raise it.
func get_extra_pierce() -> int:
	return maxi(0, pierce_bonus)


# Global cooldown multiplier (default 1.0). Mana Overload (mage) sets it to
# 0.5 to halve every weapon's cooldown while its buff is active.
var _cooldown_multiplier: float = 1.0

func get_cooldown_multiplier() -> float:
	return maxf(0.05, _cooldown_multiplier)

func set_cooldown_multiplier(value: float) -> void:
	_cooldown_multiplier = maxf(0.05, value)

## True while Mana Overload (mage secondary) is active. Used by Blood Mage's
## drain-damage tradeoff. Set by mage_overload_weapon.
var overload_active: bool = false

func is_overload_active() -> bool:
	return overload_active

## Blood Mage (mage ascension): casting a spell during Mana Overload costs HP
## as the price of the boosted damage.
func drain_overload_cost() -> void:
	var cost: float = float(current_max_health()) * BLOOD_MAGE_CAST_COST_PCT
	current_health = maxi(1, int(round(float(current_health) - cost)))
	if hp_bar:
		hp_bar.value = current_health
	health_changed.emit(current_health, current_max_health())
	_update_hp_value_label()

func apply_lifesteal() -> void:
	if lifesteal_flat <= 0.0 or current_health <= 0:
		return
	if _lifesteal_cooldown_remaining > 0.0:
		return

	_lifesteal_cooldown_remaining = LIFESTEAL_COOLDOWN
	var heal_amount: float = lifesteal_flat * get_might_multiplier()
	# Lust (Succubus's Embrace): lifesteal is doubled.
	if has_artefact(ARTEFACT_SUCCUBUS_EMBRACE):
		heal_amount *= LUST_LIFESTEAL_MULT
	# Vampiric Rage artefact: lifesteal heal can roll crit for double healing.
	if has_artefact(ARTEFACT_LIFESTEAL_CRIT) and roll_critical_hit():
		heal_amount *= get_critical_multiplier()
	heal(heal_amount)

func heal(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0:
		return
	# Lust (Succubus's Embrace): all healing received is reduced by 40%.
	if has_artefact(ARTEFACT_SUCCUBUS_EMBRACE):
		amount *= LUST_HEAL_REDUCTION
	if amount <= 0.0:
		return

	var max_hp: int = current_max_health()
	var new_hp: float = float(current_health) + amount
	# Death Knight (knight ascension): healing past full health becomes a shield.
	if new_hp > float(max_hp) and is_subclass("death_knight"):
		add_shield(new_hp - float(max_hp))
	current_health = min(max_hp, int(round(new_hp)))
	if hp_bar:
		hp_bar.value = current_health
	health_changed.emit(current_health, current_max_health())
	_update_hp_value_label()


## Heals a percentage (0..1) of the player's max health. Used by heal pickups.
func heal_percent(percent: float) -> void:
	heal(float(current_max_health()) * clampf(percent, 0.0, 1.0))


## Shield cap: defaults to 50% of max health; bonuses can raise it.
func get_shield_cap() -> float:
	var bonus: float = maxf(0.0, shield_cap_ratio_bonus)
	# Sloth (Idle Fortitude): +50% max Shield while standing still.
	if has_artefact(ARTEFACT_IDLE_FORTITUDE) and _is_idle():
		bonus += SLOTH_SHIELD_CAP_BONUS
	return float(current_max_health()) * (SHIELD_CAP_RATIO_BASE + bonus)


## Grants shield up to the cap. Clamped; never exceeds cap.
func add_shield(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0:
		return
	current_shield = minf(get_shield_cap(), current_shield + amount)
	shield_changed.emit(current_shield, get_shield_cap())
	_update_shield_display()


func _update_shield_display() -> void:
	if not has_node("ShieldBar"):
		return
	var sb: ProgressBar = get_node("ShieldBar") as ProgressBar
	sb.max_value = maxf(1.0, get_shield_cap())
	sb.value = clampf(current_shield, 0.0, sb.max_value)
	sb.visible = current_shield > 0.0

const MAX_AUTO_WEAPONS: int = 3

## When networking is active, each Player instance is assigned the class the
## *owning peer* chose (set by the MultiplayerController before spawn). Empty in
## single-player, where GameState's selected class is used instead.
var player_class_id: String = ""

## The class for this specific player: the per-instance co-op override if set,
## otherwise the class chosen in the main menu's class-selection screen
## (GameState autoload). Returns the class node, or null if unavailable.
func _get_selected_class() -> ClassBase:
	var state: Node = get_node_or_null("/root/GameState")
	if state == null:
		return null
	if not player_class_id.is_empty() and state.has_method("get_class_by_id"):
		return state.get_class_by_id(player_class_id) as ClassBase
	if state.has_method("get_selected_class"):
		return state.get_selected_class() as ClassBase
	return null


## The resolved class id for this player (per-instance co-op override if set,
## else the selected class). Used by menus to offer the right subclass options.
func get_class_id() -> String:
	var cls: ClassBase = _get_selected_class()
	return cls.class_id if cls else ""


## True if the run's selected subclass (Altar of Ascension) has the given id.
## Read live by subclass passives (e.g. Hunter's mark, Trickshot's doubling) so
## they work regardless of spawn timing — no per-spawn flag bookkeeping needed.
func is_subclass(id: String) -> bool:
	var state: Node = get_node_or_null("/root/GameState")
	if state == null or not state.has_method("get_selected_subclass"):
		return false
	var sub: Node = state.get_selected_subclass()
	return sub != null and str(sub.get("class_id")) == id


## Applies the run's selected subclass (chosen at the Altar of Ascension, room 10)
## to this player, if its parent class matches this player's class. Runs on every
## spawn because the player re-instantiates each arena — the passive must re-apply
## (static stats + any runtime behavior hooks).
func _apply_subclass_passive() -> void:
	var state: Node = get_node_or_null("/root/GameState")
	if state == null or not state.has_method("get_selected_subclass"):
		return
	var sub: SubclassBase = state.get_selected_subclass()
	if sub == null:
		return
	var cls: ClassBase = _get_selected_class()
	if cls == null or sub.parent_class_id != cls.class_id:
		return
	if sub.has_method("apply"):
		sub.apply(self)


## Applies the selected class's starting stat overrides onto this player.
func _apply_class_starting_stats() -> void:
	var cls: ClassBase = _get_selected_class()
	if cls == null:
		return
	if cls.has_method("apply_starting_stats"):
		cls.apply_starting_stats(self)


## Per-class pixel-art sprite paths, keyed by class_id.
const CLASS_SPRITE_PATHS := {
	"knight": "res://assets/Knight.png",
	"mage": "res://assets/Mage.png",
	"ranger": "res://assets/ranger.png",
}


## Assigns the selected class's sprite to the player's Sprite2D. Falls back to
## the tinted placeholder if no matching class art exists.
func _apply_class_sprite() -> void:
	if sprite == null:
		return
	var cls: ClassBase = _get_selected_class()
	var path: String = ""
	if cls != null and CLASS_SPRITE_PATHS.has(cls.class_id):
		path = CLASS_SPRITE_PATHS[cls.class_id]
	if not path.is_empty() and ResourceLoader.exists(path):
		var tex: Texture2D = load(path) as Texture2D
		if tex != null:
			sprite.texture = tex
			sprite.modulate = Color.WHITE
			# 24px art with a 16-px collision box: render slightly larger.
			sprite.scale = Vector2(0.9, 0.9)


## Equips the class-defined Primary + Secondary weapons from the selected class.
func _setup_class_starting_weapons() -> void:
	if weapons_container == null:
		return
	# When continuing a run, the captured weapon list was already restored —
	# adding the class starting weapons now would duplicate them.
	var run_state: Node = get_node_or_null("/root/GameState")
	if run_state and run_state.run_active and run_state.stage > 1:
		return
	var cls: ClassBase = _get_selected_class()
	if cls == null:
		return
	var scenes: Array[PackedScene] = []
	if cls.primary_weapon_scene != null:
		scenes.append(cls.primary_weapon_scene)
	if cls.secondary_ability_scene != null:
		scenes.append(cls.secondary_ability_scene)
	for scene in scenes:
		var ws: PackedScene = scene as PackedScene
		if ws == null:
			continue
		var weapon: Node = ws.instantiate()
		weapons_container.add_child(weapon)
		if weapon is Weapon and weapon.trigger_type == Weapon.TriggerType.AUTOMATIC:
			weapon.call_deferred("try_fire")
	weapons_changed.emit()


func count_automatic_weapons() -> int:
	var count: int = 0
	for existing in weapons_container.get_children():
		if existing is Weapon and existing.trigger_type == Weapon.TriggerType.AUTOMATIC:
			count += 1
	return count

func can_add_weapon(weapon_scene: PackedScene) -> bool:
	if weapon_scene == null:
		return false
	# Cap only the automatic (chest-earned) weapons; starting primary/secondary don't count
	if count_automatic_weapons() >= MAX_AUTO_WEAPONS:
		return false
	# Prevent taking multiple copies of the same weapon
	for existing in weapons_container.get_children():
		if existing is Weapon and existing.scene_file_path == weapon_scene.resource_path:
			return false
	return true

func add_weapon(weapon_scene: PackedScene) -> Weapon:
	if not can_add_weapon(weapon_scene):
		return null
	var weapon: Weapon = weapon_scene.instantiate() as Weapon
	weapons_container.add_child(weapon)
	# Deferred fire for AUTOMATIC weapons so they activate immediately
	if weapon.trigger_type == Weapon.TriggerType.AUTOMATIC:
		weapon.call_deferred("try_fire")
	weapons_changed.emit()
	return weapon


# --- Artefact equipment ---

## Adds a normal relic. Cursed relics route to the cursed pool instead.
func add_artefact(artefact_id: String) -> bool:
	if artefact_id.is_empty() or has_artefact(artefact_id):
		return false
	if bool(ARTEFACTS.is_cursed(artefact_id)):
		return add_cursed_artefact(artefact_id)
	if artefact_ids.size() >= MAX_ARTEFACT_SLOTS:
		return false
	artefact_ids.append(artefact_id)
	artefacts_changed.emit()
	return true


## Adds a cursed relic. Cursed relics share the SAME 5-slot inventory as normal
## relics (they only differ in source), so the cap is the combined count. There
## is no separate cap on how many may be cursed.
func add_cursed_artefact(artefact_id: String) -> bool:
	if artefact_id.is_empty() or has_artefact(artefact_id):
		return false
	if artefact_ids.size() + cursed_artefact_ids.size() >= MAX_ARTEFACT_SLOTS:
		return false
	cursed_artefact_ids.append(artefact_id)
	artefacts_changed.emit()
	return true


## Removes a relic (normal or cursed) from the inventory. Returns true if it was
## equipped. Used by the overflow "replace" flow to sacrifice an existing relic
## and free a slot for a new one.
func remove_artefact(artefact_id: String) -> bool:
	if artefact_id.is_empty():
		return false
	if artefact_id in artefact_ids:
		artefact_ids.erase(artefact_id)
		artefacts_changed.emit()
		return true
	if artefact_id in cursed_artefact_ids:
		cursed_artefact_ids.erase(artefact_id)
		artefacts_changed.emit()
		return true
	return false


## Checks both normal and cursed pools.
func has_artefact(artefact_id: String) -> bool:
	return artefact_id in artefact_ids or artefact_id in cursed_artefact_ids


func get_artefact_count() -> int:
	return artefact_ids.size() + cursed_artefact_ids.size()


func get_normal_artefact_count() -> int:
	return artefact_ids.size()


func get_cursed_artefact_count() -> int:
	return cursed_artefact_ids.size()


func get_artefact_slot_capacity() -> int:
	return MAX_ARTEFACT_SLOTS


## The display order across the shared 5 slots is: normal relics first, then
## cursed relics.
func _artefact_id_at_slot(slot_index: int) -> String:
	if slot_index < 0:
		return ""
	if slot_index < artefact_ids.size():
		return artefact_ids[slot_index]
	var cursed_idx: int = slot_index - artefact_ids.size()
	if cursed_idx >= 0 and cursed_idx < cursed_artefact_ids.size():
		return cursed_artefact_ids[cursed_idx]
	return ""


func get_artefact_slot_color(slot_index: int) -> Color:
	var id: String = _artefact_id_at_slot(slot_index)
	if id.is_empty():
		return Color(0.25, 0.25, 0.25)
	return ARTEFACTS.get_display_color(id)


func get_artefact_slot_name(slot_index: int) -> String:
	var id: String = _artefact_id_at_slot(slot_index)
	if id.is_empty():
		return ""
	return ARTEFACTS.get_display_name(id)


## Raw artefact id at the given equip slot (combined normal + cursed order,
## matching get_artefact_count and the slot-colour/name helpers). This is what
## the stats overlay / HUD use to list every relic a player owns.
func get_artefact_at_slot(slot_index: int) -> String:
	return _artefact_id_at_slot(slot_index)


## Raw cursed artefact id at the given cursed slot.
func get_cursed_artefact_at_slot(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= cursed_artefact_ids.size():
		return ""
	return cursed_artefact_ids[slot_index]


# --- Gold & Greed ---

func get_gold() -> int:
	return gold


func get_gold_multiplier() -> float:
	var mult: float = 1.0 + maxf(0.0, greed_percent_bonus)
	return mult


func add_gold(raw_amount: int) -> void:
	if raw_amount <= 0:
		return
	var amount := int(round(float(raw_amount) * get_gold_multiplier()))
	gold += amount
	gold_changed.emit(gold)
	# Enlightened Greed artefact: gold gained also grants XP.
	# Guarded so Avarice's XP->gold conversion (which calls add_gold again) does
	# not feed straight back into gold->XP — without the guard the two relics
	# combine into an infinite add_gold <-> add_xp loop.
	if has_artefact("greed_to_xp") and not _in_gold_to_xp_conversion:
		var mgr: Node = get_tree().get_first_node_in_group("team_xp_manager")
		if mgr and mgr.has_method("add_xp"):
			_in_gold_to_xp_conversion = true
			mgr.add_xp(max(1, int(round(float(amount) * 0.25))))
			_in_gold_to_xp_conversion = false


func can_afford(cost: int) -> bool:
	return gold >= cost


func spend_gold(cost: int) -> bool:
	if cost <= 0:
		return true
	if gold < cost:
		return false
	gold -= cost
	gold_changed.emit(gold)
	return true

func apply_upgrade(upgrade_id: String, rarity: int = 0) -> void:
	var value: float = LevelUpMenu.get_effective_value(upgrade_id, rarity)

	match upgrade_id:
		"might_flat":
			might_flat_bonus += value
		"might_percent":
			might_percent_bonus += value
		"attack_speed":
			attack_speed_bonus += value
		"crit_chance":
			critical_hit_chance = clamp(critical_hit_chance + value, 0.0, 1.0)
		"ailment_chance":
			ailment_chance = clamp(ailment_chance + value, 0.0, 1.0)
		"crit_damage":
			critical_hit_damage_multiplier += value
		"area":
			area_bonus += value
		"max_health":
			var hp_val: int = int(round(value))
			max_health_bonus += hp_val
			current_health = min(current_max_health(), current_health + hp_val)
		"move_speed_percent":
			move_speed_percent_bonus += value
		"magnet":
			magnet_enabled = true
			magnet_range += value
			_apply_magnet_settings()
		"armor":
			armor += value
		"evasion":
			evasion_chance += value
		"lifesteal":
			lifesteal_flat += value
		"thorns":
			thorns_flat += value
		"hp_regen":
			hp_regen_per_second += value
		"revive":
			var rev_val: int = int(round(value))
			revive_count += rev_val
			revive_remaining += rev_val
		"invincibility_frames":
			invincibility_duration += value
		"growth":
			growth_percent_bonus += value
		"greed":
			greed_percent_bonus += value
		"luck":
			luck += value
		"difficulty":
			difficulty += value
		_:
			pass

	if hp_bar:
		hp_bar.max_value = current_max_health()
		if hp_bar.value > hp_bar.max_value:
			hp_bar.value = hp_bar.max_value
	_update_hp_value_label()

func set_magnet_enabled(enabled: bool) -> void:
	magnet_enabled = enabled
	_apply_magnet_settings()

func set_magnet_range(new_range: float) -> void:
	magnet_range = maxf(0.0, new_range)
	_apply_magnet_settings()

func _apply_magnet_settings() -> void:
	if magnet_shape and magnet_shape.shape is CircleShape2D:
		(magnet_shape.shape as CircleShape2D).radius = magnet_range

	if magnet_shape:
		magnet_shape.disabled = not magnet_enabled

	if magnet_area:
		magnet_area.monitoring = magnet_enabled

func _on_magnet_area_entered(area: Area2D) -> void:
	if not magnet_enabled:
		return

	if area is XPOrb and not area.is_being_collected:
		area.start_attraction(self)
	elif area is GoldPickup and not area.is_being_collected:
		area.start_attraction(self)
	elif area.is_in_group("soul_pickups") and not area.is_being_collected:
		area.start_attraction(self)

func _physics_process(delta: float) -> void:
	# In multiplayer, only the peer that OWNS this Player node simulates it
	# (movement/aim/attack). Every other peer just receives the owner's synced
	# position via its MultiplayerSynchronizer. With no network peer this guard
	# is a no-op, so single-player is unchanged.
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	# A co-op ghost can drift around but can't attack, cast, regen, or be hurt.
	# It also checks whether a teammate that was alive has now gone down too.
	if is_ghost:
		handle_movement()
		_check_all_dead_defeat()
		return
	handle_movement()
	handle_aiming()
	handle_weapon_inputs()
	_process_class_ability_input(delta)
	_process_regen(delta)
	_process_lifesteal_cooldown(delta)
	if _momentum_timer > 0.0:
		_momentum_timer = maxf(0.0, _momentum_timer - delta)


## Co-op: keeps a remote player's ghost bars in sync. The MultiplayerSynchronizer
## writes current_health/max_health/shield straight onto this (non-authority)
## copy, but those direct writes don't re-trigger the HP/Shield bar updates that
## the owning peer's damage/heal paths do. Poll once a frame so a teammate sees
## your real HP/shield. The owner and single-player (no network peer) are
## unaffected — their bars update through the normal take_damage/heal paths.
func _process(_delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		_sync_replicated_hp_ui()
	# Rocketman (engineer ascension): count down the post-jump buff.
	if _rocketman_buff_timer > 0.0:
		_rocketman_buff_timer = maxf(0.0, _rocketman_buff_timer - _delta)


## Rebuilds the HP/Shield bars from the replicated health fields on a ghost.
func _sync_replicated_hp_ui() -> void:
	if hp_bar:
		hp_bar.max_value = current_max_health()
		hp_bar.value = clampf(current_health, 0, current_max_health())
		_update_hp_value_label()
	if has_node("ShieldBar"):
		var sb: ProgressBar = get_node("ShieldBar") as ProgressBar
		sb.max_value = maxf(1.0, get_shield_cap())
		sb.value = clampf(current_shield, 0.0, sb.max_value)
		sb.visible = current_shield > 0.0


## Co-op: called by the HOST on the peer that OWNS this player when one of the
## host's enemies hit this player's ghost on the host machine. Only the owner
## commits damage to its own player (it is the health authority); the resulting
## HP then replicates back out to everyone. No source is passed, so the owner
## applies the flat hit with its own armor/shield/evasion.
@rpc("any_peer", "reliable")
func apply_network_damage(amount: int) -> void:
	if not is_multiplayer_authority():
		return
	if amount <= 0 or current_health <= 0:
		return
	take_damage(amount, null)


# --- Movement & Aiming ---
func handle_movement() -> void:
	current_move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# While a mobility trick is active, override normal movement with the dash.
	if _mobility_active:
		velocity = _mobility_velocity + current_move_input * current_move_speed() * 0.2
		move_and_slide()
		_tick_mobility_effect()
		_mobility_time_left -= get_physics_process_delta_time()
		if _mobility_time_left <= 0.0:
			_mobility_active = false
			if _mobility_id == "invisibility":
				modulate = Color.WHITE
			_apply_mobility_shove()
		return
	velocity = current_move_input * current_move_speed()
	move_and_slide()

func current_max_health() -> int:
	return max(1, max_health + max_health_bonus)

func current_move_speed() -> float:
	var base: float = maxf(0.0, speed) * maxf(0.0, 1.0 + move_speed_percent_bonus)
	# Sloth (Idle Fortitude): move speed -20%.
	if has_artefact(ARTEFACT_IDLE_FORTITUDE):
		base *= SLOTH_SPEED_MULT
	# Rocketman (engineer ascension): +15% speed right after a Rocket Jump.
	if is_subclass("rocketman") and _rocketman_buff_timer > 0.0:
		base *= ROCKETMAN_BUFF_SPEED_MULT
	# Phantom (rogue ascension): move faster while invisible.
	if is_subclass("phantom") and _phantom_invis_active:
		base *= PHANTOM_INVIS_SPEED_MULT
	return base

# --- Class Mobility Ability (Space) ---
func _process_class_ability_input(delta: float) -> void:
	var cfg: Dictionary = MOBILITY_CONFIG.get(_get_class_ability_id(), {})
	if str(cfg.get("type", "")) == "dash":
		_process_dash_charge_refill(delta, cfg)
	elif _mobility_cd_remaining > 0.0:
		_mobility_cd_remaining = maxf(0.0, _mobility_cd_remaining - delta)
	if Input.is_action_just_pressed("class_ability"):
		trigger_class_ability()


## Refills dash charges over time (each charge refills after the cooldown, which
## the Winged Boots cooldown-reduction shortens). Only applies to dash-type moves.
func _process_dash_charge_refill(delta: float, cfg: Dictionary) -> void:
	var max_charges: int = maxi(1, dash_charges)
	if _dash_charges_ready >= max_charges:
		return
	_mobility_cd_remaining -= delta
	if _mobility_cd_remaining <= 0.0:
		_dash_charges_ready = mini(max_charges, _dash_charges_ready + 1)
		_mobility_cd_remaining = _effective_dash_cooldown(cfg)


## Default per-dash refill time (config cooldown reduced by dash_cooldown bonus).
func _effective_dash_cooldown(cfg: Dictionary) -> float:
	# Whirlmaster (berserker ascension): Whirlwind's cooldown drops to 1s and is
	# shortened by attack speed.
	if is_subclass("whirlmaster") and _get_class_ability_id() == "spin_dash":
		return maxf(0.05, 1.0 * get_attack_speed_multiplier())
	return maxf(0.05, float(cfg.get("cooldown", 1.0)) * (1.0 - clampf(dash_cooldown, 0.0, 0.8)))


func _get_class_ability_id() -> String:
	var cls: ClassBase = _get_selected_class()
	if cls == null:
		return ""
	return str(cls.get("class_ability_id"))

func trigger_class_ability() -> void:
	if _mobility_active:
		return
	var ab_id: String = _get_class_ability_id()
	_mobility_id = ab_id
	var cfg: Dictionary = MOBILITY_CONFIG.get(ab_id, {})
	if cfg.is_empty() or cfg.get("type", "") == "":
		return
	# Dash-type moves draw from the charge bank; teleport uses a single cooldown.
	if str(cfg.get("type", "")) == "dash":
		if _dash_charges_ready < 1:
			return
		_dash_charges_ready -= 1
		_mobility_cd_remaining = _effective_dash_cooldown(cfg)
		var direction: Vector2 = _mobility_direction()
		_start_dash(cfg, direction)
		return
	if _mobility_cd_remaining > 0.0:
		return
	var direction2: Vector2 = _mobility_direction()
	if cfg.get("type") == "teleport":
		_do_teleport(cfg, direction2)
		_mobility_cd_remaining = float(cfg.get("cooldown", 1.0))

# --- Public queries for the HUD ability-cooldown display ---
## Id of the current class ability (e.g. "shield_charge"), or "" if none.
func get_class_ability_id() -> String:
	if _mobility_id != "":
		return str(_mobility_id)
	return _get_class_ability_id()


## Human-readable label for the current class ability (e.g. "Shield Charge").
func get_class_ability_name() -> String:
	var names: Dictionary = {
		"shield_charge": "Shield Charge",
		"teleport": "Teleport",
		"dodge_roll": "Dodge Roll",
		"rocket_jump": "Rocket Jump",
		"invisibility": "Invisibility",
		"spin_dash": "Whirlwind",
	}
	return str(names.get(_mobility_id, ""))


## Cooldown ready fraction: 0.0 = ready, 1.0 = just used (full CD remaining).
func get_class_ability_cooldown_ratio() -> float:
	var cfg: Dictionary = MOBILITY_CONFIG.get(_mobility_id, {})
	var total: float = _effective_dash_cooldown(cfg)
	if total <= 0.0:
		return 0.0
	return clampf(_mobility_cd_remaining / total, 0.0, 1.0)


func is_class_ability_ready() -> bool:
	if _mobility_active:
		return false
	if str(MOBILITY_CONFIG.get(_mobility_id, {}).get("type", "")) == "dash":
		return _dash_charges_ready > 0
	return _mobility_cd_remaining <= 0.0


## Winged Boots: grant +1 stored dash charge (raises the bank AND the ready pool).
func add_dash_charge() -> void:
	dash_charges = maxi(1, dash_charges + 1)
	_dash_charges_ready = maxi(_dash_charges_ready, mini(dash_charges, _dash_charges_ready + 1))


## Winged Boots: shorten the dash cooldown by the given fraction (0.25 = 25% faster).
func reduce_dash_cooldown(fraction: float) -> void:
	dash_cooldown = clampf(dash_cooldown + fraction, 0.0, 0.8)


## Winged Boots: increase dash range by the given fraction (0.30 = +30% distance).
func increase_dash_range(fraction: float) -> void:
	dash_range_bonus = maxf(0.0, dash_range_bonus + fraction)


func _mobility_direction() -> Vector2:
	# Prefer movement direction if present, else fall back to facing/aim.
	if current_move_input.length_squared() > 0.01:
		return current_move_input.normalized()
	var to_mouse: Vector2 = get_global_mouse_position() - global_position
	if to_mouse.length_squared() > 1.0:
		return to_mouse.normalized()
	return Vector2.RIGHT

func _start_dash(cfg: Dictionary, direction: Vector2) -> void:
	_mobility_active = true
	_mobility_velocity = direction * float(cfg.get("speed", 500.0))
	# Winged Boots range bonus scales how far the dash carries (duration).
	_mobility_time_left = float(cfg.get("duration", 0.25)) * (1.0 + maxf(0.0, dash_range_bonus))
	if cfg.get("invincible", true):
		start_mobility_invincibility(_mobility_time_left + 0.1)
	if has_artefact("momentum"):
		_momentum_timer = MOMENTUM_WINDOW
	_on_mobility_start(cfg, direction)

func _do_teleport(cfg: Dictionary, direction: Vector2) -> void:
	var range_: float = float(cfg.get("range", 240.0))
	var target: Vector2 = global_position + direction * range_
	# Clamp to the arena's interior so the mage can't blink through walls.
	var floor_node: Node = _find_floor_node()
	if floor_node != null and floor_node.get("arena_center") != null and floor_node.get("arena_size") != null:
		var arena_center: Vector2 = floor_node.arena_center
		var arena_size: Vector2 = floor_node.arena_size
		var margin := 40.0
		var bounds: Rect2 = Rect2(arena_center - arena_size * 0.5 + Vector2(margin, margin), arena_size - Vector2(margin * 2.0, margin * 2.0))
		target.x = clampf(target.x, bounds.position.x, bounds.position.x + bounds.size.x)
		target.y = clampf(target.y, bounds.position.y, bounds.position.y + bounds.size.y)
	global_position = target
	if cfg.get("invincible", true):
		start_mobility_invincibility(0.25)
	if has_artefact("momentum"):
		_momentum_timer = MOMENTUM_WINDOW
	_apply_mobility_shove()

## Rogue's Smoke Bomb: grants a flat dodge-chance bonus for `duration` seconds,
## then removes it. Stacks additively with evasion (and Ghost Step) toward the cap.
func set_smoke_bomb(bonus: float, duration: float) -> void:
	dodge_chance_bonus = clampf(bonus, 0.0, 1.0)
	await get_tree().create_timer(maxf(0.01, duration)).timeout
	if is_instance_valid(self):
		dodge_chance_bonus = 0.0


## Per-class dash special effects, run when a dash starts.
func _on_mobility_start(_cfg: Dictionary, _direction: Vector2) -> void:
	_mobility_start_pos = global_position
	match _mobility_id:
		"rocket_jump":
			_rocket_jump_blast(_mobility_start_pos)
		"invisibility":
			_start_invisibility(_mobility_time_left)
		"spin_dash":
			_spawn_follow_ring(100.0, _mobility_time_left, Color(0.9, 0.4, 0.3, 0.6))


## Spawn a radius ring that follows the player (used for the Whirlwind dash's
## damage radius while it spins).
func _spawn_follow_ring(radius: float, dur: float, col: Color) -> void:
	var ring: Node = RadiusRingScene.instantiate()
	ring.name = "DashRadiusRing"
	add_child(ring)
	ring.position = Vector2.ZERO
	if ring.has_method("setup"):
		ring.setup(radius, dur, col)


## Tick per-frame effects while a dash is active (e.g. the Berserker whirlwind).
func _tick_mobility_effect() -> void:
	if _mobility_id == "spin_dash":
		_spin_dash_whirlwind()


## Rocket Jump: deal basic-attack-grade FIRE damage around the launch point, in
## the same radius as the Grenade Launcher's blast (inheriting its upgrades).
func _rocket_jump_blast(origin: Vector2) -> void:
	var weapon: Weapon = _class_primary_weapon()
	if weapon == null:
		return
	var dmg: int = weapon.get_attack_damage(float(weapon.get("damage")))
	var crit: bool = weapon.roll_critical_hit()
	if crit:
		dmg = int(round(float(dmg) * weapon.get_critical_multiplier()))
	var radius: float = 80.0
	if "blast_radius" in weapon:
		radius = float(weapon.blast_radius) * weapon.get_area_multiplier()
	# Rocketman (engineer ascension): doubled blast radius & knockback + a buff.
	var rocketman: bool = is_subclass("rocketman")
	if rocketman:
		radius *= 2.0
		_rocketman_buff_timer = ROCKETMAN_BUFF_TIME
	var knockback_force: float = 440.0 if rocketman else 220.0
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if origin.distance_to(en.global_position) <= radius:
			var dmg_dealt: int = weapon.apply_range_damage_multiplier(dmg, origin.distance_to(en.global_position))
			en.take_damage(dmg_dealt, crit, weapon.damage_type if weapon != null else DamageType.Type.FIRE, false, weapon.get_ailment_effect_multiplier())
			if en.has_method("apply_knockback"):
				en.apply_knockback(origin, knockback_force)
			apply_lifesteal()
			if en.has_method("has_died") and en.has_died():
				weapon.apply_explosion_on_kill(en.global_position, dmg_dealt)
	# Visual: show the blast radius at the launch point.
	var ring: Node = RadiusRingScene.instantiate()
	ring.name = "RocketJumpRing"
	get_tree().current_scene.add_child(ring)
	ring.global_position = origin
	if ring.has_method("setup"):
		ring.setup(radius, 0.7, Color(1.0, 0.55, 0.2, 0.7))


## Invisibility: become see-through and invincible for the dash's duration.
func _start_invisibility(duration: float) -> void:
	is_invincible = true
	modulate = Color(1, 1, 1, 0.25)
	# Phantom (rogue ascension): vanish slows nearby enemies and speeds you up.
	var phantom: bool = is_subclass("phantom")
	if phantom:
		_phantom_invis_active = true
		for e: Node in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e):
				continue
			var en: Node2D = e as Node2D
			if en.global_position.distance_to(global_position) <= 180.0 and en.has_method("apply_slow"):
				en.apply_slow(2.0, 0.5)
	await get_tree().create_timer(maxf(0.01, duration)).timeout
	if not is_instance_valid(self):
		return
	modulate = Color.WHITE
	is_invincible = false
	if phantom:
		_phantom_invis_active = false
		# The next attack after reappearing deals double damage.
		_phantom_bonus_attack = true


## Whirlwind: while the Berserker's spin-dash is active, periodically damage
## everything in a radius around the player (like the Spin Axe).
func _spin_dash_whirlwind() -> void:
	_whirl_timer -= get_physics_process_delta_time()
	if _whirl_timer > 0.0:
		return
	_whirl_timer = 0.15
	var weapon: Weapon = _class_primary_weapon()
	if weapon == null:
		return
	var dmg: int = weapon.get_attack_damage(float(weapon.get("damage")))
	var radius: float = 100.0
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if global_position.distance_to(en.global_position) <= radius:
			var dmg_dealt: int = weapon.apply_range_damage_multiplier(dmg, global_position.distance_to(en.global_position))
			en.take_damage(dmg_dealt, false, weapon.damage_type if weapon != null else DamageType.Type.PHYSICAL, false, weapon.get_ailment_effect_multiplier())
			apply_lifesteal()
			if en.has_method("has_died") and en.has_died():
				weapon.apply_explosion_on_kill(en.global_position, dmg_dealt)


## The class's primary weapon (used to share basic-attack damage with dashes).
func _class_primary_weapon() -> Weapon:
	if weapons_container == null:
		return null
	for w: Node in weapons_container.get_children():
		if w is Weapon and w.trigger_type == Weapon.TriggerType.PRIMARY:
			return w as Weapon
	return null


func start_mobility_invincibility(duration: float) -> void:
	_start_invincibility_effect(duration, Color(0.6, 0.8, 1.0, 0.7))

# Room a dash/teleport packs a little punch: shove nearby enemies back.
func _apply_mobility_shove() -> void:
	if _mobility_id == "dodge_roll":
		return
	var cfg: Dictionary = MOBILITY_CONFIG.get(_mobility_id, {})
	var shove: float = float(cfg.get("shove", 0.0))
	if shove <= 0.0:
		return
	var radius := 70.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.has_method("apply_knockback"):
			continue
		if global_position.distance_to(enemy.global_position) <= radius:
			enemy.apply_knockback(global_position, shove)

func _find_floor_node() -> Node:
	var node: Node = self
	while node != null:
		var f: Node = node.get_node_or_null("Floor")
		if f != null:
			return f
		node = node.get_parent()
	return null

func _process_lifesteal_cooldown(delta: float) -> void:
	if _lifesteal_cooldown_remaining > 0.0:
		_lifesteal_cooldown_remaining = maxf(0.0, _lifesteal_cooldown_remaining - delta)

func _process_regen(delta: float) -> void:
	if hp_regen_per_second <= 0.0 or current_health <= 0:
		return

	var regen_per_second: float = hp_regen_per_second
	# Sloth (Idle Fortitude): HP Regen is doubled while standing still.
	if has_artefact(ARTEFACT_IDLE_FORTITUDE) and _is_idle():
		regen_per_second *= SLOTH_REGEN_MULT
	hp_regen_bank += regen_per_second * delta
	if hp_regen_bank < 1.0:
		return

	var regen_amount = int(floor(hp_regen_bank))
	hp_regen_bank -= regen_amount
	var max_hp: int = current_max_health()
	# Regen Overload relic: excess regen (healing past full HP) converts to shield
	# instead of being wasted. Only per-second regen, not active heals.
	if has_artefact("regen_to_shield") and regen_amount > 0:
		var deficit: int = maxi(0, max_hp - current_health)
		var overheal: float = maxf(0.0, float(regen_amount) - float(deficit))
		if overheal > 0.0:
			current_health = min(max_hp, current_health + regen_amount)
			add_shield(overheal)
			regen_amount -= int(round(overheal))
	current_health = min(max_hp, current_health + regen_amount)
	if hp_bar:
		hp_bar.value = current_health
	health_changed.emit(current_health, current_max_health())
	_update_hp_value_label()

func handle_aiming() -> void:
	# Flip sprite based on mouse position relative to player (no rotation)
	sprite.flip_h = get_global_mouse_position().x < global_position.x

# --- Weapon Delegation ---
func handle_weapon_inputs() -> void:
	if weapons_container == null:
		return

	# 1. Primary Action (Left Click) — Guns, Bows, Staffs, Main Melee
	if Input.is_action_pressed("primary_attack"):
		for weapon in weapons_container.get_children():
			if weapon.has_method("try_fire") and weapon.trigger_type == Weapon.TriggerType.PRIMARY:
				weapon.try_fire()

	# 2. Secondary Action (Right Click) — Sword Slashes, Traps, Shields, Utility
	if Input.is_action_just_pressed("secondary_attack"):
		for weapon in weapons_container.get_children():
			if weapon.has_method("try_fire") and weapon.trigger_type == Weapon.TriggerType.SECONDARY:
				weapon.try_fire()

	# 3. Automatic Weapons — Books, Auras, Orbiters (Fires on internal timers)
	for weapon in weapons_container.get_children():
		if weapon.has_method("try_fire") and weapon.trigger_type == Weapon.TriggerType.AUTOMATIC:
			weapon.try_fire()

# --- Health & Damage System ---
# Minimum time between hits from the SAME source. Prevents a single enemy /
# projectile from hitting the player repeatedly within a short window even
# though the global invincibility flash alone is very short (0.05s).
const SOURCE_HIT_COOLDOWN: float = 0.5
# Tracks the last time each damage source hit the player (Node -> epoch seconds).
var _source_last_hit: Dictionary = {}

func take_damage(amount: int, source: Node = null) -> void:
	if is_invincible:
		return
	if is_ghost:
		return  # a co-op ghost is invulnerable until revived

	# Global i-frames are intentionally short (0.05s). Most incoming damage is
	# instead throttled per-source: a single source can't hit more than once per
	# SOURCE_HIT_COOLDOWN, but different sources can still pile damage on.
	if source != null and is_instance_valid(source):
		var now: float = Time.get_ticks_msec() / 1000.0
		var last: float = _source_last_hit.get(source, -INF)
		if now - last < SOURCE_HIT_COOLDOWN:
			return
		_source_last_hit[source] = now

	# Evasion is a FLAT stat like armor: chance to be hit = 100/(100+evasion), so
	# dodge chance = 1 - that = evasion/(100+evasion). The Ghost Step relic adds a
	# flat +20% dodge chance while a dash charge is ready.
	var dodge_chance: float = get_evasion_dodge_chance() + dodge_chance_bonus
	if has_artefact("ghost_step") and is_class_ability_ready():
		dodge_chance = clampf(dodge_chance + 0.20, 0.0, 0.95)
	dodge_chance = clampf(dodge_chance, 0.0, 0.95)

	var dodged: bool = randf() < dodge_chance
	# Bladedancer (rogue ascension): lucky dodge — roll twice, dodge if either hits.
	if not dodged and is_subclass("bladedancer"):
		dodged = randf() < dodge_chance
	if dodged:
		trigger_evasion()
		return

	# Cursed-relic damage taken modifiers.
	var curse_mult: float = 1.0
	# Pride (Hubris): take +20% damage from bosses.
	if has_artefact(ARTEFACT_HUBRIS) and source != null and is_instance_valid(source) and source.is_in_group("bosses"):
		curse_mult *= HUBRIS_BOSS_TAKEN_MULT
	# Envy (Green-Eyed Gaze): nearby enemies deal +4% damage to you.
	if has_artefact(ARTEFACT_GREEN_EYED_GAZE) and source != null and is_instance_valid(source) and source is Node2D:
		if (source as Node2D).global_position.distance_to(global_position) <= ENVY_RADIUS:
			curse_mult *= ENVY_NEARBY_TAKEN_MULT
	if curse_mult != 1.0:
		amount = maxi(1, int(round(float(amount) * curse_mult)))

	# Radiant Barrier (holy auto-weapon): an active barrier can reduce/absorb the
	# next hit taken and release a holy wave. Ask any active barrier to process
	# this hit; it returns the damage that still gets through.
	amount = _try_radiant_barrier(amount)
	if amount <= 0:
		trigger_invincibility()
		return

	# Flat armor uses the same diminishing-returns formula as attack speed:
	# 100/(100+armor). armor=100 -> 50% damage taken, armor=300 -> 25%.
	var mitigated_damage = maxf(0.0, float(amount) * get_damage_reduction_multiplier())

	# Shield absorbs the (already mitigated) damage before it hits health, acting
	# as a second HP bar that depletes first.
	if current_shield > 0.0:
		var absorbed: float = minf(current_shield, mitigated_damage)
		current_shield -= absorbed
		mitigated_damage -= absorbed
		shield_changed.emit(current_shield, get_shield_cap())
		_update_shield_display()

	current_health = max(0, current_health - int(round(mitigated_damage)))
	if hp_bar:
		hp_bar.value = current_health
	health_changed.emit(current_health, current_max_health())
	_update_hp_value_label()
	print("Player took damage! Current HP: ", current_health)
	
	if current_health <= 0:
		die()
	else:
		trigger_invincibility()

func trigger_invincibility() -> void:
	_start_invincibility_effect(invincibility_duration + invincibility_frame_bonus, Color(1, 0.3, 0.3, 0.7))

func trigger_evasion() -> void:
	_start_invincibility_effect(invincibility_duration + invincibility_frame_bonus, Color(0.35, 0.85, 1.0, 0.75))


## Asks any active Radiant Barrier (holy auto-weapon, in group "radiant_barrier")
## to process an incoming hit. The barrier reduces the damage (this hit becomes
## "blocked") and releases a holy wave; returns the damage that still gets
## through (0 if fully absorbed).
func _try_radiant_barrier(amount: int) -> int:
	var barriers := get_tree().get_nodes_in_group("radiant_barrier")
	var remaining: int = amount
	for b: Node in barriers:
		if is_instance_valid(b) and b.has_method("block_hit"):
			remaining = int(b.block_hit(amount))
			if remaining < amount:
				break  # an active barrier blocked this hit
	return remaining

func _start_invincibility_effect(duration: float, flash_color: Color) -> void:
	is_invincible = true
	modulate = flash_color
	
	await get_tree().create_timer(maxf(0.01, duration)).timeout
	
	modulate = Color(1, 1, 1, 1)
	is_invincible = false

func die() -> void:
	if revive_remaining > 0:
		# Second Wind relic: 50% chance the revive stack is NOT consumed.
		if not has_artefact("second_wind") or randf() >= 0.5:
			revive_remaining -= 1
		current_health = max(1, int(round(current_max_health() * maxf(0.01, revive_health_percent))))
		if hp_bar:
			hp_bar.value = current_health
		health_changed.emit(current_health, current_max_health())
		_update_hp_value_label()
		trigger_invincibility()
		return

	# Co-op: if a teammate is still standing, don't end the run — this player
	# becomes an invulnerable ghost and is revived when the room is cleared.
	if multiplayer.has_multiplayer_peer() and _has_alive_teammate():
		_enter_ghost_state()
		return
	_end_run_defeat()


## Ends the run on this machine (summary / reload). Extracted so both the normal
## "last player down" path and the co-op all-downed check can trigger it once.
func _end_run_defeat() -> void:
	if _defeat_triggered:
		return
	_defeat_triggered = true
	print("Player Died! Showing run summary...")
	# Capture the final difficulty + gold for the end-of-run summary BEFORE the
	# scene is torn down (the player is still valid here).
	var run_state: Node = get_node_or_null("/root/GameState")
	if run_state:
		if run_state.has_method("set_run_difficulty_at_end"):
			run_state.set_run_difficulty_at_end(get_map_difficulty())
		if run_state.has_method("set_run_gold_at_end"):
			run_state.set_run_gold_at_end(gold)
		if run_state.has_method("end_run"):
			run_state.end_run()
		if run_state.has_method("get_summary_scene_path"):
			call_deferred("_go_to_summary", run_state.get_summary_scene_path())
			return
	# Fallback: no GameState summary wiring — just reload to restart.
	call_deferred("_reload_current_scene_safe")


## True if any OTHER player (not self) is still alive — used to decide whether a
## downed co-op player should become a ghost rather than end the run.
func _has_alive_teammate() -> bool:
	for p: Node in get_tree().get_nodes_in_group("player"):
		if p == self:
			continue
		if not (p as Player).is_ghost and (p as Player).current_health > 0:
			return true
	return false


## True when EVERY player (including self) is down — i.e. the room can't be
## cleared by anyone, so the run should end in defeat.
func _all_players_dead() -> bool:
	for p: Node in get_tree().get_nodes_in_group("player"):
		if (p as Player).current_health > 0:
			return false
	return true


## Co-op downed state: invulnerable, can move but not act, until room clear.
func _enter_ghost_state() -> void:
	if is_ghost:
		return
	is_ghost = true
	current_health = 0
	# Ghostly tint so the state is obvious to both players.
	modulate = Color(1.0, 1.0, 1.0, 0.45)
	if hp_bar:
		hp_bar.value = 0
	health_changed.emit(0, current_max_health())
	_update_hp_value_label()


## Co-op: restores a downed player to full HP (called when the room is cleared).
func revive() -> void:
	if not is_ghost:
		return
	is_ghost = false
	current_health = current_max_health()
	modulate = Color.WHITE
	if hp_bar:
		hp_bar.max_value = current_max_health()
		hp_bar.value = current_health
	health_changed.emit(current_health, current_max_health())
	_update_hp_value_label()


## A ghost polls once a frame: if everyone is now down (a teammate who was alive
## went down too), nobody can clear the room, so end the run in defeat.
func _check_all_dead_defeat() -> void:
	if _all_players_dead():
		_end_run_defeat()

func _go_to_summary(path: String) -> void:
	var tree := get_tree()
	if tree and not path.is_empty():
		tree.change_scene_to_file(path)

func _reload_current_scene_safe() -> void:
	var tree := get_tree()
	if tree and tree.current_scene:
		tree.reload_current_scene()

# --- Run persistence (used to carry progression into the next stage) ---

## Returns a snapshot of the player's full progression so the next stage's fresh
## Player instance can be rebuilt identically.
func capture_run_state() -> Dictionary:
	var stats: Dictionary = {
		"current_health": current_health,
		"max_health_bonus": max_health_bonus,
		"max_health": max_health,
		"revive_remaining": revive_remaining,
		"might_flat_bonus": might_flat_bonus,
		"might_percent_bonus": might_percent_bonus,
		"attack_speed_bonus": attack_speed_bonus,
		"critical_hit_chance": critical_hit_chance,
		"critical_hit_damage_multiplier": critical_hit_damage_multiplier,
		"ailment_chance": ailment_chance,
		"area_bonus": area_bonus,
		"projectile_speed_bonus": projectile_speed_bonus,
		"duration_bonus": duration_bonus,
		"amount_bonus": amount_bonus,
		"armor_penetration_flat_bonus": armor_penetration_flat_bonus,
		"armor_penetration_percent_bonus": armor_penetration_percent_bonus,
		"hp_regen_per_second": hp_regen_per_second,
		"armor": armor,
		"evasion_chance": evasion_chance,
		"lifesteal_flat": lifesteal_flat,
		"revive_count": revive_count,
		"revive_health_percent": revive_health_percent,
		"thorns_flat": thorns_flat,
		"shield_capacity": shield_capacity,
		"move_speed_percent_bonus": move_speed_percent_bonus,
		"magnet_enabled": magnet_enabled,
		"magnet_range": magnet_range,
		"dash_charges": dash_charges,
		"dash_cooldown": dash_cooldown,
		"dash_range_bonus": dash_range_bonus,
		"invincibility_duration": invincibility_duration,
		"invincibility_frame_bonus": invincibility_frame_bonus,
		"growth_percent_bonus": growth_percent_bonus,
		"greed_percent_bonus": greed_percent_bonus,
		"luck": luck,
		"gold": gold,
		"rerolls": rerolls,
		"banish_count": banish_count,
		"difficulty": difficulty,
		"difficulty_runtime_bonus": difficulty_runtime_bonus,
		"pierce_bonus": pierce_bonus,
		"artefact_ids": artefact_ids.duplicate(),
		"cursed_artefact_ids": cursed_artefact_ids.duplicate(),
	}
	# Capture each equipped weapon by its scene path + its anvil stat bonuses.
	var weapons: Array[Dictionary] = []
	if weapons_container:
		for w: Node in weapons_container.get_children():
			if not (w is Weapon):
				continue
			var path: String = w.scene_file_path
			if path.is_empty():
				continue
			weapons.append({
				"path": path,
				"projectile_count_bonus": w.projectile_count_bonus,
				"pierce_bonus": w.pierce_bonus,
				"chain_count_bonus": w.chain_count_bonus,
				"area_bonus": w.area_bonus,
				"repeat_chance": w.repeat_chance,
				"anvil_upgrade_count": w.anvil_upgrade_count,
				"projectile_speed_bonus": w.projectile_speed_bonus,
				"close_range_damage_bonus": w.close_range_damage_bonus,
				"far_range_damage_bonus": w.far_range_damage_bonus,
				"explosion_on_kill_chance": w.explosion_on_kill_chance,
				"damage_percent_bonus": w.damage_percent_bonus,
				"damage_type": int(w.damage_type),
				"signature_ids": (w.signature_ids as Array[String]).duplicate(),
			})
	stats["weapons"] = weapons
	return stats


## Rebuilds this (freshly-instantiated) player from a captured run snapshot.
func restore_run_state(snap: Dictionary) -> void:
	for key: String in snap.keys():
		if key in self and key != "weapons":
			set(key, snap[key])
	# Restore the equipped weapon list (this player had no weapons yet).
	if weapons_container and snap.has("weapons"):
		var weapons: Array = snap["weapons"]
		for wdata: Dictionary in weapons:
			var path: String = wdata.get("path", "")
			if path.is_empty():
				continue
			var ws: PackedScene = load(path) as PackedScene
			if ws == null:
				continue
			if not can_add_weapon(ws):
				continue
			var weapon: Weapon = ws.instantiate() as Weapon
			weapons_container.add_child(weapon)
			weapon.projectile_count_bonus = wdata.get("projectile_count_bonus", 0)
			weapon.pierce_bonus = wdata.get("pierce_bonus", 0)
			weapon.chain_count_bonus = wdata.get("chain_count_bonus", 0)
			weapon.area_bonus = wdata.get("area_bonus", 0.0)
			weapon.repeat_chance = float(wdata.get("repeat_chance", wdata.get("repeat_bonus", 0)))
			weapon.anvil_upgrade_count = int(wdata.get("anvil_upgrade_count", 0))
			weapon.projectile_speed_bonus = wdata.get("projectile_speed_bonus", 0.0)
			weapon.close_range_damage_bonus = wdata.get("close_range_damage_bonus", 0.0)
			weapon.far_range_damage_bonus = wdata.get("far_range_damage_bonus", 0.0)
			weapon.explosion_on_kill_chance = wdata.get("explosion_on_kill_chance", 0.0)
			weapon.damage_percent_bonus = wdata.get("damage_percent_bonus", 0.0)
			weapon.damage_type = int(wdata.get("damage_type", int(weapon.damage_type))) as DamageType.Type
			weapon.signature_ids = (wdata.get("signature_ids", []) as Array).duplicate()
			if weapon.trigger_type == Weapon.TriggerType.AUTOMATIC:
				weapon.call_deferred("try_fire")
	weapons_changed.emit()

## Raises the player's base difficulty to at least the given floor. This is how
## each stage's minimum difficulty is enforced (enemies scale off this value).
func set_min_difficulty(player_floor: float) -> void:
	difficulty = maxf(difficulty, player_floor)

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
		hp_value_label.add_theme_font_size_override("font_size", 8)
		hp_bar.add_child(hp_value_label)

func _update_hp_value_label() -> void:
	if hp_value_label:
		hp_value_label.text = str(current_health) + " / " + str(current_max_health())
