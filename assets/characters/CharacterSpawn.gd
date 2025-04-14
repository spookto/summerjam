class_name CharacterSpawn, "res://assets/characters/character_spawn.svg"
extends Spatial


var _spawned: bool = false

func _ready() -> void:
	print(name)
	pass # Replace with function body.


func _enter_tree() -> void:
	Game.add_spawner(self)


func _exit_tree() -> void:
	Game.remove_spawner(self)
