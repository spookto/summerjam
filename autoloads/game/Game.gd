class_name GameAutoloadClass
extends CanvasLayer

signal race_started
signal race_ended

const ENABLE_DEBUG: bool = false

const SCENE_CHARACTER_BASE: PackedScene = preload("res://assets/characters/CharacterBase.tscn")
const SCENE_PLAYER_UI: PackedScene = preload("res://assets/player_ui/PlayerUI.tscn")

const MINIMAP_SCALE: float = 128.0/1280.0

const PLAYER_LIMIT: int = 2

const PLAYER_1_LAYER: int = 1
const PLAYER_2_LAYER: int = 2

const PLAYER_CAMERA_FOV_SINGLEPLAYER: float = 60.0
const PLAYER_CAMERA_FOV_MULTIPLAYER: float = 40.0

const PICKUPS_PATH: String = "res://assets/pickups/resources/"
const RACE_START_TIME: float = 1.25
const META_LAST_RACE_STARTED: String = "last_race_started"

export var blip_player_1: Texture = null
export var blip_player_2: Texture = null
export var blip_player_cpu: Texture = null

onready var player_2_control: Control = $VBoxContainer/Player2
onready var minimap: TextureRect = $Minimap

var lap_count: int = 3

var track_curve: Curve3D = null

var _cameras: Array = []
var _characters: Dictionary = {}
var _pickups: Array = []

var _spawn_resources: Array = []
var _spawn_points: PoolVector3Array = PoolVector3Array([])

var _player_1_slot: int = HardwareInputSource.SourceSlot.ALL
var _player_2_slot: int = HardwareInputSource.SourceSlot.ALL

var _race_start_time: float = RACE_START_TIME
var _players_left: int = 10
var _mobile: bool = false

func _ready() -> void:
	_mobile = OS.get_name() == "Android"
	
	randomize()
	_populate_pickups()
	
	propagate_call("set_world", [get_viewport().world])
	set_player2_state(false)


func _physics_process(delta: float) -> void:
	update_character_positions()
	_update_start_timer(delta)


func is_mobile() -> bool:
	return _mobile


func add_player_camera(camera: PlayerCamera) -> void:
	if camera.is_queued_for_deletion():
		print("Game won't add Camera because it is queued for deletion.")
		return
	if _cameras.has(camera) || _cameras.size() >= PLAYER_LIMIT:
		return
	show()
	_cameras.append(camera)
	
	var fov: float = PLAYER_CAMERA_FOV_SINGLEPLAYER
	var mask_layer: int = PLAYER_2_LAYER
	
	camera.get_parent().remove_child(camera)
	if _cameras.size() < 2:
		$VBoxContainer/Player1/Viewport.add_child(camera)
	else:
		mask_layer = PLAYER_1_LAYER
		set_player2_state(true)
		$VBoxContainer/Player2/Viewport.add_child(camera)
		fov = PLAYER_CAMERA_FOV_MULTIPLAYER
	
	camera.cull_mask &= ~(1 << mask_layer)
	
	for camera in _cameras:
		camera.fov = fov
	
	camera.connect("tree_exiting", self, "_remove_camera", [camera], CONNECT_ONESHOT)


func _remove_camera(camera: PlayerCamera) -> void:
	set_player2_state(false)
	_cameras.erase(camera)
	if _cameras.empty():
		hide()
		return
	for old_camera in _cameras:
		old_camera.fov = PLAYER_CAMERA_FOV_SINGLEPLAYER


func set_player2_state(enabled: bool) -> void:
	if enabled:
		player_2_control.show()
		player_2_control.pause_mode = PAUSE_MODE_INHERIT
	else:
		player_2_control.hide()
		player_2_control.pause_mode = PAUSE_MODE_STOP


func get_camera(player_id: int) -> PlayerCamera:
	player_id = int(clamp(player_id, 1, PLAYER_LIMIT))
	if player_id > _cameras.size():
		return null
	return _cameras[player_id-1]


func register_character(character: CharacterBase) -> void:
	if _characters.has(character):
		return
	yield(get_tree(), "idle_frame")
	
	var is_player_controlled: bool = character.input_source is HardwareInputSource
	var is_player_1: bool = get_camera(1).parent_character == character
	
	# Slot state for current character, 0 = CPU, 1 and 2 = Players 1 and 2 respectively.
	var slot_state: int = (int(!is_player_1) + 1) * int(is_player_controlled)
	
	# Add minimap blip
	var blip: TextureRect = TextureRect.new()
	blip.name = "BlipCharacter" + String(_characters.size())
	
	# TODO replace these if statements with a switch/match statement
	blip.rect_min_size = Vector2.ONE * (4 if is_player_controlled else 2)
	blip.texture = (blip_player_1 if is_player_1 else blip_player_2) if is_player_controlled else blip_player_cpu
	if is_player_controlled:
		yield(get_tree(), "idle_frame")
	
	minimap.add_child(blip)
	
	# Add place indicator blip
	add_child(CharacterPlaceIcon.new(character, slot_state))
	
	_characters[character] = blip
	character.connect("tree_exiting", self, "remove_character_blip", [character], CONNECT_ONESHOT)
	set_physics_process(true)


