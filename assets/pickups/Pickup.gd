class_name Pickup
extends Area

const RESPAWN_TIME: float = 3.0
const RANDOM_TEXTURE: Texture = preload("./pickup_random.png")
const BIASED_DROPS: bool = true
const GROUP: String = "pickups_group"

export var keep_random: bool = false
export var fixed_resource: Resource = null
export var cpu_ignore: bool = false

var _resource: Resource = null
var _time: float = 0.0
var _enabled: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if !is_visible_in_tree():
		queue_free()
		return
	
	add_to_group(GROUP)
	
	if !keep_random:
		if fixed_resource == null:
			set_resource(Game.get_random_pickup())
		else:
			set_resource(fixed_resource)
	
	collision_layer = 0
	collision_mask = CharacterBase.COLLISION_LAYER
	
	connect("body_entered", self, "_on_body_entered")


func _physics_process(delta: float) -> void:
	if _time > 0.0:
		_time -= delta
		return
	set_enabled(true)


func _on_body_entered(body: Node) -> void:
	if !_enabled || !body is CharacterBase:
		return
	var stack: PickupStack = PickupStack.get_from(body)
	
	if keep_random:
		set_resource(Game.get_biased_pickup(body) if BIASED_DROPS else Game.get_random_pickup())
		call_deferred("set_resource", null)
	if !stack || !stack.add_pickup(_resource):
		return
	set_enabled(false)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if enabled:
		if fixed_resource == null && !keep_random:
			set_resource(Game.get_random_pickup())
		
		show()
		set_physics_process(false)
		return
	_time = RESPAWN_TIME
	hide()
	set_physics_process(true)


func set_resource(resource: Resource) -> void:
	_resource = resource
	
	$Sprite3D.texture = _resource.get("texture") if _resource else RANDOM_TEXTURE



static func get_pickups() -> Array:
	return Game.get_tree().get_nodes_in_group(GROUP)
