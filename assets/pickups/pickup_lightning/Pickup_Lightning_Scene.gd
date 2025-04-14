extends AnimatedSprite3D

const DELAY: float = 1.1

onready var sfx_buildup: AudioStreamPlayer3D = $SFXBuildup
onready var sfx_strike: AudioStreamPlayer3D = $SFXStrike

var target: CharacterBase = null
var _time: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_as_toplevel(true)
	
	yield(get_tree(), "idle_frame")
	
	var character: CharacterBase = owner as CharacterBase
	if !is_instance_valid(character):
		queue_free()
		push_error(name + " does not have a parent of type 'CharacterBase'")
		return
	
	var spot: int = character.place - 1
	# Attack 2nd place if we are in 1st place.
	if spot == 0:
		spot = 2
	target = Game.get_character_in_place(spot)
	
	play("default")
	
	var t: SceneTreeTween = create_tween()
	t.tween_property(sfx_buildup, "pitch_scale", 1.8, DELAY).from(0.8)
	sfx_buildup.play()
	t.tween_callback(sfx_buildup, "stop")
	t.tween_callback(sfx_strike, "play")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	global_position = target.global_position
	_time += delta
	if _time >= DELAY:
		_time = -1000.0
		target.stun(2.0)
		play("strike")
		
		yield(self, "animation_finished")
		queue_free()
