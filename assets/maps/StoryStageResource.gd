class_name StoryStageResource
extends Resource

export var map_resource: Resource = null
export var player_character: Resource = null
export var cpu_characters: Array = []
export(int, 1, 5) var lap_count: int = 3

export var next_stage_resource: Resource = null


func apply() -> void:
	_add_characters_and_laps()
	Game.load_map(map_resource)


func quick_apply() -> void:
	#HACK
	Game._race_start_time = Game.RACE_START_TIME
	
	if map_resource is MapResource:
		Game.minimap.texture = map_resource.minimap
	
	_add_characters_and_laps()
	Game.spawn_characters()


func _add_characters_and_laps() -> void:
	Game.lap_count = lap_count
	
	if player_character is CharacterResource:
		Game.add_character(player_character)
	for character in cpu_characters:
		if character is CharacterResource:
			Game.add_character(character)
