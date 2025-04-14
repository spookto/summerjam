extends Spatial


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var curve: Curve3D = Curve3D.new()
	for child in get_children():
		curve.add_point(child.global_position)
	curve.add_point(get_child(0).global_position)
	
	Game.track_curve = curve
