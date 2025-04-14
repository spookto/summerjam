extends Control

const MIN: int = 0
const MAX: int = 5

onready var cpus_label: Label = $"%CPUsLabel"

var current_max: int = MAX
var _cpu_count: int = MAX

func _ready() -> void:
	connect("visibility_changed", self, "set", ["_change_cpus", MAX])
	_on_mode_selected_1_player()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") || event.is_action_pressed("ui_down"):
		_change_cpus(_cpu_count - 1)
	elif event.is_action_pressed("ui_right") || event.is_action_pressed("ui_up"):
		_change_cpus(_cpu_count + 1)


func _change_cpus(cpu_count: int = 3) -> void:
	_cpu_count = int(clamp(cpu_count, MIN, current_max))
	cpus_label.text = String(_cpu_count)


# Returns 'true' if the module was finalized properly, 'false' otherwise.
func _finalize_module() -> bool:
	var c: int = MAX - current_max
	get_parent().character_count = 1 + c + _cpu_count
	return true


func _on_mode_selected_1_player():
	current_max = MAX
	_change_cpus(_cpu_count)


func _on_mode_selected_2_players():
	current_max = MAX - 1
	_change_cpus(_cpu_count)
