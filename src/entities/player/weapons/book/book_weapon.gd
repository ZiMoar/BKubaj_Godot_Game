extends Weapon

@export var book_scene: PackedScene
@export var book_count: int = 2

var active_books: Array[Area2D] = []

func _ready() -> void:
	weapon_name = "Orbiting Books"
	trigger_type = TriggerType.AUTOMATIC
	cooldown = 5.0
	super._ready()
	
	# Spawn books immediately on game load
	call_deferred("try_fire")

func _physics_process(delta: float) -> void:
	# 1. Clean out freed/destroyed book references
	active_books = active_books.filter(func(item): return is_instance_valid(item))
	
	# 2. Drive the orbit position for each surviving book
	for proj in active_books:
		if proj.has_method("update_orbit"):
			proj.update_orbit(delta, global_position)

func fire() -> void:
	if book_scene == null:
		print("ERROR: book_scene is null! Drag your book.tscn into the Book Weapon Inspector.")
		return
		
	var angle_step = (2.0 * PI) / book_count
	var attack_is_critical = roll_critical_hit()
	var attack_damage = get_attack_damage(14)
	if attack_is_critical:
		attack_damage = int(round(float(attack_damage) * get_critical_multiplier()))
	
	for i in range(book_count):
		var initial_angle = i * angle_step
		var spawned_book = book_scene.instantiate()
		
		# Add to the active level root so it isn't affected by player transforms
		get_tree().current_scene.add_child(spawned_book)
		
		if spawned_book.has_method("setup"):
			spawned_book.setup(initial_angle, global_position)
			spawned_book.damage = attack_damage
			spawned_book.is_critical = attack_is_critical
			spawned_book.source_player = get_player()
			spawned_book.target_radius *= get_area_multiplier()
			spawned_book.scale *= get_area_multiplier()

		active_books.append(spawned_book)