func remove_character_blip(character: CharacterBase) -> void:
	if !_characters.has(character):
		return
	
	var blip: Node = _characters[character] as Node
	if is_instance_valid(blip):
		blip.queue_free()
	
	_characters.erase(character)
	
	if _characters.empty():
		set_physics_process(false)


func update_character_positions() -> void:
	var characters_order: PoolVector2Array = []
	
	var characters_count: int = _characters.size()
	
	for i in range(characters_count):
		var character: CharacterBase = _characters.keys()[i]
		var blip: Control = _characters[character]
		blip.rect_position.x = character.global_position.x * MINIMAP_SCALE
		blip.rect_position.y = character.global_position.z * MINIMAP_SCALE
		blip.rect_position += minimap.rect_size * 0.5
		blip.rect_position -= blip.rect_size * 0.5
		
		character.set_track_position(track_curve.get_closest_offset(character.global_position) / track_curve.get_baked_length())
		characters_order.append(Vector2(character.get_final_track_position(), i))
	
	characters_order.sort() # Sorting PoolVector2Array only uses 'x' component
	for i in range(characters_count):
		var info: Vector2 = characters_order[i]
		var character: CharacterBase = _characters.keys()[info.y]
		character.place = i+1


func get_character_in_place(place: int) -> CharacterBase:
	var out_char: CharacterBase = null
	var dif: int = 100
	
	for character in _characters:
		var new_dif: int = int(abs(character.place - place))
		if new_dif == 0:
			return character
		elif new_dif <= dif:
			out_char = character
			dif = new_dif
	
	return out_char


func get_characters_count() -> int:
	return _characters.size()


func switch_character_to_cpu(character: CharacterBase) -> void:
	if character.input_source is CPUInputSource:
		print(character.name, " is already a CPU!")
		return
	var source: CPUInputSource = CPUInputSource.new()
	source.drift_enabled = true
	
	#source.look_ahead = 40.0
	#source.drift_look_ahead = 20.0
	#source.drift_angle_limit = 0.35
	# TODO: Update source settings based on current map
	
	character.add_child(source)
	character.input_source.queue_free()
	character.input_source = source


## Point offset is between the range [0, 1].
func get_track_point(point_offset: float) -> Vector3:
	point_offset = wrapf(point_offset, 0.0, 1.0)
	point_offset *= track_curve.get_baked_length()
	
	return track_curve.interpolate_baked(point_offset)

## Converts units distance to offset in the range of [0, 1].
func track_units_to_offset(units: float) -> float:
	return units / track_curve.get_baked_length()


func _populate_pickups() -> void:
	_pickups = []
	
	var dir: Directory = Directory.new()
	if dir.open(PICKUPS_PATH) == OK:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.get_extension() == "tres" && !file_name.begins_with("_"):
				_pickups.push_back(load(PICKUPS_PATH + file_name))
			file_name = dir.get_next()
	else:
		push_error("Game.gd: An error occurred when trying to access resources path.")
	
	for pickup in _pickups:
		if pickup.has_method("setup"):
			pickup.call("setup")


func get_random_pickup() -> PickupResource:
	return _pickups.pick_random()


func get_biased_pickup(character: CharacterBase) -> Resource:
	var total_weight: int = 0
	var out_pickup: Resource = null
	var current_bias: int = 0

	for pickup in _pickups:
		current_bias = 8 - int(abs(character.place - pickup.get("position_bias")))
		prints(pickup.resource_name, current_bias)
	
		var r: int = randi()%(total_weight + current_bias)

		if r >= total_weight:
			out_pickup = pickup

		total_weight += current_bias

	return out_pickup


func load_map(map: MapResource) -> void:
	_spawn_points.clear()
	if !map:
		minimap.texture = null
		return
	
	minimap.texture = map.minimap
	get_tree().change_scene_to(map.scene)
	
	_race_start_time = RACE_START_TIME
	# Wait one frame for map to initialize
	yield(get_tree(), "idle_frame")
	
	spawn_characters()


func set_player_input_slot(player_index: int, input_slot: int) -> GameAutoloadClass:
	if player_index > 1:
		_player_2_slot = input_slot
	else:
		_player_1_slot = input_slot
	return self


func is_two_players() -> bool:
	return _cameras.size() > 1


func add_character(character: CharacterResource) -> GameAutoloadClass:
	_spawn_resources.append(character)
	return self


func add_spawner(spawner: CharacterSpawn) -> void:
	_spawn_points.append(spawner.global_position)


