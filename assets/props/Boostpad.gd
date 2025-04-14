extends Area

signal boosted

export var direction: Vector3 = Vector3.FORWARD
export var boost_force: float = 100.0
export var boost_hold: float = 0.3

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# HACK TO GET AI TO RESPOND TO THIS
	add_to_group(Pickup.GROUP)
	
	collision_layer = 0
	collision_mask = CharacterBase.COLLISION_LAYER
	
	connect("body_entered", self, "_on_body_entered")


func _on_body_entered(body: Node) -> void:
	var character: CharacterBase = body as CharacterBase
	if !character:
		return
	
	character.boost_direction(global_transform.basis.xform(direction), boost_force, boost_hold)
	emit_signal("boosted")
