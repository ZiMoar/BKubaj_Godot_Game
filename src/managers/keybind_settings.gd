class_name KeybindSettings
extends Object

## Persistence + application of player-rebindable input actions.
##
## The game's gameplay actions are rebindable so players can change them from
## the in-game keybind menu (res://src/ui/keybind_menu/). Bindings are stored as
## plain physical keycodes in a user:// ConfigFile so they survive restarts.
##
## Applied bindings are written into the runtime InputMap; nothing here touches
## project.godot (which the editor reverts), so this works even though the
## default bindings live in project.godot.
##
## Mouse-button actions (primary/secondary attack) are keyed under negative
## keycodes so a single int can represent both a key and a mouse button.

const ACTIONS: Dictionary = {
	"move_left": "Move Left",
	"move_right": "Move Right",
	"move_up": "Move Up",
	"move_down": "Move Down",
	"primary_attack": "Primary Attack",
	"secondary_attack": "Secondary Attack",
	"class_ability": "Class Ability",
}

## Negative keycode marker for a mouse button binding.
const MOUSE_FLAG: int = -1000

const SAVE_PATH: String = "user://keybinds.cfg"

## All rebindable actions, in menu display order.
static func get_actions() -> Array:
	return ACTIONS.keys()


static func get_display_name(action: String) -> String:
	return ACTIONS.get(action, action)


## Map an action back to its (keycode, is_mouse) pair from the live InputMap.
static func read_current(action: String) -> Dictionary:
	var events: Array = InputMap.action_get_events(action)
	for ev: InputEvent in events:
		if ev is InputEventKey and not ev.echo:
			return {"keycode": ev.physical_keycode, "is_mouse": false}
		if ev is InputEventMouseButton and ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			return {"keycode": ev.button_index, "is_mouse": true}
	return {"keycode": 0, "is_mouse": false}


## Human-readable label for a binding (key name or "LMB"/"RMB").
static func describe_binding(action: String) -> String:
	var b: Dictionary = read_current(action)
	if b.is_mouse:
		return "Left Click" if b.keycode == MOUSE_BUTTON_LEFT else "Right Click"
	if b.keycode == 0:
		return "-"
	return OS.get_keycode_string(b.keycode)


## Encode a binding into the signed-int storage form. A mouse padding of
## MOUSE_FLAG (-1000) makes negative values unambiguously mouse buttons.
static func encode(keycode: int, is_mouse: bool) -> int:
	return MOUSE_FLAG - keycode if is_mouse else keycode


static func decode(stored: int) -> Dictionary:
	if stored < 0:
		return {"keycode": MOUSE_FLAG - stored, "is_mouse": true}
	return {"keycode": stored, "is_mouse": false}


## Write the current live bindings for all actions to disk. Called whenever the
## player changes (or resets) a binding.
static func save_current() -> void:
	var cfg := ConfigFile.new()
	for action: String in get_actions():
		var b: Dictionary = read_current(action)
		cfg.set_value("keybinds", action, encode(b.keycode, b.is_mouse))
	var err: Error = cfg.save(SAVE_PATH)
	if err != OK:
		push_error("KeybindSettings: could not save keybinds (%s -> %d)" % [SAVE_PATH, err])


## Apply any previously saved bindings onto the live InputMap. Safe to call on
## autoload _ready() — returns early when nothing has been saved yet.
static func apply_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for action: String in get_actions():
		if not cfg.has_section_key("keybinds", action):
			continue
		var stored: int = cfg.get_value("keybinds", action)
		var b: Dictionary = decode(stored)
		if b.keycode == 0:
			continue
		set_binding(action, b.keycode, b.is_mouse)


## Replace the live binding for an action with the given physical key / mouse
## button. Mutates InputMap only; call save_current() separately to persist.
static func set_binding(action: String, keycode: int, is_mouse: bool) -> void:
	if not InputMap.has_action(action):
		return
	# Remove the current binding(s) before adding the replacement.
	InputMap.action_erase_events(action)
	if is_mouse:
		var ev := InputEventMouseButton.new()
		ev.button_index = keycode as MouseButton
		InputMap.action_add_event(action, ev)
	else:
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode as Key
		InputMap.action_add_event(action, ev)


## Restore all actions to the defaults baked into project.godot, then persist.
static func reset_defaults() -> void:
	for action: String in get_actions():
		_restore_project_default(action)
	save_current()


## Repopulate an action from whatever the project file defines at this moment.
## The live InputMap may have been mutated, so we re-read project.godot.
static func _restore_project_default(action: String) -> void:
	if not InputMap.has_action(action):
		return
	var cfg := ConfigFile.new()
	if cfg.load("res://project.godot") != OK:
		return
	var raw: Variant = cfg.get_value("input", action)
	if raw == null:
		return
	var mapping: Dictionary = raw
	if not mapping.has("events"):
		return
	# ConfigFile already parses the Object(...) entries into real InputEvent
	# instances (confirmed: move_left yields an InputEventKey physical=A), so we
	# can drop them straight back onto the live InputMap.
	InputMap.action_erase_events(action)
	var events: Array = mapping["events"]
	for ev: InputEvent in events:
		if ev != null:
			InputMap.action_add_event(action, ev)
