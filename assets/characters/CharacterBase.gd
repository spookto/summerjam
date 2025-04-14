tool
class_name CharacterBase
extends KinematicBody

signal drift_level_changed
signal lap_changed
signal race_finished
signal floored_changed
signal floor_bounced
signal wall_collided
signal boosted #var: boost_force

const BRAKE_JUMP: float = 12.0
const COLLISION_LAYER: int = 1 << 1
const PROTECT_VALUE: float = -10.0
const BOOST_ACCEL_THRESHOLD: float = 90.0
const BOOST_ACCEL_THRESHOLD_SQUARED: float = BOOST_ACCEL_THRESHOLD * BOOST_ACCEL_THRESHOLD
const BOOST_HOLD_DURATION: float = 0.15
const FLOOR_CHECK_OFFSET: Vector3 = Vector3.DOWN * 1.35
const FLOOR_BOUNDS_CHECK_OFFSET: Vector3 = Vector3.DOWN * 500.0

onready var sprite: AnimatedSprite3D = $Sprite
onready var jump_ray: RayCast = $"%JumpRay"
onready var acceleration_squared: float = acceleration * acceleration

# Please use a resource of type CharacterResource
export var character_resource: Resource = null

export var acceleration: float = 45.0

export var steering: float = 12.0

export var drift_impulse_1: float = 55.0
export var drift_impulse_2: float = 70.0
export var drift_impulse_3: float = 85.0
export var drift_steering: float = 20.0

export var turn_speed: float = 5.0

var input_source: InputSource = null

var turn_stop_limit: float = 0.75

var drift_direction: int = 0
var drift_level: int = 0

var rotate_input: float = 0.0
var drift_duration: float = 0.0

var wrong_way: bool = false
var place: int = 1
var lap: int = 1
var velocity: Vector3 = Vector3.ZERO

var _track_position: float = 0.0 setget set_track_position
var _wrong_track_position: float = 0.0
var _before_track_start: bool = false
var _jump_tween: SceneTreeTween
var _pickup_stack: PickupStack = null
var _last_pickup_input: int = 0
var _stunned: float = -1.0
var _boost_hold: float = -1.0

var _bump_query: PhysicsShapeQueryParameters = null
var _bump_query_shape: SphereShape = null

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	if !is_visible_in_tree():
		queue_free()
		return
	
	_setup_character()
	
	_setup_player_bump_query()
	
	_pickup_stack = get_meta(PickupStack.META_STACK, self) as PickupStack
	
	collision_layer = COLLISION_LAYER
	
	sprite.set_as_toplevel(true)
	
	input_source = _get_input_source()
	if !input_source:
		input_source = InputSource.new()
		add_child(input_source)
	
	Game.call_deferred("register_character", self)
	move_and_slide(Vector3.ZERO)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() || is_queued_for_deletion():
		return
	
	sprite.position = position
	var vflat: Vector2 = Vector2(velocity.x, velocity.z)
	var v: float = 1.0 if vflat.length_squared() <= (acceleration_squared + 256.0) else 3.0
	sprite.position.y += sin(Time.get_ticks_msec() * v / 200.0) * 0.2
	
	if !Game.is_race_started():
		move_and_collide(Vector3.ZERO)
		return
	
	_check_bounds_below()
	
	
	if is_stunned():
		sprite.set_meta(CharacterSprite.META_ANIMATION, "stunned")
		_stunned -= delta
		velocity = velocity.linear_interpolate(Vector3.UP * velocity.y, 2.5 * delta)
		move(delta)
		return
	elif is_protected():
		_stunned += delta
	
	if is_instance_valid(_pickup_stack):
		_process_pickups()
	
	
	if input_source.just_braked && jump_ray.is_colliding() && velocity.y < 0.05:
		_prep_jump_tween()
		_jump_tween.tween_property(sprite, "offset", Vector2.DOWN * 20.0, 0.1)
		_jump_tween.tween_property(sprite, "offset", Vector2.DOWN * 16.0, 0.1)
	
	_process_movement(delta)
	_process_drifting(delta)
	
	var accel: float = 1.0 if velocity.length_squared() > BOOST_ACCEL_THRESHOLD_SQUARED else 2.0
	if _boost_hold > 0.0:
		accel = 0.0
		_boost_hold -= delta
	velocity = velocity.linear_interpolate(get_forward() * acceleration, 0.8 * accel * delta)
	
	move(delta)


