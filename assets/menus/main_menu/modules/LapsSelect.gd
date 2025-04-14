extends Control

const MIN: int = 1
const MAX: int = 5

onready var laps_label: Label = $"%LapsLabel"

var _lap_count: int = 3

func _ready() -> void:
	connect("visibility_changed", self, "set", ["_change_laps", 3])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") || event.is_action_pressed("ui_down"):
		_change_laps(_lap_count - 1)
	elif event.is_action_pressed("ui_right") || event.is_action_pressed("ui_up"):
		_change_laps(_lap_count + 1)



func _change_laps(lap_count: int = 3) -> void:
	_lap_count = int(clamp(lap_count, MIN, MAX))
	laps_label.text = String(_lap_count)


# Returns 'true' if the module was finalized properly, 'false' otherwise.
func _finalize_module() -> bool:
	Game.lap_count = _lap_count
	return true
