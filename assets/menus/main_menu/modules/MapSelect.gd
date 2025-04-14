extends Control

const PREVIEW_SIZE: float = 128.0
const _ICON: Texture = preload("res://icon.png")
const _OFFSET: Vector2 = Vector2(-0.4, 1)
const _TWEEN_DURATION: float = 0.3

var _map_tween: SceneTreeTween = null
var _selected_map_index: int = 0

export var maps: Array = []

onready var _map_container: Control = $"%MapsContainer"
onready var _map_information: Label = $MapInformation

func _ready() -> void:
	for map in maps:
		var new_map: TextureRect = TextureRect.new()
		new_map.texture = map.preview
		_map_container.add_child(new_map)
	
	_selected_map_index = 1
	_change_map(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") || event.is_action_pressed("ui_right"):
		_change_map(event.is_action_pressed("ui_left"))
		get_tree().set_input_as_handled()
	elif event.is_action_pressed("ui_up") || event.is_action_pressed("ui_down"):
		_change_map(event.is_action_pressed("ui_down"))
		get_tree().set_input_as_handled()


func _change_map(back: bool) -> void:
	var last_index: int = _selected_map_index
	_selected_map_index = int(clamp(_selected_map_index + (-1 if back else 1), 0, maps.size()-1))
	if _selected_map_index == last_index:
		return
	
	if _map_tween:
		_map_tween.kill()
	_map_tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	for i in range(maps.size()):
		var map_node: Control = _map_container.get_child(i)
		var target_position: Vector2 = Vector2.ZERO
		
		var relative: int = _selected_map_index - i
		target_position = _OFFSET * PREVIEW_SIZE * relative
		_map_tween.tween_property(map_node, "rect_position", target_position, _TWEEN_DURATION)
	
	_map_information.text = maps[_selected_map_index].name

# Returns 'true' if the module was finalized properly, 'false' otherwise.
func _finalize_module() -> bool:
	get_parent().set("map_resource", maps[_selected_map_index])
	return true
