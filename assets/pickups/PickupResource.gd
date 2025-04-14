class_name PickupResource
extends Resource

const META_TEXTURE: String = "_vartex"
const META_SCENE: String = "_varscene"
const META_BIAS: String = "_varbias"

const METHOD_USE: String = "use"

export var texture: Texture = null
export var scene: PackedScene = null
export(int, 1, 6) var position_bias: int = 1
export(String, MULTILINE) var use_logic: String = ""

func _init() -> void:
	if has_meta(META_TEXTURE):
		texture = get_meta(META_TEXTURE, texture)
	if has_meta(META_SCENE):
		scene = get_meta(META_SCENE, scene)
	if has_meta(META_BIAS):
		position_bias = get_meta(META_BIAS, position_bias)

func setup() -> void:
	if use_logic.empty():
		return
	
	set_meta(META_TEXTURE, texture)
	set_meta(META_SCENE, scene)
	set_meta(META_BIAS, position_bias)
	
	var s: GDScript = GDScript.new()
	var t: String = get_script().source_code
	
	t += "\nfunc {0}(character: CharacterBase) -> void:\n".format([METHOD_USE])
	for line in use_logic.split("\n"):
		t += "\t"+line+"\n"
	s.source_code = t
	s.reload(true)
	
	call_deferred("_update", s)


func _update(script: Script) -> void:
	set_script(script)