func _process_movement(delta: float) -> void:
	if is_floored():
		if input_source.just_braked:
			drift_direction = int(sign(input_source.steer))
		elif !input_source.brake:
			drift_direction = 0
	
	if is_drifting() && is_floored():
		# Remap steer input from [-1, 1] to [0, 1]
		var drift_strength: float = abs(input_source.steer + drift_direction) * 0.5
		rotate_input = deg2rad(drift_steering) * lerp(0.4, 1.0, drift_strength) * drift_direction
	else:
		rotate_input = deg2rad(steering) * input_source.steer
	
	if velocity.length() > turn_stop_limit:
		var new_basis = sprite.global_transform.basis.rotated(sprite.global_transform.basis.y, rotate_input)
		sprite.global_transform.basis = sprite.global_transform.basis.slerp(new_basis,turn_speed * delta)
		sprite.global_transform = sprite.global_transform.orthonormalized()
	
	sprite.set_meta(CharacterSprite.META_ANIMATION, _get_animation())


func _process_drifting(delta: float) -> void:
	if is_drifting():
		if !is_floored(): # Don't increase drift in-air
			return
		drift_duration += delta
		var new_drift: int = _get_drift_level()
		if new_drift != drift_level:
			drift_level = new_drift
			emit_signal("drift_level_changed", drift_level)
	else:
		if drift_level > 0:
			var drift_impulse: float = get("drift_impulse_" + String(drift_level))
			var hold_duration: float = BOOST_HOLD_DURATION + ((drift_level - 1) * 0.08)
			boost_forward(drift_impulse, hold_duration)
			drift_level = 0
			emit_signal("drift_level_changed", drift_level)
		drift_duration = 0.0


func _check_bounds_below() -> void:
	if is_floored() || Engine.get_physics_frames() % 2 == 0:
		return
	
	var state: PhysicsDirectSpaceState = get_world().direct_space_state
	
	# Check if there is any floor below the character, much like Mario64
	# Lets us know if the character is out of bounds
	var result: Dictionary = state.intersect_ray(global_position, global_position + FLOOR_BOUNDS_CHECK_OFFSET, [get_rid()], collision_mask)
	if result.empty():
		print("OUT OF BOUNDS")

# is_on_floor isn't working as expected so we have to wing it.
var _cached_floored: bool = false
var _floor_normal: Vector3 = Vector3.UP
func is_floored(update: bool = false) -> bool:
	if !update:
		return _cached_floored
	
	var new_floor: bool = false
	var state: PhysicsDirectSpaceState = get_world().direct_space_state
	var result: Dictionary = state.intersect_ray(global_position, global_position + FLOOR_CHECK_OFFSET, [get_rid()], collision_mask)
	new_floor = !result.empty()
	
	_floor_normal = result.get("normal", Vector3.UP)
	
	if _cached_floored != new_floor:
		emit_signal("floored_changed", new_floor)
	_cached_floored = new_floor
	
	return _cached_floored


func _wall_bump_logic() -> void:
	if !is_on_wall():
		return
	
	for i in range(get_slide_count()):
		var collision: KinematicCollision = get_slide_collision(i)
		var normal: Vector3 = collision.normal
		# Ignore straight or angled surfaces
		if abs(normal.y) > 0.3:
			continue
		print("WALL COLLISION")
		emit_signal("wall_collided")
		normal.y = 0.0
		normal = normal.normalized()
		
		var y: float = velocity.y
		velocity = velocity.linear_interpolate(normal * 20.0, 0.5)
		velocity.y = y


func _setup_player_bump_query() -> void:
	_bump_query_shape = SphereShape.new()
	_bump_query_shape.radius = 1.2
	
	_bump_query = PhysicsShapeQueryParameters.new()
	
	_bump_query.set_shape_rid(_bump_query_shape.get_rid())
	_bump_query.collision_mask = collision_layer
	_bump_query.exclude = [get_rid()]


func _player_bump_logic() -> void:
	var state: PhysicsDirectSpaceState = get_world().direct_space_state
	
	_bump_query.transform = global_transform
	var results: Array = state.intersect_shape(_bump_query, 1)
	if results.empty():
		return
	
	for result_info in results:
		var collider: Spatial = result_info.collider
		var dir: Vector3 = collider.global_position - global_position
		if collider.has_meta("_player_bump_velocity"):
			collider.call("_player_bump_velocity", dir)
		_player_bump_velocity(-dir)


func _player_bump_velocity(direction: Vector3) -> void:
	if is_protected():
		return
	direction.y = 0.0
	var y: float = velocity.y
	velocity.y = 0.0
	velocity = (direction.normalized() * 16.0).linear_interpolate(velocity, 0.5)
	velocity.y = y


