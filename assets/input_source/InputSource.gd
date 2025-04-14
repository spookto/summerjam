class_name InputSource
extends Node

enum PickupInput {
	NONE,
	LEFT,
	RIGHT,
	USE,
}

const STEER_STORE_BITS: int = 4
const STEER_STORE_VALUE: int = (((1 << STEER_STORE_BITS)-1)/2)*2
const STEER_STORE_VALUE_HALF: int = STEER_STORE_VALUE / 2
const STEER_STORE_MASK: int = 0b1111

var steer: float = 0.0
var boost: bool = false
var brake: bool = false setget set_brake
var just_braked: bool = false setget _set_just_braked

var pickup: int = PickupInput.NONE # 0 = Nothing, 1 = Left, 2 = Right, 3 = Use

export(String, MULTILINE) var recorded_input: String = ""
export var record_inputs: bool = false

var _recorded_inputs: PoolByteArray = []
var _recorded_input_offset: int = 0
var _playing_recorded_input: bool = false

func set_brake(value: bool) -> void:
	if value && brake != value:
		_set_just_braked(true)
	brake = value
	_get_input_state()


func _set_just_braked(value: bool) -> void:
	if is_queued_for_deletion():
		return
	
	yield(get_tree(), "physics_frame")
	just_braked = value
	
	if is_queued_for_deletion():
		return
	
	if value:
		get_tree().connect("physics_frame", self, "_unset_just_braked", [], CONNECT_ONESHOT)

func _unset_just_braked() -> void:
	just_braked = false


func _get_input_state() -> int:
	var int_steer: int = int(round((steer + 1.0) * STEER_STORE_VALUE_HALF))
	var input_state: int = int_steer
	input_state |= int(boost) << STEER_STORE_BITS
	input_state |= int(brake) << STEER_STORE_BITS + 1
	input_state |= pickup << STEER_STORE_BITS + 2
	
	return input_state


func _set_input_state(input_state: int) -> void:
	var state_info: Dictionary = decode_input_state(input_state)
	
	steer = state_info.get("steer", 0.0)
	boost = state_info.get("boost", false)
	set_brake(state_info.get("boost", false))
	pickup = state_info.get("pickup", PickupInput.NONE)
	
	prints(steer, boost, brake, pickup)


## Takes hex encoded input state.
func _set_input_state_hex(input_state: String) -> void:
	_set_input_state(("0x"+input_state).hex_to_int())


static func decode_input_state(input_state: int) -> Dictionary:
	var output: Dictionary = {}
	
	var int_steer: int = input_state & STEER_STORE_MASK
	
	output["int_steer"] = int_steer
	output["steer"] = (float(int_steer - STEER_STORE_VALUE_HALF) / STEER_STORE_VALUE) * 2.0
	output["boost"] = bool(input_state & (1 << STEER_STORE_BITS))
	output["brake"] = bool(input_state & (1 << STEER_STORE_BITS + 1))
	output["pickup"] = (input_state & (3 << STEER_STORE_BITS + 2)) >> STEER_STORE_BITS + 2
	
	return output
