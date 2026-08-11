extends Node

## Autoload (registered as "GameState") that owns the class roster and the
## currently selected class.
##
## Each class is its own scene under res://src/entities/player/classes/<id>/.
## GameState instantiates one instance of every class scene as a child, so the
## class selection menu and the player can read identity, starting stats, and
## starting weapons straight off the class nodes. Adding a new class = dropping
## a scene in classes/ and registering it below — it then appears in the menu
## automatically.

const KNIGHT_SCENE: PackedScene = preload("res://src/entities/player/classes/knight/knight.tscn")
const RANGER_SCENE: PackedScene = preload("res://src/entities/player/classes/ranger/ranger.tscn")
const MAGE_SCENE: PackedScene = preload("res://src/entities/player/classes/mage/mage.tscn")

var _classes: Array[ClassBase] = []
var selected_class_id: String = "knight"


func _ready() -> void:
	register_class(KNIGHT_SCENE)
	register_class(RANGER_SCENE)
	register_class(MAGE_SCENE)


func register_class(scene: PackedScene) -> void:
	var cls: ClassBase = scene.instantiate()
	add_child(cls)
	_classes.append(cls)


## All registered classes, in registration order (drives menu order).
func get_class_list() -> Array[ClassBase]:
	return _classes


func get_class_by_id(id: String) -> ClassBase:
	for cls: ClassBase in _classes:
		if cls.class_id == id:
			return cls
	return null


func get_selected_class() -> ClassBase:
	return get_class_by_id(selected_class_id)


func set_selected_class(id: String) -> void:
	if get_class_by_id(id) != null:
		selected_class_id = id