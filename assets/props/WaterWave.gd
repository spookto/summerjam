extends Area

const SPEED: float = 2.0 * PI
onready var mesh: MeshInstance = $MeshInstance

var _offset: float = 0.0

func _ready() -> void:
	_offset = randf()*PI
	mesh.position.y = (sin(_offset) - 0.5)
	
	connect("body_entered", self, "_on_body_entered")

func _physics_process(delta: float) -> void:
	_offset += delta * SPEED
	mesh.position.y = sin(_offset) - 0.5
	mesh.position.z = cos(_offset)
	mesh.position *= 1.0
	
	var overlapping_bodies: Array = get_overlapping_bodies()
	if overlapping_bodies.empty():
		return
	
	for body in overlapping_bodies:
		body.velocity.y += 120.0 * delta
		print(body)


func _on_body_entered(body: Node) -> void:
	if body is CharacterBase:
		body.velocity.y += 12.0
