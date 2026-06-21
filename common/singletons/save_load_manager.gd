extends Node

var is_loading_game: bool = false

func save_game() -> void:
	var saver_script = load("res://common/singletons/game_saver.gd")
	if saver_script:
		var saver = saver_script.new()
		saver.save_game(self)

func load_game() -> void:
	var loader_script = load("res://common/singletons/game_loader.gd")
	if loader_script:
		var loader = loader_script.new()
		loader.load_game(self)
