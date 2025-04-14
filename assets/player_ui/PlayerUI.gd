extends CanvasLayer

const LAP_TEXT: String = "LAP {0}/{1}"
const WRONG_WAY_UPDATE_DELAY: float = 1.0

onready var parent_camera: PlayerCamera = get_parent() as PlayerCamera
onready var parent_character: CharacterBase = parent_camera.parent_character
onready var speed: Label = $"%SpeedLabel"
onready var place: Label = $"%PlaceLabel"
onready var lap: Label = $"%LapLabel"
onready var wrong_way: Control = $"%WrongWay"
onready var debug_label: Label = $DebugLabel
onready var gameplay_hud: Control = $GameplayHUD

var _wrong_way_update: float = 0.0

func _ready() -> void:
	debug_label.visible = Game.ENABLE_DEBUG
	if Game.ENABLE_DEBUG:
		get_tree().connect("idle_frame", self, "_update_debug_info", [], CONNECT_DEFERRED)
	
	if !parent_camera:
		print("PlayerUI '{0}' does not have a parent of type PlayerCamera.".format([name]))
		queue_free()
		return
	if !parent_character:
		yield(parent_camera, "ready")
		parent_character = parent_camera.parent_character
	
	parent_character.connect("lap_changed", self, "_on_lap_changed")
	#Game.connect("race_started", gameplay_hud, "show")
	
	_on_lap_changed(1)
	gameplay_hud.show()
	
	wrong_way.hide()


func _physics_process(delta: float) -> void:
	if !is_instance_valid(parent_character):
		return
	
	var hvel: Vector3 = parent_character.velocity
	hvel.y = 0.0
	speed.text = String(round(hvel.length()))
	
	var place_string: String = ""
	match parent_character.place:
		1:
			place_string = "1st"
		2:
			place_string = "2nd"
		3:
			place_string = "3rd"
		_:
			place_string = String(parent_character.place) + "th"
	place.text = place_string
	
	if wrong_way.visible != parent_character.wrong_way:
		if !parent_character.wrong_way:
			_wrong_way_update += WRONG_WAY_UPDATE_DELAY # Instantly update if on right path
		_wrong_way_update += delta
		
		if _wrong_way_update > WRONG_WAY_UPDATE_DELAY:
			wrong_way.visible = parent_character.wrong_way
			_wrong_way_update = 0.0
	
	wrong_way.modulate.r = ((Engine.get_physics_frames()) % 60) > 20


func _update_debug_info() -> void:
	if !is_instance_valid(parent_character):
		return
	
	var state: int = parent_character.input_source._get_input_state()
	
	var info: Array = [PoolByteArray([state]).hex_encode(), var2str(InputSource.decode_input_state(state))]
	info.append(parent_character.input_source.steer)
	
	debug_label.text = "{0}\n{1}\n{2}".format(info)


func _on_lap_changed(character_lap: int) -> void:
	print_debug(character_lap)
	if character_lap > Game.lap_count:
		if character_lap == (Game.lap_count + 1):
			$Label.text = place.text + " PLACE"
			$Label.show()
		gameplay_hud.hide()
		return
	$Label.hide()
	lap.text = LAP_TEXT.format([character_lap, Game.lap_count])
