extends TextureRect

const DELAY: float = 0.5

export var input_action: String = ""

export var texture_released: Texture = null
export var texture_pressed: Texture = null

export var repeat_animation: bool = false

func _ready() -> void:
	texture = texture_released
	
	if repeat_animation:
		var t: SceneTreeTween = create_tween().set_loops()
		t.tween_callback(self, "set_texture", [texture_pressed]).set_delay(DELAY)
		t.tween_callback(self, "set_texture", [texture_released]).set_delay(DELAY)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(input_action):
		texture = texture_pressed
	elif event.is_action_released(input_action):
		texture = texture_released
