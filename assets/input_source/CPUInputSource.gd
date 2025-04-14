class_name CPUInputSource
extends InputSource

const OFFSET_LIMIT: float = 4.0
const UPDATE_INTERVAL: int = 10
const HALF_PI: float = PI * 0.5
const USE_CHANCES: int = 4 # possibly 1 in every 4 updates
const CPU_GROUP: String = "cpu_input_source"

onready var parent_character: CharacterBase = get_parent() as CharacterBase

export var turn_aggressiveness: float = 2.5
export var turn_speed: float = 20.0
export var look_ahead: float = 40.0
export var angle_tolerance: float = 0.35

export var drift_enabled: bool = false
export var drift_look_ahead: float = 10.0
export(float, 0.0, 1.57) var drift_angle_limit: float = 0.7

var _update_offset: int = 0
var _offset: float = 0.0
var _debug_view: DebugView = null

var _move_angle: float = 0.0
var _drift_angle: float = 0.0

func _ready() -> void:
	add_to_group(CPU_GROUP)
	_update_offset = get_tree().get_nodes_in_group(CPU_GROUP).size()
	
	_offset = rand_range(-OFFSET_LIMIT, OFFSET_LIMIT)
	
	if Game.ENABLE_DEBUG:
		_debug_view = DebugView.new(self)
	
	if !get_parent().is_visible_in_tree():
		return
	yield(get_tree(), "idle_frame")
	
	look_ahead = Game.track_units_to_offset(look_ahead)
	drift_look_ahead = Game.track_units_to_offset(drift_look_ahead)

func _physics_process(delta: float) -> void:
	if !is_instance_valid(parent_character):
		set_physics_process(false)
		return
	
	if (Engine.get_physics_frames() + _update_offset) % UPDATE_INTERVAL != 0:
		return
	
	pickup = PickupInput.NONE
	if randi() % USE_CHANCES == 0:
		pickup = PickupInput.USE
	
	var current_position: Vector3 = parent_character.global_position
	var prev_position: Vector3 = Game.get_track_point(parent_character._track_position)
	var next_position: Vector3 = Game.get_track_point(parent_character._track_position + look_ahead)
	
	var track_dir: Vector3 = (next_position - prev_position).normalized()
	next_position += track_dir.cross(Vector3.UP) * _offset
	next_position = magnet_position_towards_pickups(next_position, track_dir)
	
	var current_dir: Vector3 = parent_character.get_forward()
	var target_dir: Vector3 = next_position - current_position
	
	var current_dir2d: Vector2 = Vector2(current_dir.x, current_dir.z).normalized()
	var target_dir2d: Vector2 = Vector2(target_dir.x, target_dir.z).normalized()
	
	_move_angle = target_dir2d.angle_to(current_dir2d) * turn_aggressiveness
	
	if abs(_move_angle) < angle_tolerance:
		set_brake(false)
		steer = 0.0
		return
	
	
	# Apply drift if angle difference between next position and next next position is big.
	if drift_enabled:
		_move_angle = clamp(_move_angle, -HALF_PI, HALF_PI)
		if abs(_move_angle) > drift_angle_limit:
			set_brake(true)
			steer = sign(_move_angle)
#		var drift_position: Vector3 = Game.get_track_point(parent_character._track_position + look_ahead + drift_look_ahead)
#
#		var drift_dir: Vector3 = drift_position - _next_position
#		var drift_dir2d: Vector2 = Vector2(drift_dir.x, drift_dir.z).normalized()
#		var track_dir2d: Vector2 = Vector2(track_dir.x, track_dir.z).normalized()
#
#		_drift_angle = angle_difference(drift_dir2d.angle(), track_dir2d.angle())
#
#		if abs(_drift_angle) > drift_angle_limit:
#			print(_drift_angle)
#			set_brake(true)
#			steer = sign(_drift_angle)
	
	steer = lerp(steer, clamp(_move_angle, -1.0, 1.0), turn_speed * delta)


func magnet_position_towards_pickups(position: Vector3, direction: Vector3) -> Vector3:
	angle_tolerance = 0.25
	var point: Vector3 = _get_nearest_pickup_point(position, direction, 60.0)
	
	if !_is_path_to_point_clear(point):
		point = position
	
	if position.is_equal_approx(point):
		angle_tolerance = 0.35
	
	return point


# 'w' component is the distance
func _get_nearest_pickup_point(search_point: Vector3, search_direction: Vector3, search_range: float) -> Vector3:
	var out: Vector3 = search_point
	var distance: float = search_range * search_range
	var pickups_pool: Array = Pickup.get_pickups()
	
	for pickup in pickups_pool:
		if !pickup.get("_enabled") || pickup.get("cpu_ignore"):
			continue
		
		var pos: Vector3 = pickup.global_position
		var dif: Vector3 = pos - search_point
		if abs(dif.y) > 6.0:
			continue
		dif.y = 0
		
		var dist: float = dif.length_squared()
		if dist > distance:
			continue
		
		# Position is too close so just take it
		if dif.is_equal_approx(Vector3.ZERO):
			return pos
		
		dif = dif.normalized()
		if search_direction.dot(dif) < 0.3:
			continue
		
		distance = dist
		
		out = pos + (dif * 2.5)
	
	return out


func angle_difference(a: float, b: float) -> float:
	return fposmod(b - a + PI, TAU) - PI


func _is_path_to_point_clear(point: Vector3) -> bool:
	var space_state: PhysicsDirectSpaceState = parent_character.get_world().direct_space_state
	
	return space_state.intersect_ray(parent_character.global_position, point, [], 1).empty()



class DebugView extends Control:
	const ARC_ROTATION_OFFSET: float = -PI * 0.5
	const DRAW_OFFSET: Vector2 = Vector2.ONE * 64.0
	const DRAW_LENGTH: float = 32.0
	
	var bind: CPUInputSource = null
	
	func _init(bind_input_source: CPUInputSource) -> void:
		bind = bind_input_source
		bind.connect("tree_exiting", self, "queue_free")
		
		Game.add_child(self)
	
	
	func _process(_delta: float) -> void:
		call_deferred("update")
	
	func _draw() -> void:
		var camera: Camera = Game.get_camera(1)
		if !is_instance_valid(camera):
			print("No Camera")
			return
		
		draw_line(DRAW_OFFSET, DRAW_OFFSET + (Vector2.UP * DRAW_LENGTH), Color.red * 0.5)
		
		_draw_arc(DRAW_LENGTH + 2.0, bind.angle_tolerance, Color.red)
		_draw_arc(DRAW_LENGTH + 1.0, bind.drift_angle_limit, Color.blue)
		
		draw_line(DRAW_OFFSET, DRAW_OFFSET + (Vector2.UP.rotated(-bind._drift_angle) * DRAW_LENGTH), Color.blue)
		draw_line(DRAW_OFFSET, DRAW_OFFSET + (Vector2.UP.rotated(-bind._move_angle) * DRAW_LENGTH), Color.red)
	
	
	func _draw_arc(radius: float, angle: float, color: Color) -> void:
		draw_arc(DRAW_OFFSET, radius, ARC_ROTATION_OFFSET + angle, ARC_ROTATION_OFFSET - angle, 15, color)
