class_name PickupStack
extends Spatial

const MAX_PICKUPS: int = 3
const META_STACK: String = "pickup_stack"
const PIXEL_SIZE: float = 1.0/32.0
const ANGLE_MAX: float = PI * 0.3
const COLOR_UNSELECTED: Color = Color(0.3, 0.3, 0.3, 1.0)

var _pickups: Array = []
var _sprites: Array = []
var _last_global_position: Vector3 = Vector3.ZERO
var _selected_pickup: int = 0
var _select_tween: SceneTreeTween = null

onready var parent: Spatial = get_parent_spatial()

# Called when the node enters the scene tree for the first time.
func _ready():
	for i in range(MAX_PICKUPS):
		var s: Sprite3D = _create_sprite()
		s.position = (Vector3.BACK * 2.0).rotated(Vector3.UP, lerp(-ANGLE_MAX, ANGLE_MAX, i/float(MAX_PICKUPS-1)))
	
	owner.set_meta(META_STACK, self)
	set_as_toplevel(true)


func _process(_delta: float) -> void:
	global_position = parent.get_global_transform_interpolated().origin
	rotation.y = parent.global_rotation.y


# Returns 'true' if the pickup resource was added successfully
func add_pickup(resource: Resource) -> bool:
	if is_full() || !is_instance_valid(resource):
		return false
	_pickups.push_back(resource)
	_sprites[_pickups.size()-1].texture = resource.texture
	change_selection(0)
	return true


func is_full() -> bool:
	return _pickups.size() >= MAX_PICKUPS


func _create_sprite() -> Sprite3D:
	var sprite: Sprite3D = Sprite3D.new()
	_sprites.push_back(sprite)
	
	sprite.pixel_size = PIXEL_SIZE
	sprite.billboard = Material3D.BILLBOARD_ENABLED
	sprite.transparent = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	
	add_child(sprite)
	
	return sprite


func change_selection(direction: int) -> void:
	_selected_pickup = wrapi(_selected_pickup + direction, 0, _pickups.size())
	if _select_tween:
		_select_tween.kill()
	_select_tween = create_tween().set_parallel()
	for i in range(MAX_PICKUPS):
		_select_tween.tween_property(_sprites[i], "pixel_size", \
		(PIXEL_SIZE * 1.5) if i == _selected_pickup else PIXEL_SIZE, 0.1)
		_select_tween.tween_property(_sprites[i], "modulate", \
		Color.white if i == _selected_pickup else COLOR_UNSELECTED, 0.1)


func use(character: Node) -> void:
	if _pickups.empty():
		return
	
	var resource: Resource = _pickups[_selected_pickup]
	if resource.has_method(PickupResource.METHOD_USE):
		resource.call(PickupResource.METHOD_USE, character)
	
	_pickups.remove(_selected_pickup)
	
	for i in range(MAX_PICKUPS):
		_sprites[i].texture = null if i >= _pickups.size() else _pickups[i].texture
	
	change_selection(0)


static func get_from(node: Node) -> PickupStack:
	if node.has_meta(META_STACK):
		return node.get_meta(META_STACK) as PickupStack
	return null
