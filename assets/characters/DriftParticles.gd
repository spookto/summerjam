extends Spatial


var owner_character: CharacterBase = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	owner_character = get_owner() as CharacterBase
	if !owner_character:
		queue_free()
		print("DriftParticles is not owned by CharacterBase")
		return
	
	owner_character.connect("drift_level_changed", self, "_show_particles")

func _show_particles(level: int) -> void:
	level -= 1
	for i in range(3):
		var child: Spatial = get_child(i)
		if i == level:
			child.show()
		else:
			child.hide()
