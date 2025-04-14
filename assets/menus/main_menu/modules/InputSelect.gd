extends Control

signal module_processed

const META_SLOT: String = "meta_slot_player_1"

export(int, "Player One,Player Two,Disabled") var player_slot: int = 0 setget set_player_slot
var _player_input: int = MainMenu.INVALID_INPUT

func _ready() -> void:
	if player_slot != 0:
		if player_slot == 2:
			set_meta(MainMenu.META_DISABLED, true)
		return
	
	if Game.has_meta(META_SLOT):
		print("META_SLOT FOUND")
		_player_input = Game.get_meta(META_SLOT)
		yield(get_tree(), "idle_frame")
		emit_signal("module_processed")
	
	connect("visibility_changed", self, "_on_visibility_changed", [], CONNECT_DEFERRED)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		print("Select: ", event)
		_player_input = HardwareInputSource.SourceSlot.KEYBOARD_WASD
		if event is InputEventKey && "Kp " in event.as_text():
			_player_input = HardwareInputSource.SourceSlot.KEYBOARD_ARROWS
		elif event is InputEventJoypadButton || event is InputEventJoypadMotion:
			print(event.device)
			_player_input = event.device
		
		if player_slot > 0:
			emit_signal("module_processed")
			get_tree().set_input_as_handled()


func set_player_slot(value: int) -> void:
	player_slot = value
	print(player_slot)
	set_meta(MainMenu.META_DISABLED, player_slot == 2)
	if is_instance_valid(get_parent()):
		get_parent().set("player_1_input_slot" if player_slot < 1 else "player_2_input_slot", MainMenu.INVALID_INPUT)


# Returns 'true' if the module was finalized properly, 'false' otherwise.
func _finalize_module() -> bool:
	var player_1: bool = player_slot < 1
	if !player_1:
		# Using the same input source for both players is NOT VALID
		if get_parent().get("player_1_input_slot") == _player_input:
			return false
	else:
		Game.set_meta(META_SLOT, _player_input)
	get_parent().set("player_1_input_slot" if player_1 else "player_2_input_slot", _player_input)
	return true


func _on_visibility_changed() -> void:
	if !is_visible_in_tree():
		return
	
	get_parent().set("player_1_input_slot" if player_slot < 1 else "player_2_input_slot", MainMenu.INVALID_INPUT)
