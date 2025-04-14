class_name CharacterSprite
extends AnimatedSprite3D

const META_ANIMATION: String = "_animation"

enum ViewDirection {
	BACK,
	FRONT,
	SIDE_LEFT,
	SIDE_RIGHT,
}
var player_1_camera: Camera
var player_2_camera: Camera

var player_2_sprite: AnimatedSprite3D

# Called when the node enters the scene tree for the first time.
func _ready():
	yield(get_parent(), "ready")
	player_1_camera = Game.get_camera(1)
	player_2_camera = Game.get_camera(2)
	
	
	player_2_sprite = AnimatedSprite3D.new()
	player_2_sprite.pixel_size = pixel_size
	player_2_sprite.billboard = billboard
	player_2_sprite.alpha_cut = alpha_cut
	player_2_sprite.frames = frames
	player_2_sprite.offset = offset
	player_2_sprite.playing = true
	
	layers = 1 << Game.PLAYER_1_LAYER
	player_2_sprite.layers = 1 << Game.PLAYER_2_LAYER
	
	add_child(player_2_sprite)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	player_2_sprite.offset = offset
	_process_player_1_visuals()
	_process_player_2_visuals()


func _process_player_1_visuals() -> void:
	if !is_instance_valid(player_1_camera):
		player_1_camera = Game.get_camera(1)
		return
	
	animation = get_angle_animation(player_1_camera)


func _process_player_2_visuals() -> void:
	if !is_instance_valid(player_2_camera):
		player_2_camera = Game.get_camera(2)
		return
		
	player_2_sprite.play(get_angle_animation(player_2_camera))


# 0 = Side, 1 = Front, -1 = Back
func get_angle_state(source_camera: Spatial) -> int:
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	
	var cam_forward: Vector3 = -source_camera.global_transform.basis.z
	cam_forward.y = 0.0
	cam_forward = cam_forward.normalized()
	
	var dot: float = cam_forward.dot(forward)
	
	if dot < -0.55:
		return ViewDirection.FRONT
	elif dot < 0.65:
		if Vector2(forward.x, forward.z).angle_to(Vector2(cam_forward.x, cam_forward.z)) > 0.0:
			return ViewDirection.SIDE_LEFT
		return ViewDirection.SIDE_RIGHT
	
	return ViewDirection.BACK


func get_angle_animation(source_camera: Spatial) -> String:
	match get_angle_state(source_camera):
		ViewDirection.SIDE_LEFT:
			return "default_l"
		ViewDirection.SIDE_RIGHT:
			return "default_r"
		ViewDirection.FRONT:
			return "front"
	return get_meta(META_ANIMATION, "")
