class_name HardwareInputSource
extends InputSource

enum SourceSlot {
	ALL = -3,
	KEYBOARD_ARROWS = -2,
	KEYBOARD_WASD = -1,
	CONTROLLER_1 = 0,
	CONTROLLER_2 = 1,
	CONTROLLER_3 = 2,
	CONTROLLER_4 = 3,
}

const _ACTIONS: PoolStringArray = PoolStringArray(["boost", "brake", "steer_left", "steer_right", "pickup_use", "pickup_left", "pickup_right"])

export(SourceSlot) var controller_slot: int = SourceSlot.ALL

var _actions: PoolStringArray = []
var _source_suffix: String = ""

func _ready() -> void:
	if controller_slot <= SourceSlot.ALL:
		_actions = _ACTIONS
		print(_actions)
		return
	match controller_slot:
		SourceSlot.KEYBOARD_ARROWS:
			_source_suffix = "_kb_arrows"
		SourceSlot.KEYBOARD_WASD:
			_source_suffix = "_kb"
		_:
			_source_suffix = "_" + String(controller_slot)
	_setup_action_map()


func _process(_delta: float) -> void:
	boost = Input.is_action_pressed(_actions[0])
	set_brake(Input.is_action_pressed(_actions[1]))
	steer = stepify(Input.get_axis(_actions[3], _actions[2]), 2.0 / STEER_STORE_VALUE)
	
	pickup = PickupInput.NONE
	for i in range(4, 7):
		if Input.is_action_pressed(_actions[i]):
			match i:
				4:
					pickup = PickupInput.USE
				5:
					pickup = PickupInput.LEFT
				6:
					pickup = PickupInput.RIGHT
			return


func set_input_slot(slot: int) -> HardwareInputSource:
	controller_slot = slot
	return self


func _setup_action_map() -> void:
	if InputMap.has_action(_get_action(_ACTIONS[0])):
		_fill_actions()
		return
	
	var default_ignore: int = 1 if controller_slot == SourceSlot.KEYBOARD_ARROWS else (2 if controller_slot == SourceSlot.KEYBOARD_WASD else 0)
	
	for action_name in _ACTIONS:
		var final_action_name: String = _get_action(action_name)
		InputMap.add_action(final_action_name)
		
		var ignore: int = default_ignore
		
		var action_events: Array = InputMap.get_action_list(action_name)
		for event in action_events:
			if ignore == 3: # Ignore all future events, used after binding to a keyboard
				continue
			event = event.duplicate()
			event.device = max(controller_slot, -1)
			var joypad_event: bool = event is InputEventJoypadButton || event is InputEventJoypadMotion
			if (!joypad_event && controller_slot < 0) || (joypad_event && controller_slot >= 0):
				if ignore == 1: # Controller slot is ARROWS, register next action
					ignore = 2
					continue
				InputMap.action_add_event(final_action_name, event)
				prints(name, ": Added", action_name, event.as_text())
				if !joypad_event: # Keyboard action registered, ignore all future actions
					ignore = 3
					continue
		
		_actions.append(final_action_name)


func _get_action(action_name: String) -> String:
	return action_name + _source_suffix


func _fill_actions() -> void:
	for action_name in _ACTIONS:
		_actions.append(_get_action(action_name))


static func verify_event(event: InputEvent, slot: int) -> bool:
	var joypad_event: bool = event is InputEventJoypadButton || event is InputEventJoypadMotion
	
	match slot:
		SourceSlot.ALL:
			return true
			
		SourceSlot.KEYBOARD_ARROWS, SourceSlot.KEYBOARD_WASD:
			if joypad_event:
				return false
			
			if event is InputEventKey:
				var input: String = OS.get_scancode_string(event.physical_scancode).to_lower()
				
				var keypad_input: bool = "kp " in input || input in ["left", "right", "up", "down"]
				
				return keypad_input == (slot == SourceSlot.KEYBOARD_ARROWS)
			
		_: # Controllers
			if !joypad_event:
				return false
			return event.device == slot
	
	return false
