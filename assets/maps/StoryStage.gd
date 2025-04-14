extends Node

export var quick_apply: bool = false

export var stage_resource: Resource = null

# Called when the node enters the scene tree for the first time.
func _ready():
	if stage_resource is StoryStageResource:
		if !quick_apply:
			stage_resource.apply()
			return
		
		stage_resource.quick_apply()
		
		if is_instance_valid(stage_resource.next_stage_resource) && stage_resource.next_stage_resource is StoryStageResource:
			Game.connect("race_ended", self, "_on_race_ended", [stage_resource.next_stage_resource], CONNECT_ONESHOT)


func _on_race_ended(next_stage: StoryStageResource) -> void:
	Game.consume_race_finish()
	
	yield(create_tween().tween_interval(2.0), "finished")
	next_stage.apply()