func move(delta: float) -> void:
	_wall_bump_logic()
	var last_y: float = 1.0
	if is_floored():
		velocity -= _floor_normal * 64.0 * delta
	else:
		velocity.y -= 91.0 * delta
		last_y = velocity.y
	velocity = move_and_slide_with_snap(velocity, Vector3.DOWN)
	if is_floored(true) && last_y < -10.0:
		velocity.y = abs(last_y * 0.6)
		print("BOUNCE: ", velocity.y)
		emit_signal("floor_bounced", velocity.y)
	_player_bump_logic()


func _process_pickups() -> void:
	if _last_pickup_input == input_source.pickup:
		return
	_last_pickup_input = input_source.pickup
	
	match input_source.pickup:
		InputSource.PickupInput.LEFT:
			_pickup_stack.change_selection(-1)
		InputSource.PickupInput.RIGHT:
			_pickup_stack.change_selection(1)
		InputSource.PickupInput.USE:
			_pickup_stack.use(self)


func _get_animation() -> String:
	if is_drifting():
		return ("drift_l" if drift_direction > 0 else "drift_r")
	if abs(input_source.steer) > 0.1:
		return ("turn_l" if input_source.steer > 0.0 else "turn_r")
	return "default"


func _get_input_source() -> InputSource:
	for child in get_children():
		if child is InputSource:
			return child
	return get_node_or_null("InputSource") as InputSource


func is_drifting() -> bool:
	return drift_direction != 0


func _get_drift_level() -> int:
	if drift_duration < 0.6:
		return 0
	elif drift_duration < 1.4:
		return 1
	elif drift_duration < 2.5:
		return 2
	return 3


func get_forward() -> Vector3:
	return -sprite.global_transform.basis.z

func boost_forward(boost_force: float, boost_hold: float = BOOST_HOLD_DURATION) -> void:
	boost_direction(get_forward(), boost_force, boost_hold)


func boost_direction(direction: Vector3, boost_force: float, boost_hold: float = BOOST_HOLD_DURATION) -> void:
	velocity = direction * boost_force
	_boost_hold = boost_hold
	emit_signal("boosted", boost_force)


func add_scene(scene: PackedScene, duration: float = -1.0) -> Node:
	var inst: Node = scene.instance()
	sprite.add_child(inst)
	inst.owner = self
	
	if duration >= 0.0:
		var free_tween: SceneTreeTween = inst.create_tween()
		free_tween.tween_callback(inst, "queue_free").set_delay(duration)
	
	return inst


func protect(duration: float) -> void:
	_stunned = PROTECT_VALUE - duration


func is_protected() -> bool:
	return _stunned < PROTECT_VALUE

func is_stunned() -> bool:
	return _stunned > 0.0


func stun(duration: float) -> void:
	if _stunned <= PROTECT_VALUE:
		return
	_stunned = duration
	
	_cancel_drift()
	
	_prep_jump_tween()
	_jump_tween.tween_property(sprite, "offset", Vector2.DOWN * 40.0, 0.1)
	_jump_tween.tween_property(sprite, "offset", Vector2.DOWN * 16.0, 0.1)
	_jump_tween.tween_property(sprite, "offset", Vector2.DOWN * 24.0, 0.1)
	_jump_tween.tween_property(sprite, "offset", Vector2.DOWN * 16.0, 0.1)


func _cancel_drift() -> void:
	drift_direction = 0
	drift_duration = 0.0
	drift_level = 0
	emit_signal("drift_level_changed", drift_level)


func set_track_position(value: float) -> void:
	var dif: float = value - _track_position # Greater than 0 if moving forward
	var absdif: float = abs(dif)
	
	if dif > 0.3 || _before_track_start: # Prevents going from 0 to 1 instantly or doing crazy skips
		_before_track_start = true
		wrong_way = value < _wrong_track_position
		_wrong_track_position = value
		
		if absdif < 0.05:
			_before_track_start = false
		return
	
	wrong_way = dif < 0.0 # Going backwards
	
	if value < 0.05 && _track_position > 0.95:
		lap += 1
		emit_signal("lap_changed", lap)
		if lap > Game.lap_count:
			if lap == Game.lap_count + 1:
				emit_signal("race_finished")
			Game.switch_character_to_cpu(self)
	_track_position = value


func get_final_track_position() -> float:
	return (-lap) + (1.0 - _track_position)


func _prep_jump_tween() -> SceneTreeTween:
	if _jump_tween:
		_jump_tween.custom_step(10.0)
		_jump_tween.kill()
	_jump_tween = create_tween()
	return _jump_tween


func _setup_character() -> void:
	sprite.frames = character_resource.frames



func _get_configuration_warning() -> String:
	if !character_resource:
		return "Character Resource is not set!"
	elif !character_resource is CharacterResource:
		return "Character Resource is not of type CharacterResource!"
	if !_get_input_source():
		return "CharacterBase does not have an InputSource child!"
	return ""
