extends AnimatedSprite3D

const DURATION: float = 6.0
const SPEED: float = 80.0

var direction: Vector3 = Vector3.ZERO
var character: CharacterBase = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_as_toplevel(true)
	
	yield(get_tree(), "idle_frame")
	
	character = owner as CharacterBase
	if !is_instance_valid(character):
		queue_free()
		push_error(name + " does not have a parent of type 'CharacterBase'")
		return
	
	direction = character.get_forward()
	position = character.global_position
	
	play("default")
	
	var t: SceneTreeTween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	t.tween_callback(self, "queue_free").set_delay(DURATION)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if direction.is_zero_approx():
		return
	
	var next_position = position + direction * SPEED * delta
	
	move_and_collide(next_position)
	check_attack(delta)


func move_and_collide(next_position: Vector3) -> void:
	var space_state: PhysicsDirectSpaceState = get_world().direct_space_state
	
	var result: Dictionary = space_state.intersect_ray(position, next_position, [], 1)
	
	if result.empty():
		position = next_position
		return
	
	var col_position: Vector3 = result.get("position")
	var col_normal: Vector3 = result.get("normal")
	
	position = col_position + (col_normal * 0.1)
	direction = direction.bounce(col_normal).normalized()


func check_attack(delta: float) -> void:
	for other_character in Game._characters:
		if other_character == character:
			continue
		
		var dif: Vector3 = other_character.global_position - position
		var dist: float = dif.length_squared()
		dif.y = 0.0
		
		if dist <= 25.0:
			other_character.stun(2.0)
		elif dist <= 256.0:
			direction = direction.linear_interpolate(dif.normalized(), 0.2 * delta)