func remove_spawner(spawner: CharacterSpawn) -> void:
	var spawner_position: Vector3 = spawner.global_position
	
	for i in range(_spawn_points.size()):
		var point: Vector3 = _spawn_points[i]
		if spawner_position.is_equal_approx(point):
			_spawn_points.remove(i)
			return


func is_race_started() -> bool:
	return _race_start_time < 0.0


func spawn_characters() -> void:
	_players_left = 0
	
	for i in range(_spawn_resources.size()):
		var resource: CharacterResource = _spawn_resources[i] as CharacterResource
		var spawn_point: Vector3 = _spawn_points[i] if i < _spawn_points.size() else Vector3.ZERO
		if !resource:
			continue
		
		var added_input: bool = false
		var character: CharacterBase = SCENE_CHARACTER_BASE.instance()
		if i == 0:
			var camera: PlayerCamera = PlayerCamera.new()
			camera.add_child(SCENE_PLAYER_UI.instance())
			character.add_child(camera)
			if _player_1_slot != HardwareInputSource.SourceSlot.ALL:
				character.add_child(HardwareInputSource.new().set_input_slot(_player_1_slot))
				added_input = true
				_players_left += 1
		else:
			if i == 1 && _player_2_slot != HardwareInputSource.SourceSlot.ALL:
				var camera: PlayerCamera = PlayerCamera.new()
				camera.add_child(SCENE_PLAYER_UI.instance())
				character.add_child(camera)
				character.add_child(HardwareInputSource.new().set_input_slot(_player_2_slot))
				added_input = true
				_players_left += 1
		
		if !added_input:
			var cpu_input: CPUInputSource = CPUInputSource.new()
			cpu_input.drift_enabled = i % 2 == 0
			character.add_child(cpu_input)
		else:
			character.connect("race_finished", self, "_on_player_race_finished")
		
		character.character_resource = resource
		character.position = spawn_point
		get_tree().current_scene.add_child(character)
	
	_spawn_resources = []


func _update_start_timer(delta: float) -> void:
	if is_race_started():
		if !get_meta(META_LAST_RACE_STARTED, false):
			emit_signal("race_started")
			set_meta(META_LAST_RACE_STARTED, true)
			#minimap.show()
		return
	_race_start_time -= delta
	set_meta(META_LAST_RACE_STARTED, false)
	#minimap.hide()


func _on_player_race_finished() -> void:
	_players_left -= 1
	if _players_left <= 0:
		_players_left = 1000
		_go_to_mainmenu = true
		
		emit_signal("race_ended")
		
		yield(create_tween().tween_interval(5.0), "finished")
		
		if !_go_to_mainmenu:
			return
		
		get_tree().change_scene("res://assets/menus/main_menu/MainMenu.tscn")

var _go_to_mainmenu: bool = true
# Prevent returning to main menu, call when handling story mode or custom menus after game end.
func consume_race_finish() -> void:
	_go_to_mainmenu = false


class CharacterPlaceIcon extends TextureRect:
	const SIZE: float = 24.0
	
	const BANNER_P1: Texture = preload("res://assets/player_ui/player_ui_banner_p1.png")
	const BANNER_P2: Texture = preload("res://assets/player_ui/player_ui_banner_p2.png")
	const BANNER_SIZE: float = 16.0
	const BANNER_OFFSET: Vector2 = Vector2((SIZE - BANNER_SIZE) * 0.5, SIZE - 4.0)
	
	const SCREEN_CENTER: Vector2 = Vector2(320.0, 160.0) * 0.5 + Vector2.DOWN * (SIZE * 1.2)
	
	var _character: CharacterBase = null
	var _banner: TextureRect = null
	
	func _init(character: CharacterBase, slot_state: int = 0):
		_character = character
		texture = _character.character_resource.icon
		_character.connect("tree_exiting", self, "queue_free")
		rect_pivot_offset = Vector2.ONE * SIZE * 0.5
		
		rect_position = SCREEN_CENTER
		
		if slot_state <= 0:
			return
		
		_banner = TextureRect.new()
		_banner.texture = BANNER_P1 if slot_state == 1 else BANNER_P2
		add_child(_banner)
		_banner.rect_position = BANNER_OFFSET
	
	func _process(delta: float) -> void:
		if _character.is_stunned():
			rect_rotation += 720.0 * delta
		else:
			rect_rotation = 0.0
		
		var place: int = int(Game.get_characters_count() * 0.5) - _character.place
		
		var final_position: Vector2 = Vector2.RIGHT * (place) * SIZE
		final_position += SCREEN_CENTER
		
		if !Game.is_two_players():
			final_position.y = 0.0
			rect_position.y = 0.0
		
		rect_position = rect_position.linear_interpolate(final_position, 8.0 * delta)
		
		if is_instance_valid(_banner):
			_banner.rect_global_position = rect_position + BANNER_OFFSET
			_banner.rect_rotation = -rect_rotation
