extends CanvasLayer

var _action_steer_left: InputEventAction
var _action_steer_right: InputEventAction
var _action_brake: InputEventAction

var _action_pickup_use: InputEventAction
var _action_pickup_left: InputEventAction
var _action_pickup_right: InputEventAction

var _action_ui_left: InputEventAction
var _action_ui_right: InputEventAction
var _action_ui_accept: InputEventAction

var _action_brake_visual: InputEventAction # Used for tutorial
var _action_pickup_use_visual: InputEventAction # Used for tutorial


var _steer_finger_index: int = -1

# Dictionary[InputEventAction, int]
var _tapped_inputs: Dictionary = {}

func _ready() -> void:
	visible = Game.is_mobile()
	
	_action_steer_left = _create_action("steer_left_kb")
	_action_steer_right = _create_action("steer_right_kb")

	_action_brake = _create_action("brake_kb")

	_action_ui_accept = _create_action("ui_accept")
	_action_ui_left = _create_action("ui_left")
	_action_ui_right = _create_action("ui_right")

	_action_pickup_use = _create_action("pickup_use_kb")
	_action_pickup_left = _create_action("pickup_left_kb")
	_action_pickup_right = _create_action("pickup_right_kb")

	_action_brake_visual = _create_action("brake")
	_action_pickup_use_visual = _create_action("pickup_use")

	pause_mode = Node.PAUSE_MODE_PROCESS


func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		var relative_position: Vector2 = _relative_touch_position(event.position)
		if not event.index == _steer_finger_index:
			return
		if relative_position.x < 0.5:
			_do_movement_input(event.position * Vector2(2.0, 1.0))

	elif event is InputEventScreenTouch:
		var relative_position: Vector2 = _relative_touch_position(event.position)
		if relative_position.x < 0.5 || event.index == _steer_finger_index:
			if event.is_pressed():
				_steer_finger_index = event.index
				_do_movement_input(event.position * Vector2(2.0, 1.0))
				if relative_position.x < 0.25:
					_tap_action(_action_ui_left, true)
				else:
					_tap_action(_action_ui_right, true)
			else:
				_steer_finger_index = -1
				_action_steer_left.pressed = false
				_action_steer_right.pressed = false
				Input.parse_input_event(_action_steer_left)
				Input.parse_input_event(_action_steer_right)
		else:
			if relative_position.x < 0.75:
				if not event.is_pressed():
					return
				# Tap is on top half
				if relative_position.y < 0.5:
					if relative_position.x > 0.625:
						_tap_action(_action_pickup_right)
					else:
						_tap_action(_action_pickup_left)
				# Tap is on bottom half
				else:
					Input.parse_input_event(_action_ui_accept)
					_tap_action(_action_pickup_use)
					if get_tree().is_paused():
						Input.parse_input_event(_action_pickup_use_visual)
			else:
				_action_brake.pressed = event.is_pressed()
				Input.parse_input_event(_action_brake)
				if get_tree().is_paused():
					Input.parse_input_event(_action_brake_visual)



func _brake_input(event: InputEventScreenTouch) -> void:
	_action_brake.pressed = event.is_pressed()
	Input.parse_input_event(_action_brake)
	if get_tree().is_paused():
		Input.parse_input_event(_action_brake_visual)


func _create_action(action_name: String) -> InputEventAction:
	var a = InputEventAction.new()
	a.action = action_name
	a.pressed = true
	return a


func _do_movement_input(input_position: Vector2) -> void:
	var relative_event: Vector2 = _relative_touch_position(input_position)

	var direction: float = clamp((relative_event.x - 0.5) * 2.0, -1.0, 1.0)
	var strength: float = min(abs(direction) * 2.0, 1.0)
	_action_steer_left.strength = strength
	_action_steer_right.strength = strength
	_action_steer_left.pressed = direction < 0.0
	_action_steer_right.pressed = direction > 0.0

	Input.parse_input_event(_action_steer_left)
	Input.parse_input_event(_action_steer_right)


func _tap_action(action: InputEventAction, use_timer: bool = false) -> void:
	action.pressed = true
	Input.parse_input_event(action)
	
	if use_timer:
		_tapped_inputs[action] = _tapped_inputs.get(action, 0) + 1
		yield(get_tree().create_timer(0.1), "timeout")
		_tapped_inputs[action] -= 1
		if _tapped_inputs[action] > 0:
			return
	else:
		yield(get_tree(), "idle_frame")
	
	action.pressed = false
	Input.parse_input_event(action)


func _relative_touch_position(touch_position: Vector2) -> Vector2:
	return touch_position / get_viewport().size
