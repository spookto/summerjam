extends Control

# warning-ignore-all:unused_signal
signal module_processed
signal mode_selected_2_players
signal mode_selected_1_player

enum Mode {
	STORY,
	FREE,
	PVP,
	QUIT,
}

onready var mode_label: Label = $"%ModeLabel"

var _hovered_mode: int = Mode.STORY
var _max: int = Mode.QUIT

func _ready() -> void:
	_change_mode(false)
	if OS.get_name() == "HTML5":
		_max = Mode.QUIT - 1


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") || event.is_action_pressed("ui_right"):
		_change_mode(event.is_action_pressed("ui_right"))


func _change_mode(next: bool) -> void:
	_hovered_mode = int(clamp(_hovered_mode + (1 if next else -1), Mode.STORY, _max))
	if Game.is_mobile():
		if _hovered_mode == Mode.PVP:
			_change_mode(next)
			return
	
	mode_label.text = Mode.keys()[_hovered_mode]
	mode_label.text = mode_label.text.replacen("STORY", "TUTORIAL").replace("FREE", "RACE")


# Returns 'true' if the module was finalized properly, 'false' otherwise.
func _finalize_module() -> bool:
	var _signal: String = "mode_selected_1_player"
	
	match _hovered_mode:
		Mode.STORY:
			Game.set_player_input_slot(1, get_parent().player_1_input_slot)
			Game.set_player_input_slot(2, MainMenu.INVALID_INPUT)
			get_tree().change_scene("res://assets/maps/tutorial/MapTutorialStory.tscn")
		Mode.QUIT:
			get_tree().quit()
			return false
		Mode.PVP:
			_signal = "mode_selected_2_players"
	
	emit_signal(_signal)
	return true
