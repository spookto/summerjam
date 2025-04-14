## MainMenu works by having multiple modules to manage current selection stage.
## Game starts after all modules are processed
class_name MainMenu
extends CanvasLayer

const INVALID_INPUT: int = HardwareInputSource.SourceSlot.ALL
const SIGNAL_MODULE_PROCESSED: String = "module_processed"
const METHOD_FINALIZE: String = "_finalize_module"
const META_DISABLED: String = "disabled_module"
const META_INPUT_TWO: String = "player_two_input_event"

# Count of characters in the game, including CPU.
var character_count: int = 6

var map_resource: MapResource = null
var character_resource: CharacterResource = null
var character_2_resource: CharacterResource = null
var player_1_input_slot: int = INVALID_INPUT
var player_2_input_slot: int = INVALID_INPUT
var potential_characters: Array = []

var _current_module: int = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	setup_modules()
	enable_module(0)


func _input(event: InputEvent) -> void:
	event.remove_meta(META_INPUT_TWO)
	if !HardwareInputSource.verify_event(event, player_1_input_slot):
		if player_2_input_slot != INVALID_INPUT && HardwareInputSource.verify_event(event, player_2_input_slot):
			event.set_meta(META_INPUT_TWO, true)
			return
		get_tree().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if process_module():
			get_tree().set_input_as_handled()
	
	elif event.is_action_pressed("ui_cancel"):
		while !enable_module(int(max(_current_module - 1, 0))):
			continue


func setup_modules() -> void:
	for i in range(get_child_count()):
		var module: Control = get_child(i)
		if !module.has_signal(SIGNAL_MODULE_PROCESSED):
			continue
		
		module.connect(SIGNAL_MODULE_PROCESSED, self, "process_module", [i])


func enable_module(module_index: int) -> bool:
	_current_module = module_index
	
	var success: bool = true
	
	if _current_module >= get_child_count():
		Game.set_player_input_slot(1, player_1_input_slot)
		Game.set_player_input_slot(2, player_2_input_slot)
		
		for i in range(character_count):
			match i:
				0:
					Game.add_character(character_resource)
					potential_characters.erase(character_resource)
				1:
					var c: CharacterResource = character_2_resource if character_2_resource != null else _pop_potential_character()
					Game.add_character(c)
				_:
					Game.add_character(_pop_potential_character())
		
		Game.load_map(map_resource)
		return true
	
	for i in range(get_child_count()):
		var module: Control = get_child(i)
		var active: bool = i == module_index
		if active && module.get_meta(META_DISABLED, false):
			active = false
			success = false
		
		module.set_process_input(active)
		module.set_process_unhandled_input(active)
		module.set_visible(active)
	
	return success


func _pop_potential_character() -> CharacterResource:
	if potential_characters.empty():
		return character_resource
	
	var pot_i: int = randi() % potential_characters.size()
	var c: CharacterResource = potential_characters[pot_i]
	potential_characters.remove(pot_i)
	return c



func process_module(module_index: int = _current_module) -> bool:
	if !get_child(module_index).has_method(METHOD_FINALIZE):
			printerr("MainMenu.gd: Child {0} does not have method '{1}'".format([module_index, METHOD_FINALIZE]))
			return false
	if get_child(module_index).call(METHOD_FINALIZE) != true:
		return false
	var i: int = 1
	while !enable_module(module_index + i):
		i += 1
	return true
