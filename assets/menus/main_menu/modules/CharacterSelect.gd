extends Control

const COLUMN_COUNT: int = 3

export var characters: Array = []

export var player_1_texture_full: Texture = preload("res://assets/menus/main_menu/textures/select_ring_full.svg")
export var player_1_texture_half: Texture = preload("res://assets/menus/main_menu/textures/select_ring_half.svg")

export var player_2_texture_full: Texture = preload("res://assets/menus/main_menu/textures/select_ring_full.svg")
export var player_2_texture_half: Texture = preload("res://assets/menus/main_menu/textures/select_ring_half.svg")

var _characters: Array = []
var _selected_character_index: int = 0
var _selected_character_2_index: int = 0
var _row_count: int = 0
var _two_players: bool = false

var _player_one_confirmed: bool = false
var _player_two_confirmed: bool = false

onready var grid_container: GridContainer = $"%GridContainer"
onready var hover_indicator: TextureRect = $"%HoverIndicator"
onready var hover_indicator_2: TextureRect = $"%HoverIndicator2"


func _ready():
	connect("visibility_changed", self, "_on_visibility_changed")
	_setup_characters()
	
	get_parent().set("potential_characters", characters.duplicate())
	
	yield(get_tree(), "idle_frame")
	
	_select_character_index(0, false)
	_select_character_index(0, true)


func _unhandled_input(event: InputEvent) -> void:
	var _handle: bool = false
	var player_two: bool = event.get_meta(MainMenu.META_INPUT_TWO, false)
	
	if event.is_action_pressed("ui_left"):
		_select_character(Vector2.LEFT, player_two)
		_handle = true
	elif event.is_action_pressed("ui_right"):
		_select_character(Vector2.RIGHT, player_two)
		_handle = true
	elif event.is_action_pressed("ui_up"):
		_select_character(Vector2.UP, player_two)
		_handle = true
	elif event.is_action_pressed("ui_down"):
		_select_character(Vector2.DOWN, player_two)
		_handle = true
	elif _two_players:
		if event.is_action_pressed("ui_accept") || event.is_action_pressed("ui_cancel"):
			var confirm_var: String = "_player_two_confirmed" if player_two else "_player_one_confirmed"
			var confirm_state: bool = get(confirm_var)
			
			var confirming: bool = event.is_action_pressed("ui_accept")
			
			# Trying to go back, cancel processing and let input pass
			if !confirm_state && !confirming:
				return
			
			set(confirm_var, confirming)
			(hover_indicator_2 if player_two else hover_indicator).self_modulate.a = 0.6 if confirming else 1.0
			
			# Go to next module if both players confirmed
			if _player_one_confirmed && _player_two_confirmed:
				return
			
			_handle = true
	
	
	if _handle:
		get_tree().set_input_as_handled()


func _setup_characters() -> void:
	grid_container.columns = COLUMN_COUNT
	_characters = []
	
	var container: HBoxContainer = null
	for i in range(characters.size()):
		if i % COLUMN_COUNT == 0:
			container = HBoxContainer.new()
			container.alignment = BoxContainer.ALIGN_CENTER
			$CenterContainer/VBoxContainer.add_child(container)
		
		var character: Resource = characters[i]
		if !character is CharacterResource:
			printerr("CharacterSelector.gd: Resource at index {0} is not of type CharacterResource!")
			return
		
		var tex: TextureRect = TextureRect.new()
		#tex.texture = character.frames.get_frame("front", 0)
		tex.texture = character.icon
		container.add_child(tex)
		_characters.append(tex)
		
		tex.connect("mouse_entered", self, "_select_character_index", [i])
	
	_row_count = int(floor(_characters.size() / float(COLUMN_COUNT)))


func _select_character_index(index: int, player_two: bool) -> void:
	if _two_players:
		if player_two && _player_two_confirmed:
			return
		elif !player_two && _player_one_confirmed:
			return
	
	index = int(clamp(index, 0, _characters.size()))
	
	set("_selected_character_2_index" if player_two else "_selected_character_index", index)
	(hover_indicator_2 if player_two else hover_indicator).rect_global_position = _characters[index].rect_global_position
	
	var t: String = "player_{0}_texture_full"
	
	if _two_players && _selected_character_index == _selected_character_2_index:
		t = "player_{0}_texture_half"
	
	var character_sprite: Texture = characters[index].frames.get_frame("front", 0)
	get_node("%Player2Character" if player_two else "%Player1Character").texture = character_sprite
	
	hover_indicator.texture = get(t.format([1]))
	hover_indicator_2.texture = get(t.format([2]))


func _select_character(direction: Vector2, player_two: bool = false) -> void:
	var selected_index: int = _selected_character_2_index if player_two else _selected_character_index
	
	var current_position: Vector2 = Vector2(selected_index % COLUMN_COUNT, int(floor(selected_index / float(COLUMN_COUNT))))
	var characters_in_last_column: int = int(min(COLUMN_COUNT, _characters.size() - (current_position.y * COLUMN_COUNT)))
	
	current_position.y = int(clamp(current_position.y + direction.y, 0, _row_count))
	var characters_in_column: int = int(min(COLUMN_COUNT, _characters.size() - (current_position.y * COLUMN_COUNT)))
	
	current_position.x = int(clamp(current_position.x + direction.x, 0, characters_in_column - 1))
	if characters_in_last_column == 1 && direction.y < 0:
		current_position.x = 1
	print(current_position)
	
	_select_character_index(int(current_position.x + (COLUMN_COUNT * current_position.y)), player_two)


# Returns 'true' if the module was finalized properly, 'false' otherwise.
func _finalize_module() -> bool:
	get_parent().set("character_resource", characters[_selected_character_index])
	get_parent().set("character_2_resource", characters[_selected_character_2_index] if _two_players else null)
	return true


func _on_visibility_changed() -> void:
	_player_one_confirmed = false
	_player_two_confirmed = false
	hover_indicator.self_modulate.a = 1.0
	hover_indicator_2.self_modulate.a = 1.0
	
	_two_players = get_parent().get("player_2_input_slot") != MainMenu.INVALID_INPUT
	hover_indicator_2.visible = _two_players
	$"%Player2Character".get_parent().modulate.a = float(_two_players)
	_select_character_index(_selected_character_2_index, true)
