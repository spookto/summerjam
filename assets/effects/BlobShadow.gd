extends RayCast


export var shadow_size: float = 2.0
onready var shadow_mesh: Spatial = $MeshInstance


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	shadow_mesh.scale.x = shadow_size
	shadow_mesh.scale.z = shadow_size
	shadow_mesh.set_as_toplevel(true)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	shadow_mesh.visible = is_colliding()
	if is_colliding():
		shadow_mesh.position = get_collision_point()
