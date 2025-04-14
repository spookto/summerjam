class_name PlayerCamera
extends Camera

const PLAYER_CAMERA_FAR: float = 300.0
const OFFSET_BACK: float = 12.0
const OFFSET_UP: Vector3 = Vector3.UP * 5.5
const LOOK_OFFSET: Vector3 = Vector3.UP * 3.0
const MAX_OFFSET: float = 3.0

onready var parent_character: CharacterBase = get_parent() as CharacterBase

var _first_update: bool = false
var _extra_offset: float = 0.0
var _active_offset: float = 0.0

func _ready() -> void:
	yield(get_parent(), "ready")
	parent_character = get_parent() as CharacterBase
	if !is_instance_valid(parent_character) || !parent_character.is_visible_in_tree():
		print("PlayerCamera '{}' does not have a parent of type CharacterBase.".format([name]))
		queue_free()
		return
	
	parent_character.connect("tree_exiting", self, "queue_free")
	parent_character.connect("boosted", self, "_on_character_boosted")
	parent_character.connect("race_finished", self, "_on_character_race_finished")
	
	far = PLAYER_CAMERA_FAR
	process_priority += 10
	
	set_as_toplevel(true)
	current = true
	
	Game.add_player_camera(self)
	_first_update = false


func _physics_process(delta: float) -> void:
	if !is_instance_valid(parent_character):
		queue_free()
		return
	
	_active_offset = min(lerp(_active_offset, _extra_offset, 2.4 * delta), MAX_OFFSET)
	_extra_offset = lerp(_extra_offset, 0.0, 2.0 * delta)
	
	var target_position: Vector3 = parent_character.global_position - (parent_character.get_forward() * (OFFSET_BACK + _active_offset)) + OFFSET_UP
	
	if !Game.is_race_started():
		if !_first_update:
			target_position -= parent_character.get_forward() * 8.0
			look_at_from_position(target_position, parent_character.global_position + LOOK_OFFSET, Vector3.UP)
			_first_update = true
			return
		global_position = global_position.linear_interpolate(target_position, 3.0 * delta)
		look_at(parent_character.global_position + LOOK_OFFSET, Vector3.UP)
		return
	
	look_at_from_position(target_position, parent_character.global_position + LOOK_OFFSET, Vector3.UP)


func _on_character_boosted(boost_force: float) -> void:
	boost_force = boost_force - parent_character.acceleration
	_extra_offset = max(boost_force * 0.1, 0.0)


func _on_character_race_finished() -> void:
	set_physics_process(false)
